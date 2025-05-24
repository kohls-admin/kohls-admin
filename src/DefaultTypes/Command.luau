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
		a, b = _K.Registry.commands[a], _K.Registry.commands[b]
		local rankA, rankB = math.huge, math.huge
		for role, roleData in _K.Data.roles do
			if _K.Auth.roleCanUseCommand(role, a) and roleData._rank < rankA then
				rankA = roleData._rank
			end
			if _K.Auth.roleCanUseCommand(role, b) and roleData._rank < rankB then
				rankB = roleData._rank
			end
		end
		if rankA == rankB then
			return a._listIndex < b._listIndex
		else
			return rankA < rankB
		end
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
		if _K.Data.roles then
			debounceSort(commandNames, commandSort)
		end
	end
	_K.Hook.commandRegistered:Connect(cacheCommandNames)
	for _, command in _K.Registry.commands do
		cacheCommandNames(command)
	end
	task.spawn(function()
		repeat
			task.wait()
		until _K.Data.roles
		debounceSort(commandNames, commandSort)
	end)
end
