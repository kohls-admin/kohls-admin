-- IMPORTANT: ONLY USE ONE LOADER OR THE OTHER!

-- Use usernames or userIds to add a user to a list
-- For example;	Admins = {'MyBestFriend', 'Telamon', 261}

local Banned = { "someoneyoudislike" } -- For those who have wronged you, & this guy

--------------------------------------------------------------
-- You DO NOT need to add yourself to any of these lists!!! --
--------------------------------------------------------------

local Owners = {} -- Can set SuperAdmins, & use all the commands
local SuperAdmins = {} -- Can set permanent admins, & shutdown the game
local Admins = {} -- Can ban, crash, & set Moderators/VIP
local Mods = {} -- Can kick, mute, & use most commands
local VIP = {} -- Can use nonabusive commands only on self

local Settings = {

	-- Style Options
	Flat = true, -- Enables Flat theme / Disables Aero theme
	ForcedColor = false, -- Forces everyone to have set color & transparency
	Color = Color3.new(0, 0, 0), -- Changes the Color of the user interface
	ColorTransparency = 0.75, -- Changes the Transparency of the user interface
	Chat = false, -- Enables the custom chat
	BubbleChat = false, -- Enables the custom bubble chat

	-- Basic Settings
	AdminCredit = true, -- Enables the credit GUI for that appears in the bottom right
	AutoClean = false, -- Enables automatic cleaning of hats & tools in the Workspace
	AutoCleanDelay = 60, -- The delay between each AutoClean routine
	CommandBar = true, -- Enables the Command Bar | GLOBAL KEYBIND: \
	FunCommands = true, -- Enables fun yet unnecessary commands
	FreeAdmin = false, -- Set to 1-5 to grant admin powers to all, otherwise set to false
	JoinMessage = true, -- Shows an admin message on join with the prefix and your current rank
	PublicLogs = false, -- Allows all users to see the command & chat logs
	Prefix = ";", -- Character to begin a command

	--[[
		Admin Powers

	0			Player
	1			VIP					Can use nonabusive commands only on self
	2			Moderator			Can kick, mute, & use most commands
	3			Administrator		Can ban, crash, & set Moderators/VIP
	4			SuperAdmin			Can grant permanent powers, & shutdown the game
	5			Owner				Can set SuperAdmins, & use all the commands
	6			Game Creator		Can set owners & use all the commands

		Group & VIP Admin

			You can set multiple Groups & Ranks to grant users admin powers:

	GroupAdmin = {
		[12345] = { [254] = 4, [253] = 3 };
		[GROUP_ID] = { [RANK] = ADMIN_POWER };
	};

			You can set multiple Assets to grant users admin powers:

	VIPAdmin = {
		[-12345] = 3; -- negative item_id (-12345) indicates a GamePass
		[12345] = 3; -- positive is every other catalog asset (shirts, pants, hats, etc)
		[54321] = 4;
		[ITEM_ID] = ADMIN_POWER;
	};
								]]
	GroupAdmin = {},

	VIPAdmin = {},

	-- Command Limits
	-- COMMAND_LIMIT    - How many commands can be used at once to prevent abuse.
	-- COOLDOWN_SECONDS - How long to wait between commands to prevent abuse.
	-- [ADMIN_POWER]= { COMMAND_LIMIT, COOLDOWN_SECONDS }
	CommandLimits = {
		[0] = { 1, 10 }, -- Player (rank 0) can use 1 command every 10 seconds
		[1] = { 16, 5 }, -- VIP (rank 1) can use 10 commands every 5 seconds
		[2] = { 32, 1 }, -- Moderator (rank 2) can use 16 commands every 1 second
		[3] = { 64, 1 }, -- Administrator (rank 3) can use 32 commands every 1 second
		[4] = { 128, 1 }, -- SuperAdmin (rank 4) can use 64 commands every 1 second
		[5] = { math.huge, 0 }, -- Owner (rank 5) can use infinite commands every 0 seconds
		[6] = { math.huge, 0 }, -- Game Creator (rank 6) can use infinite commands every 0 seconds
		[7] = { math.huge, 0 }, -- True Game Creator (rank 7) can use infinite commands every 0 seconds
	},

	-- Permissions
	-- The admin
	-- COMMAND_NAME = ADMIN_POWER;
	Permissions = {
		-- fly = 0; -- uncomment this line to allow everyone to fly!
	},
}

return { Settings, { Owners, SuperAdmins, Admins, Mods, VIP, Banned } }
