local _K = require(script.Parent.Parent)
local UI = _K.UI

_K.client.updateInterfaceAuth = _K.Util.Function.debounce(0.2, function()
	local userId = _K.LocalPlayer.UserId
	local userRank = _K.Auth.getRank(userId)
	_K.client.rank(userRank)

	local commandBarRank = _K.client.settings.commandBarRank:peek()
	local dashboardRank = _K.client.settings.dashboardRank:peek()
	local commandsButtonRank = _K.client.settings.commandsButtonRank:peek()
	local dashboardButtonRank = _K.client.settings.dashboardButtonRank:peek()

	if commandBarRank == nil then
		commandBarRank = 0
	end
	if dashboardRank == nil then
		dashboardRank = 0
	end
	if dashboardButtonRank == nil then
		dashboardButtonRank = 0
	end

	_K.client.commandBarEnabled = commandBarRank and userRank >= commandBarRank
	_K.client.dashboardEnabled = dashboardRank and userRank >= dashboardRank
	_K.client.dashboardButtonEnabled = _K.client.dashboardEnabled
		and dashboardButtonRank
		and userRank >= dashboardButtonRank
	_K.client.commandsButtonEnabled = not _K.client.dashboardButtonEnabled
		and commandsButtonRank
		and userRank >= commandsButtonRank

	_K.client.toggleCommandBar._instance.Visible = _K.client.commandBarEnabled
	if not _K.client.commandBarEnabled and _K.client.CommandBar and _K.client.CommandBar.Bar.Visible then
		_K.client.CommandBar.hide()
	end

	if typeof(_K.client.dashboardButton) == "Instance" and _K.client.dashboardButton:IsA("GuiObject") then
		_K.client.dashboardButton.Visible = _K.client.dashboardButtonEnabled
	else
		_K.client.dashboardButton:setEnabled(_K.client.dashboardButtonEnabled)
	end

	if typeof(_K.client.commandsButton) == "Instance" and _K.client.commandsButton:IsA("GuiObject") then
		_K.client.commandsButton.Visible = _K.client.commandsButtonEnabled
	else
		_K.client.commandsButton:setEnabled(_K.client.commandsButtonEnabled)
	end

	if not _K.client.dashboardEnabled then
		_K.client.dashboard.Window._instance.Visible = false
	end

	_K.client.dashboard.Bans._instance:SetAttribute("Enabled", _K.Auth.hasCommand(userId, "bans"))
	_K.client.dashboard.Logs._instance:SetAttribute("Enabled", _K.Auth.hasCommand(userId, "logs"))
	_K.client.dashboard.Members._instance:SetAttribute("Enabled", _K.Auth.hasCommand(userId, "members"))
	_K.client.dashboard.Settings._instance:SetAttribute("Enabled", _K.Auth.hasCommand(userId, "settings"))

	for _, command in _K.Registry.commands do
		command.LocalPlayerAuthorized = _K.Auth.hasCommand(userId, command)
		if not command.RestrictedToRole then
			for rank, roleData in _K.Data.rolesList do
				if _K.Auth.roleCanUseCommand(roleData._key, command) then
					command.RestrictedToRole = roleData
					break
				end
			end
		end
	end
	_K.client.dashboard.Commands:updateList()
	_K.client.CommandBar.updateCompletionData()

	if _K.Registry.commands.tools and _K.Registry.commands.tools.LocalPlayerAuthorized then
		_K.Remote.Tools:Fire()
	end

	_K.Hook.authChanged:Fire()
end)

UI.effect(UI.on(_K.client.settings.commandBarRank, _K.client.updateInterfaceAuth, true)):get()
UI.effect(UI.on(_K.client.settings.dashboardRank, _K.client.updateInterfaceAuth, true)):get()
UI.effect(UI.on(_K.client.settings.dashboardButtonRank, _K.client.updateInterfaceAuth, true)):get()

local _ = _K.Remote.Announce:Connect(_K.Announce)
local _ = _K.Remote.Notify:Connect(_K.Notify)

local _ = _K.Remote.SetCore:Connect(function(parameter: string, value: any)
	_K.Service.StarterGui:SetCore(parameter, value)
end)

local requestingCommand = {}
_K.Remote.RequestCommand.OnInvoke = function(from: Player | number, text: string)
	local fromUserId = if type(from) == "number" then from else from.UserId
	local fromName = if type(from) == "number" then nil else from.DisplayName
	if requestingCommand[fromUserId] then
		return
	end
	requestingCommand[fromUserId] = true

	local actionSignal = _K.Util.Signal.new()
	_K.Notify({
		Text = `\t<font transparency="0.5">{text}</font>`,
		ActionText = "Permit this action?",
		Action = true,
		ExitButton = false,
		LeftAction = true,
		RightAction = true,
		Duration = 30,

		_K.client.UserFrame(fromUserId, fromName),

		[UI.Hook] = {
			Action = function(v)
				actionSignal:Fire(v)
			end,
		},
	})

	task.delay(30, actionSignal.Fire, actionSignal, false)

	local action = actionSignal:Wait() == true
	requestingCommand[fromUserId] = nil
	return action
end

-- general data replication

local _ = _K.Remote.Ban:Connect(function(userId, ban)
	_K.Data.bans[userId] = ban
	_K.client.bans(_K.Data.bans, true)
end)

local _ = _K.Remote.Bans:Connect(function(bans)
	if bans then
		_K.Data.bans = bans
		_K.client.bans(_K.Data.bans, true)
	end
end)

local _ = _K.Remote.DisplayBubble:Connect(function(character: Model, message: string)
	_K.Service.TextChat:DisplayBubble(character, message)
end)

local _ = _K.Remote.Member:Connect(function(userId, member)
	local viewas = _K.Registry.commands.viewas
	if viewas.env.originalMember and userId == tostring(_K.LocalPlayer.UserId) then
		viewas.env.originalMember = member
		member = _K.Data.members[userId]
	end

	_K.Data.members[userId] = member
	_K.client.members(_K.Data.members, true)
	_K.client.updateInterfaceAuth()
end)

local _ = _K.Remote.Members:Connect(function(members)
	local viewas = _K.Registry.commands.viewas
	if viewas.env.originalMember then
		local key = tostring(_K.LocalPlayer.UserId)
		for userId, member in members do
			if userId == key then
				viewas.env.originalMember = member
				members[userId] = _K.Data.members[userId]
				break
			end
		end
	end

	_K.Data.members = members
	_K.client.members(_K.Data.members, true)
	_K.client.updateInterfaceAuth()
end)

local _ = _K.Remote.Log:Connect(function(log)
	if not _K.ready then
		return
	end

	local logs = _K.Data.logs
	local startIndex = 1
	for i = #logs, 1, -1 do
		if #logs - i > 250 and logs[i][3] < log[3] then
			startIndex = i + 1
			break
		end
	end

	for i = startIndex, #logs do
		local existing = logs[i]
		local ellipsisPos = if existing[3] == log[3]
				and existing[2] == log[2]
				and existing[4] == log[4]
				and existing[1] ~= log[1]
			then string.find(existing[1], "…", 1, true)
			else nil
		if
			ellipsisPos
			and (
				ellipsisPos == 1
				or string.sub(log[1], 1, ellipsisPos - 1) == string.sub(existing[1], 1, ellipsisPos - 1)
			)
		then
			existing[1] = log[1]
			existing.filterText = nil
			task.defer(_K.client.dashboard.Logs.updateList, _K.client.dashboard.Logs)
			return
		end
	end

	table.insert(logs, log)

	_K.removeExcessLogs()

	task.defer(_K.client.dashboard.Logs.updateList, _K.client.dashboard.Logs)
end)

local _ = _K.Remote.Logs:Connect(function(logsBuffer)
	if not _K.ready then
		return
	end

	_K.Util.Defer.reset()

	local ok, result = pcall(_K.Z.des, _K.Data.Schema.logsRemote, logsBuffer)
	if not ok then
		warn(result)
		return
	end

	local logs = result
	_K.Util.Defer.wait()

	_K.Util.Table.mergeList(_K.Data.logs, logs)
	_K.Util.Defer.wait()

	table.sort(_K.Data.logs, _K.Logger.sortTime)
	_K.Util.Defer.wait()

	_K.removeExcessLogs()

	_K.client.dashboard.Logs:updateList()
end)

local _ = _K.Remote.Settings:Connect(function(settings)
	-- full settings syncs repeat the pinned announcement, it only shows when it changed
	if settings.announcement ~= nil and _K.Chat.pinAnnouncement(settings.announcement) then
		-- shown like the "announce" message would show it
		local msg, from, duration = table.unpack(settings.announcement, 1, 3)
		_K.Announce({
			From = from,
			Text = _K.Chat.restoreRichText(_K.Util.String.escapeRichText(msg)),
			Duration = duration or 0,
		})
	end

	local studioThemeLock = _K.Data.defaultSettings.changeThemeAuthority == "Studio"
		or _K.Data.settings.changeThemeAuthority == "Studio"
	local useSaved = if settings.useSavedSettings ~= nil
		then settings.useSavedSettings
		else _K.Data.savedSettings.useSavedSettings ~= false

	local function applySetting(key: string, rawValue: any)
		if studioThemeLock and (key == "changeThemeAuthority" or string.find(key, "theme", 1, true) == 1) then
			return
		end
		local value = UI.raw(rawValue)
		_K.Data.savedSettings[key] = value
		local isThemeProperty = key ~= "theme" and string.find(key, "theme", 1, true) == 1
		local clientTheme = if _K.client.settings.theme
			then _K.client.settings.theme:peek()
			else _K.Data.savedSettings.theme
		local canApplyTheme = useSaved
			and (
				not isThemeProperty
				or (
					not studioThemeLock
					and (
						_K.Data.settings.changeThemeAuthority == "Server"
						or clientTheme == "Custom (DataStore)"
						or _K.Data.savedSettings.theme == "Custom (DataStore)"
					)
				)
			)
		if isThemeProperty and canApplyTheme then
			local themeKey = string.sub(key, 6)
			if _K.UI.Theme[themeKey] and UI.isNode(_K.UI.Theme[themeKey]) then
				_K.UI.Theme[themeKey](value, true)
			end
		end
		if
			(if isThemeProperty then canApplyTheme else (useSaved or key == "useSavedSettings"))
			and _K.client.settings[key]
		then
			_K.client.settings[key](value, true)
		end
	end

	-- apply authority/useSaved/theme preset before individual theme* properties so presets don't overwrite overrides
	if settings.changeThemeAuthority ~= nil then
		applySetting("changeThemeAuthority", settings.changeThemeAuthority)
		if _K.Data.defaultSettings.changeThemeAuthority ~= "Studio" then
			studioThemeLock = _K.Data.settings.changeThemeAuthority == "Studio"
		end
	end
	if settings.useSavedSettings ~= nil then
		applySetting("useSavedSettings", settings.useSavedSettings)
	end
	if settings.theme ~= nil then
		applySetting("theme", settings.theme)
	end
	for key, value in settings do
		if key ~= "changeThemeAuthority" and key ~= "useSavedSettings" and key ~= "theme" then
			applySetting(key :: string, value)
		end
	end
	_K.client.updateInterfaceAuth()
end)

local _ = _K.Remote.Role:Connect(function(role, roleData)
	_K.Data.roles[role] = roleData
	_K.client.updateInterfaceAuth()
end)

local _ = _K.Remote.Roles:Connect(function(roles)
	_K.Util.Table.merge(_K.Data.roles, roles)
	_K.client.updateInterfaceAuth()
end)

local _ = _K.Remote.RolesNotification:Connect(function()
	_K.client.rolesNotification()
end)
return true
