-- dangerous admin commands reserved for admin role or above

return {
	{
		name = "announce",
		description = "Shows a message to everyone in the game, saves and shows to new users until it has been cleared.",
		args = {
			{
				type = "string",
				name = "Message",
				description = "The message to send.",
			},
		},
		env = function(_K)
			local function announceDataInit()
				local announcement = _K.Data.settings.announcement
				if announcement then
					local message, from = unpack(announcement)
					_K.Remote.Announce:FireAllClients({
						From = from,
						Text = message,
						Duration = 0,
					})
				end
			end
			if _K.Data.settings.announcement then
				announceDataInit()
			else
				_K.Hook.initDataStore:Once(announceDataInit)
			end

			task.spawn(function()
				_K.Service.Messaging:SubscribeAsync("KA_Announcement", function(message)
					if type(message.Data) ~= "table" then
						_K.Data.settings.announcement = false
						return
					end

					local msg, from = unpack(message.Data)
					_K.Data.settings.announcement = message.Data
					_K.Remote.Announce:FireAllClients({
						From = from,
						Text = msg,
						Duration = 0,
					})
				end)
			end)
		end,

		run = function(context, message)
			if context._K.Data.SEPARATE_DATASTORE then
				return `Announcements are disabled in private servers.`
			end

			local announcement = { message, context.from }
			context._K.Data.Cache.settings.announcement = announcement
			context._K.Service.Messaging:PublishAsync("KA_Announcement", announcement)
			return
		end,
	},
	{
		name = "unannounce",
		aliases = { "clearannounce" },
		description = "Removes the pinned announcement.",
		args = {},

		run = function(context)
			if context._K.Data.SEPARATE_DATASTORE then
				return `Announcements are disabled in private servers.`
			end

			context._K.Data.Cache.settings.announcement = context._K.Data.REMOVE
			context._K.Service.Messaging:PublishAsync("KA_Announcement", nil)
			return
		end,
	},
	{
		name = "role",
		aliases = { "rank" },
		description = "Assigns a role(s) to one or more user(s).",
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
				name = "Temporary",
				description = "Assigns the role(s) only for the current server.",
				optional = true,
			},
		},
		permissions = { saveRoles = true },

		run = function(context, userIds, roles, temporary)
			for _, userId in userIds do
				local rolesAdded = {}
				for _, role in roles do
					if context._K.Auth.userRoleAdd(userId, role, if temporary then false else true) then
						local roleData = context._K.Data.roles[role]
						table.insert(rolesAdded, `<b><font color="{roleData.color}">{roleData.name}</font></b>`)
					end
				end

				local player = context._K.Service.Players:GetPlayerByUserId(userId)
				if player and #rolesAdded > 0 then
					local prefix = context._K.getCommandPrefix(player.UserId)
					context._K.Remote.Notify:FireClient(player, {
						Text = `Gave you the {table.concat(rolesAdded, ", ")} role{if #rolesAdded > 1 then "s" else ""}!\nSay <b>{prefix}cmds</b> or <b>{prefix}info</b> for details.`,
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
		name = "temprole",
		aliases = { "temprank" },
		description = "Assigns a temporary role(s) to one or more user(s).",
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
		},

		run = function(context, userIds, roles)
			for _, userId in userIds do
				local rolesAdded = {}
				for _, role in roles do
					if context._K.Auth.userRoleAdd(userId, role) then
						local roleData = context._K.Data.roles[role]
						table.insert(rolesAdded, `<b><font color="{roleData.color}">{roleData.name}</font></b>`)
					end
				end

				local player = context._K.Service.Players:GetPlayerByUserId(userId)
				if player and #rolesAdded > 0 then
					local prefix = context._K.getCommandPrefix(player.UserId)
					context._K.Remote.Notify:FireClient(player, {
						Text = `Gave you the {table.concat(rolesAdded, ", ")} role{if #rolesAdded > 1 then "s" else ""}!\nSay <b>{prefix}cmds</b> or <b>{prefix}info</b> for details.`,
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
		aliases = { "removerole", "unrank", "removerank" },
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
			local membersUnroled = {}
			for _, userId in members do
				local member = context._K.Data.members[tostring(userId)]
				for _, role in roles do
					if context._K.Auth.userRoleRemove(userId, role) then
						table.insert(membersUnroled, member and member.name or userId)
					end
				end
			end

			if #membersUnroled == 0 then
				return
			end

			local roleString = {}
			for _, role in roles do
				local roleData = context._K.Data.roles[role]
				table.insert(roleString, `<b><font color="{roleData.color}">{roleData.name}</font></b>`)
			end
			context._K.Remote.Notify:FireClient(context.fromPlayer, {
				Text = `<b>Removed Roles:</b> {table.concat(roleString, ", ")}\n<b>From:</b> <i>{table.concat(
					membersUnroled,
					", "
				)}</i>`,
			})
		end,
	},
	{
		name = "removemember",
		aliases = { "removepermissions", "removeroles" },
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
			local membersUnroled = {}
			for _, userId in members do
				local key = tostring(userId)
				local member = context._K.Data.members[key]
				if member then
					context._K.Data.members[key] = nil
					context._K.Data.Cache.members[key] = context._K.Data.REMOVE
					context._K.Remote.Member:FireAllClients(key)
					table.insert(membersUnroled, member and member.name or key)
				end
			end

			if #membersUnroled == 0 then
				return
			end

			context._K.Remote.Notify:FireClient(context.fromPlayer, {
				Text = `<b>Removed member{#membersUnroled > 1 and "s" or ""}:</b> <i>{table.concat(
					membersUnroled,
					", "
				)}</i>`,
			})
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
			local env = {}

			task.defer(function()
				env.tool = _K.Tools:WaitForChild("Building Tools") :: Tool
				env.tool.CanBeDropped = false
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
				handle.Parent = env.tool
			end)

			return env
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
			local model = context._K.Service.Insert:LoadAsset(assetId)
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
		aliases = { "ins" },
		description = "Inserts a model at the player's position.",
		args = {
			{
				type = "integer",
				name = "AssetId",
				description = "The assetId of the model.",
			},
		},

		env = function(_K)
			return {
				blocked = { 59524079, 59524162, 59524102, 59524044, 59524124, 59524006 },
			}
		end,
		run = function(context, assetId)
			if table.find(context.env.blocked, assetId) then
				return "Model has been blocked."
			end
			local ok, result = pcall(function()
				return context._K.Service.Insert:LoadAsset(assetId)
			end)
			if not ok then
				if string.find(result, "authorized") then
					return `{result} It must be added to the Game Creator's inventory!`
				else
					return result
				end
			end
			local packageRef = result:FindFirstChild("packageRef", true)
			if packageRef and packageRef:FindFirstChildOfClass("ObjectValue") then
				result:Destroy()
				return "Model has been blocked."
			end
			result.Parent = workspace
			result:MoveTo(context.fromPlayer.Character:GetPivot().Position)
			result:MakeJoints()
			table.insert(context._K.cleanupCommands, result)
			return
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
				type = "integer @ reservedServer",
				name = "PlaceId",
				description = "The identifier of the place or reserved server.",
			},
		},
		run = function(context, players, id)
			if type(id) == "number" then
				context._K.Util.SafeTeleport(id, players)
			else
				local code, placeId = unpack(id)
				local options = Instance.new("TeleportOptions")
				options.ReservedServerAccessCode = code
				context._K.Util.SafeTeleport(placeId, players, options)
			end
			for _, player in players do
				context._K.Remote.Notify:FireClient(player, {
					{
						From = "_K",
						Text = "Teleport initiated...",
					},
				})
			end
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
