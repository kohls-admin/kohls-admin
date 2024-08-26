--[[ Retries a function with exponential backoff
@param callback: () -> any | nil -- The function to retry
@param maxAttempts: number -- Maximum number of retry attempts
@param initialDelay: number -- Initial delay in seconds before first retry
@param backoffBase: number? -- Backoff delay exponent base, adds a delay of `base ^ (attempts - 1)` to the initial delay
@return (boolean, any) -- Returns the result of the pcall callback execution
]]
local function Retry(
	callback: () -> any | nil,
	maxAttempts: number,
	initialDelay: number,
	backoffBase: number?
): (boolean, any)
	local backoff = backoffBase or 0
	local feedback

	for attempt = 0, maxAttempts - 1 do
		local success, result = pcall(callback)

		if success then
			return success, result
		elseif not feedback then
			feedback = result
		end

		if attempt < maxAttempts then
			task.wait(initialDelay + (backoff ^ attempt))
		end
	end

	return false, `Max retry attempts reached: {feedback}`
end

return Retry
