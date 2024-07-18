local function simpleValidate(v)
	return v ~= nil
end

local listable = {
	listable = true,
}

local booleanType = {
	transform = string.lower,
	validate = function(v)
		return v == "true" or v == "false", "Only use true or false for booleans."
	end,
	parse = function(v)
		if v == "true" then
			return true
		elseif v == "false" then
			return false
		else
			error("Invalid boolean value.")
		end
	end,
}

local integerType = {
	transform = tonumber,
	validate = function(v)
		return v ~= nil and v == math.floor(v), "Only whole numbers are valid."
	end,
	parse = function(v)
		return v
	end,
}

local numberType = {
	transform = tonumber,
	validate = simpleValidate,
	parse = function(v)
		return v
	end,
}

local stringType = {
	validate = simpleValidate,
	parse = tostring,
}

return function(_K)
	_K.Registry.registerType("boolean", booleanType)
	_K.Registry.registerType("booleans", listable, booleanType)
	_K.Registry.registerType("integer", integerType)
	_K.Registry.registerType("integers", listable, integerType)
	_K.Registry.registerType("number", numberType)
	_K.Registry.registerType("numbers", listable, numberType)
	_K.Registry.registerType("string", stringType)
	_K.Registry.registerType("strings", listable, stringType)
	_K.Registry.registerType("stringGreedy", {
		displayName = "string",
		validate = simpleValidate,
		parse = function(_, _, message, pos)
			return _K.Util.trim(string.sub(message, pos))
		end,
	})
end
