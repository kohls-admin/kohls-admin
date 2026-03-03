local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local THROTTLE = 15
local TOPIC = "_KAdminServers"
local SERVER_ID = game.JobId ~= "" and game.JobId

local Map: { [string]: { number } } = {}

local Servers = {
	ChangedCallbacks = {},
	Map = Map,
}

if RunService:IsServer() then
	local START = DateTime.now().UnixTimestamp

	local function cleanup()
		local expireTime = tick() - (THROTTLE * 2) - 5
		for jobId, data in Map do
			local updated = data[3]
			if type(updated) == "number" and updated < expireTime then
				Map[jobId] = nil
				for _, callback in Servers.ChangedCallbacks do
					if type(callback) == "function" then
						task.spawn(callback, jobId)
					end
				end
			end
		end
	end

	local function publish()
		MessagingService:PublishAsync(TOPIC, { SERVER_ID, game.PlaceId, #Players:GetPlayers(), START })
	end

	local function subscribe()
		MessagingService:SubscribeAsync(TOPIC, function(message)
			local data = message.Data
			if
				type(data) ~= "table"
				or type(data[1]) ~= "string"
				or type(data[2]) ~= "number"
				or type(data[3]) ~= "number"
			then
				return
			end

			local jobId, placeId, count, start = unpack(data)
			if jobId == SERVER_ID then
				return
			end

			local changed
			local existing = Map[jobId]
			local now = tick()

			if existing then
				changed = existing[2] ~= count
				existing[2], existing[4] = count, now
			else
				changed = true
				existing = { placeId, count, start, now }
				Map[jobId] = existing
			end

			if changed and type(Servers.ChangedCallbacks) == "table" then
				for _, callback in Servers.ChangedCallbacks do
					if type(callback) == "function" then
						task.spawn(callback, jobId, existing)
					end
				end
			end
		end)
	end

	task.spawn(function()
		local attempts, ok = 0, false
		repeat
			ok = pcall(subscribe)
			task.wait(2 ^ attempts)
		until ok
	end)

	if not RunService:IsStudio() then
		task.spawn(function()
			while true do
				task.spawn(cleanup)
				task.spawn(publish)
				task.wait(THROTTLE)
			end
		end)
	end
end

return Servers
