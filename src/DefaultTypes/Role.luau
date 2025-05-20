return function(context)
	local _K = context

	local typeRole = {
		validate = function(input: string, self: any): (boolean, string?)
			local query = string.lower(input)
			local rank = _K.Auth.getRank(self.command.from)
			for roleId, role in _K.Data.roles do
				if role == _K.Data.roles.everyone then
					continue
				end
				if rank > role._rank and string.find(string.lower(roleId), query, 1, true) == 1 then
					return true
				end
			end
			return false, "Invalid role."
		end,
		parse = function(input: string, self: any): string
			local query = string.lower(input)
			local rank = _K.Auth.getRank(self.command.from)
			for roleId, role in _K.Data.roles do
				if role == _K.Data.roles.everyone then
					continue
				end
				if rank > role._rank and string.find(string.lower(roleId), query, 1, true) == 1 then
					return roleId
				end
			end
			error("Invalid role value")
		end,
		suggestions = function(text: string, from: number)
			local roles = {}
			local rank = _K.Auth.getRank(from)
			for roleId, role in _K.Data.roles do
				if role == _K.Data.roles.everyone then
					continue
				end
				if rank > role._rank then
					table.insert(roles, { roleId, nil, role })
				end
			end
			table.sort(roles, _K.Auth.roleIdSort)
			return roles, _K.Data.roles
		end,
	}

	_K.Registry.registerType("role", typeRole)
	_K.Registry.registerType("roles", { listable = true }, typeRole)
end
