local Players = game:GetService("Players")

local generateValidate = require(script:WaitForChild("generateValidate"))

local Types = script:WaitForChild("Types")

-- TODO: post random selector? "%blue team~5"
-- FIX: add a default description for autocompleting prefixes!

local _K = nil

--[[
	!	- inverse match
	*	- all
	@	- roles
		match displayname/username if no roles found?
	$	- special
	%	- teamPlayers match
		have non prefix fallback to userid if no username matched?
	$g=id=<>rank	- group/rank match
	$d=<>10			- distance match

	TODO: fallback matching for most prefixes? (in case of accidental typing)
]]

local prefixSuggestions = {
	{ "*", "*\t(Everyone)", "allPlayers", "^%*$" },
	{ "@", "@\t(Roles)", "rolePlayers", "@" },
	{ "%", "%\t(Teams)", "teamPlayers", "%%" },
	{ "~", "~\t(Random)", "randomPlayers", "~" },
	{ "$", "$\t(Special)", "specialPlayers", "%$" },
	{ "all", "all  (Everyone)", "allPlayers", "^all$" },
	{ "others", "others (Everyone else)", "otherPlayers", "^others$" },
}

local prefixes = {}
for prefixType, list in prefixSuggestions do
	prefixes[list[4]] = list[3]
	list[3], list[4] = nil, nil
end

local function nameUsed(names, name)
	for _, data in names do
		local used = if type(data) == "table" then data[1] else data
		if used == name or prefixes[name] then
			return true
		end
	end
	return false
end

local userCache = {}
local function memoizeUser(player: Player)
	if userCache[player.UserId] then
		return
	end
	userCache[player.UserId] = {
		Name = player.Name,
		DisplayName = player.DisplayName,
		UserId = player.UserId,
	}
end
local function freeUser(userId: number)
	userCache[userId] = nil
end

Players.PlayerAdded:Connect(memoizeUser)
Players.PlayerRemoving:Connect(function(player)
	task.delay(120, freeUser, player.UserId)
end)
for _, player in Players:GetPlayers() do
	memoizeUser(player)
end

local function baseSuggestions(text, from, definition, userType: boolean?)
	local players = Players:GetPlayers()
	local names, instances = {}, {}

	if not definition.ignoreSelf then
		table.insert(names, "me")
		table.insert(instances, Players.LocalPlayer)
	end

	local rank = _K.Auth.getRank(from)
	for _, player in players do
		if
			(definition.ignoreSelf and player == Players.LocalPlayer)
			or (definition.lowerRank and player ~= Players.LocalPlayer and rank <= _K.Auth.getRank(player.UserId))
		then
			continue
		end
		table.insert(names, player.Name)
		table.insert(instances, player)
	end

	if userType then
		for userId, user in userCache do
			if Players:GetPlayerByUserId(userId) then
				continue
			end
			if
				(definition.ignoreSelf and userId == from)
				or (definition.lowerRank and userId ~= from and rank <= _K.Auth.getRank(userId))
			then
				continue
			end

			table.insert(names, user.Name)
			table.insert(instances, user)
		end
	end

	-- diplayName suggestions
	for index = 1, #instances do
		local player = instances[index]
		if player.Name == player.DisplayName or nameUsed(names, player.DisplayName) then
			continue
		end
		table.insert(names, player.DisplayName)
		table.insert(instances, player)

		if typeof(player) == "Instance" then
			local kDisplay = player:GetAttribute("_KDisplayName")
			if kDisplay and not nameUsed(names, kDisplay) then
				table.insert(names, kDisplay)
				table.insert(instances, player)
			end
		end
	end

	-- add prefix suggestions
	for _, suggestion in prefixSuggestions do
		table.insert(names, suggestion)
	end

	return names, instances
end

local function parseIndividual(arg, self, userType)
	if arg == "" or arg == "me" then
		return self._K.Auth.targetUserArgument(self, self.command.from, self.command.fromPlayer)
	end

	local partial
	for _, player in Players:GetPlayers() do
		local name = string.lower(player.Name)
		if name == arg then
			return self._K.Auth.targetUserArgument(self, player.UserId, player)
		end
		if not partial and string.find(name, arg, 1, true) == 1 then
			partial = player
		end
	end

	if userType then
		print(userCache)
		for userId, user in userCache do
			local name = string.lower(user.Name)
			if name == arg then
				return self._K.Auth.targetUserArgument(self, userId, user)
			end
			if not partial and string.find(name, arg, 1, true) == 1 then
				partial = user
			end
		end
	end

	for _, player in Players:GetPlayers() do
		local displayName = string.lower(player.DisplayName)
		local kDisplay = player:GetAttribute("_KDisplayName")
		kDisplay = if type(kDisplay) == "string" then string.lower(kDisplay) else ""
		if displayName == arg or kDisplay == arg then
			return self._K.Auth.targetUserArgument(self, player.UserId, player)
		end
		if
			not partial and (string.find(displayName, arg, 1, true) == 1 or (string.find(kDisplay, arg, 1, true) == 1))
		then
			partial = player
		end
	end

	if userType then
		for userId, user in userCache do
			local displayName = string.lower(user.DisplayName)
			if displayName == arg then
				return self._K.Auth.targetUserArgument(self, userId, user)
			end
			if not partial and string.find(displayName, arg, 1, true) == 1 then
				partial = user
			end
		end
	end

	if partial then
		return self._K.Auth.targetUserArgument(self, partial.UserId, partial)
	end

	return nil, "Invalid player"
end

local typeIndividual = {
	transform = string.lower,
	validate = generateValidate(parseIndividual),
	parse = parseIndividual,
	suggestions = baseSuggestions,
	prefixes = prefixes,
}

local function parseUser(arg, self)
	local player = parseIndividual(arg, self, true)
	local userId = tonumber(if player then player.UserId else arg)
	if userId and userId > 0 then
		return self._K.Auth.targetUserArgument(self, userId, userId)
	end
	return nil, "Invalid user"
end

local typeUser = {
	transform = string.lower,
	validate = parseUser,
	parse = parseUser,
	postParse = function(parsedArgs)
		-- compile nested players from prefixes into one list, transform prefix results to userId
		local users = {}
		for _, arg in parsedArgs do
			if type(arg) == "table" then
				for _, user in arg do
					local userId = if type(user) == "table" or (typeof(user) == "Instance" and user:IsA("Player"))
						then user.UserId
						else user
					table.insert(users, userId)
				end
			else
				local userId = if type(arg) == "table" or (typeof(arg) == "Instance" and arg:IsA("Player"))
					then arg.UserId
					else arg
				table.insert(users, userId)
			end
		end
		return users
	end,
	suggestions = function(text, from, definition)
		return baseSuggestions(text, from, definition, true)
	end,
	prefixes = prefixes,
}

return function(context)
	_K = context

	_K.Registry.registerType("player", typeIndividual)
	_K.Registry.registerType("players", {
		listable = true,
		postParse = function(parsedArgs)
			-- compile nested players from prefixes into one list
			local players = {}
			for _, arg in parsedArgs do
				if type(arg) == "table" then
					for _, player in arg do
						table.insert(players, player)
					end
				else
					table.insert(players, arg)
				end
			end
			return players
		end,
	}, typeIndividual)

	_K.Registry.registerType("userId", typeUser)
	_K.Registry.registerType("userIds", { listable = true }, typeUser)

	for _, child in Types:GetChildren() do
		if child:IsA("ModuleScript") then
			require(child)(_K)
		end
	end
end
