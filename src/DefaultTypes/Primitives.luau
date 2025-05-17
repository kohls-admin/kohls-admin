local _K

local function simpleValidate(v)
	return v ~= nil
end

local booleanType = {
	transform = string.lower,
	validate = function(v)
		return string.find("true", v, 1, true) == 1 or string.find("false", v, 1, true) == 1,
			"Only use true or false for booleans."
	end,
	parse = function(v)
		if string.find("true", v, 1, true) == 1 then
			return true
		elseif string.find("false", v, 1, true) == 1 then
			return false
		else
			error("Invalid boolean value.")
		end
	end,
	suggestions = function(text: string, from: number)
		return { "true", "false" }
	end,
}

local integerType = {
	filterLog = true,
	transform = function(v)
		return if v == "" then 0 else tonumber(v)
	end,
	validate = function(v)
		return v ~= nil and v == math.floor(v), "Only whole numbers are valid."
	end,
	parse = function(v)
		return v
	end,
}

local numberType = {
	filterLog = true,
	transform = integerType.transform,
	validate = simpleValidate,
	parse = function(v)
		return v
	end,
}

local rawStringType = {
	filterLog = true,
	validate = simpleValidate,
	parse = tostring,
}

local stringType = {
	validate = simpleValidate,
}

return function(context)
	_K = context
	_K.Registry.registerType("boolean", booleanType)
	_K.Registry.registerType("booleans", {
		listable = true,
	}, booleanType)
	_K.Registry.registerType("integer", integerType)
	_K.Registry.registerType("integers", {
		listable = true,
	}, integerType)
	_K.Registry.registerType("number", numberType)
	_K.Registry.registerType("numbers", {
		listable = true,
	}, numberType)
	_K.Registry.registerType("rawString", rawStringType)
	_K.Registry.registerType("rawStrings", {
		listable = true,
	}, rawStringType)
	function stringType.parse(v, self)
		return _K.Util.String.filterForBroadcast(v, self.command.from)
	end
	_K.Registry.registerType("string", stringType)
	_K.Registry.registerType("strings", {
		listable = true,
	}, stringType)
end
