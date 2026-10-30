local Players = game:GetService("Players")
local UserService = game:GetService("UserService")
local RunService = game:GetService("RunService")

local Signal = require(script.Parent:WaitForChild("Signal"))
local SafePlayerAdded = require(script.Parent:WaitForChild("SafePlayerAdded"))

type UserInfo = {
	Id: number,
	Username: string,
	DisplayName: string,
	HasVerifiedBadge: boolean,
}

local userInfoCache =
	{} :: { [number]: { Id: number, Username: string, DisplayName: string, HasVerifiedBadge: boolean } }

local REMOTE
if RunService:IsServer() then
	REMOTE = Instance.new("RemoteFunction")
	REMOTE.Parent = script
elseif RunService:IsClient() then
	REMOTE = script:WaitForChild("RemoteFunction")
end

local loading = {}
local scheduled = false

-- in-flight lookups per client: the server refuses more, since each parks a thread and queues
-- an id, and the client queues its own past this so long ban lists still resolve every name
local MAX_LOOKUPS = 32
local playerLookups = {} :: { [Player]: number }
local clientLookups = 0
local clientWaiting = {} :: { thread }

local function getUserInfos()
	local attempting = {}
	for userId in loading do
		if #attempting == 200 then
			break
		end
		table.insert(attempting, userId)
	end

	local attempt = 0
	local ok, result = pcall(UserService.GetUserInfosByUserIdsAsync, UserService, attempting)
	while not ok and attempt < 5 do
		attempt += 1
		task.wait(2 ^ attempt)
		ok, result = pcall(UserService.GetUserInfosByUserIdsAsync, UserService, attempting)
	end

	if ok and result then
		for _, info in result do
			userInfoCache[info.Id] = info
			local hook = loading[info.Id]
			if hook then
				hook:Fire(info)
				hook:Destroy()
			end
			loading[info.Id] = nil
		end
		for _, userId in attempting do
			if not userInfoCache[userId] then
				userInfoCache[userId] = { Id = userId, Username = "Deleted", DisplayName = "Deleted", Deleted = true }
			end
			local hook = loading[userId]
			if hook then
				hook:Fire(userInfoCache[userId])
				hook:Destroy()
			end
			loading[userId] = nil
		end
		return
	end

	error(result, 0)
end

-- one batch at a time: lookups queued while a batch waits or runs join the next one, so
-- new lookups never restart or cancel a batch, and a batch starts within `delay` of the first
local function scheduleGetUserInfos(delay: number)
	if scheduled then
		return
	end
	scheduled = true
	task.delay(delay, function()
		local ok, err = pcall(getUserInfos)
		scheduled = false
		if not ok then
			warn(`getUserInfo failed: {err}`)
			scheduleGetUserInfos(5)
		elseif next(loading) then
			scheduleGetUserInfos(0.2)
		end
	end)
end

local function getUserInfo(userId: number, checkCache: boolean?): UserInfo
	userId = tonumber(userId) :: number
	if not userId then
		return { Id = userId, Username = "Unknown", DisplayName = "Unknown", HasVerifiedBadge = false }
	end

	if checkCache or userInfoCache[userId] then
		return userInfoCache[userId]
	end

	if RunService:IsClient() then
		-- lookups of the same id share one invoke, like the server's batches
		local hook = loading[userId]
		if hook then
			return hook:Wait()
		end
		hook = Signal.new()
		loading[userId] = hook

		if clientLookups < MAX_LOOKUPS then
			clientLookups += 1
		else
			table.insert(clientWaiting, coroutine.running())
			coroutine.yield()
		end

		-- a failed invoke must still hand its slot on
		local ok, info = pcall(REMOTE.InvokeServer, REMOTE, userId)

		local thread = table.remove(clientWaiting, 1)
		if thread then
			task.spawn(thread)
		else
			clientLookups -= 1
		end

		if ok and info then
			userInfoCache[userId] = info
		else
			info = { Id = userId, Username = "Unknown", DisplayName = "Unknown", HasVerifiedBadge = false }
		end
		loading[userId] = nil
		hook:Fire(info)
		hook:Destroy()
		return info
	end

	-- one id the Web API rejects would fail every batch it joins and keep it queued forever
	if userId < 1 or userId > 2 ^ 53 or userId % 1 ~= 0 then
		return { Id = userId, Username = "Unknown", DisplayName = "Unknown", HasVerifiedBadge = false }
	end

	local hook = loading[userId]
	if hook then
		return hook:Wait()
	end

	hook = Signal.new()
	loading[userId] = hook

	scheduleGetUserInfos(0.2)

	return hook:Wait()
end

if RunService:IsServer() then
	local function onServerInvoke(player, userId)
		-- a request handled after the player left would count again with nothing left to clear it
		if typeof(userId) ~= "number" or player.Parent ~= Players then
			return
		end
		local lookups = playerLookups[player] or 0
		if lookups >= MAX_LOOKUPS then
			return
		end
		playerLookups[player] = lookups + 1
		local info = getUserInfo(userId)
		-- the player may have left while it waited
		if playerLookups[player] then
			playerLookups[player] -= 1
		end
		-- the Unknown placeholder is not cached here, so the client falls back to its own
		return if userInfoCache[userId] then info else nil
	end
	REMOTE.OnServerInvoke = onServerInvoke

	local _ = Players.PlayerRemoving:Connect(function(player)
		playerLookups[player] = nil
	end)
end

SafePlayerAdded(function(player)
	userInfoCache[player.UserId] = {
		Id = player.UserId,
		Username = player.Name,
		DisplayName = player.DisplayName,
		HasVerifiedBadge = player.HasVerifiedBadge,
	}
end)

return getUserInfo
