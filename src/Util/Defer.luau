local defaultBudget, expireTime = 1 / 240, 0

local Defer = {}

-- Call at start of process to prevent unnecessarily waiting.
function Defer.reset(budget: number?)
	expireTime = tick() + (defaultBudget or budget)
end

function Defer.wait(budget: number?)
	if tick() >= expireTime then
		task.wait()
		Defer.reset(budget)
	end
end

return Defer
