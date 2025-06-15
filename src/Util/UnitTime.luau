local TIME_UNITS = {
	{ 1, "second" },
	{ 60, "minute" },
	{ 60 * 60, "hour", "hr" },
	{ 60 * 60 * 24, "day" },
	{ 60 * 60 * 24 * 7, "week", "wk" },
	{ 60 * 60 * 24 * 30, "month" },
	{ 60 * 60 * 24 * 365.25, "year", "yr" },
	{ 1 / 1000, "millisecond" },
}

local function UnitTime(unit: string): number?
	unit = string.lower(unit)
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

return UnitTime
