local prefix = ":"
-- Enables Kohl's Admin VIP donation features
local vip = true

local roles = {
	-- accepts a list of userids
	creator = {},
	superadmin = {},
	admin = {},
	mod = {},
	vip = {},
}

local gamePassRoles = {
	-- [gamePassId] = { "moderator", "vip" },
}

local groupRoles = {
	-- [groupId] = {
	-- { rank = 200, roles = { "admin", "vip" }, rankAndAbove = true },
	-- },
}

-- Careful! Easy configuration is above.
-- Only change the code below if you understand the consequences.
return function(_K)
	_K.settings.prefix = prefix
	_K.settings.vip = vip

	if not _K.IsServer then
		return
	end

	-- define main roles
	for role, users in roles do
		for _, userId in users do
			_K.Auth.userRoleAdd(userId, role)
		end
	end

	-- give roles on gamepass purchase
	_K.Services.MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamePassId, purchaseSuccess)
		if not purchaseSuccess then
			return
		end
		for id, roles in gamePassRoles do
			if gamePassId ~= id then
				continue
			end
			for _, role in roles do
				_K.Auth.userRoleAdd(player.UserId, role)
			end
		end
	end)

	-- handle on join role givers
	_K.Services.Players.PlayerAdded:Connect(function(player)
		-- gamepass role giver
		for id, roles in gamePassRoles do
			if not _K.Services.MarketplaceService:UserOwnsGamePassAsync(player.UserId, id) then
				continue
			end
			for _, role in roles do
				_K.Auth.userRoleAdd(player.UserId, role)
			end
		end
		-- group roles giver
		for groupId, groupRanks in groupRoles do
			if not player:IsInGroup(groupId) then
				continue
			end
			for index, rankDefinition in groupRanks do
				local rank = player:GetRankInGroup(groupId)
				if rank == rankDefinition.rank or (rankDefinition.rankAndAbove and rank >= rankDefinition.rank) then
					for _, role in rankDefinition.roles do
						_K.Auth.userRoleAdd(player.UserId, role)
					end
				end
			end
		end
	end)
end
