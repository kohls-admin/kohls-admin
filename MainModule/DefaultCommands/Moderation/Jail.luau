local Players = game:GetService("Players")

local Util = require(script.Parent.Parent.Parent.Util)

local jailParts = {}

local Jail = {
	Parts = jailParts,
}

function Jail.recapture(character)
	local player = Players:GetPlayerFromCharacter(character)
	if not (player and character and character.PrimaryPart) then
		return true
	end
	local existing = jailParts[player.UserId]
	if existing then
		task.defer(character.PivotTo, character, existing.CFrame)
		return true
	end
	return
end

function Jail.new(player)
	local character = player.Character

	if Jail.recapture(character) then
		return
	end

	local root = character and character.PrimaryPart
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not (player and root and humanoid) then
		return
	end

	local existing = jailParts[player.UserId]
	if existing then
		task.defer(character.PivotTo, character, existing.CFrame)
		return
	end

	local rootCFrame = root.CFrame
	local groundPos = rootCFrame.Position - Vector3.new(0, humanoid.HipHeight + root.Size.Y / 2, 0)

	local _, size = character:GetBoundingBox()
	local width = math.max(size.X, size.Y, size.Z) + 2
	local position = groundPos + Vector3.new(0, width / 2, 0)
	local offset = width / 2 - 0.5

	local kJail = Instance.new("Part")
	kJail.Name = "kJail"
	kJail.Anchored = true
	kJail.Size = Vector3.new(width, width, width)
	kJail.CFrame = CFrame.new(position)
	kJail.Color = Color3.new(0, 0, 0)
	kJail.Transparency = 0.3
	kJail.Material = Enum.Material.Neon
	kJail.TopSurface = Enum.SurfaceType.Smooth
	kJail.BottomSurface = Enum.SurfaceType.Smooth

	jailParts[player.UserId] = kJail

	local top = kJail:Clone()
	top.Parent = kJail
	top.Transparency = 1
	top.Size = Vector3.new(width, 1, width)
	top.Position = position + Vector3.new(0, offset, 0)

	local bottom = top:Clone()
	bottom.Parent = kJail
	bottom.Position = position - Vector3.new(0, offset + 1, 0)

	local left = top:Clone()
	left.Parent = kJail
	left.Size = Vector3.new(1, width, width)
	left.Position = position - Vector3.new(offset, 0, 0)

	local right = left:Clone()
	right.Parent = kJail
	right.Position = position + Vector3.new(offset, 0, 0)

	local front = top:Clone()
	front.Parent = kJail
	front.Size = Vector3.new(width, width, 1)
	front.Position = position - Vector3.new(0, 0, offset)

	local back = front:Clone()
	back.Parent = kJail
	back.Position = position + Vector3.new(0, 0, offset)

	kJail.CanCollide = false
	kJail.Parent = workspace

	root.CFrame = rootCFrame

	return kJail
end

Util.SafePlayerAdded(function(player)
	player.CharacterAdded:Connect(Jail.recapture)
	if player.Character then
		Jail.recapture(player.Character)
	end
end)

return Jail
