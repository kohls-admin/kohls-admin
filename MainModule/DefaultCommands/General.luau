-- "non-abusive" commands for game members

local noclipCache = {}

local spectateConnections = {}

local function spectateCleanup(context)
	for subject, spectators in context._K.spectators do
		local found = table.find(spectators, context.fromPlayer)
		if found then
			table.remove(spectators, found)
			if #spectators == 0 then
				context._K.spectators[subject] = nil
				context._K.Remote.SpectateSubject:FireClient(subject)
			end
		end
	end
end

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
		name = "follow",
		description = "Follows a player with your camera.",
		args = {
			{
				type = "player",
				name = "Player",
				description = "The player to follow.",
			},
		},

		clientRun = function(context, player)
			if player.Character and player.Character:FindFirstChildOfClass("Humanoid") then
				workspace.CurrentCamera.CameraSubject = player.Character:FindFirstChildOfClass("Humanoid")
			end
		end,
	},
	{
		name = "spectate",
		aliases = { "spy", "watch" },
		description = "Spectate a player's point of view.",
		args = {
			{
				type = "player",
				name = "Player",
				description = "The player to spectate.",
			},
		},

		clientRun = function(context, player)
			if player.Character and player.Character:FindFirstChildOfClass("Humanoid") then
				workspace.CurrentCamera.CameraSubject = player.Character:FindFirstChildOfClass("Humanoid")
			end
			if spectateConnections[context.from] then
				spectateConnections[context.from]:Disconnect()
			end
			spectateConnections[context.from] = player.CharacterAdded:Connect(function()
				workspace.CurrentCamera.CameraSubject = player.Character:FindFirstChildOfClass("Humanoid")
			end)
		end,
		run = function(context, player)
			spectateCleanup(context)
			-- apply spectate
			if not context._K.spectators[player] then
				context._K.spectators[player] = {}
			end
			context._K.Remote.SpectateSubject:FireClient(player, true)
			table.insert(context._K.spectators[player], context.fromPlayer)
		end,
	},
	{
		name = "unspectate",
		aliases = { "unspy", "unwatch", "unfollow" },
		description = "Stop spectating.",
		args = {},

		clientRun = function(context)
			local character = context.fromPlayer.Character
			if character then
				workspace.CurrentCamera.CameraSubject = character:FindFirstChildOfClass("Humanoid")
			end
			if spectateConnections[context.from] then
				spectateConnections[context.from]:Disconnect()
				spectateConnections[context.from] = nil
			end
		end,
		run = spectateCleanup,
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
}
