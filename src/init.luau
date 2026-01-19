-- src/init.luau
--- @class MainModule
if shared._K_INTERFACE then
	return shared._K_INTERFACE
end

local RunService = game:GetService("RunService")
local requireStart = os.clock()

local Client = script:WaitForChild("Client")
local Server = RunService:IsServer() and script:WaitForChild("Server")
local Shared = script:WaitForChild("Shared")

local Util = require(Shared:WaitForChild("Util"))

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

	Logger = Util.Logger.new(true),

	-- modules
	Util = Util,
	Data = require(Shared:WaitForChild("Data")),
	Hook = require(Shared:WaitForChild("Hook")),
	Remote = Util.Remote,
	UI = nil,

	-- submodules
	Flux = require(script:WaitForChild("Flux")),
	Z = require(script:WaitForChild("Z")),

	-- core modules
	Auth = require(Shared:WaitForChild("Auth")),
	Process = require(Shared:WaitForChild("Process")),
	Registry = require(Shared:WaitForChild("Registry")),
	VIP = require(Shared:WaitForChild("VIP")),

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

-- Increase Z scratch buffer size to 4MB
_K.Z.BUFFER = buffer.create(4 * 1024 ^ 2)

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
		local start = os.clock()
		while not _K.Data.roles and os.clock() - start < 10 do
			task.wait()
		end
		if _K.Data.roles then
			_K.Auth.userRoleAdd(_K.creatorId, "creator")
		end
	end
end)

function _K.getCommandPrefix(from: number?)
	if _K.IsClient then
		return _K.client.playerPrefix._value
	end
	return _K.Data.playerPrefix[from] or ";"
end

function _K.removeExcessLogs()
	local logs = _K.Data.logs
	local excess = #logs - _K.Logger.limit
	if excess > 0 then
		_K.Util.Table.fastRemove(logs, 1, excess)
	end
end

function _K.log(text: string, level: LogType, from: number?, filtered: boolean?): Log?
	if _K.Data.logsHidden[from] then
		return
	end
	local log = _K.Logger:log(text, level, from, true)
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
			-- trim for 32KB sync max
			if #log.text > 16 * 1024 then
				log.text = string.sub(log.text, 1, 16 * 1024)
			end
			if from and filtered then
				log.text = Util.String.filterForBroadcast(text, from)
			end
			if
				(level == "CHAT" and _K.Data.settings.saveChatLogs)
				or (
					level == "COMMAND"
					and _K.Data.settings.saveLogs
					and (not from or _K.Data.settings.saveLogsForAllRoles or _K.Auth.hasRestrictedRole(from))
				)
			then
				table.insert(_K.Data.Sync.logs, log)
			end
			for _, player in _K.Service.Players:GetPlayers() do
				if player:GetAttribute("_K_READY") and _K.Auth.hasPermission(player.UserId, "serverlogs") then
					_K.Remote.Log:Fire(player, log)
				end
			end
		elseif _K.client and _K.client.dashboard then
			_K.client.dashboard.Logs:updateList()
		end

		table.insert(_K.Data.logs, log)
		_K.Hook.log:Fire(log)
		_K.removeExcessLogs()
	end)

	return log
end
_K.Logger.logs = _K.Data.logs

function _K.alert(to: number | Player, text: string, isError: boolean?)
	if type(to) == "number" then
		to = _K.Service.Players:GetPlayerByUserId(to)
	end
	if to then
		local props = { Text = text, From = if isError then "_K" else nil }
		if isError then
			props.TextColor3 = Color3.new(1, 0, 0)
			props.Sound = "Call_Leave"
		end
		if _K.IsServer then
			_K.Remote.Notify:Fire(to :: Player, props)
		else
			_K.Notify(props)
		end
	end
end

-- register initial UI children
if _K.IsClient then
	_K.UI = require(Client:WaitForChild("UI"))
	local uiRegisterStart = os.clock()
	_K.UI.registerClasses()
	task.spawn(_K.log, `UI classes registered in {math.round((os.clock() - uiRegisterStart) * 1000)} ms`, "DEBUG")
end

local typeRegisterStart = os.clock()
-- register types
for _, child in Shared.DefaultTypes:GetChildren() do
	require(child)(_K)
end
task.spawn(_K.log, `Default Types registered in {math.round((os.clock() - typeRegisterStart) * 1000)} ms`, "DEBUG")

local commandRegisterStart = os.clock()
-- register commands
for _, child in Shared.DefaultCommands:GetChildren() do
	_K.Registry.registerCommandModule(_K, child)
end
task.spawn(
	_K.log,
	`Default Commands registered in {math.round((os.clock() - commandRegisterStart) * 1000)} ms`,
	"DEBUG"
)

shared._K_INTERFACE = _K

if _K.IsServer then
	require(Server)(_K)
else
	if not _K.IsStudio or IS_DEMO_PLACE then
		print(`🛡️ Running Kohl's Admin v{_K.VERSION} by @Scripth`)
	end
end

task.spawn(_K.log, `Required in {math.round((os.clock() - requireStart) * 1000)} ms`, "DEBUG")

export type _K = typeof(_K)

return _K
