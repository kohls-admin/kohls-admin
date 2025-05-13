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
	.playerPrefix { [Player]: string }
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

	VERSION = Util.String.trim(script:WaitForChild("VERSION").Value),

	-- modules
	Logger = Util.Logger.new(shared._K_DEBUG),
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
	Services = Util.Services,

	client = nil,
	pinnedAnnouncement = nil,

	cleanupCommands = {},
	playerPrefix = {},
	_serverLock = false,
}

function _K.getCommandPrefix(from: number)
	return _K.playerPrefix[from] or _K.Data.settings.prefix
end

function _K.log(text: string, level: LogType, from: number?, filtered: boolean?): Log?
	if _K.Data.logsHidden[from] then
		return
	end
	local log = Util.Logger.log(_K.Logger, text, level, from)
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
			if from and not filtered then
				log.text = Util.String.filterForBroadcast(text, from)
			end
			if level == "COMMAND" and (not from or _K.Auth.getRank(from) > 1) then
				table.insert(_K.Data.Cache.logs, { log.text, log.level, log.time, from, log.name })
			end
			if level == "CHAT" then
				table.insert(_K.Data.Cache.chatLogs, { log.text, log.level, log.time, from, log.name })
			end
			for _, player in _K.Services.Players:GetPlayers() do
				if _K.Auth.hasPermission(player.UserId, "serverlogs") then
					_K.Remote.Log:FireClient(player, log)
				end
			end
		end
		_K.Hook.log:Fire(log)
	end)

	return log
end
_K.Logger.logs = _K.Data.logs

-- Move tools to ServerStorage
if _K.IsServer then
	_K.Tools = script:WaitForChild("Tools")
	_K.Tools.Parent = _K.Services.ServerScriptService
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
	task.spawn(_K.log, `Required in {math.round((os.clock() - requireStart) * 1000)} ms`, "DEBUG")
	return _K
end
--------------------------
-- START OF SERVER CODE --
--------------------------

local function characterAdded(character: Model)
	local player = _K.Services.Players:GetPlayerFromCharacter(character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	humanoid.Died:Connect(function()
		local tag = humanoid:FindFirstChild("creator")
		local killer = tag and tag.Value
		if killer then
			_K.log(`died to {killer}.`, "DEATH", player.UserId, true)
			if typeof(killer) == "Instance" and killer:IsA("Player") then
				_K.log(`killed {player}.`, "KILL", killer.UserId, true)
			end
		else
			_K.log(`died.`, "DEATH", player.UserId, true)
		end
	end)
end

local function playerAdded(player: Player)
	repeat
		task.wait()
	until _K.Data.roles

	task.spawn(_K.log, "joined the server.", "JOIN", player.UserId, true)

	if _K.Auth.banHandler(player) then
		return
	end

	if _K.Services.RunService:IsStudio() then
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
		if
			Util.Services.TextChatService.ChatVersion == Enum.ChatVersion.TextChatService
			and string.find(message, "/e", 1, true) == 1
		then
			local prefix = _K.Data.settings.prefix
			local commandStart = string.find(message, string.format('%s[^%s"`,%%s]', prefix, prefix))
			if commandStart then
				_K.Process.runCommands(_K, player.UserId, string.sub(message, commandStart))
			end
		end
		_K.log(message, "CHAT", player.UserId)
	end)
end

local _initialized
function _K.initialize(settingsObject: ModuleScript | { [string]: any }, addons: Folder?)
	if _initialized then
		return _K
	end
	_initialized = true
	local initStart = os.clock()

	if typeof(settingsObject) == "Instance" and settingsObject:IsA("ModuleScript") then
		settingsObject = require(settingsObject)
	end

	local settings = settingsObject :: { [string]: any }
	_K.Data.settingsModuleData = settings

	-- format array role hierarchy
	for rank, definition in settings.roles do
		if type(rank) == "number" then
			definition._rank = rank
			definition._rank = rank - 1
			settings.roles[definition._key] = definition
			settings.roles[rank] = nil
		end
	end

	_K.Data.bans = settings.bans
	_K.Data.roles = settings.roles
	for key, value in settings do
		if _K.Data.settings[key] ~= nil then
			_K.Data.settings[key] = value
		end
	end

	-- private server datastore
	local dataStoreKey = "_KData"
	if game.PrivateServerId ~= "" and game.PrivateServerOwnerId ~= 0 then
		for role, users in settings.userRoles do
			if table.find(users, game.PrivateServerOwnerId) then
				dataStoreKey ..= game.PrivateServerOwnerId
				break
			end
		end
	end

	task.spawn(_K.Data.initialize, dataStoreKey)

	-- register creator
	task.spawn(function()
		if game.CreatorType == Enum.CreatorType.Group then
			local ok, result = Util.Retry(function()
				return Util.Services.GroupService:GetGroupInfoAsync(game.CreatorId)
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
					then Util.Services.Players:GetUserIdFromNameAsync(user)
					elseif (tonumber(user) or 0) > 0 then tonumber(user)
					else nil
				if userId then
					task.spawn(_K.Auth.userRoleAdd, userId, role)
				end
			end)
		end
	end

	-- gamepass and group roles
	if settings.gamePassRoles then
		_K.Util.Table.deepMerge(_K.Data.async.gamepass, settings.gamePassRoles)
	end
	if settings.groupRoles then
		_K.Util.Table.deepMerge(_K.Data.async.group, settings.groupRoles)
	end

	for role, roleData in _K.Data.roles do
		if roleData.gamepass then
			if not _K.Data.async.gamepass[roleData.gamepass] then
				_K.Data.async.gamepass[roleData.gamepass] = { role }
			else
				table.insert(_K.Data.async.gamepass[roleData.gamepass], role)
			end
		end
	end

	_K.Services.MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamePassId, purchaseSuccess)
		if not purchaseSuccess then
			return
		end
		_K.log(`bought gamepass {gamePassId}`, "PURCHASE", player.UserId, true)
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
				_K.Remote.Notify:FireClient(player, {
					Text = `You got the {table.concat(rolesAdded, ", ")} role{if #rolesAdded > 1 then "s" else ""}!\nSay <b>{_K.Data.settings.prefix}cmds</b> or <b>{_K.Data.settings.prefix}info</b> for details.`,
					From = "_K",
				})
			end
		end
	end)

	if addons then
		for _, child in script.DefaultAddons:GetChildren() do
			child.Parent = addons
		end
	else
		addons = script:WaitForChild("DefaultAddons")
	end

	if addons then
		local serverAddons = Instance.new("Folder", Util.Services.ServerStorage)
		serverAddons.Name = "_KServerAddons"

		for _, addon in addons:GetChildren() do
			if addon:IsA("ModuleScript") then
				if string.find(addon.Name, "Server", 1, true) then
					addon.Parent = serverAddons
					task.spawn(function()
						require(addon)(_K)
					end)
				elseif not string.find(addon.Name, "Client", 1, true) then
					task.spawn(function()
						require(addon)(_K)
					end)
				end
			end
		end
		addons.Parent = script
	end

	script.Name = "Kohl's Admin Source"
	script.Parent = _K.Services.ReplicatedStorage

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

		_K.Remote.Init:FireClient(player, bans, logs, members, _K.Data.roles, _K.Data.settings)

		if
			settings.vip
			and settings.gameHubEnabled
			and not Util.Services.HttpService.HttpEnabled
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
	_K.Remote.Prefix.OnServerEvent:Connect(function(player, prefix)
		_K.playerPrefix[player.UserId] = prefix
	end)

	_K.Remote.Settings.OnServerEvent:Connect(function(player, changes)
		if not _K.Auth.hasPermission(player.UserId, "settings") then
			return
		end

		for key, value in changes do
			if _K.Data.settings[key] == nil then
				continue
			end
			_K.Data.settings[key] = value

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
		for _, toPlayer in _K.Services.Players:GetPlayers() do
			if toPlayer ~= player then
				_K.Remote.Settings:FireClient(toPlayer, changes)
			end
		end
	end)

	-- handle unban events
	_K.Remote.Unban.OnServerEvent:Connect(function(player, userId)
		local ban = _K.Data.bans[tostring(userId)]
		if ban and _K.Auth.hasCommand(player.UserId, "unban") then
			_K.log(`{_K.Data.settings.prefix}unban {userId}`, "COMMAND", player.UserId, true)
			_K.Auth.unbanUsers({ userId }, player.UserId)
		end
	end)

	-- server hooks

	_K.Util.SafePlayerAdded(playerAdded)
	_K.Util.Services.Players.PlayerRemoving:Connect(function(player)
		task.spawn(_K.log, "left the server.", "LEAVE", player.UserId, true)
	end)

	task.spawn(_K.log, `Initialized in {math.round((os.clock() - initStart) * 1000)} ms`, "DEBUG")
	_K.Hook.init:Fire()

	return _K
end

export type _K = typeof(_K)

task.spawn(_K.log, `Required in {math.round((os.clock() - requireStart) * 1000)} ms`, "DEBUG")

return _K
