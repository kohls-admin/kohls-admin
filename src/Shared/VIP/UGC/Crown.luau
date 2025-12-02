local CollectionService = game:GetService("CollectionService")
local InsertService = game:GetService("InsertService")
local RunService = game:GetService("RunService")

local Package = script.Parent.Parent.Parent.Parent

local Flux = require(Package.Flux)

local Oklab = Flux.Color.Oklab

local hat = Instance.new("Accessory")
hat.AccessoryType = Enum.AccessoryType.Hat
hat.Name = "SuperCrown"
hat.AttachmentPoint = CFrame.new(0, -1, 0)
hat:AddTag("_KSuperCrown")

task.spawn(function()
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
end)

if RunService:IsClient() then
	-- handle crown animations
	local crowns, rainbowCrowns = {}, {}
	RunService.Heartbeat:Connect(function()
		if next(crowns) then
			local t = time()
			local tpi = t % (math.pi * 2)
			local cframe = CFrame.new(0, math.sin(tpi) / 8, 0) * CFrame.Angles(0, tpi, 0)
			for crown in crowns do
				if crown and crown.Parent and crown:FindFirstChild("Handle") then
					if crown.Handle:FindFirstChild("AccessoryWeld") then
						crown.Handle.AccessoryWeld.C1 = cframe
					end
				else
					crowns[crown] = nil
				end
			end
			-- rainbow crowns
			local color = Oklab.toRGB(Oklab.fromHCL(Vector3.new((t / 10) % 1, 0.4, 1)))
			for crown in rainbowCrowns do
				if crown and crown.Parent and crown:FindFirstChild("Handle") then
					crown.Handle.Color = color
					local fire = crown.Handle:FindFirstChild("Fire")
					if fire then
						fire.SecondaryColor = color
					end
				else
					crowns[crown] = nil
				end
			end
		end
	end)
	for tag, cache in { _KSuperCrown = crowns, _KSuperCrownRainbow = rainbowCrowns } do
		CollectionService:GetInstanceAddedSignal(tag):Connect(function(obj)
			cache[obj] = true
		end)
		CollectionService:GetInstanceRemovedSignal(tag):Connect(function(obj)
			cache[obj] = nil
		end)
		for _, obj in CollectionService:GetTagged(tag) do
			cache[obj] = true
		end
	end
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
					if string.find(string.lower(accessory :: string), key :: string, 1, true) then
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

		if clone:FindFirstChild("Handle") then
			if colors then
				local primary, secondary = unpack(colors)
				clone.Handle.Color = primary
				clone.Handle.Fire.Color = secondary
				clone.Handle.Fire.SecondaryColor = secondary
			end

			clone:SetAttribute("_KCrownColor", clone.Handle.Color)
			clone:SetAttribute("_KCrownFireColor", clone.Handle.Fire.Color)
		end

		clone.Parent = character

		return clone
	end,
}
