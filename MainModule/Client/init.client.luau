local _K = require(script.Parent)
local Flux = require(script.Parent.Flux)
local UI = require(script.Parent.Flux.UI).registerChildren()

_K.client = { ready = false }
_K.client.UI = UI
_K.client.hotkeys = {
	dashboard = { key = Flux.state(Enum.KeyCode.Quote), mods = {}, callback = nil },
}

UI.Scope.members = Flux.state(_K.Data.members)
UI.Scope.bans = Flux.state(_K.Data.bans)
UI.Scope.logs = Flux.state(_K.Data.logs)

-- Flux stateful settings
for key, value in _K.Data.settings do
	local state = _K.Flux.state(value)
	UI.Scope.settings[key] = state

	-- UI.Theme connection to theme settings
	if string.find(key, "theme", 1, true) == 1 then
		key = string.sub(key, 6)
		state:hook(function(value)
			if key == "CornerRadius" or key == "Padding" then
				value = UDim.new(0, value)
			end
			UI.Theme[key]:set(value)
		end)
	end
end

local CommandBar = require(script.CommandBar)
CommandBar:init(_K)

local Announce = require(script.Announce)
local Bans = require(script.Bans)
local Commands = require(script.Commands)
local Credit = require(script.Credit)
local Dashboard = require(script.Dashboard)
local Logs = require(script.Logs)
local Members = require(script.Members)
local Network = require(script.Network)
local Noclip = require(script.Noclip)
local Notify = require(script.Notify)
local Settings = require(script.Settings)
local UserFrame = require(script.UserFrame)

UI.LocalPlayer.Chatted:Connect(function(message: string)
	_K.Process.runCommands(_K, UI.LocalPlayer.UserId, message)
end)

_K.Services.UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
	if gameProcessedEvent then
		return
	end
	if input.UserInputType == Enum.UserInputType.Keyboard then
		for keyName, data in _K.client.hotkeys do
			if
				data.callback
				and (
					input.KeyCode == data.key._value
					or (type(data.key._value) == "table" and table.find(data.key._value, input.KeyCode))
				)
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

_K.Remote.Init:FireServer()

-- finally load client addons
if _K._addons then
	for _, addon in _K._addons:GetChildren() do
		if addon:IsA("ModuleScript") then
			task.spawn(function()
				require(addon)(_K)
			end)
		end
	end
end
