local Players = game:GetService("Players")
local UserService = game:GetService("UserService")

local Function = require(script.Parent:WaitForChild("Function"))
local Retry = require(script.Parent:WaitForChild("Retry"))
local Signal = require(script.Parent:WaitForChild("Signal"))

type UserInfo = {
	Id: number,
	Username: string,
	DisplayName: string,
	HasVerifiedBadge: boolean,
}

local userInfoCache =
	{} :: { [number]: { Id: number, Username: string, DisplayName: string, HasVerifiedBadge: boolean } }

local loading = {}
local debounceGetUserInfos
debounceGetUserInfos = Function.debounce(0.2, function()
	local userIds = {}
	for userId in loading do
		table.insert(userIds, userId)
	end

	local ok, result = Retry(function()
		return UserService:GetUserInfosByUserIdsAsync(userIds)
	end, 5, 0.2, 2)

	if ok and result then
		for _, info in result do
			userInfoCache[info.Id] = info
			local hook = loading[info.Id]
			if hook then
				hook:Fire(info)
				hook:DisconnectAll()
			end
			loading[info.Id] = nil
		end
		for _, userId in userIds do
			if not userInfoCache[userId] then
				local info = { Id = userId, Username = "Deleted", DisplayName = "Deleted", Deleted = true }
				userInfoCache[userId] = info
				local hook = loading[userId]
				if hook then
					hook:Fire(info)
					hook:DisconnectAll()
				end
				loading[userId] = nil
			end
		end
		return
	end

	task.delay(5, debounceGetUserInfos)
end)

local function getUserInfo(userId: number, checkCache: boolean?): UserInfo
	userId = tonumber(userId) :: number

	if checkCache or userInfoCache[userId] then
		return userInfoCache[userId]
	end

	local hook = loading[userId]
	if hook then
		return hook:Wait()
	end

	local info
	local player = Players:GetPlayerByUserId(userId)
	if player then
		info = {
			Id = userId,
			Username = player.Name,
			DisplayName = player.DisplayName,
			HasVerifiedBadge = player.HasVerifiedBadge,
		}
		userInfoCache[userId] = info
		return info
	end

	hook = Signal.new()
	loading[userId] = hook

	task.spawn(debounceGetUserInfos)
	return hook:Wait()
end

return getUserInfo
