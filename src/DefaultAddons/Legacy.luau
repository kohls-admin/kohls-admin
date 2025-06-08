local legacyRoles = {
	{
		group = "GameCreator",
		role = "creator",
	},
	{
		group = "Creator",
		role = "superadmin",
	},
	{
		group = "SuperAdmin",
		role = "admin",
	},
	{
		group = "Administration",
		role = "mod",
	},
	{
		group = "Administration",
		role = "vip",
	},
}

return function(_K)
	for index, definition in legacyRoles do
		local role = definition.role
		local roleData = _K.Data.roles[role]

		-- skip registering command if role doesn't exist
		if not roleData then
			continue
		end

		local function run(context, userIds)
			local usersRoled = {}
			local roleData = context._K.Data.roles[role]
			for _, userId in userIds do
				if context._K.Auth.userRoleAdd(userId, role, context.definition.permissions.saveRoles) then
					table.insert(usersRoled, userId)
					local player = context._K.Service.Players:GetPlayerByUserId(userId)
					if not player then
						continue
					end
					local prefix = context._K.getCommandPrefix(userId)
					context._K.Remote.Notify:FireClient(player, {
						Text = `Gave you the <b><font color="{roleData.color}">{roleData.name}</font></b> role!\nSay <b>{prefix}cmds</b> or <b>{prefix}info</b> for details.`,
						From = context.from,
					})
				end
			end

			if #usersRoled == 0 then
				return
			end

			task.spawn(function()
				local names = {}
				for _, userId in usersRoled do
					table.insert(names, context._K.Util.getUserInfo(userId).DisplayName)
				end

				context._K.Remote.Notify:FireClient(context.fromPlayer, {
					From = "_K",
					Text = `<b>Gave Role:</b> <b><font color="{roleData.color}">{roleData.name}</font></b>\n<b>To:</b> <i>{table.concat(
						names,
						", "
					)}</i>`,
				})
			end)
		end

		_K.Registry.registerCommand(_K, {
			name = role,
			description = `Gives the {role} role to one or more user(s).`,
			group = definition.group,
			permissions = { saveRoles = true },
			args = {
				{
					type = "userIds",
					name = "Users(s)",
					description = `The user(s) to give the {role} role to.`,
				},
			},
			run = run,
		})

		_K.Registry.registerCommand(_K, {
			name = "temp" .. role,
			description = `Gives the {role} role temporarily to one or more user(s).`,
			group = definition.group,
			permissions = {},
			args = {
				{
					type = "userIds",
					name = "Users(s)",
					description = `The user(s) to give the {role} role to.`,
				},
			},
			run = run,
		})

		_K.Registry.registerCommand(_K, {
			name = "un" .. role,
			description = `Removes the {role} role from one or more member(s).`,
			group = definition.group,
			args = {
				{
					type = "members",
					name = "Member(s)",
					description = `The member(s) to remove the {role} role from.`,
					lowerRank = true,
				},
			},

			run = function(context, members)
				local membersUnroled = {}
				for _, userId in members do
					local member = context._K.Data.members[tostring(userId)]
					if context._K.Auth.userRoleRemove(userId, role) then
						table.insert(membersUnroled, member and member.name or userId)
					end
				end

				if #membersUnroled == 0 then
					return
				end

				local roleData = context._K.Data.roles[role]
				context._K.Remote.Notify:FireClient(context.fromPlayer, {
					Text = `<b>Removed Roles:</b> <b><font color="{roleData.color}">{roleData.name}</font></b>\n<b>From:</b> <i>{table.concat(
						membersUnroled,
						", "
					)}</i>`,
				})
			end,
		})
	end

	task.spawn(function()
		local Package = script.Parent.Parent
		local Config = Package and Package:WaitForChild("Config", 5)
		local LEGACY_CONFIG = Config and (Config:FindFirstChild("Legacy") or Config:FindFirstChild("LegacyConfig"))
		if not LEGACY_CONFIG then
			warn("LegacyConfig was not found", Package ~= nil, Config ~= nil)
			return
		end

		local CUSTOM_COMMANDS = require(LEGACY_CONFIG:WaitForChild("Custom_Commands") :: any)
		local SETTINGS = require(LEGACY_CONFIG:WaitForChild("Settings") :: any)

		-- MIGRATE CUSTOM COMMANDS

		if type(CUSTOM_COMMANDS) == "table" then
			local legacyCommandRankToGroup = {
				[0] = "Utility", -- Player
				[1] = "VIP",
				[2] = "Moderation",
				[3] = "Administration",
				[4] = "SuperAdmin",
				[5] = "Creator", -- above 5 is clamped
			}

			local legacyArgToNew = {
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

			for _, definition in CUSTOM_COMMANDS do
				local aliases, desc, rank, argList, run = unpack(definition)

				local args = {}
				for _, arg in argList do
					arg = string.lower(arg)
					local optional = string.find(arg, "/$")
					if optional then
						arg = string.sub(arg, 1, -2)
					end
					table.insert(args, {
						type = legacyArgToNew[arg],
						name = legacyArgToNew[arg],
						optional = optional,
						description = "Migrated from Legacy custom commands.",
					})
				end

				_K.Registry.registerCommand(_K, {
					name = aliases[1],
					aliases = { unpack(aliases, 2) },
					description = tostring(desc[1]) .. "\nMigrated from Legacy config.",
					group = legacyCommandRankToGroup[math.clamp(rank, 0, 5)],
					args = args,
					run = function(context, ...)
						run(context.fromPlayer, { ... })
					end,
				})
			end
		end

		-- MIGRATE SETTINGS

		if not (_K.IsServer and type(SETTINGS) == "table") then
			return
		end

		local settings, ranks = unpack(SETTINGS)
		local owners, superAdmins, admins, mods, vip, banned = unpack(ranks)

		-- BANS

		local function banUser(nameOrUserId)
			if type(nameOrUserId) == "string" then
				local ok, result = _K.Util.Retry(function()
					return _K.Service.Players:GetUserIdFromNameAsync(nameOrUserId)
				end)
				if ok then
					nameOrUserId = result
				end
			end
			if nameOrUserId then
				_K.Auth.banUsers({ nameOrUserId }, "Migrated from Legacy bans.", 0, _K.creatorId)
			end
		end

		for index, nameOrUserId in banned do
			task.spawn(banUser, nameOrUserId)
		end

		-- ROLES

		local defaultRoles = { "vip", "mod", "admin", "superadmin", "creator" }
		local function getRoleFromRank(rank)
			rank = tonumber(rank)
			if rank then
				rank = math.clamp(math.abs(rank), 1, 5)
				local defaultRoleId = defaultRoles[rank]
				if _K.Data.roles[defaultRoleId] then
					return defaultRoleId
				end
				for roleId, role in _K.Data.roles do
					if role._rank == rank then
						return roleId
					end
				end
			end
			return
		end

		local function roleUser(nameOrUserId, rank)
			local roleId = getRoleFromRank(rank)
			if roleId then
				if type(nameOrUserId) == "string" then
					local ok, result = _K.Util.Retry(function()
						return _K.Service.Players:GetUserIdFromNameAsync(nameOrUserId)
					end)
					if ok then
						nameOrUserId = result
					end
				end
				if nameOrUserId then
					_K.Auth.userRoleAdd(nameOrUserId, roleId)
				end
			end
		end

		for rank, list in { vip, mods, admins, superAdmins, owners } do
			for _, nameOrUserId in list do
				task.spawn(roleUser, nameOrUserId, rank)
			end
		end

		if type(settings.GroupAdmin) == "table" then
			local group = {}
			for groupId, groupRanks in settings.GroupAdmin do
				local definition = {}
				for groupRank, powerRank in groupRanks do
					groupRank = tonumber(groupRank)
					local roleId = getRoleFromRank(powerRank)
					if roleId and groupRank then
						table.insert(definition, { rank = groupRank, roles = { roleId } })
					end
				end
				group[groupId] = definition
			end
			_K.Util.Table.deepMerge(_K.Data.async.group, group, true)
		end

		if type(settings.VIPAdmin) == "table" then
			local asset, gamepass = {}, {}
			for itemId, rank in settings.VIPAdmin do
				local roleId = getRoleFromRank(rank)
				if roleId and tonumber(itemId) then
					(if itemId > 0 then asset else gamepass)[itemId] = { roleId }
				end
			end
			_K.Util.Table.deepMerge(_K.Data.async.asset, asset, true)
			_K.Util.Table.deepMerge(_K.Data.async.gamepass, gamepass, true)
			_K.setupPurchasables(asset, "assets")
			_K.setupPurchasables(gamepass, "gamepasses")
		end

		-- SETTINGS

		if settings.AdminCredit == false then
			_K.Data.settings.dashboardButtonRank = false
		end

		if settings.CommandBar == false then
			_K.Data.settings.commandBarRank = false
		end

		if settings.JoinMessage == false then
			_K.Data.settings.joinNotificationRank = false
		end

		if settings.PublicLogs == true then
			_K.Data.roles.everyone.permissions.serverlogs = true
		end

		if settings.Prefix ~= ";" then
			_K.Data.settings.prefix = { settings.Prefix }
		end

		if tonumber(settings.FreeAdmin) then
			local roleId = getRoleFromRank(settings.FreeAdmin)
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
	end)
end
