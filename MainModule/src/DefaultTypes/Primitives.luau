local function simpleValidate(v)
	return v ~= nil
end

return function(_K)
	_K.Registry.registerType("string", {
		validate = simpleValidate,
		parse = tostring,
	})
	_K.Registry.registerType("stringGreedy", {
		displayName = "string",
		validate = simpleValidate,
		parse = function(_, _, message, pos)
			return _K.Util.trim(string.sub(message, pos))
		end,
	})
	_K.Registry.registerType("number", {
		transform = tonumber,
		validate = simpleValidate,
		parse = function(v)
			return v
		end,
	})
	_K.Registry.registerType("integer", {
		transform = tonumber,
		validate = function(v)
			return v ~= nil and v == math.floor(v), "Only whole numbers are valid."
		end,
		parse = function(v)
			return v
		end,
	})
	_K.Registry.registerType("boolean", {
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
	})
end
