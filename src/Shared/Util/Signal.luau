--!strict
--!optimize 2

--- @class Signal
--- A performant, doubly linked-list implementation of the Observer pattern.

type Function = (...any) -> ()

export type Connection = {
	Connected: boolean?,
	Disconnect: (self: Connection) -> (),
	_signal: Signal?,
	_next: Connection?,
	_prev: Connection?,
	_callback: Function?,
	_thread: thread?,
}

export type Signal = {
	Connect: (self: Signal, callback: Function) -> Connection,
	Once: (self: Signal, callback: Function) -> Connection,
	Fire: (self: Signal, ...any) -> (),
	Wait: (self: Signal) -> ...any,
	Destroy: (self: Signal) -> (),
	_head: Connection?,
}

local Connection = {}
Connection.__index = Connection

function Connection.new(signal: Signal, callback: Function): Connection
	return (
		setmetatable({
			Connected = true,
			_signal = signal,
			_callback = callback,
			_next = nil,
			_prev = nil,
		}, Connection) :: unknown
	) :: Connection
end

function Connection.Disconnect(self: Connection)
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
	self._callback = nil
	self._signal = nil
	self._prev = nil
	-- _next is preserved so the firing loop can continue if disconnected during dispatch
end

local Signal = {}
Signal.__index = Signal

function Signal.new(): Signal
	return (setmetatable({}, Signal) :: unknown) :: Signal
end

function Signal.Connect(self: Signal, callback: Function): Connection
	local connection = Connection.new(self, callback)
	if self._head then
		connection._next = self._head
		self._head._prev = connection
	end
	self._head = connection
	return connection
end

function Signal.Once(self: Signal, callback: Function): Connection
	local connection: Connection
	connection = self:Connect(function(...)
		if connection.Connected then
			connection:Disconnect()
		end
		callback(...)
	end)
	return connection
end

function Signal.Fire(self: Signal, ...: any)
	local item = self._head
	while item do
		local nextItem = item._next
		local callback = item._callback
		if item.Connected and callback then
			task.spawn(callback, ...)
		else -- Disconnected
			item.Connected = nil
			item._next = nil
		end
		item = nextItem
	end
end

function Signal.Wait(self: Signal): ...any
	local thread = coroutine.running()
	local connection: Connection
	connection = self:Connect(function(...)
		connection:Disconnect()
		connection._thread = nil
		if coroutine.status(thread) == "suspended" then
			task.spawn(thread, ...)
		end
	end)
	connection._thread = thread
	return coroutine.yield()
end

function Signal.Destroy(self: Signal)
	local item = self._head
	while item do
		local nextItem = item._next
		if item.Connected then
			if typeof(item._thread) == "thread" and coroutine.status(item._thread) == "suspended" then
				task.cancel(item._thread)
			end
			table.clear(item :: { [any]: any })
		end
		item = nextItem
	end
	table.clear(self :: { [any]: any })
end

return Signal
