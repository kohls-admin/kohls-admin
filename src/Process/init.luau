local Auth = require(script.Parent.Auth)
local Data = require(script.Parent.Data.Defaults)
local Hook = require(script.Parent.Hook)
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
	local rawCommands = Process.rawParse(text, _K.getCommandPrefix(from))
	if not rawCommands then
		return
	end

	local commands = {}

	for i, commandArray in rawCommands do
		local commandText = commandArray[1][2]
		local commandAlias = string.lower(commandText)
		local commandDefinition = Registry.commands[commandAlias]

		if not commandDefinition then
			return false, "Invalid command: " .. commandText
		end

		if not Auth.hasCommand(from, commandDefinition) then
			local player = _K.Util.Services.Players:GetPlayerByUserId(from)
			if player and _K.IsClient then
				for role, roleData in Data.roles do
					if (roleData.gamepass or role == "vip") and Auth.roleCanUseCommand(role, commandDefinition) then
						if role == "vip" and _K.Data.settings.vip then
							_K.promptPurchaseVIP()
						else
							_K.Util.Services.MarketplaceService:PromptGamePassPurchase(from, roleData.gamepass)
						end
					end
				end
			end

			return false, "Invalid permissions for command: " .. commandText
		end

		local command = Command.new(_K, commandAlias, commandDefinition, commandArray, from, text)
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

function Process.runCommands(_K: any, from: number, rawText: string, noLog: boolean?): boolean
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

		Hook.runPreparedCommands:Fire(from, result, rawText)
	else
		commandError = result
	end

	if commandError then
		commandError = `<b>{commandError}</b>`
		if _K.IsServer then
			_K.Remote.Notify:FireClient(
				_K.Services.Players:GetPlayerByUserId(from),
				{ Text = commandError, From = "_K", TextColor3 = Color3.new(1, 0, 0), Sound = "Call_Leave" }
			)
		else
			task.spawn(_K.Notify, {
				Text = commandError,
				TextColor3 = Color3.new(1, 0, 0),
				UserFrame = {},
				Sound = "Call_Leave",
			})
		end
	elseif _K.IsClient then
		_K.Remote.Command:FireServer(rawText)
	end

	if not (commandRan or commandError) then
		-- skip logging if nothing happened
		return commandRan
	end

	task.spawn(function()
		if commandRan then
			local tasks = Util.TaskGroup.new()
			local log = {}

			for _, command in result do
				table.insert(log, _K.Data.settings.prefix .. command.alias)
				for _, arg in command.args do
					if arg.rawType.log then
						table.insert(log, arg.rawType.log(arg))
					else
						tasks:add(function()
							local argString = Util.Table.concat(arg.parsedArgs, ",")
							table.insert(log, Util.String.filterForBroadcast(argString, from))
						end)
					end
				end
			end

			tasks:wait()

			if not noLog then
				logText = table.concat(log, " ")
			end
		elseif not noLog then -- filter entire rawText as broadcast
			local trimmed = Util.String.trim(rawText)
			if #trimmed > 0 then
				logText = Util.String.filterForBroadcast(Util.String.trim(rawText), from)
			end
		end

		if not noLog then
			_K.log(logText or "", "COMMAND", from, true)
			if commandError then
				_K.log(Util.String.filterForBroadcast(commandError, from), "ERROR", from, true)
			end
		end
	end)

	return commandRan
end

return Process
