local Players = game:GetService("Players")

local generateValidate = require(script.Parent.Parent:WaitForChild("generateValidate"))
local sanitizePlayer = require(script.Parent.Parent:WaitForChild("sanitizePlayer"))

return function(_K)
	local function roleParse(arg, self)
		local players, valid = {}, false
		for id in _K.Data.roles do
			if string.find(string.lower(id), arg, 1, true) == 1 then
				valid = true
				for _, player in Players:GetPlayers() do
					local userPermissions = _K.Data.members[tostring(player.UserId)]
					if userPermissions and table.find(userPermissions.roles, id) then
						player = sanitizePlayer(self, player)
						if player then
							table.insert(players, player)
						end
					end
				end
				break
			end
		end
		return if valid then players else false, `Invalid role`
	end

	local typeRoles = {
		transform = string.lower,
		validate = generateValidate(roleParse),
		parse = roleParse,
		suggestions = function(text, self)
			local names = {}
			for role in next, _K.Data.roles do
				table.insert(names, "@" .. role)
			end
			return _K.Util.Suggest.query(text, names)
		end,
	}

	_K.Registry.registerType("rolePlayers", typeRoles)
end
