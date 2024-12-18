local part = Instance.new("Part")
part.Anchored = true
part.CanCollide = false
part.CanQuery = false
part.CanTouch = false
part.Locked = true
part.Transparency = 1

local boneL1 = Instance.new("Bone", part)
boneL1.Name = "Bone_l"
boneL1.CFrame = CFrame.new(-0.576, 0, 0) * CFrame.Angles(0, 0, math.rad(76.663))

local boneL2 = Instance.new("Bone", boneL1)
boneL2.Name = "Bone.001_l"
boneL2.CFrame = CFrame.new(0, 2.153, 0) * CFrame.Angles(0, 0, math.rad(-34.32))

local boneL3 = Instance.new("Bone", boneL2)
boneL3.Name = "Bone.002_l"
boneL3.CFrame = CFrame.new(0, 1.67, 0) * CFrame.Angles(0, 0, math.rad(24.665))

local boneR1 = Instance.new("Bone", part)
boneR1.Name = "Bone_r"
boneR1.CFrame = CFrame.new(0.576, 0, 0) * CFrame.Angles(0, 0, math.rad(-76.663))

local boneR2 = Instance.new("Bone", boneR1)
boneR2.Name = "Bone.001_r"
boneR2.CFrame = CFrame.new(0, 2.153, 0) * CFrame.Angles(0, 0, math.rad(34.32))

local boneR3 = Instance.new("Bone", boneR2)
boneR3.Name = "Bone.002_r"
boneR3.CFrame = CFrame.new(0, 1.67, 0) * CFrame.Angles(0, 0, math.rad(-24.665))

return part
