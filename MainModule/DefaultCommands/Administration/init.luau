-- dangerous admin commands reserved for admin role or above

local Players = game:GetService("Players")
local TextService = game:GetService("TextService")

local safeTeleport = require(script.safeTeleport)

return {
	{
		name = "announce",
		description = "Shows a message to everyone in the game, saves and shows to new users until it has been cleared.",
		args = {
			{
				type = "stringGreedy",
				name = "Message",
				description = "The message to send.",
			},
		},

		run = function(context, message)
			context._K.Data.Cache.settings.announcement = { message, context.from }
			context._K.Data.pendingSaveMain = true
			-- TODO: fire to all servers with messagingservice
			local ok, result = pcall(
				TextService.FilterStringAsync,
				TextService,
				message,
				context.from,
				Enum.TextFilterContext.PublicChat
			)

			if not ok then
				return
			end

			for _, player in Players:GetPlayers() do
				task.spawn(function()
					local success, msg = pcall(result.GetChatForUserAsync, result, player.UserId)
					if success then
						context._K.Remote.Announce:FireClient(player, msg, context.from)
					end
				end)
			end
		end,
	},
	{
		name = "unannounce",
		aliases = { "clearannounce" },
		description = "Removes the pinned announcement.",
		args = {},

		run = function(context, message)
			context._K.Data.Cache.settings.announcement = false
			context._K.Data.pendingSaveMain = true
			-- TODO: fire to all servers with messagingservice
		end,
	},
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
					local roleAdded = context._K.Auth.userRoleAdd(player.UserId, role, permanent)
					if roleAdded then
						local roleData = context._K.Data.roles[role]
						context._K.Remote.Notify:FireClient(
							player,
							`Gave you the <b><font color="{roleData.color}">{roleData.name}</font></b> role!\nSay <b>{context._K.Data.settings.prefix}info</b> for details.`,
							context.from
						)
					end
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
				context._K.Remote.Notify:FireAllClients("The server has been <b>locked</b>.", context.from)
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
			context._K.Remote.Notify:FireAllClients("The server has been <b>unlocked</b>.", context.from)
		end,
	},
}
