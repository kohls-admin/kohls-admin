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
	cyan = Color3.new(0, 1, 1),
	blue = Color3.new(0, 0, 1),
	purple = Color3.new(0.5, 0, 1),
	violet = Color3.new(0.5, 0, 1),
	pink = Color3.new(1, 0, 1),
	magenta = Color3.new(1, 0, 0.5),

	white = Color3.new(1, 1, 1),
	black = Color3.new(0, 0, 0),
	grey = Color3.new(0.5, 0.5, 0.5),
	gray = Color3.new(0.5, 0.5, 0.5),
}

local invalidColorId = BrickColor.new(-1).Number
for i = 1, 1032 do
	local color = BrickColor.new(i)
	if i ~= invalidColorId and color.Number == invalidColorId then
		continue
	end
	local name = string.lower(color.Name)
	if COLORS[name] then
		continue
	end
	COLORS[tostring(i)] = color.Color
	COLORS[name] = color.Color
end

local colorNames = {}
for name in COLORS do
	table.insert(colorNames, name)
end
table.sort(colorNames)

COLORS.random = Color3.new(math.random(), math.random(), math.random())
table.insert(colorNames, 1, "random")

local typeColor = {
	transform = function(input: string)
		if input == "" then
			return ""
		end
		input = _K.Util.String.trim(string.lower(input))
		if COLORS[input] then
			if input == "random" then
				return Color3.new(math.random(), math.random(), math.random())
			end
			return COLORS[input]
		end
		if string.find(input, "^#") then
			if #input > 7 or string.find(input, "[^#a-f%d]") then
				return nil -- invalid hex input
			end
			if #input < 4 then
				input ..= string.rep("f", 4 - #input)
			elseif #input > 4 then
				input ..= string.rep("f", 7 - #input)
			end
			return Color3.fromHex(input)
		else
			local r, g, b = string.match(input, "^(%d+),?(%d*),?(%d*)$")
			if r then
				local validRGB = true
				for _, channel in { r, g, b } do
					local value = tonumber(channel)
					if value and (#channel > 3 or value < 0 or value > 255) then
						validRGB = false
						break
					end
				end
				if validRGB then
					return Color3.fromRGB(r or 255, g or 255, b or 255)
				end
			end
			for name, color in COLORS do -- partial match
				if string.find(name, input, 1, true) == 1 then
					return color
				end
			end
		end
		return nil, "Invalid Color"
	end,

	validate = function(color: Color3?): (boolean, string?)
		if typeof(color) == "Color3" then
			return true
		end
		return false, "Invalid Color3"
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
			if string.find("random", string.lower(text), 1, true) == 1 then
				COLORS.random = Color3.new(math.random(), math.random(), math.random())
			end
			local r, g, b = string.match(text, "^(%d+),?(%d*),?(%d*)$")
			table.insert(names, `{r or 255},{g or 255},{b or 255}`)
		end

		return names, COLORS
	end,
}

return function(context)
	_K = context
	_K.Registry.registerType("color", typeColor)
end
