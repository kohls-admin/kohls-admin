-- non abusive fun commands given to VIP role by default

local Util = require(script.Parent.Parent.Util)

local properties = { "Head", "Face", "Shirt", "Pants", "GraphicTShirt" }
local particles = { "_KFire", "_KSmoke", "_KSparkles", "_KLight", "_KParticleEffect" }

local function applyHumanoidDescription(humanoid, description)
	humanoid:ApplyDescriptionReset(description)
	humanoid:ApplyDescription(description)
end

local function updateHumanoidDescription(player, humanoid, description, property, value)
	local attribute = "_K" .. property
	local original = attribute .. "Original"
	if not player:GetAttribute(original) then
		player:SetAttribute(original, description[property])
	end
	description[property] = value or player:GetAttribute(original)
end

local function reapplyHumanoidDescription(player)
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
			updateHumanoidDescription(player, humanoid, description, property, value)
		end
	end

	if change then
		applyHumanoidDescription(humanoid, description)
	end
end

local function attributeHumanoidDescription(player, property, value)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local description = humanoid and humanoid:FindFirstChildOfClass("HumanoidDescription")
	if not description then
		return
	end

	updateHumanoidDescription(player, humanoid, description, property, value)
	player:SetAttribute("_K" .. property, value)

	applyHumanoidDescription(humanoid, description)
end

local function resetHumanoidDescription(player)
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

	-- TODO: reset scale, accessories, bodycolor

	if humanoid and description then
		applyHumanoidDescription(humanoid, description)
	end

	-- TODO: reset infect status, body colors, dog morph
end

if Util.Services.RunService:IsServer() then
	-- update humanoid description on respawn from _K attributes
	Util.SafePlayerAdded(function(player)
		player.CharacterAppearanceLoaded:Connect(function(character)
			task.defer(reapplyHumanoidDescription, player)
		end)
	end)
end

return {
	{
		name = "normal",
		aliases = {},
		description = "Returns one or more player(s) to their normal appearance.",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to return to normal.",
			},
		},

		run = function(context, players, assetId)
			for _, player in players do
				resetHumanoidDescription(player)
			end
		end,
	},
	{
		name = "fire",
		aliases = {},
		description = "Adds fire to one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to add the fire to.",
			},
			{
				type = "number",
				name = "Size",
				description = "The size of the fire.",
				optional = true,
			},
			{
				type = "color",
				name = "Color",
				description = "The color of the fire.",
				optional = true,
			},
			{
				type = "color",
				name = "SecondaryColor",
				description = "The secondary color of the fire.",
				optional = true,
			},
		},

		run = function(context, players, size, color, secondaryColor)
			for _, player in players do
				local root = player.Character
					and (player.Character:FindFirstChild("HumanoidRootPart") or player.Character.PrimaryPart)
				if not root then
					continue
				end
				local existing = root:FindFirstChild("_KFire")
				if existing then
					existing:Destroy()
				end
				local fire = context._K.Flux.new "Fire" {
					Parent = root,
					Name = "_KFire",
					Size = math.min(size or 5, if context._K.Auth.getRank(player.UserId) <= 1 then 5 else math.huge),
				}
				if color then
					fire.Color = color
					fire.SecondaryColor = secondaryColor or color
				end
			end
		end,
	},
	{
		name = "unfire",
		aliases = {},
		description = "Removes fire from one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to remove the fire from.",
			},
		},

		run = function(context, players)
			for _, player in players do
				local root = player.Character
					and (player.Character:FindFirstChild("HumanoidRootPart") or player.Character.PrimaryPart)
				if not root then
					continue
				end
				local existing = root:FindFirstChild("_KFire")
				if existing then
					existing:Destroy()
				end
			end
		end,
	},
	{
		name = "smoke",
		aliases = {},
		description = "Adds smoke to one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to add the smoke to.",
			},
			{
				type = "color",
				name = "Color",
				description = "The color of the smoke.",
				optional = true,
			},
		},

		run = function(context, players, color, secondaryColor)
			for _, player in players do
				local root = player.Character
					and (player.Character:FindFirstChild("HumanoidRootPart") or player.Character.PrimaryPart)
				if not root then
					continue
				end
				local existing = root:FindFirstChild("_KSmoke")
				if existing then
					existing:Destroy()
				end
				local smoke = context._K.Flux.new "Smoke" {
					Parent = root,
					Name = "_KSmoke",
					RiseVelocity = 0,
				}
				if color then
					smoke.Color = color
				end
			end
		end,
	},
	{
		name = "unsmoke",
		aliases = {},
		description = "Removes smoke from one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to remove the smoke from.",
			},
		},

		run = function(context, players)
			for _, player in players do
				local root = player.Character
					and (player.Character:FindFirstChild("HumanoidRootPart") or player.Character.PrimaryPart)
				if not root then
					continue
				end
				local existing = root:FindFirstChild("_KSmoke")
				if existing then
					existing:Destroy()
				end
			end
		end,
	},
	{
		name = "sparkles",
		aliases = {},
		description = "Adds sparkles to one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to add the sparkles to.",
			},
			{
				type = "color",
				name = "Color",
				description = "The color of the sparkles.",
				optional = true,
			},
		},

		run = function(context, players, color, secondaryColor)
			for _, player in players do
				local root = player.Character
					and (player.Character:FindFirstChild("HumanoidRootPart") or player.Character.PrimaryPart)
				if not root then
					continue
				end
				local existing = root:FindFirstChild("_KSparkles")
				if existing then
					existing:Destroy()
				end
				local sparkle = context._K.Flux.new "Sparkles" {
					Parent = root,
					Name = "_KSparkles",
				}
				if color then
					sparkle.SparkleColor = color
				end
			end
		end,
	},
	{
		name = "unsparkles",
		aliases = {},
		description = "Removes sparkles from one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to remove the sparkles from.",
			},
		},

		run = function(context, players)
			for _, player in players do
				local root = player.Character
					and (player.Character:FindFirstChild("HumanoidRootPart") or player.Character.PrimaryPart)
				if not root then
					continue
				end
				local existing = root:FindFirstChild("_KSparkles")
				if existing then
					existing:Destroy()
				end
			end
		end,
	},
	{
		name = "light",
		aliases = { "lamp", "lite" },
		description = "Adds a light to one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to add the light to.",
			},
			{
				type = "number",
				name = "Range",
				description = "The range of the light.",
				optional = true,
			},
			{
				type = "color",
				name = "Color",
				description = "The color of the light.",
				optional = true,
			},
		},

		run = function(context, players, range, color)
			for _, player in players do
				local root = player.Character
					and (player.Character:FindFirstChild("HumanoidRootPart") or player.Character.PrimaryPart)
				if not root then
					continue
				end
				local existing = root:FindFirstChild("_KLight")
				if existing then
					existing:Destroy()
				end
				context._K.Flux.new "PointLight" {
					Parent = root,
					Name = "_KLight",
					Range = math.min(range or 8, if context._K.Auth.getRank(player.UserId) <= 1 then 10 else math.huge),
					Color = color or Color3.new(1, 1, 1),
				}
			end
		end,
	},
	{
		name = "unlight",
		aliases = { "unlamp", "unlite" },
		description = "Removes a light from one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to remove the light from.",
			},
		},

		run = function(context, players)
			for _, player in players do
				local root = player.Character
					and (player.Character:FindFirstChild("HumanoidRootPart") or player.Character.PrimaryPart)
				if not root then
					continue
				end
				local existing = root:FindFirstChild("_KLight")
				if existing then
					existing:Destroy()
				end
			end
		end,
	},
	{
		name = "particle",
		aliases = { "pe" },
		description = "Adds a particle effect to one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to add the particle effect to.",
			},
			{
				type = "integer",
				name = "ImageId",
				description = "The image id of the particle.",
				optional = true,
			},
			{
				type = "color",
				name = "Color",
				description = "The color of the particle.",
				optional = true,
			},
		},
		env = function(_K)
			local infiniteEffect = _K.Flux.new "ParticleEmitter" {
				Enabled = false,
				Name = "_KParticleEffect",
				Texture = "rbxassetid://3021790960",
				Size = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0),
					NumberSequenceKeypoint.new(0.1, 0.25, 0.25),
					NumberSequenceKeypoint.new(1, 0.5),
				}),
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(0.1, 0.25, 0.25),
					NumberSequenceKeypoint.new(0.9, 0.5, 0.25),
					NumberSequenceKeypoint.new(1, 1),
				}),
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0 / 6, Color3.new(1, 0, 0)),
					ColorSequenceKeypoint.new(1 / 6, Color3.new(1, 0, 1)),
					ColorSequenceKeypoint.new(2 / 6, Color3.new(0, 0, 1)),
					ColorSequenceKeypoint.new(3 / 6, Color3.new(0, 1, 1)),
					ColorSequenceKeypoint.new(4 / 6, Color3.new(0, 1, 0)),
					ColorSequenceKeypoint.new(5 / 6, Color3.new(1, 1, 0)),
					ColorSequenceKeypoint.new(6 / 6, Color3.new(1, 0, 0)),
				}),
				Lifetime = NumberRange.new(5),
				Speed = NumberRange.new(0.5, 1),
				Rotation = NumberRange.new(0, 359),
				RotSpeed = NumberRange.new(-90, 90),
				Rate = 11,
				VelocitySpread = 180,
			}
			return { effect = infiniteEffect }
		end,

		run = function(context, players, image, color)
			for _, player in players do
				local root = player.Character
					and (player.Character:FindFirstChild("HumanoidRootPart") or player.Character.PrimaryPart)
				if not root then
					continue
				end
				local existing = root:FindFirstChild("_KParticleEffect")
				if existing then
					existing:Destroy()
				end
				local pe = context.env.effect:Clone()
				if color then
					pe.Color = ColorSequence.new(color)
				end
				if image then
					pe.Texture = "rbxassetid://" .. image
				end
				pe.Enabled = true
				pe.Parent = root
			end
		end,
	},
	{
		name = "unparticle",
		aliases = { "unpe" },
		description = "Removes a particle effect from one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to remove the particle effect from.",
			},
		},

		run = function(context, players, userId)
			for _, player in players do
				local root = player.Character
					and (player.Character:FindFirstChild("HumanoidRootPart") or player.Character.PrimaryPart)
				if not root then
					continue
				end
				local existing = root:FindFirstChild("_KParticleEffect")
				if existing then
					existing:Destroy()
				end
			end
		end,
	},

	{
		name = "removehats",
		aliases = { "rhats" },
		description = "Removes the hats of one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) whose hats to remove.",
				shouldRequest = true,
			},
			{
				type = "boolean",
				name = "AdminHats",
				description = "When true, only removes the hats given by the admin, defaults to false.",
				optional = true,
			},
		},

		run = function(context, players, adminHats)
			for _, player in players do
				if not player.Character then
					continue
				end
				for _, instance in player.Character:GetChildren() do
					if instance:IsA("Accoutrement") and (not adminHats or instance.Name == "KHat") then
						instance:Destroy()
					end
				end
			end
		end,
	},
	{
		name = "bundle",
		aliases = { "unbundle" },
		description = "Changes the bundle of one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) whose appearance to change.",
			},
			{
				type = "integer",
				name = "AssetId",
				description = "The assetId of the bundle, or the original appearance if omitted.",
				optional = true,
			},
		},
		env = function(_K)
			local function getOutfitId(bundleId)
				if bundleId <= 0 then
					return
				end
				local info = game.AssetService:GetBundleDetailsAsync(bundleId)
				if not info then
					return
				end
				for _, item in pairs(info.Items) do
					if item.Type == "UserOutfit" then
						return item.Id
					end
				end

				return nil
			end

			local function getHumanoidDescriptionBundle(bundleId)
				local itemId = getOutfitId(bundleId)
				if itemId and itemId > 0 then
					return Util.Services.Players:GetHumanoidDescriptionFromOutfitId(itemId)
				end

				return nil
			end
			return {
				getHumanoidDescriptionBundle = getHumanoidDescriptionBundle,
			}
		end,

		run = function(context, players, assetId)
			local bundleDescription = if assetId then context.env.getHumanoidDescriptionBundle(assetId) else nil
			for _, player in players do
				local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
				if not humanoid then
					return
				end
				local description = humanoid:FindFirstChildOfClass("HumanoidDescription")
				if not description then
					return
				end

				local originalDescription = player:FindFirstChild("_KHumanoidDescription")
				if not originalDescription then
					originalDescription = description:Clone()
					originalDescription.Name = "_KHumanoidDescription"
					originalDescription.Parent = player
				end

				if bundleDescription then
					humanoid:ApplyDescription(bundleDescription)
				else
					humanoid:ApplyDescription(originalDescription)
				end
				-- reapply other admin description changes
				task.defer(reapplyHumanoidDescription, player)
			end
		end,
	},
	{
		name = "head",
		aliases = { "unhead" },
		description = "Changes the head of one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) whose head to change.",
			},
			{
				type = "integer",
				name = "AssetId",
				description = "The assetId of the head, or the original head if omitted.",
				optional = true,
			},
		},

		run = function(context, players, assetId)
			for _, player in players do
				attributeHumanoidDescription(player, "Head", assetId)
			end
		end,
	},
	{
		name = "face",
		aliases = { "unface" },
		description = "Changes the face of one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) whose face to change.",
			},
			{
				type = "integer",
				name = "AssetId",
				description = "The assetId of the face, or the original face if omitted.",
				optional = true,
			},
		},

		run = function(context, players, assetId)
			for _, player in players do
				attributeHumanoidDescription(player, "Face", assetId)
			end
		end,
	},
	{
		name = "shirt",
		aliases = { "unshirt" },
		description = "Changes the shirt of one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) whose shirt to change.",
			},
			{
				type = "integer",
				name = "AssetId",
				description = "The assetId of the shirt, or the original shirt if omitted.",
				optional = true,
			},
		},

		run = function(context, players, assetId)
			for _, player in players do
				attributeHumanoidDescription(player, "Shirt", assetId)
			end
		end,
	},
	{
		name = "pants",
		aliases = { "unpants" },
		description = "Changes the pants of one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) whose pants to change.",
			},
			{
				type = "integer",
				name = "AssetId",
				description = "The assetId of the pants, or the original pants if omitted.",
				optional = true,
			},
		},

		run = function(context, players, assetId)
			for _, player in players do
				attributeHumanoidDescription(player, "Pants", assetId)
			end
		end,
	},
	{
		name = "tshirt",
		aliases = { "untshirt" },
		description = "Changes the t-shirt of one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) whose t-shirt to change.",
			},
			{
				type = "integer",
				name = "AssetId",
				description = "The assetId of the t-shirt, or the original t-shirt if omitted.",
				optional = true,
			},
		},

		run = function(context, players, assetId)
			for _, player in players do
				attributeHumanoidDescription(player, "GraphicTShirt", assetId)
			end
		end,
	},
}
