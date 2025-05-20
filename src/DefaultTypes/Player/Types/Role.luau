local Players = game:GetService("Players")

local generateValidate = require(script.Parent.Parent:WaitForChild("generateValidate"))
local sanitizePlayer = require(script.Parent.Parent:WaitForChild("sanitizePlayer"))

return function(_K)
	local function roleParse(arg, self)
		local players, valid = {}, false
		for roleId in _K.Data.roles do
			if string.find(string.lower(roleId), arg, 1, true) == 1 then
				valid = true
				for _, player in Players:GetPlayers() do
					local userPermissions = _K.Data.members[tostring(player.UserId)]
					if userPermissions and table.find(userPermissions.roles, roleId) then
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

	local roleIds = {}
	local typeRoles = {
		listable = true,
		transform = string.lower,
		validate = generateValidate(roleParse),
		parse = roleParse,
		suggestions = function(text, self)
			return roleIds
		end,
	}

	_K.Registry.registerType("rolePlayers", typeRoles)

	task.defer(function()
		repeat
			task.wait()
		until _K.Data.roles

		for roleId in _K.Data.roles do
			table.insert(roleIds, roleId)
		end
		table.sort(roleIds, _K.Auth.roleIdSortAscending)
		for index, roleId in next, roleIds do
			roleIds[index] = "@" .. roleId
		end
	end)
end
