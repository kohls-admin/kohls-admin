local InsertService = game:GetService("InsertService")

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

return hat
