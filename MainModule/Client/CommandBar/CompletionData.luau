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

		if not greedy and commandDefinition and #commandArray - 1 > #commandDefinition.args then
			local lastDefined = commandArray[#commandDefinition.args + 1] or lastArg
			table.insert(data.invalid, {
				lastDefined[1] + #lastDefined[2],
				string.sub(text, lastDefined[1] + #lastDefined[2], lastArg[1] + #lastArg[2]),
				"Too many arguments",
			})
			return data
		end

		greedy = greedy or (lastArgDefinition and lastArgDefinition.type == "stringGreedy")
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
				data.argPos = lastArg[1]
				data.argIndex = #commandArray
				data.query = string.sub(text, data.argPos)
				data.rawArg = data.query
				data.suggestionType = _K.Registry.types.stringGreedy
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
			data.suggestions = _K.Registry.types.command.suggestions(data.query, Players.LocalPlayer)
			-- TODO: filter for authorized commands

			if #data.suggestions < 1 then
				table.insert(data.invalid, { commandPos, commandText, "Invalid command3" })
				return data
			end

			local rawSuggestions = data.suggestions
			print("rawCommandSuggestions", data.suggestions)
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

		if not ok then
			command.Error = result
			if command.invalidArg then
				table.insert(data.invalid, { command.invalidPos, command.invalidArg, result })
			else
				table.insert(data.invalid, { commandPos, string.sub(text, commandPos, commandEnd), result })
			end
			return data
		end

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
				data.suggestions = transformedType.suggestions(data.query, Players.LocalPlayer)
			end
		end
	end

	return data
end

-- return function(_K, message, cursorPosition)
-- 	local data = {
-- 		message = message,
-- 		cursorPosition = cursorPosition,
-- 		invalid = {
-- 			-- {argPos, rawArg, text}
-- 		},
-- 	}
--
-- 	if message == _K.settings.prefix:get() then
-- 		data.argPos = 2
-- 		data.argIndex = 0
-- 		data.query = ""
-- 		data.rawArg = ""
-- 		data.suggestionType = "History"
-- 		-- data.suggestions = {}
-- 		-- for alias, value in _K.Registry.commands do
-- 		-- 	table.insert(data.suggestions, { alias, value })
-- 		-- end
-- 		return data
-- 	end
--
-- 	local rawCommands = _K.Process.rawParse(_K.Util.trimStart(message), _K.settings.prefix:get())
-- 	if not rawCommands then
-- 		table.insert(data.invalid, { 2, string.sub(message, 2), "Invalid command" })
-- 		return data -- invalid command string, show valid example
-- 	end
--
-- 	local greedy
-- 	for _, commandArray in rawCommands do
-- 		if greedy then
-- 			continue
-- 		end
-- 		local commandDefinition = _K.Registry.commands[string.lower(commandArray[1][2])]
-- 		local lastArg = commandArray[#commandArray]
--
-- 		local lastArgDefinition = commandDefinition and commandDefinition.args[#commandDefinition.args]
-- 		greedy = lastArgDefinition and lastArgDefinition.type == "stringGreedy"
--
-- 		if commandDefinition and not _K.Auth.hasCommandGroup(Players.LocalPlayer.UserId, commandDefinition.group) then
-- 			table.insert(data.invalid, { 2, string.sub(message, 2), "Invalid permissions" })
-- 			return data
-- 		end
--
-- 		-- TODO: if within greedy and cursor not within command array we need to set the argpos
--
-- 		if cursorPosition < commandArray[1][1] or cursorPosition > lastArg[1] + #lastArg[2] then
-- 			if not commandDefinition then
-- 				data.argPos = 2
-- 				data.argIndex = 1
-- 				data.query = commandArray[1][2]
-- 				data.rawArg = data.query
-- 				table.insert(data.invalid, { data.argPos, string.sub(message, data.argPos), "Invalid command" })
-- 				return data
-- 			end
-- 			if greedy and cursorPosition > lastArg[1] + #lastArg[2] then
-- 				data.argPos = lastArg[1]
-- 				data.argIndex = #commandArray
-- 				data.query = string.sub(message, data.argPos)
-- 				data.rawArg = data.query
-- 				data.suggestionType = _K.Registry.types.stringGreedy
-- 			end
-- 			continue -- cursor not within commandArray
-- 		end
-- 		data.commandDefinition = commandDefinition
--
-- 		for i, arg in commandArray do
-- 			local argPos, rawArg = unpack(arg)
-- 			-- FIX: need to validate every command/argument even if not in cursor...
-- 			local query = string.sub(rawArg, 1, cursorPosition - argPos)
-- 			local cursorOutsideArg = cursorPosition < argPos or cursorPosition > argPos + #rawArg
--
-- 			if i == 1 then -- command suggestions
-- 				if cursorOutsideArg then
-- 					continue
-- 				end
-- 				data.argIndex = i
-- 				data.argPos = argPos
-- 				data.query = query
-- 				data.rawArg = rawArg
-- 				data.suggestionType = _K.Registry.types.command
-- 				data.suggestions = _K.Registry.types.command.suggestions(query, Players.LocalPlayer)
--
-- 				local invalidPermissions = nil
-- 				local oldSuggestions = data.suggestions
-- 				data.suggestions = table.create(#data.suggestions)
-- 				for i, suggestionData in oldSuggestions do
-- 					local name, command = unpack(suggestionData)
-- 					print("invalidperms", query, name, command)
-- 					if invalidPermissions ~= false and string.lower(query) == string.lower(name) then
-- 						invalidPermissions = true
-- 					end
-- 					if command and _K.Auth.hasCommandGroup(Players.LocalPlayer.UserId, command.group) then
-- 						invalidPermissions = false
-- 						table.insert(data.suggestions, suggestionData)
-- 					end
-- 				end
-- 				if invalidPermissions then
-- 					table.insert(data.invalid, { argPos, rawArg, "Invalid permissions" })
-- 					return data
-- 				end
-- 				if #data.suggestions < 1 then
-- 					table.insert(data.invalid, { argPos, string.sub(message, 2), "Invalid command" })
-- 					return data
-- 				end
-- 			else
-- 				-- validate command
-- 				if not commandDefinition then
-- 					-- invalid command feedback
-- 					data.argIndex = 1
-- 					data.argPos, data.rawArg = unpack(commandArray[1])
-- 					data.query = data.rawArg
-- 					data.suggestionType = _K.Registry.types.command
-- 					table.insert(data.invalid, { data.argPos, data.rawArg, "Invalid command" })
-- 					return data
-- 				end
-- 				local argDefinition = commandDefinition.args[i - 1]
-- 				-- complete argument
-- 				if not argDefinition then
-- 					if greedy then
-- 						continue -- skip completion and don't invalidate
-- 					end
-- 					table.insert(data.invalid, { argPos, rawArg, "Too many arguments" })
-- 					return data
-- 				end
--
-- 				local rawType, rawArgs = _K.Process.initArgument(argDefinition, rawArg)
-- 				local ok, result = _K.Process.validateArgument(argDefinition, Players.LocalPlayer, rawType, rawArgs)
-- 				-- invalid argument
-- 				-- FIX: need transformArgPos from validateArgument to show invalid listables separately!
-- 				if not ok then
-- 					table.insert(data.invalid, { argPos, rawArg, result })
-- 					return data
-- 				end
--
-- 				if cursorPosition < argPos or (not greedy and cursorPosition > argPos + #rawArg) then
-- 					continue -- not within cursor
-- 				end
-- 				data.argIndex = i
-- 				data.argPos = argPos
-- 				data.query = query
-- 				data.rawArg = rawArg
-- 				data.argDefinition = argDefinition
-- 				data.suggestionType = rawType
--
-- 				local transformedArgs, transformedTypes = unpack(result)
-- 				-- TODO: account for transformed type suggestions and listable types (like players)
-- 				local transformPos = argPos
-- 				for k, transformedArg in transformedArgs do
-- 					local rawTransformArg = rawArgs[k]
-- 					local transformedType = transformedTypes[k]
-- 					data.suggestionType = transformedType
-- 					local pos = transformPos
-- 					transformPos += #rawTransformArg + 1
-- 					-- cursor within this transformedArg
-- 					if cursorPosition < pos or (not greedy and cursorPosition > transformPos) then
-- 						continue
-- 					end
-- 					if not transformedType.suggestions then
-- 						continue -- no suggestions for this type  TODO: (make sure to still show tool hint)
-- 					end
-- 					-- data.query = transformedArg
-- 					data.argPos = pos
-- 					data.rawArg = rawTransformArg
-- 					data.transformedArg = transformedArg
-- 					data.query = string.sub(rawTransformArg, 1, cursorPosition - pos)
-- 					data.suggestions = transformedType.suggestions(data.query, Players.LocalPlayer)
-- 					break
-- 				end
-- 			end
-- 		end
-- 	end
--
-- 	return data
-- end
