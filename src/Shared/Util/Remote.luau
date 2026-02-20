--!optimize 2
--!strict

--[[
	NETWORKING MODULE
	Single-Remote Wrapper with Byte-Packed IDs and Auto-Batching

	Standard Roblox networking often involves creating many RemoteEvents. However, this creates network
	overhead because every unique RemoteEvent adds its own packet header and protocol metadata.

	When multiple calls are made on the same RemoteEvent within a single frame, the engine merges them
	into one packet sequence separated by 0x00 (null) delimiters.

	This module exploits that behavior:
	1. It funnels all game traffic through a single RemoteEvent (and one UnreliableRemoteEvent).
	2. It assigns short, byte-packed IDs (1-2 bytes) to logical events.
	3. Result: Massive reduction in packet overhead (headers/delimiters) and automatic queueing.

	[ KEY FEATURES ]

	* Lazy Instantiation: Just do `Remote.MyEvent`. If it doesn't exist, it's created.
	* Auto-Synchronization: Clients automatically wait for the server to replicate IDs.
		No `WaitForChild` required.
	* Byte-Packing: IDs are compressed to 1 byte (for the first 256 events) or 2 bytes.
	* Reliability Toggling: Switch an event to `Unreliable` mode on the fly.

	[ API REFERENCE ]

	> SHARED

		Remote.EventName:Connect(callback)     -> RBXScriptConnection
		Remote.EventName:Once(callback)        -> RBXScriptConnection
		Remote.EventName:Wait()                -> ...any

	> SERVER

		Remote.EventName:Fire(player, ...)     -> void
		Remote.EventName:FireAll(...)          -> void
		Remote.FuncName:Invoke(player, ...)    -> ...any (Invokes Client)

		Remote.EventName:SetUnreliable(bool)   -> void   (Switches transport method)

		Remote.FuncName.OnInvoke = (...) -> ...any

	> CLIENT

		Remote.EventName:Fire(...)             -> void
		Remote.FuncName:Invoke(...)            -> ...any (Invokes Server)

		Remote.FuncName.OnInvoke = (...) -> ...any

	[ USAGE EXAMPLE ]

	-- Server
	local Remote = require(ReplicatedStorage.Remote)

	Remote.GetGold.OnInvoke = function(player)
		return 100
	end

	task.wait(5)

	Remote.Combat:FireAll("FightStarted")

	-- Client
	local Remote = require(ReplicatedStorage.Remote)
	Remote.Combat:Connect(function(status) print(status) end) -- Prints "FightStarted"
	print(Remote.GetGold:Invoke()) -- Prints 100
	____________________________________________________________________________________________________
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Signal = require(script.Parent.Signal)

local IS_SERVER = RunService:IsServer()

local EVENT: RemoteEvent, FUNCTION: RemoteFunction, UNRELIABLE: UnreliableRemoteEvent

if IS_SERVER then
	EVENT = script:FindFirstChildOfClass("RemoteEvent") or Instance.new("RemoteEvent", script)
	FUNCTION = script:FindFirstChildOfClass("RemoteFunction") or Instance.new("RemoteFunction", script)
	UNRELIABLE = script:FindFirstChildOfClass("UnreliableRemoteEvent") or Instance.new("UnreliableRemoteEvent", script)

	EVENT.Name = "RemoteEvent"
	FUNCTION.Name = "RemoteFunction"
	UNRELIABLE.Name = "UnreliableRemoteEvent"
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
	_fireQueue: { { any } }?,
	_invokeQueue: { { any } }?,

	OnInvoke: ((...any) -> ...any)?,
}

export type Remote = typeof(setmetatable({} :: RemoteData, RemoteObject))

local Remote: { [string | Instance]: Remote } = {}
local idToRemote: { [string | Instance]: Remote } = {}

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

function RemoteObject.Once(self: Remote, callback: (...any) -> ()): ...any?
	return self._signal:Once(callback)
end

function RemoteObject.Wait(self: Remote): ...any?
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
		if loaded[player.UserId] then
			return
		end
		loaded[player.UserId] = true

		local payload: { [string?]: { string | boolean? } } = {}

		for name, remote in Remote :: any do
			if name == script then
				continue
			end

			local unreliable = if remote._remote == UNRELIABLE then true else nil
			payload[remote._id] = { name, unreliable }
		end

		EVENT:FireClient(player, script, payload)
	end

	Players.PlayerRemoving:Connect(function(player)
		loaded[player.UserId] = nil
	end)

	idToRemote[script] = {
		_signal = {
			Fire = function(self, player: Player)
				syncPayload(player)
			end,
		},
	} :: any

	local function handleEvent(player: Player, id: string, ...)
		local remote = idToRemote[id]
		if remote then
			remote._signal:Fire(player, ...)
		end
	end

	EVENT.OnServerEvent:Connect(handleEvent)
	UNRELIABLE.OnServerEvent:Connect(handleEvent)
	FUNCTION.OnServerInvoke = function(player, id: Instance | string, ...)
		local remote = idToRemote[id]
		if remote and remote.OnInvoke then
			return remote.OnInvoke(player, ...)
		end
	end

	EVENT:SetAttribute("ServerReady", true)
else -- Client
	function RemoteObject.Fire(self: Remote, ...)
		if self._id then
			(self._remote :: any):FireServer(self._id, ...)
		else
			if not self._fireQueue then
				self._fireQueue = {}
			end
			table.insert(self._fireQueue :: any, { ... })
		end
	end

	function RemoteObject.Invoke(self: Remote, ...): ...any
		if self._id then
			return FUNCTION:InvokeServer(self._id, ...)
		else
			if not self._invokeQueue then
				self._invokeQueue = {}
			end
			table.insert(self._invokeQueue :: any, { coroutine.running(), ... :: any })

			return coroutine.yield()
		end
	end

	setmetatable(Remote, {
		__index = function(_, key: string)
			local new = newRemote(key)

			task.delay(5, function()
				if not new._id then
					warn(`Infinite yield possible on Remote '{key}'`)
				end
			end)

			return new
		end,
	})

	local function flushQueue(remote: Remote)
		if remote._fireQueue then
			for _, args in remote._fireQueue do
				EVENT:FireServer(remote._id, unpack(args))
			end
			remote._fireQueue = nil
		end

		if remote._invokeQueue then
			for _, args in remote._invokeQueue do
				local thread = args[1]
				task.spawn(function()
					local results =
						{ pcall(function()
							return FUNCTION:InvokeServer(remote._id, unpack(args, 2))
						end) }
					if coroutine.status(thread) == "suspended" then
						if results[1] then
							task.spawn(thread, unpack(results, 2))
						else
							warn("Error invoking remote function:", results[2])
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

	idToRemote[script] = {
		_signal = {
			Fire = function(self, arg1, arg2)
				-- New Event: (string Name, string ID)
				if type(arg1) == "string" then
					linkId(arg1, arg2)

				-- Reliability Change: (boolean State, string ID)
				elseif type(arg1) == "boolean" then
					local remote = idToRemote[arg2]
					if remote then
						remote:SetUnreliable(arg1)
					end

				-- Initial Sync: { [string ID]: {string Name, boolean? Unreliable} }
				elseif type(arg1) == "table" then
					for id, data in arg1 do
						linkId(data[1], id, data[2])
					end
				end
			end,
		},
	} :: any

	local function handleEvent(id: string, ...)
		local remote = idToRemote[id]
		if remote then
			remote._signal:Fire(...)
		end
	end

	EVENT.OnClientEvent:Connect(handleEvent)
	UNRELIABLE.OnClientEvent:Connect(handleEvent)
	FUNCTION.OnClientInvoke = function(id: Instance | string, ...)
		local remote = idToRemote[id]
		if remote and remote.OnInvoke then
			return remote.OnInvoke(...)
		end
	end

	if not EVENT:GetAttribute("ServerReady") then
		EVENT:GetAttributeChangedSignal("ServerReady"):Wait()
	end

	EVENT:FireServer(script)
end

return Remote
