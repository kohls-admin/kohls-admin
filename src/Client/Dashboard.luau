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

UI.Scope.dashboard.About = About.new(_K)
UI.Scope.dashboard.Commands = Commands.new(_K)
UI.Scope.dashboard.Bans = Bans.new(_K)
UI.Scope.dashboard.Members = Members.new(_K)
UI.Scope.dashboard.Logs = Logs.new(_K)
UI.Scope.dashboard.Settings = Settings.new(_K)

UI.Scope.dashboard.Tabs = UI.new "Tabs" {
	UI.Scope.dashboard.Commands,
	UI.Scope.dashboard.Bans,
	UI.Scope.dashboard.Members,
	UI.Scope.dashboard.Logs,
	UI.Scope.dashboard.Settings,
	UI.Scope.dashboard.About,
}

UI.Scope.dashboard.Tabs._pages:JumpTo(UI.Scope.dashboard.About)

local dashboard = UI.new "Window" {
	Parent = UI.LayerTopInset,
	Title = "Kohl's Admin Dashboard",
	Visible = false,

	UI.Scope.dashboard.Tabs,
}
UI.Scope.dashboard.Window = dashboard

UI.Scope.commandBarVisible = UI.state(_K.client.CommandBar.Bar, "Visible")

-- add a command bar toggle button next to the exit button
local toggleCommandBar
toggleCommandBar = UI.new "Button" {
	Size = UI.compute(function(use)
		local size = use(UI.Theme.FontSize) + use(UI.Theme.PaddingDouble).Offset
		return UDim2.new(0, size, 0, size)
	end),
	Icon = "rbxassetid://85543506317447",
	IconProperties = {
		ImageTransparency = UI.compute(function(use)
			return if use(UI.Scope.commandBarVisible) then 0 else 0.75
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

toggleCommandBar._instance:FindFirstChildOfClass("UIStroke"):Destroy()

local function dashboardToggle(button)
	if dashboard._instance.Visible then
		UI.Sound.Hover01:Play()
		UI.clearState("hover")
		UI.clearState("floating")
	else
		UI.Sound.Hover03:Play()
	end
	dashboard._instance.Visible = button.isSelected
end

local buttonEnabled = _K.Data.settings.dashboardButtonRank <= _K.Auth.getRank(UI.LocalPlayer.UserId)
local dashboardButton = TopbarPlus.new()
	:setName("KADashboardIcon")
	:setCaption("Kohl's Admin Dashboard")
	:setImage(10650723871)
	:setOrder(-1)
	:setEnabled(buttonEnabled)
	:bindEvent("toggled", dashboardToggle)
	:modifyTheme({ "Widget", "BorderSize", 0 })
local dashboardButtonIcon = dashboardButton:getInstance("IconImage")

UI.Scope.dashboardButton = dashboardButton

_K.client.hotkeys.dashboard.callback = function()
	if dashboardButton.isSelected then
		dashboardButton:deselect()
	else
		dashboardButton:select()
	end
end

dashboard._exitButton._instance.Activated:Connect(function()
	dashboardButton:deselect()
end)

task.spawn(function()
	local elapsed = 1
	while dashboard and dashboardButton and dashboard._instance do
		if not dashboard._instance.Visible then
			elapsed = 1
		end
		local alpha = math.abs(elapsed % 2 - 1) * 0.7
		dashboardButtonIcon.ImageTransparency = -(math.cos(math.pi * alpha) - 1) / 2
		elapsed += task.wait()
	end
end)

task.spawn(_K.log, `Dashboard loaded in {math.round((os.clock() - clockStart) * 1000)} ms`, "DEBUG")

return UI.Scope.dashboard
