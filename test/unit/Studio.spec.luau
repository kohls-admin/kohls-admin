local sert = require("../sert")

local describe, expect = sert.describe, sert.expect
local IS_ROBLOX = game ~= nil and typeof(game) == "Instance"
local serverTest = if IS_ROBLOX and game:GetService("RunService"):IsServer() then sert.rtest else sert.skip
local clientTest = if IS_ROBLOX and game:GetService("RunService"):IsClient() then sert.rtest else sert.skip

describe("Studio · Server", function()
	serverTest(
		"initializes _K server singleton, registers DefaultTypes & DefaultCommands, and grants Studio player creator role",
		function()
			local Players = game:GetService("Players")
			local _K = shared._K_INTERFACE
			expect(_K ~= nil).toBe(true)
			expect(_K.IsServer).toBe(true)
			expect(_K.ready).toBe(true)
			expect(#_K.Registry.commandsList > 50).toBe(true)

			local player = Players:GetPlayers()[1]
			expect(player ~= nil).toBe(true)
			local deadline = os.clock() + 10
			while not player:GetAttribute("_KRolesLoaded") and os.clock() < deadline do
				task.wait()
			end
			expect(_K.Auth.hasPermission(player.UserId, "admin")).toBe(true)
		end
	)

	serverTest("executes server commands and appends command logs in real Studio DataModel", function()
		local Players = game:GetService("Players")
		local _K = shared._K_INTERFACE
		local player = Players:GetPlayers()[1]
		expect(player ~= nil).toBe(true)

		local beforeLogs = #_K.Data.logs
		local ok = _K.Process.runCommands(_K, player.UserId, ";ping me")
		expect(ok).toBe(true)
		task.wait(0.1)
		expect(#_K.Data.logs > beforeLogs).toBe(true)
		expect(_K.Data.logs[#_K.Data.logs][1]).toBe(`;ping {player.Name}`)
	end)
end)

describe("Studio · Client", function()
	clientTest("initializes _K client singleton, UI classes, CommandBar, and Dashboard on the live client", function()
		local _K = shared._K_INTERFACE
		local deadline = os.clock() + 15
		while (not _K or not _K.client or not _K.ready) and os.clock() < deadline do
			task.wait()
			_K = shared._K_INTERFACE
		end
		expect(_K ~= nil).toBe(true)
		expect(_K.IsClient).toBe(true)
		expect(_K.client ~= nil).toBe(true)
		expect(_K.UI ~= nil).toBe(true)
		expect(_K.client.CommandBar ~= nil).toBe(true)
		expect(_K.client.dashboard ~= nil).toBe(true)

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
		expect(testTip._instance.Parent).toBe(testBtn._content)
		expect(UI.Class.Tooltip.Cache[testBtn._instance] == testTip).toBe(true)
		testBtn:Destroy()

		local testSelect = UI.new "Select" {
			Parent = UI.LayerDefault,
			Value = "Choice B",
			Choices = { "Choice A", "Choice B", "Choice C" },
		}
		expect(testSelect.menu._content:FindFirstChild("Choice B") ~= nil).toBe(true)
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
		expect(w2._instance.Position).toEqual(UDim2.fromOffset(52, 52))
		w1:Destroy()
		w2:Destroy()

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
		expect(sliderHookVal).toBeCloseTo(0.5, 4)
		expect(testSlider._slider.Position.X.Scale).toBeCloseTo(0.5, 4)
		testSlider:Destroy()

		-- Verify ColorPicker hueSlider on 0-saturation color
		local testPicker = UI.new "ColorPicker" {
			Value = Color3.new(1, 1, 1),
			Visible = true,
		}
		testPicker.hueSlider.Value(0.5, true)
		UI.flush()
		local h, s, v = testPicker.sv.BackgroundColor3:ToHSV()
		expect(h).toBeCloseTo(0.5, 2)
		expect(s).toBeCloseTo(1, 2)
		expect(v).toBeCloseTo(1, 2)
		testPicker:Destroy()
	end)

	clientTest("the command bar clears back to the prefix after running a command", function()
		local _K = shared._K_INTERFACE
		local CommandBar = _K.client.CommandBar
		local input = CommandBar.Input
		local prefix = _K.getCommandPrefix()
		local deadline = os.clock() + 10
		while not _K.Registry.commands.ping.LocalPlayerAuthorized and os.clock() < deadline do
			task.wait()
		end
		expect(not not _K.Registry.commands.ping.LocalPlayerAuthorized).toBe(true)

		CommandBar.show()
		input._input.Text = `{prefix}ping me`
		input._input.CursorPosition = #input._input.Text + 1
		task.wait()
		CommandBar.updateCompletionData()
		-- ReleaseFocus(true) fires FocusLost with enterPressed, like pressing Enter
		input._input:ReleaseFocus(true)
		task.wait(0.2)

		expect(input._input.Text).toBe(prefix)
		expect(input.Value()).toBe(prefix)
		expect(CommandBar.Bar.Visible).toBe(false)
	end)
end)

return {}
