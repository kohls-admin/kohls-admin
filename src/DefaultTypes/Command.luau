return function(_K)
	local commandType = {
		transform = function(text)
			local query = string.lower(text)
			local exactMatch = _K.Registry.commands[query]
			if exactMatch and exactMatch.LocalPlayerAuthorized then
				return exactMatch
			end
			for key, command in _K.Registry.commands do
				if not command.LocalPlayerAuthorized then
					continue
				end
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
			if _K.client.settings.onlyShowUsableCommands._value then
				local filtered = {}
				for _, name in _K.Registry.commandNames do
					local command = _K.Registry.commands[name]
					if command and command.LocalPlayerAuthorized then
						table.insert(filtered, name)
					end
				end
				return filtered, _K.Registry.commands
			end
			return _K.Registry.commandNames, _K.Registry.commands
		end,

		parse = function(command)
			return command
		end,
	}

	_K.Registry.registerType("command", commandType)
end
