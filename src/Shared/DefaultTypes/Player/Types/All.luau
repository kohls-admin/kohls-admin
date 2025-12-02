local Players = game:GetService("Players")

local generateValidate = require(script.Parent.Parent:WaitForChild("generateValidate"))

local function allParse(arg, self)
	local feedback = {}
	local players = {}
	for _, player in Players:GetPlayers() do
		local message
		player, message = self._K.Auth.targetUserArgument(self, player.UserId, player)
		if player then
			table.insert(players, player)
		elseif not table.find(feedback, message) then
			table.insert(feedback, message)
		end
	end

	if #players > 0 then
		return players
	end

	return nil, #feedback > 0 and table.concat(feedback, "\n") or "No targetable player found"
end

local typeEveryone = {
	listable = true,
	transform = string.lower,
	validate = generateValidate(allParse),
	suggestions = function(text, self)
		return { { { "*", "all" }, "*  [all] (Everyone)" } }
	end,
	parse = allParse,
}

return function(_K)
	_K.Registry.registerType("allPlayers", typeEveryone)
end
