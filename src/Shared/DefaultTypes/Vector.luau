local function validateVector(value, i)
	if value == nil then
		return false, `Invalid or missing number at position {i} in Vector type.`
	end
	return true
end

return function(context)
	local vector3Type = context.Registry.makeSequenceType({
		validate = validateVector,
		transform = tonumber,
		constructor = Vector3.new,
		length = 3,
	})

	local vector2Type = context.Registry.makeSequenceType({
		validate = validateVector,
		transform = tonumber,
		constructor = Vector2.new,
		length = 2,
	})

	context.Registry.registerType("vector3", vector3Type)
	context.Registry.registerType("vector2", vector2Type)
end
