--!optimize 2

local Shared = script.Parent

local Auth = require(Shared:WaitForChild("Auth"))
local Data = require(Shared.Data:WaitForChild("Defaults"))
local Hook = require(Shared:WaitForChild("Hook"))
local Registry = require(Shared:WaitForChild("Registry"))
local Util = require(Shared:WaitForChild("Util"))
local Command = require(script:WaitForChild("Command"))
local Type = require(Shared:WaitForChild("Type"))

type ArgumentType = Type.ArgumentType
type ArgumentDefinition = Type.ArgumentDefinition

--- @class Process
local Process = {
	ignoreFormat = `"\`%%$%%%%^%%*%%.%%+%%-%%(%%)%%[%%]\{\}%%p`,
}

--[=[
	Adds a filter that every command passes before it runs on this side, synchronously in Command:run before command
	requests are split off. `filter(command)` returns true to let it run, or false and a reason to cancel it, and may
	drop targets with `command:dropTarget(argIndex, player)`. It must not yield. A filter that errors cancels the
	command. Returns a function that removes the filter.

	Unlike the preCommand hook, which only observes, a filter can stop a command.
]=]
function Process.addCommandFilter(filter: (command: any) -> (boolean, string?)): () -> ()
	assert(type(filter) == "function", "Command filter must be a function")
	table.insert(Command.filters, filter)
	return function()
		local index = table.find(Command.filters, filter)
		if index then
			table.remove(Command.filters, index)
		end
	end
end

--- Parses a string into a raw command format.
function Process.rawParse(message: string, prefixes: { string }, delimiter: string): { any }?
	local escapedSplit = Util.String.escapePattern(delimiter)
	local commandFormat = '%s[^%s"`,%s]'
	local commandStart, prefix
	for _, value in prefixes do
		local escapedPrefix = Util.String.escapePattern(value)
		commandStart = string.find(message, string.format(commandFormat, escapedPrefix, escapedPrefix, escapedSplit))
		if commandStart then
			prefix = value
			break
		end
	end
	if not prefix then
		return
	end

	local batchIgnore = string.format(`[%s{Process.ignoreFormat}%s]`, Util.String.escapePattern(prefix), escapedSplit)
	message = string.sub(message, commandStart + #prefix)

	local len, invalidPos = utf8.len(message)
	if not len then
		message = string.sub(message, invalidPos - 1)
	end

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
		elseif char == prefix and (string.find(lastChar, "%s") or string.find(lastChar, delimiter, 1, true)) then
			if
				#argument == 1
				or string.find(argument[2] :: string, "%s")
				or string.find(argument[2] :: string, delimiter, 1, true)
			then
				table.remove(command)
			elseif string.find(lastChar, "%s") then
				table.remove(argument)
			end
			argument = { first + 1 }
			command = { argument }
			table.insert(commands, command)
		elseif char == "`" or char == '"' then
			quote = char
			if string.find(lastChar, delimiter, 1, true) then
				if #argument == 1 then
					argument[1], argument[2] = first, char
				else
					argument = { first, char }
					table.insert(command, argument)
				end
			else
				table.insert(argument, char)
			end
		elseif string.find(char :: string, delimiter, 1, true) and not string.find(lastChar, delimiter, 1, true) then
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

local commandLimits = {}
local function resetLimit(from: number)
	commandLimits[from] = nil
end

function Process.resetLimit(from: number)
	commandLimits[from] = nil
end

function Process.onCooldown(_K: any, from: number): boolean
	if not _K.IsServer then
		return false
	end
	local _rank, role = _K.Auth.getRank(from)
	local limit = role and role.limits and role.limits.commands
	return (commandLimits[from] or 0) >= (limit or math.huge)
end

function Process.countCommand(_K: any, from: number, amount: number?)
	if not _K.IsServer then
		return
	end
	local _rank, role = _K.Auth.getRank(from)
	local limits = role and role.limits
	if limits and limits.commands then
		if not commandLimits[from] then
			commandLimits[from] = 0
			task.delay(limits.cooldown, resetLimit, from)
		end
		commandLimits[from] += amount or 1
	end
end

function Process.prepareCommands(_K: any, from: number, rawText: string, global: boolean?)
	if not utf8.len(rawText) then
		return false, "Invalid utf8 string"
	end

	if _K.IsServer and #rawText > 1024 and not _K.Auth.hasRestrictedRole(from) then
		rawText = string.sub(rawText, 1, 1024)
	end

	local text = Util.String.trimStart(rawText)
	local rawCommands = Process.rawParse(
		text,
		-- global command strings are published with the server prefix, a sender's own prefix in their text isn't one
		if global then { _K.getCommandPrefix() } else { _K.getCommandPrefix(from), unpack(_K.Data.settings.prefix) },
		_K.Data.settings.splitKey or " "
	)
	if not rawCommands then
		return
	end

	local maxPrepare = math.huge
	if _K.IsServer then
		local _rank, role = _K.Auth.getRank(from)
		local limit = role and role.limits and role.limits.commands
		if limit then
			maxPrepare = math.max(1, limit - (commandLimits[from] or 0))
		end
	end

	Data.targetLimits[from] = 0
	local commands = {}

	for i, commandArray in rawCommands do
		local commandText = commandArray[1][2]
		local commandAlias = string.lower(commandText)
		if i > maxPrepare then
			if i <= maxPrepare + 64 then
				table.insert(commands, { alias = commandAlias })
			end
			continue
		end

		local commandDefinition = Registry.commands[commandAlias]

		if not commandDefinition then
			return false,
				`Invalid command: {commandText}, did you mean "{Registry.suggestCommandAlias(commandAlias)}"?`,
				commands
		end

		if not Auth.hasCommand(from, commandDefinition) then
			if _K.IsClient then
				for role, roleData in Data.roles do
					if
						((role == "vip" and _K.Data.settings.vip) or roleData.gamepasses)
						and Auth.roleCanUseCommand(role, commandDefinition)
					then
						if role == "vip" and _K.Data.settings.vip then
							_K.PromptPurchaseVIP()
						elseif roleData.gamepasses[1] then
							_K.Service.Marketplace:PromptGamePassPurchase(_K.LocalPlayer, roleData.gamepasses[1])
						end
					end
				end
				-- RestrictedToRole is filled in once the client's roles load
				local role = commandDefinition.RestrictedToRole
				if role then
					return false, `"<b>{commandText}</b>" command restricted to <b>{role.name}</b>`, commands
				end
			end
			return false, `"<b>{commandText}</b>" command restricted`, commands
		end

		local command = Command.new(_K, commandAlias, commandDefinition, commandArray, from, text, global)
		command._keepTargetLimits = true
		local ok, result = command:validate()

		table.insert(commands, command)

		if not ok then
			command.Error = result
			return false, result, commands
		end
	end

	return true, commands
end

--[=[
	Parses and runs a command string from a user. On the client, commands run their client part and the ones with a
	server part are sent to the server, unless `clientOnly`: the server already runs them (chat commands) and reports
	their prepare/server errors.
]=]
function Process.runCommands(
	_K: any,
	from: number,
	rawText: string,
	noLog: boolean?,
	global: boolean?,
	clientOnly: boolean?
): boolean
	from = from or _K.creatorId

	local cooldown, limit
	if _K.IsServer then
		local _rank, role = _K.Auth.getRank(from)
		if role.limits then
			cooldown, limit = role.limits.cooldown, role.limits.commands
		end
		if (commandLimits[from] or 0) >= (limit or math.huge) then
			_K.alert(from, `<b>Command usage on cooldown!</b>`, true)
			return false
		end
		if #rawText > 1024 and not _K.Auth.hasRestrictedRole(from) then
			rawText = string.sub(rawText, 1, 1024)
		end
	end

	local ok, result, prepared = Process.prepareCommands(_K, from, rawText, global)

	local commandsRan = {}
	local commandErrors = {}

	if ok then
		Hook.runPreparedCommands:Fire(from, result, rawText)

		for index, command in result do
			-- count before running so at most `limit` commands run per cooldown
			if _K.IsServer and limit then
				if not commandLimits[from] then
					commandLimits[from] = 0
					task.delay(cooldown, resetLimit, from)
				end
				if commandLimits[from] >= limit then
					local notRan = {}
					for i = index, #result do
						table.insert(notRan, result[i].alias)
					end
					_K.alert(
						from,
						`<b>Command limit reached!</b>\nCommands not ran: {table.concat(notRan, ", ")}`,
						true
					)
					break
				end
				commandLimits[from] += 1
			end
			local _ok, err = command:run()
			if err then
				local escapedError = _K.Util.String.escapeRichText(err)
				table.insert(commandErrors, `<b>"{command.alias}" command failed:</b> {escapedError}`)
			else
				table.insert(commandsRan, command)
			end
		end
	else
		if _K.IsServer and limit then
			if not commandLimits[from] then
				commandLimits[from] = 0
				task.delay(cooldown, resetLimit, from)
			end
			commandLimits[from] += if prepared then #prepared + 1 else 1
		end
		table.insert(commandErrors, result)
	end

	if #commandErrors > 0 and not (clientOnly and not ok) then
		local commandError = `{table.concat(commandErrors, "\n")}`
		if _K.IsServer then
			local player = _K.Service.Players:GetPlayerByUserId(from)
			if player then
				_K.Remote.Notify:Fire(
					player,
					{ Text = commandError, From = "_K", TextColor3 = Color3.new(1, 0, 0), Sound = "Call_Leave" }
				)
				local level = _K.Logger:encode("ERROR")
				local now = workspace:GetServerTimeNow()
				local name = player.Name
				for _, err in commandErrors do
					_K.Remote.Log:Fire(player, { err, level, now, from, name })
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

	if _K.IsClient and #commandsRan > 0 and not clientOnly then
		local prefix = _K.getCommandPrefix(from)
		local commandStrings, runOnServer = {}, false
		for _, command in commandsRan do
			if not command.definition.run then
				continue
			end
			runOnServer = true
			local last = command.array[#command.array]
			table.insert(commandStrings, string.sub(rawText, command.array[1][1] :: number, last[1] + #last[2]))
		end
		if runOnServer then
			_K.Remote.Command:Fire(`{prefix}{table.concat(commandStrings, " " .. prefix)}`)
		end
	end

	if #commandsRan == 0 and #commandErrors == 0 then
		-- skip logging if nothing happened
		return true
	end

	local isGlobalCommand = global == true
	for _, command in commandsRan do
		if command.definition and command.definition.name == "global" then
			isGlobalCommand = true
			break
		end
	end

	task.spawn(function()
		if noLog then
			return
		end

		local logText, liveText

		if #commandsRan > 0 then
			local index, log, tasks = 1, {}, Util.Tasks.new()
			local textPositions = {}
			local prefix = _K.getCommandPrefix()
			for _, command in commandsRan do
				-- each side logs the commands it runs, chat commands reach the server with their client-only ones
				local definition = command.definition
				if definition.noLog or not definition[if _K.IsClient then "runClient" else "run"] then
					continue
				end
				log[index] = prefix .. command.alias
				index += 1
				for _, arg in command.args do
					local position = index
					if if arg.redactLog ~= nil then arg.redactLog else arg.rawType.freeText then
						table.insert(textPositions, position)
					end
					tasks:add(function()
						local argString
						if arg.rawType.log then
							argString = arg.rawType.log(arg)
						else
							argString = Util.Table.concat(arg.parsedArgs, ",")
							if arg.rawType.filterLog and arg.redactLog ~= false and _K.IsServer then
								argString = Util.String.filterForBroadcast(argString, from)
							end
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
			-- free text would let admins talk through the logs, only the sender sees it
			if #textPositions > 0 then
				for _, position in textPositions do
					log[position] = "…"
				end
				liveText = table.concat(log, " ")
			end
		else -- filter entire rawText as broadcast
			local trimmed = Util.String.trim(rawText)
			if #trimmed == 0 then
				return
			end
			logText = if _K.IsServer then Util.String.filterForBroadcast(trimmed, from) else trimmed
			-- free text that didn't run a command would let admins talk through the live logs, only show the commands
			local aliases = {}
			local prefix = _K.getCommandPrefix()
			for _, command in if ok then result else prepared or {} do
				table.insert(aliases, prefix .. command.alias)
			end
			table.insert(aliases, "…")
			liveText = table.concat(aliases, " ")
		end

		_K.log(logText or "", "COMMAND", from, nil, liveText, isGlobalCommand)
	end)

	return #commandErrors == 0
end

return Process
