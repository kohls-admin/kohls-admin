-- "non-abusive" commands for game members

local Players = game:GetService("Players")
local TextService = game:GetService("TextService")

local noclipCache = {}
local playingSound = nil

local spectateConnection
local function spectateCleanup(context)
	local spectatorCache = context._K.Flux.Scope.spectatorsCache
	for subject, spectators in spectatorCache do
		local found = table.find(spectators, context.fromPlayer)
		if found then
			table.remove(spectators, found)
			if #spectators == 0 then
				spectatorCache[subject] = nil
				context._K.Remote.SpectateSubject:FireClient(subject)
			end
		end
	end
end

return {
	{
		name = "clean",
		aliases = { "clear" },
		description = "Cleans up miscellaneous admin objects like cloned characters, looped commands, and scripts.",
		args = {},

		run = function(context)
			for _, object in context._K.cleanupCommands do
				local objectType = typeof(object)
				if objectType == "Instance" then
					object:Destroy()
				elseif objectType == "function" then
					object()
				end
			end
			local jailParts = context._K.Flux.Scope.Jail.Parts
			for index, jail in jailParts do
				if jail then
					jail:Destroy()
				end
			end
			table.clear(jailParts)
			context._K.Flux.Scope.discoCleanup()
		end,
	},
	{ -- TODO: need to set up a way to set public logs
		name = "logs",
		aliases = { "chatlogs" },
		description = "Shows the logs in a separate window.",
		args = {},
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
						context._K.Remote.Announce:FireClient(player, msg, context.from)
					end
				end)
			end
		end,
	},
	{
		name = "vote",
		aliases = { "makevote", "startvote", "poll" },
		description = "Starts a vote for one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to poll.",
			},
			{
				type = "stringGreedy",
				name = "Question",
				description = "The question to poll.",
			},
		},
		envClient = function(_K)
			_K.Remote.Vote.OnClientInvoke = function(text: string, from: Player)
				local actionSignal = _K.Util.Signal.new()
				_K.client.Notify({
					Text = text,
					ActionText = "<b>VOTE</b>",
					Action = true,
					LeftAction = true,
					RightAction = true,
					Duration = 30,

					_K.client.UserFrame(from.UserId, from.DisplayName),

					[_K.UI.Hook] = {
						Action = function(v)
							actionSignal:Fire(v)
						end,
					},
				})
				return actionSignal:Wait() == true
			end
		end,

		run = function(context, players, message)
			local ok, result = context._K.Util.Retry(function()
				return TextService:FilterStringAsync(message, context.from, Enum.TextFilterContext.PublicChat)
			end, 5, 0.2, 1)

			if not ok then
				return
			end

			local mainThread = coroutine.running()

			local yes, no, voting = 0, 0, 0
			for _, player in players do
				voting += 1
				task.spawn(function()
					local success, msg = pcall(result.GetChatForUserAsync, result, player.UserId)
					if success then
						local vote = context._K.Remote.Vote:InvokeClient(player, msg, context.fromPlayer)
						if vote == true then
							yes += 1
						elseif vote == false then
							no += 1
						end
					end
					voting -= 1
					if voting == 0 then
						coroutine.resume(mainThread)
					end
				end)
			end

			context._K.Remote.Notify:FireClient(
				context.fromPlayer,
				`Created vote: <b>{message}</b>\n\n<font transparency="0.5"><i>The vote will end in 30 seconds or when every player has submitted their vote!</i></font>`
			)

			-- wait for timeout or all votes to be submitted
			task.delay(30, coroutine.resume, mainThread)
			coroutine.yield()

			context._K.Remote.Notify:FireClient(
				context.fromPlayer,
				`<font transparency="0.5">The results are in!</font>\n\n<b>{message}</b>\n\t<font color="#0f0"><b><sc>yes</sc></b>\t{yes}</font>\n\t<font color="#f00"><b><sc>no</sc></b> \t{no}</font>`
			)
		end,
	},
	{
		name = "watch",
		aliases = { "camera", "follow" },
		description = "Watches a player with your camera.",
		args = {
			{
				type = "player",
				name = "Player",
				description = "The player to watch.",
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
		aliases = { "spy" },
		description = "Spectate a player's camera view.",
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

			_K.Remote.SpectateSubject.OnClientEvent:Connect(function(enabled: boolean)
				if spectateConnection then
					spectateConnection:Disconnect()
				end
				if enabled then
					spectateConnection = _K.Services.RunService.Heartbeat:Connect(spectateNetwork)
				end
			end)

			_K.Remote.Spectate.OnClientEvent:Connect(function(cframe: CFrame)
				_K.Util.Services.TweenService
					:Create(workspace.CurrentCamera, TweenInfo.new(0.1), {
						CFrame = cframe,
					})
					:Play()
			end)
		end,
		env = function(_K)
			local spectators = {}
			local spectateRemote = _K.Remote.Spectate
			_K.Flux.Scope.spectatorsCache = spectators
			_K.Remote.SpectateSubject.OnServerEvent:Connect(function(player: Player, cframe: CFrame)
				if not spectators[player] then
					return
				end
				for _, player in spectators[player] do
					spectateRemote:FireClient(player, cframe)
				end
			end)
			return {
				spectators = _K.Flux.Scope.spectatorsCache,
			}
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
			if not context.env.spectators[player] then
				context.env.spectators[player] = {}
			end
			context._K.Remote.SpectateSubject:FireClient(player, true)
			table.insert(context.env.spectators[player], context.fromPlayer)
		end,
	},
	{
		name = "unspectate",
		aliases = { "unspy", "unwatch", "uncamera", "unfollow" },
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
	{
		name = "xray",
		aliases = { "unxray", "wallhack", "walls" },
		description = "Show players through walls.",
		args = {},
		envClient = function(_K)
			local env = { xray = _K.Flux.state(false) }
			local function xrayCharacter(character)
				_K.Flux.new "Highlight" {
					Parent = character,
					Name = "_Kxray",
					Enabled = env.xray,
				}
			end
			local function xrayPlayer(player)
				if player == _K.UI.LocalPlayer then
					return
				end
				player.CharacterAdded:Connect(xrayCharacter)
				if player.Character then
					xrayCharacter(player.Character)
				end
			end
			_K.Util.SafePlayerAdded(xrayPlayer)
			return env
		end,

		runClient = function(context)
			context.env.xray:set(if context.alias == "unxray" then false else not context.env.xray._value)
		end,
	},

	{
		name = "play",
		aliases = { "music", "sound", "audio" },
		description = "Plays a sound.",
		args = {
			{
				type = "integer",
				name = "AssetId",
				description = "The asset identifier of the sound.",
			},
		},

		run = function(context, assetId)
			if playingSound then
				playingSound:Stop()
				playingSound:Destroy()
			end

			local sound = Instance.new("Sound")
			playingSound = sound
			sound.Name = "_KPlaySound"
			sound.SoundId = "rbxassetid://" .. assetId
			sound.Looped = true
			sound.Parent = workspace
			sound:Play()
		end,
	},
	{
		name = "pause",
		aliases = {},
		description = "Pauses the current sound.",
		args = {},

		run = function(context)
			if playingSound then
				playingSound:Pause()
			end
		end,
	},
	{
		name = "resume",
		aliases = {},
		description = "Resumes the current sound.",
		args = {},

		run = function(context)
			if playingSound then
				playingSound:Resume()
			end
		end,
	},
	{
		name = "stop",
		aliases = { "stopmusic" },
		description = "Stops the currently playing sound.",
		args = {},

		run = function(context)
			if playingSound then
				playingSound:Stop()
				playingSound:Destroy()
			end
		end,
	},
	{
		name = "pitch",
		aliases = {},
		description = "Changes the pitch of the currently playing sound.",
		args = {
			{
				type = "number",
				name = "Value",
				description = "The pitch value.",
			},
		},

		run = function(context, pitch)
			if playingSound then
				playingSound.Pitch = pitch
			end
		end,
	},
	{
		name = "volume",
		aliases = {},
		description = "Changes the volume of the currently playing sound.",
		args = {
			{
				type = "number",
				name = "Value",
				description = "The volume value.",
			},
		},

		run = function(context, volume)
			if playingSound then
				playingSound.Volume = volume
			end
		end,
	},
}
