local RunService = game:GetService("RunService")

local Theme = require(script.Parent.Parent.Client:WaitForChild("UI"):WaitForChild("Theme"))

type Dict = { [any]: any }

local Cache = {
	-- Main
	bans = {},
	members = {},
	settings = {},
	-- Logs
	chatLogs = {},
	logs = {},
	-- userId
	players = {},
}

local Data = {
	IS_PRIVATE_SERVER = RunService:IsServer() and game.PrivateServerId ~= "" and game.PrivateServerOwnerId ~= 0,
	SEPARATE_DATASTORE = false,
	REMOVE = table.freeze({}),

	Migrate = {} :: any,

	Cache = Cache,
	creatorId = game.CreatorId,
	bans = {},
	logs = {},
	logFingerprints = {},
	members = {},
	players = {},
	playerPrefix = {},
	reservedServers = {},
	targetLimits = {},
	roles = nil,
	rolesList = {},

	settingsModuleData = nil,
	settingsDefault = {},
	settings = {
		liveSettings = true,

		announcement = false,
	},

	async = {
		asset = {},
		gamepass = {},
		group = {},
		subscription = {},
	},

	logsHidden = {},

	gameClosing = false,
	sizeBans = 0,
	sizeMain = 0,
	sizeLogs = 0,
	updatedTimeBans = 0,
	updatedTimeMain = 0,
	updatedTimeLogs = 0,
	updateAsyncInterval = 60,

	initialize = nil,
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
for key, state in Theme do
	if key == "Themes" then
		continue
	end
	if state._value ~= nil then
		Data.settings["theme" .. key] = state._value
	end
end

return Data
