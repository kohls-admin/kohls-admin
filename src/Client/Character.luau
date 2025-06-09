local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer

local PlayerModule = require(LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule") :: ModuleScript)
local ControlModule = PlayerModule:GetControls()

local maxSpeed = 128

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

local speed = 0
local function updateFly(delta: number)
	local humanoid = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	align.CFrame = workspace.CurrentCamera.CFrame
	local up = humanoid.Jump and 1 or UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) and -1 or 0
	local controlVector = ControlModule:GetMoveVector()
	if up ~= 0 or controlVector ~= Vector3.zero then
		speed = math.clamp(speed + delta * maxSpeed / 4, math.min(humanoid.WalkSpeed, maxSpeed), maxSpeed)
		linear.VectorVelocity = (align.CFrame:VectorToWorldSpace(controlVector) + Vector3.new(0, up, 0)) * speed
	else
		speed = math.clamp(speed - delta * maxSpeed / 2, math.min(humanoid.WalkSpeed, maxSpeed), maxSpeed)
		linear.VectorVelocity = Vector3.zero
	end
end

local noclipping
local function noClip(model: Model, reset: boolean?)
	if noclipping or reset then
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("BasePart") then
				if reset then
					local initial = descendant:GetAttribute("_KInitialCanCollide")
					if initial ~= nil then
						descendant.CanCollide = initial
					end
				else
					if not descendant:GetAttribute("_KInitialCanCollide") then
						descendant:SetAttribute("_KInitialCanCollide", descendant.CanCollide)
					end
					descendant.CanCollide = false
				end
			end
		end
	end
end

local Character = {}

local canDoubleJump, hasDoubleJumped = false, false
local flying, flyConnection = false, nil

function Character.fly(enable: boolean)
	if enable == flying then
		return
	end

	flying = enable
	if typeof(flyConnection) == "RBXScriptConnection" then
		flyConnection:Disconnect()
		flyConnection = nil
	end

	local character = LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local primaryPart = character and character.PrimaryPart
	if not (humanoid and primaryPart) then
		return
	end

	if flying then
		task.delay(1, function()
			canDoubleJump, hasDoubleJumped = false, false
		end)
		humanoid.PlatformStand = true
		humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
		flyAttachment.Parent = primaryPart
		flyConnection = RunService.Heartbeat:Connect(updateFly)
	else
		flyAttachment.Parent = nil
		linear.VectorVelocity = Vector3.zero
		humanoid.PlatformStand = false
		flyConnection = nil
		primaryPart.CFrame = CFrame.new(primaryPart.Position) * CFrame.Angles(0, math.rad(primaryPart.Orientation.Y), 0)
	end
end

function Character.noclip(enable: boolean)
	noclipping = enable
	if LocalPlayer.Character then
		noClip(LocalPlayer.Character, not enable)
	end
end

-- CONNECTIONS

local function onCharacter(character)
	Character.fly(false)
	Character.noclip(false)
	local humanoid = character:WaitForChild("Humanoid")
	humanoid.StateChanged:Connect(function(_old, new)
		noClip(character)
		if new == Enum.HumanoidStateType.Landed then
			canDoubleJump = false
			hasDoubleJumped = false
		elseif new == Enum.HumanoidStateType.Freefall then
			task.wait(0.1)
			canDoubleJump = true
		end
	end)
end

local lastJump = 0
local function onJumpRequest()
	if hasDoubleJumped then
		return
	end
	local character = LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid:GetState() ~= Enum.HumanoidStateType.Dead and character:IsDescendantOf(workspace) then
		local now = tick()
		local duration = now - lastJump
		lastJump = now

		if flying then
			if duration < 0.25 then
				Character.noclip(false)
				Character.fly(false)
			end
		elseif canDoubleJump then
			hasDoubleJumped = true
			local noclip = LocalPlayer:GetAttribute("_KNoClip")
			local fly = LocalPlayer:GetAttribute("_KFly")
			if noclip then
				Character.noclip(if fly then true else not noclipping)
			end
			if fly then
				Character.fly(true)
			end
		end
	end
end

LocalPlayer:GetAttributeChangedSignal("_KFly"):Connect(function()
	local fly = LocalPlayer:GetAttribute("_KFly")
	maxSpeed = math.max(0, fly or 128)
	Character.fly(fly)
end)

LocalPlayer:GetAttributeChangedSignal("_KNoClip"):Connect(function()
	local noclip = LocalPlayer:GetAttribute("_KNoClip")
	Character.noclip(noclip)
end)

if LocalPlayer.Character then
	task.spawn(onCharacter, LocalPlayer.Character)
end
LocalPlayer.CharacterAdded:Connect(onCharacter)

UserInputService.JumpRequest:Connect(onJumpRequest)

return Character
