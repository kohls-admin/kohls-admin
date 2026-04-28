local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Package = script.Parent
local Shared = Package.Shared.Value

local Remote = require(Shared.Util.Remote) :: any
local SafeTeleport = require(Shared.Util.SafeTeleport) :: any

local THROTTLE = 15
local TOPIC = "_KAdminServers"
local SERVER_ID = game.JobId

local EXPIRE = THROTTLE * 2 + 5

local SERVERS_REMOTE = Remote.Servers

local Map: { [string]: { number } } = {}
local ServersSubscribers: { [Player]: boolean? } = {}

local Servers = {
	Map = Map,
	Subscribers = ServersSubscribers,
}

if RunService:IsServer() then
	local START = DateTime.now().UnixTimestamp

	local function network(jobId: string, data: any)
		for player: Player, subscribed: boolean? in ServersSubscribers do
			if subscribed then
				SERVERS_REMOTE:Fire(player, jobId, data)
			end
		end
	end

	local function publish()
		if not RunService:IsStudio() then
			MessagingService:PublishAsync(TOPIC, { SERVER_ID, game.PlaceId, #Players:GetPlayers(), START })
		end
	end

	local function subscribe()
		MessagingService:SubscribeAsync(TOPIC, function(message)
			local data = message.Data
			if
				type(data) ~= "table"
				or type(data[1]) ~= "string"
				or type(data[2]) ~= "number"
				or type(data[3]) ~= "number"
				or type(data[4]) ~= "number"
			then
				return
			end

			local jobId, placeId, count, start = unpack(data)
			if jobId == SERVER_ID then
				return
			end

			local changed = true
			local existing = Map[jobId]
			local now = tick()

			if existing then
				changed = existing[2] ~= count
				existing[2], existing[4] = count, now
			else
				existing = { placeId, count, start, now }
				Map[jobId] = existing
			end

			if changed then
				network(jobId, existing)
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

	local function cleanup()
		local expireTime = tick() - EXPIRE
		for jobId, data in Map do
			local updated = data[4]
			if type(updated) == "number" and updated < expireTime then
				Map[jobId] = nil
				network(jobId)
			end
		end
	end

	task.spawn(function()
		while true do
			task.spawn(cleanup)
			task.spawn(publish)
			task.wait(THROTTLE)
		end
	end)

	Remote.TeleportToServer:Connect(function(player: Player, placeId: number, jobId: string)
		if
			jobId ~= SERVER_ID
			and ServersSubscribers[player] ~= nil
			and type(placeId) == "number"
			and type(jobId) == "string"
		then
			local options = Instance.new("TeleportOptions")
			options.ServerInstanceId = jobId
			SafeTeleport(placeId, { player }, options)
		end
	end)
end

return Servers
