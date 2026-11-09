local InsertService = game:GetService("InsertService")

local Package = script.Parent

local DEMO_PLACE = 2569622788
local MAIN_MODULE_ID = 1868400649
local MAIN_MODULE_NAME = "MainModule"

local AUTO_UPDATE = true
local LEGACY = false

local CONFIG = Package:FindFirstChild("Config")
local ADDONS = Package:FindFirstChild("Addons")
if CONFIG then
	local autoUpdate = CONFIG:GetAttribute("AutoUpdate")
	if autoUpdate ~= nil then
		AUTO_UPDATE = autoUpdate
	end
	local legacy = CONFIG:GetAttribute("Legacy")
	if legacy ~= nil then
		LEGACY = legacy
	else
		local legacyValue = CONFIG:FindFirstChild("Legacy")
		if legacyValue and legacyValue:IsA("ValueBase") then
			LEGACY = (legacyValue :: any).Value == true
		end
	end
end

do
	local ok, err = pcall(function()
		return script.Sandboxed
	end)
	if not ok and type(err) == "string" and string.find(err, "lacking capability") then
		error([[


[KOHL'S ADMIN PERMISSIONS FIX]

Select the Kohl's Admin folder in the Explorer and run this script in the command bar:

local obj = game.Selection:Get()[1]
for _, v in obj:GetDescendants() do v.Sandboxed = false end
while obj and obj ~= game do obj.Sandboxed = false obj = obj.Parent end

]])
	end
end

if not _G.KAU and not shared._K_LOADER_LOADED then
	_G.KAU = true
	shared._K_LOADER_LOADED = true
	shared._K_MODERN_LOADER = not LEGACY

	local legacyConfig = CONFIG and CONFIG:FindFirstChild("Legacy")

	if LEGACY then
		MAIN_MODULE_NAME = "MainModuleLegacy"
		if legacyConfig then
			for _, child in legacyConfig:GetChildren() do
				child.Parent = script
			end
		end
		script.Name = "Kohl's Admin Infinite"
		script.Parent = game:GetService("ServerScriptService")
	else
		Package.Parent = game:GetService("ServerScriptService")
	end
	AUTO_UPDATE = AUTO_UPDATE and game.PlaceId ~= DEMO_PLACE

	local localMainModule = script:FindFirstChild(MAIN_MODULE_NAME) or MAIN_MODULE_ID
	local localTools = script:FindFirstChild("Tools") or Package:FindFirstChild("Tools", true)

	if typeof(localMainModule) == "Instance" and localTools then
		local targetParent = localMainModule:FindFirstChild("Server") or localMainModule
		if not targetParent:FindFirstChild("Tools") then
			(if AUTO_UPDATE then localTools:Clone() else localTools).Parent = targetParent
		end
	end

	local ok, result = pcall(require, if AUTO_UPDATE then MAIN_MODULE_ID else localMainModule)

	if not ok then
		if AUTO_UPDATE then
			local function loadModuleAsset(assetId: number)
				local asset = InsertService:LoadAsset(assetId)
				local module = asset:FindFirstChild(MAIN_MODULE_NAME, true) or asset:FindFirstChild("MainModule", true)
				if module then
					if not LEGACY then
						local serverFolder = module:FindFirstChild("Server")
						if serverFolder and not serverFolder:FindFirstChild("Tools") then
							local tools = asset:FindFirstChild("Tools", true)
								or script:FindFirstChild("Tools")
								or Package:FindFirstChild("Tools", true)
							if tools then
								tools:Clone().Parent = serverFolder
							end
						end
					end
					return assert(require(module), ":LoadAsset() module returned invalid values!")
				end
				error(`Failed to find the source for {assetId}.`)
			end

			warn(
				"Kohl's Admin failed to auto-update from MainModule, trying to load from asset\nReason:\t"
					.. tostring(result)
			)
			ok, result = pcall(loadModuleAsset, 172732271)
			if not ok then
				warn(
					"Kohl's Admin failed to auto-update from asset, loading from local package\nReason:\t"
						.. tostring(result)
				)
				ok, result = pcall(require, localMainModule)
				if not ok then
					error(result)
				end
			end
		else
			warn("Kohl's Admin failed to load from local package\nReason:\t" .. tostring(result))
		end
	end

	if not LEGACY and ok and type(result) == "table" and type(result.initialize) == "function" then
		result.initialize(CONFIG, ADDONS)
	end
else
	warn(`Multiple Kohl's Admin models detected; removing duplicate at {Package:GetFullName()}`)
	Package:Destroy()
end
