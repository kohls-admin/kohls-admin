-- TODO: need to refactor this to make autocomplete easier hahahahaha ;(

local Argument = {}
Argument.__index = Argument

function Argument.new(command, definition, argPos, rawArg)
	local rawType = command._K.Registry.types[definition.type]
	assert(rawType, `Invalid argument type {definition.type}, did it fail to register?`)

	local rawArgs = if rawType.listable then command._K.Util.String.splitOutsideQuotes(rawArg) else { rawArg }

	local object = {
		_K = command._K,
		command = command,
		commandArray = command.array,
		definition = definition,
		validated = false,

		argPos = argPos,
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
	self.command.invalidArg = rawArg
	self.command.invalidPos = argPos
	self.command.invalidMessage = message
	return false, self.command.invalidMessage
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
			arg = argType.transform(arg)
			if arg == nil and not optional then
				local message = "Invalid transform: "
					.. if self._K.Util.String.trim(rawArg) == "" then "nil" else rawArg
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

	if self.definition.optional and string.len(self.rawArg) == 0 then
		return true
	end

	if self.command.invalidArg then
		return false, self.command.invalidMessage
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

	local parsePos = self.argPos
	local parseArgs = self.transformedArgs
	if self.rawType.preParse then
		local ok, arg, feedback = pcall(self.rawType.preParse, self.transformedArgs, self)
		if not ok or arg == nil then
			return self:invalidate(self.rawArg, parsePos, feedback or arg or "Invalid argument: " .. self.rawArg)
		end
		parseArgs = arg or parseArgs
	end

	for i, parseArg in parseArgs do
		local rawArg = self.rawArgs[i]
		local argType = self.transformedTypes[i]
		local ok, arg, feedback = pcall(argType.parse, parseArg, self)
		if not ok or arg == nil then
			return self:invalidate(rawArg, parsePos, feedback or arg or "Invalid argument: " .. rawArg)
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

		parsePos += #rawArg + 1
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
