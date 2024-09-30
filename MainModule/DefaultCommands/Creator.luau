-- dangerous commands restricted to creators

return {
	{
		name = "clearlogs",
		description = "Removes all Kohl's Admin server logs.",
		args = {},
		envClient = function(_K)
			_K.Remote.ClearLogs.OnClientEvent:Connect(function()
				local logs = _K.Data.logs
				for index, log in logs do
					if log.client then
						continue
					end
					logs[index] = nil
				end
				_K.Util.Table.settle(logs)
			end)
		end,
		env = function(_K)
			return { remote = _K.Remote.ClearLogs }
		end,

		run = function(context)
			table.clear(context._K.Data.logs)
			context._K.Data.Store.removeAsync("Logs")
			for _, player in context._K.Util.Services.Players:GetPlayers() do
				context._K.Remote.ClearLogs:FireClient(player)
			end
		end,
	},
	{
		name = "hidelogs",
		aliases = { "unhidelogs" },
		description = "Hides the Kohl's Admin logs of one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) whose logs to hide.",
				shouldRequest = true,
			},
		},
		run = function(context, players)
			if context.undo then -- defer to hide the "unhidelogs" command usage
				task.defer(function()
					for _, player in players do
						context._K.Data.logsHidden[player.UserId] = not context.undo
					end
				end)
			else
				for _, player in players do
					context._K.Data.logsHidden[player.UserId] = true
				end
			end
		end,
	},
}
