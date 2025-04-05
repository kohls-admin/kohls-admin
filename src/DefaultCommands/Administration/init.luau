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
		env = function(_K)
			task.defer(function()
				local subscribeSuccess, subscribeConnection = pcall(function()
					return _K.Util.Services.MessagingService:SubscribeAsync("KA_Announcement", function(message)
						if type(message.Data) ~= "table" then
							_K.Data.settings.announcement = false
							return
						end

						local oldMsg, oldFrom
						if _K.Data.settings.announcement then
							oldMsg, oldFrom = unpack(_K.Data.settings.announcement)
						end

						local msg, from = unpack(message.Data)
						if msg ~= oldMsg or from ~= oldFrom then
							_K.Data.settings.announcement = message.Data
							_K.Remote.Announce:FireAllClients(msg, from, 0)
						end
					end)
				end)
				if subscribeSuccess then
					game:BindToClose(function()
						subscribeConnection:Disconnect()
					end)
				end
			end)
		end,

		run = function(context, message)
			if game.PrivateServerId ~= "" and game.PrivateServerOwnerId ~= 0 then
				context._K.Remote.Notify:FireClient(context.fromPlayer, {
					From = "_K",
					Text = `Announce is disabled in private servers.`,
					TextColor3 = Color3.new(1, 0, 0),
					Sound = "Call_Leave",
				})
				return
			end

			local filteredMsg = context._K.Util.String.filterForBroadcast(message, context.from)
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

		run = function(context)
			if game.PrivateServerId ~= "" and game.PrivateServerOwnerId ~= 0 then
				context._K.Remote.Notify:FireClient(context.fromPlayer, {
					From = "_K",
					Text = `Announce is disabled in private servers.`,
					TextColor3 = Color3.new(1, 0, 0),
					Sound = "Call_Leave",
				})
				return
			end

			context._K.Data.Cache.settings.announcement = false
			context._K.Data.pendingSaveMain = true
			context._K.Util.Services.MessagingService:PublishAsync("KA_Announcement", nil)
		end,
	},
	{
		name = "role",
		aliases = { "setrole", "addrole", "giverole" },
		description = "Assigns role(s) to one or more user(s).",
		args = {
			{
				type = "userIds",
				name = "Users(s)",
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
				permissions = { saveRoles = true },
			},
		},

		run = function(context, userIds, roles, permanent)
			for _, userId in userIds do
				local rolesAdded = {}
				for _, role in roles do
					local roleAdded = context._K.Auth.userRoleAdd(userId, role, permanent)
					if roleAdded then
						local roleData = context._K.Data.roles[role]
						table.insert(rolesAdded, `<b><font color="{roleData.color}">{roleData.name}</font></b>`)
					end
				end

				local player = context._K.Util.Services.Players:GetPlayerByUserId(userId)
				if player and #rolesAdded > 0 then
					context._K.Remote.Notify:FireClient(player, {
						Text = `Gave you the {table.concat(rolesAdded, ", ")} role{if #rolesAdded > 1 then "s" else ""}!\nSay <b>{context._K.Data.settings.prefix}cmds</b> or <b>{context._K.Data.settings.prefix}info</b> for details.`,
						From = context.from,
					})
				end
			end

			task.spawn(function()
				local roleString = {}
				for _, role in roles do
					local roleData = context._K.Data.roles[role]
					table.insert(roleString, `<b><font color="{roleData.color}">{roleData.name}</font></b>`)
				end

				local names = {}
				for _, userId in userIds do
					table.insert(names, context._K.Util.getUserInfo(userId).DisplayName)
				end

				context._K.Remote.Notify:FireClient(context.fromPlayer, {
					From = "_K",
					Text = `<b>Gave Roles:</b> {table.concat(roleString, ", ")}\n<b>To:</b> <i>{table.concat(
						names,
						", "
					)}</i>`,
				})
			end)
		end,
	},
	{
		name = "unrole",
		aliases = { "removerole" },
		description = "Removes one or more role(s) from one or more member(s).",
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
			local roleString = {}
			for _, role in roles do
				local roleData = context._K.Data.roles[role]
				table.insert(roleString, `<b><font color="{roleData.color}">{roleData.name}</font></b>`)
			end
			context._K.Remote.Notify:FireClient(context.fromPlayer, {
				Text = `<b>Removed Roles:</b> {table.concat(roleString, ", ")}\n<b>From:</b> <i>{table.concat(
					members,
					", "
				)}</i>`,
			})
		end,
	},
	{
		name = "removemember",
		aliases = { "removepermissions" },
		description = "Removes all roles and permissions from one or more member(s).",
		args = {
			{
				type = "members",
				name = "Members(s)",
				description = "The member(s) to remove all roles and permissions from.",
				lowerRank = true,
				ignoreSelf = true,
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
		aliases = { "build", "f3x" },
		credit = { "GigsD4X", "Kohl @Scripth" },
		description = "Gives Building Tools by F3X to one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to give Building Tools by F3X.",
			},
		},
		env = function(_K)
			local tool = _K.DefaultTools:WaitForChild("Building Tools")
			local handle = Instance.new("Part")
			handle.Name = "Handle"
			handle.Size = Vector3.new(0.8, 0.8, 0.8)
			handle.CastShadow = false
			handle.CanTouch = false
			handle.CanQuery = false
			handle.TopSurface = 0
			handle.BottomSurface = 0
			for _, face in Enum.NormalId:GetEnumItems() do
				local decal = Instance.new("Decal")
				decal.Face = face
				decal.Texture = "rbxassetid://129748355"
				decal.Parent = handle
			end
			handle.Parent = tool

			return {
				tool = tool,
			}
		end,

		run = function(context, players)
			for _, player in players do
				local backpack = player:FindFirstChildOfClass("Backpack")
				if not backpack or backpack:FindFirstChild("Building Tools") then
					continue
				end
				context.env.tool:Clone().Parent = backpack
			end
		end,
	},
	{
		name = "classicbtools",
		aliases = { "classicbuild" },
		credit = { "MaximumADHD", "Kohl @Scripth" },
		description = "Gives classic building tools to one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to give classic building tools.",
			},
		},
		env = function(_K)
			local server = _K.DefaultTools:WaitForChild("ClassicBuildTools")
			if server then
				server.Enabled = true
			end
		end,

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
		name = "gear",
		description = "Gives one or more player(s) a gear.",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to give the gear.",
			},
			{
				type = "integer",
				name = "AssetId",
				description = "The assetId of the gear.",
			},
		},

		run = function(context, players, assetId)
			local model = context._K.Util.Services.InsertService:LoadAsset(assetId)
			for _, child in model:GetChildren() do
				if child:IsA("BackpackItem") then
					local gear = child:Clone()
					for _, player in players do
						gear:Clone().Parent = player:FindFirstChild("Backpack") or player.Character
					end
				end
			end
			model:Destroy()
		end,
	},
	{
		name = "insert",
		description = "Inserts a model at the player's position.",
		args = {
			{
				type = "integer",
				name = "AssetId",
				description = "The assetId of the model.",
			},
		},

		run = function(context, assetId)
			local model = context._K.Util.Services.InsertService:LoadAsset(assetId)
			model.Parent = workspace
			model:MoveTo(context.fromPlayer.Character:GetPivot().Position)
			model:MakeJoints()
			table.insert(context._K.cleanupCommands, model)
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
				context._K.Remote.Notify:FireAllClients({
					Text = "The server has been <b>locked</b>.",
					From = context.from,
				})
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
			context._K.Remote.Notify:FireAllClients({
				Text = "The server has been <b>unlocked</b>.",
				From = context.from,
			})
		end,
	},
}
