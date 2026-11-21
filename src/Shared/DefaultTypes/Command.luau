return function(_K)
	local commandType = {
		transform = function(text)
			local query = string.lower(text)
			local exactMatch = _K.Registry.commands[query]
			if exactMatch and exactMatch.LocalPlayerAuthorized then
				return exactMatch
			end
			local substringMatch
			for _, name in _K.Registry.commandNames do
				local command = _K.Registry.commands[name]
				if command and command.LocalPlayerAuthorized then
					local found = string.find(name, query, 1, true)
					if found == 1 then
						return command
					elseif found and not substringMatch then
						substringMatch = command
					end
				end
			end
			return substringMatch
		end,

		validate = function(command)
			return if command then true else false, "No command with that name could be found."
		end,

		suggestions = function(text)
			if _K.client.settings.onlyShowUsableCommands:peek() then
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
