-- TODO: need to refactor this to make autocomplete easier hahahahaha ;(

local Argument = {}
Argument.__index = Argument

function Argument.parseTypeUnion(rawType: string, rawArg: string)
	local split = string.split(rawType, " ")

	-- Check prefixes in order from longest to shortest
	local types = {}
	for i = 1, #split, 2 do
		types[#types + 1] = {
			prefix = split[i - 1] or "",
			type = split[i],
		}
	end

	table.sort(types, function(a, b)
		return #a.prefix > #b.prefix
	end)

	for i, t in types do
		if string.sub(rawArg, 1, #t.prefix) == t.prefix then
			return t.type, rawArg:sub(#t.prefix + 1), t.prefix
		end
	end
	return
end

function Argument.new(command, definition, argPos, rawArg)
	local unionType, unionArg, prefix = Argument.parseTypeUnion(definition.type, rawArg)
	local rawType = command._K.Registry.types[unionType]
	assert(rawType, `Invalid argument type {unionType}, did it fail to register?`)

	local rawArgs = if rawType.listable then command._K.Util.String.splitOutsideQuotes(unionArg) else { unionArg }

	local object = {
		_K = command._K,
		command = command,
		commandArray = command.array,
		definition = definition,
		validated = false,

		argPos = argPos,
		prefix = prefix,
		rawArg = rawArg,
		rawType = rawType,
		rawArgs = rawArgs,
		transformedArgs = {},
		transformedTypes = {},
		parsedArgs = {},
	}

	return setmetatable(object, Argument)
end

function Argument:invalidate(rawArg, argPos, message)
	self.invalid = { arg = rawArg, pos = argPos, message = message }
	return false, self.invalid
end

function Argument:transform()
	local argPos = self.argPos
	for _, rawArg in self.rawArgs do
		local arg = self._K.Util.String.stripQuotes(self._K.Util.String.trim(rawArg))
		local argType = self.rawType
		if argType.prefixes then
			for prefix, prefixType in argType.prefixes do
				local startIndex, endIndex = string.find(arg, prefix)
				if startIndex == 1 then
					argType = self._K.Registry.types[prefixType]
					arg = string.sub(arg, endIndex + 1)
					break
				end
			end
		end

		if argType.transform then
			local optional = not string.find(arg, "%S") and self.definition.optional
			local value, feedback = argType.transform(arg)
			arg = value
			if value == nil and not optional then
				local message = feedback
					or "Invalid transform: " .. if string.find(rawArg, "^%s*$") then "nil" else rawArg
				return self:invalidate(rawArg, argPos, message)
			end
		end
		table.insert(self.transformedArgs, arg)
		table.insert(self.transformedTypes, argType)
		argPos += #rawArg + 1
	end
	return true
end

function Argument:validate()
	if self.validated then
		return true
	end

	if self.definition.optional and #self.rawArg == 0 then
		return true
	end

	if self.invalid then
		return false, self.invalid.message
	end

	local transformPos = self.argPos
	for i, arg in self.transformedArgs do
		local rawArg = self.rawArgs[i]
		local argType = self.transformedTypes[i]
		local ok, result = argType.validate(arg, self)
		if not ok then
			return self:invalidate(rawArg, transformPos, result or "Invalid argument: " .. rawArg)
		end
		transformPos += #rawArg + 1
	end

	self.validated = true
	return true
end

function Argument:parse()
	if not (self.validated or self.definition.optional) then
		return false, "Argument must be validated before parsing"
	end

	local argPos = self.argPos
	for i, transformedArg in self.transformedArgs do
		local rawArg = self.rawArgs[i]
		local argType = self.transformedTypes[i]
		local ok, arg, feedback = pcall(argType.parse, transformedArg, self)
		if not ok or arg == nil then
			return self:invalidate(rawArg, argPos, feedback or arg or "Invalid argument: " .. rawArg)
		end

		if argType.listable and not self.rawType.listable then
			table.insert(self.parsedArgs, arg[1])
		elseif argType.listable and self.rawType.listable and argType ~= self.rawType then
			for _, value in arg do
				table.insert(self.parsedArgs, value)
			end
		else
			table.insert(self.parsedArgs, arg)
		end

		argPos += #rawArg + 1
	end

	if self.rawType.postParse then
		_, self.parsedArgs = pcall(self.rawType.postParse, self.parsedArgs, self)
	end

	return true, if self.rawType.listable then self.parsedArgs else self.parsedArgs[1]
end

function Argument:prepare()
	if self.validated then
		return true, if self.rawType.listable then self.parsedArgs else self.parsedArgs[1]
	end

	local ok, result = self:transform()
	if not ok then
		return false, result
	end

	local success, feedback = self:validate()
	if not success then
		return false, feedback
	end

	return self:parse()
end

return Argument
