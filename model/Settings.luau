-- Private server owner ID detection
local PRIVATE_SERVER_OWNER = if game:GetService("RunService"):IsServer() then game.PrivateServerOwnerId else nil

local Settings = {

	-- 🛠️ AUTOMATIC UPDATES
	-- Automatically updates from the latest official MainModule version.
	-- Set to false to use the locally included MainModule instead.
	autoUpdate = true,

	-- 🔧 COMMAND PREFIX
	-- Sets the prefix used to run commands in chat (e.g., ";cmd").
	prefix = ";",

	-- 📊 GAME HUB INTEGRATION
	--[[
	Enables participation in the Kohl's Admin Games Hub.
	Promotes your game to players looking for games that support Kohl's Admin features.
	https://www.roblox.com/games/17873329124/Games-Hub-Kohls-Admin

	⚠️ Requires "Allow HTTP Requests" to be enabled in Game Settings > Security
	]]
	gameHubEnabled = true,

	-- 💎 VIP DONATION FEATURES
	-- Enables Kohl's Admin VIP donation features (required for games hub)
	vip = true,

	-- 🗃️ LOG SAVING
	-- EXPERIMENTAL: Enables saving and syncing logs across servers.
	saveLogs = false,

	-- 🎮 DASHBOARD BUTTON VISIBILITY
	--[[
	Sets the minimum role required to see the Kohl's Admin Dashboard button in the Topbar.
		0	defaultRole
		1	vip
		2	mod
		3	admin
		4	superadmin
		5	creator
		false	Disable for every rank
	]]
	dashboardButtonRank = 0,

	-- 🛎️ JOIN NOTIFICATION
	-- Sets the minimum role required to trigger the Kohl's Admin join notification.
	joinNotificationRank = 1,

	-- 💬 POPUP DISPLAY
	-- Shows the "Enjoy Kohl's Admin?" popup to users.
	getKohlsAdminPopup = true,

	-- ⛔ BANS
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

	-- 💼 FREE ADMIN ROLES
	-- Gives everyone access to the uncommented roles
	freeAdmin = {
		-- "creator",
		-- "superadmin",
		-- "admin",
		-- "mod",
		-- "vip",
	},

	-- 🏢 GROUP ROLES
	-- Set group-specific roles and ranks
	groupRoles = {
		-- [groupId] = {
		-- { rank = 200, roles = { "admin", "vip" }, exactRank = false },
		-- },
	},

	-- 👤 USER ROLES
	--[[
	Accepts a list of UserIds, sourced from a Roblox profile
		For example;
			https://www.roblox.com/users/44391621/profile
			Has a UserId of 44391621
		Use "PRIVATE_SERVER_OWNER" for private servers!
	]]
	userRoles = {
		creator = {},
		superadmin = {},
		admin = {},
		mod = {},
		vip = { 1, 156, PRIVATE_SERVER_OWNER },
	},

	-- 🏅 ROLE DEFINITIONS
	-- Role definitions with hierarchy, permissions, colors, and available command groups.
	roles = {
		{ -- Default Role (Base permissions for all users)
			_key = "default", -- DO NOT CHANGE: System identifier

			name = "Player",
			color = "#0ff",

			-- When enabled, users can only target themselves with player arguments.
			-- ⚠️ This does not affect commands that use UserIds directly!
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

			-- Gives the role automatically if the user has the specified gamepass id
			gamepass = nil,
		},

		{ -- VIP Role
			_key = "vip", -- DO NOT CHANGE: System identifier
			name = "VIP",
			groups = { "vip" },
			permissions = {},
			color = "#0f8",
			onlyTargetSelf = true,
			gamepass = nil,
		},

		{ -- Moderator Role
			_key = "mod", -- DO NOT CHANGE: System identifier
			name = "Moderator",
			groups = { "moderation", "general", "environment", "fun", "vip" },
			permissions = { serverlogs = true },
			color = "#0f0",
			gamepass = nil,
		},

		{ -- Administrator Role
			_key = "admin", -- DO NOT CHANGE: System identifier
			name = "Administrator",
			groups = { "administration", "moderation", "general", "environment", "fun", "vip" },
			permissions = { banasync = true, serverlogs = true },
			color = "#ff0",
		},

		{ -- SuperAdmin Role
			_key = "superadmin", -- DO NOT CHANGE: System identifier
			name = "SuperAdmin",
			groups = { "superadmin", "administration", "moderation", "general", "environment", "fun", "vip" },
			permissions = { banasync = true, saveRoles = true, settings = true, serverlogs = true },
			color = "#f80",
		},

		[math.huge] = { -- Creator Role (Highest Authority)
			_key = "creator", -- DO NOT CHANGE: System identifier
			name = "Game Creator",
			permissions = { admin = true },
			color = "#f00",
		},
	},
}

return Settings
