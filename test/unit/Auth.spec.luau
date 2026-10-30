local Harness = require("./Harness")
local sert = require("../sert")

local describe, test, expect = sert.describe, sert.test, sert.expect

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
	end)
end)

describe("Auth · Stateful RBAC & Ban Model", function()
	test(
		"sert.model verifies getRank, hasPermission, hasCommand, member sorting, and ban lifecycle invariants",
		function()
			local userIds = { 101, 102, 103 }
			local grantableRoles = { "vip", "mod", "admin", "superadmin" }
			local freeAdminRoles = { "vip", "mod" }
			local banDurations = { 0, 60, -1 }

			local modelSys: any = nil
			-- typed as any: the old solver rejects sert.model's map-form `commands` (Spec)
			local model: any = sert.model
			model({
				init = function()
					local h = Harness.newEnv({ isStudio = false })
					local Data = h:requireData()
					local Auth = h:requireAuth()
					Data.SEPARATE_DATASTORE = true
					for _, uid in userIds do
						h.env:addPlayer(uid, `Player{uid}`)
					end
					modelSys = { h = h, Data = Data, Auth = Auth }
					return {
						roles = { [101] = {}, [102] = {}, [103] = {} },
						persist = { [101] = {}, [102] = {}, [103] = {} },
						freeAdmin = {},
						bans = {},
					}
				end,
				setup = function()
					return modelSys
				end,
				commands = {
					GrantRole = {
						gen = function(g)
							return {
								userId = g:pick(userIds),
								role = g:pick(grantableRoles),
								persist = g:bool(),
							}
						end,
						run = function(sys, args)
							sys.Auth.userRoleAdd(args.userId, args.role, args.persist)
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
						gen = function(g)
							return {
								userId = g:pick(userIds),
								role = g:pick(grantableRoles),
							}
						end,
						run = function(sys, args)
							sys.Auth.userRoleRemove(args.userId, args.role)
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
						gen = function(g)
							return {
								role = if g:bool() then g:pick(freeAdminRoles) else nil,
							}
						end,
						run = function(sys, args)
							sys.Data.settings.freeAdmin = if args.role then { args.role } else {}
						end,
						next = function(state, args)
							state.freeAdmin = if args.role then { args.role } else {}
						end,
					},
					BanUser = {
						gen = function(g)
							return {
								userId = g:pick(userIds),
								duration = g:pick(banDurations),
							}
						end,
						run = function(sys, args)
							sys.Auth.banUsers({ args.userId }, "rule violation", args.duration, nil, true)
						end,
						next = function(state, args)
							local stamp = nil
							if args.duration and args.duration > 0 then
								stamp = math.floor(modelSys.h.env.workspace:GetServerTimeNow()) + args.duration
							elseif args.duration == -1 then
								stamp = -1
							end
							state.bans[args.userId] = { stamp = stamp }
						end,
					},
					UnbanUser = {
						gen = function(g)
							return {
								userId = g:pick(userIds),
							}
						end,
						run = function(sys, args)
							sys.Auth.unbanUsers({ args.userId }, nil, true)
						end,
						next = function(state, args)
							state.bans[args.userId] = nil
						end,
					},
				},
				invariant = function(state, sys)
					local Data = sys.Data
					local Auth = sys.Auth
					for _, uid in userIds do
						local expectedRank = 0
						for _, roleId in state.freeAdmin do
							expectedRank = math.max(expectedRank, Data.roles[roleId]._rank)
						end
						local expectedRestricted = false
						for _, roleId in state.roles[uid] do
							expectedRank = math.max(expectedRank, Data.roles[roleId]._rank)
							if roleId ~= "vip" and not table.find(state.freeAdmin, roleId) then
								expectedRestricted = true
							end
						end
						local actualRank, actualRole = Auth.getRank(uid)
						expect(actualRank).toBe(expectedRank)
						expect(actualRole._rank).toBe(expectedRank)
						expect(Auth.hasRestrictedRole(uid)).toBe(expectedRestricted)
						expect(Auth.hasPermission(uid, "banasync")).toBe(expectedRank >= 3)
						expect(Auth.hasPermission(uid, "saveRoles")).toBe(expectedRank >= 4)

						local member = Data.members[tostring(uid)]
						if member then
							for i = 2, #member.roles do
								expect(Auth.roleIdSort(member.roles[i - 1], member.roles[i])).toBe(true)
							end
						end

						local banEntry = Data.bans[tostring(uid)]
						if state.bans[uid] ~= nil then
							expect(banEntry ~= nil).toBe(true)
							expect(banEntry[3]).toBe(state.bans[uid].stamp)
						else
							expect(banEntry).toBeNil()
						end
					end
				end,
			}, { runs = 35, length = 20 })
		end
	)

	test("banHandler kicks active bans and auto-unbans expired temporary bans", function()
		local h = Harness.newEnv({ isStudio = false })
		local Data = h:requireData()
		local Auth = h:requireAuth()
		Data.SEPARATE_DATASTORE = true

		local plr = h.env:addPlayer(501, "TimedBanUser")
		Auth.banUsers({ 501 }, "Temp ban reason", 30, nil, true)
		expect(Data.bans["501"] ~= nil).toBe(true)

		-- While ban is active, banHandler kicks the player and returns true
		expect(Auth.banHandler(plr)).toBe(true)
		expect(type(kickOf(h, plr))).toBe("string")

		-- Advance clock past the 30-second expiration
		h.env:removePlayer(501)
		local plrRejoined = h.env:addPlayer(501, "TimedBanUser")
		h.env:step(45)
		expect(Auth.banHandler(plrRejoined)).toBeNil()
		expect(kickOf(h, plrRejoined)).toBeNil()
		expect(Data.bans["501"]).toBeNil()
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
		expect(Auth.targetUserArgument(vipArg, 10, 10)).toBe(10)
		Data.targetLimits[10] = 0
		local targetOtherVal, targetOtherErr = Auth.targetUserArgument(vipArg, 20, 20)
		expect(targetOtherVal).toBeNil()
		expect(string.find(tostring(targetOtherErr), "yourself", 1, true) ~= nil).toBe(true)

		-- Mod can target others, but with lowerRank = true cannot target Admin (30)
		Data.targetLimits[20] = 0
		local modArg = {
			_K = _K,
			definition = { lowerRank = true },
			command = { from = 20, fromRank = modRank, fromRole = modRole, rank = 2 },
		}
		expect(Auth.targetUserArgument(modArg, 10, 10)).toBe(10)
		local highVal, highErr = Auth.targetUserArgument(modArg, 30, 30)
		expect(highVal).toBeNil()
		expect(string.find(tostring(highErr), "lower", 1, true) ~= nil).toBe(true)
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
		expect(Auth.hasRole(10, "mod")).toBe(true)
		expect(Auth.hasRole(10, "vip")).toBe(true)
		expect(Auth.hasRole(10, "admin")).toBe(false)
		expect(Auth.hasRole(20, "admin")).toBe(true)
		expect(Auth.hasRole(20, "mod")).toBe(true)
		expect(Auth.hasRole(20, "superadmin")).toBe(false)
		expect(Auth.hasRole(999, "superadmin")).toBe(true)
		expect(Auth.hasRole(10, "nonexistent_role")).toBe(false)

		-- getRoleFromRank finds exact match or closest role >= rank
		expect((Auth.getRoleFromRank(0) :: any)._key).toBe("everyone")
		expect((Auth.getRoleFromRank(2) :: any)._key).toBe("mod")
		expect((Auth.getRoleFromRank(2.5) :: any)._key).toBe("admin")
		expect((Auth.getRoleFromRank(100) :: any)._key).toBe("creator")

		-- roleCanUseArgument and hasArgument
		local unrestrictedArg = { name = "msg" }
		local banAsyncArg = { name = "duration", permissions = { banasync = true } }
		local saveRolesArg = { name = "persist", permissions = { saveRoles = true } }

		expect(Auth.roleCanUseArgument("nonexistent", unrestrictedArg)).toBe(false)
		expect(Auth.roleCanUseArgument("everyone", unrestrictedArg)).toBe(true)
		expect(Auth.roleCanUseArgument("mod", banAsyncArg)).toBe(false)
		expect(Auth.roleCanUseArgument("admin", banAsyncArg)).toBe(true)
		expect(Auth.roleCanUseArgument("creator", saveRolesArg)).toBe(true)

		expect(Auth.hasArgument(10, unrestrictedArg)).toBe(true)
		expect(Auth.hasArgument(10, banAsyncArg)).toBe(false)
		expect(Auth.hasArgument(20, banAsyncArg)).toBe(true)
		expect(Auth.hasArgument(20, saveRolesArg)).toBe(false)
		expect(Auth.hasArgument(999, saveRolesArg)).toBe(true)

		Data.settings.freeAdmin = { "superadmin" }
		expect(Auth.hasArgument(10, saveRolesArg)).toBe(true)
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
		expect(Data.members["40"] ~= nil).toBe(true)
		expect(Auth.userRoleRemove(40, "mod")).toBe(true)
		expect(Data.members["40"]).toBeNil()
		expect(Data.Sync.members["40"]).toBeNil()
		expect(Auth.userRoleRemove(40, "mod")).toBe(false)

		-- Persistent role removal with multiple persistent roles updates Sync.members, then sets REMOVE when empty
		Auth.userRoleAdd(50, "mod", true)
		Auth.userRoleAdd(50, "admin", true)
		h.env:step(0.05)
		expect(Auth.userRoleRemove(50, "admin")).toBe(true)
		h.env:step(0.05)
		expect(Data.members["50"] ~= nil).toBe(true)
		expect(Data.Sync.members["50"][2]).toEqual({ "mod" })

		expect(Auth.userRoleRemove(50, "mod")).toBe(true)
		expect(Data.members["50"]).toBeNil()
		expect(Data.Sync.members["50"]).toBe(Data.REMOVE)
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
		h.env.groups[1000] = {
			ranks = { [101] = 50, [102] = 220 },
			Roles = {
				{ Name = "Guest", Rank = 0 },
				{ Name = "Member", Rank = 1 },
				{ Name = "Mod", Rank = 50 },
				{ Name = "Admin", Rank = 200 },
			},
		}
		h.env.marketplace.gamePasses[101] = { [555] = true }
		h.env.marketplace.subscriptions[101] = { sub_super = true }

		-- p2 has group rank 220 (does NOT match exactRank=50, matches >=200 -> admin) and asset 777 (-> mod)
		h.env.marketplace.assets[102] = { [777] = true }

		Auth.userAsyncRoles(p1.UserId)
		expect(table.find(Data.members["101"].roles, "vip") ~= nil).toBe(true)
		expect(Auth.hasRole(p1.UserId, "mod")).toBe(true)
		expect(Auth.hasRole(p1.UserId, "superadmin")).toBe(true)

		-- Second call without bustCache is a no-op
		Auth.userAsyncRoles(p1.UserId, false)

		-- With bustCache = true, re-evaluates group roles and removes stale exactRank group role
		h.env.groups[1000].ranks[101] = 250
		Auth.userAsyncRoles(p1.UserId, true)
		expect(table.find(Data.members["101"].roles, "admin") ~= nil).toBe(true)
		expect(table.find(Data.members["101"].roles, "mod")).toBeNil()
		expect(Auth.hasAsyncRole(p1.UserId, "mod")).toBe(false)

		Auth.userAsyncRoles(p2.UserId)
		expect(table.find(Data.members["102"].roles, "admin") ~= nil).toBe(true)
		expect(table.find(Data.members["102"].roles, "mod") ~= nil).toBe(true)
		expect(table.find(Data.members["102"].roles, "vip")).toBeNil()
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
		expect(Auth.isPublicRole("vip")).toBe(true)
		expect(Auth.isPublicRole("admin")).toBe(false)

		-- Group whose GetGroupInfoAsync fails stays fail-closed (isPublicRole = true) and schedules retry
		local GroupService = h.env.game:GetService("GroupService")
		local groupMethods = rawget(GroupService, "_methods")
		local origGetInfo = groupMethods.GetGroupInfoAsync
		groupMethods.GetGroupInfoAsync = function(_self, gid)
			if gid == 3000 then
				error("GroupService error")
			end
			return origGetInfo(_self, gid)
		end
		Data.async.group[3000] = {
			{ rank = 200, roles = { "mod" } },
		}
		expect(Auth.isPublicRole("mod")).toBe(true)
		groupMethods.GetGroupInfoAsync = origGetInfo
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
		expect(Auth.banHandler(pSite)).toBeNil()
		expect(kickOf(h, pSite)).toBeNil()
		expect(Data.bans["601"]).toBeNil()

		-- 2. Timed ban kick message (> 0)
		local pTimed = h.env:addPlayer(602, "TimedUser")
		local now = h.env.globals.os.time()
		Data.bans["602"] = { "TimedUser", "Spamming chat", now + 120, 1 }
		expect(Auth.banHandler(pTimed)).toBe(true)
		expect(string.find(tostring(kickOf(h, pTimed)), "2 minutes", 1, true) ~= nil).toBe(true)
		expect(string.find(tostring(kickOf(h, pTimed)), "Reason: Spamming chat", 1, true) ~= nil).toBe(true)

		-- 3. Permanent ban kick message (-1)
		local pPerm = h.env:addPlayer(603, "PermUser")
		Data.bans["603"] = { "PermUser", "Exploiting", -1, 1 }
		expect(Auth.banHandler(pPerm)).toBe(true)
		expect(string.find(tostring(kickOf(h, pPerm)), "permanently banned", 1, true) ~= nil).toBe(true)
		expect(string.find(tostring(kickOf(h, pPerm)), "Reason: Exploiting", 1, true) ~= nil).toBe(true)

		-- 4. Server ban kick message (nil timestamp, no reason)
		local pSrv = h.env:addPlayer(604, "ServerBanUser")
		Data.bans["604"] = { "ServerBanUser", nil, nil, 1 }
		expect(Auth.banHandler(pSrv)).toBe(true)
		expect(kickOf(h, pSrv)).toBe("You are banned from this server!")

		-- 5. Creator or userId < 1 or unbanned player is never kicked
		Data.creatorId = 777
		local pCreator = h.env:addPlayer(777, "CreatorUser")
		Data.bans["777"] = { "CreatorUser", "should not kick", -1, 1 }
		expect(Auth.banHandler(pCreator)).toBeNil()
		expect(kickOf(h, pCreator)).toBeNil()
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

			local playersMethods = rawget(h.env.Players, "_methods")
			local origBanAsync = playersMethods.BanAsync
			local origUnbanAsync = playersMethods.UnbanAsync

			local banAttempts = 0
			playersMethods.BanAsync = function(_self, config)
				banAttempts += 1
				if banAttempts == 1 then
					error('{"code": "RateLimit"}')
				end
				return config
			end

			local unbanAttempts = 0
			playersMethods.UnbanAsync = function(_self, config)
				unbanAttempts += 1
				if unbanAttempts == 1 then
					error('{"code": "ServiceUnavailable"}')
				end
				return config
			end

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
			expect(banned).toEqual({ 801 })
			expect(hookBans).toEqual({ { 801 } })
			expect(banAttempts).toBe(2)
			expect(Data.bans["801"] ~= nil).toBe(true)
			expect(Data.bans["801"][2]).toBe("Exploit")
			expect(Data.bans["801"][3]).toBe(-1)
			expect(Data.Sync.bans["801"] ~= nil).toBe(true)

			-- 2. Non-banasync caller (modPlr, rank 2, lacks banasync) can't change the persistent ban (801): demoting it to
			-- a server ban would lift the universe ban, which only banasync may do (as in unbanUsers)
			h.env.task.spawn(function()
				banned = Auth.banUsers({ 801, 803 }, "Demoted to server ban", 600, modPlr.UserId, false)
			end)
			h.env:step(5)
			-- only the user without a saved ban is banned (for the server) and reported
			expect(banned).toEqual({ 803 })
			expect(hookBans[2]).toEqual({ 803 })
			expect(Data.bans["803"][3]).toBeNil()
			-- a call that only meets saved bans bans no one and fires no hook
			h.env.task.spawn(function()
				banned = Auth.banUsers({ 801 }, "Demoted to server ban", 600, modPlr.UserId, false)
			end)
			h.env:step(5)
			expect(banned).toEqual({})
			expect(#hookBans).toBe(2)
			expect(unbanAttempts).toBe(0)
			expect(Data.bans["801"][2]).toBe("Exploit")
			expect(Data.bans["801"][3]).toBe(-1)
			expect(Data.Sync.bans["801"] ~= Data.REMOVE).toBe(true)

			-- A banasync caller with a restricted role demotes it to a server ban (duration = 0), which sets
			-- Data.Sync.bans["801"] = Data.REMOVE and calls Players:UnbanAsync with retry
			local adminPlr = h.env:addPlayer(11, "AdminBanAsync")
			Auth.userRoleAdd(adminPlr.UserId, "admin")
			h.env.task.spawn(function()
				Auth.banUsers({ 801 }, "Demoted to server ban", 0, adminPlr.UserId, false)
			end)
			h.env:step(5)
			expect(unbanAttempts).toBe(2)
			expect(Data.bans["801"] ~= nil).toBe(true)
			expect(Data.bans["801"][2]).toBe("Demoted to server ban")
			expect(Data.bans["801"][3]).toBeNil()
			expect(Data.Sync.bans["801"]).toBe(Data.REMOVE)

			-- Hook.unban fires only with the users actually unbanned: a non-banasync caller keeps saved bans
			local hookUnbans = {}
			h:requireShared("Hook").unban:Connect(function(userIds)
				table.insert(hookUnbans, userIds)
			end)
			Data.bans["804"] = { "Perm804", "reason", -1, 1 }
			expect(Auth.unbanUsers({ 804, 801 }, modPlr.UserId)).toEqual({ 801 })
			expect(hookUnbans).toEqual({ { 801 } })
			expect(Data.bans["801"]).toBeNil()
			expect(Data.bans["804"] ~= nil).toBe(true)
			expect(Auth.unbanUsers({ 804 }, modPlr.UserId)).toEqual({})
			expect(#hookUnbans).toBe(1)

			-- 3. unbanUsers with BanAsync retry when unbanning a persistent ban
			Data.bans["802"] = { "Perm802", "reason", -1, 1 }
			unbanAttempts = 0
			h.env.task.spawn(function()
				Auth.unbanUsers({ 802 }, nil, true)
			end)
			h.env:step(5)
			expect(unbanAttempts).toBe(2)
			expect(Data.bans["802"]).toBeNil()
			expect(Data.Sync.bans["802"]).toBe(Data.REMOVE)

			playersMethods.BanAsync = origBanAsync
			playersMethods.UnbanAsync = origUnbanAsync
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
			expect(Auth.userRoleAdd(901, "everyone")).toBe(false)
			expect(Data.members["901"]).toBeNil()

			-- 2. unrestricted flag lifecycle on new and existing members
			expect(Auth.userRoleAdd(901, "vip", false, false)).toBe(true)
			expect(Data.members["901"].unrestricted).toBeNil()

			-- Adding a second role with unrestricted = true initializes member.unrestricted
			expect(Auth.userRoleAdd(901, "mod", false, true)).toBe(true)
			expect(Data.members["901"].unrestricted.mod).toBe(true)
			-- Because "mod" is marked unrestricted in member.unrestricted, hasRestrictedRole is false!
			expect(Auth.hasRestrictedRole(901)).toBe(false)

			-- Re-adding "mod" with unrestricted = false clears member.unrestricted.mod
			expect(Auth.userRoleAdd(901, "mod", false, false)).toBe(false)
			expect(Data.members["901"].unrestricted.mod).toBeNil()
			expect(Auth.hasRestrictedRole(901)).toBe(true)

			-- Removing a role also clears its unrestricted entry
			expect(Auth.userRoleAdd(901, "admin", false, true)).toBe(true)
			expect(Data.members["901"].unrestricted.admin).toBe(true)
			expect(Auth.userRoleRemove(901, "admin")).toBe(true)
			expect(Data.members["901"].unrestricted.admin).toBeNil()

			-- 3. roleCanUseCommand: invalid role, invalid command, alias override, and command.permissions check
			expect(Auth.roleCanUseCommand("undefined_role_xyz", "ban")).toBe(false)
			expect(Auth.roleCanUseCommand("mod", "nonexistent_command_xyz")).toBe(false)
			expect(Auth.roleCanUseCommand("mod", 12345 :: any)).toBe(false)

			Data.roles.mod.commands = { flight_alias = true, blocked_cmd = false }
			local cmdWithAlias = {
				name = "fly_custom",
				aliases = { "flight_alias" },
				group = "Administration",
			}
			expect(Auth.roleCanUseCommand("mod", cmdWithAlias)).toBe(true)
			expect(Auth.roleCanUseCommand("mod", { name = "blocked_cmd", group = "Moderation" })).toBe(false)

			local permCmd = {
				name = "perm_gated",
				group = "Moderation",
				permissions = { banasync = true },
			}
			expect(Auth.roleCanUseCommand("mod", permCmd)).toBe(false)
			expect(Auth.roleCanUseCommand("admin", permCmd)).toBe(true)

			-- 4. hasPermission via freeAdmin and friendRoles in isPublicRole
			Data.settings.freeAdmin = { "mod" }
			expect(Auth.hasPermission(99999, "serverlogs")).toBe(true)
			Data.settings.freeAdmin = {}

			Data.friendRoles = { "vip" }
			expect(Auth.isPublicRole("vip")).toBe(true)
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
			expect(badVal).toBeNil()
			expect(badErr).toBe("Invalid user")

			local infVal, infErr = Auth.targetUserArgument(arg, math.huge, math.huge)
			expect(infVal).toBeNil()
			expect(infErr).toBe("Invalid user")

			-- ignoreSelf blocks self-targeting
			Data.targetLimits[910] = 0
			local selfVal, selfErr = Auth.targetUserArgument(arg, 910, 910)
			expect(selfVal).toBeNil()
			expect(selfErr).toBe("Can't target yourself")

			-- Loading user (missing _KRolesLoaded) is rejected when lowerRank is true
			Data.targetLimits[910] = 0
			local loadVal, loadErr = Auth.targetUserArgument(arg, 911, 911)
			expect(loadVal).toBeNil()
			expect(loadErr).toBe("Can't target loading user")

			-- Exceeding limits.targets (1) rejects subsequent targets
			Data.targetLimits[910] = 2
			local limVal, limErr = Auth.targetUserArgument(arg, 911, 911)
			expect(limVal).toBeNil()
			expect(limErr).toBe("Can only target 1 user")
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
		expect(Data.members["999999"]).toBeNil()

		-- 2. Service errors across GroupService and MarketplaceService are caught and warned without throwing
		local GroupService = h.env.game:GetService("GroupService")
		local MarketplaceService = h.env.game:GetService("MarketplaceService")
		local gMethods = rawget(GroupService, "_methods")
		local mMethods = rawget(MarketplaceService, "_methods")

		local origGetGroups = gMethods.GetGroupsAsync
		local origGetGroupInfo = gMethods.GetGroupInfoAsync
		local origOwnsPass = mMethods.UserOwnsGamePassAsync
		local origOwnsAsset = mMethods.PlayerOwnsAssetAsync
		local origSubStatus = mMethods.GetUserSubscriptionStatusAsync

		gMethods.GetGroupsAsync = function()
			error("GetGroupsAsync failed")
		end
		gMethods.GetGroupInfoAsync = function()
			return { Roles = {} } -- no positive rank -> entry = nil -> schedules 60s reset
		end
		mMethods.UserOwnsGamePassAsync = function()
			error("UserOwnsGamePassAsync failed")
		end
		mMethods.PlayerOwnsAssetAsync = function()
			error("PlayerOwnsAssetAsync failed")
		end
		mMethods.GetUserSubscriptionStatusAsync = function()
			error("GetUserSubscriptionStatusAsync failed")
		end

		h.env.task.spawn(function()
			Auth.prefetchGroupEntryRanks()
			Auth.userAsyncRoles(pOnline.UserId, true)
		end)
		-- Advance in increments so all sequential Util.Retry exponential backoffs and the 60s groupEntryRanks reset delay fire
		for _ = 1, 30 do
			h.env:step(10)
		end
		expect(Data.members[tostring(pOnline.UserId)]).toBeNil()

		gMethods.GetGroupsAsync = origGetGroups
		gMethods.GetGroupInfoAsync = origGetGroupInfo
		mMethods.UserOwnsGamePassAsync = origOwnsPass
		mMethods.PlayerOwnsAssetAsync = origOwnsAsset
		mMethods.GetUserSubscriptionStatusAsync = origSubStatus
	end)

	test("userAsyncRoles keeps a player loading while their groups are retried for about a minute", function()
		local h = Harness.newEnv({ isStudio = false })
		local Data = h:requireData()
		local Auth = h:requireAuth()
		local _K = h:requireK()

		local gMethods = rawget(h.env.game:GetService("GroupService"), "_methods")
		local origGetGroups = gMethods.GetGroupsAsync
		local groupCalls, failCalls = 0, 0
		gMethods.GetGroupsAsync = function(self, userId)
			groupCalls += 1
			if groupCalls <= failCalls then
				error("GetGroupsAsync failed", 0)
			end
			return origGetGroups(self, userId)
		end
		local warnings = {}
		h.env.game:GetService("LogService").MessageOut:Connect(function(message, messageType)
			if messageType.Name == "MessageWarning" then
				table.insert(warnings, message)
			end
		end)

		Data.async.group[4100] = { { rank = 200, roles = { "superadmin" } } }
		h.env.groups[4100] = { ranks = { [961] = 250, [962] = 250, [963] = 250 }, Roles = {} }
		Data.async.gamepass[667] = { "vip" }
		h.env.marketplace.gamePasses[961] = { [667] = true }
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
					expect(Auth.hasRole(player.UserId, "vip")).toBe(player.UserId == 961)
					if failCalls > 5 then
						expect(done).toBe(false)
						Data.targetLimits[60] = 0
						expect(select(2, Auth.targetUserArgument(arg, player.UserId, player))).toBe(
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
		expect(elapsed >= 45 and elapsed <= 46).toBe(true)
		expect(groupCalls).toBe(7)
		expect(Auth.hasRole(961, "superadmin")).toBe(true)
		expect(#warnings).toBe(0)
		Data.targetLimits[60] = 0
		expect(select(2, Auth.targetUserArgument(arg, 961, recovered))).toBe("Can only target lower ranks")
		-- later calls without bustCache are cached
		Auth.userAsyncRoles(961)
		expect(groupCalls).toBe(7)

		-- groups that never load give up after about a minute and warn once
		groupCalls, failCalls = 0, math.huge
		local unlucky = h.env:addPlayer(962, "UnluckyStaff")
		elapsed = join(unlucky)
		expect(elapsed >= 60 and elapsed <= 61).toBe(true)
		expect(groupCalls).toBe(8)
		expect(Auth.hasRole(962, "superadmin")).toBe(false)
		expect(warnings).toEqual({ "GetGroupsAsync failed" })

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
		expect(stopped).toBe(true)
		expect(groupCalls).toBe(5)
		leave(31)
		expect(stopped).toBe(false)
		for _ = 1, 5 do
			h.env:step(1)
		end
		expect(stopped).toBe(true)
		expect(groupCalls).toBe(5)

		-- users out of this server aren't retried
		groupCalls, stopped = 0, false
		h.env.task.spawn(function()
			Auth.userAsyncRoles(964, true)
			stopped = true
		end)
		for _ = 1, 31 do
			h.env:step(1)
		end
		expect(stopped).toBe(true)
		expect(groupCalls).toBe(5)

		gMethods.GetGroupsAsync = origGetGroups
	end)

	test("targetUserArgument checks the group and gamepass ranks of users out of this server", function()
		local h = Harness.newEnv({ isStudio = false })
		local Data = h:requireData()
		local Auth = h:requireAuth()
		local _K = h:requireK()

		local GroupService = h.env.game:GetService("GroupService")
		local gMethods = rawget(GroupService, "_methods")
		local origGetGroups = gMethods.GetGroupsAsync
		local groupCalls, failGroups = 0, false
		gMethods.GetGroupsAsync = function(self, userId)
			groupCalls += 1
			if failGroups then
				error("GetGroupsAsync failed")
			end
			return origGetGroups(self, userId)
		end

		-- group 5000 rank 200+ gets SuperAdmin; gamepass 556 gets Administrator
		Data.async.group[5000] = { { rank = 200, roles = { "superadmin" } } }
		h.env.groups[5000] = {
			ranks = { [70001] = 250, [70003] = 10 },
			Roles = { { Name = "Member", Rank = 10 }, { Name = "Staff", Rank = 200 } },
		}
		Data.async.gamepass[556] = { "admin" }
		h.env.marketplace.gamePasses[70002] = { [556] = true }

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
		expect(select(2, target(70001))).toBe("Can only target lower ranks")
		expect(select(2, target(70002))).toBe("Can only target lower ranks")
		-- an ordinary offline user can
		expect(target(70003)).toBe(70003)
		expect(groupCalls).toBe(3)

		-- resolved ranks are cached for 60 seconds
		expect(select(2, target(70001))).toBe("Can only target lower ranks")
		expect(groupCalls).toBe(3)
		h.env:step(61)
		expect(select(2, target(70001))).toBe("Can only target lower ranks")
		expect(groupCalls).toBe(4)

		-- web call failures fail closed
		failGroups = true
		local failVal, failErr = target(70004)
		expect(failVal).toBeNil()
		expect(failErr).toBe("Can't verify the rank of an offline user")

		-- a caller gets one offline lookup at a time, so it can't flood web calls
		local first
		h.env.task.spawn(function()
			Data.targetLimits[60] = 0
			first = table.pack(Auth.targetUserArgument(arg, 70008, 70008))
		end)
		local callsBefore = groupCalls
		expect(select(2, target(70009))).toBe("Can't verify the rank of an offline user")
		expect(groupCalls).toBe(callsBefore)
		for _ = 1, 31 do
			if first then
				break
			end
			h.env:step(1)
		end
		expect(first[2]).toBe("Can't verify the rank of an offline user")
		failGroups = false
		expect(target(70009)).toBe(70009)
		local mMethods = rawget(h.env.game:GetService("MarketplaceService"), "_methods")
		local origOwnsPass = mMethods.UserOwnsGamePassAsync
		mMethods.UserOwnsGamePassAsync = function()
			error("UserOwnsGamePassAsync failed")
		end
		expect(select(2, target(70005))).toBe("Can't verify the rank of an offline user")
		mMethods.UserOwnsGamePassAsync = origOwnsPass

		-- asset and subscription roles need the Player: fail closed only when they reach the command rank
		Data.async.asset[778] = { "vip" }
		Data.async.subscription.sub_low = { "mod" }
		expect(target(70003)).toBe(70003)
		Data.async.asset[778] = { "admin" }
		expect(select(2, target(70003))).toBe("Can't verify the rank of an offline user")
		Data.async.asset[778] = nil
		Data.async.subscription.sub_high = { "superadmin" }
		expect(select(2, target(70003))).toBe("Can't verify the rank of an offline user")
		Data.async.subscription.sub_high = nil

		-- loaded players in this server keep today's check, without web calls
		local present = h.env:addPlayer(70006, "Present")
		present:SetAttribute("_KRolesLoaded", true)
		h.env.groups[5000].ranks[70006] = 250
		groupCalls = 0
		expect(target(70006)).toBe(70006)
		Auth.userRoleAdd(70006, "superadmin")
		expect(select(2, target(70006))).toBe("Can only target lower ranks")
		expect(groupCalls).toBe(0)

		-- callers with the admin permission return early
		Data.roles.admin.permissions.admin = true
		expect(target(70007)).toBe(70007)
		Data.roles.admin.permissions.admin = nil
		expect(groupCalls).toBe(0)

		gMethods.GetGroupsAsync = origGetGroups
	end)

	test("targetUserArgument skips offline rank lookups for skipOfflineRank arguments", function()
		local h = Harness.newEnv({ isStudio = false })
		local Data = h:requireData()
		local Auth = h:requireAuth()
		local _K = h:requireK()

		local gMethods = rawget(h.env.game:GetService("GroupService"), "_methods")
		local mMethods = rawget(h.env.game:GetService("MarketplaceService"), "_methods")
		local origGetGroups, origOwnsPass = gMethods.GetGroupsAsync, mMethods.UserOwnsGamePassAsync
		local webCalls = 0
		gMethods.GetGroupsAsync = function(...)
			webCalls += 1
			return origGetGroups(...)
		end
		mMethods.UserOwnsGamePassAsync = function(...)
			webCalls += 1
			return origOwnsPass(...)
		end
		Data.async.group[5000] = { { rank = 200, roles = { "superadmin" } } }
		h.env.groups[5000] = { ranks = { [70001] = 250 }, Roles = {} }
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
		expect(target(unban, 70001, "70001")).toBe("70001")
		expect(webCalls).toBe(0)
		expect(select(2, target({ lowerRank = true }, 70001, "70001"))).toBe("Can only target lower ranks")
		expect(webCalls > 0).toBe(true)

		-- roles known in this server and loading players are still checked
		webCalls = 0
		Auth.userRoleAdd(70002, "superadmin")
		expect(select(2, target(unban, 70002, "70002"))).toBe("Can only target lower ranks")
		local loading = h.env:addPlayer(70003, "Loading")
		expect(select(2, target(unban, 70003, loading))).toBe("Can't target loading user")
		expect(webCalls).toBe(0)

		gMethods.GetGroupsAsync, mMethods.UserOwnsGamePassAsync = origGetGroups, origOwnsPass
	end)

	test("targetUserArgument on the client never checks web ranks", function()
		local h = Harness.newEnv({ isStudio = false, isClient = true })
		h:mockClientRemotes()
		local Data = h:requireData()
		local Auth = h:requireAuth()

		local gMethods = rawget(h.env.game:GetService("GroupService"), "_methods")
		local origGetGroups = gMethods.GetGroupsAsync
		local groupCalls = 0
		gMethods.GetGroupsAsync = function(self, userId)
			groupCalls += 1
			return origGetGroups(self, userId)
		end
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
		expect(Auth.targetUserArgument(arg, 70001, 70001)).toBe(70001)
		expect(groupCalls).toBe(0)
		gMethods.GetGroupsAsync = origGetGroups
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
			expect(unbanned).toEqual({ 801 })
			expect(Data.bans["801"]).toBeNil()
			expect(Data.bans["802"] ~= nil).toBe(true)

			-- Re-seed expired timed ban on 801; moderator without banasync can replace it with a session ban
			Data.bans["801"] = { "ExpiredUser", "old timed ban", now - 10, 1 }
			local banned = Auth.banUsers({ 801, 802 }, "new session ban", 0, 21)
			expect(banned).toEqual({ 801 })
		end
	)
end)

return {}
