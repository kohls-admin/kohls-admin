--[[
Retries a function with exponential backoff until it succeeds or exceeds the maximum number of attempts.
@param callback -- The function to retry
@param attempts -- Number of retry attempts (Default: 5)
@param base -- Backoff delay exponent base, adds a delay of `base ^ attempts` between attempts, capped at 60 seconds (Default: 2)
@param ... -- Additional arguments to pass to the callback function
@return -- Whether the pcall succeeded, followed by its results
]]
local MAX_DELAY = 60

local function Retry(callback: (...any) -> any | nil, attempts: number?, base: number?, ...: any?): (boolean, any)
	attempts = attempts or 5
	base = base or 2

	for attempt = 1, attempts :: number do
		local results = { pcall(callback, ...) }
		if results[1] or attempt == attempts then
			return unpack(results)
		end
		-- uncapped, endless retries (attempts = math.huge) would wait hours between tries during an outage
		task.wait(math.min(base :: number ^ attempt, MAX_DELAY))
	end

	return false
end

return Retry
