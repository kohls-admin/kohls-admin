local Teams = game:GetService("Teams")

local generateValidate = require(script.Parent.Parent:WaitForChild("generateValidate"))

return function(_K)
	local function teamParse(arg, self)
		if arg == "" then
			return false, "Invalid team"
		end
		local matchedTeam
		for _, team in Teams:GetTeams() do
			local lowerName = string.lower(team.Name)
			if lowerName == arg then
				matchedTeam = team
				break
			elseif not matchedTeam and string.find(lowerName, arg, 1, true) == 1 then
				matchedTeam = team
			end
		end
		if not matchedTeam then
			return false, "Invalid team"
		end
		local feedback = {}
		local players = {}
		for _, player in matchedTeam:GetPlayers() do
			local message
			player, message = self._K.Auth.targetUserArgument(self, player.UserId, player)
			if player then
				table.insert(players, player)
			elseif not table.find(feedback, message) then
				table.insert(feedback, message)
			end
		end
		return #players > 0 and players, #feedback > 0 and table.concat(feedback, "\n") or "No targetable player found"
	end

	local typeTeam = {
		listable = true,
		transform = string.lower,
		validate = generateValidate(teamParse),
		parse = teamParse,
		suggestions = function(text, self)
			local names = {}
			for _, team in next, Teams:GetTeams() do
				table.insert(names, "%" .. team.Name)
			end
			return names
		end,
	}

	_K.Registry.registerType("teamPlayers", typeTeam)
end
