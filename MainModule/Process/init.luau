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

function Process.prepareCommands(_K: any, from: number, rawText: string)
	if not utf8.len(rawText) then
		return false, "Invalid utf8 string"
	end

	local text = Util.String.trimStart(rawText)
	local rawCommands = Process.rawParse(text, _K.playerPrefix[from] or _K.Data.settings.prefix)
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

		if not Auth.hasCommand(from, commandDefinition) then
			return false, "Invalid permissions for command: " .. commandText
		end

		local command = Command.new(_K, commandDefinition, commandArray, from, text)
		local ok, result = command:validate()

		table.insert(commands, command)

		if not ok then
			return false, result
			-- break
		end

		if command.greedy then
			break
		end
	end

	return true, commands
end

function Process.runCommands(_K: any, from: number, rawText: string, chatted: boolean?): boolean
	local commandRan, commandError
	local ok, result = Process.prepareCommands(_K, from, rawText)

	local logText

	if ok then
		for _, command in result do
			local success, err = command:run()

			if success == nil then
				if command.greedy then
					break
				end
				continue
			elseif success == true then
				commandRan = true
				command.Ran = true
			elseif success == false then
				commandError = err
				command.Error = err
				warn("commandError", err)
			end

			if command.greedy then
				break
			end
		end
	else
		commandError = result
	end

	if commandError then
		commandError = `<b>{commandError}</b>`
		if _K.IsServer then
			_K.Remote.Notify:FireClient(_K.Services.Players:GetPlayerByUserId(from), commandError, nil, "error")
		else
			task.spawn(_K.client.Notify, {
				Text = commandError,
				TextColor3 = Color3.new(1, 0, 0),
				UserFrame = {},
				ExitButton = true,
				Sound = "Call_Leave",
			})
		end
	elseif chatted and _K.IsClient then
		_K.Remote.Command:FireServer(rawText, chatted)
	end

	if not (commandRan or commandError) then
		-- skip logging if nothing happened
		return commandRan
	end

	task.spawn(function()
		local mainThread = coroutine.running()
		local running = 0

		if commandRan then
			local log = {}
			for _, command in result do
				table.insert(log, _K.Data.settings.prefix .. command.definition.name)

				for _, arg in command.args do
					if arg.rawType.log then
						table.insert(log, arg.rawType.log(arg))
					else
						running += 1
						task.spawn(function()
							local filtered =
								Util.String.filterForBroadcast(Util.Table.concat(arg.parsedArgs, ","), from)
							table.insert(log, filtered)
							running -= 1
							if running == 0 then
								coroutine.resume(mainThread)
							end
						end)
					end
				end
			end

			if running > 0 then
				coroutine.yield()
			end

			logText = table.concat(log, " ")
		else -- filter entire rawText as broadcast
			local trimmed = Util.String.trim(rawText)
			if #trimmed > 0 then
				logText = Util.String.filterForBroadcast(Util.String.trim(rawText), from)
			end
		end

		_K.log(
			if commandError then commandError else logText or "",
			if commandRan then "COMMAND" else "ERROR",
			from,
			true
		)
	end)

	return commandRan
end

return Process
