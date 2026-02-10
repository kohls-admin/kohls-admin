local Function = {}

function Function.debounce(delay: number, func: (...any) -> ...any)
	local thread
	return function(...)
		if typeof(thread) == "thread" and coroutine.status(thread) == "suspended" then
			task.cancel(thread)
		end
		thread = task.delay(delay, func, ...)
	end
end

function Function.throttle(delay: number, func: (...any) -> ...any)
	local thread, throttled
	local function trailing(...)
		throttled = tick() + delay
		func(...)
	end

	return function(...)
		local now = tick()

		if typeof(thread) == "thread" and coroutine.status(thread) == "suspended" then
			task.cancel(thread)
			thread = nil
		end

		if throttled and now < throttled then
			thread = task.delay(throttled - now, trailing, ...)
			return
		end

		throttled = now + delay
		func(...)
	end
end

return Function
