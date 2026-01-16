local _K = require(script.Parent)
local UI = _K.UI

_K.Announce = require(script:WaitForChild("Announce"))
_K.Notify = require(script:WaitForChild("Notify"))

_K.LocalPlayer = _K.Service.Players.LocalPlayer

_K.client = {
	Character = require(script:WaitForChild("Character")),
	UserFrame = require(script:WaitForChild("UserFrame")),
	TopbarPlus = nil,

	bans = _K.Flux.state(_K.Data.bans),
	logs = _K.Flux.state(_K.Data.logs),
	members = _K.Flux.state(_K.Data.members),
	rank = _K.Flux.state(0),

	ready = false,
	hotkeys = {
		dashboard = { key = UI.state(Enum.KeyCode.Quote), mods = UI.state({}), callback = nil },
	},
	settings = {},

	playerPrefix = ";",
}

task.spawn(function()
	local reference = _K.Service.ReplicatedStorage:WaitForChild("TopbarPlusReference", 10)
	if reference then
		local module = reference.Value or reference.Changed:Wait()
		_K.client.TopbarPlus = require(module)
	end
end)

local function deepMergeTheme(from, to, prefix: string?)
	for key, value in from do
		value = UI.raw(value)
		if UI.isState(to[key]) then
			if prefix then
				key = prefix .. key
				_K.Data.savedSettings[key] = value
				_K.client.settings[key](value)
			else
				to[key](value)
			end
		elseif type(value) == "table" then
			deepMergeTheme(value, to[key])
		end
	end
end

function UI.changeTheme(new)
	deepMergeTheme(new, UI.Theme, "theme")
end

local closeTags = { "font", "stroke", "b", "i", "u", "s", "uc", "sc", "uppercase", "smallcaps", "mark" }
local openTags = {}
for i, tag in closeTags do
	openTags[i] = "<" .. tag
	closeTags[i] = "</" .. tag .. ">?"
end

local chatCommandThrottle
local warnPrefixes = _K.Util.String.escapePattern(";:!$~.")

local function Chatted(message: string)
	if not _K.client.ready or _K.Data.settings.chatCommands == false then
		return
	end
	local prefix = _K.getCommandPrefix()

	local commandFormat =
		`%s[^%s{_K.Process.ignoreFormat}{_K.Util.String.escapePattern(_K.Data.settings.splitKey or " ")}]`
	local commandStart
	for _, value in { prefix, unpack(_K.Data.settings.prefix) } do
		local escapedPrefix = _K.Util.String.escapePattern(value)
		commandStart = string.find(message, string.format(commandFormat, escapedPrefix, escapedPrefix))
		if commandStart then
			break
		end
	end

	if not commandStart then
		-- check for optionalPrefix
		local directCommand = _K.Registry.commands[string.lower(message)]
		if directCommand and directCommand.optionalPrefix then
			commandStart = 1
			message = prefix .. message
		else
			if _K.Data.settings.wrongPrefixWarning ~= false and #warnPrefixes > 0 then
				local test = " " .. string.lower(message)
				for alias in _K.Registry.commands do
					local i = string.find(test, `[{warnPrefixes}]{_K.Util.String.escapePattern(alias)}`)
					if i then
						warnPrefixes =
							_K.Util.String.escapePattern(warnPrefixes:gsub("%%", ""):gsub(test:sub(i, i), ""))
						task.spawn(_K.Notify, {
							From = "_K",
							Text = `<b>Invalid command prefix, try "{prefix}{alias}"</b>`,
							TextColor3 = Color3.new(1, 0, 0),
							Sound = "Call_Leave",
						})
						break
					end
					_K.Util.Defer.wait()
				end
			end
			return
		end
	end
	if not chatCommandThrottle then
		chatCommandThrottle = true

		-- trim hanging richtext tags
		message = string.sub(message, commandStart)
		for i, tag in closeTags do
			local findIndex = string.find(message, tag, 1, true)
			if not findIndex or string.find(message, openTags[i], 1, true) < findIndex then
				continue
			end
			message = string.gsub(message, tag, "")
		end

		_K.Process.runCommands(_K, _K.LocalPlayer.UserId, message)
		task.wait(0.2)
		chatCommandThrottle = nil
	end
end

if _K.Service.TextChat.ChatVersion == Enum.ChatVersion.TextChatService then
	_K.Service.TextChat.SendingMessage:Connect(function(textChatMessage: TextChatMessage)
		Chatted(_K.Util.String.unescapeRichText(textChatMessage.Text))
	end)
end

_K.Remote.Command:Connect(Chatted)

local textBoxFocused
do
	local focusedTextBoxes = {}
	textBoxFocused = function()
		if next(focusedTextBoxes) then
			return true
		end
		local ChatInputBarConfiguration = _K.Service.TextChat:FindFirstChildOfClass("ChatInputBarConfiguration")
		if ChatInputBarConfiguration and ChatInputBarConfiguration.IsFocused then
			return true
		end
		return false
	end

	_K.Service.UserInput.TextBoxFocused:Connect(function(textbox)
		if not (textbox and textbox.TextEditable) then
			return
		end
		focusedTextBoxes[textbox] = true
	end)
	_K.Service.UserInput.TextBoxFocusReleased:Connect(function(textbox)
		if not (textbox and textbox.TextEditable) then
			return
		end
		focusedTextBoxes[textbox] = nil
	end)
end

_K.Service.UserInput.InputBegan:Connect(function(input, gameProcessedEvent)
	if input.UserInputType == Enum.UserInputType.Keyboard and not textBoxFocused() then
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
					if isDown == not data.mods._value[modifierKey.Name] then
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

_K.Remote.Init:Once(function(bans, logs, members, roles, servers, savedSettings, defaultSettings)
	-- need to improve networking performance!
	if bans then
		_K.Util.Table.merge(_K.Data.bans, bans)
		_K.client.bans(_K.Data.bans)
	end

	if logs then
		local ok, result = pcall(_K.Z.des, _K.Data.Schema.logs, logs)
		if not ok then
			warn(result)
		end
		if ok and result then
			table.move(result, 1, #result, #_K.Data.logs + 1, _K.Data.logs)
			table.sort(_K.Data.logs, _K.Logger.sortTime)
		end
	end

	if servers then
		_K.Util.Table.merge(_K.Data.reservedServers, servers)
	end

	_K.Util.Table.merge(_K.Data.members, members)
	_K.client.members(_K.Data.members)

	_K.Data.roles = roles
	for role, roleData in roles do
		if not table.find(_K.Data.rolesList, roleData) then
			table.insert(_K.Data.rolesList, roleData)
		end
	end
	table.sort(_K.Data.rolesList, function(a, b)
		return a._rank < b._rank
	end)

	local theme = UI.Themes[defaultSettings.theme]
	if theme then
		for key, state in theme do
			if state._value ~= nil then
				defaultSettings["theme" .. key] = state._value
			end
		end
	end

	local merge = _K.Util.Table.merge
	_K.Data.defaultSettings = merge(table.clone(_K.Data.settings), defaultSettings)
	_K.Data.savedSettings = merge(_K.Util.Table.deepCopy(_K.Data.defaultSettings), savedSettings)
	_K.Data.settings = if _K.Data.savedSettings.useSavedSettings ~= false
		then _K.Data.savedSettings
		else _K.Data.defaultSettings

	_K.client.playerPrefix = _K.Flux.state(_K.Data.settings.prefix[1])

	for key, value in _K.Data.settings do
		if key == "useSavedSettings" then
			value = _K.Data.savedSettings.useSavedSettings
		end
		local state
		if key ~= "theme" and string.find(key :: string, "theme", 1, true) == 1 then
			state = UI.Theme[string.sub(key :: string, 6)]
			if state then
				state(value)
			end
		end
		state = state or _K.Flux.state(value)
		_K.client.settings[key] = state

		-- UI.Theme connection to theme settings
		if key == "theme" then
			state:Connect(function(value)
				local theme = UI.Themes[value]
				if theme then
					UI.changeTheme(theme)
				end
			end)
		elseif string.find(key :: string, "theme", 1, true) == 1 then
			key = string.sub(key :: string, 6)
			if UI.Theme[key] then
				state:Connect(function(value)
					UI.Theme[key](value)
				end)
			end
		elseif key == "useSavedSettings" then
			state:Connect(function(useSaved)
				local settings = if useSaved then _K.Data.savedSettings else _K.Data.defaultSettings
				_K.Data.settings = settings
				for key, value in settings do
					if key ~= "useSavedSettings" and _K.client.settings[key] then
						_K.client.settings[key](value, true)
					end
				end
			end)
		end
	end

	_K.client.CommandBar = require(script:WaitForChild("CommandBar"))
	_K.client.CommandBar:init(_K)
	_K.client.Dashboard = require(script:WaitForChild("Dashboard") :: any) -- relies on command bar
	require(script:WaitForChild("GetKA"))
	require(script:WaitForChild("Network"))

	function _K.client.rolesNotification()
		local member = _K.Data.members[tostring(_K.LocalPlayer.UserId)]
		local roleStrings = {}
		if member and member.roles then
			for _, roleId in member.roles do
				local role = _K.Data.roles[roleId]
				if role then
					table.insert(roleStrings, `<font color="{role.color}">{role.name}</font>`)
				end
			end
		end
		for _, roleId in _K.Data.settings.freeAdmin do
			if member and member.roles and table.find(member.roles, roleId) then
				continue
			end
			local role = _K.Data.roles[roleId]
			if role then
				table.insert(roleStrings, `<font color="{role.color}">{role.name}</font>`)
			end
		end
		table.insert(roleStrings, `<font color="{_K.Data.roles.everyone.color}">{_K.Data.roles.everyone.name}</font>`)
		local roleString = table.concat(roleStrings, ", ")
		local nString = if roleString:sub(1, 1):lower():match("aeiou") then "n" else ""

		_K.Notify({
			From = "_K",
			Text = `<font family="{UI.Theme.FontMono._value.Family}"><b>You're a{nString}</b> <sc>{roleString}</sc></font>\n\n<i>Click to see the commands.</i>`,
			Duration = 15,
			Activated = function()
				_K.client.commandsWindowVisible(true)
			end,
		})
	end

	if
		_K.Data.settings.joinNotificationRank
		and _K.Auth.getRank(_K.Service.Players.LocalPlayer.UserId) >= _K.Data.settings.joinNotificationRank
	then
		_K.client.rolesNotification()
	end

	do
		local count = 0
		local vipNotificationVisible = false

		local function vipNotificationClosed()
			vipNotificationVisible = false
		end

		local function showPopup()
			_K.VIP.popup.Visible = true
			vipNotificationVisible = false
		end

		_K.client.VIPNotification = _K.Util.Function.throttle(300, function()
			if
				count > 3
				or vipNotificationVisible
				or _K.VIP.popup.Visible
				or not _K.Data.settings.vip
				or not _K.Data.settings.chatCommandsNotification
				or (_K.LocalPlayer:GetAttribute("_KDonationLevel") or 0) > 2
			then
				return
			end

			count += 1
			vipNotificationVisible = true

			local initialJoin = _K.LocalPlayer:GetAttribute("_KInitialJoin")
			local line = if workspace:GetServerTimeNow() - initialJoin < 15 * 60
				then "Unlock exclusive chat commands in <b>10k+</b> experiences for <font color='#0f0'><b>40% OFF</b></font>!"
				else "Unlock <b>exclusive</b> chat commands in <b>10k+</b> experiences!"

			_K.Notify({
				From = "System",
				Text = `{line}\n\n<i>Click for more details.</i>`,
				Duration = 60,
				Sound = "Call_Accept",
				Activated = showPopup,
				Close = vipNotificationClosed,
			})
		end)
		_K.Remote.VIPNotification:Connect(_K.client.VIPNotification)
		_K.VIP.popup.Parent = UI.LayerTopInset

		local connections
		local function showOnFirstOpen()
			if
				_K.Data.settings.vip
				and not vipNotificationVisible
				and (_K.LocalPlayer:GetAttribute("_KDonationLevel") or 0) < 3
			then
				_K.VIP.popup.Visible = true
				_K.Flux.cleanup(connections)
			end
		end

		connections = {
			_K.client.dashboard.Commands._instance:GetPropertyChangedSignal("Visible"):Once(showOnFirstOpen),
			_K.client.dashboard.Window._instance:GetPropertyChangedSignal("Visible"):Once(showOnFirstOpen),
		}
	end

	if savedSettings.announcement then
		local msg, from = unpack(savedSettings.announcement)
		task.spawn(_K.Announce, {
			From = from,
			Text = msg,
			Duration = 0,
		})
	end

	if _K.Data.settings.announcements then
		for _, announcement in _K.Data.settings.announcements do
			task.spawn(_K.Announce, announcement)
		end
	end

	if _K.Data.settings.notifications then
		for _, notification in _K.Data.settings.notifications do
			task.spawn(_K.Notify, notification)
		end
	end

	if not game:IsLoaded() then
		game.Loaded:Wait()
	end

	-- finally load client and shared addons
	local function loadAddons(list)
		for _, object in list do
			if object:IsA("ModuleScript") then
				task.spawn(function()
					require(object)(_K)
				end)
			else
				loadAddons(object:GetChildren())
			end
		end
	end

	loadAddons(_K.script.Shared:WaitForChild("DefaultAddons"):GetChildren())
	loadAddons(_K.script:WaitForChild("Addons"):GetChildren())
	loadAddons(_K.Service.Collection:GetTagged(_K._addonTag))

	_K.client.updateInterfaceAuth()

	_K.client.ready = true
	_K.Hook.init:Fire()

	task.spawn(function()
		local page = if _K.Auth.hasRestrictedRole(_K.LocalPlayer.UserId)
			then _K.client.dashboard.About
			else _K.client.dashboard.Market
		_K.client.dashboard.Tabs._pages:JumpTo(_K.client.dashboard.Tabs._containerCache[page._instance])
	end)
end)

_K.Remote.Init:Fire({ Attributes = { Platform = UI.Platform, SessionStart = workspace:GetServerTimeNow() } })

local lastIdle = time()
local function resetIdle()
	if time() - 30 > lastIdle then
		_K.Remote.Idled:Fire(0)
	end
end

_K.Service.Players.LocalPlayer.Idled:Connect(function(idleTime)
	lastIdle = time()
	_K.Remote.Idled:Fire(idleTime)
	task.delay(35, resetIdle)
end)
