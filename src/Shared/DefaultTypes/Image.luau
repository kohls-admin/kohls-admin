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
		local texture = _K.Util.getTexture(v, _K.IsClient)
		if texture then
			return texture
		end
		if self.definition.optional and self.rawArg == "" then
			return ""
		end
		if _K.IsClient then
			return "rbxasset://textures/ui/GuiImagePlaceholder.png"
		end
		return nil, "Failed to load image"
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
