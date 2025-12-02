local Players = game:GetService("Players")

local generateValidate = require(script.Parent.Parent:WaitForChild("generateValidate"))

local function parseRandom(arg, self)
	arg = if arg == "" then 1 else tonumber(arg)
	if not arg or math.floor(arg) ~= arg then
		return nil, "Invalid integer"
	end

	local feedback = {}
	local players = {}
	local list = {}
	for _, player in Players:GetPlayers() do
		local message
		player, message = self._K.Auth.targetUserArgument(self, player.UserId, player)
		if player then
			table.insert(list, player)
		elseif not table.find(feedback, message) then
			table.insert(feedback, message)
		end
	end

	if #list == 0 then
		return nil, #feedback > 0 and table.concat(feedback, "\n") or "No targetable player found"
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
