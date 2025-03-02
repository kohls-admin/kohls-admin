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

local updateAsyncInterval = 30

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

local nextBansInterval = tick() + updateAsyncInterval
local function updateBans()
	nextBansInterval = math.huge
	-- flush cache and hold onto references to make sure they are immutable!
	local bans = Data.Cache.bans
	Data.Cache.bans = {}

	local ok, result = Data.Store.updateAsync("Bans", function(value)
		print("updateAsyncBans", value, bans)
		if not value then
			return Data.Store.filterRemove(bans)
		end
		return Data.Store.mergeRemove(value, bans)
	end)

	if ok then
		task.spawn(function()
			Data.sizeBans = #Http:JSONEncode(result)
			dataLimitWarning(Data.sizeBans, "ban")
		end)
		Data.pendingSaveBans = false
		syncBans(result)
	else
		warn(`[Kohl's Admin] Main Datastore UpdateAsync failed: {result}`)
	end

	nextBansInterval = tick() + updateAsyncInterval

	return ok, result
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
			-- TODO: sort roles
		end
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

local nextMainInterval = tick() + updateAsyncInterval
local function updateMain()
	nextMainInterval = math.huge
	-- flush cache and hold onto references to make sure they are immutable!
	local members = Data.Cache.members
	local settings = Data.Cache.settings
	Data.Cache.members = {}
	Data.Cache.settings = {}

	local ok, result = Data.Store.updateAsync("Main", function(value)
		print("updateAsyncMain", value, members, settings)
		if not value then
			return Data.Store.filterRemove({ members, settings })
		end

		Data.Store.mergeRemove(value[1], members)
		Util.Table.merge(value[2], settings)

		return value
	end)

	if ok then
		task.spawn(function()
			Data.sizeMain = #Http:JSONEncode(result)
			dataLimitWarning(Data.sizeMain, "member")
		end)
		Data.pendingSaveMain = false
		syncMain(result)
	else
		warn(`[Kohl's Admin] Main Datastore UpdateAsync failed: {result}`)
	end

	nextMainInterval = tick() + updateAsyncInterval

	return ok, result
end

-- LOGS

local function syncLogs(logs)
	Hook.preSyncLogs:Fire(logs)
	Util.Defer.reset()
	local newLogs = {}
	for _, log in logs do
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
	end
	table.move(newLogs, 1, #newLogs, #Data.logs + 1, Data.logs)
	table.sort(Data.logs, Data.sortTime)
	for _, player in Players:GetPlayers() do
		if Auth.hasPermission(player.UserId, "serverlogs") then
			Remote.Logs:FireClient(player, newLogs)
		end
	end
	Hook.postSyncLogs:Fire(logs)
end

local function rawSortTime(a, b)
	return a[3] > b[3]
end

local nextLogsInterval = tick() + updateAsyncInterval
local function updateLogs()
	nextLogsInterval = math.huge

	local logs = Data.Cache.logs
	Data.Cache.logs = {}

	local ok, result = Data.Store.updateAsync("Logs", function(value)
		print("updateAsyncLog", value, logs)
		if not value then
			return logs
		end

		for _, log in logs do
			table.insert(value, log)
		end
		table.sort(value, rawSortTime)

		local logDataSize = #Http:JSONEncode(value)
		local excess = logDataSize - DATA_LIMIT
		local count = #value

		while excess > 0 do
			excess -= #Http:JSONEncode(value[count]) + 1
			value[count] = nil
			count -= 1
		end

		return value
	end)

	if ok then
		Data.pendingSaveLogs = false
		syncLogs(result)
	else
		warn(`[Kohl's Admin] Logs Datastore UpdateAsync failed: {result}`)
	end

	nextLogsInterval = tick() + updateAsyncInterval

	return ok, result
end

function Data.initialize(name)
	local store = Data.Store.loadStore(name)
	if store == nil then
		Hook.initDataStore:Fire()
		return Data
	end

	print("[Kohl's Admin] Loading data...")
	local okMain, main = Data.Store.getAsync("Main")
	if okMain then
		print("MainLoad", main)
		if main then
			syncMain(main)
		else -- first time load
			local bansKAI, mainKAI = Migrate.KAI()
			if bansKAI then
				print("[Kohl's Admin] Migrating Data from Kohl's Admin Infinite...")
				Data.Cache.bans = bansKAI
				Data.Cache.members = mainKAI[1]
				Data.Cache.settings = mainKAI[2]
				Data.pendingSaveBans = true
				Data.pendingSaveMain = true

				syncBans(bansKAI)
				syncMain(Util.Table.deepCopy(mainKAI))
			end
		end
	end

	local okBans, bans = Data.Store.getAsync("Bans")
	if okBans then
		print("BansLoad", bans)
		if bans then
			syncBans(bans)
		end
	end

	local okLogs, logs = Data.Store.getAsync("Logs")
	if okLogs then
		print("LogsLoad", logs)
		if logs then
			syncLogs(logs)
		end
	end

	Hook.initDataStore:Fire()

	if RunService:IsStudio() then
		-- Avoid writing studio data to production and stalling test session closing
		return Data
	end

	task.spawn(function() -- bans save loop
		repeat
			task.wait(1)
			if tick() > nextBansInterval and Data.pendingSaveBans then
				print("attempting a bans save!", Data.Cache.bans)
				updateBans()
			end
		until Data.gameClosing
	end)

	task.spawn(function() -- logs save loop
		repeat
			task.wait(1)
			if tick() > nextLogsInterval and Data.pendingSaveLogs then
				print("attempting a logs save!", Data.Cache.logs)
				updateLogs()
			end
		until Data.gameClosing
	end)

	task.spawn(function() -- main save loop
		repeat
			task.wait(1)
			if tick() > nextMainInterval and Data.pendingSaveMain then
				print("attempting a main save!", Data.Cache)
				updateMain()
			end
		until Data.gameClosing
	end)

	game:BindToClose(function()
		Data.gameClosing = true

		local mainThread = coroutine.running()
		local numThreadsRunning = 0

		local function startSaveThread(key, func)
			local success, result = Data.Store.updateAsync(key, func)

			if not success then
				warn(string.format("Failed to save %d's data: %s", key, result))
			end

			numThreadsRunning -= 1

			if numThreadsRunning == 0 then
				coroutine.resume(mainThread)
			end
		end

		if Data.settings.vip and Data.settings.gameHubEnabled and Http.HttpEnabled and game.GameId > 0 then
			numThreadsRunning += 1
			task.defer(function()
				Http:RequestAsync({ Method = "POST", Url = `https://api.kohl.gg/update/{game.GameId}` })
				numThreadsRunning -= 1
				if numThreadsRunning == 0 then
					coroutine.resume(mainThread)
				end
			end)
		end

		if Data.pendingSaveBans then
			numThreadsRunning += 1
			task.defer(function()
				updateBans()
				numThreadsRunning -= 1
				if numThreadsRunning == 0 then
					coroutine.resume(mainThread)
				end
			end)
		end

		if Data.pendingSaveMain then
			numThreadsRunning += 1
			task.defer(function()
				updateMain()
				numThreadsRunning -= 1
				if numThreadsRunning == 0 then
					coroutine.resume(mainThread)
				end
			end)
		end

		if Data.pendingSaveLogs then
			numThreadsRunning += 1
			task.defer(function()
				updateLogs()
				numThreadsRunning -= 1
				if numThreadsRunning == 0 then
					coroutine.resume(mainThread)
				end
			end)
		end

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
