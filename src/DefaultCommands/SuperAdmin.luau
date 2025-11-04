-- dangerous commands restricted to superadmins

local BadgeService = game:GetService("BadgeService")

return {
	{
		name = "badge",
		aliases = { "awardbadge", "givebadge" },
		description = "Awards a badge to one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to award the badge.",
			},
			{
				type = "integer",
				name = "Badge ID",
				description = "The badge ID.",
			},
		},

		run = function(context, players, badge)
			for _, player in players do
				if BadgeService:UserHasBadgeAsync(player.UserId, badge) then
					context._K.Remote.Notify:FireClient(context.fromPlayer, {
						Text = `{player.Name} already has the badge!`,
					})
				else
					local success, err = BadgeService:AwardBadge(player.UserId, badge)

					context._K.Remote.Notify:FireClient(
						context.fromPlayer,
						{ Text = if success then "Badge awarded!" else `Failed to award badge: {err}` }
					)
				end
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
		name = "clearterrain",
		aliases = { "cterrain", "clrterrain", "removeterrain" },
		description = "Removes all terrain.",
		args = {},
		run = function(context)
			workspace.Terrain:Clear()
		end,
	},
	{
		name = "incognito",
		description = "Hides one or more player(s) from lower rank players. (Persists until rejoin)",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to hide.",
				shouldRequest = true,
			},
			{
				type = "boolean",
				name = "Hide Character",
				description = "Hides the character, defaults to true.",
				optional = true,
			},
		},

		envClient = function(_K)
			local env = {
				hidden = _K.UI.state({}),
			}

			local function removeCharacter(name: string)
				local character = workspace:WaitForChild(name)
				if not (character and character:FindFirstChildOfClass("Humanoid")) then
					character = nil
					for _, child in workspace:GetChildren() do
						if child.Name == name and child:IsA("Model") and child:FindFirstChildOfClass("Humanoid") then
							character = child
							break
						end
					end
				end
				if character then
					character:Destroy()
				end
			end

			_K.Remote.Incognito.OnClientEvent:Connect(
				function(userIdOrName: number | string, hiddenRank: number, hideCharacter: boolean?)
					if type(userIdOrName) == "number" then
						if hideCharacter == nil then -- remove from hidden list
							env.hidden._value[userIdOrName] = nil
							env.hidden(env.hidden._value)
						else
							local player = _K.Service.Players:GetPlayerByUserId(userIdOrName)
							if player then
								env.hidden._value[userIdOrName] = player.Name
								env.hidden(env.hidden._value)
								if hiddenRank > _K.client.rank._value then
									if hideCharacter then
										pcall(game.Destroy, player.Character)
									end
									player:Destroy()
								end
							end
						end
					elseif type(userIdOrName) == "string" and hiddenRank > _K.client.rank._value then
						removeCharacter(userIdOrName)
					end
				end
			)

			return env
		end,

		env = function(_K)
			local env = {
				hidden = {},
				remote = _K.Remote.Incognito :: RemoteEvent,
			}

			function env.apply(hiddenPlayer: Player, hideCharacter: boolean?)
				local hiddenRank = _K.Auth.getRank(hiddenPlayer.UserId)
				if env.hidden[hiddenPlayer] == false and hideCharacter then
					env.remote:FireAllClients(hiddenPlayer.Name, hiddenRank, hideCharacter)
				else
					env.remote:FireAllClients(hiddenPlayer.UserId, hiddenRank, hideCharacter)
				end
				env.hidden[hiddenPlayer] = hideCharacter
			end

			local function characterAdded(character)
				local player = _K.Service.Players:GetPlayerFromCharacter(character)
				if env.hidden[player] ~= nil then
					local hiddenRank = _K.Auth.getRank(player.UserId)
					env.remote:FireAllClients(character.Name, hiddenRank)
				end
			end

			_K.Util.SafePlayerAdded(function(player: Player)
				for hiddenPlayer, hideCharacter in env.hidden do
					local hiddenRank = _K.Auth.getRank(hiddenPlayer.UserId)
					env.remote:FireAllClients(hiddenPlayer.UserId, hiddenRank, hideCharacter)
				end
				if player.Character then
					characterAdded(player.Character)
				end
				player.CharacterAdded:Connect(characterAdded)
			end)

			_K.Service.Players.PlayerRemoving:Connect(function(player)
				if env.hidden[player] ~= nil then
					env.hidden[player] = nil
					env.remote:FireAllClients(player.UserId)
				end
			end)

			return env
		end,

		run = function(context, players: { Player }, hideCharacter: boolean?)
			if hideCharacter == nil then
				hideCharacter = true
			end
			for _, player in players do
				context.env.apply(player, hideCharacter)
			end
		end,
	},
	{
		name = "incognitolist",
		description = "Views all incognito players in the server.",

		envClient = function(_K)
			local UI = _K.UI

			local hidden = _K.Registry.commands.incognito.env.hidden

			local scroller = UI.new "ScrollerFast" {
				List = hidden,
				Enabled = true,
				DictList = true,
				FilterInput = true,
				ReverseOrder = true,
				Visible = true,
				CreateItem = function(self, lineData)
					return UI.new "Frame" {
						BackgroundTransparency = 1,
						Size = self.ItemSize,

						UI.new "UIPadding" {
							PaddingTop = UI.Theme.PaddingHalf,
							PaddingBottom = UI.Theme.PaddingHalf,
						},

						UI.new "UIListLayout" {
							VerticalAlignment = Enum.VerticalAlignment.Center,
							FillDirection = Enum.FillDirection.Horizontal,
							SortOrder = Enum.SortOrder.LayoutOrder,
							Padding = UI.Theme.Padding,
						},

						UI.new "ImageLabel" {
							BackgroundTransparency = UI.Theme.TransparencyHeavy,
							BackgroundColor3 = UI.Theme.PrimaryText,
							Size = UDim2.new(1, 0, 1, 0),
							SizeConstraint = Enum.SizeConstraint.RelativeYY,

							UI.new "UICorner" {
								CornerRadius = UDim.new(1, 0),
							},
							UI.new "Stroke" {},
						},

						UI.new "TextLabel" {
							AutoLocalize = false,
							AutomaticSize = Enum.AutomaticSize.X,
							BackgroundTransparency = 1,
							Size = UDim2.new(0, 0, 1, 0),
							RichText = true,
							Font = UI.Theme.FontMono,
							TextSize = UI.Theme.FontSize,
							TextColor3 = UI.Theme.PrimaryText,
							TextStrokeColor3 = UI.Theme.Primary,
							TextStrokeTransparency = UI.Theme.TextStrokeTransparency,
							TextTruncate = Enum.TextTruncate.SplitWord,
							TextXAlignment = Enum.TextXAlignment.Left,

							UI.new "UIFlexItem" { FlexMode = Enum.UIFlexMode.Fill },
						},
					}
				end,
				RenderItem = function(self, lineItem, lineData)
					lineItem.ImageLabel.Image = `rbxthumb://type=AvatarHeadShot&id={lineData}&w=48&h=48`
					lineItem.TextLabel.Text =
						`<b>{hidden._value[lineData]}</b> <font transparency="0.5">[{lineData}]</font>`
				end,
			}

			UI.edit(scroller._scroller, {
				UI.new "UIFlexItem" {
					FlexMode = Enum.UIFlexMode.Fill,
				},
			})

			UI.edit(scroller._instance, {
				UI.new "UIPadding" {
					PaddingTop = UDim.new(0, 1),
					PaddingBottom = UDim.new(0, 1),
					PaddingLeft = UDim.new(0, 1),
					PaddingRight = UDim.new(0, 1),
				},
			})

			return {
				scroller = scroller,
				window = UI.new "Window" {
					Parent = UI.LayerTopInset,
					Title = "Incognito Players",
					Exitable = true,
					Position = UDim2.new(0.5, -128, 0.5, -128),
					Size = UDim2.new(0, 256, 0, 256),

					scroller,
				},
			}
		end,
		runClient = function(context, player)
			context.env.window._instance.Visible = true
		end,
	},
	{
		name = "reserve",
		aliases = { "privateserver" },
		description = "Reserves a private server.",
		args = {
			{
				type = "rawString",
				name = "AccessCode",
				description = "The access code for joining the reserved server.",
			},
			{
				type = "integer",
				name = "PlaceId",
				description = "The place identifier, omit for the current place.",
				optional = true,
			},
		},
		env = function(_K)
			task.spawn(
				_K.Service.Messaging.SubscribeAsync,
				_K.Service.Messaging,
				"_K_ReservedServers",
				function(message)
					local data = message.Data
					if data then
						_K.Data.reservedServers[data[1]] = { unpack(data, 2) }
						for _, player in _K.Service.Players:GetPlayers() do
							if
								_K.Auth.hasCommand(player.UserId, "place")
								or _K.Auth.hasCommand(player.UserId, "unreserve")
							then
								_K.Remote.ReservedServers:FireClient(player, {
									[data[1]] = { unpack(data, 2) },
								})
							end
						end
					end
				end
			)
			return
		end,
		envClient = function(_K)
			_K.Remote.ReservedServers.OnClientEvent:Connect(function(data)
				if data then
					_K.Util.Table.merge(_K.Data.reservedServers, data)
				end
			end)
		end,
		run = function(context, code: string, placeId: string?)
			if context._K.Data.SEPARATE_DATASTORE then
				return `Reserve command is disabled in private servers.`
			end

			placeId = placeId or game.PlaceId
			local data = { context._K.Service.Teleport:ReserveServer(placeId), placeId }
			context._K.Data.Store.updateAsync("Servers", function(store)
				if store == nil then
					store = {}
				end
				store[code] = data
				return store
			end)

			context._K.Service.Messaging:PublishAsync("_K_ReservedServers", { code, unpack(data, 2) })
			context._K.Remote.Notify:FireClient(context.fromPlayer, {
				Text = `Server "<b>{code}</b>" has been reserved, use <b>{context._K.getCommandPrefix(context.from)}place me @{code}</b> to join it!`,
			})

			return
		end,
	},
	{
		name = "unreserve",
		aliases = { "delreserve", "removereserve", "removeprivateserver" },
		description = "Removes a reserved server.",
		args = {
			{
				type = "reservedServer",
				name = "AccessCode",
				description = "The access code of the reserved server.",
			},
		},
		run = function(context, code: string)
			if context._K.Data.SEPARATE_DATASTORE then
				return `Unreserve command is disabled in private servers.`
			end

			local removed
			context._K.Data.Store.updateAsync("Servers", function(store)
				if store == nil then
					store = {}
				end
				if store[code] then
					removed = true
				end
				store[code] = nil
				return store
			end)

			context._K.Service.Message:PublishAsync("_K_ReservedServers", { code })
			context._K.Remote.Notify:FireClient(context.fromPlayer, {
				Text = `Server "<b>{code}</b>" {if removed then "has been removed" else "was NOT found"}!`,
			})

			return
		end,
	},
	{
		name = "shutdown",
		aliases = { "stopserver" },
		description = "Shuts down the server.",
		args = {
			{
				type = "timeSimple",
				name = "Delay",
				description = "The delay before shutting down.",
				optional = true,
			},
			{
				type = "string",
				name = "Reason",
				description = "The reason for the shutdown.",
				optional = true,
			},
		},
		run = function(context, delay: number?, reason: string?)
			if delay ~= nil then
				context._K.Remote.Announce:FireAllClients({
					Text = `Server will shut down in {delay} seconds`,
					From = context.from,
					Duration = delay,
				})
				task.wait(delay)
			end
			local from = tostring(context.fromPlayer or context.from)
			local function kick(player)
				player:Kick(`{from} has shutdown the server.{if reason then `\nReason: {reason}` else ""}`)
			end
			game:GetService("Players").PlayerAdded:Connect(kick)
			for _, player in game:GetService("Players"):GetPlayers() do
				kick(player)
			end
		end,
	},
	{
		name = "global",
		aliases = { "gcmd" },
		description = "Runs a command string globally in all servers.",
		args = {
			{
				type = "rawString",
				name = "Command string",
				description = "The command string to run.",
			},
		},
		env = function(_K)
			task.spawn(function()
				_K.Service.Messaging:SubscribeAsync("KA_GlobalCommand", function(message)
					local from, commandString = unpack(message.Data)
					if from and commandString then
						_K.Process.runCommands(_K, from, commandString, true, true)
					end
				end)
			end)

			return
		end,
		run = function(context, commandString: string)
			if context.global then
				return
			end

			if context._K.Data.SEPARATE_DATASTORE then
				return `Global commands are disabled in private servers.`
			end

			local prefix = context._K.getCommandPrefix(context.from)
			if string.find(commandString, string.format('^%s[^%s"`,%%s]', prefix, prefix)) ~= 1 then
				commandString = prefix .. commandString
			end

			local ok, result = context._K.Process.prepareCommands(context._K, context.from, commandString)
			if not ok then
				return result
			end

			local commandStrings = {}
			local msgCommands = { "hint", "privatehint", "message", "privatemessage", "fullmessage", "notify" }

			for index, command in result do
				if not command.definition.args then
					local last = command.array[#command.array]
					table.insert(commandStrings, string.sub(commandString, command.array[1][1], last[1] + #last[2]))
				end

				local argType = if table.find(msgCommands, command.definition.name) then "rawString" else "string"
				local argStrings = {}
				for i, arg in command.definition.args do
					if arg.type == argType then
						local filtered = context._K.Util.String.filterForBroadcast(command.args[i].rawArg, context.from)
						table.insert(argStrings, filtered)
					else
						table.insert(argStrings, command.args[i].rawArg)
					end
				end

				table.insert(commandStrings, `{prefix}{command.definition.name} {table.concat(argStrings, " ")}`)
			end

			commandString = table.concat(commandStrings, " ")
			context._K.Service.Messaging:PublishAsync("KA_GlobalCommand", { context.from, commandString })
			return
		end,
	},
}
