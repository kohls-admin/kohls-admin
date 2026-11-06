local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local Retry = require(script.Parent:WaitForChild("Retry"))

local ATTEMPT_LIMIT = 5
local RETRY_DELAY = 1
local FLOOD_DELAY = 15

local NON_RETRYABLE_RESULTS = {
	[Enum.TeleportResult.GameEnded] = true,
	[Enum.TeleportResult.GameFull] = true,
	[Enum.TeleportResult.GameNotFound] = true,
	[Enum.TeleportResult.IsTeleporting] = true,
	[Enum.TeleportResult.Unauthorized] = true,
}

local function SafeTeleport(placeId, players, options)
	local success, result =
		Retry(TeleportService.TeleportAsync, ATTEMPT_LIMIT, RETRY_DELAY, TeleportService, placeId, players, options)

	if not success then
		warn(result) -- print the failure reason to output
	end

	return success, result
end

local function handleFailedTeleport(player, teleportResult, errorMessage, targetPlaceId, teleportOptions)
	if NON_RETRYABLE_RESULTS[teleportResult] or string.find(errorMessage, "Roblox Studio") then
		return
	end

	if teleportResult == Enum.TeleportResult.Flooded then
		task.wait(FLOOD_DELAY)
	elseif teleportResult == Enum.TeleportResult.Failure then
		task.wait(RETRY_DELAY)
	end

	SafeTeleport(targetPlaceId, { player }, teleportOptions)
end

if RunService:IsServer() then
	local _ = TeleportService.TeleportInitFailed:Connect(handleFailedTeleport)
end

return SafeTeleport
