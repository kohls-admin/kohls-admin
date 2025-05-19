-- dangerous commands restricted to superadmins

local BadgeService = game:GetService("BadgeService")

return {
	{
		name = "badge",
		aliases = { "awardbadge", "givebadge" },
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
				description = "The badge ID.",
			},
		},

		run = function(context, players, badge)
			for _, player in players do
				if BadgeService:UserHasBadgeAsync(player.UserId, badge) then
					context._K.Remote.Notify:FireClient(context.fromPlayer, {
						Text = `{player.Name} already has the badge!`,
					})
				else
					local success, err = BadgeService:AwardBadge(player.UserId, badge)

					context._K.Remote.Notify:FireClient(
						context.fromPlayer,
						{ Text = if success then "Badge awarded!" else `Failed to award badge: {err}` }
					)
				end
			end
		end,
	},
	{
		name = "clearterrain",
		aliases = { "cterrain", "clrterrain", "removeterrain" },
		description = "Removes all terrain.",
		args = {},
		run = function(context)
			workspace.Terrain:Clear()
		end,
	},
	{
		name = "shutdown",
		aliases = { "stopserver" },
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
				context._K.Remote.Announce:FireAllClients({
					Text = `Server will shut down in {delay} seconds`,
					From = context.from,
					Duration = delay,
				})
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
	{
		name = "global",
		aliases = { "gcmd" },
		description = "Runs a command string globally in all servers.",
		args = {
			{
				type = "rawString",
				name = "Command string",
				description = "The command string to run.",
			},
		},
		env = function(_K)
			task.spawn(function()
				_K.Util.Services.MessagingService:SubscribeAsync("KA_GlobalCommand", function(message)
					local from, commandString = unpack(message.Data)
					if from and commandString then
						local prefix = _K.getCommandPrefix(from)
						if string.find(commandString, string.format('^%s[^%s"`,%%s]', prefix, prefix)) ~= 1 then
							commandString = prefix .. commandString
						end
						_K.Process.runCommands(_K, from, commandString, true)
					end
				end)
			end)
		end,
		run = function(context, commandString: string)
			context._K.Util.Services.MessagingService:PublishAsync("KA_GlobalCommand", { context.from, commandString })
		end,
	},
}
