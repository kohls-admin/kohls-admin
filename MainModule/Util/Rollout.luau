local datePattern = "(%d%d%d%d)%-(%d%d)%-(%d%d)"

local FFlags = nil

local Rollout = {}
Rollout.__index = Rollout

function Rollout.new(start, finish, key, seed, curve)
	local startYear, startMonth, startDay = string.match(start, datePattern)
	local finishYear, finishMonth, finishDay = string.match(finish, datePattern)
	assert(startYear and startMonth and startDay, "Invalid start date format, use YYYY-MM-DD")
	assert(finishYear and finishMonth and finishDay, "Invalid finish date format, use YYYY-MM-DD")

	local startTime = os.time({ year = startYear, month = startMonth, day = startDay })
	local finishTime = os.time({ year = finishYear, month = finishMonth, day = finishDay })

	assert(finishTime > startTime, "finish date must be greater than start date")

	return setmetatable({
		key = key,
		seed = seed or 0,
		curve = curve or 1,
		start = startTime,
		duration = finishTime - startTime,
	}, Rollout)
end

function Rollout:test(id)
	if FFlags and FFlags[self.key] ~= nil then
		return FFlags[self.key]
	end
	local alpha = math.clamp(0, 1, math.max(1, (os.time() - self.start) / self.duration))
	return Random.new(id + self.seed):NextNumber() <= alpha ^ self.curve
end

function Rollout:setFFlagDictionary(dict)
	FFlags = dict
end

return Rollout
