local ASSET_TEXTURE_TYPES = {
	Enum.AssetType.Face.Value,
	Enum.AssetType.Shirt.Value,
	Enum.AssetType.Pants.Value,
	Enum.AssetType.TShirt.Value,
	Enum.AssetType.Decal.Value,
}

local TEXTURE_PROPERTY = {
	Decal = "Texture",
	Shirt = "ShirtTemplate",
	Pants = "PantsTemplate",
	ShirtGraphic = "Graphic",
}

return function(assetId, infoType)
	local assetType = game:GetService("MarketplaceService"):GetProductInfo(assetId, infoType).AssetTypeId
	if assetType == Enum.AssetType.Image.Value then
		return "rbxassetid://" .. assetId
	elseif table.find(ASSET_TEXTURE_TYPES, assetType) then
		local success, model = pcall(function()
			return game:GetService("InsertService"):LoadAsset(assetId)
		end)
		if success then
			local object = model:GetChildren()[1]
			local texture = object[TEXTURE_PROPERTY[object.ClassName]]
			model:Destroy()
			return texture
		end
	end
	return "rbxthumb://type=Asset&id=" .. assetId .. "&w=420&h=420"
end
