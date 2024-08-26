local Package = script.Parent

-- Prevents the loading of duplicates
if shared._K_LOADER then
	Package:Destroy()
else
	shared._K_LOADER = Package
	local settings = require(Package.Settings)
	--force the demo place to not auto update
	if false and settings.autoUpdate and game.PlaceId ~= 18274376677 then
		-- auto udating will be added when the model is more stable
	else
		require(Package.MainModule)
	end
end
