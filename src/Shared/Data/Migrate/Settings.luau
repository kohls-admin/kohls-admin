local Data = require(script.Parent.Parent:WaitForChild("Defaults"))

local function convertFont(font: Enum.Font | Font | string)
	return if type(font) == "string"
		then Font.new(font)
		elseif typeof(font) == "EnumItem" then Font.fromEnum(font)
		else font
end

local function never()
	return false
end

local function migrateSplitKey(splitKey: string)
	return if splitKey == "%s" then " " else splitKey
end

local MIGRATE = {
	defaultTheme = "theme",
	gameHubEnabled = "addToCharts",
	-- chat text is never logged, platform-integrated chat hides it from scripts
	saveChatLogs = never,
	splitKey = migrateSplitKey,
	themeFont = convertFont,
	themeFontMono = convertFont,
}

return function(settings)
	for key, value in MIGRATE do
		if settings[key] ~= nil then
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
