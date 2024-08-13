local _K = require(script.Parent.Parent)
local UI = require(script.Parent.Parent.Flux.UI)

local Bans = require(script.Parent.Bans)
local Commands = require(script.Parent.Commands)
local Credit = require(script.Parent.Credit)
local Logs = require(script.Parent.Logs)
local Members = require(script.Parent.Members)
local Settings = require(script.Parent.Settings)

UI.Scope.dashboard.Bans = Bans.new(_K)
UI.Scope.dashboard.Members = Members.new(_K)
UI.Scope.dashboard.Logs = Logs.new(_K)
UI.Scope.dashboard.Commands = Commands.new(_K)
UI.Scope.dashboard.Settings = Settings.new(_K)
UI.Scope.dashboard.Credits = Credit.new(_K)

local dashboard = UI.new "Window" {
	Parent = UI.LayerDefault,
	Title = "Kohl's Admin Dashboard",
	Visible = false,

	UI.new "Tabs" {
		UI.Scope.dashboard.Commands,
		UI.Scope.dashboard.Bans,
		UI.Scope.dashboard.Members,
		UI.Scope.dashboard.Logs,
		UI.Scope.dashboard.Settings,
		UI.Scope.dashboard.Credits,
	},
}
UI.Scope.dashboard.Window = dashboard

-- TopbarStandard.Holders.Left
local holder = UI.PlayerGui:FindFirstChild("TopbarStandard")
if holder and holder:FindFirstChild("Holders") and holder.Holders:FindFirstChild("Left") then
	holder = holder.Holders.Left
end

local function dashboardToggle()
	dashboard._instance.Visible = not dashboard._instance.Visible
end
_K.client.hotkeys.dashboard.callback = dashboardToggle

local dasboardButtonPadding = UI.compute(function(use)
	return UDim.new(0, if use(UI.LegacyTopBar) then 6 else 12)
end)

UI.Scope.dashboard.Button = UI.new "TextButton" {
	Parent = holder or UI.TopBarFrame,
	LayoutOrder = -1,
	Name = "kDashboard",
	AnchorPoint = Vector2.new(0, 1),
	AutoButtonColor = true,
	BackgroundColor3 = Color3.new(),
	BackgroundTransparency = UI.compute(function(use)
		return if use(UI.LegacyTopBar) then 0.5 else 0.3
	end),
	BorderSizePixel = 0,
	Size = UI.compute(function(use)
		return if use(UI.LegacyTopBar) then UDim2.fromOffset(32, 32) else UDim2.fromOffset(44, 44)
	end),
	Position = UDim2.fromScale(0, 1),
	Text = "",
	TextTransparency = 1,

	UI.new "UICorner" {
		CornerRadius = UI.compute(function(use)
			return if use(UI.LegacyTopBar) then UDim.new(0, 9) else UDim.new(1, 0)
		end),
	},
	UI.new "UIPadding" {
		PaddingLeft = dasboardButtonPadding,
		PaddingRight = dasboardButtonPadding,
		PaddingTop = dasboardButtonPadding,
		PaddingBottom = dasboardButtonPadding,
	},

	UI.new "ImageLabel" {
		BackgroundTransparency = 1,
		Image = "rbxassetid://10650723871",
		Size = UDim2.fromScale(1, 1),
	},

	[UI.Event] = {
		Activated = dashboardToggle,
		MouseEnter = function()
			UI.Scope.dashboard.Button.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
		end,
		MouseLeave = function()
			UI.Scope.dashboard.Button.BackgroundColor3 = Color3.new()
		end,
	},
}

task.spawn(function()
	local elapsed = 1
	while dashboard and UI.Scope.dashboard.Button and dashboard._instance do
		if not dashboard._instance.Visible then
			elapsed = 1
		end
		local alpha = math.abs(elapsed % 2 - 1) * 0.7
		UI.Scope.dashboard.Button.ImageLabel.ImageTransparency = -(math.cos(math.pi * alpha) - 1) / 2
		elapsed += task.wait()
	end
end)

local dashCon
dashCon = UI.PlayerGui.ChildAdded:Connect(function(child)
	if child.Name == "TopbarStandard" and child:FindFirstChild("Holders") and child.Holders:FindFirstChild("Left") then
		dashCon:Disconnect()
		UI.Scope.dashboard.Button.Parent = child.Holders.Left
	end
end)

return UI.Scope.dashboard
