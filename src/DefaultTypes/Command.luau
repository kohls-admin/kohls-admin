return function(_K)
	local commandNames = {}
	local commandType = {
		transform = function(text)
			local query = string.lower(text)
			local exactMatch = _K.Registry.commands[query]
			if exactMatch then
				return exactMatch
			end
			for key, command in _K.Registry.commands do
				if string.find(key, query, 1, true) then
					return command
				end
			end
			return
		end,

		validate = function(command)
			return if command then true else false, "No command with that name could be found."
		end,

		suggestions = function(text)
			return commandNames, _K.Registry.commands
		end,

		parse = function(command)
			return command
		end,
	}

	_K.Registry.registerType("command", commandType)

	local function cacheCommandNames(command)
		local name = string.lower(command.name)
		commandNames[name] = name

		local oldCommand = _K.Registry.commands[name]
		if oldCommand then
			if oldCommand.aliases then
				for _, alias in oldCommand.aliases do
					commandNames[string.lower(alias)] = nil
				end
			end
		end

		if command.aliases then
			for _, alias in command.aliases do
				alias = string.lower(alias)
				commandNames[alias] = alias
			end
		end
	end
	_K.Hook.commandRegistered:Connect(cacheCommandNames)
	for _, command in _K.Registry.commands do
		cacheCommandNames(command)
	end
end
