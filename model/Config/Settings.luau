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

	-- ⛔ BAN DATABASE
	-- Format: ["UserId"] = {Username, Reason, Duration, BannedByUserId}
	-- Duration: -1 = permanent, 0 = server ban, >0 = temp ban (UTC timestamp)
	bans = {
		["2"] = { "John Doe", "He been noob.", 0, 44391621 },
		["3"] = { "Jane Doe", "She was noob.", 1720922623, 44391621 },
	},

	-- 👤 USER ROLES - Assign roles by UserId or Username
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

	-- 👑 FREE ADMIN ROLES - ⚠️ Affects all players
	freeAdmin = {
		-- "vip",
		-- "mod",
		-- "admin",
	},

	announcements = {
		-- {
		-- 	From = "_K", -- userId or "_K"
		-- 	Duration = 30, -- seconds, 0 = no auto-hide
		-- 	Text = "Hi!",
		-- },
	},

	notifications = {
		-- {
		-- 	From = "_K", -- userId or "_K"
		-- 	Duration = 30, -- seconds, 0 = no auto-hide
		-- 	Text = "Hi!",
		-- },
	},

	-- 🔧 SYSTEM SETTINGS
	prefix = { ";", ":" }, -- Command trigger characters
	splitKey = "%s", --       Command/argument separator

	chatCommands = true, --      Enable commands via chat
	commandBarRank = 0, --       Minimum rank for Command Bar (false = disable)
	dashboardRank = 0, --        Minimum rank for Dashboard (false = disable)
	dashboardButtonRank = 0, --  Minimum rank for Dashboard button (false = disable)
	joinNotificationRank = 1, -- Minimum rank for join notifications (false = disable)

	onlyShowUsableCommands = false, -- Show only purchasable/usable commands
	wrongPrefixWarning = true, --      Warn on incorrect prefix
	welcomeBadgeId = 0, --             Badge for new players (0 = none)
	getKohlsAdminPopup = true, --      Show feedback popup

	changeThemeAuthority = "Client", -- "Client", "Server", or "Studio"
	defaultTheme = "Default", --        Initial theme (customize in Config.Themes)

	gameHubEnabled = true, -- Add to games list   (requires HTTP requests enabled)
	vip = true, --            Enable VIP features (required if gameHubEnabled = true)

	saveLogs = true, --        Save/sync logs across servers
	commandRequests = true, -- Request commands on same/higher rank

	commands = { -- Configure command access per role
		everyone = {
			help = true,
			shutdown = false,
		},
		vip = {},
		mod = {},
		admin = {},
		superadmin = {},
		creator = {},
	},

	-- 🎭 ROLE CONFIGURATION
	roles = {
		{ -- Default Role
			_key = "everyone", -- ⚠️ DO NOT CHANGE

			name = "Player",
			color = "#0ff", -- Hex color only

			groups = {
				-- "creator", --        clearlogs, hidelogs, script, localscript, etc.
				-- "superadmin", --     badge, clearterrain, reserve, shutdown, global, etc.
				-- "administration", -- announce, role, btools, gear, insert, place, serverlock, etc.
				-- "moderation", --     ban, kick, jail, teleport, mute, warnings, etc.
				-- "environment", --    fix, lighting, gravity, wind, water, atmosphere, etc.
				-- "general", --        respawn, refresh, spectate, view, vote, xray, etc.
				-- "fun", --            disco, explode, clone, punish, zombie, etc. (abusive)
				-- "vip", --            appearance, accessories, animations, particles, etc.
				"utility", --           help, version, info, logs, etc. (safe basics)
			},

			limits = {
				cooldown = 4, -- Cooldown period in seconds
				commands = 4, -- Max commands per cooldown
				targets = 1, --  Max targets per command
			},

			permissions = {
				admin = false, --   ⚠️ Bypasses all permissions
				banasync = false, --   Saved bans
				saveRoles = false, --  Saved roles
				settings = false, --   Saved settings
				serverlogs = false, -- Server logs
			},

			onlyTargetSelf = true, -- Can only use commands on self
		},

		{ -- VIP Role
			_key = "vip", -- ⚠️ DO NOT CHANGE
			name = "VIP",
			color = "#0f8",
			groups = { "vip" },
			limits = { cooldown = 4, commands = 16, targets = 1 },
			permissions = {},
			onlyTargetSelf = true,
		},

		-- 🎭 Create as many roles as you want!
		-- Use the _key in other settings like friendRoles to auto give the role
		-- Helper would be higher rank than VIP, and lower than moderator

		-- {
		-- 	_key = "helper",
		-- 	name = "Helper",
		-- 	color = "#080",
		-- 	groups = { "general" },
		-- 	limits = { cooldown = 4, commands = 32, targets = math.huge },
		-- 	permissions = { serverlogs = true },
		-- },

		{ -- Moderator Role
			_key = "mod", -- ⚠️ DO NOT CHANGE
			name = "Moderator",
			color = "#0f0",
			groups = { "moderation", "general", "environment", "fun", "vip" },
			limits = { cooldown = 4, commands = 32, targets = math.huge },
			permissions = { serverlogs = true },
		},

		{ -- Administrator Role
			_key = "admin", -- ⚠️ DO NOT CHANGE
			name = "Administrator",
			color = "#ff0",
			groups = { "administration", "moderation", "general", "environment", "fun", "vip" },
			limits = { cooldown = 4, commands = 64, targets = math.huge },
			permissions = { banasync = true, serverlogs = true },
		},

		{ -- SuperAdmin Role
			_key = "superadmin", -- ⚠️ DO NOT CHANGE
			name = "SuperAdmin",
			color = "#f80",
			groups = { "superadmin", "administration", "moderation", "general", "environment", "fun", "vip" },
			permissions = { banasync = true, saveRoles = true, settings = true, serverlogs = true },
		},

		[math.huge] = { -- Creator Role (Highest Authority)
			_key = "creator", -- ⚠️ DO NOT CHANGE
			name = "Game Creator",
			color = "#f00",
			permissions = { admin = true },
		},
	},
}
