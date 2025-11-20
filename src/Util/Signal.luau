--!strict
--!native
--!optimize 2

--- @class Signal
--- A performant, connection pooled, type-safe, linked-list implementation of the Observer pattern.

type Function = (...any) -> ()

export type Connection = {
	Connected: boolean?,
	Disconnect: (self: Connection) -> (),
	_signal: Signal?,
	_next: Connection?,
	_prev: Connection?,
	_callback: Function?,
}

export type Signal = {
	Connect: (self: Signal, callback: Function) -> Connection,
	Once: (self: Signal, callback: Function) -> Connection,
	Fire: (self: Signal, ...any) -> (),
	Wait: (self: Signal) -> ...any,
	Destroy: (self: Signal) -> (),
	_head: Connection?,
}

local freeConnections = {}

local Connection = {}
Connection.__index = Connection

function Connection.new(signal: Signal, callback: Function): Connection
	local self
	if #freeConnections > 0 then
		self = table.remove(freeConnections) :: Connection
		self.Connected = true
		self._signal = signal
		self._callback = callback
		self._next = nil
		self._prev = nil
	else
		self = setmetatable({
			Connected = true,
			_signal = signal,
			_callback = callback,
			_next = nil,
			_prev = nil,
		}, Connection) :: any
	end

	return self
end

function Connection:Disconnect()
	if not self.Connected then
		return
	end
	self.Connected = false

	local nextConn = self._next
	local prevConn = self._prev

	if nextConn then
		nextConn._prev = prevConn
	end

	if prevConn then
		prevConn._next = nextConn
	elseif self._signal then
		self._signal._head = nextConn
	end

	table.clear(self)
	table.insert(freeConnections, self)
end

local Signal = {}
Signal.__index = Signal

function Signal.new(): Signal
	return setmetatable({}, Signal) :: any
end

function Signal:Connect(callback: Function): Connection
	local connection = Connection.new(self, callback)
	if self._head then
		connection._next = self._head
		self._head._prev = connection
	end
	self._head = connection
	return connection
end

function Signal:Once(callback: Function): Connection
	local connection
	connection = self:Connect(function(...)
		if connection.Connected then
			connection:Disconnect()
		end
		callback(...)
	end)
	return connection
end

function Signal:Fire(...)
	local item = self._head
	while item do
		local nextItem = item._next
		if item.Connected then
			task.spawn(item._callback, ...)
		end
		item = nextItem
	end
end

function Signal:Wait(): ...any
	local running = coroutine.running()
	local connection
	connection = self:Connect(function(...)
		connection:Disconnect()
		task.spawn(running, ...)
	end)
	return coroutine.yield()
end

function Signal:Destroy()
	local item = self._head
	while item do
		local nextItem = item._next
		if item.Connected then
			table.clear(item)
			table.insert(freeConnections, item)
		end
		item = nextItem
	end
	table.clear(self)
end

return Signal
