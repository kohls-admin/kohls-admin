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
	globals = if IN_ROBLOX then getfenv() else sert.env.new().globals,
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
	local remoteScript = self.Shared:WaitForChild("Util"):WaitForChild("Remote")
	if not remoteScript:FindFirstChild("RemoteEvent") then
		local ev = self.env.Instance.new("RemoteEvent", remoteScript)
		ev.Name = "RemoteEvent"
		ev:SetAttribute("ServerReady", true)
		local fn = self.env.Instance.new("RemoteFunction", remoteScript)
		fn.Name = "RemoteFunction"
		local uev = self.env.Instance.new("UnreliableRemoteEvent", remoteScript)
		uev.Name = "UnreliableRemoteEvent"
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

local function wrapEnv(env: any): MountedEnv
	assert(STAGE ~= nil, "Harness requires @stage (run via tools/sert.py)")
	local rs = env.game:GetService("ReplicatedStorage")
	local root = env:mount(STAGE, rs)
	local KA = root:FindFirstChild("KA") or root
	local Shared = KA:WaitForChild("Shared")
	local Server = KA:WaitForChild("Server")
	local Client = KA:WaitForChild("Client")
	local Tools = root:FindFirstChild("Tools")
	if Tools ~= nil and Server ~= nil then
		Tools.Parent = Server
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

function Harness.shared(): MountedEnv
	local curMutant = (_G :: any).__SERT_MUTANT
	if sharedEnv == nil or sharedMutant ~= curMutant then
		sharedEnv = wrapEnv(sert.env.new())
		sharedMutant = curMutant
	end
	return sharedEnv :: MountedEnv
end

function Harness.newEnv(opts: any?): MountedEnv
	local env = sert.env.new(opts)
	return wrapEnv(env)
end

function Harness.newPeerEnv(peer: any, opts: any?): MountedEnv
	local env = peer:env(opts)
	return wrapEnv(env)
end

return Harness
