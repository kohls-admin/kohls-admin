-- safe utilily commands for all players

return {
	{
		name = "version",
		description = "Displays the version of Kohl's Admin in this game.",
		optionalPrefix = true,
		runClient = function(context)
			context._K.Notify({ From = "_K", Text = `<sc>version</sc>:\t<b>{context._K.VERSION}</b>` })
		end,
	},
	{
		name = "prefix",
		aliases = { "hotkeys" },
		description = "Displays the prefix and hotkeys.",
		optionalPrefix = true,
		runClient = function(context)
			local commandBarKey = context._K.client.hotkeys.commandBar
			local commandBarKeyRaw = context._K.UI.UserInputService:GetStringForKeyCode(commandBarKey.key._value)
			local commandBarKeyText =
				`{commandBarKey.mods.Shift and "Shift+" or ""}{commandBarKey.mods.Alt and "Alt+" or ""}{commandBarKey.key._value.Name}`

			local dashboardKey = context._K.client.hotkeys.dashboard
			local dashboardKeyRaw = context._K.UI.UserInputService:GetStringForKeyCode(dashboardKey.key._value)
			local dashboardKeyText =
				`{dashboardKey.mods.Shift and "Shift+" or ""}{dashboardKey.mods.Alt and "Alt+" or ""}{dashboardKey.key._value.Name}`

			local prefix = context._K.UI.raw(context._K.client.settings.prefix)[1]
			local prefixKeyText = string.byte(prefix)
			for i, keyCode in Enum.KeyCode:GetEnumItems() do
				if keyCode.Value == prefixKeyText then
					prefixKeyText = keyCode.Name
					break
				end
			end

			context._K.Notify({
				From = "_K",
				Text = table.concat({
					`<font family="{context._K.UI.Theme.FontMono._value.Family}"><b>Prefix</b>     <font color="#0f0">{prefixKeyText} {prefix}</font>`,
					`<b>Commands</b>   <font color="#0f0">{commandBarKeyText} {commandBarKeyRaw}</font>`,
					`<b>Dashboard</b>  <font color="#0f0">{dashboardKeyText} {dashboardKeyRaw}</font></font>`,
				}, "\n"),
			})
		end,
	},
	{
		name = "about",
		aliases = { "credit", "credits", "info" },
		description = "Shows the about tab in a separate window.",
		optionalPrefix = true,
		envClient = function(_K)
			local env = {}
			task.defer(function()
				while not _K.client do
					task.wait()
				end
				local window = _K.UI.new "Window" {
					Parent = _K.UI.LayerTopInset,
					Icon = "rbxassetid://71961243872230",
					Title = "About",
				}
				_K.UI.edit(window, {
					[_K.UI.Event] = {
						Visible = function()
							if not window._instance.Visible and #_K.client.dashboard then
								_K.UI.edit(_K.client.dashboard.Tabs, {
									_K.client.dashboard.About,
								})
							end
						end,
					},
				})
				env.window = window
			end)
			return env
		end,

		runClient = function(context)
			context._K.client.dashboard.About._instance.Parent = context.env.window._content
			context._K.client.dashboard.About._instance.Visible = true
			context.env.window._instance.Visible = true
		end,
	},
	{
		name = "commands",
		aliases = { "cmds" },
		description = "Shows the commands in a separate window.",
		optionalPrefix = true,
		envClient = function(_K)
			local env = {}
			task.defer(function()
				while not _K.client do
					task.wait()
				end
				local window = _K.UI.new "Window" {
					Parent = _K.UI.LayerTopInset,
					Icon = "rbxassetid://71961243872230",
					Title = "Commands",
				}
				_K.UI.edit(window, {
					[_K.UI.Event] = {
						Visible = function()
							if not window._instance.Visible and #_K.client.dashboard then
								_K.UI.edit(_K.client.dashboard.Tabs, {
									_K.client.dashboard.Commands,
								})
							end
						end,
					},
				})
				env.window = window
			end)
			return env
		end,

		runClient = function(context)
			context._K.UI.edit(context.env.window, {
				Visible = true,
				context._K.client.dashboard.Commands,
			})
			context._K.client.dashboard.Commands._instance.Visible = true
		end,
	},
	{
		name = "commandbar",
		aliases = { "cmdbar" },
		description = "Shows the command bar.",
		optionalPrefix = true,
		runClient = function(context)
			if context._K.Data.settings.commandBarRank == false then
				return "Command bar has been disabled."
			end
			if context._K.Data.settings.commandBarRank > context.fromRank then
				local role = context._K.Auth.getRoleFromRank(context._K.Data.settings.dashboardRank)
				return `Command bar has been restricted to {role.name}+.`
			end
			task.defer(context._K.client.CommandBar.show)
			return
		end,
	},
	{
		name = "dashboard",
		description = "Shows the admin dashboard.",
		optionalPrefix = true,
		runClient = function(context)
			if context._K.Data.settings.dashboardRank == false then
				return `Dashboard has been disabled.`
			end
			if context._K.Data.settings.dashboardRank > context.fromRank then
				local role = context._K.Auth.getRoleFromRank(context._K.Data.settings.dashboardRank)
				return `Dashboard has been restricted to {role.name}+.`
			end
			if not context._K.client.dashboard.Window.Visible then
				context._K.client.hotkeys.dashboard.callback()
			end
			return
		end,
	},
	{
		name = "donate",
		aliases = { "market", "support" },
		description = "Shows the market tab in a separate window.",
		optionalPrefix = true,
		envClient = function(_K)
			local env = {}
			task.defer(function()
				while not _K.client do
					task.wait()
				end
				local window = _K.UI.new "Window" {
					Parent = _K.UI.LayerTopInset,
					Icon = "rbxassetid://71961243872230",
					Title = "Market",
				}
				_K.UI.edit(window, {
					[_K.UI.Event] = {
						Visible = function()
							if not window._instance.Visible and #_K.client.dashboard then
								_K.UI.edit(_K.client.dashboard.Tabs, {
									_K.client.dashboard.Market,
								})
							end
						end,
					},
				})
				env.window = window
			end)
			return env
		end,

		runClient = function(context)
			context._K.client.dashboard.Market._instance.Parent = context.env.window._content
			context._K.client.dashboard.Market._instance.Visible = true
			context.env.window._instance.Visible = true
		end,
	},
	{
		name = "log",
		aliases = {
			"logs",
			"debuglogs",
			"errorlogs",
			"chatlogs",
			"commandlogs",
			"joinlogs",
			"damagelogs",
			"killlogs",
			"purchaselogs",
			"clogs",
			"cmdlogs",
			"dmglogs",
			"buylogs",
		},
		description = "Shows the logs in a separate window.",
		optionalPrefix = true,
		envClient = function(_K)
			local env = {
				aliasMap = {
					clogs = "chatlogs",
					cmdlogs = "commandlogs",
					dmglogs = "damagelogs",
					buylogs = "purchaselogs",
				},
				typeMap = {
					DEBUG = { "DEBUG", "INFO", "WARN", "ERROR" },
					ERROR = { "WARN", "ERROR" },
					CHAT = { "CHAT" },
					COMMAND = { "COMMAND" },
					JOIN = { "JOIN", "LEAVE" },
					KILL = { "KILL", "DEATH", "DAMAGE" },
					DAMAGE = { "KILL", "DEATH", "DAMAGE" },
					PURCHASE = { "PURCHASE" },
				},
				originalFilter = nil,
			}

			task.defer(function()
				while not _K.client do
					task.wait()
				end
				local window = _K.UI.new "Window" {
					Parent = _K.UI.LayerTopInset,
					Icon = "rbxassetid://71961243872230",
					Title = "Logs",
				}
				_K.UI.edit(window, {
					[_K.UI.Event] = {
						Visible = function()
							if not window._instance.Visible then
								_K.UI.edit(_K.client.dashboard.Tabs, {
									_K.client.dashboard.Logs,
								})
								if env.originalFilter then
									for logType, value in env.originalFilter do
										_K.client.dashboard.Logs.logTypeFilter[logType](value)
									end
									env.originalFilter = nil
								end
							end
						end,
					},
				})
				env.window = window
			end)
			return env
		end,

		runClient = function(context)
			context._K.UI.edit(context.env.window, {
				Visible = true,
				context._K.client.dashboard.Logs,
			})
			context._K.client.dashboard.Logs._instance.Visible = true

			if not context.env.originalFilter then
				context.env.originalFilter = {}
				for logType, state in context._K.client.dashboard.Logs.logTypeFilter do
					context.env.originalFilter[logType] = state._value
				end
			end

			if context.alias == "log" or context.alias == "logs" then
				for _, state in context._K.client.dashboard.Logs.logTypeFilter do
					state(true)
				end
			else
				for _, state in context._K.client.dashboard.Logs.logTypeFilter do
					state(false)
				end
				local alias = string.lower(context.alias :: string)
				local match = context.env.aliasMap[alias] or alias
				match = string.upper(string.match(match, "(%w+)logs?$") :: string)
				for _, logType in context.env.typeMap[match] do
					context._K.client.dashboard.Logs.logTypeFilter[logType](true)
				end
			end
		end,
	},
	{
		name = "settings",
		aliases = { "set" },
		description = "Shows the settings in a separate window.",
		optionalPrefix = true,
		envClient = function(_K)
			local env = {}
			task.defer(function()
				while not _K.client do
					task.wait()
				end
				local window = _K.UI.new "Window" {
					Parent = _K.UI.LayerTopInset,
					Icon = "rbxassetid://71961243872230",
					Title = "Settings",
				}
				_K.UI.edit(window, {
					[_K.UI.Event] = {
						Visible = function()
							if not window._instance.Visible and #_K.client.dashboard then
								_K.UI.edit(_K.client.dashboard.Tabs, {
									_K.client.dashboard.Settings,
								})
							end
						end,
					},
				})
				env.window = window
			end)
			return env
		end,

		runClient = function(context)
			context._K.UI.edit(context.env.window, {
				Visible = true,
				context._K.client.dashboard.Settings,
			})
			context._K.client.dashboard.Settings._instance.Visible = true
		end,
	},
	{
		name = "emote",
		aliases = { "animation", "anim", "stopemote", "stopanim" },
		description = "Plays an animation on one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to play the animation on.",
			},
			{
				type = "emote",
				name = "Animation",
				description = "The emote or animation id to play.",
				optional = true,
			},
			{
				type = "boolean",
				name = "Looping",
				description = "If the animation should loop.",
				optional = true,
			},
			{
				type = "number",
				name = "Speed",
				description = "The speed of the animation.",
				optional = true,
			},
		},
		envClient = function(_K)
			local UI = _K.UI
			local env = {
				playing = nil,
				looped = nil,
				speed = nil,
				window = nil,
				preview = nil,
			}

			local emoteId = UI.state()
			local ownsEmote = UI.state(false)

			env.emoteId = emoteId

			task.defer(function()
				while not _K.client do
					task.wait()
				end

				local cameraAngleX = 0
				local cameraAngleY = 180
				local cameraZ = 9
				local worldModel = Instance.new("WorldModel")
				local previewCamera = UI.new "Camera" {}

				local cameraStartCFrame = CFrame.new(0, 3, 0)
					* CFrame.fromOrientation(math.rad(cameraAngleX), math.rad(cameraAngleY), 0)
					* CFrame.new(0, 0, cameraZ)

				local resetCameraTween = game:GetService("TweenService")
					:Create(previewCamera, TweenInfo.new(1, Enum.EasingStyle.Cubic), {
						CFrame = cameraStartCFrame,
					})

				local resetCamera = _K.Util.Function.debounce(4, function()
					resetCameraTween:Play()
				end)

				local function updatePreviewCamera()
					previewCamera.CFrame = CFrame.new(0, 3, 0)
						* CFrame.fromOrientation(math.rad(cameraAngleX), math.rad(cameraAngleY), 0)
						* CFrame.new(0, 0, cameraZ)
					if not (previewCamera.CFrame):FuzzyEq(cameraStartCFrame) then
						resetCamera()
					end
				end

				updatePreviewCamera()

				local dragStart, startAngleX, startAngleY

				local previewId
				env.preview = UI.new "Frame" {
					Name = "Preview",
					Parent = UI.LayerTopInset,
					BackgroundColor3 = Color3.new(1, 1, 1),
					Size = UDim2.new(0, 300, 0, 360),
					Position = UDim2.new(0.5, -150, 0.5, -180),
					Visible = false,
					ZIndex = 9e8,

					UI.new "UICorner" {
						CornerRadius = UDim.new(0, 12),
					},
					UI.new "UIGradient" {
						Color = ColorSequence.new({
							ColorSequenceKeypoint.new(0, Color3.fromRGB(18, 18, 21)),
							ColorSequenceKeypoint.new(1 / 3, Color3.fromRGB(36, 36, 42)),
							ColorSequenceKeypoint.new(2 / 3, Color3.fromRGB(36, 36, 42)),
							ColorSequenceKeypoint.new(1, Color3.fromRGB(18, 18, 21)),
						}),
						Rotation = 90,
					},

					UI.new "ViewportFrame" {
						BackgroundTransparency = 1,
						Size = UDim2.new(1, 0, 1, 0),
						Ambient = Color3.fromRGB(127, 127, 127),
						LightColor = Color3.fromRGB(200, 200, 200),
						LightDirection = Vector3.new(0, -1, 1),
						CurrentCamera = previewCamera,

						previewCamera,
						worldModel,
						MouseWheelBackward = function()
							cameraZ = math.clamp(cameraZ + 1, 3, 15)
							updatePreviewCamera()
						end,
						MouseWheelForward = function()
							cameraZ = math.clamp(cameraZ - 1, 3, 15)
							updatePreviewCamera()
						end,
						TouchPinch = function(_touchPositions, scale, _velocity, state)
							if state == Enum.UserInputState.Change then
								cameraZ = math.clamp(scale * 15, 3, 15)
								updatePreviewCamera()
							end
						end,
						InputBegan = function(input)
							if
								input.UserInputType == Enum.UserInputType.MouseButton1
								or input.UserInputType == Enum.UserInputType.Touch
							then
								dragStart = input.Position
								startAngleX = cameraAngleX
								startAngleY = cameraAngleY
							end
						end,
						InputChanged = function(input, gameProcessed)
							if gameProcessed or not dragStart then
								return
							end
							if
								input.UserInputType == Enum.UserInputType.MouseMovement
								or input.UserInputType == Enum.UserInputType.Touch
							then
								local delta = dragStart - input.Position
								cameraAngleX = (startAngleX + delta.Y) % 360
								cameraAngleY = (startAngleY + delta.X) % 360
								updatePreviewCamera()
							end
						end,
						InputEnded = function(input)
							if
								input.UserInputType == Enum.UserInputType.MouseButton1
								or input.UserInputType == Enum.UserInputType.Touch
							then
								dragStart = nil
							end
						end,
					},

					UI.new "ImageButton" {
						Name = "Close",
						AnchorPoint = Vector2.new(1, 0),
						BackgroundTransparency = 1,
						Image = "rbxasset://textures/ui/ScreenshotHud/Close.png",
						Position = UDim2.new(1, -4, 0, 4),
						Size = UDim2.fromOffset(32, 32),
						Activated = function()
							env.preview.Visible = false
						end,
					},

					UI.new "TextLabel" {
						Name = "Title",
						BackgroundTransparency = 1,
						FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
						Position = UDim2.fromOffset(0, 16),
						Size = UDim2.new(1, 0, 0, 28),
						Text = "Loading",
						TextColor3 = Color3.new(1, 1, 1),
						TextSize = 28,

						UI.new "TextLabel" {
							Name = "Category",
							AutomaticSize = Enum.AutomaticSize.Y,
							BackgroundTransparency = 1,
							FontFace = Font.new("rbxassetid://12187365364"),
							Position = UDim2.fromScale(0, 1),
							Size = UDim2.fromScale(1, 0),
							Text = "Emote",
							TextColor3 = Color3.new(1, 1, 1),
							TextSize = 16,
						},
					},

					UI.new "TextButton" {
						Name = "Unlock",
						AnchorPoint = Vector2.new(0.5, 1),
						AutomaticSize = Enum.AutomaticSize.XY,
						BackgroundColor3 = Color3.fromRGB(51, 95, 255),
						FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
						Position = UDim2.new(0.5, 0, 1, -38),
						Text = "UNLOCK",
						TextColor3 = Color3.new(1, 1, 1),
						TextSize = 28,

						UI.new "UICorner" {
							Name = "UICorner",
							CornerRadius = UDim.new(0, 12),
						},

						UI.new "UIPadding" {
							Name = "UIPadding",
							PaddingBottom = UDim.new(0, 12),
							PaddingLeft = UDim.new(0, 34),
							PaddingRight = UDim.new(0, 34),
							PaddingTop = UDim.new(0, 12),
						},

						Activated = function()
							if previewId then
								_K.PromptBulkPurchase(previewId)
							end
						end,
					},

					UI.new "TextLabel" {
						Name = "Tip",
						AnchorPoint = Vector2.new(0, 1),
						AutomaticSize = Enum.AutomaticSize.Y,
						BackgroundTransparency = 1,
						FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Light, Enum.FontStyle.Normal),
						Position = UDim2.new(0, 0, 1, -16),
						RichText = true,
						Size = UDim2.fromScale(1, 0),
						Text = "Use in <b>every</b> Roblox game",
						TextColor3 = Color3.new(1, 1, 1),
						TextSize = 16,
					},
				}

				task.spawn(function()
					local ok, model = _K.Util.Retry(function()
						return _K.Service.Players:CreateHumanoidModelFromUserId(_K.LocalPlayer.UserId)
					end)
					if not ok then
						model = _K.Flux.new "Model" {
							_K.Flux.new "Humanoid" {
								_K.Flux.new "Animator" {},
							},
						}
					end
					model:PivotTo(CFrame.new(0, 3, 0))

					task.spawn(function()
						local animate = model:WaitForChild("Animate", 5)
						if typeof(animate) == "Instance" and animate:IsA("LocalScript") then
							animate:Destroy()
						end
						model.Parent = worldModel
					end)

					local humanoid = model:WaitForChild("Humanoid")
					local animator = humanoid:WaitForChild("Animator")

					local anim: Animation = Instance.new("Animation")
					local animTrack: AnimationTrack

					local function updatePreview(id)
						if animTrack then
							animTrack:Stop()
							animTrack:Destroy()
						end
						previewId = id
						if id then
							cameraAngleX = 0
							cameraAngleY = 180
							cameraZ = 9
							updatePreviewCamera()
							local item = _K.Data.emoteItemFromId[id]
							env.preview.Title.Text = item.name
							anim.AnimationId = "rbxassetid://" .. item.animationId
							animTrack = animator:LoadAnimation(anim)
							animTrack.Looped = true
							animTrack:Play()
						end
					end
					env.updatePreview = updatePreview
				end)

				local looped = UI.new "Switch" {
					[UI.Hook] = {
						Value = function(loop: boolean)
							if env.playing then
								env.playing.Looped = loop
								if not env.playing.IsPlaying then
									env.playing:Play(0.1, 99, env.speed.Value._value * 2)
								end
							end
						end,
					},
				}
				local speed = UI.new "Slider" {
					[UI.Hook] = {
						Value = function(alpha: number)
							if env.playing then
								env.playing:AdjustSpeed(alpha * 2)
							end
						end,
					},
				}
				env.looped = looped
				env.speed = speed

				local window = UI.new "Window" {
					Parent = UI.LayerTopInset,
					Title = "Emote",
					Resizable = false,
					Size = UDim2.new(0, 256, 0, 32),
					Position = UDim2.new(1, -256 - 6, 0.5, -16),
					UI.new "List" {
						UI.new "ListItem" { Text = "Looped", looped },
						UI.new "ListItem" { Text = "Speed", speed },
					},
				}

				window._content.Size = UDim2.fromScale(1, 0)
				window._content.AutomaticSize = Enum.AutomaticSize.Y
				window._instance.Frame.AutomaticSize = Enum.AutomaticSize.Y
				window._instance.AutomaticSize = Enum.AutomaticSize.Y

				local titleBarHeight = UI.compute(function()
					return UI.Theme.FontSize() + UI.Theme.Padding().Offset * 2
				end)
				local buttonSize = function()
					return UDim2.fromOffset(titleBarHeight(), titleBarHeight())
				end
				local buttonVisible = function()
					return emoteId() ~= nil
				end

				UI.new "Button" {
					LayoutOrder = 3,
					Parent = window._instance.Frame.TitleBar,
					Label = "🔓",
					Size = buttonSize,
					Visible = function()
						return buttonVisible() and not ownsEmote()
					end,
					Activated = function()
						if env.updatePreview and env.preview then
							env.updatePreview(emoteId._value)
							env.preview.Visible = true
						end
					end,
				}

				UI.new "Button" {
					LayoutOrder = 3,
					Parent = window._instance.Frame.TitleBar,
					Label = "⭐",
					Size = buttonSize,
					Visible = buttonVisible,
					Activated = function()
						pcall(function()
							_K.Service.AvatarEditor:PromptSetFavorite(emoteId._value, 1, true)
						end)
					end,
				}

				env.window = window
			end)

			local function playEmote(animation: number, loop: boolean?, speed: number?)
				if env.playing then
					env.playing:Stop()
					env.playing:Destroy()
					env.playing = nil
					emoteId(nil)
					ownsEmote(false)
				end

				if not animation then
					return
				end

				local player = _K.LocalPlayer
				local character = player.Character or player.CharacterAdded:Wait()
				local humanoid = character:WaitForChild("Humanoid")
				local animator = humanoid:WaitForChild("Animator")
				local anim: Animation = _K.Flux.new "Animation" { AnimationId = `rbxassetid://{animation}` }

				local playing = animator:LoadAnimation(anim)
				playing.Priority = Enum.AnimationPriority.Action
				anim.Parent = playing

				if loop ~= nil then
					playing.Looped = loop
					env.looped.Value(playing.Looped)
				else
					task.spawn(function()
						local start = tick()
						repeat
							task.wait()
						until playing.Looped == true or tick() - start > 1
						env.looped.Value(true)
					end)
				end

				env.speed.Value(math.clamp(speed or 1, 0, 2) / 2)

				if not playing.Looped then
					playing.Stopped:Once(function()
						playing:Destroy()
					end)
				end

				local id = _K.Data.animationToEmoteId[animation]
				local emoteItem = emoteId and _K.Data.emoteItemFromId[id]
				env.window.Title(if emoteItem then emoteItem.name else "Emote")
				emoteId(id)
				ownsEmote(false)
				task.spawn(function()
					local ok, result = _K.Util.Retry(function()
						return _K.Util.Service.Marketplace:PlayerOwnsAssetAsync(_K.LocalPlayer, id)
					end)
					if ok then
						ownsEmote(result)
					end
				end)

				playing:Play(0.1, 99, speed)
				env.playing = playing
				env.window._instance.Visible = true

				return playing
			end

			env.playEmote = playEmote
			_K.Remote.Emote:Connect(playEmote)

			return env
		end,
		env = function(_K)
			return {
				remote = _K.Remote.Emote,
			}
		end,
		run = function(context, players, animation: number, loop: boolean?, speed: number?)
			if
				context._K.Auth.hasPermission(context.from, "targetOthers") ~= true
				and not context._K.Auth.hasPermission(context.from, "admin")
			then
				local ok, owned = context._K.Util.Retry(function()
					return context._K.Util.Service.Marketplace:PlayerOwnsAssetAsync(context._K.LocalPlayer, animation)
				end)
				if ok and not owned then
					local id = tostring(animation)
					if not context._K.VIP.allowedBulkPurchaseIds[animation] then
						id = "115444443724463" -- chat commands
					end
					local items = { { Type = Enum.MarketplaceProductType.AvatarAsset, Id = id } }
					context._K.Util.Service.Marketplace:PromptBulkPurchase(context._K.LocalPlayer, items, {})
					return
				end
			end
			for _, player in players do
				context.env.remote:Fire(player, animation, loop, speed)
			end
		end,
	},
	{
		name = "emotes",
		description = "Shows the emotes list.",
		optionalPrefix = true,
		envClient = function(_K)
			local UI = _K.UI

			local env = {}

			task.spawn(function()
				repeat
					task.wait()
				until _K.Registry.commands.emote and _K.Registry.commands.emote.env

				local EMOTE = _K.Registry.commands.emote.env

				local scroller = UI.new "ScrollerFast" {
					List = _K.Data.emotes,
					Enabled = true,
					Visible = true,
					CreateItem = function(self, initialLineData)
						local item = {
							lineData = initialLineData,
						}
						item._instance = UI.new "Frame" {
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

							UI.new "ImageButton" {
								BackgroundTransparency = 1,
								BackgroundColor3 = UI.Theme.PrimaryText,
								Size = UDim2.new(1, 0, 1, 0),
								SizeConstraint = Enum.SizeConstraint.RelativeYY,

								ImageTransparency = 0.25,
								ImageColor3 = function()
									return if EMOTE.emoteId() == item.lineData.emoteId
										then Color3.new(1, 0, 0)
										else Color3.new(1, 1, 1)
								end,
								Image = function()
									return if EMOTE.emoteId() == item.lineData.emoteId
										then UI.Theme.Image.Stop
										else UI.Theme.Image.Play
								end,

								UI.action(function(button)
									button.Activated:Connect(function()
										if
											not item.lineData.owned
											or _K.LocalPlayer:GetAttribute("_KDonationLevel") < 4
										then
											EMOTE.updatePreview(item.lineData.emoteId)
											EMOTE.preview.Visible = true
											return
										end
										if EMOTE.emoteId._value == item.lineData.emoteId then
											_K.UI.Sound.Hover01:Play()
											EMOTE.playEmote()
										else
											_K.UI.Sound.Hover03:Play()
											if _K.forceChat then
												local name = item.lineData.name
												if string.find(name, _K.Data.settings.splitKey, 1, true) then
													name = `"{name}"`
												end
												_K.forceChat(`{_K.getCommandPrefix()}emote me {name}`)
											end
										end
									end)
									button.MouseEnter:Connect(function()
										button.ImageTransparency = 0
									end)
									button.MouseLeave:Connect(function()
										button.ImageTransparency = 0.25
									end)
								end),
							},

							UI.new "TextLabel" {
								AutoLocalize = false,
								AutomaticSize = Enum.AutomaticSize.X,
								BackgroundTransparency = 1,
								Size = UDim2.new(0, 0, 1, 0),
								RichText = true,
								FontFace = UI.Theme.FontMono,
								TextSize = UI.Theme.FontSize,
								TextColor3 = UI.Theme.PrimaryText,
								TextStrokeColor3 = UI.Theme.Primary,
								TextStrokeTransparency = UI.Theme.TextStrokeTransparency,
								TextTruncate = Enum.TextTruncate.SplitWord,
								TextXAlignment = Enum.TextXAlignment.Left,

								UI.new "UIFlexItem" { FlexMode = Enum.UIFlexMode.Fill },
							},

							UI.new "Spacer" {},

							UI.new "Button" {
								Name = "Unlock",
								Label = "🔓",
								Padding = UI.Theme.PaddingHalf,
								Size = UDim2.new(1, 0, 1, 0),
								SizeConstraint = Enum.SizeConstraint.RelativeYY,
								Activated = function()
									EMOTE.updatePreview(item.lineData.emoteId)
									EMOTE.preview.Visible = true
								end,
							},

							UI.new "Button" {
								Label = "⭐",
								Padding = UI.Theme.PaddingHalf,
								Size = UDim2.new(1, 0, 1, 0),
								SizeConstraint = Enum.SizeConstraint.RelativeYY,
								Activated = function()
									pcall(function()
										_K.Service.AvatarEditor:PromptSetFavorite(item.lineData.emoteId, 1, true)
									end)
								end,
							},
						}

						return item
					end,

					RenderItem = function(self, lineItem, lineData)
						lineItem.lineData = lineData
						local instance = lineItem._instance
						instance.TextLabel.Text = lineData.name
						if lineData.owned == nil then
							lineData.owned = false
							task.spawn(function()
								local ok, result = _K.Util.Retry(function()
									return _K.Util.Service.Marketplace:PlayerOwnsAssetAsync(
										_K.LocalPlayer,
										lineData.emoteId
									)
								end)
								if ok then
									lineData.owned = result
									self:render(true)
								end
							end)
						end
						instance.Unlock.Visible = not lineData.owned
					end,
				}

				UI.edit(scroller._instance, {
					UI.new "UIPadding" {
						PaddingTop = UI.Theme.PaddingStroke,
						PaddingBottom = UI.Theme.PaddingStroke,
						PaddingLeft = UI.Theme.PaddingStroke,
						PaddingRight = UI.Theme.PaddingStroke,
					},
				})
				UI.edit(scroller._scroller.UIPadding, {
					PaddingTop = UDim.new(),
					PaddingBottom = UDim.new(),
				})

				env.scroller = scroller
				env.window = UI.new "Window" {
					Parent = UI.LayerTopInset,
					Name = "Emotes",
					Title = "Emotes",
					Exitable = true,
					Position = UDim2.new(0.5, -128, 0.5, -128),
					Size = UDim2.new(0, 256, 0, 256),

					scroller,
				}
			end)

			return env
		end,
		runClient = function(context, player)
			context.env.window._instance.Visible = true
		end,
	},

	{
		name = "age",
		aliases = { "accountage" },
		description = "Displays the account age of a player.",
		args = {
			{
				type = "player",
				name = "Player",
				description = "The player whose account age to display.",
				lowerRank = true,
			},
		},

		runClient = function(context, player: Player)
			context._K.Notify({
				From = player.UserId,
				Text = `<b>Account Age:</b> {context._K.Util.Time.readable(player.AccountAge * 86400)}`,
			})
		end,
	},
	{
		name = "serverage",
		aliases = { "uptime" },
		description = "Displays the age of the server.",
		runClient = function(context, volume)
			context._K.Notify({
				From = "_K",
				Text = `<b>Server Age:</b> {context._K.Util.Time.readable(
					workspace:GetServerTimeNow() - context._K.script:GetAttribute("ServerStartTime")
				)}`,
			})
		end,
	},
	{
		name = "showfps",
		aliases = { "getfps", "checkfps", "playerfps" },
		description = "Displays the frames per second of a player.",
		args = {
			{
				type = "player",
				name = "Player",
				description = "The player whose frames per second to display.",
				lowerRank = true,
			},
		},
		env = function(_K)
			return { remote = _K.Remote.ShowFPS }
		end,
		envClient = function(_K)
			local env = {
				fps = 60,
			}
			function _K.Remote.ShowFPS.OnInvoke()
				return env.fps
			end
			local frames, last = 0, tick()
			_K.Service.Run.Heartbeat:Connect(function()
				frames += 1
				local dt = tick() - last
				if dt >= 1 then
					env.fps = frames / dt
					frames, last = 0, tick()
				end
			end)
			return env
		end,
		run = function(context, player: Player)
			context._K.Remote.Notify:Fire(context.fromPlayer, {
				Text = `<b>FPS:</b> {math.round(context.env.remote:Invoke(player) or 0)}`,
				From = player.UserId,
			})
		end,
	},
	{
		name = "ping",
		aliases = { "getping", "checkping", "latency" },
		description = "Displays the ping of a player.",
		args = {
			{
				type = "player",
				name = "Player",
				description = "The player to ping.",
				lowerRank = true,
			},
		},

		run = function(context, player: Player)
			context._K.Remote.Notify:Fire(
				context.fromPlayer,
				{ Text = `<b>Ping:</b> {math.round(player:GetNetworkPing() * 1000)} ms`, From = player.UserId }
			)
		end,
	},
	{
		name = "wait",
		aliases = { "delay" },
		description = "Delays command execution for a period of time.",
		args = {
			{
				type = "number",
				name = "Seconds",
				description = "How long to wait in seconds.",
			},
		},

		run = function(context, delay: number)
			task.wait(delay)
		end,
	},
	{
		name = "rejoin",
		aliases = { "rj" },
		description = "Rejoins the server.",

		run = function(context)
			local options = Instance.new("TeleportOptions")
			options.ServerInstanceId = game.JobId
			context._K.Util.SafeTeleport(game.PlaceId, { context.fromPlayer }, options)
		end,
	},
	{
		name = "join",
		description = "Join a player in the same game.",
		args = {
			{
				type = "userId",
				name = "UserId",
				description = "The UserId of the player to join.",
			},
		},

		run = function(context, userId)
			local ok, samePlace, errorMessage, placeId, jobId =
				pcall(context._K.Service.Teleport.GetPlayerPlaceInstanceAsync, context._K.Service.Teleport, userId)
			if not ok then
				return errorMessage or samePlace
			end
			if samePlace then
				return "You're already in the same server!"
			end

			if placeId and jobId then
				local options = Instance.new("TeleportOptions")
				options.ServerInstanceId = jobId
				context._K.Util.SafeTeleport(placeId, { context.fromPlayer }, options)
			end
			return
		end,
	},

	{
		name = "viewas",
		aliases = { "unviewas" },
		description = "Views the admin system as one or more role(s).",
		args = {
			{
				type = "roles",
				name = "Roles(s)",
				description = "The roles(s) to test.",
				optional = true,
			},
		},

		envClient = function(_K)
			return {
				originalCreatorId = nil,
				originalMember = nil,
			}
		end,
		runClient = function(context, roles)
			local key = tostring(context.from)
			if context.undo then
				if not context.env.originalMember then
					return
				end
				context._K.Data.members[key] = context.env.originalMember
				if context.env.originalCreatorId then
					context._K.creatorId = context.env.originalCreatorId
					context._K.Data.creatorId = context._K.creatorId
				end
				context.env.originalMember = nil
				context.env.originalCreatorId = nil
				context._K.Notify({
					From = "_K",
					Text = `View returned to original permissions.`,
				})
			else
				if not context.env.originalMember then
					context.env.originalMember = context._K.Data.members[key]
					if context.from == context._K.creatorId then
						context.env.originalCreatorId = context._K.creatorId
						context._K.creatorId = 0
						context._K.Data.creatorId = 0
					end
				end
				context._K.Data.members[key] = {
					name = context.fromPlayer.Name,
					roles = roles or {},
					persist = {},
				}

				local roleStrings = {}
				if roles then
					for _, role in roles do
						local roleData = context._K.Data.roles[role]
						if roleData then
							table.insert(roleStrings, `<font color="{roleData.color}">{roleData.name}</font>`)
						end
					end
				end
				local everyoneRole = context._K.Data.roles.everyone
				table.insert(roleStrings, `<font color="{everyoneRole.color}">{everyoneRole.name}</font>`)
				local roleString = table.concat(roleStrings, ", ")

				context._K.Notify({
					From = "_K",
					Text = `Viewing the system as <sc>{roleString}</sc>`
						.. `\n\nUse <b>{context._K.getCommandPrefix(context.from)}unviewas</b> to return to normal.`,
				})
			end
			context._K.client.members(context._K.Data.members)
			context._K.client.updateInterfaceAuth()
		end,
	},

	-- {
	-- 	name = "alias",
	-- 	aliases = {},
	-- 	description = "Creates a command alias out of a command and given arguments.",
	-- 	args = {
	-- 		{
	-- 			type = "string",
	-- 			name = "Alias name",
	-- 			description = "The name of the command alias.",
	-- 		},
	-- 		{
	-- 			type = "string",
	-- 			name = "Command string",
	-- 			description = "The command string to alias.",
	-- 		},
	-- 	},

	-- 	runClient = function(context, alias: string, command: string)
	-- 		context._K.Registry.registerCommandAlias(context._K, alias, command)
	-- 	end,
	-- },
}
