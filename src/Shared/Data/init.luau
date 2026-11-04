-- have global datastore toggle
-- use queues?
-- debounce update async
-- eventually save player profiles as well as two main global datastores
-- TODO: make sure cache is valid json encoding by sanitizing key inputs as strings always

local Http = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local MemoryStore = game:GetService("MemoryStoreService")

local Data = require(script:WaitForChild("Defaults"))

if RunService:IsClient() then
	return Data
end

local Shared = script.Parent
local Package = Shared.Parent

local Auth = require(Shared:WaitForChild("Auth"))
local Hook = require(Shared:WaitForChild("Hook"))
local Registry = require(Shared:WaitForChild("Registry"))
local Util = require(Shared:WaitForChild("Util"))
local Z = require(Package:WaitForChild("Z"))

local ChunkChanges = require(script:WaitForChild("ChunkChanges"))
local Migrate = require(script:WaitForChild("Migrate"))

local Remote = Util.Remote
local CHAT_LEVEL = Util.Logger:encode("CHAT")

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
				Remote.Notify:Fire(player, {
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
	if data.persist and #data.persist > 0 then
		Data.Sync.members[key] = { data.name, data.persist }
	end
end

local SAVE = {
	bans = {},
	members = {},
	settings = {},
	logs = {},
}
local SAVE_TIME = {
	bans = {},
	members = {},
	settings = {},
}
local lastSyncTime = 0
local invalidateCache: ((string) -> ())? = nil

local function restoreUnsaved(
	queue: { [any]: any },
	snapshot: { [any]: any },
	timeMap: { [any]: number }?,
	snapshotTime: { [any]: number }?
)
	for k, v in snapshot do
		if queue[k] == nil and (not timeMap or not snapshotTime or timeMap[k] == snapshotTime[k]) then
			queue[k] = v
		end
	end
end

local updatingBans = false
local function updateBans()
	if updatingBans then
		while updatingBans do
			task.wait()
		end
		if next(SAVE.bans) == nil then
			return
		end
	end
	updatingBans = true
	while next(SAVE.bans) ~= nil do
		local saveBans = SAVE.bans
		local saveBansTime = table.clone(SAVE_TIME.bans)
		SAVE.bans = {}

		local ok, result = Data.Store.updateAsync("Bans", function(value, keyInfo: DataStoreKeyInfo)
			local userIds = if keyInfo then keyInfo:GetUserIds() else nil
			local metadata = if keyInfo then keyInfo:GetMetadata() else nil
			return Data.mergeRemove(value or {}, saveBans), userIds, metadata
		end)

		if ok then
			if invalidateCache then
				invalidateCache("Bans")
			end
			if not Data.gameClosing then
				task.defer(dataLimitWarning, "ban", #Http:JSONEncode(result))
			end
		else
			restoreUnsaved(SAVE.bans, saveBans, SAVE_TIME.bans, saveBansTime)
			break
		end
	end
	updatingBans = false
end

local updatingMain = false
local function updateMain()
	if updatingMain then
		while updatingMain do
			task.wait()
		end
		if next(SAVE.members) == nil and next(SAVE.settings) == nil then
			return
		end
	end
	updatingMain = true
	while next(SAVE.members) ~= nil or next(SAVE.settings) ~= nil do
		local saveMembers, saveSettings = SAVE.members, SAVE.settings
		local saveMembersTime = table.clone(SAVE_TIME.members)
		local saveSettingsTime = table.clone(SAVE_TIME.settings)
		SAVE.members, SAVE.settings = {}, {}

		local ok, result = Data.Store.updateAsync("Main", function(value, keyInfo: DataStoreKeyInfo)
			local userIds = if keyInfo then keyInfo:GetUserIds() else nil
			local metadata = if keyInfo then keyInfo:GetMetadata() else nil
			value = value or { {}, {} }
			Data.mergeRemove(value[1], saveMembers)
			Data.mergeRemove(value[2], saveSettings)
			return value, userIds, metadata
		end)

		if ok then
			if invalidateCache then
				invalidateCache("Main")
			end
			if not Data.gameClosing then
				task.defer(dataLimitWarning, "member", #Http:JSONEncode(result))
			end
		else
			restoreUnsaved(SAVE.members, saveMembers, SAVE_TIME.members, saveMembersTime)
			restoreUnsaved(SAVE.settings, saveSettings, SAVE_TIME.settings, saveSettingsTime)
			break
		end
	end
	updatingMain = false
end

-- serialized log sizes, kept off the log rows because the same rows are sent to other servers as JSON arrays
local logSizes = setmetatable({}, { __mode = "k" })

local function getLogsSize(logs)
	local size = 0
	for _, log in logs do
		-- 1 byte level, 1 byte some 8 bytes uint, 1 byte some 1 + N bytes str8, 2 + N bytes log text, 8 bytes f64 time
		local logSize = 11 + (log[4] and 9 or 1) + (log[5] and 2 + #log[5] or 1) + #log[1]
		logSizes[log] = logSize
		size += logSize
	end
	return size
end

local function serLogs(logs)
	local ser, err = Z.ser(Data.Schema.logs, logs)
	if not ser then
		error(err)
	end
	return ser
end

local LOG_FORMAT_VERSION = 1

local function migrateLogsV0(logs)
	for _, log in logs do
		log[1], log[2], log[3], log[4], log[5] = log.text, log.level, log.time, log.from, log.name
		log.text, log.level, log.time, log.from, log.name = nil, nil, nil, nil, nil
	end
	return logs
end

local updatingLogs = false
local logFlushOffset = 0
local function updateLogs()
	if updatingLogs then
		while updatingLogs do
			task.wait()
		end
		if #SAVE.logs == 0 then
			return
		end
	end
	updatingLogs = true

	while #SAVE.logs > 0 do
		local saveLogs = SAVE.logs
		SAVE.logs = {}

		local n = 0
		local saveLogsSize = getLogsSize(saveLogs)
		while saveLogsSize > DATA_LIMIT and n < #saveLogs do
			n += 1
			saveLogsSize -= logSizes[saveLogs[n]]
			saveLogs[n] = nil
		end
		if n > 0 then
			Util.Table.settle(saveLogs)
		end

		local logShard = Util.MemoryStore.shardIndex("Logs", 4, logFlushOffset)
		logFlushOffset += 1
		local okSave = Data.Store.updateAsync("Logs_" .. logShard, function(value, keyInfo: DataStoreKeyInfo)
			local metadata = if keyInfo then keyInfo:GetMetadata() else {}
			local formatVersion = if value then (metadata.version or 0) else LOG_FORMAT_VERSION

			metadata.version = LOG_FORMAT_VERSION

			if not value or type(value) ~= "buffer" then
				return serLogs(saveLogs), {}, metadata
			end

			local desSchema = if formatVersion <= 0 then Data.Schema.logsV0 else Data.Schema.logs
			local ok, result = pcall((Z.des :: unknown) :: (...any) -> ...any, desSchema, value)

			if not ok then
				warn("Failed to deserialize logs:", result)
				return serLogs(saveLogs), {}, metadata
			end

			local logs = result

			if formatVersion <= 0 then
				migrateLogsV0(logs)
			end

			local thirtyDaysAgo = workspace:GetServerTimeNow() - 30 * 86400
			local expired = false
			for i, log in logs do
				if log[3] < thirtyDaysAgo then
					logs[i] = nil
					expired = true
				end
			end
			if expired then
				Util.Table.settle(logs)
			end

			local count = 1
			local totalLogs = #logs
			local size = getLogsSize(logs) + saveLogsSize
			while size > DATA_LIMIT and count <= totalLogs do
				size -= logSizes[logs[count]]
				logs[count] = nil
				count += 1
			end
			if count > 1 then
				Util.Table.settle(logs)
			end

			Util.Table.mergeList(logs, saveLogs)

			return serLogs(logs), {}, metadata
		end)
		if not okSave then
			Util.Table.mergeList(saveLogs, SAVE.logs)
			SAVE.logs = saveLogs
			break
		end
	end

	updatingLogs = false
end

-------------------------
-- Core Sync Functions --
-------------------------

local SYNC = {
	bans = function(state, changes)
		Hook.preSyncBans:Fire(changes)
		Util.Table.merge(state, changes)
		Data.mergeRemove(state, Data.Sync.bans)
		Hook.postSyncBans:Fire(state)

		for _, player in Players:GetPlayers() do
			if player:GetAttribute("_K_READY") and Auth.hasCommand(player.UserId, "ban") then
				Remote.Bans:Fire(player, state)
			end
		end
	end,

	members = function(state, changes)
		for userId, data in changes do
			local key = tostring(userId)
			local cache = Data.Sync.members[key] or SAVE.members[key]
			if cache then -- don't overwrite pending change!
				changes[userId] = nil
				continue
			end
			local name = if data[1] ~= nil then data[1] else data.name
			local rawPersist = if data[2] ~= nil then data[2] else data.persist
			data.name, data[1] = name, nil
			data.persist, data[2] = rawPersist, nil

			-- filter out invalid roleIds
			local persist = {}
			if type(data.persist) == "table" then
				for _, roleId in data.persist do
					if Data.roles[roleId] then
						table.insert(persist, roleId)
					end
				end
			end
			data.persist = persist

			local userIdNumber = tonumber(key) :: number
			local removedRoles, addedRoles = {}, {}
			local member = state[key]
			if member then
				data.roles = member.roles
				-- keep the flags of roles a non-developer gave this session; saved roles come from developers
				data.unrestricted = member.unrestricted
				if data.unrestricted then
					for _, roleId in data.persist do
						data.unrestricted[roleId] = nil
					end
				end

				-- remove roles that were saved but now aren't
				if member.persist then
					for i = #data.roles, 1, -1 do
						local role = data.roles[i]
						local hadRole = table.find(member.persist, role)
						local hasRole = table.find(data.persist, role)
						if hadRole and not hasRole and not Auth.hasAsyncRole(userIdNumber, role) then
							table.remove(data.roles, i)
							table.insert(removedRoles, role)
						end
					end
				end

				-- append new saved roles to cached roles
				for _, roleId in data.persist do
					if not table.find(data.roles, roleId) then
						table.insert(data.roles, roleId)
						table.insert(addedRoles, roleId)
					end
				end
			else
				data.roles = table.clone(data.persist)
				Util.Table.mergeList(addedRoles, data.roles)
			end

			if #data.roles == 0 then -- remove member
				state[key] = nil
				changes[userId] = nil
				if userIdNumber then
					for _, roleId in removedRoles do
						Hook.roleRemoved:Fire(userIdNumber, roleId)
					end
				end
				continue
			end

			table.sort(data.persist, Auth.roleIdSort)
			table.sort(data.roles, Auth.roleIdSort)
			if userIdNumber then
				for _, roleId in removedRoles do
					Hook.roleRemoved:Fire(userIdNumber, roleId)
				end
				for _, roleId in addedRoles do
					Hook.roleAdded:Fire(userIdNumber, roleId)
				end
			end
		end

		Util.Table.merge(state, changes)

		-- fill missing names
		for key, data in state do
			if not data.name then
				task.spawn(fillMemberName, key, data)
			end
		end

		for _, player in Players:GetPlayers() do
			if player:GetAttribute("_K_READY") then
				if Auth.hasCommand(player.UserId, "members") then
					Remote.Members:Fire(player, state)
				else
					local selfKey = tostring(player.UserId)
					Remote.Members:Fire(player, { [selfKey] = state[selfKey] })
				end
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

		if changes.prefix then
			local prefixes = if type(changes.prefix) == "table"
				then table.clone(changes.prefix)
				else { tostring(changes.prefix) }
			if Data.settingsModuleData and type(Data.settingsModuleData.prefix) == "table" then
				for _, p in Data.settingsModuleData.prefix do
					if not table.find(prefixes, p) then
						table.insert(prefixes, p)
					end
				end
			end
			state.prefix = prefixes
			changes.prefix = state.prefix
		end

		Util.Table.merge(state, changes)
		Data.settings = if Data.savedSettings.useSavedSettings then state else Data.defaultSettings

		for _, player in Players:GetPlayers() do
			if player:GetAttribute("_K_READY") then
				Remote.Settings:Fire(player, state)
			end
		end
	end,

	logs = function(state, changes)
		local logs = changes
		if type(changes) == "buffer" then
			local ok, result = pcall((Z.des :: unknown) :: (...any) -> ...any, Data.Schema.logs, changes)
			if not ok then
				warn("Failed to deserialize sync logs:", result)
				return
			end
			logs = result
			Util.Defer.wait()
		end
		Hook.preSyncLogs:Fire(logs)

		-- chat text is never logged, skip any legacy saved chat logs and deduplicate against existing state
		local existing = {}
		for _, log in state do
			existing[`{log[3]}_{log[4] or ""}_{log[2]}_{log[1]}`] = true
		end
		local filtered = {}
		for _, log in logs do
			if log[2] ~= CHAT_LEVEL then
				local sig = `{log[3]}_{log[4] or ""}_{log[2]}_{log[1]}`
				if not existing[sig] then
					existing[sig] = true
					log[6] = false -- add global flag to each log
					table.insert(filtered, log)
				end
			end
		end
		Util.Defer.wait()

		if #filtered > 0 then
			Util.Table.mergeList(state, filtered)
			Util.Defer.wait()
			local excess = #state - Util.Logger.limit
			if excess > 0 then
				Util.Table.fastRemove(state, 1, excess)
			end
			Util.Defer.wait()
			table.sort(state, Util.Logger.sortTime)
			Data.logsVersion = (Data.logsVersion or 0) + 1

			if Data.logsLoaded then
				local ser, feedback = Z.ser(Data.Schema.logsRemote, filtered)
				if ser == nil then
					warn("Failed to serialize remote logs:", feedback)
					return
				end
				for _, player in Players:GetPlayers() do
					if player:GetAttribute("_K_READY") and Auth.hasPermission(player.UserId, "serverlogs") then
						Remote.Logs:Fire(player, ser)
					end
				end
			end
		end
		Hook.postSyncLogs:Fire(filtered)
	end,
}

local REMOVE = {
	bans = function(state, keys)
		for _, player in Util.Service.Players:GetPlayers() do
			if Auth.hasCommand(player.UserId, "ban") then
				for _, key in keys do
					Remote.Ban:Fire(player, key)
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
-- MemoryStoreHashMap automatically partitions keys across the backend; sharding distinct keys
-- within a single HashMap scales per-key read (~15k RPM) and write (~5k RPM) budgets without ListItemsAsync scans.
local HASH_EXPIRY = 60
local CHUNK_SHARDS = 16
local RECENT_SHARDS = 8
local CACHE_SHARDS = 16
local INLINE_SYNC_LIMIT = 900
local CACHE_SIZE_LIMIT = 28 * 1024
local URGENT_SAVE_THROTTLE = 6
local LOG_SYNC_INTERVAL = 30

local syncHashMap: MemoryStoreHashMap? = nil
local recentUrgentItems: { [string]: any } = {}
local cacheInvalidatedAt: { [string]: number } = {}
local TOPIC_HANDLERS: { [string]: { (any) -> () } } = {}
local topicSubscriptionActive = false
local topicSubscriptionConnection: RBXScriptConnection? = nil
local syncLoopStarted = false
local bindToCloseConnected = false

local idsFromThisServer = {}
local function removeIdFromThisServer(id)
	idsFromThisServer[id] = nil
end

local function getSyncHashMap(): MemoryStoreHashMap?
	if syncHashMap then
		return syncHashMap
	end
	if Data.SEPARATE_DATASTORE or Util.RunContext.IsStudio then
		return nil
	end
	local ok, map = Util.Retry(function()
		return MemoryStore:GetHashMap(DATA_KEY)
	end, 5)
	if ok and map then
		syncHashMap = map
	end
	return syncHashMap
end

local function hasLogsAudience(): boolean
	for _, player in Players:GetPlayers() do
		if Auth.hasPermission(player.UserId, "serverlogs") then
			return true
		end
	end
	return false
end

local function canManageServers(userId: number): boolean
	return (Registry.commands.place ~= nil and Auth.hasCommand(userId, "place") ~= false)
		or (Registry.commands.unreserve ~= nil and Auth.hasCommand(userId, "unreserve") ~= false)
end

local function hasServersAudience(): boolean
	for _, player in Players:GetPlayers() do
		if canManageServers(player.UserId) then
			return true
		end
	end
	return false
end

local function syncChanges(changes)
	if type(changes) ~= "table" then
		return
	end
	changes = Util.Table.deepCopy(changes)
	local nowClock = os.clock()
	if changes.bans ~= nil then
		cacheInvalidatedAt.Bans = nowClock
	end
	local main = changes.members ~= nil or changes.settings ~= nil
	if main then
		cacheInvalidatedAt.Main = nowClock
		Hook.preSyncMain:Fire(changes)
	end
	local syncTime = changes._time
	if type(syncTime) == "number" and syncTime > lastSyncTime then
		lastSyncTime = syncTime
	end
	for key, info in changes do
		if key == "_time" then
			continue
		end
		local state = if key == "settings" then Data.savedSettings else Data[key]
		-- Only the origin server writes its changes to DataStore; saveQueue and saveTime here guard against
		-- stale cross-server updates overwriting newer local changes and cancel superseded local saves.
		local saveQueue = SAVE[key]
		local saveTime = SAVE_TIME[key]
		local function claimSyncKey(k: any): boolean
			local canApply = Data.Sync[key][k] == nil
				and (
					((not saveQueue or saveQueue[k] == nil) and (not saveTime or saveTime[k] == nil or syncTime == nil))
					or (syncTime ~= nil and saveTime ~= nil and saveTime[k] ~= nil and syncTime >= saveTime[k])
				)
			if canApply then
				if saveQueue then
					saveQueue[k] = nil
				end
				if saveTime and syncTime ~= nil then
					saveTime[k] = syncTime
				end
			end
			return canApply
		end
		if info.unset then
			local unset = {}
			for _, k in info.unset do
				if claimSyncKey(k) then
					if key == "members" and state[k] then
						local member = state[k]
						if member.persist then
							local userIdNumber = tonumber(k) :: number
							for i = #member.roles, 1, -1 do
								local role = member.roles[i]
								if table.find(member.persist, role) and not Auth.hasAsyncRole(userIdNumber, role) then
									table.remove(member.roles, i)
								end
							end
							table.clear(member.persist)
						end
						if #member.roles == 0 then
							state[k] = nil
						end
					else
						state[k] = nil
					end
					table.insert(unset, k)
				end
			end
			if #unset > 0 and REMOVE[key] then
				REMOVE[key](state, unset)
			end
		end
		if info.insert then
			if key ~= "logs" or hasLogsAudience() then
				(SYNC[key] or Util.Table.mergeList)(state, info.insert)
			end
		elseif info.set then
			if saveQueue then
				for k in info.set do
					if not claimSyncKey(k) then
						info.set[k] = nil
					end
				end
			end
			if next(info.set) ~= nil then
				(SYNC[key] or Util.Table.merge)(state, info.set)
			end
		end
	end
	if main then
		Hook.postSyncMain:Fire(Data)
	end
end

local function fetchSyncChunk(id: string, chunkId: number): (boolean, any)
	local map = getSyncHashMap()
	if not map then
		return false, nil
	end
	local baseKey = `{id}_{chunkId}`
	local ok, changes = Util.MemoryStore.getSharded(map, baseKey, CHUNK_SHARDS, CHUNK_SHARDS, 2)
	if ok and type(changes) == "table" and next(changes) ~= nil then
		return true, changes
	end
	local okFallback, fallbackChanges = pcall(map.GetAsync, map, baseKey)
	if okFallback and type(fallbackChanges) == "table" and next(fallbackChanges) ~= nil then
		return true, fallbackChanges
	end
	return false, nil
end

local function onDataMessage(message)
	if Data.SEPARATE_DATASTORE then
		return
	end
	local data = if type(message) == "table" then message.Data else nil
	if type(data) == "string" then
		local ok, decoded = pcall(Util.Service.Http.JSONDecode, Util.Service.Http, data)
		if not ok then
			return
		end
		data = decoded
	end
	if type(data) ~= "table" then
		return
	end

	if data[1] == "_t" and type(data[2]) == "string" then
		if type(data[4]) == "string" and idsFromThisServer[data[4]] then
			return
		end
		local handlers = TOPIC_HANDLERS[data[2]]
		if handlers then
			local packet = { Data = data[3], Sent = message.Sent }
			for _, cb in handlers do
				task.spawn(cb, packet)
			end
		end
		return
	end

	local id, chunkCount, inlineChunk, logsOnly = unpack(data)
	if
		type(id) ~= "string"
		or type(chunkCount) ~= "number"
		or chunkCount < 1
		or chunkCount > 64
		or idsFromThisServer[id]
	then
		return
	end
	if logsOnly and not hasLogsAudience() then
		return
	end

	if type(inlineChunk) == "table" then
		syncChanges(inlineChunk)
		return
	end

	for chunkId = 1, chunkCount do
		local ok, changes = fetchSyncChunk(id, chunkId)
		if ok and changes then
			syncChanges(changes)
		end
	end
end

local function ensureTopicSubscription()
	if topicSubscriptionActive or Data.SEPARATE_DATASTORE then
		return
	end
	topicSubscriptionActive = true
	task.spawn(function()
		local ok, conn = Util.Retry(function()
			return Util.Service.Messaging:SubscribeAsync(DATA_KEY, onDataMessage)
		end, 5)
		if ok and conn then
			if Data.SEPARATE_DATASTORE then
				local _ = pcall(conn.Disconnect, conn)
				topicSubscriptionActive = false
			else
				topicSubscriptionConnection = conn
			end
		else
			topicSubscriptionActive = false
		end
	end)
end

function Data.subscribeTopic(topic: string, callback: (any) -> ())
	local list = TOPIC_HANDLERS[topic]
	if not list then
		list = {}
		TOPIC_HANDLERS[topic] = list
	end
	table.insert(list, callback)
	if Data.initialized and not Util.RunContext.IsStudio then
		ensureTopicSubscription()
	end
end

function Data.publishTopic(topic: string, payload: any?): boolean
	if Data.SEPARATE_DATASTORE then
		return false
	end
	local handlers = TOPIC_HANDLERS[topic]
	if handlers then
		local packet = { Data = payload, Sent = workspace:GetServerTimeNow() }
		for _, cb in handlers do
			task.spawn(cb, packet)
		end
	end
	if Util.RunContext.IsStudio then
		return true
	end
	ensureTopicSubscription()
	local id = Http:GenerateGUID(false)
	idsFromThisServer[id] = true
	task.delay(HASH_EXPIRY, removeIdFromThisServer, id)
	local ok = Util.Retry(function()
		Util.Service.Messaging:PublishAsync(DATA_KEY, { "_t", topic, payload, id })
	end, 5)
	return ok
end

local urgentSaveThrottle = false
local logSaveThrottle = false
local lastLogSyncClock = 0
local urgentKeys = { bans = "set", members = "set", settings = "set" }

local function trimRecentItemsToLimit(items: { [string]: any }, cutoff: number): { [string]: any }
	local keys = {}
	for k, entry in items do
		if type(entry) ~= "table" or (entry._time or 0) < cutoff then
			items[k] = nil
		else
			table.insert(keys, k)
		end
	end
	local okEnc, encoded = pcall(Http.JSONEncode, Http, items)
	if okEnc and #encoded <= CACHE_SIZE_LIMIT then
		return items
	end
	table.sort(keys, function(a, b)
		return (items[a]._time or 0) < (items[b]._time or 0)
	end)
	local totalSize = if okEnc then #encoded else math.huge
	for _, k in keys do
		local entry = items[k]
		items[k] = nil
		if totalSize < math.huge then
			local okItem, itemEnc = pcall(Http.JSONEncode, Http, entry)
			if okItem then
				totalSize -= (#itemEnc + #k + 4)
			end
			if totalSize > CACHE_SIZE_LIMIT then
				continue
			end
		end
		okEnc, encoded = pcall(Http.JSONEncode, Http, items)
		if okEnc and #encoded <= CACHE_SIZE_LIMIT then
			break
		end
		totalSize = if okEnc then #encoded else math.huge
	end
	return items
end

local function recordRecentUrgentChunks(id: string, chunks: { any }, now: number)
	local map = getSyncHashMap()
	if not map then
		return
	end
	local cutoff = now - HASH_EXPIRY * 1000
	local delta: { [string]: any } = {}
	local added = false
	for chunkId, chunk in chunks do
		local urgent = {}
		for key in urgentKeys do
			if chunk[key] then
				urgent[key] = chunk[key]
			end
		end
		if next(urgent) ~= nil then
			urgent._time = now
			local okItem, itemEnc = pcall(Http.JSONEncode, Http, urgent)
			if okItem and #itemEnc <= CACHE_SIZE_LIMIT - 64 then
				local itemKey = `{id}_{chunkId}`
				recentUrgentItems[itemKey] = urgent
				delta[itemKey] = urgent
				added = true
			end
		end
	end
	if not added then
		return
	end
	trimRecentItemsToLimit(recentUrgentItems, cutoff)
	local mergedSnapshot = recentUrgentItems
	if map.UpdateAsync then
		local okUpdate, updated = Util.Retry(function()
			return map:UpdateAsync("Recent_1", function(existing)
				local merged = if type(existing) == "table" then table.clone(existing) else {}
				for k, v in recentUrgentItems do
					local prev = merged[k]
					if type(prev) ~= "table" or (v._time or 0) >= (prev._time or 0) then
						merged[k] = v
					end
				end
				for k, v in delta do
					merged[k] = v
				end
				return trimRecentItemsToLimit(merged, cutoff)
			end, HASH_EXPIRY)
		end, 3)
		if okUpdate and type(updated) == "table" then
			mergedSnapshot = updated
			recentUrgentItems = table.clone(updated)
		end
	else
		local _ = pcall(map.SetAsync, map, "Recent_1", mergedSnapshot, HASH_EXPIRY)
	end
	if RECENT_SHARDS > 1 then
		local tasks = Util.Tasks.new()
		for shard = 2, RECENT_SHARDS do
			tasks:add(function()
				local _ = pcall(map.SetAsync, map, `Recent_{shard}`, mergedSnapshot, HASH_EXPIRY)
			end)
		end
		tasks:wait()
	end
end

local function processSync(forceLogs: boolean?)
	local changes = {}
	local changed = false
	lastSyncTime = math.max(DateTime.now().UnixTimestampMillis, lastSyncTime + 1)
	local now = lastSyncTime

	-- process urgent state changes (bans, members, settings)
	for key, action in urgentKeys do
		local pending = Data.Sync[key]
		if next(pending) ~= nil then
			Data.Sync[key] = {}
			local skipAnnounce = nil
			if key == "settings" then
				skipAnnounce = Data._skipNextAnnounceSync
				Data._skipNextAnnounceSync = nil
			end

			local change, remove = {}, {}
			for k, v in pending do
				if skipAnnounce ~= nil and k == "announcement" and v == skipAnnounce then
					continue
				end
				if v == Data.REMOVE then
					table.insert(remove, k)
				else
					change[k] = v
				end
			end

			local changing, removing = next(change) ~= nil, next(remove) ~= nil
			if changing or removing then
				changed = true
				changes[key] = {
					[action] = if changing then change else nil,
					unset = if removing then remove else nil,
				}
			end

			-- merge to origin datastore save queue
			Util.Table.merge(SAVE[key], pending)
			local saveTime = SAVE_TIME[key]
			if saveTime then
				for k in pending do
					saveTime[k] = now
				end
			end
			table.clear(pending)
		end
	end

	-- batch non-urgent logs unless forced (BindToClose), piggybacking on urgent changes, or interval elapsed
	local pendingLogs = Data.Sync.logs
	local clockNow = os.clock()
	if
		next(pendingLogs) ~= nil
		and (forceLogs or changed or lastLogSyncClock == 0 or (clockNow - lastLogSyncClock) >= LOG_SYNC_INTERVAL)
	then
		lastLogSyncClock = clockNow
		Data.Sync.logs = {}
		local globalLogs = {}
		local localOnlyLogs = Data.localOnlyLogs
		for _, entry in pendingLogs do
			if localOnlyLogs and localOnlyLogs[entry] then
				localOnlyLogs[entry] = nil
			else
				table.insert(globalLogs, entry)
			end
		end
		if #globalLogs > 0 then
			changed = true
			changes.logs = { insert = globalLogs }
		end
		Util.Table.mergeList(SAVE.logs, pendingLogs)
		table.clear(pendingLogs)
	end

	-- update datastores on origin server (separate throttles so 30s log saves never block 6s urgent saves)
	local hasUrgentSave = next(SAVE.bans) ~= nil or next(SAVE.members) ~= nil or next(SAVE.settings) ~= nil
	if not Data.gameClosing and not urgentSaveThrottle and hasUrgentSave then
		urgentSaveThrottle = true
		task.delay(URGENT_SAVE_THROTTLE, function()
			urgentSaveThrottle = false
		end)
		if next(SAVE.bans) ~= nil then
			task.spawn(updateBans)
		end
		if next(SAVE.members) ~= nil or next(SAVE.settings) ~= nil then
			task.spawn(updateMain)
		end
	end

	local hasLogSave = next(SAVE.logs) ~= nil
	if not Data.gameClosing and not logSaveThrottle and hasLogSave then
		logSaveThrottle = true
		task.delay(LOG_SYNC_INTERVAL, function()
			logSaveThrottle = false
		end)
		task.spawn(updateLogs)
	end

	-- cross server sync
	if not Data.gameClosing and not Data.SEPARATE_DATASTORE and not Util.RunContext.IsStudio and changed then
		local id = Http:GenerateGUID(false)
		idsFromThisServer[id] = true

		local logsOnly = changes.logs ~= nil
			and changes.bans == nil
			and changes.members == nil
			and changes.settings == nil
		local chunks = ChunkChanges(changes)
		for _, chunk in chunks do
			chunk._time = now
		end

		if not logsOnly then
			recordRecentUrgentChunks(id, chunks, now)
		end

		local inlineChunk = nil
		if #chunks == 1 then
			local okEnc, encoded = pcall(Http.JSONEncode, Http, { id, 1, chunks[1], logsOnly })
			if okEnc and #encoded <= INLINE_SYNC_LIMIT then
				inlineChunk = chunks[1]
			end
		end

		if not inlineChunk then
			local map = getSyncHashMap()
			if map then
				for chunkId, chunk in chunks do
					Util.MemoryStore.setSharded(map, `{id}_{chunkId}`, chunk, HASH_EXPIRY, CHUNK_SHARDS, 2)
				end
			end
		end

		task.delay(HASH_EXPIRY, removeIdFromThisServer, id)
		Util.Retry(function()
			Util.Service.Messaging:PublishAsync(DATA_KEY, { id, #chunks, inlineChunk, logsOnly })
		end, 5)
	end

	return changed
end

----------
-- INIT --
----------

local logsLoading = false
local logsUpdatedTime = 0

function Data.ensureLogsLoaded()
	if Data.logsLoaded or Data.SEPARATE_DATASTORE then
		Data.logsLoaded = true
		return
	end
	if not Data.canSave or Data.settings.saveLogs == false then
		Data.logsLoaded = Data.initialized == true
		return
	end
	if logsLoading then
		while logsLoading and not Data.logsLoaded do
			task.wait()
		end
		return
	end
	logsLoading = true
	for i = 1, 4 do -- 4 shards
		local okLogs, logs, metaLogs = Data.Store.getAsync("Logs_" .. i)
		local metadata = if metaLogs then metaLogs:GetMetadata() else {}
		local formatVersion = if okLogs and logs then (metadata.version or 0) else LOG_FORMAT_VERSION

		if okLogs and logs and formatVersion <= 0 then
			local success, ok = pcall(
				(Z.migrate :: unknown) :: (...any) -> ...any,
				Data.Schema.logsV0,
				Data.Schema.logs,
				logs,
				migrateLogsV0
			)
			if success and ok then
				logs = ok
			elseif not success then
				warn("[Kohl's Admin] Log migration failed, attempting standard load:", ok)
			end
		end

		if okLogs and type(logs) == "buffer" then
			SYNC.logs(Data.logs, logs)
		end
		logsUpdatedTime = math.max(if metaLogs then metaLogs.UpdatedTime else 0, logsUpdatedTime)
	end
	lastSyncTime = math.max(lastSyncTime, logsUpdatedTime)
	Data.logsLoaded = true
	logsLoading = false
end

local serversLoading = false

function Data.ensureServersLoaded(silent: boolean?)
	if Data.serversLoaded then
		return
	end
	if not Data.canSave then
		return
	end
	if serversLoading then
		while serversLoading and not Data.serversLoaded do
			task.wait()
		end
		return
	end
	serversLoading = true
	local okServers, servers = Data.Store.getAsync("Servers")
	if okServers and servers then
		for k, v in servers do
			if #v == 2 then
				servers[k] = { k, v[1], v[2] }
			end
		end
		Util.Table.merge(Data.reservedServers, servers)
		if not silent then
			for _, player in Players:GetPlayers() do
				if canManageServers(player.UserId) then
					Remote.ReservedServers:Fire(player, servers)
				end
			end
		end
	end
	Data.serversLoaded = true
	serversLoading = false
end

invalidateCache = function(key: string)
	cacheInvalidatedAt[key] = os.clock()
	if Data.gameClosing then
		return
	end
	local map = getSyncHashMap()
	if not map then
		return
	end
	local bucket = math.floor(workspace:GetServerTimeNow() / HASH_EXPIRY)
	local tasks = Util.Tasks.new()
	for b = bucket - 1, bucket do
		for shard = 1, CACHE_SHARDS do
			local shardKey = `{key}_{b}_{shard}`
			tasks:add(function()
				local _ = pcall(map.RemoveAsync, map, shardKey)
			end)
		end
	end
	tasks:wait()
end

local function getCachedOrStore(key: string): (boolean, any, any)
	local map = getSyncHashMap()
	local cacheKey: string? = nil
	if map then
		local bucket = math.floor(workspace:GetServerTimeNow() / HASH_EXPIRY)
		local minBucket = if cacheInvalidatedAt[key] == nil then bucket - 1 else bucket
		for b = bucket, minBucket, -1 do
			local shard = Util.MemoryStore.shardIndex(`{key}_{b}`, CACHE_SHARDS)
			local probeKey = `{key}_{b}_{shard}`
			if b == bucket then
				cacheKey = probeKey
			end
			local okCache, cached = pcall(map.GetAsync, map, probeKey)
			if okCache and type(cached) == "table" and cached.hit == true then
				local val = if cached.value ~= nil then Util.Table.deepCopy(cached.value) else nil
				return true, val, { UpdatedTime = cached.updatedTime or 0 }
			end
		end
	end

	local loadStartClock = os.clock()
	local ok, value, meta = Data.Store.getAsync(key)
	if ok and map and cacheKey and (cacheInvalidatedAt[key] or -1) < loadStartClock then
		local valueCopy = if value ~= nil then Util.Table.deepCopy(value) else nil
		local okEnc, encoded = true, ""
		if valueCopy ~= nil then
			okEnc, encoded = pcall(Http.JSONEncode, Http, valueCopy)
		end
		if okEnc and #encoded <= CACHE_SIZE_LIMIT then
			local updatedTime = if meta then meta.UpdatedTime else 0
			task.spawn(function()
				if (cacheInvalidatedAt[key] or -1) < loadStartClock then
					local _ = pcall(map.SetAsync, map, cacheKey, {
						hit = true,
						value = valueCopy,
						updatedTime = updatedTime,
					}, HASH_EXPIRY)
				end
			end)
		end
	end
	return ok, value, meta
end

local lazyHooksConnected = false

function Data.initialize(scope)
	Data.initialized = true
	Data.logsLoaded = false
	Data.serversLoaded = false
	logsLoading = false
	serversLoading = false
	urgentSaveThrottle = false
	logSaveThrottle = false
	lastLogSyncClock = 0
	table.clear(recentUrgentItems)
	table.clear(cacheInvalidatedAt)
	if Data.SEPARATE_DATASTORE and topicSubscriptionConnection then
		local _ = pcall(topicSubscriptionConnection.Disconnect, topicSubscriptionConnection)
		topicSubscriptionConnection = nil
		topicSubscriptionActive = false
	end

	local canSave, result = Data.Store.loadStore(DATA_KEY, scope)
	if not canSave then
		warn(`[Kohl's Admin] Data failed to load: {result}`)
		Data.canSave = false
		Data.saveError = tostring(result)
		Hook.initDataStore:Fire()
		return
	end

	Data.canSave = true

	local okMain, main, metaMain = getCachedOrStore("Main")
	if okMain then
		if main then
			Hook.preSyncMain:Fire(main)
			SYNC.members(Data.members, main[1])
			SYNC.settings(Data.savedSettings, main[2])
			Hook.postSyncMain:Fire(Data)
		else -- first time load
			local bansKAI, mainKAI = Migrate.KAI()
			if bansKAI then
				print("[Kohl's Admin] Migrating Data from Kohl's Admin Infinite...")
				local data = Util.Table.deepCopy(mainKAI)
				SYNC.bans(Data.bans, bansKAI)
				Hook.preSyncMain:Fire(data)
				SYNC.members(Data.members, data[1])
				SYNC.settings(Data.savedSettings, data[2])
				Hook.postSyncMain:Fire(Data)

				Data.Sync.bans = bansKAI
				Data.Sync.members = mainKAI[1]
				Data.Sync.settings = mainKAI[2]
			end
		end
	end

	local okBans, bans, metaBans = getCachedOrStore("Bans")
	if okBans and bans then
		SYNC.bans(Data.bans, bans)
	end

	-- erase existing private server logs
	if Data.SEPARATE_DATASTORE then
		Data.logsLoaded = true
		task.defer(function()
			for i = 1, 4 do -- 4 shards
				Data.Store.setAsync("Logs_" .. i, nil)
			end
		end)
	elseif hasLogsAudience() then
		Data.ensureLogsLoaded()
	end

	if hasServersAudience() then
		Data.ensureServersLoaded()
	end

	if not lazyHooksConnected then
		lazyHooksConnected = true
		Util.SafePlayerAdded(function(player: Player)
			if not Data.logsLoaded and Auth.hasPermission(player.UserId, "serverlogs") then
				task.spawn(Data.ensureLogsLoaded)
			end
			if not Data.serversLoaded and canManageServers(player.UserId) then
				task.spawn(Data.ensureServersLoaded)
			end
		end)
	end

	Hook.initDataStore:Fire()

	-- disable cross server sync logic in private servers
	if not Data.SEPARATE_DATASTORE and not Util.RunContext.IsStudio then
		getSyncHashMap()
		ensureTopicSubscription()

		local times = {
			bans = if metaBans then metaBans.UpdatedTime else 0,
			members = if metaMain then metaMain.UpdatedTime else 0,
			settings = if metaMain then metaMain.UpdatedTime else 0,
			logs = logsUpdatedTime,
		}
		lastSyncTime = math.max(lastSyncTime, times.bans, times.members, times.settings, times.logs)
		task.spawn(function()
			local map = getSyncHashMap()
			if not map then
				return
			end
			local sorted = {}
			local okRecent, partItems = Util.MemoryStore.getSharded(map, "Recent", RECENT_SHARDS, 2, 1)
			if not okRecent or type(partItems) ~= "table" then
				okRecent, partItems = pcall(map.GetAsync, map, "Recent_1")
			end
			if okRecent and type(partItems) == "table" then
				for _, changes in partItems do
					if type(changes) == "table" then
						table.insert(sorted, table.clone(changes))
					end
				end
			end
			table.sort(sorted, function(a, b)
				return (a._time or 0) < (b._time or 0)
			end)
			for _, changes in sorted do
				for setting in changes do
					if setting == "_time" then
						continue
					end
					if (changes._time or math.huge) <= (times[setting] or 0) then
						changes[setting] = nil -- strip stale data
					end
				end
				syncChanges(changes)
			end
		end)
	end

	if not syncLoopStarted then
		syncLoopStarted = true
		task.spawn(function()
			repeat
				task.wait(if processSync() then 6 else 1)
			until Data.gameClosing
		end)
	end

	if
		Data.settings.vip
		and Data.settings.addToCharts
		and Http.HttpEnabled
		and game.GameId > 0
		and not RunService:IsStudio()
	then
		task.delay(10, function()
			if Data.gameClosing then
				return
			end
			local map = getSyncHashMap()
			if not map then
				return
			end
			local ok, updated = Util.MemoryStore.getSharded(map, "Charts", 8, 2)
			if ok and not updated then
				Util.MemoryStore.setSharded(map, "Charts", true, 86400 / 8, 8)
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
				end, 3)
			end
		end)
	end

	if not bindToCloseConnected then
		bindToCloseConnected = true
		game:BindToClose(function()
			Data.gameClosing = true
			if Data.Store then
				Data.Store.closing = true
			end

			if Data.pendingLogReveals then
				for _, entry in Data.pendingLogReveals do
					entry.stored[1] = entry.fullText
					if entry.save then
						Data.queueLogSave(entry.stored, entry.global)
					end
				end
				table.clear(Data.pendingLogReveals)
			end

			processSync(true)

			local tasks = Util.Tasks.new()

			if updatingBans or next(SAVE.bans) ~= nil then
				tasks:add(updateBans)
			end
			if updatingMain or next(SAVE.members) ~= nil or next(SAVE.settings) ~= nil then
				tasks:add(updateMain)
			end
			if updatingLogs or next(SAVE.logs) ~= nil then
				tasks:add(updateLogs)
			end

			tasks:wait()
		end)
	end
end

return Data
