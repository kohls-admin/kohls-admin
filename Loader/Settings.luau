local PRIVATE_SERVER_OWNER = if game:GetService("RunService"):IsServer() then game.PrivateServerOwnerId else nil

local Settings = {

	-- Automatic updates from the latest official version of the MainModule
	-- Disable to use the included MainModule
	autoUpdate = true,

	-- Changes the default command prefix
	prefix = ";",

	--[[
	Enables participation in the Kohl's Admin Games Hub, showcasing
	your game to users looking for games with benefits from Kohl's Admin.
	https://www.roblox.com/games/17873329124/Kohls-Admin-Games-Hub

	⚠️ Requires Allowing HTTP Requests in File > Game Settings > Security
	]]
	gameHubEnabled = true,

	-- Enables Kohl's Admin VIP donation features (required for games hub)
	vip = true,

	--[[
	[UserId] = {Username, Reason, Duration, fromUserId}

	Ban duration
		-1 forever
		0 server session
		>0 UTC time in seconds
	]]
	bans = {
		["2"] = { "John Doe", "He been noob.", nil, 44391621 },
		["3"] = { "Jane Doe", "She was noob.", 1720922623, 44391621 },
		["5"] = { nil, "Deleted account", -1, 44391621 },
	},

	-- Gives everyone access to the uncommented roles
	freeAdmin = {
		-- "creator",
		-- "superadmin",
		-- "admin",
		-- "mod",
		-- "vip",
	},

	gamePassRoles = {
		-- [gamePassId] = { "mod", "vip" },
	},

	groupRoles = {
		-- [groupId] = {
		-- { rank = 200, roles = { "admin", "vip" }, exactRank = false },
		-- },
	},

	--[[
	Accepts a list of UserIds, sourced from a Roblox profile
		For example;
			https://www.roblox.com/users/44391621/profile
			Has a UserId of 44391621
		Use "game.PrivateServerOwnerId" for private servers!
	]]
	userRoles = {
		creator = {},
		superadmin = {},
		admin = {},
		mod = {},
		vip = { 1, 156, PRIVATE_SERVER_OWNER },
	},

	--[[
	Toggles visibility of the Kohl's Admin Dashboard Button in the Topbar.
		0	defaultRole
		1	vip
		2	mod
		3	admin
		4	superadmin
		5	creator
	]]
	dashboardButtonRank = 0,

	-- Toggles visibility of the Kohl's Admin Join Notification.
	joinNotificationRank = 1,

	roles = {
		default = {
			-- role "_rank" determines hierarchy
			-- 0 is reserved for the default role
			_rank = 0,
			name = "Player",
			color = "#0ff",

			-- when enabled only allows their player to be used with the player argument
			-- WARN: doesn't affect commands that use userids!
			onlyTargetSelf = true,

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
			permissions = { serverlogs = true },
			color = "#0f0",
		},
		admin = {
			_rank = 3,
			name = "Administrator",
			groups = { "administration", "moderation", "general", "environment", "fun", "vip" },
			permissions = { banasync = true, serverlogs = true },
			color = "#ff0",
		},
		superadmin = {
			_rank = 4,
			name = "SuperAdmin",
			groups = { "superadmin", "administration", "moderation", "general", "environment", "fun", "vip" },
			permissions = { banasync = true, saveRoles = true, settings = true, serverlogs = true },
			color = "#f80",
		},
		creator = {
			_rank = math.huge,
			name = "Game Creator",
			permissions = { admin = true },
			color = "#f00",
		},
	},
}

return Settings
