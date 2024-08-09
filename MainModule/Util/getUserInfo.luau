local Players = game:GetService("Players")
local UserService = game:GetService("UserService")

local userInfoCache =
	{} :: { [number]: { Id: number, Username: string, DisplayName: string, HasVerifiedBadge: boolean } }

local function getUserInfo(userId: number)
	userId = tonumber(userId) :: number

	if userInfoCache[userId] then
		-- TODO: if loading then retry after a delay?
		return userInfoCache[userId]
	end

	local player = Players:GetPlayerByUserId(userId)
	if player then
		userInfoCache[userId] = {
			Id = userId,
			Username = player.Name,
			DisplayName = player.DisplayName,
			HasVerifiedBadge = player.HasVerifiedBadge,
		}
		return userInfoCache[userId]
	end

	local ok, result = pcall(UserService.GetUserInfosByUserIdsAsync, UserService, { userId })
	if ok and result and result[1] then
		userInfoCache[userId] = result[1]
		return result[1]
	end

	userInfoCache[userId] =
		{ Id = userId, Username = "Unknown", DisplayName = "Unknown", HasVerifiedBadge = false, Loading = true }
	return userInfoCache[userId]
end

return getUserInfo
