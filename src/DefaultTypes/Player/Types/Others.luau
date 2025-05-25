local Players = game:GetService("Players")

local generateValidate = require(script.Parent.Parent:WaitForChild("generateValidate"))

local function othersParse(arg, self)
	local feedback = {}
	local players = {}
	for _, player in Players:GetPlayers() do
		if player == self.command.fromPlayer then
			continue
		end
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
	elseif #Players:GetPlayers() == 1 then
		return nil, "No other players online"
	end

	return nil, table.concat(feedback, "\n") or "No targetable player found"
end

local typeOthers = {
	listable = true,
	transform = string.lower,
	validate = generateValidate(othersParse),
	parse = othersParse,
}

return function(_K)
	_K.Registry.registerType("otherPlayers", typeOthers)
end
