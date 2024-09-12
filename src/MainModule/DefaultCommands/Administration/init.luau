-- dangerous admin commands reserved for admin role or above

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
			local filteredMsg = context._K.Util.String.filterForBroadcast(message, context.from)
			context._K.Remote.Announce:FireAllClients(filteredMsg, context.from)

			local announcement = { filteredMsg, context.from }
			context._K.Data.Cache.settings.announcement = announcement
			context._K.Data.pendingSaveMain = true
			context._K.Util.Services.MessagingService:PublishAsync("KA_Announcement", announcement)
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
			context._K.Util.Services.MessagingService:PublishAsync("KA_Announcement", nil)
		end,
	},
	{
		name = "role",
		aliases = { "setrole", "addrole", "giverole" },
		description = "Assigns role(s) to one or more player(s).",
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
							`Gave you the <b><font color="{roleData.color}">{roleData.name}</font></b> role!\nSay <b>{context._K.Data.settings.prefix}cmds</b> or <b>{context._K.Data.settings.prefix}info</b> for details.`,
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
		description = "Assigns role(s) to one or more user(s).",
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
		description = "Removes role(s) from one or more member(s).",
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
		description = "Removes all roles and permissions from one or more member(s).",
		args = {
			{
				type = "members",
				name = "Members(s)",
				description = "The member(s) to remove all roles and permissions from.",
				lowerRank = true,
			},
		},

		run = function(context, members)
			for _, member in members do
				context._K.Data.members[member] = nil
				context._K.Data.Cache.members[member] = context._K.Data.Store.REMOVE
				context._K.Data.pendingSaveMain = true
				context._K.Remote.Member:FireAllClients(member)
			end
		end,
	},
	{
		name = "btools",
		aliases = { "build" },
		description = "Gives building tools to one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to give building tools.",
			},
		},

		run = function(context, players)
			local NEW = context._K.Flux.new
			for _, player in players do
				if not player:FindFirstChild("Backpack") or player.Backpack:FindFirstChild("_KGameTool") then
					continue
				end

				local move = NEW "Tool" {
					Name = "_KGameTool",
					Grip = CFrame.new(-0.05, -0.1, -0.8) * CFrame.Angles(math.pi / 2, 0, 0),

					NEW "Part" {
						Name = "Handle",
						Size = Vector3.new(0.2, 0.8, 3),
						CanCollide = false,
						NEW "SpecialMesh" {
							MeshId = "rbxassetid://16884681",
							TextureId = "rbxassetid://16884673",
							Offset = Vector3.new(0.1, 0, 0),
						},
					},
				}
				move:AddTag("_KGameTool")
				move.Parent = player.Backpack

				local clone = NEW "Tool" {
					Name = "_KClone",
					Grip = CFrame.new(0.05, 0, -1) * CFrame.Angles(math.pi / 2, 0, 0),

					NEW "Part" {
						Name = "Handle",
						Size = Vector3.new(1, 0.8, 4),
						CanCollide = false,
						NEW "SpecialMesh" {
							MeshId = "rbxasset://fonts/clonewand.mesh",
							TextureId = "rbxasset://textures/CloneWandTexture.png",
							Scale = Vector3.new(0.75, 0.75, 1),
						},
					},
				}
				clone:AddTag("_KClone")
				clone.Parent = player.Backpack

				local delete = NEW "Tool" {
					Name = "_KHammer",
					Grip = CFrame.new(0, -1, 0),

					NEW "Part" {
						Name = "Handle",
						Size = Vector3.new(1, 3.8, 1),
						CanCollide = false,
						NEW "SpecialMesh" {
							MeshId = "rbxasset://fonts/hammer.mesh",
							TextureId = "rbxasset://textures/hammertex128.png",
						},
					},
				}
				delete:AddTag("_KHammer")
				delete.Parent = player.Backpack
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
			context._K.Util.SafeTeleport(placeId, players)
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
