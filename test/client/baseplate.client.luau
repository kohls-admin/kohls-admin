local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local gridSize = 8

local baseplate = Instance.new("Part")
baseplate.Anchored = true
baseplate.Locked = true
baseplate.Position = Vector3.new(0, -8, 0)
baseplate.Size = Vector3.new(2048, 16, 2048)
baseplate.Transparency = 1
baseplate.Parent = workspace

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
