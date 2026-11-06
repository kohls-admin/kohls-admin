--!optimize 2
--!strict

--[[
	Single-remote networking wrapper with byte-packed IDs and auto-batching.

	Standard Roblox networking often involves creating many RemoteEvents. However, this creates network
	overhead because every unique RemoteEvent adds its own packet header and protocol metadata.

	When multiple calls are made on the same RemoteEvent within a single frame, the engine merges them
	into one packet sequence separated by 0x00 (null) delimiters.

	This module exploits that behavior:
	1. It funnels all game traffic through a single RemoteEvent (and one UnreliableRemoteEvent).
	2. It assigns short, byte-packed IDs (1-2 bytes) to logical events.
	3. Result: Massive reduction in packet overhead (headers/delimiters) and automatic queueing.

	### Key features

	- Lazy Instantiation: Just do `Remote.MyEvent`. If it doesn't exist, it's created.
	- Auto-Synchronization: Clients automatically wait for the server to replicate IDs.
	  No `WaitForChild` required.
	- Byte-Packing: IDs are compressed to 1 byte (for the first 256 events) or 2 bytes.
	- Reliability Toggling: Switch an event to `Unreliable` mode on the fly.

	### API reference

	```luau
	-- Shared
	local _ = Remote.EventName:Connect(callback)     --> RBXScriptConnection
	Remote.EventName:Once(callback)        --> RBXScriptConnection
	Remote.EventName:Wait()                --> ...any

	-- Server
	Remote.EventName:Fire(player, ...)     --> void
	Remote.EventName:FireAll(...)          --> void
	Remote.FuncName:Invoke(player, ...)    --> ...any (invokes the client)
	Remote.EventName:SetUnreliable(bool)   --> void (switches transport method)
	Remote.FuncName.OnInvoke = (...) -> ...any

	-- Client
	Remote.EventName:Fire(...)             --> void
	Remote.FuncName:Invoke(...)            --> ...any (invokes the server)
	Remote.FuncName.OnInvoke = (...) -> ...any
	```

	### Usage

	```luau
	-- Server
	local Remote = require(ReplicatedStorage.Remote)

	Remote.GetGold.OnInvoke = function(player)
		return 100
	end

	task.wait(5)

	Remote.Combat:FireAll("FightStarted")

	-- Client
	local Remote = require(ReplicatedStorage.Remote)
	local _ = Remote.Combat:Connect(function(status) print(status) end) -- Prints "FightStarted"
	print(Remote.GetGold:Invoke()) -- Prints 100
	```
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Signal = require(script.Parent.Signal)

local IS_SERVER = RunService:IsServer()

local EVENT: RemoteEvent, FUNCTION: RemoteFunction, UNRELIABLE: UnreliableRemoteEvent

if IS_SERVER then
	local function getOrCreate(className: string)
		local remote = script:FindFirstChildOfClass(className)
		if not remote then
			remote = Instance.new(className)
			remote.Name = className
			remote.Parent = script
		end
		return remote
	end

	EVENT = getOrCreate("RemoteEvent") :: RemoteEvent
	FUNCTION = getOrCreate("RemoteFunction") :: RemoteFunction
	UNRELIABLE = getOrCreate("UnreliableRemoteEvent") :: UnreliableRemoteEvent
else
	EVENT = script:WaitForChild("RemoteEvent") :: RemoteEvent
	FUNCTION = script:WaitForChild("RemoteFunction") :: RemoteFunction
	UNRELIABLE = script:WaitForChild("UnreliableRemoteEvent") :: UnreliableRemoteEvent
end

if not IS_SERVER and not script:IsDescendantOf(ReplicatedStorage) then
	warn("Remote module should be placed in ReplicatedStorage")
end

local RemoteObject = {}
RemoteObject.__index = RemoteObject

export type RemoteData = {
	_key: string,
	_id: string?,
	_signal: Signal.Signal,
	_remote: RemoteEvent | UnreliableRemoteEvent,
	_fireQueue: { { n: number, [number]: any } }?,
	_invokeQueue: { { n: number, [number]: any } }?,
	_warnScheduled: boolean?,

	OnInvoke: ((...any) -> ...any)?,
}

export type Remote = typeof(setmetatable({} :: RemoteData, RemoteObject))

local Remote: { [string]: Remote } = {}
local idToRemote: { [string]: Remote } = {}

local function newRemote(key: string, internalId: string?): Remote
	local self = setmetatable({
		_id = internalId,
		_key = key,
		_signal = Signal.new(),
		_remote = EVENT,
	}, RemoteObject) :: Remote

	Remote[key] = self

	if internalId then
		idToRemote[internalId] = self
	end

	return self
end

function RemoteObject.Connect(self: Remote, callback: (...any) -> ()): Signal.Connection
	return self._signal:Connect(callback)
end

function RemoteObject.Once(self: Remote, callback: (...any) -> ()): Signal.Connection
	return self._signal:Once(callback)
end

function RemoteObject.Wait(self: Remote): ...any
	return self._signal:Wait()
end

function RemoteObject.FireAll(self: Remote, ...)
	(self._remote :: RemoteEvent):FireAllClients(self._id, ...)
end

function RemoteObject.SetUnreliable(self: Remote, state: boolean)
	if not IS_SERVER then
		warn(`Client cannot set reliability on Remote {self._key}`)
	else
		local targetRemote = state and UNRELIABLE or EVENT
		if self._remote ~= targetRemote then
			self._remote = targetRemote
			if self._id then
				EVENT:FireAllClients(script, state, self._id)
			end
		end
	end
end

if IS_SERVER then
	function RemoteObject.Fire(self: Remote, player: Player, ...)
		(self._remote :: RemoteEvent):FireClient(player, self._id, ...)
	end

	function RemoteObject.Invoke(self: Remote, player: Player, ...): ...any
		assert(self._id, `Remote "{self._key}" is not initialized`)
		return FUNCTION:InvokeClient(player, self._id, ...)
	end

	local _idCounter = 0
	local function generateId(): string
		local n = _idCounter
		_idCounter += 1

		return if n < 256 then string.char(n) else string.pack("<I2", n)
	end

	setmetatable(Remote, {
		__index = function(_, key: string)
			local id = generateId()
			local new = newRemote(key, id)
			EVENT:FireAllClients(script, key, id)

			return new
		end,
	})

	local loaded = {}
	local function syncPayload(player: Player)
		if loaded[player] then
			return
		end
		loaded[player] = true

		local payload: { [string]: { string | boolean? } } = {}

		for name, remote in pairs(Remote) do
			if remote._id then
				local unreliable = if remote._remote == UNRELIABLE then true else nil
				payload[remote._id] = { name, unreliable }
			end
		end

		EVENT:FireClient(player, script, payload)
	end

	local _ = Players.PlayerRemoving:Connect(function(player)
		loaded[player] = nil
	end)

	local function handleEvent(player: Player, id: Instance | string, ...)
		if id == script then
			syncPayload(player)
			return
		end
		if type(id) ~= "string" then
			return
		end
		local remote = idToRemote[id]
		if remote then
			remote._signal:Fire(player, ...)
		end
	end

	local function handleServerInvoke(player: Player, id: Instance | string, ...)
		if type(id) ~= "string" then
			return
		end
		local remote = idToRemote[id]
		if remote and remote.OnInvoke then
			return remote.OnInvoke(player, ...)
		end
		return
	end

	local _ = EVENT.OnServerEvent:Connect(handleEvent)
	local _ = UNRELIABLE.OnServerEvent:Connect(handleEvent)
	FUNCTION.OnServerInvoke = handleServerInvoke

	EVENT:SetAttribute("ServerReady", true)
else -- Client
	local function warnIfUnlinked(self: Remote)
		if not self._warnScheduled then
			self._warnScheduled = true
			task.delay(5, function()
				if not self._id then
					warn(`Infinite yield possible on Remote '{self._key}'`)
				end
			end)
		end
	end

	function RemoteObject.Wait(self: Remote): ...any
		if not self._id then
			warnIfUnlinked(self)
		end
		return self._signal:Wait()
	end

	function RemoteObject.Fire(self: Remote, ...)
		if self._id then
			(self._remote :: RemoteEvent):FireServer(self._id, ...)
		else
			local fireQueue: { { [number]: any, n: number } } = self._fireQueue or {}
			self._fireQueue = fireQueue
			-- packed so nil arguments survive the queue
			table.insert(fireQueue, table.pack(...))
		end
	end

	function RemoteObject.Invoke(self: Remote, ...): ...any
		if self._id then
			return FUNCTION:InvokeServer(self._id, ...)
		else
			warnIfUnlinked(self)
			local invokeQueue: { { [number]: any, n: number } } = self._invokeQueue or {}
			self._invokeQueue = invokeQueue
			table.insert(invokeQueue, table.pack(coroutine.running(), ...))

			return coroutine.yield()
		end
	end

	setmetatable(Remote, {
		__index = function(_, key: string)
			return newRemote(key)
		end,
	})

	local function flushQueue(remote: Remote)
		if remote._fireQueue then
			for _, args in remote._fireQueue do
				(remote._remote :: RemoteEvent):FireServer(remote._id, unpack(args, 1, args.n))
			end
			remote._fireQueue = nil
		end

		if remote._invokeQueue then
			for _, args in remote._invokeQueue do
				local thread = args[1]
				task.spawn(function()
					local ok, result = pcall(function()
						return table.pack(FUNCTION:InvokeServer(remote._id, unpack(args, 2, args.n)))
					end)
					if coroutine.status(thread) == "suspended" then
						if ok then
							task.spawn(thread, unpack(result, 1, result.n))
						else
							warn("Error invoking remote function:", result)
							task.spawn(thread)
						end
					end
				end)
			end
			remote._invokeQueue = nil
		end
	end

	local function linkId(name: string, id: string, unreliable: boolean?)
		local remote = Remote[name]
		if not remote then
			remote = newRemote(name, nil)
		end

		remote._id = id
		idToRemote[id] = remote
		remote._remote = if unreliable then UNRELIABLE else EVENT

		flushQueue(remote)
	end

	local function handleSync(arg1: any, arg2: any)
		-- New Event: (string Name, string ID)
		if type(arg1) == "string" then
			linkId(arg1, arg2)

		-- Reliability Change: (boolean State, string ID)
		elseif type(arg1) == "boolean" then
			local remote = idToRemote[arg2]
			if remote then
				remote._remote = if arg1 then UNRELIABLE else EVENT
			end

		-- Initial Sync: { [string ID]: {string Name, boolean? Unreliable} }
		elseif type(arg1) == "table" then
			for id, data in arg1 do
				linkId(data[1], id, data[2])
			end
		end
	end

	local function handleEvent(id: Instance | string, ...)
		if id == script then
			handleSync(...)
			return
		end
		if type(id) ~= "string" then
			return
		end
		local remote = idToRemote[id]
		if remote then
			remote._signal:Fire(...)
		end
	end

	local function handleClientInvoke(id: Instance | string, ...)
		if type(id) ~= "string" then
			return
		end
		local remote = idToRemote[id]
		if remote and remote.OnInvoke then
			return remote.OnInvoke(...)
		end
		return
	end

	local _ = EVENT.OnClientEvent:Connect(handleEvent)
	local _ = UNRELIABLE.OnClientEvent:Connect(handleEvent)
	FUNCTION.OnClientInvoke = handleClientInvoke

	if not EVENT:GetAttribute("ServerReady") then
		EVENT:GetAttributeChangedSignal("ServerReady"):Wait()
	end

	EVENT:FireServer(script)
end

return Remote
