if not shared._K_LOADER_LOADED then
	shared._K_LOADER_LOADED = true

	local Package = script.Parent
	Package.Parent = game:GetService("ServerScriptService")

	local AddonsFolder = Package:WaitForChild("Addons")
	local SettingsModule = Package:WaitForChild("Settings")
	local Settings = require(SettingsModule)

	local function loadModuleAsset(assetId: number)
		local asset = game:GetService("InsertService"):LoadAsset(assetId)
		local module = asset:FindFirstChild("MainModule", true)
		if module then
			return assert(require(module), ":LoadAsset() module returned invalid values!")
		end
		error(`Failed to find the source for {assetId}.`)
	end

	local loaderId = 172732271
	local autoUpdate = Settings.autoUpdate and game.PlaceId ~= 2569622788
	local moduleId = if autoUpdate then 1868400649 else Package.MainModule
	local ok, result = pcall(require, moduleId)
	if not ok and autoUpdate then
		warn("Kohl's Admin failed to auto-update from MainModule, attempting to load from asset\nReason:\t" .. result)
		ok, result = pcall(loadModuleAsset, loaderId)
		if not ok then
			warn("Kohl's Admin failed to auto-update from asset, attempting to load from local package\nReason:\t" .. result)
			result = require(Package.MainModule)
		end
	end
	result.initialize(SettingsModule, AddonsFolder, true)
end
