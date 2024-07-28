return function(_K)
	local infoType = _K.Util.makeEnumType("infoType", Enum.InfoType:GetEnumItems())

	_K.Registry.registerType("infoType", infoType)
	_K.Registry.registerType("infoTypes", infoType, { listable = true })
end
