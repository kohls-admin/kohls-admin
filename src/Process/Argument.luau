-- TODO: need to refactor this to make autocomplete easier hahahahaha ;(

local Argument = {}
Argument.__index = Argument

function Argument.new(command, definition, argPos, rawArg)
	local rawType = command._K.Registry.types[definition.type]
	assert(rawType, `Invalid argument type {definition.type}, did it fail to register?`)

	if string.find(rawArg, '["`]', 1) then
		rawArg = string.match(rawArg, '[^"`]+') or ""
	end

	local object = {
		_K = command._K,
		command = command,
		commandArray = command.array,
		definition = definition,
		validated = false,

		argPos = argPos,
		rawArg = rawArg,
		rawType = rawType,
		rawArgs = if rawType.listable then string.split(rawArg) else { rawArg },
		transformedArgs = {},
		transformedTypes = {},
		parsedArgs = {},
	}

	return setmetatable(object, Argument)
end

function Argument:transform()
	for _, rawArg in self.rawArgs do
		local argType = self.rawType
		if argType.prefixes then
			for prefix, prefixType in argType.prefixes do
				local startIndex, endIndex = string.find(rawArg, prefix)
				if startIndex == 1 then
					argType = self._K.Registry.types[prefixType]
					rawArg = string.sub(rawArg, endIndex + 1)
					break
				end
			end
		end

		local arg = self._K.Util.String.stripQuotes(rawArg)
		if argType.transform then
			local optional = not string.find(arg, "%S") and self.definition.optional
			arg = argType.transform(arg)
			if arg == nil and not optional then
				self.command.invalidArg = rawArg
				self.command.invalidPos = self.argPos
				self.command.invalidMessage = "Invalid transform: "
					.. if self._K.Util.String.trim(rawArg) == "" then "nil" else rawArg
				break
			end
		end
		table.insert(self.transformedArgs, if type(arg) == "string" then self._K.Util.String.trim(arg) else arg)
		table.insert(self.transformedTypes, argType)
	end
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
			self.command.invalidArg = rawArg
			self.command.invalidPos = transformPos
			self.command.invalidMessage = result or "Invalid argument: " .. rawArg
			return false, self.command.invalidMessage
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

	local parseArgs = self.transformedArgs
	if self.rawType.preParse then
		local ok, arg = pcall(self.rawType.preParse, self.transformedArgs, self)
		if not ok then
			warn("preParseArg error", arg)
		end
		parseArgs = arg or parseArgs
	end

	for i, parseArg in parseArgs do
		local argType = self.transformedTypes[i]
		local ok, arg = pcall(argType.parse, parseArg, self)
		if not ok then
			warn("parseArg error", arg)
		end

		if not ok then
			table.insert(self.parsedArgs, nil)
		else
			if argType.listable and not self.rawType.listable then
				table.insert(self.parsedArgs, arg[1])
			elseif argType.listable and self.rawType.listable and argType ~= self.rawType then
				for _, value in arg do
					table.insert(self.parsedArgs, value)
				end
			else
				table.insert(self.parsedArgs, arg)
			end
		end
	end

	if self.rawType.postParse then
		_, self.parsedArgs = pcall(self.rawType.postParse, self.parsedArgs, self)
	end

	return if self.rawType.listable then self.parsedArgs else self.parsedArgs[1]
end

function Argument:prepare()
	if self.validated then
		return true, if self.rawType.listable then self.parsedArgs else self.parsedArgs[1]
	end

	self:transform()
	local success, feedback = self:validate()
	if not success then
		return false, feedback
	end

	return true, self:parse()
end

return Argument
