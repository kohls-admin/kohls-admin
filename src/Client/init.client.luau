local _K = require(script.Parent)
local Flux = _K.Flux
local UI = _K.UI

_K.Announce = require(script:WaitForChild("Announce"))
_K.Notify = require(script:WaitForChild("Notify"))

_K.client = {
	Character = require(script:WaitForChild("Character")),
	CommandBar = require(script:WaitForChild("CommandBar")),
	TopbarPlus = require(script:WaitForChild("TopbarPlus")),
	UserFrame = require(script:WaitForChild("UserFrame")),

	ready = false,
	hotkeys = {
		dashboard = { key = Flux.state(Enum.KeyCode.Quote), mods = {}, callback = nil },
	},
	settings = {},
}

_K.client.members = Flux.state(_K.Data.members)
_K.client.bans = Flux.state(_K.Data.bans)
_K.client.logs = Flux.state(_K.Data.logs)

-- Flux stateful settings
for key, value in _K.Data.settings do
	local state = _K.Flux.state(value)
	_K.client.settings[key] = state

	-- UI.Theme connection to theme settings
	if string.find(key, "theme", 1, true) == 1 then
		key = string.sub(key, 6)
		state:hook(function(value)
			UI.Theme[key]:set(value)
		end)
	end
end

_K.client.CommandBar:init(_K)
_K.client.Dashboard = require(script:WaitForChild("Dashboard")) -- relies on command bar
require(script:WaitForChild("Network"))
require(script:WaitForChild("GetKA"))

local chatCommandThrottle

local function Chatted(message: string)
	local prefix = _K.getCommandPrefix(UI.LocalPlayer.UserId)
	local commandStart = string.find(message, string.format('%s[^%s"`,%%s]', prefix, prefix))
	if not commandStart then
		-- check for optionalPrefix
		local directCommand = _K.Registry.commands[string.lower(message)]
		if directCommand and directCommand.optionalPrefix then
			commandStart = 1
			message = prefix .. message
		else
			-- checks for invalid prefix but valid command alias
			local test = " " .. string.lower(message)
			for alias in _K.Registry.commands do
				if string.find(test, `[;:]{_K.Util.String.escapePattern(alias)}`) then
					task.spawn(_K.Notify, {
						Text = `<b>Invalid command prefix, use "{_K.Data.settings.prefix}"</b>`,
						TextColor3 = Color3.new(1, 0, 0),
						UserFrame = {},
						Sound = "Call_Leave",
					})
					break
				end
			end
			return
		end
	end
	if not chatCommandThrottle then
		chatCommandThrottle = true
		_K.Process.runCommands(_K, UI.LocalPlayer.UserId, string.sub(message, commandStart))
		task.delay(0.2, function()
			chatCommandThrottle = nil
		end)
	end
end

if _K.Services.TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
	_K.Services.TextChatService.SendingMessage:Connect(function(textChatMessage: TextChatMessage)
		Chatted(_K.Util.String.unescapeRichText(textChatMessage.Text))
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

-- finally load client and shared addons
local addons = _K.script:WaitForChild("Addons")
if addons then
	for _, addon in addons:GetChildren() do
		if addon:IsA("ModuleScript") then
			task.spawn(function()
				require(addon)(_K)
			end)
		end
	end
end
