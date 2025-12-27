local RunService = game:GetService("RunService")

local Shared = script.Parent.Parent
local Package = Shared.Parent

local Theme = require(Package.Client:WaitForChild("UI"):WaitForChild("Theme"))
local Z = require(Package.Z)

type Dict = { [any]: any }

Z.TRIM_STRINGS = true

local Schema = {}

Schema.log = Z.schema {
	level = Z.byte,
	from = Z.some(Z.uint),
	name = Z.some(Z.str8),
	text = Z.str16,
	time = Z.f64,
}

Schema.logs = Z.schema { Schema.log }

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
	Migrate = {} :: any,
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

	bans = {},
	members = {},
	logs = {},
	reservedServers = {},
	roles = nil,
	rolesList = {},

	logsHidden = {},
	playerPrefix = {},
	targetLimits = {},

	defaultSettings = {},
	savedSettings = {} :: any,
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

Data.Store = require(script.Parent.Store)
if game:GetService("RunService"):IsClient() then
	Data.Store = nil
end

-- UI Theme initial settings
for key, state in Theme :: any do
	if key == "Themes" then
		continue
	end
	if state._value ~= nil then
		Data.settings["theme" .. key] = state._value
	end
end

return Data
