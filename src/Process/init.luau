--!optimize 2
--!native

local Auth = require(script.Parent.Auth)
local Data = require(script.Parent.Data.Defaults)
local Hook = require(script.Parent.Hook)
local Registry = require(script.Parent.Registry)
local Util = require(script.Parent.Util)
local Command = require(script.Command)
local Type = require(script.Parent.Type)

type ArgumentType = Type.ArgumentType
type ArgumentDefinition = Type.ArgumentDefinition

--- @class Process
local Process = {
	ignoreFormat = `"\`%%$%%%%^%%*%%.%%+%%-%%(%%)%%[%%]\{\}%%p`,
}

--- Parses a string into a raw command format.
function Process.rawParse(message: string, prefixes: { string }, delimiter: string): { any }?
	local escapedSplit = Util.String.escapePattern(delimiter)
	local commandFormat = `%s[^%s"\`,{escapedSplit}]`
	local commandStart, prefix
	for _, value in prefixes do
		local escapedPrefix = Util.String.escapePattern(value)
		commandStart = string.find(message, string.format(commandFormat, escapedPrefix, escapedPrefix))
		if commandStart then
			prefix = value
			break
		end
	end
	if not prefix then
		return
	end

	local batchIgnore = string.format(`[%s{Process.ignoreFormat}{escapedSplit}]`, Util.String.escapePattern(prefix))
	message = string.sub(message, commandStart + #prefix)

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
		elseif lastChar == prefix and #argument == 1 and string.find(char, batchIgnore) then
			table.remove(commands)
			command = commands[#commands]
			argument = { first - 1, prefix, char }
			table.insert(command, argument)
		elseif char == prefix and string.find(lastChar, delimiter) then
			if #argument == 1 or string.find(argument[2], `^{delimiter}*$`) then
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
	local rawCommands = Process.rawParse(
		text,
		{ _K.getCommandPrefix(from), unpack(_K.Data.settings.prefix) },
		_K.Data.settings.splitKey or "%s"
	)
	if not rawCommands then
		return
	end

	local commands = {}

	for i, commandArray in rawCommands do
		local commandText = commandArray[1][2]
		local commandAlias = string.lower(commandText)
		local commandDefinition = Registry.commands[commandAlias]

		if not commandDefinition then
			return false, `Invalid command: {commandText}, did you mean "{Registry.suggestCommandAlias(commandAlias)}"?`
		end

		if not Auth.hasCommand(from, commandDefinition) then
			if _K.IsClient then
				for role, roleData in Data.roles do
					if (roleData.gamepasses or role == "vip") and Auth.roleCanUseCommand(role, commandDefinition) then
						if role == "vip" and _K.Data.settings.vip then
							_K.promptPurchaseVIP()
						elseif roleData.gamepasses[1] then
							_K.Service.Marketplace:PromptGamePassPurchase(_K.LocalPlayer, roleData.gamepasses[1])
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

local commandLimits = {}
local function resetLimit(from: number)
	commandLimits[from] = nil
end

function Process.runCommands(_K: any, from: number, rawText: string, noLog: boolean?): boolean
	from = from or _K.creatorId

	local cooldown, limit
	if _K.IsServer then
		local _rank, role = _K.Auth.getRank(from)
		if role.limits then
			cooldown, limit = role.limits.cooldown, role.limits.commands
		end
		if (commandLimits[from] or 0) > (limit or math.huge) then
			_K.systemNotify(from, `<b>Command usage on cooldown!</b>`, true)
			return false
		end
	end

	local ok, result = Process.prepareCommands(_K, from, rawText)

	local commandsRan = {}
	local commandErrors = {}

	if ok then
		for index, command in result do
			local _ok, err = command:run()
			if err then
				local escapedError = _K.Util.String.escapeRichText(err)
				table.insert(commandErrors, `<b>"{command.alias}" command failed:</b> {escapedError}`)
			else
				table.insert(commandsRan, command)
			end
			if _K.IsServer and limit then
				if not commandLimits[from] then
					commandLimits[from] = 0
					task.delay(cooldown, resetLimit, from)
				end
				commandLimits[from] += 1
				if commandLimits[from] > limit then
					local notRan = {}
					for _ = index, #result do
						table.insert(notRan, command.alias)
					end
					local appendText = if #notRan == 0 then "" else `\nCommands not ran: {table.concat(notRan, ", ")}`
					_K.systemNotify(from, `<b>Command limit reached!</b>{appendText}`, true)
					break
				end
			end
		end

		Hook.runPreparedCommands:Fire(from, result, rawText)
	else
		table.insert(commandErrors, result)
	end

	if #commandErrors > 0 then
		local commandError = `{table.concat(commandErrors, "\n")}`
		if _K.IsServer then
			local player = _K.Service.Players:GetPlayerByUserId(from)
			if player then
				_K.Remote.Notify:FireClient(
					player,
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
				From = "_K",
				Text = commandError,
				TextColor3 = Color3.new(1, 0, 0),
				Sound = "Call_Leave",
			})
			for _, err in commandErrors do
				_K.log(err, "ERROR", from)
			end
		end
	end

	if _K.IsClient and #commandsRan > 0 then
		local prefix = _K.getCommandPrefix(from)
		local commandStrings, runOnServer = {}, false
		for _, command in commandsRan do
			if not command.definition.run then
				continue
			end
			runOnServer = true
			local last = command.array[#command.array]
			table.insert(commandStrings, string.sub(rawText, command.array[1][1], last[1] + #last[2]))
		end
		if runOnServer then
			_K.Remote.Command:FireServer(`{prefix}{table.concat(commandStrings, " " .. prefix)}`)
		end
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
			local index, log, tasks = 1, {}, Util.Tasks.new()
			local prefix = _K.getCommandPrefix()
			for _, command in commandsRan do
				if command.definition.noLog or (_K.IsClient and not command.definition.runClient) then
					continue
				end
				log[index] = prefix .. command.alias
				index += 1
				for _, arg in command.args do
					local position = index
					tasks:add(function()
						local argString = Util.Table.concat(arg.parsedArgs, ",")
						if arg.rawType.filterLog and _K.IsServer then
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
			if #trimmed == 0 then
				return
			end
			logText = if _K.IsServer then Util.String.filterForBroadcast(trimmed, from) else trimmed
		end

		_K.log(logText or "", "COMMAND", from)
	end)

	return #commandErrors == 0
end

return Process
