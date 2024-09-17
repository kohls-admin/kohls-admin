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
	Kohl's Admin VIP Game Catalog Integration

	Enables participation in the Kohl's Admin VIP game catalog, showcasing
	your game to VIP users looking for games with Kohl's Admin.

	⚠️ IMPORTANT: Allow HTTP Requests in Game Settings -> Security

	The catalog updates every 6 hours, check it out below;
	https://www.roblox.com/games/17873329124/
	]]
	vipGameCatalogEnabled = true,

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

	roles = {
		-- accepts a list of userids
		creator = {},
		superadmin = {},
		admin = {},
		mod = {},
		vip = {},
	},

	-- TODO: theme configuration
	-- TODO: command permissions and role definitions
}

return Settings
