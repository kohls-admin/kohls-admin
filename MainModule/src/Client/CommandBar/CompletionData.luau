local Players = game:GetService("Players")

return function(_K, message, cursorPosition)
	local data = {
		message = message,
		cursorPosition = cursorPosition,
		invalid = {
			-- {argPos, rawArg, text}
		},
	}

	if message == _K.settings.prefix:get() then
		data.query = ""
		data.rawArg = ""
		data.argPos = 2
		data.argIndex = 0
		data.suggestionType = "History"
		-- data.suggestions = {}
		-- for alias, value in _K.Registry.commands do
		-- 	table.insert(data.suggestions, { alias, value })
		-- end
		return data
	end

	local rawCommands = _K.Process.rawParse(_K.Util.trimStart(message), _K.settings.prefix:get())
	if not rawCommands then
		table.insert(data.invalid, { 1, message, "Invalid command" })
		return data -- invalid command string, show valid example
	end

	local greedy
	for _, commandArray in rawCommands do
		if greedy then
			continue
		end
		local commandDefinition = _K.Registry.commands[string.lower(commandArray[1][2])]
		local lastArg = commandArray[#commandArray]

		if cursorPosition < commandArray[1][1] or cursorPosition > lastArg[1] + #lastArg[2] then
			continue -- cursor not within commandArray
		end

		local lastArgDefinition = commandDefinition and commandDefinition.args[#commandDefinition.args]
		greedy = lastArgDefinition and lastArgDefinition.type == "stringGreedy"

		for i, arg in commandArray do
			local argPos, rawArg = unpack(arg)
			-- FIX: need to validate every command/argument even if not in cursor...
			local query = string.sub(rawArg, 1, cursorPosition - argPos)
			local cursorOutsideArg = cursorPosition < argPos or cursorPosition > argPos + #rawArg
			data.query = query
			data.rawArg = rawArg
			data.argPos = argPos
			data.argIndex = i
			data.commandDefinition = commandDefinition

			if i == 1 then -- command suggestions
				if cursorOutsideArg then
					continue
				end
				data.suggestionType = _K.Registry.types.command
				data.suggestions = _K.Registry.types.command.suggestions(query)
				if #data.suggestions < 1 then
					table.insert(data.invalid, { argPos, rawArg, "Invalid command" })
					return data
				end
			else
				-- validate command
				if not commandDefinition then
					-- invalid command feedback
					table.insert(data.invalid, { argPos, rawArg, "Invalid command" })
					return data
				end
				local argDefinition = commandDefinition.args[i - 1]
				-- complete argument
				if not argDefinition then
					if greedy then
						continue -- skip completion and don't invalidate
					end
					table.insert(data.invalid, { argPos, rawArg, "Too many arguments" })
					return data
				end
				data.argDefinition = argDefinition
				local rawType, rawArgs = _K.Process.initArgument(argDefinition, rawArg)
				local ok, result = _K.Process.validateArgument(argDefinition, Players.LocalPlayer, rawType, rawArgs)
				-- invalid argument
				-- FIX: need transformArgPos from validateArgument to show invalid listables separately!
				if not ok then
					table.insert(data.invalid, { argPos, rawArg, result })
					return data
				end

				if cursorPosition < argPos or (not greedy and cursorPosition > argPos + #rawArg) then
					continue -- not within cursor
				end

				local transformedArgs, transformedTypes = unpack(result)

				-- TODO: account for transformed type suggestions and listable types (like players)
				local transformPos = argPos
				for k, transformedArg in transformedArgs do
					local transformedType = transformedTypes[k]
					data.suggestionType = transformedType
					local pos = transformPos
					transformPos += #transformedArg + 1
					print(argPos, pos, pos + #transformedArg, cursorPosition)
					-- cursor within this transformedArg
					print(cursorPosition < pos, cursorPosition > transformPos)
					if cursorPosition < pos or cursorPosition > pos + #transformedArg then
						continue
					end
					if not transformedType.suggestions then
						continue -- no suggestions for this type  TODO: (make sure to still show tool hint)
					end
					-- data.query = transformedArg
					data.argPos = pos
					data.rawArg = transformedArg
					data.query = string.sub(transformedArg, 1, cursorPosition - pos)
					data.suggestions = transformedType.suggestions(data.query, Players.LocalPlayer)
				end
			end
		end
	end

	return data
end
