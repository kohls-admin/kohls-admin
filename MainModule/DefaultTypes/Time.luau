local TIME_PATTERN = "(%d+%.?%d*)%s*(%a+)"
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

-- TODO suggestions, ideally 1 of each unit, or whatever number they current have + a unit

local function unitDuration(unit: string): number?
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

local function parseTime(input: string): (boolean, string | number)
	if input == "" then
		return true, ""
	elseif string.find("-1", input, 1, true) then
		return true, -1
	end

	if tonumber(input) then
		-- no units specified, default to seconds?
		return true, tonumber(input) :: number
	end
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

local suggestedUnits = {
	"second",
	"minute",
	"hour",
	"day",
	"week",
	"month",
	"year",
	"millisecond",
	"s",
	"m",
	"h",
	"d",
	"w",
	"y",
	"hr",
	"wk",
	"yr",
	"ms",
}

local pluralUnits = {}

local defaultSuggestions = {}
for i, value in suggestedUnits do
	defaultSuggestions[i] = "1" .. value
	if #value > 1 then
		pluralUnits[i] = value .. "s"
	end
end

table.insert(defaultSuggestions, { "-1", "-1 forever" })

return function(_K)
	_K.Registry.registerType("timeSimple", {
		validate = function(v)
			return parseTime(v)
		end,
		parse = function(v)
			local ok, result = parseTime(v)
			if not ok then
				error(result)
			end
			return result
		end,
		suggestions = function(text)
			local number = tonumber(string.match(text, "^%-?%d*"))
			if #text > 0 and string.find("-1", text, 1, true) == 1 then
				number = -1
			end
			if number then
				local names = { { "-1", "-1 forever" } }
				if number > 0 then
					local original = if number > 1 then pluralUnits else suggestedUnits
					for i, value in original do
						names[i + 1] = number .. value
					end
				end
				return _K.Util.Suggest.query(text, names)
			else
				return _K.Util.Suggest.query(text, defaultSuggestions)
			end
		end,
	})
end
