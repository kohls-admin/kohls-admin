--[[
	Kohl's Admin Settings
	This file contains all the configuration options for the Kohl's Admin system.
]]

-- Detect private server owner ID
local PRIVATE_SERVER_OWNER = if game:GetService("RunService"):IsServer() then game.PrivateServerOwnerId else nil

local Settings = {

	-- 🛠️ Auto-Update Configuration
	-- When true: Automatically fetches and uses the latest official MainModule version
	-- When false: Uses the locally included MainModule version instead
	autoUpdate = true,

	-- 🔧 Command Configuration
	-- The prefix character used to trigger commands (e.g., ";kick player")
	prefix = ";",

	-- 📊 Game Hub Integration
	-- Enables integration with the Kohl's Admin Games Hub:
	-- Lists your game in the hub's directory, making it discoverable by players seeking Kohl's Admin games
	-- Hub URL: https://www.roblox.com/games/17873329124/Games-Hub-Kohls-Admin
	-- ⚠️ Important: Requires "Allow HTTP Requests" in Game Settings > Security
	gameHubEnabled = true,

	-- 💎 VIP Features
	-- Enables VIP-specific features and donation support
	-- Note: Required if gameHubEnabled is true
	vip = true,

	-- 🗃️ Log Management
	-- Experimental: When enabled, saves and syncs admin logs across multiple servers
	saveLogs = true,

	-- 🎮 Dashboard Access Control
	--[[
	Controls visibility of the Kohl's Admin Dashboard button in the Topbar
	Rank values:
		0: Default role (everyone)
		1: VIP
		2: Moderator
		3: Administrator
		4: SuperAdmin
		5: Creator
		false: Hidden from all ranks
	]]
	dashboardButtonRank = 0,

	-- 🛎️ Join Notifications
	-- Minimum rank required to trigger join notifications
	-- Uses same rank values as dashboardButtonRank
	joinNotificationRank = 1,

	-- 💬 Feedback System
	-- When true, shows the "Enjoy Kohl's Admin?" feedback popup to users
	getKohlsAdminPopup = true,

	-- ⛔ Ban Database
	--[[
	Stores active bans in format: [UserId] = {Username, Reason, Time, BannedByUserId}

	Duration values:
		-1: Permanent ban
		0:  Server-session ban (until server restart)
		>0: Temporary ban (UTC timestamp in seconds for ban expiry)
	]]
	bans = {
		["2"] = { "John Doe", "He been noob.", nil, 44391621 },
		["3"] = { "Jane Doe", "She was noob.", 1720922623, 44391621 },
		["5"] = { nil, "Deleted account", -1, 44391621 },
	},

	-- 💼 Universal Roles
	-- When uncommented, grants specified roles to all players
	-- Warning: Use with caution as this affects everyone who joins
	freeAdmin = {
		-- "creator",     -- Highest authority
		-- "superadmin",  -- Extended administration
		-- "admin",       -- General administration
		-- "mod",         -- Basic moderation
		-- "vip",         -- Special features
	},

	-- 🏢 Group-Based Roles
	-- Automatically assigns roles based on Roblox group membership and rank
	groupRoles = {
		-- [groupId] = {
		-- 	{ rank = 200, roles = { "admin", "vip" }, exactRank = false },
		-- },
	},

	-- 👤 User-Specific Roles
	--[[
	Assigns roles to specific Roblox users by their UserID

	To find a UserID:
	1. Visit a user's profile (e.g., https://www.roblox.com/users/44391621/profile)
	2. The number in the URL is their UserID (44391621 in this example)

	Special values:
	- PRIVATE_SERVER_OWNER: Automatically targets private server owner
	]]
	userRoles = {
		creator = {}, -- Highest authority
		superadmin = {}, -- Extended administration
		admin = {}, -- General administration
		mod = {}, -- Basic moderation
		vip = { 1, 156, PRIVATE_SERVER_OWNER }, -- Special features
	},

	-- 🏅 Role Configuration
	-- Defines the hierarchy, permissions, and capabilities of each role
	roles = {
		{ -- Default Role (Base permissions for all users)
			_key = "default", -- DO NOT CHANGE: System identifier

			name = "Player", -- Display name
			color = "#0ff", -- Role color, hex only!

			-- Auto-Role Assignment
			gamepass = nil, -- GamePass ID for automatic role granting

			-- Command Access
			commands = {
				help = true, -- Enable help command
				shutdown = false, -- Disable shutdown capability
			},

			-- Command Access Groups
			groups = {
				-- "creator",        -- System-level commands
				-- "administration", -- Administrative tools
				-- "moderation",     -- Moderation tools
				-- "environment",    -- World manipulation
				-- "general",        -- Staff utilities
				-- "fun",            -- Entertainment commands
				-- "vip",            -- Special features
				"utility", -- Common utilities
			},

			-- Permission Flags
			permissions = {
				admin = false, -- ⚠️ Complete bypass of all restrictions
				banasync = false, -- Permanent ban capability
				saveRoles = false, -- Role management for lower ranks
				settings = false, -- Global admin settings access
				serverlogs = false, -- Server-side log access
			},

			-- Target Restriction
			-- When true: Users can only use commands on themselves
			-- ⚠️ Note: Does not restrict commands using direct UserIDs
			onlyTargetSelf = true,
		},

		{ -- VIP Role
			_key = "vip", -- DO NOT CHANGE: System identifier
			name = "VIP",
			color = "#0f8",
			commands = {}, -- Command-Specific Overrides
			groups = { "vip" },
			permissions = {},
			onlyTargetSelf = true,
			gamepass = nil, -- Set to your VIP GamePass ID
		},

		{ -- Moderator Role
			_key = "mod", -- DO NOT CHANGE: System identifier
			name = "Moderator",
			color = "#0f0",
			commands = {}, -- Command-Specific Overrides
			groups = { "moderation", "general", "environment", "fun", "vip" },
			permissions = { serverlogs = true },
			gamepass = nil, -- Set to your Moderator GamePass ID
		},

		{ -- Administrator Role
			_key = "admin", -- DO NOT CHANGE: System identifier
			name = "Administrator",
			color = "#ff0",
			commands = {}, -- Command-Specific Overrides
			groups = { "administration", "moderation", "general", "environment", "fun", "vip" },
			permissions = { banasync = true, serverlogs = true },
		},

		{ -- SuperAdmin Role
			_key = "superadmin", -- DO NOT CHANGE: System identifier
			name = "SuperAdmin",
			color = "#f80",
			commands = {}, -- Command-Specific Overrides
			groups = { "superadmin", "administration", "moderation", "general", "environment", "fun", "vip" },
			permissions = { banasync = true, saveRoles = true, settings = true, serverlogs = true },
		},

		[math.huge] = { -- Creator Role (Highest Authority)
			_key = "creator", -- DO NOT CHANGE: System identifier
			name = "Game Creator",
			color = "#f00",
			permissions = { admin = true }, -- Full system access
		},
	},
}

return Settings
