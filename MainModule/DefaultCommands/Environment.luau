-- commands relating to the game environment, lighting, workspace properties, etc

return {
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
			workspace.Gravity = if gravity == context.OPTIONAL then context.env.gravity else gravity
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
		description = "Changes the gnobal wind speed.",
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
				description = `The wave speed of the water, default is {workspace.Terrain.WaterWaveSpeed}.`,
			},
		},
		run = function(context, speed)
			workspace.Terrain.WaterWaveSpeed = speed
		end,
	},
}
