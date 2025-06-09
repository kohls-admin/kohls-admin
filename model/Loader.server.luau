local Package = script.Parent

local DEMO_PLACE = 2569622788
local MAIN_MODULE_ID = 1868400649
local MAIN_MODULE_NAME = "MainModule"

local AUTO_UPDATE = true
local LEGACY = false

local CONFIG = Package:FindFirstChild("Config")
if CONFIG then
	AUTO_UPDATE = CONFIG:GetAttribute("AutoUpdate")
	LEGACY = CONFIG:GetAttribute("Legacy")
end

if (LEGACY and not _G.KAU) or not shared._K_LOADER_LOADED then
	local legacyConfig = CONFIG:FindFirstChild("Legacy")

	if LEGACY then
		_G.KAU = true
		MAIN_MODULE_NAME = "MainModuleLegacy"
		for _, child in legacyConfig:GetChildren() do
			child.Parent = script
		end
		script.Name = "Kohl's Admin Infinite"
		script.Parent = game:GetService("ServerScriptService")
	else
		shared._K_LOADER_LOADED = true
		Package.Parent = game:GetService("ServerScriptService")
	end
	AUTO_UPDATE = AUTO_UPDATE and game.PlaceId ~= DEMO_PLACE

	local localMainModule = script:FindFirstChild(MAIN_MODULE_NAME) or MAIN_MODULE_ID
	local ok, result = pcall(require, if AUTO_UPDATE then MAIN_MODULE_ID else localMainModule)

	if not ok then
		if AUTO_UPDATE then
			local function loadModuleAsset(assetId: number)
				local asset = game:GetService("InsertService"):LoadAsset(assetId)
				local module = asset:FindFirstChild("MainModule", true)
				if module then
					return assert(require(module), ":LoadAsset() module returned invalid values!")
				end
				error(`Failed to find the source for {assetId}.`)
			end

			warn("Kohl's Admin failed to auto-update from MainModule, trying to load from asset\nReason:\t" .. result)
			ok, result = pcall(loadModuleAsset, 172732271)
			if not ok then
				warn("Kohl's Admin failed to auto-update from asset, loading from local package\nReason:\t" .. result)
				result = require(localMainModule)
			end
		else
			warn("Kohl's Admin failed to load from local package\nReason:\t" .. result)
		end
	end

	if not LEGACY then
		result.initialize(CONFIG)
	end
end
