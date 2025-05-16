local CollectionService = game:GetService("CollectionService")
local InsertService = game:GetService("InsertService")
local RunService = game:GetService("RunService")

local hat = Instance.new("Accessory")
hat.AccessoryType = Enum.AccessoryType.Hat
hat.Name = "SuperCrown"
hat.AttachmentPoint = CFrame.new(0, -1, 0)
hat:AddTag("_KSuperCrown")

local handle = InsertService:CreateMeshPartAsync(
	"rbxassetid://18966762965",
	Enum.CollisionFidelity.Box,
	Enum.RenderFidelity.Automatic
)
handle.Parent = hat
handle.Name = "Handle"
handle.Color = Color3.new(1, 1, 1)
handle.CastShadow = false
handle.CanCollide = false
handle.CanQuery = false
handle.CanTouch = false
handle.Massless = true
handle.Locked = true
handle.Material = Enum.Material.Neon
-- handle.Size = Vector3.new(1.2, 0.2, 1.2)

local attachment = Instance.new("Attachment", handle)
attachment.Name = "HatAttachment"
attachment.CFrame = CFrame.new(0, -1.5, 0)

local fire = Instance.new("Fire", handle)
fire.Color = Color3.new(0, 0, 0)
fire.SecondaryColor = Color3.new(0, 0, 0)
fire.Heat = 4
fire.Size = 2

if RunService:IsClient() then
	-- handle spinning logic
	local crowns = CollectionService:GetTagged("_KSuperCrown")
	RunService.Heartbeat:Connect(function()
		if #crowns > 0 then
			local t = time()
			local tpi = t % (math.pi * 2)
			local AP = CFrame.new(0, math.sin(tpi) / 8, 0) * CFrame.Angles(0, tpi, 0)
			for i, v in crowns do
				if v and v.Parent and v:FindFirstChild("Handle") then
					if v.Handle:FindFirstChild("AccessoryWeld") then
						v.Handle.AccessoryWeld.C1 = AP
					end
				else
					table.remove(crowns, i)
				end
			end
			-- rainbow crowns
			-- local color = Color3.fromHSV((t / 10) % 1, 1, 1)
		end
	end)
	CollectionService:GetInstanceAddedSignal("_KSuperCrown"):Connect(function(obj)
		table.insert(crowns, obj)
	end)
	CollectionService:GetInstanceRemovedSignal("_KSuperCrown"):Connect(function(obj)
		table.remove(crowns, table.find(crowns, obj))
	end)
end

local COLORS = {
	dark = { Color3.new(), Color3.new(1, 1, 1) },
	gold = { Color3.fromRGB(170, 125, 0), Color3.new() },
}

return {
	Name = hat.Name,
	MatchId = "rbxassetid://18966762965",
	Method = function(character: Model, accessory: Accessory)
		local colors
		if accessory then
			if typeof(accessory) == "Instance" then
				local part = accessory:FindFirstChild("Handle")
				if part:IsA("MeshPart") then
					if string.find(part.TextureID, "74391200400192") then
						colors = COLORS.dark
					elseif string.find(part.TextureID, "115319077247149") then
						colors = COLORS.gold
					end
				end
				accessory:Destroy()
			elseif typeof(accessory) == "string" then
				for key, value in COLORS do
					if string.find(string.lower(accessory), key, 1, true) then
						colors = value
						break
					end
				end
			end
		end

		local existing = character:FindFirstChild(hat.Name)
		if existing then
			existing:Destroy()
		end

		local clone = hat:Clone()

		if colors then
			local primary, secondary = unpack(colors)
			clone.Handle.Color = primary
			clone.Handle.Fire.Color = secondary
			clone.Handle.Fire.SecondaryColor = secondary
		end

		clone.Parent = character

		return clone
	end,
}
