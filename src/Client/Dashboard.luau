local _K = require(script.Parent.Parent)
local UI = require(script.Parent.UI)
local TopbarPlus = require(script.Parent.TopbarPlus)

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

_K.client.dashboard.Tabs = UI.new "Tabs" {
	_K.client.dashboard.Commands,
	_K.client.dashboard.Bans,
	_K.client.dashboard.Members,
	_K.client.dashboard.Logs,
	_K.client.dashboard.Settings,
	_K.client.dashboard.About,
}

task.delay(0.2, _K.client.dashboard.Tabs.JumpTo, _K.client.dashboard.About)

local dashboard = UI.new "Window" {
	Parent = UI.LayerTopInset,
	Title = UI.compute(function(use)
		return `Kohl's Admin Dashboard  <font transparency="0.75" size = "{use(UI.Theme.FontSize)}">v{_K.VERSION}</font>`
	end),
	Visible = false,

	_K.client.dashboard.Tabs,
}
_K.client.dashboard.Window = dashboard

_K.client.commandBarVisible = UI.state(_K.client.CommandBar.Bar, "Visible")

local titleBarButtonSize = UI.compute(function(use)
	local size = use(UI.Theme.FontSizeLarger) + use(UI.Theme.Padding).Offset
	return UDim2.new(0, size, 0, size)
end)

-- add a command bar toggle button next to the exit button
_K.client.toggleCommandBar = UI.new "Button" {
	BackgroundTransparency = 1,
	Size = titleBarButtonSize,
	Icon = "rbxassetid://85543506317447",
	IconProperties = {
		Size = UDim2.new(0.875, 0, 0.875, 0),
		ImageTransparency = UI.compute(function(use)
			return if use(_K.client.commandBarVisible) then 0 else 0.75
		end),
	},
	Text = "",
	Parent = dashboard._instance.Frame.TitleBar,
	LayoutOrder = 8,

	Activated = function()
		local hide = _K.client.CommandBar.Bar.Visible
		if hide then
			_K.client.CommandBar.hide()
		else
			_K.client.CommandBar.show()
		end
	end,
}
_K.client.toggleCommandBar._instance:FindFirstChildOfClass("UIStroke"):Destroy()

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
			TextWrapped = true,
			Size = UDim2.new(1, 0, 0, 24),
			Text = `<font transparency="0.33">Join the <b>Kohl's Admin</b> Discord server!</font>\n\n<font color="#f00"><b>We are not associated with this game!</b></font>`,
			RichText = true,
		}

		UI.new "TextBox" {
			Parent = social,
			LayoutOrder = -1,
			Name = "Invite",
			AutoLocalize = false,
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundColor3 = Color3.fromHex("#5865F2"),
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

		local socialDialog
		socialDialog = UI.new "Dialog" {
			Parent = UI.LayerTop,
			Title = "Kohl's Admin Discord",
			Text = "",
			Visible = false,
			ExitButton = true,
			BackgroundTransparency = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, 0),
			Size = UDim2.new(0, 256, 0, 0),
			Modal = true,
			ZIndex = 1000,
			Close = function()
				_K.client.lastAttemptedPurchase = false
				socialDialog.Visible:set(false)
			end,

			social,
		}
		local socialButton = UI.new "Button" {
			BackgroundTransparency = 1,
			Size = titleBarButtonSize,
			Icon = "rbxassetid://128691342988958",
			IconProperties = {
				Size = UDim2.new(0.75, 0, 40 / 52.8 * 0.75, 0),
				ImageTransparency = UI.compute(function(use)
					return if use(socialDialog.Visible) then 0 else 0.75
				end),
			},
			Text = "",
			Parent = dashboard._instance.Frame.TitleBar,
			LayoutOrder = 7,

			Activated = function()
				socialDialog.Visible:set(not socialDialog.Visible._value)
			end,
		}
		socialButton._instance:FindFirstChildOfClass("UIStroke"):Destroy()

		local function updateDialogPosition()
			if socialDialog.Visible._value then
				local position = socialButton._instance.AbsolutePosition
					+ socialDialog._instance.AbsoluteSize * socialDialog._instance.AnchorPoint
				socialDialog.Position:set(
					UDim2.fromOffset(
						position.X,
						position.Y + UI.TopbarInset._value.Height + socialButton._instance.AbsoluteSize.Y
					)
				)
			end
		end
		socialDialog.Visible:hook(updateDialogPosition)
		socialButton._instance:GetPropertyChangedSignal("AbsolutePosition"):Connect(updateDialogPosition)
	end
end)

local function dashboardToggle(button)
	if dashboard._instance.Visible then
		UI.Sound.Hover01:Play()
		UI.clearState("hover")
		UI.clearState("floating")
	else
		UI.Sound.Hover03:Play()
	end
	local container = _K.client.dashboard.Tabs._pages.CurrentPage
	local page = container and container:FindFirstChildWhichIsA("GuiObject")
	if page then
		page.Visible = button.isSelected
	end
	dashboard._instance.Visible = button.isSelected
end

local buttonEnabled = _K.Data.settings.dashboardButtonRank
	and _K.Data.settings.dashboardButtonRank <= _K.Auth.getRank(UI.LocalPlayer.UserId)
local dashboardButton = TopbarPlus.new()
	:setName("KADashboardIcon")
	:setCaption("Kohl's Admin Dashboard")
	:setImage(10650723871)
	:setOrder(-1)
	:setEnabled(buttonEnabled)
	:bindEvent("toggled", dashboardToggle)
	:modifyTheme({ "Widget", "BorderSize", 0 })
local dashboardButtonIcon = dashboardButton:getInstance("IconImage")

_K.client.dashboardButton = dashboardButton

_K.client.hotkeys.dashboard.callback = function()
	if _K.client.dashboardEnabled then
		if dashboardButton.isSelected then
			dashboardButton:deselect()
		else
			dashboardButton:select()
		end
	end
end

dashboard._exitButton._instance.Activated:Connect(function()
	dashboardButton:deselect()
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
