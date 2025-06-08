-- non abusive fun commands given to VIP role by default

local Util = require(script.Parent.Parent.Util)

if Util.Service.Run:IsServer() then
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
		aliases = { "uninfect" },
		description = "Returns one or more player(s) to their normal appearance.",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to return to normal.",
			},
		},

		run = function(context, players)
			for _, player in players do
				if player.Character then
					local crmCommand = context._K.Registry.commands.crm
					if crmCommand then
						crmCommand.env.update(player.Character)
					end
				end

				local existing = player.Character and player.Character:FindFirstChild("_KCape")
				if existing then
					existing:Destroy()
				end

				local dogSeat = player.Character:FindFirstChild("_KDogSeat")
				if dogSeat then
					dogSeat:Destroy()
					local undogCommand = context._K.Registry.commands.undog
					if undogCommand then
						local humanoid = player.Character:FindFirstChild("Humanoid")
						if not humanoid then
							continue
						end
						if humanoid.RigType == Enum.HumanoidRigType.R6 then
							undogCommand.env.R6(player.Character)
						else
							undogCommand.env.R15(player.Character)
						end
					end
				end

				Util.Humanoid.resetDescription(player)

				local infectedCommand = context._K.Registry.commands.infect
				if infectedCommand then
					local infected = infectedCommand.env.infected[player.Character]
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
			end
		end,
	},
	{
		name = "fire",
		aliases = { "🔥" },
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
			size = math.min(size or 5, if context._K.Auth.getRank(context.from) <= 1 then 5 else math.huge)
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
					Size = size,
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
		aliases = { "un🔥" },
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
		aliases = { "💨" },
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
		aliases = { "un💨" },
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
		aliases = { "✨" },
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
		aliases = { "un✨" },
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
		aliases = { "💡", "lamp", "lite" },
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
			range = math.min(range or 8, if context._K.Auth.getRank(context.from) <= 1 then 10 else math.huge)
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
					Range = range,
					Color = color or Color3.new(1, 1, 1),
				}
			end
		end,
	},
	{
		name = "unlight",
		aliases = { "un💡", "unlamp", "unlite" },
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
		name = "highlight",
		aliases = { "hl", "unhighlight", "unhl" },
		description = "Highlights one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to highlight.",
			},
			{
				type = "color",
				name = "FillColor",
				description = "The fill color of the highlight.",
				optional = true,
			},
			{
				type = "color",
				name = "OutlineColor",
				description = "The outline color of the highlight.",
				optional = true,
			},
			{
				type = "number",
				name = "FillTransparency",
				description = "The fill transparency of the highlight.",
				optional = true,
			},
			{
				type = "number",
				name = "OutlineTransparency",
				description = "The outline transparency of the highlight.",
				optional = true,
			},
		},
		run = function(context, players, fillColor, outlineColor, fillTransparency, outlineTransparency)
			for _, player in players do
				if player.Character then
					local existing = player.Character:FindFirstChild("_KHighlight")
					if existing then
						existing:Destroy()
					end

					if context.undo then
						continue
					end
					context._K.Flux.new "Highlight" {
						Parent = player.Character,
						Name = "_KHighlight",
						FillColor = fillColor or Color3.new(1, 1, 1),
						FillTransparency = fillTransparency or 0.5,
						OutlineColor = outlineColor or Color3.new(1, 1, 1),
						OutlineTransparency = outlineTransparency or 0,
						DepthMode = Enum.HighlightDepthMode.Occluded,
					}
				end
			end
		end,
	},
	{
		name = "particle",
		aliases = { "💫", "pe" },
		description = "Adds a particle effect to one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to add the particle effect to.",
			},
			{
				type = "image",
				name = "AssetId",
				description = "The image assetId of the particle.",
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
			local particle = _K.Flux.new "ParticleEmitter" {
				Enabled = false,
				Name = "_KParticleEffect",
				Texture = "rbxassetid://73860257495735",
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

			local function apply(fromPlayer, player, image, color)
				local root = player.Character
					and (player.Character:FindFirstChild("HumanoidRootPart") or player.Character.PrimaryPart)
				if not root then
					return
				end
				local existing = root:FindFirstChild("_KParticleEffect")
				if existing then
					existing:Destroy()
				end
				local pe = particle:Clone()
				if fromPlayer and (fromPlayer:GetAttribute("_KDonationLevel") < 3) then
					color = color or Color3.new()
				end
				if color then
					pe.Color = ColorSequence.new(color)
				end
				if image then
					pe.Texture = _K.Util.getTexture(image)
				end
				pe.Enabled = true
				pe.Parent = root
			end

			_K.Remote.DonorTrail.OnServerEvent:Connect(function(player)
				apply(player, player, nil, nil)
			end)

			return { apply = apply }
		end,

		run = function(context, players, image, color)
			for _, player in players do
				context.env.apply(context.fromPlayer, player, image, color)
			end
		end,
	},
	{
		name = "unparticle",
		aliases = { "un💫", "unpe" },
		description = "Removes a particle effect from one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to remove the particle effect from.",
			},
		},

		run = function(context, players)
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
		name = "trail",
		aliases = { "☄️" },
		description = "Adds a trail to one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to add the trail to.",
			},
			{
				type = "color",
				name = "Color",
				description = "The color of the trail.",
				optional = true,
			},
		},

		run = function(context, players: { Player }, color: Color3?)
			for _, player in players do
				local torso = player.Character
					and (player.Character:FindFirstChild("Torso") or player.Character:FindFirstChild("UpperTorso"))
				if not torso then
					continue
				end
				local existing = torso:FindFirstChild("_KTrailEffect")
				if existing then
					existing:Destroy()
				end
				local trail = Instance.new("Trail")
				trail.Name = "_KTrailEffect"
				trail.Attachment0 = torso:FindFirstChild("WaistRigAttachment")
					or torso:FindFirstChild("WaistCenterAttachment")
				trail.Attachment1 = torso:FindFirstChild("NeckAttachment")
				trail.FaceCamera = true
				trail.Lifetime = 0.5
				trail.LightEmission = 1
				trail.LightInfluence = 0
				trail.WidthScale = NumberSequence.new(1, 0)
				trail.Transparency = NumberSequence.new(0, 1)
				trail.Color = color or trail.Color
				trail.Parent = torso
			end
		end,
	},
	{
		name = "untrail",
		aliases = { "un☄️" },
		description = "Removers a trail from one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to remove the trail from.",
			},
		},

		run = function(context, players)
			for _, player in players do
				local torso = player.Character
					and (player.Character:FindFirstChild("Torso") or player.Characer:FindFirstChild("UpperTorso"))
				if not torso then
					continue
				end
				local existing = torso:FindFirstChild("_KTrailEffect")
				if existing then
					existing:Destroy()
				end
			end
		end,
	},
	{
		name = "shine",
		aliases = { "🌟", "un🌟", "unshine" },
		description = "Adds a shine effect to one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to add the shine effect to.",
			},
		},
		env = function(_K)
			return {
				effect = _K.Flux.new "ParticleEmitter" {
					Name = "_KShineEffect",
					LockedToPart = true,
					LightEmission = 1,
					Texture = "rbxassetid://1085001473",
					Lifetime = NumberRange.new(2),
					Size = NumberSequence.new(5),
					Speed = NumberRange.new(0),
					Rate = 2,
					Rotation = NumberRange.new(-180, 180),
					RotSpeed = NumberRange.new(-10, 10),
					Transparency = NumberSequence.new({
						NumberSequenceKeypoint.new(0, 1, 0),
						NumberSequenceKeypoint.new(0.5, 0.75, 0),
						NumberSequenceKeypoint.new(1, 1, 0),
					}),
				},
			}
		end,
		run = function(context, players)
			for _, player in players do
				local root = player.Character
					and (player.Character:FindFirstChild("HumanoidRootPart") or player.Character.PrimaryPart)
				if not root then
					continue
				end
				local existing = root:FindFirstChild("_KShineEffect")
				if existing then
					existing:Destroy()
				end
				if context.undo then
					continue
				end
				local shine = context.env.effect:Clone()
				shine.Parent = root
			end
		end,
	},

	{
		name = "bundle",
		aliases = { "📦", "un📦", "unbundle" },
		description = "Applies a bundle to one or more player(s).",
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
					return _K.Service.Asset:GetBundleDetailsAsync(bundleId)
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
					return Util.Service.Players:GetHumanoidDescriptionFromOutfitId(itemId)
				end

				return nil
			end
			return {
				getHumanoidDescriptionBundle = getHumanoidDescriptionBundle,
			}
		end,

		run = function(context, players, assetId: number?)
			local bundleDescription = if assetId then context.env.getHumanoidDescriptionBundle(assetId) else nil
			if assetId and not bundleDescription then
				return `Failed to load bundle.`
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
			return
		end,
	},
	{
		name = "cape",
		description = "Gives a cape to one or more player(s)",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to give a cape.",
			},
			{
				type = "color",
				name = "Color",
				description = "The color to apply to the cape.",
				optional = true,
			},
			{
				type = "number",
				name = "Reflectance",
				description = "How much the cape reflects the skybox.",
				optional = true,
			},
			{
				type = "Enum.Material",
				name = "Material",
				description = "The material to apply to the cape.",
				optional = true,
			},
			{
				type = "image",
				name = "AssetId",
				description = "The assetId of the image to apply to the cape.",
				optional = true,
			},
		},
		envClient = function(_K)
			local CollectionService = game:GetService("CollectionService")

			local capeMotors = {}
			game:GetService("RunService").Heartbeat:Connect(function(step)
				for motor, offset in capeMotors do
					local root = motor.Part0
					if not root then
						capeMotors[motor] = nil
						continue
					end

					local wave = (math.sin(offset) + 1) / 10
					local velocity = root.AssemblyLinearVelocity - workspace.GlobalWind
					local dot = math.max(0, root.CFrame.LookVector:Dot(velocity.Unit))
					local magnitude = velocity.Magnitude
						+ root.AssemblyAngularVelocity.Magnitude
						+ math.abs(root.AssemblyLinearVelocity.Y)
					local angle = dot * magnitude / 32
					motor.MaxVelocity = math.clamp(magnitude / 32, 0.02, 0.2)
					motor.DesiredAngle = math.clamp(angle + wave + 0.1, 0.1, if velocity.Y < 0 then 2.5 else 2)

					capeMotors[motor] += step * (math.clamp(dot * magnitude / 4 + 1, 1, 8))
				end
			end)

			local function addCapeMotor(motor: Motor6D)
				capeMotors[motor] = math.random() * 2 * math.pi
			end

			local function removeCapeMotor(motor: Motor6D)
				capeMotors[motor] = nil
			end

			CollectionService:GetInstanceRemovedSignal("_KCapeMotor"):Connect(removeCapeMotor)
			for _, tagged in CollectionService:GetTagged("_KCapeMotor") do
				addCapeMotor(tagged)
			end
			CollectionService:GetInstanceAddedSignal("_KCapeMotor"):Connect(addCapeMotor)
		end,
		env = function(_K)
			return {
				add = function(character, color, reflectance, material, image)
					local root = character
						and (character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso"))
					if not root then
						return
					end

					local existing = character:FindFirstChild("_KCape")
					if existing then
						existing:Destroy()
					end

					local cape = Instance.new("Part")
					cape.Name = "_KCape"
					cape.Color = color or Color3.new()
					cape.Material = material or Enum.Material.SmoothPlastic
					cape.Reflectance = reflectance or 0
					cape.CanCollide = false
					cape.CanQuery = false
					cape.CanTouch = false
					cape.Massless = true
					cape.TopSurface = 0
					cape.BottomSurface = 0
					cape.Size = Vector3.new(1.9, 3.8, 0.2)

					if image then
						Instance.new("Decal", cape).Texture = image
					end

					local motor = Instance.new("Motor6D")
					motor.Part0 = root
					motor.Part1 = cape
					motor.C0 = CFrame.new(0, root.Size.Y / 2, root.Size.Z / 2) * CFrame.Angles(0, -math.pi / 2, 0)
					motor.C1 = CFrame.new(0, cape.Size.Y / 2, 0) * CFrame.Angles(0, math.pi / 2, 0)
					motor.DesiredAngle = 0.1
					motor.MaxVelocity = 0.1
					motor:AddTag("_KCapeMotor")
					motor.Parent = cape

					cape.Parent = character
				end,
			}
		end,
		run = function(context, players, color, reflectance, material, image)
			for _, player in players do
				context.env.add(player.Character, color, reflectance, material, image)
			end
		end,
	},
	{
		name = "uncape",
		description = "Removes the cape from one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) whose cape to remove.",
			},
		},

		run = function(context, players)
			for _, player in players do
				local existing = player.Character and player.Character:FindFirstChild("_KCape")
				if existing then
					existing:Destroy()
				end
			end
		end,
	},
	{
		name = "hat",
		aliases = { "🎩", "crmhat" },
		description = "Gives one or more hats to one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to give one or more hats.",
			},
			{
				type = "integers",
				name = "AssetIds",
				description = "The assetId of one or more hats.",
			},
			{
				type = "image",
				name = "Texture",
				description = "The assetId of the hat texture.",
				optional = true,
			},
			{
				type = "color",
				name = "Color",
				description = "The color to apply to the hat.",
				optional = true,
			},
			{
				type = "number",
				name = "Reflectance",
				description = "How much the hat reflects the skybox.",
				optional = true,
			},
			{
				type = "Enum.Material",
				name = "Material",
				description = "The material to apply to the hat.",
				optional = true,
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
							if hats >= 16 then
								child:Destroy()
							end
						end
					end
				end,
			}
		end,

		run = function(context, players, assetIds, texture, color, reflectance, material)
			for i, assetId in assetIds do
				if i >= 16 then
					break
				end

				local hat, model

				-- meshpart loading hack for crm neon compatibility
				local accessoryTypes = {
					[8] = "HatAccessory",
					[41] = "HairAccessory",
					[42] = "FaceAccessory",
					[43] = "NeckAccessory",
					[44] = "ShouldersAccessory",
					[45] = "FrontAccessory",
					[46] = "BackAccessory",
					[47] = "WaistAccessory",
				}
				local ok, info = pcall(function()
					return context._K.Service.Marketplace:GetProductInfo(assetId)
				end)
				local accessoryType = ok and accessoryTypes[info.AssetTypeId]
				local description = Instance.new("HumanoidDescription")
				if accessoryType then
					description[accessoryType] = assetId
					model = context._K.Service.Players:CreateHumanoidModelFromDescription(
						description,
						Enum.HumanoidRigType.R15
					)
					hat = model:FindFirstChildWhichIsA("Accoutrement")
				end

				-- fallback hat loading
				if not hat then
					model = context._K.Service.Insert:LoadAsset(assetId)
					-- clean up scripts if not a sound hat
					if not table.find(context.env.allowed, assetId) then
						for _, descendant in model:GetDescendants() do
							if descendant:IsA("BaseScript") or descendant:IsA("ModuleScript") then
								descendant:Destroy()
							end
						end
					end
					hat = model:FindFirstChildWhichIsA("Accoutrement")
				end

				hat = hat and hat:Clone()
				model:Destroy()

				if not hat then
					continue
				end

				if texture and hat:FindFirstChild("Handle") then
					if hat.Handle:IsA("MeshPart") then
						hat.Handle.TextureID = texture
					else
						local mesh = hat.Handle:FindFirstChildWhichIsA("FileMesh")
						if mesh then
							mesh.TextureId = texture
						end
					end
				end

				if color then
					for _, descendant in hat:GetDescendants() do
						if descendant:IsA("BasePart") then
							context._K.Registry.commands.crm.env.updatePart(descendant, color, reflectance, material)
						end
					end
				end

				local name = "_KHat" .. assetId
				hat.Name = name

				for _, player in players do
					if player.Character then
						local existing = player.Character:FindFirstChild(name)
						if existing then
							existing:Destroy()
						end
						context.env.limit(player.Character)
						hat:Clone().Parent = player.Character
					end
				end
			end
		end,
	},
	{
		name = "removehats",
		aliases = { "remove🎩", "r🎩", "rhats" },
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
				description = "When true, only removes hats given via admin commands (defaults to false).",
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
		aliases = { "🗿", "unhead" },
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
		aliases = { "🙂", "un🙂", "unface" },
		description = "Changes the face of one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) whose face to change.",
			},
			{
				type = "image",
				name = "AssetId",
				description = "The assetId of the face, or the original face if omitted.",
				optional = true,
			},
		},

		run = function(context, players, image)
			for _, player in players do
				local head = player.Character and player.Character:FindFirstChild("Head")
				if not head then
					continue
				end
				local face = head:FindFirstChild("face")
				if not face then
					face = Instance.new("Decal")
					face.Name = "face"
					face.Parent = head
				end
				if not player.Character:GetAttribute("_KFace") then
					player.Character:SetAttribute("_KFace", face.Texture)
				end
				face.Texture = if context.undo then player.Character:GetAttribute("_KFace") else image
			end
		end,
	},
	{
		name = "shirt",
		aliases = { "👕", "un👕", "unshirt" },
		description = "Changes the shirt of one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) whose shirt to change.",
			},
			{
				type = "image",
				name = "AssetId",
				description = "The assetId of the shirt, or the original shirt if omitted.",
				optional = true,
			},
		},

		run = function(context, players, image)
			for _, player in players do
				if not player.Character then
					continue
				end
				local shirt = player.Character:FindFirstChildOfClass("Shirt")
				if not shirt then
					shirt = Instance.new("Shirt")
					shirt.Parent = player.Character
				end
				if not player.Character:GetAttribute("_KShirt") then
					player.Character:SetAttribute("_KShirt", shirt.ShirtTemplate)
				end
				shirt.ShirtTemplate = if context.undo then player.Character:GetAttribute("_KShirt") else image
			end
		end,
	},
	{
		name = "pants",
		aliases = { "👖", "un👖", "unpants" },
		description = "Changes the pants of one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) whose pants to change.",
			},
			{
				type = "image",
				name = "AssetId",
				description = "The assetId of the pants, or the original pants if omitted.",
				optional = true,
			},
		},

		run = function(context, players, image)
			for _, player in players do
				if not player.Character then
					continue
				end
				local existing = player.Character:FindFirstChildOfClass("Pants")
				if not existing then
					existing = Instance.new("Pants")
					existing.Parent = player.Character
				end
				if not player.Character:GetAttribute("_KPants") then
					player.Character:SetAttribute("_KPants", existing.PantsTemplate)
				end
				existing.PantsTemplate = if context.undo then player.Character:GetAttribute("_KPants") else image
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
				type = "image",
				name = "AssetId",
				description = "The assetId of the t-shirt, or the original t-shirt if omitted.",
				optional = true,
			},
		},

		run = function(context, players, image)
			for _, player in players do
				if not player.Character then
					continue
				end
				local tshirt = player.Character:FindFirstChildOfClass("ShirtGraphic")
				if not tshirt then
					tshirt = Instance.new("ShirtGraphic")
					tshirt.Parent = player.Character
				end
				if not player.Character:GetAttribute("_KTShirt") then
					player.Character:SetAttribute("_KTShirt", tshirt.Graphic)
				end
				tshirt.Graphic = if context.undo then player.Character:GetAttribute("_KTShirt") else image
			end
		end,
	},
	{
		name = "crm",
		aliases = { "uncrm" },
		description = "Changes the color, reflectance, or material of one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) whose character appearance will be changed",
			},
			{
				type = "color",
				name = "Color",
				description = "The color to apply to the character.",
				optional = true,
			},
			{
				type = "number",
				name = "Reflectance",
				description = "How much a character reflects the skybox.",
				optional = true,
			},
			{
				type = "Enum.Material",
				name = "Material",
				description = "The material to apply to the character.",
				optional = true,
			},
		},
		env = function(_K)
			local deny = {
				[Enum.Material.Water] = true,
			}

			local function updatePart(part: BasePart, color: Color3, reflectance: number, material: Enum.Material)
				local apply = color or reflectance or material

				if part:IsA("MeshPart") and material ~= Enum.Material.ForceField then
					if not part:GetAttribute("_KTextureID") then
						part:SetAttribute("_KTextureID", part.TextureID)
					end
					part.TextureID = if apply then "" else part:GetAttribute("_KTextureID") :: string
				end
				local mesh = part:FindFirstChildOfClass("SpecialMesh")
				if mesh and material ~= Enum.Material.ForceField then
					if not mesh:GetAttribute("_KTextureId") then
						mesh:SetAttribute("_KTextureId", mesh.TextureId)
					end
					mesh.TextureId = if apply then "" else mesh:GetAttribute("_KTextureId")
				end
				if not part:GetAttribute("_KColor") then
					part:SetAttribute("_KColor", part.Color)
				end
				if not part:GetAttribute("_KReflectance") then
					part:SetAttribute("_KReflectance", part.Reflectance)
				end
				if not part:GetAttribute("_KMaterial") then
					part:SetAttribute("_KMaterial", part.Material)
				end
				part.Color = if color then color else part:GetAttribute("_KColor") :: Color3
				part.Reflectance = if reflectance then reflectance else part:GetAttribute("_KReflectance") :: number
				part.Material = if material then material else part:GetAttribute("_KMaterial") :: Enum.Material
			end

			return {
				updatePart = updatePart,
				update = function(character: Model, color: Color3, reflectance: number, material: Enum.Material)
					if deny[material] then
						return
					end
					local humanoid = character:FindFirstChildOfClass("Humanoid")
					if not humanoid then
						return
					end

					local apply = color or reflectance or material

					if material ~= Enum.Material.ForceField then
						local shirt = character:FindFirstChildOfClass("Shirt")
						if shirt then
							if not character:GetAttribute("_KShirt") then
								character:SetAttribute("_KShirt", shirt.ShirtTemplate)
							end
							shirt.ShirtTemplate = if apply then "" else character:GetAttribute("_KShirt")
						end

						local pants = character:FindFirstChildOfClass("Pants")
						if pants then
							if not character:GetAttribute("_KPants") then
								character:SetAttribute("_KPants", pants.PantsTemplate)
							end
							pants.PantsTemplate = if apply then "" else character:GetAttribute("_KPants")
						end
					end

					for _, descendant in character:GetDescendants() do
						if descendant:IsA("BasePart") and descendant.Name ~= "HumanoidRootPart" then
							updatePart(descendant, color, reflectance, material)
						elseif descendant:IsA("SurfaceAppearance") then
							if apply and not descendant:FindFirstChild("_KParent") then
								local _KParent = Instance.new("ObjectValue")
								_KParent.Name = "_KParent"
								_KParent.Value = descendant.Parent
								_KParent.Parent = descendant
								descendant.Parent = humanoid
							elseif not apply and descendant:FindFirstChild("_KParent") then
								descendant.Parent = descendant._KParent.Value
								descendant._KParent:Destroy()
							end
						end
					end
				end,
			}
		end,

		run = function(context, players, color, reflectance, material)
			for _, player in players do
				if player.Character and player.Character.PrimaryPart then
					context.env.update(player.Character, color, reflectance, material)
				end
			end
		end,
	},
	{
		name = "goldify",
		aliases = { "gold" },
		description = "Glimmer like gold!",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to turn to gold.",
			},
		},
		run = function(context, players: { Player })
			for _: number, player: Player in players do
				if
					player.Character
					and player.Character.PrimaryPart
					and player.Character:FindFirstChildWhichIsA("Humanoid")
				then
					context._K.Registry.commands.crm.env.update(
						player.Character,
						BrickColor.new("Gold").Color,
						0.4,
						Enum.Material.Metal
					)
				end
			end
		end,
	},
	{
		name = "silverify",
		aliases = { "silver", "metalify", "metal" },
		description = "Shine bright as a silver statue!",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to turn to silver.",
			},
		},

		run = function(context, players: { Player })
			for index: number, player: Player in players do
				if player.Character and player.Character.PrimaryPart then
					context._K.Registry.commands.crm.env.update(
						player.Character,
						BrickColor.new("Silver").Color,
						0.4,
						Enum.Material.Metal
					)
				end
			end
		end,
	},
	{
		name = "ungoldify",
		aliases = { "ungold", "unsilverify", "unsilver", "unmetalify", "unmetal" },
		description = "Restores the character of one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to restore.",
			},
		},
		run = function(context, players: { Player })
			for index: number, player: Player in players do
				if player.Character and player.Character.PrimaryPart then
					context._K.Registry.commands.crm.env.update(player.Character)
				end
			end
		end,
	},
	{
		name = "swagify",
		aliases = { "swag" },
		description = "Makes one or more player(s) swaggy. 😎",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to swagify.",
			},
		},
		run = function(context, players: { Player })
			for index: number, player: Player in players do
				if player.Character and player.Character.PrimaryPart then
					local shirt = player.Character:FindFirstChildOfClass("Shirt")
					if not shirt then
						shirt = Instance.new("Shirt")
						shirt.Parent = player.Character
					end
					if not player.Character:GetAttribute("_KShirt") then
						player.Character:SetAttribute("_KShirt", shirt.ShirtTemplate)
					end
					shirt.ShirtTemplate = "rbxassetid://109163376"

					local pants = player.Character:FindFirstChildOfClass("Pants")
					if not pants then
						pants = Instance.new("Pants")
						pants.Parent = player.Character
					end
					if not player.Character:GetAttribute("_KPants") then
						player.Character:SetAttribute("_KPants", pants.PantsTemplate)
					end
					pants.PantsTemplate = "rbxassetid://109163376"

					context._K.Registry.commands.cape.env.add(
						player.Character,
						Color3.new(1, 0, 1),
						nil,
						nil,
						"rbxassetid://109301474"
					)
				end
			end
		end,
	},
	{
		name = "unswagify",
		aliases = { "unswag" },
		description = "Removes swag from one or more player(s). 👎",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to remove swag from.",
			},
		},
		run = function(context, players: { Player })
			for index: number, player: Player in players do
				if player.Character and player.Character.PrimaryPart then
					local existing = player.Character and player.Character:FindFirstChild("_KCape")
					if existing then
						existing:Destroy()
					end
					local shirt = player.Character:FindFirstChildOfClass("Shirt")
					if shirt then
						shirt.ShirtTemplate = player.Character:GetAttribute("_KShirt") or shirt.ShirtTemplate
					end
					local pants = player.Character:FindFirstChildOfClass("Pants")
					if pants then
						pants.PantsTemplate = player.Character:GetAttribute("_KPants") or pants.PantsTemplate
					end
				end
			end
		end,
	},
	{
		name = "wingscolor",
		description = "Changes the VIP wings color.",
		args = {
			{
				type = "color",
				name = "Wings Color",
				description = "The color of the wings.",
				optional = true,
			},
		},

		runClient = function(context)
			if (context.fromPlayer:GetAttribute("_KDonationLevel") or 0) < 3 then
				context._K.promptPurchaseVIP(true)
				return
			end
		end,
		run = function(context, wingsColor: Color3?)
			if (context.fromPlayer:GetAttribute("_KDonationLevel") or 0) < 3 then
				return
			end
			if not context.fromPlayer.Character then
				return "You have no character!"
			end
			local wings = context.fromPlayer.Character:FindFirstChild("_KAlphaWings")
			if not wings then
				return "You don't have VIP wings equipped!"
			end
			wingsColor = wingsColor or wings:GetAttribute("_KWingsColor")
			task.defer(function()
				wings.Wings.Color = wingsColor
			end)
			return
		end,
	},
	{
		name = "rainbowwings",
		aliases = { "wingsrainbow" },
		description = "Toggles the VIP wings rainbow.",
		runClient = function(context)
			if (context.fromPlayer:GetAttribute("_KDonationLevel") or 0) < 3 then
				context._K.promptPurchaseVIP(true)
				return
			end
		end,
		run = function(context)
			if (context.fromPlayer:GetAttribute("_KDonationLevel") or 0) < 3 then
				return
			end
			if not context.fromPlayer.Character then
				return "You have no character!"
			end
			local wings = context.fromPlayer.Character:FindFirstChild("_KAlphaWings")
			if not wings then
				return "You don't have VIP wings equipped!"
			end
			if wings:HasTag("_KAlphaWingsRainbow") then
				wings:RemoveTag("_KAlphaWingsRainbow")
				task.defer(function()
					wings.Wings.Color = wings:GetAttribute("_KWingsColor") or Color3.new(1, 1, 1)
				end)
			else
				wings:AddTag("_KAlphaWingsRainbow")
			end
			return
		end,
	},
	{
		name = "crowncolor",
		description = "Changes the VIP crown color.",
		args = {
			{
				type = "color",
				name = "Crown Color",
				description = "The color of the crown.",
				optional = true,
			},
			{
				type = "color",
				name = "Fire Color",
				description = "The color of the crown's fire.",
				optional = true,
			},
		},

		runClient = function(context)
			if (context.fromPlayer:GetAttribute("_KDonationLevel") or 0) < 2 then
				context._K.promptPurchaseVIP(true)
				return
			end
		end,
		run = function(context, crownColor: Color3?, fireColor: Color3?)
			if (context.fromPlayer:GetAttribute("_KDonationLevel") or 0) < 2 then
				return
			end
			if not context.fromPlayer.Character then
				return "You have no character!"
			end
			local crown = context.fromPlayer.Character:FindFirstChild("SuperCrown")
			if not crown then
				return "You don't have a VIP crown equipped!"
			end
			crownColor = crownColor or crown:GetAttribute("_KCrownColor")
			fireColor = fireColor or crown:GetAttribute("_KCrownFireColor")
			crown:RemoveTag("_KSuperCrownRainbow")
			task.defer(function()
				crown.Handle.Color = crownColor
				crown.Handle.Fire.Color = fireColor
				crown.Handle.Fire.SecondaryColor = crownColor
			end)
			return
		end,
	},
	{
		name = "rainbowcrown",
		aliases = { "crownrainbow" },
		description = "Toggles the VIP crown rainbow.",
		runClient = function(context)
			if (context.fromPlayer:GetAttribute("_KDonationLevel") or 0) < 3 then
				context._K.promptPurchaseVIP(true)
				return
			end
		end,
		run = function(context)
			if (context.fromPlayer:GetAttribute("_KDonationLevel") or 0) < 3 then
				return
			end
			if not context.fromPlayer.Character then
				return "You have no character!"
			end
			local crown = context.fromPlayer.Character:FindFirstChild("SuperCrown")
			if not crown then
				return "You don't have a VIP crown equipped!"
			end
			if crown:HasTag("_KSuperCrownRainbow") then
				crown:RemoveTag("_KSuperCrownRainbow")
				task.defer(function()
					local primary = crown:GetAttribute("_KCrownColor") or Color3.new(1, 1, 1)
					local secondary = crown:GetAttribute("_KCrownFireColor") or Color3.new()
					crown.Handle.Color = primary
					crown.Handle.Fire.Color = secondary
					crown.Handle.Fire.SecondaryColor = primary
				end)
			else
				crown:AddTag("_KSuperCrownRainbow")
			end
			return
		end,
	},
}
