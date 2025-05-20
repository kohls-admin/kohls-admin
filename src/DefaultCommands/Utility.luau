-- safe utilily commands for all players

return {
	{
		name = "version",
		description = "Displays the version of Kohl's Admin in this game.",
		optionalPrefix = true,
		runClient = function(context)
			context._K.Notify({ From = "_K", Text = `<sc>version</sc>:\t<b>{context._K.VERSION}</b>` })
		end,
	},
	{
		name = "help",
		aliases = { "?", "prefix" },
		description = "Displays a help notification for Kohl's Admin in this game.",
		optionalPrefix = true,
		runClient = function(context)
			local commandBarKey = context._K.client.hotkeys.commandBar
			local commandBarKeyRaw = context._K.UI.UserInputService:GetStringForKeyCode(commandBarKey.key._value)
			local commandBarKeyText =
				`{commandBarKey.mods.Shift and "Shift+" or ""}{commandBarKey.mods.Alt and "Alt+" or ""}{commandBarKey.key._value.Name}`

			local dashboardKey = context._K.client.hotkeys.dashboard
			local dashboardKeyRaw = context._K.UI.UserInputService:GetStringForKeyCode(dashboardKey.key._value)
			local dashboardKeyText =
				`{dashboardKey.mods.Shift and "Shift+" or ""}{dashboardKey.mods.Alt and "Alt+" or ""}{dashboardKey.key._value.Name}`

			context._K.Notify({
				From = "_K",
				Text = table.concat({
					`<font family="{context._K.UI.Theme.FontMono._value.Name}">This game uses <b>Kohl's Admin</b>!\n`,
					`<b>Prefix</b>     <font color="#0f0">{context._K.UI.peek(context._K.client.settings.prefix)}</font>`,
					`<b>Commands</b>   <font color="#0f0">{commandBarKeyText} {commandBarKeyRaw}</font>`,
					`<b>Dashboard</b>  <font color="#0f0">{dashboardKeyText} {dashboardKeyRaw}</font></font>`,
				}, "\n"),
			})
		end,
	},
	{
		name = "about",
		aliases = { "credit", "credits", "info", "donate", "support" },
		description = "Shows the about tab in a separate window.",
		optionalPrefix = true,
		envClient = function(_K)
			local env = {}
			task.defer(function()
				local window = _K.UI.new "Window" {
					Parent = _K.UI.LayerTopInset,
					Title = "Kohl's Admin About",
					Visible = false,
					_K.UI.new "UIPadding" {
						PaddingLeft = UDim.new(0, 1),
						PaddingRight = UDim.new(0, 1),
						PaddingTop = UDim.new(0, 1),
						PaddingBottom = UDim.new(0, 1),
					},
				}
				_K.UI.edit(window, {
					[_K.UI.Event.Property] = {
						Visible = function()
							if not window._instance.Visible and #_K.client.dashboard then
								_K.UI.edit(_K.client.dashboard.Tabs, {
									_K.client.dashboard.About,
								})
							end
						end,
					},
				})
				env.window = window
			end)
			return env
		end,

		runClient = function(context)
			local about = context._K.client.dashboard.About
			local scrollY = if string.find(context.alias, "credit", 1, true)
				then about.CanvasPosition.Y + about.Credits.AbsolutePosition.Y - about.AbsolutePosition.Y
				else 0
			about.CanvasPosition = Vector2.new(0, scrollY)
			context._K.UI.edit(context.env.window, {
				Visible = true,
				context._K.client.dashboard.About,
			})
			context._K.UI.edit(context._K.client.dashboard.About, { Visible = true })
			if not context.env.init then
				local size = context.env.window._instance.AbsoluteSize
				context.env.window.Position:set(
					UDim2.fromOffset(
						math.floor(workspace.CurrentCamera.ViewportSize.X / 2) - size.X / 2,
						math.floor(workspace.CurrentCamera.ViewportSize.Y / 2) - size.Y / 2
					)
				)
				context.env.init = true
			end
		end,
	},
	{
		name = "commands",
		aliases = { "cmds" },
		description = "Shows the commands in a separate window.",
		optionalPrefix = true,
		envClient = function(_K)
			local env = {}
			task.defer(function()
				local window = _K.UI.new "Window" {
					Parent = _K.UI.LayerTopInset,
					Title = "Kohl's Admin Commands",
					Visible = false,
					_K.UI.new "UIPadding" {
						PaddingLeft = UDim.new(0, 1),
						PaddingRight = UDim.new(0, 1),
						PaddingTop = UDim.new(0, 1),
						PaddingBottom = UDim.new(0, 1),
					},
				}
				_K.UI.edit(window, {
					[_K.UI.Event.Property] = {
						Visible = function()
							if not window._instance.Visible and #_K.client.dashboard then
								_K.UI.edit(_K.client.dashboard.Tabs, {
									_K.client.dashboard.Commands,
								})
							end
						end,
					},
				})
				env.window = window
			end)
			return env
		end,

		runClient = function(context)
			context._K.UI.edit(context.env.window, {
				Visible = true,
				context._K.client.dashboard.Commands,
			})
			context._K.UI.edit(context._K.client.dashboard.Commands, { Visible = true })
			if not context.env.init then
				local size = context.env.window._instance.AbsoluteSize
				context.env.window.Position:set(
					UDim2.fromOffset(
						math.floor(workspace.CurrentCamera.ViewportSize.X / 2) - size.X / 2,
						math.floor(workspace.CurrentCamera.ViewportSize.Y / 2) - size.Y / 2
					)
				)
				context.env.init = true
			end
		end,
	},
	{
		name = "dashboard",
		description = "Shows the admin dashboard.",
		optionalPrefix = true,
		runClient = function(context)
			if not context._K.client.dashboard.Commands.window.Visible then
				context._K.client.hotkeys.dashboard.callback()
			end
		end,
	},
	{
		name = "log",
		aliases = {
			"logs",
			"debuglogs",
			"errorlogs",
			"chatlogs",
			"commandlogs",
			"joinlogs",
			"damagelogs",
			"killlogs",
			"purchaselogs",
			"clogs",
			"cmdlogs",
			"dmglogs",
			"buylogs",
		},
		description = "Shows the logs in a separate window.",
		optionalPrefix = true,
		envClient = function(_K)
			local env = {
				aliasMap = {
					clogs = "chatlogs",
					cmdlogs = "commandlogs",
					dmglogs = "damagelogs",
					buylogs = "purchaselogs",
				},
				typeMap = {
					DEBUG = { "DEBUG", "INFO", "WARN", "ERROR" },
					ERROR = { "WARN", "ERROR" },
					CHAT = { "CHAT" },
					COMMAND = { "COMMAND" },
					JOIN = { "JOIN", "LEAVE" },
					KILL = { "KILL", "DEATH", "DAMAGE" },
					DAMAGE = { "KILL", "DEATH", "DAMAGE" },
					PURCHASE = { "PURCHASE" },
				},
				originalFilter = nil,
			}

			task.defer(function()
				local window = _K.UI.new "Window" {
					Parent = _K.UI.LayerTopInset,
					Title = "Kohl's Admin Logs",
					Visible = false,
					_K.UI.new "UIPadding" {
						PaddingLeft = UDim.new(0, 1),
						PaddingRight = UDim.new(0, 1),
						PaddingTop = UDim.new(0, 1),
						PaddingBottom = UDim.new(0, 1),
					},
				}
				_K.UI.edit(window, {
					[_K.UI.Event.Property] = {
						Visible = function()
							if not window._instance.Visible then
								_K.UI.edit(_K.client.dashboard.Tabs, {
									_K.client.dashboard.Logs,
								})
								if env.originalFilter then
									for logType, value in env.originalFilter do
										_K.client.dashboard.Logs.logTypeFilter[logType]:set(value)
									end
									env.originalFilter = nil
								end
							end
						end,
					},
				})
				env.window = window
			end)
			return env
		end,

		runClient = function(context)
			context._K.UI.edit(context.env.window, {
				Visible = true,
				context._K.client.dashboard.Logs,
			})
			context._K.UI.edit(context._K.client.dashboard.Logs, { Visible = true })

			if not context.env.originalFilter then
				context.env.originalFilter = {}
				for logType, state in context._K.client.dashboard.Logs.logTypeFilter do
					context.env.originalFilter[logType] = state._value
				end
			end

			if context.alias == "log" or context.alias == "logs" then
				for _, state in context._K.client.dashboard.Logs.logTypeFilter do
					state:set(true)
				end
			else
				for _, state in context._K.client.dashboard.Logs.logTypeFilter do
					state:set(false)
				end
				local alias = string.lower(context.alias)
				local match = context.env.aliasMap[alias] or alias
				match = string.upper(string.match(match, "(%w+)logs?$") :: string)
				for _, logType in context.env.typeMap[match] do
					context._K.client.dashboard.Logs.logTypeFilter[logType]:set(true)
				end
			end

			if not context.env.init then
				local size = context.env.window._instance.AbsoluteSize
				context.env.window.Position:set(
					UDim2.fromOffset(
						math.floor(workspace.CurrentCamera.ViewportSize.X / 2) - size.X / 2,
						math.floor(workspace.CurrentCamera.ViewportSize.Y / 2) - size.Y / 2
					)
				)
				context.env.init = true
			end
		end,
	},
	{
		name = "settings",
		aliases = { "set" },
		description = "Shows the settings in a separate window.",
		optionalPrefix = true,
		envClient = function(_K)
			local env = {}
			task.defer(function()
				local window = _K.UI.new "Window" {
					Parent = _K.UI.LayerTopInset,
					Title = "Kohl's Admin Settings",
					Visible = false,
					_K.UI.new "UIPadding" {
						PaddingLeft = UDim.new(0, 1),
						PaddingRight = UDim.new(0, 1),
						PaddingTop = UDim.new(0, 1),
						PaddingBottom = UDim.new(0, 1),
					},
				}
				_K.UI.edit(window, {
					[_K.UI.Event.Property] = {
						Visible = function()
							if not window._instance.Visible and #_K.client.dashboard then
								_K.UI.edit(_K.client.dashboard.Tabs, {
									_K.client.dashboard.Settings,
								})
							end
						end,
					},
				})
				env.window = window
			end)
			return env
		end,

		runClient = function(context)
			context._K.UI.edit(context.env.window, {
				Visible = true,
				context._K.client.dashboard.Settings,
			})
			context._K.UI.edit(context._K.client.dashboard.Settings, { Visible = true })
			if not context.env.init then
				local size = context.env.window._instance.AbsoluteSize
				context.env.window.Position:set(
					UDim2.fromOffset(
						math.floor(workspace.CurrentCamera.ViewportSize.X / 2) - size.X / 2,
						math.floor(workspace.CurrentCamera.ViewportSize.Y / 2) - size.Y / 2
					)
				)
				context.env.init = true
			end
		end,
	},

	{
		name = "age",
		aliases = { "accountage" },
		description = "Displays the account age of a player.",
		args = {
			{
				type = "player",
				name = "Player",
				description = "The player whose account age to display.",
				lowerRank = true,
			},
		},

		runClient = function(context, player: Player)
			context._K.Notify({
				From = player.UserId,
				Text = `<b>Account Age:</b> {context._K.Util.ReadableTime(player.AccountAge * 86400)}`,
			})
		end,
	},
	{
		name = "serverage",
		aliases = {},
		description = "Displays the age of the server.",
		run = function(context, volume)
			context._K.Remote.Notify:FireClient(context.fromPlayer, {
				From = "_K",
				Text = `<b>Server Age:</b> {context._K.Util.ReadableTime(workspace.DistributedGameTime)}`,
			})
		end,
	},
	{
		name = "showfps",
		description = "Displays the frames per second of a player.",
		args = {
			{
				type = "player",
				name = "Player",
				description = "The player whose frames per second to display.",
				lowerRank = true,
			},
		},
		envClient = function(_K)
			local env = {
				fps = 60,
			}
			function _K.Remote.ShowFPS.OnClientInvoke()
				return env.fps
			end
			local frames, last = 0, tick()
			_K.Service.Run.Heartbeat:Connect(function()
				frames += 1
				local dt = tick() - last
				if dt >= 1 then
					env.fps = frames / dt
					frames, last = 0, tick()
				end
			end)
			return env
		end,
		run = function(context, player: Player)
			context._K.Remote.Notify:FireClient(context.fromPlayer, {
				Text = `<b>FPS:</b> {math.round(context._K.Remote.ShowFPS:InvokeClient(player) or 0)}`,
				From = player.UserId,
			})
		end,
	},
	{
		name = "ping",
		description = "Displays the ping of a player.",
		args = {
			{
				type = "player",
				name = "Player",
				description = "The player to ping.",
				lowerRank = true,
			},
		},

		run = function(context, player: Player)
			context._K.Remote.Notify:FireClient(
				context.fromPlayer,
				{ Text = `<b>Ping:</b> {math.round(player:GetNetworkPing() * 1000)} ms`, From = player.UserId }
			)
		end,
	},
	{
		name = "wait",
		aliases = { "delay" },
		description = "Delays command execution for a period of time.",
		args = {
			{
				type = "number",
				name = "Seconds",
				description = "How long to wait in seconds.",
			},
		},

		runClient = function(context, delay: number)
			task.wait(delay)
		end,
		run = function(context, delay: number)
			task.wait(delay)
		end,
	},
	{
		name = "rejoin",
		description = "Rejoins the server.",

		run = function(context)
			local options = Instance.new("TeleportOptions")
			options.ServerInstanceId = game.JobId
			context._K.Util.SafeTeleport(
				game.PlaceId,
				{ context.fromPlayer },
				#context._K.Service.Players:GetPlayers() > 1 and options
			)
		end,
	},
	{
		name = "join",
		description = "Join a player in the same game.",
		args = {
			{
				type = "userId",
				name = "UserId",
				description = "The UserId of the player to join.",
			},
		},

		run = function(context, userId)
			local ok, samePlace, errorMessage, placeId, jobId =
				pcall(context._K.Service.Teleport.GetPlayerPlaceInstanceAsync, context._K.Service.Teleport, userId)
			if not ok then
				return errorMessage or samePlace
			end
			if samePlace then
				return "You're already in the same server!"
			end

			if placeId and jobId then
				local options = Instance.new("TeleportOptions")
				options.ServerInstanceId = jobId
				context._K.Util.SafeTeleport(placeId, { context.fromPlayer }, options)
			end
			return
		end,
	},

	-- {
	-- 	name = "alias",
	-- 	aliases = {},
	-- 	description = "Creates a command alias out of a command and given arguments.",
	-- 	args = {
	-- 		{
	-- 			type = "string",
	-- 			name = "Alias name",
	-- 			description = "The name of the command alias.",
	-- 		},
	-- 		{
	-- 			type = "string",
	-- 			name = "Command string",
	-- 			description = "The command string to alias.",
	-- 		},
	-- 	},

	-- 	runClient = function(context, alias: string, command: string)
	-- 		context._K.Registry.registerCommandAlias(context._K, alias, command)
	-- 	end,
	-- },
}
