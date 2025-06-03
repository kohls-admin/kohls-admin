local _K = require(script.Parent.Parent)
local UI = _K.UI

function _K.client.updateInterfaceAuth()
	-- TODO: recheck visibility for all restricted UIs
	local userId = _K.LocalPlayer.UserId
	local userRank = _K.Auth.getRank(userId)
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
	_K.client.dashboardButtonEnabled = _K.client.dashboardEnabled
		and dashboardButtonRank
		and userRank >= dashboardButtonRank
	_K.client.dashboardButton:setEnabled(_K.client.dashboardButtonEnabled)

	if not _K.client.dashboardEnabled then
		_K.client.dashboard.Window._instance.Visible = false
	end

	_K.client.dashboard.Bans._instance:SetAttribute("Enabled", _K.Auth.hasCommand(userId, "bans"))
	_K.client.dashboard.Logs._instance:SetAttribute("Enabled", _K.Auth.hasCommand(userId, "logs"))
	_K.client.dashboard.Members._instance:SetAttribute("Enabled", _K.Auth.hasCommand(userId, "members"))
	_K.client.dashboard.Settings:SetAttribute("Enabled", _K.Auth.hasCommand(userId, "settings"))

	for _, command in _K.Registry.commands do
		command.LocalPlayerAuthorized = _K.Auth.hasCommand(userId, command)
	end
	_K.client.dashboard.Commands:updateList()
	_K.client.CommandBar.updateCompletionData()

	if _K.Registry.commands.tools and _K.Registry.commands.tools.LocalPlayerAuthorized then
		_K.Remote.Tools:FireServer()
	end

	_K.Hook.authChanged:Fire()
end

_K.Remote.Announce.OnClientEvent:Connect(_K.Announce)
_K.Remote.Notify.OnClientEvent:Connect(_K.Notify)

_K.Remote.SetCore.OnClientEvent:Connect(function(parameter: string, value: any)
	_K.Service.StarterGui:SetCore(parameter, value)
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
		Duration = 30,

		_K.client.UserFrame(from.UserId, from.DisplayName),

		[UI.Hook] = {
			Action = function(v)
				actionSignal:Fire(v)
			end,
		},
	})

	task.delay(30, actionSignal.Fire, actionSignal, false)

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
	while #_K.Data.logs > _K.Logger.limit do
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
		table.insert(logs, log)
	end

	table.move(logs, 1, #logs, #_K.Data.logs + 1, _K.Data.logs)
	_K.Util.Defer.wait()
	table.sort(_K.Data.logs, _K.Logger.sortTime)

	while #_K.Data.logs > _K.Logger.limit do
		table.remove(_K.Data.logs, 1)
		_K.Util.Defer.wait()
	end

	_K.client.dashboard.Logs:updateList()
end)

_K.Remote.Settings.OnClientEvent:Connect(function(settings)
	_K.client.syncSettings(settings)
	_K.client.updateInterfaceAuth()
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
