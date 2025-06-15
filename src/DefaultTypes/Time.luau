local TIME_PATTERN = "(%d+%.?%d*)%s*(%a+)"

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

local defaultSuggestions = { { "0", "0 Session" }, { "-1", "-1 Forever" } }
for i, value in suggestedUnits do
	local capitalized = if #value > 2 then string.upper(string.sub(value, 1, 1)) .. string.sub(value, 2) else value
	defaultSuggestions[i + 2] = { "1" .. value, "1 " .. capitalized }
	if #value > 1 then
		pluralUnits[i + 2] = value .. "s"
	end
end

return function(_K)
	local function parseTime(input: string): (boolean, string | number)
		if input == "" then
			return true, 1
		elseif string.find("-1", input, 1, true) then
			return true, -1
		end

		if tonumber(input) then
			-- no units specified, default to seconds?
			return true, tonumber(input) :: number
		end
		if string.find(input, TIME_PATTERN) == nil then
			return false, "Invalid time format"
		end

		local seconds = 0
		for amount, unit in string.gmatch(string.lower(input), TIME_PATTERN) do
			local duration: number? = _K.Util.UnitTime(unit)
			if duration == nil then
				return false, "Invalid time format"
			else
				seconds += amount * duration
			end
		end

		return true, seconds
	end
	_K.Registry.registerType("timeSimple", {
		filterLog = true,
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
				local names = { { "0", "0 Session" }, { "-1", "-1 Forever" } }
				if number > 0 then
					local original = if number > 1 then pluralUnits else suggestedUnits
					for i, value in original do
						local capitalized = if #value > 2
							then string.upper(string.sub(value, 1, 1)) .. string.sub(value, 2)
							else value
						names[i + 1] = {
							number .. value,
							number .. " " .. capitalized,
						}
					end
				end
				return names
			else
				return defaultSuggestions
			end
		end,
	})
end
