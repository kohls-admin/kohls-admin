local Players = game:GetService("Players")

local Command = require(script.Parent.Parent.Parent.Process.Command)

local LocalPlayer = Players.LocalPlayer

return function(_K, text, cursorPosition)
	local from = LocalPlayer.UserId
	local data = {
		commands = {},
		message = text,
		cursorPosition = cursorPosition,
		invalid = {
			-- {argPos, rawArg, text}
		},
	}

	local prefix = _K.playerPrefix[from] or _K.settings.prefix._value

	if text == prefix then
		data.argPos = 2
		data.argIndex = 0
		data.query = ""
		data.rawArg = ""
		data.suggestionType = "History"
		-- data.suggestions = {}
		-- for alias, value in _K.Registry.commands do
		-- 	table.insert(data.suggestions, { alias, value })
		-- end
		return data
	end

	local rawCommands = _K.Process.rawParse(text, prefix)
	if not rawCommands then
		table.insert(data.invalid, { 2, string.sub(text, 2), "Invalid command1" })
		return data -- invalid command string, show valid example
	end

	local greedy
	for _, commandArray in rawCommands do
		local commandPos, commandText = unpack(commandArray[1])
		local commandDefinition = _K.Registry.commands[string.lower(commandText)]

		local lastArgDefinition = commandDefinition and commandDefinition.args[#commandDefinition.args]
		local lastArg = commandArray[#commandArray]
		local commandEnd = lastArg[1] + #lastArg[2]

		if commandDefinition and not (greedy or _K.Auth.hasCommandGroup(from, commandDefinition.group)) then
			table.insert(data.invalid, { 2, string.sub(text, 2), "Invalid permissions" })
			return data
		end

		if not greedy and lastArgDefinition and lastArgDefinition.type == "stringGreedy" then
			greedy = true
		end

		if not greedy and commandDefinition and #commandArray - 1 > #commandDefinition.args then
			local lastDefined = commandArray[#commandDefinition.args + 1] or lastArg
			local finalText = string.sub(text, lastDefined[1] + #lastDefined[2])
			if string.find(finalText, `[^%s{if prefix == "%" then "%%" else prefix}]`) then
				table.insert(data.invalid, {
					lastDefined[1] + #lastDefined[2],
					string.sub(text, lastDefined[1] + #lastDefined[2], lastArg[1] + #lastArg[2]),
					"Too many arguments",
				})
				return data
			end
		end

		if cursorPosition < commandArray[1][1] or cursorPosition > commandEnd then
			if not commandDefinition and not greedy then
				data.argIndex = 1
				data.argPos = commandPos
				data.rawArg = commandText
				data.query = commandText
				table.insert(data.invalid, { commandPos, commandText, "Invalid command2" })
				return data
			end
			if greedy and cursorPosition > commandEnd then
				data.argIndex = #commandDefinition.args
				data.argPos = commandArray[math.min(#commandArray, data.argIndex + 1)][1]
				data.suggestionType = _K.Registry.types.stringGreedy
				data.query = string.sub(text, data.argPos)
				data.rawArg = data.query
				return data
			end
			continue -- cursor not within commandArray
			-- FIX: need to still validate the command for a total valid state
		end

		-- within command

		-- command suggestions
		if cursorPosition <= commandPos + #commandText then
			data.argIndex = 1
			data.argPos = commandPos
			data.rawArg = commandText
			data.query = string.sub(commandText, 1, cursorPosition - commandPos)
			data.suggestionType = _K.Registry.types.command
			data.suggestions = _K.Registry.types.command.suggestions(data.query, Players.LocalPlayer.UserId)
			-- TODO: filter for authorized commands

			if #data.suggestions < 1 then
				table.insert(data.invalid, { commandPos, commandText, "Invalid command3" })
				return data
			end

			local rawSuggestions = data.suggestions
			data.suggestions = table.create(#data.suggestions)
			for _, suggestionData in rawSuggestions do
				local name, cmd = unpack(suggestionData)
				if cmd and _K.Auth.hasCommandGroup(LocalPlayer.UserId, cmd.group) then
					table.insert(data.suggestions, suggestionData)
				end
			end

			if #data.suggestions < 1 then
				table.insert(data.invalid, { commandPos, commandText, "Invalid permissions" })
				return data
			end

			return data
		end

		if not commandDefinition then
			table.insert(data.invalid, { commandPos, commandText, "Invalid command4" })
			return data
		end

		data.commandDefinition = commandDefinition

		local command = Command.new(_K, commandDefinition, commandArray, from, text)
		local ok, result = command:validate()
		table.insert(data.commands, command)

		-- argument suggestions
		for i, arg in command.args do
			if cursorPosition < arg.argPos or cursorPosition > arg.argPos + #arg.rawArg then
				continue
			end
			data.argIndex = i + 1
			data.argPos = arg.argPos
			data.rawArg = arg.rawArg
			data.query = string.sub(arg.rawArg, 1, cursorPosition - arg.argPos)
			data.argDefinition = arg.definition
			data.suggestionType = arg.rawType

			local transformPos = arg.argPos
			for k, transformedArg in arg.transformedArgs do
				local rawArg = arg.rawArgs[k]
				local transformedType = arg.transformedTypes[k]
				local pos = transformPos
				transformPos += #rawArg + 1

				if cursorPosition < pos or (not greedy and cursorPosition > transformPos) then
					continue
				end

				if not transformedType.suggestions then
					continue
				end

				data.suggestionType = transformedType
				data.argPos = pos
				data.rawArg = rawArg
				data.transformedArg = transformedArg
				data.query = string.sub(rawArg, 1, cursorPosition - pos)
				data.suggestions = transformedType.suggestions(data.query, Players.LocalPlayer.UserId, arg.definition)
			end
		end

		if not ok and not (data.suggestionType and data.rawArg == "") then
			command.Error = result
			if command.invalidArg then
				table.insert(data.invalid, { command.invalidPos, command.invalidArg, result })
			else
				table.insert(data.invalid, { commandPos, string.sub(text, commandPos, commandEnd), result })
			end
			return data
		end
	end

	return data
end
