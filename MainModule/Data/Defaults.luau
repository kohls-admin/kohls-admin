local UI = require(script.Parent.Parent.Client.UI)

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
	bans = {
		-- [UserId] = {Reason, Timestamp, fromUserId}
		-- Username is the last known username of the user when they were banned
		-- TODO: progressively parse and update each name!
		-- if Timestamp is -1 the ban is permanent
		-- if Timestamp is nil the ban is for the server session only
		-- saves only if Timestamp isn't nil
		["2"] = { "John Doe", "He been noob.", nil, 44391621 },
		["3"] = { "Jane Doe", "She was a noob.", 1720922623, 44391621 },
		["5"] = { nil, "Deleted account", -1, 44391621 },
	},
	logs = {},
	members = {
		-- example role data structure
		-- [userid] = {data}
		["1"] = {
			-- last known username? (update over time on init?)
			name = "Roblox",
			filter = {}, -- TODO: implement member filter for auth
			permissions = {},
			persist = {},
			roles = { "admin", "vip" },
		},
	},
	players = {},

	loaderSettings = {} :: { [string]: any },
	settings = {
		prefix = ";",
		announcement = false,
		liveSettings = true,
		gameHubEnabled = true,
		vip = true,
		dashboardButtonRank = 0,
		joinNotificationRank = 1,
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
	roles = {
		-- WARN: unique key should NEVER be changed or you may lose save data
		default = {
			-- role "_rank" determines hierarchy
			-- 0 is reserved for the default role
			_rank = 0,
			name = "Player",
			color = "#0ff",

			-- when enabled only allows their player to be used with the player argument
			-- WARN: doesn't affect commands that use userids!
			onlyTargetSelf = false,

			permissions = {
				-- this permission bypasses all restrictions (danger!)
				admin = false,
				-- can ban users via banasync, otherwise only per server session if has ban command
				banasync = false,
				-- allows the user to manage saved roles of other users with a lesser role
				saveRoles = false,
				-- can configure the global admin settings
				settings = false,
				-- can view server-side logs
				serverlogs = false,
			},

			-- allowed command groups
			groups = {
				-- "creator",
				-- "administration",
				-- "moderation",
				-- "environment",
				-- "general",
				-- "fun",
				-- "vip",
				"utility",
			},

			-- command overrides
			commands = {
				-- allow the help command
				help = true,
				-- disable the shutdown command if given to role by a command group
				shutdown = false,
			},
		},
		vip = {
			_rank = 1,
			name = "VIP",
			groups = { "vip" },
			permissions = {},
			color = "#0f8",
			onlyTargetSelf = true,
		},
		mod = {
			_rank = 2,
			name = "Moderator",
			groups = { "moderation", "general", "environment", "fun", "vip" },
			permissions = {},
			color = "#0f0",
		},
		admin = {
			_rank = 3,
			name = "Administrator",
			groups = { "administration", "moderation", "general", "environment", "fun", "vip" },
			permissions = { banasync = true },
			color = "#ff0",
		},
		superadmin = {
			_rank = 4,
			name = "SuperAdmin",
			groups = { "superadmin", "administration", "moderation", "general", "environment", "fun", "vip" },
			permissions = { banasync = true, saveRoles = true, settings = true },
			color = "#f80",
		},
		-- FIXME should this be defined and configurable? (or should it just be forced...)
		creator = {
			_rank = math.huge,
			name = "Game Creator",
			permissions = { admin = true },
			color = "#f00",
		},
	},

	logsHidden = {},

	gameClosing = false,
	pendingSaveMain = false,
	pendingSaveLogs = false,
	sizeMain = 0,
	sizeLogs = 0,

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
for key, state in UI.Theme do
	Data.settings["theme" .. key] = UI.peek(state)
end

return Data
