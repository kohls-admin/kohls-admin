-- TODO: load settings module stuff eventually? haha
-- TODO: client compatibility
-- need pre/post hooks for almost everything so addons can just DO IT?

--------------------------
-- START OF SHARED CODE --
--------------------------

local _K = {
	-- modules
	Util = require(script.Util),

	-- key used to check when global data has been changed for a save cycle
	-- TODO: account for race conditions... use a timestamp?
	_lastUpdate = 0,
	_dataUpdate = 0,

	bans = {
		-- [UserId] = {Username, Reason, Timestamp}
		-- Username is the last known username of the user when they were banned
		-- if Timestamp is -1 the ban is permanent
		-- if Timestamp is nil the ban is for the server session only
		-- saves only if Timestamp isn't nil
		[1] = { "Roblox" },
	},

	-- configuration
	settings = {
		prefix = ":",
		mutableHooks = false,
	},
}

-- assign shorthand
_K.Services = _K.Util.Services
_K.Remote = _K.Util.Remote

-- assign CreatorId
if game.CreatorType == Enum.CreatorType.Group then
	local groupInfo = _K.Services.GroupService:GetGroupInfoAsync(game.CreatorId)
	_K.creatorId = groupInfo.Owner.Id
else
	_K.creatorId = game.CreatorId
end

-- register internal modules to _K
for _, module in { "Authorization", "Registry", "Process" } do
	_K[module] = require(script[module])
	_K[module]._K = _K
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
local addonParent = (shared._K_LOADER or script)
local addons = typeof(addonParent) == "Instance" and addonParent:FindFirstChild("Addons")
if addons then
	for _, addon in addons:GetChildren() do
		require(addon)(_K)
	end
end

--------------------------
-- START OF SERVER CODE --
--------------------------

-- TODO: include Loader settings then include datastore settings to override

if not _K.Services.RunService:IsServer() then
	return _K
end

-- network test
_K.Remote.Test.OnServerEvent:Connect(print)

-- replicate addons
addons.Parent = script
-- selene: warn(incorrect_standard_library_use)
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
				banMessage = "You are banned from this experience for " .. _K.Util.simpleTime(timeRemaining) .. "!"
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

-- handle player chatting
local function playerAdded(player: Player)
	if banHandler(player) then
		return
	end
	player.Chatted:Connect(function(message: string)
		local success, err = _K.Process.runCommands(player, message, true)
		if not success then
			print(err)
		end
	end)
end

_K.Services.Players.PlayerAdded:Connect(playerAdded)
-- if any players join before PlayerAdded connection
for _, player in _K.Services.Players:GetPlayers() do
	playerAdded(player)
end

return _K
