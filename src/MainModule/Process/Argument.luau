-- TODO: need to refactor this to make autocomplete easier hahahahaha ;(

local Argument = {
	OPTIONAL = table.freeze({ type = "Optional" }),
}
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
				if string.find(rawArg, prefix, 1, true) == 1 then
					argType = self._K.Registry.types[prefixType]
					rawArg = string.sub(rawArg, #prefix + 1)
					break
				end
			end
		end

		local arg = self._K.Util.String.stripQuotes(rawArg)
		arg = if argType.transform then argType.transform(rawArg) else rawArg
		table.insert(self.transformedArgs, if type(arg) == "string" then self._K.Util.String.trim(arg) else arg)
		table.insert(self.transformedTypes, argType)
	end
end

function Argument:validate()
	if self.validated or self.definition.optional then
		return true
	end

	local transformPos = self.argPos
	for i, arg in self.transformedArgs do
		local rawArg = self.rawArgs[i]
		local argType = self.transformedTypes[i]
		local ok, result = argType.validate(arg, self)
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
	if not (self.validated or self.definition.optional) then
		return false, "Argument must be validated before parsing"
	end

	local parseArgs = self.transformedArgs
	if self.rawType.preParse then
		local ok, arg, exit = pcall(self.rawType.preParse, self.transformedArgs, self)
		if not ok then
			warn("preParseArg error", arg)
		end
		self.exit = self.exit or exit
		parseArgs = arg or parseArgs
	end

	for i, arg in parseArgs do
		local argType, ok = self.transformedTypes[i], nil
		ok, arg, self.exit = pcall(argType.parse, arg, self)
		if not ok then
			warn("parseArg error", arg)
		end
		table.insert(self.parsedArgs, if ok then arg else Argument.OPTIONAL)
		if self.exit then
			break
		end
	end

	if string.find(string.lower(self.rawType.name), "player", 1, true) then
		if self.definition.ignoreSelf then
			local found = table.find(self.parsedArgs, self.command.fromPlayer)
			if found then
				table.remove(self.parsedArgs, found)
			end
		end

		local rank, role = self._K.Auth.getRank(self.command.from)
		if role.onlyTargetSelf then
			self.parsedArgs = { self.command.fromPlayer }
		elseif self.definition.lowerRank and not self.definition.shouldRequest then
			local new = {}
			for _, arg in self.parsedArgs do
				if
					arg == Argument.OPTIONAL
					or arg == self.command.fromPlayer
					or rank > self._K.Auth.getRank(arg.UserId)
				then
					table.insert(new, arg)
				end
			end
			self.parsedArgs = new
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
