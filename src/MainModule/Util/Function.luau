local Function = {}

function Function.debounce(delay: number, func: (...any) -> ...any)
	local thread
	return function(...)
		if thread then
			task.cancel(thread)
		end
		thread = task.delay(delay, func, ...)
	end
end

function Function.throttle(delay: number, func: (...any) -> ...any)
	local throttled
	local function reset()
		throttled = nil
	end
	return function(...)
		if throttled then
			return
		end
		throttled = true
		task.delay(delay, reset)
		func(...)
	end
end

return Function
