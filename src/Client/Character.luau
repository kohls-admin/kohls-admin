local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Notify = require(script.Parent:WaitForChild("Notify"))
local UI = require(script.Parent:WaitForChild("UI"))

local LocalPlayer = Players.LocalPlayer

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
local function updateFly(delta: number, constant: boolean?)
	local humanoid = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	align.CFrame = workspace.CurrentCamera.CFrame
	local up = humanoid.Jump and 1 or UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) and -1 or 0
	if up ~= 0 or humanoid.MoveDirection ~= Vector3.zero then
		local look = align.CFrame.LookVector
		local reference = CFrame.lookAlong(align.CFrame.Position, Vector3.new(look.X, 0, look.Z), Vector3.yAxis)
		local controlVector = reference:VectorToObjectSpace(humanoid.MoveDirection).Unit
		if controlVector ~= controlVector then
			controlVector = Vector3.zero
		end
		speed = constant and maxSpeed
			or math.clamp(speed + delta * maxSpeed / 4, math.min(humanoid.WalkSpeed, maxSpeed), maxSpeed)
		linear.VectorVelocity = (align.CFrame:VectorToWorldSpace(controlVector) + (align.CFrame.UpVector * up)) * speed
	else
		speed = constant and maxSpeed
			or math.clamp(speed - delta * maxSpeed / 2, math.min(humanoid.WalkSpeed, maxSpeed), maxSpeed)
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

function Character.fly(enable: boolean, constant: boolean?)
	if enable == flying then
		return
	end

	if typeof(flyConnection) == "RBXScriptConnection" then
		flyConnection:Disconnect()
		flyConnection = nil
	end

	local character = LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not (humanoid and humanoid.RootPart) then
		return
	end

	flying = enable

	if flying then
		task.delay(0.3, function()
			canDoubleJump, hasDoubleJumped = false, false
		end)
		humanoid.PlatformStand = true
		flyAttachment.Parent = humanoid.RootPart
		flyConnection = RunService.Heartbeat:Connect(function(delta)
			updateFly(delta, constant or false)
		end)
		task.defer(humanoid.ChangeState, humanoid, Enum.HumanoidStateType.Freefall)
	else
		flyAttachment.Parent = nil
		linear.VectorVelocity = Vector3.zero
		humanoid.PlatformStand = false
		humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	end
end

function Character.noclip(enable: boolean)
	noclipping = enable
	if LocalPlayer.Character then
		noClip(LocalPlayer.Character, not enable)
	end
end

-- CONNECTIONS

local characterCleanup = {}

local function onCharacter(character)
	Character.fly(false)
	Character.noclip(false)
	local humanoid = character:WaitForChild("Humanoid")
	if characterCleanup[character] then
		characterCleanup[character]:Disconnect()
	end
	characterCleanup[character] = humanoid.StateChanged:Connect(function(old, new)
		noClip(character)
		if new == Enum.HumanoidStateType.Landed then
			canDoubleJump = false
			hasDoubleJumped = false
		elseif new == Enum.HumanoidStateType.Freefall then
			task.wait((old == Enum.HumanoidStateType.Jumping) and 0.1 or 0.4)
			if humanoid:GetState() == Enum.HumanoidStateType.Freefall then
				canDoubleJump = true
			end
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
			if duration < 0.4 then
				Character.noclip(false)
				Character.fly(false)
			end
		elseif canDoubleJump then
			hasDoubleJumped = true
			local noclip = LocalPlayer:GetAttribute("_KNoClip")
			local fly = LocalPlayer:GetAttribute("_KFly")
			local constant = LocalPlayer:GetAttribute("_KFlyConstant") and true or false
			if noclip then
				Character.noclip(if fly then true else not noclipping)
				if not fly then
					local status = if noclipping
						then `<font color="#{UI.Theme.Valid._value:ToHex()}">enabled`
						else `<font color="#{UI.Theme.Invalid._value:ToHex()}">disabled`
					Notify({ Text = `<b>Noclip {status}</font>.</b>\nDouble tap <b>jump</b> to toggle.` })
				end
			end
			if fly then
				Character.fly(true, constant)
			end
		end
	end
end

LocalPlayer:GetAttributeChangedSignal("_KFly"):Connect(function()
	local fly = LocalPlayer:GetAttribute("_KFly")
	local constant = LocalPlayer:GetAttribute("_KFlyConstant") and true or false
	local noclip = LocalPlayer:GetAttribute("_KNoClip")
	maxSpeed = math.max(0, fly or 128)
	Character.fly(fly, constant)
	if not flying and not noclip and fly then
		Notify({
			Text = `Double tap <b>jump</b> to toggle fly.`,
		})
	end
end)

LocalPlayer:GetAttributeChangedSignal("_KNoClip"):Connect(function()
	local noclip = LocalPlayer:GetAttribute("_KNoClip")
	Character.noclip(noclip)
	if noclip then
		Notify({
			Text = `Double tap <b>jump</b> to toggle noclip.`,
		})
	end
end)

if LocalPlayer.Character then
	task.spawn(onCharacter, LocalPlayer.Character)
end
LocalPlayer.CharacterAdded:Connect(onCharacter)
LocalPlayer.CharacterRemoving:Connect(function(character)
	if characterCleanup[character] and characterCleanup[character].Connected then
		characterCleanup[character]:Disconnect()
	end
	characterCleanup[character] = nil
end)

UserInputService.JumpRequest:Connect(onJumpRequest)

return Character
