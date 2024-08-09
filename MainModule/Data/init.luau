-- have global datastore toggle
-- use queues?
-- debounce update async
-- eventually save player profiles as well as two main global datastores

-- TODO: make sure cache is valid json encoding by sanitizing key inputs as strings always

local RunService = game:GetService("RunService")

local Data = require(script.Defaults)
local Util = require(script.Parent.Util)
local Remote = require(script.Parent.Remote)

if RunService:IsClient() then
	return Data
end

Data.Store = require(script.Store)

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
	local bans = Data.Cache.bans
	local members = Data.Cache.members
	local settings = Data.Cache.settings
	Data.Cache.bans = {}
	Data.Cache.members = {}
	Data.Cache.settings = {}

	local ok, result = Data.Store.updateAsync("Main", function(value)
		print("updateAsync", value, members)
		if not value then
			return Data.Store.filterRemove({ bans, members, settings })
		end

		Data.Store.mergeRemove(value[1], bans)
		Data.Store.mergeRemove(value[2], members)

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
	Data.Store.loadStore(name)

	print("[Kohl's Admin] Loading data...")
	local okMain, main = Data.Store.getAsync("Main")
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

	local okLogs, logs = Data.Store.getAsync("Logs")
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
				print("attempting a main save!", Data.Cache)
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
			local success, result = Data.Store.updateAsync(key, func)

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
