if not shared._K_LOADER_LOADED then
	shared._K_LOADER_LOADED = true

	local Package = script.Parent["Kohl's Admin"]
	Package.Parent = game:GetService("ServerScriptService")

	local AddonsFolder = Package:WaitForChild("Addons")
	local SettingsModule = Package:WaitForChild("Settings")
	local Settings = require(SettingsModule)

	local module = script.Parent.MainModule
	require(module).initialize(SettingsModule, AddonsFolder, true)
end
