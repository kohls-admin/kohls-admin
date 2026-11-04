--!strict
--[[
Network-synchronized signals shared between the server and clients.
Writes batch once per frame over a single `RemoteEvent` (or `UnreliableRemoteEvent`), and clients sync automatically on join.

```luau
-- Shared
local round = Flux.Sync("Round", "Lobby")
local coins = Flux.Sync("Coins", 0)
local theme = Flux.Sync("Theme", "Dark", function(player, value)
	return value == "Dark" or value == "Light" -- clients may write it; the server validates
end)

-- Server
round("Fighting") -- every client
coins:of(player)(250) -- only that player

-- Client
Flux.new "TextLabel" { Text = function() return `{round()}: {coins()} coins` end }
theme("Light") -- optimistic; rolled back if the server rejects it
```
]]

local Compat = require("./Compat")
local Graph = require("./Graph")

local Instance = Compat.Instance
local warn = Compat.warn
local Players: Players? = Compat.getService("Players")
local RunService: RunService? = Compat.getService("RunService")

local sampleSignal: any = Graph.signal(nil)
local SignalMT: any = getmetatable(sampleSignal)
local rawGet = SignalMT.get
local rawSet = SignalMT.set
local rawDestroy = SignalMT.Destroy

local function newSignal(initial: any, mt: any): any
	local raw: any = Graph.signal(initial)
	return setmetatable(raw, mt)
end

--[[
Validates a client write on the server (`fn(player, value)`).
Return `true` to accept (`true, replacement` to store `replacement`), or `false`/`nil` to reject without yielding.
]]
export type Validator<T> = (player: Player, value: T) -> (boolean?, ...T)

--[[
A signal synchronized between the server and clients.
Server writes replicate to all clients, and client writes are validated on the server.
]]
export type SyncSignal<T = any> = Graph.State<T> & {
	--[[
	Returns a per-player signal on the server whose writes replicate only to `player` (returns `self` on the client).
	]]
	of: (self: any, player: Player) -> Graph.State<T>,
	--[[
	Clears `player`'s per-player override on the server so they see the shared value again.
	]]
	clear: (self: any, player: Player) -> (),
	--[[
	Sets the server-side validator that allows clients to write to this signal (`nil` makes it server-only).
	]]
	validate: (self: any, fn: Validator<T>?) -> SyncSignal<T>,
	--[[
	Configures this signal to replicate over an `UnreliableRemoteEvent` instead of a reliable `RemoteEvent`.
	]]
	unreliable: (self: any, enabled: boolean?) -> SyncSignal<T>,
}

-- A table & function intersection rather than a `__call` metatable type: the solver only instantiates `T` through a
-- plain function type.
export type Namespace = {
	--[[
	Sends all pending synced changes immediately instead of waiting for the end of the frame.
	]]
	flush: () -> (),
	--[[
	Read-only node that is `true` on the server and turns `true` on the client once the initial sync arrives.
	]]
	ready: Graph.Node<boolean>,
	[string]: SyncSignal<any>,
} & (<T>(key: string, initial: T, validate: Validator<T>?) -> SyncSignal<T>)

-- Each synced signal stores its graph node at `[1]` alongside Sync's `_` bookkeeping fields.
type Synced = {
	_sync: Sync,
	_key: string,
	_id: string?,
	_validator: Validator<any>?,
	_unreliable: boolean,
	-- written (or given an initial) since creation, so a later `Flux.Sync(key, initial)` must not overwrite it
	_touched: boolean,
	-- server: per-player signals, created by the first `:of` (which routes accepted client writes per player)
	_own: { [any]: PlayerSignal }?,
	_ownCount: number,
	_yieldWarned: boolean?,
	-- client: the stamp of the last batch that carried this signal
	_lastSent: number,
}

type PlayerSignal = {
	_owner: Synced?,
	_player: any,
}

-- One side of the protocol. `reliable`/`unreliable` are the remotes, or tables with the same Fire methods in tests.
type Sync = {
	isServer: boolean,
	reliable: any,
	unreliable: any,
	signals: { [string]: Synced },
	byId: { [string]: Synced },
	ready: Graph.State<boolean>,
	connections: { RBXScriptConnection },
	-- server
	count: number,
	-- joined players -> client batches received (the ack they get back)
	received: { [any]: number },
	-- players who left; weak keys
	gone: { [any]: true },
	ackDirty: { [any]: boolean },
	playerDirty: { [any]: { [Synced]: boolean } },
	globalDirty: { [Synced]: boolean },
	announce: { Synced },
	validating: Synced?,
	wrote: boolean,
	-- client
	joined: boolean,
	sent: number,
	acked: number,
	outDirty: { [Synced]: boolean },
}

local instances: { [Sync]: true } = {}
local default: Sync? = nil

-- Batch buffers reused by every flush (flushes never nest: remotes serialize their arguments on the spot).
local reliableBuf: { any } = {}
local unreliableBuf: { any } = {}
local scopedBuf: { Synced } = {}

local function push(list: { any }, n: number, id: any, value: any): number
	list[n + 1] = id
	list[n + 2] = value
	return n + 2
end

local function pushEntry(
	reliableList: { any },
	rn: number,
	unreliableList: { any },
	un: number,
	entry: Synced,
	value: any
): (number, number)
	if entry._unreliable then
		return rn, push(unreliableList, un, entry._id, value)
	end
	return push(reliableList, rn, entry._id, value), un
end

local function idOf(n: number): string
	if n < 256 then
		return string.char(n)
	elseif n < 65536 then
		return string.pack("<I2", n)
	end
	error("Flux.Sync: more than 65536 synced signals", 5)
end

local function nodeValue(signal: any): any
	return signal[1][1]
end

local function valueFor(entry: Synced, player: any): any
	local own = entry._own
	local mine = own and own[player]
	return nodeValue(mine or entry)
end

local function markPlayer(sync: Sync, entry: Synced, player: any)
	local dirty = sync.playerDirty[player]
	if dirty == nil then
		dirty = {}
		sync.playerDirty[player] = dirty
	end
	dirty[entry] = true
end

local function written(sync: Sync, entry: Synced, player: any?)
	if not sync.isServer then
		sync.outDirty[entry] = true
		return
	end
	if sync.validating == entry then
		sync.wrote = true
	end
	if player == nil then
		sync.globalDirty[entry] = true
	else
		markPlayer(sync, entry, player)
	end
end

-- Drops `player`'s own signal; true if there was one.
local function drop(entry: Synced, player: any): boolean
	local own = entry._own
	local mine = if own then own[player] else nil
	if own == nil or mine == nil then
		return false
	end
	own[player] = nil
	entry._ownCount -= 1
	mine._owner = nil
	rawDestroy(mine)
	return true
end

local function call(self: any, value: any?, force: boolean?): any
	if value == nil and not force then
		return rawGet(self)
	end
	return self:set(value, force)
end

-- Forces a write of the current value so in-place table mutations replicate.
local function update(self: any): any
	self:set(nodeValue(self), true)
	return self
end

local SyncMT: any = table.clone(SignalMT)
SyncMT.__index = SyncMT
SyncMT.__call = call
SyncMT.update = update

local PlayerMT: any = table.clone(SignalMT)
PlayerMT.__index = PlayerMT
PlayerMT.__call = call
PlayerMT.update = update

function SyncMT.set(self: Synced, value: any, force: boolean?): any
	local old = nodeValue(self)
	rawSet(self, value, force)
	if old ~= value or force then
		self._touched = true
		written(self._sync, self, nil)
	end
	return value
end

function PlayerMT.set(self: PlayerSignal, value: any, force: boolean?): any
	local old = nodeValue(self)
	rawSet(self, value, force)
	local owner = self._owner
	if owner and (old ~= value or force) then
		written(owner._sync, owner, self._player)
	end
	return value
end

function SyncMT.of(self: Synced, player: any): any
	local sync = self._sync
	if not sync.isServer then
		return self
	end
	local own = self._own
	local mine = if own then own[player] else nil
	if mine then
		return mine
	elseif sync.gone[player] then
		error(`Flux.Sync: {player} left; "{self._key}" has no value for them anymore`, 2)
	end
	local node: PlayerSignal = newSignal(nodeValue(self), PlayerMT)
	node._owner = self
	node._player = player
	if own then
		own[player] = node
	else
		self._own = { [player] = node }
	end
	self._ownCount += 1
	-- the player may not have been sent the shared value this node starts from yet
	markPlayer(sync, self, player)
	return node
end

function SyncMT.clear(self: Synced, player: any)
	if drop(self, player) then
		written(self._sync, self, player)
	end
end

function SyncMT.validate(self: Synced, fn: Validator<any>?): any
	self._validator = fn
	return self
end

function SyncMT.unreliable(self: Synced, enabled: boolean?): any
	self._unreliable = enabled ~= false
	return self
end

table.freeze(SyncMT)
table.freeze(PlayerMT)

local function createEntry(sync: Sync, key: string, initial: any): Synced
	local id = if sync.isServer then idOf(sync.count) else nil
	local entry: Synced = newSignal(initial, SyncMT)
	entry._sync = sync
	entry._key = key
	entry._id = id
	entry._unreliable = false
	entry._touched = initial ~= nil
	entry._ownCount = 0
	entry._lastSent = 0
	sync.signals[key] = entry
	if id then
		sync.count += 1
		sync.byId[id] = entry
		if next(sync.received) ~= nil then
			table.insert(sync.announce, entry)
		end
	end
	return entry
end

local function signal(sync: Sync, key: string, initial: any, validate: Validator<any>?): Synced
	if type(key) ~= "string" then
		error(`Flux.Sync: the key must be a string, got {typeof(key)}`, 3)
	end
	local entry = sync.signals[key]
	if entry == nil then
		entry = createEntry(sync, key, initial)
	elseif initial ~= nil and not entry._touched then
		entry._touched = true
		rawSet(entry, initial)
		if sync.isServer then
			sync.globalDirty[entry] = true
		end
	end
	if validate then
		entry._validator = validate
	end
	return entry
end

-- client: applies a server value unless the client has a write the server has not answered yet
local function applyRemote(sync: Sync, entry: Synced?, value: any)
	if entry == nil or sync.outDirty[entry] or entry._lastSent > sync.acked then
		return
	end
	entry._touched = true
	rawSet(entry, value)
end

local function link(sync: Sync, links: any, handshake: boolean)
	if type(links) ~= "table" then
		return
	end
	for id, data in links do
		if type(id) ~= "string" or type(data) ~= "table" or type(data[1]) ~= "string" then
			continue
		end
		local key = data[1]
		local entry = sync.signals[key] or createEntry(sync, key, nil)
		entry._id = id
		sync.byId[id] = entry
		applyRemote(sync, entry, data[2])
	end
	if handshake and not sync.joined then
		sync.joined = true
		sync.ready:set(true)
	end
end

-- Runs `entry`'s validator on a coroutine so a yield is caught (and rejected) instead of leaking `validating` into
-- other remote threads. Returns whether to store a value and which one.
local function runValidator(
	sync: Sync,
	entry: Synced,
	validator: Validator<any>,
	player: any,
	value: any
): (boolean, any)
	local thread = coroutine.create(validator)
	sync.validating, sync.wrote = entry, false
	local ok, accepted, replacement = coroutine.resume(thread, player, value)
	sync.validating = nil
	if coroutine.status(thread) ~= "dead" then
		coroutine.close(thread)
		if not entry._yieldWarned then
			entry._yieldWarned = true
			warn(
				`[Flux] Sync validator for "{entry._key}" yielded; validators must not yield, so the write is rejected`
			)
		end
		return false, nil
	elseif not ok then
		warn(`[Flux] Sync validator for "{entry._key}" errored: {accepted}`)
		return false, nil
	end
	if not accepted or sync.wrote then
		return false, nil
	end
	return true, if replacement ~= nil then replacement else value
end

local function applyServer(sync: Sync, entry: Synced, player: any, value: any)
	local validator = entry._validator
	if validator then
		local accept, stored = runValidator(sync, entry, validator, player, value)
		if accept then
			local target: any = if entry._own then SyncMT.of(entry, player) else entry
			target:set(stored)
		end
	end
	if valueFor(entry, player) ~= value then
		written(sync, entry, player)
	else
		-- the client already shows this value; skip echoing it back to them
		local dirty = sync.playerDirty[player]
		if dirty then
			dirty[entry] = nil
		end
	end
end

local function hello(sync: Sync, player: any)
	if sync.received[player] or sync.gone[player] then
		return
	end
	sync.received[player] = 0
	sync.playerDirty[player] = nil
	local links = {}
	for key, entry in sync.signals do
		links[entry._id :: string] = { key, valueFor(entry, player) }
	end
	sync.reliable:FireClient(player, links, true)
end

-- Server -> client messages: `(id, value, ...)` batches, `(ack, id, value, ...)` per-player batches (ack = client
-- batches processed), `(links)` new ids and `(links, true)` the join handshake, links being
-- `{ [id] = { key, value } }`. Client -> server: `()` hello and `(id, value, ...)` batches.
local function receive(sync: Sync, ...: any)
	local n = select("#", ...)
	if sync.isServer then
		local player = ...
		if n == 1 then
			hello(sync, player)
			return
		end
		local received = sync.received[player]
		if received == nil then
			return
		end
		sync.received[player] = received + 1
		sync.ackDirty[player] = true
		local args = { ... }
		local byId = sync.byId
		for i = 2, n, 2 do
			local id = args[i]
			local entry = if type(id) == "string" then byId[id] else nil
			if entry then
				applyServer(sync, entry, player, args[i + 1])
			end
		end
		return
	end

	if n == 0 then
		return
	end
	local first, second = ...
	if type(first) == "table" then
		link(sync, first, second == true)
		return
	end
	local start = 1
	if type(first) == "number" then
		sync.acked = math.max(sync.acked, first)
		start = 2
	end
	if n < start then
		return
	end
	local args = { ... }
	local byId = sync.byId
	for i = start, n, 2 do
		local id = args[i]
		applyRemote(sync, if type(id) == "string" then byId[id] else nil, args[i + 1])
	end
end

local function flushServer(sync: Sync)
	local reliable = sync.reliable
	local unreliable = sync.unreliable or reliable
	local received, globalDirty, playerDirty, ackDirty =
		sync.received, sync.globalDirty, sync.playerDirty, sync.ackDirty

	local announce = sync.announce
	if #announce > 0 then
		local links = {}
		for _, entry in announce do
			links[entry._id] = { entry._key, nodeValue(entry) }
			if entry._ownCount == 0 then
				globalDirty[entry] = nil
			end
		end
		table.clear(announce)
		reliable:FireAllClients(links)
	end

	-- shared values of signals with per-player overrides go out per player, skipping players with their own
	local sn = 0
	for entry in globalDirty do
		if entry._ownCount > 0 then
			sn += 1
			scopedBuf[sn] = entry
		end
	end

	local rn, un
	for player, ack in received do
		local dirty = playerDirty[player]
		local hasDirty = dirty ~= nil and next(dirty) ~= nil
		if not hasDirty and sn == 0 and not ackDirty[player] then
			continue
		end
		reliableBuf[1] = ack
		rn, un = 1, 0
		if dirty ~= nil and hasDirty then
			for entry in dirty do
				rn, un = pushEntry(reliableBuf, rn, unreliableBuf, un, entry, valueFor(entry, player))
			end
		end
		for i = 1, sn do
			local entry = scopedBuf[i]
			local own = entry._own
			if (own == nil or own[player] == nil) and not (dirty ~= nil and dirty[entry]) then
				rn, un = pushEntry(reliableBuf, rn, unreliableBuf, un, entry, nodeValue(entry))
			end
		end
		if dirty ~= nil and hasDirty then
			table.clear(dirty)
		end
		if rn > 1 or ackDirty[player] then
			ackDirty[player] = nil
			reliable:FireClient(player, table.unpack(reliableBuf, 1, rn))
		end
		if un > 0 then
			unreliable:FireClient(player, table.unpack(unreliableBuf, 1, un))
		end
	end

	if next(globalDirty) ~= nil then
		if next(received) ~= nil then
			rn, un = 0, 0
			for entry in globalDirty do
				if entry._ownCount == 0 then
					rn, un = pushEntry(reliableBuf, rn, unreliableBuf, un, entry, nodeValue(entry))
				end
			end
			if rn > 0 then
				reliable:FireAllClients(table.unpack(reliableBuf, 1, rn))
			end
			if un > 0 then
				unreliable:FireAllClients(table.unpack(unreliableBuf, 1, un))
			end
		end
		table.clear(globalDirty)
	end

	-- release the values the buffers still reference
	table.clear(reliableBuf)
	table.clear(unreliableBuf)
	table.clear(scopedBuf)
end

local function flushClient(sync: Sync)
	local outDirty = sync.outDirty
	if not sync.joined or next(outDirty) == nil then
		return
	end
	local stamp = sync.sent + 1
	local n = 0
	for entry in outDirty do
		local id = entry._id
		if id then
			n = push(reliableBuf, n, id, nodeValue(entry))
			entry._lastSent = stamp
			outDirty[entry] = nil
		end
	end
	if n > 0 then
		sync.sent = stamp
		sync.reliable:FireServer(table.unpack(reliableBuf, 1, n))
		table.clear(reliableBuf)
	end
end

local function flush(sync: Sync)
	if sync.isServer then
		flushServer(sync)
	else
		flushClient(sync)
	end
end

local function playerRemoving(sync: Sync, player: any)
	sync.gone[player] = true
	for _, entry in sync.signals do
		drop(entry, player)
	end
	sync.received[player] = nil
	sync.ackDirty[player] = nil
	sync.playerDirty[player] = nil
end

local function start(sync: Sync)
	if not sync.isServer then
		sync.reliable:FireServer()
	end
end

local function destroy(sync: Sync)
	instances[sync] = nil
	for _, conn in sync.connections do
		conn:Disconnect()
	end
	table.clear(sync.connections)
	if default == sync then
		default = nil
	end
	rawDestroy(sync.ready)
end

-- Method form for tests (`inst:flush()`); the module calls the functions directly.
local InstanceMT = table.freeze({
	__index = table.freeze({
		signal = signal,
		flush = flush,
		receive = receive,
		start = start,
		destroy = destroy,
		playerRemoving = playerRemoving,
	}),
})

local function newSync(isServer: boolean, reliable: any, unreliable: any): Sync
	local raw: any = setmetatable({
		isServer = isServer,
		reliable = reliable,
		unreliable = unreliable,
		signals = {},
		byId = {},
		ready = Graph.signal(isServer),
		connections = {},
		count = 0,
		received = {},
		gone = setmetatable({}, { __mode = "k" }),
		ackDirty = {},
		playerDirty = {},
		globalDirty = {},
		announce = {},
		validating = nil,
		wrote = false,
		joined = false,
		sent = 0,
		acked = 0,
		outDirty = {},
	}, InstanceMT)
	local sync: Sync = raw
	instances[sync] = true
	return sync
end

local function onEvent(...: any)
	receive(default :: Sync, ...)
end

local function onPlayerRemoving(player: Player)
	-- deferred so other PlayerRemoving handlers (saving data, say) can still read `sig:of(player)`
	task.defer(playerRemoving, default :: Sync, player)
end

local function connectClient(sync: Sync, container: Instance)
	local event = container:WaitForChild("SyncEvent") :: RemoteEvent
	local unreliableEvent = container:WaitForChild("SyncUnreliable") :: UnreliableRemoteEvent
	sync.reliable = event
	table.insert(sync.connections, event.OnClientEvent:Connect(onEvent))
	table.insert(sync.connections, unreliableEvent.OnClientEvent:Connect(onEvent))
	start(sync)
end

local function findOrCreate(container: Instance, name: string, class: "RemoteEvent" | "UnreliableRemoteEvent"): any
	local remote = container:FindFirstChild(name)
	if not remote then
		remote = Instance.new(class)
		remote.Name = name
		remote.Parent = container
	end
	return remote
end

-- Wires the default instance to remotes under this module: the server creates them, a client waits for them in the
-- background so creating signals never yields. Clients only send on the reliable remote, so the server only listens
-- there.
local function getDefault(): Sync
	if default then
		return default
	end
	local runService, players = RunService, Players
	if not Compat.isRoblox or not runService or not players then
		error("Flux.Sync needs Roblox; headless tests use Sync._internal.create", 3)
	end
	if runService:IsServer() then
		local event: RemoteEvent = findOrCreate(script, "SyncEvent", "RemoteEvent")
		local unreliableEvent: UnreliableRemoteEvent = findOrCreate(script, "SyncUnreliable", "UnreliableRemoteEvent")
		local sync = newSync(true, event, unreliableEvent)
		default = sync
		table.insert(sync.connections, event.OnServerEvent:Connect(onEvent))
		table.insert(sync.connections, players.PlayerRemoving:Connect(onPlayerRemoving))
		return sync
	end
	local sync = newSync(false, nil, nil)
	default = sync
	task.spawn(connectClient, sync, script)
	return sync
end

-- `Flux.Sync` and test namespaces share this metatable; a test namespace holds its instance at `_sync`.
local NamespaceMT = {}

function NamespaceMT.__index(ns: any, key: any): any
	local sync = rawget(ns, "_sync") or getDefault()
	if key == "ready" then
		return sync.ready
	end
	return signal(sync, key, nil)
end

function NamespaceMT.__call(ns: any, key: string, initial: any, validate: Validator<any>?): any
	return signal(rawget(ns, "_sync") or getDefault(), key, initial, validate)
end

table.freeze(NamespaceMT)

local function flushDefault()
	if default then
		flush(default)
	end
end

local function stepAll()
	for sync in instances do
		flush(sync)
	end
end

-- Tests: a namespace over remote-shaped tables (`FireClient`/`FireAllClients` or `FireServer`), plus its instance.
local function createInternal(isServer: boolean, reliable: any, unreliable: any?): (Namespace, any)
	local sync = newSync(isServer, reliable, unreliable)
	local function flushThis()
		flush(sync)
	end
	local ns: any = setmetatable({ _sync = sync, flush = flushThis }, NamespaceMT)
	return ns, sync
end

local Sync: any = setmetatable({ flush = flushDefault }, NamespaceMT)

--- @ignore
Sync._internal = table.freeze({
	-- Flushes every Sync instance; init.luau runs it each frame after the graph flush.
	flushAll = stepAll,
	step = stepAll,
	create = createInternal,
})

return Sync :: Namespace & { _internal: any }
