local Time = {
	UNITS = table.freeze({
		{ 1 / 1000, "millisecond" },
		{ 1, "second" },
		{ 60, "minute" },
		{ 60 * 60, "hour", "hr" },
		{ 60 * 60 * 24, "day" },
		{ 60 * 60 * 24 * 7, "week", "wk" },
		{ 60 * 60 * 24 * 30, "month" },
		{ 60 * 60 * 24 * 365.25, "year", "yr" },
	}),
}
Time.__index = Time

function Time.fromUnit(unit: string): number?
	unit = string.lower(unit)
	if unit == "m" then
		return 60
	elseif unit == "mss" then
		return 1 / 1000
	end
	if #unit > 1 and string.find(unit, "s$") then
		unit = string.sub(unit, 1, -2)
	end
	for _, list in Time.UNITS do
		for i = 2, #list do
			if string.find(list[i], unit) == 1 then
				-- match found, return duration in seconds
				return list[1]
			end
		end
	end
	return
end

function Time.readable(seconds: number): string
	local buffer = {}
	for index = #Time.UNITS, 2, -1 do
		local definition = Time.UNITS[index]
		local unitDuration, unitName = unpack(definition)
		local unitAmount = math.floor(seconds / unitDuration)
		if unitAmount > 0 then
			seconds = seconds % unitDuration
			local plural = if unitAmount > 1 then "s" else ""
			table.insert(buffer, string.format("%s %s%s", unitAmount, unitName, plural))
		end
	end
	return table.concat(buffer, ", ")
end

return Time
