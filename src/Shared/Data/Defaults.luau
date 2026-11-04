local RunService = game:GetService("RunService")

local Shared = script.Parent.Parent
local Package = Shared.Parent

local Theme = require(Package.Client:WaitForChild("UI"):WaitForChild("Theme"))
local Z = require(Package:WaitForChild("Z"))

type Dict = { [any]: any }

Z.TRIM_STRINGS = true

local Schema = {}

Schema.log = Z.schema {
	Z.str16, -- text
	Z.byte, -- level
	Z.f64, -- time
	Z.some(Z.uint), -- from
	Z.some(Z.str8), -- name
}

Schema.logs = Z.schema { Schema.log }

Schema.logRemote = Z.schema {
	Z.str16, -- text
	Z.byte, -- level
	Z.f64, -- time
	Z.some(Z.uint), -- from
	Z.some(Z.str8), -- name
	Z.some(Z.bool), -- false = global
}

Schema.logsRemote = Z.schema { Schema.logRemote }

Schema.logV0 = Z.schema {
	level = Z.byte,
	from = Z.some(Z.uint),
	name = Z.some(Z.str8),
	text = Z.str16,
	time = Z.f64,
}

Schema.logsV0 = Z.schema { Schema.logV0 }

local Data = {
	IS_PRIVATE_SERVER = RunService:IsServer() and game.PrivateServerId ~= "" and game.PrivateServerOwnerId ~= 0,

	-- DataStore

	SEPARATE_DATASTORE = nil,
	REMOVE = table.freeze({}),
	Schema = Schema,

	Sync = {
		bans = {},
		members = {},
		settings = {},
		logs = {},
	},
	Migrate = {} :: Dict,
	canSave = nil,
	saveError = nil,
	initialize = nil,

	sizeBans = 0,
	sizeMain = 0,
	sizeLogs = 0,

	-- Core

	creatorId = game.CreatorId,
	gameClosing = false,

	async = {
		asset = {},
		gamepass = {},
		group = {},
		subscription = {},
	},
	friendRoles = {},

	bans = {},
	members = {},
	logs = {},
	logsVersion = 0,
	reservedServers = {},
	servers = {},
	roles = nil,
	rolesList = {},
	defaultRoles = {
		everyone = {
			_key = "everyone",
			_rank = 0,
			name = "Player",
			color = "#ffffff",
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
		},
		mod = {
			_key = "mod",
			_rank = 2,
			name = "Moderator",
			color = "#0f0",
			groups = { "moderation", "general", "environment", "fun", "vip" },
			limits = { cooldown = 4, commands = 32, targets = math.huge },
			permissions = { serverlogs = true, targetOthers = true },
		},
		admin = {
			_key = "admin",
			_rank = 3,
			name = "Administrator",
			color = "#fc0",
			groups = { "administration", "moderation", "general", "environment", "fun", "vip" },
			limits = { cooldown = 4, commands = 64, targets = math.huge },
			permissions = { banasync = true, serverlogs = true, targetOthers = true },
		},
		superadmin = {
			_key = "superadmin",
			_rank = 4,
			name = "SuperAdmin",
			color = "#f80",
			groups = { "superadmin", "administration", "moderation", "general", "environment", "fun", "vip" },
			permissions = {
				banasync = true,
				saveRoles = true,
				settings = true,
				serverlogs = true,
				targetOthers = true,
			},
		},
		creator = {
			_key = "creator",
			_rank = math.huge,
			name = "Game Creator",
			color = "#f00",
			permissions = { admin = true, targetOthers = true },
		},
	},

	logsHidden = {},
	pendingLogReveals = {} :: { any },
	playerPrefix = {},
	targetLimits = {},

	defaultSettings = {},
	savedSettings = {} :: Dict,
	settingsModuleData = nil,
	settings = {
		announcement = false,
		useSavedSettings = true,

		prefix = { ";", ":" },
		splitKey = " ",

		commandBarRank = 0,
		dashboardRank = 0,
		commandsButtonRank = 0,
		dashboardButtonRank = 1,
		joinNotificationRank = 1,

		welcomeBadgeId = 0,

		addToCharts = true,
		vip = true,

		chatCommands = true,
		chatCommandsNotification = true,
		commandRequests = true,
		onlyShowUsableCommands = true,
		getKohlsAdminPopup = true,
		wrongPrefixWarning = true,
		saveLogs = true,
		saveChatLogs = false,
		saveLogsForAllRoles = false,

		theme = "Default",
		changeThemeAuthority = "Client",
	},
}

function Data.filterRemove(source: Dict): Dict
	for key, value in source do
		if value == Data.REMOVE then
			source[key] = nil
		elseif type(value) == "table" then
			Data.filterRemove(value)
		end
	end
	return source
end

function Data.mergeRemove(to: Dict, from: Dict): Dict
	for key, value in from do
		to[key] = if value == Data.REMOVE then nil else value
	end
	return to
end

Data.Store = require(script.Parent:WaitForChild("Store"))
if game:GetService("RunService"):IsClient() then
	Data.Store = nil
end

-- UI Theme initial settings
function Data.syncThemeDefaults()
	for key, state in pairs(Theme) do
		if key == "Themes" then
			continue
		end
		if type(state) == "table" and type(state.set) == "function" and type(state.peek) == "function" then
			Data.settings["theme" .. key] = state:peek()
		end
	end
end
Data.syncThemeDefaults()

return Data
