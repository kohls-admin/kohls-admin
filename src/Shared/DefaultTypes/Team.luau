local Teams = game:GetService("Teams")

local _K

local typeTeam = {
	validate = function(input: string, from: number): (boolean, string?)
		local query = string.lower(input)
		local teams = Teams:GetTeams()
		if #teams == 0 then
			return false, "No teams available"
		end
		for _, team in teams do
			if string.find(string.lower(team.Name), query, 1, true) == 1 then
				return true
			end
		end
		return false, "Invalid team"
	end,
	parse = function(input: string, from: number): string
		local query = string.lower(input)
		for _, team in Teams:GetTeams() do
			if string.find(string.lower(team.Name), query, 1, true) == 1 then
				return team
			end
		end
		error("Invalid team value")
	end,
	suggestions = function(text: string, from: number)
		return _K.Util.Suggest.new(Teams:GetTeams())
	end,
}

local typeTeams = {
	listable = true,
}

return function(context)
	_K = context
	_K.Registry.registerType("team", typeTeam)
	_K.Registry.registerType("teams", typeTeams, typeTeam)
end
