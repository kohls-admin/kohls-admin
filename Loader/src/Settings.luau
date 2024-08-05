local prefix = ":"
-- Enables Kohl's Admin VIP donation features
local vip = true
local freeAdmin = true

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
	-- { rank = 200, roles = { "admin", "vip" }, exactRank = true },
	-- },
}

-- Careful! Easy configuration is above.
-- Only change the code below if you understand the consequences.
return function(_K)
	_K.settings.prefix:set(prefix)
	_K.settings.vip:set(vip)
	_K.Auth.defaultRole.admin = freeAdmin

	if not _K.IsServer then
		return
	end

	-- define main roles
	for role, users in roles do
		for _, userId in users do
			_K.Auth.userRoleAdd(userId, role)
		end
	end

	-- gamepass and group roles
	_K.Util.deepMergeTable(_K.Auth.async.gamepass, gamePassRoles)
	_K.Util.deepMergeTable(_K.Auth.async.group, groupRoles)

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
		-- studio testing roles
		if _K.Services.RunService:IsStudio() then
			_K.Auth.userRoleAdd(player.UserId, "creator")
		end
	end)
end
