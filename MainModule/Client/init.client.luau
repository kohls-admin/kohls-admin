local _K = require(script.Parent)
local Flux = require(script.Parent.Flux)
local UI = require(script.Parent.Flux.UI).registerChildren()
local Announce = require(script.Announce)
local Bans = require(script.Bans)
local Logs = require(script.Logs)
local Members = require(script.Members)
local Noclip = require(script.Noclip)
local Commands = require(script.Commands)
local Settings = require(script.Settings)
local Credit = require(script.Credit)

_K.client = {}
_K.client.UI = UI
_K.client.settings = {}
_K.client.hotkeys = {}

local CommandBar = require(script.CommandBar)
CommandBar:init(_K)

_K.Remote.Announce.OnClientEvent:Connect(Announce)
_K.Remote.Noclip.OnClientEvent:Connect(Noclip.noclip)

local lastCameraCFrame
_K.Remote.Refresh.OnClientEvent:Connect(function()
	if lastCameraCFrame then
		workspace.CurrentCamera:GetPropertyChangedSignal("CFrame"):Wait()
		workspace.CurrentCamera.CFrame = lastCameraCFrame
	end
end)

UI.LocalPlayer.CharacterRemoving:Connect(function()
	lastCameraCFrame = workspace.CurrentCamera.CFrame
end)

-- stateful hotkeys
for _, data in _K.client.hotkeys do
	data.key = Flux.state(data.key)
end

_K.Services.UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
	if gameProcessedEvent then
		return
	end
	if input.UserInputType == Enum.UserInputType.Keyboard then
		for keyName, data in _K.client.hotkeys do
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

UI.Scope.members = Flux.state(_K.Auth.members)
UI.Scope.bans = Flux.state(_K.bans)
UI.Scope.logs = Flux.state(_K.logs)
UI.Scope.settings = Flux.state(_K.settings)

local dashboardBans = Bans.new(_K)
local dashboardMembers = Members.new(_K)
local dashboardLogs = Logs.new(_K)
local dashboardCommands = Commands.new(_K)
local dashboardSettings = Settings.new(_K)
local dashboardCredits = Credit.new(_K)

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
		dashboardCredits,
		-- UI.new "TextLabel" {
		-- 	Name = "Credit",
		-- 	BackgroundTransparency = 1,
		-- 	Font = UI.Theme.Font,
		-- 	TextSize = UI.Theme.FontSize,
		-- 	TextColor3 = UI.Theme.PrimaryText,
		-- 	Size = UDim2.new(1, 0, 0, 32),
		-- 	Text = "Kohl's Admin (Created by Scripth)",
		-- },
	},
}
-- TopbarStandard.Holders.Left
local holder = UI.PlayerGui:FindFirstChild("TopbarStandard")
if holder and holder:FindFirstChild("Holders") and holder.Holders:FindFirstChild("Left") then
	holder = holder.Holders.Left
end

local dasboardButtonPadding = UI.compute(function(use)
	return UDim.new(0, if use(UI.LegacyTopBar) then 6 else 12)
end)
local dashboardButton
dashboardButton = UI.new "TextButton" {
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
	local elapsed = 1
	while dashboard and dashboardButton and dashboard._instance do
		if not dashboard._instance.Visible then
			elapsed = 1
		end
		local alpha = math.abs(elapsed % 2 - 1) * 0.7
		dashboardButton.ImageLabel.ImageTransparency = -(math.cos(math.pi * alpha) - 1) / 2
		elapsed += task.wait()
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
initCon = _K.Remote.Init.OnClientEvent:Connect(function(auth, bans, logs, settings)
	initCon:Disconnect()
	_K.Util.mergeTable(_K.Auth, auth)
	UI.Scope.members:set(_K.Auth.members)

	_K.Util.mergeTable(_K.bans, bans)
	UI.Scope.bans:set(_K.bans)

	for k, log in logs do
		table.insert(_K.logs, {
			text = log[1],
			level = log[2],
			time = log[3],
			from = log[4],
		})
		if #_K.logs > 100_000 then
			table.remove(_K.logs, 1)
		end
	end
	UI.Scope.logs:set(_K.logs)

	-- need to update all the settings values somehow xD
	-- need to improve networking performance!
	for key, value in settings do
		_K.settings[key]:set(UI.peek(value))
	end
	dashboardLogs:updateList()
end)

_K.Remote.Log.OnClientEvent:Connect(function(log)
	-- TODO: PERF: add to sorted list and filtered list directly
	table.insert(_K.logs, {
		text = log[1],
		level = log[2],
		time = log[3],
		from = log[4],
	})
	if #_K.logs > 1e5 then
		table.remove(_K.logs, 1)
	end
	dashboardLogs:updateList()
end)

_K.Remote.Init:FireServer()

local loremIpsum = {
	"Lorem",
	"ipsum",
	"dolor",
	"sit",
	"amet",
	"consectetur",
	"adipiscing",
	"elit",
	"sed",
	"do",
	"eiusmod",
	"tempor",
	"incididunt",
	"ut",
	"labore",
	"et",
	"dolore",
	"magna",
	"aliqua",
	"Ut",
	"enim",
	"ad",
	"minim",
	"veniam",
	"quis",
	"nostrud",
	"exercitation",
	"ullamco",
	"laboris",
	"nisi",
	"ut",
	"aliquip",
	"ex",
	"ea",
	"commodo",
	"consequat",
	"Duis",
	"aute",
	"irure",
	"dolor",
	"in",
	"reprehenderit",
	"in",
	"voluptate",
	"velit",
	"esse",
	"cillum",
	"dolore",
	"eu",
	"fugiat",
	"nulla",
	"pariatur",
	"Excepteur",
	"sint",
	"occaecat",
	"cupidatat",
	"non",
	"proident",
	"sunt",
	"in",
	"culpa",
	"qui",
	"officia",
	"deserunt",
	"mollit",
	"anim",
	"id",
	"est",
	"laborum",
}

local function generateLoremIpsum(wordCount: number): string
	local result = {}
	for i = 1, wordCount do
		local randomIndex = math.random(1, #loremIpsum)
		table.insert(result, loremIpsum[randomIndex])
	end
	return table.concat(result, " ")
end

local lines = {}
for i = 1, 100 do
	table.insert(lines, generateLoremIpsum(math.random(16, 32)))
end

local levels = {
	"DEBUG",
	"INFO",
	"WARN",
	"ERROR",
	"CHAT",
	"COMMAND",
	"JOIN",
	"LEAVE",
	"KILL",
	"DEATH",
	"DAMAGE",
	"PURCHASE",
}

_K.Util.deferTimerReset()
for i = 1, 1_000_000 do
	_K.logger:log("log #" .. i .. ": " .. lines[math.random(1, 100)], levels[math.random(1, #levels)])
	_K.Util.deferWait()
end

dashboardLogs:updateList()
