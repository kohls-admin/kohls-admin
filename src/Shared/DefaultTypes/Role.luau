return function(context)
	local _K = context

	local function roleIdSort(a, b)
		return _K.Data.roles[a[1]]._rank > _K.Data.roles[b[1]]._rank
	end

	local function roleParse(input: string, self: any)
		local query = string.lower(input)
		local rank = _K.Auth.getRank(self.command.from)
		for roleId, role in _K.Data.roles do
			if role == _K.Data.roles.everyone then
				continue
			end
			if
				(self.command.from == _K.creatorId or rank > role._rank)
				and string.find(string.lower(roleId), query, 1, true) == 1
			then
				return roleId
			end
		end
		return nil, "Invalid role"
	end

	local typeRole = {
		validate = roleParse,
		parse = roleParse,
		suggestions = function(text: string, from: number)
			local roles = {}
			local rank = _K.Auth.getRank(from)
			for roleId, role in _K.Data.roles do
				if role == _K.Data.roles.everyone then
					continue
				end
				if from == _K.creatorId or rank > role._rank then
					table.insert(roles, { roleId, nil, role })
				end
			end
			table.sort(roles, roleIdSort)
			return roles, _K.Data.roles
		end,
	}

	_K.Registry.registerType("role", typeRole)
	_K.Registry.registerType("roles", { listable = true }, typeRole)
end
