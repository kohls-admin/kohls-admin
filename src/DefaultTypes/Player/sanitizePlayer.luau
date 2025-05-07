local function sanitizePlayer(self, player: Player)
	if self.definition.ignoreSelf then
		if player == self.command.fromPlayer then
			return nil, "Can't target yourself"
		end
	else
		if player == self.command.fromPlayer then
			return player
		end
	end

	local rank, role = self._K.Auth.getRank(self.command.from)
	if role.onlyTargetSelf then
		if player == self.command.fromPlayer then
			return self.command.fromPlayer
		else
			return nil, "Can only target yourself"
		end
	elseif self.definition.lowerRank and not self.definition.shouldRequest then
		if player:GetAttribute("_KRolesLoaded") ~= true then
			return nil, "Can't target loading player"
		end
		if self._K.Auth.getRank(player.UserId) < rank then
			return player
		end
		return nil, "Can only target lower ranks"
	else
		return player
	end
end

return sanitizePlayer
