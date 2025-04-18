local Flux = require(script.Parent.Parent.Flux)
local Theme = require(script.Parent.Parent.Client:WaitForChild("UI").Theme)

local Cache = {
	-- Main
	bans = {},
	members = {},
	settings = {},
	-- Logs
	logs = {},
	-- userId
	players = {},
}

local Data = {
	Cache = Cache,
	creatorId = game.CreatorId,
	bans = {},
	logs = {},
	members = {
		-- example role data structure
		-- [userid] = {data}
		-- ["1"] = {
		-- 	name = "Roblox",
		-- 	commands = {},
		-- 	permissions = {},
		-- 	persist = {},
		-- 	roles = { "admin", "vip" },
		-- },
	},
	players = {},
	roles = nil,

	loaderSettings = {} :: { [string]: any },
	settings = {
		prefix = ";",
		announcement = false,
		liveSettings = true,
		gameHubEnabled = true,
		vip = true,
		dashboardButtonRank = 0,
		joinNotificationRank = 1,
		getKohlsAdminPopup = true,
		saveLogs = false,
	},

	async = {
		gamepass = {},
		-- NOTE: ASSET/SUBS REQUIRE A PLAYER FOR PERMISSIONS AND CAN STILL BE AFFECTED BY ID COMMANDS!
		asset = {},
		subscription = {},
		-- TODO: need a way to define exact rank roles instead of >=
		group = {},
		-- [groupId] = {
		-- { rank = 200, roles = { "admin", "vip" }, rankAndAbove = true },
		-- },
	},

	logsHidden = {},

	gameClosing = false,
	sizeBans = 0,
	sizeMain = 0,
	sizeLogs = 0,
	updatedTimeBans = 0,
	updatedTimeMain = 0,
	updatedTimeLogs = 0,
	updateAsyncInterval = 15,

	banHandler = nil,
	banUser = nil,
	initialize = nil,
	Store = nil,
}

function Data.sortTime(a, b)
	return a.time < b.time
end

if game:GetService("RunService"):IsServer() then
	Data.Store = require(script.Parent.Store)
end

-- UI Theme initial settings
for key, state in Theme do
	Data.settings["theme" .. key] = Flux.peek(state)
end

return Data
