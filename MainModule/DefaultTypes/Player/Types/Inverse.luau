local Players = game:GetService("Players")

local sanitizePlayer = require(script.Parent.Parent:WaitForChild("sanitizePlayer"))

-- TODO: finish inverse type

local typeInverse = {
	postParse = function(arg, self)
		local players = {}
		if type(arg) == "table" then
			for _, player in Players:GetPlayers() do
				local matched
				for _, player2 in arg do
					if player == player2 then
						matched = true
						break
					end
				end
				if not matched then
					player = sanitizePlayer(self, player)
					if player then
						table.insert(players, player)
					end
				end
			end
		elseif typeof(arg) == "Instance" then
			for _, player in Players:GetPlayers() do
				if player ~= arg then
					player = sanitizePlayer(self, player)
					if player then
						table.insert(players, player)
					end
				end
			end
		end
		return players
	end,
	prefixes = {
		["%$"] = "magicPlayers",
		["@"] = "rolePlayers",
		["%%"] = "teamPlayers",
	},
}

return function(_K)
	-- _K.Registry.registerType("inversePlayers", typeInverse)
end
