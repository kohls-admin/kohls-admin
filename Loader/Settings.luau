local Settings = {

	-- Auto updates via require, disable to use the included MainModule
	autoUpdate = true,

	-- MAKE SURE TO CHANGE THIS FOR IMPROVED SECURITY!
	-- Using Roblox secrets via HttpService:GetSecret recommended!
	dataStoreKey = "CHANGE_THIS",

	-- Changes the default command prefix
	prefix = ";",

	-- Enables Kohl's Admin VIP donation features
	vip = true,

	--[[
	Enables participation in the Kohl's Admin Games Hub, showcasing
	your game to users looking for games with benefits from Kohl's Admin.
	https://www.roblox.com/games/17873329124/Kohls-Admin-Games-Hub

	⚠️ IMPORTANT: Allow HTTP Requests in Game Settings -> Security
	]]
	gameHubEnabled = true,

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
		-- { rank = 200, roles = { "admin", "vip" }, exactRank = true },
		-- },
	},

	--[[
	Accepts a list of UserIds, sourced from a Roblox profile
		For example;
			https://www.roblox.com/users/44391621/profile
			Has a UserId of 44391621
		Use "game.PrivateServerOwnerId" for private servers!
	]]
	roles = {
		creator = {},
		superadmin = {},
		admin = {},
		mod = {},
		vip = { 1, 156, game.PrivateServerOwnerId },
	},

	--[[
	Toggles visibility of the Kohl's Admin Dashboard Button in the Topbar.
		0	default
		1	vip
		2	mod
		3	admin
		4	superadmin
		5	creator
	]]
	dashboardButtonRank = 0,

	-- TODO: theme configuration
	-- Toggles visibility of the Kohl's Admin Join Notification.
	joinNotificationRank = 1,

	-- TODO: command/member permissions and role definitions
}

return Settings
