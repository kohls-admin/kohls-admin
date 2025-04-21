-- dangerous moderation commands, but not the most dangerous of commands

local Jail = require(script.Jail)
local teleportCharacter = require(script.teleportCharacter)

return {
	{
		name = "bans",
		aliases = {},
		description = "Shows the bans in a separate window.",
		args = {},
		envClient = function(_K)
			local window = _K.UI.new "Window" {
				Parent = _K.UI.LayerTopInset,
				Title = "Kohl's Admin Bans",
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
								_K.client.dashboard.Bans,
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
				if visible then context._K.client.dashboard.Bans else nil,
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
		name = "members",
		aliases = { "admins", "roles" },
		description = "Shows the roled members in a separate window.",
		args = {},
		envClient = function(_K)
			local window = _K.UI.new "Window" {
				Parent = _K.UI.LayerTopInset,
				Title = "Kohl's Admin Members",
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
								_K.client.dashboard.Members,
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
				if visible then context._K.client.dashboard.Members else nil,
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
		name = "ban",
		description = "Bans one or more user(s) by UserId.",
		args = {
			{
				type = "userIds",
				name = "User(s)",
				description = "The Player(s) or UserId(s) to ban.",
				lowerRank = true,
				ignoreSelf = true,
			},
			{
				type = "timeSimple",
				name = "Duration",
				description = "The duration for the ban.",
				optional = true,
			},
			{
				type = "stringGreedy",
				name = "Reason",
				description = "The reason for the ban.",
				optional = true,
			},
		},

		run = function(context, userIds, duration: number?, reason: string?)
			if type(reason) == "string" then
				reason = string.sub(reason, 1, 400) -- banasync limit
			end

			if not context._K.Auth.hasPermission(context.from, "banasync") then
				duration = 0
			end

			local term = if not duration or duration == 0
				then "Session"
				elseif duration == -1 then "Permanently"
				else context._K.Util.ReadableTime(duration)

			local players = context._K.Services.Players:GetPlayers()
			for _, userId in userIds do
				for _, player in players do
					if player.UserId == tonumber(userId) then
						player:Kick(reason or "No reason.")
					end
				end
				task.spawn(context._K.Auth.userBan, userId, reason, duration, context.from, nil, true)
				task.defer(function()
					context._K.Remote.Notify:FireClient(context.fromPlayer, {
						Text = `Banned <b>{context._K.Util.getUserInfo(userId).Username}</b> for <b>{reason or "no reason"}</b>.\nDuration: <b>{term}</b>`,
					})
				end)
			end

			if duration and duration ~= 0 then
				local ok, err = pcall(context._K.Services.Players.BanAsync, context._K.Services.Players, {
					UserIds = userIds,
					PrivateReason = reason or "No reason.",
					DisplayReason = reason or "No reason.",
					Duration = duration,
					ApplyToUniverse = true,
				})
				if not (ok or string.find(err, "NOT_FOUND")) then
					error(err, 1)
				end
			end
		end,
	},
	{
		name = "unban",
		description = "Unbans one or more player(s).",
		args = {
			{
				type = "bans",
				name = "Player(s)",
				description = "The player(s) to unban.",
			},
		},

		run = function(context, bans)
			local ids = table.create(#bans)
			-- need to somehow display only session bans in suggestions...

			for i, userId in bans do
				context._K.Data.bans[userId] = nil

				if context._K.Auth.hasPermission(context.from, "banasync") then
					context._K.Auth.userUnban(userId, context.from, true)
					table.insert(ids, tonumber(userId))
				end
			end

			if #ids > 0 then
				local ok, err = pcall(
					context._K.Services.Players.UnbanAsync,
					context._K.Services.Players,
					{ UserIds = ids, ApplyToUniverse = true }
				)
				if not ok and not string.find(err, "NOT_FOUND") then
					error(err, 1)
				end
			end
			context._K.Remote.Notify:FireClient(
				context.fromPlayer,
				{ Text = `<b>Unbanned:</b> <i>{table.concat(bans, ", ")}</i>` }
			)
		end,
	},
	{
		name = "kick",
		description = "Kicks one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to kick.",
				ignoreSelf = true,
				lowerRank = true,
			},
			{
				type = "stringGreedy",
				name = "Reason",
				description = "The reason for the kick.",
				optional = true,
			},
		},
		run = function(context, players, reason: string?)
			for _, player in players do
				player:Kick(reason)
			end
			local names = context._K.Util.Suggest.getNames(players)
			context._K.Remote.Notify:FireClient(
				context.fromPlayer,
				{ Text = `<b>Kicked:</b> <i>{table.concat(names, ", ")}</i>` }
			)
		end,
	},
	{
		name = "mute",
		aliases = { "shh", "silence" },
		description = "Mutes one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to mute.",
				ignoreSelf = false,
				lowerRank = true,
			},
		},
		envClient = function(_K)
			_K.Remote.Mute.OnClientEvent:Connect(function(muted)
				local muteText = if muted then "muted" else "unmuted"
				if _K.Util.Services.TextChatService.ChatVersion == Enum.ChatVersion.LegacyChatService then
					_K.Util.Services.StarterGui:SetCore("ChatBarDisabled", muted)
					_K.Util.Services.StarterGui:SetCore("ChatMakeSystemMessage", {
						Text = `You have been {muteText}!`,
						Color = if muted then Color3.new(1, 0, 0) else Color3.new(0, 1, 0),
					})
				else
					local chatbar = _K.Util.Services.TextChatService:FindFirstChildOfClass("ChatInputBarConfiguration")
					if chatbar then
						chatbar.Enabled = not muted
					end
					local channels = _K.Util.Services.TextChatService:FindFirstChild("TextChannels")
					if not channels then
						return
					end
					local system = channels:FindFirstChild("RBXSystem")
					system:DisplaySystemMessage(
						`<font color="#{if muted then "f00" else "0f0"}"><b>You have been {muteText}!</b></font>`
					)
				end
			end)
		end,
		env = function(_K)
			local muted = {}
			_K.Util.Services.TextChatService.DescendantAdded:Connect(function(descendant)
				if descendant:IsA("TextSource") then
					if muted[descendant.UserId] then
						descendant.CanSend = false
					end
				end
			end)

			_K.Data.muted = muted
			return { muted = muted, remote = _K.Remote.Mute }
		end,
		run = function(context, players)
			for _, player in players do
				local con = context._K.Data.muted[player.UserId]
				if con then
					con:Disconnect()
				end

				context.env.remote:FireClient(player, true)

				context.env.muted[player.UserId] = context._K.Util.Services.TextChatService.DescendantAdded:Connect(
					function(descendant)
						if
							descendant:IsA("TextSource")
							and descendant.UserId == player.UserId
							and descendant.CanSend
						then
							descendant:SetAttribute("_KCouldSend", true)
							descendant.CanSend = false
						end
					end
				)

				for _, descendant in context._K.Util.Services.TextChatService:GetDescendants() do
					if descendant:IsA("TextSource") and descendant.UserId == player.UserId and descendant.CanSend then
						descendant:SetAttribute("_KCouldSend", true)
						descendant.CanSend = false
					end
				end
			end
			local names = context._K.Util.Suggest.getNames(players)
			context._K.Remote.Notify:FireClient(
				context.fromPlayer,
				{ Text = `<b>Muted:</b> <i>{table.concat(names, ", ")}</i>` }
			)
		end,
	},
	{
		name = "unmute",
		aliases = { "unshh", "unsilence" },
		description = "Unmutes one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to unmute.",
				ignoreSelf = false,
				lowerRank = true,
			},
		},

		run = function(context, players)
			for _, player in players do
				local con = context._K.Data.muted[player.UserId]
				if con then
					con:Disconnect()
				end
				context._K.Data.muted[player.UserId] = nil

				for _, descendant in context._K.Util.Services.TextChatService:GetDescendants() do
					if
						descendant:IsA("TextSource")
						and descendant.UserId == player.UserId
						and descendant:GetAttribute("_KCouldSend")
					then
						descendant:SetAttribute("_KCouldSend", nil)
						descendant.CanSend = true
					end
				end

				context._K.Remote.Mute:FireClient(player)
			end
			local names = context._K.Util.Suggest.getNames(players)
			context._K.Remote.Notify:FireClient(
				context.fromPlayer,
				{ Text = `<b>Unmuted:</b> <i>{table.concat(names, ", ")}</i>` }
			)
		end,
	},
	{
		name = "punish",
		aliases = {},
		description = "Punishes one or more player(s) to the void.",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to punish.",
				shouldRequest = true,
			},
		},
		env = function(_K)
			return { punished = {} }
		end,

		run = function(context, players)
			for _, player in players do
				if player.Character then
					context.env.punished[player.UserId] = player.Character
					player.Character.Parent = nil
					player.Character = nil
				end
			end
		end,
	},
	{
		name = "unpunish",
		aliases = {},
		description = "Unpunishes one or more player(s) from the void.",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to forgive.",
			},
		},
		envClient = function(_K)
			local function reactivate(script)
				script.Enabled = true
			end
			_K.Remote.RefreshLocalScripts.OnClientEvent:Connect(function(model: Model)
				for _, descendant in model:GetDescendants() do
					if descendant:IsA("LocalScript") and descendant.Enabled then
						descendant.Enabled = false
						task.defer(reactivate, descendant)
					end
				end
			end)
		end,
		env = function(_K)
			return {
				remote = _K.Remote.RefreshLocalScripts,
			}
		end,

		run = function(context, players)
			local punished = context._K.Registry.commands.punish.env.punished
			for _, player in players do
				local character = punished[player.UserId]
				if character then
					punished[player.UserId] = nil
					character.Parent = workspace
					player.Character = character
					context.env.remote:FireClient(player, character)
				end
			end
		end,
	},
	{
		name = "name",
		aliases = { "nickname", "displayname", "unname" },
		description = "Changes the DisplayName of one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) whose DisplayName to change.",
			},
			{
				type = "stringGreedy",
				name = "DisplayName",
				description = "The DisplayName string to use.",
				optional = true,
			},
		},
		envClient = function(_K)
			local display
			_K.Remote.DisplayName.OnClientEvent:Connect(function(name)
				local character = _K.UI.LocalPlayer.Character
				local head = character and character:FindFirstChild("Head")
				if head then
					if not name then
						if display then
							display:Destroy()
						end
						return
					end
					if not display then
						display = Instance.new("Model")
						local humanoid = Instance.new("Humanoid")
						humanoid.Parent = display
						local fakeHead = Instance.new("Part")
						fakeHead.Name = "Head"
						fakeHead.CanQuery = false
						fakeHead.CanTouch = false
						fakeHead.Massless = true
						fakeHead.Size = Vector3.zero
						fakeHead.Parent = display
						local mesh = Instance.new("SpecialMesh")
						mesh.MeshType = Enum.MeshType.Brick
						mesh.Scale = Vector3.zero
						mesh.Parent = fakeHead
						local weld = Instance.new("Weld")
						weld.Part0 = head
						weld.Part1 = fakeHead
						weld.Parent = fakeHead
						display.Parent = character
					end
					display.Name = name
				end
			end)
		end,
		env = function(_K)
			local displayNames = {}
			_K.Util.SafePlayerAdded(function(player)
				player.CharacterAdded:Connect(function(character)
					local name = displayNames[player.UserId]
					if not name then
						return
					end
					character:FindFirstChildOfClass("Humanoid").DisplayName = name
					_K.Remote.DisplayName:FireClient(player, name)
				end)
			end)

			return {
				displayNames = displayNames,
				remote = _K.Remote.DisplayName,
			}
		end,

		run = function(context, players, displayName)
			for _, player in players do
				context.env[player.UserId] = displayName
				local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
				if humanoid then
					humanoid.DisplayName = displayName or player.DisplayName
					context._K.Remote.DisplayName:FireClient(player, displayName)
				end
			end
		end,
	},
	{
		name = "hidename",
		aliases = {},
		description = "Hides the character name of one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) whose name to hide.",
			},
		},

		run = function(context, players)
			for _, player in players do
				local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
				if humanoid then
					humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
				end
			end
		end,
	},
	{
		name = "showname",
		aliases = {},
		description = "Shows the character name of one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) whose name to show.",
				shouldRequest = true,
			},
		},

		run = function(context, players)
			for _, player in players do
				local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
				if humanoid then
					humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
				end
			end
		end,
	},
	{
		name = "toolban",
		aliases = { "bantools" },
		description = "Bans one or more player(s) from using tools.",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to ban from using tools.",
				lowerRank = true,
			},
		},
		env = function(_K)
			return {
				bans = {},
				removeTool = function(tool: Instance)
					if tool:IsA("Tool") or tool:IsA("HopperBin") then
						task.defer(tool.Destroy, tool)
					end
				end,
				removeTools = function(source: Instance)
					if not source then
						return
					end
					for _, tool in source:GetChildren() do
						if tool:IsA("Tool") or tool:IsA("HopperBin") then
							task.spawn(tool.Destroy, tool)
						end
					end
				end,
			}
		end,

		run = function(context, players)
			for _, player in players do
				if context.env.bans[player] then
					return
				end
				local backpack = player:FindFirstChildOfClass("Backpack")
				if backpack then
					context.env.bans[player] = backpack.ChildAdded:Connect(context.env.removeTool)
					context.env.removeTools(backpack)
				end
				context.env.removeTools(player.Character)
			end
		end,
	},
	{
		name = "untoolban",
		aliases = { "unbantools" },
		description = "Unbans one or more player(s) from using tools.",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to unban from using tools.",
				lowerRank = true,
			},
		},

		run = function(context, players)
			local toolBans = context._K.Registry.commands.toolban.env.bans
			for _, player in players do
				local toolBan = toolBans[player]
				if toolBan then
					toolBan:Disconnect()
					toolBans[player] = nil
				end
			end
		end,
	},
	{
		name = "give",
		description = "Gives a tool to one or more player(s).\nTools must be a descendant of <b>Lighting</b> or <b>ServerStorage</b>.",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to give the tools.",
			},
			{
				type = "tools",
				name = "Tools",
				description = "The tools to give.",
			},
		},

		run = function(context, players, tools)
			for _, player in players do
				local destination = player:FindFirstChildOfClass("Backpack")
				if destination then
					for _, tool in tools do
						tool:Clone().Parent = destination
					end
				end
			end
		end,
	},
	{
		name = "copytools",
		aliases = { "ctools" },
		description = "Copies tools from one or more player(s) to one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) whose tools to copy.",
			},
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to give the copied tools.",
			},
		},

		run = function(context, fromPlayers, toPlayers)
			for _, fromPlayer in fromPlayers do
				local tools = {}
				local fromBackpack = fromPlayer:FindFirstChildOfClass("Backpack")
				if fromBackpack then
					for _, descendant in fromBackpack:GetChildren() do
						if descendant:IsA("Tool") or descendant:IsA("HopperBin") then
							table.insert(tools, descendant)
						end
					end
				end
				if fromPlayer.Character then
					for _, descendant in fromPlayer.Character:GetChildren() do
						if descendant:IsA("Tool") or descendant:IsA("HopperBin") then
							table.insert(tools, descendant)
						end
					end
				end
				if #tools == 0 then
					continue
				end
				for _, toPlayer in toPlayers do
					local toBackpack = toPlayer:FindFirstChildOfClass("Backpack")
					if toBackpack then
						for _, tool in tools do
							tool:Clone().Parent = toBackpack
						end
					end
				end
			end
		end,
	},
	{
		name = "removetools",
		aliases = { "rtools" },
		description = "Removes all tools from one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to remove tools from.",
			},
		},
		env = function(_K)
			return {
				removeTools = function(source: Instance)
					if not source then
						return
					end
					for _, tool in source:GetChildren() do
						if tool:IsA("Tool") or tool:IsA("HopperBin") then
							task.spawn(tool.Destroy, tool)
						end
					end
				end,
			}
		end,

		run = function(context, players)
			for _, player in players do
				context.env.removeTools(player:FindFirstChildOfClass("Backpack"))
				context.env.removeTools(player:FindFirstChildOfClass("StarterGear"))
				context.env.removeTools(player.Character)
			end
		end,
	},
	{
		name = "tools",
		aliases = { "toollist" },
		description = "Views all tools usable with the give command.",

		runClient = function(context, player)
			if #context._K.tools <= 1 then
				context._K.Notify({ Text = `No tools found!` })
				return
			end
			local toolNames = {}
			for _, tool in context._K.tools do
				if tool.Name == "all" then
					continue
				end
				table.insert(toolNames, tool.Name)
			end
			table.sort(toolNames)

			local UI = context._K.UI
			UI.new "Window" {
				Parent = UI.LayerTopInset,
				Title = "Kohl's Admin Tools",
				Exitable = true,
				RemoveOnClose = true,
				Position = UDim2.new(0.5, -128, 0.5, -128),
				Size = UDim2.new(0, 256, 0, 256),

				UI.new "Scroller" {
					UI.new "UIFlexItem" {
						FlexMode = Enum.UIFlexMode.Fill,
					},
					UI.new "TextLabel" {
						AutoLocalize = false,
						Name = "Text",
						BackgroundTransparency = 1,
						TextColor3 = UI.Theme.PrimaryText,
						Text = table.concat(toolNames, "\n"),
						TextSize = UI.Theme.FontSize,
						TextWrapped = true,
						TextXAlignment = "Left",
						Font = UI.Theme.Font,
						RichText = true,
						Size = UDim2.new(1, 0, 0, 0),

						AutomaticSize = Enum.AutomaticSize.Y,
					},
				},
			}
		end,
	},
	{
		name = "viewtools",
		aliases = { "vtools" },
		description = "Views all tools from a player.",
		args = {
			{
				type = "player",
				name = "Player",
				description = "The player whose tools to view.",
			},
		},
		envClient = function(_K)
			return {
				addTools = function(source: Instance, tools)
					if not source then
						return
					end
					for _, tool in source:GetChildren() do
						if tool:IsA("Tool") or tool:IsA("HopperBin") then
							table.insert(tools, tool.Name)
						end
					end
				end,
			}
		end,

		runClient = function(context, player)
			local toolNames = {}
			context.env.addTools(player:FindFirstChildOfClass("Backpack"), toolNames)
			context.env.addTools(player.Character, toolNames)
			if #toolNames == 0 then
				context._K.Notify({ Text = `No tools found!` })
				return
			end
			table.sort(toolNames)

			local UI = context._K.UI
			UI.new "Window" {
				Parent = UI.LayerTopInset,
				Title = player.Name .. "'s Tools",
				Exitable = true,
				RemoveOnClose = true,
				Position = UDim2.new(0.5, -128, 0.5, -128),
				Size = UDim2.new(0, 256, 0, 256),

				UI.new "Scroller" {
					UI.new "UIFlexItem" {
						FlexMode = Enum.UIFlexMode.Fill,
					},
					UI.new "TextLabel" {
						AutoLocalize = false,
						Name = "Text",
						BackgroundTransparency = 1,
						TextColor3 = UI.Theme.PrimaryText,
						Text = table.concat(toolNames, "\n"),
						TextSize = UI.Theme.FontSize,
						TextWrapped = true,
						TextXAlignment = "Left",
						Font = UI.Theme.Font,
						RichText = true,
						Size = UDim2.new(1, 0, 0, 0),

						AutomaticSize = Enum.AutomaticSize.Y,
					},
				},
			}
		end,
	},
	{
		name = "sword",
		credit = { "Luckymaxer", "EUROCOW", "StarWars", "TakeoHonorable", "Kohl @Scripth" },
		description = "Gives a sword to one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to give a sword.",
			},
		},
		env = function(_K)
			local env = {}

			task.defer(function()
				local sword = _K.Services.InsertService:LoadAsset(47433):FindFirstChildOfClass("Tool")
				if not sword then
					warn(`Sword failed to load, sword command won't work!`)
				end
				env.sword = sword
			end)

			return env
		end,

		run = function(context, players)
			for _, player in players do
				if not (player.Character and player:FindFirstChild("Backpack")) then
					continue
				end
				context.env.sword:Clone().Parent = player.Backpack
			end
		end,
	},
	{
		name = "kill",
		aliases = { "unalive", "💀" },
		description = "Kills one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to kill.",
				shouldRequest = true,
			},
		},
		run = function(context, players)
			for _, player in players do
				if player.Character then
					local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
					if not humanoid then
						continue
					end
					humanoid.MaxHealth = math.max(1, humanoid.MaxHealth)
					humanoid.Health = 0
				end
			end
		end,
	},
	{
		name = "loopkill",
		credit = { "SkellyLua" },
		aliases = { "loopunalive", "loop💀", "unloopkill", "unloopunalive", "unloop💀" },
		description = "Kills one or more player(s) repeatedly.",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to kill repeatedly.",
				shouldRequest = true,
			},
		},
		env = function(_K)
			local loopKillList = {}

			local function loopKillCheck(player)
				if loopKillList[player.UserId] and player.Character then
					local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
					if humanoid then
						humanoid.MaxHealth = math.max(1, humanoid.MaxHealth)
						humanoid.Health = 0
					end
				end
			end

			task.spawn(function()
				repeat
					task.wait(1)
					for userId in loopKillList do
						local player = _K.Util.Services.Players:GetPlayerByUserId(userId)
						if player and player.Character then
							loopKillCheck(player)
						end
					end
				until nil
			end)

			return {
				loopKillList = loopKillList,
				loopKillCheck = loopKillCheck,
			}
		end,
		run = function(context, players)
			for _, player in players do
				context.env.loopKillList[player.UserId] = if context.undo then nil else true
			end
		end,
	},
	{
		name = "hurt",
		aliases = { "damage" },
		description = "Damages one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to hurt.",
				shouldRequest = true,
			},
			{
				type = "number",
				name = "Damage",
				description = "The damage to deal to their health.",
			},
		},

		run = function(context, players, health)
			for _, player in players do
				local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
				if humanoid then
					humanoid:TakeDamage(health)
				end
			end
		end,
	},
	{
		name = "health",
		aliases = { "maxhealth" },
		description = "Changes the maximum health one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) whose health to change.",
			},
			{
				type = "number",
				name = "Max Health",
				description = "The new maximum health.",
			},
		},

		run = function(context, players, health)
			health = math.max(1, health)
			for _, player in players do
				local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
				if humanoid then
					humanoid.MaxHealth = health
					humanoid.Health = health
				end
			end
		end,
	},
	{
		name = "heal",
		description = "Heals one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to heal.",
			},
		},

		run = function(context, players)
			for _, player in players do
				local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
				if humanoid then
					humanoid.Health = humanoid.MaxHealth
				end
			end
		end,
	},
	{
		name = "immortal",
		aliases = { "god" },
		description = "Makes one or more player(s) invincible.",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to make invincible.",
			},
		},

		run = function(context, players)
			for _, player in players do
				if not player.Character then
					continue
				end

				local existing = player.Character:FindFirstChild("_Kff")
				if existing then
					existing.Visible = false
				else
					local ff = Instance.new("ForceField")
					ff.Name = "_Kff"
					ff.Visible = false
					ff.Parent = player.Character
				end

				local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
				if humanoid then
					if not humanoid:GetAttribute("_KMaxHealth") then
						humanoid:SetAttribute("_KMaxHealth", humanoid.MaxHealth)
					end
					humanoid.MaxHealth = math.huge
					humanoid.Health = math.huge
				end
			end
		end,
	},
	{
		name = "forcefield",
		aliases = { "ff" },
		description = "Gives a ForceField to one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to protect.",
			},
		},

		run = function(context, players)
			for _, player in players do
				if not player.Character then
					continue
				end
				local existing = player.Character:FindFirstChild("_Kff")
				if existing then
					existing.Visible = true
				else
					local ff = Instance.new("ForceField")
					ff.Name = "_Kff"
					ff.Parent = player.Character
				end
			end
		end,
	},
	{
		name = "unforcefield",
		aliases = { "unff", "ungod", "mortal" },
		description = "Removes a ForceField from one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to remove a ForceField from.",
				shouldRequest = true,
			},
		},

		run = function(context, players)
			local ungod = context.alias == "ungod" or context.alias == "mortal"
			for _, player in players do
				if player.Character then
					for _, child in player.Character:GetChildren() do
						if child:IsA("ForceField") then
							child:Destroy()
						end
					end

					if not ungod then
						continue
					end

					local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
					if humanoid then
						local oldHealth = humanoid:GetAttribute("_KMaxHealth")
						if oldHealth then
							humanoid.MaxHealth = oldHealth
							humanoid.Health = oldHealth
						end
					end
				end
			end
		end,
	},
	{
		name = "invisible",
		aliases = { "inv" },
		description = "Makes one or more player(s) invisible.",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to make invisible.",
			},
		},

		run = function(context, players)
			for _, player in players do
				if not player.Character then
					continue
				end
				for _, child in player.Character:GetDescendants() do
					if
						(child:IsA("BasePart") or child:IsA("Decal") or child:IsA("Texture"))
						and not child:GetAttribute("kTransparency")
					then
						child:SetAttribute("kTransparency", child.Transparency)
						child.Transparency = 1
					elseif
						(
							child:IsA("Light")
							or child:IsA("Beam")
							or child:IsA("Trail")
							or child:IsA("ParticleEmitter")
							or child:IsA("Fire")
							or child:IsA("Smoke")
							or child:IsA("Sparkles")
							or child:IsA("SurfaceGui")
						) and not child:GetAttribute("kEnabled")
					then
						child:SetAttribute("kEnabled", child.Enabled)
						child.Enabled = false
					end
				end
			end
		end,
	},
	{
		name = "visible",
		aliases = { "vis" },
		description = "Makes one or more player(s) visible.",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to make visible.",
				shouldRequest = true,
			},
		},

		run = function(context, players)
			for _, player in players do
				if not player.Character then
					continue
				end
				for _, child in player.Character:GetDescendants() do
					local kTransparency = child:GetAttribute("kTransparency")
					local kEnabled = child:GetAttribute("kEnabled")
					if kTransparency then
						child:SetAttribute("kTransparency", nil)
						child.Transparency = kTransparency
					elseif kEnabled then
						child:SetAttribute("kEnabled", nil)
						child.Enabled = kEnabled
					end
				end
			end
		end,
	},

	{
		name = "blind",
		description = "Blinds one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to blind.",
			},
		},
		env = function(_K)
			return { remote = _K.Remote.Blind }
		end,
		envClient = function(_K)
			local blind = _K.UI.new "Frame" {
				Parent = _K.UI.LayerTop,
				BackgroundColor3 = Color3.new(),
				Size = UDim2.fromScale(1, 1),
				ZIndex = -100,
				Visible = false,
			}
			_K.Remote.Blind.OnClientEvent:Connect(function(blinded)
				blind.Visible = if blinded then true else false
			end)
			return { frame = blind }
		end,

		run = function(context, players)
			for _, player in players do
				context._K.Remote.Blind:FireClient(player, true)
			end
		end,
	},
	{
		name = "unblind",
		description = "Unblinds one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to unblind.",
			},
		},

		run = function(context, players)
			for _, player in players do
				context._K.Remote.Blind:FireClient(player)
			end
		end,
	},
	{
		name = "freeze",
		aliases = { "anchor", "ice" },
		description = "Freezes one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to freeze.",
				shouldRequest = true,
			},
		},

		run = function(context, players)
			for _, player in players do
				if not player.Character then
					continue
				end
				for _, descendant in player.Character:GetDescendants() do
					if descendant:IsA("BasePart") then
						descendant.Anchored = true
					end
				end
				if context.alias == "anchor" or player.Character:FindFirstChild("kFreeze") then
					continue
				end
				local orientation, size = player.Character:GetBoundingBox()
				local kFreeze = Instance.new("Part")
				kFreeze.Name = "kFreeze"
				kFreeze.Anchored = true
				kFreeze.CFrame = orientation
				kFreeze.Reflectance = 1
				kFreeze.Transparency = 0.3
				kFreeze.Size = size + Vector3.new(2, 2, 2)
				kFreeze.Color = Color3.fromHex("#8bf")
				kFreeze.Material = Enum.Material.Ice
				kFreeze.TopSurface = Enum.SurfaceType.Smooth
				kFreeze.BottomSurface = Enum.SurfaceType.Smooth
				kFreeze.Parent = player.Character
			end
		end,
	},
	{
		name = "thaw",
		aliases = { "unfreeze", "unanchor", "unice" },
		description = "Thaws one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to thaw.",
			},
		},

		run = function(context, players)
			for _, player in players do
				if not player.Character then
					continue
				end
				local kFreeze = player.Character:FindFirstChild("kFreeze")
				if kFreeze then
					kFreeze:Destroy()
				end
				for _, descendant in player.Character:GetDescendants() do
					if descendant:IsA("BasePart") then
						descendant.Anchored = false
					end
				end
			end
		end,
	},
	{
		name = "jail",
		aliases = {},
		description = "Jails one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to jail.",
				shouldRequest = true,
			},
		},
		env = function(_K)
			return Jail
		end,

		run = function(context, players)
			for _, player in players do
				if Jail.parts[player.UserId] then
					continue
				end
				if player.Character then
					Jail.new(player)
				end
			end
		end,
	},
	{
		name = "unjail",
		aliases = {},
		description = "Frees one or more player(s) from jail.",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to release.",
			},
		},

		run = function(context, players)
			for _, player in players do
				Jail.users[player.UserId] = nil
				local jail = Jail.parts[player.UserId]
				if jail then
					Jail.parts[player.UserId] = nil
					jail:Destroy()
				end
			end
		end,
	},
	{
		name = "fps",
		aliases = { "lag", "unlag", "unfps" },
		description = "Limits the frames per second of one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) whose frames per second to limit.",
				shouldRequest = true,
			},
			{
				type = "number",
				name = "FPS",
				description = "The frames per second limit.",
				optional = true,
			},
		},
		envClient = function(_K)
			local limitTime = 0
			_K.Remote.FPS.OnClientEvent:Connect(function(fps: number?)
				fps = fps or 32
				local t = tick()
				limitTime = t

				while t == limitTime and _K.UI.LocalPlayer:GetAttribute("_KFPSLimit") do
					local nextStep = tick() + (1 / fps :: number)
					repeat
					until tick() > nextStep
					task.wait()
				end
			end)
		end,
		env = function(_K)
			return { remote = _K.Remote.FPS }
		end,

		run = function(context, players, fps)
			local undo = context.undo or (not fps and context.alias == "fps")
			for _, player in players do
				if undo then
					player:SetAttribute("_KFPSLimit", nil)
					continue
				end
				player:SetAttribute("_KFPSLimit", true)
				context.env.remote:FireClient(player, fps)
			end
		end,
	},
	{
		name = "lock",
		description = "Locks the character of one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to lock.",
			},
		},

		run = function(context, players)
			for _, player in players do
				for _, descendant in player.Character:GetDescendants() do
					if descendant:IsA("BasePart") then
						descendant.Locked = true
					end
				end
			end
		end,
	},
	{
		name = "unlock",
		description = "Unlocks the character of one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to unlock.",
				shouldRequest = true,
			},
		},

		run = function(context, players)
			for _, player in players do
				for _, descendant in player.Character:GetDescendants() do
					if descendant:IsA("BasePart") then
						descendant.Locked = false
					end
				end
			end
		end,
	},

	{
		name = "stun",
		aliases = { "disable" },
		description = "Stuns one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to stun.",
				shouldRequest = true,
			},
		},

		run = function(context, players)
			for _, player in players do
				if player.Character and player.Character:FindFirstChildOfClass("Humanoid") then
					player.Character:FindFirstChildOfClass("Humanoid").PlatformStand = true
				end
			end
		end,
	},
	{
		name = "unstun",
		aliases = { "undisable", "enable" },
		description = "Removes stun from one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to remove the stun from.",
			},
		},

		run = function(context, players)
			for _, player in players do
				if player.Character and player.Character:FindFirstChildOfClass("Humanoid") then
					player.Character:FindFirstChildOfClass("Humanoid").PlatformStand = false
				end
			end
		end,
	},

	{
		name = "bring",
		aliases = {},
		description = "Teleports one or more player(s) to you.",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to bring.",
				shouldRequest = true,
			},
		},

		run = function(context, players)
			for _, player in players do
				if player == context.fromPlayer then
					continue
				end
				teleportCharacter(player.Character, context.fromPlayer.Character)
			end
		end,
	},
	{
		name = "to",
		aliases = { "goto" },
		description = "Teleports to a player.",
		args = {
			{
				type = "player",
				name = "Player",
				description = "The player to teleport to.",
			},
		},

		run = function(context, player)
			teleportCharacter(context.fromPlayer.Character, player.Character)
		end,
	},
	{
		name = "tp",
		aliases = { "teleport" },
		description = "Teleports one or more player(s) to another player.",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to teleport.",
				shouldRequest = true,
			},
			{
				type = "player",
				name = "Player",
				description = "The player to teleport to.",
			},
		},
		envClient = function(_K)
			_K.Remote.Teleport.OnClientEvent:Connect(function(cframe)
				local character = _K.UI.LocalPlayer.Character
				if character then
					character:PivotTo(cframe)
				end
			end)
		end,

		run = function(context, players, target)
			for _, player in players do
				teleportCharacter(player.Character, target.Character)
			end
		end,
	},

	{
		name = "fov",
		aliases = { "unfov", "resetfov" },
		description = "Changes the field of view of one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) whose field of view to change.",
				shouldRequest = true,
			},
			{
				type = "number",
				name = "Degrees",
				description = "The field of view in degrees.",
				optional = true,
			},
		},
		envClient = function(_K)
			local last
			_K.Remote.FOV.OnClientEvent:Connect(function(degrees)
				if degrees and not last then
					last = workspace.CurrentCamera.FieldOfView
				end
				if degrees or last then
					workspace.CurrentCamera.FieldOfView = math.clamp(degrees or last, 1, 120)
					if not degrees then
						last = nil
					end
				end
			end)
			return true
		end,
		env = function(_K)
			return {
				remote = _K.Remote.FOV,
			}
		end,

		run = function(context, players, degrees)
			for _, player in players do
				context.env.remote:FireClient(player, if degrees == nil then nil else degrees)
			end
		end,
	},
	{
		name = "jump",
		description = "Makes one or more player(s) jump.",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) who will jump.",
				shouldRequest = true,
			},
		},

		run = function(context, players)
			for _, player in players do
				if player.Character and player.Character:FindFirstChildOfClass("Humanoid") then
					player.Character:FindFirstChildOfClass("Humanoid").Jump = true
				end
			end
		end,
	},
	{
		name = "jumppower",
		description = "Changes the jump power of one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) whose jump power to change.",
			},
			{
				type = "number",
				name = "JumpPower",
				description = "The jump power to use.",
			},
		},

		run = function(context, players, jumpPower)
			for _, player in players do
				if player.Character and player.Character:FindFirstChildOfClass("Humanoid") then
					player.Character:FindFirstChildOfClass("Humanoid").JumpPower = jumpPower
				end
			end
		end,
	},
	{
		name = "starterjumppower",
		description = "Changes the jump power of one or more player(s) when they spawn.",
		args = {
			{
				type = "number",
				name = "JumpPower",
				description = "The jump power to use.",
			},
		},

		run = function(context, walkSpeed: number)
			context._K.Util.Services.StarterPlayer.CharacterJumpPower = walkSpeed
		end,
	},
	{
		name = "sit",
		description = "Makes one or more player(s) sit.",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) who will sit.",
				shouldRequest = true,
			},
		},

		run = function(context, players)
			for _, player in players do
				if player.Character and player.Character:FindFirstChildOfClass("Humanoid") then
					player.Character:FindFirstChildOfClass("Humanoid").Sit = true
				end
			end
		end,
	},
	{
		name = "unsit",
		description = "Makes one or more player(s) stop sitting.",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) who will stop sitting.",
				shouldRequest = true,
			},
		},

		run = function(context, players)
			for _, player in players do
				if player.Character and player.Character:FindFirstChildOfClass("Humanoid") then
					player.Character:FindFirstChildOfClass("Humanoid").Sit = false
				end
			end
		end,
	},
	{
		name = "speed",
		aliases = { "walkspeed" },
		description = "Changes the walkspeed of one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) whose walkspeed to change.",
			},
			{
				type = "number",
				name = "Speed",
				description = "The walkspeed to use.",
			},
		},

		run = function(context, players, walkSpeed: number)
			for _, player in players do
				if player.Character and player.Character:FindFirstChildOfClass("Humanoid") then
					player.Character:FindFirstChildOfClass("Humanoid").WalkSpeed = walkSpeed
				end
			end
		end,
	},
	{
		name = "starterspeed",
		aliases = { "starterwalkspeed" },
		description = "Changes the walkspeed of one or more player(s) when they spawn.",
		args = {
			{
				type = "number",
				name = "Speed",
				description = "The walkspeed to use.",
			},
		},

		run = function(context, walkSpeed: number)
			context._K.Util.Services.StarterPlayer.CharacterWalkSpeed = walkSpeed
		end,
	},
	{
		name = "vehiclespeed",
		aliases = {},
		description = "Changes the vehicle speed of one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) whose vehicle speed to change.",
			},
			{
				type = "number",
				name = "Speed",
				description = "The vehicle speed to use.",
			},
		},

		run = function(context, players, speed: number)
			for _, player in players do
				if not player.Character then
					continue
				end
				local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
				if not (humanoid and humanoid.SeatPart) then
					continue
				end
				humanoid.SeatPart.MaxSpeed = speed
			end
		end,
	},
	{
		name = "vehicletorque",
		aliases = {},
		description = "Changes the vehicle torque of one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) whose vehicle torque to change.",
			},
			{
				type = "number",
				name = "Torque",
				description = "The vehicle torque to use.",
			},
		},

		run = function(context, players, torque: number)
			for _, player in players do
				if not player.Character then
					continue
				end
				local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
				if not (humanoid and humanoid.SeatPart) then
					continue
				end
				humanoid.SeatPart.Torque = torque
			end
		end,
	},
	{
		name = "slopeangle",
		aliases = { "maxslopeangle" },
		description = "Changes the max slope angle of one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) whose max slope angle to change.",
			},
			{
				type = "number",
				name = "MaxSlopeAngle",
				description = "The max slope angle to use.",
			},
		},

		run = function(context, players, maxSlopeAngle)
			for _, player in players do
				if player.Character and player.Character:FindFirstChildOfClass("Humanoid") then
					player.Character:FindFirstChildOfClass("Humanoid").MaxSlopeAngle = math.clamp(maxSlopeAngle, 0, 89)
				end
			end
		end,
	},
	{
		name = "starterslopeangle",
		aliases = { "startermaxslopeangle" },
		description = "Changes the starting max slope angle of one or more player(s) when they spawn.",
		args = {
			{
				type = "number",
				name = "MaxSlopeAngle",
				description = "The max slope angle to use.",
			},
		},

		run = function(context, maxSlopeAngle: number)
			context._K.Util.Services.StarterPlayer.CharacterMaxSlopeAngle = math.clamp(maxSlopeAngle, 0, 89)
		end,
	},
	{
		name = "r6",
		aliases = { "r15" },
		description = "Changes the rig type of one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) whose rig type to change.",
				shouldRequest = true,
			},
		},

		run = function(context, players)
			local rigType = if context.alias == "r6" then Enum.HumanoidRigType.R6 else Enum.HumanoidRigType.R15
			for _, player in players do
				local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
				local description = humanoid and humanoid:FindFirstChildOfClass("HumanoidDescription")
				if not description then
					return
				end

				-- TODO: save rig type as an attribute for application on spawn

				local rig = context._K.Util.Services.Players:CreateHumanoidModelFromDescription(description, rigType)
				rig:PivotTo(player.Character:GetPivot())
				rig.Name = player.Character.Name
				local rigHumanoid = rig:FindFirstChildOfClass("Humanoid")
				if rigHumanoid then
					local properties = {
						"CameraOffset",
						"DisplayName",
						"HealthDisplayDistance",
						"NameDisplayDistance",
						"UseJumpPower",
						"JumpPower",
						"WalkSpeed",
						"MaxSlopeAngle",
						"Health",
						"MaxHealth",
					}
					for _, property in properties do
						rigHumanoid[property] = humanoid[property]
					end
				end

				local StarterCharacterScripts =
					context._K.Util.Services.StarterPlayer:FindFirstChild("StarterCharacterScripts")

				if StarterCharacterScripts then
					for _, child in StarterCharacterScripts:GetChildren() do
						child:Clone().Parent = rig
					end
				end

				player.Character = rig
				context._K.VIP.UGCHandler(rig)
				rig.Parent = workspace
			end
		end,
	},
	{
		name = "respawn",
		aliases = { "spawn" },
		description = "Respawns the character of one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to respawn.",
				shouldRequest = true,
			},
		},

		run = function(context, players)
			for _, player in players do
				player:LoadCharacter()
			end
		end,
	},
	{
		name = "refresh",
		aliases = { "re" },
		description = "Refreshes the character of one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to refresh.",
				shouldRequest = true,
			},
		},

		envClient = function(_K)
			local lastCameraCFrame
			_K.Remote.Refresh.OnClientEvent:Connect(function()
				if lastCameraCFrame then
					workspace.CurrentCamera:GetPropertyChangedSignal("CFrame"):Wait()
					workspace.CurrentCamera.CFrame = lastCameraCFrame
				end
			end)

			_K.Services.Players.LocalPlayer.CharacterRemoving:Connect(function()
				lastCameraCFrame = workspace.CurrentCamera.CFrame
			end)
		end,

		run = function(context, players)
			for _, player in players do
				if player and player.Character then
					local old = player.Character:GetPivot()
					player:LoadCharacter()
					player.Character:PivotTo(old)
					context._K.Remote.Refresh:FireClient(player)
				end
			end
		end,
	},
	{
		name = "removelimbs",
		aliases = { "rlimbs" },
		description = "Removes the limbs of one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) whose limbs to remove.",
				shouldRequest = true,
			},
		},

		run = function(context, players)
			for _, player in players do
				if not player.Character then
					continue
				end
				for _, instance in player.Character:GetChildren() do
					if string.find(instance.Name, "Arm$") or string.find(instance.Name, "Leg$") then
						instance:Destroy()
					end
				end
			end
		end,
	},
	{
		name = "removearms",
		aliases = { "rarms" },
		description = "Removes the arms of one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) whose arms to remove.",
				shouldRequest = true,
			},
		},

		run = function(context, players)
			for _, player in players do
				if not player.Character then
					continue
				end
				for _, instance in player.Character:GetChildren() do
					if string.find(instance.Name, "Arm$") then
						instance:Destroy()
					end
				end
			end
		end,
	},
	{
		name = "removelegs",
		aliases = { "rlegs" },
		description = "Removes the legs of one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) whose legs to remove.",
				shouldRequest = true,
			},
		},

		run = function(context, players)
			for _, player in players do
				if not player.Character then
					continue
				end
				for _, instance in player.Character:GetChildren() do
					if string.find(instance.Name, "Leg$") then
						instance:Destroy()
					end
				end
			end
		end,
	},

	{
		name = "buy",
		aliases = { "purchase" },
		description = "Prompts a purchase for one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to prompt.",
			},
			{
				type = "Enum.InfoType",
				name = "InfoType",
				description = "The Enum.InfoType of the purchase.",
				optional = true,
			},
			{
				type = "integer",
				name = "Identifier",
				description = "The identifier of the item to purchase.",
			},
		},

		env = function(_K)
			local MarketplaceService = game:GetService("MarketplaceService")
			return {
				market = MarketplaceService,
				method = {
					[Enum.InfoType.Asset] = MarketplaceService.PromptPurchase,
					[Enum.InfoType.Bundle] = MarketplaceService.PromptBundlePurchase,
					[Enum.InfoType.GamePass] = MarketplaceService.PromptGamePassPurchase,
					[Enum.InfoType.Product] = MarketplaceService.PromptProductPurchase,
					[Enum.InfoType.Subscription] = MarketplaceService.PromptSubscriptionPurchase,
				},
			}
		end,

		run = function(context, players, infoType, id)
			if infoType == nil then
				infoType = Enum.InfoType.Asset
			end
			local method = context.env.method[infoType]
			if not method then
				return
			end
			if infoType == Enum.InfoType.Subscription then
				id = "EXP-" .. id
			end
			for _, player in players do
				pcall(method, context.env.market, player, id)
			end
		end,
	},
	{
		name = "change",
		aliases = {},
		description = "Changes a leaderstat of one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) whose leaderstat to change.",
			},
			{
				type = "string",
				name = "Stat",
				description = "The stat to change.",
			},
			{
				type = "stringGreedy",
				name = "Value",
				description = "The value of the stat.",
			},
		},
		run = function(context, players, stat, value)
			stat = string.lower(stat)
			for _, player in players do
				local leaderstats = player:FindFirstChild("leaderstats")
				if not leaderstats then
					continue
				end
				for _, child in leaderstats:GetChildren() do
					if string.find(string.lower(child.Name), stat, 1, true) == 1 then
						if child:IsA("IntValue") or child:IsA("NumberValue") then
							child.Value = tonumber(value)
						elseif child:IsA("BoolValue") then
							local v = string.lower(value)
							child.Value = v ~= "false" and v ~= "nil" and v ~= "0" and v ~= "off"
						elseif child:IsA("StringValue") then
							child.Value = value
						end
					end
				end
			end
		end,
	},
	{
		name = "resetstats",
		aliases = { "rs" },
		description = "Resets the stats of one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) whose stats to reset.",
				shouldRequest = true,
			},
		},
		run = function(context, players)
			for _, player in players do
				local leaderstats = player:FindFirstChild("leaderstats")
				if not leaderstats then
					continue
				end
				for _, child in leaderstats:GetChildren() do
					if child:IsA("IntValue") or child:IsA("NumberValue") then
						child.Value = 0
					end
				end
			end
		end,
	},
	{
		name = "team",
		aliases = { "tm" },
		description = "Changes the team of one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) whose teams to change.",
			},
			{
				type = "team",
				name = "Team",
				description = "The team to assign.",
				optional = true,
			},
		},
		run = function(context, players, team)
			for _, player in players do
				player.Team = team
			end
		end,
	},
	{
		name = "randomizeteams",
		aliases = { "randomiseteams", "randomteams", "rteams", "rteam", "rt" },
		description = "Randomizes the team of one or more player(s) from a list of teams.",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) whose teams to randomize.",
			},
			{
				type = "teams",
				name = "Random Teams",
				description = "The teams to randomly assign.",
				optional = true,
			},
		},
		run = function(context, players, teams)
			teams = context._K.Util.Table.shuffle(teams or context._K.Services.Teams:GetTeams())
			for i, player in context._K.Util.Table.shuffle(players) do
				player.Team = teams[((i - 1) % #teams) + 1]
			end
		end,
	},
}
