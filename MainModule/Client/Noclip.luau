local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local Character, Humanoid

local PlayerModule = require(LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule"))
local ControlModule = PlayerModule:GetControls()

local minSpeed = 32
local maxSpeed = 512
local accelDuration = 16
local lastStop = elapsedTime()

local function FlyStep(delta)
	if not (Character and Humanoid and Character.PrimaryPart) then
		return
	end
	local cameraCFrame = workspace.CurrentCamera.CFrame
	local newCFrame = cameraCFrame.Rotation + Character.PrimaryPart.Position
	local moveVector = cameraCFrame:VectorToWorldSpace(ControlModule:GetMoveVector())
	local up = Humanoid.Jump and 1 or UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) and -1 or 0
	if up ~= 0 or moveVector.x ~= 0 or moveVector.z ~= 0 then
		local speed = minSpeed + (maxSpeed - minSpeed) * math.clamp((elapsedTime() - lastStop) / accelDuration, 0, 1)
		newCFrame += Vector3.new(moveVector.X, moveVector.Y + up, moveVector.Z).Unit * (delta * speed) * 4
	else
		lastStop = elapsedTime()
	end
	Character.PrimaryPart.CFrame = Character.PrimaryPart.CFrame:lerp(newCFrame, 0.25)
end

local FlyEnabled, FlyConnection, flying
local function Fly(enable)
	flying = enable
	if typeof(FlyConnection) == "RBXScriptConnection" then
		FlyConnection:Disconnect()
	end
	if not (Character and Humanoid and Character.PrimaryPart) then
		return
	end
	if enable then
		if FlyEnabled and not FlyConnection then
			Character.PrimaryPart.Anchored, Humanoid.PlatformStand = true, true
			FlyConnection = RunService.Heartbeat:Connect(FlyStep)
		end
	else
		Character.PrimaryPart.Anchored, Humanoid.PlatformStand = false, false
		FlyConnection = nil
	end
end

local lastJump, debounceJump = 0, nil
UserInputService.JumpRequest:Connect(function()
	if debounceJump then
		return
	end
	local now = tick()
	if now - lastJump <= 0.3 and FlyEnabled then
		debounceJump = true
		Fly(not flying)
		task.wait(1)
		debounceJump = nil
		lastJump = 0
	end
	lastJump = now
end)

local collideCache = {}
local function noCollide(model)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			if descendant.CanCollide and not collideCache[descendant] then
				collideCache[descendant] = true
			end
			descendant.CanCollide = false
		end
	end
end

local noclipping
local function onCharacter(character)
	Character = character
	Humanoid = character:FindFirstChildOfClass("Humanoid")
	while not Humanoid do
		task.wait()
		Humanoid = character:FindFirstChildOfClass("Humanoid")
	end

	if not noclipping then
		return
	end

	if typeof(noclipping) == "RBXScriptConnection" then
		noclipping:Disconnect()
	end
	noclipping = Humanoid.StateChanged:Connect(function()
		noCollide(character)
	end)
	noCollide(character)
end
LocalPlayer.CharacterAdded:Connect(onCharacter)
if LocalPlayer.Character then
	onCharacter(LocalPlayer.Character)
end

local Noclip = {}

function Noclip.fly(enabled: boolean)
	FlyEnabled = enabled
	Fly(enabled)
end

function Noclip.noclip(enabled: boolean)
	if not enabled == not noclipping then
		return
	end
	noclipping = enabled
	Noclip.fly(enabled)

	if not LocalPlayer.Character then
		return
	end

	if enabled then
		onCharacter(LocalPlayer.Character)
	else
		if noclipping then
			if typeof(noclipping) == "RBXScriptConnection" then
				noclipping:Disconnect()
			end
			noclipping = nil
		end
		for _, descendant in LocalPlayer.Character:GetDescendants() do
			if descendant:IsA("BasePart") then
				if collideCache[descendant] then
					descendant.CanCollide = true
				end
			end
		end
	end
end

return Noclip
