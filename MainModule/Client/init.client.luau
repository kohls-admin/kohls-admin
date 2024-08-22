local _K = require(script.Parent)
local Flux = _K.Flux
local UI = _K.UI

_K.client = {
	ready = false,
	hotkeys = {
		dashboard = { key = Flux.state(Enum.KeyCode.Quote), mods = {}, callback = nil },
	},
}

_K.client.Notify = require(script.Notify)

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
local Dashboard = require(script.Dashboard)
local Network = require(script.Network)
local Noclip = require(script.Noclip)

local function Chatted(message: string)
	local prefix = _K.playerPrefix[UI.LocalPlayer.UserId] or _K.Data.settings.prefix
	if string.find(message, string.format('^%s[^%s"`,%%s]', prefix, prefix)) ~= 1 then
		-- check for invalid prefix but valid command alias
		local found = string.find(message, "%s")
		local commandText = string.lower(string.sub(message, 2, if found then found - 1 else -1))
		for alias in _K.Registry.commands do
			if alias == commandText then
				_K.Services.StarterGui:SetCore("ChatMakeSystemMessage", {
					Text = `KA Error: Invalid command prefix, try "{_K.Data.settings.prefix}"`,
					Color = Color3.fromRGB(255, 0, 0),
				})
				break
			end
		end
		return
	end
	_K.Process.runCommands(_K, UI.LocalPlayer.UserId, message, true)
end

if _K.Services.TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
	_K.Services.TextChatService.SendingMessage:Connect(function(textChatMessage: TextChatMessage)
		Chatted(textChatMessage.Text)
	end)
else
	UI.LocalPlayer.Chatted:Connect(Chatted)
end

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
