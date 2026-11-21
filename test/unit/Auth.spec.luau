local Harness = require("./Harness")
local sert = require("../sert")

local describe, test = sert.describe, sert.test

local ROLE_IDS = { "everyone", "vip", "mod", "admin", "superadmin", "creator" }

local function kickOf(h: any, player: any): string?
	for _, kick in h.env.kicks do
		if kick.player == player then
			return kick.message
		end
	end
	return nil
end

describe("Auth · Role Ordering Laws", function()
	test("roleIdSort and roleIdSortAscending satisfy strict weak order laws", function()
		local Auth = Harness.shared():requireAuth()

		sert.laws.order({
			name = "Auth.roleIdSort",
			gen = function(g)
				return g:pick(ROLE_IDS)
			end,
			lt = Auth.roleIdSort,
		}, { runs = 60 })

		sert.laws.order({
			name = "Auth.roleIdSortAscending",
			gen = function(g)
				return g:pick(ROLE_IDS)
			end,
			lt = Auth.roleIdSortAscending,
		}, { runs = 60 })

		sert.eq(Auth.roleIdSort("mod", "unknown_role"), true)
		sert.eq(Auth.roleIdSort("unknown_role", "mod"), false)
		sert.eq(Auth.roleIdSortAscending("unknown_role", "mod"), true)
		sert.eq(Auth.roleIdSortAscending("mod", "unknown_role"), false)
	end)
end)

describe("Auth · Stateful RBAC & Ban Model", function()
	test("banHandler kicks active bans and auto-unbans expired temporary bans", function()
		local h = Harness.newEnv({ isStudio = false })
		local Data = h:requireData()
		local Auth = h:requireAuth()
		Data.SEPARATE_DATASTORE = true

		local plr = h.env:addPlayer(501, "TimedBanUser")
		Auth.banUsers({ 501 }, "Temp ban reason", 30, nil, true)
		sert.eq(Data.bans["501"] ~= nil, true)

		-- While ban is active, banHandler kicks the player and returns true
		sert.eq(Auth.banHandler(plr), true)
		sert.eq(type(kickOf(h, plr)), "string")

		-- Advance clock past the 30-second expiration
		h.env:removePlayer(501)
		local plrRejoined = h.env:addPlayer(501, "TimedBanUser")
		h.env:step(45)
		sert.eq(Auth.banHandler(plrRejoined), nil)
		sert.eq(kickOf(h, plrRejoined), nil)
		sert.eq(Data.bans["501"], nil)
	end)

	test("targetUserArgument enforces self-targeting, lowerRank, and targetLimits", function()
		local h = Harness.newEnv({ isStudio = false })
		local Data = h:requireData()
		local Auth = h:requireAuth()
		local _K = h:requireK()

		local p1 = h.env:addPlayer(10, "VipUser")
		local p2 = h.env:addPlayer(20, "ModUser")
		local p3 = h.env:addPlayer(30, "AdminUser")
		p1:SetAttribute("_KRolesLoaded", true)
		p2:SetAttribute("_KRolesLoaded", true)
		p3:SetAttribute("_KRolesLoaded", true)
		Auth.userRoleAdd(10, "vip")
		Auth.userRoleAdd(20, "mod")
		Auth.userRoleAdd(30, "admin")

		local vipRank, vipRole = Auth.getRank(10)
		local modRank, modRole = Auth.getRank(20)

		-- VIP has onlyTargetSelf = true: can target self (10), cannot target Mod (20)
		Data.targetLimits[10] = 0
		local vipArg = {
			_K = _K,
			definition = { lowerRank = false },
			command = { from = 10, fromRank = vipRank, fromRole = vipRole, rank = 1 },
		}
		sert.eq(Auth.targetUserArgument(vipArg, 10, 10), 10)
		Data.targetLimits[10] = 0
		local targetOtherVal, targetOtherErr = Auth.targetUserArgument(vipArg, 20, 20)
		sert.eq(targetOtherVal, nil)
		sert.eq(string.find(tostring(targetOtherErr), "yourself", 1, true) ~= nil, true)

		-- Mod can target others, but with lowerRank = true cannot target Admin (30)
		Data.targetLimits[20] = 0
		local modArg = {
			_K = _K,
			definition = { lowerRank = true },
			command = { from = 20, fromRank = modRank, fromRole = modRole, rank = 2 },
		}
		sert.eq(Auth.targetUserArgument(modArg, 10, 10), 10)
		local highVal, highErr = Auth.targetUserArgument(modArg, 30, 30)
		sert.eq(highVal, nil)
		sert.eq(string.find(tostring(highErr), "lower", 1, true) ~= nil, true)
	end)

	test("hasRole, getRoleFromRank, roleCanUseArgument, and hasArgument", function()
		local h = Harness.newEnv({ isStudio = false })
		local Data = h:requireData()
		local Auth = h:requireAuth()
		Data.creatorId = 999

		h.env:addPlayer(10, "TempMod")
		h.env:addPlayer(20, "PersistAdmin")
		Auth.userRoleAdd(10, "mod", false)
		Auth.userRoleAdd(20, "admin", true)

		-- hasRole checks direct role, higher rank role, creatorId, and invalid role
		sert.eq(Auth.hasRole(10, "mod"), true)
		sert.eq(Auth.hasRole(10, "vip"), true)
		sert.eq(Auth.hasRole(10, "admin"), false)
		sert.eq(Auth.hasRole(20, "admin"), true)
		sert.eq(Auth.hasRole(20, "mod"), true)
		sert.eq(Auth.hasRole(20, "superadmin"), false)
		sert.eq(Auth.hasRole(999, "superadmin"), true)
		sert.eq(Auth.hasRole(10, "nonexistent_role"), false)

		-- getRoleFromRank finds exact match or closest role >= rank
		sert.eq((Auth.getRoleFromRank(0) :: any)._key, "everyone")
		sert.eq((Auth.getRoleFromRank(2) :: any)._key, "mod")
		sert.eq((Auth.getRoleFromRank(2.5) :: any)._key, "admin")
		sert.eq((Auth.getRoleFromRank(100) :: any)._key, "creator")

		-- roleCanUseArgument and hasArgument
		local unrestrictedArg = { name = "msg" }
		local banAsyncArg = { name = "duration", permissions = { banasync = true } }
		local saveRolesArg = { name = "persist", permissions = { saveRoles = true } }

		sert.eq(Auth.roleCanUseArgument("nonexistent", unrestrictedArg), false)
		sert.eq(Auth.roleCanUseArgument("everyone", unrestrictedArg), true)
		sert.eq(Auth.roleCanUseArgument("mod", banAsyncArg), false)
		sert.eq(Auth.roleCanUseArgument("admin", banAsyncArg), true)
		sert.eq(Auth.roleCanUseArgument("creator", saveRolesArg), true)

		sert.eq(Auth.hasArgument(10, unrestrictedArg), true)
		sert.eq(Auth.hasArgument(10, banAsyncArg), false)
		sert.eq(Auth.hasArgument(20, banAsyncArg), true)
		sert.eq(Auth.hasArgument(20, saveRolesArg), false)
		sert.eq(Auth.hasArgument(999, saveRolesArg), true)

		Data.settings.freeAdmin = { "superadmin" }
		sert.eq(Auth.hasArgument(10, saveRolesArg), true)
		Data.settings.freeAdmin = {}
	end)

	test("userRoleRemove handles temporary vs persistent roles and multiple persistent roles", function()
		local h = Harness.newEnv({ isStudio = false })
		local Data = h:requireData()
		local Auth = h:requireAuth()

		h.env:addPlayer(40, "TempOnly")
		h.env:addPlayer(50, "PersistMulti")

		-- Temporary role removal clears member entry without syncing REMOVE to DataStore
		Auth.userRoleAdd(40, "mod", false)
		sert.eq(Data.members["40"] ~= nil, true)
		sert.eq(Auth.userRoleRemove(40, "mod"), true)
		sert.eq(Data.members["40"], nil)
		sert.eq(Data.Sync.members["40"], nil)
		sert.eq(Auth.userRoleRemove(40, "mod"), false)

		-- Persistent role removal with multiple persistent roles updates Sync.members, then sets REMOVE when empty
		Auth.userRoleAdd(50, "mod", true)
		Auth.userRoleAdd(50, "admin", true)
		h.env:step(0.05)
		sert.eq(Auth.userRoleRemove(50, "admin"), true)
		h.env:step(0.05)
		sert.eq(Data.members["50"] ~= nil, true)
		sert.eq(Data.Sync.members["50"][2], { "mod" })

		sert.eq(Auth.userRoleRemove(50, "mod"), true)
		sert.eq(Data.members["50"], nil)
		sert.eq(Data.Sync.members["50"], Data.REMOVE)
	end)

	test("userAsyncRoles grants roles from group (exactRank and >= rank), gamepass, asset, and subscription", function()
		local h = Harness.newEnv({ isStudio = false })
		local Data = h:requireData()
		local Auth = h:requireAuth()

		local p1 = h.env:addPlayer(101, "AsyncUser1")
		local p2 = h.env:addPlayer(102, "AsyncUser2")

		-- Configure group rules: group 1000 requires exactRank = 50 for mod, and rank >= 200 for admin
		Data.async.group[1000] = {
			{ rank = 50, roles = { "mod" }, exactRank = true },
			{ rank = 200, roles = { "admin" }, exactRank = false },
		}
		Data.async.gamepass[555] = { "vip" }
		Data.async.asset[777] = { "mod" }
		Data.async.subscription["sub_super"] = { "superadmin" }

		-- p1 has group rank 50 (matches exactRank=50 -> mod), gamepass 555 (-> vip), subscription sub_super (-> superadmin)
		h.env:setGroupRank(101, 1000, 50)
		h.env:setGroupRank(102, 1000, 220)
		h.env.groups[1000].Roles = {
			{ Name = "Guest", Rank = 0 },
			{ Name = "Member", Rank = 1 },
			{ Name = "Mod", Rank = 50 },
			{ Name = "Admin", Rank = 200 },
		}
		h.env:setGamePass(101, 555, true)
		h.env.marketplace.subscriptions[101] = { sub_super = true }

		-- p2 has group rank 220 (does NOT match exactRank=50, matches >=200 -> admin) and asset 777 (-> mod)
		h.env.marketplace.assets[102] = { [777] = true }

		Auth.userAsyncRoles(p1.UserId)
		sert.eq(table.find(Data.members["101"].roles, "vip") ~= nil, true)
		sert.eq(Auth.hasRole(p1.UserId, "mod"), true)
		sert.eq(Auth.hasRole(p1.UserId, "superadmin"), true)

		-- Second call without bustCache is a no-op
		Auth.userAsyncRoles(p1.UserId, false)

		-- With bustCache = true, re-evaluates group roles and removes stale exactRank group role
		h.env:setGroupRank(101, 1000, 250)
		Auth.userAsyncRoles(p1.UserId, true)
		sert.eq(table.find(Data.members["101"].roles, "admin") ~= nil, true)
		sert.eq(table.find(Data.members["101"].roles, "mod"), nil)
		sert.eq(Auth.hasAsyncRole(p1.UserId, "mod"), false)

		Auth.userAsyncRoles(p2.UserId)
		sert.eq(table.find(Data.members["102"].roles, "admin") ~= nil, true)
		sert.eq(table.find(Data.members["102"].roles, "mod") ~= nil, true)
		sert.eq(table.find(Data.members["102"].roles, "vip"), nil)
	end)

	test("prefetchGroupEntryRanks and isPublicRole cache group entry ranks and fail closed on error", function()
		local h = Harness.newEnv({ isStudio = false })
		local Data = h:requireData()
		local Auth = h:requireAuth()

		h.env.groups[2000] = {
			Roles = {
				{ Name = "Guest", Rank = 0 },
				{ Name = "Member", Rank = 10 },
				{ Name = "Officer", Rank = 100 },
			},
		}
		Data.async.group[2000] = {
			{ rank = 10, roles = { "vip" } },
			{ rank = 100, roles = { "admin" } },
		}

		-- Prefetch resolves entry rank = 10 for group 2000
		Auth.prefetchGroupEntryRanks()
		h.env:step(0.05)

		-- "vip" is granted at entry rank 10 -> public role; "admin" requires 100 -> restricted role
		sert.eq(Auth.isPublicRole("vip"), true)
		sert.eq(Auth.isPublicRole("admin"), false)

		-- Group whose GetGroupInfoAsync fails stays fail-closed (isPublicRole = true) and schedules retry
		local GroupService = h.env.game:GetService("GroupService")
		local origGetInfo = GroupService.GetGroupInfoAsync
		local getInfoSpy = sert.spy(GroupService, "GetGroupInfoAsync", function(_self, gid)
			if gid == 3000 then
				error("GroupService error")
			end
			return origGetInfo(_self, gid)
		end)
		Data.async.group[3000] = {
			{ rank = 200, roles = { "mod" } },
		}
		sert.eq(Auth.isPublicRole("mod"), true)
		getInfoSpy:restore()
	end)

	test("banHandler checks site-unban history and formats timed, permanent, and server ban kick messages", function()
		local h = Harness.newEnv({ isStudio = false })
		local Data = h:requireData()
		local Auth = h:requireAuth()
		Data.SEPARATE_DATASTORE = true

		-- 1. Site-unban check via Players:GetBanHistoryAsync when banInfo[3] ~= 0 and last.Ban == false
		local pSite = h.env:addPlayer(601, "SiteUnbanned")
		Data.bans["601"] = { "SiteUnbanned", "Appeal accepted", -1, 1 }
		h.env.bans[601] = { Ban = false }
		sert.eq(Auth.banHandler(pSite), nil)
		sert.eq(kickOf(h, pSite), nil)
		sert.eq(Data.bans["601"], nil)

		-- 2. Timed ban kick message (> 0)
		local pTimed = h.env:addPlayer(602, "TimedUser")
		local now = h.env.globals.os.time()
		Data.bans["602"] = { "TimedUser", "Spamming chat", now + 120, 1 }
		sert.eq(Auth.banHandler(pTimed), true)
		sert.eq(string.find(tostring(kickOf(h, pTimed)), "2 minutes", 1, true) ~= nil, true)
		sert.eq(string.find(tostring(kickOf(h, pTimed)), "Reason: Spamming chat", 1, true) ~= nil, true)

		-- 3. Permanent ban kick message (-1)
		local pPerm = h.env:addPlayer(603, "PermUser")
		Data.bans["603"] = { "PermUser", "Exploiting", -1, 1 }
		sert.eq(Auth.banHandler(pPerm), true)
		sert.eq(string.find(tostring(kickOf(h, pPerm)), "permanently banned", 1, true) ~= nil, true)
		sert.eq(string.find(tostring(kickOf(h, pPerm)), "Reason: Exploiting", 1, true) ~= nil, true)

		-- 4. Server ban kick message (nil timestamp, no reason) and nameless permanent ban
		local pSrv = h.env:addPlayer(604, "ServerBanUser")
		Data.bans["604"] = { "ServerBanUser", nil, nil, 1 }
		sert.eq(Auth.banHandler(pSrv), true)
		sert.eq(kickOf(h, pSrv), "You are banned from this server!")

		local pHole = h.env:addPlayer(605, "HoleBanUser")
		Data.bans["605"] = { nil, nil, -1, 1 }
		sert.eq(Auth.banHandler(pHole), true)
		sert.eq(kickOf(h, pHole), "You are permanently banned from this experience!")

		-- 5. Creator or userId < 1 or unbanned player is never kicked
		Data.creatorId = 777
		local pCreator = h.env:addPlayer(777, "CreatorUser")
		Data.bans["777"] = { "CreatorUser", "should not kick", -1, 1 }
		sert.eq(Auth.banHandler(pCreator), nil)
		sert.eq(kickOf(h, pCreator), nil)
	end)

	test(
		"banUsers and unbanUsers handle BanAsync/UnbanAsync retries, server-ban demotion, and non-banasync callers",
		function()
			local h = Harness.newEnv({ isStudio = false })
			local Data = h:requireData()
			local Auth = h:requireAuth()
			Data.SEPARATE_DATASTORE = false

			local modPlr = h.env:addPlayer(10, "ModNoBanAsync")
			Auth.userRoleAdd(modPlr.UserId, "mod")

			local banAttempts = 0
			local banSpy = sert.spy(h.env.Players, "BanAsync", function(_self, config)
				banAttempts += 1
				if banAttempts == 1 then
					error('{"code": "RateLimit"}')
				end
				return config
			end)

			local unbanAttempts = 0
			local unbanSpy = sert.spy(h.env.Players, "UnbanAsync", function(_self, config)
				unbanAttempts += 1
				if unbanAttempts == 1 then
					error('{"code": "ServiceUnavailable"}')
				end
				return config
			end)

			-- Hook.ban fires only with the users actually banned
			local hookBans = {}
			h:requireShared("Hook").ban:Connect(function(userIds)
				table.insert(hookBans, userIds)
			end)
			local banned

			-- 1. Permanent ban with BanAsync transient failure then retry success
			h.env.task.spawn(function()
				banned = Auth.banUsers({ 801 }, "Exploit", -1, nil, true)
			end)
			h.env:step(5)
			sert.eq(banned, { 801 })
			sert.eq(hookBans, { { 801 } })
			sert.eq(banAttempts, 2)
			sert.eq(Data.bans["801"] ~= nil, true)
			sert.eq(Data.bans["801"][2], "Exploit")
			sert.eq(Data.bans["801"][3], -1)
			sert.eq(Data.Sync.bans["801"] ~= nil, true)

			-- 2. Non-banasync caller (modPlr, rank 2, lacks banasync) can't change the persistent ban (801): demoting it to
			-- a server ban would lift the universe ban, which only banasync may do (as in unbanUsers)
			h.env.task.spawn(function()
				banned = Auth.banUsers({ 801, 803 }, "Demoted to server ban", 600, modPlr.UserId, false)
			end)
			h.env:step(5)
			-- only the user without a saved ban is banned (for the server) and reported
			sert.eq(banned, { 803 })
			sert.eq(hookBans[2], { 803 })
			sert.eq(Data.bans["803"][3], nil)
			-- a call that only meets saved bans bans no one and fires no hook
			h.env.task.spawn(function()
				banned = Auth.banUsers({ 801 }, "Demoted to server ban", 600, modPlr.UserId, false)
			end)
			h.env:step(5)
			sert.eq(banned, {})
			sert.eq(#hookBans, 2)
			sert.eq(unbanAttempts, 0)
			sert.eq(Data.bans["801"][2], "Exploit")
			sert.eq(Data.bans["801"][3], -1)
			sert.eq(Data.Sync.bans["801"] ~= Data.REMOVE, true)

			-- A banasync caller with a restricted role demotes it to a server ban (duration = 0), which sets
			-- Data.Sync.bans["801"] = Data.REMOVE and calls Players:UnbanAsync with retry
			local adminPlr = h.env:addPlayer(11, "AdminBanAsync")
			Auth.userRoleAdd(adminPlr.UserId, "admin")
			h.env.task.spawn(function()
				Auth.banUsers({ 801 }, "Demoted to server ban", 0, adminPlr.UserId, false)
			end)
			h.env:step(5)
			sert.eq(unbanAttempts, 2)
			sert.eq(Data.bans["801"] ~= nil, true)
			sert.eq(Data.bans["801"][2], "Demoted to server ban")
			sert.eq(Data.bans["801"][3], nil)
			sert.eq(Data.Sync.bans["801"], Data.REMOVE)

			-- Hook.unban fires only with the users actually unbanned: a non-banasync caller keeps saved bans
			local hookUnbans = {}
			h:requireShared("Hook").unban:Connect(function(userIds)
				table.insert(hookUnbans, userIds)
			end)
			Data.bans["804"] = { "Perm804", "reason", -1, 1 }
			sert.eq(Auth.unbanUsers({ 804, 801 }, modPlr.UserId), { 801 })
			sert.eq(hookUnbans, { { 801 } })
			sert.eq(Data.bans["801"], nil)
			sert.eq(Data.bans["804"] ~= nil, true)
			sert.eq(Auth.unbanUsers({ 804 }, modPlr.UserId), {})
			sert.eq(#hookUnbans, 1)

			-- 3. unbanUsers with BanAsync retry when unbanning a persistent ban
			Data.bans["802"] = { "Perm802", "reason", -1, 1 }
			unbanAttempts = 0
			h.env.task.spawn(function()
				Auth.unbanUsers({ 802 }, nil, true)
			end)
			h.env:step(5)
			sert.eq(unbanAttempts, 2)
			sert.eq(Data.bans["802"], nil)
			sert.eq(Data.Sync.bans["802"], Data.REMOVE)

			banSpy:restore()
			unbanSpy:restore()
		end
	)

	test(
		"userRoleAdd/Remove unrestricted flags, roleCanUseCommand overrides/aliases/permissions, hasPermission freeAdmin, and targetUserArgument limits",
		function()
			local h = Harness.newEnv({ isStudio = false })
			local Data = h:requireData()
			local Auth = h:requireAuth()
			local _K = h:requireK()

			-- 1. userRoleAdd("everyone") returns false
			sert.eq(Auth.userRoleAdd(901, "everyone"), false)
			sert.eq(Data.members["901"], nil)

			-- 2. unrestricted flag lifecycle on new and existing members
			sert.eq(Auth.userRoleAdd(901, "vip", false, false), true)
			sert.eq(Data.members["901"].unrestricted, nil)

			-- Adding a second role with unrestricted = true initializes member.unrestricted
			sert.eq(Auth.userRoleAdd(901, "mod", false, true), true)
			sert.eq(Data.members["901"].unrestricted.mod, true)
			-- Because "mod" is marked unrestricted in member.unrestricted, hasRestrictedRole is false!
			sert.eq(Auth.hasRestrictedRole(901), false)

			-- Re-adding "mod" with unrestricted = false clears member.unrestricted.mod
			sert.eq(Auth.userRoleAdd(901, "mod", false, false), false)
			sert.eq(Data.members["901"].unrestricted.mod, nil)
			sert.eq(Auth.hasRestrictedRole(901), true)

			-- Removing a role also clears its unrestricted entry
			sert.eq(Auth.userRoleAdd(901, "admin", false, true), true)
			sert.eq(Data.members["901"].unrestricted.admin, true)
			sert.eq(Auth.userRoleRemove(901, "admin"), true)
			sert.eq(Data.members["901"].unrestricted.admin, nil)

			-- 3. roleCanUseCommand: invalid role, invalid command, alias override, and command.permissions check
			sert.eq(Auth.roleCanUseCommand("undefined_role_xyz", "ban"), false)
			sert.eq(Auth.roleCanUseCommand("mod", "nonexistent_command_xyz"), false)
			sert.eq(Auth.roleCanUseCommand("mod", 12345 :: any), false)

			Data.roles.mod.commands = { flight_alias = true, blocked_cmd = false }
			local cmdWithAlias = {
				name = "fly_custom",
				aliases = { "flight_alias" },
				group = "Administration",
			}
			sert.eq(Auth.roleCanUseCommand("mod", cmdWithAlias), true)
			sert.eq(Auth.roleCanUseCommand("mod", { name = "blocked_cmd", group = "Moderation" }), false)

			local permCmd = {
				name = "perm_gated",
				group = "Moderation",
				permissions = { banasync = true },
			}
			sert.eq(Auth.roleCanUseCommand("mod", permCmd), false)
			sert.eq(Auth.roleCanUseCommand("admin", permCmd), true)

			-- 4. hasPermission via freeAdmin and friendRoles in isPublicRole
			Data.settings.freeAdmin = { "mod" }
			sert.eq(Auth.hasPermission(99999, "serverlogs"), true)
			Data.settings.freeAdmin = {}

			Data.friendRoles = { "vip" }
			sert.eq(Auth.isPublicRole("vip"), true)
			Data.friendRoles = {}

			-- 5. targetUserArgument: invalid userId, targetLimits exceeded, ignoreSelf, and loading user
			local pMod = h.env:addPlayer(910, "ModCaller")
			h.env:addPlayer(911, "LoadingTarget")
			pMod:SetAttribute("_KRolesLoaded", true)
			-- LoadingTarget intentionally does NOT have _KRolesLoaded set
			Auth.userRoleAdd(910, "mod")
			local modRank, modRole = Auth.getRank(910)
			modRole.limits = { targets = 1 }

			local arg = {
				_K = _K,
				definition = { lowerRank = true, ignoreSelf = true },
				command = { from = 910, fromRank = modRank, fromRole = modRole, rank = 2 },
			}

			local badVal, badErr = Auth.targetUserArgument(arg, 1.5, 1.5)
			sert.eq(badVal, nil)
			sert.eq(badErr, "Invalid user")

			local infVal, infErr = Auth.targetUserArgument(arg, math.huge, math.huge)
			sert.eq(infVal, nil)
			sert.eq(infErr, "Invalid user")

			-- ignoreSelf blocks self-targeting
			Data.targetLimits[910] = 0
			local selfVal, selfErr = Auth.targetUserArgument(arg, 910, 910)
			sert.eq(selfVal, nil)
			sert.eq(selfErr, "Can't target yourself")

			-- Loading user (missing _KRolesLoaded) is rejected when lowerRank is true
			Data.targetLimits[910] = 0
			local loadVal, loadErr = Auth.targetUserArgument(arg, 911, 911)
			sert.eq(loadVal, nil)
			sert.eq(loadErr, "Can't target loading user")

			-- Exceeding limits.targets (1) rejects subsequent targets
			Data.targetLimits[910] = 2
			local limVal, limErr = Auth.targetUserArgument(arg, 911, 911)
			sert.eq(limVal, nil)
			sert.eq(limErr, "Can only target 1 user")
			modRole.limits = nil
		end
	)

	test("userAsyncRoles and getGroupEntryRank handle offline users, service errors, and 60s retry reset", function()
		local h = Harness.newEnv({ isStudio = false })
		local Data = h:requireData()
		local Auth = h:requireAuth()

		local pOnline = h.env:addPlayer(950, "OnlineErrUser")

		Data.async.group[4000] = { { rank = 10, roles = { "vip" } } }
		Data.async.gamepass[666] = { "vip" }
		Data.async.asset[888] = { "mod" }
		Data.async.subscription["sub_err"] = { "admin" }

		-- 1. Offline user (not in Players) stops before asset/subscription checks
		Auth.userAsyncRoles(999999, true)
		sert.eq(Data.members["999999"], nil)

		-- 2. Service errors across GroupService and MarketplaceService are caught and warned without throwing
		local GroupService = h.env.game:GetService("GroupService")
		local MarketplaceService = h.env.game:GetService("MarketplaceService")

		local spies = {
			sert.spy(GroupService, "GetGroupsAsync", function()
				error("GetGroupsAsync failed")
			end),
			sert.spy(GroupService, "GetGroupInfoAsync", function()
				return { Roles = {} } -- no positive rank -> entry = nil -> schedules 60s reset
			end),
			sert.spy(MarketplaceService, "UserOwnsGamePassAsync", function()
				error("UserOwnsGamePassAsync failed")
			end),
			sert.spy(MarketplaceService, "PlayerOwnsAssetAsync", function()
				error("PlayerOwnsAssetAsync failed")
			end),
			sert.spy(MarketplaceService, "GetUserSubscriptionStatusAsync", function()
				error("GetUserSubscriptionStatusAsync failed")
			end),
		}

		h.env.task.spawn(function()
			Auth.prefetchGroupEntryRanks()
			Auth.userAsyncRoles(pOnline.UserId, true)
		end)
		-- Advance in increments so all sequential Util.Retry exponential backoffs and the 60s groupEntryRanks reset delay fire
		for _ = 1, 30 do
			h.env:step(10)
		end
		sert.eq(Data.members[tostring(pOnline.UserId)], nil)

		for _, s in spies do
			s:restore()
		end
	end)

	test("userAsyncRoles keeps a player loading while their groups are retried for about a minute", function()
		local h = Harness.newEnv({ isStudio = false })
		local Data = h:requireData()
		local Auth = h:requireAuth()
		local _K = h:requireK()

		local GroupService = h.env.game:GetService("GroupService")
		local origGetGroups = GroupService.GetGroupsAsync
		local groupCalls, failCalls = 0, 0
		local getGroupsSpy = sert.spy(GroupService, "GetGroupsAsync", function(self, userId)
			groupCalls += 1
			if groupCalls <= failCalls then
				error("GetGroupsAsync failed", 0)
			end
			return origGetGroups(self, userId)
		end)
		local warnings = {}
		h.env.game:GetService("LogService").MessageOut:Connect(function(message, messageType)
			if messageType.Name == "MessageWarning" then
				table.insert(warnings, message)
			end
		end)

		Data.async.group[4100] = { { rank = 200, roles = { "superadmin" } } }
		h.env:setGroupRank(961, 4100, 250)
		h.env:setGroupRank(962, 4100, 250)
		h.env:setGroupRank(963, 4100, 250)
		Data.async.gamepass[667] = { "vip" }
		h.env:setGamePass(961, 667, true)
		-- unowned assets and subscriptions aren't warnings
		Data.async.asset[889] = { "mod" }
		Data.async.subscription.sub_none = { "mod" }

		local adminPlr = h.env:addPlayer(60, "Administrator")
		adminPlr:SetAttribute("_KRolesLoaded", true)
		Auth.userRoleAdd(60, "admin")
		local rank, role = Auth.getRank(60)
		local arg = {
			_K = _K,
			definition = { lowerRank = true },
			command = { from = 60, fromRank = rank, fromRole = role, rank = rank },
		}

		-- joins like the server does: async roles, then loaded; returns the seconds it took
		local function join(player)
			local elapsed, done = 0, false
			h.env.task.spawn(function()
				Auth.userAsyncRoles(player.UserId, true)
				player:SetAttribute("_KRolesLoaded", true)
				done = true
			end)
			while not done and elapsed < 120 do
				h.env:step(1)
				elapsed += 1
				if elapsed == 31 then
					-- the first fetch gave up after its own retries; other sources aren't held back
					sert.eq(Auth.hasRole(player.UserId, "vip"), player.UserId == 961)
					if failCalls > 5 then
						sert.eq(done, false)
						Data.targetLimits[60] = 0
						sert.eq(
							select(2, Auth.targetUserArgument(arg, player.UserId, player)),
							"Can't target loading user"
						)
					end
				end
			end
			return elapsed
		end

		-- groups that load on a later retry give their roles before the player loads
		failCalls = 6
		local recovered = h.env:addPlayer(961, "RecoveredStaff")
		local elapsed = join(recovered)
		sert.eq(elapsed >= 45 and elapsed <= 46, true)
		sert.eq(groupCalls, 7)
		sert.eq(Auth.hasRole(961, "superadmin"), true)
		sert.eq(#warnings, 0)
		Data.targetLimits[60] = 0
		sert.eq(select(2, Auth.targetUserArgument(arg, 961, recovered)), "Can only target lower ranks")
		-- later calls without bustCache are cached
		Auth.userAsyncRoles(961)
		sert.eq(groupCalls, 7)

		-- groups that never load give up after about a minute and warn once
		groupCalls, failCalls = 0, math.huge
		local unlucky = h.env:addPlayer(962, "UnluckyStaff")
		elapsed = join(unlucky)
		sert.eq(elapsed >= 60 and elapsed <= 61, true)
		sert.eq(groupCalls, 8)
		sert.eq(Auth.hasRole(962, "superadmin"), false)
		sert.eq(warnings, { "GetGroupsAsync failed" })

		-- retries stop when the player leaves, before or during a wait
		local stopped
		local function leave(leaveAt)
			groupCalls, stopped = 0, false
			local leaver = h.env:addPlayer(963, "Leaver")
			h.env.task.spawn(function()
				Auth.userAsyncRoles(963, true)
				stopped = true
			end)
			for second = 1, 31 do
				h.env:step(1)
				if second == leaveAt then
					h.env:removePlayer(leaver)
				end
			end
		end
		leave(20)
		sert.eq(stopped, true)
		sert.eq(groupCalls, 5)
		leave(31)
		sert.eq(stopped, false)
		for _ = 1, 5 do
			h.env:step(1)
		end
		sert.eq(stopped, true)
		sert.eq(groupCalls, 5)

		-- users out of this server aren't retried
		groupCalls, stopped = 0, false
		h.env.task.spawn(function()
			Auth.userAsyncRoles(964, true)
			stopped = true
		end)
		for _ = 1, 31 do
			h.env:step(1)
		end
		sert.eq(stopped, true)
		sert.eq(groupCalls, 5)

		getGroupsSpy:restore()
	end)

	test("targetUserArgument checks the group and gamepass ranks of users out of this server", function()
		local h = Harness.newEnv({ isStudio = false })
		local Data = h:requireData()
		local Auth = h:requireAuth()
		local _K = h:requireK()

		local GroupService = h.env.game:GetService("GroupService")
		local origGetGroups = GroupService.GetGroupsAsync
		local groupCalls, failGroups = 0, false
		local getGroupsSpy = sert.spy(GroupService, "GetGroupsAsync", function(self, userId)
			groupCalls += 1
			if failGroups then
				error("GetGroupsAsync failed")
			end
			return origGetGroups(self, userId)
		end)

		-- group 5000 rank 200+ gets SuperAdmin; gamepass 556 gets Administrator
		Data.async.group[5000] = { { rank = 200, roles = { "superadmin" } } }
		h.env:setGroupRank(70001, 5000, 250)
		h.env:setGroupRank(70003, 5000, 10)
		h.env.groups[5000].Roles = { { Name = "Member", Rank = 10 }, { Name = "Staff", Rank = 200 } }
		Data.async.gamepass[556] = { "admin" }
		h.env:setGamePass(70002, 556, true)

		local adminPlr = h.env:addPlayer(60, "Administrator")
		adminPlr:SetAttribute("_KRolesLoaded", true)
		Auth.userRoleAdd(60, "admin")
		local rank, role = Auth.getRank(60)
		local arg = {
			_K = _K,
			definition = { lowerRank = true },
			command = { from = 60, fromRank = rank, fromRole = role, rank = rank },
		}
		local function target(userId)
			Data.targetLimits[60] = 0
			local result
			h.env.task.spawn(function()
				result = table.pack(Auth.targetUserArgument(arg, userId, userId))
			end)
			-- failing web calls retry with backoff for 30 seconds
			for _ = 1, 31 do
				if result then
					break
				end
				h.env:step(1)
			end
			return result[1], result[2]
		end

		-- an offline group SuperAdmin and an offline gamepass Administrator can't be targeted by an Administrator
		sert.eq(select(2, target(70001)), "Can only target lower ranks")
		sert.eq(select(2, target(70002)), "Can only target lower ranks")
		-- an ordinary offline user can
		sert.eq(target(70003), 70003)
		sert.eq(groupCalls, 3)

		-- resolved ranks are cached for 60 seconds
		sert.eq(select(2, target(70001)), "Can only target lower ranks")
		sert.eq(groupCalls, 3)
		h.env:step(61)
		sert.eq(select(2, target(70001)), "Can only target lower ranks")
		sert.eq(groupCalls, 4)

		-- web call failures fail closed
		failGroups = true
		local failVal, failErr = target(70004)
		sert.eq(failVal, nil)
		sert.eq(failErr, "Can't verify the rank of an offline user")

		-- a caller gets one offline lookup at a time, so it can't flood web calls
		local first
		h.env.task.spawn(function()
			Data.targetLimits[60] = 0
			first = table.pack(Auth.targetUserArgument(arg, 70008, 70008))
		end)
		local callsBefore = groupCalls
		sert.eq(select(2, target(70009)), "Can't verify the rank of an offline user")
		sert.eq(groupCalls, callsBefore)
		for _ = 1, 31 do
			if first then
				break
			end
			h.env:step(1)
		end
		sert.eq(first[2], "Can't verify the rank of an offline user")
		failGroups = false
		sert.eq(target(70009), 70009)
		local ownsPassSpy = sert.spy(h.env.game:GetService("MarketplaceService"), "UserOwnsGamePassAsync", function()
			error("UserOwnsGamePassAsync failed")
		end)
		sert.eq(select(2, target(70005)), "Can't verify the rank of an offline user")
		ownsPassSpy:restore()

		-- asset and subscription roles need the Player: fail closed only when they reach the command rank
		Data.async.asset[778] = { "vip" }
		Data.async.subscription.sub_low = { "mod" }
		sert.eq(target(70003), 70003)
		Data.async.asset[778] = { "admin" }
		sert.eq(select(2, target(70003)), "Can't verify the rank of an offline user")
		Data.async.asset[778] = nil
		Data.async.subscription.sub_high = { "superadmin" }
		sert.eq(select(2, target(70003)), "Can't verify the rank of an offline user")
		Data.async.subscription.sub_high = nil

		-- loaded players in this server keep today's check, without web calls
		local present = h.env:addPlayer(70006, "Present")
		present:SetAttribute("_KRolesLoaded", true)
		h.env:setGroupRank(70006, 5000, 250)
		groupCalls = 0
		sert.eq(target(70006), 70006)
		Auth.userRoleAdd(70006, "superadmin")
		sert.eq(select(2, target(70006)), "Can only target lower ranks")
		sert.eq(groupCalls, 0)

		-- callers with the admin permission return early
		Data.roles.admin.permissions.admin = true
		sert.eq(target(70007), 70007)
		Data.roles.admin.permissions.admin = nil
		sert.eq(groupCalls, 0)

		getGroupsSpy:restore()
	end)

	test("targetUserArgument skips offline rank lookups for skipOfflineRank arguments", function()
		local h = Harness.newEnv({ isStudio = false })
		local Data = h:requireData()
		local Auth = h:requireAuth()
		local _K = h:requireK()

		local groupSpy = sert.spy(h.env.game:GetService("GroupService"), "GetGroupsAsync")
		local passSpy = sert.spy(h.env.game:GetService("MarketplaceService"), "UserOwnsGamePassAsync")
		Data.async.group[5000] = { { rank = 200, roles = { "superadmin" } } }
		h.env:setGroupRank(70001, 5000, 250)
		Data.async.gamepass[556] = { "admin" }

		local adminPlr = h.env:addPlayer(60, "Administrator")
		adminPlr:SetAttribute("_KRolesLoaded", true)
		Auth.userRoleAdd(60, "admin")
		local rank, role = Auth.getRank(60)
		local function target(definition, userId, value)
			Data.targetLimits[60] = 0
			local arg = {
				_K = _K,
				definition = definition,
				command = { from = 60, fromRank = rank, fromRole = role, rank = rank },
			}
			return Auth.targetUserArgument(arg, userId, value)
		end
		local unban = { lowerRank = true, skipOfflineRank = true }

		-- an offline group SuperAdmin can be unbanned without web calls, but not banned
		sert.eq(target(unban, 70001, "70001"), "70001")
		sert.eq(groupSpy.callCount + passSpy.callCount, 0)
		sert.eq(select(2, target({ lowerRank = true }, 70001, "70001")), "Can only target lower ranks")
		sert.eq(groupSpy.callCount + passSpy.callCount > 0, true)

		-- roles known in this server and loading players are still checked
		groupSpy:reset()
		passSpy:reset()
		Auth.userRoleAdd(70002, "superadmin")
		sert.eq(select(2, target(unban, 70002, "70002")), "Can only target lower ranks")
		local loading = h.env:addPlayer(70003, "Loading")
		sert.eq(select(2, target(unban, 70003, loading)), "Can't target loading user")
		sert.eq(groupSpy.callCount + passSpy.callCount, 0)

		groupSpy:restore()
		passSpy:restore()
	end)

	test("targetUserArgument on the client never checks web ranks", function()
		local h = Harness.newEnv({ isStudio = false, isClient = true })
		h:mockClientRemotes()
		local Data = h:requireData()
		local Auth = h:requireAuth()

		local groupSpy = sert.spy(h.env.game:GetService("GroupService"), "GetGroupsAsync")
		Data.async.group[5000] = { { rank = 200, roles = { "superadmin" } } }
		Data.async.asset[778] = { "superadmin" }
		Data.members["61"] = { name = "ClientAdmin", roles = { "admin" }, persist = {} }
		local rank, role = Auth.getRank(61)
		Data.targetLimits[61] = 0
		local arg = {
			_K = { Data = Data },
			definition = { lowerRank = true },
			command = { from = 61, fromRank = rank, fromRole = role, rank = rank },
		}
		sert.eq(Auth.targetUserArgument(arg, 70001, 70001), 70001)
		sert.eq(groupSpy.callCount, 0)
		groupSpy:restore()
	end)

	test(
		"banUsers and unbanUsers treat expired timed bans as non-persistent so moderators without banasync can act",
		function()
			local h = Harness.newEnv({ isStudio = false })
			local Data = h:requireData()
			local Auth = h:requireAuth()

			h.env:addPlayer(21, "ModCaller")
			Auth.userRoleAdd(21, "mod") -- has ban & unban, but NOT banasync

			-- Seed an already-expired timed ban (0 < ban[3] <= os.time()) and an active timed ban (ban[3] > os.time())
			local now = h.env.globals.os.time()
			Data.bans["801"] = { "ExpiredUser", "old timed ban", now - 10, 1 }
			Data.bans["802"] = { "ActiveTimedUser", "active timed ban", now + 3600, 1 }

			-- Moderator without banasync can unban expired 801, but cannot unban active 802
			local unbanned = Auth.unbanUsers({ 801, 802 }, 21)
			sert.eq(unbanned, { 801 })
			sert.eq(Data.bans["801"], nil)
			sert.eq(Data.bans["802"] ~= nil, true)

			-- Re-seed expired timed ban on 801; moderator without banasync can replace it with a session ban
			Data.bans["801"] = { "ExpiredUser", "old timed ban", now - 10, 1 }
			local banned = Auth.banUsers({ 801, 802 }, "new session ban", 0, 21)
			sert.eq(banned, { 801 })
		end
	)

	test(
		"sert.laws.differential verifies getRank, hasPermission, hasRole, hasCommand, and getRoleFromRank against reference oracle",
		function()
			local h = Harness.newEnv({ isStudio = false })
			local Data = h:requireData()
			local Auth = h:requireAuth()
			local Registry = h:requireRegistry()

			Registry.commands.help = { name = "help", group = "utility", aliases = {}, args = {} }
			Registry.commands.ban = { name = "ban", group = "moderation", aliases = {}, args = {} }
			Registry.commands.role = { name = "role", group = "administration", aliases = {}, args = {} }
			Registry.commands.shutdown = { name = "shutdown", group = "superadmin", aliases = {}, args = {} }

			local rolePool = { "vip", "mod", "admin", "superadmin" }
			local permPool = { "admin", "banasync", "saveRoles", "settings", "serverlogs", "targetOthers" }
			local cmdPool = { "help", "ban", "role", "shutdown" }
			local rankNums: { [string]: number } = {
				everyone = 0,
				vip = 1,
				mod = 2,
				admin = 3,
				superadmin = 4,
				creator = math.huge,
			}

			local scenarioGen = function(g: any)
				local memberRoles = {}
				for _, r in rolePool do
					if g:bool(0.35) then
						table.insert(memberRoles, r)
					end
				end
				table.sort(memberRoles, Auth.roleIdSort)
				local freeRoles = {}
				for _, r in { "vip", "mod", "admin" } do
					if g:bool(0.25) then
						table.insert(freeRoles, r)
					end
				end
				return {
					isCreator = g:bool(0.15),
					memberRoles = memberRoles,
					freeRoles = freeRoles,
					queryRank = g:pick({ -5, 0, 0.5, 1, 2, 2.5, 3, 4, 10, math.huge }),
				}
			end

			sert.laws.differential("Auth rank, permission, role, and command resolution", {
				gen = scenarioGen,
				sut = function(sc: any)
					local uid = if sc.isCreator then Data.creatorId else 707
					if #sc.memberRoles > 0 then
						Data.members[tostring(uid)] = {
							name = "DiffUser",
							roles = table.clone(sc.memberRoles),
							persist = {},
						}
					else
						Data.members[tostring(uid)] = nil
					end
					Data.settings.freeAdmin = table.clone(sc.freeRoles)

					local rank, roleObj = Auth.getRank(uid)
					local perms = {}
					for _, p in permPool do
						perms[p] = Auth.hasPermission(uid, p)
					end
					local rolesOut = {}
					for _, r in ROLE_IDS do
						rolesOut[r] = Auth.hasRole(uid, r)
					end
					local cmdsOut = {}
					for _, c in cmdPool do
						cmdsOut[c] = Auth.hasCommand(uid, c)
					end
					local roleFromRank = Auth.getRoleFromRank(sc.queryRank)._key
					return {
						rank = rank,
						roleKey = roleObj._key,
						perms = perms,
						roles = rolesOut,
						cmds = cmdsOut,
						roleFromRank = roleFromRank,
					}
				end,
				oracle = function(sc: any)
					local maxRank = 0
					local maxRoleKey = "everyone"
					if sc.isCreator then
						maxRank = math.huge
						maxRoleKey = "creator"
					else
						for _, list in { sc.memberRoles, sc.freeRoles } do
							for _, r in list do
								local rk = rankNums[r]
								if rk and rk > maxRank then
									maxRank = rk
									maxRoleKey = r
								end
							end
						end
					end

					local function roleHasPerm(roleKey: string, perm: string): boolean
						local roleDef = Data.roles[roleKey]
						if not roleDef then
							return false
						end
						return (roleDef.permissions.admin or roleDef.permissions[perm]) == true
					end

					local perms = {}
					for _, p in permPool do
						local ok = sc.isCreator or roleHasPerm("everyone", p)
						if not ok then
							for _, r in sc.memberRoles do
								if roleHasPerm(r, p) then
									ok = true
									break
								end
							end
						end
						if not ok then
							for _, r in sc.freeRoles do
								if roleHasPerm(r, p) then
									ok = true
									break
								end
							end
						end
						perms[p] = ok
					end

					local rolesOut = {}
					for _, r in ROLE_IDS do
						if sc.isCreator or table.find(sc.memberRoles, r) ~= nil then
							rolesOut[r] = true
						else
							rolesOut[r] = maxRank > rankNums[r]
						end
					end

					local cmdsOut = {}
					for _, c in cmdPool do
						local cmdDef = Registry.commands[c]
						if sc.isCreator then
							cmdsOut[c] = math.huge
						else
							local matched: boolean | number = false
							for _, r in sc.memberRoles do
								if Auth.roleCanUseCommand(r, cmdDef) then
									matched = rankNums[r]
									break
								end
							end
							if matched == false then
								for _, r in sc.freeRoles do
									if Auth.roleCanUseCommand(r, cmdDef) then
										matched = rankNums[r]
										break
									end
								end
							end
							if matched == false and Auth.roleCanUseCommand("everyone", cmdDef) then
								matched = 0
							end
							cmdsOut[c] = matched
						end
					end

					local closestKey = "creator"
					local closestRank = math.huge
					for _, r in ROLE_IDS do
						local rk = rankNums[r]
						if rk == sc.queryRank then
							closestKey = r
							break
						elseif rk >= sc.queryRank and rk < closestRank then
							closestRank = rk
							closestKey = r
						end
					end

					return {
						rank = maxRank,
						roleKey = maxRoleKey,
						perms = perms,
						roles = rolesOut,
						cmds = cmdsOut,
						roleFromRank = closestKey,
					}
				end,
			}, { runs = 80 })
		end
	)

	test(
		"sert.laws.remote verifies banUsers, unbanUsers, and targetUserArgument under adversarial and unprivileged inputs",
		function()
			local h = Harness.newEnv({ isStudio = false })
			local Data = h:requireData()
			local Auth = h:requireAuth()
			local _K = { Data = Data }

			local adminPlr = h.env:addPlayer(101, "SuperAdminProtected")
			local modPlr = h.env:addPlayer(201, "ModCaller")
			local guestPlr = h.env:addPlayer(202, "GuestCaller")
			for _, p in { adminPlr, modPlr, guestPlr } do
				p:SetAttribute("_KRolesLoaded", true)
			end
			Auth.userRoleAdd(101, "superadmin")
			Auth.userRoleAdd(201, "mod")

			Data.bans["500"] = { "PersistentBanUser", "Permanent ban", -1, 101 }

			-- 1. Unprivileged guest calling Auth.banUsers / Auth.unbanUsers / Auth.targetUserArgument
			sert.roblox.fuzzRemote("Auth.banUsers & unbanUsers (guest)", {
				runs = 50,
				maxArgs = 3,
				makePlayer = function()
					return guestPlr
				end,
				validGen = sert.gen.map(
					sert.gen.tuple({
						sert.gen.pick({ 101, 201, 500 }),
						sert.gen.malformedString(),
						sert.gen.boundaryInt(-1, 3600),
					}),
					function(tup)
						tup._validTuple = true
						return tup
					end
				),
				handler = function(plr: any, targetId: any, reason: any, duration: any)
					if type(targetId) == "table" and rawget(targetId, "_validTuple") then
						targetId, reason, duration = targetId[1], targetId[2], targetId[3]
					end
					local rank, role = Auth.getRank(plr.UserId)
					Data.targetLimits[plr.UserId] = 0
					local arg = {
						_K = _K,
						definition = { lowerRank = true },
						command = { from = plr.UserId, fromRank = rank, fromRole = role, rank = rank },
					}
					if type(targetId) == "number" and targetId > 0 and math.floor(targetId) == targetId then
						local allowed = Auth.targetUserArgument(arg, targetId, targetId)
						if allowed then
							Auth.banUsers(
								{ targetId },
								if type(reason) == "string" then reason else nil,
								duration,
								plr.UserId
							)
							Auth.unbanUsers({ targetId }, plr.UserId)
						end
					end
				end,
				checkState = function(plr: any)
					sert.eq(Auth.getRank(plr.UserId), 0)
					sert.eq(Data.bans["101"], nil)
					sert.eq(Data.bans["201"], nil)
					sert.eq(Data.bans["500"] ~= nil, true)
					sert.eq(Data.bans["500"][3], -1)
				end,
			})

			-- 2. Moderator (without banasync) calling Auth.banUsers / Auth.unbanUsers against saved ban 500 & higher-rank 101
			sert.roblox.fuzzRemote("Auth.banUsers & unbanUsers (mod boundary)", {
				runs = 50,
				maxArgs = 3,
				makePlayer = function()
					return modPlr
				end,
				validGen = sert.gen.map(
					sert.gen.tuple({
						sert.gen.pick({ 101, 500 }),
						sert.gen.malformedString(),
						sert.gen.boundaryInt(-1, 3600),
					}),
					function(tup)
						tup._validTuple = true
						return tup
					end
				),
				handler = function(plr: any, targetId: any, reason: any, duration: any)
					if type(targetId) == "table" and rawget(targetId, "_validTuple") then
						targetId, reason, duration = targetId[1], targetId[2], targetId[3]
					end
					if type(targetId) == "number" and (targetId == 101 or targetId == 500) then
						local safeDur = if type(duration) == "number" and duration == duration
							then math.floor(duration)
							else 0
						Auth.banUsers(
							{ targetId },
							if type(reason) == "string" then reason else "fuzz",
							safeDur,
							plr.UserId
						)
						Auth.unbanUsers({ targetId }, plr.UserId)
					end
				end,
				checkState = function(plr: any)
					sert.eq(Auth.getRank(plr.UserId), 2)
					sert.eq(Data.bans["101"], nil)
					sert.eq(Data.bans["500"] ~= nil, true)
					sert.eq(Data.bans["500"][3], -1)
				end,
			})
		end
	)

	do
		local compH: any, compData: any, compAuth: any
		local COMP_ROLES = { "everyone", "vip", "mod", "admin", "superadmin", "creator" }
		local COMP_PERMS = { "admin", "banasync", "saveRoles", "settings", "serverlogs", "targetOthers" }
		local COMP_GROUPS =
			{ "utility", "vip", "moderation", "general", "environment", "fun", "administration", "superadmin" }
		local COMP_CMDS = { "help", "version", "fly", "ban", "unban", "announce", "settings", "shutdown" }

		sert.prop(
			"Metamorphic Permission Composition Law: Rank(A ∪ B) == math.max(Rank(A), Rank(B)) and Perms(A ∪ B) == Perms(A) ∪ Perms(B)",
			function(g)
				if not compH then
					compH = Harness.newEnv({ isStudio = false })
					compData = compH:requireData()
					compAuth = compH:requireAuth()
					local Registry = compH:requireRegistry()
					for _, name in COMP_CMDS do
						if not Registry.commands[name] then
							Registry.commands[name] = {
								name = name,
								aliases = {},
								group = "moderation",
								args = {},
							}
						end
					end
				end

				Harness.seedRoles(compData)
				table.clear(compData.members)
				compData.settings.freeAdmin = {}

				-- Define two dynamic synthetic roles alongside the built-in role catalog
				local function makeDynamicRole(key: string, rank: number)
					local perms: { [string]: boolean } = {}
					for _, p in COMP_PERMS do
						if p ~= "admin" then
							perms[p] = g:bool()
						else
							perms[p] = g:int(1, 6) == 1
						end
					end
					local groups: { string } = {}
					for _, grp in COMP_GROUPS do
						if g:bool() then
							table.insert(groups, grp)
						end
					end
					local cmds: { [string]: boolean } = {}
					for _, c in COMP_CMDS do
						if g:int(1, 4) == 1 then
							cmds[c] = true
						end
					end
					local roleObj = {
						_key = key,
						_rank = rank,
						name = key,
						color = "#fff",
						groups = groups,
						limits = { cooldown = 4, commands = 32, targets = 10 },
						permissions = perms,
						commands = cmds,
					}
					compData.roles[key] = roleObj
					table.insert(compData.rolesList, roleObj)
				end

				local rankA = g:int(1, 8)
				local rankB = g:int(1, 8)
				if rankB == rankA then
					rankB += 1
				end
				makeDynamicRole("customA", rankA)
				makeDynamicRole("customB", rankB)

				local pool = { "everyone", "vip", "mod", "admin", "superadmin", "creator", "customA", "customB" }
				local roleA = g:pick(pool)
				local roleB = g:pick(pool)

				local uA, uB, uAB, uBA = 701, 702, 703, 704
				compAuth.userRoleAdd(uA, roleA)
				compAuth.userRoleAdd(uB, roleB)
				compAuth.userRoleAdd(uAB, roleA)
				compAuth.userRoleAdd(uAB, roleB)
				compAuth.userRoleAdd(uBA, roleB)
				compAuth.userRoleAdd(uBA, roleA)

				local rA = compAuth.getRank(uA)
				local rB = compAuth.getRank(uB)
				local rAB = compAuth.getRank(uAB)
				local rBA = compAuth.getRank(uBA)

				sert.eq(rAB, math.max(rA, rB))
				sert.eq(rBA, rAB)

				for _, p in COMP_PERMS do
					local pA = compAuth.hasPermission(uA, p)
					local pB = compAuth.hasPermission(uB, p)
					local pAB = compAuth.hasPermission(uAB, p)
					local pBA = compAuth.hasPermission(uBA, p)
					sert.eq(pAB, pA or pB)
					sert.eq(pBA, pAB)
				end

				for _, c in COMP_CMDS do
					local cA = compAuth.hasCommand(uA, c) ~= false
					local cB = compAuth.hasCommand(uB, c) ~= false
					local cAB = compAuth.hasCommand(uAB, c) ~= false
					local cBA = compAuth.hasCommand(uBA, c) ~= false
					sert.eq(cAB, cA or cB)
					sert.eq(cBA, cAB)
				end

				for _, r in COMP_ROLES do
					local hA = compAuth.hasRole(uA, r)
					local hB = compAuth.hasRole(uB, r)
					local hAB = compAuth.hasRole(uAB, r)
					local hBA = compAuth.hasRole(uBA, r)
					sert.eq(hAB, hA or hB)
					sert.eq(hBA, hAB)
				end
			end,
			{ runs = if rawget(_G, "__SERT_MUTANT") ~= nil then 10 else 80 }
		)
	end

	test(
		"sert.model verifies getRank, hasPermission, hasCommand, member sorting, and ban lifecycle invariants",
		function()
			local userIds = { 101, 102, 103 }
			local grantableRoles = { "vip", "mod", "admin", "superadmin" }
			local freeAdminRoles = { "vip", "mod" }
			local banDurations = { 0, 60, -1 }

			local h = Harness.newEnv({ isStudio = false })
			local Data = h:requireData()
			local Auth = h:requireAuth()
			Data.SEPARATE_DATASTORE = true
			for _, uid in userIds do
				h.env:addPlayer(uid, `Player{uid}`)
			end
			local sys = { h = h, Data = Data, Auth = Auth }

			local model: any = sert.model
			model("Auth role, freeAdmin, and ban state machine", {
				setup = function()
					table.clear(Data.members)
					table.clear(Data.bans)
					table.clear(h.env.kicks)
					Data.settings.freeAdmin = {}
					return sys
				end,
				init = function()
					return {
						roles = { [101] = {}, [102] = {}, [103] = {} },
						persist = { [101] = {}, [102] = {}, [103] = {} },
						freeAdmin = {},
						bans = {},
					}
				end,
				commands = {
					GrantRole = {
						gen = function(_state, g)
							return {
								userId = g:pick(userIds),
								role = g:pick(grantableRoles),
								persist = g:bool(),
							}
						end,
						pre = function(state, args)
							return args ~= nil and state.roles[args.userId] ~= nil and args.role ~= nil
						end,
						run = function(s, args)
							s.Auth.userRoleAdd(args.userId, args.role, args.persist)
						end,
						next = function(state, args)
							local r = state.roles[args.userId]
							if not table.find(r, args.role) then
								table.insert(r, args.role)
							end
							if args.persist then
								local p = state.persist[args.userId]
								if not table.find(p, args.role) then
									table.insert(p, args.role)
								end
							end
						end,
					},
					RevokeRole = {
						gen = function(_state, g)
							return {
								userId = g:pick(userIds),
								role = g:pick(grantableRoles),
							}
						end,
						pre = function(state, args)
							return args ~= nil and state.roles[args.userId] ~= nil and args.role ~= nil
						end,
						run = function(s, args)
							s.Auth.userRoleRemove(args.userId, args.role)
						end,
						next = function(state, args)
							local r = state.roles[args.userId]
							local idx = table.find(r, args.role)
							if idx then
								table.remove(r, idx)
							end
							local p = state.persist[args.userId]
							local pidx = table.find(p, args.role)
							if pidx then
								table.remove(p, pidx)
							end
						end,
					},
					SetFreeAdmin = {
						gen = function(_state, g)
							return {
								role = if g:bool() then g:pick(freeAdminRoles) else nil,
							}
						end,
						pre = function(_state, args)
							return args ~= nil
						end,
						run = function(s, args)
							s.Data.settings.freeAdmin = if args.role then { args.role } else {}
						end,
						next = function(state, args)
							state.freeAdmin = if args.role then { args.role } else {}
						end,
					},
					BanUser = {
						gen = function(_state, g)
							return {
								userId = g:pick(userIds),
								duration = g:pick(banDurations),
							}
						end,
						pre = function(_state, args)
							return args ~= nil and args.userId ~= nil and args.duration ~= nil
						end,
						run = function(s, args)
							local stamp = nil
							if args.duration and args.duration > 0 then
								stamp = math.floor(s.h.env.workspace:GetServerTimeNow()) + args.duration
							elseif args.duration == -1 then
								stamp = -1
							end
							s.Auth.banUsers({ args.userId }, "rule violation", args.duration, nil, true)
							return stamp
						end,
						next = function(state, args, stamp)
							state.bans[args.userId] = { stamp = stamp }
						end,
					},
					UnbanUser = {
						gen = function(_state, g)
							return {
								userId = g:pick(userIds),
							}
						end,
						pre = function(_state, args)
							return args ~= nil and args.userId ~= nil
						end,
						run = function(s, args)
							s.Auth.unbanUsers({ args.userId }, nil, true)
						end,
						next = function(state, args)
							state.bans[args.userId] = nil
						end,
					},
				},
				invariants = {
					memberRolesSorted = function(_state, s)
						for _, uid in userIds do
							local member = s.Data.members[tostring(uid)]
							if member then
								for i = 2, #member.roles do
									if not s.Auth.roleIdSort(member.roles[i - 1], member.roles[i]) then
										return false
									end
								end
							end
						end
						return true
					end,
					banEntriesConsistent = function(state, s)
						for _, uid in userIds do
							local hasModelBan = state.bans[uid] ~= nil
							local hasSutBan = s.Data.bans[tostring(uid)] ~= nil
							if hasModelBan ~= hasSutBan then
								return false
							end
						end
						return true
					end,
					noUnrestrictedEscalation = function(state, s)
						for _, uid in userIds do
							local expectedRestricted = false
							for _, roleId in state.roles[uid] do
								if roleId ~= "vip" and not table.find(state.freeAdmin, roleId) then
									expectedRestricted = true
								end
							end
							if s.Auth.hasRestrictedRole(uid) ~= expectedRestricted then
								return false
							end
						end
						return true
					end,
					rankAndPermissionsMatchModel = function(state, s)
						for _, uid in userIds do
							local expectedRank = 0
							for _, roleId in state.freeAdmin do
								expectedRank = math.max(expectedRank, s.Data.roles[roleId]._rank)
							end
							for _, roleId in state.roles[uid] do
								expectedRank = math.max(expectedRank, s.Data.roles[roleId]._rank)
							end
							local actualRank, actualRole = s.Auth.getRank(uid)
							sert.eq(actualRank, expectedRank)
							sert.eq(actualRole._rank, expectedRank)
							sert.eq(s.Auth.hasPermission(uid, "banasync"), expectedRank >= 3)
							sert.eq(s.Auth.hasPermission(uid, "saveRoles"), expectedRank >= 4)
						end
					end,
					banTimestampsMatchModel = function(state, s)
						for _, uid in userIds do
							local banEntry = s.Data.bans[tostring(uid)]
							if state.bans[uid] ~= nil then
								sert.eq(banEntry ~= nil, true)
								sert.eq(banEntry[3], state.bans[uid].stamp)
							else
								sert.eq(banEntry, nil)
							end
						end
					end,
				},
			}, { runs = if rawget(_G, "__SERT_MUTANT") ~= nil then 10 else 35, length = 20 })
		end
	)

	test("Auth.userRoleAdd networks member when clearing unrestricted flag on an already-held role", function()
		local h = Harness.newEnv({ isStudio = false })
		local Data = h:requireData()
		local Auth = h:requireAuth()

		Auth.userRoleAdd(808, "mod", false, true)
		local member = Data.members["808"]
		member.name = "ModUser808"
		sert.eq(member.unrestricted and member.unrestricted.mod, true)
		sert.eq(Auth.hasRestrictedRole(808), false)

		local networkedUsers = {}
		local origNetworkMember = Auth.networkMember
		Auth.networkMember = function(uid: number)
			table.insert(networkedUsers, uid)
		end

		-- Upgrading existing session "mod" from unrestricted=true to unrestricted=false returns false (not newly added)
		-- but MUST call Auth.networkMember(808) because member.unrestricted changed!
		local added = Auth.userRoleAdd(808, "mod", false, false)
		sert.eq(added, false)
		sert.eq(member.unrestricted and member.unrestricted.mod, nil)
		sert.eq(Auth.hasRestrictedRole(808), true)
		sert.eq(networkedUsers, { 808 })

		-- Re-calling when already restricted does not re-network unnecessarily
		Auth.userRoleAdd(808, "mod", false, false)
		sert.eq(networkedUsers, { 808 })

		Auth.networkMember = origNetworkMember
	end)

	test("Auth.networkMember and Data SYNC/REMOVE coerce string keys and preserve Studio theme authority", function()
		local world = sert.sim.new({ backing = true })
		local server = world:server()
		local h = Harness.newPeerEnv(server, { isStudio = false })
		local Data = h:requireData()
		local Auth = h:requireAuth()
		local Remote = h:requireRemote()

		local plr = h.env:addPlayer(808, "Member808")
		plr:SetAttribute("_K_READY", true)

		Data.SEPARATE_DATASTORE = false
		Data.settingsModuleData = { prefix = { ";" }, changeThemeAuthority = "Studio", theme = "Default" }
		server:spawn(function()
			Data.initialize("_KDataTestSync")
		end)
		world:run(0.5)
		local defaultSettings: any = Data.defaultSettings
		defaultSettings.changeThemeAuthority = "Studio"
		defaultSettings.theme = "Default"
		Data.savedSettings.useSavedSettings = true
		Data.savedSettings.changeThemeAuthority = "Studio"
		Data.savedSettings.theme = "Default"

		Data.members["808"] = { name = "Member808", roles = { "mod" }, persist = { "mod" } }
		Data.Sync.members["808"] = nil

		local memberFires = {}
		local origFire = Remote.Member.Fire
		Remote.Member.Fire = function(selfRemote: any, targetPlr: any, key: any, data: any)
			table.insert(memberFires, { plr = targetPlr, key = key, data = data })
			return origFire(selfRemote, targetPlr, key, data)
		end

		Auth.networkMember("808" :: any)
		sert.eq(#memberFires, 1)
		sert.eq(memberFires[1].plr, plr)
		sert.eq(memberFires[1].key, "808")

		table.clear(memberFires)
		server:spawn(function()
			h.env.game:GetService("MessagingService"):PublishAsync("_KData", {
				"remote-sync-1",
				1,
				{
					_time = h.env.DateTime.now().UnixTimestampMillis + 100000,
					members = { unset = { "808" } },
					settings = { set = { changeThemeAuthority = "Client", theme = "Cyan" } },
				},
			})
		end)
		world:run(0.2)
		world.backing.messaging.drain()
		world:run(0.5)

		Remote.Member.Fire = origFire
		sert.eq(Data.members["808"], nil)
		sert.eq(#memberFires >= 1, true)
		sert.eq(memberFires[#memberFires].plr, plr)
		sert.eq(memberFires[#memberFires].key, "808")
		sert.eq(Data.savedSettings.changeThemeAuthority, "Studio")
		sert.eq(Data.savedSettings.theme, "Default")

		server:shutdown()
	end)
end)

do
	return {}
end
