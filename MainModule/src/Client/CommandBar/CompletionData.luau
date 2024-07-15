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

	local rawCommands = _K.Process.rawParse(_K.Util.trimStart(message), _K.settings.prefix:get())
	if not rawCommands then
		table.insert(data.invalid, { 2, string.sub(message, 2), "Invalid command" })
		return data -- invalid command string, show valid example
	end

	local greedy
	for _, commandArray in rawCommands do
		if greedy then
			continue
		end
		local commandDefinition = _K.Registry.commands[string.lower(commandArray[1][2])]
		local lastArg = commandArray[#commandArray]

		local lastArgDefinition = commandDefinition and commandDefinition.args[#commandDefinition.args]
		greedy = lastArgDefinition and lastArgDefinition.type == "stringGreedy"

		if commandDefinition and not _K.Auth.hasCommandGroup(Players.LocalPlayer.UserId, commandDefinition.group) then
			table.insert(data.invalid, { 2, string.sub(message, 2), "Invalid permissions" })
			return data
		end

		-- TODO: if within greedy and cursor not within command array we need to set the argpos

		if cursorPosition < commandArray[1][1] or cursorPosition > lastArg[1] + #lastArg[2] then
			if not commandDefinition then
				data.argPos = 2
				data.argIndex = 1
				data.query = commandArray[1][2]
				data.rawArg = data.query
				table.insert(data.invalid, { data.argPos, string.sub(message, data.argPos), "Invalid command" })
				return data
			end
			if greedy and cursorPosition > lastArg[1] + #lastArg[2] then
				data.argPos = lastArg[1]
				data.argIndex = #commandArray
				data.query = string.sub(message, data.argPos)
				data.rawArg = data.query
				data.suggestionType = _K.Registry.types.stringGreedy
			end
			continue -- cursor not within commandArray
		end
		data.commandDefinition = commandDefinition

		for i, arg in commandArray do
			local argPos, rawArg = unpack(arg)
			-- FIX: need to validate every command/argument even if not in cursor...
			local query = string.sub(rawArg, 1, cursorPosition - argPos)
			local cursorOutsideArg = cursorPosition < argPos or cursorPosition > argPos + #rawArg

			if i == 1 then -- command suggestions
				if cursorOutsideArg then
					continue
				end
				data.argIndex = i
				data.argPos = argPos
				data.query = query
				data.rawArg = rawArg
				data.suggestionType = _K.Registry.types.command
				data.suggestions = _K.Registry.types.command.suggestions(query, Players.LocalPlayer)

				local invalidPermissions = nil
				local oldSuggestions = data.suggestions
				data.suggestions = table.create(#data.suggestions)
				for i, suggestionData in oldSuggestions do
					local name, command = unpack(suggestionData)
					print("invalidperms", query, name, command)
					if invalidPermissions ~= false and string.lower(query) == string.lower(name) then
						invalidPermissions = true
					end
					if command and _K.Auth.hasCommandGroup(Players.LocalPlayer.UserId, command.group) then
						invalidPermissions = false
						table.insert(data.suggestions, suggestionData)
					end
				end
				if invalidPermissions then
					table.insert(data.invalid, { argPos, rawArg, "Invalid permissions" })
					return data
				end
				if #data.suggestions < 1 then
					table.insert(data.invalid, { argPos, string.sub(message, 2), "Invalid command" })
					return data
				end
			else
				-- validate command
				if not commandDefinition then
					-- invalid command feedback
					data.argIndex = 1
					data.argPos, data.rawArg = unpack(commandArray[1])
					data.query = data.rawArg
					data.suggestionType = _K.Registry.types.command
					table.insert(data.invalid, { data.argPos, data.rawArg, "Invalid command" })
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
				data.argIndex = i
				data.argPos = argPos
				data.query = query
				data.rawArg = rawArg
				data.argDefinition = argDefinition
				data.suggestionType = rawType

				local transformedArgs, transformedTypes = unpack(result)
				-- TODO: account for transformed type suggestions and listable types (like players)
				local transformPos = argPos
				for k, transformedArg in transformedArgs do
					local rawTransformArg = rawArgs[k]
					local transformedType = transformedTypes[k]
					data.suggestionType = transformedType
					local pos = transformPos
					transformPos += #rawTransformArg + 1
					-- cursor within this transformedArg
					if cursorPosition < pos or (not greedy and cursorPosition > transformPos) then
						continue
					end
					if not transformedType.suggestions then
						continue -- no suggestions for this type  TODO: (make sure to still show tool hint)
					end
					-- data.query = transformedArg
					data.argPos = pos
					data.rawArg = rawTransformArg
					data.transformedArg = transformedArg
					data.query = string.sub(rawTransformArg, 1, cursorPosition - pos)
					data.suggestions = transformedType.suggestions(data.query, Players.LocalPlayer)
					break
				end
			end
		end
	end

	return data
end
