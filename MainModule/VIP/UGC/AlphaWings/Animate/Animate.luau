local TweenService = game:GetService("TweenService")

local Animate = {
	timeScale = 1,
}

function Animate.getBoneFromPose(rig: Instance, pose: Pose): Motor6D?
	if not pose.Parent then
		return
	end
	local poseParentName = pose.Parent.Name
	for i, v in rig:GetDescendants() do
		if v:IsA("Bone") and v.Name == pose.Name and v.Parent.Name == poseParentName then
			return v
		end
	end
	return
end

local tracks = {}

function Animate.play(rig: Instance, sequence: KeyframeSequence, loop: boolean?)
	if tracks[rig] then
		pcall(task.cancel, tracks[rig])
	end
	local thread = coroutine.running()
	tracks[rig] = thread

	local frames = sequence:GetKeyframes()
	table.sort(frames, function(a, b)
		return a.Time < b.Time
	end)

	local bones = {}
	local blend = true
	repeat
		for i, keyframe in frames do
			local duration = 0

			if frames[i - 1] then
				duration = (keyframe.Time - frames[i - 1].Time) / Animate.timeScale
			elseif blend then
				blend = false
				duration = 0.5
			end

			for _, pose: Pose in keyframe:GetDescendants() do
				local bone = Animate.getBoneFromPose(rig, pose)
				if not bone then
					continue
				end
				bones[bone] = true

				local originalCFrame = bone:GetAttribute("OriginalCFrame")
				if not originalCFrame then
					originalCFrame = bone.CFrame
					bone:SetAttribute("OriginalCFrame", originalCFrame)
				end

				if bone and pose.CFrame ~= CFrame.identity then
					local EasingStyle, EasingDirection =
						Enum.EasingStyle[pose.EasingStyle.Name], Enum.EasingDirection[pose.EasingDirection.Name]

					TweenService:Create(
						bone,
						TweenInfo.new(duration, EasingStyle, EasingDirection),
						{ CFrame = originalCFrame * pose.CFrame }
					):Play()
				end
			end
			task.wait(duration)
		end
	until not loop

	for bone in bones do
		TweenService:Create(bone, TweenInfo.new(0.5), { CFrame = bone:GetAttribute("OriginalCFrame") }):Play()
	end
end

return Animate
