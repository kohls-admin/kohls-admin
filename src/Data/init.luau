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
local ChunkChanges = require(script.ChunkChanges)
local Hook = require(script.Parent.Hook)
local Migrate = require(script.Migrate)
local Util = require(script.Parent.Util)
local Remote = require(script.Parent.Remote)
local Z = require(script.Parent.Z)

Data.Migrate = Migrate

local DATA_KEY = "_KData"
local DATA_LIMIT = 512 * 1024 -- 512 KB

---------------------------
-- Core Save Functions --
---------------------------

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
					Text = `<b><font color="#{invalidColor}">You're approaching the limit of the DataStore!</font>\n\tConsider removing some {dataType}s.</b>\n\n<b>Data Usage:</b> {string.format(
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
	if data.persist then
		Data.Sync.members[key] = { data.name, data.persist }
	end
end

local SAVE = {
	bans = {},
	members = {},
	settings = {},
	logs = {},
}

local updatingBans = false
local function updateBans()
	if updatingBans then
		return
	end
	updatingBans = true
	local saveBans = SAVE.bans
	SAVE.bans = {}

	local ok, result = Data.Store.updateAsync("Bans", function(value)
		return if not value then Data.filterRemove(saveBans) else Data.mergeRemove(value, saveBans)
	end)

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
	local saveMembers, saveSettings = SAVE.members, SAVE.settings
	SAVE.members, SAVE.settings = {}, {}

	local ok, result = Data.Store.updateAsync("Main", function(value)
		if not value then
			return Data.filterRemove({ saveMembers, saveSettings })
		end
		Data.mergeRemove(value[1], saveMembers)
		Data.mergeRemove(value[2], saveSettings)
		return value
	end)

	updatingMain = false

	if ok and not Data.gameClosing then
		task.defer(dataLimitWarning, "member", #Http:JSONEncode(result))
	end
end

local function getLogsSize(logs)
	local size = 0
	for _, log in logs do
		-- 1 byte level, 1 byte some 8 bytes uint, 1 byte some 1 + N bytes str8, 2 + N bytes log text, 8 bytes f64 time
		log.size = 11 + (log.from and 9 or 1) + (log.name and 2 + #log.name or 1) + #log.text
		size += log.size
	end
	return size
end

local updatingLogs = false
local function updateLogs()
	if updatingLogs then
		return
	end
	updatingLogs = true
	local saveLogs = SAVE.logs
	SAVE.logs = {}

	local n = 0
	local saveLogsSize = getLogsSize(saveLogs)
	while saveLogsSize > DATA_LIMIT do
		n += 1
		saveLogsSize -= saveLogs[n].size
		saveLogs[n] = nil
	end
	if n > 0 then
		Util.Table.settle(saveLogs)
	end

	Data.Store.updateAsync("Logs_" .. math.random(4), function(value)
		if not value or type(value) ~= "buffer" then
			return Z.ser(Data.Schema.logs, saveLogs)
		end

		local logs = Z.des(Data.Schema.logs, value)

		local thirtyDaysAgo = workspace:GetServerTimeNow() - 30 * 86400
		local count = 1
		for i, log in logs do
			if log.time < thirtyDaysAgo then
				logs[i] = nil
				count += 1
			end
		end

		local size = getLogsSize(logs) + saveLogsSize
		while size > DATA_LIMIT do
			size -= logs[count].size
			logs[count] = nil
			count += 1
		end
		if count > 1 then
			Util.Table.settle(logs)
		end

		Util.Table.mergeList(logs, saveLogs)

		local result, err = Z.ser(Data.Schema.logs, logs)
		assert(result, err)

		return result
	end)

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
		local tasks = Util.Tasks.new()
		for key, data in state do
			if not data.name then
				tasks:add(fillMemberName, key, data)
			end
		end
		tasks:wait()

		for _, player in Players:GetPlayers() do
			if player:GetAttribute("_K_READY") then
				Remote.Members:FireClient(player, state)
			end
		end
	end,

	settings = function(state, changes)
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

		if changes.themeFont then
			changes.themeFont = Font.new(changes.themeFont)
		end
		if changes.themeFontMono then
			changes.themeFontMono = Font.new(changes.themeFontMono)
		end

		if changes.prefix then
			local prefix = if type(changes.prefix) == "table" then changes.prefix[1] else changes.prefix
			state.prefix = table.clone(Data.settingsModuleData.prefix)
			if not table.find(state.prefix, prefix) then
				table.insert(state.prefix, 1, prefix)
			end
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
		local logs = changes

		if type(changes) == "table" then
			changes = Z.ser(Data.Schema.logs, changes)
		elseif type(changes) == "buffer" then
			logs = Z.des(Data.Schema.logs, changes)
		end
		Util.Defer.wait()

		if #logs > 0 then
			Util.Table.mergeList(state, logs)
			Util.Defer.wait()
			local excess = #state - Util.Logger.limit
			if excess > 0 then
				for i = 1, excess do
					state[i] = nil
				end
				Util.Table.settle(state)
			end
			Util.Defer.wait()
			table.sort(state, Util.Logger.sortTime)

			for _, player in Players:GetPlayers() do
				if player:GetAttribute("_K_READY") and Auth.hasPermission(player.UserId, "serverlogs") then
					Remote.Logs:FireClient(player, changes)
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

local function syncChanges(changes)
	for key, info in changes do
		if key == "_time" then
			continue
		end
		local state = Data[key]
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

local dataStoreUpdateThrottle = false
local cacheKeys = { bans = "set", members = "set", settings = "set", logs = "insert" }
local function processSync()
	local changes = {}

	-- process changes
	for key, action in cacheKeys do
		local pending = Data.Sync[key]
		Data.Sync[key] = {}
		if next(pending) ~= nil then -- pending changes
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

	-- update datastores
	if not Data.gameClosing and not dataStoreUpdateThrottle then
		dataStoreUpdateThrottle = true
		task.delay(HASH_EXPIRY, function()
			dataStoreUpdateThrottle = false
		end)
		if next(SAVE.bans) ~= nil then
			task.spawn(updateBans)
		end
		if next(SAVE.members) ~= nil or next(SAVE.settings) ~= nil then
			task.spawn(updateMain)
		end
		if next(SAVE.logs) ~= nil then
			task.spawn(updateLogs)
		end
	end

	-- cross server sync
	if not Data.SEPARATE_DATASTORE and next(changes) ~= nil then
		local id = Http:GenerateGUID(false)
		idsFromThisServer[id] = true

		local now = DateTime.now().UnixTimestampMillis
		local chunks = ChunkChanges(changes)
		for chunkId, chunk in chunks do
			chunk._time = now
			for n = 1, HASH_PARTITIONS do
				pcall(Util.Retry, function()
					-- set random map for #HASH_PARTITIONS * request limit
					SYNC_HASH_MAPS[n]:SetAsync(id .. "_" .. chunkId, chunk, HASH_EXPIRY)
				end, math.huge)
			end
		end

		task.delay(HASH_EXPIRY, removeIdFromThisServer, id)
		pcall(Util.Retry, function()
			Util.Service.Messaging:PublishAsync(DATA_KEY, { id, #chunks })
		end, math.huge)
	end
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

	local okMain, main, metaMain = Data.Store.getAsync("Main")
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

	local okBans, bans, metaBans = Data.Store.getAsync("Bans")
	if okBans and bans then
		SYNC.bans(Data.bans, bans)
	end

	local logsUpdatedTime = 0
	if Data.settings.saveLogs ~= false or Data.settings.saveChatLogs ~= false then
		for i = 1, 4 do -- 4 shards
			local okLogs, logs, metaLogs = Data.Store.getAsync("Logs_" .. i)
			if okLogs and type(logs) == "buffer" then
				SYNC.logs(Data.logs, logs)
			end
			logsUpdatedTime = if metaLogs then metaLogs.UpdatedTime else logsUpdatedTime
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
			local _, syncHashMap = pcall(Util.Retry, function()
				return MemoryStore:GetHashMap(DATA_KEY .. i)
			end, math.huge)
			table.insert(SYNC_HASH_MAPS, syncHashMap)
		end

		task.defer(Util.Retry, function()
			return Util.Service.Messaging:SubscribeAsync(DATA_KEY, function(message)
				local data = message.Data
				if not data then
					return
				end

				local id, chunkCount = unpack(data)
				if not id or not chunkCount or idsFromThisServer[id] then
					return
				end

				for chunkId = 1, chunkCount do
					local _ok, changes = Util.Retry(function()
						-- get random map for #HASH_PARTITIONS * request limit
						return SYNC_HASH_MAPS[math.random(HASH_PARTITIONS)]:GetAsync(id .. "_" .. chunkId)
					end, math.huge)
					syncChanges(changes)
				end
			end)
		end, math.huge)

		if not Util.RunContext.IsStudio then
			local times = {
				bans = if metaBans then metaBans.UpdatedTime else 0,
				members = if metaMain then metaMain.UpdatedTime else 0,
				settings = if metaMain then metaMain.UpdatedTime else 0,
				logs = logsUpdatedTime,
			}
			local hashmap = SYNC_HASH_MAPS[math.random(HASH_PARTITIONS)]
			local success, items = pcall(Util.MemoryStore.getItemsFromHashMap, hashmap)
			if success then
				for _, changes in items do
					for key in changes do
						if key == "_time" then
							continue
						end
						if changes._time <= times[key] then
							changes[key] = nil -- strip stale data
						end
					end
					syncChanges(changes)
				end
			end
		end
	end

	task.spawn(function()
		repeat
			processSync()
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
			local ok, hashMap = pcall(Util.Retry, function()
				return MemoryStore:GetHashMap("__KA_Charts")
			end)
			local ok2, updated = pcall(Util.Retry, function()
				return hashMap:GetAsync("Updated")
			end)
			if ok and ok2 and not updated then
				pcall(Util.Retry, function()
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
				pcall(Util.Retry, function()
					Http:RequestAsync(request)
				end)
			end
		end)
	end

	game:BindToClose(function()
		Data.gameClosing = true

		processSync()

		local tasks = Util.Tasks.new()

		if next(SAVE.bans) ~= nil then
			tasks:add(updateBans)
		end
		if next(SAVE.members) ~= nil or next(SAVE.settings) ~= nil then
			tasks:add(updateMain)
		end
		if next(SAVE.logs) ~= nil then
			tasks:add(updateLogs)
		end

		tasks:wait()
	end)

	return Data
end

return Data
