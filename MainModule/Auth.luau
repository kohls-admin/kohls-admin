local GroupService = game:GetService("GroupService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local TextService = game:GetService("TextService")

local Data = require(script.Parent.Data)
local Remote = require(script.Parent.Remote)
local Util = require(script.Parent.Util)

export type Role = "vip" | "mod" | "admin" | "superadmin" | "creator"

--- @class Auth
local Auth = {
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
	-- role definition
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

	members = {
		-- example role data structure
		-- [userid] = {data}
		["1"] = {
			-- last known username? (update over time on init?)
			name = "Roblox",
			roles = { "admin", "vip" },
		},
	},
}

if game.CreatorId > 0 then
	Auth.members[tostring(game.CreatorId)] = {
		name = game:GetService("Players"):GetNameFromUserIdAsync(game.CreatorId),
		roles = { "creator" },
	}
end

function Auth.banHandler(player)
	local banInfo = Data.bans[player.UserId]
	-- TODO: should staff roles bypass bans? add a settings toggle
	if not banInfo or player.UserId == _K.creatorId then
		-- not banned
		return
	end

	local reason, timeStamp = unpack(banInfo, 2)
	local banMessage
	if tonumber(timeStamp) then
		if timeStamp > 0 then
			local timeRemaining = timeStamp - os.time()
			if timeRemaining > 0 then
				banMessage = "You are banned from this experience for " .. Util.ReadableTime(timeRemaining) .. "!"
			else
				-- unbanning
				Data.bans[player.UserId] = nil
				return
			end
		else
			banMessage = "You are permanently banned from this experience!"
		end
	else
		banMessage = "You are banned from this server!"
	end

	player:Kick(if reason then banMessage .. "\n Reason: " .. reason else banMessage)
	return true
end

--- Generic ban handler
function Auth.userBan(
	userId: number,
	name: string,
	reason: string,
	duration: number,
	fromUserId: number,
	fromName: string
)
	Data.bans[tostring(userId)] = { name, reason, duration, fromUserId, fromName }
	-- network ban to all with filtered season?
	-- _K.filterMessage(reason, fromUserId or game.CreatorId, )
	local ok, result =
		pcall(TextService.FilterStringAsync, TextService, reason, fromUserId, Enum.TextFilterContext.PrivateChat)
	if ok then
		for _, player in Players:GetPlayers() do
			local _, filtered = pcall(result.GetChatForUserAsync, result, player.UserId)
			Remote.Ban:FireClient(player, userId, { name, filtered, duration, fromUserId, fromName })
		end
	end
end

--- Adds a role to a user if they don't already have it
-- TODO: make a way to define permanent vs temporary roles
function Auth.userRoleAdd(userId: number, role: Role)
	local member = Auth.members[tostring(userId)]
	if not member then
		local player = Players:GetPlayerByUserId(userId)
		Auth.members[tostring(userId)] = {
			name = if player then player.name else Players:GetNameFromUserIdAsync(userId),
			roles = { role },
		}
	else
		if not table.find(member.roles, role) then
			table.insert(member.roles, role)
			table.sort(member.roles, roleSort)
		end
	end
end

--- Removes a role from a user if it exists
function Auth.userRoleRemove(userId: number, role: Role)
	local member = Auth.members[tostring(userId)]
	if member then
		local index = table.find(member.roles, role)
		if index then
			table.remove(member, index)
		end
	end
end

local asyncRolesCache = {}
function Auth.userAsyncRoles(userId: number, flushCache: boolean?)
	if asyncRolesCache[userId] and not flushCache then
		return
	end
	asyncRolesCache[userId] = true

	-- gamepass permissions
	for gamePassId, roles in Auth.async.gamepass do
		if MarketplaceService:UserOwnsGamePassAsync(userId, gamePassId) then
			for _, role in roles do
				Auth.userRoleAdd(userId, role)
			end
		end
	end

	-- group permissions
	if next(Auth.async.group) then
		local groups = GroupService:GetGroupsAsync(userId)
		for _, group in groups do
			local groupAuth = Auth.async.group[group.Id]
			if groupAuth then
				for _, auth in groupAuth do
					if group.Rank == auth.rank or (not auth.exactRank and group.Rank >= auth.rank) then
						for _, role in auth.roles do
							Auth.userRoleAdd(userId, role)
						end
					end
				end
			end
		end
	end

	-- the following requires a player instance
	local player = Players:GetPlayerByUserId(userId)
	if not player then
		return
	end

	-- legacy asset permissions
	for assetId, roles in Auth.async.asset do
		if MarketplaceService:PlayerOwnsAsset(player, assetId) then
			for _, role in roles do
				Auth.userRoleAdd(userId, role)
			end
		end
	end

	-- subscription permissions
	for subscriptionId, roles in Auth.async.subscription do
		local ok, result =
			pcall(MarketplaceService.GetUserSubscriptionStatusAsync, MarketplaceService, player, subscriptionId)
		if ok and result.IsSubscribed then
			for _, role in roles do
				Auth.userRoleAdd(userId, role)
			end
		end
	end
end

--- Checks the maximum role rank of the user, if permission is given it will fetch the highest rank of the roles with that permission
function Auth.getRank(userId: number, permission: string?): (number, Role)
	Auth.userAsyncRoles(userId)
	permission = permission or "_rank"
	local rank, rankRole = 0, Auth.defaultRole
	local member = Auth.members[tostring(userId)]
	if member then
		for _, roleId in member.roles do
			local role = Auth.roles[roleId]
			if role and role[permission] then
				rank = math.max(rank, role._rank)
				rankRole = role
			end
		end
	end
	return rank, rankRole
end

--- Checks if a user has access to a command group
function Auth.hasCommandGroup(userId: number, group: string): boolean
	group = string.lower(group)
	if Auth.defaultRole.admin or (Auth.defaultRole.groups and table.find(Auth.defaultRole.groups, group)) then
		return true
	end
	local member = Auth.members[tostring(userId)]
	if member then
		if member.permissions and member.permissions.admin then
			return true
		end
		for _, roleId in member.roles do
			local role = Auth.roles[roleId]
			if not role then
				warn("undefined role?", role)
				continue
			end
			if role.admin or (role.groups and table.find(role.groups, group)) then
				return true
			end
		end
	end
	return false
end

--- Checks if a user has access to a permission
function Auth.hasPermission(userId: number, permission: string): boolean
	-- does everyone have the permission?
	if Auth.defaultRole[permission] or Auth.defaultRole.admin then
		return true
	end
	local member = Auth.members[tostring(userId)]
	if member then
		if member.permissions and (member.permissions.admin or member.permissions[permission]) then
			return true
		end
		for _, roleId in member.roles do
			local role = Auth.roles[roleId]
			if role and (role.admin or role[permission]) then
				return true
			end
		end
	end
	return false
end

--- Gets the difference of two users' ranks, with an optional permission parameter
function Auth.rankDiff(userIdFrom: number, userIdTo: number, permission: string?)
	return Auth.getRank(userIdFrom, permission) - Auth.getRank(userIdTo, permission)
end

return Auth
