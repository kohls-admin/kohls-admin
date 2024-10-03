local Players = game:GetService("Players")

local generateValidate = require(script.Parent.Parent:WaitForChild("generateValidate"))
local sanitizePlayer = require(script.Parent.Parent:WaitForChild("sanitizePlayer"))

local function parseRandom(arg, self)
	arg = if arg == "" then 1 else tonumber(arg)
	if not arg or math.floor(arg) ~= arg then
		return nil, "Invalid integer"
	end

	local players = {}
	local list = {}
	for _, player in Players:GetPlayers() do
		player = sanitizePlayer(self, player)
		if player then
			table.insert(list, player)
		end
	end

	if #list == 0 then
		return nil, "No valid player found"
	end

	for _ = 1, arg do
		local length = #list
		if length == 0 then
			break
		end
		table.insert(players, table.remove(list, math.random(length)))
	end
	return players
end

local typeRandom = {
	listable = true,
	validate = generateValidate(parseRandom),
	parse = parseRandom,
}

-- TODO: dynamic suggestion to show how many random people will be selected

return function(_K)
	_K.Registry.registerType("randomPlayers", typeRandom)
end
