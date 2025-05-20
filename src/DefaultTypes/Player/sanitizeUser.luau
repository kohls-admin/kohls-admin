local function sanitizeUser(self, userId: number, value: Player | number | string)
	local from = self.command.from
	if userId == from then
		if self.definition.ignoreSelf then
			return nil, "Can't target yourself"
		end
		return value
	end
	if self._K.Auth.hasPermission(from, "admin") then
		return value
	end
	if self._K.Auth.hasPermission(from, "targetOthers") ~= true then
		return nil, "Can only target yourself"
	end
	if self.definition.lowerRank and not self.definition.shouldRequest then
		local rank = self._K.Auth.hasCommand(from, self.command.definition)
		if not rank then
			return nil, "Can't access this command"
		end
		local player = self._K.Service.Players:GetPlayerByUserId(userId)
		if player and player:GetAttribute("_KRolesLoaded") ~= true then
			return nil, "Can't target loading user"
		end
		if self._K.Auth.getRank(userId) < rank then
			return value
		end
		return nil, "Can only target lower ranks"
	else
		return value
	end
end

return sanitizeUser
