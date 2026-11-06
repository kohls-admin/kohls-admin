-- safe utilily commands for all players

local function hasVIPGroupRole(_K: any, roleIds: { string }?): boolean
	if type(roleIds) ~= "table" then
		return false
	end
	for _, roleId in roleIds do
		local role = _K.Data.roles and _K.Data.roles[roleId]
		if role and type(role.groups) == "table" and table.find(role.groups, "vip") then
			return true
		end
	end
	return false
end

local function hasEmoteAccess(_K: any, userId: number, player: Player?): boolean
	if player and (player:GetAttribute("_KDonationLevel") or 0) >= 1 then
		return true
	end
	if
		_K.Auth.getRank(userId) >= 1
		or _K.Auth.hasRole(userId, "vip")
		or _K.Auth.hasPermission(userId, "targetOthers")
	then
		return true
	end
	local member = _K.Data.members and _K.Data.members[tostring(userId)]
	return (member ~= nil and hasVIPGroupRole(_K, member.roles))
		or (_K.Data.settings ~= nil and hasVIPGroupRole(_K, _K.Data.settings.freeAdmin))
end

local function createEmotePreviewViewport(UI: any, previewCamera: Camera, worldModel: WorldModel, state: any)
	return UI.new "ViewportFrame" {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0),
		Ambient = Color3.fromRGB(127, 127, 127),
		LightColor = Color3.fromRGB(200, 200, 200),
		LightDirection = Vector3.new(0, -1, 1),
		CurrentCamera = previewCamera,

		previewCamera,
		worldModel,
		MouseWheelBackward = function()
			state.cameraZ = math.clamp(state.cameraZ + 1, 3, 15)
			state.updateCamera()
		end,
		MouseWheelForward = function()
			state.cameraZ = math.clamp(state.cameraZ - 1, 3, 15)
			state.updateCamera()
		end,
		TouchPinch = function(_touchPositions, scale, _velocity, pinchState)
			if pinchState == Enum.UserInputState.Change then
				state.cameraZ = math.clamp(scale * 15, 3, 15)
				state.updateCamera()
			end
		end,
		InputBegan = function(input)
			if
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				state.dragStart = input.Position
				state.startAngleX = state.cameraAngleX
				state.startAngleY = state.cameraAngleY
			end
		end,
		InputChanged = function(input, gameProcessed)
			if gameProcessed or not state.dragStart then
				return
			end
			if
				input.UserInputType == Enum.UserInputType.MouseMovement
				or input.UserInputType == Enum.UserInputType.Touch
			then
				local delta = state.dragStart - input.Position
				state.cameraAngleX = (state.startAngleX + delta.Y) % 360
				state.cameraAngleY = (state.startAngleY + delta.X) % 360
				state.updateCamera()
			end
		end,
		InputEnded = function(input)
			if
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				state.dragStart = nil
			end
		end,
	}
end

local function createEmoteUnlockButton(_K: any, UI: any, env: any, state: any)
	return UI.new "TextButton" {
		Name = "Unlock",
		AnchorPoint = Vector2.new(0.5, 1),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundColor3 = Color3.fromRGB(51, 95, 255),
		FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
		Position = UDim2.new(0.5, 0, 1, -38),
		Text = "UNLOCK",
		TextColor3 = Color3.new(1, 1, 1),
		TextSize = 28,

		UI.corner(12),
		UI.padding { x = 34, y = 12 },

		Activated = function()
			local previewId = state.previewId
			if not previewId then
				return
			end
			local item = _K.Data.emoteItemFromId and _K.Data.emoteItemFromId[previewId]
			if item and item.canSell == false then
				if _K.Data.settings.vip and _K.PromptPurchaseVIP then
					env.preview.Visible = false
					_K.PromptPurchaseVIP()
				end
				return
			end
			_K.PromptBulkPurchase(previewId)
		end,
	}
end

local function createEmotePreviewFrame(
	_K: any,
	UI: any,
	env: any,
	previewCamera: Camera,
	worldModel: WorldModel,
	state: any
)
	return UI.new "Frame" {
		Name = "Preview",
		Parent = UI.LayerTopInset,
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.new(0, 300, 0, 360),
		Position = UDim2.new(0.5, -150, 0.5, -180),
		Visible = false,
		ZIndex = 9e8,

		UI.corner(12),
		UI.gradient {
			color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(18, 18, 21)),
				ColorSequenceKeypoint.new(1 / 3, Color3.fromRGB(36, 36, 42)),
				ColorSequenceKeypoint.new(2 / 3, Color3.fromRGB(36, 36, 42)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(18, 18, 21)),
			}),
			rotation = 90,
		},

		createEmotePreviewViewport(UI, previewCamera, worldModel, state),

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

		createEmoteUnlockButton(_K, UI, env, state),

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
end

local function setupEmotePreviewModel(_K: any, env: any, worldModel: WorldModel, state: any)
	task.spawn(function()
		local ok, model = _K.Util.Retry(function()
			return _K.Service.Players:CreateHumanoidModelFromUserId(math.max(1, _K.LocalPlayer.UserId))
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

		function env.updatePreview(id)
			if animTrack then
				animTrack:Stop()
				animTrack:Destroy()
			end
			state.previewId = id
			if id then
				state.cameraAngleX = 0
				state.cameraAngleY = 180
				state.cameraZ = 9
				state.updateCamera()
				local item = _K.Data.emoteItemFromId[id]
				env.preview.Title.Text = item.name
				anim.AnimationId = "rbxassetid://" .. item.animationId
				animTrack = animator:LoadAnimation(anim)
				animTrack.Looped = true
				animTrack:Play()
			end
		end
	end)
end

local function connectEmoteBulkPurchase(_K: any, env: any, emoteId: any, ownsEmote: any, state: any)
	if not _K.Service.Marketplace.PromptBulkPurchaseFinished then
		return
	end
	local _ = _K.Service.Marketplace.PromptBulkPurchaseFinished:Connect(function(player, status, results)
		if
			player ~= _K.LocalPlayer
			or status ~= Enum.MarketplaceBulkPurchasePromptStatus.Completed
			or type(results) ~= "table"
			or type(results.Items) ~= "table"
		then
			return
		end
		local updated = false
		for _, resultItem in results.Items do
			local itemId = type(resultItem) == "table" and tonumber(resultItem.Id or resultItem.id)
			local emoteItem = itemId and _K.Data.emoteItemFromId and _K.Data.emoteItemFromId[itemId]
			if type(emoteItem) == "table" then
				emoteItem.owned = true
				updated = true
				if emoteId:peek() == itemId then
					ownsEmote(true)
				end
				if state.previewId == itemId and env.preview then
					env.preview.Visible = false
				end
			end
		end
		if
			updated
			and _K.Registry.commands.emotes
			and _K.Registry.commands.emotes.env
			and _K.Registry.commands.emotes.env.scroller
		then
			_K.Registry.commands.emotes.env.scroller:render(true)
		end
	end)
end

local function createEmoteControlWindow(_K: any, UI: any, env: any, emoteId: any, ownsEmote: any)
	local looped = UI.new "Switch" {
		[UI.Hook] = {
			Value = function(loop: boolean)
				if env.playing then
					env.playing.Looped = loop
					if not env.playing.IsPlaying then
						env.playing:Play(0.1, 99, env.speed.Value:peek() * 2)
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
		AutomaticSize = Enum.AutomaticSize.Y,
		Resizable = false,
		Size = UDim2.new(0, 256, 0, 0),
		Position = UDim2.new(1, -256 - 6, 0.5, -16),
		UI.new "List" {
			UI.new "ListItem" { Text = "Looped", looped },
			UI.new "ListItem" { Text = "Speed", speed },
		},
	}

	local buttonSize = function()
		local h = UI.Theme.FontSize() + UI.Theme.Padding().Offset * 2
		return UDim2.fromOffset(h, h)
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
				env.updatePreview(emoteId:peek())
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
			local _ = pcall(function()
				_K.Service.AvatarEditor:PromptSetFavorite(emoteId:peek(), 1, true)
			end)
		end,
	}

	env.window = window
end

local function createPlayEmote(_K: any, env: any, emoteId: any, ownsEmote: any)
	return function(animation: number, loop: boolean?, speed: number?)
		if env.playing then
			env.playing:Stop()
			env.playing:Destroy()
			env.playing = nil
			emoteId:set(nil)
			ownsEmote(false)
		end

		if type(animation) ~= "number" then
			if env.window then
				env.window._instance.Visible = false
			end
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

		-- the slider's hook applies its speed on the next flush, so play at the same clamped speed
		local playSpeed = math.clamp(speed or 1, 0, 2)
		env.speed.Value(playSpeed / 2)

		if not playing.Looped then
			playing.Stopped:Once(function()
				playing:Destroy()
			end)
		end

		local id = _K.Data.animationToEmoteId[animation]
		local emoteItem = id and _K.Data.emoteItemFromId[id]
		env.window.Title(if emoteItem then emoteItem.name else "Emote")
		emoteId:set(id)
		ownsEmote(false)
		if id then
			task.spawn(function()
				local ok, result = _K.Util.Retry(function()
					return _K.Service.Marketplace:PlayerOwnsAssetAsync(_K.LocalPlayer, id)
				end)
				if ok then
					ownsEmote(result)
				end
			end)
		end

		playing:Play(0.1, 99, playSpeed)
		env.playing = playing
		env.window._instance.Visible = true

		return playing
	end
end

local function createEmotesPlayButton(_K: any, UI: any, EMOTE: any, item: any)
	return UI.new "ImageButton" {
		BackgroundTransparency = 1,
		BackgroundColor3 = UI.Theme.PrimaryText,
		Size = UDim2.new(1, 0, 1, 0),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,

		ImageTransparency = 0.25,
		ImageColor3 = function()
			return if item.lineData and EMOTE.emoteId() == item.lineData.emoteId
				then Color3.new(1, 0, 0)
				else Color3.new(1, 1, 1)
		end,
		Image = function()
			return if item.lineData and EMOTE.emoteId() == item.lineData.emoteId
				then UI.Theme.Image.Stop()
				else UI.Theme.Image.Play()
		end,

		function(button)
			local _ = button.Activated:Connect(function()
				if not item.lineData.owned and not hasEmoteAccess(_K, _K.LocalPlayer.UserId, _K.LocalPlayer) then
					EMOTE.updatePreview(item.lineData.emoteId)
					EMOTE.preview.Visible = true
					return
				end
				if EMOTE.emoteId:peek() == item.lineData.emoteId then
					_K.UI.Sound.Hover01:Play()
					EMOTE.playEmote()
				else
					_K.UI.Sound.Hover03:Play()
					local name = item.lineData.name
					if string.find(name, _K.Data.settings.splitKey, 1, true) then
						name = `"{name}"`
					end
					_K.Process.runCommands(_K, _K.LocalPlayer.UserId, `{_K.getCommandPrefix()}emote me {name}`)
				end
			end)
			local hovering = UI.Interact.hover(button)
			UI.edit(button)({
				ImageTransparency = UI.pick(hovering, 0, 0.25),
				__CLEAN = { hovering },
			})
		end,
	}
end

local function createEmotesItem(_K: any, UI: any, EMOTE: any, self: any, initialLineData: any)
	local item = {
		lineData = initialLineData,
	}
	item._instance = UI.new "Frame" {
		BackgroundTransparency = 1,
		Size = self.ItemSize,

		UI.padding {
			y = UI.Theme.PaddingHalf,
		},

		UI.list {
			direction = "x",
			gap = UI.Theme.Padding,
			verticalAlign = "center",
		},

		createEmotesPlayButton(_K, UI, EMOTE, item),

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

			UI.flex("fill"),
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
				local _ = pcall(function()
					_K.Service.AvatarEditor:PromptSetFavorite(item.lineData.emoteId, 1, true)
				end)
			end,
		},
	}

	return item
end

local function renderEmotesItem(_K: any, self: any, lineItem: any, lineData: any)
	lineItem.lineData = lineData
	local instance = lineItem._instance
	instance.TextLabel.Text = lineData.name
	if lineData.owned == nil then
		lineData.owned = false
		task.spawn(function()
			local ok, result = _K.Util.Retry(function()
				return _K.Service.Marketplace:PlayerOwnsAssetAsync(_K.LocalPlayer, lineData.emoteId)
			end)
			if ok then
				lineData.owned = result
				self:render(true)
			end
		end)
	end
	instance.Unlock.Visible = not lineData.owned
end

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
			local commandBarMods = commandBarKey.mods:peek()
			local commandBarKeyRaw = context._K.UI.UserInputService:GetStringForKeyCode(commandBarKey.key:peek())
			local commandBarKeyText =
				`{commandBarMods.Shift and "Shift+" or ""}{commandBarMods.Alt and "Alt+" or ""}{commandBarKey.key:peek().Name}`

			local dashboardKey = context._K.client.hotkeys.dashboard
			local dashboardMods = dashboardKey.mods:peek()
			local dashboardKeyRaw = context._K.UI.UserInputService:GetStringForKeyCode(dashboardKey.key:peek())
			local dashboardKeyText =
				`{dashboardMods.Shift and "Shift+" or ""}{dashboardMods.Alt and "Alt+" or ""}{dashboardKey.key:peek().Name}`

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
					`<font family="{context._K.UI.Theme.FontMono:peek().Family}"><b>Prefix</b>     <font color="#0f0">{prefixKeyText} {prefix}</font>`,
					`<b>Commands</b>   <font color="#0f0">{commandBarKeyText} {commandBarKeyRaw}</font>`,
					`<b>Dashboard</b>  <font color="#0f0">{dashboardKeyText} {dashboardKeyRaw}</font></font>`,
				}, "\n"),
			})
		end,
	},
	{
		name = "cmdbar2",
		aliases = { "cmdbarfloating", "cmdbarwindow" },
		description = "Shows a floating command bar window.",
		optionalPrefix = true,
		envClient = function(_K)
			local UI = _K.UI
			local env = {}

			local input = UI.new "Input" {
				ClearTextButton = true,
				Fill = true,
				FontFace = UI.Theme.FontMono,
				FontSize = UI.Theme.FontSize,
				Placeholder = ";command",
				Value = "",
			}

			input._input:GetPropertyChangedSignal("Text"):Connect(function()
				_K.client.updateCommandInput(input)
			end)

			local function executeCommand()
				local trimmed = _K.Util.String.trimEnd(input._input.Text)
				task.spawn(_K.Process.runCommands, _K, _K.LocalPlayer.UserId, trimmed)
			end

			local _ = input._input.FocusLost:Connect(function(enterPressed)
				if enterPressed then
					executeCommand()
				end
			end)

			env.window = UI.new "Window" {
				Parent = UI.LayerTopInset,
				Icon = "rbxassetid://71961243872230",
				Name = "Cmdbar2",
				Title = "Command Bar",
				AutomaticSize = Enum.AutomaticSize.Y,
				Position = UDim2.new(0.5, -210, 0.5, -56),
				Size = UDim2.fromOffset(420, 0),

				UI.list {
					gap = UI.Theme.Padding,
				},

				input,
				UI.new "Button" {
					Label = "Run Command",
					Activated = executeCommand,
				},
			}

			return env
		end,

		runClient = function(context)
			context.env.window._instance.Visible = not context.env.window._instance.Visible
		end,
	},
	{
		name = "about",
		aliases = { "credit", "credits", "info" },
		description = "Shows the about tab in a separate window.",
		optionalPrefix = true,
		envClient = function(_K)
			return _K.Registry.dashboardWindowEnv("About")(_K)
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
			return _K.Registry.dashboardWindowEnv("Commands")(_K)
		end,

		runClient = function(context)
			context._K.UI.edit(context.env.window)({
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
		aliases = { "market", "shop", "store", "support" },
		description = "Shows the market tab in a separate window.",
		optionalPrefix = true,
		envClient = function(_K)
			return _K.Registry.dashboardWindowEnv("Market")(_K)
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
			"commandlogs",
			"joinlogs",
			"damagelogs",
			"killlogs",
			"purchaselogs",
			"cmdlogs",
			"dmglogs",
			"buylogs",
		},
		description = "Shows the logs in a separate window.",
		optionalPrefix = true,
		envClient = function(_K)
			local env = {
				aliasMap = {
					cmdlogs = "commandlogs",
					dmglogs = "damagelogs",
					buylogs = "purchaselogs",
				},
				typeMap = {
					DEBUG = { "DEBUG", "INFO", "WARN", "ERROR" },
					ERROR = { "WARN", "ERROR" },
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
				_K.UI.edit(window)({
					_Visible = function()
						if not window._instance.Visible then
							_K.UI.edit(_K.client.dashboard.Tabs)({
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
				})
				env.window = window
			end)
			return env
		end,

		runClient = function(context)
			context._K.UI.edit(context.env.window)({
				Visible = true,
				context._K.client.dashboard.Logs,
			})
			context._K.client.dashboard.Logs._instance.Visible = true

			if not context.env.originalFilter then
				context.env.originalFilter = {}
				for logType, state in context._K.client.dashboard.Logs.logTypeFilter do
					context.env.originalFilter[logType] = state:peek()
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
			return _K.Registry.dashboardWindowEnv("Settings")(_K)
		end,

		runClient = function(context)
			context._K.UI.edit(context.env.window)({
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

			local emoteId = UI.signal(nil)
			local ownsEmote = UI.signal(false)

			env.emoteId = emoteId

			task.defer(function()
				while not _K.client do
					task.wait()
				end

				local worldModel = Instance.new("WorldModel")
				local previewCamera = UI.new "Camera" {}
				local state = {
					cameraAngleX = 0,
					cameraAngleY = 180,
					cameraZ = 9,
					dragStart = nil,
					startAngleX = 0,
					startAngleY = 0,
					previewId = nil,
				}

				local cameraStartCFrame = CFrame.new(0, 3, 0)
					* CFrame.fromOrientation(math.rad(state.cameraAngleX), math.rad(state.cameraAngleY), 0)
					* CFrame.new(0, 0, state.cameraZ)

				local resetCameraTween =
					_K.Service.Tween:Create(previewCamera, TweenInfo.new(1, Enum.EasingStyle.Cubic), {
						CFrame = cameraStartCFrame,
					})

				local resetCamera = _K.Util.Function.debounce(4, function()
					resetCameraTween:Play()
				end)

				function state.updateCamera()
					previewCamera.CFrame = CFrame.new(0, 3, 0)
						* CFrame.fromOrientation(math.rad(state.cameraAngleX), math.rad(state.cameraAngleY), 0)
						* CFrame.new(0, 0, state.cameraZ)
					if not (previewCamera.CFrame):FuzzyEq(cameraStartCFrame) then
						resetCamera()
					end
				end

				state.updateCamera()

				env.preview = createEmotePreviewFrame(_K, UI, env, previewCamera, worldModel, state)
				setupEmotePreviewModel(_K, env, worldModel, state)
				connectEmoteBulkPurchase(_K, env, emoteId, ownsEmote, state)
				createEmoteControlWindow(_K, UI, env, emoteId, ownsEmote)
			end)

			local playEmote = createPlayEmote(_K, env, emoteId, ownsEmote)
			env.playEmote = playEmote
			local _ = _K.Remote.Emote:Connect(playEmote)

			return env
		end,
		env = function(_K)
			return {
				remote = _K.Remote.Emote,
			}
		end,
		run = function(context, players, animation: number, loop: boolean?, speed: number?)
			local _K, fromPlayer = context._K, context.fromPlayer
			if type(animation) == "number" and not hasEmoteAccess(_K, context.from, fromPlayer) then
				if not fromPlayer or not fromPlayer.Parent then
					return
				end
				local hasAccess = false
				if fromPlayer:GetAttribute("_KDonationLevel") == nil and _K.VIP and _K.VIP.setDonationLevel then
					_K.VIP.setDonationLevel(fromPlayer)
					if not fromPlayer.Parent then
						return
					end
					hasAccess = hasEmoteAccess(_K, context.from, fromPlayer)
				end
				if not hasAccess then
					local emoteId = _K.Data.animationToEmoteId[animation] or animation
					local ok, owned = _K.Util.Retry(function()
						return _K.Service.Marketplace:PlayerOwnsAssetAsync(fromPlayer, emoteId)
					end, 3)
					if not ok or not fromPlayer.Parent then
						return
					end
					if not owned then
						if _K.VIP.allowedBulkPurchaseIds[emoteId] then
							local items = {
								{ Type = Enum.MarketplaceProductType.AvatarAsset, Id = tostring(emoteId) },
							}
							_K.Service.Marketplace:PromptBulkPurchase(fromPlayer, items, {})
						elseif _K.Data.settings.vip then
							_K.Remote.VIPNotification:Fire(fromPlayer, true)
						end
						return
					end
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
						return createEmotesItem(_K, UI, EMOTE, self, initialLineData)
					end,
					RenderItem = function(self, lineItem, lineData)
						renderEmotesItem(_K, self, lineItem, lineData)
					end,
				}

				UI.edit(scroller._instance)({
					UI.padding(UI.Theme.PaddingStroke),
				})
				UI.edit(scroller._scroller.UIPadding)({
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
		name = "gameid",
		aliases = {},
		description = "Displays the current GameId.",
		runClient = function(context, volume)
			context._K.Notify({ From = "GameId", Text = tostring(game.GameId), Selectable = true })
		end,
	},
	{
		name = "jobid",
		aliases = {},
		description = "Displays the current JobId.",
		runClient = function(context, volume)
			context._K.Notify({ From = "JobId", Text = tostring(game.JobId), Selectable = true })
		end,
	},
	{
		name = "placeid",
		aliases = {},
		description = "Displays the current PlaceId.",
		runClient = function(context, volume)
			context._K.Notify({ From = "PlaceId", Text = tostring(game.PlaceId), Selectable = true })
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
			local function onShowFPSInvoke()
				return env.fps
			end
			_K.Remote.ShowFPS.OnInvoke = onShowFPSInvoke
			local frames, last = 0, tick()
			local _ = _K.Service.Run.Heartbeat:Connect(function()
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
			-- the target's client answers, it can error or return anything
			local ok, fps = pcall(context.env.remote.Invoke, context.env.remote, player)
			fps = if ok and type(fps) == "number" and fps == fps then math.clamp(fps, 0, 999) else 0
			context._K.Remote.Notify:Fire(context.fromPlayer, {
				Text = `<b>FPS:</b> {math.round(fps)}`,
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
			context._K.client.members(context._K.Data.members, true)
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
