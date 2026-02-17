local part = script.Parent

local Animate = require(script:WaitForChild("Animate"))

local Animations = script:WaitForChild("Animations")
local fall = Animations:WaitForChild("fall")
local idle = Animations:WaitForChild("idle")
local idle2 = Animations:WaitForChild("idle2")

local humanoid = part.Parent.Parent:FindFirstChildOfClass("Humanoid")
while not humanoid do
	humanoid = part.Parent.Parent:FindFirstChildOfClass("Humanoid")
	task.wait()
end

local animFalling, lastY
local randomIdle = true
task.delay(math.random(15, 30), function()
	randomIdle = false
end)

game:GetService("RunService").PreSimulation:Connect(function(step)
	local falling = humanoid.FloorMaterial == Enum.Material.Air
		and humanoid.RootPart
		and humanoid.RootPart.Anchored == false
	local currentY = part.Position.Y
	local speed = (if lastY then currentY - lastY else part.Velocity.Y) / step
	lastY = currentY

	if falling then
		if speed < 0 then -- falling
			Animate.timeScale = 0.5 + (200 + math.max(-200, speed)) / 400
		else -- flying
			Animate.timeScale = 1 + math.min(200, speed) / 100
		end
		if animFalling then
			return
		end
		animFalling = true
		Animate.play(part, fall, true)
		animFalling = false
	else
		if animFalling then
			animFalling = false
			Animate.timeScale = 0.5
			Animate.play(part, idle, true)
		elseif not randomIdle then
			randomIdle = true
			task.delay(math.random(15, 30), function()
				randomIdle = false
			end)
			Animate.timeScale = 0.5
			Animate.play(part, idle2)
			Animate.play(part, idle, true)
		end
	end
end)

Animate.timeScale = 0.5
Animate.play(part, idle, true)
