-- dangerous admin commands reserved for the highest roles

return {
	{
		name = "role",
		aliases = { "setrole", "addrole", "giverole" },
		description = "Assigns role(s) to one or more players.",
		-- asks players with the same or higher rank if the command should work on them
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to assign roles.",
				lowerRank = true,
			},
			{
				type = "roles",
				name = "Roles(s)",
				description = "The roles(s) to assign.",
			},
		},

		run = function(context, players, roles)
			for _, player in players do
				for _, role in roles do
					context._K.Auth.userRoleAdd(player.UserId, role)
				end
			end
		end,
	},
	{
		name = "unrole",
		aliases = { "removerole" },
		description = "Removes role(s) from one or more players.",
		-- asks players with the same or higher rank if the command should work on them
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to remove roles from.",
				lowerRank = true,
			},
			{
				type = "roles",
				name = "Roles(s)",
				description = "The roles(s) to remove.",
			},
		},

		run = function(context, players, roles)
			for _, player in players do
				for _, role in roles do
					context._K.Auth.userRoleRemove(player.UserId, role)
				end
			end
		end,
	},
	{
		name = "unadmin",
		aliases = { "removepermissions" },
		description = "Removes all roles and permissions from one or more players.",
		-- asks players with the same or higher rank if the command should work on them
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to kill.",
				lowerRank = true,
			},
		},

		run = function(context, players)
			for _, player in players do
				context._K.Auth.members[tostring(player.UserId)] = nil
			end
		end,
	},
}
