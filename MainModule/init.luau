--------------------------
-- START OF SHARED CODE --
--------------------------
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")

local Util = require(script:WaitForChild("Util"))

export type Log = Util.Log
export type LogType = Util.LogType
export type Logger = Util.Logger

--- @within _K
--- @type Hook "log" | "preCommand" | "postCommand"
export type Hook = "log" | "preCommand" | "postCommand"

--- @within _K
--- @prop Flux Flux

--- @within _K
--- @prop Auth Auth

--- @within _K
--- @prop Process Process

--- @within _K
--- @prop Registry Registry

--- @within _K
--- @prop Util Util

--- @within _K
--- @prop logger Logger

--- @within _K
--- @prop hook { [Hook]: RBXScriptSignal }

--- @within _K
--- @prop bans { [string]: {any} }

--- @within _K
--- @prop settings { [string]: {any} }

--- @within _K
--- @prop logs { Log }

--- @class _K
local _K = {
	IsClient = RunService:IsClient(),
	IsServer = RunService:IsServer(),
	IsStudio = RunService:IsStudio(),

	-- modules
	Flux = require(script:WaitForChild("Flux")),
	Data = require(script:WaitForChild("Data")),
	Auth = require(script:WaitForChild("Auth")),
	Hook = require(script:WaitForChild("Hook")),
	Logger = require(script:WaitForChild("Logger")),
	Process = require(script:WaitForChild("Process")),
	Registry = require(script:WaitForChild("Registry")),
	Remote = require(script:WaitForChild("Remote")),
	UI = require(script:WaitForChild("Flux"):WaitForChild("UI")),
	Util = Util,

	logger = Util.Logger.new(),
	client = nil,
	pinnedAnnouncement = nil,

	playerPrefix = {},
	_serverLock = false,
}

-- shorthand
_K.creatorId = _K.Data.creatorId
_K.log = _K.Logger.log
_K.logger = _K.Logger.logger
_K.Services = _K.Util.Services

-- register initial UI children
if _K.IsClient then
	_K.UI.registerChildren()
end

function _K.filterMethod(from: number)
	return if Util.Services.Players:GetPlayerByUserId(from)
		then "GetChatForUserAsync"
		else "GetNonChatStringForBroadcastAsync"
end

--- Filters a message with [TextService.FilterStringAsync]
function _K.filterMessage(message: string, from: number, to: number, filterContext: Enum.TextFilterContext?): string
	if from == to then
		return message
	end
	local ok, result = pcall(
		TextService.FilterStringAsync,
		TextService,
		message,
		from,
		filterContext or Enum.TextFilterContext.PublicChat
	)
	if ok then
		ok, result = pcall(result[_K.filterMethod(from)], result, to)
		if ok then
			return result
		end
	end
	return `TextService filtering failed: {result}`
end

-- register types
for _, child in script.DefaultTypes:GetChildren() do
	require(child)(_K)
end

-- register commands
for _, child in script.DefaultCommands:GetChildren() do
	_K.Registry.registerCommandModule(_K, child)
end

-- register loader addons and settings
if _K.IsServer then
	local K_LOADER = shared._K_LOADER
	local addons = K_LOADER:FindFirstChild("Addons")
	local serverAddons = Instance.new("Folder", K_LOADER)
	serverAddons.Name = "ServerAddons"

	local settings = K_LOADER:FindFirstChild("Settings")
	if settings then
		settings.Parent = script
		_K.loaderSettings = require(settings)
	end

	if addons then
		for _, addon in addons:GetChildren() do
			if addon:IsA("ModuleScript") then
				if string.find(addon.Name, "Server$") then
					addon.Parent = serverAddons
					task.spawn(function()
						require(addon)(_K)
					end)
				elseif not string.find(addon.Name, "Client$") then
					task.spawn(function()
						require(addon)(_K)
					end)
				end
			end
		end
		addons.Parent = script
	end
elseif _K.IsClient then -- TODO: load after client.luau instead lol
	_K._addons = script:FindFirstChild("Addons")
	_K.loaderSettings = require(script:WaitForChild("Settings") :: any)
end

-- loader settings
_K.Data.settings.prefix = _K.loaderSettings.prefix
_K.Data.settings.vip = _K.loaderSettings.vip
_K.Data.settings.vipGameCatalogEnabled = _K.loaderSettings.vipGameCatalogEnabled

if not _K.IsServer then
	return _K
end
--------------------------
-- START OF SERVER CODE --
--------------------------

-- TODO: warn creator and developers to change the datastore key if unchanged
_K.Data.initialize(_K.loaderSettings.dataStoreKey)

-- assign creator role
if _K.creatorId > 0 then
	_K.Auth.userRoleAdd(_K.creatorId, "creator")
end

-- loader settings cont.

-- define main roles
for role, users in _K.loaderSettings.roles do
	for _, userId in users do
		_K.Auth.userRoleAdd(userId, role)
	end
end

-- gamepass and group roles
_K.Util.Table.deepMerge(_K.Data.async.gamepass, _K.loaderSettings.gamePassRoles)
_K.Util.Table.deepMerge(_K.Data.async.group, _K.loaderSettings.groupRoles)

-- give roles on gamepass purchase
_K.Services.MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamePassId, purchaseSuccess)
	if not purchaseSuccess then
		return
	end
	for id, roles in _K.loaderSettings.gamePassRoles do
		if gamePassId ~= id then
			continue
		end
		for _, role in roles do
			_K.Auth.userRoleAdd(player.UserId, role)
		end
	end
end)

-- TODO: include Loader settings then include datastore settings to override

-- network test
_K.Remote.Init.OnServerEvent:Connect(function(player)
	-- send their own player permissions always for clientside validation
	-- TODO: make sure data is network safe!

	local bans, logs = {}, table.create(#_K.Data.logs)
	for i, ban in _K.Data.bans do
		local reason = if ban[4] then _K.filterMessage(ban[2], ban[4], player.UserId) else ban[2]
		bans[i] = { ban[1], reason, ban[3], ban[4] }
	end
	for i, log in _K.Data.logs do
		local text = if log.from then _K.filterMessage(log.text, log.from, player.UserId) else log.text
		logs[i] = { text, log.level, log.time, log.from }
	end

	_K.Remote.Init:FireClient(player, bans, logs, _K.Data.members, _K.Data.settings)
end)

script.Parent = _K.Services.ReplicatedStorage
script.Name = "Kohl's Admin Source"

-- enable client
script.Client.Enabled = true

-- handle custom command prefix
_K.Remote.Prefix.OnServerEvent:Connect(function(player, prefix)
	_K.playerPrefix[player.UserId] = prefix
end)

local function playerAdded(player: Player)
	if _K.Services.RunService:IsStudio() then
		_K.Auth.userRoleAdd(player.UserId, "creator")
	end

	for _, role in _K.loaderSettings.freeAdmin do
		_K.Auth.userRoleAdd(player.UserId, role)
	end

	-- group admin and gamepass roles
	_K.Auth.userAsyncRoles(player.UserId, true)

	if _K.Auth.banHandler(player) then
		return
	end

	if _K._serverLock and _K.Auth.getRank(player.UserId) < 2 then
		player:Kick(`Server has been locked by {_K._serverLock}`)
		return
		-- allows those with higher than vip perms
	end
	player.Chatted:Connect(function(message: string)
		_K.log(message, "CHAT", player.UserId)
	end)

	if _K.Data.settings.announcement then
		local message, from = unpack(_K.Data.settings.announcement)
		_K.Remote.Announce:FireClient(player, message, from)
	end
end

_K.Services.Players.PlayerAdded:Connect(playerAdded)
-- if any players join before PlayerAdded connection
for _, player in _K.Services.Players:GetPlayers() do
	playerAdded(player)
end

_K.Remote.Command.OnServerEvent:Connect(function(player: Player, message: string, chatted: boolean?)
	_K.Process.runCommands(_K, player.UserId, message, chatted)
end)

_K.Remote.Setting.OnServerEvent:Connect(function(player, key, value)
	if not _K.Auth.hasPermission(player.UserId, "settings") then
		return
	end

	_K.Data.settings[key] = value

	local cacheValue = value
	if typeof(value) == "Color3" then
		cacheValue = { "color", value.R, value.G, value.B }
	end

	_K.Data.Cache.settings[key] = cacheValue
	_K.Data.pendingSaveMain = true

	for _, toPlayer in _K.Services.Players:GetPlayers() do
		if toPlayer ~= player then
			_K.Remote.Setting:FireClient(toPlayer, key, value)
		end
	end
end)

_K.spectators = {}
_K.Remote.SpectateSubject.OnServerEvent:Connect(function(player: Player, cframe: CFrame)
	if not _K.spectators[player] then
		return
	end
	for _, player in _K.spectators[player] do
		_K.Remote.Spectate:FireClient(player, cframe)
	end
end)

local subscribeSuccess, subscribeConnection = pcall(function()
	return Util.Services.MessagingService:SubscribeAsync("KA_Announcement", function(message)
		if type(message.Data) ~= "table" then
			_K.Data.settings.announcement = false
			return
		end

		local oldMsg, oldFrom
		if _K.Data.settings.announcement then
			oldMsg, oldFrom = unpack(_K.Data.settings.announcement)
		end

		local msg, from = unpack(message.Data)
		if msg ~= oldMsg or from ~= oldFrom then
			_K.Data.settings.announcement = message.Data
			_K.Remote.Announce:FireAllClients(unpack(message.Data))
		end
	end)
end)
if subscribeSuccess then
	game:BindToClose(function()
		subscribeConnection:Disconnect()
	end)
end

-- NOTE: shouldn't network system logs to other servers, ideally only command and error logs
_K.log("Server initialized.", "INFO")

return _K
