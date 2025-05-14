local legacyRoles = {
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
					local player = context._K.Util.Services.Players:GetPlayerByUserId(userId)
					if not player then
						continue
					end
					context._K.Remote.Notify:FireClient(player, {
						Text = `Gave you the <b><font color="{roleData.color}">{roleData.name}</font></b> role!\nSay <b>{context._K.Data.settings.prefix}cmds</b> or <b>{context._K.Data.settings.prefix}info</b> for details.`,
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
end
