local _K

local typeRole = {
	validate = function(input: string, self: any): (boolean, string?)
		local query = string.lower(input)
		local rank = _K.Auth.getRank(self.command.from)
		for roleName, role in _K.Data.roles do
			if role == _K.Data.defaultRole then
				continue
			end
			if rank > role._rank and string.find(string.lower(roleName), query) == 1 then
				return true
			end
		end
		return false, "Invalid role."
	end,
	parse = function(input: string, self: any): string
		local query = string.lower(input)
		local rank = _K.Auth.getRank(self.command.from)
		for roleName, role in _K.Data.roles do
			if role == _K.Data.defaultRole then
				continue
			end
			if rank > role._rank and string.find(string.lower(roleName), query) == 1 then
				return roleName
			end
		end
		error("Invalid role value")
	end,
	suggestions = function(text: string, from: number)
		local names = {}
		local rank = _K.Auth.getRank(from)
		for roleName, role in _K.Data.roles do
			if role == _K.Data.defaultRole then
				continue
			end
			if rank > role._rank then
				names[roleName] = roleName
			end
		end
		return _K.Util.Suggest.query(text, names, _K.Data.roles)
	end,
}

local typeRoles = {
	listable = true,
}

return function(context)
	_K = context
	_K.Registry.registerType("role", typeRole)
	_K.Registry.registerType("roles", typeRoles, typeRole)
end
