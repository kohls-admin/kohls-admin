-- have global datastore toggle
-- use queues?
-- debounce update async
-- eventually save player profiles as well as two main global datastores
-- TODO: make sure cache is valid json encoding by sanitizing key inputs as strings always

local Http = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local MemoryStore = game:GetService("MemoryStoreService")

local Data = require(script.Defaults)

if RunService:IsClient() then
	return Data
end

local Auth = require(script.Parent.Auth)
local Migrate = require(script.Migrate)
local Hook = require(script.Parent.Hook)
local Util = require(script.Parent.Util)
local Remote = require(script.Parent.Remote)

Data.Migrate = Migrate

-- DataStore value limit of 4,194,303 bytes
local DATA_KEY = "_KData"

---------------------------
-- Core Update Functions --
---------------------------

local DATA_LIMIT = 2 ^ 22 - 1

local nextDataLimitWarning = {}
local function dataLimitWarning(dataType, size)
	local ratio = size / DATA_LIMIT
	if ratio > 0.9 and tick() > (nextDataLimitWarning[dataType] or 0) then
		nextDataLimitWarning[dataType] = tick() + 300
		for _, player in Players:GetPlayers() do
			if
				Auth.hasCommand(player.UserId, "ban")
				or Auth.hasCommand(player.UserId, "members")
				or Auth.hasPermission(player.UserId, "settings")
			then
				local invalidColor = Data.settings.themeInvalid:ToHex()
				Remote.Notify:FireClient(player, {
					From = "_K",
					Text = `<b><font color="#{invalidColor}">You're approaching the limit of Roblox DataStores!</font>\n\tConsider removing some {dataType}s.</b>\n\n<b>Data Usage:</b> {string.format(
						"%.01f",
						ratio * 100
					)}%`,
				})
			end
		end
	end
end

local function fillMemberName(key, data)
	local userId = tonumber(key)
	data.name = Util.getUserInfo(userId).Username
	Data.Sync.members[key] = { data.name, data.persist }
	Auth.networkMember(key)
end

local function rawSortTime(a, b)
	return a[3] > b[3] -- reverse sort
end

local SAVE = {
	bans = {},
	members = {},
	settings = {},
	logs = {},
	players = {},
}

local updatingBans = false
local function updateBans()
	if updatingBans then
		return
	end
	updatingBans = true

	local ok, result = Data.Store.updateAsync("Bans", function(value)
		return if not value then Data.filterRemove(SAVE.bans) else Data.mergeRemove(value, SAVE.bans)
	end)

	table.clear(SAVE.bans)
	updatingBans = false

	if ok and not Data.gameClosing then
		task.defer(dataLimitWarning, "ban", #Http:JSONEncode(result))
	end
end

local updatingMain = false
local function updateMain()
	if updatingMain then
		return
	end
	updatingMain = true

	local ok, result = Data.Store.updateAsync("Main", function(value)
		if not value then
			return Data.filterRemove({ SAVE.members, SAVE.settings })
		end
		Data.mergeRemove(value[1], SAVE.members)
		Data.mergeRemove(value[2], SAVE.settings)
		return value
	end)

	table.clear(SAVE.members)
	table.clear(SAVE.settings)
	updatingMain = false

	if ok and not Data.gameClosing then
		task.defer(dataLimitWarning, "member", #Http:JSONEncode(result))
	end
end

local updatingLogs = false
local function updateLogs()
	if updatingLogs then
		return
	end
	updatingLogs = true

	local updateSize = #Http:JSONEncode(SAVE.logs)
	local dataStructureSize = #Http:JSONEncode({ {}, DATA_LIMIT })

	Data.Store.updateAsync("Logs", function(value)
		if not value or type(value) ~= "table" or type(value[1]) ~= "table" or type(value[2]) ~= "number" then
			return { SAVE.logs, updateSize }
		end

		local savedLogs, savedSize = unpack(value)
		savedSize = savedSize or #Http:JSONEncode(savedLogs)

		Util.Table.mergeList(savedLogs, SAVE.logs)
		table.sort(savedLogs, rawSortTime)

		local totalSize = savedSize + updateSize
		local excess = totalSize - (DATA_LIMIT + dataStructureSize)
		local count = #savedLogs

		while excess > 0 do
			local logSize = #Http:JSONEncode(savedLogs[count]) + 1
			excess -= logSize
			totalSize -= logSize
			savedLogs[count] = nil
			count -= 1
		end
		value[2] = totalSize

		return value
	end)

	table.clear(SAVE.logs)

	updatingLogs = false
end

-------------------------
-- Core Sync Functions --
-------------------------

local SYNC = {
	bans = function(state, changes)
		Hook.preSyncBans:Fire(changes)
		Util.Table.merge(state, changes)
		Util.Table.merge(state, Data.Sync.bans)
		Hook.postSyncBans:Fire(state)

		for _, player in Players:GetPlayers() do
			if player:GetAttribute("_K_READY") and Auth.hasCommand(player.UserId, "ban") then
				Remote.Bans:FireClient(player, state)
			end
		end
	end,

	members = function(state, changes)
		for userId, data in changes do
			local cache = Data.Sync.members[userId]
			if cache then -- don't overwrite pending change!
				changes[userId] = nil
				continue
			end
			data.name, data[1] = data[1], nil
			data.persist, data[2] = data[2], nil

			-- filter out invalid roleIds
			local persist = {}
			for _, roleId in data.persist do
				if Data.roles[roleId] then
					table.insert(persist, roleId)
				else
					warn(`Invalid roleId: {roleId}, did you change the role _key?`)
					continue
				end
			end
			data.persist = persist

			local member = state[userId]
			if member then
				data.roles = member.roles

				-- remove roles that were saved but now aren't
				if member.persist then
					for _, role in data.roles do
						local hadRole = table.find(member.persist, role)
						local hasRole = table.find(data.persist, role)
						if hadRole and not hasRole then
							table.remove(data.roles, table.find(data.roles, role))
						end
					end
				end

				-- append new saved roles to cached roles
				for _, roleId in data.persist do
					if not table.find(data.roles, roleId) then
						table.insert(data.roles, roleId)
					end
				end
			else
				data.roles = table.clone(data.persist)
			end

			if #data.roles == 0 then -- remove member
				state[userId] = nil
				continue
			end

			table.sort(data.persist, Auth.roleIdSort)
			table.sort(data.roles, Auth.roleIdSort)
		end

		Util.Table.merge(state, changes)

		-- fill missing names
		for key, data in state do
			if not data.name and #data.persist > 0 then
				task.defer(fillMemberName, key, data)
			end
		end

		for _, player in Players:GetPlayers() do
			if player:GetAttribute("_K_READY") then
				Remote.Members:FireClient(player, state)
			end
		end
	end,

	settings = function(state, changes)
		-- deserialize settings
		for key, setting in changes do
			if type(setting) == "table" then
				local itemType = setting[1]
				if itemType == "color" then
					changes[key] = Color3.new(unpack(setting, 2))
				elseif itemType == "udim" then
					changes[key] = UDim.new(unpack(setting, 2))
				elseif itemType == "enum" then
					changes[key] = Enum[setting[2]][setting[3]]
				end
			end
		end

		Migrate.Settings(changes)

		-- settings sync
		if type(changes.prefix) == "string" then
			state.prefix[1] = changes.prefix
			changes.prefix = state.prefix
		end
		Util.Table.merge(state, changes)
		Data.settings = if Data.savedSettings.useSavedSettings then state else Data.defaultSettings

		for _, player in Players:GetPlayers() do
			if player:GetAttribute("_K_READY") then
				Remote.Settings:FireClient(player, state)
			end
		end
	end,

	logs = function(state, changes)
		local newLogs = {}
		local newLogsRaw = {}

		for _, log in changes do
			Util.Defer.wait()
			local text, level, time, from, name = unpack(log)
			if type(level) == "number" then
				level = string.char(level + 1)
			end
			table.insert(newLogs, { text = text, level = level, time = time, from = from, name = name })
			table.insert(newLogsRaw, { text, level, time, from, name })
		end

		if #newLogs > 0 then
			Util.Table.mergeList(state, newLogs)
			local excess = #state - Util.Logger.limit
			if excess > 0 then
				for i = 1, excess do
					state[i] = nil
				end
				Util.Table.settle(state)
			end
			table.sort(state, Util.Logger.sortTime)

			for _, player in Players:GetPlayers() do
				if player:GetAttribute("_K_READY") and Auth.hasPermission(player.UserId, "serverlogs") then
					Remote.Logs:FireClient(player, newLogsRaw)
				end
			end
		end
	end,
}

local REMOVE = {
	bans = function(state, keys)
		for _, player in Util.Service.Players:GetPlayers() do
			if Auth.hasCommand(player.UserId, "ban") then
				for _, key in keys do
					Remote.Ban:FireClient(player, key)
				end
			end
		end
	end,
	members = function(state, keys)
		for _, key in keys do
			Auth.networkMember(key)
		end
	end,
}

-----------------------------
-- CROSS SERVER NETWORKING --
-----------------------------
-- Partition limit: 150k Requests Per Minute
-- 7 Hashmaps * 150k RPM = 1.05M total RPM
-- Aligns with 1M hashmap item limit
-- Supports 1M server syncs/min
local HASH_EXPIRY = 60
local HASH_PARTITIONS = 7
local SYNC_HASH_MAPS = {}

local idsFromThisServer = {}
local function removeIdFromThisServer(id)
	idsFromThisServer[id] = nil
end

local function syncData(dir, changes)
	for key, info in changes do
		local state = dir[key]
		if info.changes then
			syncData(state, info.changes)
		end
		if info.unset then
			for _, key in info.unset do
				state[key] = nil
			end
			if REMOVE[key] then
				REMOVE[key](state, info.unset)
			end
		end
		if info.insert then
			(SYNC[key] or Util.Table.mergeList)(state, info.insert)
		elseif info.set then
			(SYNC[key] or Util.Table.merge)(state, info.set)
		end
	end
end

local cacheKeys = { bans = "set", members = "set", settings = "set", logs = "insert" }
local function syncChanges()
	local changes = {}

	for key, action in cacheKeys do
		local pending = Data.Sync[key]
		if next(pending) then -- pending changes
			local change, remove = {}, {}
			for k, v in pending do
				if v == Data.REMOVE then
					table.insert(remove, k)
				else
					change[k] = v
				end
			end

			local changing, removing = next(change) ~= nil, next(remove) ~= nil
			if changing or removing then
				changes[key] = {
					[action] = if changing then change else nil,
					unset = if removing then remove else nil,
				}
			end

			-- merge to datastore save queue
			if action == "insert" then
				Util.Table.mergeList(SAVE[key], pending)
			else
				Util.Table.merge(SAVE[key], pending)
			end
			table.clear(pending)
		end
	end

	if next(changes) == nil then
		return
	end

	if not Data.gameClosing then
		if changes.bans then
			task.spawn(updateBans)
		end
		if changes.members or changes.settings then
			task.spawn(updateMain)
		end
		if changes.logs then
			task.spawn(updateLogs)
		end
	end

	local id = Http:GenerateGUID(false)
	idsFromThisServer[id] = true

	for i = 1, HASH_PARTITIONS do
		Util.Retry(function()
			-- set random map for #HASH_PARTITIONS * request limit
			SYNC_HASH_MAPS[i]:SetAsync(id, changes, HASH_EXPIRY)
		end, math.huge)
	end
	task.delay(HASH_EXPIRY, removeIdFromThisServer, id)

	Util.Retry(function()
		Util.Service.Messaging:PublishAsync(DATA_KEY, id)
	end, math.huge)
end

----------
-- INIT --
----------

function Data.initialize(scope)
	local ok, result = Data.Store.loadStore(DATA_KEY, scope)
	if not ok then
		warn("[Kohl's Admin] Data failed to load: " .. result)
		Hook.initDataStore:Fire()
		return Data
	end

	local okMain, main = Data.Store.getAsync("Main")
	if okMain then
		if main then
			SYNC.members(Data.members, main[1])
			SYNC.settings(Data.savedSettings, main[2])
		else -- first time load
			local bansKAI, mainKAI = Migrate.KAI()
			if bansKAI then
				print("[Kohl's Admin] Migrating Data from Kohl's Admin Infinite...")
				Data.Sync.bans = bansKAI
				Data.Sync.members = mainKAI[1]
				Data.Sync.settings = mainKAI[2]

				local data = Util.Table.deepCopy(mainKAI)
				SYNC.bans(Data.bans, bansKAI)
				SYNC.members(Data.members, data[1])
				SYNC.settings(Data.savedSettings, data[2])
			end
		end
	end

	local okBans, bans = Data.Store.getAsync("Bans")
	if okBans and bans then
		SYNC.bans(Data.bans, bans)
	end

	if Data.settings.saveLogs ~= false or Data.settings.saveChatLogs ~= false then
		local okLogs, logs = Data.Store.getAsync("Logs")
		if okLogs and logs and type(logs) == "table" and type(logs[1]) == "table" and type(logs[1][1]) == "table" then
			SYNC.logs(Data.logs, logs[1])
		end
	end

	local okServers, servers = Data.Store.getAsync("Servers")
	if okServers and servers then
		Util.Table.merge(Data.reservedServers, servers)
		for _, player in Util.Service.Players:GetPlayers() do
			task.spawn(function()
				if Auth.hasCommand(player.UserId, "place") or Auth.hasCommand(player.UserId, "unreserve") then
					Remote.ReservedServers:FireClient(player, servers)
				end
			end)
		end
	end

	Hook.initDataStore:Fire()

	-- disable cross server sync logic in private servers
	if not Data.SEPARATE_DATASTORE then
		for i = 1, HASH_PARTITIONS do
			local _, syncHashMap = Util.Retry(function()
				return MemoryStore:GetHashMap(DATA_KEY .. i)
			end, math.huge)
			table.insert(SYNC_HASH_MAPS, syncHashMap)
		end

		task.defer(Util.Retry, function()
			return Util.Service.Messaging:SubscribeAsync(DATA_KEY, function(message)
				local id = message.Data
				if not id or idsFromThisServer[id] then
					return
				end

				local _ok, changes = Util.Retry(function()
					-- get random map for #HASH_PARTITIONS * request limit
					return SYNC_HASH_MAPS[math.random(HASH_PARTITIONS)]:GetAsync(id)
				end, math.huge)
				syncData(Data, changes)
			end)
		end, math.huge)
	end

	task.spawn(function()
		repeat
			syncChanges()
			task.wait(1)
		until Data.gameClosing
	end)

	if
		Data.settings.vip
		and Data.settings.addToCharts
		and Http.HttpEnabled
		and game.GameId > 0
		and not RunService:IsStudio()
	then
		task.spawn(function()
			local ok, hashMap = Util.Retry(function()
				return MemoryStore:GetHashMap("__KA_Charts")
			end)
			local ok2, updated = Util.Retry(function()
				return hashMap:GetAsync("Updated")
			end)
			if ok and ok2 and not updated then
				Util.Retry(function()
					hashMap:SetAsync("Updated", true, 86400 / 8)
				end)
				local request = {
					Method = "POST",
					Url = `https://api.kohl.gg/update`,
					Headers = { ["Content-Type"] = "application/json" },
					Body = Http:JSONEncode({
						game_id = game.GameId,
						token = "lzjjp9LUOtePr7xnKmctfp5DAuFgvcrcxL3caXpBnVM=",
					}),
				}
				Util.Retry(function()
					Http:RequestAsync(request)
				end)
			end
		end)
	end

	game:BindToClose(function()
		Data.gameClosing = true

		syncChanges()

		local tasks = Util.Tasks.new()

		if next(Data.Sync.bans) then
			tasks:add(updateBans)
		end
		if next(Data.Sync.members) or next(Data.Sync.settings) then
			tasks:add(updateMain)
		end
		if next(Data.Sync.logs) then
			tasks:add(updateLogs)
		end

		tasks:wait()
	end)

	return Data
end

return Data
