local CollectionService = game:GetService("CollectionService")
local InsertService = game:GetService("InsertService")
local RunService = game:GetService("RunService")

local Package = script.Parent.Parent.Parent.Parent

local Util = require(Package.Shared:WaitForChild("Util"))

local hclToRGB = Util.Color.hclToRGB

local HAT_NAME = "_KAlphaWings"
local bonesModule = script:FindFirstChild("Bones")
local animateTemplate = script:FindFirstChild("Animate")

local hat: Accessory?
local building = false
local waiters: { thread } = {}

local function getBuiltHat(): Accessory
	return assert(hat, "Expected built accessory")
end

local function ensureHat(): Accessory
	if hat then
		return hat
	end
	if building then
		table.insert(waiters, coroutine.running())
		coroutine.yield()
		return getBuiltHat()
	end
	building = true

	local newHat = Instance.new("Accessory")
	newHat.AccessoryType = Enum.AccessoryType.Back
	newHat.Name = HAT_NAME
	newHat:AddTag("_KAlphaWings")

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Transparency = 1
	handle.CanCollide = false
	handle.CanQuery = false
	handle.CanTouch = false
	handle.Massless = true
	handle.Locked = true
	handle.Parent = newHat

	local attachment = Instance.new("Attachment")
	attachment.CFrame = CFrame.new(0, -0.5, 0)
	attachment.Name = "BodyBackAttachment"
	attachment.Parent = handle

	local ok, result = Util.Retry(function()
		return InsertService:CreateMeshPartAsync(
			"rbxassetid://135389107063517",
			Enum.CollisionFidelity.Box,
			Enum.RenderFidelity.Precise
		)
	end)
	if ok and result then
		local wingMesh = result
		wingMesh:AddTag("_KAlphaWings")
		wingMesh.Parent = newHat
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

		local weld = Instance.new("Weld")
		weld.Part0 = handle
		weld.Part1 = wingMesh
		weld.Parent = wingMesh

		if bonesModule and bonesModule:IsA("ModuleScript") then
			local Bones = require(bonesModule) :: Instance
			for _, bone in Bones:GetChildren() do
				local clone = bone:Clone()
				clone:SetAttribute("OriginalCFrame", clone.CFrame)
				clone.Parent = wingMesh
			end
		end

		if animateTemplate then
			animateTemplate:Clone().Parent = wingMesh
		end
	elseif not ok then
		warn(result)
	end

	hat = newHat
	building = false
	local pending = table.clone(waiters)
	table.clear(waiters)
	for _, thread in pending do
		task.spawn(thread)
	end

	return newHat
end

if RunService:IsClient() then
	local rainbow = {}
	local _ = RunService.Heartbeat:Connect(function()
		if next(rainbow) then
			local color = hclToRGB(Vector3.new((time() / 10) % 1, 0.4, 1))
			for wings in rainbow do
				if wings and wings.Parent and wings:FindFirstChild("Handle") then
					wings.Wings.Color = color
				else
					rainbow[wings] = nil
				end
			end
		end
	end)

	CollectionService:GetInstanceAddedSignal("_KAlphaWingsRainbow"):Connect(function(obj)
		rainbow[obj] = true
	end)
	CollectionService:GetInstanceRemovedSignal("_KAlphaWingsRainbow"):Connect(function(obj)
		rainbow[obj] = nil
	end)
	for _, obj in CollectionService:GetTagged("_KAlphaWingsRainbow") do
		rainbow[obj] = true
	end
end

local COLORS = {
	dark = Color3.new(),
	gold = Color3.fromRGB(170, 125, 0),
}

return {
	Name = HAT_NAME,
	MatchId = "rbxassetid://89119211625300",
	detachServerAssets = function(targetParent: Instance)
		if bonesModule and bonesModule.Parent == script then
			bonesModule.Parent = targetParent
		end
		if animateTemplate and animateTemplate.Parent == script then
			animateTemplate.Parent = targetParent
		end
	end,
	Method = function(character: Model, accessory: Accessory)
		local color
		if accessory then
			if typeof(accessory) == "Instance" then
				-- only replace the wearer's own accessory
				if not (accessory:IsA("Accessory") and accessory:IsDescendantOf(character)) then
					return
				end
				local part = accessory:FindFirstChild("Handle")
				if part and part:IsA("MeshPart") then
					if string.find(part.TextureID, "74391200400192") then
						color = COLORS.dark
					elseif string.find(part.TextureID, "115319077247149") then
						color = COLORS.gold
					end
				end
				accessory:Destroy()
			elseif typeof(accessory) == "string" then
				for key, value in COLORS do
					if string.find(string.lower(accessory :: string), key :: string, 1, true) then
						color = value
						break
					end
				end
			end
		end

		local template = ensureHat()

		local existing = character:FindFirstChild(HAT_NAME)
		if existing then
			existing:Destroy()
		end

		local clone = template:Clone()

		local wings = clone:FindFirstChild("Wings")
		if wings and wings:IsA("BasePart") then
			if color then
				clone:SetAttribute("_KWingsColor", color)
				wings.Color = color
			end

			local animate = wings:FindFirstChild("Animate")
			if animate and animate:IsA("BaseScript") then
				animate.Enabled = true
			end
		end

		clone.Parent = character

		return clone
	end,
}
