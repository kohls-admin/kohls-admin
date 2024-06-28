--------------------------------------------------------------------------------
--                           Fast Signal-like class                           --
-- This is a Signal class that is implemented in the most performant way      --
-- possible, sacrificing correctness. The event handlers will be called       --
-- directly, so it is not safe to yield in them, and it is also not safe to   --
-- connect new handlers in the middle of a handler (though it is still safe   --
-- for a handler to specifically disconnect itself)                           --
--------------------------------------------------------------------------------

local Signal = {}
Signal.__index = Signal

local Connection = {}
Connection.__index = Connection

function Connection.new(signal, handler)
	return setmetatable({
		_handler = handler,
		_signal = signal,
	}, Connection)
end

function Connection:Disconnect()
	self._signal[self] = nil
end

function Signal.new()
	return setmetatable({}, Signal)
end

function Signal:Connect(fn)
	local connection = Connection.new(self, fn)
	self[connection] = true
	return connection
end

function Signal:DisconnectAll()
	table.clear(self)
end

function Signal:Fire(...)
	if next(self) then
		for handler, _ in self do
			handler._handler(...)
		end
	end
end

function Signal:Wait()
	local waitingCoroutine = coroutine.running()
	local cn
	cn = self:Connect(function(...)
		cn:Disconnect()
		task.spawn(waitingCoroutine, ...)
	end)
	return coroutine.yield()
end

function Signal:Once(fn)
	local cn
	cn = self:Connect(function(...)
		cn:Disconnect()
		fn(...)
	end)
	return cn
end

return Signal
