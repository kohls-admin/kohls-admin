local RunService = game:GetService("RunService")

local Theme = require(script.Parent.Parent.Client:WaitForChild("UI"):WaitForChild("Theme"))

type Dict = { [any]: any }

local Data = {
	IS_PRIVATE_SERVER = RunService:IsServer() and game.PrivateServerId ~= "" and game.PrivateServerOwnerId ~= 0,

	-- DataStore

	SEPARATE_DATASTORE = nil,
	REMOVE = table.freeze({}),

	Sync = {
		bans = {},
		members = {},
		settings = {},
		logs = {},
		players = {},
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
		splitKey = "%s",

		commandBarRank = 0,
		dashboardRank = 0,
		dashboardButtonRank = 0,
		joinNotificationRank = 1,

		welcomeBadgeId = 0,

		addToCharts = true,
		vip = true,

		chatCommands = true,
		commandRequests = true,
		onlyShowUsableCommands = false,
		getKohlsAdminPopup = true,
		wrongPrefixWarning = true,
		saveLogs = true,

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
