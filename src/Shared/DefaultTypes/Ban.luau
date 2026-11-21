local _K

local function canUnban(userId: string, ban: any, self: any)
	local from = self.command.from
	local savedBan = ban and ban[3] and (ban[3] < 0 or ban[3] > os.time())
	if
		(not ban or savedBan)
		and from ~= _K.Data.creatorId
		-- banasync includes admin, and only developers change saved bans, as in Auth.unbanUsers
		and (not _K.Auth.hasPermission(from, "banasync") or not _K.Auth.hasRestrictedRole(from))
	then
		return nil, "No permission to unban saved bans"
	end
	local numId = tonumber(userId)
	if not numId then
		return nil, "Invalid ban."
	end
	return self._K.Auth.targetUserArgument(self, numId, userId)
end

local function parseBan(input, self)
	local query = string.lower(input)
	local exactBan = _K.Data.bans[query]
	if exactBan then
		return canUnban(query, exactBan, self)
	end
	local partial
	for userId, ban in _K.Data.bans do
		local name = ban[1]
		local lowerName = if name then string.lower(name) else nil
		if lowerName == query then
			return canUnban(userId, ban, self)
		end
		if
			((lowerName and string.find(lowerName, query, 1, true) == 1) or string.find(userId, query, 1, true) == 1)
			and (not partial or userId < partial)
		then
			partial = userId
		end
	end
	if partial then
		return canUnban(partial, _K.Data.bans[partial], self)
	end

	local userId = tonumber(input)
	if userId and userId > 0 and userId <= 2 ^ 53 and math.floor(userId) == userId then
		local key = tostring(userId)
		return canUnban(key, _K.Data.bans[key], self)
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
			local name = ban[1]
			if name then
				table.insert(names, { { name, userId }, `{name} [{userId}]` })
			else
				table.insert(names, { userId, `UNKNOWN [{userId}]` })
			end
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
		local target, message = canUnban(userId, ban, self)
		if target then
			table.insert(bans, userId)
		elseif not table.find(feedback, message) then
			table.insert(feedback, message)
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
