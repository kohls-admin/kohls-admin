local _K = require(script.Parent)
local Flux = _K.Flux
local UI = _K.UI

_K.client = {
	CommandBar = require(script:WaitForChild("CommandBar")),
	TopbarPlus = require(script:WaitForChild("TopbarPlus")),
	UserFrame = require(script:WaitForChild("UserFrame")),
	Noclip = require(script.Noclip),

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
			UI.Theme[key]:set(value)
		end)
	end
end

_K.client.CommandBar:init(_K)

local Announce = require(script.Announce)
local Dashboard = require(script.Dashboard)
local Network = require(script.Network)

local function Chatted(message: string)
	local prefix = _K.playerPrefix[UI.LocalPlayer.UserId] or _K.Data.settings.prefix
	local commandStart = string.find(message, string.format('%s[^%s"`,%%s]', prefix, prefix))
	if not commandStart then
		-- checks for invalid prefix but valid command alias
		local test = " " .. string.lower(message)
		for alias in _K.Registry.commands do
			if string.find(test, `%s[^%s%w]{_K.Util.String.escapePattern(alias)}`) then
				task.spawn(_K.client.Notify, {
					Text = `<b>Invalid command prefix, use "{_K.Data.settings.prefix}"</b>`,
					TextColor3 = Color3.new(1, 0, 0),
					UserFrame = {},
					ExitButton = true,
					Sound = "Call_Leave",
				})
				break
			end
		end
		return
	end
	_K.Process.runCommands(_K, UI.LocalPlayer.UserId, string.sub(message, commandStart), true)
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
				for _, modifierKey in Enum.ModifierKey:GetEnumItems() do
					local isDown = input:IsModifierKeyDown(modifierKey)
					if isDown == not data.mods[modifierKey] then
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
local addons = script:FindFirstChild("Addons")
if addons then
	for _, addon in _K._addons:GetChildren() do
		if addon:IsA("ModuleScript") then
			task.spawn(function()
				require(addon)(_K)
			end)
		end
	end
end
