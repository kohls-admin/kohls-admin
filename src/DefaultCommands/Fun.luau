-- potentially abusive fun commands, moderator+ default

return {
	{
		name = "disco",
		aliases = { "🪩", "un🪩", "undisco" },
		description = "It's time to party! 🎉",
		env = function(_K)
			local env = { id = false, restore = false }
			function env.cleanup()
				if env.restore then
					_K.Service.Lighting.Ambient, _K.Service.Lighting.FogColor = unpack(env.restore)
					env.restore = false
				end
				env.id = false
			end
			return env
		end,

		run = function(context)
			if context.undo then
				return context.env.cleanup()
			end

			if not context.env.restore then
				context.env.restore = { context._K.Service.Lighting.Ambient, context._K.Service.Lighting.FogColor }
			end

			local t = time()
			context.env.id = t
			task.spawn(function()
				repeat
					local color = Color3.fromHSV((time() - t) % 1, 1, 1)
					context._K.Service.Lighting.Ambient = color
					context._K.Service.Lighting.FogColor = color
					task.wait(math.pi / 10)
				until context.env.id ~= t
			end)
			return
		end,
	},
	{
		name = "dog",
		aliases = { "🐶", "🐎", "horse" },
		description = "Turns one or more player(s) into dog",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to turn into a dog.",
				shouldRequest = true,
			},
		},
		env = function(_K)
			return {
				R6 = function(character)
					if not (character and character.PrimaryPart) then
						return
					end

					local torso = character:FindFirstChild("Torso")
					if not torso then
						return
					end

					torso.Transparency = 1

					local neck = torso:FindFirstChild("Neck")
					local rightShoulder = torso:FindFirstChild("Right Shoulder")
					local leftShoulder = torso:FindFirstChild("Left Shoulder")
					local rightHip = torso:FindFirstChild("Right Hip")
					local leftHip = torso:FindFirstChild("Left Hip")

					if neck then
						neck.C0 = CFrame.new(0, -0.5, -2) * CFrame.Angles(math.rad(90), math.rad(180), 0)
					end
					if rightShoulder then
						rightShoulder.C0 = CFrame.new(0.5, -1.5, -1.5) * CFrame.Angles(0, math.pi / 2, 0)
					end
					if leftShoulder then
						leftShoulder.C0 = CFrame.new(-0.5, -1.5, -1.5) * CFrame.Angles(0, -math.pi / 2, 0)
					end
					if rightHip then
						rightHip.C0 = CFrame.new(1.5, -1, 1.5) * CFrame.Angles(0, math.pi / 2, 0)
					end
					if leftHip then
						leftHip.C0 = CFrame.new(-1.5, -1, 1.5) * CFrame.Angles(0, -math.pi / 2, 0)
					end

					local seat = _K.Flux.new "Seat" {
						Name = "_KDogSeat",
						Transparency = 0,
						Color = torso.Color,
						Material = torso.Material,
						CFrame = torso.CFrame,
						CastShadow = false,
						CanQuery = false,
						CanCollide = false,
						Massless = true,
						Size = Vector3.new(3, 1, 4),
						TopSurface = 0,
						BottomSurface = 0,
					}

					_K.Flux.new "Weld" {
						Parent = seat,
						Part0 = torso,
						Part1 = seat,
						C1 = CFrame.new(0, 0.5, 0),
					}

					seat.Parent = character
				end,
				R15 = function(character)
					if not (character and character.PrimaryPart) then
						return
					end

					local torso = character:FindFirstChild("UpperTorso")
					if not torso then
						return
					end

					local root = character:FindFirstChild("LowerTorso") and character.LowerTorso:FindFirstChild("Root")
					local neck = character:FindFirstChild("Head") and character.Head:FindFirstChild("Neck")
					local waist = character:FindFirstChild("UpperTorso")
						and character.UpperTorso:FindFirstChild("Waist")
					local rightShoulder = character:FindFirstChild("RightShoulder", true)
					local leftShoulder = character:FindFirstChild("LeftShoulder", true)
					local rightHip = character:FindFirstChild("RightHip", true)
					local leftHip = character:FindFirstChild("LeftHip", true)

					if root then
						root.C0 *= CFrame.Angles(-math.rad(60), 0, 0) - Vector3.new(0, 0.5, 0)
					end
					if waist then
						waist.C0 *= CFrame.Angles(-math.rad(30), 0, 0)
					end
					if neck then
						neck.C0 *= CFrame.Angles(math.pi / 2, 0, 0)
					end
					if rightShoulder then
						rightShoulder.C0 *= CFrame.Angles(math.pi / 4, 0, 0)
					end
					if leftShoulder then
						leftShoulder.C0 *= CFrame.Angles(math.pi / 4, 0, 0)
					end
					if rightHip then
						rightHip.C0 *= CFrame.Angles(-math.pi / 4, 0, 0)
					end
					if leftHip then
						leftHip.C0 *= CFrame.Angles(-math.pi / 4, 0, 0)
					end

					local seat = _K.Flux.new "Seat" {
						Name = "_KDogSeat",
						Transparency = 1,
						CastShadow = false,
						CanQuery = false,
						CanCollide = false,
						Massless = true,
						Size = Vector3.new(2, 1, 2),
						CFrame = torso.CFrame,
					}

					_K.Flux.new "Weld" {
						Parent = seat,
						Part0 = torso,
						Part1 = seat,
						C1 = CFrame.new(0, 0.1, -0.7) * CFrame.Angles(-math.pi / 2, 0, 0),
					}

					seat.Parent = character
				end,
			}
		end,

		run = function(context, players)
			for _, player in players do
				if
					player.Character
					and player.Character.PrimaryPart
					and player.Character:FindFirstChild("Humanoid")
					and not player.Character:FindFirstChild("_KDogSeat")
				then
					local humanoid = player.Character:FindFirstChild("Humanoid")
					if not humanoid then
						continue
					end

					if humanoid.RigType == Enum.HumanoidRigType.R6 then
						context.env.R6(player.Character)
					else
						context.env.R15(player.Character)
					end
				end
			end
		end,
	},
	{
		name = "undog",
		aliases = { "un🐶", "un🐎", "unhorse" },
		description = "Reverts one or more player(s) from dog",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to revert dog from.",
				shouldRequest = true,
			},
		},
		env = function(_K)
			return {
				R6 = function(character)
					if not (character and character.PrimaryPart) then
						return
					end

					local torso = character:FindFirstChild("Torso")
					if not torso then
						return
					end

					torso.Transparency = 0

					local neck = torso:FindFirstChild("Neck")
					local rightShoulder = torso:FindFirstChild("Right Shoulder")
					local leftShoulder = torso:FindFirstChild("Left Shoulder")
					local rightHip = torso:FindFirstChild("Right Hip")
					local leftHip = torso:FindFirstChild("Left Hip")

					if neck then
						neck.C0 = CFrame.new(0, 1, 0) * CFrame.Angles(math.rad(90), math.rad(180), 0)
					end
					if rightShoulder then
						rightShoulder.C0 = CFrame.new(1, 0.5, 0) * CFrame.Angles(0, math.rad(90), 0)
					end
					if leftShoulder then
						leftShoulder.C0 = CFrame.new(-1, 0.5, 0) * CFrame.Angles(0, math.rad(-90), 0)
					end
					if rightHip then
						rightHip.C0 = CFrame.new(1, -1, 0) * CFrame.Angles(0, math.rad(90), 0)
					end
					if leftHip then
						leftHip.C0 = CFrame.new(-1, -1, 0) * CFrame.Angles(0, math.rad(-90), 0)
					end
				end,
				R15 = function(character)
					if not (character and character.PrimaryPart) then
						return
					end

					local torso = character:FindFirstChild("UpperTorso")
					if not torso then
						return
					end

					local root = character:FindFirstChild("LowerTorso") and character.LowerTorso:FindFirstChild("Root")
					local neck = character:FindFirstChild("Head") and character.Head:FindFirstChild("Neck")
					local waist = character:FindFirstChild("UpperTorso")
						and character.UpperTorso:FindFirstChild("Waist")
					local rightShoulder = character:FindFirstChild("RightShoulder", true)
					local leftShoulder = character:FindFirstChild("LeftShoulder", true)
					local rightHip = character:FindFirstChild("RightHip", true)
					local leftHip = character:FindFirstChild("LeftHip", true)

					if root then
						root.C0 *= CFrame.Angles(math.rad(60), 0, 0) + Vector3.new(0, 0.5, 0)
					end
					if waist then
						waist.C0 *= CFrame.Angles(math.rad(30), 0, 0)
					end
					if neck then
						neck.C0 *= CFrame.Angles(-math.pi / 2, 0, 0)
					end
					if rightShoulder then
						rightShoulder.C0 *= CFrame.Angles(-math.pi / 4, 0, 0)
					end
					if leftShoulder then
						leftShoulder.C0 *= CFrame.Angles(-math.pi / 4, 0, 0)
					end
					if rightHip then
						rightHip.C0 *= CFrame.Angles(math.pi / 4, 0, 0)
					end
					if leftHip then
						leftHip.C0 *= CFrame.Angles(math.pi / 4, 0, 0)
					end
				end,
			}
		end,

		run = function(context, players, userId)
			for _, player in players do
				if not player.Character then
					continue
				end
				local seat = player.Character:FindFirstChild("_KDogSeat")
				if seat then
					seat:Destroy()
					local humanoid = player.Character:FindFirstChild("Humanoid")
					if not humanoid then
						continue
					end
					if humanoid.RigType == Enum.HumanoidRigType.R6 then
						context.env.R6(player.Character)
					else
						context.env.R15(player.Character)
					end
				end
			end
		end,
	},
	{
		name = "char",
		aliases = { "character" },
		description = "Changes the character of one or more player(s).",
		credit = { "Kohl @Scripth", "@AlanDev09" },
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) whose character to change.",
				shouldRequest = true,
			},
			{
				type = "userId",
				name = "UserId",
				description = "The identifier of the Roblox user.",
				optional = true,
			},
		},
		run = function(context, players, userId)
			local appearance = context._K.Service.Players:GetHumanoidDescriptionFromUserId(userId)
			if not appearance then
				return "Invalid character appearance!"
			end
			for _, player in players do
				player.CharacterAppearanceId = if userId == nil then player.UserId else userId
				local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
				if not humanoid then
					continue
				end
				task.spawn(humanoid.ApplyDescription, humanoid, appearance)
			end
			return
		end,
	},
	{
		name = "unchar",
		aliases = { "uncharacter" },
		description = "Restores the character of one or more player(s).",
		credit = { "Kohl @Scripth", "@AlanDev09" },
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) whose character to restore.",
			},
		},
		env = function(_K)
			return {
				apply = function(player, humanoid)
					local appearance = _K.Service.Players:GetHumanoidDescriptionFromUserId(player.UserId)
					if appearance then
						humanoid:ApplyDescription(appearance)
					end
				end,
			}
		end,
		run = function(context, players)
			for _, player in players do
				if player.CharacterAppearanceId == player.UserId then
					continue
				end
				player.CharacterAppearanceId = player.UserId
				local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
				if not humanoid then
					continue
				end
				task.spawn(context.env.apply, player, humanoid)
			end
		end,
	},
	{
		name = "clone",
		aliases = {},
		description = "Clones the character of one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) whose character to clone.",
			},
		},

		run = function(context, players, userId)
			for _, player in players do
				if player.Character then
					player.Character.Archivable = true
					local clone = player.Character:Clone()
					player.Character.Archivable = false
					clone.Name ..= "Clone"
					clone.Parent = workspace
					table.insert(context._K.cleanupCommands, clone)
					clone:MoveTo(player.Character:GetPivot().Position)
				end
			end
		end,
	},
	{
		name = "control",
		aliases = { "takeover" },
		description = "Controls the character of a player.",
		args = {
			{
				type = "player",
				name = "Player",
				description = "The player to control.",
				shouldRequest = true,
				ignoreSelf = true,
			},
		},
		envClient = function(_K)
			_K.Remote.ControlCommand.OnClientEvent:Connect(function(target: Humanoid | Model)
				if target then
					workspace.CurrentCamera.CameraSubject = target
				end
			end)
		end,
		env = function(_K)
			return {
				connections = {},
				remote = _K.Remote.ControlCommand,
			}
		end,
		run = function(context, player: Player)
			local character = player and player.Character
			if not character then
				return `{player} doesn't have a character!`
			end
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if not humanoid then
				return `{player} doesn't have a humanoid!`
			end

			context.fromPlayer.Character = character
			context.env.remote:FireClient(context.fromPlayer, humanoid)
			context.env.remote:FireClient(player, humanoid)

			for _, descendant in character:GetDescendants() do
				if descendant:IsA("BasePart") and descendant:CanSetNetworkOwnership() then
					descendant:SetNetworkOwner(context.fromPlayer)
				end
			end

			if not context.env.connections[player] then
				context.env.connections[player] = context.fromPlayer
					:GetPropertyChangedSignal("Character")
					:Connect(function()
						print("character removing", humanoid.Health)
						context.env.connections[player]:Disconnect()
						context.env.connections[player] = nil
						if humanoid and humanoid.Health > 0 then
							local old = character:GetPivot()
							player:LoadCharacter()
							local newCharacter = player.Character
							newCharacter:PivotTo(old)
							context._K.Remote.Refresh:FireClient(player)
						end
					end)
			end

			return
		end,
	},
	{
		name = "infect",
		aliases = { "zombie" },
		description = "Infects of one or more player(s), starting a zombie outbreak!",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to infect.",
				shouldRequest = true,
			},
		},
		env = function(_K)
			local env = { infected = {} }

			function env.infect(player, character)
				if not character then
					return
				end
				local humanoid = character:FindFirstChildOfClass("Humanoid")
				if not humanoid then
					return
				end

				local face = character:FindFirstChild("Head") and character.Head:FindFirstChild("face")
				if face then
					if not face:GetAttribute("_KInfectOriginal") then
						face:SetAttribute("_KInfectOriginal", face.Texture)
					end
					face.Texture = "rbxassetid://629946036"
				end

				local colors = character:FindFirstChildOfClass("BodyColors")
				if colors then
					colors.HeadColor3 = Color3.fromRGB(50, 100, 50)
					colors.LeftArmColor3 = Color3.fromRGB(50, 100, 50)
					colors.RightArmColor3 = Color3.fromRGB(50, 100, 50)
					colors.TorsoColor3 = Color3.fromRGB(100, 50, 20)
					colors.LeftLegColor3 = Color3.fromRGB(100, 50, 20)
					colors.RightLegColor3 = Color3.fromRGB(100, 50, 20)
				end

				local shirt = character:FindFirstChildOfClass("Shirt")
				if shirt then
					shirt:Destroy()
				end

				local pants = character:FindFirstChildOfClass("Pants")
				if pants then
					pants:Destroy()
				end

				_K.Flux
					.new "Sound" {
					Parent = character.PrimaryPart,
					PlayOnRemove = true,
					SoundId = "rbxassetid://9114030073",
				}
					:Destroy()

				env.infected[character] = humanoid.Touched:Connect(function(part)
					if not part or not part.Parent or env.infected[part.Parent] then
						return
					end

					local player = _K.Service.Players:GetPlayerFromCharacter(part.Parent)
					if not player then
						return
					end

					env.infect(player, part.Parent)
				end)
			end

			return env
		end,

		run = function(context, players)
			for _, player in players do
				context.env.infect(player, player.Character)
			end
		end,
	},

	{
		name = "explode",
		aliases = { "boom", "💥" },
		description = "Explodes one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to explode.",
				shouldRequest = true,
			},
		},
		run = function(context, players, distance)
			for _, player in players do
				if player.Character then
					local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
					if not humanoid then
						continue
					end

					humanoid.MaxHealth = math.max(1, humanoid.MaxHealth)
					humanoid.Health = 0

					local explosion = Instance.new("Explosion")
					explosion.ExplosionType = Enum.ExplosionType.NoCraters
					explosion.Position = player.Character:GetPivot().Position
					explosion.DestroyJointRadiusPercent = 0
					explosion.Parent = player.Character
				end
			end
		end,
	},
	{
		name = "nuke",
		aliases = {},
		description = "Nuke one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to nuke.",
				shouldRequest = true,
			},
		},
		env = function(_K)
			local boomSound = _K.Flux.new "Sound" {
				SoundId = "rbxassetid://9114224354",
				EmitterSize = 512,
				Volume = 1,
			}
			local sphere
			task.defer(function()
				sphere = _K.Service.Insert:CreateMeshPartAsync(
					"rbxassetid://116325731356319",
					Enum.CollisionFidelity.Box,
					Enum.RenderFidelity.Precise
				)
				_K.Flux.edit(sphere, {
					Name = "Sphere",
					Color = Color3.new(1, 0, 0),
					Material = Enum.Material.Neon,
					Transparency = 0.75,
					Anchored = true,
					EnableFluidForces = false,
					CastShadow = false,
					CanCollide = false,
					CanTouch = false,
					CanQuery = false,
					Massless = true,
					Size = Vector3.zero,
				})
			end)

			local function explode(character, position)
				if character:GetAttribute("_KNuked") then
					return
				end
				character:SetAttribute("_KNuked", true)

				local explosion = Instance.new("Explosion")
				explosion.ExplosionType = Enum.ExplosionType.NoCraters
				explosion.Position = position
				explosion.DestroyJointRadiusPercent = 0
				explosion.Parent = character

				local humanoid = character:FindFirstChildOfClass("Humanoid")
				if not humanoid then
					return
				end

				humanoid.MaxHealth = math.max(1, humanoid.MaxHealth)
				humanoid.Health = 0
			end

			return {
				explode = explode,
				nuke = function(from: Player, fromRank, position)
					local part = sphere:Clone()
					part.Position = position

					local part2 = sphere:Clone()
					part2.Color = Color3.new(1, 1, 0)
					part2.Position = position + Vector3.new(0, 0.1, 0)
					part2.Parent = part

					local part3 = sphere:Clone()
					part3.Color = Color3.new(1, 1, 1)
					part3.Position = position - Vector3.new(0, 0.1, 0)
					part3.Parent = part

					part.Parent = workspace

					local sound = boomSound:Clone()
					sound.Parent = part
					sound:Play()
					task.delay(2, function()
						local sound = boomSound:Clone()
						sound.Volume = 1
						sound.Parent = part
						sound:Play()
					end)

					local start, alpha = tick(), 0
					repeat
						alpha = _K.Service.Tween:GetValue(
							1 - (1 - math.clamp((tick() + 1 - start) / 8, 0, 1)) ^ 2,
							Enum.EasingStyle.Bounce,
							Enum.EasingDirection.In
						)
						local distance = alpha * 512
						part.Size = Vector3.one * distance
						part2.Size = part.Size * 0.9
						part3.Size = part.Size * 0.5
						for _, player in _K.Service.Players:GetPlayers() do
							if from.UserId ~= _K.creatorId and _K.Auth.getRank(player.UserId) >= fromRank then
								continue
							end
							local direction = (player.Character and not player.Character:GetAttribute("_KNuked"))
								and position - player.Character:GetPivot().Position
							if direction and direction.Magnitude <= distance / 2 then
								explode(player.Character, player.Character:GetPivot().Position + direction.unit)
							end
						end
						task.wait()
					until alpha == 1

					start, alpha = tick(), 0
					repeat
						alpha = _K.Service.Tween:GetValue(
							math.clamp((tick() - start) / 1, 0, 1),
							Enum.EasingStyle.Cubic,
							Enum.EasingDirection.In
						)
						local distance = 512 - 512 * alpha
						part.Transparency = 0.75 + 0.25 * alpha
						part2.Transparency = part.Transparency
						part3.Transparency = part.Transparency
						part.Size = Vector3.one * distance
						part2.Size = part.Size * 0.9
						part3.Size = part.Size * 0.5
						task.wait()
					until alpha == 1

					task.wait(4)
					part:Destroy()
				end,
			}
		end,
		run = function(context, players)
			for _, player in players do
				if player.Character then
					local position = player.Character:GetPivot().Position
					context.env.explode(player.Character, position)
					task.spawn(context.env.nuke, context.fromPlayer, context.fromRank, position)
				end
			end
		end,
	},
	{
		name = "smite",
		credit = { "@Yuruzuu", "Kohl @Scripth" },
		description = "Smites one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to smite.",
				shouldRequest = true,
			},
		},
		run = function(context, players)
			for _, player in players do
				if player.Character then
					local root = player.Character:FindFirstChild("HumanoidRootPart") or player.Character.PrimaryPart
					local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
					if not (humanoid and root) then
						continue
					end

					for _, descendant in player.Character:GetDescendants() do
						if descendant:IsA("BasePart") then
							task.delay(math.random(), function()
								local effect = context._K.Flux.new "ParticleEmitter" {
									Parent = descendant,
									LockedToPart = true,
									Brightness = 4,
									Color = ColorSequence.new(Color3.new(1, 1, 0.5)),
									Transparency = NumberSequence.new(0.5),
									LightEmission = 1,
									LightInfluence = 0,
									Orientation = Enum.ParticleOrientation.FacingCamera,
									Texture = "rbxassetid://11492870634",
									ZOffset = 2,
									Lifetime = NumberRange.new(0.5, 0.75),
									Rate = 2,
									Speed = NumberRange.new(0),
									Rotation = NumberRange.new(-360, 360),
									FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4,
									FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
								}
								effect:Emit(1)
							end)
						end
					end

					local sounds = { 9116282544, 9116282647, 9116282646, 9116282791, 9116282875 }
					local sound = context._K.Flux.new "Sound" {
						Parent = workspace,
						SoundId = `rbxassetid://{sounds[math.random(4)]}`,
						PlayOnRemove = true,
						Volume = 1,
					}
					sound:Destroy()

					local hipHeight = if humanoid.RigType == Enum.HumanoidRigType.R15
						then humanoid.HipHeight + root.Size.Y / 2
						else root.Size.Y * 1.5

					task.delay(2.2, function()
						local part = context._K.Flux.new "Part" {
							Parent = workspace,
							Transparency = 0.9,
							Material = Enum.Material.Neon,
							Color = Color3.new(1, 1, 1),
							Anchored = true,
							CanCollide = false,
							CanQuery = false,
							CanTouch = false,
							CastShadow = false,
							Size = Vector3.one,
							CFrame = CFrame.new(player.Character:GetPivot().Position - Vector3.new(0, hipHeight, 0)),

							context._K.Flux.new "BlockMesh" {
								Scale = Vector3.new(2, 1e4, 2),
								Offset = Vector3.new(0, 5e3, 0),
							},
						}

						for i = 1, 4 do
							local outer = part:Clone()
							outer.Mesh.Scale = Vector3.new(2 + i, 1e4, 2 + i)
							outer.Parent = part
						end

						humanoid.MaxHealth = math.max(1, humanoid.MaxHealth)
						humanoid.Health = 0
						task.delay(0.4, part.Destroy, part)
					end)
				end
			end
		end,
	},
	{
		name = "fling",
		aliases = {},
		description = "Flings one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to fling.",
				shouldRequest = true,
			},
			{
				type = "number",
				name = "Strength",
				description = "The strength of the fling, 1 is default.",
				optional = true,
			},
		},
		env = function(_K)
			return {
				apply = function(character, strength)
					local angularStrength = strength * 10
					if character and character:FindFirstChild("HumanoidRootPart") then
						character:PivotTo(character:GetPivot() * CFrame.Angles(math.pi, 0, 0))

						local direction = CFrame.Angles(0, math.random() * math.pi * 2, 0).LookVector
						character.HumanoidRootPart.AssemblyLinearVelocity = direction
								* math.random(strength * 160, strength * 200)
							+ Vector3.new(0, math.random(strength * 160, strength * 200), 0)

						character.HumanoidRootPart.AssemblyAngularVelocity = Vector3.new(
							math.random(-angularStrength, angularStrength),
							math.random(-angularStrength, angularStrength),
							math.random(-angularStrength, angularStrength)
						)
					end
				end,
			}
		end,
		run = function(context, players: { Player }, strength: number?)
			for _, player in players do
				context.env.apply(player.Character, strength or 1)
			end
		end,
	},
	{
		name = "loopfling",
		aliases = { "unloopfling" },
		description = "Flings one or more player(s) repeatedly.",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to fling repeatedly.",
				shouldRequest = true,
			},
			{
				type = "number",
				name = "Strength",
				description = "The strength of the fling, 1 is default.",
				optional = true,
			},
		},
		env = function(_K)
			local flinging = {}
			task.spawn(function()
				repeat
					for userId, strength in flinging do
						local player = _K.Service.Players:GetPlayerByUserId(userId)
						if not (player and player.Character) then
							continue
						end
						_K.Registry.commands.fling.env.apply(player.Character, strength)
					end
					task.wait(2)
				until _K.Data.gameClosing
			end)
			return { flinging = flinging }
		end,
		run = function(context, players: { Player }, strength: number?)
			for _, player in players do
				context.env.flinging[player.UserId] = if context.undo then nil else (strength or 1)
			end
		end,
	},
	{
		name = "poison",
		description = "Damages one or more player(s) over time.",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to poison.",
				shouldRequest = true,
			},
			{
				type = "number",
				name = "Damage",
				description = "The damage to deal to their health.",
			},
			{
				type = "number",
				name = "Duration",
				description = "The duration of the poison effect in seconds, defaults to 8.",
				optional = true,
			},
		},

		env = function(_K)
			local function removeEffect(effect: Smoke)
				effect.Enabled = false
				task.wait(5)
				effect:Destroy()
			end
			return {
				apply = function(humanoid: Humanoid, damage: number, duration: number?)
					local effect = Instance.new("Smoke")
					effect.Name = "_KPoisonEffect"
					effect.Color = Color3.new(0.5, 0, 1)
					effect.Opacity = 0.1
					effect.RiseVelocity = 0
					effect.Parent = humanoid.RootPart
					task.delay(duration or 8, removeEffect, effect)
					local dealt = 0
					repeat
						local hit = math.min(damage / (duration or 8) * task.wait(0.8), damage - dealt)
						dealt += hit
						humanoid:TakeDamage(hit)
					until dealt >= damage
				end,
			}
		end,
		run = function(context, players, damage, duration)
			for _, player in players do
				local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
				if humanoid then
					task.spawn(context.env.apply, humanoid, damage, duration)
				end
			end
		end,
	},
	{
		name = "spin",
		aliases = {},
		description = "Spins one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to spin.",
				shouldRequest = true,
			},
			{
				type = "number",
				name = "Speed",
				description = "The speed of the spin, 1 is default.",
				optional = true,
			},
		},

		run = function(context, players, speed)
			speed = Vector3.new(0, 30 * (speed or 1))

			for _, player in players do
				if
					player.Character
					and player.Character.PrimaryPart
					and player.Character.PrimaryPart:FindFirstChildOfClass("Attachment")
				then
					local existing = player.Character:FindFirstChild("_KSpin")
					if existing then
						existing:Destroy()
					end

					local angular = Instance.new("AngularVelocity")
					angular.Name = "_KSpin"
					angular.Attachment0 = player.Character.PrimaryPart:FindFirstChildOfClass("Attachment")
					angular.AngularVelocity = speed
					angular.MaxTorque = math.huge
					angular.Parent = player.Character
				end
			end
		end,
	},
	{
		name = "unspin",
		aliases = {},
		description = "Stops spinning one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to stop spinning.",
			},
		},

		run = function(context, players)
			for _, player in players do
				if player.Character then
					local existing = player.Character:FindFirstChild("_KSpin")
					if existing then
						existing:Destroy()
					end
				end
			end
		end,
	},
	{
		name = "setgravity",
		aliases = { "setgrav", "grav", "nograv", "ungravity", "ungrav", "resetgravity", "resetgrav" },
		description = "Sets the gravity of one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) whose gravity to change.",
				shouldRequest = true,
			},
			{
				type = "number",
				name = "Strength",
				description = "The gravity strength, default is 1.",
				optional = true,
			},
		},
		env = function(_K)
			return { resetAlias = { "ungravity", "ungrav", "resetgravity", "resetgrav" } }
		end,

		run = function(context, players, strength)
			strength = strength or 1
			if context.alias == "nograv" then
				strength = -1
			elseif table.find(context.env.resetAlias, context.alias) then
				strength = 1
			end

			for _, player in players do
				if
					player.Character
					and player.Character.PrimaryPart
					and player.Character.PrimaryPart:FindFirstChildOfClass("Attachment")
				then
					local existing = player.Character:FindFirstChild("_KGravityForce")
					if existing then
						existing:Destroy()
					end
					if strength == 1 then
						continue
					end

					local force = Instance.new("VectorForce")
					force.Name = "_KGravityForce"
					force.ApplyAtCenterOfMass = true
					force.Attachment0 = player.Character.PrimaryPart:FindFirstChildOfClass("Attachment")
					force.RelativeTo = Enum.ActuatorRelativeTo.World
					force.Force =
						Vector3.new(0, player.Character.PrimaryPart.AssemblyMass * -strength * workspace.Gravity)
					force.Parent = player.Character
				end
			end
		end,
	},
	{
		name = "skydive",
		aliases = { "freefall" },
		description = "Sends one or more player(s) into the sky.",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to send into the sky.",
				shouldRequest = true,
			},
			{
				type = "number",
				name = "Distance",
				description = "The distance, in studs, that players are sent into the sky.",
				optional = true,
			},
		},
		run = function(context, players, distance)
			for _, player in players do
				if player.Character then
					player.Character:TranslateBy(Vector3.new(0, distance or 8e3, 0))
				end
			end
		end,
	},
	{
		name = "trip",
		aliases = {},
		description = "Trips one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to trip.",
				shouldRequest = true,
			},
		},
		envClient = function(_K)
			_K.Remote.Trip.OnClientEvent:Connect(function()
				local character = _K.LocalPlayer.Character
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				if humanoid then
					humanoid:ChangeState(Enum.HumanoidStateType.FallingDown)

					local direction = CFrame.Angles(0, math.random() * math.pi * 2, 0).LookVector
					character.PrimaryPart.AssemblyAngularVelocity = direction * 8
				end
			end)
			return true
		end,
		env = function(_K)
			return {
				remote = _K.Remote.Trip,
			}
		end,

		run = function(context, players)
			for _, player in players do
				context.env.remote:FireClient(player)
			end
		end,
	},
	{
		name = "rocket",
		aliases = { "🚀" },
		description = "Attaches a rocket to one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to attach a rocket to.",
				shouldRequest = true,
			},
		},

		run = function(context, players, speed)
			for _, player in players do
				if
					player.Character
					and player.Character.PrimaryPart
					and player.Character:FindFirstChildOfClass("Humanoid")
				then
					local existing = player.Character:FindFirstChild("_KRocket")
					if existing then
						continue
					end

					player.Character:FindFirstChildOfClass("Humanoid").Jump = true

					local attachment = Instance.new("Attachment")
					attachment.Position = Vector3.new(0, -3, 0)
					context._K.Flux.new "Fire" {
						Parent = attachment,
						Size = 2,
					}

					local rocket = context._K.Flux.new "Part" {
						Parent = player.Character,
						Name = "_KRocket",
						Size = Vector3.new(1, 6, 1),
						Anchored = false,
						CanCollide = false,
						Massless = true,
						TopSurface = 0,
						BottomSurface = 0,
						Material = Enum.Material.Metal,

						attachment,
						context._K.Flux.new "VectorForce" {
							ApplyAtCenterOfMass = true,
							RelativeTo = Enum.ActuatorRelativeTo.World,
							Force = Vector3.new(0, player.Character.PrimaryPart.AssemblyMass * workspace.Gravity + 800),
							Attachment0 = attachment,
						},
					}

					context._K.Flux.new "Weld" {
						Parent = rocket,
						Part0 = rocket,
						Part1 = player.Character.PrimaryPart,
						C1 = CFrame.new(0, 0, 1),
					}

					task.delay(5, function()
						if player.Character then
							player.Character:BreakJoints()
							rocket:Destroy()
							local explosion = Instance.new("Explosion")
							explosion.ExplosionType = Enum.ExplosionType.NoCraters
							explosion.Position = rocket.Position
							explosion.DestroyJointRadiusPercent = 0
							explosion.Parent = player.Character
						end
					end)
				end
			end
		end,
	},

	{
		name = "size",
		aliases = { "resize", "scale", "unsize", "unresize", "unscale" },
		description = "Resizes one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to resize.",
				shouldRequest = true,
			},
			{
				type = "number",
				name = "Scale",
				description = "The scale of the character, 1 is default.",
				optional = true,
			},
		},

		run = function(context, players, scale)
			for _, player in players do
				player.Character:ScaleTo(scale or 1)
			end
		end,
	},
	{
		name = "slim",
		aliases = { "unslim" },
		description = "Makes one or more player(s) slim.",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to make slim.",
				shouldRequest = true,
			},
		},
		env = function(_K)
			return {
				slim = function(object, property, undo)
					local originalValue = object:GetAttribute("_KSlimOriginal")
					if undo or not originalValue then
						object:SetAttribute("_KSlimOriginal", if undo then nil else object[property].Z)
					end
					local value = object[property]
					object[property] = Vector3.new(value.X, value.Y, if undo then originalValue or value else 0.2)
				end,
			}
		end,

		run = function(context, players)
			for _, player in players do
				local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
				if not humanoid or (context.undo and not humanoid:GetAttribute("_KSlim")) then
					continue
				end
				humanoid:SetAttribute("_KSlim", not context.undo)
				for _, object in player.Character:GetChildren() do
					if object:IsA("BasePart") then
						context.env.slim(object, "Size", context.undo)
					elseif object:IsA("Accessory") then
						local part = object:FindFirstChildWhichIsA("BasePart")
						if part then
							context.env.slim(part, "Size", context.undo)
							local mesh = part:FindFirstChildOfClass("SpecialMesh")
							if mesh then
								context.env.slim(mesh, "Scale", context.undo)
							end
						end
					end
				end
			end
		end,
	},
	{
		name = "noobify",
		aliases = { "noob" },
		description = "Turn one or more player(s) into a noob",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to transform into a noob.",
				shouldRequest = true,
			},
		},
		env = function(_K)
			local blue = BrickColor.new("Bright blue").Color
			local green = BrickColor.new("Br. yellowish green").Color
			local yellow = BrickColor.new("Bright yellow").Color

			return {
				properties = {
					HeadColor = yellow,
					LeftArmColor = yellow,
					RightArmColor = yellow,
					LeftLegColor = green,
					RightLegColor = green,
					TorsoColor = blue,
					Pants = 0,
					Shirt = 0,
					LeftArm = 0,
					RightArm = 0,
					LeftLeg = 0,
					RightLeg = 0,
					Torso = 0,
				},
			}
		end,
		run = function(context, players)
			for _, player in players do
				local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
				if humanoid then
					local description = humanoid:GetAppliedDescription()
					for k, v in context.env.properties do
						description[k] = v
					end
					task.defer(humanoid.ApplyDescription, humanoid, description, Enum.AssetTypeVerification.Always)
				end
			end
		end,
	},
	{
		name = "slippery",
		aliases = { "iceskate", "icewalk", "slide" },
		description = "Makes one or more player(s) slide when they walk",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to make slippery.",
				shouldRequest = true,
			},
		},
		envClient = function(_K)
			local thread
			_K.Remote.Slippery.OnClientEvent:Connect(function(bodyVelocity: BodyVelocity?)
				if thread then
					task.cancel(thread)
					thread = nil
				end
				if bodyVelocity then
					thread = task.spawn(function()
						while bodyVelocity and bodyVelocity.Parent do
							local velocity = (bodyVelocity.Parent :: Part).AssemblyLinearVelocity
							bodyVelocity.Velocity = Vector3.new(velocity.X, 0, velocity.Z)
							task.wait(0.1)
						end
					end)
				end
			end)
		end,
		env = function(_K)
			return {
				remote = _K.Remote.Slippery,
			}
		end,
		run = function(context, players)
			for _, player in players do
				local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				if not root then
					continue
				end

				local existing = root:FindFirstChild("_K_Slippery")
				if existing then
					existing:Destroy()
				end

				if context.undo then
					continue
				end

				context.env.remote:FireClient(
					player,
					context._K.Flux.new "BodyVelocity" {
						Name = "_K_Slippery",
						MaxForce = Vector3.new(5000, 0, 5000),
						Parent = root,
					}
				)
			end
		end,
	},
}
