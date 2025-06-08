local _K

local function notNil(v)
	return v ~= nil
end

local function startMatch(list, v)
	for _, match in list do
		local vStart, vEnd = string.find(match, v, 1, true)
		if vStart == 1 and vEnd > 0 then
			return true
		end
	end
	return false
end

local yes, no = { "+", "true", "yes", "enabled" }, { "-", "false", "no", "disabled" }
local booleanSuggestions = {}
for i, v in yes do
	table.insert(booleanSuggestions, v)
	table.insert(booleanSuggestions, no[i])
end

local booleanType = {
	transform = string.lower,
	validate = function(v)
		if v == "" then
			return true
		end
		return startMatch(yes, v) or startMatch(no, v), "Invalid boolean"
	end,
	parse = function(v)
		if v == "" then
			return true
		end
		if startMatch(yes, v) then
			return true
		elseif startMatch(no, v) then
			return false
		end
		return nil, "Invalid boolean"
	end,
	suggestions = function(text: string, from: number)
		return booleanSuggestions
	end,
}

local integerType = {
	filterLog = true,
	transform = function(v)
		return if v == "" then 0 else tonumber(v), "Invalid number"
	end,
	validate = function(v)
		return v ~= nil and v == math.floor(v), "Only whole numbers are valid"
	end,
	parse = function(v)
		return v
	end,
}

local numberType = {
	filterLog = true,
	transform = integerType.transform,
	validate = notNil,
	parse = function(v)
		return v
	end,
}

local rawStringType = {
	filterLog = true,
	validate = notNil,
	parse = tostring,
}

local stringType = {
	validate = notNil,
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
	_K.Registry.registerType("stringGreedy", rawStringType)
	_K.Registry.registerType("rawString", rawStringType)
	_K.Registry.registerType("rawStrings", {
		listable = true,
	}, rawStringType)
	function stringType.parse(v, self)
		if _K.Service.RunService:IsClient() then
			return v
		end
		return _K.Util.String.filterForBroadcast(v, self.command.from)
	end
	_K.Registry.registerType("string", stringType)
	_K.Registry.registerType("strings", {
		listable = true,
	}, stringType)
end
