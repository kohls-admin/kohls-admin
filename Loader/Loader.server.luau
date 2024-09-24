if not shared._K_LOADER_LOADED then
	shared._K_LOADER_LOADED = true

	local Package = script.Parent
	local Addons = Package:WaitForChild("Addons")
	local Settings = require(Package:WaitForChild("Settings"))

	if false and Settings.autoUpdate and game.PlaceId ~= 18274376677 then
		-- auto udating will be added when the model is more stable
	else
		local _K = require(Package.MainModule)
		_K.initialize(Settings, Addons, true)
	end
end
