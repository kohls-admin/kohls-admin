local Players = game:GetService("Players")
local Teams = game:GetService("Teams")

local generateValidate = require(script.Parent.Parent:WaitForChild("generateValidate"))
local sanitizePlayer = require(script.Parent.Parent:WaitForChild("sanitizePlayer"))

local function teamParse(arg, self)
	local players, valid = {}, false
	for _, team in Teams:GetTeams() do
		if string.find(string.lower(team.Name), arg, 1, true) == 1 then
			valid = true
			for _, player in team:GetPlayers() do
				player = sanitizePlayer(self, player)
				if player then
					table.insert(players, player)
				end
			end
			break
		end
	end
	return if valid then players else false, `Invalid team`
end

local typeTeam = {
	transform = string.lower,
	validate = generateValidate(teamParse),
	parse = teamParse,
	suggestions = function(text, self)
		local names = {}
		for _, team in next, Teams:GetTeams() do
			table.insert(names, "%" .. team.Name)
		end
		return _K.Util.Suggest.query(text, names)
	end,
}

return function(_K)
	_K.Registry.registerType("teamPlayers", typeTeam)
end
