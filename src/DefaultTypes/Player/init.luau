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

local prefixes = {
	["^%*$"] = "allPlayers",
	["^all$"] = "allPlayers",
	["@"] = "rolePlayers",
	["%%"] = "teamPlayers",
	["~"] = "randomPlayers",
	["%$"] = "specialPlayers",
	["^others$"] = "otherPlayers",
}

local prefixSuggestions = {
	{ { "*", "all" }, "*  [all] (Everyone)" },
	{ "@", "@\t\t(Roles)" },
	{ "%", "%\t\t(Teams)" },
	{ "~", "~\t\t(Random)" },
	{ "$", "$\t\t(Special)" },
	{ "others", "others   (Everyone else)" },
}

local userCache = {}
local function memoizeUser(player: Player)
	if userCache[player.UserId] then
		local freeThread = userCache[player.UserId].freeThread
		if freeThread then
			pcall(task.cancel, freeThread)
		end
		return
	end
	userCache[player.UserId] = {
		Name = player.Name,
		DisplayName = player.DisplayName,
		UserId = player.UserId,
		freeThread = nil,
	}
end
local function freeUser(userId: number)
	if userCache[userId] then
		local freeThread = userCache[userId].freeThread
		if freeThread then
			pcall(task.cancel, freeThread)
		end
	end
	userCache[userId] = nil
end

Players.PlayerAdded:Connect(function(player)
	freeUser(player.UserId)
end)
Players.PlayerRemoving:Connect(function(player)
	memoizeUser(player)
	userCache[player.UserId].freeThread = task.delay(120, freeUser, player.UserId)
end)

local function sortPlayers(a, b)
	if a == Players.LocalPlayer then
		return true
	elseif b == Players.LocalPlayer then
		return false
	end
	return a.Name < b.Name
end

local function playerSuggestion(player, suggestion)
	local displayName = if player.Name ~= player.DisplayName then player.DisplayName else nil
	local kName = if player.GetAttribute then player:GetAttribute("_KDisplayName") else nil

	if kName == player.Name or kName == displayName then
		kName = nil
	end

	local suggestions = { suggestion }
	table.insert(suggestions, player.Name)
	table.insert(suggestions, displayName)
	table.insert(suggestions, kName)

	displayName = if displayName then ` [{displayName}]` else ""
	kName = if kName then ` [{kName}]` else ""

	local suggestionDisplay = if suggestion
		then `{suggestion} [{player.Name}]{displayName}{kName}`
		else `{player.Name} {displayName}{kName}`

	return { suggestions, suggestionDisplay, player }
end

local function baseSuggestions(text, from, definition, userType: boolean?)
	local players = Players:GetPlayers()
	local names = {}

	if userType then
		for userId, user in userCache do
			table.insert(players, user)
		end
	end

	table.sort(players, sortPlayers)

	if not definition.ignoreSelf then
		table.insert(names, playerSuggestion(Players.LocalPlayer, "me"))
	end

	local rank = _K.Auth.getRank(from)
	for _, player in players do
		if
			player.UserId ~= Players.LocalPlayer.UserId
			and (from == _K.creatorId or not definition.lowerRank or rank > _K.Auth.getRank(player.UserId))
		then
			table.insert(names, playerSuggestion(player))
		end
	end

	for _, suggestion in prefixSuggestions do
		table.insert(names, suggestion)
	end

	return names
end

local function parseIndividual(arg, self, userType)
	if arg == "" or arg == "me" then
		return self._K.Auth.targetUserArgument(self, self.command.from, self.command.fromPlayer)
	end

	local players = Players:GetPlayers()

	if userType then
		for userId, user in userCache do
			table.insert(players, user)
		end
	end

	table.sort(players, sortPlayers)

	local partial
	for _, player in players do
		local name = string.lower(player.Name)
		if name == arg then
			return self._K.Auth.targetUserArgument(self, player.UserId, player)
		end
		if not partial and string.find(name, arg, 1, true) == 1 then
			partial = player
		end
	end

	for _, player in players do
		local displayName = string.lower(player.DisplayName)
		local kDisplay = if userType then "" else string.lower(player:GetAttribute("_KDisplayName") or "")
		if displayName == arg or kDisplay == arg then
			return self._K.Auth.targetUserArgument(self, player.UserId, player)
		end
		if
			not partial and (string.find(displayName, arg, 1, true) == 1 or (string.find(kDisplay, arg, 1, true) == 1))
		then
			partial = player
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
		local names = baseSuggestions(text, from, definition, true)
		if tonumber(text) then
			table.insert(names, 1, { text, nil, { UserId = tonumber(text) } })
		end
		return names
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
