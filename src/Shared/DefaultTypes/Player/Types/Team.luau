local Teams = game:GetService("Teams")

local generateValidate = require(script.Parent.Parent:WaitForChild("generateValidate"))

return function(_K)
	local function teamParse(arg, self)
		local feedback = {}
		local players, valid = {}, false
		for _, team in Teams:GetTeams() do
			if string.find(string.lower(team.Name), arg, 1, true) == 1 then
				valid = true
				for _, player in team:GetPlayers() do
					local message
					player, message = self._K.Auth.targetUserArgument(self, player.UserId, player)
					if player then
						table.insert(players, player)
					elseif not table.find(feedback, message) then
						table.insert(feedback, message)
					end
				end
				break
			end
		end
		if not valid then
			return false, "Invalid team"
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
