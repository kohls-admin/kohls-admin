local Function = {}

function Function.debounce(delay: number, func: (...any) -> ...any)
	local thread
	return function(...)
		if thread then
			pcall(task.cancel, thread)
			thread = nil
		end
		thread = task.delay(delay, func, ...)
	end
end

function Function.throttle(delay: number, func: (...any) -> ...any)
	local thread, throttled
	local function reset()
		throttled = nil
	end
	return function(...)
		if thread then
			pcall(task.cancel, thread)
			thread = nil
		end
		if throttled then
			thread = task.delay(throttled - tick(), func, ...)
			return
		end
		throttled = tick() + delay
		task.delay(delay, reset)
		func(...)
	end
end

return Function
