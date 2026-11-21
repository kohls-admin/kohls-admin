local Players = game:GetService("Players")

local generateValidate = require(script.Parent.Parent:WaitForChild("generateValidate"))

return function(_K)
	local function roleParse(arg, self)
		if arg == "" then
			return false, "Invalid role"
		end
		local matchedRole
		for roleId in _K.Data.roles do
			local lowerId = string.lower(roleId :: string)
			if lowerId == arg then
				matchedRole = roleId
				break
			elseif string.find(lowerId, arg, 1, true) == 1 and (not matchedRole or roleId < matchedRole) then
				matchedRole = roleId
			end
		end

		if not matchedRole then
			return false, "Invalid role"
		end

		local feedback = {}
		local players = {}
		for _, player in Players:GetPlayers() do
			local userPermissions = _K.Data.members[tostring(player.UserId)]
			if userPermissions and table.find(userPermissions.roles, matchedRole) then
				local message
				player, message = self._K.Auth.targetUserArgument(self, player.UserId, player)
				if player then
					table.insert(players, player)
				elseif not table.find(feedback, message) then
					table.insert(feedback, message)
				end
			end
		end

		return #players > 0 and players, #feedback > 0 and table.concat(feedback, "\n") or "No targetable player found"
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
