local function sanitizeUser(self, user: number)
	if self.definition.ignoreSelf then
		if user == self.command.from then
			return nil, "Can't target yourself"
		end
	else
		if user == self.command.from then
			return user
		end
	end

	local rank, role = self._K.Auth.getRank(self.command.from)
	if role.onlyTargetSelf then
		if user == self.command.from then
			return self.command.from
		else
			return nil, "Can only target yourself"
		end
	elseif self.definition.lowerRank and not self.definition.shouldRequest then
		if self._K.Auth.getRank(user) < rank then
			return user
		end
		return nil, "Can only target lower ranks"
	else
		return user
	end
end

return sanitizeUser
