--- @class MainModule
if shared._K_INTERFACE then
	return shared._K_INTERFACE
end

--------------------------
-- START OF SHARED CODE --
--------------------------
local RunService = game:GetService("RunService")

local Client = script:WaitForChild("Client")
local UtilModule = script:WaitForChild("Util")

local requireStart = os.clock()
local Util = require(UtilModule)

export type Log = Util.Log
export type LogType = Util.LogType
export type Logger = Util.Logger
export type Hook = "log" | "preCommand" | "postCommand"

local IS_DEMO_PLACE = game.PlaceId == 2569622788

--[=[
	@within MainModule
	@interface _K
	.Flux Flux

	.Auth Auth

	.Process Process
	.Registry Registry
	.Util Util
	.UI UI

	.IsClient boolean
	.IsServer boolean
	.IsStudio boolean

	.client { [any]: any }?
	.pinnedAnnouncement {}?
	._serverLock boolean

	.creatorId number
	.log Logger.log
	.logger Logger.logger
]=]
local _K = {
	script = script,
	IsClient = RunService:IsClient(),
	IsServer = RunService:IsServer(),
	IsStudio = RunService:IsStudio(),

	DEBUG = IS_DEMO_PLACE,
	VERSION = Util.String.trim(script:WaitForChild("VERSION").Value),

	-- modules
	Logger = Util.Logger.new(true),
	Util = Util,
	Data = require(script:WaitForChild("Data")),
	Flux = require(script:WaitForChild("Flux")),
	Hook = require(script:WaitForChild("Hook")),
	Remote = require(script:WaitForChild("Remote")),
	UI = nil,

	-- core modules
	Auth = require(script:WaitForChild("Auth")),
	Process = require(script:WaitForChild("Process")),
	Registry = require(script:WaitForChild("Registry")),
	VIP = require(script:WaitForChild("VIP")),

	-- shorthand
	Service = Util.Service,

	client = nil,
	pinnedAnnouncement = nil,

	cleanupCommands = {},
	_serverLock = false,
	_addonTag = "Kohl's Admin Addon",
}

function _K.getCommandPrefix(from: number?)
	if not from and _K.IsClient then
		from = Util.Service.Players.LocalPlayer.UserId
	end
	return _K.Data.settings.playerPrefix[from]
		or (if type(_K.Data.settings.prefix) == "table" then _K.Data.settings.prefix[1] else _K.Data.settings.prefix)
end

function _K.log(text: string, level: LogType, from: number?, filtered: boolean?): Log?
	if _K.Data.logsHidden[from] then
		return
	end
	local log = _K.Logger:log(text, level, from)
	if not log then
		return -- DEBUG disabled
	end
	if _K.IsClient then
		log.client = true
	end

	task.defer(function()
		if from then
			log.name = Util.getUserInfo(from).Username
		end
		if _K.IsServer then
			if from and filtered then
				log.text = Util.String.filterForBroadcast(text, from)
			end
			if level == "COMMAND" and (not from or _K.Auth.getRank(from) > 1) then
				table.insert(_K.Data.Cache.logs, { log.text, log.level, log.time, from, log.name })
			end
			if level == "CHAT" then
				table.insert(_K.Data.Cache.chatLogs, { log.text, log.level, log.time, from, log.name })
			end
			for _, player in _K.Service.Players:GetPlayers() do
				if player:GetAttribute("_K_READY") and _K.Auth.hasPermission(player.UserId, "serverlogs") then
					_K.Remote.Log:FireClient(player, log)
				end
			end
		elseif _K.client and _K.client.dashboard then
			_K.client.dashboard.Logs:updateList()
		end
		_K.Hook.log:Fire(log)
	end)

	return log
end
_K.Logger.logs = _K.Data.logs

-- register initial UI children
if _K.IsClient then
	_K.UI = require(Client:WaitForChild("UI"))
	local uiRegisterStart = os.clock()
	_K.UI.registerDefaultClasses()
	task.spawn(_K.log, `UI classes registered in {math.round((os.clock() - uiRegisterStart) * 1000)} ms`, "DEBUG")
end

task.defer(function()
	local typeRegisterStart = os.clock()
	-- register types
	for _, child in script.DefaultTypes:GetChildren() do
		require(child)(_K)
	end
	task.spawn(_K.log, `Default Types registered in {math.round((os.clock() - typeRegisterStart) * 1000)} ms`, "DEBUG")

	local commandRegisterStart = os.clock()
	-- register commands
	for _, child in script.DefaultCommands:GetChildren() do
		_K.Registry.registerCommandModule(_K, child)
	end
	task.spawn(
		_K.log,
		`Default Commands registered in {math.round((os.clock() - commandRegisterStart) * 1000)} ms`,
		"DEBUG"
	)
end)

shared._K_INTERFACE = _K

if not _K.IsServer then
	if not _K.IsStudio or IS_DEMO_PLACE then
		print(`🛡️ Running Kohl's Admin v{_K.VERSION} by @Scripth`)
	end
	task.spawn(_K.log, `Required in {math.round((os.clock() - requireStart) * 1000)} ms`, "DEBUG")
	return _K
end
--------------------------
-- START OF SERVER CODE --
--------------------------

_K.Tools = script:WaitForChild("Tools")
_K.Tools.Parent = _K.Service.ServerScript

local function characterAdded(character: Model)
	local player = _K.Service.Players:GetPlayerFromCharacter(character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")

	-- damage logs
	local alive, lastHealth = true, humanoid.Health
	humanoid.HealthChanged:Connect(function(health)
		if alive then
			local tag = humanoid:FindFirstChild("creator")
			local from = tag and tag.Value
			local damage = lastHealth - health
			lastHealth = health
			if damage > 0 then
				if from then
					_K.log(`damaged {player} for {damage} damage.`, "DAMAGE", from.UserId)
				else
					_K.log(`{player} took {damage} damage.`, "DAMAGE", player.UserId)
				end
			end
		end
	end)

	-- kill logs
	humanoid.Died:Connect(function()
		alive = false
		local tag = humanoid:FindFirstChild("creator")
		local from = tag and tag.Value
		if from then
			_K.log(`died to {from}.`, "DEATH", player.UserId)
			if typeof(from) == "Instance" and from:IsA("Player") then
				_K.log(`killed {player}.`, "KILL", from.UserId)
			end
		else
			_K.log(`died.`, "DEATH", player.UserId)
		end
	end)
end

local function welcomeBadge(userId)
	if not _K.Service.Badge:UserHasBadgeAsync(userId, _K.Data.settings.welcomeBadgeId) then
		_K.Service.Badge:AwardBadge(userId, _K.Data.settings.welcomeBadgeId)
	end
end

local function playerAdded(player: Player)
	if (_K.Data.settings.welcomeBadgeId or 0) > 0 then
		task.spawn(welcomeBadge, player.UserId)
	end

	repeat
		task.wait()
	until _K.Data.roles

	task.spawn(_K.log, "joined the server.", "JOIN", player.UserId)

	if _K.Auth.banHandler(player) then
		return
	end

	if _K.Service.Run:IsStudio() then
		_K.Auth.userRoleAdd(player.UserId, "creator")
	end

	for _, role in _K.Data.settings.freeAdmin do
		_K.Auth.userRoleAdd(player.UserId, role)
	end

	-- group admin and gamepass roles
	local success = _K.Auth.userAsyncRoles(player.UserId, true)
	player:SetAttribute("_KRolesLoaded", success)

	if _K._serverLock and _K.Auth.getRank(player.UserId) < 2 then
		player:Kick(`Server has been locked by {_K._serverLock}`)
		return
	end

	if player.Character then
		task.spawn(characterAdded, player.Character)
	end
	player.CharacterAdded:Connect(characterAdded)
	player.Chatted:Connect(function(message: string)
		local emote = string.find(message, "/e", 1, true) == 1
		local v = _K.Service.TextChat.ChatVersion
		if
			_K.Data.settings.chatCommands ~= false
			and ((v == Enum.ChatVersion.TextChatService and emote) or v == Enum.ChatVersion.LegacyChatService)
		then
			_K.Remote.Command:FireClient(player, message)
		end
		if emote then
			return
		end
		_K.log(message, "CHAT", player.UserId, true)
	end)
end

local _initialized
function _K.initialize(settingsObject: ModuleScript | { [string]: any }, addons: Folder?, legacyConfig: Folder?)
	if _initialized then
		return _K
	end
	_initialized = true
	local initStart = os.clock()

	if typeof(legacyConfig) == "Instance" then
		legacyConfig.Parent = script
	end

	if typeof(settingsObject) == "Instance" and settingsObject:IsA("ModuleScript") then
		settingsObject = require(settingsObject)
	end

	local settings = settingsObject :: { [string]: any }
	_K.Data.settingsModuleData = settings

	if type(settings.prefix) == "string" then
		settings.prefix = { settings.prefix }
	end

	-- format array role hierarchy
	do
		if settings.roles.default then
			settings.roles.everyone = settings.roles.default
			settings.roles.default = nil
		end
		local roles = {}
		for rank, definition in settings.roles do
			if definition.permissions.targetOthers == nil then
				definition.permissions.targetOthers = not definition.onlyTargetSelf
			end
			if type(rank) == "number" then
				if definition._key == "default" then
					definition._key = "everyone"
				end
				settings.roles[rank] = nil
				definition._rank = rank - 1
				roles[definition._key] = definition
			end
		end
		Util.Table.merge(settings.roles, roles)
	end

	_K.Data.bans = table.clone(settings.bans)
	_K.Data.roles = table.clone(settings.roles)
	for key, value in settings do
		if _K.Data.settings[key] ~= nil then
			_K.Data.settings[key] = value
		end
	end

	if settings.commands and #settings.commands > 0 then
		for role, commands in settings.commands do
			local roleData = _K.Data.roles[role]
			if roleData then
				if roleData.commands then
					_K.Util.Table.merge(roleData.commands, commands)
				else
					roleData.commands = commands
				end
			end
		end
	end

	local dataStoreScope = "_K_0.1" -- WARN: REQUIRES DATA MIGRATION WHEN CHANGED
	if game.PrivateServerId ~= "" and game.PrivateServerOwnerId ~= 0 then
		for role, users in settings.userRoles do
			if table.find(users, game.PrivateServerOwnerId) then
				dataStoreScope ..= game.PrivateServerOwnerId
				break
			end
		end
	end

	task.spawn(_K.Data.initialize, dataStoreScope)

	-- register creator
	task.spawn(function()
		if game.CreatorType == Enum.CreatorType.Group then
			_K.groupId = game.CreatorId
			local ok, result = Util.Retry(function()
				return _K.Service.Group:GetGroupInfoAsync(game.CreatorId)
			end)
			_K.creatorId = if ok then result.Owner.Id else 0
		else
			_K.creatorId = game.CreatorId
		end
		_K.Data.creatorId = _K.creatorId
		_K.Auth.userRoleAdd(_K.creatorId, "creator")
	end)

	-- define user roles
	for role, users in settings.userRoles do
		for _, user in users do
			task.spawn(function()
				local userId = if type(user) == "string"
					then _K.Service.Players:GetUserIdFromNameAsync(user)
					elseif (tonumber(user) or 0) > 0 then tonumber(user)
					else nil
				if userId then
					task.spawn(_K.Auth.userRoleAdd, userId, role)
				end
			end)
		end
	end

	function _K.setupPurchasables(purchasables, roleKey)
		for id, role in purchasables do
			local roleData = _K.Data.roles[role]
			if roleData then
				roleData[roleKey] = roleData[roleKey] or {}
				table.insert(roleData[roleKey], id)
			end
		end
	end

	if settings.assetRoles then
		Util.Table.deepMerge(_K.Data.async.asset, settings.assetRoles, true)
		_K.setupPurchasables(settings.assetRoles, "assets")
	end
	if settings.gamePassRoles then
		Util.Table.deepMerge(_K.Data.async.gamepass, settings.gamePassRoles, true)
		_K.setupPurchasables(settings.gamePassRoles, "gamepasses")
	end
	if settings.subscriptionRoles then
		Util.Table.deepMerge(_K.Data.async.subscription, settings.subscriptionRoles, true)
		_K.setupPurchasables(settings.subscriptionRoles, "subscriptions")
	end

	if settings.groupRoles then
		_K.Util.Table.deepMerge(_K.Data.async.group, settings.groupRoles, true)
	end

	if settings.friendRoles and #settings.friendRoles > 0 then
		task.spawn(function()
			local friendPages = _K.Service.Players:GetFriendsAsync(_K.creatorId)
			for item, _pageNo in Util.iterPageItems(friendPages) do
				if item.Id then
					for _, role in settings.friendRoles do
						_K.Auth.userRoleAdd(item.Id, role)
					end
				end
			end
		end)
	end

	_K.Service.Marketplace.PromptGamePassPurchaseFinished:Connect(function(player, gamePassId, purchaseSuccess)
		if not purchaseSuccess then
			return
		end
		_K.log(`bought gamepass {gamePassId}`, "PURCHASE", player.UserId)
		for id, roles in _K.Data.async.gamepass do
			if gamePassId ~= id then
				continue
			end
			local rolesAdded = {}
			for _, role in roles do
				local roleAdded = _K.Auth.userRoleAdd(player.UserId, role)
				if roleAdded then
					local roleData = _K.Data.roles[role]
					table.insert(rolesAdded, `<b><font color="{roleData.color}">{roleData.name}</font></b>`)
				end
			end

			if player and #rolesAdded > 0 then
				local prefix = _K.getCommandPrefix(player.UserId)
				_K.Remote.Notify:FireClient(player, {
					Text = `You got the {table.concat(rolesAdded, ", ")} role{if #rolesAdded > 1 then "s" else ""}!\nSay <b>{prefix}cmds</b> or <b>{prefix}info</b> for details.`,
					From = "_K",
				})
			end
		end
	end)

	-- addons
	local serverAddons = Instance.new("Folder", _K.Service.ServerStorage)
	serverAddons.Name = "_KServerAddons"

	local sharedAddons = Instance.new("Folder", script)
	sharedAddons.Name = "Addons"

	local function loadAddons(list)
		for _, object in list do
			if object:IsA("ModuleScript") then
				if string.find(object.Name, "Server", 1, true) then
					object.Parent = serverAddons
					task.spawn(function()
						require(object)(_K)
					end)
				elseif not string.find(object.Name, "Client", 1, true) then
					object.Parent = sharedAddons
					task.spawn(function()
						require(object)(_K)
					end)
				else
					object.Parent = sharedAddons
				end
			else
				loadAddons(object:GetChildren())
			end
		end
	end

	loadAddons(script.DefaultAddons:GetChildren())
	loadAddons(_K.Service.Collection:GetTagged(_K._addonTag))
	if addons and not addons:HasTag(_K._addonTag) then
		loadAddons(addons:GetChildren())
	end

	script.Name = "Kohl's Admin Source"
	script.Parent = _K.Service.ReplicatedStorage

	-- enable client
	Client.Enabled = true

	-- fix wally renaming nested default.project.json
	local wallyIsBroken = Client:FindFirstChild("kohls-admin")
	if wallyIsBroken then
		wallyIsBroken.Name = "TopbarPlus"
	end

	-- server network events

	_K.Remote.Init.OnServerEvent:Connect(function(player)
		local bans = _K.Auth.hasCommand(player.UserId, "ban") and _K.Data.bans
		local logs = _K.Auth.hasPermission(player.UserId, "serverlogs") and _K.Data.logs
		local members = if _K.Auth.hasCommand(player.UserId, "members")
			then _K.Data.members
			else {
				[tostring(player.UserId)] = _K.Data.members[tostring(player.UserId)],
			}
		local servers = (_K.Auth.hasCommand(player.UserId, "place") or _K.Auth.hasCommand(player.UserId, "unreserve"))
			and _K.Data.reservedServers

		_K.Remote.Init:FireClient(player, bans, logs, members, _K.Data.roles, _K.Data.settings, servers)
		player:SetAttribute("_K_READY", true)

		if
			settings.vip
			and settings.gameHubEnabled
			and not _K.Service.Http.HttpEnabled
			and _K.Auth.hasPermission(player.UserId, "settings")
		then
			task.delay(2, function()
				_K.Remote.Notify:FireClient(player, {
					From = "_K",
					Text = `Your game is unable to participate in the <b>Kohl's Admin Games Hub</b> because <b><font color='#f00'>HTTP Requests are disabled in your game settings</font></b>.\n\n<i><font transparency='0.5'>Enable HTTP Requests in your Roblox game settings to avoid missing out on free advertising and other benefits!</font></i>`,
				})
			end)
		end
	end)

	_K.Remote.Command.OnServerEvent:Connect(function(player: Player, message: string)
		_K.Process.runCommands(_K, player.UserId, message)
	end)

	-- handle custom command prefix
	_K.Remote.PlayerPrefix.OnServerEvent:Connect(function(player, prefix)
		_K.Data.settings.playerPrefix[player.UserId] = prefix
	end)

	_K.Remote.Settings.OnServerEvent:Connect(function(player, changes)
		if not _K.Auth.hasPermission(player.UserId, "settings") then
			return
		end

		local changeStrings = {}
		for key, value in changes do
			if _K.Data.settings[key] == nil then
				continue
			end
			_K.Data.settings[key] = value
			table.insert(changeStrings, `[{key}]: {value}`)

			local cacheValue, valueType = value, typeof(value)
			if valueType == "Color3" then
				cacheValue = { "color", value.R, value.G, value.B }
			elseif valueType == "EnumItem" then
				cacheValue = { "enum", tostring(value.EnumType), value.Name }
			elseif valueType == "UDim" then
				cacheValue = { "udim", value.Scale, value.Offset }
			end

			_K.Data.Cache.settings[key] = cacheValue
		end
		for _, toPlayer in _K.Service.Players:GetPlayers() do
			if toPlayer ~= player then
				_K.Remote.Settings:FireClient(toPlayer, changes)
			end
		end
		_K.log(`changed settings: {table.concat(changeStrings, " ")}`, "COMMAND", player.UserId)
	end)

	-- handle unban events
	_K.Remote.Unban.OnServerEvent:Connect(function(player, userId)
		local ban = _K.Data.bans[tostring(userId)]
		if ban and _K.Auth.hasCommand(player.UserId, "unban") then
			_K.log(`{_K.getCommandPrefix()}unban {userId}`, "COMMAND", player.UserId)
			_K.Auth.unbanUsers({ userId }, player.UserId)
		end
	end)

	-- server hooks

	_K.Util.SafePlayerAdded(playerAdded)
	_K.Service.Players.PlayerRemoving:Connect(function(player)
		task.spawn(_K.log, "left the server.", "LEAVE", player.UserId)
	end)

	task.spawn(_K.log, `Initialized in {math.round((os.clock() - initStart) * 1000)} ms`, "DEBUG")
	_K.Hook.init:Fire()

	return _K
end

export type _K = typeof(_K)

task.spawn(_K.log, `Required in {math.round((os.clock() - requireStart) * 1000)} ms`, "DEBUG")

return _K
