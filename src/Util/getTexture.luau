local InsertService = game:GetService("InsertService")
local MarketplaceService = game:GetService("MarketplaceService")

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

local function getTexture(assetId)
	local assetType = MarketplaceService:GetProductInfo(assetId).AssetTypeId
	if assetType == Enum.AssetType.Image.Value then
		return "rbxassetid://" .. assetId
	elseif table.find(loadAssetTextureTypes, assetType) then
		local success, model = pcall(function()
			return InsertService:LoadAsset(assetId)
		end)
		if success then
			local object = model:GetChildren()[1]
			local texture = object[textureProperty[object.ClassName]]
			model:Destroy()
			return texture
		end
	end
	return "rbxthumb://type=Asset&id=" .. assetId .. "&w=420&h=420"
end

return getTexture
