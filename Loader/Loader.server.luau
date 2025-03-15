if not shared._K_LOADER_LOADED then
	shared._K_LOADER_LOADED = true

	local Package = script.Parent
	Package.Parent = game:GetService("ServerScriptService")

	local AddonsFolder = Package:WaitForChild("Addons")
	local SettingsModule = Package:WaitForChild("Settings")
	local Settings = require(SettingsModule)

	local module = if Settings.autoUpdate and game.PlaceId ~= 2569622788 then 1868400649 else Package.MainModule
	require(module).initialize(SettingsModule, AddonsFolder, true)
end
