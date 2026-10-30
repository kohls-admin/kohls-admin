local Harness = require("./Harness")
local sert = require("../sert")

local describe, test, expect = sert.describe, sert.test, sert.expect

describe("Data · Schema Codecs & ChunkChanges Laws", function()
	local CHUNK_STAMPS = { -1, 0, 1700000000 }

	test("Data.Schema.log, logs, logRemote, and logsRemote satisfy Z binary codec round-trip laws", function()
		local h = Harness.shared()
		local Data = h:requireData()
		local Z = h.env:require(h.KA:WaitForChild("Z"))

		local function genLog(g)
			local hasFrom = g:bool()
			local from = if hasFrom then g:int(1, 100000) else nil
			local name = if hasFrom and g:bool() then g:string("abcdef", 3, 12) else nil
			return {
				g:string("abcdefghijklmnopqrstuvwxyz0123456789_", 1, 32),
				string.char(g:int(0, 5)),
				math.floor(g:float(1000, 1e9)),
				from,
				name,
			}
		end

		local function genLogRemote(g)
			local entry: { any } = genLog(g)
			if entry[4] ~= nil and entry[5] ~= nil and g:bool() then
				entry[6] = g:bool()
			end
			return entry
		end

		local function runZCodecLaw(name: string, schema: any, runs: number, gen: (any) -> any)
			sert.laws.codec({
				name = name,
				gen = gen,
				encode = function(v)
					local buf, err = Z.ser(schema, v)
					assert(buf ~= nil, tostring(err))
					return buf
				end,
				decode = function(buf)
					local val, err = Z.des(schema, buf)
					assert(val ~= nil, tostring(err))
					return val
				end,
			}, { runs = runs })
		end

		runZCodecLaw("Data.Schema.log", Data.Schema.log, 60, genLog)
		runZCodecLaw("Data.Schema.logs", Data.Schema.logs, 40, function(g)
			return g:list(genLog, 0, 8)
		end)
		runZCodecLaw("Data.Schema.logRemote", Data.Schema.logRemote, 60, genLogRemote)
		runZCodecLaw("Data.Schema.logsRemote", Data.Schema.logsRemote, 40, function(g)
			return g:list(genLogRemote, 0, 8)
		end)
	end)

	test("ChunkChanges satisfies chunking size-bound and lossless reassembly laws", function()
		local h = Harness.shared()
		local chunkChanges = h.env:require(h.Shared:WaitForChild("Data"):WaitForChild("ChunkChanges"))
		local HttpService = h.env.game:GetService("HttpService")
		local LIMIT = 32 * 1000 - 32

		sert.laws.chunk({
			name = "Data.ChunkChanges",
			minSize = LIMIT,
			maxSize = LIMIT,
			gen = function(g)
				local update: { [string]: any } = {}
				local count = g:int(1, 20)
				for i = 1, count do
					update[`user_{i}_{g:int(1, 999)}`] = {
						`Player{i}`,
						g:string("abcdefghij ", 2, 40),
						g:pick(CHUNK_STAMPS),
						1,
					}
				end
				return { bans = { update = update } }
			end,
			chunk = chunkChanges,
			measure = function(piece)
				return #HttpService:JSONEncode(piece)
			end,
			join = function(pieces)
				local mergedUpdate: { [string]: any } = {}
				for _, piece in pieces do
					if piece.bans and piece.bans.update then
						for k, v in piece.bans.update do
							mergedUpdate[k] = v
						end
					end
				end
				return { bans = { update = mergedUpdate } }
			end,
		}, { runs = 30 })
	end)

	test(
		"ChunkChanges splits >32KB payloads for both 'insert' arrays and 'set' dictionaries and reassembles losslessly",
		function()
			local h = Harness.shared()
			local chunkChanges = h.env:require(h.Shared:WaitForChild("Data"):WaitForChild("ChunkChanges"))
			local HttpService = h.env.game:GetService("HttpService")
			local pad = string.rep("x", 250)
			local logsInsert = {}
			local bansSet: { [string]: any } = {}
			for i = 1, 200 do
				logsInsert[i] = { `log_{i}_{pad}`, 1, 1700000000 + i, 101, "AdminUser" }
				bansSet[`user_{i}`] = { `Player_{i}`, `reason_{i}_{pad}`, -1, 101 }
			end

			local changes = {
				logs = { insert = logsInsert },
				bans = { set = bansSet },
			}
			expect(#HttpService:JSONEncode(changes) > 32000).toBe(true)

			local chunks = chunkChanges(changes)
			expect(#chunks >= 2).toBe(true)
			expect(#chunks <= 5).toBe(true)

			local mergedLogs = {}
			local mergedBans: { [string]: any } = {}
			for _, chunk in chunks do
				expect(#HttpService:JSONEncode(chunk) < 32000).toBe(true)
				if chunk.logs and chunk.logs.insert then
					for _, entry in chunk.logs.insert do
						table.insert(mergedLogs, entry)
					end
				end
				if chunk.bans and chunk.bans.set then
					for k, v in chunk.bans.set do
						mergedBans[k] = v
					end
				end
			end

			expect(#mergedLogs).toBe(200)
			expect(mergedLogs).toEqual(logsInsert)
			expect(mergedBans).toEqual(bansSet)
		end
	)
end)

describe("Data · Store CRUD, Budget & Studio/Publish Error Warnings", function()
	test("Store.loadStore, getBudget, getAsync, setAsync, updateAsync, removeAsync, and Studio error paths", function()
		-- 1. Normal Store lifecycle & CRUD
		local h = Harness.newEnv({ isStudio = false })
		local Store = h.env:require(h.Shared:WaitForChild("Data"):WaitForChild("Store"))
		local budget = Store.getBudget(h.env.globals.Enum.DataStoreRequestType.GetAsync)
		expect(type(budget)).toBe("number")

		local canSave, ds = Store.loadStore("_KStoreTest", "scope1")
		expect(canSave).toBe(true)
		expect(ds ~= nil).toBe(true)
		expect(Store.dataStore).toBe(ds)
		-- Second loadStore call returns cached Store.dataStore
		local canSave2, ds2 = Store.loadStore("_KStoreTest", "scope1")
		expect(canSave2).toBe(true)
		expect(ds2).toBe(ds)

		local okSet = Store.setAsync("testKey", { count = 10 }, { 101 })
		expect(okSet).toBe(true)

		local okGet, val = Store.getAsync("testKey")
		expect(okGet).toBe(true)
		expect(val.count).toBe(10)

		local okUpd, updVal = Store.updateAsync("testKey", function(old)
			return { count = (old and old.count or 0) + 5 }
		end)
		expect(okUpd).toBe(true)
		expect(updVal.count).toBe(15)

		local okRem, remVal = Store.removeAsync("testKey")
		expect(okRem).toBe(true)
		expect(remVal.count).toBe(15)

		local okAfter, afterVal = Store.getAsync("testKey")
		expect(okAfter).toBe(true)
		expect(afterVal).toBeNil()

		-- 2. Studio unpublished game warning ("publish" error in GetDataStore)
		local hPub = Harness.newEnv({ isStudio = true })
		local dssPub = hPub.env.game:GetService("DataStoreService")
		local origGetDS = dssPub.GetDataStore
		dssPub.GetDataStore = function()
			error("502: You must publish this place to the web to access DataStore.")
		end
		local StorePub = hPub.env:require(hPub.Shared:WaitForChild("Data"):WaitForChild("Store"))
		local canSavePub = StorePub.loadStore("_KUnpublished", "s")
		expect(canSavePub).toBe(false)
		dssPub.GetDataStore = origGetDS

		-- 3. Studio API access disabled warning ("Studio access" error in GetAsync("__TEST"))
		local hApi = Harness.newEnv({ isStudio = true })
		local dssApi = hApi.env.game:GetService("DataStoreService")
		dssApi.GetDataStore = function()
			return {
				GetAsync = function()
					error("403: Studio access to API services is not allowed.")
				end,
			}
		end
		local StoreApi = hApi.env:require(hApi.Shared:WaitForChild("Data"):WaitForChild("Store"))
		local canSaveApi, msgApi = StoreApi.loadStore("_KNoApi", "s")
		expect(canSaveApi).toBe(false)
		expect(string.find(tostring(msgApi), "Enable Studio access", 1, true) ~= nil).toBe(true)
	end)
end)

describe("Data · Migrate (Settings & Legacy KAI)", function()
	test("Migrate.Settings renames legacy keys and converts themeFont string/EnumItem/Font datatypes", function()
		local h = Harness.newEnv()
		local Data = h:requireData()
		local existingFont = h.env.globals.Font.new("rbxasset://fonts/families/Roboto.json")
		local settings: { [string]: any } = {
			defaultTheme = "Cyan",
			gameHubEnabled = false,
			themeFont = "Roboto",
			themeFontMono = h.env.globals.Enum.Font.RobotoMono,
		}
		Data.Migrate.Settings(settings)
		expect(settings.theme).toBe("Cyan")
		expect(settings.defaultTheme).toBeNil()
		expect(settings.addToCharts).toBe(false)
		expect(settings.gameHubEnabled).toBeNil()
		expect(h.env.globals.typeof(settings.themeFont)).toBe("Font")
		expect(h.env.globals.typeof(settings.themeFontMono)).toBe("Font")
		expect(Data.Sync.settings.defaultTheme).toBe(Data.REMOVE)
		expect(Data.Sync.settings.gameHubEnabled).toBe(Data.REMOVE)

		-- Passing an already-constructed Font instance preserves it unchanged (line 7 of Migrate/Settings.luau)
		settings.themeFont = existingFont
		Data.Migrate.Settings(settings)
		expect(settings.themeFont).toBe(existingFont)
	end)

	test(
		"Migrate.KAI imports legacy KSave admins, bans, and JSON settings and handles custom roles and DataStore errors",
		function()
			local h = Harness.newEnv({ isStudio = true })
			local Data = h:requireData()
			local dss = h.env.game:GetService("DataStoreService")
			local HttpService = h.env.game:GetService("HttpService")
			local globalStore = dss:GetGlobalDataStore()

			-- Temporarily rename Data.roles.admin to customAdmin (with _rank = 3) and remove superadmin (_rank = 4)
			-- so Migrate.KAI exercises both the custom _rank fallback loop and the unmapped rank return path
			local origAdmin = Data.roles.admin
			local origSuper = Data.roles.superadmin
			Data.roles.admin = nil
			Data.roles.customAdmin = origAdmin
			Data.roles.superadmin = nil

			globalStore:SetAsync("KSave", {
				"101:-3 102:-4 103:2",
				"201:-1 202:-1750000000 203:10",
				HttpService:JSONEncode({ FreeAdmin = 1, Prefix = "!" }),
			})

			Data.initialize("_K_MigrateTest")
			expect(Data.bans["201"] ~= nil).toBe(true)
			expect(Data.bans["201"][3]).toBe(-1)
			expect(Data.bans["202"][3]).toBe(1750000000)
			expect(Data.bans["203"]).toBeNil() -- positive duration is ignored
			expect(Data.members["101"] ~= nil).toBe(true)
			expect(table.find(Data.members["101"].roles, "customAdmin") ~= nil).toBe(true)
			expect(Data.members["102"]).toBeNil() -- rank 4 had no matching role
			expect(Data.members["103"]).toBeNil() -- positive power is ignored
			expect(Data.savedSettings.prefix).toEqual({ "!", ";" })

			Data.roles.admin = origAdmin
			Data.roles.customAdmin = nil
			Data.roles.superadmin = origSuper

			-- When GetGlobalDataStore throws, Migrate.KAI safely returns nil
			local origGetGlobal = dss.GetGlobalDataStore
			dss.GetGlobalDataStore = function()
				error("GlobalDataStore unavailable")
			end
			local bansErr, mainErr = Data.Migrate.KAI()
			expect(bansErr).toBeNil()
			expect(mainErr).toBeNil()
			dss.GetGlobalDataStore = origGetGlobal
		end
	)
end)

describe("Data & Sim · Multi-Server Sync, Partition Heal & BindToClose Convergence", function()
	local function bootServer(world: any, scope: string)
		local server = world:server({ skew = 0 })
		local h = Harness.newPeerEnv(server, { isStudio = false })
		local Data = h:requireData()
		Data.savedSettings.useSavedSettings = true
		Data.savedSettings.dashboardRank = 0
		local Auth = h:requireAuth()
		server:spawn(function()
			Data.initialize(scope)
		end)
		return {
			server = server,
			h = h,
			Data = Data,
			Auth = Auth,
		}
	end

	test(
		"sert.sim.model verifies multi-server ban, role, and setting convergence across live sync and server restarts",
		function()
			local targetUsers = { 301, 302, 303 }
			local banReasons = { "spam", "exploit", "grief" }
			local persistRoles = { "vip", "mod", "admin" }
			local convergeOpts = { timeout = 30, step = 2 }

			sert.sim.model({
				world = { backing = true, faults = { profile = "light", drop = 0 } },
				init = function(world)
					local n1 = bootServer(world, "_K_ModelSync")
					local n2 = bootServer(world, "_K_ModelSync")
					world:run(20)
					return {
						bans = {},
						roles = {},
						dashboardRank = 0,
					}, { n1 = n1, n2 = n2, nodes = { n1, n2 } }
				end,
				commands = {
					BanUser = {
						gen = function(g)
							return {
								nodeIdx = g:int(1, 2),
								userId = g:pick(targetUsers),
								reason = g:pick(banReasons),
							}
						end,
						run = function(sys, args, world)
							local node = sys.nodes[args.nodeIdx]
							node.server:spawn(function()
								node.Auth.banUsers({ args.userId }, args.reason, -1, nil, true)
							end)
							world:run(0.5)
						end,
						next = function(state, args)
							state.bans[tostring(args.userId)] = args.reason
						end,
					},
					UnbanUser = {
						gen = function(g)
							return {
								nodeIdx = g:int(1, 2),
								userId = g:pick(targetUsers),
							}
						end,
						run = function(sys, args, world)
							local node = sys.nodes[args.nodeIdx]
							node.server:spawn(function()
								node.Auth.unbanUsers({ args.userId }, nil, true)
							end)
							world:run(0.5)
						end,
						next = function(state, args)
							state.bans[tostring(args.userId)] = nil
						end,
					},
					GrantPersistRole = {
						gen = function(g)
							return {
								nodeIdx = g:int(1, 2),
								userId = g:pick(targetUsers),
								role = g:pick(persistRoles),
							}
						end,
						run = function(sys, args, world)
							local node = sys.nodes[args.nodeIdx]
							node.server:spawn(function()
								node.Auth.userRoleAdd(args.userId, args.role, true)
							end)
							world:run(0.5)
						end,
						next = function(state, args)
							local key = tostring(args.userId)
							state.roles[key] = state.roles[key] or {}
							state.roles[key][args.role] = true
						end,
					},
					UpdateSetting = {
						gen = function(g)
							return {
								nodeIdx = g:int(1, 2),
								rank = g:int(0, 3),
							}
						end,
						run = function(sys, args, world)
							local node = sys.nodes[args.nodeIdx]
							node.Data.savedSettings.dashboardRank = args.rank
							node.Data.Sync.settings.dashboardRank = args.rank
							world:step()
						end,
						next = function(state, args)
							state.dashboardRank = args.rank
						end,
					},
					RestartNode2 = {
						gen = function()
							return {}
						end,
						run = function(sys, _, world)
							sys.n2.server:shutdown()
							world:run(6)
							sys.n2 = bootServer(world, "_K_ModelSync")
							sys.nodes[2] = sys.n2
							world:run(20)
						end,
						next = function(_state) end,
					},
				},
				invariant = function(state, sys, world)
					local function project(srv: any)
						local node = if srv == sys.n1.server then sys.n1 else sys.n2
						local activeBans: { [string]: string } = {}
						for k, v in node.Data.bans do
							if type(v) == "table" then
								activeBans[k] = v[2]
							end
						end
						local activeRoles: { [string]: { [string]: boolean } } = {}
						for k, member in node.Data.members do
							if type(member) == "table" and type(member.persist) == "table" and #member.persist > 0 then
								local roleSet: { [string]: boolean } = {}
								for _, r in member.persist do
									roleSet[r] = true
								end
								activeRoles[k] = roleSet
							end
						end
						return {
							bans = activeBans,
							roles = activeRoles,
							dashboardRank = node.Data.savedSettings.dashboardRank,
						}
					end
					world:run(8)
					world:converge(project, convergeOpts)
					expect(project(sys.n1.server)).toEqual({
						bans = state.bans,
						roles = state.roles,
						dashboardRank = state.dashboardRank,
					})
				end,
			}, { runs = if rawget(_G, "__SERT_MUTANT") ~= nil then 2 else 15, length = 8 })
		end
	)

	local function waitServerReady(world: any, node: any)
		for _ = 1, 600 do
			if #node.server.closers > 0 then
				return
			end
			world:run(0.1)
		end
	end

	test("sert.sim.explore verifies BindToClose shutdown flushes pending bans, roles, and logs to DataStore", function()
		sert.sim.explore(function(world)
			local n1 = bootServer(world, "_K_ShutdownFlush")
			waitServerReady(world, n1)

			local now = n1.h.env.workspace:GetServerTimeNow()
			n1.server:spawn(function()
				n1.Auth.banUsers({ 777 }, "persistent ban", -1, nil, true)
				n1.Auth.userRoleAdd(888, "admin", true)
				table.insert(n1.Data.Sync.logs, { "shutdown_flushed_log", string.char(1), now, 888, "Admin888" })
			end)
			world:run(0.5)

			-- Shutdown server 1 (triggers BindToClose DataStore/MemoryStore flush for bans, members, and logs)
			n1.server:shutdown()
			world:run(20)

			-- Boot a fresh server 2 on the same scope and verify it loads the ban, persistent role, and log
			local n2 = bootServer(world, "_K_ShutdownFlush")
			waitServerReady(world, n2)

			expect(n2.Data.bans["777"] ~= nil).toBe(true)
			expect(n2.Data.bans["777"][3]).toBe(-1)
			expect(n2.Data.members["888"] ~= nil).toBe(true)
			expect(table.find(n2.Data.members["888"].persist, "admin") ~= nil).toBe(true)
			local sawShutdownLog = false
			for _, entry in n2.Data.logs do
				if entry[1] == "shutdown_flushed_log" then
					sawShutdownLog = true
				end
			end
			expect(sawShutdownLog).toBe(true)
		end, {
			maxRuns = 12,
			world = { faults = "none", backing = true },
		})
	end)

	test("member syncs from other servers keep the unrestricted flags of session roles", function()
		local world = sert.sim.new({ backing = true })
		local n1 = bootServer(world, "_K_UnrestrictedSync")
		local n2 = bootServer(world, "_K_UnrestrictedSync")
		world:run(6)

		local function sync(fn: () -> ())
			n2.server:spawn(fn)
			world:run(7)
			world.messaging:drain()
			world:run(1)
		end

		-- a non-developer gave 301 Moderator for this session on server 1
		n1.server:spawn(function()
			n1.Auth.userRoleAdd(301, "mod", false, true)
		end)
		world:run(0.1)
		expect(n1.Auth.hasRestrictedRole(301)).toBe(false)

		-- a developer on server 2 saves VIP for 301: server 1 keeps the session Moderator unrestricted
		sync(function()
			n2.Auth.userRoleAdd(301, "vip", true)
		end)
		local member = n1.Data.members["301"]
		expect(member.roles).toEqual({ "mod", "vip" })
		expect(member.unrestricted and member.unrestricted.mod).toBe(true)
		expect(n1.Auth.hasRestrictedRole(301)).toBe(false)

		-- once a developer saves the Moderator role itself, it is a developer's grant everywhere
		sync(function()
			n2.Auth.userRoleAdd(301, "mod", true)
		end)
		member = n1.Data.members["301"]
		expect(member.persist).toEqual({ "mod", "vip" })
		expect(member.unrestricted and member.unrestricted.mod).toBeNil()
		expect(n1.Auth.hasRestrictedRole(301)).toBe(true)
	end)

	test(
		"unsaved local changes in SAVE during the 60s DataStore throttle are not overwritten by older syncs",
		function()
			local world = sert.sim.new({ backing = true })
			local n1 = bootServer(world, "_K_SaveThrottleGuard")
			local n2 = bootServer(world, "_K_SaveThrottleGuard")
			world:run(6)

			-- Trigger initial save on n1 to start its 60s dataStoreUpdateThrottle
			n1.server:spawn(function()
				n1.Auth.banUsers({ 901 }, "initial ban", -1, nil, true)
			end)
			world:run(2)

			-- While n1's 60s throttle is active, n1 makes local changes that processSync drains into SAVE
			n1.server:spawn(function()
				n1.Auth.userRoleAdd(902, "admin", true)
				n1.Auth.banUsers({ 903 }, "fresh local ban", -1, nil, true)
			end)
			world:run(7)
			expect(n1.Data.Sync.members["902"]).toBeNil()
			expect(n1.Data.members["902"].persist).toEqual({ "admin" })
			expect(n1.Data.bans["903"][2]).toBe("fresh local ban")

			-- Inject an older cross-server sync item into the MemoryStore hashmap and replay via MessagingService
			local ms = n1.h.env.game:GetService("MemoryStoreService")
			for i = 1, 7 do
				local hm = ms:GetHashMap("_KData" .. i)
				hm:SetAsync("stale_sync_1", {
					_time = 1, -- older than n1's local SAVE timestamp
					members = {
						set = {
							["902"] = { "StaleName", { "vip" } },
						},
					},
					bans = {
						set = {
							["901"] = { "StaleSavedBan", "stale saved reason", -1, 101 },
							["903"] = { "StaleBan", "stale reason", -1, 101 },
						},
						unset = { "901", "903" },
					},
				}, 60)
			end
			n2.server:spawn(function()
				n2.h.env.game:GetService("MessagingService"):PublishAsync("_KData", { "stale_sync", 1 })
			end)
			world:run(0.5)
			world.messaging:drain()
			world:run(1)

			-- n1's newer saved (901) and unsaved (902, 903) changes must remain intact
			expect(n1.Data.bans["901"] ~= nil).toBe(true)
			expect(n1.Data.bans["901"][2]).toBe("initial ban")
			expect(n1.Data.members["902"].persist).toEqual({ "admin" })
			expect(n1.Data.bans["903"] ~= nil).toBe(true)
			expect(n1.Data.bans["903"][2]).toBe("fresh local ban")

			-- Shutdown n1 so BindToClose flushes SAVE to DataStore, then verify a fresh server loads n1's local changes
			n1.server:shutdown()
			world:run(6)
			local n3 = bootServer(world, "_K_SaveThrottleGuard")
			world:run(6)
			expect(n3.Data.members["902"].persist).toEqual({ "admin" })
			expect(n3.Data.bans["903"][2]).toBe("fresh local ban")
			n2.server:shutdown()
			n3.server:shutdown()
		end
	)

	test(
		"Data.initialize handles V0->V1 log migration, >512KB log trimming, dataLimitWarning, REMOVE/insert sync, and error/private-server paths",
		function()
			local world = sert.sim.new({ backing = true })
			local s1 = world:server({ skew = 0 })
			local h1 = Harness.newPeerEnv(s1, { isStudio = false })
			local Data1 = h1:requireData()
			Data1.defaultSettings = table.clone(Data1.settings)
			Data1.savedSettings = table.clone(Data1.settings)
			local Auth1 = h1:requireAuth()
			local Util1 = h1:requireUtil()
			local Z1 = h1.env:require(h1.KA:WaitForChild("Z"))
			Z1.BUFFER = buffer.create(4 * 1024 ^ 2)

			local scope = "_K_AdvancedData"
			local dss = h1.env.game:GetService("DataStoreService")
			local rawStore = dss:GetDataStore("_KData", scope)
			local now = h1.env.workspace:GetServerTimeNow()

			-- Seed shards 1..3 with legacy V0 log buffers (including >30-day-old and recent logs + >250KB payload for combined shard trimming)
			-- and shard 4 with a corrupted buffer to exercise migration & sync error fallbacks
			local bigExisting = string.rep("E", 14000)
			local v0Logs = {
				{
					level = string.char(1),
					from = 101,
					name = "OldAdmin",
					text = "expired_v0_log",
					time = now - 40 * 86400,
				},
				{ level = string.char(1), from = 101, name = "Alice", text = "migrated_v0_log", time = now - 10 },
			}
			for idx = 1, 20 do
				table.insert(v0Logs, {
					level = string.char(1),
					from = 101,
					name = "Alice",
					text = bigExisting .. idx,
					time = now - 5 + idx * 0.01,
				})
			end
			local v0Buf = Z1.ser(Data1.Schema.logsV0, v0Logs)
			for i = 1, 3 do
				rawStore:SetAsync("Logs_" .. i, v0Buf)
			end
			rawStore:SetAsync("Logs_4", buffer.fromstring("\255\255\255"))

			rawStore:SetAsync("Servers", {
				legacyLobby = { "access_code_123", 98765 },
			})
			rawStore:SetAsync("Bans", {
				["5001"] = { "Banned1", "temp", -1, 101 },
			})

			-- Pre-seed Data1.members["203"] (with admin + mod) and pending Data1.Sync.members["204"]
			Data1.members["203"] = {
				name = "Existing203",
				roles = { "admin", "mod" },
				persist = { "admin", "mod" },
			}
			Data1.Sync.members["204"] = { "PendingLocal204", { "vip" } }

			rawStore:SetAsync("Main", {
				{
					["202"] = { "SyncedMod", { "mod", "invalid_role_xyz" } },
					["203"] = { "Existing203", { "mod" } }, -- removes "admin" from persist/roles (line 269)
					["204"] = { "Remote204", { "admin" } }, -- skipped because Data1.Sync.members["204"] is pending (lines 242-243)
					["205"] = { "EmptyRoles205", { "invalid_role_only" } }, -- #data.roles == 0 -> removed (lines 285-286)
				},
				{
					themePrimary = { "color", 1, 0, 0 },
					themeCornerRadius = { "udim", 0, 8 },
					sampleEnum = { "enum", "Font", "Roboto" },
					prefix = "!",
				},
			})

			local function seedServerAdminAndCommands(h: Harness.MountedEnv, Auth: any, adminName: string)
				local adminPlr = h.env:addPlayer(101, adminName)
				adminPlr:SetAttribute("_K_READY", true)
				Auth.userRoleAdd(101, "superadmin")
				local Registry = h:requireRegistry()
				for _, cmdName in { "place", "unreserve", "members" } do
					Registry.commands[cmdName] = { name = cmdName, group = "administration", aliases = {}, args = {} }
				end
				Registry.commands.ban = { name = "ban", group = "moderation", aliases = {}, args = {} }
			end

			seedServerAdminAndCommands(h1, Auth1, "AdminOnline")
			local guestPlr = h1.env:addPlayer(909, "GuestOnline")
			guestPlr:SetAttribute("_K_READY", true)

			local warnings = {}
			local Remote1 = h1:requireRemote()
			Remote1.Notify.Fire = function(_self, _plr, payload)
				table.insert(warnings, payload.Text)
			end

			-- Set Logger.limit low during initialize so SYNC.logs exercises excess log trimming (lines 371-374)
			local origLimit = Util1.Logger.limit
			Util1.Logger.limit = 10

			s1:spawn(function()
				Data1.initialize(scope)
			end)
			world:run(2)
			Util1.Logger.limit = origLimit

			-- Verify V0 logs were migrated and trimmed to Logger.limit (10)
			expect(#Data1.logs).toBe(10)

			-- Verify ReservedServers 2-tuple was converted to 3-tuple { code, accessCode, placeId }
			expect(Data1.reservedServers.legacyLobby).toEqual({ "legacyLobby", "access_code_123", 98765 })

			-- Verify Main members & settings deserialization
			expect(Data1.members["202"] ~= nil).toBe(true)
			expect(Data1.members["202"].persist).toEqual({ "mod" })
			expect(Data1.members["203"].roles).toEqual({ "mod" })
			expect(Data1.members["204"]).toBeNil() -- was skipped due to pending Sync.members["204"]
			expect(Data1.members["205"]).toBeNil() -- all invalid roles filtered out (#roles == 0 branch)
			expect(h1.env.globals.typeof(Data1.savedSettings.themePrimary)).toBe("Color3")
			expect(h1.env.globals.typeof(Data1.savedSettings.themeCornerRadius)).toBe("UDim")
			expect(Data1.savedSettings.sampleEnum).toBe(h1.env.globals.Enum.Font.Roboto)

			-- Boot a second server s2 to verify REMOVE.bans, REMOVE.members, and logs insert cross-server sync
			rawStore:SetAsync("Main", {
				{ ["202"] = { "SyncedMod", { "mod" } } },
				{},
			})
			rawStore:SetAsync("Bans", {
				["5001"] = { "Banned1", "temp", -1, 101 },
			})
			Data1.bans["5001"] = { "Banned1", "temp", -1, 101 }

			local s2 = bootServer(world, scope)
			seedServerAdminAndCommands(s2.h, s2.Auth, "AdminOnS2")
			world:run(5)
			expect(s2.Data.members["202"] ~= nil).toBe(true)
			expect(s2.Data.bans["5001"] ~= nil).toBe(true)

			-- Remove member 202, unban 5001, and insert a synced log on s1 -> syncs to s2
			s1:spawn(function()
				Auth1.userRoleRemove(202, "mod")
				Auth1.unbanUsers({ 5001 }, 101, true)
				table.insert(Data1.Sync.logs, { "cross_server_log", string.char(1), now + 50, 101, "AdminOnline" })
			end)
			-- Also publish a JSON string that decodes to a non-table to exercise lines 666 & 669
			local Messaging1 = h1.env.game:GetService("MessagingService")
			s1:spawn(function()
				Messaging1:PublishAsync("_KData", '"not_a_table"')
			end)
			world:run(7)
			world.messaging:drain()
			world:run(1)
			expect(s2.Data.members["202"]).toBeNil()
			expect(s2.Data.bans["5001"]).toBeNil()

			-- Queue 280KB of logs in Data1.Sync.logs (<= 512KB so first loop doesn't trim, but existing shard + saveLogs > 512KB so second loop trims!)
			-- and queue >512KB in a second batch + >90% of 512KB in Data1.Sync.bans for dataLimitWarning
			Data1.SEPARATE_DATASTORE = true
			local bigLogText = string.rep("L", 15000)
			for i = 1, 20 do
				table.insert(Data1.Sync.logs, { bigLogText .. i, string.char(1), now + i, 101, "AdminOnline" })
			end
			local bigBanReason = string.rep("B", 15000)
			for i = 1, 33 do
				Data1.Sync.bans[tostring(5000 + i)] = { `Banned{i}`, bigBanReason, -1, 101 }
			end

			-- Advance past HASH_EXPIRY (60s) so dataStoreUpdateThrottle resets and processSync runs updateBans & updateLogs
			world:run(65)
			local sawLimitWarn = false
			for _, w in warnings do
				if string.find(tostring(w), "approaching the limit of the DataStore", 1, true) then
					sawLimitWarn = true
				end
			end
			expect(sawLimitWarn).toBe(true)

			-- Also trigger >512KB single-batch saveLogs trimming (lines 156-163)
			local newest
			for i = 1, 36 do
				newest = { bigLogText .. i, string.char(1), now + 100 + i, 101, "AdminOnline" }
				table.insert(Data1.Sync.logs, newest)
			end
			world:run(65)
			-- the log rows are also synced as JSON arrays, measuring them for the save mustn't add keys
			expect(newest.size).toBeNil()
			-- the trimmed save keeps the newest log and stays under the DataStore limit
			local savedNewest = false
			for i = 1, 4 do
				local shard = rawStore:GetAsync("Logs_" .. i)
				if type(shard) == "buffer" then
					expect(buffer.len(shard) <= 512 * 1024).toBe(true)
					local ok, logs = pcall(Z1.des, Data1.Schema.logs, shard)
					if ok then
						for _, log in logs do
							if log[1] == newest[1] and log[3] == newest[3] then
								savedNewest = true
							end
						end
					end
				end
			end
			expect(savedNewest).toBe(true)

			-- Test Data.initialize when SEPARATE_DATASTORE = true (erases Logs_1..4, lines 627-629)
			-- and when Store.loadStore fails (canSave = false, lines 561-565)
			local hPriv = Harness.newEnv({ isStudio = false })
			local DataPriv = hPriv:requireData()
			DataPriv.SEPARATE_DATASTORE = true
			DataPriv.initialize("_K_PrivScope")
			hPriv.env:step(0.1)
			expect(DataPriv.canSave).toBe(true)

			local hFail = Harness.newEnv({ isStudio = true })
			local dssFail = hFail.env.game:GetService("DataStoreService")
			dssFail.GetDataStore = function()
				error("502: You must publish this place to the web to access DataStore.")
			end
			local DataFail = hFail:requireData()
			DataFail.initialize("_K_FailScope")
			expect(DataFail.canSave).toBe(false)
			expect(type(DataFail.saveError)).toBe("string")
		end
	)
end)

describe("Data · ChunkChanges array actions", function()
	local LIMIT = 32 * 1000 - 32

	-- Chunks `changes` and checks every chunk encodes within LIMIT, every insert/unset list is a proper array
	-- (1..n, no holes) and the merged chunks reproduce `changes`: sets, inserts in order, every unset key.
	local function checkChunks(changes: { [string]: any }): number
		local h = Harness.shared()
		local chunkChanges = h.env:require(h.Shared:WaitForChild("Data"):WaitForChild("ChunkChanges"))
		local HttpService = h.env.game:GetService("HttpService")

		local chunks = chunkChanges(changes)
		local merged: { [string]: any } = {}
		for _, chunk in chunks do
			local ok, json = pcall(HttpService.JSONEncode, HttpService, chunk)
			expect(ok).toBe(true)
			expect(#json <= LIMIT).toBe(true)
			-- processSync stamps _time on each chunk before SetAsync, which takes items up to 32 KB
			local stamped = table.clone(chunk)
			stamped._time = 1700000000000
			expect(#HttpService:JSONEncode(stamped) <= 32 * 1000).toBe(true)
			for key, info in chunk do
				local into = merged[key] or {}
				merged[key] = into
				for action, data in info do
					if action == "insert" or action == "unset" then
						local count = 0
						for _ in data do
							count += 1
						end
						expect(count > 0).toBe(true)
						expect(count).toBe(#data)
						into[action] = into[action] or {}
						table.move(data, 1, #data, #into[action] + 1, into[action])
					else
						into[action] = into[action] or {}
						for k, v in data do
							expect(into[action][k]).toBeNil()
							into[action][k] = v
						end
					end
				end
			end
		end
		expect(merged).toEqual(changes)
		return #chunks
	end

	test("ChunkChanges splits a >32KB unset list into proper arrays alongside sets and inserts", function()
		local pad = string.rep("x", 200)
		local bansSet: { [string]: any } = {}
		local bansUnset, membersUnset, logsInsert = {}, {}, {}
		for i = 1, 60 do
			bansSet[`{2000000 + i}`] = { `Player_{i}`, `reason_{i}_{pad}`, -1, 101 }
		end
		for i = 1, 3000 do
			bansUnset[i] = `{1000000000 + i}`
		end
		for i = 1, 400 do
			membersUnset[i] = `{3000000000 + i}`
		end
		for i = 1, 80 do
			logsInsert[i] = { `log_{i}_{pad}`, string.char(1), 1700000000 + i, 101, "AdminUser" }
		end
		local changes = {
			bans = { set = bansSet, unset = bansUnset },
			members = { unset = membersUnset },
			logs = { insert = logsInsert },
		}
		expect(checkChunks(changes) >= 3).toBe(true)
	end)

	sert.prop("ChunkChanges chunks stay under the limit, encode as arrays and merge back losslessly", function(g)
		local keyChars = 'abc019"\\'
		local changes: { [string]: any } = {}
		for _, key in { "bans", "members", "settings" } do
			local info: { [string]: any } = {}
			local set: { [string]: any } = {}
			for i = 1, g:int(0, 40) do
				set[`s{i}_{g:string(keyChars, 0, 6)}`] = { g:string(keyChars, 0, g:int(0, 600)), g:int(-1, 1e9) }
			end
			local unset = {}
			for i = 1, g:int(0, 600) do
				unset[i] = `u{i}_{g:string(keyChars, 0, 3)}`
			end
			info.set = if next(set) ~= nil then set else nil
			info.unset = if #unset > 0 then unset else nil
			if next(info) ~= nil then
				changes[key] = info
			end
		end
		local logs = {}
		for i = 1, g:int(0, 120) do
			logs[i] = { g:string(keyChars, 1, g:int(1, 400)), string.char(g:int(0, 5)), 1700000000 + i }
		end
		if #logs > 0 then
			changes.logs = { insert = logs }
		end
		checkChunks(changes)
	end, { runs = 40 })

	test("ChunkChanges accounts for comma separator when a key has multiple actions near the 32KB limit", function()
		local h = Harness.newEnv({ isStudio = false })
		local ChunkChanges = h.env:require(h.Shared.Data.ChunkChanges)
		local Http = h.env.game:GetService("HttpService")

		-- Construct a payload where `bans.set` fills the first chunk to within 11 bytes of LIMIT,
		-- so adding `,"unset":["1"]` (14 bytes: 9 for `,"unset":{}` + 3 for `"1"` + 1 prefix) must spill
		-- to chunk 2 rather than overflowing LIMIT by 1 byte due to undercounting the comma before `"unset"`.
		local pad = string.rep("a", 31900)
		local base = {
			bans = {
				set = { k = pad },
			},
		}
		local baseEncoded = #Http:JSONEncode(base)
		local targetRemaining = 12 -- `"unset"` + 5 + 4 (`"1"` + 1) == 16, or if `set` was smaller: craft exact boundary
		local adjust = (LIMIT - targetRemaining) - baseEncoded
		if adjust > 0 then
			base.bans.set.k = pad .. string.rep("b", adjust)
		elseif adjust < 0 then
			base.bans.set.k = string.sub(pad, 1, #pad + adjust)
		end
		base.bans.unset = { "1" }

		local chunks = ChunkChanges(base)
		for _, chunk in chunks do
			expect(#Http:JSONEncode(chunk) <= LIMIT).toBe(true)
		end
	end)
end)

return {}
