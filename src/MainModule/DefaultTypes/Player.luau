local Players = game:GetService("Players")
local _Teams = game:GetService("Teams")

-- TODO: post random selector? "%blue team~5"
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

local function sanitizePlayer(self, player: Player)
	if self.definition.ignoreSelf then
		if player == self.command.fromPlayer then
			return nil, "Can't target yourself"
		end
	else
		if player == self.command.fromPlayer then
			return player
		end
	end

	local rank, role = _K.Auth.getRank(self.command.from)
	if role.onlyTargetSelf then
		if player == self.command.fromPlayer then
			return self.command.fromPlayer
		else
			return nil, "Can only target yourself"
		end
	elseif self.definition.lowerRank and not self.definition.shouldRequest then
		if _K.Auth.getRank(player.UserId) < rank then
			return player
		end
		return nil, "Can only target lower ranks"
	else
		return player
	end
end

local function sanitizeUser(self, user: number)
	if self.definition.ignoreSelf then
		if user == self.command.from then
			return nil, "Can't target yourself"
		end
	else
		if user == self.command.from then
			return user
		end
	end

	local rank, role = _K.Auth.getRank(self.command.from)
	if role.onlyTargetSelf then
		if user == self.command.from then
			return self.command.from
		else
			return nil, "Can only target yourself"
		end
	elseif self.definition.lowerRank and not self.definition.shouldRequest then
		if _K.Auth.getRank(user) < rank then
			return user
		end
		return nil, "Can only target lower ranks"
	else
		return user
	end
end

local typeInverse = {
	postParse = function(arg, self)
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
					player = sanitizePlayer(self, player)
					if player then
						table.insert(players, player)
					end
				end
			end
		elseif typeof(arg) == "Instance" then
			for _, player in Players:GetPlayers() do
				if player ~= arg then
					player = sanitizePlayer(self, player)
					if player then
						table.insert(players, player)
					end
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

-- FIX: make sure all player selectors are sanitized

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

local function magicParse(arg, self)
	local players = {}
	local check = directMagic[arg] or partialMatch(arg)
	for _, player in Players:GetPlayers() do
		local success, _feedback = check(player, Players.LocalPlayer)
		if success then
			player = sanitizePlayer(self, player)
			if player then
				table.insert(players, player)
			end
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
					player = sanitizePlayer(self, player)
					if player then
						table.insert(players, player)
					end
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
	validate = function(arg, self)
		local list = {}
		for _, player in Players:GetPlayers() do
			player = sanitizePlayer(self, player)
			if player then
				table.insert(list, player)
			end
		end
		return arg ~= nil and arg <= #list
	end,
	parse = function(arg, self)
		local players = {}
		local list = {}
		for _, player in Players:GetPlayers() do
			player = sanitizePlayer(self, player)
			if player then
				table.insert(list, player)
			end
		end
		for _ = 1, arg do
			table.insert(players, table.remove(list, math.random(#list)))
		end
		return players
	end,
}

local function parseIndividual(arg, self)
	if arg == "" or arg == "me" then
		return sanitizePlayer(self, self.command.fromPlayer)
	end
	for _, player in Players:GetPlayers() do
		if string.find(string.lower(player.Name), arg, 1, true) == 1 then
			return sanitizePlayer(self, player)
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
	transform = string.lower,
	validate = genValidate(function(arg, self)
		if arg == "*" or arg == "all" then
			local players = {}
			for _, player in Players:GetPlayers() do
				player = sanitizePlayer(self, player)
				if player then
					table.insert(players, player)
				end
			end
			return #players > 0, "No valid player found"
		end
		return parseIndividual(arg, self)
	end),
	preParse = function(transformedArgs, self)
		if table.find(transformedArgs, "*") or table.find(transformedArgs, "all") then
			local players = {}
			for _, player in Players:GetPlayers() do
				player = sanitizePlayer(self, player)
				if player then
					table.insert(players, player)
				end
			end
			return { players }
		end
		return
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
	log = typeIndividual.log,
	prefixes = typeIndividual.prefixes,
	suggestions = typeIndividual.suggestions,
}

local function parseId(arg, self)
	local player = parseIndividual(arg, self)
	local userId = tonumber(if player then player.UserId else arg)
	if userId and userId > 0 then
		return sanitizeUser(self, userId)
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
	_K.Registry.registerType("players", typeMultiple)

	_K.Registry.registerType("userId", typeId)
	_K.Registry.registerType("userIds", { listable = true }, typeId)
end
