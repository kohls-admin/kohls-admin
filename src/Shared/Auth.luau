local Players = game:GetService("Players")

local Shared = script.Parent

local Data = require(Shared.Data:WaitForChild("Defaults"))
local Hook = require(Shared:WaitForChild("Hook"))
local Registry = require(Shared:WaitForChild("Registry"))
local Util = require(Shared:WaitForChild("Util"))

local Remote = Util.Remote

export type Role = "everyone" | "vip" | "mod" | "admin" | "superadmin" | "creator" | string

--- @class Auth
local Auth = {}

-- BAN FUNCTIONS

function Auth.banHandler(player)
	local key = tostring(player.UserId)
	local banInfo = Data.bans[key]

	if player.UserId == Data.creatorId or player.UserId < 1 or not banInfo then
		return -- not banned
	end

	if not Util.RunContext.IsStudio then
		-- a failed lookup must not skip the kick below
		local ok, banHistory = pcall(Players.GetBanHistoryAsync, Players, player.UserId)
		if ok and banHistory then
			local items = banHistory:GetCurrentPage()
			local last = items[1]

			if last and not last.Ban and banInfo and banInfo[3] and banInfo[3] ~= 0 then
				Auth.unbanUsers({ player.UserId })
				return -- unbanned from site
			end
		end
	end

	local _name, reason, timeStamp = unpack(banInfo)
	local banMessage
	if tonumber(timeStamp) then
		if timeStamp > 0 then
			local timeRemaining = timeStamp - os.time()
			if timeRemaining > 0 then
				banMessage = "You are banned from this experience for " .. Util.Time.readable(timeRemaining) .. "!"
			else
				Auth.unbanUsers({ player.UserId })
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

local function saveBan(key, userId, ban, timestamp)
	local username = Util.getUserInfo(userId).Username
	if Data.bans[key] ~= ban then
		return
	end
	ban[1] = username
	if timestamp then
		Data.Sync.bans[key] = ban
	end
	for _, player in Players:GetPlayers() do
		if Auth.hasCommand(player.UserId, "ban") then
			Remote.Ban:Fire(player, key, ban)
		end
	end
end

local BAN_API_ATTEMPTS = 8

-- calls BanAsync/UnbanAsync in chunks of 50 with capped exponential backoff
local function banApi(method: (Players, any) -> (), name: string, userIds: { number }, config: { [string]: any })
	for i = 1, #userIds, 50 do
		config.UserIds = table.move(userIds, i, math.min(#userIds, i + 49), 1, {})
		local ok, err = Util.Retry(method, BAN_API_ATTEMPTS, 2, Players, config)
		if not ok then
			local code = string.match(tostring(err), '"code": "([^"]+)"')
			warn(`{name} failed: {code or err}, giving up`)
		end
	end
end

--- Bans users and returns the ones banned; saved bans are kept unless the caller can use banasync
function Auth.banUsers(
	userIds: { number },
	reason: string?,
	duration: number?,
	fromUserId: number?,
	forceBanAsync: boolean?
): { number }
	local banAsync = forceBanAsync
		or not fromUserId
		or (Auth.hasPermission(fromUserId, "banasync") and Auth.hasRestrictedRole(fromUserId))

	if not banAsync then
		duration = 0
	end

	local timestamp
	if duration and duration ~= 0 then
		timestamp = if duration > 0 then os.time() + duration else -1
	end

	local banned, unbanAsync = {}, {}
	for _, userId in userIds do
		if userId == Data.creatorId or userId <= 0 then
			continue
		end
		local key = tostring(userId)
		local ban = Data.bans[key]
		local savedBan = ban and ban[3] and (ban[3] < 0 or ban[3] > os.time())
		if savedBan then
			-- only banasync can change saved bans, as in unbanUsers
			if not banAsync then
				continue
			end
			-- remove saved bans when changed to server ban
			Data.Sync.bans[key] = Data.REMOVE
			table.insert(unbanAsync, userId)
		end
		local newBan = { if ban then ban[1] else nil, reason, timestamp, fromUserId }
		Data.bans[key] = newBan
		if timestamp then
			Data.Sync.bans[key] = newBan
		end
		table.insert(banned, userId)
		task.spawn(saveBan, key, userId, newBan, timestamp)
	end

	if banAsync and timestamp and #banned > 0 and not Data.SEPARATE_DATASTORE and not Util.RunContext.IsStudio then
		banApi(Players.BanAsync, "BanAsync", banned, {
			PrivateReason = reason or "No reason.",
			DisplayReason = reason or "No reason.",
			Duration = duration,
			ApplyToUniverse = true,
		})
	elseif #unbanAsync > 0 and not Data.SEPARATE_DATASTORE and not Util.RunContext.IsStudio then
		banApi(Players.UnbanAsync, "UnbanAsync", unbanAsync, { ApplyToUniverse = true })
	end

	if #banned > 0 then
		Hook.ban:Fire(banned, reason, duration, fromUserId, forceBanAsync)
	end

	return banned
end

--- Unbans users and returns the ones unbanned; saved bans are kept unless the caller can use banasync
function Auth.unbanUsers(userIds: { number }, fromUserId: number?, forceBanAsync: boolean?): { number }
	local banAsync = forceBanAsync
		or not fromUserId
		or (Auth.hasPermission(fromUserId, "banasync") and Auth.hasRestrictedRole(fromUserId))
	local unbanned, unbanAsync = {}, {}
	for index, userId in userIds do
		local key = tostring(userId)
		local number = tonumber(userId)
		local ban = Data.bans[key]
		local savedBan = ban and ban[3] and (ban[3] < 0 or ban[3] > os.time())

		if not ban or savedBan then
			if not banAsync then
				continue
			end
			if number then
				table.insert(unbanAsync, number)
			end
		end

		table.insert(unbanned, userId)
		Data.bans[key] = nil
		Data.Sync.bans[key] = Data.REMOVE
		for _, player in Players:GetPlayers() do
			if Auth.hasCommand(player.UserId, "ban") then
				Remote.Ban:Fire(player, key)
			end
		end
	end

	if banAsync and #unbanAsync > 0 and not Data.SEPARATE_DATASTORE and not Util.RunContext.IsStudio then
		banApi(Players.UnbanAsync, "UnbanAsync", unbanAsync, { ApplyToUniverse = true })
	end

	if #unbanned > 0 then
		Hook.unban:Fire(unbanned, fromUserId, forceBanAsync)
	end

	return unbanned
end

-- ROLE FUNCTIONS

local function saveMember(key, userId)
	local username = Util.getUserInfo(userId).Username
	local member = Data.members[key]
	if member and #member.persist > 0 then
		Data.Sync.members[key] = { username, member.persist }
	end
end

function Auth.networkMember(userId: number)
	local userIdString = tostring(userId)
	local member = Data.members[userIdString]
	for _, player in Players:GetPlayers() do
		if not player:GetAttribute("_K_READY") then
			continue
		end
		if player.UserId == userId or Auth.hasCommand(player.UserId, "members") then
			Remote.Member:Fire(player, userIdString, member)
		end
	end
end

local function updateMemberName(member, userId)
	member.name = Util.getUserInfo(userId).Username
	Auth.networkMember(userId)
end

--- Sorts roleIds by highest to lowest
function Auth.roleIdSort(a: Role, b: Role): boolean
	local roleA, roleB = Data.roles[a], Data.roles[b]
	local rankA = if roleA then roleA._rank else 0
	local rankB = if roleB then roleB._rank else 0
	return rankA > rankB
end

--- Sorts roleIds by lowest to highest
function Auth.roleIdSortAscending(a: Role, b: Role): boolean
	local roleA, roleB = Data.roles[a], Data.roles[b]
	local rankA = if roleA then roleA._rank else 0
	local rankB = if roleB then roleB._rank else 0
	return rankA < rankB
end

--- Adds a role to a user if they don't already have it
function Auth.userRoleAdd(userId: number, roleId: Role, persist: boolean?, unrestricted: boolean?): boolean
	if roleId == "everyone" then
		return false
	end

	local key = tostring(userId)
	local member = Data.members[key]
	local roleAdded = false

	if not member then
		member = {
			name = nil,
			roles = { roleId },
			persist = { if persist then roleId else nil },
			unrestricted = if unrestricted then { [roleId] = true } else nil,
		}
		Data.members[key] = member
		roleAdded = true
		task.spawn(updateMemberName, member, userId)
	else
		if not table.find(member.roles, roleId) then
			table.insert(member.roles, roleId)
			table.sort(member.roles, Auth.roleIdSort)
			roleAdded = true
			if unrestricted then
				member.unrestricted = member.unrestricted or {}
				member.unrestricted[roleId] = true
			end
		elseif not unrestricted and member.unrestricted then
			member.unrestricted[roleId] = nil
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

-- roles users own through a group, gamepass, asset or subscription, which userRoleRemove keeps
local asyncRoles: { [number]: { [Role]: true } } = {}
local groupAsyncRoles: { [number]: { [Role]: true } } = {}
local ownedAsyncRoles: { [number]: { [Role]: true } } = {}

--- Gives a user a role they own through a group, gamepass, asset or subscription, which userRoleRemove keeps
function Auth.asyncRoleAdd(userId: number, roleId: Role, fromGroup: boolean?): boolean
	local roles = asyncRoles[userId] or {}
	asyncRoles[userId] = roles
	roles[roleId] = true
	if not fromGroup then
		local owned = ownedAsyncRoles[userId] or {}
		ownedAsyncRoles[userId] = owned
		owned[roleId] = true
	end
	return Auth.userRoleAdd(userId, roleId)
end

--- Checks if a user owns a role through a group, gamepass, asset or subscription
function Auth.hasAsyncRole(userId: number, roleId: Role): boolean
	local roles = asyncRoles[tonumber(userId) :: number]
	return roles ~= nil and roles[roleId] == true
end

--[=[
	Removes a role from a user if it exists. A role the user owns through a group, gamepass, asset or subscription
	(Auth.hasAsyncRole) stays, only a saved copy of it is removed.
]=]
function Auth.userRoleRemove(userId: number, roleId: Role): boolean
	local key = tostring(userId)
	local member = Data.members[key]
	local roleRemoved = false
	local persistent = false

	if member then
		local index = table.find(member.roles, roleId)
		if index and not Auth.hasAsyncRole(userId, roleId) then
			table.remove(member.roles, index)
			roleRemoved = true
		end
		if member.unrestricted then
			member.unrestricted[roleId] = nil
		end
		index = table.find(member.persist, roleId)
		if index then
			table.remove(member.persist, index)
			persistent = true
		end
	end

	if roleRemoved or persistent then
		if #member.roles == 0 then
			Data.members[key] = nil
		end
		if persistent then
			if #member.persist == 0 then
				Data.Sync.members[key] = Data.REMOVE
			else
				task.spawn(saveMember, key, userId)
			end
		end
		if roleRemoved then
			Hook.roleRemoved:Fire(userId, roleId)
		end
		Auth.networkMember(userId)
	end

	return roleRemoved or persistent
end

local asyncRolesCache = {}
-- checks a group role rule against a group rank, either exactly or at least that rank
local function rankMatches(rule, rank: number): boolean
	return rank == rule.rank or (not rule.exactRank and rank >= rule.rank)
end

-- the roles a user gets from their groups, without giving them; false and the error when the groups can't be read
local function groupRoleIds(userId: number, attempts: number?): (boolean, { Role } | string)
	local ok, result = Util.Retry(function()
		return Util.Service.Group:GetGroupsAsync(userId)
	end, attempts)
	if not ok then
		return false, result
	end
	local roleIds = {}
	for _, group in result do
		local groupAuth = Data.async.group[group.Id] or Data.async.group[tostring(group.Id)]
		if type(groupAuth) == "table" then
			for _, auth in if type(groupAuth.roles) == "table" then { groupAuth } else groupAuth do
				if
					type(auth) == "table"
					and type(auth.rank) == "number"
					and type(auth.roles) == "table"
					and rankMatches(auth, group.Rank)
				then
					table.move(auth.roles, 1, #auth.roles, #roleIds + 1, roleIds)
				end
			end
		end
	end
	return true, roleIds
end

-- the roles a user gets from the gamepasses they own, without giving them; also returns the last ownership error
local function gamePassRoleIds(userId: number): ({ Role }, string?)
	local roleIds, err = {}, nil
	for gamePassId, passRoleIds in Data.async.gamepass do
		local ok, result = Util.Retry(function()
			return Util.Service.Marketplace:UserOwnsGamePassAsync(userId, gamePassId)
		end)
		if ok and result then
			table.move(passRoleIds, 1, #passRoleIds, #roleIds + 1, roleIds)
		elseif not ok then
			warn(result)
			err = result
		end
	end
	return roleIds, err
end

-- gives the roles a user gets from their groups, returns the error when the groups can't be read
local function giveGroupRoles(userId: number, attempts: number?): string?
	local ok, result = groupRoleIds(userId, attempts)
	if not ok then
		return result :: string
	end
	local current: { [Role]: true } = {}
	for _, roleId in result :: { Role } do
		current[roleId] = true
	end
	local previous = groupAsyncRoles[userId]
	groupAsyncRoles[userId] = current
	if previous then
		local owned = ownedAsyncRoles[userId]
		local roles = asyncRoles[userId]
		local member = Data.members[tostring(userId)]
		for roleId in previous do
			if not current[roleId] and not (owned and owned[roleId]) then
				if roles then
					roles[roleId] = nil
				end
				if member and (not member.persist or not table.find(member.persist, roleId)) then
					Auth.userRoleRemove(userId, roleId)
				end
			end
		end
	end
	for _, roleId in result :: { Role } do
		Auth.asyncRoleAdd(userId, roleId, true)
	end
	return nil
end

-- waits between group fetches after the first one fails, about a minute in total with its own retries
local GROUP_RETRY_DELAYS = { 5, 10, 15 }

function Auth.userAsyncRoles(userId: number, bustCache: boolean?)
	local cached = asyncRolesCache[userId]
	if cached and not bustCache then
		return
	end
	asyncRolesCache[userId] = true

	local player = Players:GetPlayerByUserId(userId)
	local groupError = if next(Data.async.group) then giveGroupRoles(userId) else nil

	if not cached then
		for _, roleId in (gamePassRoleIds(userId)) do
			Auth.asyncRoleAdd(userId, roleId)
		end
	end

	if player and not cached then
		for assetId, roleIds in Data.async.asset do
			local ok, result = Util.Retry(function()
				return Util.Service.Marketplace:PlayerOwnsAssetAsync(player, assetId)
			end)
			if ok and result then
				for _, roleId in roleIds do
					Auth.asyncRoleAdd(userId, roleId)
				end
			elseif not ok then
				warn(result)
			end
		end

		for subscriptionId, roleIds in Data.async.subscription do
			local ok, result = Util.Retry(function()
				return Util.Service.Marketplace:GetUserSubscriptionStatusAsync(player, subscriptionId)
			end)
			if ok and result.IsSubscribed then
				for _, roleId in roleIds do
					Auth.asyncRoleAdd(userId, roleId)
				end
			elseif not ok then
				warn(result)
			end
		end
	end

	-- a group-ranked player would count as rank 0, so the player keeps loading while their groups are retried
	for _, delay in GROUP_RETRY_DELAYS do
		if not groupError or not player or not player.Parent then
			break
		end
		task.wait(delay)
		if not player.Parent then
			break
		end
		groupError = giveGroupRoles(userId, 1)
	end
	if groupError then
		warn(groupError)
	end
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
		warn(`Invalid command type for {tostring(rawCommand)}: Expected table or string got {typeof(command)}`, 2)
		return false
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
		for _, roleId in member.roles do
			if Auth.roleCanUseArgument(roleId, argument) then
				return true
			end
		end
	end
	if Data.settings.freeAdmin then
		for _, roleId in Data.settings.freeAdmin do
			if Auth.roleCanUseArgument(roleId, argument) then
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
	if Data.settings.freeAdmin then
		for _, roleId in Data.settings.freeAdmin do
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
	if Data.settings.freeAdmin then
		for _, roleId in Data.settings.freeAdmin do
			local role = Data.roles[roleId]
			if role and (role.permissions.admin or role.permissions[permission]) then
				return true
			end
		end
	end
	return false
end

--- Checks if a user has a role or higher rank
function Auth.hasRole(userId: number, roleId: Role): boolean
	if userId == Data.creatorId then
		return true
	end
	local role = type(roleId) == "string" and Data.roles[roleId]
	if not role then
		return false
	end
	local member = Data.members[tostring(userId)]
	if member and member.roles and table.find(member.roles, roleId) then
		return true
	end
	return Auth.getRank(userId) > role._rank
end

--- Checks the maximum role rank of the user
function Auth.getRank(userId: number): (number, Role)
	if userId == Data.creatorId then
		return math.huge, Data.roles.creator
	end
	local member = Data.members[tostring(userId)]
	local rank, role = 0, Data.roles.everyone
	if member then
		for _, roleId in member.roles do
			local data = Data.roles[roleId]
			if data and data._rank > rank then
				rank, role = data._rank, data
			end
		end
	end
	if Data.settings.freeAdmin then
		for _, roleId in Data.settings.freeAdmin do
			local data = Data.roles[roleId]
			if data and data._rank > rank then
				rank, role = data._rank, data
			end
		end
	end

	return rank, role
end

--- Gets the closest role equal to or above a given rank
function Auth.getRoleFromRank(rank: number): Role
	local roleResult = Data.roles.creator
	for roleId, role in Data.roles do
		if role._rank == rank then
			return role
		end
		if role._rank >= rank and (not roleResult or role._rank < roleResult._rank) then
			roleResult = role
		end
	end
	return roleResult
end

local offlineRanks: { [number]: number } = {}
local offlineLookups: { [number]: true } = {}

-- the highest rank a user gets from groups and gamepasses, nil when a web call fails
local function lookupOfflineRank(userId: number): number?
	local roleIds = {}
	if next(Data.async.group) then
		local ok, result = groupRoleIds(userId)
		if not ok then
			warn(result)
			return nil
		end
		roleIds = result :: { Role }
	end
	local passRoleIds, err = gamePassRoleIds(userId)
	if err then
		return nil
	end
	table.move(passRoleIds, 1, #passRoleIds, #roleIds + 1, roleIds)

	local offlineRank = 0
	for _, roleId in roleIds do
		local role = Data.roles[roleId]
		if role and role._rank > offlineRank then
			offlineRank = role._rank
		end
	end
	return offlineRank
end

-- the highest rank a user out of this server gets from groups and gamepasses, nil when it can't be verified
local function getOfflineRank(userId: number, rank: number, from: number): number?
	-- asset and subscription ownership needs the Player, so fail closed when they give this rank or higher
	for _, source in { Data.async.asset, Data.async.subscription } do
		for _, roleIds in source do
			for _, roleId in roleIds do
				local role = Data.roles[roleId]
				if role and role._rank >= rank then
					return nil
				end
			end
		end
	end

	local cached = offlineRanks[userId]
	if cached then
		return cached
	end

	-- one lookup at a time per caller, so nobody can spend the web call budget that joining players need
	if offlineLookups[from] then
		return nil
	end
	offlineLookups[from] = true
	local offlineRank = lookupOfflineRank(userId)
	offlineLookups[from] = nil

	if offlineRank then
		offlineRanks[userId] = offlineRank
		task.delay(60, function()
			offlineRanks[userId] = nil
		end)
	end
	return offlineRank
end

--- Validates if a user can be targeted by a command argument based on permissions and rank limits
function Auth.targetUserArgument(arg: any, userId: number, value: Player | number | string)
	if type(userId) ~= "number" or math.floor(userId) ~= userId or math.abs(userId) == math.huge then
		return nil, "Invalid user"
	end
	local from = arg.command.from
	local limits = arg.command.fromRole.limits
	local targetLimits = arg._K.Data.targetLimits
	targetLimits[from] = targetLimits[from] or 0
	if limits and targetLimits[from] >= (limits.targets or math.huge) then
		return nil, `Can only target {limits.targets} user{if limits.targets == 1 then "" else "s"}`
	end
	targetLimits[from] += 1
	if userId == from then
		if arg.definition.ignoreSelf then
			return nil, "Can't target yourself"
		end
		return value
	end
	if from == Data.creatorId or Auth.hasPermission(from, "admin") then
		return value
	end
	if Auth.hasPermission(from, "targetOthers") ~= true then
		return nil, "Can only target yourself"
	end
	if
		arg.definition.lowerRank
		and (not arg.definition.shouldRequest or arg._K.Data.settings.commandRequests == false)
	then
		local player = Players:GetPlayerByUserId(userId)
		if player and player:GetAttribute("_KRolesLoaded") ~= true then
			return nil, "Can't target loading user"
		end
		local rank = if arg.command.rank == 0 then arg.command.fromRank else arg.command.rank
		if Auth.getRank(userId) >= rank then
			return nil, "Can only target lower ranks"
		end
		if not player and Util.RunContext.IsServer and not arg.definition.skipOfflineRank then
			-- roles from groups and gamepasses are only given in the user's server
			local offlineRank = getOfflineRank(userId, rank, from)
			if not offlineRank then
				return nil, "Can't verify the rank of an offline user"
			elseif offlineRank >= rank then
				return nil, "Can only target lower ranks"
			end
		end
		return value
	else
		return value
	end
end

local groupEntryRanks: { [number]: number | false } = {}

-- the lowest member rank of a group, which anyone joining the group receives; nil until known
local function getGroupEntryRank(groupId: number): number?
	local cached = groupEntryRanks[groupId]
	if cached == nil then
		groupEntryRanks[groupId] = false
		task.spawn(function()
			local ok, info = Util.Retry(function()
				return Util.Service.Group:GetGroupInfoAsync(groupId)
			end)
			local entry
			if ok and type(info) == "table" and type(info.Roles) == "table" then
				for _, role in info.Roles do
					if role.Rank > 0 and (not entry or role.Rank < entry) then
						entry = role.Rank
					end
				end
			end
			if entry then
				groupEntryRanks[groupId] = entry
			else
				-- stay closed and retry later
				task.delay(60, function()
					groupEntryRanks[groupId] = nil
				end)
			end
		end)
	end
	return cached or nil
end

--- Starts fetching the entry rank of every group in the group roles, so role checks don't stay closed on first use
function Auth.prefetchGroupEntryRanks()
	for groupId in Data.async.group do
		local id = tonumber(groupId)
		if id then
			getGroupEntryRank(id)
		end
	end
end

--- Checks if a role is handed out freely: free admin, friends of the creator, or every member of a group
function Auth.isPublicRole(roleId: Role): boolean
	if Data.settings.freeAdmin and table.find(Data.settings.freeAdmin, roleId) then
		return true
	end
	if table.find(Data.friendRoles, roleId) then
		return true
	end
	for groupId, rules in Data.async.group do
		local id = tonumber(groupId)
		if not id or type(rules) ~= "table" then
			continue
		end
		for _, rule in if type(rules.roles) == "table" then { rules } else rules do
			if
				type(rule) ~= "table"
				or type(rule.rank) ~= "number"
				or type(rule.roles) ~= "table"
				or not table.find(rule.roles, roleId)
			then
				continue
			end
			local entry = getGroupEntryRank(id)
			if not entry then
				return true -- fail closed until the group's entry rank is known
			end
			if rankMatches(rule, entry) then
				return true
			end
		end
	end
	return false
end

--- Checks if a user has any developer roles; Roles not associated with any assets, gamepasses, subscriptions, and not handed out freely
function Auth.hasRestrictedRole(userId: number): boolean
	if userId == Data.creatorId then
		return true
	end
	local member = Data.members[tostring(userId)]
	if member and member.roles then
		for _, roleId in member.roles do
			if member.unrestricted and member.unrestricted[roleId] then
				continue
			end
			local role = Data.roles[roleId]
			if
				role
				and (roleId ~= "vip" or not Data.settings.vip)
				and (type(role.assets) ~= "table" or not next(role.assets))
				and (type(role.gamepasses) ~= "table" or not next(role.gamepasses))
				and (type(role.subscriptions) ~= "table" or not next(role.subscriptions))
				and not Auth.isPublicRole(roleId)
			then
				return true
			end
		end
	end
	return false
end

return Auth
