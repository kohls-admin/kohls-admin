return function(_K)
	local commandType = {
		transform = function(text)
			return _K.Registry.commands[string.lower(text)]
		end,

		validate = function(command)
			return if command then true else false, "No command with that name could be found."
		end,

		suggestions = function(text)
			-- TODO: create and cache command names every time a new command is added (debounced)
			local names = {}
			for alias in _K.Registry.commands do
				names[alias] = alias
			end
			return _K.Util.Suggest.query(text, names, _K.Registry.commands)
		end,

		parse = function(command)
			return command
		end,
		log = function(arg)
			return _K.Util.Table.concat(arg.parsedArgs, ",")
		end,
	}

	_K.Registry.registerType("command", commandType)
end
