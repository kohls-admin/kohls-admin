local TIME_PATTERN = "(%d+%.?%d*)%s*(%a+)"
local TIME_UNITS = {
	{ 1, "second" },
	{ 60, "minute" },
	{ 60 * 60, "hour", "hr" },
	{ 60 * 60 * 24, "day" },
	{ 60 * 60 * 24 * 7, "week", "wk" },
	{ 60 * 60 * 24 * 30, "month" },
	{ 60 * 60 * 24 * 365, "year", "yr" },
	{ 1 / 1000, "millisecond" },
}

function unitDuration(unit: string): number?
	-- special case to return millisecond duration if unit is "ms(s)"
	-- prevents "ms" from defaulting to minutes, other solutions are nasty
	if unit == "ms" or unit == "mss" then
		return 1 / 1000
	end
	-- strip trailing "s"
	if #unit > 1 and string.find(unit, "s$") then
		unit = string.sub(unit, 1, -2)
	end
	for _, list in TIME_UNITS do
		for i = 2, #list do
			if string.find(list[i], unit) == 1 then
				-- match found, return duration in seconds
				return list[1]
			end
		end
	end
	return
end

function parseTime(input: string): (boolean, string | number)
	if string.find(input, TIME_PATTERN) == nil then
		return false, "Invalid time format."
	end

	local seconds = 0
	for amount, unit in string.gmatch(string.lower(input), TIME_PATTERN) do
		local duration: number? = unitDuration(unit)
		if duration == nil then
			return false, "Invalid time format."
		else
			seconds += amount * duration
		end
	end

	return true, seconds
end

return function(_K)
	_K.Registry.registerType("timeSimple", {
		transform = function(v: string)
			local ok, result = parseTime(v)
			return if ok then result else false, result
		end,
		validate = function(v)
			return v
		end,
		parse = function(v)
			return v
		end,
	})
end
