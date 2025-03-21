-- dangerous commands restricted to superadmins

local BadgeService = game:GetService("BadgeService")

return {
	{
		name = "badge",
		aliases = { "awardbadge" },
		description = "Awards a badge to one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to award the badge.",
			},
			{
				type = "integer",
				name = "Badge ID",
				description = "The badge identifier.",
			},
		},

		run = function(context, players, badge)
			for _, player in players do
				if BadgeService:UserHasBadgeAsync(player.UserId, badge) then
					context._K.Remote.Announce:FireClient(context.fromPlayer, `{player.Name} already has the badge!`)
				else
					local success, err = BadgeService:AwardBadge(player.UserId, badge)

					context._K.Remote.Announce:FireClient(
						context.fromPlayer,
						if success then "Badge awarded!" else `Failed to award badge: {err}`
					)
				end
			end
		end,
	},
	{
		name = "clearterrain",
		aliases = { "cterrain" },
		description = "Removes the terrain.",
		args = {},
		run = function(context)
			workspace.Terrain:Clear()
		end,
	},
	{
		name = "shutdown",
		aliases = {},
		description = "Shuts down the server.",
		args = {
			{
				type = "timeSimple",
				name = "Delay",
				description = "The delay before shutting down.",
				optional = true,
			},
		},
		run = function(context, delay)
			if delay ~= nil then
				context._K.Remote.Announce:FireAllClients(
					`Server will shut down in {delay} seconds`,
					context.from,
					delay
				)
				task.wait(delay)
			end
			local from = tostring(context.fromPlayer or context.from)
			local function kick(player)
				player:Kick(`{from} has shutdown the server.`)
			end
			game:GetService("Players").PlayerAdded:Connect(kick)
			for _, player in game:GetService("Players"):GetPlayers() do
				kick(player)
			end
		end,
	},
}
