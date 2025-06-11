--- @class MainModule
if shared._K_INTERFACE then
	return shared._K_INTERFACE
end

--------------------------
-- START OF SHARED CODE --
--------------------------
local RunService = game:GetService("RunService")

local requireStart = os.clock()

local Client = script:WaitForChild("Client")
local Server = RunService:IsServer() and script:WaitForChild("Server")

local Util = require(script:WaitForChild("Util"))

export type Log = Util.Log
export type LogType = Util.LogType
export type Logger = Util.Logger
export type Hook = "log" | "preCommand" | "postCommand"

local IS_DEMO_PLACE = game.PlaceId == 2569622788

if Server then
	Server.Parent = Util.Service.ServerStorage
end

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
	Server = Server,
	Tools = Server and Server:WaitForChild("Tools"),

	client = nil,
	pinnedAnnouncement = nil,
	ready = false,
	Notify = nil,

	cleanupCommands = {},
	_serverLock = false,
	_addonTag = "Kohl's Admin Addon",
}

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

	if _K.IsServer then
		_K.Auth.userRoleAdd(_K.creatorId, "creator")
	end
end)

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
	elseif level == "CHAT" or level == "COMMAND" then
		log.fingerprint = table.concat({ text, log.level, log.time, from :: any }, "|")
		_K.Data.logFingerprints[log.fingerprint] = true
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
		while #_K.Data.logs > _K.Logger.limit do
			local removedLog = table.remove(_K.Data.logs, 1)
			_K.Data.logFingerprints[removedLog.fingerprint] = nil
			Util.Defer.wait()
		end
	end)

	return log
end
_K.Logger.logs = _K.Data.logs

function _K.systemNotify(to: number | Player, text: string, isError: boolean?)
	if type(to) == "number" then
		to = _K.Service.Players:GetPlayerByUserId(to)
	end
	if to then
		local props = { Text = text, From = "_K" }
		if isError then
			props.TextColor3 = Color3.new(1, 0, 0)
			props.Sound = "Call_Leave"
		end
		if _K.IsServer then
			_K.Remote.Notify:FireClient(to, props)
		else
			_K.Notify:FireClient(props)
		end
	end
end

-- register initial UI children
if _K.IsClient then
	_K.UI = require(Client:WaitForChild("UI"))
	local uiRegisterStart = os.clock()
	_K.UI.registerDefaultClasses()
	task.spawn(_K.log, `UI classes registered in {math.round((os.clock() - uiRegisterStart) * 1000)} ms`, "DEBUG")
end

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

local function characterAdded(character: Model)
	local player = _K.Service.Players:GetPlayerFromCharacter(character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")

	-- damage logs
	local alive, lastHealth = true, humanoid.Health
	local damageBatch = {}
	local function logDamage(from)
		local damage = damageBatch[from]
		damageBatch[from] = nil
		if not damage then
			return
		end
		damage = math.round(damage)
		if from and from ~= game then
			_K.log(`damaged {player} for {damage} damage.`, "DAMAGE", from.UserId)
		else
			_K.log(`{player} took {damage} damage.`, "DAMAGE", player.UserId)
		end
	end
	local logDamageDebounce = _K.Util.Function.debounce(1, logDamage)
	humanoid.HealthChanged:Connect(function(health)
		if alive then
			local tag = humanoid:FindFirstChild("creator")
			local from = (tag and tag.Value) or game
			local damage = lastHealth - health
			lastHealth = health
			if damage > 0 and health >= 0 then
				damageBatch[from] = (damageBatch[from] or 0) + damage
				logDamageDebounce(from)
			end
		end
	end)

	-- kill logs
	humanoid.Died:Connect(function()
		alive = false
		local tag = humanoid:FindFirstChild("creator")
		local from = tag and tag.Value
		for attacker in damageBatch do
			logDamage(attacker)
		end
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
		_K.log(_K.Util.String.unescapeRichText(message), "CHAT", player.UserId, true)
	end)
end

local _initialized
function _K.initialize(config: Configuration | ModuleScript | { [string]: any }, oldAddonStructure: Folder?)
	if _initialized then
		return _K
	end
	_initialized = true
	local initStart = os.clock()
	_K.LoadScript = require(Server.LoadScript)

	local settings: { [string]: any } = {}
	if typeof(config) == "Instance" then
		if config:IsA("ModuleScript") then
			settings = require(config)
		elseif config:IsA("Configuration") then
			config.Parent = script
			local addons = config:FindFirstChild("Addons")
			addons.Parent = Server
			local settingsModule = config:FindFirstChild("Settings")
			if settingsModule and settingsModule:IsA("ModuleScript") then
				settings = require(settingsModule)
			end
			local studioThemes = config:FindFirstChild("Themes")
			if studioThemes then
				Client.UI.Theme.Themes:ClearAllChildren()
				for _, child in studioThemes:GetChildren() do
					child.Parent = Client.UI.Theme.Themes
				end
			end
		end
	elseif type(config) == "table" then
		settings = config
	end

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

	task.spawn(function() -- populate ban names
		for userId, ban in _K.Data.bans do
			if not ban[1] then
				ban[1] = Util.getUserInfo(userId).Username
			end
		end
	end)

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

	task.spawn(function()
		repeat
			task.wait()
		until _K.creatorId

		_K.Data.SEPARATE_DATASTORE = _K.Data.IS_PRIVATE_SERVER and game.PrivateServerOwnerId ~= _K.creatorId

		local dataStoreScope = "_K_0.1" -- WARN: REQUIRES DATA MIGRATION WHEN CHANGED
		if _K.Data.SEPARATE_DATASTORE then
			for role, users in settings.userRoles do
				if table.find(users, game.PrivateServerOwnerId) then
					dataStoreScope ..= game.PrivateServerOwnerId
					break
				end
			end
		end

		_K.Data.initialize(dataStoreScope)
	end)

	-- define user roles
	for role, users in settings.userRoles do
		for _, user in users do
			task.spawn(function()
				local userId
				if type(user) == "string" then
					local ok, result = _K.Util.Retry(function()
						return _K.Service.Players:GetUserIdFromNameAsync(user)
					end)
					if ok then
						userId = result
					end
				elseif (tonumber(user) or 0) > 0 then
					userId = tonumber(user)
				end
				if userId then
					task.spawn(_K.Auth.userRoleAdd, userId, role)
				end
			end)
		end
	end

	function _K.setupPurchasables(purchasables, key)
		for id, role in purchasables do
			local roleData = _K.Data.roles[role]
			if roleData then
				roleData[key] = roleData[key] or {}
				table.insert(roleData[key], id)
			end
		end
	end

	if settings.assetRoles then
		Util.Table.deepMerge(_K.Data.async.asset, settings.assetRoles, true)
		_K.setupPurchasables(settings.assetRoles, "assets")
	end
	if settings.gamepassRoles then
		Util.Table.deepMerge(_K.Data.async.gamepass, settings.gamepassRoles, true)
		_K.setupPurchasables(settings.gamepassRoles, "gamepasses")
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

	for role, roleData in _K.Data.roles do
		for _, key in { "asset", "gamepass", "subscription" } do
			local id = roleData[key]
			if id then
				local listKey = key .. if string.find(key, "s$", 1, true) then "es" else "s"
				roleData[listKey] = roleData[listKey] or {}
				table.insert(roleData[listKey], id)

				if not _K.Data.async[key][id] then
					_K.Data.async[key][id] = { role }
				else
					table.insert(_K.Data.async[key][id], role)
				end
			end
		end
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
	if oldAddonStructure and not oldAddonStructure:HasTag(_K._addonTag) then
		loadAddons(oldAddonStructure:GetChildren())
	end

	script.Name = "Kohl's Admin Source"
	script.Parent = _K.Service.ReplicatedStorage

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
					Text = `Your game is unable to participate in the <b>Kohl's Admin Games Hub</b> because <b><font color='#{_K.Data.settings.themeInvalid:ToHex()}'>HTTP Requests are disabled in your game settings</font></b>.\n\n<i><font transparency='0.5'>Enable HTTP Requests in your Roblox game settings to avoid missing out on free advertising and other benefits!</font></i>`,
				})
			end)
		end
	end)

	-- enable client
	Client.Enabled = true

	_K.Remote.Command.OnServerEvent:Connect(function(player: Player, message: string)
		_K.Process.runCommands(_K, player.UserId, message)
	end)

	-- handle custom command prefix
	_K.Remote.PlayerPrefix.OnServerEvent:Connect(function(player, prefix)
		_K.Data.settings.playerPrefix[player.UserId] = prefix
	end)

	-- handle changing of settings
	_K.Remote.Settings.OnServerEvent:Connect(function(player, changes)
		local themeAuthority = _K.Data.settings.changeThemeAuthority
		--TODO: make the Client authority save each players' theming

		if not _K.Auth.hasPermission(player.UserId, "settings") then
			return
		end

		local changeStrings = {}
		for key, value in changes do
			if _K.Data.settings[key] == nil then
				continue
			end

			if string.find(key, "theme", 1, true) and (themeAuthority == "Studio") then
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
	_K.ready = true
	_K.Hook.init:Fire()

	return _K
end

export type _K = typeof(_K)

task.spawn(_K.log, `Required in {math.round((os.clock() - requireStart) * 1000)} ms`, "DEBUG")

return _K
