local Humanoid = {}

local properties = {
	"Head",
	"Face",
	"Shirt",
	"Pants",
	"GraphicTShirt",
	"HeadColor",
	"LeftArmColor",
	"LeftLegColor",
	"RightArmColor",
	"RightLegColor",
	"TorsoColor",
}
local particles = { "_KFire", "_KSmoke", "_KSparkles", "_KLight", "_KParticleEffect" }

function Humanoid.applyDescription(humanoid, description)
	humanoid:ApplyDescriptionReset(description)
	humanoid:ApplyDescription(description)
end

function Humanoid.updateDescription(player, humanoid, description, property, value)
	local attribute = "_K" .. property
	local original = attribute .. "Original"
	if not player:GetAttribute(original) then
		player:SetAttribute(original, description[property])
	end
	description[property] = value or player:GetAttribute(original)
end

function Humanoid.reapplyDescription(player)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local description = humanoid and humanoid:FindFirstChildOfClass("HumanoidDescription")
	if not description then
		return
	end

	local change
	for _, property in properties do
		local value = player:GetAttribute("_K" .. property)
		if value then
			change = true
			Humanoid.updateDescription(player, humanoid, description, property, value)
		end
	end

	if change then
		Humanoid.applyDescription(humanoid, description)
	end
end

function Humanoid.attributeDescription(player, property, value)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local description = humanoid and humanoid:FindFirstChildOfClass("HumanoidDescription")
	if not description then
		return
	end

	Humanoid.updateDescription(player, humanoid, description, property, value)
	player:SetAttribute("_K" .. property, value)

	Humanoid.applyDescription(humanoid, description)
end

function Humanoid.resetDescription(player)
	-- reset particles
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		or player.Character.PrimaryPart
	if root then
		for _, particle in particles do
			local existing = root:FindFirstChild(particle)
			if existing then
				existing:Destroy()
			end
		end
	end

	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local description = humanoid and humanoid:FindFirstChildOfClass("HumanoidDescription")

	local originalDescription = player:FindFirstChild("_KHumanoidDescription")
	if originalDescription then
		description:Destroy()
		originalDescription.Name = "HumanoidDescription"
		originalDescription.Parent = humanoid
		description = originalDescription
	end

	-- reset properties
	for _, property in properties do
		local attribute = "_K" .. property
		local original = attribute .. "Original"
		local originalValue = player:GetAttribute(original)
		if originalValue == nil then
			continue
		end
		player:SetAttribute(original, nil)
		if description then
			description[property] = originalValue
		end
	end

	-- TODO: reset scale, accessories

	if humanoid and description then
		Humanoid.applyDescription(humanoid, description)
	end
end

return Humanoid
