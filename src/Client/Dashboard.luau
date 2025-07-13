local _K = require(script.Parent.Parent)
local UI = require(script.Parent.UI)
local TopbarPlus = require(script.Parent.Parent.TopbarPlus)

local About = require(script.Parent.About)
local Bans = require(script.Parent.Bans)
local Commands = require(script.Parent.Commands)
local Logs = require(script.Parent.Logs)
local Members = require(script.Parent.Members)
local Settings = require(script.Parent.Settings)

local clockStart = os.clock()

_K.client.dashboard = {}
_K.client.dashboard.About = About.new(_K)
_K.client.dashboard.Commands = Commands.new(_K)
_K.client.dashboard.Bans = Bans.new(_K)
_K.client.dashboard.Members = Members.new(_K)
_K.client.dashboard.Logs = Logs.new(_K)
_K.client.dashboard.Settings = Settings.new(_K)

local titleLine = UI.new "Frame" {
	Name = "Line",
	BackgroundColor3 = UI.Theme.Border,
	BackgroundTransparency = UI.Theme.TransparencyBalanced,
	BorderSizePixel = 0,
	Size = UDim2.new(1, 0, 0, 1),
}

local tabs = UI.new "Tabs" {
	Vertical = true,
	_K.client.dashboard.Commands,
	_K.client.dashboard.Bans,
	_K.client.dashboard.Members,
	_K.client.dashboard.Logs,
	_K.client.dashboard.Settings,
	_K.client.dashboard.About,

	[UI.Event] = {
		AbsoluteSize = function()
			local size = _K.client.dashboard.Tabs._instance.AbsoluteSize
			_K.client.dashboard.Tabs.Vertical(size.x > size.y)
			titleLine.Visible = size.x > size.y
		end,
	},
}
_K.client.dashboard.Tabs = tabs

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
	Size = UDim2.fromOffset(640, 480),
	SizeBounds = Rect.new(128, 128, 9e9, 9e9),
	Title = "",
	Visible = false,
	_K.client.dashboard.Tabs,
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

titleLine.Parent = dashboard._instance.Frame

local titleBar = dashboard._instance.Frame.TitleBar

UI.edit(titleBar.UIPadding, {
	PaddingLeft = UI.Theme.PaddingDouble,
})

UI.edit(titleBar.Left.Title, {
	TextSize = UI.Theme.FontSize,
	TextTransparency = 0.5,
})

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
	local moveToTitleBar = UI.state(false)

	local function update()
		local parent = instance.Parent
		local move = parent
			and parent:IsDescendantOf(dashboard._instance)
			and _K.client.dashboard.Tabs._pages.CurrentPage == instance.Parent
			and _K.client.dashboard.Tabs.Vertical()

		moveToTitleBar(move, true)
	end

	instance:GetPropertyChangedSignal("Parent"):Connect(update)
	tabs._pages:GetPropertyChangedSignal("CurrentPage"):Connect(function()
		local page = tabs._pageCache[tabs._pages.CurrentPage]
		if page == instance then
			update()
		end
	end)

	UI.new "UIFlexItem" {
		Parent = page._input._instance,
		FlexMode = function()
			return if moveToTitleBar() then Enum.UIFlexMode.Fill else Enum.UIFlexMode.None
		end,
	}
	UI.edit(page._input, {
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
			titleBar.Spacer.Visible = next(parented) == nil
			return if move then titleBar else instance
		end,
	})
	UI.edit(page._scroller.UIPadding, {
		PaddingTop = function()
			return if moveToTitleBar() then UI.Theme.Padding else UDim.new(0, 1)
		end,
	})
end

UI.edit(_K.client.dashboard.Logs._scroller.UIPadding, {
	PaddingTop = UDim.new(),
})

UI.edit(_K.client.dashboard.Tabs._instance.Bar.UIPadding, {
	PaddingBottom = function()
		return if _K.client.dashboard.Tabs.Vertical() then UDim.new() else UI.Theme.Padding
	end,
})

local titleSize = UI.state(titleBar.Left.Title, "AbsoluteSize")
local tabBarSize = UI.state(_K.client.dashboard.Tabs._instance.Bar, "AbsoluteSize")

UI.edit(dashboard._instance.Frame.TitleBar.Left, {
	Size = function()
		return if _K.client.dashboard.Tabs.Vertical()
			then UDim2.fromOffset(tabBarSize().X - UI.Theme.PaddingDouble().Offset, 0)
			else UDim2.new()
	end,
})

UI.new "Frame" {
	Name = "SideBar",
	Parent = dashboard._instance,
	BackgroundTransparency = 1,
	ClipsDescendants = true,
	Size = function()
		if _K.client.dashboard.Tabs.Vertical() then
			local padding = UI.Theme.Padding().Offset
			local titleWidth = (titleBar.Left.Title.AbsolutePosition.X + titleSize().X + padding * 4)
				- titleBar.Left.AbsolutePosition.X
			local maxWidth = math.max(titleWidth, tabBarSize().X)
			local statusBarHeight = UI.Theme.FontSize + padding + 1
			_K.client.dashboard.Tabs._instance.Bar.Size = UDim2.new(0, titleWidth, 1, 0)
			return UDim2.new(0, maxWidth + 1, 1, -statusBarHeight)
		else
			_K.client.dashboard.Tabs._instance.Bar.Size = UDim2.new(1, 0, 0, 0)
			return UDim2.new()
		end
	end,
	UI.new "Frame" {
		BackgroundTransparency = UI.Theme.TransparencyMax,
		BackgroundColor3 = UI.Theme.Secondary,
		Size = UDim2.fromScale(2, 1),
		UI.new "UICorner" {
			CornerRadius = UI.Theme.CornerRadius,
		},
	},
	UI.new "Frame" {
		Name = "Line",
		BackgroundColor3 = UI.Theme.Border,
		BackgroundTransparency = UI.Theme.TransparencyBalanced,
		BorderSizePixel = 0,
		Position = UDim2.new(1, -1, 0, 0),
		Size = UDim2.new(0, 1, 1, 0),
	},
	Visible = _K.client.dashboard.Tabs.Vertical,
}

local statusLabelPosition = UI.compute(function()
	return UDim2.fromOffset(UI.Theme.FontSize() + UI.Theme.PaddingHalf().Offset, 0)
end)

local function statusIconLabel(name, imageDefinition, labelDefinition, tooltipDefinition)
	return UI.new "Frame" {
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Name = name,
		Size = UDim2.new(0, 0, 1, 0),
		UI.edit(
			UI.new "ImageLabel" {
				BackgroundTransparency = 1,
				Image = UI.Theme.Image.Signal,
				ImageColor3 = UI.Theme.PrimaryText,
				ImageTransparency = 0.5,
				Size = UDim2.new(1, 0, 1, 0),
				SizeConstraint = Enum.SizeConstraint.RelativeYY,
			},
			imageDefinition or {}
		),
		UI.edit(
			UI.new "TextLabel" {
				Name = "Label",
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundTransparency = 1,
				Position = statusLabelPosition,
				Size = UDim2.fromScale(0, 1),
				Font = UI.Theme.FontMono,
				Text = "?",
				TextColor3 = UI.Theme.PrimaryText,
				TextSize = UI.Theme.FontSize,
				TextTransparency = 0.5,
			},
			labelDefinition or {}
		),
		UI.edit(UI.new "Tooltip" { Font = UI.Theme.FontMono, Text = name }, tooltipDefinition or {}),
	}
end

local function getAvgLow(buffer, avg, low, sum, nextAvgUpdate)
	local now = tick()
	if now > nextAvgUpdate then
		nextAvgUpdate = now + 2
		table.sort(buffer)
		avg, low = math.round(sum / #buffer), 0
		local lowCount = math.ceil(#buffer / 100)
		for i = 1, lowCount do
			low += buffer[i]
		end
		low //= lowCount
		table.clear(buffer)
	end
	return avg, low, 0
end

local lerpGreenRed
do
	local hueGreen = UI.compute(function()
		return UI.Color.Oklab.toHCL(UI.Color.Oklab.fromLinear(UI.Theme.Valid())).X
	end)
	local hueRed = UI.compute(function()
		return UI.Color.Oklab.toHCL(UI.Color.Oklab.fromLinear(UI.Theme.Invalid())).X
	end)
	lerpGreenRed = function(alpha: number)
		local hcl = Vector3.new(math.lerp(hueGreen(), hueRed(), alpha), 1, 1)
		return UI.Color.Oklab.toLinear(UI.Color.Oklab.fromHCL(hcl))
	end
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
		return UDim2.new(1, 0, 0, UI.Theme.FontSizeSmall + UI.Theme.PaddingDouble().Offset)
	end,
	UI.new "Frame" {
		AnchorPoint = Vector2.new(0, 1),
		BackgroundTransparency = UI.Theme.TransparencyMax,
		BackgroundColor3 = UI.Theme.Secondary,
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, 2),
		UI.new "UICorner" {
			CornerRadius = UI.Theme.CornerRadius,
		},
	},
	UI.new "Frame" {
		Name = "Line",
		BackgroundColor3 = UI.Theme.Border,
		BackgroundTransparency = UI.Theme.TransparencyBalanced,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 0, 0),
		Size = UDim2.new(1, 0, 0, 1),
	},

	UI.new "Frame" {
		Name = "Content",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		UI.new "UIListLayout" {
			SortOrder = Enum.SortOrder.LayoutOrder,
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UI.Theme.PaddingDouble,
		},
		UI.new "UIPadding" {
			PaddingLeft = UI.Theme.Padding,
			PaddingRight = UI.Theme.Padding,
			PaddingTop = UI.Theme.Padding,
			PaddingBottom = UI.Theme.Padding,
		},
		statusIconLabel("Ping", {
			Image = UI.Theme.Image.SignalSheet,
			ImageRectSize = Vector2.new(86, 86),
		}, {
			UI.action(function(instance)
				local ping, max, avg, nFrames, sum = 0, 0, 0, 0, 0
				local buffer, nextAvgUpdate = {}, tick()
				_K.Service.Run.Heartbeat:Connect(function()
					ping = math.round(_K.Service.Players.LocalPlayer:GetNetworkPing() * 1000)
					max = math.min(math.max(max, ping), 30000)
					nFrames += 1
					sum += ping
					table.insert(buffer, ping)
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
			end),
		}),
		statusIconLabel("FPS", {
			Image = UI.Theme.Image.Pace,
		}, {
			UI.action(function(instance)
				local fps, max, avg, low, sum = 0, 0, 0, 0, 0
				local buffer, nextAvgUpdate = {}, tick()
				_K.Service.Run.Heartbeat:Connect(function()
					fps = math.round(1 / _K.Service.Stats.FrameTime)
					max = math.min(math.max(max, fps), 240)
					sum += fps
					table.insert(buffer, fps)
				end)
				repeat
					task.wait(1)
					avg, low, sum = getAvgLow(buffer, avg, low, sum, nextAvgUpdate)

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
			end),
		}),
		UI.edit(
			statusIconLabel("Memory Usage (RAM)", {
				Image = UI.Theme.Image.Memory_Alt,
			}, {
				UI.action(function(instance)
					repeat
						task.wait(1)
						instance.Text = `{math.round(_K.Service.Stats:GetTotalMemoryUsageMb())} MB`
					until nil
				end),
			}),
			{ UI.new "UIFlexItem" { FlexMode = Enum.UIFlexMode.Fill } }
		),
		statusIconLabel("Uptime", {
			Image = UI.Theme.Image.Hourglass_Bottom,
		}, {
			UI.action(function(instance)
				local function getTimeString(amount)
					local hours = math.floor(amount / 3600)
					local minutes = math.floor((amount % 3600) / 60)
					local seconds = math.floor(amount % 60)
					local strings = {}
					for k, v in { hours, minutes, seconds } do
						if hours > 0 or v > 0 or k == 3 then
							table.insert(
								strings,
								if (v < 10 and v > 0) and ((k == 2 and hours == 0) or (k == 3 and minutes == 0))
									then tostring(v)
									else string.format("%02d", v)
							)
						end
					end
					return table.concat(strings, ":")
				end
				repeat
					task.wait(1)
					local uptime = math.round(workspace:GetServerTimeNow() - _K.script:GetAttribute("ServerStartTime"))
					instance.Text = getTimeString(uptime)

					local tooltip = UI.Class.Tooltip.Cache[instance.Parent]
					if tooltip then
						tooltip.Text(`Server Uptime\n\n<b>Client Uptime:</b>  {getTimeString(time())}`)
					end
				until nil
			end),
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

_K.client.commandBarVisible = UI.state(_K.client.CommandBar.Bar, "Visible")

local titleBarButtonSize = UI.compute(function()
	local size = UI.Theme.FontSizeLargest()
	return UDim2.fromOffset(size, size)
end)

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

	Activated = function()
		if _K.client.CommandBar.Bar.Visible then
			_K.client.CommandBar.hide()
		else
			_K.client.CommandBar.show()
		end
	end,
}
_K.client.toggleCommandBar._instance:FindFirstChildOfClass("UIStroke"):Destroy()
UI.edit(_K.client.toggleCommandBar._content.IconFrame.Icon, {
	ImageTransparency = function()
		return if _K.client.commandBarVisible() then 0 elseif _K.client.toggleCommandBar._hovering() then 0.5 else 0.75
	end,
})

UI.new "Tooltip" {
	Parent = _K.client.toggleCommandBar,
	Hovering = _K.client.toggleCommandBar._hovering,
	Text = "Command Bar",
}

task.defer(function()
	local success, result = _K.Util.Retry(function()
		return _K.Util.Service.PolicyService:GetPolicyInfoForPlayerAsync(_K.Util.Service.Players.LocalPlayer)
	end)

	local socialInvite = success
		and result.AllowedExternalLinkReferences
		and table.find(result.AllowedExternalLinkReferences, "Discord")

	if socialInvite then
		local social = UI.new "Frame" {
			Name = "Social",
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -2, 0, 0),
			LayoutOrder = 2,

			UI.new "UIListLayout" {
				SortOrder = Enum.SortOrder.LayoutOrder,
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				Padding = UI.Theme.PaddingDouble,
				Wraps = true,
			},
		}

		UI.new "TextLabel" {
			Parent = social,
			LayoutOrder = -2,
			AutoLocalize = false,
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Font = UI.Theme.Font,
			TextSize = UI.Theme.FontSize,
			TextColor3 = UI.Theme.PrimaryText,
			TextStrokeColor3 = UI.Theme.Primary,
			TextStrokeTransparency = UI.Theme.TextStrokeTransparency,
			TextWrapped = true,
			Size = UDim2.new(1, 0, 0, 24),
			Text = function()
				local invalidColor = UI.Theme.Invalid():ToHex()
				local socialWarning = if game.CreatorId ~= 3403354
					then `\n\n<font color="#{invalidColor}"><b>This game wasn't made by us!</b></font>`
					else ""
				return `<font transparency="0.33">Join the <b>Kohl's Admin</b> Discord server!</font>{socialWarning}`
			end,
			RichText = true,
		}

		UI.new "TextBox" {
			Parent = social,
			LayoutOrder = -1,
			Name = "Invite",
			AutoLocalize = false,
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = Color3.fromHex("#5865F2"),
			Size = UDim2.fromScale(1, 0),
			Font = UI.Theme.FontMono,
			TextSize = UI.Theme.FontSize,
			TextColor3 = Color3.new(1, 1, 1),
			Text = "discord.gg/kohl",
			TextWrapped = true,
			TextEditable = false,
			ClearTextOnFocus = false,

			UI.new "UICorner" {
				CornerRadius = UI.Theme.CornerRadius,
			},
			UI.new "UIPadding" {
				PaddingLeft = UI.Theme.Padding,
				PaddingRight = UI.Theme.Padding,
				PaddingTop = UI.Theme.Padding,
				PaddingBottom = UI.Theme.Padding,
			},
		}

		local socialMenu
		local socialButton = UI.new "Button" {
			BackgroundTransparency = 1,
			HoverTransparency = 1,
			Size = titleBarButtonSize,
			Icon = "rbxassetid://129281087731453",
			IconProperties = {
				ImageColor3 = UI.Theme.PrimaryText,
				Size = UDim2.new(0.75, 0, 50 / 66 * 0.75, 0),
			},
			Text = "",
			Parent = dashboard._instance.Frame.TitleBar,
			LayoutOrder = 7,
			Activated = function()
				UI.toggleState(socialMenu.Visible, "floating")
			end,
		}
		socialButton._instance:FindFirstChildOfClass("UIStroke"):Destroy()
		UI.new "Tooltip" {
			Parent = socialButton,
			Hovering = socialButton._hovering,
			Text = "Kohl's Admin Community",
		}

		socialMenu = UI.new "Menu" {
			Adornee = socialButton._instance,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.fromOffset(256, 0),

			UI.new "UIPadding" {
				PaddingTop = UI.Theme.Padding,
				PaddingBottom = UI.Theme.Padding,
				PaddingLeft = UI.Theme.Padding,
				PaddingRight = UI.Theme.Padding,
			},

			social,
		}
		socialMenu._content.AutomaticSize = Enum.AutomaticSize.Y

		UI.edit(socialButton._content.IconFrame.Icon, {
			ImageTransparency = function()
				return if socialMenu.Visible() then 0 elseif socialButton._hovering() then 0.5 else 0.75
			end,
		})
	end
end)

local function dashboardToggle(button)
	if not _K.client.dashboardEnabled then
		return
	end
	if button.isSelected then
		UI.Sound.Hover03:Play()
	else
		UI.Sound.Hover01:Play()
		UI.clearActiveStates()
	end
	local container = _K.client.dashboard.Tabs._pages.CurrentPage
	local page = container and container:FindFirstChildWhichIsA("GuiObject")
	if page then
		page.Visible = button.isSelected
	end
	if (not container) or (#container:GetChildren() == 0) then
		_K.client.dashboard.Tabs.JumpTo(_K.client.dashboard.About)
	end
	dashboard._instance.Visible = button.isSelected
end

local buttonEnabled = _K.Data.settings.dashboardButtonRank
	and _K.Data.settings.dashboardButtonRank <= _K.Auth.getRank(_K.LocalPlayer.UserId)
local dashboardButton = TopbarPlus.new()
	:setName("KADashboardIcon")
	:setCaption("Kohl's Admin Dashboard")
	:setImage(71961243872230)
	:setOrder(-1)
	:setEnabled(buttonEnabled)
	:bindEvent("toggled", dashboardToggle)
local dashboardButtonIcon = dashboardButton:getInstance("IconImage")

if dashboardButton.modifyTheme then
	dashboardButton:modifyTheme({ "Widget", "BorderSize", 0 })
end

_K.client.dashboardButton = dashboardButton

local fakeButton = { isSelected = false }
_K.client.hotkeys.dashboard.callback = function()
	if not _K.client.dashboardEnabled then
		return
	end
	if _K.client.dashboardButtonEnabled then
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

dashboard._exitButton._instance.Activated:Connect(function()
	dashboardButton:deselect()
	fakeButton.isSelected = false
end)

task.spawn(function()
	local elapsed = 1
	while dashboard and dashboardButton and dashboard._instance do
		local dt = task.wait()
		if dashboard._instance.Visible then
			local alpha = math.abs(elapsed % 2 - 1) * 0.7
			dashboardButtonIcon.ImageTransparency = -(math.cos(math.pi * alpha) - 1) / 2
			elapsed += dt
		elseif elapsed ~= 1 then
			dashboardButtonIcon.ImageTransparency = 0
			elapsed = 1
		end
	end
end)

task.spawn(_K.log, `Dashboard loaded in {math.round((os.clock() - clockStart) * 1000)} ms`, "DEBUG")

return _K.client.dashboard
