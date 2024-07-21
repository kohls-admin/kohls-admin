local context

local typeRole = {
	validate = function(input: string, from: number): (boolean, string?)
		local query = string.lower(input)
		local rank = context.Auth.getRank(from)
		for roleName, role in context.Auth.roles do
			if rank > role._rank and string.find(string.lower(roleName), query) == 1 then
				return true
			end
		end
		return false, "Invalid role."
	end,
	parse = function(input: string, from: number): string
		local query = string.lower(input)
		local rank = context.Auth.getRank(from)
		for roleName, role in context.Auth.roles do
			if rank > role._rank and string.find(string.lower(roleName), query) == 1 then
				return roleName
			end
		end
		error("Invalid role value")
	end,
	suggestions = function(text: string, from: number)
		local names = {}
		local rank = context.Auth.getRank(from)
		for roleName, role in context.Auth.roles do
			if rank > role._rank then
				names[roleName] = roleName
			end
		end
		return context.Util.querySuggestions(text, names, context.Auth.roles)
	end,
}

local typeRoles = {
	listable = true,
}

return function(_K)
	context = _K
	_K.Registry.registerType("role", typeRole)
	_K.Registry.registerType("roles", typeRoles, typeRole)
end
