-- dangerous admin commands reserved for the highest roles

local safeTeleport = require(script.safeTeleport)

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
			{
				type = "boolean",
				name = "Permanent",
				description = "Saves the role to persist across all servers.",
				optional = true,
			},
		},

		run = function(context, players, roles, permanent)
			for _, player in players do
				for _, role in roles do
					context._K.Auth.userRoleAdd(player.UserId, role, permanent)
				end
			end
		end,
	},
	{
		name = "roleid",
		aliases = { "setroleid", "addroleid", "giveroleid" },
		description = "Assigns role(s) to one or more users.",
		-- asks players with the same or higher rank if the command should work on them
		args = {
			{
				type = "integers",
				name = "UserId(s)",
				description = "The user(s) to assign roles.",
			},
			{
				type = "roles",
				name = "Roles(s)",
				description = "The roles(s) to assign.",
			},
			{
				type = "boolean",
				name = "Permanent",
				description = "Saves the role to persist across all servers.",
				optional = true,
			},
		},

		run = function(context, users, roles, permanent)
			for _, userId in users do
				-- FIX: verify that they have a lower rank than you
				for _, role in roles do
					context._K.Auth.userRoleAdd(userId, role, permanent)
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
				type = "members",
				name = "Member(s)",
				description = "The member(s) to remove roles from.",
				lowerRank = true,
			},
			{
				type = "roles",
				name = "Roles(s)",
				description = "The roles(s) to remove.",
			},
		},

		run = function(context, members, roles)
			for _, member in members do
				for _, role in roles do
					context._K.Auth.userRoleRemove(member, role)
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
				-- TODO: make sure this saves and networks...
				context._K.Data.members[tostring(player.UserId)] = nil
			end
		end,
	},
	{
		name = "place",
		aliases = { "pl" },
		description = "Teleports one or more player(s) to a place.",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to teleport to a place.",
				shouldRequest = true,
			},
			{
				type = "integer",
				name = "Place ID",
				description = "The identifier of the place.",
			},
		},
		run = function(context, players, placeId)
			safeTeleport(placeId, players)
		end,
	},
	{
		name = "serverlock",
		aliases = { "slock" },
		description = "Locks the server preventing new players from joining.",
		args = {},
		run = function(context)
			if not context._K._serverLock then
				context._K._serverLock = context.fromPlayer.Name
			end
		end,
	},
	{
		name = "unserverlock",
		aliases = { "unslock" },
		description = "Unlocks the server allowing new players to join again.",
		args = {},
		run = function(context)
			context._K._serverLock = nil
		end,
	},
}
