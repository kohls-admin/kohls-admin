-- have global datastore toggle
-- use queues?
-- debounce update async
-- eventually save player profiles as well as two main global datastores
-- TODO: make sure cache is valid json encoding by sanitizing key inputs as strings always

local Http = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Auth = require(script.Parent.Auth)
local Data = require(script.Defaults)
local Migrate = require(script.Migrate)
local Hook = require(script.Parent.Hook)
local Util = require(script.Parent.Util)
local Remote = require(script.Parent.Remote)

if RunService:IsClient() then
	return Data
end

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
				Remote.Notify:FireClient(player, {
					From = "_K",
					Text = `<b><font color="#f00">You're approaching the limit of Roblox DataStores!</font>\n\tConsider removing some {dataType}s.</b>\n\n<b>Data Usage:</b> {string.format(
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
	Util.Table.merge(Data.bans, bans)
	Hook.postSyncBans:Fire(Data)

	for _, player in Players:GetPlayers() do
		if Auth.hasCommand(player.UserId, "ban") then
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

	local sync
	local ok, result, metaData = Data.Store.updateAsync("Bans", function(value, metaData)
		if not value then
			return Data.Store.filterRemove(bans)
		end
		if metaData.UpdatedTime > Data.updatedTimeBans then
			sync = value
		end
		if not save then
			return
		end
		return Data.Store.mergeRemove(value, bans)
	end)

	if ok then
		if metaData and (save or sync) then
			Data.updatedTimeBans = metaData.UpdatedTime
		end
		if sync then
			task.spawn(syncBans, result or sync)
		end
		task.spawn(function()
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
end

local function syncMain(result)
	Hook.preSyncMain:Fire(result)
	local members, settings = unpack(result)

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
			table.sort(data.persist, Auth.roleSort)
		end
		table.sort(data.roles, Auth.roleSort)
	end
	for key, data in Data.members do
		local cache = Data.Cache.members[key]
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
	Util.Table.merge(Data.members, members)

	-- fill missing names
	for key, data in Data.members do
		if not data.name and #data.persist > 0 then
			task.spawn(fillMemberName, key, data)
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
	Util.Table.merge(Data.settings, settings)

	for _, player in Players:GetPlayers() do
		if Auth.hasCommand(player.UserId, "members") then
			Remote.Members:FireClient(player, Data.members)
		end

		Remote.Settings:FireClient(player, Data.settings)
	end
	Hook.postSyncMain:Fire(Data)
end

local nextMainInterval = tick() + Data.updateAsyncInterval
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

	local sync
	local ok, result, metaData = Data.Store.updateAsync("Main", function(value, metaData)
		if not value then
			return Data.Store.filterRemove({ members, settings })
		end

		if metaData.UpdatedTime > Data.updatedTimeMain then
			sync = value
		end
		if not save then
			return
		end

		Data.Store.mergeRemove(value[1], members)
		Util.Table.merge(value[2], settings)

		return value
	end)

	if ok then
		if metaData and (save or sync) then
			Data.updatedTimeMain = metaData.UpdatedTime
		end
		if sync then
			task.spawn(syncMain, result or sync)
		end
		task.spawn(function()
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
		for _, log in logData do
			Util.Defer.wait()
			local text, level, time, from, name = unpack(log)
			local exists
			for _, existingLog in Data.logs do
				if
					existingLog.time == time
					and existingLog.from == from
					and existingLog.level == level
					and existingLog.text == text
				then
					exists = true
					break
				end
			end
			if exists then
				continue
			end

			table.insert(newLogs, { text = text, level = level, time = time, from = from, name = name })
			table.insert(newLogsRaw, { text, level, time, from, name })
		end
	end
	table.move(newLogs, 1, #newLogs, #Data.logs + 1, Data.logs)
	Util.Defer.wait()
	table.sort(Data.logs, Util.Logger.sortTime)
	for _, player in Players:GetPlayers() do
		if Auth.hasPermission(player.UserId, "serverlogs") then
			Remote.Logs:FireClient(player, newLogsRaw)
		end
	end
	Hook.postSyncLogs:Fire(unpack(logsData))
end

local function rawSortTime(a, b)
	return a[3] > b[3] -- reverse sort
end

local nextLogsInterval = tick() + Data.updateAsyncInterval
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

	local sync
	local ok, result, metaData = Data.Store.updateAsync("LogsV2", function(value, metaData)
		if not value then
			return { chatLogs, logs }
		end
		if metaData.UpdatedTime > Data.updatedTimeLogs then
			sync = value
		end
		if not save then
			return
		end

		local savedChatLogs, savedLogs = unpack(value)
		for logData, savedlogData in { [chatLogs] = savedChatLogs, [logs] = savedLogs } do
			for _, log in logData do
				table.insert(savedlogData, log)
			end
			table.sort(savedlogData, rawSortTime)

			local logDataSize = #Http:JSONEncode(logData)
			local excess = logDataSize - math.ceil(DATA_LIMIT / 2)
			local count = #logData

			while excess > 0 do
				excess -= #Http:JSONEncode(logData[count]) + 1
				logData[count] = nil
				count -= 1
			end
		end

		return value
	end)

	if ok then
		if metaData and (save or sync) then
			Data.updatedTimeLogs = metaData.UpdatedTime
		end
		if sync then
			task.spawn(syncLogs, sync)
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

function Data.initialize(name)
	local store = Data.Store.loadStore(name)
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

	Hook.initDataStore:Fire()

	task.spawn(function()
		repeat
			task.wait(1)
			if tick() > nextMainInterval then
				task.spawn(updateMain)
			end
			if tick() > nextBansInterval then
				task.spawn(updateBans)
			end
			if tick() > nextLogsInterval then
				task.spawn(updateLogs)
			end
		until Data.gameClosing
	end)

	game:BindToClose(function()
		Data.gameClosing = true

		local tasks = Util.TaskGroup.new()

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
