-- non abusive fun commands given to VIP role by default

return {
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
				local root = player.Character and player.Character.PrimaryPart
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
				local root = player.Character and player.Character.PrimaryPart
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
}
