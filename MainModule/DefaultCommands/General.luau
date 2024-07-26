-- "non-abusive" commands for game members

local noclipCache = {}

return {
	{
		name = "message",
		aliases = { "m", "msg" },
		description = "Sends a message to everyone in the server.",
		args = {
			{
				type = "stringGreedy",
				name = "Message",
				description = "The message to send.",
			},
		},

		run = function(context, message)
			context._K.Remote.Announce:FireAllClients(message, context.from)
		end,
	},
	{
		name = "ff",
		description = "Gives a ForceField to one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to protect.",
			},
		},

		run = function(context, players)
			for _, player in players do
				if player and player.Character and not player.Character:FindFirstChildOfClass("ForceField") then
					Instance.new("ForceField", player.Character)
				end
			end
		end,
	},
	{
		name = "unff",
		description = "Removes a ForceField from one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to remove a ForceField from.",
			},
		},

		run = function(context, players)
			for _, player in players do
				if player and player.Character then
					local ff = player.Character:FindFirstChildOfClass("ForceField")
					if ff then
						ff:Destroy()
					end
				end
			end
		end,
	},
	{
		name = "fly",
		aliases = { "noclip" },
		description = "Enables flight and disables collisions on one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to give flight.",
			},
		},

		run = function(context, players)
			for _, player in players do
				if noclipCache[player] then
					continue
				end
				noclipCache[player] = player.DevCameraOcclusionMode
				player.DevCameraOcclusionMode = Enum.DevCameraOcclusionMode.Invisicam
				context._K.Remote.Noclip:FireClient(player, true)
			end
		end,
	},
	{
		name = "unfly",
		aliases = { "clip" },
		description = "Disables flight and enables collisions on one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to remove flight from.",
			},
		},

		run = function(context, players)
			for _, player in players do
				if not noclipCache[player] then
					continue
				end
				player.DevCameraOcclusionMode = noclipCache[player]
				noclipCache[player] = nil
				context._K.Remote.Noclip:FireClient(player)
			end
		end,
	},
	{
		name = "invisible",
		aliases = { "inv" },
		description = "Makes one or more player(s) invisible.",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to make invisible.",
			},
		},

		run = function(context, players)
			for _, player in players do
				if not player.Character then
					continue
				end
				for _, child in player.Character:GetDescendants() do
					if
						(child:IsA("BasePart") or child:IsA("Decal") or child:IsA("Texture"))
						and not child:GetAttribute("kTransparency")
					then
						child:SetAttribute("kTransparency", child.Transparency)
						child.Transparency = 1
					elseif
						(
							child:IsA("Light")
							or child:IsA("Beam")
							or child:IsA("Trail")
							or child:IsA("ParticleEmitter")
							or child:IsA("Fire")
							or child:IsA("Smoke")
							or child:IsA("Sparkles")
							or child:IsA("SurfaceGui")
						) and not child:GetAttribute("kEnabled")
					then
						child:SetAttribute("kEnabled", child.Enabled)
						child.Enabled = false
					end
				end
			end
		end,
	},
	{
		name = "visible",
		aliases = { "vis" },
		description = "Makes one or more player(s) visible.",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to make visible.",
			},
		},

		run = function(context, players)
			for _, player in players do
				if not player.Character then
					continue
				end
				for _, child in player.Character:GetDescendants() do
					local kTransparency = child:GetAttribute("kTransparency")
					local kEnabled = child:GetAttribute("kEnabled")
					if kTransparency then
						child:SetAttribute("kTransparency", nil)
						child.Transparency = kTransparency
					elseif kEnabled then
						child:SetAttribute("kEnabled", nil)
						child.Enabled = kEnabled
					end
				end
			end
		end,
	},
	{
		name = "respawn",
		description = "Respawns the character of one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to respawn.",
			},
		},

		run = function(context, players)
			for _, player in players do
				player:LoadCharacter()
			end
		end,
	},
	{
		name = "refresh",
		aliases = { "re" },
		description = "Refreshes the character of one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to refresh.",
			},
		},

		run = function(context, players)
			for _, player in players do
				if player and player.Character then
					local old = player.Character:GetPivot()
					player:LoadCharacter()
					player.Character:PivotTo(old)
					context._K.Remote.Refresh:FireClient(player)
				end
			end
		end,
	},
}
