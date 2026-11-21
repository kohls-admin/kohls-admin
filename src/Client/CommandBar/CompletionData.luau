local Players = game:GetService("Players")

local Package = script.Parent.Parent.Parent

local Command = require(Package.Shared.Process:WaitForChild("Command"))

local LocalPlayer = Players.LocalPlayer

-- RestrictedToRole is filled in once roles load, so name it only when known
local function restrictedMessage(commandText: string, commandDefinition: any): string
	local role = commandDefinition.RestrictedToRole
	return if role then `"{commandText}" command restricted to {role.name}` else `"{commandText}" command restricted`
end

local function findEarliestCommandStart(_K, message: string, prefixList: { string }, delimiter: string): number?
	if delimiter == "%s" then
		delimiter = " "
	end
	local escapedSplit = _K.Util.String.escapePattern(delimiter)
	local commandFormat = '%s[^%s"`,%s]'
	local earliest: number?
	for _, value in prefixList do
		local escapedPrefix = _K.Util.String.escapePattern(value)
		local ignorePrefix = if string.find(value, "^%w") then "" else escapedPrefix
		local found = string.find(message, string.format(commandFormat, escapedPrefix, ignorePrefix, escapedSplit))
		if found and (not earliest or found < earliest) then
			earliest = found
		end
	end
	return earliest
end

return function(_K, text, cursorPosition)
	local from = LocalPlayer.UserId
	local data = {
		commands = {},
		message = text,
		cursorPosition = cursorPosition,
		hasInvalidCommand = false,
		cursorInvalid = false,
		rawCommandsCount = 0,
		invalid = {
			-- {feedback, argPos, rawArg}
		},
	}

	local prefix = _K.getCommandPrefix(from)

	if text == prefix then
		data.argPos = #prefix + 1
		data.argIndex = 0
		data.rawArg = ""
		data.query = ""
		data.suggestionType = "History"
		return data
	end

	local prefixList = { prefix, table.unpack(_K.Data.settings.prefix) }
	local splitKey = _K.Data.settings.splitKey or " "
	local rawCommands = _K.Process.rawParse(text, prefixList, splitKey)
	if not rawCommands then
		local invalidPos = 1
		for _, candidate in prefixList do
			if type(candidate) == "string" and candidate ~= "" and string.sub(text, 1, #candidate) == candidate then
				invalidPos = math.max(invalidPos, #candidate + 1)
			end
		end
		data.hasInvalidCommand = true
		data.cursorInvalid = true
		table.insert(data.invalid, { "Invalid command string", invalidPos, string.sub(text, invalidPos) })
		return data -- invalid command string, show valid example
	end

	data.rawCommandsCount = #rawCommands

	local earliestStart = findEarliestCommandStart(_K, text, prefixList, splitKey)
	if earliestStart and earliestStart > 1 then
		local leading = string.sub(text, 1, earliestStart - 1)
		local leadStart, leadEnd = string.find(leading, "%S+")
		if leadStart and leadEnd then
			local leadToken = string.sub(leading, leadStart, leadEnd)
			data.hasInvalidCommand = true
			table.insert(data.invalid, { "Invalid command string", leadStart, leadToken })
			if cursorPosition < earliestStart then
				data.cursorInvalid = true
				data.argIndex = 1
				data.argPos = leadStart
				data.rawArg = leadToken
				data.query = leadToken
			end
		end
	end

	for _, commandArray in rawCommands do
		if not commandArray[1] then
			data.hasInvalidCommand = true
			continue
		end
		local commandPos, commandText = commandArray[1][1], commandArray[1][2]
		local commandAlias = string.lower(commandText)
		local commandDefinition = _K.Registry.commands[commandAlias]

		local lastArgDefinition = commandDefinition and commandDefinition.args[#commandDefinition.args]
		local lastArgType = lastArgDefinition and _K.Registry.types[lastArgDefinition.type]
		local lastArg = commandArray[#commandArray]
		local commandEnd = lastArg[1] + #lastArg[2]
		local greedy = lastArgType ~= nil and lastArgType.freeText == true

		if cursorPosition < commandArray[1][1] or cursorPosition > commandEnd then --outside current query
			if (commandText == "" or not commandDefinition) and not greedy then
				data.hasInvalidCommand = true
				if not data.argIndex then
					data.argIndex = 1
					data.argPos = commandPos
					data.rawArg = commandText
					data.query = commandText
				end
				local feedback = if commandText == ""
					then "Invalid command"
					else `Invalid command: {commandText}, did you mean "{_K.Registry.suggestCommandAlias(
						commandAlias
					)}"?`
				table.insert(data.invalid, { feedback, commandPos, commandText })
				continue
			elseif commandDefinition then
				local command = Command.new(_K, commandAlias, commandDefinition, commandArray, from, text)
				table.insert(data.commands, command)
				if not commandDefinition.LocalPlayerAuthorized then
					data.hasInvalidCommand = true
					local message = restrictedMessage(commandText, commandDefinition)
					table.insert(data.invalid, { message, commandPos, commandText })
					continue
				end
				local ok, result = command:validate()
				if not ok then
					data.hasInvalidCommand = true
					if command.invalidArg then
						table.insert(
							data.invalid,
							{ command.argMissing or command.invalidMessage, command.invalidPos, command.invalidArg }
						)
					else
						table.insert(data.invalid, { result, commandPos, string.sub(text, commandPos, commandEnd) })
					end
					continue
				end
			end
			continue -- cursor not within commandArray
		end

		if cursorPosition <= commandPos + #commandText then -- within command suggestion
			data.argIndex = 1
			data.argPos = commandPos
			data.rawArg = commandText
			data.query = string.sub(commandText, 1, cursorPosition - commandPos)
			data.suggestionType = _K.Registry.types.command
			local rawSuggestions =
				_K.Util.Suggest.query(data.query, _K.Registry.types.command.suggestions(data.query, from))
			data.suggestions = table.create(#rawSuggestions)
			local invalidSuggestions = {}
			for _, suggestionData in rawSuggestions do
				local cmd = suggestionData[3]
				if cmd then
					if cmd.LocalPlayerAuthorized then
						table.insert(data.suggestions, suggestionData)
						data.validSuggestion = true
					else
						suggestionData[4] = true -- invalid
						table.insert(invalidSuggestions, suggestionData)
					end
				end
			end

			if #invalidSuggestions > 0 then
				_K.Util.Table.mergeList(data.suggestions, invalidSuggestions)
			end

			if commandDefinition then
				data.commandDefinition = commandDefinition
			elseif data.suggestions and data.suggestions[1] then
				data.commandDefinition = data.suggestions[1][3]
			end

			if commandDefinition then
				if commandDefinition.LocalPlayerAuthorized then
					local command = Command.new(_K, commandAlias, commandDefinition, commandArray, from, text)
					local ok = command:validate()
					if not ok and command.invalidArg and not command.argMissing then
						data.hasInvalidCommand = true
					end
					table.insert(data.commands, command)
				else
					data.hasInvalidCommand = true
					if
						#data.suggestions == 0
						or not string.find(string.lower(data.suggestions[1][1]), string.lower(data.query), 1, true)
					then
						local message = restrictedMessage(commandText, commandDefinition)
						data.cursorInvalid = true
						table.insert(data.invalid, { message, commandPos, commandText })
					end
				end
			elseif commandText ~= "" then
				local hasAuthorizedMatch = false
				if data.validSuggestion then
					local queryLower = string.lower(data.query)
					for _, s in data.suggestions do
						if not s[4] and string.find(string.lower(s[1]), queryLower, 1, true) then
							hasAuthorizedMatch = true
							break
						end
					end
				end
				if not hasAuthorizedMatch then
					data.hasInvalidCommand = true
				end
			end

			continue
		end

		if commandText == "" or not commandDefinition then
			local feedback = if commandText == ""
				then "Invalid command"
				else `Invalid command: {commandText}, did you mean "{_K.Registry.suggestCommandAlias(commandAlias)}"?`
			data.hasInvalidCommand = true
			data.cursorInvalid = true
			table.insert(data.invalid, { feedback, commandPos, commandText })
			continue
		elseif not commandDefinition.LocalPlayerAuthorized then
			local message = restrictedMessage(commandText, commandDefinition)
			data.hasInvalidCommand = true
			data.cursorInvalid = true
			table.insert(data.invalid, { message, commandPos, commandText })
			continue
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
			data.hasInvalidCommand = true
			if command.invalidArg then
				if not command.argMissing then
					data.cursorInvalid = true
					table.insert(data.invalid, { result, command.invalidPos, command.invalidArg })
				end
			else
				data.cursorInvalid = true
				table.insert(data.invalid, { result, commandPos, string.sub(text, commandPos, commandEnd) })
			end
			continue
		end
	end

	return data
end
