local Data = require(script.Parent.Parent:WaitForChild("Defaults"))

local function convertFont(font: Enum.Font | Font | string)
	return if type(font) == "string"
		then Font.new(font)
		elseif typeof(font) == "EnumItem" then Font.fromEnum(font)
		else font
end

local MIGRATE = {
	defaultTheme = "theme",
	gameHubEnabled = "addToCharts",
	themeFont = convertFont,
	themeFontMono = convertFont,
}

return function(settings)
	for key, value in MIGRATE do
		if settings[key] then
			if type(value) == "function" then
				settings[key] = value(settings[key])
			elseif type(value) == "string" then
				settings[value] = settings[key]
				settings[key] = nil
				Data.Sync.settings[key] = Data.REMOVE
			end
		end
	end
end
