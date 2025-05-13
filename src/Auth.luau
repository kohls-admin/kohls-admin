local GroupService = game:GetService("GroupService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local Data = require(script.Parent.Data.Defaults)
local Hook = require(script.Parent.Hook)
local Registry = require(script.Parent.Registry)
local Remote = require(script.Parent.Remote)
local Util = require(script.Parent.Util)

export type Role = "default" | "vip" | "mod" | "admin" | "superadmin" | "creator" | string

--- @class Auth
local Auth = {}

function Auth.roleSort(a: Role, b: Role): boolean
	return Data.roles[a]._rank > Data.roles[b]._rank
end

function Auth.banHandler(player)
	local key = tostring(player.UserId)
	local banInfo = Data.bans[key]

	if player.UserId == Data.creatorId or player.UserId < 1 then
		return -- not banned
	end

	if not Util.Services.RunService:IsStudio() then
		local banHistory = Players:GetBanHistoryAsync(player.UserId)
		if banHistory then
			local items = banHistory:GetCurrentPage()
			local last = items[1]

			if last and not last.Ban and banInfo and banInfo[3] ~= 0 then
				Auth.unbanUsers({ player.UserId }, nil, true)
				return -- unbanned from site
			end
		end
	end

	if not banInfo then
		return -- not banned
	end

	local _name, reason, timeStamp = unpack(banInfo)
	local banMessage
	if tonumber(timeStamp) then
		if timeStamp > 0 then
			local timeRemaining = timeStamp - os.time()
			if timeRemaining > 0 then
				banMessage = "You are banned from this experience for " .. Util.ReadableTime(timeRemaining) .. "!"
			else
				Auth.unbanUsers({ player.UserId }, nil, true)
				return -- duration has passed, unbanned
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

function Auth.banUsers(
	userIds: { number },
	reason: string,
	duration: number?,
	fromUserId: number?,
	forceBanAsync: boolean?
)
	local banAsync = forceBanAsync or not fromUserId or Auth.hasPermission(fromUserId, "banasync")

	if not banAsync then
		duration = 0
	end

	local timestamp
	if duration and duration ~= 0 then
		timestamp = if duration > 0 then os.time() + duration else -1
	end

	for _, userId in userIds do
		local ban = { Util.getUserInfo(userId).Username, reason, timestamp, fromUserId }

		local key = tostring(userId)
		Data.bans[key] = ban
		if timestamp then
			Data.Cache.bans[key] = ban
		end

		for _, player in Players:GetPlayers() do
			if Auth.hasCommand(player.UserId, "ban") then
				Remote.Ban:FireClient(player, key, ban)
			end
		end
	end

	if banAsync and timestamp then
		Players:BanAsync({
			UserIds = userIds,
			PrivateReason = reason or "No reason.",
			DisplayReason = reason or "No reason.",
			Duration = duration,
			ApplyToUniverse = true,
		})
	end
end

function Auth.unbanUsers(userIds: { number }, fromUserId: number?, forceBanAsync: boolean?)
	local banAsync = forceBanAsync or not fromUserId or Auth.hasPermission(fromUserId, "banasync")

	for _, userId in userIds do
		local key = tostring(userId)
		Data.bans[key] = nil

		if banAsync then
			Data.Cache.bans[key] = false
		end

		for _, player in Players:GetPlayers() do
			if Auth.hasCommand(player.UserId, "ban") then
				Remote.Ban:FireClient(player, key)
			end
		end
	end

	if forceBanAsync then -- for non command calls
		Players:UnbanAsync({ UserIds = userIds, ApplyToUniverse = true })
	end
end

function Auth.networkMember(userId: number)
	local userIdString = tostring(userId)
	local member = Data.members[userIdString]
	for _, player in Players:GetPlayers() do
		if player.UserId == userId or Auth.hasCommand(player.UserId, "members") then
			Remote.Member:FireClient(player, userIdString, member)
		end
	end
end

local function cacheMember(key, userId)
	Data.Cache.members[key] = { Util.getUserInfo(userId).Username, Data.members[key].persist }
end

local function updateMemberName(member, userId)
	member.name = Util.getUserInfo(userId).Username
end

--- Adds a role to a user if they don't already have it
function Auth.userRoleAdd(userId: number, role: Role, persist: boolean?): boolean
	local key = tostring(userId)
	local member = Data.members[key]
	local roleAdded = false

	if not member then
		member = {
			name = nil,
			roles = { role },
			persist = { if persist then role else nil },
		}
		Data.members[key] = member
		roleAdded = true

		task.spawn(updateMemberName, member, userId)
	else
		if not table.find(member.roles, role) then
			table.insert(member.roles, role)
			table.sort(member.roles, Auth.roleSort)
			if persist then
				table.insert(member.persist, role)
				table.sort(member.persist, Auth.roleSort)
			end
			roleAdded = true
		end
	end

	if roleAdded then
		if persist then
			task.spawn(cacheMember, key, userId)
		end

		Hook.roleAdded:Fire(userId, role)
		Auth.networkMember(userId)
	end

	return roleAdded
end

--- Removes a role from a user if it exists
function Auth.userRoleRemove(userId: number, role: Role): boolean
	local key = tostring(userId)
	local member = Data.members[key]
	local roleRemoved = false
	local persistent = false

	if member then
		local index = table.find(member.roles, role)
		if index then
			table.remove(member.roles, index)
			roleRemoved = true
		end
		index = table.find(member.persist, role)
		if index then
			table.remove(member.persist, index)
			roleRemoved = true
			persistent = true
		end
	end

	if roleRemoved then
		if #member.roles == 0 then
			Data.members[key] = nil
		end

		if persistent then
			if #member.persist == 0 then
				Data.Cache.members[key] = false
			else
				task.spawn(cacheMember, key, userId)
			end
		end

		Hook.roleRemoved:Fire(userId, role)
		Auth.networkMember(userId)
	end

	return roleRemoved
end

local asyncRolesCache = {}
function Auth.userAsyncRoles(userId: number, flushCache: boolean?)
	local success = true
	if asyncRolesCache[userId] and not flushCache then
		return
	end
	asyncRolesCache[userId] = true

	-- gamepass permissions
	for gamePassId, roles in Data.async.gamepass do
		local ok, result = Util.Retry(function()
			return MarketplaceService:UserOwnsGamePassAsync(userId, gamePassId)
		end)
		if ok and result then
			for _, role in roles do
				Auth.userRoleAdd(userId, role)
			end
		end
		if not ok then
			success = false
		end
	end

	-- group permissions
	if next(Data.async.group) then
		local ok, groups = Util.Retry(function()
			return GroupService:GetGroupsAsync(userId)
		end)
		if ok then
			for _, group in groups do
				local groupAuth = Data.async.group[group.Id]
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
		if not ok then
			success = false
		end
	end

	-- the following requires a player instance
	local player = Players:GetPlayerByUserId(userId)
	if not player then
		return
	end

	if Data.settings.vip then
		local level = player:GetAttribute("_KDonationLevel")
		if not level then
			player:GetAttributeChangedSignal("_KDonationLevel"):Wait()
			level = player:GetAttribute("_KDonationLevel")
		end
		if level > 0 then
			Auth.userRoleAdd(userId, "vip")
		end
	end

	-- legacy asset permissions
	for assetId, roles in Data.async.asset do
		local ok, result = Util.Retry(function()
			return MarketplaceService:PlayerOwnsAsset(player, assetId)
		end)
		if ok and result then
			for _, role in roles do
				Auth.userRoleAdd(userId, role)
			end
		end
		if not ok then
			success = false
		end
	end

	-- subscription permissions
	for subscriptionId, roles in Data.async.subscription do
		local ok, result = Util.Retry(function()
			return MarketplaceService:GetUserSubscriptionStatusAsync(player, subscriptionId)
		end)
		if ok and result.IsSubscribed then
			for _, role in roles do
				Auth.userRoleAdd(userId, role)
			end
		end
		if not ok then
			success = false
		end
	end

	return success
end

--- Checks the maximum role rank of the user, if permission is given it will fetch the highest rank of the roles with that permission
function Auth.getRank(userId: number, permission: string?): (number, Role)
	local rank, rankRole = 0, Data.roles.default
	local member = Data.members[tostring(userId)]
	if member then
		for _, roleId in member.roles do
			local role = Data.roles[roleId]
			if role and (not permission or role.permissions[permission]) and role._rank > rank then
				rank = role._rank
				rankRole = role
			end
		end
	end
	return rank, rankRole
end

--- Checks if a role has access to a command argument
function Auth.roleCanUseArgument(role: Role, argument: any): boolean
	local roleData = Data.roles[role]
	if not roleData then
		warn(`undefined role "{role}"`)
		return false
	end

	-- admins always have access
	if roleData.permissions.admin then
		return true
	end

	-- argument definition permissions against role
	if argument.permissions then
		for permission, value in argument.permissions do
			if roleData.permissions[permission] ~= value then
				return false
			end
		end
	end

	return true
end

--- Checks if a user has access to a command argument
function Auth.hasArgument(userId: number, argument: any): boolean
	if Auth.roleCanUseArgument("default", argument) then
		return true
	end

	local member = Data.members[tostring(userId)]
	if member then
		if member.permissions and member.permissions.admin then
			return true
		end
		for _, role in member.roles do
			local roleData = Data.roles[role]
			if not roleData then
				warn(`undefined role "{role}"`)
				continue
			end
			if Auth.roleCanUseArgument(role, argument) then
				return true
			end
		end
	end
	return false
end

--- Checks if a role has access to a command
function Auth.roleCanUseCommand(role: Role, command: any): boolean
	local roleData = Data.roles[role]
	if not roleData then
		warn(`undefined role "{role}"`)
		return false
	end

	local rawCommand = command
	if type(command) == "string" then
		command = Registry.commands[string.lower(command)]
	end

	if type(command) ~= "table" then
		error(`Invalid command: {tostring(rawCommand)}`, 2)
	end

	-- admins always have access
	if roleData.permissions and roleData.permissions.admin then
		return true
	end

	-- command definition permissions against role
	if command.permissions then
		for permission, value in command.permissions do
			if roleData.permissions[permission] ~= value then
				return false
			end
		end
	end

	-- command permission override
	if roleData.commands then
		local override = roleData.commands[command.name]
		if override ~= nil then
			return override
		end
		if command.aliases then
			for _, alias in command.aliases do
				local aliasOverride = roleData.commands[alias]
				if aliasOverride ~= nil then
					return aliasOverride
				end
			end
		end
	end

	-- role has command group
	if command and roleData.groups and command.group and table.find(roleData.groups, string.lower(command.group)) then
		return true
	end

	return false
end

--- Checks if a user has access to a command
function Auth.hasCommand(userId: number, command: any): boolean
	if type(command) == "string" then
		command = Registry.commands[string.lower(command)]
	end

	if Auth.roleCanUseCommand("default", command) then
		return true
	end

	local member = Data.members[tostring(userId)]
	if member then
		if member.permissions and member.permissions.admin then
			return true
		end

		if member.commands then
			local override = member.commands[command.name]
			if override ~= nil then
				return override
			end
			if command.aliases then
				for _, alias in command.aliases do
					local aliasOverride = member.commands[alias]
					if aliasOverride ~= nil then
						return aliasOverride
					end
				end
			end
		end

		for _, role in member.roles do
			local roleData = Data.roles[role]
			if not roleData then
				warn(`undefined role "{role}"`)
				continue
			end
			if Auth.roleCanUseCommand(role, command) then
				return true
			end
		end
	end
	return false
end

--- Checks if a user has access to a permission
function Auth.hasPermission(userId: number, permission: string): boolean
	-- does everyone have the permission?
	if Data.roles.default.permissions[permission] or Data.roles.default.permissions.admin then
		return true
	end
	local member = Data.members[tostring(userId)]
	if member then
		if member.permissions and (member.permissions.admin or member.permissions[permission]) then
			return true
		end
		for _, roleId in member.roles do
			local role = Data.roles[roleId]
			if role and (role.permissions.admin or role.permissions[permission]) then
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
