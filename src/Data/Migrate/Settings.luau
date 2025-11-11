local Data = require(script.Parent.Parent.Defaults)

local function convertFont(font: Enum.Font | Font)
	return if typeof(font) == "EnumItem" then Font.fromEnum(font) else font
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
				value(settings, key)
			elseif type(value) == "string" then
				settings[value] = settings[key]
				settings[key] = nil
				Data.Sync.settings[key] = Data.REMOVE
			end
		end
	end
end
