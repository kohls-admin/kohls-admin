local Players = game:GetService("Players")

local _K = require(script.Parent.Parent)
local UI = require(script.Parent.UI)
local Remote = require(script.Parent.Parent.Remote)
local Util = require(script.Parent.Parent.Util)

local Announce = require(script.Parent.Announce)
local Notify = require(script.Parent.Notify)
local UserFrame = require(script.Parent.UserFrame)

local function updateInterfaceAuth()
	-- TODO: recheck visibility for all restricted UIs
	local buttonEnabled = _K.Data.settings.dashboardButtonRank
		and _K.Data.settings.dashboardButtonRank <= _K.Auth.getRank(UI.LocalPlayer.UserId)
	UI.Scope.dashboardButton:setEnabled(buttonEnabled)

	UI.Scope.dashboard.Bans._instance.Visible = _K.Auth.hasCommand(UI.LocalPlayer.UserId, "bans")
	UI.Scope.dashboard.Members._instance.Visible = _K.Auth.hasCommand(UI.LocalPlayer.UserId, "members")
	UI.Scope.dashboard.Settings.Visible = _K.Auth.hasCommand(UI.LocalPlayer.UserId, "settings")

	for _, command in _K.Registry.commands do
		command.LocalPlayerAuthorized = _K.Auth.hasCommand(UI.LocalPlayer.UserId, command)
	end
	UI.Scope.dashboard.Commands:updateList()
end
UI.Scope.updateInterfaceAuth = updateInterfaceAuth

Remote.Announce.OnClientEvent:Connect(Announce)
Remote.Notify.OnClientEvent:Connect(Notify)

Remote.SetCore.OnClientEvent:Connect(function(parameter: string, value: any)
	Util.Services.StarterGui:SetCore(parameter, value)
end)

local requestingCommand = {}
Remote.RequestCommand.OnClientInvoke = function(from: Player, text: string)
	if requestingCommand[from.UserId] then
		return
	end
	requestingCommand[from.UserId] = true

	local actionSignal = Util.Signal.new()
	Notify({
		Text = `\t<font transparency="0.5">{text}</font>`,
		ActionText = "Permit this action?",
		Action = true,
		ExitButton = false,
		LeftAction = true,
		RightAction = true,
		Duration = -1,

		UserFrame(from.UserId, from.DisplayName),

		[UI.Hook] = {
			Action = function(v)
				actionSignal:Fire(v)
			end,
		},
	})

	local action = actionSignal:Wait() == true
	requestingCommand[from.UserId] = nil
	return action
end

-- general data replication

Remote.Ban.OnClientEvent:Connect(function(userId, ban)
	_K.Data.bans[userId] = ban
	UI.Scope.bans:set(_K.Data.bans)
end)

Remote.Bans.OnClientEvent:Connect(function(bans)
	_K.Util.Table.merge(_K.Data.bans, bans)
	UI.Scope.bans:set(_K.Data.bans)
	-- Remote.Ban:FireClient(player, userId, { filtered, duration, fromUserId })
end)

Remote.Member.OnClientEvent:Connect(function(userId, member)
	_K.Data.members[userId] = member
	UI.Scope.members:set(_K.Data.members)
	updateInterfaceAuth()
end)

Remote.Members.OnClientEvent:Connect(function(members)
	_K.Util.Table.merge(_K.Data.members, members)
	UI.Scope.members:set(_K.Data.members)
	updateInterfaceAuth()
end)

Remote.Log.OnClientEvent:Connect(function(log)
	if not _K.client.ready then
		return
	end
	-- TODO: PERF: add to sorted list and filtered list directly
	table.insert(_K.Data.logs, log)
	if #_K.Data.logs > 1e5 then
		table.remove(_K.Data.logs, 1)
	end
	task.defer(UI.Scope.dashboard.Logs.updateList, UI.Scope.dashboard.Logs)
end)

Remote.Logs.OnClientEvent:Connect(function(logs)
	if not _K.client.ready then
		return
	end
	-- this sometimes updates before Logs updateList is ready to call?
	table.move(logs, 1, #logs, #_K.Data.logs + 1, _K.Data.logs)
	table.sort(_K.Data.logs, _K.Data.sortTime)
	task.defer(UI.Scope.dashboard.Logs.updateList, UI.Scope.dashboard.Logs)
end)

Remote.Settings.OnClientEvent:Connect(function(settings)
	for key, value in settings do
		value = UI.peek(value)
		_K.Data.settings[key] = value
		UI.Scope.settings[key]:set(value)
		if string.find(key, "theme", 1, true) == 1 then
			local themeKey = string.sub(key, 6)
			UI.Theme[themeKey]:set(value)
		end
	end
	if settings.dashboardButtonRank ~= nil or settings.freeAdmin ~= nil then
		updateInterfaceAuth()
	end
end)

Remote.Role.OnClientEvent:Connect(function(role, roleData)
	_K.Data.roles[role] = roleData
	updateInterfaceAuth()
end)

Remote.Roles.OnClientEvent:Connect(function(roles)
	_K.Util.Table.merge(_K.Data.roles, roles)
	updateInterfaceAuth()
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

local initCon
initCon = Remote.Init.OnClientEvent:Connect(function(members, settings, bans, logs, roles)
	initCon:Disconnect()
	_K.Util.Table.merge(_K.Data.members, members)
	UI.Scope.members:set(_K.Data.members)

	-- need to improve networking performance!
	for key, value in settings do
		value = UI.peek(value)
		_K.Data.settings[key] = value
		UI.Scope.settings[key]:set(value)
	end

	if bans then
		_K.Util.Table.merge(_K.Data.bans, bans)
		UI.Scope.bans:set(_K.Data.bans)
	end

	if logs then
		table.move(logs, 1, #logs, #_K.Data.logs + 1, _K.Data.logs)
		table.sort(_K.Data.logs, _K.Data.sortTime)
		task.defer(UI.Scope.dashboard.Logs.updateList, UI.Scope.dashboard.Logs)
	end

	_K.Util.Table.merge(_K.Data.roles, roles)

	updateInterfaceAuth()

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
		`<b>Prefix</b>     <font color="#0f0">{UI.peek(UI.Scope.settings.prefix)}</font>`,
		`<b>Commands</b>   <font color="#0f0">{commandBarKeyText} {commandBarKeyRaw}</font>`,
		`<b>Dashboard</b>  <font color="#0f0">{dashboardKeyText} {dashboardKeyRaw}</font>`,
		`<b>Roles</b>\t  <sc>{roleText}</sc>\n`,
		`<b>Place</b>        <font transparency="0.5">{game.Name}</font>`,
		`<b>Server Age</b>   <font transparency="0.5">{_K.Util.ReadableTime(workspace.DistributedGameTime)}</font>`,
		`<b>Server Time</b>  <font transparency="0.5">{os.date("%X", workspace:GetServerTimeNow())}</font></font>`,
	}

	if
		_K.Data.settings.joinNotificationRank
		and _K.Auth.getRank(Players.LocalPlayer.UserId) >= _K.Data.settings.joinNotificationRank
	then
		Notify({
			Text = table.concat(lines, "\n"),
			Duration = 30,
			UserFrame = {},
			Sound = "Hello",
		})
	end

	_K.client.ready = true
end)

return true
