-- safe utilily commands for all players

return {
	{
		name = "version",
		description = "Displays the version of Kohl's Admin in this game.",
		optionalPrefix = true,
		runClient = function(context)
			context._K.Notify({ From = "_K", Text = `<sc>version</sc>:\t<b>{context._K.prefix}</b>` })
		end,
	},
	{
		name = "help",
		aliases = { "?", "prefix" },
		description = "Displays a help notification for of Kohl's Admin in this game.",
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
					`<b>Prefix</b>     <font color="#0f0">{context._K.UI.peek(context._K.UI.Scope.settings.prefix)}</font>`,
					`<b>Commands</b>   <font color="#0f0">{commandBarKeyText} {commandBarKeyRaw}</font>`,
					`<b>Dashboard</b>  <font color="#0f0">{dashboardKeyText} {dashboardKeyRaw}</font></font>`,
				}, "\n"),
			})
		end,
	},
	{
		name = "about",
		aliases = { "credit", "credits", "info", "donate", "support", "vip" },
		description = "Shows the about tab in a separate window.",
		optionalPrefix = true,
		envClient = function(_K)
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
						if not window._instance.Visible and #_K.UI.Scope.dashboard then
							_K.UI.edit(_K.UI.Scope.dashboard.Tabs, {
								_K.UI.Scope.dashboard.About,
							})
						end
					end,
				},
			})
			return {
				window = window,
			}
		end,

		runClient = function(context)
			local about = context._K.UI.Scope.dashboard.About
			local scrollY = if string.find(context.alias, "credit", 1, true)
				then about.CanvasPosition.Y + about.Credits.AbsolutePosition.Y - about.AbsolutePosition.Y
				else 0
			about.CanvasPosition = Vector2.new(0, scrollY)
			local visible = not context.env.window._instance.Visible
			context._K.UI.edit(context.env.window, {
				Visible = visible,
				if visible then context._K.UI.Scope.dashboard.About else nil,
			})
			if not context.env.init then
				context.env.window.Position:set(
					UDim2.fromOffset(
						math.floor(workspace.CurrentCamera.ViewportSize.X / 2) - 210,
						math.floor(workspace.CurrentCamera.ViewportSize.Y / 2) - 210
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
						if not window._instance.Visible and #_K.UI.Scope.dashboard then
							_K.UI.edit(_K.UI.Scope.dashboard.Tabs, {
								_K.UI.Scope.dashboard.Commands,
							})
						end
					end,
				},
			})
			return {
				window = window,
			}
		end,

		runClient = function(context)
			local visible = not context.env.window._instance.Visible
			context._K.UI.edit(context.env.window, {
				Visible = visible,
				if visible then context._K.UI.Scope.dashboard.Commands else nil,
			})
			if not context.env.init then
				context.env.window.Position:set(
					UDim2.fromOffset(
						math.floor(workspace.CurrentCamera.ViewportSize.X / 2) - 210,
						math.floor(workspace.CurrentCamera.ViewportSize.Y / 2) - 210
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
			context._K.client.hotkeys.dashboard.callback()
		end,
	},
	{
		name = "log",
		aliases = { "logs", "chatlog", "chatlogs" },
		description = "Shows the logs in a separate window.",
		optionalPrefix = true,
		envClient = function(_K)
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
						if not window._instance.Visible and #_K.UI.Scope.dashboard then
							_K.UI.edit(_K.UI.Scope.dashboard.Tabs, {
								_K.UI.Scope.dashboard.Logs,
							})
						end
					end,
				},
			})
			return {
				window = window,
			}
		end,

		runClient = function(context)
			local visible = not context.env.window._instance.Visible
			context._K.UI.edit(context.env.window, {
				Visible = visible,
				if visible then context._K.UI.Scope.dashboard.Logs else nil,
			})
			if not context.env.init then
				context.env.window.Position:set(
					UDim2.fromOffset(
						math.floor(workspace.CurrentCamera.ViewportSize.X / 2) - 210,
						math.floor(workspace.CurrentCamera.ViewportSize.Y / 2) - 210
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
						if not window._instance.Visible and #_K.UI.Scope.dashboard then
							_K.UI.edit(_K.UI.Scope.dashboard.Tabs, {
								_K.UI.Scope.dashboard.Settings,
							})
						end
					end,
				},
			})
			return {
				window = window,
			}
		end,

		runClient = function(context)
			local visible = not context.env.window._instance.Visible
			context._K.UI.edit(context.env.window, {
				Visible = visible,
				if visible then context._K.UI.Scope.dashboard.Settings else nil,
			})
			if not context.env.init then
				context.env.window.Position:set(
					UDim2.fromOffset(
						math.floor(workspace.CurrentCamera.ViewportSize.X / 2) - 210,
						math.floor(workspace.CurrentCamera.ViewportSize.Y / 2) - 210
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

		run = function(context, player: Player)
			context._K.Remote.Notify:FireClient(
				context.fromPlayer,
				{ Text = `<b>Age:</b> {context._K.Util.ReadableTime(player.AccountAge * 86400)}`, From = player.UserId }
			)
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
		description = "Rejoins the place.",
		args = {},

		run = function(context)
			context._K.Util.SafeTeleport(game.PlaceId, { context.fromPlayer })
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
			local ok, samePlace, errorMessage, placeId, jobId = pcall(
				context._K.Util.Services.TeleportService.GetPlayerPlaceInstanceAsync,
				context._K.Util.Services.TeleportService,
				userId
			)
			if not ok then
				context._K.Remote.Notify:FireClient(context.fromPlayer, {
					From = "_K",
					Text = errorMessage or samePlace,
					TextColor3 = Color3.new(1, 0, 0),
					Sound = "Call_Leave",
				})
				return
			end
			if samePlace then
				context._K.Remote.Notify:FireClient(context.fromPlayer, {
					From = "_K",
					Text = "You're already in the same server!",
					TextColor3 = Color3.new(1, 0, 0),
					Sound = "Call_Leave",
				})
				return
			end

			if placeId and jobId then
				local options = Instance.new("TeleportOptions")
				options.ServerInstanceId = jobId
				context._K.Util.SafeTeleport(placeId, { context.fromPlayer }, options)
			end
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
	-- 			type = "stringGreedy",
	-- 			name = "Command string",
	-- 			description = "The command string to alias.",
	-- 		},
	-- 	},

	-- 	runClient = function(context, alias: string, command: string)
	-- 		context._K.Registry.registerCommandAlias(context._K, alias, command)
	-- 	end,
	-- },
}
