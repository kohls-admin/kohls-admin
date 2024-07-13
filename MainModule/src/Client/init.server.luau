-- NOTE: CLIENT ENTRY POINT
-- NOT A SERVER SCRIPT, HAS CLIENT RUNCONTEXT
local _K = require(script.Parent)
local Flux = require(script.Parent.Flux)
local UI = require(script.Parent.Flux.UI).registerChildren()
local Bans = require(script.Bans)
local Logs = require(script.Logs)
local Members = require(script.Members)
local Commands = require(script.Commands)
local Settings = require(script.Settings)

_K.UI = UI
_K.clientSettings = {}
_K.hotkeys = {}

local CommandBar = require(script.CommandBar)
CommandBar:init(_K)

-- stateful hotkeys
for _, data in _K.hotkeys do
	data.key = Flux.state(data.key)
end

_K.Services.UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
	if gameProcessedEvent then
		return
	end
	if input.UserInputType == Enum.UserInputType.Keyboard then
		for keyName, data in _K.hotkeys do
			if
				input.KeyCode == data.key._value
				or (type(data.key._value) == "table" and table.find(data.key._value, input.KeyCode))
			then
				local missingMod = false
				for mod, value in data.mods do
					if not value then
						continue
					end
					if not input:IsModifierKeyDown(Enum.ModifierKey[mod]) then
						missingMod = true
						break
					end
				end
				if missingMod then
					return
				end
				task.defer(data.callback)
			end
		end
	end
end)

_K.memberState = Flux.state(_K.Auth.members)
_K.banState = Flux.state(_K.bans)
_K.logState = Flux.state(_K.logs)
_K.settingState = Flux.state(_K.settings)

local dashboardBans = Bans.new(_K)
local dashboardMembers = Members.new(_K)
local dashboardLogs = Logs.new(_K)
local dashboardCommands = Commands.new(_K)
local dashboardSettings = Settings.new(_K)

local dashboard = UI.new "Window" {
	Parent = UI.LayerDefault,
	Title = "Kohl's Admin Dashboard",
	Visible = false,

	UI.new "Tabs" {
		dashboardCommands,
		dashboardBans,
		dashboardMembers,
		dashboardLogs,
		dashboardSettings,
	},
}
-- TopbarStandard.Holders.Left
local holder = UI.PlayerGui:FindFirstChild("TopbarStandard")
if holder and holder:FindFirstChild("Holders") and holder.Holders:FindFirstChild("Left") then
	holder = holder.Holders.Left
end

local dashboardButton
dashboardButton = UI.new "TextButton" {
	Parent = holder or UI.LayerTop,
	LayoutOrder = -1,
	Name = "kDashboard",
	AutoButtonColor = true,
	BackgroundColor3 = Color3.new(),
	BackgroundTransparency = 0.3,
	BorderSizePixel = 0,
	Size = UDim2.fromOffset(44, 44),
	Position = UDim2.fromOffset(172, 12),
	Text = "",
	TextTransparency = 1,

	UI.new "UICorner" {
		CornerRadius = UDim.new(1, 0),
	},
	UI.new "UIPadding" {
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 12),
		PaddingTop = UDim.new(0, 12),
		PaddingBottom = UDim.new(0, 12),
	},

	UI.new "ImageLabel" {
		BackgroundTransparency = 1,
		Image = "rbxassetid://10650723871",
		Size = UDim2.fromScale(1, 1),
	},

	[UI.Event] = {
		Activated = function()
			dashboard._instance.Visible = not dashboard._instance.Visible
		end,
		MouseEnter = function()
			dashboardButton.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
		end,
		MouseLeave = function()
			dashboardButton.BackgroundColor3 = Color3.new()
		end,
	},
}

task.spawn(function()
	local white = Color3.new(1, 1, 1)
	while dashboard and dashboard._instance and dashboardButton do
		dashboardButton.ImageLabel.ImageColor3 = if dashboard._instance.Visible
			then Color3.fromHSV((tick() / 10) % 1, 1, 1)
			else white
		task.wait()
	end
end)

local dashCon
dashCon = UI.PlayerGui.ChildAdded:Connect(function(child)
	if child.Name == "TopbarStandard" and child:FindFirstChild("Holders") and child.Holders:FindFirstChild("Left") then
		dashCon:Disconnect()
		dashboardButton.Parent = child.Holders.Left
	end
end)

local initCon
initCon = _K.Remote "Init".OnClientEvent:Connect(function(auth, bans, logs, settings)
	initCon:Disconnect()
	_K.Auth = auth
	_K.memberState:set(auth.members)

	_K.bans = bans
	_K.banState:set(bans)

	_K.logs = logs
	_K.logState:set(logs)

	-- need to update all the settings values somehow xD
	for key, value in settings do
		_K.settings[key]:set(UI.peek(value))
	end
	dashboardLogs:updateList()
end)

_K.Remote "Log".OnClientEvent:Connect(function(log)
	-- TODO: PERF: add to sorted list and filtered list directly
	local raw = UI.peek(_K.logs)
	table.insert(raw, log)
	if #raw > 1e5 then
		table.remove(raw, 1)
	end
	dashboardLogs:updateList()
end)

_K.Remote "Init":FireServer()
