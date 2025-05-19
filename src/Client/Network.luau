local _K = require(script.Parent.Parent)
local UI = _K.UI

function _K.client.updateInterfaceAuth()
	-- TODO: recheck visibility for all restricted UIs
	local userRank = _K.Auth.getRank(UI.LocalPlayer.UserId)
	_K.client.rank:set(userRank)

	local commandBarRank = _K.Data.settings.commandBarRank
	local dashboardRank = _K.Data.settings.dashboardRank
	local dashboardButtonRank = _K.Data.settings.dashboardButtonRank

	if commandBarRank == nil then
		commandBarRank = 0
	end
	if dashboardRank == nil then
		dashboardRank = 0
	end
	if dashboardButtonRank == nil then
		dashboardButtonRank = 0
	end

	_K.client.toggleCommandBar._instance.Visible = commandBarRank and userRank >= commandBarRank
	_K.client.dashboardEnabled = dashboardRank and userRank >= dashboardRank
	_K.client.dashboardButton:setEnabled(dashboardButtonRank and userRank >= dashboardButtonRank)

	if not _K.client.dashboardEnabled then
		_K.client.dashboard.Window._instance.Visible = false
	end

	_K.client.dashboard.Bans._instance.Visible = _K.Auth.hasCommand(UI.LocalPlayer.UserId, "bans")
	_K.client.dashboard.Logs._instance.Visible = _K.Auth.hasPermission(UI.LocalPlayer.UserId, "serverlogs")
	_K.client.dashboard.Members._instance.Visible = _K.Auth.hasCommand(UI.LocalPlayer.UserId, "members")
	_K.client.dashboard.Settings.Visible = _K.Auth.hasCommand(UI.LocalPlayer.UserId, "settings")

	for _, command in _K.Registry.commands do
		command.LocalPlayerAuthorized = _K.Auth.hasCommand(UI.LocalPlayer.UserId, command)
	end
	_K.client.dashboard.Commands:updateList()
	_K.client.CommandBar.updateCompletionData()
end

_K.Remote.Announce.OnClientEvent:Connect(_K.Announce)
_K.Remote.Notify.OnClientEvent:Connect(_K.Notify)

_K.Remote.SetCore.OnClientEvent:Connect(function(parameter: string, value: any)
	_K.Util.Services.StarterGui:SetCore(parameter, value)
end)

local requestingCommand = {}
_K.Remote.RequestCommand.OnClientInvoke = function(from: Player, text: string)
	if requestingCommand[from.UserId] then
		return
	end
	requestingCommand[from.UserId] = true

	local actionSignal = _K.Util.Signal.new()
	_K.Notify({
		Text = `\t<font transparency="0.5">{text}</font>`,
		ActionText = "Permit this action?",
		Action = true,
		ExitButton = false,
		LeftAction = true,
		RightAction = true,
		Modal = true,
		Duration = -1,

		_K.client.UserFrame(from.UserId, from.DisplayName),

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
	_K.client.bans:set(_K.Data.bans)
end)

_K.Remote.Bans.OnClientEvent:Connect(function(bans)
	_K.Data.bans = bans
	_K.client.bans:set(_K.Data.bans)
end)

_K.Remote.Member.OnClientEvent:Connect(function(userId, member)
	_K.Data.members[userId] = member
	_K.client.members:set(_K.Data.members)
	_K.client.updateInterfaceAuth()
end)

_K.Remote.Members.OnClientEvent:Connect(function(members)
	_K.Data.members = members
	_K.client.members:set(_K.Data.members)
	_K.client.updateInterfaceAuth()
end)

_K.Remote.Log.OnClientEvent:Connect(function(log)
	if not _K.client.ready then
		return
	end
	-- TODO: PERF: add to sorted list and filtered list directly
	table.insert(_K.Data.logs, log)

	_K.Util.Defer.reset()
	while #_K.Data.logs > 1e5 do
		table.remove(_K.Data.logs, 1)
		_K.Util.Defer.wait()
	end

	task.defer(_K.client.dashboard.Logs.updateList, _K.client.dashboard.Logs)
end)

_K.Remote.Logs.OnClientEvent:Connect(function(rawLogs)
	if not _K.client.ready then
		return
	end

	_K.Util.Defer.reset()

	local logs = {}
	for _, log in rawLogs do
		_K.Util.Defer.wait()
		log.text, log.level, log.time, log.from, log.name = unpack(log)
		log[1], log[2], log[3], log[4], log[5] = nil

		local exists
		for _, existingLog in _K.Data.logs do
			if
				existingLog.time == log.time
				and existingLog.from == log.from
				and existingLog.level == log.level
				and existingLog.text == log.text
			then
				exists = true
				break
			end
		end

		if exists then
			continue
		end

		table.insert(logs, log)
	end

	table.move(logs, 1, #logs, #_K.Data.logs + 1, _K.Data.logs)
	_K.Util.Defer.wait()
	table.sort(_K.Data.logs, _K.Logger.sortTime)

	while #_K.Data.logs > 1e5 do
		table.remove(_K.Data.logs, 1)
		_K.Util.Defer.wait()
	end

	task.defer(_K.client.dashboard.Logs.updateList, _K.client.dashboard.Logs)
end)

_K.Remote.Settings.OnClientEvent:Connect(function(settings)
	for key, value in settings do
		value = UI.peek(value)
		_K.Data.settings[key] = value
		if _K.client.settings[key] then
			_K.client.settings[key]:set(value)
		end
		if string.find(key, "theme", 1, true) == 1 then
			local themeKey = string.sub(key, 6)
			if UI.Theme[themeKey] then
				UI.Theme[themeKey]:set(value)
			end
		end
	end
	if settings.dashboardButtonRank ~= nil or settings.freeAdmin ~= nil then
		_K.client.updateInterfaceAuth()
	end
end)

_K.Remote.Role.OnClientEvent:Connect(function(role, roleData)
	_K.Data.roles[role] = roleData
	_K.client.updateInterfaceAuth()
end)

_K.Remote.Roles.OnClientEvent:Connect(function(roles)
	_K.Util.Table.merge(_K.Data.roles, roles)
	_K.client.updateInterfaceAuth()
end)

return true
