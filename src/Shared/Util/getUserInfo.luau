local UserService = game:GetService("UserService")
local RunService = game:GetService("RunService")

local Function = require(script.Parent:WaitForChild("Function"))
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
	REMOTE = Instance.new("RemoteFunction", script)
elseif RunService:IsClient() then
	REMOTE = script:WaitForChild("RemoteFunction")
end

local loading = {}
local attempting = {}
local debounceGetUserInfos
debounceGetUserInfos = Function.debounce(0.2, function()
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
				local info = { Id = userId, Username = "Deleted", DisplayName = "Deleted", Deleted = true }
				userInfoCache[userId] = info
				local hook = loading[userId]
				if hook then
					hook:Fire(info)
					hook:Destroy()
				end
			end
			loading[userId] = nil
		end

		table.clear(attempting)
		if next(loading) then
			task.defer(debounceGetUserInfos)
		end
		return
	end

	warn(`getUserInfo failed: {result}`)

	task.delay(5, debounceGetUserInfos)
end)

local function getUserInfo(userId: number, checkCache: boolean?): UserInfo
	userId = tonumber(userId) :: number
	if not userId then
		return { Id = userId, Username = "Unknown", DisplayName = "Unknown", HasVerifiedBadge = false }
	end

	if checkCache or userInfoCache[userId] then
		return userInfoCache[userId]
	end

	if RunService:IsClient() then
		local info = REMOTE:InvokeServer(userId)
		if not info then
			return { Id = userId, Username = "Unknown", DisplayName = "Unknown", HasVerifiedBadge = false }
		end
		userInfoCache[userId] = info
		return info
	end

	local hook = loading[userId]
	if hook then
		return hook:Wait()
	end

	hook = Signal.new()
	loading[userId] = hook

	task.defer(debounceGetUserInfos)

	return hook:Wait()
end

if RunService:IsServer() then
	-- uncached lookups hit UserService and stay cached, so each client gets a budget of them
	local LOOKUP_BUDGET, LOOKUP_WINDOW = 30, 10
	local lookups: { [Player]: { start: number, count: number } } = {}

	game:GetService("Players").PlayerRemoving:Connect(function(player)
		lookups[player] = nil
	end)

	REMOTE.OnServerInvoke = function(player, userId)
		userId = tonumber(userId)
		if not userId or userId < 1 or userId >= 2 ^ 53 or userId % 1 ~= 0 then
			return nil
		end
		local cached = userInfoCache[userId]
		if cached then
			return cached
		end
		local now = os.clock()
		local budget = lookups[player]
		if not budget or now - budget.start > LOOKUP_WINDOW then
			budget = { start = now, count = 0 }
			lookups[player] = budget
		end
		if budget.count >= LOOKUP_BUDGET then
			return nil
		end
		budget.count += 1
		return getUserInfo(userId)
	end
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
