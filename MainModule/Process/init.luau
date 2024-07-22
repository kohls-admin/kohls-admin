local Auth = require(script.Parent.Auth)
local Registry = require(script.Parent.Registry)
local Util = require(script.Parent.Util)
local Command = require(script.Command)

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
		elseif not (quoted or escaped) and char == prefix and string.find(lastChar, argDelimiter) then
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

function Process.prepareCommands(context: any, from: number, rawText: string)
	if not utf8.len(rawText) then
		return false, "Invalid utf8 string"
	end

	local text = Util.trimStart(rawText)
	local rawCommands = Process.rawParse(text, context.playerPrefix[from] or context.settings.prefix._value)
	if not rawCommands then
		return
	end

	local commands = {}

	for i, commandArray in rawCommands do
		local commandText = commandArray[1][2]
		local commandDefinition = Registry.commands[string.lower(commandText)]

		if not commandDefinition then
			return false, "Invalid command: " .. commandText
		end

		if not Auth.hasCommandGroup(from, commandDefinition.group) then
			return false, "Invalid permissions for command: " .. commandText
		end

		local command = Command.new(context, commandDefinition, commandArray, from, text)
		local ok, result = command:validate()

		table.insert(commands, command)

		if not ok then
			command.Error = result
			break
		end

		if command.greedy then
			break
		end
	end

	return true, commands
end

function Process.runCommands(context: any, from: number, rawText: string): boolean
	local commandRan, commandError
	local ok, result = Process.prepareCommands(context, from, rawText)

	if ok then
		for _, command in result do
			-- error during preparation
			if command.Error then
				commandError = command.Error
				break
			end

			local run = command.definition[if context.IsServer then "run" else "clientRun"]
			if not run then
				if command.greedy then
					break
				end
				continue
			end

			context.hook.preCommand:Fire(command)

			local success, err = command:run()
			if success then
				commandRan = true
				command.Ran = true
			elseif success == false then
				commandError = err
				command.Error = err
				warn("commandError", err)
			end

			context.hook.postCommand:Fire(command)

			if command.greedy then
				break
			end
		end
	else
		commandError = result
	end

	if not (commandRan or commandError or context.IsServer) then
		-- skip logging on client if nothing happened
		return commandRan
	end
	context.log(
		if commandError then commandError else Util.trimStart(rawText),
		if commandRan then "COMMAND" elseif commandError then "ERROR" else "CHAT",
		from
	)

	return commandRan
end

return Process
