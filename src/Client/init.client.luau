local _K = require(script.Parent)
local UI = _K.UI

_K.Announce = require(script:WaitForChild("Announce"))
_K.Notify = require(script:WaitForChild("Notify"))

_K.LocalPlayer = _K.Service.Players.LocalPlayer

_K.client = {
	Character = require(script:WaitForChild("Character")),
	Explorer = require(script:WaitForChild("Explorer")),
	UserFrame = require(script:WaitForChild("UserFrame")),
	TopbarPlus = nil,

	bans = _K.Flux.signal(_K.Data.bans),
	logs = _K.Flux.signal(_K.Data.logs),
	members = _K.Flux.signal(_K.Data.members),
	servers = _K.Flux.signal(_K.Data.servers),
	rank = _K.Flux.signal(0),

	ready = false,
	hotkeys = {
		dashboard = { key = UI.signal(Enum.KeyCode.Quote), mods = UI.signal({}), callback = nil },
	},
	settings = {},

	playerPrefix = _K.Flux.signal(";"),
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
		if UI.isNode(to[key]) then
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

-- chat commands are TextChatCommands the server runs, it forwards their text so this client runs its own part (windows,
-- purchase prompts); scripts can't read chat text with platform-integrated chat
local _ = _K.Remote.Command:Connect(function(message: string, clientOnly: boolean?)
	if _K.ready then
		if clientOnly and type(message) == "string" then
			local trimmed = _K.Util.String.trim(message)
			local nextChar = utf8.offset(trimmed, 2) or 2
			local firstChar = string.sub(trimmed, 1, nextChar - 1)
			local clientPrefix = _K.getCommandPrefix()
			if
				firstChar ~= clientPrefix
				and not table.find(_K.Data.settings.prefix, firstChar)
				and table.find(_K.Data.savedSettings.prefix or {}, firstChar)
			then
				message = clientPrefix .. string.sub(trimmed, nextChar)
			end
			if _K.client.commandBarEnabled then
				local ok, _err, prepared = _K.Process.prepareCommands(_K, _K.LocalPlayer.UserId, message)
				local lastCommand = not ok and prepared and prepared[#prepared]
				if
					lastCommand
					and (lastCommand.argMissing ~= nil or (#lastCommand.array == 2 and lastCommand.array[2][2] == ""))
				then
					local body = string.sub(_K.Util.String.trim(message), prepared[1].array[1][1])
					_K.client.CommandBar.show(`{clientPrefix}{body} `)
					return
				end
			end
		end
		_K.Process.runCommands(_K, _K.LocalPlayer.UserId, message, nil, nil, clientOnly == true)
	end
end)

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

	local _ = _K.Service.UserInput.TextBoxFocused:Connect(function(textbox)
		if not (textbox and textbox.TextEditable) then
			return
		end
		focusedTextBoxes[textbox] = true
	end)
	local _ = _K.Service.UserInput.TextBoxFocusReleased:Connect(function(textbox)
		if not (textbox and textbox.TextEditable) then
			return
		end
		focusedTextBoxes[textbox] = nil
	end)
end

local _ = _K.Service.UserInput.InputBegan:Connect(function(input, gameProcessedEvent)
	if input.UserInputType == Enum.UserInputType.Keyboard and not textBoxFocused() then
		for keyName, data in _K.client.hotkeys do
			if
				data.callback
				and (
					input.KeyCode == data.key:peek()
					or (type(data.key:peek()) == "table" and table.find(data.key:peek(), input.KeyCode))
				)
			then
				local missingMod = false
				for _, modifierKey in Enum.ModifierKey:GetEnumItems() do
					local isDown = input:IsModifierKeyDown(modifierKey)
					if isDown == not data.mods:peek()[modifierKey.Name] then
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

_K.Remote.Init:Once(function(bans, logs, members, roles, reservedServers, servers, savedSettings, defaultSettings)
	-- need to improve networking performance!
	if bans then
		_K.Util.Table.merge(_K.Data.bans, bans)
		_K.client.bans(_K.Data.bans, true)
	end

	if logs then
		local ok, result = pcall(_K.Z.des, _K.Data.Schema.logsRemote, logs)
		if not ok then
			warn(result)
		end
		if ok and result then
			_K.Util.Table.mergeList(_K.Data.logs, result)
			table.sort(_K.Data.logs, _K.Logger.sortTime)
		end
	end

	if reservedServers then
		_K.Util.Table.merge(_K.Data.reservedServers, reservedServers)
	end

	if servers then
		_K.Util.Table.merge(_K.Data.servers, servers)
		_K.client.servers(_K.Data.servers, true)
	end

	_K.Util.Table.merge(_K.Data.members, members)
	_K.client.members(_K.Data.members, true)

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
			local val = if type(state) == "table" and type(state.peek) == "function"
				then state:peek()
				elseif type(state) ~= "table" then state
				else nil
			if val ~= nil then
				defaultSettings["theme" .. key] = val
			end
		end
	end

	local merge = _K.Util.Table.merge
	_K.Data.defaultSettings = merge(table.clone(_K.Data.settings), defaultSettings)
	_K.Data.savedSettings = merge(_K.Util.Table.deepCopy(_K.Data.defaultSettings), savedSettings)
	_K.Data.settings = if _K.Data.savedSettings.useSavedSettings ~= false
		then _K.Data.savedSettings
		else _K.Data.defaultSettings

	_K.client.playerPrefix(_K.Data.settings.prefix[1])

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
		state = state or _K.Flux.signal(value)
		_K.client.settings[key] = state

		-- UI.Theme connection to theme settings
		if key == "theme" then
			UI.effect(UI.on(state, function(value)
				local theme = UI.Themes[value]
				if theme then
					UI.changeTheme(theme)
				end
			end, true)):get()
		elseif string.find(key :: string, "theme", 1, true) == 1 then
			key = string.sub(key :: string, 6)
			if UI.Theme[key] then
				UI.effect(UI.on(state, function(value)
					UI.Theme[key](value)
				end, true)):get()
			end
		elseif key == "useSavedSettings" then
			UI.effect(UI.on(state, function(useSaved)
				local settings = if useSaved then _K.Data.savedSettings else _K.Data.defaultSettings
				_K.Data.settings = settings
				for key, value in settings do
					if key ~= "useSavedSettings" and _K.client.settings[key] then
						_K.client.settings[key](value, true)
					end
				end
			end, true)):get()
		end
	end

	_K.client.CommandBar = require(script:WaitForChild("CommandBar"))
	_K.client.CommandBar:init(_K)
	_K.client.Dashboard = require(script:WaitForChild("Dashboard")) -- relies on command bar
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
			Text = `<font family="{UI.Theme.FontMono:peek().Family}"><b>You're a{nString}</b> <sc>{roleString}</sc></font>\n\n<i>Click to see the commands.</i>`,
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
		local vipNotificationVisible = false
		local shownPreSale = false
		local shownSale = false

		local function vipNotificationClosed()
			vipNotificationVisible = false
		end

		local function showPopup()
			_K.VIP.popup.Visible = true
			vipNotificationVisible = false
		end

		_K.client.VIPNotification = function()
			if
				vipNotificationVisible
				or _K.VIP.popup.Visible
				or not _K.Data.settings.vip
				or not _K.Data.settings.chatCommandsNotification
				or (_K.LocalPlayer:GetAttribute("_KDonationLevel") or 0) > 2
			then
				return
			end

			local initialJoin = _K.LocalPlayer:GetAttribute("_KInitialJoin")
			local onSale = initialJoin ~= nil and (workspace:GetServerTimeNow() - initialJoin >= 10 * 60)

			if onSale then
				if shownSale then
					return
				end
				shownSale = true
			else
				if shownPreSale then
					return
				end
				shownPreSale = true
			end

			vipNotificationVisible = true

			local prefix = _K.Util.String.escapeRichText(_K.getCommandPrefix())
			local line = if onSale
				then "<b>VIP Chat Commands</b> are now <font color='#0f0'><b>40% OFF</b></font> in <b>10k+</b> experiences!"
				else `Unlock <b>{prefix}headless</b>, <b>{prefix}korblox</b>, <b>{prefix}fire</b> &amp; more VIP chat commands in <b>10k+</b> experiences!`
			local cta = if onSale then "Click to claim 40% OFF." else "Click for more details."

			_K.Notify({
				From = "System",
				Text = `{line}\n\n<i>{cta}</i>`,
				Duration = 60,
				Sound = "Call_Accept",
				Activated = showPopup,
				Close = vipNotificationClosed,
			})
		end

		local _ = _K.Remote.VIPNotification:Connect(_K.client.VIPNotification)
		_K.client.dashboard.Commands._instance:GetPropertyChangedSignal("Visible"):Once(_K.client.VIPNotification)
		_K.client.dashboard.Window._instance:GetPropertyChangedSignal("Visible"):Once(_K.client.VIPNotification)

		_K.VIP.popup.Parent = UI.LayerTopInset
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
					require(object :: ModuleScript)(_K)
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

	_K.ready = true
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

local _ = _K.Service.Players.LocalPlayer.Idled:Connect(function(idleTime)
	lastIdle = time()
	_K.Remote.Idled:Fire(idleTime)
	task.delay(35, resetIdle)
end)
