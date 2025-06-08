local MarketplaceService = game:GetService("MarketplaceService")

local _K

local imageType = {
	filterLog = true,
	transform = function(v)
		return if v == "" then 0 else tonumber(v)
	end,
	validate = function(v)
		return v ~= nil and v == math.floor(v), "Only whole numbers are valid"
	end,
	parse = function(v, self)
		if _K.IsClient then
			if pcall(MarketplaceService.GetProductInfo, MarketplaceService, v) then
				return "rbxthumb://type=Asset&id=" .. v .. "&w=150&h=150"
			end
		else
			local ok, result = pcall(_K.Util.getTexture, v)
			if ok then
				return result
			end
		end
		if self.definition.optional and self.rawArg == "" then
			return ""
		end
		return nil, "Invalid image"
	end,
	suggestions = function(text)
		return { if tonumber(text) then text else nil }
	end,
}

return function(context)
	_K = context
	_K.Registry.registerType("image", imageType)
	_K.Registry.registerType("images", { listable = true }, imageType)
end
