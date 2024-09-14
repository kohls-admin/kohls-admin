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
			-- {feedback, argPos, rawArg}
		},
	}

	local prefix = _K.playerPrefix[from] or _K.Data.settings.prefix

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
		table.insert(data.invalid, { "Invalid command1", 2, string.sub(text, 2) })
		return data -- invalid command string, show valid example
	end

	local greedy
	for _, commandArray in rawCommands do
		local commandPos, commandText = unpack(commandArray[1])
		local commandAlias = string.lower(commandText)
		local commandDefinition = _K.Registry.commands[commandAlias]

		local lastArgDefinition = commandDefinition and commandDefinition.args[#commandDefinition.args]
		local lastArg = commandArray[#commandArray]
		local commandEnd = lastArg[1] + #lastArg[2]

		if commandDefinition and not (greedy or _K.Auth.hasCommand(from, commandDefinition)) then
			table.insert(data.invalid, { "Invalid permissions", 2, string.sub(text, 2) })
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
					"Too many arguments",
					lastDefined[1] + #lastDefined[2],
					string.sub(text, lastDefined[1] + #lastDefined[2], lastArg[1] + #lastArg[2]),
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
				table.insert(data.invalid, { "Invalid command2", commandPos, commandText })
				return data
			elseif commandDefinition then
				local command = Command.new(_K, commandAlias, commandDefinition, commandArray, from, text)
				command:validate()
				table.insert(data.commands, command)
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
		end

		-- within command
		-- command suggestions
		if cursorPosition <= commandPos + #commandText then
			data.argIndex = 1
			data.argPos = commandPos
			data.rawArg = commandText
			data.query = string.sub(commandText, 1, cursorPosition - commandPos)
			data.suggestionType = _K.Registry.types.command
			data.suggestions = _K.Registry.types.command.suggestions(data.query, from)

			if #data.suggestions < 1 then
				table.insert(data.invalid, { "Invalid command3", commandPos, commandText })
				return data
			end

			local rawSuggestions = data.suggestions
			data.suggestions = table.create(#data.suggestions)
			for _, suggestionData in rawSuggestions do
				local _name, cmd = unpack(suggestionData)
				if cmd and _K.Auth.hasCommand(from, cmd) then
					table.insert(data.suggestions, suggestionData)
				end
			end

			if #data.suggestions < 1 then
				table.insert(data.invalid, { "Invalid permissions", commandPos, commandText })
				return data
			end

			if commandDefinition then
				local command = Command.new(_K, commandAlias, commandDefinition, commandArray, from, text)
				command:validate()
				table.insert(data.commands, command)
			end

			return data
		end

		if not commandDefinition then
			table.insert(data.invalid, { "Invalid command4", commandPos, commandText })
			return data
		end

		data.commandDefinition = commandDefinition

		local command = Command.new(_K, commandAlias, commandDefinition, commandArray, from, text)
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
				data.suggestions = transformedType.suggestions(data.query, from, arg.definition)
			end
		end

		if
			not ok
			and not (
				data.suggestionType
				and (
					data.rawArg == ""
					or (
						data.suggestions
						and #data.suggestions > 0
						and if type(data.suggestions[1]) == "table"
							then data.suggestions[1][1] ~= data.rawArg
							else data.suggestions[1] ~= data.rawArg
					)
				)
			)
		then
			command.Error = result
			if command.invalidArg then
				if not command.argMissing then
					table.insert(data.invalid, { result, command.invalidPos, command.invalidArg })
				end
			else
				table.insert(data.invalid, { result, commandPos, string.sub(text, commandPos, commandEnd) })
			end
			return data
		end
	end

	return data
end
