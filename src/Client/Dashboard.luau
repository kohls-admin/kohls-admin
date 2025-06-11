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
		return `Kohl's Admin  <stroke transparency="1"><font transparency="0.75" size="{math.round(
			use(UI.Theme.FontSize)
		)}">v{_K.VERSION}</font></stroke>`
	end),
	Visible = false,

	_K.client.dashboard.Tabs,
}
_K.client.dashboard.Window = dashboard

_K.client.commandBarVisible = UI.state(_K.client.CommandBar.Bar, "Visible")

local titleBarButtonSize = UI.compute(function(use)
	local size = use(UI.Theme.FontSizeLargest)
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
	ImageTransparency = UI.compute(function(use)
		return if use(_K.client.commandBarVisible)
			then 0
			elseif use(_K.client.toggleCommandBar._hovering) then 0.5
			else 0.75
	end),
})

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
			Text = UI.compute(function(use)
				local invalidColor = use(UI.Theme.Invalid):ToHex()
				local socialWarning = if true or game.CreatorId ~= 3403354
					then `\n\n<font color="#{invalidColor}"><b>This game wasn't made by us!</b></font>`
					else ""
				return `<font transparency="0.33">Join the <b>Kohl's Admin</b> Discord server!</font>{socialWarning}`
			end),
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
			ImageTransparency = UI.compute(function(use)
				return if use(socialMenu.Visible) then 0 elseif use(socialButton._hovering) then 0.5 else 0.75
			end),
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
		UI.clearState("hover")
		UI.clearState("floating")
	end
	local container = _K.client.dashboard.Tabs._pages.CurrentPage
	local page = container and container:FindFirstChildWhichIsA("GuiObject")
	if page then
		page.Visible = button.isSelected
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
