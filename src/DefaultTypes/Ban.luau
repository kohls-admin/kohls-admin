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
	prefixes = {
		["^%*$"] = "allBans",
		["^all$"] = "allBans",
	},
	suggestions = function(text)
		local names = { { { "*", "all" }, "*  [all] (Everyone)" } }
		for userId, ban in _K.Data.bans do
			local name = ban[1] or _K.Util.getUserInfo(userId).Username
			if not name then
				continue
			end
			table.insert(names, { { name, userId }, `{name} [{userId}]` })
		end
		return names
	end,
}

local typeBans = {
	listable = true,
}

local function parseAll(arg, self)
	local feedback = {}
	local bans = {}
	for userId, ban in _K.Data.bans do
		local message
		ban, message = self._K.Auth.targetUserArgument(self, tonumber(userId) :: number, userId)
		if ban then
			table.insert(bans, userId)
		elseif not table.find(feedback, message) then
			table.insert(feedback, userId)
		end
	end

	if #bans > 0 then
		return bans
	end

	return nil, #feedback > 0 and table.concat(feedback, "\n") or "No targetable user found"
end

local typeAll = {
	listable = true,
	transform = string.lower,
	validate = function(v, self)
		local ok, feedback = parseAll(v, self)
		return ok, feedback or "Invalid ban"
	end,
	suggestions = { { { "*", "all" }, "*  [all] (Everyone)" } },
	parse = parseAll,
}

return function(context)
	_K = context
	_K.Registry.registerType("ban", typeBan)
	_K.Registry.registerType("bans", typeBans, typeBan)
	_K.Registry.registerType("allBans", typeAll)
end
