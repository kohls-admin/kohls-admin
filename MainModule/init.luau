--------------------------
-- START OF SHARED CODE --
--------------------------
local TextChatService = game:GetService("TextService")

local Util = require(script.Util)

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
	-- modules
	Flux = require(script.Flux),
	Auth = require(script.Auth),
	Process = require(script.Process),
	Registry = require(script.Registry),
	Util = Util,

	logger = Util.Logger.new(),
	client = nil,
	hook = {
		log = Util.SignalGood.new(),
		preCommand = Util.SignalGood.new(),
		postCommand = Util.SignalGood.new(),
	},

	-- key used to check when global data has been changed for a save cycle
	-- TODO: account for race conditions... use a timestamp?
	_lastUpdate = 0,
	_dataUpdate = 0,

	bans = {
		-- [UserId] = {Username, Reason, Timestamp}
		-- Username is the last known username of the user when they were banned
		-- TODO: progressively parse and update each name!
		-- if Timestamp is -1 the ban is permanent
		-- if Timestamp is nil the ban is for the server session only
		-- saves only if Timestamp isn't nil
		["1"] = { "Roblox", "He noob.", -1, 44391621, "Scripth" },
		["2"] = { "John Doe", "He been noob.", nil, 44391621, "Scripth" },
		["3"] = { "Jane Doe", "She was a noob.", nil, 44391621, "Scripth" },
		["5"] = { "Jack Doe", "Wow!", 1720922623, 44391621, "Scripth" },
	},

	playerPrefix = {},

	-- configuration
	settings = {
		prefix = ":",
		vip = true,
		mutableHooks = false,
	},
}

_K.logs = _K.logger.logs

-- shorthand utility
_K.Services = _K.Util.Services
_K.Remote = _K.Util.Remote

_K.IsServer = _K.Services.RunService:IsServer()
_K.IsClient = _K.Services.RunService:IsClient()

-- assign CreatorId
if game.CreatorType == Enum.CreatorType.Group then
	local groupInfo = _K.Services.GroupService:GetGroupInfoAsync(game.CreatorId)
	_K.creatorId = groupInfo.Owner.Id
else
	_K.creatorId = game.CreatorId
end

--- The core log function
function _K.log(text: string, level: LogType, from: Player? | number?): Log
	-- fire this log to all clients that are authorized!
	-- TODO: make sure they pull logs on client init
	-- make sure to sort by timestamp for new datastore entries
	local userId = if typeof(from) == "Instance" then from.UserId else from

	local log = _K.logger:log(text, level, userId)

	_K.hook.log:Fire(log)

	if _K.IsServer then
		if userId then
			local ok, result = pcall(
				TextChatService.FilterStringAsync,
				TextChatService,
				text,
				userId,
				Enum.TextFilterContext[if _K.Auth.defaultRole.logs then "PublicChat" else "PrivateChat"]
			)
			if ok then
				for _, player in _K.Services.Players:GetPlayers() do
					local success, filtered = pcall(result.GetChatForUserAsync, result, player.UserId)
					if success then
						_K.Remote "Log":FireClient(player, { filtered, level, log.time, userId })
					else -- retry
					end
				end
			else
				-- TODO: if not ok, retry
			end
		else
			_K.Remote "Log":FireAllClients(log)
		end
	end

	return log
end

--- Filters a message with [TextChatService.FilterStringAsync]
function _K.filterMessage(message: string, from: number, to: number): string
	local ok, result = pcall(
		TextChatService.FilterStringAsync,
		TextChatService,
		message,
		from,
		Enum.TextFilterContext[if _K.Auth.defaultRole.logs then "PublicChat" else "PrivateChat"]
	)
	if ok then
		ok, result = pcall(result.GetChatForUserAsync, result, to)
		if ok then
			return result
		end
	end
	return "TextChatService filtering failed."
end

--- Generic ban handler
function _K.handleBan(
	userId: number,
	name: string,
	reason: string,
	duration: number,
	fromUserId: number,
	fromName: string
)
	_K.bans[tostring(userId)] = { name, reason, duration, fromUserId, fromName }
	-- network ban to all with filtered season?
	-- _K.filterMessage(reason, fromUserId or game.CreatorId, )
	local ok, result = pcall(
		TextChatService.FilterStringAsync,
		TextChatService,
		reason,
		fromUserId,
		Enum.TextFilterContext.PrivateChat
	)
	if ok then
		for _, player in _K.Services.Players:GetPlayers() do
			local _, filtered = pcall(result.GetChatForUserAsync, result, player.UserId)
			_K.Remote "Ban":FireClient(player, userId, { name, filtered, duration, fromUserId, fromName })
		end
	end
end

-- Flux stateful settings
for key, value in _K.settings do
	_K.settings[key] = _K.Flux.state(value)
end

-- register types
for _, child in script.DefaultTypes:GetChildren() do
	require(child)(_K)
end

-- register commands
for _, child in script.DefaultCommands:GetChildren() do
	_K.Registry.registerCommandModule(child)
end

-- register addons
if _K.IsServer then
	local K_LOADER = shared._K_LOADER
	local addons = K_LOADER:FindFirstChild("Addons")
	local serverAddons = Instance.new("Folder", K_LOADER)
	serverAddons.Name = "ServerAddons"

	local settingsAddon = K_LOADER:FindFirstChild("Settings")
	if settingsAddon then
		settingsAddon.Parent = addons
	end

	if addons then
		for _, addon in addons:GetChildren() do
			if addon:IsA("ModuleScript") then
				if string.find(addon.Name, "Server$") then
					addon.Parent = serverAddons
					require(addon)(_K)
				elseif not string.find(addon.Name, "Client$") then
					require(addon)(_K)
				end
			end
		end
		addons.Parent = script
	end
elseif _K.IsClient then
	local addons = script:FindFirstChild("Addons")
	if addons then
		for _, addon in addons:GetChildren() do
			if addon:IsA("ModuleScript") then
				require(addon)(_K)
			end
		end
	end
end

if not _K.IsServer then
	return _K
end
--------------------------
-- START OF SERVER CODE --
--------------------------

-- TODO: include Loader settings then include datastore settings to override

-- define remotes
for _, remote in { "Init", "Command", "Log" } do
	_K.Remote(remote)
end

-- network test
_K.Remote "Init".OnServerEvent:Connect(function(player)
	-- send their own player permissions always for clientside validation
	-- TODO: make sure data is network safe!

	local bans, logs = {}, table.create(#_K.logs)
	for i, ban in _K.bans do
		local reason = if ban[4] then _K.filterMessage(ban[2], ban[4], player.UserId) else ban[2]
		bans[i] = { ban[1], reason, ban[3], ban[4] }
	end
	for i, log in _K.logs do
		local text = if log.user then _K.filterMessage(log.text, log.user, player.UserId) else log.text
		logs[i] = { text, log.level, log.time, log.user }
	end

	_K.Remote "Init":FireClient(player, _K.Auth, bans, logs, _K.settings)
end)

script.Parent = _K.Services.ReplicatedStorage
script.Name = "Kohl's Admin Source"

-- enable client
script.Client.Enabled = true

local function banHandler(player)
	local banInfo = _K.bans[player.UserId]
	-- TODO: should staff roles bypass bans? add a settings toggle
	if not banInfo or player.UserId == _K.creatorId then
		-- not banned
		return
	end

	local reason, timeStamp = unpack(banInfo, 2)
	local banMessage
	if tonumber(timeStamp) then
		if timeStamp > 0 then
			local timeRemaining = timeStamp - os.time()
			if timeRemaining > 0 then
				banMessage = "You are banned from this experience for " .. _K.Util.ReadableTime(timeRemaining) .. "!"
			else
				-- unbanning
				_K.bans[player.UserId] = nil
				return
			end
		else
			banMessage = "You are permanently banned from this experience!"
		end
	else
		banMessage = "You are banned from this server!"
	end

	player:Kick(if reason then banMessage .. "\n Reason: " .. reason else banMessage)
	return true
end

-- handle custom command prefix
_K.Remote "Prefix".OnServerEvent:Connect(function(player, prefix)
	_K.playerPrefix[player.UserId] = prefix
end)

-- handle player chatting
local function playerAdded(player: Player)
	if banHandler(player) then
		return
	end
	player.Chatted:Connect(function(message: string)
		_K.Process.runCommands(_K, player, message)
	end)
end

_K.Services.Players.PlayerAdded:Connect(playerAdded)
-- if any players join before PlayerAdded connection
for _, player in _K.Services.Players:GetPlayers() do
	playerAdded(player)
end

_K.Remote "Command".OnServerEvent:Connect(function(player, message)
	_K.Process.runCommands(_K, player, message)
end)
-- NOTE: probably shouldn't network system logs to other servers, ideally only command and error logs
_K.log("Server initialized.", "INFO")

return _K
