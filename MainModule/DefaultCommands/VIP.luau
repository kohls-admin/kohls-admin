-- non abusive fun commands given to VIP role by default

local Util = require(script.Parent.Parent.Util)

if Util.Services.RunService:IsServer() then
	-- update humanoid description on respawn from _K attributes
	Util.SafePlayerAdded(function(player)
		player.CharacterAppearanceLoaded:Connect(function(character)
			task.defer(Util.Humanoid.reapplyDescription, player)
		end)
	end)
end

return {
	{
		name = "normal",
		aliases = { "undog", "unhorse", "uninfect" },
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
				Util.Humanoid.resetDescription(player)

				local infected = context._K.Flux.Scope.Infected[player.Character]
				if infected then
					infected:Disconnect()
					local face = player.Character:FindFirstChild("Head")
						and player.Character.Head:FindFirstChild("face")
					if face then
						face.Texture = face:GetAttribute("_KInfectOriginal")
						face:SetAttribute("_KInfectOriginal")
					end
				end
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

				local ok, info = pcall(function()
					return _K.Util.Services.AssetService:GetBundleDetailsAsync(bundleId)
				end)
				if not ok or not info then
					return
				end

				for _, item in pairs(info.Items) do
					if item.Type == "UserOutfit" then
						return item.Id
					end
				end

				return
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
			if not bundleDescription then
				context._K.Remote.Notify:FireClient(context.fromPlayer, `Failed to load bundle.`, nil, "error")
			end
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
				task.defer(Util.Humanoid.reapplyDescription, player)
			end
		end,
	},
	{
		name = "hat",
		description = "Gives one or more player(s) a hat.",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to give the hat.",
			},
			{
				type = "integer",
				name = "AssetId",
				description = "The assetId of the hat.",
			},
		},
		env = function()
			return {
				allowed = { 24112667, 24114402, 33070696, 305888394 },
				limit = function(character)
					-- limit to 16 hats to mitigate lag
					local hats = 0
					for _, child in character:GetChildren() do
						if child:IsA("Accoutrement") and string.find(child.Name, "_KHat") == 1 then
							hats += 1
							if #hats >= 16 then
								child:Destroy()
							end
						end
					end
				end,
			}
		end,

		run = function(context, players, assetId)
			local model = context._K.Util.Services.InsertService:LoadAsset(assetId)
			-- clean up scripts if not a sound hat
			if not table.find(context.env.allowed, assetId) then
				for _, descendant in model:GetDescendants() do
					if descendant:IsA("BaseScript") or descendant:IsA("ModuleScript") then
						descendant:Destroy()
					end
				end
			end

			local hat = model:FindFirstChildWhichIsA("Accoutrement")
			hat = hat and hat:Clone()
			model:Destroy()
			if not hat then
				return false, "Invalid hat id"
			end
			local name = "_KHat" .. assetId
			hat.Name = name

			for _, player in players do
				if player.Character and not player.Character:FindFirstChild(name) then
					context.env.limit(player.Character)
					hat:Clone().Parent = player.Character
				end
			end
			return
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
					if instance:IsA("Accoutrement") and (not adminHats or string.find(instance.Name, "_KHat") == 1) then
						instance:Destroy()
					end
				end
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
				Util.Humanoid.attributeDescription(player, "Head", assetId)
			end
		end,
	},
	{
		name = "headsize",
		aliases = { "bighead", "hugehead", "largehead", "tinyhead", "minihead", "smallhead", "normalhead" },
		description = "Changes the head size of one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) whose head size to change.",
			},
			{
				type = "number",
				name = "Size",
				description = "The size of the head, or the original size if omitted.",
				optional = true,
			},
		},
		env = function(_K)
			local function scaleHead(char, scale)
				local human = char and char:FindFirstChildOfClass("Humanoid")
				if not human then
					return
				end
				if human.RigType == Enum.HumanoidRigType.R15 then
					if human:FindFirstChild("HeadScale") then
						local headScale = human:GetAttribute("_KHeadScale")
						if not headScale then
							headScale = human.HeadScale.Value
							human:SetAttribute("_KHeadScale", headScale)
						end
						human.HeadScale.Value = headScale * scale
					end
				elseif human.RigType == Enum.HumanoidRigType.R6 then
					if char:FindFirstChild("Head") and char:FindFirstChild("Torso") then
						local meshScale = human:GetAttribute("_KMeshScale")
						if not meshScale then
							meshScale = char.Head.Mesh.Scale
							human:SetAttribute("_KMeshScale", meshScale)
						end
						char.Head.Mesh.Scale = meshScale * scale

						local headY = char.Head.Size.Y
						char.Torso.Neck.C0 = CFrame.new(0, headY / 2 + (headY * scale / 2), 0)
							* CFrame.Angles(math.pi / 2, math.pi, 0)
					end
				end
				if scale == 1 then
					human:SetAttribute("_KHeadScale", nil)
					human:SetAttribute("_KMeshScale", nil)
				end
			end

			_K.Flux.Scope.scaleHead = scaleHead
			return {
				scaleHead = scaleHead,
				big = { "bighead", "largehead", "hugehead" },
				small = { "smallhead", "minihead", "tinyhead" },
			}
		end,

		run = function(context, players, size)
			if context.alias == "normalhead" then
				size = 1
			elseif table.find(context.env.big, context.alias) then
				size = 3
			elseif table.find(context.env.small, context.alias) then
				size = 0.5
			end

			size = size or 1
			if context._K.Auth.getRank(context.from) <= 1 then
				size = math.clamp(size, 0.5, 3)
			end
			for _, player in players do
				context.env.scaleHead(player.Character, size)
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
				Util.Humanoid.attributeDescription(player, "Face", assetId)
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
				Util.Humanoid.attributeDescription(player, "Shirt", assetId)
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
				Util.Humanoid.attributeDescription(player, "Pants", assetId)
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
				Util.Humanoid.attributeDescription(player, "GraphicTShirt", assetId)
			end
		end,
	},
}
