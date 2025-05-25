local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local gridSize = 8

local baseplate = workspace:WaitForChild("Baseplate")

function UpdatePosition()
	local char = LocalPlayer.Character
	local primary = char and char.PrimaryPart

	if primary then
		baseplate.CFrame = CFrame.new(
			(primary.Position.X // gridSize) * gridSize,
			-baseplate.Size.Y / 2,
			(primary.Position.Z // gridSize) * gridSize
		)
	end
end

RunService.Heartbeat:Connect(UpdatePosition)
