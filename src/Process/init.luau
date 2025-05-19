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
function Process.rawParse(message: string, prefix: string, argSeparator: string?): { any }?
	-- is there a command prefix?
	if string.find(message, string.format('^%s[^%s"`,%%s]', prefix, prefix)) ~= 1 then
		return
	end
	message = string.sub(message, #prefix + 1)

	local delimiter = argSeparator or "%s"
	local argument = { 1 }
	local command = { argument }
	local commands = { command }
	local lastChar, quote = "", nil

	for first, last in utf8.graphemes(message) do
		local char: string = string.sub(message, first, last)
		if quote then
			table.insert(argument, char)
			if char == quote then
				quote = nil
			end
		elseif char == prefix and string.find(lastChar, delimiter) then
			if #argument == 1 then
				table.remove(command)
			end
			argument = { first + 1 }
			command = { argument }
			table.insert(commands, command)
		elseif char == "`" or char == '"' then
			quote = char
			if string.find(lastChar, delimiter) then
				if #argument == 1 then
					argument[1], argument[2] = first, char
				else
					argument = { first, char }
					table.insert(command, argument)
				end
			else
				table.insert(argument, char)
			end
		elseif string.find(char, delimiter) and not string.find(lastChar, delimiter) then
			argument = { first + 1 }
			table.insert(command, argument)
		else
			table.insert(argument, char)
		end
		lastChar = char
	end

	-- compiles arg char list into a string
	for _, cmd in commands do
		for argIndex, arg in cmd do
			local position = arg[1]
			local text = table.concat(arg, nil, 2)
			table.clear(arg)
			arg[1] = position + #prefix
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
					if (roleData.gamepasses or role == "vip") and Auth.roleCanUseCommand(role, commandDefinition) then
						if role == "vip" and _K.Data.settings.vip then
							_K.promptPurchaseVIP()
						else
							_K.Util.Services.MarketplaceService:PromptGamePassPurchase(from, roleData.gamepasses[1])
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
			command.Error = result
			return false, result
		end
	end

	return true, commands
end

function Process.runCommands(_K: any, from: number, rawText: string, noLog: boolean?): boolean
	from = from or _K.CreatorId
	local ok, result = Process.prepareCommands(_K, from, rawText)

	local commandsRan = {}
	local commandErrors = {}

	if ok then
		for _, command in result do
			local success, err = command:run()
			if success == false or err then
				table.insert(commandErrors, `<b>"{command.alias}" command failed:</b> {err}`)
			else
				table.insert(commandsRan, command)
			end
		end

		Hook.runPreparedCommands:Fire(from, result, rawText)
	else
		table.insert(commandErrors, result)
		warn("commandError", result)
	end

	if #commandErrors > 0 then
		local commandError = `{table.concat(commandErrors, "\n")}`
		if _K.IsServer then
			local player = _K.Services.Players:GetPlayerByUserId(from)
			if player then
				_K.Remote.Notify:FireClient(
					_K.Services.Players:GetPlayerByUserId(from),
					{ Text = commandError, From = "_K", TextColor3 = Color3.new(1, 0, 0), Sound = "Call_Leave" }
				)
				for _, err in commandErrors do
					_K.Remote.Log:FireClient(player, {
						text = err,
						level = _K.Logger:encode("ERROR"),
						time = workspace:GetServerTimeNow(),
						from = from,
						name = player.Name,
					})
				end
			end
		else
			task.spawn(_K.Notify, {
				Text = commandError,
				TextColor3 = Color3.new(1, 0, 0),
				UserFrame = {},
				Sound = "Call_Leave",
			})
			for _, err in commandErrors do
				_K.log(err, "ERROR", from, true)
			end
		end
	end

	if _K.IsClient and #commandsRan > 0 then
		local prefix = _K.getCommandPrefix(from)
		local commandStrings = {}
		for _, command in commandsRan do
			local last = command.array[#command.array]
			table.insert(commandStrings, string.sub(rawText, command.array[1][1], last[1] + #last[2] - 1))
		end
		_K.Remote.Command:FireServer(`{prefix}{table.concat(commandStrings, " " .. prefix)}`)
	end

	if #commandsRan == 0 and #commandErrors == 0 then
		-- skip logging if nothing happened
		return true
	end

	task.spawn(function()
		if noLog then
			return
		end

		local logText

		if #commandsRan > 0 then
			local tasks = Util.TaskGroup.new()
			local log = {}

			local index = 1
			for _, command in commandsRan do
				if command.definition.noLog then
					continue
				end
				log[index] = _K.Data.settings.prefix .. command.alias
				index += 1
				for _, arg in command.args do
					local position = index
					tasks:add(function()
						local argString = Util.Table.concat(arg.parsedArgs, ",")
						if arg.rawType.filterLog then
							argString = Util.String.filterForBroadcast(argString, from)
						end
						log[position] = argString
					end)
					index += 1
				end
			end

			tasks:wait()

			if #log == 0 then
				return
			end

			logText = table.concat(log, " ")
		else -- filter entire rawText as broadcast
			local trimmed = Util.String.trim(rawText)
			if #trimmed > 0 then
				logText = Util.String.filterForBroadcast(Util.String.trim(rawText), from)
			end
		end

		_K.log(logText or "", "COMMAND", from, true)
	end)

	return #commandErrors == 0
end

return Process
