--- @class MainModule
if shared._K_INTERFACE then
	return shared._K_INTERFACE
end

--------------------------
-- START OF SHARED CODE --
--------------------------
local RunService = game:GetService("RunService")

local Client = script:WaitForChild("Client")
local LoggerModule = script:WaitForChild("Logger")
local UtilModule = script:WaitForChild("Util")

local requireStart = os.clock()
local Logger = require(LoggerModule)
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

	VERSION = script:WaitForChild("VERSION").Value,

	-- modules
	Logger = Logger,
	Util = Util,
	Data = require(script:WaitForChild("Data")),
	Flux = require(script:WaitForChild("Flux")),
	Hook = require(script:WaitForChild("Hook")),
	Remote = require(script:WaitForChild("Remote")),
	UI = require(Client:WaitForChild("UI")),

	-- core modules
	Auth = require(script:WaitForChild("Auth")),
	Process = require(script:WaitForChild("Process")),
	Registry = require(script:WaitForChild("Registry")),
	VIP = require(script:WaitForChild("VIP")),

	client = nil,
	pinnedAnnouncement = nil,

	cleanupCommands = {},
	displayNames = {},
	playerPrefix = {},
	_serverLock = false,
}

shared._K_INTERFACE = _K

-- shorthand
_K.log = _K.Logger.log
_K.logger = _K.Logger.logger
_K.Services = _K.Util.Services

-- register initial UI children
if _K.IsClient then
	local uiRegisterStart = os.clock()
	_K.UI.registerChildren()
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

if not _K.IsServer then
	task.spawn(_K.log, `Required in {math.round((os.clock() - requireStart) * 1000)} ms`, "DEBUG")
	return _K
end
--------------------------
-- START OF SERVER CODE --
--------------------------

local function playerAdded(player: Player)
	task.spawn(_K.log, "joined the server.", "JOIN", player.UserId)
	if _K.Services.RunService:IsStudio() then
		_K.Auth.userRoleAdd(player.UserId, "creator")
	end

	for _, role in _K.Data.loaderSettings.freeAdmin do
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
	end

	player.Chatted:Connect(function(message: string)
		_K.log(Util.String.filterForBroadcast(message, player.UserId), "CHAT", player.UserId)
	end)

	if _K.Data.settings.announcement then
		local message, from = unpack(_K.Data.settings.announcement)
		_K.Remote.Announce:FireClient(player, message, from)
	end
end

local _initialized
function _K.initialize(loaderSettings: { [string]: any }, addons: Folder?, requireId: boolean?)
	if _initialized then
		return _K
	end
	_initialized = true
	local initStart = os.clock()

	if loaderSettings then
		loaderSettings.Parent = script
		-- TODO: warn creator and developers to change the datastore key if unchanged
		_K.Util.Table.merge(_K.Data.loaderSettings, loaderSettings)
		_K.Data.settings.prefix = loaderSettings.prefix
		_K.Data.settings.vip = loaderSettings.vip
		_K.Data.settings.gameHubEnabled = loaderSettings.gameHubEnabled
		_K.Data.settings.dashboardButtonRank = loaderSettings.dashboardButtonRank

		task.spawn(_K.Data.initialize, loaderSettings.dataStoreKey)

		-- register creator
		task.spawn(function()
			if game.CreatorType == Enum.CreatorType.Group then
				local ok, result = Util.Retry(function()
					return Util.Services.GroupService:GetGroupInfoAsync(game.CreatorId)
				end, 1, 1)
				if ok then
					_K.creatorId = result.Owner.Id
				end
			else
				_K.creatorId = game.CreatorId
			end
			_K.Data.creatorId = _K.creatorId
			_K.Auth.userRoleAdd(_K.creatorId, "creator")
		end)

		-- define main roles
		for role, users in loaderSettings.roles do
			for _, userId in users do
				_K.Auth.userRoleAdd(userId, role)
			end
		end

		-- gamepass and group roles
		_K.Util.Table.deepMerge(_K.Data.async.gamepass, loaderSettings.gamePassRoles)
		_K.Util.Table.deepMerge(_K.Data.async.group, loaderSettings.groupRoles)
	end

	if addons then
		local serverAddons = Instance.new("Folder", Util.Services.ServerStorage)
		serverAddons.Name = "_KServerAddons"

		if addons then
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
	end

	if requireId then
		script.Parent = _K.Services.ReplicatedStorage
		script.Name = "Kohl's Admin Source"
	end

	-- enable client
	Client.Enabled = true

	-- fix wally renaming nested default.project.json
	local wallyIsBroken = Client:FindFirstChild("kohls-admin")
	if wallyIsBroken then
		wallyIsBroken.Name = "TopbarPlus"
	end

	-- server network events

	_K.Remote.Init.OnServerEvent:Connect(function(player)
		local bans = (_K.Auth.hasPermission(player.UserId, "ban") or _K.Auth.hasPermission(player.UserId, "kick"))
			and _K.Data.bans
		local logs = _K.Auth.hasPermission(player.UserId, "logs") and _K.Data.logs
		_K.Remote.Init:FireClient(player, _K.Data.members, _K.Data.settings, bans, logs, _K.Data.roles)
	end)

	_K.Remote.Command.OnServerEvent:Connect(function(player: Player, message: string, chatted: boolean?)
		_K.Process.runCommands(_K, player.UserId, message, chatted)
	end)

	-- handle custom command prefix
	_K.Remote.Prefix.OnServerEvent:Connect(function(player, prefix)
		_K.playerPrefix[player.UserId] = prefix
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

	-- server hooks

	_K.Hook.logFiltered:Connect(function(log)
		for _, player in _K.Util.Services.Players:GetPlayers() do
			if _K.Auth.hasPermission(player.UserId, "logs") then
				_K.Remote.Log:FireClient(player, log)
			end
		end
	end)

	-- gamepass roles
	_K.Services.MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamePassId, purchaseSuccess)
		if not purchaseSuccess then
			return
		end
		for id, roles in _K.Data.async.gamepass do
			if gamePassId ~= id then
				continue
			end
			for _, role in roles do
				_K.Auth.userRoleAdd(player.UserId, role)
			end
		end
	end)

	_K.Util.SafePlayerAdded(playerAdded)
	_K.Util.Services.Players.PlayerRemoving:Connect(function(player)
		task.spawn(_K.log, "left the server.", "LEAVE", player.UserId)
	end)

	task.spawn(_K.log, `Initialized in {math.round((os.clock() - initStart) * 1000)} ms`, "DEBUG")

	return _K
end

export type _K = typeof(_K)

task.spawn(_K.log, `Required in {math.round((os.clock() - requireStart) * 1000)} ms`, "DEBUG")

return _K
