local module = {}
module._K = {}

-- TODO: test the automatic whitespace stripping?
-- have argument types use the raw string if they want to parse whitespace :)

-- TODO: test support for utf8

function module.rawParse(message: string, prefix: string, delimiter: string?): { any }?
	local argDelimiter: string = delimiter or "%s"
	-- is there a command prefix?
	if string.find(message, string.format("^%s%%a", prefix)) ~= 1 then
		return
	end
	local prefixLen = #prefix
	message = string.sub(message, prefixLen + 1)

	local argument = { 1 }
	local command = { argument }
	local commands = { command }
	local lastChar, escaped, quoted = "", nil, nil

	for first, last in utf8.graphemes(message) do
		local char: string = string.sub(message, first, last)
		if string.find(char, '["`]') and not escaped and (not quoted or quoted == char) then
			if not quoted and not string.find(lastChar, argDelimiter) then
				argument = { first }
				table.insert(command, argument)
			end
			quoted = not quoted and char or nil
		elseif
			not (quoted or escaped)
			and char == prefix
			and string.find(lastChar, argDelimiter)
			and string.find(string.sub(message, last + 1), "^%a")
		then
			if #argument == 1 then
				table.remove(command)
			end
			argument = { first + 1 }
			command = { argument }
			table.insert(commands, command)
		elseif char == "\\" and not escaped then
			escaped = true
		else
			escaped = nil
			if not quoted and string.find(char, argDelimiter) and not string.find(lastChar, argDelimiter) then
				argument = { first + 1 }
				table.insert(command, argument)
			elseif quoted or not string.find(char, argDelimiter) then
				table.insert(argument, char)
			end
		end
		lastChar = char
	end

	-- TODO: can this be improved?
	-- compiles arg char list into a string
	for _, cmd in commands do
		for _, arg in cmd do
			local position = arg[1]
			local text = table.concat(arg, nil, 2)
			table.clear(arg)
			arg[1] = position + prefixLen -- offset position by prefix :)
			arg[2] = text
		end
	end

	return commands
end

function module.initArgument(argDefinition, rawArg)
	local rawType = module._K.Registry.types[argDefinition.type]
	local rawArgs = if rawType.listable then string.split(rawArg) else { rawArg }
	return rawType, rawArgs
end

function module.validateArgument(argDefinition, from, rawType, rawArgs)
	-- transform arguments
	local transformedArgs = {}
	local transformedTypes = {}
	for _, rawArg in rawArgs do
		local argType = rawType
		-- argument prefixes
		if rawType.prefixes then
			for prefix, prefixType in rawType.prefixes do
				if string.find(rawArg, prefix) == 1 then
					argType = module._K.Registry.types[prefixType]
					rawArg = string.sub(rawArg, #prefix + 1)
					break
				end
			end
		end
		local arg = if argType.transform then argType.transform(rawArg) else rawArg
		table.insert(transformedArgs, module._K.Util.trim(arg))
		table.insert(transformedTypes, argType)
	end
	-- validate arguments
	for i, arg in transformedArgs do
		local argType = transformedTypes[i]
		local ok, result = argType.validate(arg, from)
		print("validation", ok, arg, argType, result)
		if not ok then
			-- TODO: compile a list of feedback to display
			return false, result or "Invalid argument: " .. arg
		end
	end
	print("validated")
	return true, { transformedArgs, transformedTypes }
end

function module.prepareArgument(argDefinition, from, message, argPos, rawArg)
	local rawType, rawArgs = module.initArgument(argDefinition, rawArg)
	local ok, result = module.validateArgument(argDefinition, from, rawType, rawArgs)
	if not ok then
		-- FIX: please figure out feedback lol
		warn(result)
		return
	end
	local transformedArgs, transformedTypes = unpack(result)
	-- parse arguments
	local exitCmd = false
	local parsedArgs = {}

	if rawType.preParse then
		local preParsed, exit = rawType.preParse(transformedArgs, from, message, argPos)
		-- need to exit command with this somehow? lol
		exitCmd = exitCmd or exit
		transformedArgs = preParsed or transformedArgs
	end
	for i, arg in transformedArgs do
		local argType = transformedTypes[i]
		local parsedArg, exit = argType.parse(arg, from, message, argPos)
		-- if argType.postParse then
		-- 	arg = argType.postParse(arg)
		-- end
		table.insert(parsedArgs, parsedArg)
		if exit then
			break
		end
	end
	if rawType.postParse then
		parsedArgs = rawType.postParse(parsedArgs)
	end
	-- return transformed, validated, and parsed argument
	return (if rawType.listable then parsedArgs else parsedArgs[1]), exitCmd
end

function module.prepareCommand(commandArray, from, message)
	-- TODO: prepare commandArray[1] like an argument to validate and get the commandDefinition from the parsed result?
	local commandDefinition = module._K.Registry.commands[string.lower(commandArray[1][2])]
	if not commandDefinition then
		-- NOTE: this should only happen with .Chatted commands, cmdbar should be instantly validated
		print("Invalid command: " .. commandArray[1][2])
		return false, "Invalid command: " .. commandArray[1][2]
	end

	local args = {}
	local argsIndex = 1
	local argsLength = #commandDefinition.args
	print("command", message)
	for i = 2, #commandArray do
		local argPos, rawArg = unpack(commandArray[i])
		print("arg", argPos, rawArg)

		-- if it's the last argument concat the rest of the commands's arguments
		if argsIndex == argsLength then
			local lastArg = commandArray[#commandArray]
			rawArg = string.sub(message, argPos, lastArg[1] + #lastArg[2])
			print("lastarg", rawArg)
		end

		-- TODO: finish flag implementation, make sure last argument logic doesn't conflict with behaviour
		-- local flag = string.match(rawArg, "^%-%-?(%a%w*)")
		-- if flag then
		-- 	self.flags[string.lower(flag)] = true
		-- 	continue
		-- end
		local argDefinition = i - 1 <= argsLength and commandDefinition.args[argsIndex]
		if not argDefinition then
			print("no argDefinition lol", i - 1, argsLength, argsIndex)
			-- end of defined positional arguments
			-- NOTE: probably shouldn't break here and instead only parse the rest as flags? (unless greedy type)
			break
		end

		local parsedArg, exitCmd = module.prepareArgument(argDefinition, from, message, argPos, rawArg)
		print("parsed", parsedArg)
		if parsedArg then
			table.insert(args, parsedArg)
		end

		if exitCmd == true then
			-- exit with immediate execution (what was this for again? NOTE IT)
			break
		else
			-- TODO: need to step only if the argument is successful or optional
			-- TODO: how to handle optional arguments?!
			argsIndex += 1
		end
	end
	-- TODO: return feedback array to be merged
	return true,
		{
			_K = module._K,
			args = args,
			array = commandArray,
			definition = commandDefinition,
			from = from,
			message = message,
		}
end

function module.runCommands(from: (Player | number)?, rawString: string, chatted: boolean?)
	-- TODO: allow for remote commands with no player? or a userid to log remote users?
	local message = module._K.Util.trimStart(rawString)

	local rawCommands = module.rawParse(message, module._K.settings.prefix:get())
	if not rawCommands then
		return -- no valid commands found, show feedback
	end

	print("rawCommands", rawCommands)

	for _, commandArray in rawCommands do
		print("commandArray", commandArray)
		local ok, result = module.prepareCommand(commandArray, from, message)

		if not ok then
			-- TODO: need to have a unified way of displaying feedback, and a way for autocomplete lol
			print(result)
			return false, result
		end

		-- -- TODO: check if client/server and handle client/server run?
		-- -- need to also pass the validated command object to the server if on client?

		-- TODO pre/post command hooks
		local success, err = pcall(result.definition.run, result, unpack(result.args))
		if not success then
			-- show command error
			-- TODO: propagate error info to send relevant information to the client? (for serverside run only?)
			print(err)
			return success, err
		end
	end
	return
end

return module
