local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Package = script.Parent
local Shared = Package.Shared.Value

local Remote = require(Shared.Util.Remote :: ModuleScript)
local Retry = require(Shared.Util.Retry :: ModuleScript)
local SafeTeleport = require(Shared.Util.SafeTeleport :: ModuleScript)

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
	Enabled = false,
}

if RunService:IsServer() then
	local START = DateTime.now().UnixTimestamp
	local started = false
	local subscribed = false

	local function network(jobId: string, data: any)
		for player: Player, isSubscribed: boolean? in ServersSubscribers do
			if isSubscribed then
				SERVERS_REMOTE:Fire(player, jobId, data)
			end
		end
	end

	local function publish()
		if not RunService:IsStudio() then
			Retry(function()
				MessagingService:PublishAsync(TOPIC, { SERVER_ID, game.PlaceId, #Players:GetPlayers(), START })
			end, 2)
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

	function Servers.start()
		Servers.Enabled = true
		if started then
			return
		end
		started = true
		if not subscribed then
			subscribed = true
			task.spawn(function()
				if not Retry(subscribe, 5) then
					subscribed = false
				end
			end)
		end
		task.spawn(function()
			while Servers.Enabled do
				task.spawn(cleanup)
				task.spawn(publish)
				task.wait(THROTTLE)
			end
			started = false
		end)
	end

	local _ = Remote.TeleportToServer:Connect(function(player: Player, placeId: number, jobId: string)
		-- only servers this server knows about, the servers list shows the same entries
		local server = type(jobId) == "string" and Map[jobId]
		if jobId ~= SERVER_ID and ServersSubscribers[player] ~= nil and server and server[1] == placeId then
			local options = Instance.new("TeleportOptions")
			options.ServerInstanceId = jobId
			SafeTeleport(placeId, { player }, options)
		end
	end)
end

return Servers
