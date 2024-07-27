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
	{
		name = "gravity",
		description = "Changes the world's gravity.",
		args = {
			{
				type = "number",
				name = "Gravity",
				description = `The gravity acceleration in stud/s, default is {workspace.Gravity}.`,
			},
		},
		run = function(context, gravity)
			workspace.Gravity = gravity
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
		description = "Orients the wind direction along your camera.",
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
