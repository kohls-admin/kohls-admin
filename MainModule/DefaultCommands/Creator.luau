-- dangerous commands restricted to creators

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
}
