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
	Process = require(script:WaitForChild("Process")),
	Registry = require(script:WaitForChild("Registry")),
	Remote = require(script:WaitForChild("Remote")),
	Util = Util,

	logger = Util.Logger.new(),
	client = nil,

	playerPrefix = {},
	_serverLock = false,
}

-- use Data log table
_K.logger.logs = _K.Data.logs

-- shorthand
_K.Services = _K.Util.Services

-- assign CreatorId
if game.CreatorType == Enum.CreatorType.Group then
	local ok, result = pcall(_K.Services.GroupService.GetGroupInfoAsync, _K.Services.GroupService, game.CreatorId)
	if ok then
		_K.creatorId = result.Owner.Id
	end
else
	_K.creatorId = game.CreatorId
end

--- The core log function
function _K.log(text: string, level: LogType, from: number?): Log
	-- fire this log to all clients that are authorized!
	-- TODO: make sure they pull logs on client init
	-- make sure to sort by timestamp for new datastore entries

	local log = _K.logger:log(text, level, from)

	_K.Hook.log:Fire(log)

	if _K.IsServer then
		if from then
			local ok, result = pcall(
				TextService.FilterStringAsync,
				TextService,
				text,
				from,
				Enum.TextFilterContext[if _K.Auth.defaultRole.logs then "PublicChat" else "PrivateChat"]
			)
			if ok then
				for _, player in _K.Services.Players:GetPlayers() do
					local success, filtered = pcall(result.GetChatForUserAsync, result, player.UserId)
					if success then
						_K.Remote.Log:FireClient(player, { filtered, level, log.time, from })
					else -- retry
					end
				end
			else
				-- TODO: if not ok, retry
			end
		else
			_K.Remote.Log:FireAllClients({ log.text, log.level, log.time, log.from })
		end
	end

	return log
end

--- Filters a message with [TextService.FilterStringAsync]
function _K.filterMessage(message: string, from: number, to: number): string
	local ok, result = pcall(
		TextService.FilterStringAsync,
		TextService,
		message,
		from,
		Enum.TextFilterContext[if _K.Data.defaultRole.logs then "PublicChat" else "PrivateChat"]
	)
	if ok then
		ok, result = pcall(result.GetChatForUserAsync, result, to)
		if ok then
			return result
		end
	end
	return "TextService filtering failed."
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
_K.Data.defaultRole.admin = _K.loaderSettings.freeAdmin

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

-- define main roles
for role, users in _K.loaderSettings.roles do
	for _, userId in users do
		_K.Auth.userRoleAdd(userId, role)
	end
end

-- gamepass and group roles
_K.Util.deepMergeTable(_K.Data.async.gamepass, _K.loaderSettings.gamePassRoles)
_K.Util.deepMergeTable(_K.Data.async.group, _K.loaderSettings.groupRoles)

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

	_K.Remote.Init:FireClient(player, _K.Auth, bans, logs, _K.Data.members, _K.Data.settings)
end)

script.Parent = _K.Services.ReplicatedStorage
script.Name = "Kohl's Admin Source"

-- enable client
script.Client.Enabled = true

-- handle custom command prefix
_K.Remote.Prefix.OnServerEvent:Connect(function(player, prefix)
	_K.playerPrefix[player.UserId] = prefix
end)

-- handle player chatting
local function playerAdded(player: Player)
	-- studio testing roles
	if _K.Services.RunService:IsStudio() then
		_K.Auth.userRoleAdd(player.UserId, "creator")
	end

	_K.Auth.userAsyncRoles(player.UserId, true)
	if _K.Auth.banHandler(player) then
		return
	end
	if _K._serverLock and _K.Auth.getRank(player.UserId) < 2 then
		player:Kick(`Server has been locked by {_K._serverLock}`)
		return
		-- allow those with higher than vip perms
	end
	player.Chatted:Connect(function(message: string)
		_K.Process.runCommands(_K, player.UserId, message)
	end)
end

_K.Services.Players.PlayerAdded:Connect(playerAdded)
-- if any players join before PlayerAdded connection
for _, player in _K.Services.Players:GetPlayers() do
	playerAdded(player)
end

_K.Remote.Command.OnServerEvent:Connect(function(player: Player, message: string)
	_K.Process.runCommands(_K, player.UserId, message)
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

-- NOTE: probably shouldn't network system logs to other servers, ideally only command and error logs
_K.log("Server initialized.", "INFO")

return _K
