local Data = require(script.Parent.Parent.Defaults)

local MIGRATE = {
	defaultTheme = "theme",
}

return function(settings)
	for key, value in MIGRATE do
		if settings[key] then
			if type(value) == "function" then
				value(settings, key)
			elseif type(value) == "string" then
				settings[value] = settings[key]
				settings[key] = nil
				Data.Cache.settings[key] = Data.REMOVE
			end
		end
	end
end
