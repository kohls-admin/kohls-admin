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
				if string.find(string.lower(key), query, 1, true) then
					return command
				end
				if not command.aliases then
					continue
				end
				for _, alias in command.aliases do
					if string.find(string.lower(alias), query, 1, true) then
						return command
					end
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

	local function commandSort(a, b)
		if #a == #b then
			return a < b
		end
		return #a < #b
	end

	local debounceSort = _K.Util.Function.debounce(0.2, table.sort)

	local function cacheCommandNames(command)
		local name = string.lower(command.name)
		local oldCommand = table.find(commandNames, name)
		if oldCommand then
			oldCommand = _K.Registry.commands[name]
			if oldCommand.aliases then
				for _, alias in oldCommand.aliases do
					table.remove(commandNames, table.find(commandNames, alias))
				end
			end
		else
			table.insert(commandNames, name)
		end

		if command.aliases then
			for _, alias in command.aliases do
				alias = string.lower(alias)
				table.insert(commandNames, alias)
			end
		end
		debounceSort(commandNames, commandSort)
	end
	_K.Hook.commandRegistered:Connect(cacheCommandNames)
	for _, command in _K.Registry.commands do
		cacheCommandNames(command)
	end
end
