local Players = game:GetService("Players")

local generateValidate = require(script.Parent.Parent:WaitForChild("generateValidate"))
local sanitizeUser = require(script.Parent.Parent:WaitForChild("sanitizeUser"))

local function othersParse(arg, self)
	local players = {}
	for _, player in Players:GetPlayers() do
		if player == self.command.fromPlayer then
			continue
		end
		player = sanitizeUser(self, player.UserId, player)
		if player then
			table.insert(players, player)
		end
	end
	return #players > 0 and players, "No valid player found"
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
