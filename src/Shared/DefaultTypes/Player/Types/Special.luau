local Players = game:GetService("Players")

local generateValidate = require(script.Parent.Parent:WaitForChild("generateValidate"))

return function(_K)
	local specialReference = {
		all = function(player, from)
			return true
		end,
		others = function(player, from)
			return player ~= from, "Can't target yourself"
		end,
		admins = function(player)
			return _K.Data.members[tostring(player.UserId)]
		end,
		nonadmins = function(player)
			return not _K.Data.members[tostring(player.UserId)]
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
		distance = function(player: Player, from: Player, arg: string): (boolean, string?)
			if player.Character and from.Character then
				local sign, radiusMatch = string.match(arg, "([><])(%d+)$")
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
				elseif sign == "<" then
					return player:DistanceFromCharacter(pivot.Position) <= radius
				end
			end
			return false
		end,
		group = function(player: Player, _, arg: string): (boolean, string?)
			local idMatch, sign, equal, rankMatch = string.match(arg, "=(%d+)([>=<])(=?)(%d*)$")
			local id, rank = tonumber(idMatch), tonumber(rankMatch)
			if not id then
				return false, "Invalid group: " .. arg
			end
			if player:IsInGroupAsync(id) then
				if not rank then
					return true
				end
				local playerRank = player:GetRankInGroupAsync(id)
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
	}

	local specialSuggestions = {}
	for suggestion, check in specialReference do
		if suggestion == "distance" then
			table.insert(specialSuggestions, "$distance<200")
		elseif suggestion == "group" then
			table.insert(specialSuggestions, `${suggestion}={_K.groupId or 3403354}<=255`)
		else
			table.insert(specialSuggestions, "$" .. suggestion)
		end
	end
	table.sort(specialSuggestions)

	local function specialParse(arg, self)
		for match, check in specialReference do
			if match == "distance" or match == "group" then
				if string.find(arg, match :: string, 1, true) ~= 1 then
					continue
				end
			else
				if string.find(match :: string, arg, 1, true) ~= 1 then
					continue
				end
			end

			local feedback = {}
			local players = {}
			for _, player in Players:GetPlayers() do
				local ok, validPlayer, specialFeedback = pcall(check, player, self.command.fromPlayer, arg)
				if ok and validPlayer then
					local message
					player, message = self._K.Auth.targetUserArgument(self, player.UserId, player)
					if player then
						table.insert(players, player)
					elseif not table.find(feedback, message) then
						table.insert(feedback, message)
					end
				elseif not table.find(feedback, specialFeedback) then
					table.insert(feedback, specialFeedback)
				end
			end

			return #players > 0 and players,
				#feedback > 0 and table.concat(feedback, "\n") or "No targetable player found"
		end

		return false, "Invalid match"
	end

	local typeSpecial = {
		listable = true,
		transform = string.lower,
		validate = generateValidate(specialParse),
		parse = specialParse,
		suggestions = function(text, self)
			return specialSuggestions
		end,
	}

	_K.Registry.registerType("specialPlayers", typeSpecial)
end
