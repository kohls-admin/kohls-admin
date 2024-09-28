-- potentially abusive fun commands, moderator+ default

local function resizeCharacter(char, scale)
	local human = char and char:FindFirstChildOfClass("Humanoid")
	if not human then
		return
	end

	local diff = scale / (char:GetAttribute("_KCharacterScale") or 1)
	local hipHeight = human.HipHeight + human.RootPart.Size.Y / 2

	if human.RigType == Enum.HumanoidRigType.R15 then
		for _, v in human:GetChildren() do
			if v:IsA("NumberValue") and string.find(v.Name, "Scale") then
				local base = v:GetAttribute("_KOriginalScale")
				if not base then
					base = v.Value
					v:SetAttribute("_KOriginalScale", base)
				end
				v.Value = base * scale
			end
		end
	elseif human.RigType == Enum.HumanoidRigType.R6 then
		hipHeight = human.RootPart.Size.Y * 1.5
		for _, v in char:GetDescendants() do
			if v:IsA("BasePart") then
				v.Size *= diff
			elseif v:IsA("JointInstance") then
				v.C0 -= v.C0.Position * (1 - diff)
				v.C1 -= v.C1.Position * (1 - diff)
			elseif v:IsA("SpecialMesh") and v.MeshType == Enum.MeshType.FileMesh then
				v.Scale *= diff
			end
		end
	end
	-- reposition rootpart to prevent falling
	human.RootPart.CFrame *= CFrame.new(0, hipHeight * (diff - 1), 0)
	char:SetAttribute("_KCharacterScale", scale)
end

return {
	{
		name = "disco",
		aliases = {},
		description = "It's time to party! 🎉",
		args = {},
		env = function(_K)
			_K.Flux.Scope.discoRestore = false
			_K.Flux.Scope.discoCleanup = function()
				if _K.Flux.Scope.discoRestore then
					_K.Util.Services.Lighting.Ambient, _K.Util.Services.Lighting.FogColor =
						unpack(_K.Flux.Scope.discoRestore)
					_K.Flux.Scope.discoRestore = nil
				end
				_K.Flux.Scope.discoId = nil
			end
		end,

		run = function(context)
			if not context._K.Flux.Scope.discoRestore then
				context._K.Flux.Scope.discoRestore =
					{ context._K.Util.Services.Lighting.Ambient, context._K.Util.Services.Lighting.FogColor }
			end

			local t = time()
			context._K.Flux.Scope.discoId = t
			task.spawn(function()
				repeat
					local color = Color3.fromHSV((time() - t) % 1, 1, 1)
					context._K.Util.Services.Lighting.Ambient = color
					context._K.Util.Services.Lighting.FogColor = color
					task.wait(math.pi / 10)
				until context._K.Flux.Scope.discoId ~= t
			end)
		end,
	},
	{
		name = "undisco",
		aliases = {},
		description = "Stop the party! ✋",
		args = {},

		run = function(context)
			context._K.Flux.Scope.discoCleanup()
		end,
	},

	{
		name = "dog",
		aliases = { "horse" },
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

					local root = character:FindFirstChild("LowerTorso") and character:FindFirstChild("Root", true)
					local neck = character:FindFirstChild("Neck", true)
					local waist = character:FindFirstChild("Waist", true)
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
						return
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
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) whose character to change.",
				shouldRequest = true,
			},
			{
				type = "integer",
				name = "UserId",
				description = "The UserId of the player to use.",
				optional = true,
			},
		},

		run = function(context, players, userId)
			for _, player in players do
				player.CharacterAppearanceId = if userId == nil then player.UserId else userId
				player:LoadCharacter()
			end
		end,
	},
	{
		name = "unchar",
		aliases = { "uncharacter" },
		description = "Restores the character of one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) whose character to restore.",
			},
		},

		run = function(context, players, userId)
			for _, player in players do
				if player.CharacterAppearanceId == player.UserId then
					continue
				end
				player.CharacterAppearanceId = player.UserId
				player:LoadCharacter()
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
					table.insert(context._K.cleanupCommands, clone)
					clone.Parent = workspace
					clone:MoveTo(player.Character:GetPivot().Position)
					table.insert(context._K.cleanupCommands, clone)
				end
			end
		end,
	},
	{
		name = "control",
		aliases = { "release", "uncontrol" },
		description = "Controls the character of a player.",
		args = {
			{
				type = "player",
				name = "Player",
				description = "The player to control or release.",
				shouldRequest = true,
				ignoreSelf = true,
				optional = true,
			},
		},
		env = function(_K)
			return {
				control = function(controller, target)
					if not target.Character then
						return
					end
					for _, descendant in target.Character:GetDescendants() do
						if descendant:IsA("BasePart") then
							descendant:SetNetworkOwner(controller)
						end
					end

					local oldCharacter = controller.Character
					local oldParent = oldCharacter.Parent
					oldCharacter.Parent = nil
					controller.Character = target.Character
					oldCharacter.Parent = oldParent

					if not controller:FindFirstChild("_KControlOriginal") then
						_K.Flux.new "ObjectValue" {
							Name = "_KControlOriginal",
							Value = oldCharacter,
							Parent = controller,
						}
					end

					if not target.Character:FindFirstChild("_KOriginalController") then
						_K.Flux.new "ObjectValue" {
							Name = "_KOriginalController",
							Value = target,
							Parent = target.Character,
						}
					end
				end,
				reset = function(controller)
					local original = controller:FindFirstChild("_KControlOriginal")
					if original then
						local character = original.Value
						for _, descendant in character:GetDescendants() do
							if descendant:IsA("BasePart") then
								descendant:SetNetworkOwner(controller)
							end
						end
						controller.Character = character
					end
				end,
				release = function(controller)
					local character = controller.Character
					local original = character:FindFirstChild("_KOriginalController")
					if original then
						local player = original.Value
						if player == controller then
							return -- don't release self
						end

						for _, descendant in character:GetDescendants() do
							if descendant:IsA("BasePart") then
								descendant:SetNetworkOwner(player)
							end
						end

						local oldParent = character.Parent
						character.Parent = nil
						controller.Character = nil
						character.Parent = oldParent
						player.Character = character
					end
				end,
			}
		end,

		runClient = function(context, player)
			if player and context.alias ~= "uncontrol" and context.alias ~= "release" then
				workspace.CurrentCamera.CameraSubject = player.Character
			else -- release control
				local original = context.fromPlayer:FindFirstChild("_KControlOriginal")
				if original then
					local character = original.Value
					workspace.CurrentCamera.CameraSubject = character
					context.fromPlayer.CharacterAdded:Wait()
					local function reactivate(script)
						script.Enabled = true
					end
					for _, descendant in character:GetDescendants() do
						if descendant:IsA("LocalScript") and descendant.Enabled then
							descendant.Enabled = false
							task.defer(reactivate, descendant)
						end
					end
				end
			end
		end,
		run = function(context, player)
			context.env.release(context.fromPlayer)
			if not player or context.alias == "uncontrol" or context.alias == "release" then
				context.env.reset(context.fromPlayer)
				return
			end
			context.env.control(context.fromPlayer, player)
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
					player.Character:BreakJoints()
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
				Volume = 2,
			}
			local sphere
			task.defer(function()
				sphere = _K.Util.Services.InsertService:CreateMeshPartAsync(
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

				character:BreakJoints()
				local explosion = Instance.new("Explosion")
				explosion.ExplosionType = Enum.ExplosionType.NoCraters
				explosion.Position = position
				explosion.DestroyJointRadiusPercent = 0
				explosion.Parent = character
			end

			return {
				explode = explode,
				nuke = function(fromRank, position)
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
						alpha = _K.Util.Services.TweenService:GetValue(
							1 - (1 - math.clamp((tick() + 1 - start) / 8, 0, 1)) ^ 2,
							Enum.EasingStyle.Bounce,
							Enum.EasingDirection.In
						)
						local distance = alpha * 512
						part.Size = Vector3.one * distance
						part2.Size = part.Size * 0.9
						part3.Size = part.Size * 0.5
						for _, player in _K.Util.Services.Players:GetPlayers() do
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
						alpha = _K.Util.Services.TweenService:GetValue(
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
		run = function(context, players, distance)
			for _, player in players do
				if player.Character then
					local position = player.Character:GetPivot().Position
					context.env.explode(player.Character, position)
					task.spawn(context.env.nuke, context.fromRank, position)
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

		run = function(context, players, strength)
			strength = strength or 1
			local angularStrength = strength * 10

			for _, player in players do
				if player.Character and player.Character.PrimaryPart then
					player.Character:PivotTo(player.Character:GetPivot() * CFrame.Angles(math.pi, 0, 0))

					local direction = CFrame.Angles(0, math.random() * math.pi * 2, 0).LookVector
					player.Character.PrimaryPart.AssemblyLinearVelocity = direction
							* math.random(strength * 160, strength * 200)
						+ Vector3.new(0, math.random(strength * 160, strength * 200), 0)

					player.Character.PrimaryPart.AssemblyAngularVelocity = Vector3.new(
						math.random(-angularStrength, angularStrength),
						math.random(-angularStrength, angularStrength),
						math.random(-angularStrength, angularStrength)
					)
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
				local character = _K.UI.LocalPlayer.Character
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
		aliases = {},
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
		aliases = { "resize", "scale" },
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
				resizeCharacter(player.Character, math.clamp(scale or 1, 0.2, 10))
			end
		end,
	},
	{
		name = "unsize",
		aliases = { "unresize", "unscale" },
		description = "Resets the size of one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) whose size to reset.",
				shouldRequest = true,
			},
		},

		run = function(context, players)
			for _, player in players do
				if player.Character and player.Character:GetAttribute("_KCharacterScale") then
					resizeCharacter(player.Character, 1)
				end
			end
		end,
	},
}
