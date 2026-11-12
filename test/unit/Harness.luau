local sert = require("../sert")

local IN_ROBLOX = game ~= nil and type(game) == "userdata"
local STAGE: any = nil
if not IN_ROBLOX then
	local ok, loaded = pcall(require :: any, "@stage")
	if ok then
		STAGE = loaded
	end
end

local Harness = {
	globals = if IN_ROBLOX then getfenv() else sert.env.new({ strict = false, signalBehavior = "Immediate" }).globals,
}

export type UtilModule = typeof(require("../../src/Shared/Util"))
export type DataModule = typeof(require("../../src/Shared/Data"))
export type StringModule = typeof(require("../../src/Shared/Util/String"))
export type TimeModule = typeof(require("../../src/Shared/Util/Time"))
export type SignalModule = typeof(require("../../src/Shared/Util/Signal"))
export type TasksModule = typeof(require("../../src/Shared/Util/Tasks"))
export type FunctionModule = typeof(require("../../src/Shared/Util/Function"))
export type SuggestModule = typeof(require("../../src/Shared/Util/Suggest"))
export type SafePlayerAddedModule = typeof(require("../../src/Shared/Util/SafePlayerAdded"))
export type GenerateValidateModule = typeof(require("../../src/Shared/DefaultTypes/Player/generateValidate"))
export type UIModule = typeof(require("../../src/Client/UI"))
export type ThemeModule = typeof(require("../../src/Client/UI/Theme"))
export type BaseClassModule = typeof(require("../../src/Client/UI/Classes/BaseClass"))
export type NotifyModule = typeof(require("../../src/Client/Notify"))
export type ClackModule = typeof(require("../../src/Client/UI/Classes/Input/Clack"))
export type FontsModule = typeof(require("../../src/Client/UI/Fonts"))
export type LegacyThemeModule = typeof(require("../../src/Client/UI/Theme/Themes/Legacy"))
export type LightThemeModule = typeof(require("../../src/Client/UI/Theme/Themes/Light"))
export type InversePlayerTypeModule = typeof(require("../../src/Shared/DefaultTypes/Player/Types/Inverse"))
export type OthersPlayerTypeModule = typeof(require("../../src/Shared/DefaultTypes/Player/Types/Others"))
export type RandomPlayerTypeModule = typeof(require("../../src/Shared/DefaultTypes/Player/Types/Random"))
export type VectorTypeModule = typeof(require("../../src/Shared/DefaultTypes/Vector"))
export type RunContextModule = typeof(require("../../src/Shared/Util/RunContext"))
export type PurchasablesModule = typeof(require("../../src/Shared/VIP/Purchasables"))
export type AlphaWingsBonesModule = typeof(require("../../src/Shared/VIP/UGC/AlphaWings/Bones"))
export type LegacyCustomCommandsModule = typeof(require("../../model/Config/Legacy/Custom_Commands"))
export type ExampleAddonModule = typeof(require("../../model/Config/addons/src/ExampleAddon"))
export type ExampleAddonClientModule = typeof(require("../../model/Config/addons/src/ExampleAddonClient"))
export type ExampleAddonServerModule = typeof(require("../../model/Config/addons/src/ExampleAddonServer"))

export type MountedEnv = {
	env: any,
	root: any,
	KA: any,
	Shared: any,
	Server: any,
	Client: any,
	requireShared: (self: MountedEnv, name: string) -> any,
	requireUtil: (self: MountedEnv) -> UtilModule & any,
	requireRemote: (self: MountedEnv) -> any,
	mockClientRemotes: (self: MountedEnv) -> any,
	requireData: (self: MountedEnv) -> DataModule & any,
	requireAuth: (self: MountedEnv) -> any,
	requireProcess: (self: MountedEnv) -> any,
	requireRegistry: (self: MountedEnv) -> any,
	requireK: (self: MountedEnv) -> any,
}

function Harness.defaultRoles(): ({ [string]: any }, { any })
	local roles: { [string]: any } = {
		everyone = {
			_key = "everyone",
			_rank = 0,
			name = "Player",
			color = "#aaa",
			groups = { "utility" },
			limits = { cooldown = 4, commands = 4, targets = 1 },
			permissions = {
				admin = false,
				banasync = false,
				saveRoles = false,
				settings = false,
				serverlogs = false,
				targetOthers = false,
			},
			onlyTargetSelf = true,
			commands = { help = true, shutdown = false },
		},
		vip = {
			_key = "vip",
			_rank = 1,
			name = "VIP",
			color = "#0ff",
			groups = { "vip" },
			limits = { cooldown = 4, commands = 16, targets = 1 },
			permissions = { targetOthers = false },
			onlyTargetSelf = true,
			commands = {},
		},
		mod = {
			_key = "mod",
			_rank = 2,
			name = "Moderator",
			color = "#0f0",
			groups = { "moderation", "general", "environment", "fun", "vip" },
			limits = { cooldown = 4, commands = 32, targets = math.huge },
			permissions = { serverlogs = true, targetOthers = true },
			commands = {},
		},
		admin = {
			_key = "admin",
			_rank = 3,
			name = "Administrator",
			color = "#fc0",
			groups = { "administration", "moderation", "general", "environment", "fun", "vip" },
			limits = { cooldown = 4, commands = 64, targets = math.huge },
			permissions = { banasync = true, serverlogs = true, targetOthers = true },
			commands = {},
		},
		superadmin = {
			_key = "superadmin",
			_rank = 4,
			name = "SuperAdmin",
			color = "#f80",
			groups = { "superadmin", "administration", "moderation", "general", "environment", "fun", "vip" },
			limits = { cooldown = 0, commands = math.huge, targets = math.huge },
			permissions = {
				banasync = true,
				saveRoles = true,
				settings = true,
				serverlogs = true,
				targetOthers = true,
			},
			commands = {},
		},
		creator = {
			_key = "creator",
			_rank = math.huge,
			name = "Game Creator",
			color = "#f00",
			groups = {},
			limits = { cooldown = 0, commands = math.huge, targets = math.huge },
			permissions = { admin = true, targetOthers = true },
			commands = {},
		},
	}

	local rolesList = {
		roles.everyone,
		roles.vip,
		roles.mod,
		roles.admin,
		roles.superadmin,
		roles.creator,
	}

	return roles, rolesList
end

function Harness.seedRoles(Data: any)
	local roles, rolesList = Harness.defaultRoles()
	Data.roles = roles
	table.clear(Data.rolesList)
	for _, r in rolesList do
		table.insert(Data.rolesList, r)
	end
	if not Data.settingsModuleData then
		Data.settingsModuleData = { prefix = { ";" } }
	end
	return roles, rolesList
end

local function mountedRequireShared(self: MountedEnv, name: string): any
	return self.env:require(self.Shared:WaitForChild(name))
end

local function mountedRequireUtil(self: MountedEnv): any
	return self:requireShared("Util")
end

local function mountedRequireRemote(self: MountedEnv): any
	return self.env:require(self.Shared:WaitForChild("Util"):WaitForChild("Remote"))
end

local function mountedMockClientRemotes(self: MountedEnv): any
	local utilFolder = self.Shared:WaitForChild("Util")
	local remoteScript = utilFolder:WaitForChild("Remote")
	if not remoteScript:FindFirstChild("RemoteEvent") then
		local ev = self.env.Instance.new("RemoteEvent", remoteScript)
		ev.Name = "RemoteEvent"
		ev:SetAttribute("ServerReady", true)
		local fn = self.env.Instance.new("RemoteFunction", remoteScript)
		fn.Name = "RemoteFunction"
		local uev = self.env.Instance.new("UnreliableRemoteEvent", remoteScript)
		uev.Name = "UnreliableRemoteEvent"
	end
	local getUserInfoScript = utilFolder:FindFirstChild("getUserInfo")
	if getUserInfoScript and not getUserInfoScript:FindFirstChild("RemoteFunction") then
		local userFn = self.env.Instance.new("RemoteFunction", getUserInfoScript)
		userFn.Name = "RemoteFunction"
	end
	return remoteScript
end

local function mountedRequireData(self: MountedEnv): any
	local Data = self:requireShared("Data")
	if not Data.roles then
		Harness.seedRoles(Data)
	end
	if Data.Store and not Data.Store._guardedUpdateAsync then
		Data.Store._guardedUpdateAsync = true
		local origUpdateAsync = Data.Store.updateAsync
		local updateCalls = 0
		Data.Store.updateAsync = function(key: string, fn: any)
			updateCalls += 1
			if updateCalls > 100 then
				error("Data.Store.updateAsync exceeded max calls (infinite loop)", 0)
			end
			return origUpdateAsync(key, fn)
		end
	end
	return Data
end

local function mountedRequireAuth(self: MountedEnv): any
	self:requireData()
	local Registry = self:requireShared("Registry")
	if not Registry.commands.ban then
		Registry.commands.ban = { name = "ban", group = "moderation", aliases = {}, args = {} }
	end
	return self:requireShared("Auth")
end

local function mountedRequireProcess(self: MountedEnv): any
	self:requireData()
	return self:requireShared("Process")
end

local function mountedRequireRegistry(self: MountedEnv): any
	self:requireData()
	return self:requireShared("Registry")
end

local function mountedRequireK(self: MountedEnv): any
	return self.env:require(self.KA)
end

local function normalizeStageNode(node: any, enumRoot: any)
	if type(node) ~= "table" then
		return
	end
	local props = node.props
	if type(props) == "table" then
		local rc: any = props.RunContext
		if rc ~= nil then
			if type(rc) == "string" then
				props.RunContext = enumRoot.RunContext:FromName(rc)
			elseif type(rc) == "table" and type(rc.Enum) == "number" then
				props.RunContext = enumRoot.RunContext:FromValue(rc.Enum)
			elseif type(rc.Value) == "number" then
				props.RunContext = enumRoot.RunContext:FromValue(rc.Value)
			end
		end
	end
	if type(node.children) == "table" then
		for _, child in node.children do
			normalizeStageNode(child, enumRoot)
		end
	end
end

local function patchPlayerMethods(plr: any)
	if type(plr) == "table" then
		local methods = rawget(plr, "_methods")
		if type(methods) ~= "table" then
			methods = {}
			rawset(plr, "_methods", methods)
		end
		if methods.GetNetworkPing == nil then
			methods.GetNetworkPing = function()
				return 0.05
			end
		end
	end
end

local function sanitizeRemoteValue(val: any, seen: { [any]: boolean }): (any, boolean)
	if type(val) ~= "table" or rawget(val, "_isInstance") == true or getmetatable(val) ~= nil then
		return val, false
	end
	if seen[val] then
		return val, false
	end
	seen[val] = true
	local intCount, strCount, otherCount, maxInt = 0, 0, 0, 0
	for k in next, val do
		local kt = type(k)
		if kt == "string" then
			strCount += 1
		elseif kt == "number" and k == k and k >= 1 and k % 1 == 0 and k < 2 ^ 31 then
			intCount += 1
			if k > maxInt then
				maxInt = k
			end
		else
			otherCount += 1
		end
	end
	if otherCount > 0 or (intCount > 0 and strCount > 0) then
		seen[val] = nil
		return val, false
	end
	if intCount > 0 then
		if maxInt ~= intCount then
			local out = {}
			local i = 1
			while rawget(val, i) ~= nil do
				local child = sanitizeRemoteValue(rawget(val, i), seen)
				out[i] = child
				i += 1
			end
			seen[val] = nil
			return out, true
		end
		local changed = false
		local out: { [number]: any }? = nil
		for i = 1, intCount do
			local child, cChanged = sanitizeRemoteValue(rawget(val, i), seen)
			if cChanged and out == nil then
				out = table.clone(val)
				changed = true
			end
			if out ~= nil then
				out[i] = child
			end
		end
		seen[val] = nil
		return (out or val), changed
	end
	local changed = false
	local out: { [any]: any }? = nil
	for k, item in next, val do
		local child, cChanged = sanitizeRemoteValue(item, seen)
		if cChanged and out == nil then
			out = table.clone(val)
			changed = true
		end
		if out ~= nil then
			out[k] = child
		end
	end
	seen[val] = nil
	return (out or val), changed
end

local function patchRemoteEventSparseArrays(rem: any)
	local origFireClient = rem.FireClient
	local origFireAllClients = rem.FireAllClients
	local methods = rawget(rem, "_methods") or {}
	methods.FireClient = function(selfRem: any, player: any, ...: any)
		local packed = table.pack(...)
		for i = 1, packed.n do
			packed[i] = (sanitizeRemoteValue(packed[i], {}))
		end
		return origFireClient(selfRem, player, table.unpack(packed, 1, packed.n))
	end
	methods.FireAllClients = function(selfRem: any, ...: any)
		local packed = table.pack(...)
		for i = 1, packed.n do
			packed[i] = (sanitizeRemoteValue(packed[i], {}))
		end
		return origFireAllClients(selfRem, table.unpack(packed, 1, packed.n))
	end
	rawset(rem, "_methods", methods)
end

local function wrapEnv(env: any): MountedEnv
	assert(STAGE ~= nil, "Harness requires @stage (run via tools/sert.py)")
	if rawget(env.services, "SocialService") == nil then
		local social = env.Instance.new("Folder", env.game)
		social.Name = "SocialService"
		rawset(social, "_isService", true)
		env.services.SocialService = social
	end
	if env.server ~= nil then
		local okTp, tp = pcall(function()
			return env.game:GetService("TeleportService")
		end)
		if okTp and type(tp) == "table" then
			local methods = rawget(tp, "_methods")
			if type(methods) == "table" and type(methods.TeleportAsync) == "function" and not methods._recordsEnv then
				methods._recordsEnv = true
				methods.TeleportAsync = function(_selfTp: any, placeId: number, players: any, options: any?)
					if type(env.teleports) == "table" then
						table.insert(env.teleports, {
							placeId = placeId,
							players = players,
							options = options,
						})
					end
					return { PrivateServerId = "", ReservedServerAccessCode = "" }
				end
			end
		end
	end
	for _, plr in env.Players:GetPlayers() do
		patchPlayerMethods(plr)
	end
	env.Players.PlayerAdded:Connect(patchPlayerMethods)
	if type(env.addPlayer) == "function" then
		local origAddPlayer = env.addPlayer
		env.addPlayer = function(selfEnv: any, ...: any)
			local plr = origAddPlayer(selfEnv, ...)
			patchPlayerMethods(plr)
			return plr
		end
	end
	normalizeStageNode((STAGE :: any).root or STAGE, env.Enum)
	if type((STAGE :: any).files) == "table" then
		(STAGE :: any).files["vendor/flux/src/Type/init.luau"] = function()
			return function()
				return nil
			end
		end
	end
	local rs = env.game:GetService("ReplicatedStorage")
	local stageName = (STAGE :: any).name or "kohls-admin"
	local existingRoot = if env.isClient then rs:FindFirstChild(stageName) else nil
	local root = existingRoot or env:mount(STAGE, rs)
	local KA = root:FindFirstChild("KA") or root
	local Shared = KA:WaitForChild("Shared")
	local Server = if existingRoot ~= nil then KA:FindFirstChild("Server") else KA:WaitForChild("Server")
	local Client = KA:WaitForChild("Client")
	local Tools = root:FindFirstChild("Tools")
	if Tools ~= nil and Server ~= nil then
		Tools.Parent = Server
	end
	if env.isServer then
		local utilFolder = Shared:FindFirstChild("Util")
		if utilFolder ~= nil then
			local remoteScript = utilFolder:FindFirstChild("Remote")
			if remoteScript ~= nil then
				local ev = remoteScript:FindFirstChildOfClass("RemoteEvent")
				if ev == nil then
					ev = env.Instance.new("RemoteEvent", remoteScript)
					ev.Name = "RemoteEvent"
				end
				patchRemoteEventSparseArrays(ev)
				local uev = remoteScript:FindFirstChildOfClass("UnreliableRemoteEvent")
				if uev == nil then
					uev = env.Instance.new("UnreliableRemoteEvent", remoteScript)
					uev.Name = "UnreliableRemoteEvent"
				end
				patchRemoteEventSparseArrays(uev)
				if remoteScript:FindFirstChildOfClass("RemoteFunction") == nil then
					local rfn = env.Instance.new("RemoteFunction", remoteScript)
					rfn.Name = "RemoteFunction"
				end
			end
		end
	end

	local mounted: MountedEnv = {
		env = env,
		root = root,
		KA = KA,
		Shared = Shared,
		Server = Server,
		Client = Client,
		requireShared = mountedRequireShared,
		requireUtil = mountedRequireUtil,
		requireRemote = mountedRequireRemote,
		mockClientRemotes = mountedMockClientRemotes,
		requireData = mountedRequireData,
		requireAuth = mountedRequireAuth,
		requireProcess = mountedRequireProcess,
		requireRegistry = mountedRequireRegistry,
		requireK = mountedRequireK,
	}
	return mounted
end

local sharedEnv: MountedEnv? = nil
local sharedMutant: any = nil

local function withDefaultEnvOpts(opts: any?): any
	if opts == nil then
		return { strict = false, signalBehavior = "Immediate" }
	end
	if opts.strict == nil or opts.signalBehavior == nil then
		local copy = table.clone(opts)
		if copy.strict == nil then
			copy.strict = false
		end
		if copy.signalBehavior == nil then
			copy.signalBehavior = "Immediate"
		end
		return copy
	end
	return opts
end

function Harness.shared(): MountedEnv
	local curMutant = (_G :: any).__SERT_MUTANT
	if sharedEnv == nil or sharedMutant ~= curMutant then
		sharedEnv = wrapEnv(sert.env.new({ strict = false, signalBehavior = "Immediate" }))
		sharedMutant = curMutant
	end
	return sharedEnv :: MountedEnv
end

function Harness.newEnv(opts: any?): MountedEnv
	local env = sert.env.new(withDefaultEnvOpts(opts))
	return wrapEnv(env)
end

function Harness.newPeerEnv(peer: any, opts: any?): MountedEnv
	local env = peer:env(withDefaultEnvOpts(opts))
	return wrapEnv(env)
end

return Harness
