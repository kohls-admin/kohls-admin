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
		name = "hint",
		aliases = { "h" },
		description = "Sends a hint to everyone in the server.",
		args = {
			{
				type = "stringGreedy",
				name = "Message",
				description = "The message to send.",
			},
		},

		run = function(context, message)
			local msgObject = Instance.new("Hint")
			msgObject.Text = message
			msgObject.Parent = workspace
			task.delay(5, function()
				msgObject:Destroy()
			end)
		end,
	},
}
