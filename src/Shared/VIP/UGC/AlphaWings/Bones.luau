local part = Instance.new("Part")
part.Anchored = true
part.CanCollide = false
part.CanQuery = false
part.CanTouch = false
part.Locked = true
part.Transparency = 1

local function createBone(name: string, cframe: CFrame, parent: Instance): Bone
	local bone = Instance.new("Bone")
	bone.Name = name
	bone.CFrame = cframe
	bone.Parent = parent
	return bone
end

local boneL1 = createBone("Bone_l", CFrame.new(-0.576, 0, 0) * CFrame.Angles(0, 0, math.rad(76.663)), part)
local boneL2 = createBone("Bone.001_l", CFrame.new(0, 2.153, 0) * CFrame.Angles(0, 0, math.rad(-34.32)), boneL1)
createBone("Bone.002_l", CFrame.new(0, 1.67, 0) * CFrame.Angles(0, 0, math.rad(24.665)), boneL2)

local boneR1 = createBone("Bone_r", CFrame.new(0.576, 0, 0) * CFrame.Angles(0, 0, math.rad(-76.663)), part)
local boneR2 = createBone("Bone.001_r", CFrame.new(0, 2.153, 0) * CFrame.Angles(0, 0, math.rad(34.32)), boneR1)
createBone("Bone.002_r", CFrame.new(0, 1.67, 0) * CFrame.Angles(0, 0, math.rad(-24.665)), boneR2)

return part
