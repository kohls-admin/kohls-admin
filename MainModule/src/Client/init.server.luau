-- NOTE: CLIENT ENTRY POINT
-- NOT A SERVER SCRIPT, HAS CLIENT RUNCONTEXT
local _K = require(script.Parent)
local Flux = require(script.Parent.Flux)
local UI = require(script.Parent.Flux.UI).registerChildren()
local CommandBar = require(script.CommandBar)
local Bans = require(script.Bans)
local Logs = require(script.Logs)
local Members = require(script.Members)
local Commands = require(script.Commands)
local Settings = require(script.Settings)

_K.UI = UI
_K.clientSettings = {}
_K.hotkeys = {}

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

local _uiTestWindow = UI.new "Window" {
	Parent = UI.LayerDefault,
	Title = "Dashboard",

	UI.new "Tabs" {
		dashboardMembers,
		dashboardBans,
		dashboardLogs,
		dashboardCommands,
		dashboardSettings,
		UI.new "Frame" {},
		UI.new "Frame" {},
		UI.new "Frame" {},
		UI.new "Frame" {},
		UI.new "Frame" {},
		UI.new "Frame" {},
		UI.new "Frame" {},
		UI.new "Frame" {},
		UI.new "Frame" {},
		UI.new "Frame" {},
	},
}

local initCon
initCon = _K.Remote "Init".OnClientEvent:Connect(function(auth, bans, logs, settings)
	initCon:Disconnect()
	_K.Auth = auth
	_K.memberState:set(auth.members)

	_K.bans = bans
	_K.banState:set(bans)
	print("init bans", bans)

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
