local Teams = game:GetService("Teams")

local context

local typeTeam = {
	validate = function(input: string, from: number): (boolean, string?)
		local query = string.lower(input)
		for _, team in Teams:GetTeams() do
			if string.find(string.lower(team.Name), query) == 1 then
				return true
			end
		end
		return false, "Invalid team."
	end,
	parse = function(input: string, from: number): string
		local query = string.lower(input)
		for _, team in Teams:GetTeams() do
			if string.find(string.lower(team.Name), query) == 1 then
				return team
			end
		end
		error("Invalid team value")
	end,
	suggestions = function(text: string, from: number)
		return context.Util.Suggest.query(text, context.Util.Suggest.new(Teams:GetTeams()))
	end,
}

local typeTeams = {
	listable = true,
}

return function(_K)
	context = _K
	_K.Registry.registerType("team", typeTeam)
	_K.Registry.registerType("teams", typeTeams, typeTeam)
end
