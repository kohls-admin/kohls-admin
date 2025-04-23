local _K = require(script.Parent)
local UI = _K.UI

_K.Announce = require(script:WaitForChild("Announce"))
_K.Notify = require(script:WaitForChild("Notify"))

_K.client = {
	Character = require(script:WaitForChild("Character")),
	TopbarPlus = require(script:WaitForChild("TopbarPlus")),
	UserFrame = require(script:WaitForChild("UserFrame")),

	bans = _K.Flux.state(_K.Data.bans),
	logs = _K.Flux.state(_K.Data.logs),
	members = _K.Flux.state(_K.Data.members),

	ready = false,
	hotkeys = {
		dashboard = { key = _K.Flux.state(Enum.KeyCode.Quote), mods = {}, callback = nil },
	},
	settings = {},
}

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

-- initial remote connection
local greetings = {
	morning = {
		"Seize the day, %s! Make it yours.",
		"Wake up and chase your dreams, %s!",
		"Rise and grind, %s! Let's make this day epic!",
		"Wake up, %s! It's time to level up your skills.",
	},
	afternoon = {
		"Good afternoon, %s! You've got this.",
		"How's your Roblox adventure going, %s? Hope it's awesome!",
		"Howdy, %s! Let's make the afternoon awesome!",
		"Afternoon, %s! Remember to take breaks and have some fun!",
	},
	evening = {
		"Relax and unwind, %s. You've earned it.",
		"You did great today, %s! Be proud of yourself.",
		"Good evening, %s! You've got this.",
		"Evenin', %s! It's time to relax and take a break.",
	},
	night = {
		"Dream big dreams, %s. This night is yours.",
		'Early bird gets the <font color="#0f0">Robux</font>, %s. Make sure to get some rest!',
		"Even in the darkest hours, %s, remember that a new dawn is coming.",
		"Burning the midnight oil, %s?",
		"Still up, %s? Don't forget to rest!",
	},
}

_K.Remote.Init.OnClientEvent:Once(function(bans, logs, members, roles, settings)
	-- need to improve networking performance!
	if bans then
		_K.Util.Table.merge(_K.Data.bans, bans)
		_K.client.bans:set(_K.Data.bans)
	end

	if logs then
		table.move(logs, 1, #logs, #_K.Data.logs + 1, _K.Data.logs)
		table.sort(_K.Data.logs, _K.Data.sortTime)
	end

	_K.Util.Table.merge(_K.Data.members, members)
	_K.client.members:set(_K.Data.members)

	_K.Data.roles = roles

	for key, value in settings do
		value = UI.peek(value)
		_K.Data.settings[key] = value
		_K.client.settings[key]:set(value)
	end

	_K.client.CommandBar = require(script:WaitForChild("CommandBar"))
	_K.client.CommandBar:init(_K)
	_K.client.Dashboard = require(script:WaitForChild("Dashboard")) -- relies on command bar
	require(script:WaitForChild("GetKA"))
	require(script:WaitForChild("Network"))

	_K.client.updateInterfaceAuth()

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

	_K.client.ready = true
	_K.Hook.init:Fire()

	-- join notification

	local greeting
	local hour = tonumber(os.date("%H")) -- Get the current hour (0-23)
	if hour >= 5 and hour < 12 then
		greeting = greetings.morning
	elseif hour >= 12 and hour < 17 then
		greeting = greetings.afternoon
	elseif hour >= 17 and hour < 22 then
		greeting = greetings.evening
	else
		greeting = greetings.night
	end
	greeting = greeting[Random.new(tick()):NextInteger(1, #greeting)]
	greeting = string.format(greeting, `<b>{UI.LocalPlayer.DisplayName}</b>`)

	local member = _K.Data.members[tostring(UI.LocalPlayer.UserId)]
	local roleText = ""
	if member and member.roles then
		for _, role in member.roles do
			if _K.Data.roles[role] then
				roleText ..= _K.Data.roles[role].name .. ", "
			end
		end
	end
	roleText ..= _K.Data.roles.default.name

	local commandBarKey = _K.client.hotkeys.commandBar
	local commandBarKeyRaw = UI.UserInputService:GetStringForKeyCode(commandBarKey.key._value)
	local commandBarKeyText =
		`{commandBarKey.mods.Shift and "Shift+" or ""}{commandBarKey.mods.Alt and "Alt+" or ""}{commandBarKey.key._value.Name}`

	local dashboardKey = _K.client.hotkeys.dashboard
	local dashboardKeyRaw = UI.UserInputService:GetStringForKeyCode(dashboardKey.key._value)
	local dashboardKeyText =
		`{dashboardKey.mods.Shift and "Shift+" or ""}{dashboardKey.mods.Alt and "Alt+" or ""}{dashboardKey.key._value.Name}`

	local lines = {
		`<font family="{UI.Theme.FontMono._value.Name}">{greeting}\n`,
		`<b>Prefix</b>     <font color="#0f0">{UI.peek(_K.client.settings.prefix)}</font>`,
		`<b>Commands</b>   <font color="#0f0">{commandBarKeyText} {commandBarKeyRaw}</font>`,
		`<b>Dashboard</b>  <font color="#0f0">{dashboardKeyText} {dashboardKeyRaw}</font>`,
		`<b>Roles</b>\t  <sc>{roleText}</sc>\n`,
		`<b>Place</b>        <font transparency="0.5">{game.Name}</font>`,
		`<b>Server Age</b>   <font transparency="0.5">{_K.Util.ReadableTime(workspace.DistributedGameTime)}</font>`,
		`<b>Server Time</b>  <font transparency="0.5">{os.date("%X", workspace:GetServerTimeNow())}</font></font>`,
	}

	if
		_K.Data.settings.joinNotificationRank
		and _K.Auth.getRank(_K.Util.Services.Players.LocalPlayer.UserId) >= _K.Data.settings.joinNotificationRank
	then
		_K.Notify({
			Text = table.concat(lines, "\n"),
			Duration = 30,
			UserFrame = {},
			Sound = "Hello",
		})
	end
end)

_K.Remote.Init:FireServer()
