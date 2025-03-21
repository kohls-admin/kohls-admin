-- "non-abusive" commands for game staff members

local Players = game:GetService("Players")
local TextService = game:GetService("TextService")

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
			context._K.Remote.StartCountdown:FireAllClients()
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
						context._K.Remote.Notify:FireClient(player, { Text = msg, From = context.from })
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
		name = "countdown",
		aliases = { "cd" },
		description = "Starts a countdown.",
		args = {
			{
				type = "integer",
				name = "Duration",
				description = "The duration of the countdown, in seconds.",
				optional = true,
			},
		},
		envClient = function(_K)
			local countdown, progress
			_K.Remote.StartCountdown.OnClientEvent:Connect(function(start, duration)
				if countdown then
					countdown:Disconnect()
				end
				if progress then
					progress:Destroy()
				end
				if not start then
					return
				end

				local time = _K.UI.new "TextLabel" {
					Name = "Time",
					AnchorPoint = Vector2.new(0.5, 0.5),
					Size = UDim2.new(1, 0, 1, 0),
					BackgroundTransparency = 1,
					Position = UDim2.new(0.5, 0, 0.5, 0),
					Font = _K.UI.Theme.Font,
					TextSize = 100,
					TextColor3 = Color3.new(),
					TextStrokeColor3 = Color3.new(1, 1, 1),
					TextStrokeTransparency = 0.5,
					Text = duration,
					ZIndex = 2,
				}
				progress = _K.UI.new "CircleProgress" {
					Parent = _K.UI.LayerTopInset,
					Position = UDim2.fromOffset(math.floor(_K.UI.LayerTop.AbsoluteSize.X / 2) - 64, 0),
					Size = UDim2.new(0, 128, 0, 128),
					ZIndex = -1,
					time,
				}

				_K.UI.Sound.Hover02:Play()

				countdown = _K.Util.Services.RunService.Heartbeat:Connect(function()
					local delta = workspace:GetServerTimeNow() - start
					if delta > duration then
						countdown:Disconnect()
						progress:Destroy()
						_K.UI.Sound.Notification_High:Play()
						return
					end
					progress:setProgress(1 - math.clamp(delta / duration, 0, 1))
					local newText = tostring(math.clamp(math.floor(duration - delta) + 1, 0, duration))
					if newText ~= time.Text then
						_K.UI.Sound.Hover02:Play()
					end
					time.Text = newText
				end)
			end)
		end,
		env = function(_K)
			return { remote = _K.Remote.StartCountdown }
		end,

		run = function(context, duration)
			if duration then
				context.env.remote:FireAllClients(workspace:GetServerTimeNow(), math.min(duration, 120))
			else
				context.env.remote:FireAllClients()
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
					ExitButton = false,
					LeftAction = true,
					RightAction = true,
					Duration = 30,

					UserFrame = { from.UserId },

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

			context._K.Remote.Notify:FireClient(context.fromPlayer, {
				Text = `Created vote: <b>{message}</b>\n\n<font transparency="0.5"><i>The vote will end in 30 seconds or when every player has submitted their vote!</i></font>`,
			})

			-- wait for timeout or all votes to be submitted
			task.delay(30, coroutine.resume, mainThread)
			coroutine.yield()

			context._K.Remote.Notify:FireClient(context.fromPlayer, {
				Text = `<font transparency="0.5">The results are in!</font>\n\n<b>{message}</b>\n\t<font color="#0f0"><b><sc>yes</sc></b>\t{yes}</font>\n\t<font color="#f00"><b><sc>no</sc></b> \t{no}</font>`,
			})
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
				workspace.CurrentCamera.CameraType =
					workspace.CurrentCamera:GetAttribute("kCameraType") :: Enum.CameraType
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
		description = "Enables flight on one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to give flight.",
			},
			{
				type = "number",
				name = "Speed",
				description = "The flight speed, defaults to 256.",
				optional = true,
			},
		},

		run = function(context, players, speed)
			for _, player in players do
				if not player:GetAttribute("_KFly") then
					context._K.Remote.Notify:FireClient(player, { Text = `Double tap <b>jump</b> to toggle fly.` })
				end
				player:SetAttribute("_KNoclip", nil)
				player:SetAttribute("_KFly", if speed then speed else 256)
			end
		end,
	},
	{
		name = "unfly",
		description = "Disables flight on one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to remove flight from.",
			},
		},

		run = function(context, players)
			for _, player in players do
				player:SetAttribute("_KFly", nil)
				player:SetAttribute("_KNoclip", nil)
			end
		end,
	},

	{
		name = "noclip",
		description = "Disables collisions on one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) whose collisions to disable.",
			},
			{
				type = "number",
				name = "Speed",
				description = "The flight speed, defaults to 256.",
				optional = true,
			},
		},

		run = function(context, players, speed)
			for _, player in players do
				if not player:GetAttribute("_KDevCameraOcclusionMode") then
					player:SetAttribute("_KDevCameraOcclusionMode", player.DevCameraOcclusionMode)
					player.DevCameraOcclusionMode = Enum.DevCameraOcclusionMode.Invisicam
				end
				if not player:GetAttribute("_KNoclip") then
					context._K.Remote.Notify:FireClient(player, { Text = `Double tap <b>jump</b> to toggle noclip.` })
				end
				player:SetAttribute("_KFly", nil)
				player:SetAttribute("_KNoclip", if speed then speed else 256)
			end
		end,
	},
	{
		name = "clip",
		aliases = { "unnoclip" },
		description = "Disables noclip on one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to remove noclip from.",
			},
		},

		run = function(context, players)
			for _, player in players do
				local initialCameraMode = player:GetAttribute("_KDevCameraOcclusionMode")
				if initialCameraMode then
					player.DevCameraOcclusionMode = initialCameraMode
					player:SetAttribute("_KDevCameraOcclusionMode", nil)
				end
				player:SetAttribute("_KFly", nil)
				player:SetAttribute("_KNoclip", nil)
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
