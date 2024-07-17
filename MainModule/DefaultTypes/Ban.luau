local context

local typeBan = {
	validate = function(input: string): (boolean, string?)
		local query = string.lower(input)
		for userId, ban in context.bans do
			if string.find(string.lower(ban[1]), query) == 1 or string.find(string.lower(userId), query) == 1 then
				return true
			end
		end
		return false, "Invalid ban."
	end,
	parse = function(input: string): string
		local query = string.lower(input)
		for userId, ban in context.bans do
			if string.find(string.lower(ban[1]), query) == 1 or string.find(string.lower(userId), query) == 1 then
				return userId
			end
		end
		error("Invalid ban value.")
	end,
	suggestions = function(text)
		local names = {}
		for userId, bans in context.bans do
			local name = bans[1]
			names[userId] = if string.find(name, " ") then `"{name}"` else name
		end
		return context.Util.querySuggestions(text, names, context.bans)
	end,
}

local typeBans = {
	listable = true,
}

return function(_K)
	context = _K
	_K.Registry.registerType("ban", typeBan)
	_K.Registry.registerType("bans", typeBans, typeBan)
end
