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
			task.spawn(function()
				_K.Service.Messaging:SubscribeAsync("KA_Announcement", function(message)
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
						_K.Remote.Announce:FireAllClients({
							From = from,
							Text = msg,
							Duration = 0,
						})
					end
				end)
			end)
		end,
		envClient = function(_K)
			task.spawn(function()
				repeat
					task.wait()
				until _K.client and _K.client.ready

				local announcement = _K.client.settings.announcement._value
				if not announcement then
					return
				end

				local message, from = unpack(announcement)
				_K.Announce({
					From = from,
					Text = message,
					Duration = 0,
				})
			end)
		end,

		run = function(context, message)
			if context._K.Data.IS_PRIVATE_SERVER then
				return `Announce are disabled in private servers.`
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
			if context._K.Data.IS_PRIVATE_SERVER then
				return `Announcements are disabled in private servers.`
			end

			context._K.Data.Cache.settings.announcement = false
			context._K.Service.Messaging:PublishAsync("KA_Announcement", nil)
			return
		end,
	},
	{
		name = "role",
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
					context._K.Data.Cache.members[key] = false
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

		run = function(context, assetId)
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
	{
		name = "warn",
		aliases = { "warning" },
		credit = { "Realistic @iiRealistic_Dev" },
		description = "Sends a warning message to one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to warn.",
			},
			{
				type = "string",
				name = "Message",
				description = "The message to send.",
			},
		},
		permissions = { warn = true },
		run = function(context, players, message)
			local warningsCache = context._K.Data.Cache.warnings
			local now = os.time()
			for _, player in players do
				context._K.Remote.Notify:FireClient(player, {
					Text = `<b>Warning:</b> {message}`,
					From = context.from,
				})
				-- Store warning in cache (server)
				if not warningsCache[player.UserId] then
					warningsCache[player.UserId] = {}
				end
				table.insert(warningsCache[player.UserId], {
					message = message,
					from = context.from,
					timestamp = now,
				})
			end

			task.spawn(function()
				local names = {}
				for _, player in players do
					table.insert(names, player.Name)
				end
				context._K.Remote.Notify:FireClient(context.fromPlayer, {
					From = "_K",
					Text = `<b>Warned:</b> <i>{table.concat(names, ", ")}</i>\n<b>Message:</b> {message}`,
				})
			end)
		end,
		runClient = function(ctx, players, message)
			-- Store warning on the client for each player warned (for UI viewing)
			--? probably a better way to do this, but i cant figure it out w/o breaking stuff
			local warnings = ctx._K.Data.Cache.warnings or {}
			local now = os.time()
			for _, player in ipairs(players) do
				local userId = player.UserId
				if not warnings[userId] then
					warnings[userId] = {}
				end
				table.insert(warnings[userId], {
					message = message,
					from = ctx.from,
					timestamp = now,
				})
			end
		end,
	},
	{
		name = "warnings",
		aliases = { "warns" },
		description = "Shows all warnings for a player in a separate window.",
		args = {
			{
				type = "player",
				name = "Player",
				description = "The player whose warnings to view.",
			},
		},
		optionalPrefix = true,
		envClient = function(_K)
			local env = {}
			task.defer(function()
				local window = _K.UI.new "Window" {
					Parent = _K.UI.LayerTopInset,
					Title = "Kohl's Admin Warnings",
					_K.UI.new "UIPadding" {
						PaddingLeft = UDim.new(0, 1),
						PaddingRight = UDim.new(0, 1),
						PaddingTop = UDim.new(0, 1),
						PaddingBottom = UDim.new(0, 1),
					},
				}
				_K.UI.edit(window, {
					[_K.UI.Event.Property] = {
						Visible = function()
							if not window._instance.Visible and #_K.client.dashboard then
								_K.UI.edit(_K.client.dashboard.Tabs, {
									_K.client.dashboard.Logs,
								})
							end
						end,
					},
				})
				env.window = window
			end)
			return env
		end,
		runClient = function(ctx, player)
			local warnings = ctx._K.Data.Cache.warnings or {}
			local playerId = player.UserId
			local playerWarnings = warnings[playerId] or {}
			ctx._K.UI.edit(ctx.env.window, {
				Visible = true,
			})
			print(ctx.env.window._instance:GetFullName(), "opened for", player.Name)
			-- Remove old children and add the new TextLabel
			for _, child in ipairs(ctx.env.window._instance:FindFirstChildOfClass("Frame"):FindFirstChildOfClass("Frame"):GetChildren()) do
				if child:IsA("ScrollingFrame") then
					child:Destroy()
				end
			end

			-- Add a scrolling frame for warnings, similar to Logs UI
			local scrollingFrame = ctx._K.UI.new "ScrollingFrame" {
				Parent = ctx.env.window,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = UDim2.new(1, -8, 1, -8),
				Position = UDim2.new(0, 4, 0, 4),
				CanvasSize = UDim2.new(0, 0, 0, 0),
				ScrollBarThickness = 6,
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
			}

			ctx._K.UI.new "UIListLayout" {
				Parent = scrollingFrame,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 4),
			}

			-- If no warnings, show a message
			if #playerWarnings == 0 then
				ctx._K.UI.new "TextLabel" {
					Parent = scrollingFrame,
					Text = "No warnings found for this player.",
					TextColor3 = Color3.fromRGB(200, 200, 200),
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, 40),
					TextWrapped = true,
					TextScaled = true,
					TextXAlignment = Enum.TextXAlignment.Center,
					TextYAlignment = Enum.TextYAlignment.Center,
					Font = Enum.Font.SourceSansSemibold,
				}
				return
			end

			-- Display each warning in a uniform, log-like style
			for i, warning in ipairs(playerWarnings) do
				local label = ctx._K.UI.new "TextLabel" {
					Parent = scrollingFrame,
					Text = `<b>{os.date("!%Y-%m-%d %H:%M:%S", warning.timestamp)}</b>  <font color="#ffb347">{warning.from}</font>\n{warning.message}`,
					TextColor3 = Color3.fromRGB(230, 230, 230),
					BackgroundTransparency = 0.15,
					BackgroundColor3 = i % 2 == 0 and Color3.fromRGB(40, 40, 40) or Color3.fromRGB(50, 50, 50),
					Size = UDim2.new(1, 0, 0, 48),
					RichText = true,
					TextWrapped = true,
					TextScaled = false,
					TextSize = 16,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Top,
					Font = Enum.Font.Code,
					LayoutOrder = i,
				}

				ctx._K.UI.new "UIPadding" {
					Parent = label,
					PaddingLeft = UDim.new(0, 8),
					PaddingRight = UDim.new(0, 8),
					PaddingTop = UDim.new(0, 4),
					PaddingBottom = UDim.new(0, 4),
				}
			end

		end,
	},
}
