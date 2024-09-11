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
		aliases = { "setgrav", "nograv", "ungravity", "ungrav", "resetgravity", "resetgrav" },
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
			local aliasUsed = string.lower(context.array[1][2])
			if aliasUsed == "nograv" then
				strength = -1
			elseif table.find(context.env.resetAlias, aliasUsed) then
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
