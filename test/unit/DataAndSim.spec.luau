local Harness = require("./Harness")
local sert = require("../sert")

local describe, test = sert.describe, sert.test

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

		sert.prop("Data.ChunkChanges", function(g)
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
			local input = { bans = { update = update } }
			local pieces = chunkChanges(input)
			sert.eq(#pieces >= 1, true)
			local mergedUpdate: { [string]: any } = {}
			for _, piece in pieces do
				sert.eq(#HttpService:JSONEncode(piece) <= LIMIT, true)
				if piece.bans and piece.bans.update then
					for k, v in piece.bans.update do
						mergedUpdate[k] = v
					end
				end
			end
			sert.eq({ bans = { update = mergedUpdate } }, input)
		end, { runs = 30 })
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
			sert.eq(#HttpService:JSONEncode(changes) > 32000, true)

			local chunks = chunkChanges(changes)
			sert.eq(#chunks >= 2, true)
			sert.eq(#chunks <= 5, true)

			local mergedLogs = {}
			local mergedBans: { [string]: any } = {}
			for _, chunk in chunks do
				sert.eq(#HttpService:JSONEncode(chunk) < 32000, true)
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

			sert.eq(#mergedLogs, 200)
			sert.eq(mergedLogs, logsInsert)
			sert.eq(mergedBans, bansSet)
		end
	)
end)

describe("Data · Store CRUD, Budget & Studio/Publish Error Warnings", function()
	test("Store.loadStore, getBudget, getAsync, setAsync, updateAsync, removeAsync, and Studio error paths", function()
		-- 1. Normal Store lifecycle & CRUD
		local h = Harness.newEnv({ isStudio = false })
		local Store = h.env:require(h.Shared:WaitForChild("Data"):WaitForChild("Store"))
		local budget = Store.getBudget(h.env.globals.Enum.DataStoreRequestType.GetAsync)
		sert.eq(type(budget), "number")

		local canSave, ds = Store.loadStore("_KStoreTest", "scope1")
		sert.eq(canSave, true)
		sert.eq(ds ~= nil, true)
		sert.eq(Store.dataStore, ds)
		-- Second loadStore call returns cached Store.dataStore
		local canSave2, ds2 = Store.loadStore("_KStoreTest", "scope1")
		sert.eq(canSave2, true)
		sert.eq(ds2, ds)

		local okSet = Store.setAsync("testKey", { count = 10 }, { 101 })
		sert.eq(okSet, true)

		local okGet, val = Store.getAsync("testKey")
		sert.eq(okGet, true)
		sert.eq(val.count, 10)

		local okUpd, updVal = Store.updateAsync("testKey", function(old)
			return { count = (old and old.count or 0) + 5 }
		end)
		sert.eq(okUpd, true)
		sert.eq(updVal.count, 15)

		local okRem, remVal = Store.removeAsync("testKey")
		sert.eq(okRem, true)
		sert.eq(remVal.count, 15)

		local okAfter, afterVal = Store.getAsync("testKey")
		sert.eq(okAfter, true)
		sert.eq(afterVal, nil)

		-- Verify waitForBudget is invoked by getAsync, setAsync, updateAsync, and removeAsync, and respects closing & budget reserve
		local waitedTypes = {}
		local origWaitForBudget = Store.waitForBudget
		Store.waitForBudget = function(reqType, reserve)
			table.insert(waitedTypes, reqType)
			return origWaitForBudget(reqType, reserve)
		end
		Store.setAsync("bKey", 1)
		Store.getAsync("bKey")
		Store.updateAsync("bKey", function(v)
			return v
		end)
		Store.removeAsync("bKey")
		Store.waitForBudget = origWaitForBudget
		sert.eq(#waitedTypes, 4)

		-- Verify waitForBudget polls up to 5 times when budget < minBudget, stops early when Store.closing = true, and breaks when getBudget throws
		local budgetChecks = 0
		local origGetBudget = Store.getBudget
		Store.getBudget = function()
			budgetChecks += 1
			if budgetChecks < 3 then
				return 0
			end
			return 5
		end
		h.env.task.spawn(function()
			Store.waitForBudget(h.env.globals.Enum.DataStoreRequestType.GetAsync, 2)
		end)
		h.env:advance(5)
		sert.eq(budgetChecks, 3)

		budgetChecks = 0
		Store.closing = true
		Store.waitForBudget(h.env.globals.Enum.DataStoreRequestType.GetAsync, 2)
		sert.eq(budgetChecks, 0)
		Store.closing = false

		Store.getBudget = function()
			budgetChecks += 1
			error("GetRequestBudget unavailable")
		end
		Store.waitForBudget(h.env.globals.Enum.DataStoreRequestType.GetAsync, 2)
		sert.eq(budgetChecks, 1)
		Store.getBudget = origGetBudget

		-- Verify transient DataStore failure retries with jitterBase > 1s
		local retryTries = 0
		local origGetAsync = Store.dataStore.GetAsync
		Store.dataStore.GetAsync = function(self, k, opts)
			retryTries += 1
			if retryTries == 1 then
				error("Transient 500")
			end
			return origGetAsync(self, k, opts)
		end
		local retryOk = false
		h.env.task.spawn(function()
			retryOk = Store.getAsync("testKey")
		end)
		h.env:advance(5)
		sert.eq(retryOk, true)
		sert.eq(retryTries, 2)
		Store.dataStore.GetAsync = origGetAsync

		-- 2. Studio unpublished game warning ("publish" error in GetDataStore) and non-publish permanent error clearing Store.dataStore
		local hPub = Harness.newEnv({ isStudio = true })
		local dssPub = hPub.env.game:GetService("DataStoreService")
		local origGetDS = dssPub.GetDataStore
		local StorePub = hPub.env:require(hPub.Shared:WaitForChild("Data"):WaitForChild("Store"))
		StorePub.loadStore("_KValidFirst", "s")
		sert.eq(StorePub.dataStore ~= nil, true)
		dssPub.GetDataStore = function()
			error("502: You must publish this place to the web to access DataStore.")
		end
		local canSavePub = StorePub.loadStore("_KUnpublished", "s")
		sert.eq(canSavePub, false)
		sert.eq(StorePub.dataStore, nil)
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
		sert.eq(canSaveApi, false)
		sert.eq(string.find(tostring(msgApi), "Enable Studio access", 1, true) ~= nil, true)
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
		sert.eq(settings.theme, "Cyan")
		sert.eq(settings.defaultTheme, nil)
		sert.eq(settings.addToCharts, false)
		sert.eq(settings.gameHubEnabled, nil)
		sert.eq(h.env.globals.typeof(settings.themeFont), "Font")
		sert.eq(h.env.globals.typeof(settings.themeFontMono), "Font")
		sert.eq(Data.Sync.settings.defaultTheme, Data.REMOVE)
		sert.eq(Data.Sync.settings.gameHubEnabled, Data.REMOVE)

		-- Passing an already-constructed Font instance preserves it unchanged (line 7 of Migrate/Settings.luau)
		settings.themeFont = existingFont
		Data.Migrate.Settings(settings)
		sert.eq(settings.themeFont, existingFont)
	end)

	test(
		"Migrate.KAI imports legacy KSave admins, bans, and JSON settings and handles custom roles and DataStore errors",
		function()
			local h = Harness.newEnv({ isStudio = true })
			local studioHashMaps = 0
			local emptyMap = {
				ListItemsAsync = function()
					return {
						GetCurrentPage = function()
							return {}
						end,
						IsFinished = true,
					}
				end,
			}
			h.env.game:GetService("MemoryStoreService").GetHashMap = function(_self: any, name: string)
				if name ~= "__KA_Charts" then
					studioHashMaps += 1
				end
				return emptyMap
			end
			h.env.game:GetService("MessagingService").SubscribeAsync = function() end
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
			sert.eq(studioHashMaps, 0)
			sert.eq(Data.bans["201"] ~= nil, true)
			sert.eq(Data.bans["201"][3], -1)
			sert.eq(Data.bans["202"][3], 1750000000)
			sert.eq(Data.bans["203"], nil) -- positive duration is ignored
			sert.eq(Data.members["101"] ~= nil, true)
			sert.eq(table.find(Data.members["101"].roles, "customAdmin") ~= nil, true)
			sert.eq(Data.members["102"], nil) -- rank 4 had no matching role
			sert.eq(Data.members["103"], nil) -- positive power is ignored
			sert.eq(Data.savedSettings.prefix, { "!" })

			Data.roles.admin = origAdmin
			Data.roles.customAdmin = nil
			Data.roles.superadmin = origSuper

			-- When GetGlobalDataStore throws, Migrate.KAI safely returns nil
			local origGetGlobal = dss.GetGlobalDataStore
			dss.GetGlobalDataStore = function()
				error("GlobalDataStore unavailable")
			end
			local bansErr, mainErr = Data.Migrate.KAI()
			sert.eq(bansErr, nil)
			sert.eq(mainErr, nil)
			dss.GetGlobalDataStore = origGetGlobal
		end
	)
end)

describe("Data & Sim · Multi-Server Sync, Partition Heal & BindToClose Convergence", function()
	local function bootServer(world: any, scope: string, slot: number?)
		local restarts = if slot ~= nil and world.servers[slot] ~= nil then world.servers[slot].restarts + 1 else 0
		local server = world:server({ slot = slot, restarts = restarts, skew = 0 })
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

	local function waitServerReady(world: any, node: any)
		for _ = 1, 600 do
			if #node.server.closers > 0 or node.server.state ~= "up" then
				return
			end
			world:run(0.1)
		end
	end

	local targetUsers = { 301, 302, 303 }
	local banReasons = { "spam", "exploit", "grief" }
	local persistRoles = { "vip", "mod", "admin" }
	local convergeOpts = { timeout = 30, step = 2 }

	local function projectNode(node: any)
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

	local function cloneRevoked(revoked: { [string]: { [string]: boolean } }): { [string]: { [string]: boolean } }
		local out: { [string]: { [string]: boolean } } = {}
		for uid, roles in revoked do
			if next(roles) ~= nil then
				out[uid] = table.clone(roles)
			end
		end
		return out
	end

	local function ensureUp(world: any, sys: any, idx: number)
		local node = sys.nodes[idx]
		if node == nil or node.server.state ~= "up" or #node.server.closers == 0 then
			local savedFaults = world.faults
			world.faults = table.clone(world.faults)
			world.faults.crash = 0
			world.faults.stale = 0
			if node == nil or node.server.state ~= "up" then
				node = bootServer(world, "_K_ModelSync", idx)
				sys.nodes[idx] = node
				if idx == 1 then
					sys.n1 = node
				elseif idx == 2 then
					sys.n2 = node
				end
			end
			waitServerReady(world, node)
			world:run(5)
			world.faults = savedFaults
		end
		return node
	end

	local function deepEqual(a: any, b: any): boolean
		if a == b then
			return true
		end
		if type(a) ~= "table" or type(b) ~= "table" then
			return false
		end
		for k, v in a do
			if not deepEqual(v, b[k]) then
				return false
			end
		end
		for k in b do
			if a[k] == nil then
				return false
			end
		end
		return true
	end

	local function convergeCluster(world: any, project: (srv: any) -> any, opts: { timeout: number?, step: number? }?)
		local o = opts or {}
		local timeout = o.timeout or 30
		local stepDt = o.step or 1
		world:heal()
		for _, gate in table.clone(world.gates) :: { [string]: any } do
			gate:release()
		end
		table.clear(world.scripted)

		local savedFaults = world.faults
		local zeroFaults = table.clone(world.faults)
		for k, v in zeroFaults do
			if type(v) == "number" then
				zeroFaults[k] = 0
			end
		end
		zeroFaults.remoteLatencyRange = nil
		zeroFaults.budget = nil
		world.faults = zeroFaults

		local function drainQueues()
			world.scheduler:drain()
			world.backing.messaging.drain()
			world.scheduler:drain()
		end

		local function queuesIdle(): boolean
			return (world.pendingCloud or 0) == 0
				and (world.pendingRemotes or 0) == 0
				and #world.backing.messaging.queue == 0
		end

		local function allEqual(): boolean
			local ref: any, hasRef = nil, false
			for _, srv in world.servers do
				if srv.state == "up" then
					local cur = project(srv)
					if not hasRef then
						ref, hasRef = cur, true
					elseif not deepEqual(ref, cur) then
						return false
					end
				end
			end
			return true
		end

		local converged = false
		local ok, err = pcall(function()
			local elapsed = 0
			while elapsed + 1e-9 < timeout do
				drainQueues()
				if queuesIdle() and allEqual() then
					converged = true
					return
				end
				local dt = math.min(stepDt, timeout - elapsed)
				world:step(dt)
				elapsed += dt
			end
			drainQueues()
			converged = queuesIdle() and allEqual()
		end)

		world.faults = savedFaults
		if not ok then
			error(err, 0)
		end
		world:assertNoErrors("convergeCluster")
		if not converged then
			error(`convergeCluster: did not converge within {timeout}s\n{world:summary()}`, 0)
		end
	end

	local function settleCluster(world: any, sys: any, applyFn: ((node: any) -> ())?, nodeIdx: number?)
		world:run(8)
		local savedFaults = world.faults
		world.faults = table.clone(world.faults)
		world.faults.crash = 0
		world.faults.stale = 0
		if nodeIdx ~= nil and applyFn ~= nil and sys.nodes[nodeIdx].server.state ~= "up" then
			local rebooted = ensureUp(world, sys, nodeIdx)
			rebooted.server:spawn(function()
				applyFn(rebooted)
			end)
			world:run(8)
		end
		ensureUp(world, sys, 1)
		ensureUp(world, sys, 2)
		world.faults = savedFaults
		convergeCluster(world, function(srv: any)
			local node = if srv == sys.n1.server then sys.n1 else sys.n2
			return projectNode(node)
		end, convergeOpts)
	end

	local bfsBanArgs = {
		{ nodeIdx = 1, userId = 301, reason = "spam" },
		{ nodeIdx = 2, userId = 302, reason = "exploit" },
	}
	local bfsUnbanArgs = {
		{ nodeIdx = 1, userId = 301 },
		{ nodeIdx = 2, userId = 302 },
	}
	local bfsGrantArgs = {
		{ nodeIdx = 1, userId = 301, role = "vip" },
		{ nodeIdx = 2, userId = 302, role = "mod" },
	}
	local bfsRevokeArgs = {
		{ nodeIdx = 1, userId = 301, role = "vip" },
		{ nodeIdx = 2, userId = 302, role = "mod" },
	}
	local bfsSettingArgs = {
		{ nodeIdx = 1, rank = 1 },
		{ nodeIdx = 2, rank = 2 },
	}
	local bfsBurstArgs = {
		{ seq = 1, targetId = 301 },
	}
	local bfsRestartArgs = { {} }

	local function attachFaultRemotes(world: any, sys: any)
		local node = ensureUp(world, sys, 1)
		if rawget(node, "_faultRemotesReady") then
			return node
		end
		rawset(node, "_faultRemotesReady", true)
		local rs = node.h.env.game:GetService("ReplicatedStorage")
		local guestRemote = node.h.env.Instance.new("RemoteEvent")
		guestRemote.Name = "GuestAttemptPrivilege"
		guestRemote.Parent = rs
		guestRemote.OnServerEvent:Connect(function(player: any, _targetId: any, _roleOrReason: any)
			if player and player.UserId == 202 then
				return
			end
			error(`Unexpected caller for GuestAttemptPrivilege: {player and player.UserId}`)
		end)
		local hbRemote = node.h.env.Instance.new("RemoteEvent")
		hbRemote.Name = "AdminHeartbeat"
		hbRemote.Parent = rs
		hbRemote.OnServerEvent:Connect(function(player: any, seq: any)
			if player and player.UserId == 101 and type(seq) == "number" then
				rawset(world, "_lastAdminHeartbeat", math.max(rawget(world, "_lastAdminHeartbeat") or 0, seq))
			end
		end)
		local c202 = node.server:client(202, "Guest202")
		local c101 = node.server:client(101, "Admin101")
		local env202 = c202:env({ isClient = true })
		local env101 = c101:env({ isClient = true })
		world:run(0.2)
		rawset(
			node,
			"_guestClientRemote",
			env202.game:GetService("ReplicatedStorage"):FindFirstChild("GuestAttemptPrivilege")
		)
		rawset(node, "_adminClientRemote", env101.game:GetService("ReplicatedStorage"):FindFirstChild("AdminHeartbeat"))
		return node
	end

	local KAdminDataSpec = sert.sim.spec({
		name = "KAdminDistributedData",
		world = {
			autoRestart = false,
			faults = {
				profile = "vopr",
				drop = 0,
				remoteDropRate = 0.15,
				remoteReorderRate = 0.2,
				remoteDuplicateRate = 0.2,
			},
		},
		init = function()
			return {
				bans = {},
				roles = {},
				dashboardRank = 0,
				unbanned = {},
				revoked = {},
			}
		end,
		setup = function(world)
			local sys: any = { n1 = nil, n2 = nil, nodes = {}, unbanned = {}, revoked = {} }
			ensureUp(world, sys, 1)
			ensureUp(world, sys, 2)
			world:run(20)
			ensureUp(world, sys, 1)
			ensureUp(world, sys, 2)
			attachFaultRemotes(world, sys)
			return sys
		end,
		converge = function(_st, sys, world)
			settleCluster(world, sys)
		end,
		project = function(sys)
			local projected = projectNode(sys.n1)
			return {
				bans = projected.bans,
				roles = projected.roles,
				dashboardRank = projected.dashboardRank,
				unbanned = table.clone(sys.unbanned),
				revoked = cloneRevoked(sys.revoked),
			}
		end,
		commands = {
			BanUser = {
				args = bfsBanArgs,
				gen = function(_st, g)
					return {
						nodeIdx = g:int(1, 2),
						userId = g:pick(targetUsers),
						reason = g:pick(banReasons),
					}
				end,
				pre = function(_st, args)
					return args ~= nil and (args.nodeIdx == 1 or args.nodeIdx == 2) and args.userId ~= nil
				end,
				run = function(sys, args, world)
					local key = tostring(args.userId)
					sys.unbanned[key] = nil
					local function apply(n: any)
						n.Auth.banUsers({ args.userId }, args.reason, -1, nil, true)
					end
					local node = ensureUp(world, sys, args.nodeIdx)
					node.server:spawn(function()
						apply(node)
					end)
					settleCluster(world, sys, apply, args.nodeIdx)
				end,
				next = function(st, args)
					local key = tostring(args.userId)
					st.bans[key] = args.reason
					st.unbanned[key] = nil
				end,
			},
			UnbanUser = {
				args = bfsUnbanArgs,
				gen = function(_st, g)
					return {
						nodeIdx = g:int(1, 2),
						userId = g:pick(targetUsers),
					}
				end,
				pre = function(_st, args)
					return args ~= nil and (args.nodeIdx == 1 or args.nodeIdx == 2) and args.userId ~= nil
				end,
				run = function(sys, args, world)
					local key = tostring(args.userId)
					sys.unbanned[key] = true
					local function apply(n: any)
						n.Auth.unbanUsers({ args.userId }, nil, true)
					end
					local node = ensureUp(world, sys, args.nodeIdx)
					node.server:spawn(function()
						apply(node)
					end)
					settleCluster(world, sys, apply, args.nodeIdx)
				end,
				next = function(st, args)
					local key = tostring(args.userId)
					st.bans[key] = nil
					st.unbanned[key] = true
				end,
			},
			GrantPersistRole = {
				args = bfsGrantArgs,
				gen = function(_st, g)
					return {
						nodeIdx = g:int(1, 2),
						userId = g:pick(targetUsers),
						role = g:pick(persistRoles),
					}
				end,
				pre = function(_st, args)
					return args ~= nil and (args.nodeIdx == 1 or args.nodeIdx == 2) and args.role ~= nil
				end,
				run = function(sys, args, world)
					local key = tostring(args.userId)
					if sys.revoked[key] ~= nil then
						sys.revoked[key][args.role] = nil
						if next(sys.revoked[key]) == nil then
							sys.revoked[key] = nil
						end
					end
					local function apply(n: any)
						if not n.Auth.userRoleAdd(args.userId, args.role, true) then
							local member = n.Data.members[key]
							if member ~= nil and #member.persist > 0 then
								n.Data.Sync.members[key] = { member.name or `User{args.userId}`, member.persist }
							end
						end
					end
					local node = ensureUp(world, sys, args.nodeIdx)
					node.server:spawn(function()
						apply(node)
					end)
					settleCluster(world, sys, apply, args.nodeIdx)
				end,
				next = function(st, args)
					local key = tostring(args.userId)
					st.roles[key] = st.roles[key] or {}
					st.roles[key][args.role] = true
					if st.revoked[key] ~= nil then
						st.revoked[key][args.role] = nil
						if next(st.revoked[key]) == nil then
							st.revoked[key] = nil
						end
					end
				end,
			},
			RevokePersistRole = {
				args = bfsRevokeArgs,
				gen = function(_st, g)
					return {
						nodeIdx = g:int(1, 2),
						userId = g:pick(targetUsers),
						role = g:pick(persistRoles),
					}
				end,
				pre = function(_st, args)
					return args ~= nil and (args.nodeIdx == 1 or args.nodeIdx == 2) and args.role ~= nil
				end,
				run = function(sys, args, world)
					local key = tostring(args.userId)
					sys.revoked[key] = sys.revoked[key] or {}
					sys.revoked[key][args.role] = true
					local function apply(n: any)
						if not n.Auth.userRoleRemove(args.userId, args.role) then
							local member = n.Data.members[key]
							if member == nil or #member.persist == 0 then
								n.Data.Sync.members[key] = n.Data.REMOVE
							else
								n.Data.Sync.members[key] = { member.name or `User{args.userId}`, member.persist }
							end
						end
					end
					local node = ensureUp(world, sys, args.nodeIdx)
					node.server:spawn(function()
						apply(node)
					end)
					settleCluster(world, sys, apply, args.nodeIdx)
				end,
				next = function(st, args)
					local key = tostring(args.userId)
					if st.roles[key] ~= nil then
						st.roles[key][args.role] = nil
						if next(st.roles[key]) == nil then
							st.roles[key] = nil
						end
					end
					st.revoked[key] = st.revoked[key] or {}
					st.revoked[key][args.role] = true
				end,
			},
			UpdateSetting = {
				args = bfsSettingArgs,
				gen = function(_st, g)
					return {
						nodeIdx = g:int(1, 2),
						rank = g:int(0, 3),
					}
				end,
				pre = function(_st, args)
					return args ~= nil and args.rank >= 0 and args.rank <= 3
				end,
				run = function(sys, args, world)
					local function apply(n: any)
						n.Data.savedSettings.dashboardRank = args.rank
						n.Data.Sync.settings.dashboardRank = args.rank
					end
					local node = ensureUp(world, sys, args.nodeIdx)
					apply(node)
					settleCluster(world, sys, apply, args.nodeIdx)
				end,
				next = function(st, args)
					st.dashboardRank = args.rank
				end,
			},
			FaultyRemoteBurst = {
				args = bfsBurstArgs,
				gen = function(_st, g)
					return {
						seq = g:int(1, 50),
						targetId = g:pick(targetUsers),
					}
				end,
				pre = function(_st, args)
					return args ~= nil and type(args.seq) == "number"
				end,
				run = function(sys, args, world)
					ensureUp(world, sys, 1)
					ensureUp(world, sys, 2)
					local n1 = attachFaultRemotes(world, sys)
					local guestRem = rawget(n1, "_guestClientRemote")
					local adminRem = rawget(n1, "_adminClientRemote")
					if guestRem then
						guestRem:FireServer(args.targetId, "creator")
					end
					if adminRem then
						adminRem:FireServer(args.seq)
					end
					world:run(2)
					settleCluster(world, sys)
				end,
				next = function(_st) end,
			},
			RestartNode2 = {
				args = bfsRestartArgs,
				gen = function()
					return {}
				end,
				pre = function()
					return true
				end,
				run = function(sys, _, world)
					ensureUp(world, sys, 1)
					if sys.n2 ~= nil and sys.n2.server.state == "up" then
						sys.n2.server:shutdown()
					end
					world:run(6)
					sys.n2 = bootServer(world, "_K_ModelSync", 2)
					sys.nodes[2] = sys.n2
					ensureUp(world, sys, 2)
					settleCluster(world, sys)
				end,
				next = function(_st) end,
			},
		},
		invariants = {
			noUnbannedUserStillBanned = function(st)
				for uid in st.unbanned do
					if st.bans[uid] ~= nil then
						return false
					end
				end
				return true
			end,
			noRevokedRoleStillPresent = function(st)
				for uid, roles in st.revoked do
					local active = st.roles[uid]
					if active ~= nil then
						for role in roles do
							if active[role] then
								return false
							end
						end
					end
				end
				return true
			end,
			validDashboardRank = function(st)
				return type(st.dashboardRank) == "number" and st.dashboardRank >= 0 and st.dashboardRank <= 3
			end,
			rolesNonEmpty = function(st)
				for _, roleSet in st.roles do
					if next(roleSet) == nil then
						return false
					end
				end
				return true
			end,
			nodesConverged = function(st, sys)
				if sys == nil then
					return true
				end
				local p1 = projectNode(sys.n1)
				local p2 = projectNode(sys.n2)
				sert.eq(p1, p2)
				sert.eq(p1, {
					bans = st.bans,
					roles = st.roles,
					dashboardRank = st.dashboardRank,
				})
				return true
			end,
		},
	})

	test("member syncs from other servers keep the unrestricted flags of session roles", function()
		local world = sert.sim.new({ backing = true })
		local n1 = bootServer(world, "_K_UnrestrictedSync")
		local n2 = bootServer(world, "_K_UnrestrictedSync")
		world:run(6)

		local function sync(fn: () -> ())
			n2.server:spawn(fn)
			world:run(7)
			world.backing.messaging.drain()
			world:run(1)
		end

		-- a non-developer gave 301 Moderator for this session on server 1
		n1.server:spawn(function()
			n1.Auth.userRoleAdd(301, "mod", false, true)
		end)
		world:run(0.1)
		sert.eq(n1.Auth.hasRestrictedRole(301), false)

		-- a developer on server 2 saves VIP for 301: server 1 keeps the session Moderator unrestricted
		sync(function()
			n2.Auth.userRoleAdd(301, "vip", true)
		end)
		local member = n1.Data.members["301"]
		sert.eq(member.roles, { "mod", "vip" })
		sert.eq(member.unrestricted and member.unrestricted.mod, true)
		sert.eq(n1.Auth.hasRestrictedRole(301), false)

		-- once a developer saves the Moderator role itself, it is a developer's grant everywhere
		sync(function()
			n2.Auth.userRoleAdd(301, "mod", true)
		end)
		member = n1.Data.members["301"]
		sert.eq(member.persist, { "mod", "vip" })
		sert.eq(member.unrestricted and member.unrestricted.mod, nil)
		sert.eq(n1.Auth.hasRestrictedRole(301), true)
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
			sert.eq(n1.Data.Sync.members["902"], nil)
			sert.eq(n1.Data.members["902"].persist, { "admin" })
			sert.eq(n1.Data.bans["903"][2], "fresh local ban")

			-- Inject an older cross-server sync item into the MemoryStore hashmap and replay via MessagingService
			local ms = n1.h.env.game:GetService("MemoryStoreService")
			local hm = ms:GetHashMap("_KData")
			for i = 1, 16 do
				hm:SetAsync("stale_sync_1_" .. i, {
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
			world.backing.messaging.drain()
			world:run(1)

			-- n1's newer saved (901) and unsaved (902, 903) changes must remain intact
			sert.eq(n1.Data.bans["901"] ~= nil, true)
			sert.eq(n1.Data.bans["901"][2], "initial ban")
			sert.eq(n1.Data.members["902"].persist, { "admin" })
			sert.eq(n1.Data.bans["903"] ~= nil, true)
			sert.eq(n1.Data.bans["903"][2], "fresh local ban")

			-- Shutdown n1 so BindToClose flushes SAVE to DataStore, then verify a fresh server loads n1's local changes
			n1.server:shutdown()
			world:run(6)
			local n3 = bootServer(world, "_K_SaveThrottleGuard")
			world:run(6)
			sert.eq(n3.Data.members["902"].persist, { "admin" })
			sert.eq(n3.Data.bans["903"][2], "fresh local ban")
			n2.server:shutdown()
			n3.server:shutdown()
		end
	)

	test(
		"cross-server sync survives late MemoryStore SetAsync, single-partition eviction/stale reads, clock drift, and UpdateAsync retransform",
		function()
			local world = sert.sim.new({ backing = true })
			local n1 = bootServer(world, "_K_VoprHazards")
			local n2 = bootServer(world, "_K_VoprHazards")
			world:run(6)

			-- 1. Positive clock drift (+30s) on n1 followed by negative clock drift (-30s) on n2:
			-- causal updates (ban on n1 -> unban on n2) must still apply despite n2's wall clock being 60s behind n1
			n1.server:drift(30)
			n1.server:spawn(function()
				n1.Auth.banUsers({ 401 }, "drifted ban", -1, nil, true)
				n1.Auth.userRoleAdd(402, "admin", true)
			end)
			world:run(2)
			world.backing.messaging.drain()
			world:run(1)
			sert.eq(n2.Data.bans["401"] ~= nil, true)
			sert.eq(n2.Data.members["402"] ~= nil, true)

			-- 2. Inject late MemoryStore SetAsync, single-partition stale read, and -30s drift on n2 when unbanning 401 and revoking 402
			n2.server:drift(-30)
			world:fail("MemoryStoreService", "SetAsync", "late")
			world:fail("MemoryStoreService", "GetAsync", "stale")
			world:fail("DataStoreService", "UpdateAsync", "retransform")
			n2.server:spawn(function()
				n2.Auth.unbanUsers({ 401 }, nil, true)
				n2.Auth.userRoleRemove(402, "admin")
			end)
			world:run(8)
			world.backing.messaging.drain()
			world:run(2)

			sert.eq(n1.Data.bans["401"], nil)
			sert.eq(n2.Data.bans["401"], nil)
			sert.eq(n1.Data.members["402"], nil)
			sert.eq(n2.Data.members["402"], nil)
			n1.server:shutdown()
			n2.server:shutdown()
		end
	)

	test(
		"World remote packet drops, duplicates, and reorders with concurrent cross-server ban/rank/settings updates converge without privilege escalation",
		function()
			local world = sert.sim.new({
				seed = 424242,
				mode = "random",
				backing = true,
				faults = "none",
			})

			local n1 = bootServer(world, "_K_RemoteFaultSync", 1)
			local n2 = bootServer(world, "_K_RemoteFaultSync", 2)
			waitServerReady(world, n1)
			waitServerReady(world, n2)
			world:run(6)

			local adminPackets = 0
			local guestBlocked = 0

			-- Register server RemoteEvent handlers on n1 and n2
			local function attachAdminMutation(node: any)
				local rs = node.h.env.game:GetService("ReplicatedStorage")
				local rem = node.h.env.Instance.new("RemoteEvent")
				rem.Name = "AdminMutation"
				rem.Parent = rs
				rem.OnServerEvent:Connect(function(player: any, op: any, userId: any, val: any)
					if not player or player.UserId ~= 101 then
						guestBlocked += 1
						return
					end
					adminPackets += 1
					node.server:spawn(function()
						if op == "ban" then
							node.Auth.banUsers({ userId }, tostring(val), -1, nil, true)
						elseif op == "unban" then
							node.Auth.unbanUsers({ userId }, nil, true)
						elseif op == "role" then
							if not node.Auth.userRoleAdd(userId, tostring(val), true) then
								local member = node.Data.members[tostring(userId)]
								if member and #member.persist > 0 then
									node.Data.Sync.members[tostring(userId)] =
										{ member.name or `User{userId}`, member.persist }
								end
							end
						elseif op == "settings" then
							node.Data.savedSettings.dashboardRank = tonumber(val) or 1
							node.Data.Sync.settings.dashboardRank = tonumber(val) or 1
						end
					end)
				end)
				local gCli = node.server:client(202, "Guest202")
				local aCli = node.server:client(101, "Admin101")
				local gEnv = gCli:env({ isClient = true })
				local aEnv = aCli:env({ isClient = true })
				world:run(0.2)
				return {
					guest = gEnv.game:GetService("ReplicatedStorage"):FindFirstChild("AdminMutation"),
					admin = aEnv.game:GetService("ReplicatedStorage"):FindFirstChild("AdminMutation"),
				}
			end

			local r1 = attachAdminMutation(n1)
			local r2 = attachAdminMutation(n2)

			world.faults.remoteDropRate = 0.25
			world.faults.remoteReorderRate = 0.35
			world.faults.remoteDuplicateRate = 0.3
			world.faults.remoteLatencyRange = { 1, 4 }
			world.faults.reorder = 0.2
			world.faults.duplicate = 0.2

			-- Fire a burst of hostile guest packets (peer 202) and admin packets (peer 101) under drop/reorder/duplicate faults
			for i = 1, 20 do
				local guestTarget = if (i % 2) == 0 then r1.guest else r2.guest
				guestTarget:FireServer("role", 202, "creator")
				guestTarget:FireServer("ban", 101, "hostile")
				r1.admin:FireServer("ban", 601, "griefing")
				r2.admin:FireServer("role", 602, "mod")
				r1.admin:FireServer("settings", 0, 2)
			end

			world:run(20)

			-- Clear faults and issue deterministic final admin state across n1 and n2
			for k, v in world.faults do
				if type(v) == "number" then
					world.faults[k] = 0
				end
			end
			world.faults.remoteLatencyRange = nil

			r1.admin:FireServer("ban", 601, "final_ban")
			r2.admin:FireServer("role", 602, "admin")
			r1.admin:FireServer("settings", 0, 2)
			world:run(1)
			convergeCluster(world, function(srv: any)
				local node = if srv == n1.server then n1 else n2
				return projectNode(node)
			end, convergeOpts)

			sert.eq(adminPackets > 0, true)
			sert.eq(guestBlocked > 0, true)
			-- Guest 202 never gained any role or banned admin 101
			sert.eq(n1.Auth.getRank(202), 0)
			sert.eq(n2.Auth.getRank(202), 0)
			sert.eq(n1.Data.bans["101"], nil)
			sert.eq(n2.Data.bans["101"], nil)
			-- Both servers converged on the final ban, role, and settings updates
			sert.eq(n1.Data.bans["601"] ~= nil, true)
			sert.eq(n2.Data.bans["601"] ~= nil, true)
			sert.eq(n1.Auth.hasRole(602, "admin"), true)
			sert.eq(n2.Auth.hasRole(602, "admin"), true)
			sert.eq(n1.Data.savedSettings.dashboardRank, 2)
			sert.eq(n2.Data.savedSettings.dashboardRank, 2)

			n1.server:shutdown()
			n2.server:shutdown()
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
			sert.eq(#Data1.logs, 10)

			-- Verify ReservedServers 2-tuple was converted to 3-tuple { code, accessCode, placeId }
			sert.eq(Data1.reservedServers.legacyLobby, { "legacyLobby", "access_code_123", 98765 })

			-- Verify Main members & settings deserialization
			sert.eq(Data1.members["202"] ~= nil, true)
			sert.eq(Data1.members["202"].persist, { "mod" })
			sert.eq(Data1.members["203"].roles, { "mod" })
			sert.eq(Data1.members["204"], nil) -- was skipped due to pending Sync.members["204"]
			sert.eq(Data1.members["205"], nil) -- all invalid roles filtered out (#roles == 0 branch)
			sert.eq(h1.env.globals.typeof(Data1.savedSettings.themePrimary), "Color3")
			sert.eq(h1.env.globals.typeof(Data1.savedSettings.themeCornerRadius), "UDim")
			sert.eq(Data1.savedSettings.sampleEnum, h1.env.globals.Enum.Font.Roboto)

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
			sert.eq(s2.Data.members["202"] ~= nil, true)
			sert.eq(s2.Data.bans["5001"] ~= nil, true)

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
			world.backing.messaging.drain()
			world:run(1)
			sert.eq(s2.Data.members["202"], nil)
			sert.eq(s2.Data.bans["5001"], nil)

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
			sert.eq(sawLimitWarn, true)

			-- Also trigger >512KB single-batch saveLogs trimming (lines 156-163)
			local newest
			for i = 1, 36 do
				newest = { bigLogText .. i, string.char(1), now + 100 + i, 101, "AdminOnline" }
				table.insert(Data1.Sync.logs, newest)
			end
			world:run(65)
			-- the log rows are also synced as JSON arrays, measuring them for the save mustn't add keys
			sert.eq(newest.size, nil)
			-- the trimmed save keeps the newest log and stays under the DataStore limit
			local savedNewest = false
			for i = 1, 4 do
				local shard = rawStore:GetAsync("Logs_" .. i)
				if type(shard) == "buffer" then
					sert.eq(buffer.len(shard) <= 512 * 1024, true)
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
			sert.eq(savedNewest, true)

			-- Test Data.initialize when SEPARATE_DATASTORE = true (erases Logs_1..4, lines 627-629)
			-- and when Store.loadStore fails (canSave = false, lines 561-565)
			local hPriv = Harness.newEnv({ isStudio = false })
			local privHashMaps = 0
			local emptyPrivMap = {
				ListItemsAsync = function()
					return {
						GetCurrentPage = function()
							return {}
						end,
						IsFinished = true,
					}
				end,
			}
			hPriv.env.game:GetService("MemoryStoreService").GetHashMap = function(_self: any, name: string)
				if name ~= "__KA_Charts" then
					privHashMaps += 1
				end
				return emptyPrivMap
			end
			hPriv.env.game:GetService("MessagingService").SubscribeAsync = function() end
			local DataPriv = hPriv:requireData()
			DataPriv.SEPARATE_DATASTORE = true
			DataPriv.initialize("_K_PrivScope")
			hPriv.env:step(0.1)
			sert.eq(DataPriv.canSave, true)
			sert.eq(privHashMaps, 0)

			local hFail = Harness.newEnv({ isStudio = true })
			local dssFail = hFail.env.game:GetService("DataStoreService")
			dssFail.GetDataStore = function()
				error("502: You must publish this place to the web to access DataStore.")
			end
			local DataFail = hFail:requireData()
			DataFail.initialize("_K_FailScope")
			sert.eq(DataFail.canSave, false)
			sert.eq(type(DataFail.saveError), "string")

			-- Store.loadStore clears Store.dataStore when Studio __TEST check fails so a retry isn't short-circuited
			local hStudioStore = Harness.newEnv({ isStudio = true })
			local studioTestFail = true
			local origStudioGetDataStore = hStudioStore.env.game:GetService("DataStoreService").GetDataStore
			hStudioStore.env.game:GetService("DataStoreService").GetDataStore = function(
				self: any,
				name: string,
				sc: string
			)
				local ds = origStudioGetDataStore(self, name, sc)
				local origGet = ds.GetAsync
				ds.GetAsync = function(s: any, key: string, ...: any)
					if key == "__TEST" and studioTestFail then
						error("502: API Services rejected request with error. Studio access to APIs is not allowed.")
					end
					return origGet(s, key, ...)
				end
				return ds
			end
			local StudioStore = hStudioStore.env:require(hStudioStore.Shared:WaitForChild("Data"):WaitForChild("Store"))
			local canSave1 = StudioStore.loadStore("_KData", "_K_StudioRetry")
			sert.eq(canSave1, false)
			sert.eq(StudioStore.dataStore, nil)
			studioTestFail = false
			local canSave2 = StudioStore.loadStore("_KData", "_K_StudioRetry")
			sert.eq(canSave2, true)
			sert.eq(StudioStore.dataStore ~= nil, true)
		end
	)

	test(
		"never calls HashMap:ListItemsAsync, syncs <=900B deltas inline with 0 receiver MemoryStore reads, and only persists from origin server",
		function()
			local world = sert.sim.new({ backing = true })
			local n1 = bootServer(world, "_K_ScaleInline")
			local n2 = bootServer(world, "_K_ScaleInline")
			waitServerReady(world, n1)
			waitServerReady(world, n2)
			world:run(12)

			sert.eq(world.backing.memorystore.calls.ListItemsAsync or 0, 0)
			local beforeGets = world.backing.memorystore.calls.GetAsync or 0
			local n2UpdateAsyncCalls = 0

			local origUpdate = n2.Data.Store.updateAsync
			n2.Data.Store.updateAsync = function(...: any)
				n2UpdateAsyncCalls += 1
				return origUpdate(...)
			end

			-- Small delta (<= 900B): synced inline via MessagingService with 0 receiver MemoryStore GetAsync calls
			n1.server:spawn(function()
				n1.Auth.banUsers({ 8801 }, "small inline ban", -1, nil, true)
			end)
			world:run(7)
			world.backing.messaging.drain()
			world:run(2)

			sert.eq(n2.Data.bans["8801"] ~= nil, true)
			sert.eq(n2.Data.bans["8801"][2], "small inline ban")
			sert.eq(world.backing.memorystore.calls.ListItemsAsync or 0, 0)
			sert.eq(world.backing.memorystore.calls.GetAsync or 0, beforeGets)
			-- Receiver server n2 must not re-queue received syncs into its own DataStore SAVE queue
			world:run(10)
			sert.eq(n2UpdateAsyncCalls, 0)

			-- Large delta (> 900B): spills to sharded MemoryStore keys in _KData without calling ListItemsAsync
			local longReason = string.rep("X", 1200)
			n1.server:spawn(function()
				n1.Auth.banUsers({ 8802 }, longReason, -1, nil, true)
			end)
			world:run(7)
			world.backing.messaging.drain()
			world:run(2)

			sert.eq(n2.Data.bans["8802"] ~= nil, true)
			sert.eq(n2.Data.bans["8802"][2], longReason)
			sert.eq(world.backing.memorystore.calls.ListItemsAsync or 0, 0)
			sert.eq((world.backing.memorystore.calls.GetAsync or 0) > beforeGets, true)
			sert.eq(n2UpdateAsyncCalls, 0)
		end
	)

	test(
		"lazy-loads Logs_1..4 and Servers on demand, skips __TEST GetAsync outside Studio, and serves startup Main/Bans from sharded MemoryStore cache",
		function()
			local world = sert.sim.new({ backing = true })
			local s1 = world:server({ skew = 0 })
			local h1 = Harness.newPeerEnv(s1, { isStudio = false })
			local Data1 = h1:requireData()
			local Auth1 = h1:requireAuth()
			Harness.seedRoles(Data1)

			local scope = "_K_LazyAndCache"
			local rawStore = h1.env.game:GetService("DataStoreService"):GetDataStore("_KData", scope)
			rawStore:SetAsync("Main", { { ["303"] = { "CachedMod", { "mod" } } }, { prefix = ":" } })
			rawStore:SetAsync("Bans", { ["404"] = { "CachedBan", "reason", -1, 1 } })
			rawStore:SetAsync("Servers", { lobby1 = { "lobby1", "code_abc", 12345 } })

			local getKeys: { [string]: number } = {}
			local origGetAsync = Data1.Store.getAsync
			Data1.Store.getAsync = function(key: string, ...: any)
				getKeys[key] = (getKeys[key] or 0) + 1
				return origGetAsync(key, ...)
			end

			s1:spawn(function()
				Data1.initialize(scope)
			end)
			world:run(3)

			-- Without an online admin, Logs_1..4 and Servers are not fetched on startup, and __TEST is skipped outside Studio
			sert.eq(getKeys["__TEST"], nil)
			sert.eq(getKeys["Logs_1"], nil)
			sert.eq(getKeys["Servers"], nil)
			sert.eq(Data1.logsLoaded, false)
			sert.eq(Data1.serversLoaded, false)
			sert.eq(Data1.members["303"] ~= nil, true)
			sert.eq(Data1.bans["404"] ~= nil, true)

			-- Calling ensureLogsLoaded / ensureServersLoaded loads them once and is idempotent
			s1:spawn(function()
				Data1.ensureLogsLoaded()
				Data1.ensureLogsLoaded()
				Data1.ensureServersLoaded()
				Data1.ensureServersLoaded()
			end)
			world:run(2)
			sert.eq(Data1.logsLoaded, true)
			sert.eq(Data1.serversLoaded, true)
			sert.eq(getKeys["Logs_1"], 1)
			sert.eq(getKeys["Servers"], 1)
			sert.eq(Data1.reservedServers.lobby1 ~= nil, true)

			-- Populate all 16 shards of the previous 60s MemoryStore cache bucket (testing bucket - 1 rollover fallback)
			-- and verify a warm server startup reads 0 DataStore keys
			local hm = h1.env.game:GetService("MemoryStoreService"):GetHashMap("_KData")
			local bucket = math.floor(h1.env.workspace:GetServerTimeNow() / 60)
			local prevBucket = bucket - 1
			for shard = 1, 16 do
				hm:SetAsync(`Main_{prevBucket}_{shard}`, {
					hit = true,
					value = { { ["505"] = { "WarmCachedAdmin", { "admin" } } }, { prefix = "!" } },
					updatedTime = 100,
				}, 60)
				hm:SetAsync(`Bans_{bucket}_{shard}`, {
					hit = true,
					value = { ["606"] = { "WarmBan", "warm reason", -1, 1 } },
					updatedTime = 100,
				}, 60)
			end

			local s2 = world:server({ skew = 0 })
			local h2 = Harness.newPeerEnv(s2, { isStudio = false })
			local s2Subscribes = 0
			local origSub2 = h2.env.game:GetService("MessagingService").SubscribeAsync
			h2.env.game:GetService("MessagingService").SubscribeAsync = function(self: any, topic: string, ...: any)
				if topic == "_KData" then
					s2Subscribes += 1
				end
				return origSub2(self, topic, ...)
			end
			local Data2 = h2:requireData()
			Harness.seedRoles(Data2)
			Data2.subscribeTopic("pre_init_topic", function() end)
			sert.eq(s2Subscribes, 0) -- subscribeTopic before Data.initialize does not prematurely SubscribeAsync
			local s2StoreGets = 0
			local origGet2 = Data2.Store.getAsync
			Data2.Store.getAsync = function(key: string, ...: any)
				s2StoreGets += 1
				return origGet2(key, ...)
			end

			s2:spawn(function()
				Data2.initialize(scope)
			end)
			world:run(3)
			sert.eq(s2Subscribes, 1) -- exactly 1 _KData subscription after Data.initialize
			sert.eq(s2StoreGets, 0)
			sert.eq(Data2.members["505"] ~= nil, true)
			sert.eq(Data2.bans["606"] ~= nil, true)

			-- Verify invalidateCache clears both current and previous bucket shards, and TOPIC_HANDLERS isolate errors
			hm:SetAsync(`Bans_{prevBucket}_1`, { hit = true, value = {}, updatedTime = 99 }, 60)
			s1:spawn(function()
				Auth1.banUsers({ 909 }, "invalidate both buckets", -1, nil, true)
			end)
			world:run(8)
			sert.eq(hm:GetAsync(`Bans_{bucket}_1`), nil)
			sert.eq(hm:GetAsync(`Bans_{prevBucket}_1`), nil)

			-- Seed >28KB into Recent_1 and trigger an urgent update to verify trimRecentItemsToLimit evicts oldest entries
			local bigRecentEntry = { _time = 10, bans = { set = { ["1"] = { "Old", string.rep("R", 14000), -1, 1 } } } }
			local bigRecentEntry2 =
				{ _time = 20, bans = { set = { ["2"] = { "Old2", string.rep("R", 14000), -1, 1 } } } }
			hm:SetAsync("Recent_1", { old_a = bigRecentEntry, old_b = bigRecentEntry2 }, 60)
			s1:spawn(function()
				Auth1.banUsers({ 910 }, "recent trim test", -1, nil, true)
			end)
			world:run(8)
			local recentAfterTrim = hm:GetAsync("Recent_1")
			sert.eq(type(recentAfterTrim), "table")
			sert.eq(recentAfterTrim.old_a, nil)
			sert.eq(hm:GetAsync("Recent_8") ~= nil, true)

			local secondHandlerCalled = false
			local localDispatchCalls = 0
			Data1.subscribeTopic("isolated_test", function(packet)
				if packet.Data == "ping" then
					localDispatchCalls += 1
				end
			end)
			Data2.subscribeTopic("isolated_test", function()
				error("first topic handler boom")
			end)
			Data2.subscribeTopic("isolated_test", function(packet)
				if packet.Data == "ping" then
					secondHandlerCalled = true
				end
			end)
			s1:spawn(function()
				Data1.publishTopic("isolated_test", "ping")
			end)
			world:run(1)
			world.backing.messaging.drain()
			world:run(1)
			sert.eq(secondHandlerCalled, true)
			-- Origin server dispatches TOPIC_HANDLERS locally once and suppresses its own MessagingService echo
			sert.eq(localDispatchCalls, 1)

			-- Failed updateBans does not resurrect a ban key unset by a newer syncChanges during the in-flight UpdateAsync
			Data1.Sync.bans["7777"] = { "TempBan", "reason", -1, 1 }
			Data1.Sync.bans["7778"] = { "KeepBan", "reason", -1, 1 }
			local origStoreUpdate = Data1.Store.updateAsync
			local simulatedOutageHit = false
			Data1.Store.updateAsync = function(key: string, fn: any)
				if key == "Bans" and not simulatedOutageHit then
					simulatedOutageHit = true
					-- Deliver a remote unban delta for 7777 with a newer _time while UpdateAsync is in flight
					local newerTime = h1.env.DateTime.now().UnixTimestampMillis + 100000
					h1.env.game:GetService("MessagingService"):PublishAsync(
						"_KData",
						h1.env.game:GetService("HttpService"):JSONEncode({
							"remote_unban_7777",
							1,
							{ _time = newerTime, bans = { unset = { "7777" } } },
						})
					)
					world.backing.messaging.drain()
					h1.env.task.wait()
					return false, "simulated DataStore outage"
				end
				return origStoreUpdate(key, fn)
			end
			world:run(65)
			Data1.Store.updateAsync = origStoreUpdate
			sert.eq(simulatedOutageHit, true)
			-- Trigger a second urgent save so SAVE.bans flushes to DataStore
			Data1.Sync.bans["7779"] = { "TriggerFlush", "reason", -1, 1 }
			world:run(10)
			local savedBans = rawStore:GetAsync("Bans")
			sert.eq(savedBans["7777"], nil)
			sert.eq(savedBans["7778"] ~= nil, true)

			-- Verify local command logs persist to DataStore without broadcasting cross-server MessagingService packets,
			-- while global command logs broadcast to servers with a logs audience without mutating log tuples
			local adminPlr2 = h2.env:addPlayer(202, "AdminOnS2")
			adminPlr2:SetAttribute("_K_READY", true)
			local Auth2 = h2:requireAuth()
			Auth2.userRoleAdd(202, "superadmin")

			local localPublishes = 0
			local origPublish = h1.env.game:GetService("MessagingService").PublishAsync
			h1.env.game:GetService("MessagingService").PublishAsync = function(...: any)
				localPublishes += 1
				return origPublish(...)
			end
			Data1.settings.saveLogs = true
			Data1.settings.saveLogsForAllRoles = true
			local K1 = h1.env:require(h1.KA)
			s1:spawn(function()
				K1.log(";fly me", "COMMAND", 101)
			end)
			world:run(35)
			sert.eq(localPublishes, 0)

			s1:spawn(function()
				K1.log(";global fly all", "COMMAND", 101, nil, nil, true)
			end)
			world:run(35)
			world.backing.messaging.drain()
			world:run(2)
			sert.eq(localPublishes > 0, true)
			local foundGlobalLogOnS2 = false
			for _, logEntry in Data2.logs do
				if logEntry[1] == ";global fly all" then
					foundGlobalLogOnS2 = true
					sert.eq(rawget(logEntry, "_global"), nil)
				end
			end
			sert.eq(foundGlobalLogOnS2, true)
		end
	)

	test("KAdmin distributed data spec satisfies negative and positive invariants", function()
		sert.sim.check(KAdminDataSpec, {
			bfs = true,
			vopr = false,
			maxStates = if rawget(_G, "__SERT_MUTANT") ~= nil then 30 else 200,
			maxDepth = 6,
		})
	end)

	sert.sim.vopr("KAdmin multi-server sync converges under VOPR hazards", KAdminDataSpec, {
		runs = if rawget(_G, "__SERT_MUTANT") ~= nil then 2 else 15,
		steps = 8,
	})

	test("sert.sim.explore verifies BindToClose shutdown flushes pending bans, roles, and logs to DataStore", function()
		sert.sim.explore({
			maxRuns = if rawget(_G, "__SERT_MUTANT") ~= nil then 2 else 12,
			faults = "none",
		}, function(world)
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
			world:run(31)

			-- Boot a fresh server 2 on the same scope and verify it loads the ban, persistent role, and log
			local n2 = bootServer(world, "_K_ShutdownFlush")
			waitServerReady(world, n2)
			n2.server:spawn(function()
				n2.Data.ensureLogsLoaded()
			end)
			for _ = 1, 100 do
				if n2.Data.logsLoaded then
					break
				end
				world:run(0.2)
			end

			sert.eq(n2.Data.bans["777"] ~= nil, true)
			sert.eq(n2.Data.bans["777"][3], -1)
			sert.eq(n2.Data.members["888"] ~= nil, true)
			sert.eq(table.find(n2.Data.members["888"].persist, "admin") ~= nil, true)
			local sawShutdownLog = false
			for _, entry in n2.Data.logs do
				if entry[1] == "shutdown_flushed_log" then
					sawShutdownLog = true
				end
			end
			sert.eq(sawShutdownLog, true)
		end)
	end)
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
			sert.eq(ok, true)
			sert.eq(#json <= LIMIT, true)
			-- processSync stamps _time on each chunk before SetAsync, which takes items up to 32 KB
			local stamped = table.clone(chunk)
			stamped._time = 1700000000000
			sert.eq(#HttpService:JSONEncode(stamped) <= 32 * 1000, true)
			for key, info in chunk do
				local into = merged[key] or {}
				merged[key] = into
				for action, data in info do
					if action == "insert" or action == "unset" then
						local count = 0
						for _ in data do
							count += 1
						end
						sert.eq(count > 0, true)
						sert.eq(count, #data)
						into[action] = into[action] or {}
						table.move(data, 1, #data, #into[action] + 1, into[action])
					else
						into[action] = into[action] or {}
						for k, v in data do
							sert.eq(into[action][k], nil)
							into[action][k] = v
						end
					end
				end
			end
		end
		sert.eq(merged, changes)
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
		sert.eq(checkChunks(changes) >= 3, true)
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
			sert.eq(#Http:JSONEncode(chunk) <= LIMIT, true)
		end
	end)

	do
		local chunkChanges: any
		local HttpService: any
		local function getChunkDeps()
			if not chunkChanges then
				local h = Harness.shared()
				chunkChanges = h.env:require(h.Shared:WaitForChild("Data"):WaitForChild("ChunkChanges"))
				HttpService = h.env.game:GetService("HttpService")
			end
			return chunkChanges, HttpService
		end

		sert.prop("Data.ChunkChanges multi-action (set, unset, insert)", function(g)
			local keyChars = "abcdef012345"
			local changes: { [string]: any } = {}
			for _, section in { "bans", "members", "settings" } do
				local set: { [string]: any } = {}
				for i = 1, g:int(1, 15) do
					set[`{section}_s_{i}_{g:string(keyChars, 1, 4)}`] = {
						g:string(keyChars, 1, g:int(10, 120)),
						g:int(-1, 100000),
					}
				end
				local unset = {}
				for i = 1, g:int(1, 30) do
					unset[i] = `{section}_u_{i}_{g:string(keyChars, 1, 4)}`
				end
				changes[section] = { set = set, unset = unset }
			end
			local logs = {}
			for i = 1, g:int(1, 20) do
				logs[i] = { g:string(keyChars, 1, g:int(10, 80)), string.char(g:int(0, 5)), 1700000000 + i }
			end
			changes.logs = { insert = logs }

			local fn, http = getChunkDeps()
			local pieces = fn(changes)
			sert.eq(#pieces >= 1, true)
			local merged: { [string]: any } = {}
			for _, piece in pieces do
				sert.eq(#http:JSONEncode(piece) <= LIMIT, true)
				for key, info in piece do
					local into = merged[key] or {}
					merged[key] = into
					for action, data in info do
						if action == "insert" or action == "unset" then
							into[action] = into[action] or {}
							table.move(data, 1, #data, #into[action] + 1, into[action])
						else
							into[action] = into[action] or {}
							for k, v in data do
								into[action][k] = v
							end
						end
					end
				end
			end
			sert.eq(merged, changes)
		end, { runs = 30 })

		-- Helper that chunks `a` and `b` via ChunkChanges and composes their state transitions (`set` and `unset`)
		local function composeChunkedDeltas(a: { [string]: any }, b: { [string]: any }): { [string]: any }
			local fn = getChunkDeps()
			local state: { [string]: { set: { [string]: any }, unset: { [string]: boolean } } } = {}
			local function applyChunks(delta: { [string]: any })
				if next(delta) == nil then
					return
				end
				for _, chunk in fn(delta) do
					for section, info in chunk do
						local sec = state[section]
						if not sec then
							sec = { set = {}, unset = {} }
							state[section] = sec
						end
						if info.unset then
							for _, k in info.unset do
								sec.set[k] = nil
								sec.unset[k] = true
							end
						end
						if info.set then
							for k, v in info.set do
								sec.unset[k] = nil
								sec.set[k] = v
							end
						end
					end
				end
			end
			applyChunks(a)
			applyChunks(b)

			local out: { [string]: any } = {}
			for section, sec in state do
				local unsetArr = {}
				for k in sec.unset do
					table.insert(unsetArr, k)
				end
				table.sort(unsetArr)
				local info: { [string]: any } = {}
				if next(sec.set) ~= nil then
					info.set = sec.set
				end
				if #unsetArr > 0 then
					info.unset = unsetArr
				end
				if next(info) ~= nil then
					out[section] = info
				end
			end
			return out
		end

		local batchSeq = 0
		sert.laws.algebra("Data.ChunkChanges disjoint-key delta algebra (idempotence & commutativity)", {
			gen = function(g)
				batchSeq += 1
				local ns = batchSeq
				local delta: { [string]: any } = {}
				for _, section in { "bans", "members", "settings" } do
					local set: { [string]: any } = {}
					local unset = {}
					for i = 1, g:int(1, 6) do
						local k = `{section}_{ns}_{i}`
						if g:bool() then
							set[k] = { `val_{ns}_{i}`, g:int(-1, 1000) }
						else
							table.insert(unset, k)
						end
					end
					table.sort(unset)
					local info: { [string]: any } = {}
					if next(set) ~= nil then
						info.set = set
					end
					if #unset > 0 then
						info.unset = unset
					end
					if next(info) ~= nil then
						delta[section] = info
					end
				end
				return delta
			end,
			op = composeChunkedDeltas,
			identity = {},
			associative = true,
			commutative = true,
			idempotent = true,
			eq = sert.equals,
		}, { runs = 40 })

		sert.laws.algebra("Data.ChunkChanges overlapping-key delta algebra (associativity & idempotence)", {
			gen = function(g)
				local delta: { [string]: any } = {}
				for _, section in { "bans", "members" } do
					local set: { [string]: any } = {}
					local unset = {}
					for i = 1, 6 do
						local choice = g:int(0, 2)
						local k = `shared_{i}`
						if choice == 1 then
							set[k] = { `v_{g:int(1, 4)}`, g:pick({ -1, 0, 60 }) }
						elseif choice == 2 then
							table.insert(unset, k)
						end
					end
					table.sort(unset)
					local info: { [string]: any } = {}
					if next(set) ~= nil then
						info.set = set
					end
					if #unset > 0 then
						info.unset = unset
					end
					if next(info) ~= nil then
						delta[section] = info
					end
				end
				return delta
			end,
			op = composeChunkedDeltas,
			identity = {},
			associative = true,
			commutative = false,
			idempotent = true,
			eq = sert.equals,
		}, { runs = 40 })
	end

	test(
		"Data.initialize BindToClose distinguishes closing vs non-closing errors and cross-server members.unset fires Hook.roleRemoved",
		function()
			-- 1. Non-closing BindToClose failure does NOT mark gameClosing = true
			do
				local h = Harness.newEnv({ isStudio = false })
				local gameMethods = rawget(h.env.game, "_methods")
				local origBind = gameMethods.BindToClose
				gameMethods.BindToClose = function()
					error("BindToClose is unavailable in this capability context")
				end
				local Data = h:requireData()
				Data.initialize("_K_BindNonClosing")
				h.env:step(0.1)
				sert.eq(Data.gameClosing, false)
				sert.eq(Data.Store.closing ~= true, true)
				gameMethods.BindToClose = origBind
			end

			-- 2. Closing BindToClose failure ("already closing") spawns onClose() and sets Data.gameClosing = true
			do
				local h = Harness.newEnv({ isStudio = false })
				local gameMethods = rawget(h.env.game, "_methods")
				local origBind = gameMethods.BindToClose
				gameMethods.BindToClose = function()
					error("Cannot BindToClose while game is closing")
				end
				local Data = h:requireData()
				Data.initialize("_K_BindAlreadyClosing")
				h.env:step(0.2)
				sert.eq(Data.gameClosing, true)
				sert.eq(Data.Store.closing, true)
				gameMethods.BindToClose = origBind
			end

			-- 3. Cross-server members.unset fires Hook.roleRemoved on remote servers and SYNC.settings keeps exact prefix list
			local function bootNode(world: any, scope: string)
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

			local world = sert.sim.new({ backing = true })
			local n1 = bootNode(world, "_K_UnsetRoleRemoved")
			local n2 = bootNode(world, "_K_UnsetRoleRemoved")
			world:run(6)

			n1.Data.settingsModuleData = { prefix = { ";", ":" } }
			n2.Data.settingsModuleData = { prefix = { ";", ":" } }

			local removedEvents = {}
			n2.h:requireShared("Hook").roleRemoved:Connect(function(uid, role)
				table.insert(removedEvents, { uid = uid, role = role })
			end)

			-- Give user 701 persisted "admin" on n1 and sync to n2
			n1.server:spawn(function()
				n1.Auth.userRoleAdd(701, "admin", true)
				n1.Data.savedSettings.prefix = { "!" }
				n1.Data.Sync.settings.prefix = { "!" }
			end)
			world:run(7)
			world.backing.messaging.drain()
			world:run(1)

			sert.eq(n2.Auth.hasRole(701, "admin"), true)
			-- Deterministic prefix sync without re-appending stale settingsModuleData.prefix { ";", ":" }
			sert.eq(n2.Data.savedSettings.prefix, { "!" })

			-- Now remove persisted "admin" from 701 on n1 (triggers Data.REMOVE -> members.unset) and sync to n2
			n1.server:spawn(function()
				n1.Auth.userRoleRemove(701, "admin")
			end)
			world:run(7)
			world.backing.messaging.drain()
			world:run(1)

			sert.eq(n2.Data.members["701"], nil)
			sert.eq(#removedEvents, 1)
			sert.eq(removedEvents[1].uid, 701)
			sert.eq(removedEvents[1].role, "admin")

			n1.server:shutdown()
			n2.server:shutdown()
		end
	)
end)

do
	return {}
end
