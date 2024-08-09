local Settings = {
	dataStoreKey = "CHANGE_THIS", -- MAKE SURE TO CHANGE THIS FOR IMPROVED SECURITY!

	prefix = ":",
	-- Enables Kohl's Admin VIP donation features
	vip = true,
	freeAdmin = true,

	roles = {
		-- accepts a list of userids
		creator = {},
		superadmin = {},
		admin = {},
		mod = {},
		vip = {},
	},

	gamePassRoles = {
		-- [gamePassId] = { "moderator", "vip" },
	},

	groupRoles = {
		-- [groupId] = {
		-- { rank = 200, roles = { "admin", "vip" }, exactRank = true },
		-- },
	},
}

return Settings

-- Careful! Easy configuration is above.
-- Only change the code below if you understand the consequences.
-- return function(_K)
-- 	_K.Data.settings.prefix = prefix
-- 	_K.Data.settings.vip = vip
-- 	_K.Data.defaultRole.admin = freeAdmin

-- 	if not _K.IsServer then
-- 		return
-- 	end

-- 	-- define main roles
-- 	for role, users in roles do
-- 		for _, userId in users do
-- 			_K.Auth.userRoleAdd(userId, role)
-- 		end
-- 	end

-- 	-- gamepass and group roles
-- 	_K.Util.Table.deepMerge(_K.Data.async.gamepass, gamePassRoles)
-- 	_K.Util.Table.deepMerge(_K.Data.async.group, groupRoles)

-- 	-- give roles on gamepass purchase
-- 	_K.Services.MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamePassId, purchaseSuccess)
-- 		if not purchaseSuccess then
-- 			return
-- 		end
-- 		for id, roles in gamePassRoles do
-- 			if gamePassId ~= id then
-- 				continue
-- 			end
-- 			for _, role in roles do
-- 				_K.Auth.userRoleAdd(player.UserId, role)
-- 			end
-- 		end
-- 	end)

-- 	-- handle on join role givers
-- 	_K.Services.Players.PlayerAdded:Connect(function(player)
-- 		-- studio testing roles
-- 		if _K.Services.RunService:IsStudio() then
-- 			_K.Auth.userRoleAdd(player.UserId, "creator")
-- 		end
-- 	end)
-- end
