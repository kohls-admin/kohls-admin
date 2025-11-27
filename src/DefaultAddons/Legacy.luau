-- Constants
local LEGACY_ROLES = {
	{ group = "GameCreator", role = "creator" },
	{ group = "Creator", role = "superadmin" },
	{ group = "SuperAdmin", role = "admin" },
	{ group = "Administration", role = "mod" },
	{ group = "Administration", role = "vip" },
}

local RANK_TO_GROUP = {
	[0] = "Utility",
	[1] = "VIP",
	[2] = "Moderation",
	[3] = "Administration",
	[4] = "SuperAdmin",
	[5] = "Creator",
}

local LEGACY_ARG_MAPPING = {
	player = "players",
	userid = "userIds",
	boolean = "boolean",
	color = "color",
	number = "number",
	string = "rawString",
	word = "rawString",
	time = "timeSimple",
	banned = "ban",
	admin = "member",
}

local DEFAULT_ROLES = { "vip", "mod", "admin", "superadmin", "creator" }

-- Utility Functions
local function safeGetPlayer(Service, userId)
	local success, result = pcall(function()
		return Service.Players:GetPlayerByUserId(userId)
	end)
	return success and result or nil
end

local function notifyPlayer(Remote, player, text, from, color)
	if not player then return end
	
	pcall(function()
		Remote.Notify:FireClient(player, {
			Text = text,
			From = from or "_K",
		})
	end)
end

local function batchGetUserInfo(Util, userIds)
	local names = {}
	for _, userId in userIds do
		local success, info = pcall(function()
			return Util.getUserInfo(userId)
		end)
		if success and info then
			table.insert(names, info.DisplayName)
		else
			table.insert(names, tostring(userId))
		end
	end
	return names
end

-- Role Command Functions
local function createRoleGiver(role, isTemporary)
	return function(context, userIds)
		if not context._K.Data.roles[role] then
			warn(`Role '{role}' does not exist`)
			return
		end

		local usersRoled = {}
		local roleData = context._K.Data.roles[role]
		local saveRoles = not isTemporary and context.definition.permissions.saveRoles

		for _, userId in userIds do
			local success, added = pcall(function()
				return context._K.Auth.userRoleAdd(userId, role, saveRoles)
			end)

			if success and added then
				table.insert(usersRoled, userId)
				
				local player = safeGetPlayer(context._K.Service, userId)
				if player then
					local prefix = context._K.getCommandPrefix(userId)
					local message = `Gave you the <b><font color="{roleData.color}">{roleData.name}</font></b> role!`
					if isTemporary then
						message = message .. ` (temporary)`
					end
					message = message .. `\nSay <b>{prefix}cmds</b> or <b>{prefix}info</b> for details.`
					
					notifyPlayer(context._K.Remote, player, message, context.from)
				end
			end
		end

		if #usersRoled == 0 then
			return
		end

		-- Notify command executor
		task.spawn(function()
			local names = batchGetUserInfo(context._K.Util, usersRoled)
			local roleType = isTemporary and "Temporarily Gave" or "Gave"
			
			notifyPlayer(
				context._K.Remote,
				context.fromPlayer,
				`<b>{roleType} Role:</b> <b><font color="{roleData.color}">{roleData.name}</font></b>\n<b>To:</b> <i>{table.concat(names, ", ")}</i>`,
				"_K"
			)
		end)
	end
end

local function createRoleRemover(role)
	return function(context, members)
		if not context._K.Data.roles[role] then
			warn(`Role '{role}' does not exist`)
			return
		end

		local membersUnroled = {}
		for _, userId in members do
			local success, removed = pcall(function()
				return context._K.Auth.userRoleRemove(userId, role)
			end)

			if success and removed then
				local member = context._K.Data.members[tostring(userId)]
				table.insert(membersUnroled, member and member.name or tostring(userId))
			end
		end

		if #membersUnroled == 0 then
			return
		end

		local roleData = context._K.Data.roles[role]
		notifyPlayer(
			context._K.Remote,
			context.fromPlayer,
			`<b>Removed Role:</b> <b><font color="{roleData.color}">{roleData.name}</font></b>\n<b>From:</b> <i>{table.concat(membersUnroled, ", ")}</i>`,
			"_K"
		)
	end
end

-- Command Registration
local function registerRoleCommands(_K, definition)
	local role = definition.role
	local roleData = _K.Data.roles[role]

	if not roleData then
		return
	end

	-- Permanent role command
	_K.Registry.registerCommand(_K, {
		name = role,
		description = `Gives the {roleData.name} role to one or more user(s).`,
		group = definition.group,
		permissions = { saveRoles = true },
		args = {
			{
				type = "userIds",
				name = "User(s)",
				description = `The user(s) to give the {roleData.name} role to.`,
			},
		},
		run = createRoleGiver(role, false),
	})

	-- Temporary role command
	_K.Registry.registerCommand(_K, {
		name = "temp" .. role,
		description = `Temporarily gives the {roleData.name} role to one or more user(s).`,
		group = definition.group,
		permissions = {},
		args = {
			{
				type = "userIds",
				name = "User(s)",
				description = `The user(s) to temporarily give the {roleData.name} role to.`,
			},
		},
		run = createRoleGiver(role, true),
	})

	-- Remove role command
	_K.Registry.registerCommand(_K, {
		name = "un" .. role,
		description = `Removes the {roleData.name} role from one or more member(s).`,
		group = definition.group,
		args = {
			{
				type = "members",
				name = "Member(s)",
				description = `The member(s) to remove the {roleData.name} role from.`,
				lowerRank = true,
			},
		},
		run = createRoleRemover(role),
	})
end

-- Legacy Migration Functions
local function getUserIdFromName(Service, Util, nameOrUserId)
	if type(nameOrUserId) == "number" then
		return nameOrUserId
	end
	
	local success, userId = Util.Retry(function()
		return Service.Players:GetUserIdFromNameAsync(nameOrUserId)
	end)
	
	return success and userId or nil
end

local function migrateBans(_K, bannedList)
	local tasks = {}
	
	for _, nameOrUserId in bannedList do
		table.insert(tasks, task.spawn(function()
			local userId = getUserIdFromName(_K.Service, _K.Util, nameOrUserId)
			if userId then
				pcall(function()
					_K.Auth.banUsers({ userId }, "Migrated from Legacy bans.", 0, _K.creatorId)
				end)
			end
		end))
	end
	
	return tasks
end

local function getRoleFromRank(_K, rank)
	rank = tonumber(rank)
	if not rank then
		return nil
	end
	
	rank = math.clamp(math.abs(rank), 1, 5)
	local defaultRoleId = DEFAULT_ROLES[rank]
	
	if _K.Data.roles[defaultRoleId] then
		return defaultRoleId
	end
	
	for roleId, role in _K.Data.roles do
		if role._rank == rank then
			return roleId
		end
	end
	
	return nil
end

local function migrateRoles(_K, roleLists)
	local tasks = {}
	
	for rank, list in ipairs(roleLists) do
		for _, nameOrUserId in list do
			table.insert(tasks, task.spawn(function()
				local roleId = getRoleFromRank(_K, rank)
				if roleId then
					local userId = getUserIdFromName(_K.Service, _K.Util, nameOrUserId)
					if userId then
						pcall(function()
							_K.Auth.userRoleAdd(userId, roleId)
						end)
					end
				end
			end))
		end
	end
	
	return tasks
end

local function migrateCustomCommands(_K, customCommands)
	if type(customCommands) ~= "table" then
		return
	end

	for _, definition in customCommands do
		local aliases, desc, rank, argList, run = unpack(definition)
		if not (aliases and desc and rank and argList and run) then
			continue
		end

		local args = {}
		for _, arg in argList do
			arg = string.lower(arg)
			local optional = string.find(arg, "/$")
			
			if optional then
				arg = string.sub(arg, 1, -2)
			end
			
			local argType = LEGACY_ARG_MAPPING[arg]
			if argType then
				table.insert(args, {
					type = argType,
					name = argType,
					optional = optional,
					description = "Migrated from Legacy custom commands.",
				})
			end
		end

		pcall(function()
			_K.Registry.registerCommand(_K, {
				name = aliases[1],
				aliases = { select(2, unpack(aliases)) },
				description = tostring(desc[1]) .. "\nMigrated from Legacy config.",
				group = RANK_TO_GROUP[math.clamp(rank, 0, 5)],
				args = args,
				run = function(context, ...)
					pcall(run, context.fromPlayer, { ... })
				end,
			})
		end)
	end
end

local function migrateGroupAdmin(_K, groupAdmin)
	if type(groupAdmin) ~= "table" then
		return
	end

	local group = {}
	for groupId, groupRanks in groupAdmin do
		local definition = {}
		for groupRank, powerRank in groupRanks do
			groupRank = tonumber(groupRank)
			local roleId = getRoleFromRank(_K, powerRank)
			
			if roleId and groupRank then
				table.insert(definition, { rank = groupRank, roles = { roleId } })
			end
		end
		group[groupId] = definition
	end
	
	pcall(function()
		_K.Util.Table.deepMerge(_K.Data.async.group, group, true)
	end)
end

local function migrateVIPAdmin(_K, vipAdmin)
	if type(vipAdmin) ~= "table" then
		return
	end

	local asset, gamepass = {}, {}
	
	for itemId, rank in vipAdmin do
		local roleId = getRoleFromRank(_K, rank)
		local numericId = tonumber(itemId)
		
		if roleId and numericId then
			if numericId > 0 then
				asset[numericId] = { roleId }
			else
				gamepass[numericId] = { roleId }
			end
		end
	end
	
	pcall(function()
		_K.Util.Table.deepMerge(_K.Data.async.asset, asset, true)
		_K.Util.Table.deepMerge(_K.Data.async.gamepass, gamepass, true)
		_K.setupPurchasables(asset, "assets")
		_K.setupPurchasables(gamepass, "gamepasses")
	end)
end

local function migrateSettings(_K, settings)
	if type(settings) ~= "table" then
		return
	end

	if settings.AdminCredit == false then
		_K.Data.defaultSettings.dashboardButtonRank = false
	end

	if settings.CommandBar == false then
		_K.Data.defaultSettings.commandBarRank = false
	end

	if settings.JoinMessage == false then
		_K.Data.defaultSettings.joinNotificationRank = false
	end

	if settings.PublicLogs == true then
		_K.Data.roles.everyone.permissions.serverlogs = true
	end

	if settings.Prefix and settings.Prefix ~= ";" then
		_K.Data.defaultSettings.prefix = { settings.Prefix }
	end

	local freeAdminRank = tonumber(settings.FreeAdmin)
	if freeAdminRank then
		local roleId = getRoleFromRank(_K, freeAdminRank)
		if roleId and not table.find(_K.Data.settings.freeAdmin, roleId) then
			table.insert(_K.Data.settings.freeAdmin, roleId)
		end
	end

	if type(settings.Permissions) == "table" then
		for alias, rank in settings.Permissions do
			rank = tonumber(rank)
			if alias and rank then
				rank = math.clamp(rank, 0, math.huge)
				for roleId, role in _K.Data.roles do
					role.commands[alias] = role._rank >= rank
				end
			end
		end
	end
end

local function performLegacyMigration(_K)
	local Package = script.Parent.Parent
	local Config = Package and Package:WaitForChild("Config", 5)
	
	if not Config then
		warn("Config folder not found")
		return
	end
	
	local LEGACY_CONFIG = Config:FindFirstChild("Legacy") or Config:FindFirstChild("LegacyConfig")
	
	if not LEGACY_CONFIG then
		return -- No legacy config, nothing to migrate
	end

	local success, customCommands = pcall(function()
		return require(LEGACY_CONFIG:WaitForChild("Custom_Commands", 5))
	end)
	
	if success then
		migrateCustomCommands(_K, customCommands)
	end

	if not _K.IsServer then
		return
	end

	local settingsSuccess, settingsData = pcall(function()
		return require(LEGACY_CONFIG:WaitForChild("Settings", 5))
	end)
	
	if not settingsSuccess or type(settingsData) ~= "table" then
		return
	end

	local settings, ranks = unpack(settingsData)
	if not (settings and ranks) then
		return
	end

	local owners, superAdmins, admins, mods, vip, banned = unpack(ranks)

	-- Migrate bans
	if banned then
		migrateBans(_K, banned)
	end

	-- Migrate roles
	if vip or mods or admins or superAdmins or owners then
		migrateRoles(_K, { vip, mods, admins, superAdmins, owners })
	end

	-- Migrate group admin
	migrateGroupAdmin(_K, settings.GroupAdmin)

	-- Migrate VIP admin
	migrateVIPAdmin(_K, settings.VIPAdmin)

	-- Migrate other settings
	migrateSettings(_K, settings)
	
	print("Legacy configuration migration completed")
end

-- Main Module
return function(_K)
	-- Register role commands
	for _, definition in LEGACY_ROLES do
		registerRoleCommands(_K, definition)
	end

	-- Perform legacy migration
	task.spawn(performLegacyMigration, _K)
end
