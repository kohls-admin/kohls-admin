--[[
Retries a function with exponential backoff until it succeeds or exceeds the maximum number of attempts.
@param callback: () -> any | nil -- The function to retry
@param attempts: number -- Number of retry attempts (Default: 5)
@param base: number? -- Backoff delay exponent base, adds a delay of `base ^ attempts` between attempts (Default: 2)
@param ...: any? -- Additional arguments to pass to the callback function
@return (boolean, any) -- Returns the result of the pcall callback execution
]]
local function Retry(callback: () -> any | nil, attempts: number?, base: number?, ...: any?): (boolean, any)
	attempts = attempts or 5
	base = base or 2

	for attempt = 1, attempts :: number do
		local results = { pcall(callback, ...) }
		if results[1] or attempt == attempts then
			return unpack(results)
		end
		task.wait(base :: number ^ attempt)
	end

	return false
end

return Retry
