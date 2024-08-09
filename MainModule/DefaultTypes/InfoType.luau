return function(_K)
	local infoType = _K.Registry.makeEnumType("infoType", Enum.InfoType:GetEnumItems())

	_K.Registry.registerType("infoType", infoType)
	_K.Registry.registerType("infoTypes", { listable = true }, infoType)
end
