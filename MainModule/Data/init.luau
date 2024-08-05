-- have global datastore toggle
-- use queues?
-- debounce update async
-- eventually save player profiles as well as two main global datastores

-- TODO: make sure cache is valid json encoding by sanitizing key inputs as strings always

local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local Util = require(script.Parent.Util)
local Remote = require(script.Parent.Remote)

type Dict = { [any]: any }

local RETRY_COUNT = 1
local RETRY_DELAY = 5
local RETRY_BACKOFF = 2

-- -- key used to check when global data has been changed for a save cycle
-- 	-- TODO: account for race conditions... use a timestamp?
-- 	_lastUpdate = 0,
-- 	_dataUpdate = 0,

local Cache = {
	-- Main
	bans = {},
	members = {},
	settings = {},
	-- Logs
	logs = {},
	-- userId
	players = {},
}

local Data = {
	REMOVE = table.freeze({ type = "Remove" }),

	Cache = Cache,
	bans = {
		-- [UserId] = {Username, Reason, Timestamp}
		-- Username is the last known username of the user when they were banned
		-- TODO: progressively parse and update each name!
		-- if Timestamp is -1 the ban is permanent
		-- if Timestamp is nil the ban is for the server session only
		-- saves only if Timestamp isn't nil
		["2"] = { "John Doe", "He been noob.", nil, 44391621, "Scripth" },
		["3"] = { "Jane Doe", "She was a noob.", nil, 44391621, "Scripth" },
		["5"] = { "Jack Doe", "Wow!", 1720922623, 44391621, "Scripth" },
	},
	logs = {},
	members = {
		-- example role data structure
		-- [userid] = {data}
		["1"] = {
			-- last known username? (update over time on init?)
			name = "Roblox",
			roles = { "admin", "vip" },
			persist = {},
		},
	},
	players = {},
	settings = {
		prefix = ":",
		vip = true,
		mutableHooks = false,
	},

	async = {
		gamepass = {},
		-- NOTE: ASSET/SUBS REQUIRE A PLAYER FOR PERMISSIONS AND CAN STILL BE AFFECTED BY ID COMMANDS!
		asset = {},
		subscription = {},
		-- TODO: need a way to define exact rank roles instead of >=
		group = {
			[451053] = {
				{ rank = 1, roles = { "vip" } },
				{ rank = 255, roles = { "creator", "mod" }, exactRank = true },
			},
		},
		-- [groupId] = {
		-- { rank = 200, roles = { "admin", "vip" }, rankAndAbove = true },
		-- },
	},
	defaultRole = {
		-- role "_rank" determines hierarchy
		-- 0 is reserved for the default role
		_rank = 0,
		name = "Player",
		color = "#0ff",

		-- STAFF PERMISSIONS (anyone with one of these permissions will be saved to the list of staff)

		-- this permission bypasses all restrictions (danger!)
		admin = false,
		-- can PERMANENTLY ban users from the game
		ban = false,
		-- can kick or ban users from the current server session
		kick = false,
		-- allows the user to manage roles of other users with a lesser role
		roles = false,
		-- can configure the global admin settings
		settings = false,
		-- can view audit logs
		logs = false,

		-- COSMETIC PERMISSIONS
		-- can use commands that require VIP permission
		vip = false,

		-- allowed command groups?
		groups = {
			-- "administration",
			-- "moderation",
			-- "general",
			"utility",
		},

		-- command name/alias filter
		filter = {
			-- allows the help command unless it's disabled
			help = true,
			-- prevents the use of the kill command
			kill = false,
		},
	},
	roles = {
		-- unique key should NEVER be changed or you may lose save data
		vip = {
			_rank = 1,
			name = "VIP",
			vip = true,
			color = "#0f8",
		},
		mod = {
			_rank = 2,
			name = "Moderator",
			kick = true,
			logs = true,
			groups = { "moderation", "general" },
			color = "#0f0",
		},
		admin = {
			_rank = 3,
			name = "Administrator",
			ban = true,
			kick = true,
			roles = true,
			logs = true,
			groups = { "administration", "moderation", "general" },
			color = "#ff0",
		},
		superadmin = {
			_rank = 4,
			name = "SuperAdmin",
			ban = true,
			kick = true,
			roles = true,
			logs = true,
			settings = true,
			groups = { "creator", "administration", "moderation", "general" },
			color = "#f80",
		},
		-- FIXME should this be defined and configurable? (or should it just be forced...)
		creator = {
			_rank = math.huge,
			name = "Game Creator",
			admin = true,
			color = "#f00",
		},
	},

	gameClosing = false,
	pendingSaveMain = false,
	pendingSaveLogs = false,

	store = nil,
}

Data.roles.defaultRole = Data.defaultRole

-- for adding/removing roles only save staff roles?
-- TODO: should probably not save roles to a player datastore otherwise those would need to be updated too ;(
-- TODO: instead let the game developer handle their own player save state and just give roles on join?

if RunService:IsClient() then
	return Data
end

-- TODO: get datastore key from settings module

function Data.getAsync(key: string, options: DataStoreSetOptions?): (boolean, any)
	return Util.Retry(function()
		return Data.store:GetAsync(key, options)
	end, RETRY_COUNT, RETRY_DELAY, RETRY_BACKOFF)
end

function Data.setAsync(key: string, value: any, userIds: { number }?, options: DataStoreSetOptions?): (boolean, any)
	return Util.Retry(function()
		return Data.store:SetAsync(key, value, userIds, options)
	end, RETRY_COUNT, RETRY_DELAY, RETRY_BACKOFF)
end

function Data.updateAsync(key: string, func: (value: any, keyInfo: DataStoreKeyInfo) -> any): (boolean, any)
	return Util.Retry(function()
		return Data.store:UpdateAsync(key, func)
	end, RETRY_COUNT, RETRY_DELAY, RETRY_BACKOFF)
end

function Data.mergeRemove(to: Dict, from: Dict): Dict
	for key, value in from do
		to[key] = if value == Data.REMOVE then nil else value
	end
	return to
end

function Data.filterRemove(source: Dict): Dict
	for key, value in source do
		if value == Data.REMOVE then
			source[key] = nil
		elseif type(value) == "table" then
			Data.filterRemove(value)
		end
	end

	return source
end

function Data.loadStore(name)
	if Data.store then
		return Data.store
	end
	print(`[Kohl's Admin] Initializing DataStore {name}...`)
	local ok, store = Util.Retry(function()
		return DataStoreService:GetDataStore(name, "Kohl's Admin Test")
	end, RETRY_COUNT, 1, 2)

	if not ok then
		error(store)
	end

	Data.store = store

	return store
end

local function syncMain(result)
	local bans, members, settings = unpack(result)

	-- TODO: need a way to clear SAVED session bans/settings for removal xD

	-- ban sync
	Util.mergeTable(Data.bans, bans)

	-- member sync
	for key, data in members do
		data.name, data[1] = data[1], nil
		data.persist, data[2] = data[2], nil
		data.roles = if Data.members[key] then Data.members[key].roles else data.persist
		if data.persist ~= data.roles then
			for _, role in data.persist do
				if not table.find(data.roles, role) then
					table.insert(data.roles, role)
				end
			end
			-- TODO: sort roles
		end
	end
	for key, data in Data.members do
		local cache = Cache.members[key]
		if not cache and #data.persist > 0 and not members[key] then
			for _, role in data.persist do
				-- remove from data.roles
				local index = table.find(data.roles, role)
				if index then
					table.remove(data.roles, index)
				end
			end
			Data.members[key] = nil
		end
	end
	Util.mergeTable(Data.members, members)

	-- settings sync
	Util.mergeTable(Data.settings, settings)

	print(result)

	-- TODO: only send to clients authorized to view these data
	Remote.Members:FireAllClients(Data.members)
	-- replicate bans/settings to clients
end

local nextMainInterval = tick() + 10
local function updateMain()
	-- flush cache and hold onto references to make sure they are immutable!
	local bans = Cache.bans
	local members = Cache.members
	local settings = Cache.settings
	Cache.bans = {}
	Cache.members = {}
	Cache.settings = {}

	local ok, result = Data.updateAsync("Main", function(value)
		print("updateAsync", value, members)
		if not value then
			return Data.filterRemove({ bans, members, settings })
		end

		Data.mergeRemove(value[1], bans)
		Data.mergeRemove(value[2], members)

		Util.mergeTable(value[3], settings)

		return value
	end)

	if ok then
		Data.pendingSaveMain = false
		nextMainInterval = tick() + 10
		syncMain(result)
	else
		warn(`[Kohl's Admin] Main Datastore UpdateAsync failed: {result}`)
	end

	return ok, result
end

function Data.initialize(name)
	Data.loadStore(name)

	print("[Kohl's Admin] Loading data...")
	local okMain, main = Data.getAsync("Main")
	if okMain then
		print("MainLoad", main)
		if main then
			syncMain(main)
		end
	else
		if RunService:IsStudio() and string.find(main, "502", 1, true) then
			warn("Data failed to load, enable Studio access to API services in Game Settings.")
			return Data
		end
		error(`Failed to load Kohl's Admin Main DataStore: {main}`)
	end

	local okLogs, logs = Data.getAsync("Logs")
	if okLogs then
		-- Data.logs = logs
		print("LogsLoad", logs)
		-- TODO: network data to existing clients
	end

	if not RunService:IsStudio() then
		-- Avoid writing studio data to production and stalling test session closing
		return Data
	end

	task.spawn(function() -- main save loop
		repeat
			task.wait(1)
			if tick() > nextMainInterval and Data.pendingSaveMain then
				print("attempting a main save!", Cache)
				updateMain()
			end
		until Data.gameClosing
		print("game closing?")
	end)

	game:BindToClose(function()
		Data.gameClosing = true

		local mainThread = coroutine.running()
		local numThreadsRunning = 0

		local function startSaveThread(key, func)
			local success, result = Data.updateAsync(key, func)

			if not success then
				warn(string.format("Failed to save %d's data: %s", key, result))
			end

			numThreadsRunning -= 1

			if numThreadsRunning == 0 then
				coroutine.resume(mainThread)
			end
		end

		if Data.pendingSaveMain then
			numThreadsRunning += 1
			task.spawn(updateMain)
		end

		-- TODO: figure out log merge and sort, need to compress dem logs haha!
		-- if Data.pendingSaveLogs then
		-- 	numThreadsRunning += 1
		-- 	task.spawn(startSaveThread, "Logs", function(value)
		-- 		return Util.mergeTable(value, Cache.logs)
		-- 	end)
		-- end

		-- TODO: prepare player data
		-- for userId, sessionData in Cache.players do
		-- 	numThreadsRunning += 1
		-- 	task.spawn(startSaveThread, userId, function(value)
		-- 		return sessionData
		-- 	end)
		-- end

		if numThreadsRunning > 0 then
			coroutine.yield()
		end
	end)

	return Data
end

return Data
