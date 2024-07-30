local function teleportCharacter(from, to)
	if not (from and to) then
		return
	end

	-- prevent teleporting seats
	local humanoid = from:FindFirstChildOfClass("Humanoid")
	if humanoid then
		if humanoid.SeatPart then
			local weld = humanoid.SeatPart:FindFirstChild("SeatWeld")
			if weld then
				weld:Destroy()
			end
		end
		humanoid.Sit = false
	end

	-- reset velocity on teleport
	for _, v in from:GetDescendants() do
		if v:IsA("BasePart") then
			v.AssemblyLinearVelocity = Vector3.zero
		end
	end

	-- add a small offset to prevent clipping
	local offset =
		Vector3.new((math.random(1, 2) - 1) * math.random(2, 4), 0, (math.random(1, 2) - 1) * math.random(2, 4))

	from:PivotTo(to:GetPivot() + offset)
end

return teleportCharacter
