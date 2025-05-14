if not shared._K_LOADER_LOADED then
	shared._K_LOADER_LOADED = true

	local Package = script.Parent
	Package.Parent = game:GetService("ServerScriptService")

	local Settings = require(Package:WaitForChild("Settings"))

	local autoUpdate = Settings.autoUpdate and game.PlaceId ~= 2569622788
	local ok, result = pcall(require, if autoUpdate then 1868400649 else Package.MainModule)

	if not ok and autoUpdate then
		local function loadModuleAsset(assetId: number)
			local asset = game:GetService("InsertService"):LoadAsset(assetId)
			local module = asset:FindFirstChild("MainModule", true)
			if module then
				return assert(require(module), ":LoadAsset() module returned invalid values!")
			end
			error(`Failed to find the source for {assetId}.`)
		end

		warn("Kohl's Admin failed to auto-update from MainModule, attempting to load from asset\nReason:\t" .. result)
		ok, result = pcall(loadModuleAsset, 172732271)
		if not ok then
			warn("Kohl's Admin failed to auto-update from asset, loading from local package\nReason:\t" .. result)
			result = require(Package.MainModule)
		end
	end

	result.initialize(Settings)
end
