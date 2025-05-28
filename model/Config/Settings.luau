--[[ DEFAULT ROLES
┏━━━━━━━━━┳━━━━━━━━━━━━━━┳━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃ RANK    ┃ ROLE         ┃ DETAILS                                                                                                ┃
┣━━━━━━━━━╋━━━━━━━━━━━━━━╋━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫
┃ inf     ┃ creator      ┃ Can do everything, automatically given to the creator of the group/game.                               ┃
┃ 4       ┃ superadmin   ┃ Can permanently role users, change settings, shutdown servers, give badges, and use commands globally. ┃
┃ 3       ┃ admin        ┃ Can permanently ban users and give roles per server.                                                   ┃
┃ 2       ┃ mod          ┃ Can kick and server ban with other potentially abusive commands.                                       ┃
┃ 1       ┃ vip          ┃ Can only use commands on themselves, limited to non-abusive cosmetic commands.                         ┃
┃ 0       ┃ everyone     ┃ The default role, limited to basic features.                                                           ┃
┗━━━━━━━━━┻━━━━━━━━━━━━━━┻━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
--]]

return {

	--[[ ⛔ BAN DATABASE
	Stores bans in format: ["UserId"] = {Username, Reason, Duration, BannedByUserId}

	Duration values:
		-1: Permanent ban
		0:  Server ban
		>0: Temporary ban (UTC timestamp in seconds for ban expiry)
	]]
	bans = {
		["2"] = { "John Doe", "He been noob.", nil, 44391621 },
		["3"] = { "Jane Doe", "She was noob.", 1720922623, 44391621 },
		["5"] = { nil, "Deleted account", -1, 44391621 },
	},

	-- 👤 USER ROLES - Add roles to users by their UserID or Username
	userRoles = {
		vip = { "Roblox", 156, game.PrivateServerOwnerId },
		mod = {},
		admin = {},
		superadmin = {},
		creator = {},
	},

	-- 📦 ASSET ROLES
	assetRoles = {
		-- [assetId] = { "vip", "mod" },
	},

	-- 💵 GAMEPASS ROLES
	gamepassRoles = {
		-- [gamepassId] = { "vip", "mod" },
	},

	-- 💳 SUBSCRIPTION ROLES
	subscriptionRoles = {
		-- [subscriptionId] = { "vip", "mod" },
	},

	-- 🏢 GROUP ROLES
	groupRoles = {
		-- [groupId] = {
		-- 	{ rank = 200, roles = { "vip", "admin" }, exactRank = false },
		-- },
	},

	-- 👥 FRIEND ROLES
	friendRoles = {
		-- "vip",
	},

	-- 👑 FREE ADMIN ROLES
	freeAdmin = { -- ⚠️ Use with caution as this affects everyone who joins
		-- "vip",
		-- "mod",
		-- "admin",
	},

	-- 🔧 SYSTEM SETTINGS
	prefix = { ";", ":" }, -- The prefix character used to trigger and separate commands (e.g., ";kick noob ;ff me")
	splitKey = "%s", --       The key to split commands and arguments  (e.g., Change to "/" for ";kick/noob/;ff/me")

	chatCommands = true, --        Enables command execution via the Chat
	commandBarRank = 0, --         Minimum rank required to view the Command Bar       (Set to false to disable for everyone)
	dashboardRank = 0, --          Minimum rank required to view the Dashboard         (Set to false to disable for everyone)
	dashboardButtonRank = 0, --    Minimum rank required to view the Dashboard button  (Set to false to disable for everyone)
	joinNotificationRank = 1, --   Minimum rank required to show the join notification (Set to false to disable for everyone)

	onlyShowUsableCommands = false, -- Only displays commands the player can purchase or use
	wrongPrefixWarning = true, --      Warns users when they use the wrong command prefix
	welcomeBadgeId = 0, --             Awards a badge to new players, set to 0 for no badge
	getKohlsAdminPopup = true, --      Enables the "Enjoy Kohl's Admin?" feedback popup to users

	--[[
	changeThemeAuthority:
		"Client" - Clients can change their theme, which will save for future sessions.
		"Server" - Roles with the `settings` permission can change the theme, SuperAdmin+ default.
		"Studio" - Disables changing the theme in-game.
	]]
	changeThemeAuthority = "Client", -- Describes the behavior of changing Theme settings.
	defaultTheme = "Default", -- Changes the initial theme, create your own themes in Config.Themes

	gameHubEnabled = true, -- Adds your to a list of games with Kohl's Admin | ⚠️ Requires "Allow HTTP Requests" in File > Game Settings > Security | https://www.roblox.com/games/17873329124/Kohls-Admin-Games-Hub
	vip = true, --            Enables VIP-specific features and donation support | ⚠️ Required if gameHubEnabled is true

	saveLogs = true, --        Saves and syncs admin logs across multiple servers
	commandRequests = true, -- If commands should be requested on same rank or higher

	commands = { -- Configure command access per role
		everyone = {
			help = true, --      Enable help command
			shutdown = false, -- Disable shutdown capability
		},
		vip = {},
		mod = {},
		admin = {},
		superadmin = {},
		creator = {},
	},

	announcements = {
		-- {
		-- 	From = "_K", --    Set to a userId or "_K"
		-- 	Duration = 30, --  Duration in seconds until the announcement is hidden, set to 0 to not automatically hide
		-- 	Text = "Hi!",
		-- },
	},

	notifications = {
		-- {
		-- 	From = "_K", --    Set to a userId or "_K"
		-- 	Duration = 30, --  Duration in seconds until the notification is hidden, set to 0 to not automatically hide
		-- 	Text = "Hi!",
		-- },
	},

	-- 🎭 ROLE CONFIGURATION
	-- Defines the hierarchy, permissions, and capabilities of each role, you can create as many custom roles as you want!
	roles = {
		{ -- Default Role (Base permissions for all users)
			_key = "everyone", -- DO NOT CHANGE: System identifier

			name = "Player", -- Display name
			color = "#0ff", -- Role color, hex only!

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
				admin = false, --   ⚠️ Complete bypass of all restrictions
				banasync = false, --   Permanent ban capability
				saveRoles = false, --  Role management for lower ranks
				settings = false, --   Global admin settings access
				serverlogs = false, -- Server-side log access
			},

			onlyTargetSelf = true, -- Whether users can ONLY use commands on themselves
		},

		{ -- VIP Role
			_key = "vip", -- DO NOT CHANGE: System identifier
			name = "VIP",
			color = "#0f8",
			groups = { "vip" },
			permissions = {},
			onlyTargetSelf = true,
		},

		{ -- Moderator Role
			_key = "mod", -- DO NOT CHANGE: System identifier
			name = "Moderator",
			color = "#0f0",
			groups = { "moderation", "general", "environment", "fun", "vip" },
			permissions = { serverlogs = true },
		},

		{ -- Administrator Role
			_key = "admin", -- DO NOT CHANGE: System identifier
			name = "Administrator",
			color = "#ff0",
			groups = { "administration", "moderation", "general", "environment", "fun", "vip" },
			permissions = { banasync = true, serverlogs = true },
		},

		{ -- SuperAdmin Role
			_key = "superadmin", -- DO NOT CHANGE: System identifier
			name = "SuperAdmin",
			color = "#f80",
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
