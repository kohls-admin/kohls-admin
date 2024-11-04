if game:GetService("RunService"):IsClient() then
	return false
end

local InsertService = game:GetService("InsertService")

local hat = Instance.new("Accessory")
hat.AccessoryType = Enum.AccessoryType.Back
hat.Name = "_KAlphaWings"
hat:AddTag("_KAlphaWings")

local handle = InsertService:CreateMeshPartAsync(
	"rbxassetid://135389107063517",
	Enum.CollisionFidelity.Box,
	Enum.RenderFidelity.Automatic
)
handle:AddTag("_KAlphaWings")
handle.Parent = hat
handle.Name = "Handle"
handle.Color = Color3.fromRGB(170, 170, 170)
handle.CastShadow = false
handle.CanCollide = false
handle.CanQuery = false
handle.CanTouch = false
handle.Massless = true
handle.Locked = true
handle.Material = Enum.Material.Neon

local Bones = script:WaitForChild("Bones")
for _, bone in Bones:GetChildren() do
	bone.Parent = handle
end

script:WaitForChild("Animate").Parent = handle

local attachment = Instance.new("Attachment", handle)
attachment.Position = Vector3.new(0, 3, -1)
attachment.Name = "BodyBackAttachment"

local COLORS = {
	dark = Color3.new(),
	gold = Color3.fromRGB(170, 125, 0),
}

return {
	Name = hat.Name,
	MatchId = "rbxassetid://89119211625300",
	Method = function(character: Model, accessory: Accessory)
		local color
		if accessory then
			if typeof(accessory) == "Instance" then
				local part = accessory:FindFirstChild("Handle")
				if part:IsA("MeshPart") then
					if string.find(part.TextureID, "74391200400192") then
						color = COLORS.dark
					elseif string.find(part.TextureID, "115319077247149") then
						color = COLORS.gold
					end
				end
			elseif typeof(accessory) == "table" then
				for key, value in COLORS do
					if string.find(string.lower(accessory.Name), key) then
						color = value
						break
					end
				end
			end
			accessory:Destroy()
		end

		local existing = character:FindFirstChild(hat.Name)
		if existing then
			existing:Destroy()
		end

		local clone = hat:Clone()

		if color then
			clone.Handle.Color = color
		end

		clone.Parent = character
		clone.Handle.Animate.Enabled = true

		return clone
	end,
}
