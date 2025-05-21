local Teams = game:GetService("Teams")

local generateValidate = require(script.Parent.Parent:WaitForChild("generateValidate"))

return function(_K)
	local function teamParse(arg, self)
		local players, valid = {}, false
		for _, team in Teams:GetTeams() do
			if string.find(string.lower(team.Name), arg, 1, true) == 1 then
				valid = true
				for _, player in team:GetPlayers() do
					player = self._K.Auth.targetUserArgument(self, player.UserId, player)
					if player then
						table.insert(players, player)
					end
				end
				break
			end
		end
		if not valid then
			return false, "Invalid team"
		end
		return #players > 0 and players, "No valid player found"
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
