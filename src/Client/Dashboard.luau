local _K = require(script.Parent.Parent)
local UI = require(script.Parent:WaitForChild("UI"))

local About = require(script.Parent:WaitForChild("About"))
local Bans = require(script.Parent:WaitForChild("Bans"))
local Commands = require(script.Parent:WaitForChild("Commands"))
local Logs = require(script.Parent:WaitForChild("Logs"))
local Members = require(script.Parent:WaitForChild("Members"))
local Servers = require(script.Parent:WaitForChild("Servers"))
local Settings = require(script.Parent:WaitForChild("Settings"))
local Market = require(script.Parent:WaitForChild("Market"))

local clockStart = os.clock()

_K.client.dashboard = {}
_K.client.dashboard.About = About.new(_K)
_K.client.dashboard.Bans = Bans.new(_K)
_K.client.dashboard.Commands = Commands.new(_K)
_K.client.dashboard.Members = Members.new(_K)
_K.client.dashboard.Servers = Servers.new(_K)
_K.client.dashboard.Logs = Logs.new(_K)
_K.client.dashboard.Settings = Settings.new(_K)
_K.client.dashboard.Market = Market.new(_K)

local tabs = UI.new "Tabs" {
	CurrentPage = _K.client.dashboard.About,
	Tabs = {
		{ _K.client.dashboard.Commands },
		{ _K.client.dashboard.Bans },
		{ _K.client.dashboard.Members },
		{ _K.client.dashboard.Servers },
		{ _K.client.dashboard.Logs },
		{ _K.client.dashboard.Settings },
		{ _K.client.dashboard.About },
		{ _K.client.dashboard.Market },
	},
	Vertical = true,

	_AbsoluteSize = function()
		-- can fire while the dashboard is still being built, before Window and Tabs are assigned below
		local window, dashboardTabs = _K.client.dashboard.Window, _K.client.dashboard.Tabs
		if not window or not dashboardTabs then
			return
		end
		local size = window._instance.AbsoluteSize
		dashboardTabs.Vertical(size.X > size.Y)
	end,
}
_K.client.dashboard.Tabs = tabs

local notPaddedWhenVertical = UI.pick(tabs.Vertical, UDim.new(), UI.Theme.Padding)

local paddedWhenVertical = UI.pick(tabs.Vertical, UI.Theme.Padding, UDim.new())

local paddedWhenVerticalWithStroke = UI.pick(tabs.Vertical, UI.Theme.PaddingWithStroke, UI.Theme.PaddingStroke)

UI.edit(tabs._content)({
	BackgroundColor3 = UI.Theme.Secondary,
	BackgroundTransparency = UI.pick(tabs.Vertical, UI.Theme.TransparencyMax, 1),
	UI.corner(UI.Theme.CornerPadded),
	UI.padding {
		x = paddedWhenVertical,
	},
})

UI.edit(tabs._instance)({
	UI.padding {
		right = paddedWhenVertical,
	},
})

local dashboard = UI.new "Window" {
	Parent = UI.LayerTopInset,
	Icon = "rbxassetid://71961243872230",
	IconProperties = {
		Size = function()
			return UDim2.fromOffset(UI.Theme.FontSize(), UI.Theme.FontSize())
		end,
		UI.new "Tooltip" {
			Text = "Kohl's Admin",
		},
	},
	Position = UDim2.new(0.5, -320, 0.5, -240),
	Size = UDim2.fromOffset(648, 492),
	SizeBounds = Rect.new(128, 128, 9e9, 9e9),
	Title = "",
	Visible = false,
	tabs,
}
_K.client.dashboard.Window = dashboard
dashboard._exitButton.ActiveSound(false)
dashboard._content.UIPadding:Destroy()

task.spawn(function()
	repeat
		task.wait(1)
		dashboard.Title(DateTime.now():FormatLocalTime("LT", "en-us"))
	until nil
end)

local titleBar = dashboard._instance.Frame.TitleBar

UI.edit(titleBar.UIPadding)({
	PaddingLeft = UI.Theme.PaddingDouble,
})

UI.edit(titleBar.Left.Title)({
	TextSize = UI.Theme.FontSize,
	TextTransparency = 0.5,
})

local timeTooltip = UI.new "Tooltip" {
	Parent = titleBar.Left.Title,
}
task.spawn(function()
	repeat
		task.wait(1)
		timeTooltip.Text(DateTime.now():FormatLocalTime("dddd, LL", UI.LocalPlayer.LocaleId))
	until nil
end)

local parented = {}
for _, page in
	{
		_K.client.dashboard.Bans,
		_K.client.dashboard.Commands,
		_K.client.dashboard.Logs,
		_K.client.dashboard.Members,
		_K.client.dashboard.Settings,
	}
do
	local instance = if type(page) == "table" then page._instance else page
	local moveToTitleBar = UI.signal(false)

	local function update()
		local parent = instance.Parent
		local move = parent
			and parent:IsDescendantOf(dashboard._instance)
			and tabs._pages.CurrentPage == parent
			and tabs.Vertical()

		moveToTitleBar(move, true)
	end

	instance:GetPropertyChangedSignal("Parent"):Connect(update)
	tabs._pages:GetPropertyChangedSignal("CurrentPage"):Connect(function()
		local page = tabs._pageCache[tabs._pages.CurrentPage]
		if page == instance then
			update()
		end
	end)
	UI.effect(UI.on(tabs.Vertical, update, true)):get()
	if tabs._pageCache[tabs._pages.CurrentPage] == instance then
		update()
	end

	UI.edit(page._input._instance)({
		UI.flex(UI.pick(moveToTitleBar, "fill", "none")),
	})
	UI.edit(page._input)({
		Size = function()
			local y = if moveToTitleBar() then 0 else 1
			return UDim2.new(y, 0, 0, UI.Theme.FontSize() + UI.Theme.Padding().Offset * 2)
		end,
		LayoutOrder = function()
			return if moveToTitleBar() then 4 else -1
		end,
		Parent = function()
			local move = moveToTitleBar()
			parented[page] = if move then true else nil
			local spacer = titleBar:FindFirstChild("Spacer")
			if spacer then
				spacer.Visible = next(parented) == nil
			end
			return if move then titleBar else instance
		end,
	})
	UI.edit(page._scroller.UIPadding)({
		PaddingTop = paddedWhenVerticalWithStroke,
		PaddingBottom = paddedWhenVerticalWithStroke,
	})
end

UI.edit(_K.client.dashboard.Logs._scroller.UIPadding)({
	PaddingTop = UDim.new(),
})

UI.edit(tabs._instance.Bar.UIPadding)({
	PaddingBottom = notPaddedWhenVertical,
})

UI.edit(tabs._instance.Bar.Tabs)({
	UI.new "Spacer" {
		LayoutOrder = 9e8 - 1,
		Visible = tabs.Vertical,
	},
})

UI.edit(tabs._instance.Bar.Tabs.Market)({
	LayoutOrder = 9e8,
})

UI.edit(tabs._instance.Bar.Tabs.Market.UIContent.Label)({
	Name = "Title",
	UI.gradient(),
})

tabs._instance.Bar.Tabs.Market.UIContent:AddTag("_Keternal")

local tabBarSize = UI.property(tabs._instance.Bar, "AbsoluteSize")

UI.edit(titleBar.Left)({
	Size = function()
		return if tabs.Vertical()
			then UDim2.fromOffset(tabBarSize().X - UI.Theme.Padding().Offset * 3, 0)
			else UDim2.new()
	end,
})

local statusLabelPosition = UI.computed(function()
	return UDim2.fromOffset(UI.Theme.FontSize() + UI.Theme.PaddingHalf().Offset, 0)
end)

local function statusIconLabel(name, imageDefinition, labelDefinition, tooltipDefinition)
	return UI.new "Frame" {
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Name = name,
		Size = UDim2.new(0, 0, 1, 0),
		UI.edit(UI.new "ImageLabel" {
			BackgroundTransparency = 1,
			Image = UI.Theme.Image.Signal,
			ImageColor3 = UI.Theme.PrimaryText,
			ImageTransparency = 0.5,
			Size = UDim2.new(1, 0, 1, 0),
			SizeConstraint = Enum.SizeConstraint.RelativeYY,
		})(imageDefinition or {}),
		UI.edit(UI.new "TextLabel" {
			Name = "Label",
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			Position = statusLabelPosition,
			Size = UDim2.fromScale(0, 1),
			FontFace = UI.Theme.FontMono,
			Text = "?",
			TextColor3 = UI.Theme.PrimaryText,
			TextSize = UI.Theme.FontSize,
			TextTransparency = 0.5,
		})(labelDefinition or {}),
		UI.edit(UI.new "Tooltip" { FontFace = UI.Theme.FontMono, Text = name })(tooltipDefinition or {}),
	}
end

local function getAvgLow(buffer, avg, low, sum, nextAvgUpdate)
	local now = tick()
	if now > nextAvgUpdate then
		nextAvgUpdate = now + 2
		table.sort(buffer)
		avg, low = math.round(sum / #buffer) * 2, 0
		local lowCount = math.ceil(#buffer / 100)
		for i = 1, lowCount do
			low += buffer[i]
		end
		low //= lowCount
		table.clear(buffer)
	end
	return avg, low, 0, nextAvgUpdate
end

local function oklabHue(color: Color3): number
	local lab = UI.Color.Oklab.fromRGB(color)
	return math.atan2(lab.Z, lab.Y) / (2 * math.pi)
end

-- interpolates only the Oklab hue (green -> yellow -> red) at fixed chroma/lightness, so the midpoint stays vivid;
-- the shorter way round the hue circle, for themes whose hues straddle the wrap
local function lerpGreenRed(alpha: number)
	local from = oklabHue(UI.Theme.Valid:peek())
	local delta = (oklabHue(UI.Theme.Invalid:peek()) - from + 0.5) % 1 - 0.5
	return _K.Util.Color.hclToRGB(Vector3.new(from + delta * alpha, 0.4, 1))
end

UI.new "Frame" {
	Name = "StatusBar",
	Parent = dashboard._instance.Frame,
	LayoutOrder = 2 ^ 31 - 1,
	AnchorPoint = Vector2.new(0, 1),
	BackgroundTransparency = 1,
	ClipsDescendants = true,
	Position = UDim2.fromScale(0, 1),
	Size = function()
		return UDim2.new(1, 0, 0, UI.Theme.FontSizeSmall() + UI.Theme.PaddingDouble().Offset)
	end,

	UI.new "Frame" {
		Name = "Content",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		UI.list {
			direction = "x",
			verticalAlign = "center",
			gap = UI.Theme.PaddingDouble,
		},
		UI.padding(UI.Theme.Padding),
		statusIconLabel("Ping", {
			Image = UI.Theme.Image.SignalSheet,
			ImageRectSize = Vector2.new(86, 86),
		}, {
			function(instance)
				task.spawn(function()
					local ping, max, avg, nFrames, sum = 0, 0, 0, 0, 0
					local nextAvgUpdate = tick()
					local _ = _K.Service.Run.Heartbeat:Connect(function()
						ping = math.round(_K.Service.Players.LocalPlayer:GetNetworkPing() * 1000)
						max = math.min(math.max(max, ping), 30000)
						nFrames += 1
						sum += ping
					end)
					repeat
						task.wait(1)
						if tick() > nextAvgUpdate then
							nextAvgUpdate = tick() + 2
							avg = sum // nFrames
							sum, nFrames = 0, 0
						end

						local alpha = math.clamp(ping / 350, 0, 1)
						local color = lerpGreenRed(alpha)
						instance.Parent.ImageLabel.ImageRectOffset =
							Vector2.new(math.round((1 - alpha) * 4) * 90 + math.ceil(alpha), 0)
						instance.Parent.ImageLabel.ImageColor3 = color
						instance.TextColor3 = color
						instance.Text = `{avg}ms`

						local tooltip = UI.Class.Tooltip.Cache[instance.Parent]
						if tooltip then
							tooltip.Text(`Ping\n\n<b>Avg:</b>     {avg}ms\n<b>Max:</b>     {max}ms`)
						end
					until nil
				end)
			end,
		}),
		statusIconLabel("FPS", {
			Image = UI.Theme.Image.Pace,
		}, {
			function(instance)
				task.spawn(function()
					local fps, max, avg, low, sum = 0, 0, 0, 0, 0
					local buffer, nextAvgUpdate = {}, tick()
					local _ = _K.Service.Run.Heartbeat:Connect(function()
						fps = math.round(1 / _K.Service.Stats.FrameTime)
						max = math.clamp(fps, max, 240)
						sum += fps
						table.insert(buffer, fps)
					end)
					repeat
						task.wait(1)
						avg, low, sum, nextAvgUpdate = getAvgLow(buffer, avg, low, sum, nextAvgUpdate)
						avg = math.clamp(avg, 0, 240)

						local alpha = math.clamp(fps / max, 0, 1)
						local color = lerpGreenRed(1 - alpha)
						instance.Parent.ImageLabel.ImageColor3 = color
						instance.TextColor3 = color
						instance.Text = `{avg} fps`

						local tooltip = UI.Class.Tooltip.Cache[instance.Parent]
						if tooltip then
							tooltip.Text(
								`Frames Per Second\n\n<b>1% Low:</b>  {low} fps\n<b>Avg:</b>     {avg} fps\n<b>Max:</b>     {max} fps`
							)
						end
					until nil
				end)
			end,
		}),
		UI.new "Spacer" {},
		statusIconLabel("Uptime", {
			Image = UI.Theme.Image.Hourglass_Bottom,
		}, {
			function(instance)
				task.spawn(function()
					repeat
						task.wait(1)
						local uptime =
							math.round(workspace:GetServerTimeNow() - _K.script:GetAttribute("ServerStartTime"))
						instance.Text = _K.Util.Time.clock(uptime)

						local tooltip = UI.Class.Tooltip.Cache[instance.Parent]
						if tooltip then
							tooltip.Text(
								`Uptime\n\n<b>Server:</b>  {instance.Text}\n<b>Client:</b>  {_K.Util.Time.clock(time())}`
							)
						end
					until nil
				end)
			end,
		}),
		statusIconLabel("Kohl's Admin Version", {
			Image = UI.Theme.Image.Graph1,
			ImageTransparency = UI.Theme.TransparencyStrong,
		}, {
			Text = `{_K.VERSION}`,
			TextTransparency = UI.Theme.TransparencyStrong,
		}),
	},
}

_K.client.commandBarVisible = UI.property(_K.client.CommandBar.Bar, "Visible")

local titleBarButtonSize = UI.computed(function()
	local size = UI.Theme.FontSizeLargest()
	return UDim2.fromOffset(size, size)
end)

local function toggleCommandBar()
	if _K.client.CommandBar.Bar.Visible then
		_K.client.CommandBar.hide()
	else
		_K.client.CommandBar.show()
	end
end

-- add a command bar toggle button next to the exit button
_K.client.toggleCommandBar = UI.new "Button" {
	BackgroundTransparency = 1,
	HoverTransparency = 1,
	Size = titleBarButtonSize,
	Icon = UI.Theme.Image.Terminal,
	IconProperties = {
		ImageColor3 = UI.Theme.PrimaryText,
		Size = UDim2.new(0.75, 0, 0.75, 0),
	},
	Text = "",
	Parent = dashboard._instance.Frame.TitleBar,
	LayoutOrder = 8,

	Activated = toggleCommandBar,
}
_K.client.toggleCommandBar._instance:FindFirstChildOfClass("UIStroke"):Destroy()
UI.edit(_K.client.toggleCommandBar._content.IconFrame.Icon)({
	ImageTransparency = function()
		return if _K.client.commandBarVisible() then 0 elseif _K.client.toggleCommandBar._hovering() then 0.5 else 0.75
	end,
})

UI.new "Tooltip" {
	Parent = _K.client.toggleCommandBar,
	Hovering = _K.client.toggleCommandBar._hovering,
	Text = "Command Bar",
}

local isSelected = UI.signal(false)
local function dashboardToggle(button)
	if not _K.client.dashboardEnabled then
		return
	end
	isSelected(button.isSelected)
	if button.isSelected then
		UI.Sound.Hover03:Play()
	else
		UI.Sound.Hover01:Play()
		UI.clearActiveStates()
	end
	local container = tabs._pages.CurrentPage
	local page = container and container:FindFirstChildWhichIsA("GuiObject")
	if page then
		page.Visible = button.isSelected
	end
	dashboard._instance.Visible = button.isSelected
	if button.isSelected then
		task.delay(4, _K.client.VIPNotification)
	end
end

local function toggleCommandBarWithSound()
	if _K.client.CommandBar.Bar.Visible then
		UI.Sound.Hover03:Play()
		_K.client.CommandBar.hide()
	else
		UI.Sound.Hover01:Play()
		_K.client.CommandBar.show()
		UI.Haptic.Hover:Play()
	end
end

local dashboardButtonPadding = UI.spring(function()
	return if isSelected() then UDim.new(0, 10) else UDim.new(0, 12)
end, 8 / math.pi, 0.5)

local fakeButton = { isSelected = false }
local dashboardButton = UI.new "TextButton" {
	Parent = UI.TopbarFrame,
	Name = "KADashboardButton",
	BackgroundColor3 = Color3.fromRGB(18, 18, 21),
	BackgroundTransparency = 0.08,
	Size = UDim2.fromScale(1, 1),
	SizeConstraint = Enum.SizeConstraint.RelativeYY,
	Text = "",
	Visible = false,

	UI.corner(UDim.new(1, 0)),
	UI.padding(dashboardButtonPadding),

	UI.new "ImageLabel" {
		BackgroundTransparency = 1,
		Image = "rbxassetid://71961243872230",
		Size = UDim2.fromScale(1, 1),
	},

	Activated = function()
		fakeButton.isSelected = not fakeButton.isSelected
		dashboardToggle(fakeButton)
	end,
	MouseButton2Click = toggleCommandBarWithSound,
	TouchLongPress = toggleCommandBarWithSound,
}

_K.client.dashboardButton = dashboardButton

function _K.client.commandsWindowVisible(visible: boolean)
	local context = _K.Registry.commands.cmds
	if visible then
		UI.edit(context.env.window)({
			Visible = true,
			_K.client.dashboard.Commands,
		})
		_K.client.dashboard.Commands._instance.Visible = true
	else
		context.env.window._instance.Visible = false
		_K.UI.edit(_K.client.dashboard.Tabs)({
			_K.client.dashboard.Commands,
		})
	end
end

local function toggleCommandsWindow()
	_K.client.commandsWindowVisible(
		_K.client.dashboard.Commands._instance.Parent ~= _K.Registry.commands.cmds.env.window._content
	)
end

local commandsButton = UI.new "TextButton" {
	Parent = UI.TopbarFrame,
	Name = "KACommandsButton",
	BackgroundColor3 = Color3.fromRGB(18, 18, 21),
	BackgroundTransparency = 0.08,
	Size = UDim2.fromScale(1, 1),
	SizeConstraint = Enum.SizeConstraint.RelativeYY,
	Text = "",
	Visible = true,

	UI.corner(UDim.new(1, 0)),
	UI.padding(12),

	UI.new "ImageLabel" {
		BackgroundTransparency = 1,
		Image = UI.Theme.Image.Terminal,
		Size = UDim2.fromScale(1, 1),
	},

	Activated = toggleCommandsWindow,
	MouseButton2Click = toggleCommandBarWithSound,
	TouchLongPress = toggleCommandBarWithSound,
}

_K.client.commandsButton = commandsButton

task.spawn(function()
	repeat
		task.wait()
	until _K.client.TopbarPlus

	dashboardButton:Destroy()
	dashboardButton = _K.client.TopbarPlus
		.new()
		:setName("KADashboardButton")
		:setImage(71961243872230)
		:setImageScale(1)
		:setOrder(-1)
		:setEnabled(_K.client.dashboardButtonEnabled)
		:bindEvent("toggled", dashboardToggle)

	local image = dashboardButton:getInstance("IconImage")
	if image then
		UI.padding(dashboardButtonPadding).Parent = image.Parent
	end

	_K.client.dashboardButton = dashboardButton

	commandsButton:Destroy()
	commandsButton = _K.client.TopbarPlus
		.new()
		:setName("KACommandsButton")
		:setImage(string.match(UI.Theme.Image.Terminal:peek(), "%d+$"))
		:setImageScale(1)
		:setOrder(-1)
		:setEnabled(_K.client.commandsButtonEnabled)
		:bindEvent("toggled", toggleCommandsWindow)

	_K.client.commandsButton = commandsButton

	local image2 = commandsButton:getInstance("IconImage")
	if image2 then
		UI.padding(12).Parent = image2.Parent
	end

	for _, button in { commandsButton, dashboardButton } do
		if button.modifyTheme then
			button:modifyTheme({ "Widget", "BorderSize", 0 })
		end

		local clickRegion: TextButton? = button:getInstance("ClickRegion")
		if clickRegion then
			local _ = clickRegion.MouseButton2Click:Connect(toggleCommandBarWithSound)
			local _ = clickRegion.TouchLongPress:Connect(toggleCommandBarWithSound)
		end

		local iconSpot = button:getInstance("IconSpot")
		if iconSpot then
			iconSpot.Size = UDim2.fromOffset(44, 44)
		end
	end
end)

_K.client.hotkeys.dashboard.callback = function()
	if not _K.client.dashboardEnabled then
		return
	end
	if _K.client.dashboardButtonEnabled and _K.client.TopbarPlus then
		if dashboardButton.isSelected then
			dashboardButton:deselect()
		else
			dashboardButton:select()
		end
	else
		fakeButton.isSelected = not fakeButton.isSelected
		dashboardToggle(fakeButton)
	end
end

local _ = dashboard._exitButton._instance.Activated:Connect(function()
	fakeButton.isSelected = false
	if _K.client.TopbarPlus then
		dashboardButton:deselect()
	else
		dashboardToggle(fakeButton)
	end
end)

task.spawn(_K.log, `Dashboard loaded in {math.round((os.clock() - clockStart) * 1000)} ms`, "DEBUG")

return _K.client.dashboard
