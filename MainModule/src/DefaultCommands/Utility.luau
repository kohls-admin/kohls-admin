-- safe utilily commands for all players

return {
	{
		name = "alias",
		aliases = {},
		description = "Creates a command alias out of a command and given arguments.",
		args = {
			{
				type = "string",
				name = "Alias name",
				description = "The name of the command alias.",
			},
			{
				type = "string",
				name = "Command string",
				description = "The command string to alias.",
			},
		},

		clientRun = function(context, alias: string, command: string)
			context.Registry.registerCommandAlias(alias, command)
		end,
	},
}
