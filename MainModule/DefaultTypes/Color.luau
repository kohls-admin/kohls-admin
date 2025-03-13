local _K

local COLORS = {
	["0,0,0"] = Color3.new(0, 0, 0),
	["255,255,255"] = Color3.new(1, 1, 1),
	["#000"] = Color3.new(0, 0, 0),
	["#fff"] = Color3.new(1, 1, 1),

	red = Color3.new(1, 0, 0),
	orange = Color3.new(1, 0.5, 0),
	yellow = Color3.new(1, 1, 0),
	yellowgreen = Color3.new(0.5, 1, 0),
	green = Color3.new(0, 1, 0),
	aqua = Color3.new(0, 1, 1),
	blue = Color3.new(0, 0, 1),
	purple = Color3.new(0.5, 0, 1),
	pink = Color3.new(1, 0, 1),
	magenta = Color3.new(1, 0, 0.5),
        brown = Color3.new(0.6, 0.3, 0),

	white = Color3.new(1, 1, 1),
	black = Color3.new(0, 0, 0),
	gray = Color3.new(0.5, 0.5, 0.5),
}

local colorNames = {}
for name in COLORS do
	table.insert(colorNames, name)
end
table.sort(colorNames)

local typeColor = {
	transform = function(input: string)
		input = _K.Util.String.trim(input)
		if COLORS[input] then
			return COLORS[input]
		end
		if string.find(input, "^#") then
			if #input > 7 or string.find(input, "[^#a-fA-F%d]") then
				return nil -- invalid hex input
			end
			if #input < 4 then
				input ..= string.rep("f", 4 - #input)
			elseif #input > 4 then
				input ..= string.rep("f", 7 - #input)
			end
			return Color3.fromHex(input)
		else
			local r, g, b = string.match(input, "^(%d*),?(%d*),?(%d*)$")
			return Color3.fromRGB(r or 255, g or 255, b or 255)
		end
	end,

	validate = function(color: Color3?): (boolean, string?)
		if typeof(color) == "Color3" then
			return true
		end
		return false, "Invalid Color3."
	end,

	parse = function(color: Color3): Color3
		return color
	end,

	suggestions = function(text: string)
		local names = table.clone(colorNames)

		if string.find(text, "^#") then
			if #text < 4 then
				table.insert(names, text .. string.rep("f", 4 - #text))
			end
			if #text < 7 then
				table.insert(names, text .. string.rep("f", 7 - #text))
			end
		elseif text ~= "" then
			local r, g, b = string.match(text, "^(%d*),?(%d*),?(%d*)$")
			table.insert(names, `{r or 255},{g or 255},{b or 255}`)
		end

		return _K.Util.Suggest.query(text, names, COLORS)
	end,
}

return function(context)
	_K = context
	_K.Registry.registerType("color", typeColor)
end
