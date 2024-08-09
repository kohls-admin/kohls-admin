local GroupService = game:GetService("GroupService")

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
	bans = {
		-- [UserId] = {Reason, Timestamp, fromUserId}
		-- Username is the last known username of the user when they were banned
		-- TODO: progressively parse and update each name!
		-- if Timestamp is -1 the ban is permanent
		-- if Timestamp is nil the ban is for the server session only
		-- saves only if Timestamp isn't nil
		["2"] = { "He been noob.", nil, 44391621 },
		["3"] = { "She was a noob.", nil, 44391621 },
		["5"] = { "Wow!", 1720922623, 44391621 },
	},
	logs = {},
	members = {
		-- example role data structure
		-- [userid] = {data}
		["1"] = {
			-- last known username? (update over time on init?)
			name = "Roblox",
			roles = { "admin", "vip" },
			persist = {},
		},
	},
	players = {},
	settings = {
		prefix = ":",
		vip = true,
		mutableHooks = false,
	},

	async = {
		gamepass = {},
		-- NOTE: ASSET/SUBS REQUIRE A PLAYER FOR PERMISSIONS AND CAN STILL BE AFFECTED BY ID COMMANDS!
		asset = {},
		subscription = {},
		-- TODO: need a way to define exact rank roles instead of >=
		group = {
			[451053] = {
				{ rank = 1, roles = { "vip" } },
				{ rank = 255, roles = { "creator", "mod" }, exactRank = true },
			},
		},
		-- [groupId] = {
		-- { rank = 200, roles = { "admin", "vip" }, rankAndAbove = true },
		-- },
	},
	defaultRole = {
		-- role "_rank" determines hierarchy
		-- 0 is reserved for the default role
		_rank = 0,
		name = "Player",
		color = "#0ff",

		-- STAFF PERMISSIONS (anyone with one of these permissions will be saved to the list of staff)

		-- this permission bypasses all restrictions (danger!)
		admin = false,
		-- can PERMANENTLY ban users from the game
		ban = false,
		-- can kick or ban users from the current server session
		kick = false,
		-- allows the user to manage roles of other users with a lesser role
		roles = false,
		-- can configure the global admin settings
		settings = false,
		-- can view audit logs
		logs = false,

		-- COSMETIC PERMISSIONS
		-- can use commands that require VIP permission
		vip = false,

		-- allowed command groups?
		groups = {
			-- "administration",
			-- "moderation",
			-- "general",
			"utility",
		},

		-- command name/alias filter
		filter = {
			-- allows the help command unless it's disabled
			help = true,
			-- prevents the use of the kill command
			kill = false,
		},
	},
	roles = {
		-- unique key should NEVER be changed or you may lose save data
		vip = {
			_rank = 1,
			name = "VIP",
			vip = true,
			color = "#0f8",
		},
		mod = {
			_rank = 2,
			name = "Moderator",
			kick = true,
			logs = true,
			groups = { "moderation", "general" },
			color = "#0f0",
		},
		admin = {
			_rank = 3,
			name = "Administrator",
			ban = true,
			kick = true,
			roles = true,
			logs = true,
			groups = { "administration", "moderation", "general" },
			color = "#ff0",
		},
		superadmin = {
			_rank = 4,
			name = "SuperAdmin",
			ban = true,
			kick = true,
			roles = true,
			logs = true,
			settings = true,
			groups = { "creator", "administration", "moderation", "general" },
			color = "#f80",
		},
		-- FIXME should this be defined and configurable? (or should it just be forced...)
		creator = {
			_rank = math.huge,
			name = "Game Creator",
			admin = true,
			color = "#f00",
		},
	},

	gameClosing = false,
	pendingSaveMain = false,
	pendingSaveLogs = false,

	banHandler = nil,
	banUser = nil,
	initialize = nil,
	Store = nil,
}

Data.roles.defaultRole = Data.defaultRole

-- assign CreatorId
if game.CreatorType == Enum.CreatorType.Group then
	local ok, result = pcall(GroupService.GetGroupInfoAsync, GroupService, game.CreatorId)
	if ok then
		Data.creatorId = result.Owner.Id
	end
else
	Data.creatorId = game.CreatorId
end

return Data
