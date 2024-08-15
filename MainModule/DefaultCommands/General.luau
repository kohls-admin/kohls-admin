-- "non-abusive" commands for game members

local Players = game:GetService("Players")
local TextService = game:GetService("TextService")

local noclipCache = {}

local spectateConnection

local function spectateCleanup(context)
	for subject, spectators in context._K.spectators do
		local found = table.find(spectators, context.fromPlayer)
		if found then
			table.remove(spectators, found)
			if #spectators == 0 then
				context._K.spectators[subject] = nil
				context._K.Remote.SpectateSubject:FireClient(subject)
			end
		end
	end
end

return {
	{ -- TODO: need to set up a way to set public logs
		name = "logs",
		aliases = { "chatlogs" },
		description = "Shows the logs in a separate window.",
		args = {},
		envClient = function(_K)
			local window = _K.UI.new "Window" {
				Parent = _K.UI.LayerTop,
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
			context._K.UI.edit(context.env.window, {
				Visible = true,
				context._K.UI.Scope.dashboard.Logs,
			})
		end,
	},
	{
		name = "message",
		aliases = { "m", "msg" },
		description = "Sends a message to everyone in the server.",
		args = {
			{
				type = "stringGreedy",
				name = "Message",
				description = "The message to send.",
			},
		},

		run = function(context, message)
			local ok, result = pcall(
				TextService.FilterStringAsync,
				TextService,
				message,
				context.from,
				Enum.TextFilterContext.PublicChat
			)

			if not ok then
				return
			end

			for _, player in Players:GetPlayers() do
				task.spawn(function()
					local success, msg = pcall(result.GetChatForUserAsync, result, player.UserId)
					if success then
						context._K.Remote.Announce:FireClient(player, msg, context.from)
					end
				end)
			end
		end,
	},
	{
		name = "notify",
		aliases = { "n" },
		description = "Sends a notification to one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to notify.",
			},
			{
				type = "stringGreedy",
				name = "Message",
				description = "The message to send.",
			},
		},

		run = function(context, players, message)
			local ok, result = pcall(
				TextService.FilterStringAsync,
				TextService,
				message,
				context.from,
				Enum.TextFilterContext.PublicChat
			)

			if not ok then
				return
			end

			for _, player in players do
				task.spawn(function()
					local success, msg = pcall(result.GetChatForUserAsync, result, player.UserId)
					if success then
						context._K.Remote.Notify:FireClient(player, msg, context.from)
					end
				end)
			end
		end,
	},
	{
		name = "privatemessage",
		aliases = { "pm", "pmsg" },
		description = "Sends a message to one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to message.",
			},
			{
				type = "stringGreedy",
				name = "Message",
				description = "The message to send.",
			},
		},

		run = function(context, message, players)
			local ok, result = pcall(
				TextService.FilterStringAsync,
				TextService,
				message,
				context.from,
				Enum.TextFilterContext.PublicChat
			)

			if not ok then
				return
			end

			for _, player in players do
				task.spawn(function()
					local success, msg = pcall(result.GetChatForUserAsync, result, player.UserId)
					if success then
						context._K.Remote.Announce:FireClient(player, msg, context.from)
					end
				end)
			end
		end,
	},
	{
		name = "follow",
		description = "Follows a player with your camera.",
		args = {
			{
				type = "player",
				name = "Player",
				description = "The player to follow.",
			},
		},

		runClient = function(context, player)
			if player.Character and player.Character:FindFirstChildOfClass("Humanoid") then
				workspace.CurrentCamera.CameraSubject = player.Character:FindFirstChildOfClass("Humanoid")
			end
		end,
	},
	{
		name = "spectate",
		aliases = { "spy", "watch" },
		description = "Spectate a player's point of view.",
		args = {
			{
				type = "player",
				name = "Player",
				description = "The player to spectate.",
				ignoreSelf = true,
			},
		},

		envClient = function(_K)
			local function spectateNetwork()
				_K.Remote.SpectateSubject:FireServer(workspace.CurrentCamera.CFrame)
			end

			_K.Remote.Spectate.OnClientEvent:Connect(function(cframe: CFrame)
				workspace.CurrentCamera.CFrame = cframe
			end)

			local spectateConnection
			_K.Remote.SpectateSubject.OnClientEvent:Connect(function(enabled: boolean)
				if spectateConnection then
					spectateConnection:Disconnect()
				end
				if enabled then
					spectateConnection = _K.Services.RunService.Heartbeat:Connect(spectateNetwork)
				end
			end)
		end,

		runClient = function(context, player)
			if not workspace.CurrentCamera:GetAttribute("kCameraType") then
				workspace.CurrentCamera:SetAttribute("kCameraType", workspace.CurrentCamera.CameraType)
				workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable
			end
			if player.Character and player.Character:FindFirstChildOfClass("Humanoid") then
				workspace.CurrentCamera.CameraSubject = player.Character:FindFirstChildOfClass("Humanoid")
			end
			if spectateConnection then
				spectateConnection:Disconnect()
			end
			spectateConnection = player.CharacterAdded:Connect(function()
				workspace.CurrentCamera.CameraSubject = player.Character:FindFirstChildOfClass("Humanoid")
			end)
		end,
		run = function(context, player)
			spectateCleanup(context)
			if not context._K.spectators[player] then
				context._K.spectators[player] = {}
			end
			context._K.Remote.SpectateSubject:FireClient(player, true)
			table.insert(context._K.spectators[player], context.fromPlayer)
		end,
	},
	{
		name = "unspectate",
		aliases = { "unspy", "unwatch", "unfollow" },
		description = "Stop spectating.",
		args = {},

		runClient = function(context)
			if workspace.CurrentCamera:GetAttribute("kCameraType") then
				workspace.CurrentCamera.CameraType = workspace.CurrentCamera:GetAttribute("kCameraType")
				workspace.CurrentCamera:SetAttribute("kCameraType", nil)
			end
			local character = context.fromPlayer.Character
			if character then
				workspace.CurrentCamera.CameraSubject = character:FindFirstChildOfClass("Humanoid")
			end
			if spectateConnection then
				spectateConnection:Disconnect()
				spectateConnection = nil
			end
		end,
		run = spectateCleanup,
	},
	{
		name = "fly",
		aliases = { "noclip" },
		description = "Enables flight and disables collisions on one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to give flight.",
			},
		},

		run = function(context, players)
			for _, player in players do
				if noclipCache[player] then
					continue
				end
				noclipCache[player] = player.DevCameraOcclusionMode
				player.DevCameraOcclusionMode = Enum.DevCameraOcclusionMode.Invisicam
				context._K.Remote.Noclip:FireClient(player, true)
			end
		end,
	},
	{
		name = "unfly",
		aliases = { "clip" },
		description = "Disables flight and enables collisions on one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to remove flight from.",
				shouldRequest = true,
			},
		},

		run = function(context, players)
			for _, player in players do
				if not noclipCache[player] then
					continue
				end
				player.DevCameraOcclusionMode = noclipCache[player]
				noclipCache[player] = nil
				context._K.Remote.Noclip:FireClient(player)
			end
		end,
	},
}
