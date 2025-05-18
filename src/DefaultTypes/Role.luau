local _K

local function roleSort(a, b)
	return _K.Data.roles[a[1]]._rank > _K.Data.roles[b[1]]._rank
end

local typeRole = {
	validate = function(input: string, self: any): (boolean, string?)
		local query = string.lower(input)
		local rank = _K.Auth.getRank(self.command.from)
		for roleName, role in _K.Data.roles do
			if role == _K.Data.roles.everyone then
				continue
			end
			if rank > role._rank and string.find(string.lower(roleName), query, 1, true) == 1 then
				return true
			end
		end
		return false, "Invalid role."
	end,
	parse = function(input: string, self: any): string
		local query = string.lower(input)
		local rank = _K.Auth.getRank(self.command.from)
		for roleName, role in _K.Data.roles do
			if role == _K.Data.roles.everyone then
				continue
			end
			if rank > role._rank and string.find(string.lower(roleName), query, 1, true) == 1 then
				return roleName
			end
		end
		error("Invalid role value")
	end,
	suggestions = function(text: string, from: number)
		local roles = {}
		local rank = _K.Auth.getRank(from)
		for roleName, role in _K.Data.roles do
			if role == _K.Data.roles.everyone then
				continue
			end
			if rank > role._rank then
				table.insert(roles, { roleName, nil, role })
			end
		end
		table.sort(roles, roleSort)
		return roles, _K.Data.roles
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
