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

	local prefix = _K.getCommandPrefix(from)

	if text == prefix then
		data.argPos = 2
		data.argIndex = 0
		data.rawArg = ""
		data.query = ""
		data.suggestionType = "History"
		return data
	end

	local rawCommands =
		_K.Process.rawParse(text, { prefix, unpack(_K.Data.settings.prefix) }, _K.Data.settings.splitKey or "%s")
	if not rawCommands then
		table.insert(data.invalid, { "Invalid command string", 2, string.sub(text, 2) })
		return data -- invalid command string, show valid example
	end

	for _, commandArray in rawCommands do
		local commandPos, commandText = unpack(commandArray[1])
		local commandAlias = string.lower(commandText)
		local commandDefinition = _K.Registry.commands[commandAlias]
		local invalidPermissions = false

		local lastArgDefinition = commandDefinition and commandDefinition.args[#commandDefinition.args]
		local lastArg = commandArray[#commandArray]
		local commandEnd = lastArg[1] + #lastArg[2]
		local greedy = lastArgDefinition and (lastArgDefinition.type == "string" or lastArgDefinition.type == "strings")

		if commandDefinition and not commandDefinition.LocalPlayerAuthorized then
			data.invalidPermissionsCommand = commandDefinition
			invalidPermissions = true
		end

		if cursorPosition < commandArray[1][1] or cursorPosition > commandEnd then --outside current query
			if not commandDefinition and not greedy then
				data.argIndex = 1
				data.argPos = commandPos
				data.rawArg = commandText
				data.query = commandText
				local feedback =
					`Invalid command: {commandText}, did you mean "{_K.Registry.suggestCommandAlias(commandAlias)}"?`
				table.insert(data.invalid, { feedback, commandPos, commandText })
				return data
			elseif commandDefinition and commandDefinition.LocalPlayerAuthorized then
				local command = Command.new(_K, commandAlias, commandDefinition, commandArray, from, text)
				command:validate()
				table.insert(data.commands, command)
				if command.invalidArg then
					table.insert(
						data.invalid,
						{ command.argMissing or command.invalidMessage, command.invalidPos, command.invalidArg }
					)
					return data
				end
			end
			continue -- cursor not within commandArray
		end

		if cursorPosition <= commandPos + #commandText then -- within command
			data.argIndex = 1
			data.argPos = commandPos
			data.rawArg = commandText
			data.query = string.sub(commandText, 1, cursorPosition - commandPos)
			data.suggestionType = _K.Registry.types.command
			data.suggestions =
				_K.Util.Suggest.query(data.query, _K.Registry.types.command.suggestions(data.query, from))

			local rawSuggestions = data.suggestions
			data.suggestions = table.create(#data.suggestions)
			local invalidSuggestions = {}
			for _, suggestionData in rawSuggestions do
				local _name, _display, cmd = unpack(suggestionData)
				if cmd then
					if cmd.LocalPlayerAuthorized then
						table.insert(data.suggestions, suggestionData)
						data.validSuggestion = true
					else
						suggestionData[4] = true -- invalid
						table.insert(invalidSuggestions, suggestionData)
						data.invalidPermissionsCommand = cmd
					end
				end
			end

			if #invalidSuggestions > 0 then
				table.move(invalidSuggestions, 1, #invalidSuggestions, #data.suggestions + 1, data.suggestions)
			end

			if invalidPermissions then
				if
					#data.suggestions == 0
					or not string.find(string.lower(data.suggestions[1][1]), string.lower(data.query), 1, true)
				then
					table.insert(data.invalid, { "Invalid permissions", commandPos, commandText })
					return data
				end
			end

			if commandDefinition and commandDefinition.LocalPlayerAuthorized then
				local command = Command.new(_K, commandAlias, commandDefinition, commandArray, from, text)
				command:validate()
				table.insert(data.commands, command)
			end

			return data
		end

		if not commandDefinition then
			local feedback =
				`Invalid command: {commandText}, did you mean "{_K.Registry.suggestCommandAlias(commandAlias)}"?`
			table.insert(data.invalid, { feedback, commandPos, commandText })
			return data
		elseif invalidPermissions then
			table.insert(data.invalid, { "Invalid permissions", commandPos, commandText })
			return data
		end

		data.commandDefinition = commandDefinition

		local command = Command.new(_K, commandAlias, commandDefinition, commandArray, from, text)
		local ok, result = command:validate()
		table.insert(data.commands, command)

		-- argument suggestions
		for i, arg in command.args do
			local isGreedy = greedy and i == #commandDefinition.args
			if cursorPosition < arg.argPos or (not isGreedy and cursorPosition > arg.argPos + #arg.rawArg) then
				continue
			end
			data.arg = arg
			data.argIndex = i + 1
			data.argPos = arg.argPos
			data.rawArg = arg.rawArg
			data.rawQuery = string.sub(arg.rawArg, 1, cursorPosition - arg.argPos)
			data.query = _K.Util.String.stripQuotes(data.rawQuery)
			data.argDefinition = arg.definition
			data.suggestionType = arg.rawType

			if
				arg.skipped
				and cursorPosition >= arg.argPos
				and (isGreedy or cursorPosition < arg.argPos + #arg.rawArg)
			then
				data.skipped = true
				data.rawQuery = string.sub(arg.skipped, 1, cursorPosition - arg.argPos)
				data.query = _K.Util.String.stripQuotes(data.rawQuery)
				local suggestions, values = arg.rawType.suggestions, nil
				if type(suggestions) == "function" then
					suggestions, values = arg.rawType.suggestions(data.query, from, arg.definition)
				end
				data.suggestions = suggestions and _K.Util.Suggest.query(data.query, suggestions, values)
				if data.suggestions and #data.suggestions > 0 then
					break
				end
			end

			local transformPos = arg.argPos
			for k, rawArg in arg.rawArgs do
				local transformedArg = arg.transformedArgs[k]
				local transformedType = arg.transformedTypes[k]
				local pos = transformPos
				transformPos += #rawArg + 1

				if cursorPosition < pos or (not isGreedy and cursorPosition > transformPos) then
					continue
				end

				data.argPos = if arg.prefix then pos + #arg.prefix else pos
				data.rawArg = rawArg
				data.rawQuery = string.sub(rawArg, 1, cursorPosition - pos)
				data.query = _K.Util.String.stripQuotes(data.rawQuery)
				data.transformedArg = transformedArg
				data.suggestionType = transformedType or data.suggestionType
				local suggestions, values = transformedType and transformedType.suggestions, nil
				if type(suggestions) == "function" then
					suggestions, values = transformedType.suggestions(data.query, from, arg.definition)
				end
				data.suggestions = suggestions and _K.Util.Suggest.query(data.query, suggestions, values)
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
						and #data.suggestions > 1
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
