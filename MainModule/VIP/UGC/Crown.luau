local CollectionService = game:GetService("CollectionService")
local InsertService = game:GetService("InsertService")
local RunService = game:GetService("RunService")

local hat = Instance.new("Accessory")
hat.Name = "SuperCrown"
hat.AttachmentPoint = CFrame.new(0, -1, 0)
hat:AddTag("_KSuperCrown")

local handle = InsertService:CreateMeshPartAsync(
	"rbxassetid://10282777453",
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
				if v and v.Parent then
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

return {
	MatchId = "rbxassetid://18966762965",
	Method = function(character: Model, accessory: Accessory)
		if accessory then
			accessory:Destroy()
		end
		if not character:FindFirstChild(hat.Name) then
			hat:Clone().Parent = character
		end
	end,
}
