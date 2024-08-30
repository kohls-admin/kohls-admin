local Players = game:GetService("Players")
local _Teams = game:GetService("Teams")

-- TODO: set up some nice errors for improper matching of various thingies?
-- TODO: convert lists to hashmaps to remove duplicates
-- TODO: post random selector? "%blue team~5"
-- TODO: autocomplete this haha ;(
-- TODO: add team types
--
-- FIX: add a default description for autocompleting prefixes!

local _K = nil

--[[
	need teamPlayers matching
	singular player
	magic word prefix matching for multiple players and role matching
	autocomplete is gonna be pure pain

	!	- inverse match
	*	- all
	@	- roles/self
		match displayname/username if no roles found?
	$	- magic
	%	- teamPlayers match
	#	- id match for userId
		have non prefix fallback to userid if no username matched?
	$g=id=<>rank	- group/rank match
	$d=<>10			- distance match

	TODO: fallback matching for most prefixes? (in case of accidental typing)
]]

local function genValidate(validate)
	return function(v, self)
		local ok, feedback = validate(v, self)
		return ok, feedback or "Invalid player"
	end
end

local typeInverse = {
	postParse = function(arg)
		local players = {}
		if type(arg) == "table" then
			for _, player in Players:GetPlayers() do
				local matched
				for _, player2 in arg do
					if player == player2 then
						matched = true
						break
					end
				end
				if not matched then
					table.insert(players, player)
				end
			end
		elseif typeof(arg) == "Instance" then
			for _, player in Players:GetPlayers() do
				if player ~= arg then
					table.insert(players, player)
				end
			end
		end
		return players
	end,
	prefixes = {
		["%$"] = "magicPlayers",
		["@"] = "rolePlayers",
		["%%"] = "teamPlayers",
	},
}

local directMagic = {
	others = function(player, from)
		return player ~= from
	end,
	admins = function(player)
		return _K.Data.members[player.UserId]
	end,
	nonadmins = function(player)
		return not _K.Data.members[player.UserId]
	end,
	friends = function(player, from)
		return player ~= from and player:IsFriendsWith(from)
	end,
	close = function(player, from)
		return if player.Character and from.Character
			then player:DistanceFromCharacter(from.Character.PrimaryPart.Position) <= 100
			else false
	end,
	far = function(player, from)
		return if player.Character and from.Character
			then player:DistanceFromCharacter(from.Character.PrimaryPart.Position) > 100
			else false
	end,
}

local partialMagic = {
	{
		matches = { "group", "g" },
		check = function(player: Player, _, arg: string): (boolean, string?)
			local idMatch, sign, equal, rankMatch = string.match(arg, "=(%d+)([>=<]?)(=?)(%d*)$")
			local id, rank = tonumber(idMatch), tonumber(rankMatch)
			if not id then
				return false, "Invalid group: " .. arg
			end
			if player:IsInGroup(id) then
				if not rank then
					return true
				end
				local playerRank = player:GetRankInGroup(id)
				if not playerRank then
					return false
				end
				if sign == ">" then
					return if equal then playerRank >= rank else playerRank > rank
				elseif sign == "<" then
					return if equal then playerRank <= rank else playerRank < rank
				else
					return playerRank == rank
				end
			end
			return false
		end,
	},
	{
		matches = { "distance", "dist", "d" },
		check = function(player: Player, from: Player, arg: string): (boolean, string?)
			if player.Character and from.Character then
				local sign, radiusMatch = string.match(arg, "=([><]?)=?(%d+)$")
				local radius = tonumber(radiusMatch)
				if not radius then
					return false, "Invalid distance radius: " .. arg
				end
				local pivot = from.Character:GetPivot()
				if not pivot then
					return false, `Cannot calculate distance, you need a character`
				end
				if sign == ">" then
					return player:DistanceFromCharacter(pivot.Position) > radius
				else
					return player:DistanceFromCharacter(pivot.Position) <= radius
				end
			end
			return false
		end,
	},
}

local function partialMatch(arg)
	for _, magic in partialMagic do
		for _, match in magic.matches do
			if string.find(arg, match) == 1 then
				return magic.check
			end
		end
	end
	return
end

local function magicParse(arg)
	local players = {}
	local check = directMagic[arg] or partialMatch(arg)
	for _, player in Players:GetPlayers() do
		-- TODO: handle feedback ;)
		local success, _feedback = check(player, Players.LocalPlayer)
		if success then
			table.insert(players, player)
		end
	end
	return #players > 0 and players
end

local typeMagic = {
	transform = string.lower,
	validate = genValidate(magicParse),
	parse = magicParse,
}

local function roleParse(arg, self)
	local players, valid = {}, false
	for id in _K.Auth.roles do
		if string.find(string.lower(id), arg, 1, true) == 1 then
			valid = true
			for _, player in Players:GetPlayers() do
				local userPermissions = _K.Data.members[player.UserId]
				if userPermissions and table.find(userPermissions.roles, id) then
					table.insert(players, player)
				end
			end
			break
		end
	end
	return if valid then players else false, `Invalid role`
end

local typeRoles = {
	transform = string.lower,
	validate = genValidate(roleParse),
	parse = roleParse,
	suggestions = function(text, self)
		local names = {}
		for role in next, _K.Auth.roles do
			table.insert(names, "@" .. role)
		end
		return _K.Util.Suggest.query(text, names)
	end,
}

local typeRandom = {
	transform = tonumber,
	validate = function(arg)
		return arg ~= nil and arg <= #Players:GetPlayers()
	end,
	parse = function(arg)
		local players = {}
		local list = Players:GetPlayers()
		for _ = 1, arg do
			table.insert(players, table.remove(list, math.random(#list)))
		end
		return players
	end,
}

local function parseIndividual(arg, self)
	if arg == "" or arg == "me" then
		return self.command.fromPlayer
	end
	for _, player in Players:GetPlayers() do
		if string.find(string.lower(player.Name), arg, 1, true) == 1 then
			return player
		end
	end
	return
end

local prefixes = {
	["~"] = "randomPlayers",
	["!"] = "inversePlayers",
	["$"] = "magicPlayers",
	["@"] = "rolePlayers",
	["%"] = "teamPlayers",
}

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
		if definition.ignoreSelf and player == Players.LocalPlayer then
			continue
		end
		if definition.lowerRank and player ~= Players.LocalPlayer and rank <= _K.Auth.getRank(player.UserId) then
			continue
		end
		table.insert(names, player.Name)
		table.insert(instances, player)
	end

	return names, instances
end

local typeIndividual = {
	transform = string.lower,
	validate = genValidate(parseIndividual),
	parse = parseIndividual,
	log = function(arg)
		return _K.Util.Table.concat(arg.parsedArgs, ",")
	end,
	suggestions = function(text, from, definition)
		local names, instances = baseSuggestions(text, from, definition)
		-- add all suggestion
		table.insert(names, "all")
		table.insert(names, "*")
		-- add prefix suggestions
		for prefix, name in prefixes do
			table.insert(names, prefix)
		end
		return _K.Util.Suggest.query(text, names, instances)
	end,
	-- TODO: make sure it only returns the first result?
	prefixes = {
		["~"] = "randomPlayers",
		["!"] = "inversePlayers",
		["$"] = "magicPlayers",
		["@"] = "rolePlayers",
		["%"] = "teamPlayers",
	},
}

local typeMultiple = {
	listable = true,
	validate = genValidate(function(arg, self)
		if arg == "*" or arg == "all" then
			return true
		end
		return parseIndividual(arg, self)
	end),
	preParse = function(transformedArgs)
		return if table.find(transformedArgs, "*") or table.find(transformedArgs, "all")
			then Players:GetPlayers()
			else nil
	end,
	parse = function(arg, self)
		if type(arg) == "string" then
			return parseIndividual(arg, self)
		end
		return arg
	end,
	postParse = function(parsedArgs)
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
}

local function parseId(arg, self)
	local player = parseIndividual(arg, self)
	local userId = tonumber(if player then player.UserId else arg)
	if userId and userId > 0 then
		return userId
	end
	return nil, "Invalid user"
end

local typeId = {
	transform = string.lower,
	validate = parseId,
	parse = parseId,
	suggestions = typeIndividual.suggestions,
	prefixes = typeIndividual.prefixes,
	log = typeIndividual.log,
}

return function(context)
	_K = context

	_K.Registry.registerType("inversePlayers", typeInverse, typeIndividual)
	_K.Registry.registerType("magicPlayers", typeMagic)
	_K.Registry.registerType("rolePlayers", typeRoles)
	_K.Registry.registerType("randomPlayers", typeRandom)
	_K.Registry.registerType("player", typeIndividual)
	_K.Registry.registerType("players", typeMultiple, typeIndividual)

	_K.Registry.registerType("userId", typeId)
	_K.Registry.registerType("userIds", { listable = true }, typeId)
end
