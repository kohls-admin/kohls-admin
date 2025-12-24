local InsertService = game:GetService("InsertService")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")

local loadAssetTextureTypes = {
	Enum.AssetType.Face.Value,
	Enum.AssetType.Shirt.Value,
	Enum.AssetType.Pants.Value,
	Enum.AssetType.TShirt.Value,
}

local textureProperty = {
	Decal = "Texture",
	Shirt = "ShirtTemplate",
	Pants = "PantsTemplate",
	ShirtGraphic = "Graphic",
}

local textureCache = {}

local function getTexture(assetId: number, small: boolean?): string?
	local cached = textureCache[assetId]
	if cached then
		return cached
	end

	local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, assetId)
	if not ok then
		return
	end

	local texture = false

	if info.AssetTypeId == Enum.AssetType.Image.Value then
		texture = "rbxassetid://" .. assetId
	elseif RunService:IsServer() and table.find(loadAssetTextureTypes, info.AssetTypeId) then
		local success, model = pcall(function()
			return InsertService:LoadAsset(assetId)
		end)
		if success then
			local object = model:GetChildren()[1]
			texture = object[textureProperty[object.ClassName]]
			model:Destroy()
		end
	end

	if not texture then
		local size = if small then 150 else 420
		texture = `rbxthumb://type=Asset&id={assetId}&w={size}&h={size}`
	end

	textureCache[assetId] = texture

	return texture
end

return getTexture
