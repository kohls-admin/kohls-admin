local defaultBudget, expireTime = 1 / 240, 0

local Defer = {}

-- Call at start of process to prevent unnecessarily waiting.
function Defer.reset(budget: number?)
	expireTime = os.clock() + (budget or defaultBudget)
end

function Defer.wait(budget: number?)
	if os.clock() >= expireTime then
		task.wait()
		Defer.reset(budget)
	end
end

return Defer
