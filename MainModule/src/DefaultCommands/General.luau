return {
	{
		name = "alias",
		aliases = {},
		description = "Creates a command alias out of a command and given arguments.",
		group = "General",
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

	{
		name = "message",
		aliases = { "m", "msg" },
		description = "Sends a message to everyone in the server.",
		group = "General",
		args = {
			{
				type = "stringGreedy",
				name = "Message",
				description = "The message to send.",
			},
		},

		run = function(_, message)
			local msgObject = Instance.new("Message")
			msgObject.Text = message
			msgObject.Parent = workspace
			task.delay(5, function()
				msgObject:Destroy()
			end)
		end,
	},
	{
		name = "kill",
		aliases = { "unalive" },
		description = "Kills one or more players.",
		group = "General",
		-- asks players with the same or higher rank if the command should work on them
		abusable = true, -- shorthand for context._K.Auth.shouldRequest(context, player)
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to kill.",
			},
		},

		run = function(context, players)
			print(context, players)
			for _, player in players do
				if context._K.Auth.shouldRequest(context, player) then
					continue
				end
				if player.Character then
					player.Character:BreakJoints()
				end
			end
		end,
	},
	{
		name = "ban",
		description = "Bans one or more players.",
		group = "General",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to ban.",
			},
			{
				type = "timeSimple",
				name = "Duration",
				description = "The duration for the ban.",
				optional = true,
			},
			{
				type = "string",
				name = "Reason",
				description = "The reason for the ban.",
				optional = true,
			},
		},

		run = function(context, players, duration, reason)
			local flags = context.flags
			for _, player in players do
				if context._K.Auth.shouldRequest(context, player) then
					continue
				end
				-- do i change this to a serverban command? (will flags really be useful?)
				if flags.server or flags.s then
					duration = nil
				elseif duration == nil then
					duration = -1
				else
					duration = os.time() + duration
				end
				-- use a helper method for bans?
				-- need to make sure it knows to save?
				context._K.bans[player.UserId] = { player.Username, reason, duration }
				player:Kick(reason)
			end
		end,
	},
}
