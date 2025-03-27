local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer

local PlayerModule = require(LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule") :: ModuleScript)
local ControlModule = PlayerModule:GetControls()

local character
local humanoid

local maxSpeed = 256

local flyAttachment = Instance.new("Attachment")

local align = Instance.new("AlignOrientation", flyAttachment)
align.Attachment0 = flyAttachment
align.Mode = "OneAttachment"
align.RigidityEnabled = true
align.Enabled = true

local linear = Instance.new("LinearVelocity", flyAttachment)
linear.Attachment0 = flyAttachment
linear.ForceLimitsEnabled = false
linear.Enabled = true

local function flyStep(delta)
	local up = humanoid.Jump and 1 or UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) and -1 or 0
	local controlVector = ControlModule:GetMoveVector() + Vector3.new(0, up, 0)

	if controlVector ~= Vector3.zero then
		local cameraCFrame = workspace.CurrentCamera.CFrame
		local minSpeed = maxSpeed / 8
		local accelSpeed = minSpeed

		align.CFrame = cameraCFrame
		linear.VectorVelocity = cameraCFrame:VectorToWorldSpace(controlVector.Unit)
			* math.clamp(linear.VectorVelocity.Magnitude + delta * math.max(8, accelSpeed), minSpeed, maxSpeed)
	else
		linear.VectorVelocity = linear.VectorVelocity:Lerp(Vector3.zero, delta * 4)
	end
end

local noclipping
local function noCollide(model, reset: boolean?)
	if not noclipping and not reset then
		return
	end

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			if reset then
				local initial = descendant:GetAttribute("InitialCanCollide")
				if initial ~= nil then
					descendant.CanCollide = initial
				end
			else
				if descendant.CanCollide then
					descendant:SetAttribute("InitialCanCollide", true)
				end
				descendant.CanCollide = false
			end
		end
	end
end

local Character = {}

local canDoubleJump = false
local hasDoubleJumped = false
local FlyConnection, flying

function Character.fly(enable)
	if not enable == not flying then
		return
	end

	flying = enable
	if typeof(FlyConnection) == "RBXScriptConnection" then
		FlyConnection:Disconnect()
		FlyConnection = nil
	end

	if not (humanoid and character.PrimaryPart) then
		return
	end

	if flying then
		task.delay(1, function()
			canDoubleJump = false
			hasDoubleJumped = false
		end)
		humanoid.PlatformStand = true
		humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
		flyAttachment.Parent = character.PrimaryPart
		FlyConnection = RunService.Heartbeat:Connect(flyStep)
	else
		flyAttachment.Parent = nil
		linear.VectorVelocity = Vector3.zero
		humanoid.PlatformStand = false
		FlyConnection = nil
	end
end
LocalPlayer:GetAttributeChangedSignal("_KFly"):Connect(function()
	local fly = LocalPlayer:GetAttribute("_KFly")
	maxSpeed = if fly then math.max(0, fly) else 256
	if not fly ~= not flying then
		Character.fly(fly)
	end
end)

function Character.noclip(noclip: boolean)
	noclipping = noclip

	if character then
		noCollide(character, not noclip)
	end

	Character.fly(noclip)
end
LocalPlayer:GetAttributeChangedSignal("_KNoclip"):Connect(function()
	local noclip = LocalPlayer:GetAttribute("_KNoclip")
	maxSpeed = if noclip then math.max(0, noclip) else 256
	if not noclip ~= not noclipping then
		Character.noclip(noclip)
	end
end)

function Character.tryFlyNoclip()
	local noclip = LocalPlayer:GetAttribute("_KNoclip")
	local fly = LocalPlayer:GetAttribute("_KFly")
	if noclip then
		noclipping = true
		noCollide(character)
	end
	if fly or noclip then
		Character.fly(true)
	end
end

local function onCharacter(newCharacter)
	if noclipping then
		noclipping = nil
		noCollide(character, true)
	end
	Character.fly(false)

	character = newCharacter
	humanoid = character:WaitForChild("Humanoid")

	humanoid.StateChanged:Connect(function(_old, new)
		noCollide(character)
		if new == Enum.HumanoidStateType.Landed then
			canDoubleJump = false
			hasDoubleJumped = false
		elseif new == Enum.HumanoidStateType.Freefall then
			task.wait(0.2)
			canDoubleJump = true
		end
	end)
	noCollide(character)
end
LocalPlayer.CharacterAdded:Connect(onCharacter)
if LocalPlayer.Character then
	task.spawn(onCharacter, LocalPlayer.Character)
end

local lastJump = 0
local function onJumpRequest()
	if
		not character
		or not humanoid
		or not character:IsDescendantOf(workspace)
		or humanoid:GetState() == Enum.HumanoidStateType.Dead
	then
		return
	end

	local now = tick()
	local duration = now - lastJump
	lastJump = now

	if flying and not hasDoubleJumped then
		if duration < 0.4 then
			if noclipping then
				noclipping = nil
				noCollide(character, true)
			end
			Character.fly(false)
		end
	elseif canDoubleJump and not hasDoubleJumped then
		hasDoubleJumped = true
		Character.tryFlyNoclip()
	end
end
UserInputService.JumpRequest:Connect(onJumpRequest)

return Character
