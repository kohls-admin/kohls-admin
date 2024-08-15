-- potentially abusive fun commands

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
			},
			{
				type = "integer",
				name = "UserId",
				description = "The UserId of the player to use.",
			},
		},

		run = function(context, players, userId)
			for _, player in players do
				player.CharacterAppearanceId = userId
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
				player.CharacterAppearanceId = player.UserId
				player:LoadCharacter()
			end
		end,
	},
}
