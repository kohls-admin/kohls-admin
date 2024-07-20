local Auth = require(script.Parent.Auth)
local Registry = require(script.Parent.Registry)
local Util = require(script.Parent.Util)

type ArgumentType = Registry.ArgumentType
type ArgumentDefinition = Registry.ArgumentDefinition

--- @class Process
local Process = {}

--- Parses a string into a raw command format.
function Process.rawParse(message: string, prefix: string, delimiter: string?): { any }?
	local argDelimiter: string = delimiter or "%s"
	-- is there a command prefix?
	if string.find(message, string.format('^%s[^%s"`,%%s]', prefix, prefix)) ~= 1 then
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
			table.insert(argument, char)
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

--- Initializes an argument.
function Process.initArgument(argDefinition: ArgumentDefinition, rawArg: string): (ArgumentType, { string })
	local rawType = Registry.types[argDefinition.type]
	local rawArgs = if rawType.listable then string.split(rawArg) else { rawArg }
	return rawType, rawArgs
end

--- Validates an argument.
function Process.validateArgument(
	argDefinition: ArgumentDefinition,
	from: number,
	rawType: ArgumentType,
	rawArgs: { string }
): (boolean, string | { any })
	-- transform arguments
	local rawLength = #rawArgs
	local transformedArgs = table.create(rawLength)
	local transformedTypes = table.create(rawLength)
	for i, rawArg in rawArgs do
		local argType = rawType
		-- argument prefixes
		if rawType.prefixes then
			for prefix, prefixType in rawType.prefixes do
				if string.find(rawArg, prefix) == 1 then
					argType = Registry.types[prefixType]
					rawArg = string.sub(rawArg, #prefix + 1)
					break
				end
			end
		end
		local arg = Util.stripQuotes(rawArg)
		arg = if argType.transform then argType.transform(arg) else arg
		transformedArgs[i] = if type(arg) == "string" then Util.trim(arg) else arg
		transformedTypes[i] = argType
	end
	-- validate arguments
	for i, transformedArg in transformedArgs do
		local argType = transformedTypes[i]
		local ok, result = argType.validate(transformedArg, from)
		if not ok then
			-- TODO: compile a list of feedback to display
			return false, result or "Invalid argument: " .. transformedArg
		end
	end
	return true, { transformedArgs, transformedTypes }
end

--- Prepares an argument for use with a command
function Process.prepareArgument(
	argDefinition: ArgumentDefinition,
	from: number,
	message: string,
	argPos: number,
	rawArg: string
): (any?, boolean?)
	local rawType, rawArgs = Process.initArgument(argDefinition, rawArg)
	local ok, result = Process.validateArgument(argDefinition, from, rawType, rawArgs)
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

--- Prepares a command to be executed
function Process.prepareCommand(
	context: any,
	commandArray: { any },
	from: number,
	message: string
): (boolean, string | {
	_K: { any },
	args: { any },
	array: { any },
	definition: { any },
	from: number,
	message: string,
	greedy: boolean,
})
	-- TODO: prepare commandArray[1] like an argument to validate and get the commandDefinition from the parsed result?
	local commandDefinition = Registry.commands[string.lower(commandArray[1][2])]
	if not commandDefinition then
		-- NOTE: this should only happen with .Chatted commands, cmdbar should be instantly validated
		print("Invalid command: " .. commandArray[1][2])
		return false, "Invalid command: " .. commandArray[1][2]
	end

	if not Auth.hasCommandGroup(from, commandDefinition.group) then
		print("Invalid permissions for command: " .. commandArray[1][2])
		return false, "Invalid permissions for command: " .. commandArray[1][2]
	end

	local args = {}
	local argsIndex = 1
	local argsLength = #commandDefinition.args
	local lastArgDefinition = commandDefinition.args[argsLength]
	local greedy = false
	for i = 2, #commandArray do
		local argPos, rawArg = unpack(commandArray[i])

		-- if it's the last argument concat the rest of the commands's arguments
		if argsIndex - 1 == argsLength then
			local lastArg = commandArray[#commandArray]
			rawArg = string.sub(message, argPos, lastArg[1] + #lastArg[2])
		end

		local argDefinition = i - 1 <= argsLength and commandDefinition.args[argsIndex]
		if not argDefinition then
			-- end of defined positional arguments

			break
		end

		if
			argDefinition.type == "stringGreedy" or (i == #commandArray and lastArgDefinition.type == "stringGreedy")
		then
			print("greedy string prepare command", argDefinition)
			rawArg = string.sub(message, argPos)
			greedy = true
		end

		local parsedArg, exitCmd = Process.prepareArgument(argDefinition, from, message, argPos, rawArg)
		if parsedArg then
			table.insert(args, parsedArg)
		end

		if exitCmd == true or greedy then
			-- exit with immediate execution, for stringGreedy early return and other early returns from argument parsing
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
			_K = context,
			args = args,
			array = commandArray,
			definition = commandDefinition,
			from = from,
			message = message,
			greedy = greedy,
		}
end

--- Executes commands
function Process.runCommands(context: any, from: (Player | number)?, rawString: string): boolean
	-- TODO: validate permissions!
	-- TODO: allow for remote commands with no player? or a userid to log remote users?
	if not utf8.len(rawString) then
		context.log(tostring(from) .. ": Invalid utf8 string", "ERROR")
		context.log(rawString, "CHAT", from)
		return false
	end
	local message = Util.trimStart(rawString)
	local userId = if typeof(from) == "Instance" then from.UserId else from
	local commandRan, commandError
	local rawCommands = Process.rawParse(message, context.playerPrefix[userId] or context.settings.prefix:get())
	if rawCommands then
		for i, commandArray in rawCommands do
			local ok, result = Process.prepareCommand(context, commandArray, userId, message)

			if not ok then
				-- TODO: need to have a unified way of displaying feedback, and a way for autocomplete lol
				commandError = result
				break
			end

			local run = result.definition[if context.IsServer then "run" else "clientRun"]
			if not run then
				if result.greedy then
					break
				end
				continue
			end

			context.hook.preCommand:Fire(result)
			local success, err = pcall(run, result, unpack(result.args))
			if not success then
				-- TODO: propagate error info to send relevant information to the client? (for serverside run only?)
				commandError = err
				result.commandError = err
				warn("commandError", err)
			else
				commandRan = true
				result.commandRan = true
			end
			context.hook.postCommand:Fire(result)
			if result.greedy then
				print("greedy!")
				break
			end
		end
	end

	-- TODO: error visual feedback for user
	if not (commandRan or commandError or context.IsServer) then
		-- skip logging on client if nothing happened
		return commandRan
	end
	context.log(
		if commandError then commandError else message,
		if commandRan then "COMMAND" elseif commandError then "ERROR" else "CHAT",
		from
	)
	return commandRan
end

return Process
