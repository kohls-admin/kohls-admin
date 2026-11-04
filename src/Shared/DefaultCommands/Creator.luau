-- dangerous commands restricted to creators

return {
	{
		name = "clearlogs",
		aliases = { "clrlogs" },
		description = "Removes all Kohl's Admin server logs.",
		args = {},
		envClient = function(_K)
			local _ = _K.Remote.ClearLogs:Connect(function()
				local logs = _K.Data.logs
				for index, log in logs do
					if log[6] then
						continue
					end
					logs[index] = nil
				end
				_K.Util.Table.settle(logs)
				if _K.client and _K.client.dashboard and _K.client.dashboard.Logs then
					_K.client.dashboard.Logs:updateList()
				end
			end)
		end,
		env = function(_K)
			local env = {
				remote = _K.Remote.ClearLogs,
				clearLogs = function()
					table.clear(_K.Data.logs)
					table.clear(_K.Data.Sync.logs)
					table.clear(_K.Data.pendingLogReveals)
					_K.Data.logsVersion += 1
					for _, player in _K.Service.Players:GetPlayers() do
						_K.Remote.ClearLogs:Fire(player)
					end
				end,
			}
			_K.Data.subscribeTopic("clearlogs", env.clearLogs)
			return env
		end,

		run = function(context)
			if not context._K.Data.SEPARATE_DATASTORE then
				for i = 1, 4 do
					task.spawn(context._K.Data.Store.removeAsync, "Logs_" .. i)
				end
			end
			context.env.clearLogs()
			context._K.Data.publishTopic("clearlogs")
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
	{
		name = "script",
		aliases = { "s", "loadstring" },
		description = "Runs a script.",
		args = {
			{
				type = "rawString",
				name = "Source",
				description = "The source of the script.",
			},
		},
		run = function(context, source: string)
			if context._K.Data.SEPARATE_DATASTORE then
				return `Script commands are disabled in private servers.`
			end
			table.insert(context._K.cleanupCommands, context._K.LoadScript(source, "Server"))
			return
		end,
	},
	{
		name = "localscript",
		aliases = { "ls" },
		description = "Runs a script locally for one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to run the localscript on.",
				shouldRequest = true,
			},
			{
				type = "rawString",
				name = "Source",
				description = "The source of the localscript.",
			},
		},
		run = function(context, players: { Player }, source: string)
			if context._K.Data.SEPARATE_DATASTORE then
				return `Script commands are disabled in private servers.`
			end
			for _, player in players do
				local parent = player:FindFirstChildOfClass("PlayerGui")
				if not parent then
					continue
				end
				table.insert(context._K.cleanupCommands, context._K.LoadScript(source, "Client", parent))
			end
			return
		end,
	},
}
