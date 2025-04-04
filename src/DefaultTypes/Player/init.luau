local Players = game:GetService("Players")

local generateValidate = require(script:WaitForChild("generateValidate"))
local sanitizePlayer = require(script:WaitForChild("sanitizePlayer"))
local sanitizeUser = require(script:WaitForChild("sanitizeUser"))

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
	{ "*", "*\t(Everyone)", "allPlayers" },
	{ "@", "@\t(Roles)", "rolePlayers" },
	{ "%", "%\t(Teams)", "teamPlayers" },
	{ "~", "~\t(Random)", "randomPlayers" },
	{ "$", "$\t(Special)", "specialPlayers" },
	{ "all", "all  (Everyone)", "allPlayers" },
	{ "others", "others (Everyone else)", "otherPlayers" },
}

local prefixes = {}
for prefixType, list in prefixSuggestions do
	prefixes[list[1]] = list[3]
	list[3] = nil
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

local function baseSuggestions(text, from, definition)
	local players = Players:GetPlayers()
	local names, instances = {}, {}
	-- add me suggestion
	if not definition.ignoreSelf then
		table.insert(names, "me")
		table.insert(instances, Players.LocalPlayer)
	end

	-- filter out lowerRank and ignoreSelf
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

	-- diplayName suggestions
	for index = 1, #instances do
		local player = instances[index]
		-- hide duplicate suggestions
		if player.Name == player.DisplayName or nameUsed(names, player.DisplayName) then
			continue
		end
		table.insert(names, player.DisplayName)
		table.insert(instances, player)
	end

	-- add prefix suggestions
	for _, suggestion in prefixSuggestions do
		table.insert(names, suggestion)
	end

	return names, instances
end

local function parseIndividual(arg, self)
	if arg == "" or arg == "me" then
		return sanitizePlayer(self, self.command.fromPlayer)
	end
	for _, player in Players:GetPlayers() do
		if string.find(string.lower(player.Name), arg, 1, true) == 1 then
			return sanitizePlayer(self, player)
		end
	end
	for _, player in Players:GetPlayers() do
		if string.find(string.lower(player.DisplayName), arg, 1, true) == 1 then
			return sanitizePlayer(self, player)
		end
	end
	return
end

local typeIndividual = {
	transform = string.lower,
	validate = generateValidate(parseIndividual),
	parse = parseIndividual,
	log = function(arg)
		return _K.Util.Table.concat(arg.parsedArgs, ",")
	end,
	suggestions = function(text, from, definition)
		return _K.Util.Suggest.query(text, baseSuggestions(text, from, definition))
	end,
	prefixes = prefixes,
}

local typeMultiple = {
	listable = true,
	transform = string.lower,
	validate = typeIndividual.validate,
	parse = parseIndividual,
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
	log = typeIndividual.log,
	prefixes = prefixes,
	suggestions = typeIndividual.suggestions,
}

local function parseUser(arg, self)
	local player = parseIndividual(arg, self)
	local userId = tonumber(if player then player.UserId else arg)
	if userId and userId > 0 then
		return sanitizeUser(self, userId)
	end
	return nil, "Invalid user"
end

local typeUser = {
	transform = string.lower,
	validate = parseUser,
	parse = parseUser,
	postParse = function(parsedArgs)
		-- compile nested players from prefixes into one list, transform prefix results to userId
		local players = {}
		for _, arg in parsedArgs do
			if type(arg) == "table" then
				for _, player in arg do
					table.insert(
						players,
						if typeof(player) == "Instance" and player:IsA("Player") then player.UserId else player
					)
				end
			else
				table.insert(players, if typeof(arg) == "Instance" and arg:IsA("Player") then arg.UserId else arg)
			end
		end
		return players
	end,
	suggestions = typeIndividual.suggestions,
	log = typeIndividual.log,
	prefixes = prefixes,
}

return function(context)
	_K = context

	_K.Registry.registerType("player", typeIndividual)
	_K.Registry.registerType("players", typeMultiple)

	_K.Registry.registerType("userId", typeUser)
	_K.Registry.registerType("userIds", { listable = true }, typeUser)

	for _, child in Types:GetChildren() do
		if child:IsA("ModuleScript") then
			require(child)(_K)
		end
	end
end
