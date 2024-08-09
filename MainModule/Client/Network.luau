local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local _K = require(script.Parent.Parent)
local UI = require(script.Parent.Parent.Flux.UI)
local Remote = require(script.Parent.Parent.Remote)
local Util = require(script.Parent.Parent.Util)

local Announce = require(script.Parent.Announce)
local Noclip = require(script.Parent.Noclip)
local Notify = require(script.Parent.Notify)
local UserFrame = require(script.Parent.UserFrame)

Remote.Announce.OnClientEvent:Connect(Announce)
Remote.Noclip.OnClientEvent:Connect(Noclip.noclip)
Remote.Notify.OnClientEvent:Connect(function(text: string, from: number)
	Notify({
		Text = text,
		Duration = 4 + 0.125 * #text,
		UserFrame = { from },
		ExitButton = true,
	})
end)

local requestingCommand = {}
Remote.RequestCommand.OnClientInvoke = function(from: Player, text: string)
	if requestingCommand[from.UserId] then
		return
	end
	requestingCommand[from.UserId] = true

	local actionSignal = Util.SignalGood.new()
	Notify({
		Text = `\t<font transparency="0.5">{text}</font>`,
		ActionText = "Permit this action?",
		Action = true,
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

_K.Remote.Ban.OnClientEvent:Connect(function(userId, ban)
	_K.Data.bans[userId] = ban
	UI.Scope.bans:set(_K.Data.bans)
end)

_K.Remote.Bans.OnClientEvent:Connect(function(bans)
	_K.Util.Table.merge(_K.Data.bans, bans)
	UI.Scope.bans:set(_K.Data.bans)
	-- Remote.Ban:FireClient(player, userId, { filtered, duration, fromUserId })
end)

_K.Remote.Members.OnClientEvent:Connect(function(members)
	_K.Util.Table.merge(_K.Data.members, members)
	UI.Scope.members:set(_K.Data.members)
end)

_K.Remote.Log.OnClientEvent:Connect(function(log)
	if not _K.client.ready then
		return
	end
	-- TODO: PERF: add to sorted list and filtered list directly
	table.insert(_K.Data.logs, {
		text = log[1],
		level = log[2],
		time = log[3],
		from = log[4],
	})
	if #_K.Data.logs > 1e5 then
		table.remove(_K.Data.logs, 1)
	end
	UI.Scope.dashboard.Logs:updateList()
end)

_K.Remote.Logs.OnClientEvent:Connect(function(logs)
	local dataLogs = _K.Data.logs

	table.clear(dataLogs)
	for k, log in logs do
		dataLogs[k] = log
	end

	UI.Scope.logs:set(_K.Data.logs)
	UI.Scope.dashboard.Logs:updateList()
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
initCon = _K.Remote.Init.OnClientEvent:Connect(function(auth, bans, logs, members, settings)
	initCon:Disconnect()
	_K.Util.Table.deepMerge(_K.Auth, auth)
	_K.Util.Table.merge(_K.Data.members, members)
	UI.Scope.members:set(_K.Data.members)

	_K.Util.Table.merge(_K.Data.bans, bans)
	UI.Scope.bans:set(_K.Data.bans)

	for k, log in logs do
		table.insert(_K.Data.logs, {
			text = log[1],
			level = log[2],
			time = log[3],
			from = log[4],
		})
		if #_K.Data.logs > 100_000 then
			table.remove(_K.Data.logs, 1)
		end
	end
	UI.Scope.logs:set(_K.Data.logs)
	UI.Scope.dashboard.Logs:updateList()

	-- need to improve networking performance!
	for key, value in settings do
		value = UI.peek(value)
		_K.Data.settings[key] = value
		UI.Scope.settings[key]:set(value)
	end

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
			roleText ..= _K.Data.roles[role].name .. ", "
		end
	end
	roleText ..= _K.Data.defaultRole.name

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
		`<b>Commands</b>   <font color="#0f0">{commandBarKeyText} {commandBarKeyRaw}</font>`,
		`<b>Dashboard</b>  <font color="#0f0">{dashboardKeyText} {dashboardKeyRaw}</font>`,
		`<b>Roles</b>\t  <sc>{roleText}</sc>\n`,
		`<b>Place</b>        <font transparency="0.5">{game.Name}</font>`,
		`<b>Server Age</b>   <font transparency="0.5">{_K.Util.ReadableTime(workspace.DistributedGameTime)}</font>`,
		`<b>Server Time</b>  <font transparency="0.5">{os.date("%X", _K.Data.logs[#_K.Data.logs].time)}</font></font>`,
	}

	-- TODO: settings flag for hiding join notification for rank 0
	Notify({
		Text = table.concat(lines, "\n"),
		Duration = 30,
		UserFrame = {},
		ExitButton = true,
	})

	_K.client.ready = true
end)

return true
