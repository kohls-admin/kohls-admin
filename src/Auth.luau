local Data = require(script.Parent.Data.Defaults)
local Hook = require(script.Parent.Hook)
local Registry = require(script.Parent.Registry)
local Remote = require(script.Parent.Remote)
local Util = require(script.Parent.Util)

export type Role = "everyone" | "vip" | "mod" | "admin" | "superadmin" | "creator" | string

--- @class Auth
local Auth = {}

-- BAN FUNCTIONS

function Auth.banHandler(player)
	local key = tostring(player.UserId)
	local banInfo = Data.bans[key]

	if player.UserId == Data.creatorId or player.UserId < 1 then
		return -- not banned
	end

	if not Util.Service.Run:IsStudio() then
		local banHistory = Util.Service.Players:GetBanHistoryAsync(player.UserId)
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
		for _, player in Util.Service.Players:GetPlayers() do
			if Auth.hasCommand(player.UserId, "ban") then
				Remote.Ban:FireClient(player, key, ban)
			end
		end
	end

	if banAsync and timestamp and not Data.SEPARATE_DATASTORE then
		Util.Service.Players:BanAsync({
			UserIds = userIds,
			PrivateReason = reason or "No reason.",
			DisplayReason = reason or "No reason.",
			Duration = duration,
			ApplyToUniverse = true,
		})
	end
end

function Auth.unbanUsers(userIds: { number }, fromUserId: number?, forceBanAsync: boolean?)
	for index, userId in userIds do
		local number = tonumber(userId)
		if number then
			userIds[index] = number
		end
		local key = tostring(userId)
		Data.bans[key] = nil
		Data.Cache.bans[key] = Data.REMOVE
		for _, player in Util.Service.Players:GetPlayers() do
			if Auth.hasCommand(player.UserId, "ban") then
				Remote.Ban:FireClient(player, key)
			end
		end
	end

	if not Data.SEPARATE_DATASTORE then
		Util.Service.Players:UnbanAsync({ UserIds = userIds, ApplyToUniverse = true })
	end
end

-- ROLE FUNCTIONS

local function saveMember(key, userId)
	Data.Cache.members[key] = { Util.getUserInfo(userId).Username, Data.members[key].persist }
end

function Auth.networkMember(userId: number)
	local userIdString = tostring(userId)
	local member = Data.members[userIdString]
	for _, player in Util.Service.Players:GetPlayers() do
		if player.UserId == userId or Auth.hasCommand(player.UserId, "members") then
			Remote.Member:FireClient(player, userIdString, member)
		end
	end
end

local function updateMemberName(member, userId)
	member.name = Util.getUserInfo(userId).Username
	Auth.networkMember(userId)
end

--- Sorts roleIds by highest to lowest
function Auth.roleIdSort(a: Role, b: Role): boolean
	return Data.roles[a]._rank > Data.roles[b]._rank
end

--- Sorts roleIds by lowest to highest
function Auth.roleIdSortAscending(a: Role, b: Role): boolean
	return Data.roles[a]._rank < Data.roles[b]._rank
end

--- Adds a role to a user if they don't already have it
function Auth.userRoleAdd(userId: number, roleId: Role, persist: boolean?): boolean
	local key = tostring(userId)
	local member = Data.members[key]
	local roleAdded = false

	if not member then
		member = {
			name = nil,
			roles = { roleId },
			persist = { if persist then roleId else nil },
		}
		Data.members[key] = member
		roleAdded = true
		task.spawn(updateMemberName, member, userId)
	else
		if not table.find(member.roles, roleId) then
			table.insert(member.roles, roleId)
			table.sort(member.roles, Auth.roleIdSort)
			roleAdded = true
		end
		if persist and not table.find(member.persist, roleId) then
			table.insert(member.persist, roleId)
			table.sort(member.persist, Auth.roleIdSort)
			roleAdded = true
		end
	end

	if roleAdded then
		if persist then
			task.spawn(saveMember, key, userId)
		end
		Hook.roleAdded:Fire(userId, roleId)
		if not member.name then
			task.spawn(updateMemberName, member, userId)
		else
			Auth.networkMember(userId)
		end
	end

	return roleAdded
end

--- Removes a role from a user if it exists
function Auth.userRoleRemove(userId: number, roleId: Role): boolean
	local key = tostring(userId)
	local member = Data.members[key]
	local roleRemoved = false
	local persistent = false

	if member then
		local index = table.find(member.roles, roleId)
		if index then
			table.remove(member.roles, index)
			roleRemoved = true
		end
		index = table.find(member.persist, roleId)
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
				Data.Cache.members[key] = Data.REMOVE
			else
				task.spawn(saveMember, key, userId)
			end
		end
		Hook.roleRemoved:Fire(userId, roleId)
		Auth.networkMember(userId)
	end

	return roleRemoved
end

local asyncRolesCache = {}
function Auth.userAsyncRoles(userId: number, bustCache: boolean?)
	local success = true
	if asyncRolesCache[userId] and not bustCache then
		return
	end
	asyncRolesCache[userId] = true

	for gamePassId, roleIds in Data.async.gamepass do
		local ok, result = Util.Retry(function()
			return Util.Service.Marketplace:UserOwnsGamePassAsync(userId, gamePassId)
		end)
		if ok and result then
			for _, roleId in roleIds do
				Auth.userRoleAdd(userId, roleId)
			end
		end
		if not ok then
			success = false
		end
	end

	if next(Data.async.group) then
		local ok, groups = Util.Retry(function()
			return Util.Service.Group:GetGroupsAsync(userId)
		end)
		if ok then
			for _, group in groups do
				local groupAuth = Data.async.group[group.Id]
				if groupAuth then
					for _, auth in groupAuth do
						if group.Rank == auth.rank or (not auth.exactRank and group.Rank >= auth.rank) then
							for _, roleId in auth.roles do
								Auth.userRoleAdd(userId, roleId)
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

	local player = Util.Service.Players:GetPlayerByUserId(userId)
	if not player then
		return
	end

	for assetId, roleIds in Data.async.asset do
		local ok, result = Util.Retry(function()
			return Util.Service.Marketplace:PlayerOwnsAsset(player, assetId)
		end)
		if ok and result then
			for _, roleId in roleIds do
				Auth.userRoleAdd(userId, roleId)
			end
		end
		if not ok then
			success = false
		end
	end

	for subscriptionId, roleIds in Data.async.subscription do
		local ok, result = Util.Retry(function()
			return Util.Service.Marketplace:GetUserSubscriptionStatusAsync(player, subscriptionId)
		end)
		if ok and result.IsSubscribed then
			for _, roleId in roleIds do
				Auth.userRoleAdd(userId, roleId)
			end
		end
		if not ok then
			success = false
		end
	end

	return success
end

-- PERMISSION FUNCTIONS

--- Checks if a role has access to a command argument
function Auth.roleCanUseArgument(roleId: Role, argument: any): boolean
	local role = Data.roles[roleId]
	if not role then
		warn(`undefined role "{roleId}"`)
		return false
	end

	if role.permissions.admin then
		return true
	end

	if argument.permissions then
		for permission, value in argument.permissions do
			if role.permissions[permission] ~= value then
				return false
			end
		end
	end

	return true
end

--- Checks if a role has access to a command
function Auth.roleCanUseCommand(roleId: Role, command: any): boolean
	local role = Data.roles[roleId]
	if not role then
		warn(`undefined role "{roleId}"`)
		return false
	end

	local rawCommand = command
	if type(command) == "string" then
		command = Registry.commands[string.lower(command)]
	end
	if type(command) ~= "table" then
		error(`Invalid command type for {tostring(rawCommand)}: Expected table or string got {typeof(command)}`, 2)
	end

	if role.permissions and role.permissions.admin then
		return true
	end

	if role.commands then
		local override = role.commands[command.name]
		if override ~= nil then
			return override
		end
		if command.aliases then
			for _, alias in command.aliases do
				local aliasOverride = role.commands[alias]
				if aliasOverride ~= nil then
					return aliasOverride
				end
			end
		end
	end

	if command.permissions then
		for permission, value in command.permissions do
			if role.permissions[permission] ~= value then
				return false
			end
		end
	end

	if command and role.groups and command.group and table.find(role.groups, string.lower(command.group)) then
		return true
	end

	return false
end

--- Checks if a user has access to a command argument
function Auth.hasArgument(userId: number, argument: any): boolean
	if userId == Data.creatorId or Auth.roleCanUseArgument("everyone", argument) then
		return true
	end
	local member = Data.members[tostring(userId)]
	if member then
		for _, role in member.roles do
			if Auth.roleCanUseArgument(role, argument) then
				return true
			end
		end
	end
	return false
end

--- Checks if a user has access to a command, returns their rank if they do
function Auth.hasCommand(userId: number, command: any): boolean | number
	if userId == Data.creatorId then
		return math.huge
	end
	local member = Data.members[tostring(userId)]
	if member then
		for _, roleId in member.roles do
			if Auth.roleCanUseCommand(roleId, command) then
				return Data.roles[roleId]._rank
			end
		end
	end
	if Auth.roleCanUseCommand("everyone", command) then
		return 0
	end
	return false
end

--- Checks if a user has access to a permission
function Auth.hasPermission(userId: number, permission: string): boolean
	if
		userId == Data.creatorId
		or Data.roles.everyone.permissions.admin
		or Data.roles.everyone.permissions[permission]
	then
		return true
	end
	local member = Data.members[tostring(userId)]
	if member then
		for _, roleId in member.roles do
			local role = Data.roles[roleId]
			if role and (role.permissions.admin or role.permissions[permission]) then
				return true
			end
		end
	end
	return false
end

--- Checks the maximum role rank of the user
function Auth.getRank(userId: number): (number, Role)
	if userId == Data.creatorId then
		return math.huge, Data.roles.creator
	end
	local member = Data.members[tostring(userId)]
	if member then
		for _, roleId in member.roles do -- roles are descending by rank
			local role = Data.roles[roleId]
			if role then
				return role._rank, role
			end
		end
	end
	return 0, Data.roles.everyone
end

--- Gets the closest role equal to or above a given rank
function Auth.getRoleFromRank(rank: number): Role
	local roleResult = Data.roles.creator
	for roleId, role in Data.roles do
		if role._rank == rank then
			return role
		end
		if role._rank >= rank and role._rank < roleResult._rank then
			roleResult = role
		end
	end
	return roleResult
end

function Auth.targetUserArgument(arg, userId: number, value: Player | number | string)
	local from = arg.command.from
	local limits = arg.command.fromRole.limits
	local targetLimits = arg._K.Data.targetLimits
	targetLimits[from] = targetLimits[from] or 0
	if limits and targetLimits[from] > (limits.targets or math.huge) then
		return nil, `Can only target {limits.targets} user{if limits.targets == 1 then "" else "s"}`
	end
	targetLimits[from] += 1
	if userId == from then
		if arg.definition.ignoreSelf then
			return nil, "Can't target yourself"
		end
		return value
	end
	if from == Data.creatorId then
		return value
	end
	if Auth.hasPermission(from, "targetOthers") ~= true and not Auth.hasPermission(from, "admin") then
		return nil, "Can only target yourself"
	end
	if
		arg.definition.lowerRank
		and (not arg.definition.shouldRequest or arg.command._K.Data.settings.commandRequests == false)
	then
		local player = Util.Service.Players:GetPlayerByUserId(userId)
		if player and player:GetAttribute("_KRolesLoaded") ~= true then
			return nil, "Can't target loading user"
		end
		if Auth.getRank(userId) < (if arg.command.rank == 0 then arg.command.fromRank else arg.command.rank) then
			return value
		end
		return nil, "Can only target lower ranks"
	else
		return value
	end
end

return Auth
