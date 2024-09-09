local _K = require(script.Parent.Parent)
local UI = require(script.Parent.Parent.Flux.UI)
local TopbarPlus = require(script.Parent.TopbarPlus)

local About = require(script.Parent.About)
local Bans = require(script.Parent.Bans)
local Commands = require(script.Parent.Commands)
local Logs = require(script.Parent.Logs)
local Members = require(script.Parent.Members)
local Settings = require(script.Parent.Settings)

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

local dashboard = UI.new "Window" {
	Parent = UI.LayerTopInset,
	Title = "Kohl's Admin Dashboard",
	Visible = false,

	UI.Scope.dashboard.Tabs,
}
UI.Scope.dashboard.Window = dashboard

-- TopbarStandard.Holders.Left
local holder = UI.PlayerGui:FindFirstChild("TopbarStandard")
if holder and holder:FindFirstChild("Holders") and holder.Holders:FindFirstChild("Left") then
	holder = holder.Holders.Left
end

local function dashboardToggle()
	if dashboard._instance.Visible then
		UI.Sound.Hover01:Play()
		UI.clearState("hover")
		UI.clearState("floating")
	else
		UI.Sound.Hover03:Play()
	end
	dashboard._instance.Visible = not dashboard._instance.Visible
end
_K.client.hotkeys.dashboard.callback = dashboardToggle

local dashboardButton = TopbarPlus.new()
	:setImage(10650723871)
	:bindEvent("toggled", dashboardToggle)
	:modifyTheme({ "Widget", "BorderSize", 0 })
local dashboardButtonIcon = dashboardButton:getInstance("IconImage")

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

return UI.Scope.dashboard
