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
local attempting = {}
local debounceGetUserInfos
debounceGetUserInfos = Function.debounce(0.2, function()
	for userId in loading do
		table.insert(attempting, userId)
		if #attempting == 200 then
			break
		end
	end

	local ok, result = Retry(function()
		return UserService:GetUserInfosByUserIdsAsync(attempting)
	end)

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
		for _, userId in attempting do
			if not userInfoCache[userId] then
				local info = { Id = userId, Username = "Deleted", DisplayName = "Deleted", Deleted = true }
				userInfoCache[userId] = info
				local hook = loading[userId]
				if hook then
					hook:Fire(info)
					hook:DisconnectAll()
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
