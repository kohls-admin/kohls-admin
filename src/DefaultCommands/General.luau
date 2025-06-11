-- "non-abusive" commands for game staff members

local Players = game:GetService("Players")

local playingSound = nil

return {
	{
		name = "clean",
		aliases = { "clear", "clr" },
		description = "Cleans up miscellaneous admin objects like cloned characters, looped commands, and scripts.",
		args = {},

		run = function(context)
			for _, object in context._K.cleanupCommands do
				local objectType = typeof(object)
				if objectType == "Instance" then
					object:Destroy()
				elseif objectType == "function" then
					object()
				end
			end
			local discoCommand = context._K.Registry.commands.disco
			if discoCommand then
				task.spawn(discoCommand.env.cleanup)
			end
			context._K.Remote.StartCountdown:FireAllClients()
		end,
	},
	{
		name = "hint",
		aliases = { "h" },
		description = "Sends a hint to everyone in the server.",
		args = {
			{
				type = "rawString",
				name = "Message",
				description = "The message to send.",
			},
		},
		envClient = function(_K)
			local existing
			_K.Remote.Hint.OnClientEvent:Connect(function(message: string, duration: number?)
				if existing then
					existing:Destroy()
				end
				local hint = _K.UI.new "TextLabel" {
					Name = "Hint",
					Parent = _K.UI.LayerTop,
					AutomaticSize = Enum.AutomaticSize.Y,
					Size = UDim2.new(1, 0, 0, 0),
					BackgroundColor3 = _K.UI.Theme.Primary,
					BackgroundTransparency = _K.UI.Theme.Transparency,
					Font = _K.UI.Theme.Font,
					TextSize = _K.UI.Theme.FontSize,
					TextColor3 = _K.UI.Theme.PrimaryText,
					TextStrokeColor3 = _K.UI.Theme.Primary,
					TextStrokeTransparency = _K.UI.Theme.TextStrokeTransparency,
					Text = message,
					RichText = true,

					_K.UI.new "UIPadding" {
						PaddingTop = _K.UI.Theme.Padding,
						PaddingBottom = _K.UI.Theme.Padding,
					},
				}
				existing = hint
				task.delay(duration or 4 + 0.0625 * #message, game.Destroy, hint)
			end)
		end,
		env = function(_K)
			return { remote = _K.Remote.Hint }
		end,
		run = function(context, message: string)
			local ok, result = context._K.Util.String.filterResult(message, context.from)
			if not ok then
				return result
			end
			for _, player in Players:GetPlayers() do
				task.spawn(function()
					local msg = context._K.Util.String.filterResultForUser(result, context.from, player.UserId)
					context.env.remote:FireClient(player, `<b>{context.fromPlayer}:</b> {msg}`)
				end)
			end
			return
		end,
	},
	{
		name = "privatehint",
		aliases = { "phint", "ph" },
		description = "Sends a private hint to one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to hint.",
			},
			{
				type = "rawString",
				name = "Message",
				description = "The message to send.",
			},
		},
		run = function(context, players: { Player }, message: string)
			local ok, result = context._K.Util.String.filterResult(message, context.from)
			if not ok then
				return result
			end
			for _, player in players do
				task.spawn(function()
					local msg = context._K.Util.String.filterResultForUser(result, context.from, player.UserId)
					context._K.Remote.Hint:FireClient(player, `<b>{context.fromPlayer}:</b> {msg}`)
				end)
			end
			return
		end,
	},
	{
		name = "message",
		aliases = { "m", "msg" },
		description = "Sends a message to everyone in the server.",
		args = {
			{
				type = "rawString",
				name = "Message",
				description = "The message to send.",
			},
		},

		run = function(context, message)
			local ok, result = context._K.Util.String.filterResult(message, context.from)
			if not ok then
				return result
			end
			for _, player in Players:GetPlayers() do
				task.spawn(function()
					local msg = context._K.Util.String.filterResultForUser(result, context.from, player.UserId)
					context._K.Remote.Announce:FireClient(player, {
						From = context.from,
						Text = msg,
					})
				end)
			end
			return
		end,
	},
	{
		name = "fullmessage",
		aliases = { "fm", "fmsg" },
		description = "Sends a full screen message to everyone in the server.",
		args = {
			{
				type = "rawString",
				name = "Message",
				description = "The message to send.",
			},
		},
		envClient = function(_K)
			local existing
			_K.Remote.FullScreenMessage.OnClientEvent:Connect(function(from: number, message: string, duration: number?)
				if existing then
					existing:Destroy()
				end
				local msg = _K.UI.new "TextLabel" {
					Name = "Message",
					Parent = _K.UI.LayerTop,
					AutomaticSize = Enum.AutomaticSize.Y,
					Size = UDim2.new(1, 0, 1, 0),
					BackgroundColor3 = _K.UI.Theme.Primary,
					BackgroundTransparency = _K.UI.Theme.Transparency,
					Font = _K.UI.Theme.Font,
					TextSize = _K.UI.Theme.FontSizeDouble,
					TextColor3 = _K.UI.Theme.PrimaryText,
					TextStrokeColor3 = _K.UI.Theme.Primary,
					TextStrokeTransparency = _K.UI.Theme.TextStrokeTransparency,
					Text = message,
					TextWrapped = true,
					RichText = true,

					_K.UI.new "UIPadding" {
						PaddingLeft = _K.UI.Theme.PaddingDouble,
						PaddingRight = _K.UI.Theme.PaddingDouble,
					},
				}
				local userFrame = _K.client.UserFrame(from)
				userFrame.Icon.Image = `rbxthumb://type=AvatarHeadShot&id={from}&w=150&h=150`
				_K.UI.edit(userFrame, {
					Parent = msg,
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.new(0.5, 0, 0.05, 0),
					_K.UI.new "UIScale" {
						Scale = 2,
					},
				})
				local displaySize = _K.UI.state(userFrame.From.From, "AbsoluteSize")
				_K.UI.edit(userFrame.From.Badge, {
					Position = _K.UI.compute(function(use)
						return UDim2.fromOffset(use(displaySize).X / 2 + 4, 0)
					end),
				})
				existing = msg
				task.delay(duration or 4 + 0.0625 * #message, game.Destroy, msg)
			end)
		end,
		env = function(_K)
			return { remote = _K.Remote.FullScreenMessage }
		end,
		run = function(context, message)
			local ok, result = context._K.Util.String.filterResult(message, context.from)
			if not ok then
				return result
			end
			for _, player in Players:GetPlayers() do
				task.spawn(function()
					local msg = context._K.Util.String.filterResultForUser(result, context.from, player.UserId)
					context.env.remote:FireClient(player, context.from, msg)
				end)
			end
			return
		end,
	},
	{
		name = "notify",
		aliases = { "n" },
		description = "Sends a notification to one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to notify.",
			},
			{
				type = "rawString",
				name = "Message",
				description = "The message to send.",
			},
		},

		run = function(context, players, message)
			local ok, result = context._K.Util.String.filterResult(message, context.from)
			if not ok then
				return result
			end
			for _, player in players do
				task.spawn(function()
					local msg = context._K.Util.String.filterResultForUser(result, context.from, player.UserId)
					context._K.Remote.Notify:FireClient(player, { Text = msg, From = context.from })
				end)
			end
			return
		end,
	},
	{
		name = "privatemessage",
		aliases = { "pm", "pmsg" },
		description = "Sends a message to one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to message.",
			},
			{
				type = "rawString",
				name = "Message",
				description = "The message to send.",
			},
		},

		run = function(context, players, message)
			local ok, result = context._K.Util.String.filterResult(message, context.from)
			if not ok then
				return result
			end
			for _, player in players do
				task.spawn(function()
					local msg = context._K.Util.String.filterResultForUser(result, context.from, player.UserId)
					context._K.Remote.Announce:FireClient(player, {
						From = context.from,
						Text = msg,
					})
				end)
			end
			return
		end,
	},
	{
		name = "countdown",
		aliases = { "cd" },
		description = "Starts a countdown.",
		args = {
			{
				type = "integer",
				name = "Duration",
				description = "The duration of the countdown, in seconds.",
				optional = true,
			},
		},
		envClient = function(_K)
			local countdown, progress
			_K.Remote.StartCountdown.OnClientEvent:Connect(function(start, duration)
				if countdown then
					countdown:Disconnect()
				end
				if progress then
					progress:Destroy()
				end
				if not start then
					return
				end

				local time = _K.UI.new "TextLabel" {
					Name = "Time",
					AnchorPoint = Vector2.new(0.5, 0.5),
					Size = UDim2.new(1, 0, 1, 0),
					BackgroundTransparency = 1,
					Position = UDim2.new(0.5, 0, 0.5, 0),
					Font = _K.UI.Theme.Font,
					TextSize = 100,
					TextColor3 = _K.UI.Theme.SecondaryText,
					TextStrokeColor3 = _K.UI.Theme.PrimaryText,
					TextStrokeTransparency = 0.5,
					Text = duration,
					ZIndex = 2,
				}
				progress = _K.UI.new "CircleProgress" {
					Parent = _K.UI.LayerTopInset,
					Position = UDim2.fromOffset(math.floor(_K.UI.LayerTop.AbsoluteSize.X / 2) - 64, 0),
					Size = UDim2.new(0, 128, 0, 128),
					ZIndex = -1,
					time,
				}

				_K.UI.Sound.Hover03:Play()

				countdown = _K.Service.Run.Heartbeat:Connect(function()
					local delta = workspace:GetServerTimeNow() - start
					if delta > duration then
						countdown:Disconnect()
						progress:Destroy()
						_K.UI.Sound.Notification_High:Play()
						return
					end
					progress:setProgress(1 - math.clamp(delta / duration, 0, 1))
					local newText = tostring(math.clamp(math.floor(duration - delta) + 1, 0, duration))
					if newText ~= time.Text then
						_K.UI.Sound.Hover03:Play()
					end
					time.Text = newText
				end)
			end)
		end,
		env = function(_K)
			return { remote = _K.Remote.StartCountdown }
		end,

		run = function(context, duration)
			if duration then
				context.env.remote:FireAllClients(workspace:GetServerTimeNow(), math.min(duration, 120))
			else
				context.env.remote:FireAllClients()
			end
		end,
	},
	{
		name = "title",
		aliases = { "tag", "untag", "untitle" },
		description = "Changes the title of one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) whose title to change.",
			},
			{
				type = "string",
				name = "Title",
				description = "The title text to use.",
				optional = true,
			},
			{
				type = "color",
				name = "Color",
				description = "The title color to use.",
				optional = true,
			},
			{
				type = "color",
				name = "SecondaryColor",
				description = "The secondary title color to use.",
				optional = true,
			},
			{
				type = "Enum.Font",
				name = "Font",
				description = "The title font to use.",
				optional = true,
			},
		},

		run = function(context, players, title: string?, color: Color3?, secondaryColor: Color3?, font: Enum.Font?)
			for _, player in players do
				if context.undo then
					task.spawn(context._K.VIP.Title, player)
				else
					task.spawn(context._K.VIP.Title, player, title, color, secondaryColor, font)
				end
			end
		end,
	},
	{
		name = "vote",
		aliases = { "makevote", "startvote", "poll" },
		description = "Starts a vote for one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to poll.",
			},
			{
				type = "rawString",
				name = "Question",
				description = "The question to poll.",
			},
		},
		envClient = function(_K)
			_K.Remote.Vote.OnClientInvoke = function(text: string, from: Player)
				local actionSignal = _K.Util.Signal.new()
				_K.Notify({
					Text = text,
					ActionText = "<b>VOTE</b>",
					Action = true,
					ExitButton = false,
					LeftAction = true,
					RightAction = true,
					Modal = true,
					Duration = 30,

					UserFrame = { from.UserId },

					[_K.UI.Hook] = {
						Action = function(v)
							actionSignal:Fire(v)
						end,
					},
				})
				return actionSignal:Wait() == true
			end
		end,

		run = function(context, players, message)
			local ok, result = context._K.Util.String.filterResult(message, context.from)
			if not ok then
				return
			end

			local yes, no = 0, 0
			local function voteTask(player)
				local msg = context._K.Util.String.filterResultForUser(result, context.from, player.UserId)
				local vote = context._K.Remote.Vote:InvokeClient(player, msg, context.fromPlayer)
				if vote == true then
					yes += 1
				elseif vote == false then
					no += 1
				end
			end

			local tasks = context._K.Util.Tasks.new()
			for _, player in players do
				tasks:add(voteTask, player)
			end

			context._K.Remote.Notify:FireClient(context.fromPlayer, {
				Text = `Created vote: <b>{message}</b>\n\n<font transparency="0.5"><i>The vote will end in 30 seconds or when every player has submitted their vote!</i></font>`,
			})

			-- wait for timeout or all votes to be submitted
			task.delay(30, coroutine.resume, tasks.running)
			tasks:wait()

			local validColor = context._K.Data.settings.themeValid:ToHex()
			local invalidColor = context._K.Data.settings.themeInvalid:ToHex()
			context._K.Remote.Notify:FireClient(context.fromPlayer, {
				Text = `<font transparency="0.5">The results are in!</font>\n\n<b>{message}</b>\n\t<font color="#{validColor}"><b><sc>yes</sc></b>\t{yes}</font>\n\t<font color="#{invalidColor}"><b><sc>no</sc></b> \t{no}</font>`,
			})
		end,
	},
	{
		name = "link",
		aliases = { "connect", "track" },
		description = "Links one or more player(s) to your character.",
		args = {
			{
				type = "players",
				name = "Players",
				description = "The player(s) to link.",
				ignoreSelf = true,
			},
			{
				type = "boolean",
				name = "Persistent",
				description = "If the link persists through respawn.",
				optional = true,
			},
		},
		envClient = function(_K)
			local localPlayer = _K.Service.Players.LocalPlayer
			local persist, link = {}, nil

			local function characterAddedHandler(character)
				task.defer(link, _K.Service.Players:GetPlayerFromCharacter(character))
			end

			link = function(player, persistent)
				if persistent and not persist[player] then
					persist[player] = player.CharacterAdded:Connect(characterAddedHandler)
				end

				local playerRoot = player and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				local localRoot = localPlayer
					and localPlayer.Character
					and localPlayer.Character:FindFirstChild("HumanoidRootPart")
				local playerAttachment = playerRoot and playerRoot:FindFirstChildOfClass("Attachment")
				local localAttachment = localRoot and localRoot:FindFirstChildOfClass("Attachment")
				if playerAttachment and localAttachment then
					local beam = playerRoot:FindFirstChild("_KBeamLink")
					if not beam then
						beam = Instance.new("Beam")
						beam.Name = "_KBeamLink"
						beam.Color = ColorSequence.new(Color3.fromHSV(math.random(), 1, math.random()))
						beam.FaceCamera = true
						beam.Segments = 1
						beam.Transparency = NumberSequence.new(0)
						beam.Width0 = 0.2
						beam.Width1 = 0.2
						beam.Parent = playerRoot
					end
					beam.Attachment0 = playerAttachment
					beam.Attachment1 = localAttachment
				end
			end

			localPlayer.CharacterAdded:Connect(function()
				for player in persist do
					task.defer(link, player)
				end
			end)

			return {
				persist = persist,
				link = link,
			}
		end,

		runClient = function(context, players, persistent)
			for _, player in players do
				context.env.link(player, persistent)
			end
		end,
	},
	{
		name = "unlink",
		aliases = { "unconnect", "untrack" },
		description = "Removes a link from one or more player(s).",
		args = {
			{
				type = "players",
				name = "Players",
				description = "The player(s) to unlink.",
				ignoreSelf = true,
			},
		},

		runClient = function(context, players)
			for _, player in players do
				local connection = context._K.Registry.commands.link.env.persist[player]
				if connection then
					connection:Disconnect()
					context._K.Registry.commands.link.env.persist[player] = nil
				end
				local playerRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				local link = playerRoot and playerRoot:FindFirstChild("_KBeamLink")
				if link then
					link:Destroy()
				end
			end
		end,
	},
	{
		name = "watch",
		aliases = { "camera", "follow" },
		description = "Watches a player with your camera.",
		args = {
			{
				type = "player",
				name = "Player",
				description = "The player to watch.",
			},
		},

		runClient = function(context, player)
			if player.Character and player.Character:FindFirstChildOfClass("Humanoid") then
				workspace.CurrentCamera.CameraSubject = player.Character:FindFirstChildOfClass("Humanoid")
			end
		end,
	},
	{
		name = "spectate",
		aliases = { "spy" },
		description = "Spectate a player's camera view.",
		args = {
			{
				type = "player",
				name = "Player",
				description = "The player to spectate.",
				ignoreSelf = true,
			},
		},

		envClient = function(_K)
			local env = {
				spectateConnection = nil,
			}

			local function spectateNetwork()
				_K.Remote.SpectateSubject:FireServer(workspace.CurrentCamera.CFrame)
			end

			_K.Remote.SpectateSubject.OnClientEvent:Connect(function(enabled: boolean)
				if env.spectateConnection then
					env.spectateConnection:Disconnect()
				end
				if enabled then
					env.spectateConnection = _K.Service.Run.Heartbeat:Connect(spectateNetwork)
				end
			end)

			_K.Remote.Spectate.OnClientEvent:Connect(function(cframe: CFrame)
				_K.Service.Tween
					:Create(workspace.CurrentCamera, TweenInfo.new(0.1), {
						CFrame = cframe,
					})
					:Play()
			end)

			return env
		end,
		env = function(_K)
			local spectators = {}
			local spectateRemote = _K.Remote.Spectate
			_K.Remote.SpectateSubject.OnServerEvent:Connect(function(player: Player, cframe: CFrame)
				if not spectators[player] then
					return
				end
				for _, player in spectators[player] do
					spectateRemote:FireClient(player, cframe)
				end
			end)

			local function spectateCleanup(context)
				local spectatorCache = spectators
				for subject, spectators in spectatorCache do
					local found = table.find(spectators, context.fromPlayer)
					if found then
						table.remove(spectators, found)
						if #spectators == 0 then
							spectatorCache[subject] = nil
							context._K.Remote.SpectateSubject:FireClient(subject)
						end
					end
				end
			end

			_K.Hook.roleRemoved:Connect(function(userId: number, role: string)
				local player = _K.Service.Players:GetPlayerByUserId(userId)
				if player and not _K.Auth.hasCommand(userId, _K.Registry.commands.spectate) then
					spectateCleanup({ _K = _K, fromPlayer = player })
				end
			end)

			return {
				spectators = spectators,
				spectateCleanup = spectateCleanup,
			}
		end,

		runClient = function(context, player)
			if not workspace.CurrentCamera:GetAttribute("kCameraType") then
				workspace.CurrentCamera:SetAttribute("kCameraType", workspace.CurrentCamera.CameraType)
				workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable
			end
			if player.Character and player.Character:FindFirstChildOfClass("Humanoid") then
				workspace.CurrentCamera.CameraSubject = player.Character:FindFirstChildOfClass("Humanoid")
			end
			if context.env.spectateConnection then
				context.env.spectateConnection:Disconnect()
			end
			context.env.spectateConnection = player.CharacterAdded:Connect(function()
				workspace.CurrentCamera.CameraSubject = player.Character:FindFirstChildOfClass("Humanoid")
			end)
		end,
		run = function(context, player)
			context.env.spectateCleanup(context)
			if not context.env.spectators[player] then
				context.env.spectators[player] = {}
			end
			context._K.Remote.SpectateSubject:FireClient(player, true)
			table.insert(context.env.spectators[player], context.fromPlayer)
		end,
	},
	{
		name = "unspectate",
		aliases = { "unspy", "unwatch", "uncamera", "unfollow" },
		description = "Stop spectating.",
		args = {},

		runClient = function(context)
			if workspace.CurrentCamera:GetAttribute("kCameraType") then
				workspace.CurrentCamera.CameraType =
					workspace.CurrentCamera:GetAttribute("kCameraType") :: Enum.CameraType
				workspace.CurrentCamera:SetAttribute("kCameraType", nil)
			end
			local character = context.fromPlayer.Character
			if character then
				workspace.CurrentCamera.CameraSubject = character:FindFirstChildOfClass("Humanoid")
			end
			local spectateEnv = context._K.Registry.commands.spectate.env
			if spectateEnv.spectateConnection then
				spectateEnv.spectateConnection:Disconnect()
				spectateEnv.spectateConnection = nil
			end
		end,
		run = function(context)
			context._K.Registry.commands.spectate.env.spectateCleanup(context)
		end,
	},
	{
		name = "fly",
		description = "Enables flight for one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to give flight.",
			},
			{
				type = "number",
				name = "Speed",
				description = "The maximum flight speed, defaults to 128.",
				optional = true,
			},
		},
		env = function(_K)
			_K.Hook.roleRemoved:Connect(function(userId: number, role: string)
				local player = _K.Service.Players:GetPlayerByUserId(userId)
				if player and not _K.Auth.hasCommand(userId, _K.Registry.commands.fly) then
					player:SetAttribute("_KFly", nil)
					player:SetAttribute("_KNoClip", nil)
				end
			end)
		end,
		run = function(context, players, speed)
			for _, player in players do
				if not player:GetAttribute("_KFly") then
					context._K.Remote.Notify:FireClient(player, { Text = `Double tap <b>jump</b> to toggle fly.` })
				end
				player:SetAttribute("_KFly", speed or 128)
				player:SetAttribute("_KNoClip", nil)
			end
		end,
	},
	{
		name = "unfly",
		description = "Disables flight for one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to remove flight from.",
			},
		},

		run = function(context, players)
			for _, player in players do
				player:SetAttribute("_KFly", nil)
				player:SetAttribute("_KNoClip", nil)
			end
		end,
	},
	{
		name = "noclip",
		description = "Enables noclip for one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to noclip.",
			},
			{
				type = "boolean",
				name = "Flight",
				description = "If flight should be enabled, defaults to enabled.",
				optional = true,
			},
			{
				type = "number",
				name = "Speed",
				description = "The maximum flight speed, defaults to 128.",
				optional = true,
			},
		},
		run = function(context, players, flying: boolean?, speed: number?)
			for _, player in players do
				if not player:GetAttribute("_KDevCameraOcclusionMode") then
					player:SetAttribute("_KDevCameraOcclusionMode", player.DevCameraOcclusionMode)
					player.DevCameraOcclusionMode = Enum.DevCameraOcclusionMode.Invisicam
				end
				if not player:GetAttribute("_KNoClip") then
					context._K.Remote.Notify:FireClient(player, { Text = `Double tap <b>jump</b> to toggle noclip.` })
				end
				player:SetAttribute("_KFly", if flying == false then nil else speed or 128)
				player:SetAttribute("_KNoClip", true)
			end
		end,
	},
	{
		name = "clip",
		aliases = { "unnoclip" },
		description = "Disables noclip for one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to remove noclip from.",
			},
		},

		run = function(context, players)
			for _, player in players do
				local initialCameraMode = player:GetAttribute("_KDevCameraOcclusionMode")
				if initialCameraMode then
					player.DevCameraOcclusionMode = initialCameraMode
					player:SetAttribute("_KDevCameraOcclusionMode", nil)
				end
				player:SetAttribute("_KFly", nil)
				player:SetAttribute("_KNoClip", nil)
			end
		end,
	},
	{
		name = "xray",
		aliases = { "wallhack", "walls", "unxray", "unwallhack", "unwalls" },
		description = "Show players through walls.",
		args = {
			{
				type = "color",
				name = "FillColor",
				description = "The fill color of the xray.",
				optional = true,
			},
			{
				type = "color",
				name = "OutlineColor",
				description = "The outline color of the xray.",
				optional = true,
			},
		},
		envClient = function(_K)
			local xray = _K.Flux.state(false)
			local xrayModel = _K.Flux.new "Model" {
				Parent = workspace,
				Name = "_K_XRay",
			}
			local highlight = _K.Flux.new "Highlight" {
				Parent = xrayModel,
				Name = "_Kxray",
				Enabled = xray,
				FillColor = Color3.new(),
			}
			local characterConnections = {}
			local function cleanup(character)
				local con = characterConnections[character]
				if con then
					con()
				end
				characterConnections[character] = nil
			end
			local function xrayCharacter(character: Model)
				local oldParent = character.Parent
				characterConnections[character] = xray:hook(function(value)
					character.Parent = if value then xrayModel else oldParent
				end)
				character:GetPropertyChangedSignal("Parent"):Connect(function()
					if character.Parent ~= xrayModel then
						oldParent = character.Parent
					end
				end)
			end
			local function xrayPlayer(player: Player)
				if player == _K.LocalPlayer then
					return
				end
				player.CharacterAdded:Connect(xrayCharacter)
				player.CharacterRemoving:Connect(cleanup)
				if player.Character then
					xrayCharacter(player.Character)
				end
			end
			_K.Util.SafePlayerAdded(xrayPlayer)
			return {
				xray = xray,
				xrayModel = xrayModel,
				highlight = highlight,
			}
		end,

		runClient = function(context, fillColor: Color3?, outlineColor: Color3?)
			context.env.xray:set(if context.undo then false else true)
			context.env.xrayModel.Parent = if context.undo then nil else workspace
			context.env.hightlight.FillColor = fillColor or Color3.new(0, 1, 1)
			context.env.hightlight.OutlineColor = outlineColor or Color3.new(1, 1, 1)
		end,
	},

	{
		name = "play",
		aliases = { "music", "sound", "audio" },
		description = "Plays a sound.",
		args = {
			{
				type = "integer",
				name = "AssetId",
				description = "The asset identifier of the sound.",
			},
		},

		run = function(context, assetId)
			if playingSound then
				playingSound:Stop()
				playingSound:Destroy()
			end

			local sound = Instance.new("Sound")
			playingSound = sound
			sound.Name = "_KPlaySound"
			sound.SoundId = "rbxassetid://" .. assetId
			sound.Looped = true
			sound.Parent = workspace
			sound:Play()
		end,
	},
	{
		name = "pause",
		aliases = {},
		description = "Pauses the current sound.",
		args = {},

		run = function(context)
			if playingSound then
				playingSound:Pause()
			end
		end,
	},
	{
		name = "resume",
		aliases = {},
		description = "Resumes the current sound.",
		args = {},

		run = function(context)
			if playingSound then
				playingSound:Resume()
			end
		end,
	},
	{
		name = "stop",
		aliases = { "stopmusic" },
		description = "Stops the currently playing sound.",
		args = {},

		run = function(context)
			if playingSound then
				playingSound:Stop()
				playingSound:Destroy()
			end
		end,
	},
	{
		name = "pitch",
		aliases = {},
		description = "Changes the pitch of the currently playing sound.",
		args = {
			{
				type = "number",
				name = "Value",
				description = "The pitch value.",
			},
		},

		run = function(context, pitch)
			if playingSound then
				playingSound.Pitch = pitch
			end
		end,
	},
	{
		name = "volume",
		aliases = {},
		description = "Changes the volume of the currently playing sound.",
		args = {
			{
				type = "number",
				name = "Value",
				description = "The volume value.",
			},
		},

		run = function(context, volume)
			if playingSound then
				playingSound.Volume = volume
			end
		end,
	},
}
