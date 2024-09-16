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

local function flyingTimeScale()
	local speed = part.Velocity.Y
	if speed < 0 then -- falling
		Animate.timeScale = 0.5 + (200 + math.max(-200, speed)) / 400
	else -- flying
		Animate.timeScale = 1 + math.min(200, speed) / 100
	end
end

local falling
humanoid.StateChanged:Connect(function(old, new)
	if new == Enum.HumanoidStateType.Freefall or new == Enum.HumanoidStateType.Flying then
		falling = true
		Animate.timeScale = 1
		Animate.play(part, fall, true)
	elseif falling then
		falling = false
		Animate.timeScale = 0.5
		Animate.play(part, idle, true)
	end
end)

local randomIdle
game:GetService("RunService").PreSimulation:Connect(function()
	if falling then
		flyingTimeScale()
	elseif not randomIdle then
		randomIdle = true
		task.delay(math.random(5, 15), function()
			randomIdle = false
		end)
		Animate.play(part, idle2)
		Animate.play(part, idle, true)
	end
end)

Animate.timeScale = 0.5
Animate.play(part, idle, true)
