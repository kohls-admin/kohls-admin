local TeleportService = game:GetService("TeleportService")

local Retry = require(script.Parent:WaitForChild("Retry"))

local ATTEMPT_LIMIT = 5
local RETRY_DELAY = 1
local FLOOD_DELAY = 15

local function SafeTeleport(placeId, players, options)
	local success, result =
		Retry(TeleportService.TeleportAsync, ATTEMPT_LIMIT, RETRY_DELAY, TeleportService, placeId, players, options)

	if not success then
		warn(result) -- print the failure reason to output
	end

	return success, result
end

local function handleFailedTeleport(player, teleportResult, errorMessage, targetPlaceId, teleportOptions)
	if teleportResult == Enum.TeleportResult.Flooded then
		task.wait(FLOOD_DELAY)
	elseif teleportResult == Enum.TeleportResult.Failure then
		task.wait(RETRY_DELAY)
	end

	if
		teleportResult == Enum.TeleportResult.GameNotFound
		or teleportResult == Enum.TeleportResult.Unauthorized
		or string.find(errorMessage, "Roblox Studio")
	then
		return
	end

	SafeTeleport(targetPlaceId, { player }, teleportOptions)
end

local _ = TeleportService.TeleportInitFailed:Connect(handleFailedTeleport)

return SafeTeleport
