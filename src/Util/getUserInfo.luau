local Players = game:GetService("Players")
local UserService = game:GetService("UserService")

local Retry = require(script.Parent:WaitForChild("Retry"))
local Signal = require(script.Parent:WaitForChild("Signal"))

local userInfoCache =
	{} :: { [number]: { Id: number, Username: string, DisplayName: string, HasVerifiedBadge: boolean } }

local loading = {}
local function getUserInfo(userId: number, check: boolean?)
	userId = tonumber(userId) :: number

	if check or userInfoCache[userId] then
		return userInfoCache[userId]
	end

	local hook = loading[userId]
	if hook then
		return hook:Wait()
	end
	hook = Signal.new()
	loading[userId] = hook

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
		hook:Fire(info)
		return info
	end

	local ok, result = Retry(function()
		return UserService:GetUserInfosByUserIdsAsync({ userId })
	end, 5, 0.2 + math.random() / 5, 2)
	if ok and result then
		if not result[1] then -- deleted account
			result[1] = { Id = userId, Username = "Deleted", DisplayName = "Deleted", Deleted = true }
		end
		userInfoCache[userId] = result[1]
		hook:Fire(result[1])
		return result[1]
	end

	info = { Id = userId, Username = "Unknown", DisplayName = "Unknown", Unknown = true }
	userInfoCache[userId] = info

	hook:Fire(info)

	return info
end

return getUserInfo
