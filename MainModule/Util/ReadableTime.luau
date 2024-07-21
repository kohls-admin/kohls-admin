local TIME_UNITS = {
	{ 60 * 60 * 24 * 365.25, "year" },
	{ 60 * 60 * 24, "day" },
	{ 60 * 60, "hour" },
	{ 60, "minute" },
	{ 1, "second" },
}
return function(seconds: number): string
	local buffer = {}
	for _, definition in TIME_UNITS do
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
