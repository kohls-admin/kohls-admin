local Teams = game:GetService("Teams")

local _K

local function findTeam(input: string, teams: { Team }?): Team?
	local query = string.lower(input)
	if query == "" then
		return nil
	end
	local partial, partialLower
	for _, team in teams or Teams:GetTeams() do
		local lowerName = string.lower(team.Name)
		if lowerName == query then
			return team
		elseif string.find(lowerName, query, 1, true) == 1 and (not partial or lowerName < partialLower) then
			partial = team
			partialLower = lowerName
		end
	end
	return partial
end

local typeTeam = {
	find = findTeam,
	validate = function(input: string, from: number): (boolean, string?)
		local teams = Teams:GetTeams()
		if #teams == 0 then
			return false, "No teams available"
		end
		if findTeam(input, teams) then
			return true
		end
		return false, "Invalid team"
	end,
	parse = function(input: string, from: number): Team
		return findTeam(input) or error("Invalid team value")
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
