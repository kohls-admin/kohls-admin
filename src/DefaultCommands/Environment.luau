-- commands relating to the game environment, lighting, workspace properties, etc

local Lighting = game:GetService("Lighting")

return {
	{
		name = "fix",
		description = "Reverts the environment to the original state.",
		env = function(_K)
			local env = {
				[workspace] = {
					"AirDensity",
					"GlobalWind",
					"Gravity",
				},
				[workspace.Terrain] = {
					"WaterColor",
					"WaterReflectance",
					"WaterTransparency",
					"WaterWaveSize",
					"WaterWaveSpeed",
				},
				[_K.Service.Lighting] = {
					"Ambient",
					"Brightness",
					"ColorShift_Bottom",
					"ColorShift_Top",
					"EnvironmentDiffuseScale",
					"EnvironmentSpecularScale",
					"ExposureCompensation",
					"GeographicLatitude",
					"GlobalShadows",
					"OutdoorAmbient",
					"ShadowColor",
					"ClockTime",
					"FogColor",
					"FogEnd",
					"FogStart",
				},
			}
			local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
			if atmosphere then
				env[atmosphere] = {
					"Density",
					"Offset",
					"Color",
					"Decay",
					"Glare",
					"Haze",
				}
			end

			for object, properties in env do
				for index = 1, #properties do
					local property = properties[index]
					properties[property] = object[property]
					properties[index] = nil
				end
			end

			return env
		end,
		run = function(context)
			local discoCommand = context._K.Registry.commands.disco
			if discoCommand then
				task.spawn(discoCommand.env.cleanup)
			end
			pcall(game.Destroy, context._K.Service.Lighting:FindFirstChild("_KSky"))
			for object, original in context.env do
				for property, originalValue in original do
					object[property] = originalValue
				end
			end
		end,
	},
	{
		name = "ambient",
		description = "Changes the color of Lighting.Ambient.",
		args = {
			{
				type = "color",
				name = "Hue",
				description = "The lighting hue applied to areas that are occluded from the sky, such as indoor areas.",
			},
		},
		run = function(context, ambient)
			Lighting.Ambient = ambient
		end,
	},
	{
		name = "outdoorambient",
		description = "Changes the color of Lighting.OutdoorAmbient.",
		args = {
			{
				type = "color",
				name = "Hue",
				description = "The lighting hue applied to outdoor areas.",
			},
		},
		run = function(context, ambient)
			Lighting.OutdoorAmbient = ambient
		end,
	},
	{
		name = "atmosphere",
		description = "Changes the values of a Ligthing.Atmosphere.",
		args = {
			{
				type = "number",
				name = "Density",
				description = "How thick the air is, making it harder to see through.",
			},
			{
				type = "number",
				name = "Offset",
				description = "Affects how the sky and distant objects blend. Higher values create a horizon line; lower values create a seamless sky.",
				optional = true,
			},
			{
				type = "color",
				name = "Color",
				description = "The color of the sky. Combine with Haze for a more visible effect.",
				optional = true,
			},
			{
				type = "color",
				name = "DecayColor",
				description = "The color of the sky far from the sun. Requires Glare and Haze for a visible effect.",
				optional = true,
			},
			{
				type = "number",
				name = "Glare",
				description = "How much the sun glows. Higher values create stronger sunlight effects. Requires Haze for a visible effect.",
				optional = true,
			},
			{
				type = "number",
				name = "Haze",
				description = "How hazy the sky is. Affects both the sky and distant objects.",
				optional = true,
			},
		},
		run = function(context, density, offset, color, decay, glare, haze)
			local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
			if atmosphere then
				atmosphere.Density = density
				atmosphere.Offset = offset or atmosphere.Offset
				atmosphere.Color = color or atmosphere.Color
				atmosphere.Decay = decay or atmosphere.Decay
				atmosphere.Glare = glare or atmosphere.Glare
				atmosphere.Haze = haze or atmosphere.Haze
			end
		end,
	},
	{
		name = "fogcolor",
		description = "Changes the color of Lighting.FogColor.",
		args = {
			{
				type = "color",
				name = "Color3",
				description = "The lighting hue applied to fog.",
			},
		},
		run = function(context, fogColor)
			Lighting.FogColor = fogColor
			local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
			if atmosphere then
				atmosphere.Color = fogColor
				atmosphere.Haze = math.max(2 ^ -32, atmosphere.Haze)
			end
		end,
	},
	{
		name = "fogstart",
		description = "Changes the value of Lighting.FogStart.",
		args = {
			{
				type = "number",
				name = "Studs",
				description = "The depth from the Workspace.CurrentCamera, in studs, at which fog begins to show.",
			},
		},
		run = function(context, studs)
			Lighting.FogStart = studs
			local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
			if atmosphere then
				atmosphere.Density = (64 / studs) ^ 0.25
				atmosphere.Haze = math.max(2 ^ -32, 5 / studs ^ 0.1)
			end
		end,
	},
	{
		name = "fogend",
		description = "Changes the value of Lighting.FogEnd.",
		args = {
			{
				type = "number",
				name = "Studs",
				description = "The depth from the Workspace.CurrentCamera, in studs, at which fog will be completely opaque.",
			},
		},
		run = function(context, studs)
			Lighting.FogEnd = studs
			local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
			if atmosphere then
				atmosphere.Density = (64 / studs) ^ 0.25
				atmosphere.Haze = math.max(2 ^ -32, 5 / studs ^ 0.1)
			end
		end,
	},
	{
		name = "brightness",
		description = "Changes the value of Lighting.Brightness.",
		args = {
			{
				type = "number",
				name = "Intensity",
				description = "The intensity of illumination in the place.",
			},
		},
		run = function(context, intensity)
			Lighting.Brightness = intensity
		end,
	},
	{
		name = "colorshift",
		description = "Changes the colors of Lighting.ColorShift_Bottom and Lighting.ColorShift_Top.",
		args = {
			{
				type = "color",
				name = "BottomHue",
				description = "The hue represented in light reflected in the opposite surfaces to those facing the sun or moon.",
			},
			{
				type = "color",
				name = "TopHue",
				description = "The hue represented in light reflected from surfaces facing the sun or moon.",
			},
		},
		run = function(context, shiftBottom: Color3, shiftTop: Color3)
			Lighting.ColorShift_Bottom = shiftBottom
			Lighting.ColorShift_Top = shiftTop
		end,
	},
	{
		name = "diffusescale",
		description = "Changes the value of Lighting.EnvironmentDiffuseScale.",
		args = {
			{
				type = "number",
				name = "Scale",
				description = "Ambient light that is derived from the environment. The value of this property defaults to 0.",
			},
		},
		run = function(context, scale)
			Lighting.EnvironmentDiffuseScale = scale
		end,
	},
	{
		name = "specularscale",
		description = "Changes the value of Lighting.EnvironmentSpecularScale.",
		args = {
			{
				type = "number",
				name = "Scale",
				description = "Specular light derived from environment. The value of this property defaults to 0.",
			},
		},
		run = function(context, scale)
			Lighting.EnvironmentSpecularScale = scale
		end,
	},
	{
		name = "exposure",
		description = "Changes the value of Lighting.ExposureCompensation.",
		args = {
			{
				type = "number",
				name = "Amount",
				description = "The exposure compensation amount which applies a bias to the exposure level of the scene prior to the tonemap step. Defaults to 0.",
			},
		},
		run = function(context, amount)
			Lighting.ExposureCompensation = amount
		end,
	},
	{
		name = "time",
		aliases = { "clocktime" },
		credit = {
			"Realistic @iiRealistic_Dev",
			"Kohl @Scripth",
		},
		description = "Changes the value of Lighting.ClockTime.",
		args = {
			{
				type = "string",
				name = "Time",
				description = "The time of day, can be HH, HH:MM, or HH:MM:SS.",
			},
			{
				type = "number",
				name = "Duration",
				description = "Transition duration to the new time of day. Defaults to instant.",
				optional = true,
			},
		},
		run = function(context, time: string, duration: number?)
			local hours, minutes, seconds = unpack(string.split(time, ":"))
			hours = math.clamp(tonumber(hours) or 0, 0, 23)
			minutes = math.clamp(tonumber(minutes) or 0, 0, 59)
			seconds = math.clamp(tonumber(seconds) or 0, 0, 59)

			local clockTime = hours + minutes / 60 + seconds / 3600

			if duration then
				context._K.Service.TweenService
					:Create(Lighting, TweenInfo.new(duration, Enum.EasingStyle.Linear), { ClockTime = clockTime })
					:Play()
			else
				Lighting.ClockTime = clockTime
			end
		end,
	},
	{
		name = "latitude",
		aliases = { "geographiclatitude" },
		description = "Changes the value of Lighting.GeographicLatitude.",
		args = {
			{
				type = "number",
				name = "Degrees",
				description = "The geographic latitude, in degrees, of the scene, influencing the result of time on the position of the sun and moon.",
				optional = true,
			},
		},
		env = function(_K)
			return { defaultLatitude = Lighting.GeographicLatitude }
		end,
		run = function(context, degrees)
			Lighting.GeographicLatitude = if degrees == nil then context.env.defaultLatitude else degrees
		end,
	},
	{
		name = "shadows",
		aliases = { "globalshadows" },
		description = "Changes the value of Lighting.GlobalShadows.",
		args = {
			{
				type = "boolean",
				name = "Enabled",
				description = "Toggles voxel-based dynamic lighting in the game.",
			},
		},
		run = function(context, enabled)
			Lighting.GlobalShadows = enabled
		end,
	},
	{
		name = "skybox",
		aliases = { "sky", "unskybox", "unsky" },
		description = "Changes the skybox.",
		args = {
			{
				type = "image",
				name = "Bottom",
				description = "The bottom image.",
				optional = true,
			},
			{
				type = "image",
				name = "Back",
				description = "The back image.",
				optional = true,
			},
			{
				type = "image",
				name = "Left",
				description = "The left image.",
				optional = true,
			},
			{
				type = "image",
				name = "Top",
				description = "The top image.",
				optional = true,
			},
			{
				type = "image",
				name = "Front",
				description = "The front image.",
				optional = true,
			},
			{
				type = "image",
				name = "Right",
				description = "The right image.",
				optional = true,
			},
		},
		run = function(context, bottom, back, left, top, front, right)
			if not bottom or context.undo then
				pcall(game.Destroy, context._K.Service.Lighting:FindFirstChild("_KSky"))
				return
			end
			local existing = context._K.Service.Lighting:FindFirstChildOfClass("Sky")
			if not existing or existing.Name ~= "_KSky" then
				existing = Instance.new("Sky")
				existing.Name = "_KSky"
			end
			existing.SkyboxDn = bottom
			existing.SkyboxBk = back or bottom
			existing.SkyboxLf = left or bottom
			existing.SkyboxUp = top or bottom
			existing.SkyboxFt = front or back or bottom
			existing.SkyboxRt = right or left or bottom
			existing.Parent = context._K.Service.Lighting
		end,
	},

	{
		name = "airdensity",
		description = "Changes the air density used in aerodynamic forces model.",
		args = {
			{
				type = "number",
				name = "Density",
				description = `The density of the air, default is {workspace.AirDensity}.`,
			},
		},
		run = function(context, density)
			workspace.AirDensity = density
		end,
	},
	{ -- technically abusive, can reproduce punish behaviour
		name = "gravity",
		description = "Changes the world's gravity.",
		args = {
			{
				type = "number",
				name = "Gravity",
				description = `The gravity acceleration in stud/s, default is {string.format("%.1f", workspace.Gravity)}.`,
				optional = true,
			},
		},
		env = function(_K)
			return {
				gravity = workspace.Gravity,
			}
		end,
		run = function(context, gravity)
			workspace.Gravity = if gravity == nil then context.env.gravity else gravity
		end,
	},
	{
		name = "winddir",
		aliases = { "winddirection" },
		description = "Orients the wind direction along your camera.",
		args = {},
		run = function(context)
			if context.fromPlayer then
				context._K.Remote.SpectateSubject:FireClient(context.fromPlayer, true)
				local con
				con = context._K.Remote.SpectateSubject.OnServerEvent:Connect(function(player, cframe)
					if player == context.fromPlayer then
						con:Disconnect()
						workspace.GlobalWind = cframe.LookVector * workspace.GlobalWind.Magnitude
					end
				end)
			end
		end,
	},
	{
		name = "windspeed",
		description = "Changes the global wind speed.",
		args = {
			{
				type = "number",
				name = "Speed",
				description = `The speed of the wind in studs per second, default is {workspace.GlobalWind.Magnitude}.`,
			},
		},
		run = function(context, windSpeed)
			workspace.GlobalWind = windSpeed
				* if workspace.GlobalWind.Magnitude > 0 then workspace.GlobalWind.Unit else -Vector3.xAxis
		end,
	},

	{
		name = "watercolor",
		description = "Changes the color of Terrain water.",
		args = {
			{
				type = "color",
				name = "Color",
				description = `The color of the water, default is {workspace.Terrain.WaterColor}.`,
			},
		},
		run = function(context, color)
			workspace.Terrain.WaterColor = color
		end,
	},
	{
		name = "waterreflectance",
		description = "Changes the reflectance of Terrain water.",
		args = {
			{
				type = "number",
				name = "Reflectance",
				description = `The reflectance of the water, default is {workspace.Terrain.WaterReflectance}.`,
			},
		},
		run = function(context, reflectance)
			workspace.Terrain.WaterReflectance = reflectance
		end,
	},
	{
		name = "watertransparency",
		description = "Changes the transparency of Terrain water.",
		args = {
			{
				type = "number",
				name = "Transparency",
				description = `The transparency of the water, default is {workspace.Terrain.WaterTransparency}.`,
			},
		},
		run = function(context, transparency)
			workspace.Terrain.WaterTransparency = transparency
		end,
	},
	{
		name = "watersize",
		description = "Changes the wave size of Terrain water.",
		args = {
			{
				type = "number",
				name = "Size",
				description = `The wave size of the water, default is {workspace.Terrain.WaterWaveSize}.`,
			},
		},
		run = function(context, size)
			workspace.Terrain.WaterWaveSize = size
		end,
	},
	{
		name = "waterspeed",
		description = "Changes the wave speed of Terrain water.",
		args = {
			{
				type = "number",
				name = "Speed",
				description = `The wave speed of the water, default is {string.format(
					"%.1f",
					workspace.Terrain.WaterWaveSpeed
				)}.`,
			},
		},
		run = function(context, speed)
			workspace.Terrain.WaterWaveSpeed = speed
		end,
	},
}
