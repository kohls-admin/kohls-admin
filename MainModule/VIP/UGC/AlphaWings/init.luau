if game:GetService("RunService"):IsClient() then
	return false
end

local InsertService = game:GetService("InsertService")

local hat = Instance.new("Accessory")
hat.AccessoryType = Enum.AccessoryType.Back
hat.Name = "_KAlphaWings"
hat:AddTag("_KAlphaWings")

local handle = Instance.new("Part", hat)
handle.Name = "Handle"
handle.Transparency = 1
handle.CanCollide = false
handle.CanQuery = false
handle.CanTouch = false
handle.Massless = true
handle.Locked = true

local attachment = Instance.new("Attachment", handle)
attachment.CFrame = CFrame.new(0, 0, 0)
attachment.Name = "BodyBackAttachment"

local wingMesh = InsertService:CreateMeshPartAsync(
	"rbxassetid://135389107063517",
	Enum.CollisionFidelity.Box,
	Enum.RenderFidelity.Precise
)
wingMesh:AddTag("_KAlphaWings")
wingMesh.Parent = hat
wingMesh.Name = "Wings"
wingMesh.Color = Color3.fromRGB(170, 170, 170)
wingMesh.CastShadow = false
wingMesh.CanCollide = false
wingMesh.CanQuery = false
wingMesh.CanTouch = false
wingMesh.Massless = true
wingMesh.Locked = true
wingMesh.Material = Enum.Material.Neon
wingMesh:SetAttribute("OriginalSize", wingMesh.Size)

local weld = Instance.new("Weld", wingMesh)
weld.Part0 = handle
weld.Part1 = wingMesh

local Bones = require(script:WaitForChild("Bones"))
for _, bone in Bones:GetChildren() do
	bone:SetAttribute("OriginalCFrame", bone.CFrame)
	bone.Parent = wingMesh
end

script:WaitForChild("Animate").Parent = wingMesh

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
					if string.find(string.lower(accessory.Name), key, 1, true) then
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
			clone.Wings.Color = color
		end

		clone.Parent = character
		clone.Wings.Animate.Enabled = true

		return clone
	end,
}
