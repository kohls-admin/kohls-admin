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
local lastStop = os.clock()

local Noclip = {
	flyCFrame = CFrame.new(),
}
local function FlyStep(delta)
	if not (Character and Humanoid and Character.PrimaryPart and not Character:FindFirstChild("kFreeze")) then
		return
	end

	local cameraCFrame = workspace.CurrentCamera.CFrame
	local newCFrame = cameraCFrame.Rotation + Noclip.flyCFrame.Position
	local moveVector = cameraCFrame:VectorToWorldSpace(ControlModule:GetMoveVector())
	local up = Humanoid.Jump and 1 or UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) and -1 or 0

	if up ~= 0 or moveVector.x ~= 0 or moveVector.z ~= 0 then
		local speed = minSpeed + (maxSpeed - minSpeed) * math.clamp((os.clock() - lastStop) / accelDuration, 0, 1)
		newCFrame += Vector3.new(moveVector.X, moveVector.Y + up, moveVector.Z).Unit * (delta * speed) * 4
	else
		lastStop = os.clock()
	end
	Noclip.flyCFrame = Noclip.flyCFrame:lerp(newCFrame, 0.25)
	Character.PrimaryPart.CFrame = Noclip.flyCFrame
	Character.PrimaryPart.AssemblyLinearVelocity = Vector3.zero
	Character.PrimaryPart.AssemblyAngularVelocity = Vector3.zero
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
	lastStop = os.clock()
	if enable then
		Humanoid.PlatformStand = true
		if FlyEnabled and not FlyConnection then
			Noclip.flyCFrame = Character.PrimaryPart.CFrame
			FlyConnection = RunService.Heartbeat:Connect(FlyStep)
		end
	else
		if Humanoid.PlatformStand then
			Humanoid.PlatformStand = false
		end
		FlyConnection = nil
	end
end

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
	if not Humanoid:GetAttribute("_KStateEnabledJumping") then
		Humanoid:SetAttribute("_KStateEnabledJumping", Humanoid:GetStateEnabled(Enum.HumanoidStateType.Jumping))
		Humanoid:SetAttribute("_KStateEnabledFallingDown", Humanoid:GetStateEnabled(Enum.HumanoidStateType.FallingDown))
		Humanoid:SetAttribute("_KStateEnabledRagdoll", Humanoid:GetStateEnabled(Enum.HumanoidStateType.Ragdoll))
	end
	Humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	Humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
	Humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)

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

function Noclip.fly(enabled: boolean)
	FlyEnabled = enabled
	Fly(enabled)
end

function Noclip.noclip(enabled: boolean)
	if not enabled == not FlyEnabled then
		return
	end

	if noclipping then
		if typeof(noclipping) == "RBXScriptConnection" then
			noclipping:Disconnect()
		end
	end

	noclipping = enabled
	Noclip.fly(enabled)

	if not LocalPlayer.Character then
		return
	end

	if enabled then
		onCharacter(LocalPlayer.Character)
	else
		Humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
		Humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, Humanoid:GetAttribute("_KStateEnabledJumping"))
		Humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, Humanoid:GetAttribute("_KStateEnabledFallingDown"))
		Humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, Humanoid:GetAttribute("_KStateEnabledRagdoll"))
		Humanoid:SetAttribute("_KStateEnabledJumping", nil)
		Humanoid:SetAttribute("_KStateEnabledFallingDown", nil)
		Humanoid:SetAttribute("_KStateEnabledRagdoll", nil)

		for _, descendant in LocalPlayer.Character:GetDescendants() do
			if descendant:IsA("BasePart") then
				if collideCache[descendant] then
					descendant.CanCollide = true
				end
			end
		end
	end
end

local lastJump, debounceJump = 0, nil
UserInputService.JumpRequest:Connect(function()
	local now = tick()
	local duration = now - lastJump
	if debounceJump then
		return
	end
	lastJump = now
	if FlyEnabled and (duration <= 0.25 or not flying) then
		debounceJump = true
		task.delay(if not flying then 1 else 0.1, function()
			debounceJump = nil
			lastJump = 0
		end)
		if noclipping then
			if typeof(noclipping) == "RBXScriptConnection" then
				noclipping:Disconnect()
			end
		end
		noclipping = not flying
		Fly(noclipping)
		if not LocalPlayer.Character then
			return
		end

		if noclipping then
			onCharacter(LocalPlayer.Character)
		else
			Humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
			Humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
			Humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)

			for _, descendant in LocalPlayer.Character:GetDescendants() do
				if descendant:IsA("BasePart") then
					if collideCache[descendant] then
						descendant.CanCollide = true
					end
				end
			end
		end
	end
end)

return Noclip
