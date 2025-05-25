local _K

local function parseBan(input)
	local query = string.lower(input)
	for userId, ban in _K.Data.bans do
		local name = ban[1] or _K.Util.getUserInfo(userId).Username
		if not name then
			continue
		end
		if
			string.find(string.lower(name), query, 1, true) == 1
			or string.find(string.lower(userId), query, 1, true) == 1
		then
			return userId
		end
	end

	if tonumber(input) then
		return tonumber(input)
	end

	return nil, "Invalid ban."
end

local typeBan = {
	validate = parseBan,
	parse = parseBan,
	suggestions = function(text)
		local names = {}
		-- username suggestions
		for userId, ban in _K.Data.bans do
			local name = ban[1] or _K.Util.getUserInfo(userId).Username
			if not name then
				continue
			end
			table.insert(names, { name, `{name} ({userId})` })
		end
		-- userId suggestions
		for userId, ban in _K.Data.bans do
			local name = ban[1] or "UNKNOWN"
			table.insert(names, { userId, `{userId} ({name})` })
		end
		return names
	end,
}

local typeBans = {
	listable = true,
}

return function(context)
	_K = context
	_K.Registry.registerType("ban", typeBan)
	_K.Registry.registerType("bans", typeBans, typeBan)
end
