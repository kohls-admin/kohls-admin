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
		name = "reserve",
		aliases = { "privateserver" },
		description = "Reserves a private server.",
		args = {
			{
				type = "rawString",
				name = "AccessCode",
				description = "The access code for joining the reserved server.",
			},
			{
				type = "integer",
				name = "PlaceId",
				description = "The place identifier, omit for the current place.",
				optional = true,
			},
		},
		env = function(_K)
			task.spawn(
				_K.Service.Messaging.SubscribeAsync,
				_K.Service.Messaging,
				"_K_ReservedServers",
				function(message)
					local data = message.Data
					if data then
						_K.Data.reservedServers[data[1]] = { unpack(data, 2) }
						for _, player in _K.Service.Players:GetPlayers() do
							if
								_K.Auth.hasCommand(player.UserId, "place")
								or _K.Auth.hasCommand(player.UserId, "unreserve")
							then
								_K.Remote.ReservedServers:FireClient(player, {
									[data[1]] = { unpack(data, 2) },
								})
							end
						end
					end
				end
			)
			return
		end,
		envClient = function(_K)
			_K.Remote.ReservedServers.OnClientEvent:Connect(function(data)
				if data then
					_K.Util.Table.merge(_K.Data.reservedServers, data)
				end
			end)
		end,
		run = function(context, code: string, placeId: string?)
			if context._K.Data.SEPARATE_DATASTORE then
				return `Reserve command is disabled in private servers.`
			end

			placeId = placeId or game.PlaceId
			local data = { context._K.Service.Teleport:ReserveServer(placeId), placeId }
			context._K.Data.Store.updateAsync("Servers", function(store)
				if store == nil then
					store = {}
				end
				store[code] = data
				return store
			end)

			context._K.Service.Messaging:PublishAsync("_K_ReservedServers", { code, unpack(data, 2) })
			context._K.Remote.Notify:FireClient(context.fromPlayer, {
				Text = `Server "<b>{code}</b>" has been reserved, use <b>{context._K.getCommandPrefix(context.from)}place me @{code}</b> to join it!`,
			})

			return
		end,
	},
	{
		name = "unreserve",
		aliases = { "delreserve", "removereserve", "removeprivateserver" },
		description = "Removes a reserved server.",
		args = {
			{
				type = "reservedServer",
				name = "AccessCode",
				description = "The access code of the reserved server.",
			},
		},
		run = function(context, code: string)
			if context._K.Data.SEPARATE_DATASTORE then
				return `Unreserve command is disabled in private servers.`
			end

			local removed
			context._K.Data.Store.updateAsync("Servers", function(store)
				if store == nil then
					store = {}
				end
				if store[code] then
					removed = true
				end
				store[code] = nil
				return store
			end)

			context._K.Service.Message:PublishAsync("_K_ReservedServers", { code })
			context._K.Remote.Notify:FireClient(context.fromPlayer, {
				Text = `Server "<b>{code}</b>" {if removed then "has been removed" else "was NOT found"}!`,
			})

			return
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
			{
				type = "string",
				name = "Reason",
				description = "The reason for the shutdown.",
				optional = true,
			},
		},
		run = function(context, delay: number?, reason: string?)
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
				player:Kick(`{from} has shutdown the server.{if reason then `\nReason: {reason}` else ""}`)
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
				_K.Service.Messaging:SubscribeAsync("KA_GlobalCommand", function(message)
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
			if context._K.Data.SEPARATE_DATASTORE then
				return `Global commands are disabled in private servers.`
			end

			context._K.Service.Messaging:PublishAsync("KA_GlobalCommand", { context.from, commandString })
			return
		end,
	},
}
