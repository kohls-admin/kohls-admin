-- TODO: load settings module stuff eventually? haha
-- TODO: client compatibility
-- need pre/post hooks for almost everything so addons can just DO IT?

--------------------------
-- START OF SHARED CODE --
--------------------------
local TextChatService = game:GetService("TextService")

local _K = {
	-- modules
	Util = require(script.Util),
	Auth = require(script.Auth),

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

	logs = {},
	playerPrefix = {},

	-- configuration
	settings = {
		prefix = ":",
		vip = true,
		mutableHooks = false,
	},

	Registry = nil,
	Process = nil,
}

-- shorthand utility
_K.Services = _K.Util.Services
_K.Remote = _K.Util.Remote
_K.Enum = _K.Util.Enum

_K.IsServer = _K.Services.RunService:IsServer()
_K.IsClient = _K.Services.RunService:IsClient()

-- assign CreatorId
if game.CreatorType == Enum.CreatorType.Group then
	local groupInfo = _K.Services.GroupService:GetGroupInfoAsync(game.CreatorId)
	_K.creatorId = groupInfo.Owner.Id
else
	_K.creatorId = game.CreatorId
end

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

function _K.handleBan(userId, name, reason, duration, fromUserId, fromName)
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

_K.Enum.LogType = { "Chat", "Command", "Info", "Warning", "Error", "System" }
function _K.log(message: string, logType: string, from: Player?)
	-- fire this log to all clients that are authorized!
	-- TODO: make sure they pull logs on client init
	-- make sure to sort by timestamp for new datastore entries
	if from then
		message = tostring(from) .. ": " .. message
	end
	local log = { os.time(), message, _K.Enum.LogType[logType], from and from.UserId }
	_K.Registry.hooks.preLog:Fire(log)
	table.insert(_K.logs, log)
	if #_K.logs > 1e5 then
		table.remove(_K.logs, 1)
	end
	if _K.IsServer then
		if from then
			local ok, result = pcall(
				TextChatService.FilterStringAsync,
				TextChatService,
				message,
				from,
				Enum.TextFilterContext[if _K.Auth.defaultRole.logs then "PublicChat" else "PrivateChat"]
			)
			if ok then
				for _, player in _K.Services.Players:GetPlayers() do
					local _, filtered = pcall(result.GetChatForUserAsync, result, player.UserId)
					_K.Remote "Log":FireClient(player, { log[1], filtered, log[3] })
				end
			end
		else
			_K.Remote "Log":FireAllClients(log)
		end
	end
	_K.Registry.hooks.postLog:Fire(log)
end

-- register internal modules to _K
for _, module in { "Registry", "Process", "Flux" } do
	_K[module] = require(script[module])
	_K[module]._K = _K
end

-- register default hooks
local hooks = _K.Registry.hooks
_K.Registry.hooks = {}
for i, hook in ipairs(hooks) do
	_K.Registry.registerHook(hook)
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

	local bans = {}
	local logs = table.create(#_K.logs)
	for _, items in { bans, logs } do
		for i, item in items do
			local message = if item[4] then _K.filterMessage(item[2], item[4], player.UserId) else item[2]
			bans[i] = { item[1], message, item[3], item[4] }
		end
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
	if not banInfo or player.UserId == _K.CreatorId then
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
		_K.Process.runCommands(player, message, true)
	end)
end

_K.Services.Players.PlayerAdded:Connect(playerAdded)
-- if any players join before PlayerAdded connection
for _, player in _K.Services.Players:GetPlayers() do
	playerAdded(player)
end

_K.Remote "Command".OnServerEvent:Connect(_K.Process.runCommands)
-- NOTE: probably shouldn't network system logs to other servers, ideally only command and error logs
_K.log("Server initialized.", "System")

return _K
