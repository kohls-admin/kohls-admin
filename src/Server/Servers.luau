local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Package = script.Parent
local Shared = Package.Shared.Value

local Data = require(Shared.Data :: ModuleScript)
local Remote = require(Shared.Util.Remote :: ModuleScript)
local Retry = require(Shared.Util.Retry :: ModuleScript)
local SafeTeleport = require(Shared.Util.SafeTeleport :: ModuleScript)

local THROTTLE = 15
local SYNC_COOLDOWN = 5
local TOPIC = "_KAdminServers"
local SERVER_ID = game.JobId

local EXPIRE = THROTTLE * 2 + 5
local MAX_TTL = 600

local SERVERS_REMOTE = Remote.Servers

local Map: { [string]: { number } } = {}
local ServersSubscribers: { [Player]: boolean? } = {}

local Servers = {
	Map = Map,
	Subscribers = ServersSubscribers,
	Enabled = false,
	syncSubscription = function() end,
	start = function() end,
}

if RunService:IsServer() then
	local START = DateTime.now().UnixTimestamp
	local started = false
	local subscribing = false
	local subscriptionConn: RBXScriptConnection? = nil
	local lastPublishClock = 0
	local lastSyncRequestClock = 0
	local syncReplyPending = false
	local knownServerCount = 1

	local function hasSubscribers(): boolean
		for _, isSubscribed in ServersSubscribers do
			if isSubscribed then
				return true
			end
		end
		return false
	end

	local function canPublish(): boolean
		return not RunService:IsStudio() and game.PrivateServerId == ""
	end

	local function countMap(): number
		local count = 1
		for _ in Map do
			count += 1
		end
		return count
	end

	local function getInterval(): number
		return math.max(THROTTLE, countMap(), knownServerCount, 1)
	end

	local function network(jobId: string, data: any)
		for player: Player, isSubscribed: boolean? in ServersSubscribers do
			if isSubscribed then
				SERVERS_REMOTE:Fire(player, jobId, data)
			end
		end
	end

	local function publish()
		if canPublish() then
			lastPublishClock = os.clock()
			local interval = getInterval()
			Retry(function()
				MessagingService:PublishAsync(
					TOPIC,
					{ SERVER_ID, game.PlaceId, #Players:GetPlayers(), START, interval * 2 + 5 }
				)
			end, 2)
		end
	end

	local function onMessage(message: any)
		local data = if type(message) == "table" then message.Data else nil
		if
			type(data) ~= "table"
			or type(data[1]) ~= "string"
			or type(data[2]) ~= "number"
			or type(data[3]) ~= "number"
			or type(data[4]) ~= "number"
		then
			return
		end

		local jobId, placeId, count, start, ttl = table.unpack(data, 1, 5)
		if jobId == SERVER_ID then
			return
		end

		local changed = true
		local existing = Map[jobId]
		local now = os.clock()
		local expireOffset = EXPIRE
		if type(ttl) == "number" and ttl == ttl then
			expireOffset = math.clamp(ttl, EXPIRE, MAX_TTL)
		end

		if existing then
			changed = existing[2] ~= count or existing[1] ~= placeId
			existing[1], existing[2], existing[4], existing[5] = placeId, count, now, expireOffset
		else
			existing = { placeId, count, start, now, expireOffset }
			Map[jobId] = existing
		end

		knownServerCount = math.max(knownServerCount, countMap())

		if changed then
			network(jobId, existing)
		end
	end

	local function cleanup()
		local now = os.clock()
		local defaultExpireTime = now - EXPIRE
		for jobId, data in Map do
			local updated = data[4]
			local ttl = data[5]
			local expireTime = if type(ttl) == "number" then now - ttl else defaultExpireTime
			if type(updated) == "number" and updated < expireTime then
				Map[jobId] = nil
				network(jobId)
			end
		end
		knownServerCount = math.max(countMap(), math.floor(knownServerCount * 0.5))
	end

	Data.subscribeTopic("serversSync", function(packet)
		local payload = packet and packet.Data
		local senderJobId = if type(payload) == "table" then payload[1] else payload
		local rawCount = if type(payload) == "table" then payload[2] else nil
		local senderCount = if type(rawCount) == "number" and rawCount == rawCount
			then math.clamp(rawCount, 1, 10000)
			else nil
		if senderCount then
			knownServerCount = math.max(knownServerCount, senderCount)
		end
		if senderJobId and senderJobId ~= SERVER_ID and Servers.Enabled and canPublish() then
			if not syncReplyPending and os.clock() - lastPublishClock >= SYNC_COOLDOWN then
				syncReplyPending = true
				lastPublishClock = os.clock()
				task.spawn(function()
					task.wait(math.random() * 2)
					syncReplyPending = false
					if Servers.Enabled then
						publish()
					end
				end)
			end
		end
	end)

	function Servers.syncSubscription()
		if not Servers.Enabled then
			return
		end
		if hasSubscribers() then
			cleanup()
			if subscriptionConn or subscribing then
				return
			end
			subscribing = true
			task.spawn(function()
				local ok, conn = Retry(function()
					return MessagingService:SubscribeAsync(TOPIC, onMessage)
				end, 5)
				subscribing = false
				if ok and conn then
					if not Servers.Enabled or not hasSubscribers() then
						conn:Disconnect()
						return
					end
					subscriptionConn = conn
					if canPublish() and os.clock() - lastSyncRequestClock >= SYNC_COOLDOWN then
						lastSyncRequestClock = os.clock()
						task.spawn(
							Data.publishTopic,
							"serversSync",
							{ SERVER_ID, math.max(countMap(), knownServerCount, 1) }
						)
					end
				end
			end)
		elseif subscriptionConn then
			knownServerCount = math.max(countMap(), math.floor(knownServerCount * 0.5))
			local conn = subscriptionConn
			subscriptionConn = nil
			conn:Disconnect()
		end
	end

	function Servers.start()
		Servers.Enabled = true
		Servers.syncSubscription()
		if started then
			return
		end
		started = true
		task.spawn(function()
			while Servers.Enabled do
				cleanup()
				if canPublish() then
					task.spawn(publish)
				end
				task.wait(getInterval())
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
