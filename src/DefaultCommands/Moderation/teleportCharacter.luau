local Players = game:GetService("Players")

local Remote = require(script.Parent.Parent.Parent:WaitForChild("Remote"))

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
	local cframe
	if typeof(to) == "Vector3" then
		cframe = CFrame.new(to) * from:GetPivot().Rotation
	else
		local offset =
			Vector3.new((math.random(1, 2) - 1) * math.random(2, 4), 0, (math.random(1, 2) - 1) * math.random(2, 4))
		cframe = to:GetPivot() + offset
	end
	from:PivotTo(cframe)

	local player = Players:GetPlayerFromCharacter(from)
	if player then
		Remote.Teleport:FireClient(player, cframe)
	end
end

return teleportCharacter
