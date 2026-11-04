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

		expect(Auth.roleIdSort("mod", "unknown_role")).toBe(true)
		expect(Auth.roleIdSort("unknown_role", "mod")).toBe(false)
		expect(Auth.roleIdSortAscending("unknown_role", "mod")).toBe(true)
		expect(Auth.roleIdSortAscending("mod", "unknown_role")).toBe(false)
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

			-- typed as any: the old solver rejects sert.model's map-form `actions` (Spec)
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
					local state = {
						roles = { [101] = {}, [102] = {}, [103] = {} },
						persist = { [101] = {}, [102] = {}, [103] = {} },
						freeAdmin = {},
						bans = {},
					}
					return state, { h = h, Data = Data, Auth = Auth }
				end,
				actions = {
					GrantRole = {
						gen = function(g)
							return {
								userId = g:pick(userIds),
								role = g:pick(grantableRoles),
								persist = g:bool(),
							}
						end,
						guard = function(state, args)
							return args ~= nil and state.roles[args.userId] ~= nil and args.role ~= nil
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
						guard = function(state, args)
							return args ~= nil and state.roles[args.userId] ~= nil and args.role ~= nil
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
						guard = function(_state, args)
							return args ~= nil
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
						guard = function(_state, args)
							return args ~= nil and args.userId ~= nil and args.duration ~= nil
						end,
						run = function(sys, args)
							local stamp = nil
							if args.duration and args.duration > 0 then
								stamp = math.floor(sys.h.env.workspace:GetServerTimeNow()) + args.duration
							elseif args.duration == -1 then
								stamp = -1
							end
							sys.Auth.banUsers({ args.userId }, "rule violation", args.duration, nil, true)
							return stamp
						end,
						next = function(state, args, stamp)
							state.bans[args.userId] = { stamp = stamp }
						end,
					},
					UnbanUser = {
						gen = function(g)
							return {
								userId = g:pick(userIds),
							}
						end,
						guard = function(_state, args)
							return args ~= nil and args.userId ~= nil
						end,
						run = function(sys, args)
							sys.Auth.unbanUsers({ args.userId }, nil, true)
						end,
						next = function(state, args)
							state.bans[args.userId] = nil
						end,
					},
				},
				never = {
					unsortedMemberRoles = function(_state, sys)
						for _, uid in userIds do
							local member = sys.Data.members[tostring(uid)]
							if member then
								for i = 2, #member.roles do
									if not sys.Auth.roleIdSort(member.roles[i - 1], member.roles[i]) then
										return true
									end
								end
							end
						end
						return false
					end,
					bannedWithoutEntry = function(state, sys)
						for _, uid in userIds do
							local hasModelBan = state.bans[uid] ~= nil
							local hasSutBan = sys.Data.bans[tostring(uid)] ~= nil
							if hasModelBan ~= hasSutBan then
								return true
							end
						end
						return false
					end,
					unrestrictedEscalation = function(state, sys)
						for _, uid in userIds do
							local expectedRestricted = false
							for _, roleId in state.roles[uid] do
								if roleId ~= "vip" and not table.find(state.freeAdmin, roleId) then
									expectedRestricted = true
								end
							end
							if sys.Auth.hasRestrictedRole(uid) ~= expectedRestricted then
								return true
							end
						end
						return false
					end,
				},
				invariants = {
					rankAndPermissionsMatchModel = function(state, sys)
						local Data = sys.Data
						local Auth = sys.Auth
						for _, uid in userIds do
							local expectedRank = 0
							for _, roleId in state.freeAdmin do
								expectedRank = math.max(expectedRank, Data.roles[roleId]._rank)
							end
							for _, roleId in state.roles[uid] do
								expectedRank = math.max(expectedRank, Data.roles[roleId]._rank)
							end
							local actualRank, actualRole = Auth.getRank(uid)
							expect(actualRank).toBe(expectedRank)
							expect(actualRole._rank).toBe(expectedRank)
							expect(Auth.hasPermission(uid, "banasync")).toBe(expectedRank >= 3)
							expect(Auth.hasPermission(uid, "saveRoles")).toBe(expectedRank >= 4)
						end
					end,
					banTimestampsMatchModel = function(state, sys)
						for _, uid in userIds do
							local banEntry = sys.Data.bans[tostring(uid)]
							if state.bans[uid] ~= nil then
								expect(banEntry ~= nil).toBe(true)
								expect(banEntry[3]).toBe(state.bans[uid].stamp)
							else
								expect(banEntry).toBeNil()
							end
						end
					end,
				},
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
		expect(table.find(Data.members["101"].roles, "vip") ~= nil).toBe(true)
		expect(Auth.hasRole(p1.UserId, "mod")).toBe(true)
		expect(Auth.hasRole(p1.UserId, "superadmin")).toBe(true)

		-- Second call without bustCache is a no-op
		Auth.userAsyncRoles(p1.UserId, false)

		-- With bustCache = true, re-evaluates group roles and removes stale exactRank group role
		h.env:setGroupRank(101, 1000, 250)
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
		expect(Auth.isPublicRole("mod")).toBe(true)
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
		expect(Data.members[tostring(pOnline.UserId)]).toBeNil()

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
		local ownsPassSpy = sert.spy(h.env.game:GetService("MarketplaceService"), "UserOwnsGamePassAsync", function()
			error("UserOwnsGamePassAsync failed")
		end)
		expect(select(2, target(70005))).toBe("Can't verify the rank of an offline user")
		ownsPassSpy:restore()

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
		h.env:setGroupRank(70006, 5000, 250)
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
		expect(target(unban, 70001, "70001")).toBe("70001")
		expect(groupSpy.callCount + passSpy.callCount).toBe(0)
		expect(select(2, target({ lowerRank = true }, 70001, "70001"))).toBe("Can only target lower ranks")
		expect(groupSpy.callCount + passSpy.callCount > 0).toBe(true)

		-- roles known in this server and loading players are still checked
		groupSpy:reset()
		passSpy:reset()
		Auth.userRoleAdd(70002, "superadmin")
		expect(select(2, target(unban, 70002, "70002"))).toBe("Can only target lower ranks")
		local loading = h.env:addPlayer(70003, "Loading")
		expect(select(2, target(unban, 70003, loading))).toBe("Can't target loading user")
		expect(groupSpy.callCount + passSpy.callCount).toBe(0)

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
		expect(Auth.targetUserArgument(arg, 70001, 70001)).toBe(70001)
		expect(groupSpy.callCount).toBe(0)
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
			expect(unbanned).toEqual({ 801 })
			expect(Data.bans["801"]).toBeNil()
			expect(Data.bans["802"] ~= nil).toBe(true)

			-- Re-seed expired timed ban on 801; moderator without banasync can replace it with a session ban
			Data.bans["801"] = { "ExpiredUser", "old timed ban", now - 10, 1 }
			local banned = Auth.banUsers({ 801, 802 }, "new session ban", 0, 21)
			expect(banned).toEqual({ 801 })
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
			sert.laws.remote("Auth.banUsers & unbanUsers (guest)", {
				makePlayer = function()
					return guestPlr
				end,
				argCount = 3,
				validGen = sert.gen.tuple({
					sert.gen.pick({ 101, 201, 500 }),
					sert.gen.malformedString(),
					sert.gen.boundaryInt(-1, 3600),
				}),
				invalidGen = sert.gen.tuple({
					sert.gen.remotePayload(2),
					sert.gen.adversarial(2),
					sert.gen.boundaryFloat(-1e6, 1e6),
				}),
				handler = function(plr: any, targetId: any, reason: any, duration: any)
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
				post = function(plr: any, ok: boolean)
					expect(ok).toBe(true)
					expect(Auth.getRank(plr.UserId)).toBe(0)
				end,
				checkState = function(plr: any)
					expect(Auth.getRank(plr.UserId)).toBe(0)
					expect(Data.bans["101"]).toBeNil()
					expect(Data.bans["201"]).toBeNil()
					expect(Data.bans["500"] ~= nil).toBe(true)
					expect(Data.bans["500"][3]).toBe(-1)
				end,
			}, { runs = 50 })

			-- 2. Moderator (without banasync) calling Auth.banUsers / Auth.unbanUsers against saved ban 500 & higher-rank 101
			sert.laws.remote("Auth.banUsers & unbanUsers (mod boundary)", {
				makePlayer = function()
					return modPlr
				end,
				argCount = 3,
				validGen = sert.gen.tuple({
					sert.gen.pick({ 101, 500 }),
					sert.gen.malformedString(),
					sert.gen.boundaryInt(-1, 3600),
				}),
				invalidGen = sert.gen.tuple({
					sert.gen.adversarial(2),
					sert.gen.remotePayload(2),
					sert.gen.boundaryFloat(-1e6, 1e6),
				}),
				handler = function(plr: any, targetId: any, reason: any, duration: any)
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
				post = function(plr: any, ok: boolean)
					expect(ok).toBe(true)
					expect(Auth.getRank(plr.UserId)).toBe(2)
				end,
				checkState = function()
					expect(Data.bans["101"]).toBeNil()
					expect(Data.bans["500"] ~= nil).toBe(true)
					expect(Data.bans["500"][3]).toBe(-1)
				end,
			}, { runs = 50 })
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

				expect(rAB).toBe(math.max(rA, rB))
				expect(rBA).toBe(rAB)

				for _, p in COMP_PERMS do
					local pA = compAuth.hasPermission(uA, p)
					local pB = compAuth.hasPermission(uB, p)
					local pAB = compAuth.hasPermission(uAB, p)
					local pBA = compAuth.hasPermission(uBA, p)
					expect(pAB).toBe(pA or pB)
					expect(pBA).toBe(pAB)
				end

				for _, c in COMP_CMDS do
					local cA = compAuth.hasCommand(uA, c) ~= false
					local cB = compAuth.hasCommand(uB, c) ~= false
					local cAB = compAuth.hasCommand(uAB, c) ~= false
					local cBA = compAuth.hasCommand(uBA, c) ~= false
					expect(cAB).toBe(cA or cB)
					expect(cBA).toBe(cAB)
				end

				for _, r in COMP_ROLES do
					local hA = compAuth.hasRole(uA, r)
					local hB = compAuth.hasRole(uB, r)
					local hAB = compAuth.hasRole(uAB, r)
					local hBA = compAuth.hasRole(uBA, r)
					expect(hAB).toBe(hA or hB)
					expect(hBA).toBe(hAB)
				end
			end,
			{ runs = 80 }
		)
	end
end)

return {}
