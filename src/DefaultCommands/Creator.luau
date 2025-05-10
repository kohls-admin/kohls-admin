-- dangerous commands restricted to creators

return {
	{
		name = "clearlogs",
		aliases = { "clrlogs" },
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
			local env = {
				remote = _K.Remote.ClearLogs,
				clearLogs = function()
					table.clear(_K.Data.logs)
					table.clear(_K.Data.Cache.logs)
					table.clear(_K.Data.Cache.chatLogs)
				end,
			}
			task.spawn(function()
				_K.Util.Services.MessagingService:SubscribeAsync("KA_ClearLogs", env.clearLogs)
			end)
			return env
		end,

		run = function(context)
			task.spawn(context._K.Data.Store.removeAsync, "LogsV2")
			context._K.Util.Services.MessagingService:PublishAsync("KA_ClearLogs")
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
