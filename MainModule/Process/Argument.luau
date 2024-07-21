-- TODO: need to refactor this to make autocomplete easier hahahahaha ;(

local Argument = {}
Argument.__index = Argument

function Argument.new(command, definition, argPos, rawArg)
	local object = {
		_K = command._K,
		command = command,
		commandArray = command.array,
		definition = definition,
		-- special case for argTypes like StringGreedy which use the rest of the input message
		exit = false,
		validated = false,

		argPos = argPos,
		rawArg = rawArg,
		rawType = nil,
		rawArgs = nil,
		transformedArgs = {},
		transformedTypes = {},
		parsedArgs = {},
	}

	-- if it's the last argument use the rest of the argument string
	-- only caveat would be irrelevant text after the command string (might as well make it explicit!)
	if command.argIndex == #command.definition.args then
		local lastArg = object.commandArray[#object.commandArray]
		object.rawArg = string.sub(command.text, argPos, lastArg[1] + #lastArg[2])
	end

	object.rawType = object._K.Registry.types[definition.type]
	object.rawArgs = if object.rawType.listable then string.split(rawArg) else { rawArg }

	return setmetatable(object, Argument)
end

function Argument:transform()
	for _, rawArg in self.rawArgs do
		local argType = self.rawType
		if argType.prefixes then
			for prefix, prefixType in argType.prefixes do
				if string.find(rawArg, prefix) == 1 then
					argType = self._K.Registry.types[prefixType]
					rawArg = string.sub(rawArg, #prefix + 1)
					break
				end
			end
		end

		local arg = self._K.Util.stripQuotes(rawArg)
		arg = if argType.transform then argType.transform(rawArg) else rawArg
		table.insert(self.transformedArgs, if type(arg) == "string" then self._K.Util.trim(arg) else arg)
		table.insert(self.transformedTypes, argType)
	end
end

function Argument:validate()
	if self.validated then
		return true
	end

	local transformPos = self.argPos
	for i, arg in self.transformedArgs do
		local rawArg = self.rawArgs[i]
		local argType = self.transformedTypes[i]
		local ok, result = argType.validate(arg, self.command.from)
		if not ok then
			self.command.invalidArg = rawArg
			self.command.invalidPos = transformPos
			return false, result or "Invalid argument: " .. arg
		end
		transformPos += #rawArg + 1
	end
	self.validated = true

	return true
end

function Argument:parse()
	if not self.validated then
		return false, "Argument must be validated before parsing"
	end

	local parseArgs = self.transformedArgs
	if self.rawType.preParse then
		local arg, exit = self.rawType.preParse(self.transformedArgs, self.command.from, self.command.text, self.argPos)
		self.exit = self.exit or exit
		parseArgs = arg or parseArgs
	end

	for i, arg in parseArgs do
		local argType = self.transformedTypes[i]
		arg, self.exit = argType.parse(arg, self.command.from, self.command.text, self.argPos)
		table.insert(self.parsedArgs, arg)
		if self.exit then
			break
		end
	end

	if self.rawType.postParse then
		self.parsedArgs = self.rawType.postParse(self.parsedArgs)
	end

	return if self.rawType.listable then self.parsedArgs else self.parsedArgs[1]
end

function Argument:prepare()
	if self.validated then
		return if self.rawType.listable then self.parsedArgs else self.parsedArgs[1]
	end

	self:transform()
	local success, feedback = self:validate()
	if not success then
		return false, feedback
	end

	return self:parse()
end

return Argument
