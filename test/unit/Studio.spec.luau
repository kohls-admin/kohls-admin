local sert = require("../sert")

local describe = sert.describe
local serverTest = sert.test.server
local clientTest = sert.test.client

describe("Studio · Server", function()
	serverTest(
		"initializes _K server singleton, registers DefaultTypes & DefaultCommands, and grants Studio player creator role",
		function()
			local Players = game:GetService("Players")
			local _K = shared._K_INTERFACE
			sert.eq(_K ~= nil, true)
			sert.eq(_K.IsServer, true)
			sert.eq(_K.ready, true)
			sert.eq(#_K.Registry.commandsList > 50, true)

			local player = Players:GetPlayers()[1]
			sert.eq(player ~= nil, true)
			sert.waitFor(function()
				return player:GetAttribute("_KRolesLoaded")
			end, 10, nil, "Studio player _KRolesLoaded")
			sert.eq(_K.Auth.hasPermission(player.UserId, "admin"), true)
		end
	)

	serverTest("executes server commands and appends command logs in real Studio DataModel", function()
		local Players = game:GetService("Players")
		local _K = shared._K_INTERFACE
		local player = Players:GetPlayers()[1]
		sert.eq(player ~= nil, true)

		local beforeLogs = #_K.Data.logs
		local ok = _K.Process.runCommands(_K, player.UserId, ";ping me")
		sert.eq(ok, true)
		task.wait(0.1)
		sert.eq(#_K.Data.logs > beforeLogs, true)
		sert.eq(_K.Data.logs[#_K.Data.logs][1], `;ping {player.Name}`)
	end)

	serverTest("Loader initializes modern flags/Tools and syncs per-player PlayerPrefix TextChatCommands", function()
		local Players = game:GetService("Players")
		local ServerScriptService = game:GetService("ServerScriptService")
		local TextChatService = game:GetService("TextChatService")

		sert.eq((_G :: any).KAU, true)
		sert.eq(shared._K_LOADER_LOADED, true)
		sert.eq(shared._K_MODERN_LOADER, true)

		local kaFolder = ServerScriptService:FindFirstChild("Kohl's Admin")
		sert.eq(kaFolder ~= nil, true)
		local loader = if kaFolder then kaFolder:FindFirstChild("Loader") else nil
		sert.eq(loader ~= nil, true)

		local _K = shared._K_INTERFACE
		local ReplicatedStorage = game:GetService("ReplicatedStorage")
		local LogService = game:GetService("LogService")
		for _, entry in LogService:GetLogHistory() do
			sert.eq(string.find(entry.message, "Duplicate theme", 1, true), nil)
		end
		local load: (Instance) -> any = require
		local serverThemes = load(_K.script.Client.UI.Theme).Themes
		sert.eq(type(serverThemes.Default), "table")
		sert.eq(type(serverThemes.Legacy), "table")
		sert.eq(type(serverThemes.Light), "table")
		sert.eq(_K.script, ReplicatedStorage:FindFirstChild("Kohl's Admin Source"))
		sert.eq(_K.Server ~= nil and _K.Tools ~= nil and _K.Server:FindFirstChild("Tools") ~= nil, true)
		local player = Players:GetPlayers()[1]
		sert.eq(player ~= nil, true)

		local cmdFolder = sert.waitFor(function()
			return TextChatService:FindFirstChild("TextChatCommands_KA")
		end, 5, nil, "TextChatCommands_KA folder")

		local prevPrefix = _K.Data.playerPrefix[player.UserId]
		_K.Data.playerPrefix[player.UserId] = "!"
		if _K.ChatCommands and _K.ChatCommands.refresh then
			_K.ChatCommands.refresh()
		end

		local playerCmdName = string.format("_KPlayer_%d_ping", string.byte("!"))
		local playerPing = cmdFolder:FindFirstChild(playerCmdName) :: TextChatCommand?
		sert.eq(playerPing ~= nil, true)
		if playerPing then
			sert.eq(playerPing.PrimaryAlias, "!ping")
			sert.eq(playerPing:GetAttribute("PlayerPrefix"), "!")
		end

		_K.Data.playerPrefix[player.UserId] = prevPrefix
		if _K.ChatCommands and _K.ChatCommands.refresh then
			_K.ChatCommands.refresh()
		end
		sert.eq(cmdFolder:FindFirstChild(playerCmdName), nil)
	end)
end)

describe("Studio · Client", function()
	clientTest("initializes _K client singleton, UI classes, CommandBar, and Dashboard on the live client", function()
		local _K = sert.waitFor(function()
			local k = shared._K_INTERFACE
			return if k and k.client and k.ready then k else nil
		end, 15, nil, "_K client interface ready")
		sert.eq(_K ~= nil, true)
		sert.eq(_K.IsClient, true)
		sert.eq(_K.client ~= nil, true)
		sert.eq(_K.UI ~= nil, true)
		sert.eq(_K.client.CommandBar ~= nil, true)
		sert.eq(_K.client.dashboard ~= nil, true)

		local LogService = game:GetService("LogService")
		for _, entry in LogService:GetLogHistory() do
			sert.eq(string.find(entry.message, "Duplicate theme", 1, true), nil)
		end
		sert.eq(type(_K.UI.Themes.Default), "table")
		sert.eq(type(_K.UI.Themes.Legacy), "table")
		sert.eq(type(_K.UI.Themes.Light), "table")

		-- Verify dashboard topbar button stays 44x44 across desktop and console (Xbox 87px TopbarInset)
		local dashboardButton = _K.client.dashboardButton
		sert.eq(typeof(dashboardButton), "Instance")
		if typeof(dashboardButton) == "Instance" and dashboardButton:IsA("GuiObject") then
			sert.roblox.Layout.settle(_K.UI.TopbarFrame)
			sert.eq(dashboardButton.AbsoluteSize, Vector2.new(44, 44))
		end

		-- Verify UI.new Button + Tooltip hover stability and Select choices in live Studio
		local UI = _K.UI
		local testBtn = UI.new "Button" {
			Parent = UI.LayerDefault,
			Position = UDim2.fromOffset(200, 200),
			Size = UDim2.fromOffset(120, 36),
			Label = "HoverTest",
		}
		local testTip = UI.new "Tooltip" {
			Parent = testBtn,
			Text = "Studio Tooltip",
		}
		sert.eq(testTip._instance.Parent, testBtn._content)
		sert.eq(UI.Class.Tooltip.Cache[testBtn._instance] == testTip, true)
		testBtn:Destroy()

		local testSelect = UI.new "Select" {
			Parent = UI.LayerDefault,
			Value = "Choice B",
			Choices = { "Choice A", "Choice B", "Choice C" },
		}
		sert.eq(testSelect.menu._content:FindFirstChild("Choice B") ~= nil, true)
		testSelect:Destroy()

		-- Verify Window.nudge preserves nudged position when a second window opens at the same spot
		local w1 = UI.new "Window" {
			Parent = UI.LayerTopInset,
			Title = "StudioWin1",
			Position = UDim2.fromOffset(20, 20),
			Size = UDim2.fromOffset(128, 128),
			Visible = true,
		}
		local w2 = UI.new "Window" {
			Parent = UI.LayerTopInset,
			Title = "StudioWin2",
			Position = UDim2.fromOffset(20, 20),
			Size = UDim2.fromOffset(128, 128),
			Visible = false,
		}
		w2._instance.Visible = true
		sert.eq(w2._instance.Position, UDim2.fromOffset(52, 52))
		w1:Destroy()
		w2:Destroy()

		-- Verify cmdbar2 Window with AutomaticSize.Y expands to fit its Input + Button children in Studio
		local cmdbar2Win = _K.Registry.commands.cmdbar2.env.window
		cmdbar2Win._instance.Visible = true
		sert.roblox.Layout.settle(cmdbar2Win._instance)
		sert.eq(cmdbar2Win._instance.AbsoluteSize.X, 420)
		sert.eq(cmdbar2Win._instance.AbsoluteSize.Y > 60, true)
		sert.eq(cmdbar2Win._content.AbsoluteSize.Y > 30, true)
		sert.eq(cmdbar2Win._instance.UISizeConstraint.MaxSize.X > 0, true)
		cmdbar2Win._instance.Visible = false

		-- Verify Slider synchronous knob & hook update
		local sliderHookVal = nil
		local testSlider = UI.new "Slider" {
			Parent = UI.LayerDefault,
			Size = UDim2.fromOffset(200, 24),
			Value = 0,
			[UI.Hook] = {
				Value = function(v)
					sliderHookVal = v
				end,
			},
		}
		testSlider.Value(0.5, true)
		UI.flush()
		sert.near(sliderHookVal, 0.5, 5e-5)
		sert.near(testSlider._slider.Position.X.Scale, 0.5, 5e-5)
		testSlider:Destroy()

		-- Verify ColorPicker hueSlider on 0-saturation color
		local testPicker = UI.new "ColorPicker" {
			Value = Color3.new(1, 1, 1),
			Visible = true,
		}
		testPicker.hueSlider.Value(0.5, true)
		UI.flush()
		local h, s, v = testPicker.sv.BackgroundColor3:ToHSV()
		sert.near(h, 0.5, 5e-3)
		sert.near(s, 1, 5e-3)
		sert.near(v, 1, 5e-3)
		testPicker:Destroy()
	end)

	clientTest("the command bar clears back to the prefix after running a command", function()
		local _K = shared._K_INTERFACE
		local CommandBar = _K.client.CommandBar
		local input = CommandBar.Input
		local prefix = _K.getCommandPrefix()
		sert.waitFor(function()
			return _K.Registry.commands.ping.LocalPlayerAuthorized
		end, 10, nil, "ping command LocalPlayerAuthorized")
		sert.eq(not not _K.Registry.commands.ping.LocalPlayerAuthorized, true)

		sert.roblox.Flicker.steady(function()
			CommandBar.show()
			return CommandBar.Bar
		end, { label = "CommandBar", fromSettledSize = true })
		sert.roblox.Layout.settle(CommandBar.Bar)
		input._input.Text = `{prefix}ping me`
		input._input.CursorPosition = #input._input.Text + 1
		task.wait()
		CommandBar.updateCompletionData()
		-- ReleaseFocus(true) fires FocusLost with enterPressed, like pressing Enter
		input._input:ReleaseFocus(true)
		task.wait(0.2)

		sert.eq(input._input.Text, prefix)
		sert.eq(input.Value(), prefix)
		sert.eq(CommandBar.Bar.Visible, false)
	end)

	clientTest("custom-prefix chat commands show in chat while slash commands stay silent", function()
		local TextChatService = game:GetService("TextChatService")
		local channels = sert.waitFor(function()
			return TextChatService:FindFirstChild("TextChannels")
		end, 5, nil, "TextChannels folder")
		local general = sert.waitFor(function()
			return channels:FindFirstChild("RBXGeneral") :: TextChannel?
		end, 5, nil, "RBXGeneral channel")
		local cmdFolder = sert.waitFor(function()
			return TextChatService:FindFirstChild("TextChatCommands_KA")
		end, 5, nil, "TextChatCommands_KA folder")
		local pingCmd = sert.waitFor(function()
			return cmdFolder:FindFirstChild("ping") :: TextChatCommand?
		end, 5, nil, "ping TextChatCommand")
		sert.eq(pingCmd ~= nil, true)

		local sendingTexts = {}
		local triggeredTexts = {}
		local sendingConn = TextChatService.SendingMessage:Connect(function(msg)
			table.insert(sendingTexts, msg.Text)
		end)
		local trigConn = pingCmd.Triggered:Connect(function(_src, text)
			table.insert(triggeredTexts, text)
		end)

		-- TextChannel:SendAsync never resolves its yielding thread when a TextChatCommand intercepts the message
		task.spawn(pcall, general.SendAsync, general, "/ping me")
		sert.waitFor(function()
			return #triggeredTexts == 1
		end, 5, nil, "/ping me triggered")
		task.wait(0.1)
		sert.eq(triggeredTexts[1], "/ping me")
		sert.eq(#sendingTexts, 0)

		task.spawn(pcall, general.SendAsync, general, ";ping me")
		sert.waitFor(function()
			return #triggeredTexts == 2 and #sendingTexts == 1
		end, 5, nil, ";ping me triggered and sent to chat")
		sendingConn:Disconnect()
		trigConn:Disconnect()

		sert.eq(triggeredTexts[2], ";ping me")
		sert.eq(sendingTexts[1], ";ping me")
		sert.eq(pingCmd.Enabled, true)
	end)

	clientTest(
		"PlayerPrefix TextChatCommands stay disabled for non-matching local prefix and enable when matching",
		function()
			local TextChatService = game:GetService("TextChatService")
			local _K = shared._K_INTERFACE
			local cmdFolder = sert.waitFor(function()
				return TextChatService:FindFirstChild("TextChatCommands_KA")
			end, 5, nil, "TextChatCommands_KA folder")

			local otherCmd = Instance.new("TextChatCommand")
			otherCmd.Name = "_KPlayer_63_ping"
			otherCmd.PrimaryAlias = "?ping"
			otherCmd:SetAttribute("PlayerPrefix", "?")
			otherCmd.Parent = cmdFolder
			task.wait(0.1)
			sert.eq(otherCmd.Enabled, false)
			sert.eq(otherCmd.AutocompleteVisible, false)

			local matchPrefix = _K.getCommandPrefix()
			local matchCmd = Instance.new("TextChatCommand")
			matchCmd.Name = "_KPlayer_match_ping"
			matchCmd.PrimaryAlias = `{matchPrefix}pingtest`
			matchCmd:SetAttribute("PlayerPrefix", matchPrefix)
			matchCmd.Parent = cmdFolder
			task.wait(0.1)
			sert.eq(matchCmd.Enabled, true)

			otherCmd:Destroy()
			matchCmd:Destroy()
		end
	)
end)

do
	return {}
end
