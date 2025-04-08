if not shared._K_LOADER_LOADED then
	shared._K_LOADER_LOADED = true

	local Package = script.Parent
	Package.Parent = game:GetService("ServerScriptService")

	local AddonsFolder = Package:WaitForChild("Addons")
	local SettingsModule = Package:WaitForChild("Settings")
	local Settings = require(SettingsModule)

	local function loadModuleAsset(moduleId: number)
		local asset = game:GetService("InsertService"):LoadAsset(moduleId)

		if asset.Name == "MainModule" then
			return assert(require(asset), ":LoadAsset() module returned invalid values!")
		elseif asset:FindFirstChild("MainModule") then
			return assert(require(asset.MainModule), ":LoadAsset() module returned invalid values!")
		elseif asset:IsA("ModuleScript") then
			return assert(require(asset), ":LoadAsset() module returned invalid values!")
		end

		for _, v in asset:GetChildren() do
			if v:IsA("ModuleScript") then
				return assert(require(v), ":LoadAsset() module returned invalid values!")
			end
		end

		error(`Failed to find any matching ModuleScripts for {moduleId}.`)
	end

	local autoUpdate = Settings.autoUpdate and game.PlaceId ~= 2569622788
	local moduleId = if autoUpdate then 1868400649 else Package.MainModule
	local ok, result = pcall(require, moduleId)
	if not ok and autoUpdate then
		warn("Kohl's Admin failed to auto-update from MainModule, attempting to load from asset\nReason:\t" .. result)
		ok, result = pcall(loadModuleAsset, moduleId)
		if not ok then
			warn("Kohl's Admin failed to auto-update from asset, attempting to load from local package\nReason:\t" .. result)
			result = require(Package.MainModule)
		end
	end
	result.initialize(SettingsModule, AddonsFolder, true)
end
