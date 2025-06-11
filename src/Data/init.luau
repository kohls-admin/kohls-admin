-- have global datastore toggle
-- use queues?
-- debounce update async
-- eventually save player profiles as well as two main global datastores
-- TODO: make sure cache is valid json encoding by sanitizing key inputs as strings always

local Http = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Data = require(script.Defaults)

if RunService:IsClient() then
	return Data
end

local Auth = require(script.Parent.Auth)
local Migrate = require(script.Migrate)
local Hook = require(script.Parent.Hook)
local Util = require(script.Parent.Util)
local Remote = require(script.Parent.Remote)

-- DataStore value limit of 4,194,303 bytes
local DATA_LIMIT = 2 ^ 22 - 1

local nextDataLimitWarning = {}
local function dataLimitWarning(size, dataType)
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

-- BANS

local function syncBans(bans)
	Hook.preSyncBans:Fire(bans)

	local mergeBans = {}
	-- merge settings bans
	for key, ban in Data.settingsModuleData.bans do
		if Data.bans[key] then
			mergeBans[key] = ban
		end
	end
	-- merge server bans
	for key, ban in Data.bans do
		if ban and ban[3] == nil then
			mergeBans[key] = ban
		end
	end

	table.clear(Data.bans)
	Util.Table.merge(Data.bans, mergeBans)
	Util.Table.merge(Data.bans, bans)
	Util.Table.merge(Data.bans, Data.Cache.bans)
	Hook.postSyncBans:Fire(Data.bans)

	for _, player in Players:GetPlayers() do
		if player:GetAttribute("_K_READY") and Auth.hasCommand(player.UserId, "ban") then
			Remote.Bans:FireClient(player, Data.bans)
		end
	end
end

local nextBansInterval = tick() + Data.updateAsyncInterval
local function updateBans()
	nextBansInterval = math.huge
	-- flush cache and hold onto references to make sure they are immutable!
	local save = false
	local bans = Data.Cache.bans
	if next(bans) then
		save = true
		Data.Cache.bans = {}
	end

	local sync, updatedTime
	local ok, result = Data.Store.updateAsync("Bans", function(value, metaData)
		if not value then
			return Data.filterRemove(bans)
		end
		if metaData.UpdatedTime > Data.updatedTimeBans then
			sync, updatedTime = value, metaData.UpdatedTime
		end
		if not save then
			return
		end
		return Data.mergeRemove(value, bans)
	end)

	if ok then
		if sync then
			Data.updatedTimeBans = updatedTime
			task.defer(syncBans, result or sync)
		end
		task.defer(function()
			Data.sizeBans = #Http:JSONEncode(result or sync)
			dataLimitWarning(Data.sizeBans, "ban")
		end)
	else
		warn(`[Kohl's Admin] Main Datastore UpdateAsync failed: {result}`)
	end

	nextBansInterval = tick() + Data.updateAsyncInterval

	return ok, result
end

-- MAIN

local function fillMemberName(key, data)
	local userId = tonumber(key)
	data.name = Util.getUserInfo(userId).Username
	Data.Cache.members[key] = { data.name, data.persist }
	Auth.networkMember(key)
end

local function syncMain(result)
	Hook.preSyncMain:Fire(result)
	local members, settings = unpack(result)

	-- deserialize and add roles
	for key, data in members do
		local cache = Data.Cache.members[key]
		if cache then -- don't overwrite pending save!
			members[key] = nil
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

		-- append saved roles to cached roles
		data.roles = if Data.members[key] then Data.members[key].roles else table.clone(data.persist)
		if data.persist ~= data.roles then
			for _, roleId in data.persist do
				if data.persist ~= data.roles and not table.find(data.roles, roleId) then
					table.insert(data.roles, roleId)
				end
			end
		end

		table.sort(data.persist, Auth.roleIdSort)
		table.sort(data.roles, Auth.roleIdSort)
	end

	-- remove all saved roles when no saved member
	for key, data in Data.members do
		local cache = Data.Cache.members[key]
		if cache then -- don't overwrite pending save!
			members[key] = nil
		elseif not members[key] and #data.persist > 0 then
			for _, role in data.roles do
				if table.find(data.persist, role) then
					table.remove(data.roles, table.find(data.roles, role))
				end
			end
			if #data.roles == 0 then
				Data.members[key] = nil
				continue
			end
			table.clear(data.persist)
		end
	end

	Util.Table.merge(Data.members, members)

	-- fill missing names
	for key, data in Data.members do
		if not data.name and #data.persist > 0 then
			task.defer(fillMemberName, key, data)
		end
	end

	-- deserialize settings
	for key, setting in settings do
		if type(setting) == "table" then
			local itemType = setting[1]
			if itemType == "color" then
				settings[key] = Color3.new(unpack(setting, 2))
			elseif itemType == "udim" then
				settings[key] = UDim.new(unpack(setting, 2))
			elseif itemType == "enum" then
				settings[key] = Enum[setting[2]][setting[3]]
			end
		end
	end

	-- settings sync
	if type(settings.prefix) == "string" then
		Data.settings.prefix[1] = settings.prefix
		settings.prefix = Data.settings.prefix
	end
	Util.Table.merge(Data.settings, settings)

	for _, player in Players:GetPlayers() do
		if not player:GetAttribute("_K_READY") then
			continue
		end
		if Auth.hasCommand(player.UserId, "members") then
			Remote.Members:FireClient(player, Data.members)
		end
		Remote.Settings:FireClient(player, Data.settings)
	end
	Hook.postSyncMain:Fire(Data)
end

local nextMainInterval = tick() + Data.updateAsyncInterval * 4 / 3
local function updateMain()
	nextMainInterval = math.huge
	local save = false
	local members = Data.Cache.members
	local settings = Data.Cache.settings
	if next(members) or next(settings) then
		save = true
		Data.Cache.members = {}
		Data.Cache.settings = {}
	end

	local sync, updatedTime
	local ok, result = Data.Store.updateAsync("Main", function(value, metaData)
		if not value then
			return Data.filterRemove({ members, settings })
		end

		if metaData.UpdatedTime > Data.updatedTimeMain then
			sync, updatedTime = value, metaData.UpdatedTime
		end
		if not save then
			return
		end

		Data.mergeRemove(value[1], members)
		Util.Table.merge(value[2], settings)

		return value
	end)

	if ok then
		if sync then
			Data.updatedTimeMain = updatedTime
			task.defer(syncMain, result or sync)
		end
		task.defer(function()
			Data.sizeMain = #Http:JSONEncode(result or sync)
			dataLimitWarning(Data.sizeMain, "member")
		end)
	else
		warn(`[Kohl's Admin] Main Datastore UpdateAsync failed: {result}`)
		Data.Cache.members = Util.Table.merge(members, Data.Cache.members)
		Data.Cache.settings = Util.Table.merge(settings, Data.Cache.settings)
	end

	nextMainInterval = tick() + Data.updateAsyncInterval
end

-- LOGS

local function syncLogs(logsData)
	Hook.preSyncLogs:Fire(unpack(logsData))
	Util.Defer.reset()
	local newLogs = {}
	local newLogsRaw = {}
	for _, logData in logsData do
		if type(logData) ~= "table" then -- skip the size cache
			continue
		end
		for _, log in logData do
			Util.Defer.wait()
			local text, level, time, from, name = unpack(log)
			local fingerprint = table.concat({ text, level, time, from }, "|")
			if Data.logFingerprints[fingerprint] then
				continue
			end
			Data.logFingerprints[fingerprint] = true
			table.insert(
				newLogs,
				{ text = text, level = level, time = time, from = from, name = name, fingerprint = fingerprint }
			)
			table.insert(newLogsRaw, { text, level, time, from, name })
		end
	end
	if #newLogs > 0 then
		Util.Table.mergeList(Data.logs, newLogs)
		while #Data.logs > Util.Logger.limit do
			local removedLog = table.remove(Data.logs, 1)
			Data.logFingerprints[removedLog.fingerprint] = nil
			Util.Defer.wait()
		end
		table.sort(Data.logs, Util.Logger.sortTime)

		for _, player in Players:GetPlayers() do
			if player:GetAttribute("_K_READY") and Auth.hasPermission(player.UserId, "serverlogs") then
				Remote.Logs:FireClient(player, newLogsRaw)
			end
		end
	end
	Hook.postSyncLogs:Fire(unpack(logsData))
end

local function rawSortTime(a, b)
	return a[3] > b[3] -- reverse sort
end

local nextLogsInterval = tick() + Data.updateAsyncInterval * 5 / 3
local function updateLogs()
	nextLogsInterval = math.huge
	if Data.settings.saveLogs == false then
		return true
	end

	local save = false
	local chatLogs, logs = Data.Cache.chatLogs, Data.Cache.logs
	if next(chatLogs) or next(logs) then
		save = true
		Data.Cache.chatLogs, Data.Cache.logs = {}, {}
	end
	local chatSize, logsSize = #Http:JSONEncode(chatLogs), #Http:JSONEncode(logs)
	local dataStructureSize = #Http:JSONEncode({ {}, {}, math.ceil(DATA_LIMIT / 2), math.ceil(DATA_LIMIT / 2) })

	local sync, updatedTime
	local ok, result = Data.Store.updateAsync("LogsV2", function(value, metaData)
		if not value then
			return { chatLogs, logs, chatSize, logsSize }
		end
		if metaData.UpdatedTime > Data.updatedTimeLogs then
			sync, updatedTime = value, metaData.UpdatedTime
		end
		if not save then
			return
		end

		local savedChatLogs, savedLogs, savedChatSize, savedLogsSize = unpack(value)
		if not savedChatSize then
			savedChatSize = #Http:JSONEncode(savedChatLogs)
		end
		if not savedLogsSize then
			savedLogsSize = #Http:JSONEncode(savedLogs)
		end
		for index, data in
			{ { savedChatLogs, chatLogs, savedChatSize, chatSize }, { savedLogs, logs, savedLogsSize, logsSize } }
		do
			local savedData, newData, savedSize, newSize = unpack(data)
			Util.Table.mergeList(savedData, newData)
			table.sort(savedData, rawSortTime)

			local totalSize = savedSize + newSize
			local excess = totalSize - (math.ceil(DATA_LIMIT / 2) + dataStructureSize)
			local count = #savedData

			while excess > 0 do
				local logSize = #Http:JSONEncode(savedData[count]) + 1
				excess -= logSize
				totalSize -= logSize
				savedData[count] = nil
				count -= 1
			end
			value[index + 2] = totalSize
		end

		return value
	end)

	if ok then
		if sync then
			Data.updatedTimeLogs = updatedTime
			task.defer(syncLogs, sync)
		end
	else
		warn(`[Kohl's Admin] Logs Datastore UpdateAsync failed: {result}`)
		for logData, logCache in { [chatLogs] = Data.Cache.chatLogs, [logs] = Data.Cache.logs } do
			for _, log in logData do
				table.insert(logCache, log)
			end
			table.sort(logCache, rawSortTime)
		end
	end

	nextLogsInterval = tick() + Data.updateAsyncInterval

	return
end

function Data.initialize(scope)
	local store = Data.Store.loadStore("_KData", scope)
	if store == nil then
		Hook.initDataStore:Fire()
		return Data
	end

	local okMain, main, mainMetaData = Data.Store.getAsync("Main")
	if okMain then
		if main then
			Data.updatedTimeMain = mainMetaData.UpdatedTime
			syncMain(main)
		else -- first time load
			local bansKAI, mainKAI = Migrate.KAI()
			if bansKAI then
				print("[Kohl's Admin] Migrating Data from Kohl's Admin Infinite...")
				Data.Cache.bans = bansKAI
				Data.Cache.members = mainKAI[1]
				Data.Cache.settings = mainKAI[2]

				syncBans(bansKAI)
				syncMain(Util.Table.deepCopy(mainKAI))
			end
		end
	end

	local okBans, bans, bansMetaData = Data.Store.getAsync("Bans")
	if okBans then
		if bans then
			Data.updatedTimeBans = bansMetaData.UpdatedTime
			syncBans(bans)
		end
	end

	if Data.settings.saveLogs ~= false then
		local okLogs, logs, logsMetaData = Data.Store.getAsync("LogsV2")
		if okLogs then
			if logs then
				Data.updatedTimeLogs = logsMetaData.UpdatedTime
				syncLogs(logs)
			end
		end
	end

	local okServers, servers = Data.Store.getAsync("Servers")
	if okServers then
		if servers then
			Util.Table.merge(Data.reservedServers, servers)
			for _, player in Util.Service.Players:GetPlayers() do
				task.spawn(function()
					if Auth.hasCommand(player.UserId, "place") or Auth.hasCommand(player.UserId, "unreserve") then
						Remote.ReservedServers:FireClient(player, servers)
					end
				end)
			end
		end
	end

	Hook.initDataStore:Fire()

	task.spawn(function()
		repeat
			task.wait(1)
			if Data.Store.getBudget(Enum.DataStoreRequestType.UpdateAsync) <= 3 then
				continue
			end
			if tick() > nextMainInterval then
				task.defer(updateMain)
			end
			if tick() > nextBansInterval then
				task.defer(updateBans)
			end
			if tick() > nextLogsInterval then
				task.defer(updateLogs)
			end
		until Data.gameClosing
	end)

	game:BindToClose(function()
		Data.gameClosing = true

		local tasks = Util.Tasks.new()

		if Data.settings.vip and Data.settings.gameHubEnabled and Http.HttpEnabled and game.GameId > 0 then
			tasks:add(Http.RequestAsync, Http, { Method = "POST", Url = `https://api.kohl.gg/update/{game.GameId}` })
		end

		tasks:add(updateBans)
		tasks:add(updateMain)
		tasks:add(updateLogs)

		-- local function userSave(key, func)
		-- 	local success, result = Data.Store.updateAsync(key, func)
		-- 	if not success then
		-- 		warn(string.format("Failed to save %d's data: %s", key, result))
		-- 	end
		-- end

		-- TODO: prepare player data
		-- for userId, sessionData in Cache.players do
		--  tasks:add(userSave, userId, function(value)
		-- 		return sessionData
		-- 	end)
		-- end

		tasks:wait()
	end)

	return Data
end

return Data
