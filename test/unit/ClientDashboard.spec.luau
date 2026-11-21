local ClientHarness = require("./ClientHarness")
local Harness = require("./Harness")
local sert = require("../sert")

local describe, test = sert.describe, sert.test

-- Live Studio UI & hover suite (play mode: a server and one client). Declared before the headless globals below so
-- it uses the real engine Enum/UDim2/Vector2. Headless `luau` skips these (a skip is not a pass).
do
	local IS_ROBLOX = game ~= nil and typeof(game) == "Instance"
	local IS_CLIENT = IS_ROBLOX and game:GetService("RunService"):IsClient()
	local serverTest = sert.test.server
	local clientTest = sert.test.client

	-- every error and warning the client prints while the suite runs, minus engine/CoreGui noise and sert's own report
	local ENGINE_NOISE =
		{ "UIBlox", "CorePackages", "FoundationProvider", "203785492", "publish this game", "❌", "⚠️", "[sert-" }
	local consoleProblems: { string } = {}
	if IS_CLIENT then
		game:GetService("LogService").MessageOut:Connect(function(message, messageType)
			if messageType ~= Enum.MessageType.MessageError and messageType ~= Enum.MessageType.MessageWarning then
				return
			end
			for _, noise in ENGINE_NOISE do
				if string.find(message, noise, 1, true) then
					return
				end
			end
			table.insert(consoleProblems, `[{messageType.Name}] {message}`)
		end)
	end

	local function clientK(): any
		return sert.waitFor(function()
			local _K = shared._K_INTERFACE
			return if _K
					and _K.ready
					and _K.client
					and _K.client.dashboard
					and _K.client.dashboard.Window
				then _K
				else nil
		end, 15, nil, "the Kohl's Admin client never became ready")
	end

	local function frames(UI: any, n: number?)
		UI.flush()
		for _ = 1, n or 2 do
			game:GetService("RunService").Heartbeat:Wait()
			UI.flush()
		end
		game:GetService("RunService").Heartbeat:Wait()
	end

	local function openDashboard(_K: any)
		local window = _K.client.dashboard.Window
		if not window._instance.Visible then
			sert.roblox.Flicker.steady(function()
				_K.client.hotkeys.dashboard.callback()
				return window._instance
			end, { label = "Dashboard", fromSettledSize = true })
		end
		sert.roblox.Layout.settle(window._instance)
		frames(_K.UI, 3)
		-- Opening the dashboard must never auto-open the VIP modal
		if _K.VIP and _K.VIP.popup then
			sert.eq(_K.VIP.popup.Visible, false)
		end
	end

	local function jumpTo(_K: any, page: any)
		local tabs = _K.client.dashboard.Tabs
		tabs._pages:JumpTo(tabs._containerCache[page._instance])
		sert.roblox.Layout.settle(page._instance)
		frames(_K.UI, 4)
	end

	describe("Studio · Server", function()
		serverTest("Studio UI · seeds bans, members, servers and logs for the client", function()
			local _K = shared._K_INTERFACE
			sert.eq(_K ~= nil and _K.ready, true)
			local player = game:GetService("Players"):GetPlayers()[1]
			sert.eq(player ~= nil, true)
			_K.Auth.userRoleAdd(player.UserId, "creator")

			_K.Data.bans["2"] = { "BannedBob", "Griefing spawn", nil, 1 }
			_K.Data.bans["3"] = { "BannedAlice", "Spamming", os.time() + 3600, 1 }
			_K.Remote.Bans:Fire(player, _K.Data.bans)
			_K.Data.members["2"] = { name = "AdminBob", roles = { "admin", "vip" }, persist = { "admin" } }
			_K.Remote.Members:Fire(player, _K.Data.members)
			_K.Data.servers["job123456"] = { game.PlaceId, 3, os.time() - 125 }
			_K.Remote.Servers:Fire(player, nil, _K.Data.servers)
			_K.log("Studio UI info log", "INFO")
			_K.log("Studio UI warn log", "WARN")
		end)
	end)

	describe("Studio · Client", function()
		clientTest("Studio UI · UI.textWidth measures text off the reactive graph", function()
			local _K = clientK()
			local UI = _K.UI
			local text = UI.signal("Kohl's Admin")
			local width, measure = UI.textWidth(function()
				return { { Text = text(), Font = UI.Theme.FontBold:peek(), Size = 18 } }
			end)
			sert(width:peek() > 0, `starts at a non-zero estimate, got {width:peek()}`)
			sert(UI.isReactive() == false, "measuring never leaves the caller inside a reactive context")

			local params = Instance.new("GetTextBoundsParams")
			params.Text, params.Font, params.Size, params.Width =
				"Kohl's Admin", UI.Theme.FontBold:peek(), 18, math.huge
			local expected = math.ceil(game:GetService("TextService"):GetTextBoundsAsync(params).X)
			sert.waitFor(function()
				return width:peek() == expected
			end, 5, nil, "UI.textWidth initial measurement")
			sert.eq(width:peek(), expected)

			text:set("Kohl's Admin, but wider")
			UI.flush()
			sert.waitFor(function()
				return width:peek() > expected
			end, 5, nil, "UI.textWidth updated measurement")
			sert(width:peek() > expected, "re-measures when its tracked inputs change")
			measure:Destroy()
			width:Destroy()
			text:Destroy()
		end)

		clientTest("Studio UI · buttons are hit-tested without being sunk or covered", function()
			local _K = clientK()
			local UI = _K.UI
			local button = UI.new "Button" {
				Parent = UI.LayerTopInset,
				Label = "Hit test",
				Position = UDim2.fromOffset(60, 60),
				Size = UDim2.fromOffset(140, 40),
			}
			local instance = button._instance
			sert.roblox.Layout.settle(instance)
			frames(UI, 2)
			local center = instance.AbsolutePosition + instance.AbsoluteSize / 2
			local hits = game:GetService("Players").LocalPlayer.PlayerGui:GetGuiObjectsAtPosition(center.X, center.Y)
			local found = false
			for _, gui in hits do
				if gui == instance then
					found = true
				end
			end
			sert(
				found,
				`the button is under its own center ({center.X}, {center.Y}; size={instance.AbsoluteSize}; hits={#hits})`
			)
			sert.eq(UI.Interact.sunk(center.X, center.Y, instance), false)
			sert.eq(UI.Interact.covered(center.X, center.Y, instance), false)
			button:Destroy()
		end)

		clientTest(
			"Studio UI · tooltips claim the hover state and UI.clearState cancels pending and shown tips",
			function()
				local _K = clientK()
				local UI = _K.UI
				local function makeTip(name: string, y: number)
					local button = UI.new "Button" {
						Parent = UI.LayerTopInset,
						Label = name,
						Position = UDim2.fromOffset(240, y),
						Size = UDim2.fromOffset(140, 40),
					}
					local hovering = UI.signal(false)
					local tip = UI.new "Tooltip" { Parent = button, Hovering = hovering, Text = `{name} tip` }
					return button, tip, hovering
				end
				local buttonA, tipA, hoverA = makeTip("Tip A", 300)
				local buttonB, tipB, hoverB = makeTip("Tip B", 360)
				local label = UI.LayerTop:FindFirstChild("Tooltip")
				frames(UI, 2)

				-- a pending show (before the 0.4s delay) is cancelled by clearing the hover state
				hoverA(true)
				UI.flush()
				sert(UI._activeState.hover ~= nil, "a starting hover claims the shared hover state before the delay")
				UI.clearState("hover")
				task.wait(0.6)
				UI.flush()
				sert.eq(tipA.Visible:peek(), false)

				-- hovering again shows it after the delay
				hoverA(false)
				UI.flush()
				hoverA(true)
				UI.flush()
				task.wait(0.6)
				UI.flush()
				sert.eq(tipA.Visible:peek(), true)
				label = label or UI.LayerTop:FindFirstChild("Tooltip")
				sert(
					label ~= nil and label.Visible and label.Text == "Tip A tip",
					"the shared tooltip label shows tip A"
				)

				-- clearing the hover state (scroll, tab switch, window close) hides a shown tip
				UI.clearState("hover")
				frames(UI, 1)
				sert.eq(tipA.Visible:peek(), false)
				sert(not label.Visible, "the shared tooltip label hides")

				-- hovering another tooltip releases the first
				hoverA(false)
				UI.flush()
				hoverA(true)
				UI.flush()
				task.wait(0.6)
				UI.flush()
				sert.eq(tipA.Visible:peek(), true)
				hoverB(true)
				UI.flush()
				frames(UI, 1)
				sert.eq(tipA.Visible:peek(), false)
				task.wait(0.6)
				UI.flush()
				sert.eq(tipB.Visible:peek(), true)
				sert(label.Text == "Tip B tip", "the shared tooltip label follows tip B")

				buttonA:Destroy()
				buttonB:Destroy()
				frames(UI, 1)
				sert(not label.Visible, "a shown tooltip hides when its adornee is destroyed")
				sert(
					UI._activeState.hover == nil or not UI._activeState.hover:peek(),
					"destroying releases the hover state"
				)
			end
		)

		clientTest("Studio UI · every dashboard tab renders its rows", function()
			local _K = clientK()
			local UI = _K.UI
			local dashboard = _K.client.dashboard
			openDashboard(_K)
			sert.eq(dashboard.Window._instance.Visible, true)

			local expectations = {
				{ page = dashboard.Commands, child = "Description" },
				{ page = dashboard.Bans, child = "Left" },
				{ page = dashboard.Members },
				{ page = dashboard.Servers },
				{ page = dashboard.Logs, child = "TextLabel" },
				{ page = dashboard.Settings },
				{ page = dashboard.About },
				{ page = dashboard.Market },
			}
			for _, case in expectations do
				local page = case.page
				jumpTo(_K, page)
				local name = page._instance.Name
				sert.eq(dashboard.Tabs.CurrentPage:peek(), page._instance)
				if page._lineItemCache then
					sert.waitFor(function()
						if next(page._lineItemCache) ~= nil then
							return true
						end
						frames(UI, 1)
						return false
					end, 3, nil, `{name} rows rendered`)
					local rows, hitTested = 0, false
					for _, item in page._lineItemCache do
						rows += 1
						local instance = if type(item) == "table" then item._instance else item
						sert(instance.Parent == page._scroller, `{name} rows are parented to the scroller`)
						if case.child then
							sert(instance:FindFirstChild(case.child) ~= nil, `{name} rows keep their {case.child}`)
						end
						-- a row in view must not be covered by anything outside it (a popup, another window)
						local center = instance.AbsolutePosition + instance.AbsoluteSize / 2
						if not hitTested and UI.Interact.pointIn(center.X, center.Y, page._scroller) then
							hitTested = true
							sert(
								not UI.Interact.covered(center.X, center.Y, instance),
								`{name}'s first visible row is covered`
							)
						end
					end
					sert(rows > 0, `{name} renders rows, got {rows}`)
					sert(hitTested, `{name} has a row in view`)
				end
				if name == "About" then
					local credits = sert.waitFor(function()
						local c = page._instance:FindFirstChild("Credits", true)
						if c and c:FindFirstChild("Contributors") then
							return c
						end
						frames(UI, 1)
						return nil
					end, 3, nil, "About credits sections rendered")
					local activeSection = credits:FindFirstChild("Active contributors")
					local plainSection = credits:FindFirstChild("Contributors")
					local specialSection = credits:FindFirstChild("Special Thanks")
					sert.eq(activeSection ~= nil, true)
					sert.eq(plainSection ~= nil, true)
					sert.eq(specialSection ~= nil, true)
					sert.eq(activeSection.LayoutOrder < plainSection.LayoutOrder, true)
					sert.eq(plainSection.LayoutOrder < specialSection.LayoutOrder, true)
					local plainUsers = plainSection:FindFirstChild("Users")
					sert.eq(plainUsers ~= nil and plainUsers:FindFirstChild("Header") == nil, true)
					sert.eq(plainUsers:FindFirstChild("Credit") ~= nil, true)

					local linkA = UI.new "Link" {
						Parent = UI.LayerDefault,
						Text = "roblox.com/communities/3403354/Kohls-Admin",
					}
					local linkB = UI.new "Link" {
						Parent = UI.LayerDefault,
						Text = "create.roblox.com/store/asset/1868400649",
					}
					linkA:Select()
					frames(UI, 2)
					sert.eq(linkA._instance:IsFocused(), true)
					sert.eq(linkA._instance.SelectionStart, 1)
					sert.eq(linkA._instance.CursorPosition, #linkA._instance.Text + 1)

					-- Switching focus to a second Link must not lose focus when linkA's FocusLost fires
					linkB:Select()
					frames(UI, 2)
					sert.eq(linkA._instance:IsFocused(), false)
					sert.eq(linkA._instance.SelectionStart, -1)
					sert.eq(linkB._instance:IsFocused(), true)
					sert.eq(linkB._instance.SelectionStart, 1)
					sert.eq(linkB._instance.CursorPosition, #linkB._instance.Text + 1)

					-- Mutating cursor/selection while focused snaps back to full-text selection
					linkB._instance.SelectionStart = -1
					linkB._instance.CursorPosition = 1
					frames(UI, 1)
					sert.eq(linkB._instance.SelectionStart, 1)
					sert.eq(linkB._instance.CursorPosition, #linkB._instance.Text + 1)

					linkA:Destroy()
					linkB:Destroy()
				end
			end
		end)

		clientTest("Studio UI · font size changes keep tabs measured and rows intact", function()
			local _K = clientK()
			local UI = _K.UI
			local dashboard = _K.client.dashboard
			openDashboard(_K)
			local original = UI.Theme.FontSize:peek()
			for _, page in { dashboard.Logs, dashboard.Settings, dashboard.Members } do
				jumpTo(_K, page)
				UI.Theme.FontSize:set(original + 4)
				frames(UI, 3)
				UI.Theme.FontSize:set(original)
				frames(UI, 3)
			end
			task.wait(0.5)
			frames(UI, 2)

			for _, button in dashboard.Tabs._instance.Bar.Tabs:GetChildren() do
				if button:IsA("GuiButton") and button.Visible then
					local padding = UI.Theme.Padding:peek().Offset * 2
					sert(button.AbsoluteSize.X > padding, `tab {button.Name} has a measured width`)
				end
			end
			jumpTo(_K, dashboard.Logs)
			for _, item in dashboard.Logs._lineItemCache do
				sert(item._instance:FindFirstChild("TextLabel") ~= nil, "log rows keep their label")
			end
		end)

		clientTest("Studio UI · command windows open", function()
			local _K = clientK()
			for _, command in { ";cmds", ";bans", ";members", ";servers", ";logs", ";settings", ";about", ";market" } do
				local ok, err = pcall(_K.Process.runCommands, _K, _K.LocalPlayer.UserId, command)
				sert(ok, `{command} runs: {err}`)
				frames(_K.UI, 4)
			end
			_K.Process.runCommands(_K, _K.LocalPlayer.UserId, ";emotes")
			frames(_K.UI, 4)
			local env = _K.Registry.commands.emotes.env
			sert(env and env.window and env.window._instance.Visible, "the emotes window opens")

			-- Verify VIP Popup lazy construction, layout, PromptPurchaseVIP, View button, and sale state sync in real Studio
			local vip = _K.VIP.popup
			sert.eq(vip ~= nil, true)
			sert.eq(vip.Visible, false)
			sert.eq(vip:FindFirstChild("Frame"), nil)
			_K.PromptPurchaseVIP()
			frames(_K.UI, 2)
			sert.eq(vip.Visible, true)
			sert.eq(vip.Frame:FindFirstChild("Preview") ~= nil, true)
			local previewCount = 0
			for cmdName in string.gmatch(vip.Frame.Preview.Text, "<b>;([%w_]+)</b>") do
				previewCount += 1
				local cmd = _K.Registry.commands[cmdName]
				sert(cmd ~= nil, `VIP preview command {cmdName} exists`)
				sert(_K.Auth.roleCanUseCommand("vip", cmd), `VIP preview command {cmdName} is usable by vip role`)
			end
			sert.eq(previewCount, 5)
			sert.eq(vip.Frame.BuyFrame.Favorite:IsA("ImageButton"), true)
			sert.eq(vip.Frame.BuyFrame.Favorite.Visible, true)
			sert.eq(vip.Frame.BuyFrame.Buy.Price.AutomaticSize, Enum.AutomaticSize.X)
			sert.eq(vip.Frame.BuyFrame.OriginalPrice.Label.AutomaticSize, Enum.AutomaticSize.X)
			-- Calling _K.VIP.openFromView() exercises the View button action in live Studio
			vip.Visible = false
			_K.client.dashboard.Commands._instance.Visible = true
			frames(_K.UI, 2)
			sert.eq(vip.Visible, false)
			sert.eq(_K.client.dashboard.Commands._instance.Visible, true)
			sert.eq(vip.ZIndex, 9e8)

			-- Verify _K.VIP.saleStateChanged and _K.client.ownsKAModel signals in live Studio
			sert.eq(_K.VIP.getActiveAssetId(), 110019084552349)
			sert.eq(type(_K.client.promptGetKA), "function")
		end)

		clientTest("Studio UI · the suite printed no errors or warnings", function()
			clientK()
			task.wait(0.5)
			for i, problem in consoleProblems do
				print(`[Studio UI problem {i}] {problem}`)
			end
			sert(#consoleProblems == 0, `{#consoleProblems} errors/warnings, first: {consoleProblems[1]}`)
		end)
	end)
end

local setupClientEnv = ClientHarness.setupClientEnv
local makeInput = ClientHarness.makeInput
local getOrCreateFullClientSut = ClientHarness.getOrCreateFullClientSut
local makeFastRun = ClientHarness.makeFastRun

local baseGlobals = Harness.globals
local Enum = baseGlobals.Enum
local Font = baseGlobals.Font
local Color3 = baseGlobals.Color3
local UDim2 = baseGlobals.UDim2
local Vector2 = baseGlobals.Vector2
local Vector3 = baseGlobals.Vector3

describe("Client and UI", function()
	describe(
		"Part 4 · Full Client Initialization, CommandBar, Dashboard Tabs, Network, Notify, Character & Explorer",
		function()
			test("initializes full Server + Client pair, Theme, UserFrame, Notify, Announce, and CommandBar", function()
				local world, _srvMounted, cliMounted, _sK, cK = getOrCreateFullClientSut()
				local fastRun = makeFastRun(world)

				sert.eq(cK.ready, true)
				sert.eq(cK.client.dashboard ~= nil, true)
				sert.eq(cK.client.CommandBar ~= nil, true)

				local UI = cK.UI

				-- Lazy startup state: unopened windows, dialogs, and VIP popup remain unbuilt before first display
				sert.eq(rawget(cK.Registry.commands.cmds.env, "window"), nil)
				sert.eq(rawget(cK.Registry.commands.cmdbar2.env, "window"), nil)
				sert.eq(rawget(cK.Registry.commands.log.env, "window"), nil)
				sert.eq(rawget(cK.Registry.commands.emote.env, "window"), nil)
				sert.eq(rawget(cK.Registry.commands.emotes.env, "window"), nil)
				sert.eq(cK.VIP.popup:FindFirstChild("Frame"), nil)
				sert.eq(UI.LayerTop:FindFirstChild("Dialog"), nil)
				for _, child in UI.LayerTop:GetChildren() do
					sert.ne(child.Name == "Menu" and child.AutomaticSize == Enum.AutomaticSize.X, true)
				end
				local cEnv = cliMounted.env

				-- 1. UI.changeTheme
				if UI.Themes.Default then
					UI.changeTheme(UI.Themes.Default)
				end

				-- 2. UserFrame variations
				local uf1 = cK.client.UserFrame(1, "CustomDisplay")
				sert.eq(uf1.Name, "Header")
				local ufK = cK.client.UserFrame("_K")
				sert.eq(ufK.Name, "Header")
				local ufCustom = cK.client.UserFrame("SystemSender", nil, "rbxassetid://12345", false)
				sert.eq(ufCustom.Name, "Header")
				local ufBadge = cK.client.UserFrame(1, nil, nil, true)
				sert.eq(ufBadge.Name, "Header")
				fastRun(0.2)

				-- 3. Notify & Announce
				local notifActivated = false
				local notifClosed = false
				local nDialog = cK.Notify({
					Text = "Test Notification",
					From = 1,
					Duration = 2,
					Activated = function()
						notifActivated = true
					end,
					Close = function()
						notifClosed = true
					end,
				})
				sert.eq(nDialog ~= nil, true)
				sert.eq(nDialog._content.Header.LayoutOrder, -3)
				sert.eq(nDialog._content.Header.LayoutOrder < nDialog._content.Title.LayoutOrder, true)
				sert.eq(nDialog._content.Title.LayoutOrder < nDialog._content.Text.LayoutOrder, true)
				nDialog._instance.Activated:Fire()
				fastRun(0.2)
				sert.eq(notifActivated, true)
				sert.eq(notifClosed, true)

				local aDialog = cK.Announce({
					Text = "Pinned Announcement",
					From = "_K",
					Duration = 2,
				})
				sert.eq(aDialog ~= nil, true)
				aDialog._exitButton._instance.Activated:Fire()
				fastRun(0.2)

				-- 4. CommandBar interactions & rich suggestion types
				local CommandBar = cK.client.CommandBar
				CommandBar.show()
				fastRun(0.2)
				sert.eq(CommandBar.Bar.Visible, true)

				-- CircleIndicator button
				local circleInd = CommandBar.Bar:FindFirstChild("CircleIndicator")
				if circleInd then
					local ciBtn = circleInd:FindFirstChildOfClass("TextButton")
					if ciBtn then
						ciBtn.Activated:Fire()
						fastRun(0.1)
					end
				end

				-- Typing prefix-less text via env:input() auto-prepends prefix; duplicate prefix strips
				cEnv:input():click(CommandBar.Input._input)
				cEnv:input():type("help")
				CommandBar.Input._input.CursorPosition = 6
				fastRun(0.2)
				sert.eq(string.sub(CommandBar.Input._input.Text, 1, 1), ";")

				CommandBar.Input._input.Text = ";;help"
				CommandBar.Input._input.CursorPosition = 7
				fastRun(0.2)
				sert.eq(CommandBar.Input._input.Text, ";help")

				-- #358: Alphanumeric prefix allows typing commands starting with the same letter (e.g. prefix "e" -> "eemote")
				cK.client.playerPrefix("e")
				CommandBar.Input._input.Text = "eemote"
				CommandBar.Input._input.CursorPosition = 7
				fastRun(0.1)
				sert.eq(CommandBar.Input._input.Text, "eemote")
				cK.client.playerPrefix(";")

				-- #364 & #379: Short valid command (;ff) sets validState(true), partial with valid suggestions stays neutral (nil), and cycling suggestions does not flip validState
				for _, cmd in cK.Registry.commands do
					cmd.LocalPlayerAuthorized = true
				end
				CommandBar.Input._input.SelectionStart = -1
				CommandBar.Input:SetValue(";ff")
				CommandBar.Input._input.CursorPosition = 4
				CommandBar.updateCompletionData()
				fastRun(0.1)
				sert.eq(cK.client.CommandBarState[1]:peek(), true)

				CommandBar.Input:SetValue(";ver")
				CommandBar.Input._input.CursorPosition = 5
				CommandBar.updateCompletionData()
				fastRun(0.1)
				sert.eq(cK.client.CommandBarState[1]:peek(), nil)
				CommandBar.Input._input:CaptureFocus()
				UI.UserInputService.InputBegan:Fire(
					makeInput(cEnv, { UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.Down }),
					false
				)
				fastRun(0.1)
				sert.eq(cK.client.CommandBarState[1]:peek(), nil)

				-- Broken multi-command chains (;xyz ;ff and ;ff ;xyz) turn validState red (false) and refuse Enter submission
				CommandBar.Input:SetValue(";xyz ;ff")
				CommandBar.Input._input.CursorPosition = 9
				CommandBar.updateCompletionData()
				fastRun(0.1)
				sert.eq(cK.client.CommandBarState[1]:peek(), false)
				CommandBar.Input._input.FocusLost:Fire(true)
				fastRun(0.1)
				sert.eq(CommandBar.Input._input.Text, ";xyz ;ff")

				CommandBar.Input:SetValue(";ff ;xyz")
				CommandBar.Input._input.CursorPosition = 4
				CommandBar.updateCompletionData()
				fastRun(0.1)
				sert.eq(cK.client.CommandBarState[1]:peek(), false)
				CommandBar.Input._input.FocusLost:Fire(true)
				fastRun(0.1)
				sert.eq(CommandBar.Input._input.Text, ";ff ;xyz")

				-- Input ClearTextButton clears CommandBar back to prefix and resets validState/suggestions
				local clearBtn = CommandBar.Input._instance:FindFirstChild("ImageButton")
				sert.eq(clearBtn ~= nil, true)
				if clearBtn then
					clearBtn.Activated:Fire()
					fastRun(0.1)
					sert.eq(CommandBar.Input._input.Text, ";")
					sert.eq(cK.client.CommandBarState[1]:peek(), nil)
				end

				-- SelectionStart ~= -1 and CursorPosition < prefixPosition clamping
				CommandBar.Input._input.SelectionStart = 2
				CommandBar.Input._input.CursorPosition = 1
				fastRun(0.1)
				CommandBar.Input._input.SelectionStart = -1
				CommandBar.Input._input.CursorPosition = 1
				fastRun(0.1)
				sert.eq(CommandBar.Input._input.CursorPosition >= 2, true)

				-- Up / Down suggestion navigation via env:input()
				cEnv:input():press(Enum.KeyCode.Down)
				cEnv:input():release(Enum.KeyCode.Down)
				cEnv:input():press(Enum.KeyCode.Up)
				cEnv:input():release(Enum.KeyCode.Up)

				CommandBar.Input._input.Text = ";uitestcmd "
				CommandBar.Input._input.CursorPosition = 12
				CommandBar.updateCompletionData()
				fastRun(0.2)

				-- Click a suggestion frame directly
				local suggestionMenu = CommandBar.Bar:FindFirstChild("SuggestionMenu", true)
					or UI.LayerTop:FindFirstChild("SuggestionMenu", true)
				if suggestionMenu then
					for _, child in suggestionMenu:GetDescendants() do
						if child:IsA("TextButton") and child.Name ~= "Purchase" then
							child.Activated:Fire()
							break
						end
					end
				end

				-- Image argument suggestion branch
				CommandBar.Input._input.Text = ";uitestcmd playerVal rbxassetid://1"
				CommandBar.Input._input.CursorPosition = 36
				CommandBar.updateCompletionData()
				fastRun(0.2)

				-- Tab completion (including quote completion)
				local origUisMethods = rawget(UI.UserInputService, "_methods")
				local tabDown = true
				rawset(
					UI.UserInputService,
					"_methods",
					setmetatable({
						IsKeyDown = function(_self, kc)
							return tabDown and kc == Enum.KeyCode.Tab
						end,
					}, { __index = origUisMethods })
				)

				CommandBar.Input._input.Text = ';uitestcmd "pla'
				CommandBar.Input._input.CursorPosition = 16
				CommandBar.updateCompletionData()
				fastRun(0.1)
				UI.UserInputService.InputBegan:Fire(
					makeInput(cEnv, { UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.Tab }),
					false
				)
				fastRun(0.2)
				tabDown = false
				rawset(UI.UserInputService, "_methods", origUisMethods)

				-- Restricted command suggestion with VIP and GamePass purchase buttons
				if cK.Registry.commands.ban then
					cK.Registry.commands.ban.LocalPlayerAuthorized = false
					cK.Registry.commands.ban.RestrictedToRole = cK.Data.roles.vip
					CommandBar.Input._input.Text = ";ban"
					CommandBar.Input._input.CursorPosition = 5
					CommandBar.updateCompletionData()
					fastRun(0.2)
					CommandBar.Input._input.Text = ";ban "
					CommandBar.Input._input.CursorPosition = 6
					CommandBar.updateCompletionData()
					fastRun(0.2)
					cK.Data.roles.vip.gamepasses = { 12345 }
					CommandBar.Input._input.Text = ";ban"
					CommandBar.Input._input.CursorPosition = 5
					CommandBar.updateCompletionData()
					fastRun(0.2)
					cK.Data.roles.vip.gamepasses = nil
					cK.Registry.commands.ban.LocalPlayerAuthorized = true
				end

				-- Invalid command & invalid argument suggestions + FocusLost(true) error paths
				CommandBar.Input._input.Text = ";notacommand "
				CommandBar.Input._input.CursorPosition = 14
				CommandBar.updateCompletionData()
				fastRun(0.1)
				CommandBar.Input._input.FocusLost:Fire(true)
				fastRun(0.2)

				CommandBar.show()
				CommandBar.Input._input.Text = ";ban Player1"
				CommandBar.Input._input.CursorPosition = 13
				CommandBar.updateCompletionData()
				fastRun(0.1)
				CommandBar.Input._input.FocusLost:Fire(true)
				fastRun(0.2)

				-- Execute valid command twice via FocusLost(true) to cover duplicate history deduplication
				for _ = 1, 2 do
					CommandBar.show()
					CommandBar.Input._input.Text = ";version"
					CommandBar.Input._input.CursorPosition = 9
					CommandBar.updateCompletionData()
					CommandBar.Input._input.FocusLost:Fire(true)
					fastRun(0.3)
					-- a run command clears the bar back to the prefix
					sert.eq(CommandBar.Input._input.Text, ";")
					sert.eq(CommandBar.Input.Value(), ";")
				end

				-- History completion when text == ";"
				CommandBar.show()
				fastRun(0.1)
				CommandBar.Input._input.Text = ";"
				CommandBar.Input._input.CursorPosition = 2
				CommandBar.updateCompletionData()
				UI.UserInputService.InputBegan:Fire(
					makeInput(cEnv, { UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.Up }),
					false
				)
				UI.UserInputService.InputBegan:Fire(
					makeInput(cEnv, { UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.Down }),
					false
				)
				CommandBar.hide()
				sert.eq(CommandBar.Bar.Visible, false)
			end)

			test("exercises Network remotes, RequestCommand RPC, and client chat command routing", function()
				local world, srvMounted, cliMounted, sK, cK = getOrCreateFullClientSut()
				local fastRun = makeFastRun(world)
				local server = srvMounted.peer
				local client = cliMounted.peer
				local UI = cK.UI
				local cEnv = cliMounted.env

				-- 5. Network remotes & init.client events (Server -> Client & Client -> Server)
				local srvPlayer = srvMounted.env.Players:GetPlayerByUserId(1)
				sK.Remote.Ban:Fire(srvPlayer, "606", { "NewBanUser", "Reason", 0, 1 })
				sK.Remote.Bans:Fire(srvPlayer, {
					["202"] = { "BannedBob", "Griefing", 0, 1 },
					["303"] = { "TimedTim", "Spam", 1800000000, 1 },
					["404"] = { "PermPete", "Exploits", -1, nil },
				})
				sK.Remote.Member:Fire(srvPlayer, "707", { name = "ModMary", roles = { "mod" }, persist = { "mod" } })
				sK.Remote.Member:Fire(
					srvPlayer,
					"808",
					{ name = "Spaced User", roles = { "mod", "vip" }, persist = { "mod" } }
				)
				sK.Remote.Members:Fire(srvPlayer, {
					["1"] = { name = "Player1", roles = { "creator" }, persist = { "creator" } },
					["707"] = { name = "ModMary", roles = { "mod" }, persist = { "mod" } },
					["808"] = { name = "Spaced User", roles = { "mod", "vip" }, persist = { "mod" } },
				})
				sK.Remote.Log:Fire(
					srvPlayer,
					{ "Test server log", sK.Logger:encode("INFO"), os.time(), nil, "Player1" }
				)
				local logsBuf = sK.Z.ser(sK.Data.Schema.logsRemote, {
					{ "Bulk log entry", sK.Logger:encode("COMMAND"), os.time(), nil, "Player1" },
				})
				if logsBuf then
					sK.Remote.Logs:Fire(srvPlayer, logsBuf)
				end
				sK.Remote.Settings:Fire(srvPlayer, { chatCommands = true, themeFontSize = 16 })
				sK.Remote.Role:Fire(srvPlayer, "vip", sK.Data.roles.vip)
				sK.Remote.Roles:Fire(srvPlayer, sK.Data.roles)
				sK.Remote.RolesNotification:Fire(srvPlayer)
				sK.Remote.SetCore:Fire(srvPlayer, "ChatActive", true)
				sK.Remote.DisplayBubble:Fire(srvPlayer, nil, "Bubble hello")
				sK.Remote.Announcement:Fire(srvPlayer, { Text = "Server Broadcast", From = 1, Duration = 1 })
				sK.Remote.Notify:Fire(srvPlayer, { Text = "Direct Remote Notify", From = 1, Duration = 1 })
				sK.Remote.VIPNotification:Fire(srvPlayer)
				-- Fire VIPNotification while already open, then close it and fire again
				sK.Remote.VIPNotification:Fire(srvPlayer)
				-- Fire VIPNotification with forcePopup = true to open VIP.popup directly
				sK.Remote.VIPNotification:Fire(srvPlayer, true)
				fastRun(0.1)
				sert.eq(cK.VIP.popup.Visible, true)
				cK.VIP.popup.Visible = false
				sK.Remote.Servers:Fire(srvPlayer, "job_abc123", { 12345, 4, os.time() - 60 })
				sK.Remote.Servers:Fire(srvPlayer, nil, {
					job_abc123 = { 12345, 4, os.time() - 60 },
					job_def456 = { 12345, 8, os.time() - 120 },
					job_ghi789 = { 67890, 2, os.time() - 30 },
				})
				fastRun(1)

				sert.eq(cK.Data.bans["202"] ~= nil, true)
				sert.eq(cK.Data.bans["404"] ~= nil, true)
				sert.eq(cK.Data.members["707"] ~= nil, true)
				sert.eq(cK.Data.members["808"] ~= nil, true)
				sert.eq(cK.Data.servers["job_abc123"] ~= nil, true)
				sert.eq(cK.Data.servers["job_ghi789"] ~= nil, true)

				-- Close any open Dialogs in LayerTopInset (including VIPNotification)
				for _, child in UI.LayerTopInset:GetChildren() do
					if child.Name == "Dialog" and child:FindFirstChild("Frame") then
						local exitBtn = child.Frame:FindFirstChild("Button")
						if exitBtn and exitBtn:IsA("TextButton") then
							exitBtn.Activated:Fire()
						end
					end
				end
				fastRun(0.2)

				-- TextChatService SendingMessage & MessageReceived, LocalPlayer.Idled, and Hotkey dispatch
				local tcs = cEnv.game:GetService("TextChatService")
				local logCount = #cK.Data.logs
				tcs.SendingMessage:Fire({ Text = ";version" })
				tcs.MessageReceived:Fire({
					TextSource = { UserId = 1 },
					Text = "Ignored without Success status",
				})
				tcs.MessageReceived:Fire({
					Status = Enum.TextChatMessageStatus.Success,
					TextChannel = { Name = "KA_Announce" },
					TextSource = { UserId = 1 },
					Text = "Ignored KA channel",
					Metadata = "",
				})
				tcs.MessageReceived:Fire({
					Status = Enum.TextChatMessageStatus.Success,
					TextSource = { UserId = 1 },
					Text = "Experience metadata message",
					Metadata = "meta",
				})
				tcs.MessageReceived:Fire({
					Status = Enum.TextChatMessageStatus.Success,
					TextSource = { UserId = 1 },
					Text = ";version",
					Metadata = "_K_CMD",
				})
				for _, emoteText in { "/e", "/e wave", "/E dance", "/emote", "/emote wave" } do
					tcs.MessageReceived:Fire({
						Status = Enum.TextChatMessageStatus.Success,
						TextSource = { UserId = 1 },
						Text = emoteText,
						Metadata = "",
					})
				end
				tcs.MessageReceived:Fire({
					Status = Enum.TextChatMessageStatus.Success,
					TextSource = { UserId = 1 },
					Text = "/everyone wave",
					Metadata = "",
				})
				tcs.MessageReceived:Fire({
					Status = Enum.TextChatMessageStatus.Success,
					TextSource = { UserId = 1 },
					Text = "Hello chat",
					Metadata = "",
				})
				fastRun(0.1)
				sert.eq(#cK.Data.logs, logCount + 3)
				sert.eq(cK.Data.logs[logCount + 1][1], "Experience metadata message")
				sert.eq(cK.Data.logs[logCount + 2][1], "/everyone wave")
				sert.eq(cK.Data.logs[logCount + 3][1], "Hello chat")
				sert.eq(cK.Logger:decode(cK.Data.logs[#cK.Data.logs][2]), "CHAT")

				-- Unauthorized clients (without `logs` command access) do not accumulate CHAT logs
				local origHasCommand = cK.Auth.hasCommand
				cK.Auth.hasCommand = function(userId, cmd)
					if cmd == "logs" then
						return false
					end
					return origHasCommand(userId, cmd)
				end
				tcs.MessageReceived:Fire({
					Status = Enum.TextChatMessageStatus.Success,
					TextSource = { UserId = 1 },
					Text = "Should not log when unauthorized",
					Metadata = "",
				})
				cK.Auth.hasCommand = origHasCommand
				fastRun(0.05)
				sert.eq(#cK.Data.logs, logCount + 3)
				cEnv.Players.LocalPlayer.Idled:Fire(120)

				local focusBox = cEnv.Instance.new("TextBox")
				UI.UserInputService.TextBoxFocused:Fire(focusBox)
				UI.UserInputService.InputBegan:Fire(
					makeInput(cEnv, { UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.Quote }),
					false
				)
				UI.UserInputService.TextBoxFocusReleased:Fire(focusBox)
				UI.UserInputService.InputBegan:Fire(
					makeInput(cEnv, { UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.Quote }),
					false
				)
				fastRun(0.2)

				-- RequestCommand RPC from server to client
				local reqResult = nil
				server:spawn(function()
					reqResult = sK.Remote.RequestCommand:Invoke(srvPlayer, srvPlayer, ";kill me")
				end)
				fastRun(0.5)
				for _, child in UI.LayerTopInset:GetChildren() do
					if
						child.Name == "Dialog"
						and child:FindFirstChild("Frame")
						and child.Frame:FindFirstChild("Actions")
					then
						child.Frame.Actions.RightAction.Activated:Fire()
					end
				end
				fastRun(0.5)
				sert.eq(reqResult, true)

				-- Verify RequestCommand.OnInvoke accepts a numeric userId (from cross-server ;global request)
				local req2Result = nil
				local reqThread = client:spawn(function()
					req2Result = cK.Remote.RequestCommand.OnInvoke(101, ";kill Target")
				end)
				fastRun(0.1)
				sert.eq(coroutine.status(reqThread), "suspended")
				for _, child in UI.LayerTopInset:GetChildren() do
					if
						child.Name == "Dialog"
						and child:FindFirstChild("Frame")
						and child.Frame:FindFirstChild("Actions")
					then
						child.Frame.Actions.LeftAction.Activated:Fire()
					end
				end
				fastRun(0.2)
				sert.eq(req2Result, false)

				-- Chatted / Remote.Command on client (wrong prefix warning + valid command)
				sK.Remote.Command:Fire(srvPlayer, "!help")
				fastRun(0.3)
				sK.Remote.Command:Fire(srvPlayer, ";version</b>")
				fastRun(0.3)
				-- chat commands the server already ran: the client runs its part and leaves errors to the server
				local function errorLogs(): number
					local count = 0
					for _, log in cK.Data.logs do
						if cK.Logger:decode(log[2]) == "ERROR" then
							count += 1
						end
					end
					return count
				end
				local errorsBefore = errorLogs()
				sK.Remote.Command:Fire(srvPlayer, ";nosuchcommand", true)
				fastRun(0.3)
				sert.eq(errorLogs(), errorsBefore)
				sK.Remote.Command:Fire(srvPlayer, ";nosuchcommand")
				fastRun(0.3)
				sert.eq(errorLogs(), errorsBefore + 1)

				-- chat commands missing required arguments open CommandBar pre-filled with trailing space for argument autocomplete
				cK.client.CommandBar.hide()
				fastRun(0.1)
				sert.eq(cK.client.CommandBar.Bar.Visible, false)
				sK.Remote.Command:Fire(srvPlayer, ";ban", true)
				fastRun(0.3)
				sert.eq(cK.client.CommandBar.Bar.Visible, true)
				sert.eq(cK.client.CommandBar.Input._input.Text, ";ban ")
				sert.eq(cK.client.CommandBar.Input._input.CursorPosition, 6)
				cK.client.CommandBar.hide()
				fastRun(0.1)

				-- kick (ignoreSelf first player arg) with no args also opens CommandBar pre-filled
				sK.Remote.Command:Fire(srvPlayer, ";kick", true)
				fastRun(0.3)
				sert.eq(cK.client.CommandBar.Bar.Visible, true)
				sert.eq(cK.client.CommandBar.Input._input.Text, ";kick ")
				cK.client.CommandBar.hide()
				fastRun(0.1)
			end)

			test("exercises Dashboard Bans, Members, and stale async lookup dialogs", function()
				local world, _srvMounted, cliMounted, _sK, cK = getOrCreateFullClientSut()
				local fastRun = makeFastRun(world)
				local UI = cK.UI
				local cEnv = cliMounted.env
				cK.Data.members["707"] = { name = "ModMary", roles = { "mod" }, persist = { "mod" } }
				cK.Data.members["808"] = { name = "Spaced User", roles = { "mod", "vip" }, persist = { "mod" } }
				cK.client.members(cK.Data.members, true)

				-- 6. Dashboard & Tabs (Bans, Members, Logs, Commands, Settings, Servers, Market, About, GetKA)
				local dash = cK.client.dashboard
				cK.Process.runCommands(cK, cEnv.Players.LocalPlayer.UserId, ";cmds")
				fastRun(0.2)
				cK.client.dashboardButton.Activated:Fire()
				cK.client.dashboardButton.MouseButton2Click:Fire()
				if cK.client.dashboardButton.TouchLongPress then
					cK.client.dashboardButton.TouchLongPress:Fire({}, Enum.UserInputState.Begin)
				end
				if cK.client.commandsButton then
					cK.client.commandsButton.Activated:Fire()
					cK.client.commandsButton.MouseButton2Click:Fire()
					if cK.client.commandsButton.TouchLongPress then
						cK.client.commandsButton.TouchLongPress:Fire({}, Enum.UserInputState.Begin)
					end
				end
				cK.client.commandsWindowVisible(true)
				UI.flush()
				sert.eq(dash.Commands._instance.Visible, true)
				cK.client.commandsWindowVisible(false)
				UI.flush()
				cK.client.settings.commandBarRank(false)
				cK.client.settings.dashboardRank(false)
				cK.client.settings.commandBarRank(0)
				cK.client.settings.dashboardRank(0)
				cK.client.hotkeys.dashboard.callback()
				dash.Window._instance.Visible = true
				fastRun(0.5)

				-- Trigger StatusBar and other cached Tooltips
				if UI.Class.Tooltip and UI.Class.Tooltip.Cache then
					for _, tip in UI.Class.Tooltip.Cache do
						if type(tip) == "table" and UI.isNode(tip.Visible) then
							tip.Visible(true)
							UI.flush()
							tip.Visible(false)
							UI.flush()
						end
					end
				end

				local function openScrollerTab(tab: any)
					tab.Enabled(true)
					tab._instance.Visible = true
					tab:updateList()
					fastRun(0.1)
					tab:forceRender()
					sert.eq(next(tab._lineItemCache) ~= nil, true)
				end

				local function filterScrollerTab(tab: any, queries: { string })
					for _, q in queries do
						tab._input._input.Text = q
						tab:refreshList()
						fastRun(0.1)
						if q ~= "" then
							tab:forceRender()
						end
					end
				end

				-- Bans tab (rendering, filtering left/right, newBanDialog, editBanButton, unbanDialog)
				openScrollerTab(dash.Bans)
				local emptyBanBtn = dash.Bans._instance:FindFirstChild("Button")
				sert.eq(emptyBanBtn ~= nil, true)
				sert.eq(emptyBanBtn.LayoutOrder, 1)
				sert.eq(dash.Bans._scroller.LayoutOrder, 2)
				sert.eq(emptyBanBtn.LayoutOrder < dash.Bans._scroller.LayoutOrder, true)

				-- Hover ban item tooltips
				for _, item in dash.Bans._lineItemCache do
					local tip = UI.Class.Tooltip.Cache and UI.Class.Tooltip.Cache[item._instance]
					if tip then
						tip.Visible(true)
						tip.Visible(false)
					end
				end

				-- Open newBanDialog via newBanButton in Bans._input
				local newBanBtn = dash.Bans._input._instance:FindFirstChild("Button")
				if newBanBtn and newBanBtn:IsA("TextButton") then
					newBanBtn.Activated:Fire()
					newBanBtn.Activated:Fire()
					newBanBtn.Activated:Fire()
					fastRun(0.1)
				end

				-- Exercise newBanDialog inputs (userId, invalid self, username, reason, Server/Forever/Timed ban)
				for _, child in dash.Bans._instance:GetChildren() do
					if child.Name ~= "Dialog" or not child:FindFirstChild("Frame") then
						continue
					end
					local boxes = {}
					local buttons = {}
					for _, desc in child:GetDescendants() do
						if desc:IsA("TextBox") then
							table.insert(boxes, desc)
						elseif desc:IsA("TextButton") then
							table.insert(buttons, desc)
						end
					end
					if boxes[1] then
						boxes[1].Text = "Player1"
						boxes[1].FocusLost:Fire(true)
						fastRun(0.1)
						boxes[1].Text = "BannedBob"
						boxes[1].FocusLost:Fire(true)
						fastRun(0.1)
						boxes[1].Text = "202"
						boxes[1].FocusLost:Fire(true)
						fastRun(0.1)
					end
					if boxes[2] then
						boxes[2].Text = "Test Ban Reason"
						boxes[2].FocusLost:Fire(true)
					end
					for _, b in buttons do
						if b.Name == "Button" then
							b.Activated:Fire()
						end
					end
					fastRun(0.2)
				end

				-- Click editBanButton and unbanButton on a ban item, then confirm unbanDialog
				for _, item in dash.Bans._lineItemCache do
					for _, child in item._instance:GetChildren() do
						if child:IsA("TextButton") then
							child.Activated:Fire()
							fastRun(0.1)
						end
					end
					break
				end
				for _, child in dash.Bans._instance:GetChildren() do
					if
						child.Name == "Dialog"
						and child:FindFirstChild("Frame")
						and child.Frame:FindFirstChild("Actions")
					then
						child.Frame.Actions.RightAction.Activated:Fire()
						fastRun(0.1)
					end
				end

				filterScrollerTab(dash.Bans, { "bob", "forever", "" })

				-- Members tab (rendering, role chips, newRoleDialog, roleMenu, filtering)
				openScrollerTab(dash.Members)

				-- Open newRoleDialog via newMemberButton
				local newMemBtn = dash.Members._input._instance:FindFirstChild("Button")
				if newMemBtn and newMemBtn:IsA("TextButton") then
					newMemBtn.Activated:Fire()
					newMemBtn.Activated:Fire()
					newMemBtn.Activated:Fire()
					fastRun(0.1)
				end
				for _, child in dash.Members._instance:GetChildren() do
					if child.Name ~= "Dialog" or not child:FindFirstChild("Frame") then
						continue
					end
					for _, desc in child:GetDescendants() do
						if desc:IsA("TextBox") then
							desc.Text = "Player1"
							desc.FocusLost:Fire(true)
							fastRun(0.1)
							desc.Text = "ModMary"
							desc.FocusLost:Fire(true)
							fastRun(0.1)
							desc.Text = "707"
							desc.FocusLost:Fire(true)
							fastRun(0.1)
							break
						end
					end
					for _, desc in child:GetDescendants() do
						if desc:IsA("TextButton") then
							desc.Activated:Fire()
						end
					end
					fastRun(0.2)
				end

				-- Click add role button and role chip remove buttons on a member item
				for _, item in dash.Members._lineItemCache do
					for _, desc in item._instance:GetDescendants() do
						if desc:IsA("TextButton") then
							desc.Activated:Fire()
							fastRun(0.05)
						end
					end
					break
				end
				-- Click a role button in roleMenu (under UI.LayerTop)
				for _, menuChild in UI.LayerTop:GetChildren() do
					if menuChild.Name ~= "Menu" or not menuChild.Visible then
						continue
					end
					for _, btn in menuChild:GetDescendants() do
						if btn:IsA("TextButton") then
							btn.Activated:Fire()
							break
						end
					end
				end
				fastRun(0.2)

				filterScrollerTab(dash.Members, { "mary", "" })

				-- Stale lookup target: while a name lookup yields, the ban/role target is nil so the dialog
				-- can't act on the previous user, and a superseded lookup never overwrites a newer one
				do
					local playersMethods = rawget(cEnv.Players, "_methods")
					local origLookup = playersMethods.GetUserIdFromNameAsync
					local lookupDelay: { [string]: number } = { bannedbob = 0.3, adminalice = 0.15 }
					playersMethods.GetUserIdFromNameAsync = function(self, name)
						local delay = lookupDelay[string.lower(name)]
						if delay then
							cEnv.task.wait(delay)
						end
						return origLookup(self, name)
					end

					local function findDialog(titles: { string }): any
						for _, child in UI.LayerTop:GetChildren() do
							for _, desc in child:GetDescendants() do
								if desc:IsA("TextLabel") and desc.Name ~= "Label" and table.find(titles, desc.Text) then
									return child
								end
							end
						end
						return nil
					end
					local function dialogParts(dialog: any, actionLabel: string)
						local avatar, box, button
						for _, desc in dialog:GetDescendants() do
							if
								not avatar
								and desc:IsA("ImageLabel")
								and string.find(desc.Image, "AvatarHeadShot", 1, true)
							then
								avatar = desc
							elseif desc:IsA("TextLabel") and desc.Name == "Label" and desc.Text == actionLabel then
								button = desc:FindFirstAncestorWhichIsA("TextButton")
							end
						end
						-- the target input sits beside the avatar in the "User" row
						if avatar then
							for _, desc in avatar.Parent:GetDescendants() do
								if desc:IsA("TextBox") then
									box = desc
									break
								end
							end
						end
						return avatar, box, button
					end
					local function enter(box: any, text: string)
						box.Text = text
						box.FocusLost:Fire(true)
					end
					local function targetId(avatar: any): string?
						UI.flush()
						return string.match(avatar.Image, "id=([^&]*)")
					end

					-- Ban dialog
					local banDialog = findDialog({ "New Ban", "Edit Ban" })
					sert.eq(banDialog ~= nil, true)
					local banAvatar, banBox, banButton = dialogParts(banDialog, "Ban")
					sert.eq(banAvatar ~= nil and banBox ~= nil and banButton ~= nil, true)
					local bansFired = {}
					local origBanFire = cK.Remote.Ban.Fire
					cK.Remote.Ban.Fire = function(_self, userId)
						table.insert(bansFired, userId)
					end

					enter(banBox, "707")
					fastRun(0.1)
					sert.eq(targetId(banAvatar), "707")

					enter(banBox, "BannedBob")
					fastRun(0.1)
					sert.eq(targetId(banAvatar), "nil")
					banButton.Activated:Fire()
					sert.eq(#bansFired, 0)

					-- AdminAlice resolves first, then the slower BannedBob lookup is dropped
					enter(banBox, "AdminAlice")
					fastRun(0.1)
					sert.eq(targetId(banAvatar), "nil")
					fastRun(0.1)
					sert.eq(targetId(banAvatar), "505")
					fastRun(0.2)
					sert.eq(targetId(banAvatar), "505")
					banButton.Activated:Fire()
					sert.eq(bansFired, { 505 })
					cK.Remote.Ban.Fire = origBanFire

					-- Members role dialog
					local roleDialog = findDialog({ "Add Role" })
					sert.eq(roleDialog ~= nil, true)
					local roleAvatar, roleBox, confirmButton = dialogParts(roleDialog, "Confirm")
					sert.eq(roleAvatar ~= nil and roleBox ~= nil and confirmButton ~= nil, true)
					local commandsRun = {}
					local origRunCommands = cK.Process.runCommands
					cK.Process.runCommands = function(_K, _from, cmd)
						table.insert(commandsRun, cmd)
					end

					enter(roleBox, "707")
					fastRun(0.1)
					sert.eq(targetId(roleAvatar), "707")

					enter(roleBox, "BannedBob")
					fastRun(0.1)
					sert.eq(targetId(roleAvatar), "nil")
					confirmButton.Activated:Fire()
					sert.eq(#commandsRun, 0)

					enter(roleBox, "AdminAlice")
					fastRun(0.1)
					sert.eq(targetId(roleAvatar), "nil")
					fastRun(0.1)
					sert.eq(targetId(roleAvatar), "505")
					fastRun(0.2)
					sert.eq(targetId(roleAvatar), "505")
					confirmButton.Activated:Fire()
					sert.eq(#commandsRun, 1)
					sert.eq(string.find(commandsRun[1], "role 505 ", 1, true) ~= nil, true)
					cK.Process.runCommands = origRunCommands

					playersMethods.GetUserIdFromNameAsync = origLookup
				end
			end)

			test("exercises Dashboard Logs, Commands, Servers, Settings, About, Market, and GetKA", function()
				local world, _srvMounted, cliMounted, _sK, cK = getOrCreateFullClientSut()
				local fastRun = makeFastRun(world)
				local UI = cK.UI
				local cEnv = cliMounted.env
				local dash = cK.client.dashboard
				dash.Window._instance.Visible = true
				cK.Data.servers["job_abc123"] = { 12345, 4, os.time() - 60 }
				cK.Data.servers["job_def456"] = { 12345, 8, os.time() - 120 }
				cK.Data.servers["job_ghi789"] = { 67890, 2, os.time() - 30 }
				cK.client.servers(cK.Data.servers, true)

				local function openScrollerTab(tab: any)
					tab.Enabled(true)
					tab._instance.Visible = true
					tab:updateList()
					fastRun(0.1)
					tab:forceRender()
					sert.eq(next(tab._lineItemCache) ~= nil, true)
				end

				local function filterScrollerTab(tab: any, queries: { string })
					for _, q in queries do
						tab._input._input.Text = q
						tab:refreshList()
						fastRun(0.1)
						if q ~= "" then
							tab:forceRender()
						end
					end
				end

				-- Logs tab (client/global/server tags, tooltip, filterMenu checkboxes, text filter)
				table.insert(
					cK.Data.logs,
					{ "Client debug log", cK.Logger:encode("DEBUG"), os.time(), 1, "Player1", true }
				)
				table.insert(
					cK.Data.logs,
					{ "Global warn log", cK.Logger:encode("WARN"), os.time(), 1, "Player1", false }
				)
				-- chat logs filter is enabled by default on the client
				sert.eq(dash.Logs.logTypeFilter.CHAT:peek(), true)
				table.insert(cK.Data.logs, { "Client chat line", cK.Logger:encode("CHAT"), os.time(), 1, "Player1" })
				openScrollerTab(dash.Logs)

				for _, item in dash.Logs._lineItemCache do
					local tip = UI.Class.Tooltip.Cache and UI.Class.Tooltip.Cache[item]
					if tip then
						tip.Visible(true)
						tip.Visible(false)
						break
					end
				end
				local logFilterBtn = dash.Logs._input._instance:FindFirstChild("Button")
				if logFilterBtn and logFilterBtn:IsA("TextButton") then
					logFilterBtn.Activated:Fire()
					fastRun(0.1)
				end
				for _, menuChild in UI.LayerTop:GetChildren() do
					if menuChild.Name ~= "Menu" or not menuChild.Visible then
						continue
					end
					for _, btn in menuChild:GetDescendants() do
						if btn:IsA("TextButton") then
							btn.Activated:Fire()
							break
						end
					end
				end
				fastRun(0.2)

				filterScrollerTab(dash.Logs, { "server", "" })

				-- Commands tab (authorized vs restricted VIP/gamepass, purchaseButton, filter by role/name/description)
				if cK.Registry.commands.ban then
					cK.Registry.commands.ban.LocalPlayerAuthorized = false
					cK.Registry.commands.ban.RestrictedToRole = cK.Data.roles.vip
				end
				openScrollerTab(dash.Commands)

				local hoveredCmdTip = false
				local clickedCmdBtn = false
				for _, item in dash.Commands._lineItemCache do
					if not hoveredCmdTip then
						local tip = UI.Class.Tooltip.Cache and UI.Class.Tooltip.Cache[item._instance]
						if tip then
							tip.Visible(true)
							tip.Visible(false)
							hoveredCmdTip = true
						end
					end
					if not clickedCmdBtn then
						for _, desc in item._instance:GetDescendants() do
							if desc:IsA("TextButton") and desc.Visible then
								desc.Activated:Fire()
								clickedCmdBtn = true
								break
							end
						end
					end
					if hoveredCmdTip and clickedCmdBtn then
						break
					end
				end
				cK.client.settings.onlyShowUsableCommands(true)
				fastRun(0.25)
				local clientCmdFolder = cK.Service.TextChat:FindFirstChild("TextChatCommands_KA")
				if clientCmdFolder then
					local pingCmd = clientCmdFolder:FindFirstChild("ping")
					sert.eq(pingCmd ~= nil and pingCmd.AutocompleteVisible, true)
					local pingCmd2 = clientCmdFolder:FindFirstChild("ping2")
					if pingCmd2 then
						sert.eq(pingCmd2.AutocompleteVisible, false)
					end
					if pingCmd then
						local channelsFolder = cK.Service.TextChat:FindFirstChild("TextChannels")
							or cEnv.Instance.new("Folder", cK.Service.TextChat)
						channelsFolder.Name = "TextChannels"
						local generalChannel = channelsFolder:FindFirstChild("RBXGeneral")
							or cEnv.Instance.new("TextChannel", channelsFolder)
						generalChannel.Name = "RBXGeneral"
						local sentChatMessages = {}
						local sentChatMetadatas = {}
						local enabledDuringSend = nil
						rawset(generalChannel, "_methods", {
							SendAsync = function(_self, msgText, msgMetadata)
								enabledDuringSend = pingCmd.Enabled
								table.insert(sentChatMessages, msgText)
								table.insert(sentChatMetadatas, msgMetadata)
							end,
						})
						-- Other user and slash commands do not re-send to chat
						pingCmd.Triggered:Fire({ UserId = 99999 }, ";ping me")
						pingCmd.Triggered:Fire({ UserId = cK.LocalPlayer.UserId }, "/ping me")
						pingCmd.Triggered:Fire({ UserId = cK.LocalPlayer.UserId }, "   ")
						-- Non-slash command temporarily disables the TextChatCommand and re-sends to chat with _K_CMD sentinel
						pingCmd.Triggered:Fire({ UserId = cK.LocalPlayer.UserId }, ";ping me")
						fastRun(0.1)
						sert.eq(sentChatMessages, { ";ping me" })
						sert.eq(sentChatMetadatas, { "_K_CMD" })
						sert.eq(enabledDuringSend, false)
						sert.eq(pingCmd.Enabled, true)

						-- Echoed command fallback skips CHAT logging even if experience callback overwrote Metadata
						local preEchoCount = #cK.Data.logs
						cK.Service.TextChat.MessageReceived:Fire({
							Status = Enum.TextChatMessageStatus.Success,
							TextSource = { UserId = cK.LocalPlayer.UserId },
							Text = `{pingCmd.PrimaryAlias} me`,
							Metadata = "overwritten_by_game",
						})
						fastRun(0.05)
						sert.eq(#cK.Data.logs, preEchoCount)

						-- PlayerPrefix attribute gates per-player custom prefix TextChatCommands
						local customCmd = cEnv.Instance.new("TextChatCommand")
						customCmd.Name = "ping"
						customCmd.PrimaryAlias = "!ping"
						customCmd.SecondaryAlias = "!pong"
						customCmd:SetAttribute("PlayerPrefix", "!")
						customCmd.Parent = clientCmdFolder
						fastRun(0.1)
						sert.eq(customCmd.Enabled, false)
						sert.eq(customCmd.AutocompleteVisible, false)

						cK.Data.playerPrefix[cK.LocalPlayer.UserId] = "!"
						cK.client.playerPrefix("!")
						fastRun(0.1)
						sert.eq(customCmd.Enabled, true)
						sert.eq(customCmd.AutocompleteVisible, true)

						cK.Data.playerPrefix[cK.LocalPlayer.UserId] = nil
						cK.client.playerPrefix(";")
						fastRun(0.1)
						sert.eq(customCmd.Enabled, false)
						sert.eq(customCmd.AutocompleteVisible, false)
						customCmd:Destroy()
					end
				end
				cK.client.settings.chatCommands(false)
				cK.Data.settings.chatCommands = false
				fastRun(0.25)
				if clientCmdFolder then
					local pingCmd = clientCmdFolder:FindFirstChild("ping")
					sert.eq(pingCmd ~= nil and pingCmd.AutocompleteVisible, false)
				end
				cK.Data.settings.chatCommands = true
				cK.client.settings.chatCommands(true)
				cK.client.settings.onlyShowUsableCommands(false)
				fastRun(0.25)
				local chatInputBar = cK.Service.TextChat:FindFirstChildOfClass("ChatInputBarConfiguration")
				if chatInputBar then
					chatInputBar.IsFocused = true
					chatInputBar.IsFocused = false
				end

				filterScrollerTab(dash.Commands, { "role=vip", "ban", "rich suggestions", "" })
				if cK.Registry.commands.ban then
					cK.Registry.commands.ban.LocalPlayerAuthorized = true
				end

				-- Servers tab (rendering, place name cache hit & miss, sort, Join button)
				openScrollerTab(dash.Servers)
				local emptyServersLabel = dash.Servers._instance:FindFirstChild("EmptyListLabel")
				sert.eq(emptyServersLabel ~= nil, true)
				sert.eq(emptyServersLabel.LayoutOrder, 1)
				sert.eq(dash.Servers._scroller.LayoutOrder, 2)
				sert.eq(emptyServersLabel.LayoutOrder < dash.Servers._scroller.LayoutOrder, true)
				sert.eq(dash.Logs._input._instance.LayoutOrder, -1)
				sert.eq(dash.Members._input._instance.LayoutOrder, -1)
				for _, item in dash.Servers._lineItemCache do
					if item.Join and item.Join._instance then
						item.Join._instance.Activated:Fire()
					end
				end
				fastRun(0.2)

				-- Settings tab (filter, modifying inputs/switches/sliders, resetChanges & confirmChanges)
				dash.Tabs._pages:JumpTo(dash.Tabs._containerCache[dash.Settings._instance])
				fastRun(0.5)
				dash.Settings._input._input.Text = "theme"
				fastRun(0.1)
				dash.Settings._input._input.Text = ""
				fastRun(0.1)

				local modifiedPrefix = false
				local clickedSettingBtn = false
				for _, desc in dash.Settings._instance:GetDescendants() do
					if not modifiedPrefix and desc:IsA("TextBox") and desc.Text == ";" then
						desc.Text = ":"
						desc.FocusLost:Fire(true)
						modifiedPrefix = true
					elseif not clickedSettingBtn and desc:IsA("TextButton") and desc.Name == "Button" then
						desc.Activated:Fire()
						clickedSettingBtn = true
					end
					if modifiedPrefix and clickedSettingBtn then
						break
					end
				end
				fastRun(0.1)
				-- Confirm settingsDialog if visible
				for _, child in dash.Settings._instance:GetChildren() do
					if
						child.Name == "Dialog"
						and child:FindFirstChild("Frame")
						and child.Frame:FindFirstChild("Actions")
					then
						child.Frame.Actions.LeftAction.Activated:Fire()
						fastRun(0.1)
						child.Frame.Actions.RightAction.Activated:Fire()
						fastRun(0.1)
					end
				end

				-- About & Market tabs
				dash.Tabs._pages:JumpTo(dash.Tabs._containerCache[dash.About._instance])
				fastRun(0.2)
				do
					local AboutModule = cliMounted.Client:FindFirstChild("About")
					local Credits = cliMounted.env:require(AboutModule:FindFirstChild("Credits"))
					local Contributions = cliMounted.env:require(AboutModule:FindFirstChild("Contributions"))
					local Order = cliMounted.env:require(AboutModule:FindFirstChild("Order"))

					local function ids(list)
						local out = {}
						for idx, person in list do
							out[idx] = person.Id
						end
						return out
					end

					-- Shared fixture order & tie-breaking rules (matches test/unit/CreditsOrder.json)
					local fixtureData = {
						recent = {
							ALPHA = 3,
							beta = 10,
							gamma = 3,
							eps = 3,
							unmapped = 1,
							zeta = 1,
							theta = 2,
							eta = 1,
						},
						names = {
							[1] = { name = "zed", displayName = "Zed", verified = false },
							[2] = { name = "bob", displayName = "Bob", verified = false },
							[3] = { name = "cy", displayName = "Cy", verified = false },
							[4] = { name = "amy", displayName = "amy", verified = false },
							[5] = { name = "al", displayName = "Al", verified = false },
							[7] = { name = "dee", displayName = "Dee", verified = false },
							[8] = { name = "Ébé", displayName = "Ébé", verified = false },
							[9] = { name = "éa", displayName = "éa", verified = false },
							[10] = { name = "sam_b", displayName = "Sam", verified = false },
							[11] = { name = "Sam_a", displayName = "sam", verified = false },
							[12] = { name = "sam_a", displayName = "Sam", verified = false },
							[14] = { name = "aaa", displayName = "Bob", verified = false },
							[15] = { name = "zeta_u", displayName = "Zeta", verified = false },
							[16] = { name = "theta", displayName = "Theta", verified = false },
							[17] = { name = "eta", displayName = "Eta", verified = false },
						},
					}
					local fixturePeople = {
						{ Id = 1 },
						{ Id = 2, GitHub = "alpha" },
						{ Id = 3, GitHub = "Beta" },
						{ Id = 4 },
						{ Id = 5, GitHub = "gamma" },
						{ Id = 6 },
						{ Id = 7, GitHub = "delta" },
						{ Id = 8 },
						{ Id = 9 },
						{ Id = 10 },
						{ Id = 11 },
						{ Id = 12 },
						{ Id = 13 },
						{ Id = 14, GitHub = "eps" },
						{ Id = 15, GitHub = "zeta" },
						{ Id = 16, GitHub = "theta" },
						{ Id = 17, GitHub = "eta" },
					}
					sert.eq(ids(Order.active(fixturePeople, fixtureData)), { 3, 5, 14, 2, 16 })
					sert.eq(ids(Order.plain(fixturePeople, fixtureData)), {
						4,
						7,
						17,
						11,
						12,
						10,
						1,
						15,
						8,
						9,
						6,
						13,
					})
					-- Also exercise active tie-breaking when displayNames or names are missing
					local tiePeople = {
						{ Id = 20, GitHub = "alpha" },
						{ Id = 10, GitHub = "Beta" },
						{ Id = 30, GitHub = "gamma" },
					}
					local tieData = {
						recent = { alpha = 4, Beta = 4, gamma = 4 },
						names = {
							[10] = { name = "same", displayName = "Same", verified = false },
							[20] = { name = "same", displayName = "Same", verified = false },
						},
					}
					sert.eq(ids(Order.active(tiePeople, tieData)), { 10, 20, 30 })

					-- Generated data invariants + luv2trilogy (3727541395)
					local activeList = Order.active(Credits.people)
					local plainList = Order.plain(Credits.people)
					sert.eq(#activeList + #plainList, #Credits.people)
					sert.eq(Credits.specialThanks.Id, 16)
					local foundLuv2 = false
					for _, person in Credits.people do
						sert.eq(Contributions.names[person.Id] ~= nil, true)
						sert.eq(person.Id ~= 16, true)
						if person.Id == 3727541395 then
							foundLuv2 = true
							sert.eq(person.GitHub, "luv2trilogy")
						end
					end
					sert.eq(foundLuv2, true)

					local creditsFrame = dash.About._instance:FindFirstChild("Credits", true)
					sert.eq(creditsFrame ~= nil, true)
					sert.eq(creditsFrame:FindFirstChild("Active contributors") ~= nil, true)
					sert.eq(creditsFrame:FindFirstChild("Contributors") ~= nil, true)
					sert.eq(creditsFrame:FindFirstChild("Special Thanks") ~= nil, true)
				end
				for _, desc in dash.About._instance:GetDescendants() do
					if desc:IsA("TextButton") or desc:IsA("ImageButton") then
						desc.Activated:Fire()
						break
					end
				end
				cEnv.game
					:GetService("LogService").MessageOut
					:Fire("AllowThirdPartySales has blocked the purchase", Enum.MessageType.MessageWarning)
				fastRun(0.2)

				dash.Tabs._pages:JumpTo(dash.Tabs._containerCache[dash.Market._instance])
				fastRun(0.2)
				cEnv.Players.LocalPlayer:SetAttribute("_KDonationLevel", 3)
				local marketSvc = cEnv.game:GetService("MarketplaceService")
				marketSvc.PromptPurchaseFinished:Fire(cEnv.Players.LocalPlayer, 90666920573726, true)
				marketSvc.PromptBulkPurchaseFinished:Fire(
					cEnv.Players.LocalPlayer,
					Enum.MarketplaceBulkPurchasePromptStatus.Completed,
					{ Items = { { Id = "90666920573726", Status = Enum.MarketplaceItemPurchaseStatus.Success } } }
				)
				marketSvc.PromptGamePassPurchaseFinished:Fire(cEnv.Players.LocalPlayer, 5411126, true)
				fastRun(0.2)
				local clickedMarketText, clickedMarketImg = false, false
				for _, desc in dash.Market._instance:GetDescendants() do
					if not clickedMarketText and desc:IsA("TextButton") then
						desc.Activated:Fire()
						clickedMarketText = true
					elseif not clickedMarketImg and desc:IsA("ImageButton") then
						desc.Activated:Fire()
						clickedMarketImg = true
					end
					if clickedMarketText and clickedMarketImg then
						break
					end
				end
				fastRun(0.2)

				-- GetKA hook (chat commands with silent=false are ignored; 3 silent UI/CommandBar executions trigger corner notification)
				for _ = 1, 4 do
					cK.Hook.runPreparedCommands:Fire(1, "help", ";help", false)
				end
				fastRun(0.1)
				for _ = 1, 3 do
					cK.Hook.runPreparedCommands:Fire(1, "help", ";help", true)
				end
				fastRun(0.2)
			end)

			test("updates chat command visibility in place without reparenting commands or the folder", function()
				local world, _srvMounted, cliMounted, _sK, cK = getOrCreateFullClientSut()
				local cEnv = cliMounted.env
				local textChat = cK.Service.TextChat
				-- the server folder doesn't replicate in this world, so add it the way replication would
				local folder = textChat:FindFirstChild("TextChatCommands_KA")
				if not folder then
					folder = cEnv.Instance.new("Folder")
					folder.Name = "TextChatCommands_KA"
					folder.Parent = textChat
				end
				world:run(0.05)
				sert.eq(folder.Parent, textChat)
				cK.Data.settings.chatCommands = true
				cK.client.settings.chatCommands(true)
				world:run(0.1)

				local readds, folderRemoved = 0, 0
				local conns = {
					folder.ChildRemoved:Connect(function()
						readds += 1
					end),
					textChat.ChildRemoved:Connect(function(child)
						if child == folder then
							folderRemoved += 1
						end
					end),
				}

				-- the server adds commands one at a time, the client flips each to visible and re-adds it once
				local added = {}
				for i = 1, 230 do
					local cmd = cEnv.Instance.new("TextChatCommand")
					cmd.Name = "ping"
					cmd.PrimaryAlias = `/pingbatch{i}`
					cmd.AutocompleteVisible = false
					cmd.Parent = folder
					table.insert(added, cmd)
				end
				world:run(0.3)
				local function countAdded()
					local visible, inFolder = 0, 0
					for _, cmd in added do
						if cmd.AutocompleteVisible and cmd.Enabled then
							visible += 1
						end
						if cmd.Parent == folder then
							inFolder += 1
						end
					end
					return visible, inFolder
				end
				local visible, inFolder = countAdded()
				sert.eq(visible, #added)
				sert.eq(inFolder, #added)
				sert.eq(readds, 0)
				sert.eq(folderRemoved, 0)

				-- turning chat commands off flips every command in place with zero reparents
				readds = 0
				cK.Data.settings.chatCommands = false
				cK.client.settings.chatCommands(false)
				local maxPerFrame, framesWithReadds = 0, 0
				for _ = 1, 60 do
					local before = readds
					world:run(1 / 60)
					local count = readds - before
					maxPerFrame = math.max(maxPerFrame, count)
					if count > 0 then
						framesWithReadds += 1
					end
				end
				visible, inFolder = countAdded()
				sert.eq(visible, 0)
				sert.eq(inFolder, #added)
				sert.eq(readds, 0)
				sert.eq(framesWithReadds, 0)
				sert.eq(maxPerFrame, 0)
				sert.eq(folderRemoved, 0)

				cK.Data.settings.chatCommands = true
				cK.client.settings.chatCommands(true)
				world:run(1)
				visible = countAdded()
				sert.eq(visible, #added)

				-- a sync with nothing changed re-adds nothing
				readds = 0
				added[1]:SetAttribute("PlayerPrefix", nil)
				world:run(0.2)
				sert.eq(readds, 0)

				for _, conn in conns do
					conn:Disconnect()
				end
				for _, cmd in added do
					cmd:Destroy()
				end
				world:run(0.1)
			end)

			test(
				"exercises Character movement/double-jump and Explorer tree, selection, drag-and-drop, and search",
				function()
					local world = sert.sim.new({ backing = true })
					local server = world:server()
					local client = server:client(1, "Player1")
					local function fastRun(seconds: number)
						local dt = 1 / 60
						if seconds <= dt * 3 then
							world:run(seconds)
						else
							world:step(dt)
							world:step(seconds - dt * 2)
							world:step(dt)
						end
					end

					local cliMounted = setupClientEnv(client, { mockRemote = true })
					local cK = cliMounted:requireK()
					local UI = cliMounted.env:require(cliMounted.Client.UI)
					if UI.registerClasses then
						UI.registerClasses()
					end
					UI.Pointer = UI.signal({ Position = Vector3.new(100, 100, 0) })
					cK.UI = UI
					cK.IsClient = true
					cK.LocalPlayer = cliMounted.env.Players.LocalPlayer
					cK.client = {
						rank = cK.Flux.signal(0),
						Character = cliMounted.env:require(cliMounted.Client.Character),
						Explorer = cliMounted.env:require(cliMounted.Client.Explorer),
					}
					local cEnv = cliMounted.env
					local origUisMethods = rawget(UI.UserInputService, "_methods")

					-- 7. Character module (fly, noclip, Freefall double-jump, double-tap stop, CharacterRemoving)
					local charModel = cEnv.Instance.new("Model")
					charModel.Name = "Player1"
					local rootPart = cEnv.Instance.new("Part")
					rootPart.Name = "HumanoidRootPart"
					rootPart.Parent = charModel
					local hum = cEnv.Instance.new("Humanoid")
					hum.RootPart = rootPart
					hum.Parent = charModel
					charModel.Parent = cEnv.workspace
					cEnv.Players.LocalPlayer.Character = charModel
					cEnv.Players.LocalPlayer.CharacterAdded:Fire(charModel)
					fastRun(0.2)

					local Character = cK.client.Character
					Character.noclip(true)
					sert.eq(rootPart.CanCollide, false)
					Character.noclip(false)
					sert.eq(rootPart.CanCollide, true)

					Character.fly(true, true)
					sert.eq(hum.PlatformStand, true)
					hum.Jump = true
					hum.MoveDirection = Vector3.new(1, 0, 0)
					fastRun(0.2)
					hum.Jump = false
					hum.MoveDirection = Vector3.zero
					fastRun(0.2)
					Character.fly(false)
					sert.eq(hum.PlatformStand, false)

					cEnv.Players.LocalPlayer:SetAttribute("_KFly", 100)
					cEnv.Players.LocalPlayer:SetAttribute("_KNoClip", true)
					Character.fly(false)
					Character.noclip(false)
					fastRun(0.4)
					-- Freefall -> wait 0.15s -> canDoubleJump = true -> JumpRequest activates fly & noclip
					hum:ChangeState(Enum.HumanoidStateType.Freefall)
					client:spawn(function()
						hum.StateChanged:Fire(Enum.HumanoidStateType.Jumping, Enum.HumanoidStateType.Freefall)
					end)
					fastRun(0.2)
					UI.UserInputService.JumpRequest:Fire()
					sert.eq(hum.PlatformStand, true)
					hum.StateChanged:Fire(Enum.HumanoidStateType.Freefall, Enum.HumanoidStateType.Landed)
					-- Double-tap JumpRequest (< 0.4s since lastJump in tick()) stops fly & noclip
					UI.UserInputService.JumpRequest:Fire()
					sert.eq(hum.PlatformStand, false)
					cEnv.Players.LocalPlayer:SetAttribute("_KFly", nil)
					cEnv.Players.LocalPlayer:SetAttribute("_KNoClip", false)
					cEnv.Players.LocalPlayer.CharacterRemoving:Fire(charModel)
					fastRun(0.2)

					-- 8. Explorer (icons, expand/collapse, multi-select, copy/paste/delete, drag-and-drop, search, removal)
					local testPart = cEnv.Instance.new("Part")
					testPart.Name = "ExplorerTestPart"
					testPart.Parent = cEnv.workspace

					local testFolder = cEnv.Instance.new("Folder")
					testFolder.Name = "ExplorerFolder"
					testFolder.Parent = cEnv.workspace
					local testVal = cEnv.Instance.new("IntValue")
					testVal.Name = "ExplorerVal"
					testVal.Parent = testFolder
					local testCfg = cEnv.Instance.new("Configuration")
					testCfg.Name = "ExplorerCfg"
					testCfg.Parent = cEnv.workspace

					cK.client.Explorer.Show()
					fastRun(1.2)
					cK.client.Explorer.Show()
					fastRun(0.2)

					local expWin = UI.LayerTopInset:FindFirstChild("Explorer")
					sert.eq(expWin ~= nil, true)
					local expScrollerFrame = expWin:FindFirstChild("UIContent", true)
						and expWin.Frame.UIContent:FindFirstChild("ScrollerFast")
					sert.eq(expScrollerFrame ~= nil, true)

					-- Exercise Explorer item buttons (Expand, double-click expand, Ctrl multi-select, & Drag-and-Drop)
					local innerScroller = expScrollerFrame:FindFirstChild("ScrollerFast")
					local renderedBtns = {}
					if innerScroller then
						for _, itemBtn in innerScroller:GetChildren() do
							if not itemBtn:IsA("TextButton") then
								continue
							end
							table.insert(renderedBtns, itemBtn)
							if #renderedBtns <= 2 then
								if itemBtn.TouchLongPress then
									itemBtn.TouchLongPress:Fire(
										{ Position = Vector3.new(10, 10, 0) },
										Enum.UserInputState.Begin
									)
								end
								local expandBtn = itemBtn:FindFirstChild("Expand")
								if expandBtn and expandBtn:IsA("TextButton") then
									expandBtn.Activated:Fire()
								end
								-- Double-click itemBtn (< 0.3s)
								itemBtn.Activated:Fire()
								itemBtn.Activated:Fire()
							end
						end
					end
					sert.eq(#renderedBtns > 0, true)
					fastRun(0.35)
					if renderedBtns[1] then
						renderedBtns[1].Activated:Fire()
						fastRun(0.35)
					end

					-- Ctrl+click multi-select toggle (off then back on) & keyboard shortcuts (Ctrl+C, Ctrl+V, Delete)
					local ctrlHeld = true
					local mouseDown = true
					rawset(
						UI.UserInputService,
						"_methods",
						setmetatable({
							IsKeyDown = function(_self, kc)
								return ctrlHeld and kc == Enum.KeyCode.LeftControl
							end,
							IsMouseButtonPressed = function(_self, btn)
								return mouseDown and btn == Enum.UserInputType.MouseButton1
							end,
						}, { __index = origUisMethods })
					)

					if renderedBtns[1] then
						renderedBtns[1].Activated:Fire()
						fastRun(0.35)
						renderedBtns[1].Activated:Fire()
					end
					UI.UserInputService.InputBegan:Fire(
						makeInput(cEnv, { UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.C }),
						false
					)
					UI.UserInputService.InputBegan:Fire(
						makeInput(cEnv, { UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.V }),
						false
					)
					fastRun(0.2)

					-- Drag-and-Drop between two Explorer item buttons
					if renderedBtns[1] and renderedBtns[2] then
						renderedBtns[1].InputBegan:Fire(
							makeInput(
								cEnv,
								{ UserInputType = Enum.UserInputType.MouseButton1, Position = Vector3.new(10, 10, 0) }
							),
							false
						)
						renderedBtns[1].InputChanged:Fire(
							makeInput(
								cEnv,
								{ UserInputType = Enum.UserInputType.MouseMovement, Position = Vector3.new(30, 30, 0) }
							),
							false
						)
						renderedBtns[2].InputChanged:Fire(
							makeInput(
								cEnv,
								{ UserInputType = Enum.UserInputType.MouseMovement, Position = Vector3.new(35, 35, 0) }
							),
							false
						)
						UI.UserInputService.InputChanged:Fire(
							makeInput(
								cEnv,
								{ UserInputType = Enum.UserInputType.MouseMovement, Position = Vector3.new(40, 40, 0) }
							),
							false
						)
						UI.UserInputService.InputEnded:Fire(
							makeInput(
								cEnv,
								{ UserInputType = Enum.UserInputType.MouseButton1, Position = Vector3.new(40, 40, 0) }
							),
							false
						)
						fastRun(0.35)
					end

					ctrlHeld = false
					mouseDown = false
					rawset(UI.UserInputService, "_methods", origUisMethods)

					if renderedBtns[1] then
						renderedBtns[1].Activated:Fire()
					end

					-- Trigger Copy (6), Paste (7, only when a node is selected), and Delete (4) in order
					local expTitleBar = expWin.Frame.TitleBar
					local copyBtn, pasteBtn, deleteBtn
					for _, child in expTitleBar:GetChildren() do
						if child.Name ~= "Button" or not child:IsA("TextButton") then
							continue
						end
						if child.LayoutOrder == 6 then
							copyBtn = child
						elseif child.LayoutOrder == 7 then
							pasteBtn = child
						elseif child.LayoutOrder == 4 then
							deleteBtn = child
						end
					end
					if copyBtn then
						copyBtn.Activated:Fire()
					end
					if pasteBtn then
						pasteBtn.Activated:Fire()
					end
					if deleteBtn then
						deleteBtn.Activated:Fire()
					end
					fastRun(0.2)

					-- Exercise Explorer search filter input (1-char, name match, non-matching fallback)
					local expInput = expScrollerFrame:FindFirstChild("Input")
					if expInput then
						local expBox = expInput:FindFirstChildOfClass("TextBox")
						if expBox then
							expBox.Text = "a"
							fastRun(0.3)
							expBox.Text = "ExplorerTestPart"
							fastRun(0.3)
							expBox.Text = "zzzz_no_match"
							fastRun(0.3)
							expBox.Text = ""
							fastRun(0.3)
						end
					end

					testFolder:Destroy()
					testCfg:Destroy()
					testPart:Destroy()
					fastRun(0.2)
				end
			)
		end
	)
end)

describe("Client and UI · Dashboard ping & 2026 Compliance", function()
	test("Dashboard ping color walks the Oklab hue from Valid through yellow to Invalid", function()
		local world, _srvMounted, cliMounted, _sK, cK = getOrCreateFullClientSut()
		sert.eq(cK.ready, true)
		local dashWin = cK.client.dashboard.Window._instance
		local prevDashVisible = dashWin.Visible
		dashWin.Visible = true

		local ping = 0.175 -- half of the 350 ms that reads fully Invalid
		local player = cliMounted.env.Players.LocalPlayer
		local origMethods = rawget(player, "_methods")
		local methods = table.clone(origMethods or {})
		methods.GetNetworkPing = function()
			return ping
		end
		rawset(player, "_methods", methods)

		local UI = cK.UI
		local origValid = UI.Theme.Valid:peek()
		local origInvalid = UI.Theme.Invalid:peek()
		UI.Theme.Valid(Color3.fromRGB(0, 255, 0))
		UI.Theme.Invalid(Color3.fromRGB(255, 0, 0))
		local label = ClientHarness.getSharedFullPingLabel()
			or cK.client.dashboard.Window._instance:FindFirstChild("StatusBar", true).Content.Ping.Label
		world:step()
		world:step(1.1)
		-- a straight Oklab mix of green and red is olive (~0.82, 0.66, 0); the hue walk stays a vivid yellow
		local mid = label.TextColor3
		sert(mid.R > 0.95 and mid.G > 0.75 and mid.B < 0.1, `midpoint reads as yellow, got {mid}`)

		-- endpoints follow the current theme colors' hues
		ping = 0
		UI.Theme.Valid(Color3.fromRGB(0, 0, 255))
		world:step()
		world:step(1.1)
		local low = label.TextColor3
		sert(low.B > 0.95 and low.B > low.R and low.B > low.G, `zero ping takes the Valid hue, got {low}`)

		UI.Theme.Valid(origValid)
		UI.Theme.Invalid(origInvalid)
		rawset(player, "_methods", origMethods)
		dashWin.Visible = prevDashVisible
	end)

	test(
		"Notify/Announce table cloning, Network FIFO logs & Custom (DataStore) sync, Settings, Bans/Servers/Members/Commands",
		function()
			local world, srvMounted, cliMounted, sK, cK = getOrCreateFullClientSut()
			local srvPlayer = srvMounted.env.Players:GetPlayers()[1]
			local UI = cK.UI
			local function fastRun(seconds: number)
				world:step(1 / 60)
				if seconds > 1 / 30 then
					world:step(seconds - 1 / 60)
				end
			end

			-- 1. Notify & Announce never mutate caller tables in place
			local notifyCfg = { Text = "Immutable Notify", From = "_K", Sound = "Hover01", Duration = 0.5 }
			local nCard = cK.Notify(notifyCfg)
			sert.eq(notifyCfg.From, "_K")
			sert.eq((notifyCfg :: any).Announce, nil)
			sert.eq((notifyCfg :: any).TextSize, nil)
			nCard._exitButton._instance.Activated:Fire()

			local announceCfg = { Text = "Immutable Announce", From = "_K", Duration = 0.5 }
			local aCard = cK.Announce(announceCfg)
			sert.eq(announceCfg.From, "_K")
			sert.eq((announceCfg :: any).Announce, nil)
			aCard._exitButton._instance.Activated:Fire()
			fastRun(0.1)

			-- 2. Network.luau FIFO same-timestamp delayed log reveal without clobbering distinct redacted commands
			local cmdLevel = sK.Logger:encode("COMMAND")
			local t0 = os.time() + 500
			local baseIdx = #cK.Data.logs
			table.insert(cK.Data.logs, { ";ban …", cmdLevel, t0, 1, "Player1" })
			table.insert(cK.Data.logs, { ";kick …", cmdLevel, t0, 1, "Player1" })
			table.insert(cK.Data.logs, { ";ban …", cmdLevel, t0, 1, "Player1" })

			sK.Remote.Log:Fire(srvPlayer, { ";ban Alice first_secret", cmdLevel, t0, 1, "Player1" })
			sK.Remote.Log:Fire(srvPlayer, { ";ban Bob second_secret", cmdLevel, t0, 1, "Player1" })
			sK.Remote.Log:Fire(srvPlayer, { ";kick Carol third_secret", cmdLevel, t0, 1, "Player1" })
			fastRun(0.1)

			sert.eq(cK.Data.logs[baseIdx + 1][1], ";ban Alice first_secret")
			sert.eq(cK.Data.logs[baseIdx + 2][1], ";kick Carol third_secret")
			sert.eq(cK.Data.logs[baseIdx + 3][1], ";ban Bob second_secret")

			-- 3. Network.luau Custom (DataStore) live theme* edits & non-node themeSoundEnabled safety
			local origSavedUse = cK.Data.savedSettings.useSavedSettings
			local origSavedTheme = cK.Data.savedSettings.theme
			local origPrimary = UI.Theme.Primary:peek()

			cK.Data.savedSettings.useSavedSettings = true
			cK.Data.savedSettings.theme = "Custom (DataStore)"
			local customColor = Color3.fromRGB(24, 48, 96)
			sK.Remote.Settings:Fire(srvPlayer, {
				themePrimary = customColor,
				themeSoundEnabled = false,
				themeTypingSounds = false,
			})
			fastRun(0.1)
			sert.eq(UI.Theme.Primary:peek(), customColor)

			sK.Remote.Settings:Fire(srvPlayer, { useSavedSettings = false })
			fastRun(0.1)
			sert.eq(cK.client.settings.useSavedSettings:peek(), false)

			-- Restore savedSettings & Primary
			cK.Data.savedSettings.useSavedSettings = origSavedUse
			cK.Data.savedSettings.theme = origSavedTheme
			cK.client.settings.useSavedSettings(true)
			UI.Theme.Primary(origPrimary)
			UI.flush()

			-- 4. deepMergeTheme does not mutate _K.Data.savedSettings tables in place
			local origSavedPrefix = cK.Data.savedSettings.prefix
			local savedArr = { ";", ":" }
			cK.Data.savedSettings.prefix = savedArr
			if UI.Themes.Default then
				UI.changeTheme(UI.Themes.Default)
			end
			sert.eq(cK.Data.savedSettings.prefix, savedArr)
			sert.eq(savedArr[1], ";")
			sert.eq(savedArr[2], ":")
			cK.Data.savedSettings.prefix = origSavedPrefix

			-- 5. Settings.luau preserves & deduplicates secondary prefixes when editing primary prefix
			local dash = cK.client.dashboard
			local prevWinVis = dash.Window._instance.Visible
			dash.Window._instance.Visible = true
			dash.Tabs._pages:JumpTo(dash.Tabs._containerCache[dash.Settings._instance])
			fastRun(0.1)
			local origDataPrefix = table.clone(cK.Data.settings.prefix)
			cK.Data.settings.prefix = { ";", ":", "!" }
			cK.client.settings.prefix(cK.Data.settings.prefix, true)
			UI.flush()

			local prefixBox: TextBox? = nil
			for _, desc in dash.Settings._instance:GetDescendants() do
				if desc:IsA("TextBox") and desc.Text == ";" then
					prefixBox = desc
					break
				end
			end
			sert.eq(prefixBox ~= nil, true)
			if prefixBox then
				prefixBox.Text = "$"
				(prefixBox.FocusLost :: any):Fire(true)
				fastRun(0.1)
				-- Cancel via LeftAction to verify resetChanges restores original prefixes cleanly
				for _, child in dash.Settings._instance:GetChildren() do
					if
						child.Name == "Dialog"
						and child:FindFirstChild("Frame")
						and child.Frame:FindFirstChild("Actions")
					then
						-- Before cancelling, check that secondary prefixes were preserved in pending changes:
						-- Triggering deduplicating edit ("!") also deduplicates existing "!"
						prefixBox.Text = "!"
						(prefixBox.FocusLost :: any):Fire(true)
						fastRun(0.05)
						child.Frame.Actions.LeftAction.Activated:Fire()
						fastRun(0.1)
						break
					end
				end
				sert.eq(cK.Data.settings.prefix[1], ";")
				sert.eq(cK.Data.settings.prefix[2], ":")
				sert.eq(cK.Data.settings.prefix[3], "!")
			end
			dash.Window._instance.Visible = prevWinVis
			cK.Data.settings.prefix = origDataPrefix
			cK.client.settings.prefix(origDataPrefix, true)

			-- 6. Bans formatting: no stray `}` in rawTextLeft, RichText escaped in non-matching columns
			local function activateScrollerTab(tab: any)
				dash.Window._instance.Visible = true
				tab.Enabled(true)
				tab._instance.Visible = true
				tab:updateList()
				tab:refreshList()
				fastRun(0.15)
				tab:forceRender()
			end

			sK.Remote.Ban:Fire(srvPlayer, "909", { "Rich<User>", "Bad<b>Reason</b>", 0, 1 })
			fastRun(0.2)
			dash.Tabs._pages:JumpTo(dash.Tabs._containerCache[dash.Bans._instance])
			activateScrollerTab(dash.Bans)
			local found909 = cK.Data.bans["909"]
			sert.eq(found909 ~= nil, true)
			if found909 then
				sert.eq(string.sub(found909.rawTextLeft, -1), "]")
				sert.eq(string.find(found909.richTextLeft, "&lt;User&gt;", 1, true) ~= nil, true)
				sert.eq(string.find(found909.tipText, "&lt;b&gt;Reason&lt;/b&gt;", 1, true) ~= nil, true)
			end
			-- Filtering by Right column ("server") escapes non-matching Left column (`Rich<User>`)
			dash.Bans._input._input.Text = "server"
			dash.Bans:refreshList()
			fastRun(0.15)
			dash.Bans:forceRender()
			local verifiedNonMatchingLeft = false
			for _, item in dash.Bans._lineItemCache do
				local leftLabel = item._instance and item._instance:FindFirstChild("Left")
				if leftLabel and string.find(leftLabel.Text, "909", 1, true) then
					sert.eq(string.find(leftLabel.Text, "&lt;User&gt;", 1, true) ~= nil, true)
					verifiedNonMatchingLeft = true
				end
			end
			sert.eq(verifiedNonMatchingLeft, true)
			dash.Bans._input._input.Text = ""
			dash.Bans:refreshList()
			fastRun(0.1)

			-- 7. Servers RichText escaping on JobId and Place name
			local marketSvc = cliMounted.env.game:GetService("MarketplaceService")
			local marketMethods = rawget(marketSvc, "_methods") or {}
			local origGetProductInfo = marketMethods.GetProductInfo
			local origGetProductInfoAsync = marketMethods.GetProductInfoAsync
			marketMethods.GetProductInfoAsync = function(_self, placeId)
				if placeId == 987654 then
					return { Name = "Danger<Place>" }
				end
				return { Name = "Place" }
			end
			rawset(marketSvc, "_methods", marketMethods)

			sK.Remote.Servers:Fire(srvPlayer, "job_<tag>", { 987654, 2, os.time() - 10 })
			fastRun(0.1)
			dash.Tabs._pages:JumpTo(dash.Tabs._containerCache[dash.Servers._instance])
			activateScrollerTab(dash.Servers)
			fastRun(0.1)
			local escapedServerFound = false
			for _, item in dash.Servers._lineItemCache do
				local idLabel = item._instance and item._instance:FindFirstChild("Id")
				local placeLabel = item._instance and item._instance:FindFirstChild("Place")
				if idLabel and string.find(idLabel.Text, "&lt;tag&gt;", 1, true) then
					escapedServerFound = true
					if placeLabel then
						sert.eq(string.find(placeLabel.Text, "&lt;Place&gt;", 1, true) ~= nil, true)
					end
					break
				end
			end
			marketMethods.GetProductInfo = origGetProductInfo
			marketMethods.GetProductInfoAsync = origGetProductInfoAsync
			sert.eq(escapedServerFound, true)

			-- 8. Members missing role guard (`roleChip` returns nil) & lazy roleMenu AutomaticSize.X
			local function hasAutoSizeRoleMenu(): boolean
				for _, child in UI.LayerTop:GetChildren() do
					if child.Name == "Menu" and child.AutomaticSize == Enum.AutomaticSize.X and child.Visible then
						return true
					end
				end
				return false
			end
			sert.eq(hasAutoSizeRoleMenu(), false)
			local preMemberErrCount = #world.scheduler.errors
			sK.Remote.Member:Fire(srvPlayer, "919", {
				name = "Tag<Member>",
				roles = { "nonexistent_deleted_role", "vip" },
				persist = { "nonexistent_deleted_role" },
			})
			dash.Tabs._pages:JumpTo(dash.Tabs._containerCache[dash.Members._instance])
			activateScrollerTab(dash.Members)
			for i = preMemberErrCount + 1, #world.scheduler.errors do
				local errEntry = world.scheduler.errors[i]
				local trace = tostring(errEntry and errEntry.traceback or "")
				sert.eq(string.find(trace, "Members.luau", 1, true), nil)
			end
			local foundMember919 = false
			local addRoleBtn: any = nil
			for _, item in dash.Members._lineItemCache do
				local label = item._instance and item._instance:FindFirstChild("TextLabel")
				if not addRoleBtn and item._instance then
					local btn = item._instance:FindFirstChild("Button")
					if btn and btn:IsA("TextButton") then
						addRoleBtn = btn
					end
				end
				if label and string.find(label.Text, "919", 1, true) then
					sert.eq(string.find(label.Text, "&lt;Member&gt;", 1, true) ~= nil, true)
					foundMember919 = true
					break
				end
			end
			sert.eq(foundMember919, true)
			sert.eq(hasAutoSizeRoleMenu(), false)
			sert.eq(addRoleBtn ~= nil, true)
			if addRoleBtn then
				addRoleBtn.Activated:Fire()
				fastRun(0.05)
				sert.eq(hasAutoSizeRoleMenu(), true)
				addRoleBtn.Activated:Fire()
			end

			-- 9. Commands multi-tier purchasable roles & RichText escaping in filterCommands
			cK.Data.roles.tier1 = {
				_rank = 1,
				_key = "tier1",
				name = "Tier1",
				color = "#00ff00",
				permissions = {},
				groups = { "vip" },
				gamepasses = { 11111 },
			}
			cK.Data.roles.tier2 = {
				_rank = 2,
				_key = "tier2",
				name = "Tier2",
				color = "#00ffff",
				permissions = {},
				groups = { "vip" },
				gamepasses = { 22222 },
			}
			if not cK.Registry.commands.richtagcmd then
				cK.Registry.registerCommand(cK, {
					name = "richtagcmd",
					aliases = {},
					description = "Escape <script> tag",
					group = "VIP",
					args = {},
					run = function() end,
				})
			end
			dash.Tabs._pages:JumpTo(dash.Tabs._containerCache[dash.Commands._instance])
			activateScrollerTab(dash.Commands)
			dash.Commands._input._input.Text = "richtagcmd"
			dash.Commands:refreshList()
			fastRun(0.15)
			dash.Commands:forceRender()
			dash.Commands._input._input.Text = "Escape"
			dash.Commands:refreshList()
			fastRun(0.15)
			dash.Commands:forceRender()
			for _, item in dash.Commands._lineItemCache do
				if item.Title and string.find(item.Title.Text, "richtagcmd", 1, true) then
					sert.eq(string.find(item.Description.Text, "&lt;script&gt;", 1, true) ~= nil, true)
				end
			end
			dash.Commands._input._input.Text = ""
			dash.Commands:refreshList()
			cK.Data.roles.tier1 = nil
			cK.Data.roles.tier2 = nil
			fastRun(0.1)
		end
	)

	test("Client loadAddons deduplicates addons present in both Addons folder and addonTag", function()
		local world = sert.sim.new({ backing = true })
		local server = world:server()
		local client = server:client(1, "Player1")

		local srvMounted = Harness.newPeerEnv(server, { isStudio = true })
		local cliMounted = setupClientEnv(client)
		local sK = srvMounted:requireK()
		server:spawn(function()
			sK.initialize({
				bans = {},
				userRoles = { creator = { 1 } },
				assetRoles = {},
				gamepassRoles = {},
				subscriptionRoles = {},
				groupRoles = {},
				friendRoles = {},
				freeAdmin = {},
				announcements = {},
				notifications = {},
				prefix = { ";" },
				splitKey = " ",
				commands = {},
				vip = false,
				chatCommandsNotification = false,
				joinNotificationRank = 0,
				roles = Harness.defaultRoles(),
			})
		end)
		for _ = 1, 5 do
			world:step(0.1)
		end

		local cEnv = cliMounted.env
		local cK = cliMounted:requireK()
		local preUI = cEnv:require(cliMounted.Client.UI)
		preUI.Pointer = preUI.signal({ Position = Vector3.new(0, 0, 0) })

		local addonRuns = 0
		local addonMod = cEnv.Instance.new("ModuleScript")
		addonMod.Name = "DualTaggedClientAddon"
		addonMod.Parent = cliMounted.KA:FindFirstChild("Addons")
		rawset(addonMod, "_factory", function()
			return function()
				addonRuns += 1
			end
		end)
		cEnv.game:GetService("CollectionService"):AddTag(addonMod, cK._addonTag)

		client:spawn(function()
			local okCli, errCli = pcall(cEnv.require, cEnv, cliMounted.Client)
			if not okCli and not string.find(tostring(errCli), "did not return exactly one value", 1, true) then
				error(errCli, 0)
			end
		end)
		for _ = 1, 10 do
			world:step(0.125)
		end
		sert.eq(cK.ready, true)
		sert.eq(addonRuns, 1)
	end)

	test(
		"Explorer delegates PARENT and DELETE to Remote.Explorer, clears hover target on leave, and purges destroyed nodes",
		function()
			local world = sert.sim.new({ backing = true })
			local server = world:server()
			local client = server:client(1, "Player1")
			local function fastRun(seconds: number)
				local dt = 1 / 60
				if seconds <= dt * 8 then
					world:run(seconds)
				else
					world:step(dt)
					world:step(seconds - dt * 7)
					for _ = 1, 6 do
						world:step(dt)
					end
				end
			end

			local cliMounted = setupClientEnv(client, { mockRemote = true })
			local cK = cliMounted:requireK()
			local UI = cliMounted.env:require(cliMounted.Client.UI)
			if UI.registerClasses then
				UI.registerClasses()
			end
			UI.Pointer = UI.signal({ Position = Vector3.new(100, 100, 0) })
			cK.UI = UI
			cK.IsClient = true
			cK.LocalPlayer = cliMounted.env.Players.LocalPlayer
			cK.client = {
				rank = cK.Flux.signal(0),
				Explorer = cliMounted.env:require(cliMounted.Client.Explorer),
			}
			local cEnv = cliMounted.env
			local origUisMethods = rawget(UI.UserInputService, "_methods")

			local remoteCalls = {}
			cK.Remote.Explorer = {
				Fire = function(_self, action, ...)
					table.insert(remoteCalls, { action = action, args = { ... } })
				end,
			}

			local folderA = cEnv.Instance.new("Folder")
			folderA.Name = "AlphaFolder"
			folderA.Parent = cEnv.workspace
			local folderB = cEnv.Instance.new("Folder")
			folderB.Name = "BetaFolder"
			folderB.Parent = cEnv.workspace

			cK.client.Explorer.Show()
			fastRun(1.2)

			local expWin = UI.LayerTopInset:FindFirstChild("Explorer")
			sert.eq(expWin ~= nil, true)
			local expScrollerFrame = expWin.Frame.UIContent:FindFirstChild("ScrollerFast")
			local innerScroller = expScrollerFrame:FindFirstChild("ScrollerFast")

			local function findRowBtn(rowName: string): any
				for _, btn in innerScroller:GetChildren() do
					if not btn:IsA("TextButton") then
						continue
					end
					local label = btn:FindFirstChild("TextLabel")
					if label and label.Text == rowName then
						return btn
					end
				end
				return nil
			end

			-- Expand Workspace so AlphaFolder and BetaFolder render
			local wsBtn = findRowBtn("Workspace")
			sert.eq(wsBtn ~= nil, true)
			if wsBtn then
				local expBtn = wsBtn:FindFirstChild("Expand")
				if expBtn then
					expBtn.Activated:Fire()
				end
			end
			fastRun(0.35)

			local alphaBtn = findRowBtn("AlphaFolder")
			local betaBtn = findRowBtn("BetaFolder")
			sert.eq(alphaBtn ~= nil and betaBtn ~= nil, true)

			-- 1. Select AlphaFolder and press Delete -> fires ("DELETE", { folderA }) WITHOUT destroying folderA client-side
			alphaBtn.Activated:Fire()
			fastRun(0.1)
			local expTitleBar = expWin.Frame.TitleBar
			local copyBtn, pasteBtn, deleteBtn
			for _, child in expTitleBar:GetChildren() do
				if child.Name == "Button" and child:IsA("TextButton") then
					if child.LayoutOrder == 6 then
						copyBtn = child
					elseif child.LayoutOrder == 7 then
						pasteBtn = child
					elseif child.LayoutOrder == 4 then
						deleteBtn = child
					end
				end
			end
			sert.eq(deleteBtn ~= nil, true)
			deleteBtn.Activated:Fire()
			fastRun(0.1)
			sert.eq(folderA.Parent, cEnv.workspace)
			sert.eq(#remoteCalls, 1)
			sert.eq(remoteCalls[1].action, "DELETE")
			sert.eq(remoteCalls[1].args[1][1], folderA)

			-- 2. Drag AlphaFolder onto BetaFolder -> fires ("PARENT", { folderA }, folderB) WITHOUT client-side reparent
			table.clear(remoteCalls)
			alphaBtn = findRowBtn("AlphaFolder")
			betaBtn = findRowBtn("BetaFolder")
			cEnv:setAbsolute(alphaBtn, Vector2.new(200, 20), Vector2.new(10, 10))
			cEnv:setAbsolute(betaBtn, Vector2.new(200, 20), Vector2.new(10, 30))
			rawset(
				UI.UserInputService,
				"_methods",
				setmetatable({
					IsMouseButtonPressed = function(_self, btn)
						return btn == Enum.UserInputType.MouseButton1
					end,
				}, { __index = origUisMethods })
			)
			alphaBtn.InputBegan:Fire(
				makeInput(cEnv, { UserInputType = Enum.UserInputType.MouseButton1, Position = Vector3.new(10, 10, 0) }),
				false
			)
			alphaBtn.InputChanged:Fire(
				makeInput(cEnv, { UserInputType = Enum.UserInputType.MouseMovement, Position = Vector3.new(30, 30, 0) }),
				false
			)
			UI.Pointer({ Position = Vector3.new(35, 35, 0) })
			betaBtn.MouseEnter:Fire(35, 35)
			betaBtn.InputChanged:Fire(
				makeInput(cEnv, { UserInputType = Enum.UserInputType.MouseMovement, Position = Vector3.new(35, 35, 0) }),
				false
			)
			UI.flush()
			UI.UserInputService.InputEnded:Fire(
				makeInput(cEnv, { UserInputType = Enum.UserInputType.MouseButton1, Position = Vector3.new(35, 35, 0) }),
				false
			)
			-- Settle Explorer's 1.0s updateListThrottled window + ScrollerFast queues before Step 3
			fastRun(1.2)
			sert.eq(folderA.Parent, cEnv.workspace)
			sert.eq(#remoteCalls, 1)
			sert.eq(remoteCalls[1].action, "PARENT")
			sert.eq(remoteCalls[1].args[1][1], folderA)
			sert.eq(remoteCalls[1].args[2], folderB)

			-- 3. Drag hover-leave clears DragScope.TargetNode so dropping off-target fires nothing
			table.clear(remoteCalls)
			alphaBtn = findRowBtn("AlphaFolder")
			betaBtn = findRowBtn("BetaFolder")
			cEnv:setAbsolute(alphaBtn, Vector2.new(200, 20), Vector2.new(10, 10))
			cEnv:setAbsolute(betaBtn, Vector2.new(200, 20), Vector2.new(10, 30))
			betaBtn.MouseLeave:Fire(90, 90)
			UI.Pointer({ Position = Vector3.new(90, 90, 0) })
			UI.flush()
			alphaBtn.InputBegan:Fire(
				makeInput(cEnv, { UserInputType = Enum.UserInputType.MouseButton1, Position = Vector3.new(10, 10, 0) }),
				false
			)
			alphaBtn.InputChanged:Fire(
				makeInput(cEnv, { UserInputType = Enum.UserInputType.MouseMovement, Position = Vector3.new(30, 30, 0) }),
				false
			)
			UI.Pointer({ Position = Vector3.new(35, 35, 0) })
			betaBtn.MouseEnter:Fire(35, 35)
			betaBtn.InputChanged:Fire(
				makeInput(cEnv, { UserInputType = Enum.UserInputType.MouseMovement, Position = Vector3.new(35, 35, 0) }),
				false
			)
			UI.flush()
			UI.Pointer({ Position = Vector3.new(90, 90, 0) })
			betaBtn.MouseLeave:Fire(90, 90)
			UI.flush()
			UI.UserInputService.InputEnded:Fire(
				makeInput(cEnv, { UserInputType = Enum.UserInputType.MouseButton1, Position = Vector3.new(90, 90, 0) }),
				false
			)
			fastRun(0.1)
			sert.eq(#remoteCalls, 0)
			rawset(UI.UserInputService, "_methods", origUisMethods)

			-- 4. Copy AlphaFolder, then Destroy AlphaFolder on server/world -> purges CLIPBOARD & SELECTION cleanly
			alphaBtn = findRowBtn("AlphaFolder")
			sert.eq(alphaBtn ~= nil, true)
			alphaBtn.Activated:Fire()
			fastRun(0.05)
			copyBtn.Activated:Fire()
			fastRun(0.05)
			folderA:Destroy()
			fastRun(1.2)
			sert.eq(findRowBtn("AlphaFolder"), nil)
			betaBtn = findRowBtn("BetaFolder")
			sert.eq(betaBtn ~= nil, true)
			betaBtn.Activated:Fire()
			fastRun(0.05)
			table.clear(remoteCalls)
			pasteBtn.Activated:Fire()
			fastRun(0.1)
			sert.eq(#remoteCalls, 0)

			-- 5. Multi-character identifier search ("BetaFolder") prepends `#` via `^[%w_]+$` cleanly
			local expInput = expScrollerFrame:FindFirstChild("Input")
			local expBox = expInput and expInput:FindFirstChildWhichIsA("TextBox", true)
			sert.eq(expBox ~= nil, true)
			if expBox then
				expBox.Text = "BetaFolder"
				fastRun(0.25)
				sert.eq(#world.scheduler.errors, 0)
				expBox.Text = ""
				fastRun(0.1)
			end

			folderB:Destroy()
			fastRun(0.1)
		end
	)

	test(
		"_K.getCommandPrefix reads remote _KPlayerPrefix, MessageReceived filters CHAT vs COMMAND echoes cleanly, and CompletionData/Network enforce multi-char positions & Studio lock",
		function()
			local world, srvMounted, cliMounted, sK, cK = getOrCreateFullClientSut()
			local function fastRun(seconds: number)
				world:step(1 / 60)
				if seconds > 1 / 30 then
					world:step(seconds - 1 / 60)
				end
			end
			local tcs = cliMounted.env.game:GetService("TextChatService")

			-- 1. _K.getCommandPrefix(otherUserId) uses otherPlayer's _KPlayerPrefix, never LocalPlayer's
			local peer2 = cliMounted.env:addPlayer(222, "RemotePeer2")
			peer2:SetAttribute("_KPlayerPrefix", "?")
			cK.Data.playerPrefix[1] = "!"
			cK.client.playerPrefix("!")
			sert.eq(cK.getCommandPrefix(222), "?")
			sert.eq(cK.getCommandPrefix(1), "!")

			-- 2. MessageReceived CHAT logging vs shouldSuppressEchoedChatLog
			cK.Registry.registerCommand(cK, {
				name = "testecholog",
				description = "Test server echo suppression",
				group = "utility",
				args = { { type = "string", name = "Val", description = "Value" } },
				run = function() end,
			})
			cK.Registry.commands.testecholog.LocalPlayerAuthorized = true

			local function fireMsg(uid: number, text: string)
				tcs.MessageReceived:Fire({
					Status = Enum.TextChatMessageStatus.Success,
					TextSource = { UserId = uid },
					Text = text,
					Metadata = "",
				})
				fastRun(0.05)
			end

			local base = #cK.Data.logs
			-- Non-matching prefix from another player ("!" while peer2 uses "?") logs as CHAT
			fireMsg(222, "!version")
			sert.eq(#cK.Data.logs, base + 1)

			-- Sender on _KCommandCooldown logs as CHAT
			peer2:SetAttribute("_KCommandCooldown", true)
			fireMsg(222, "?version")
			peer2:SetAttribute("_KCommandCooldown", nil)
			sert.eq(#cK.Data.logs, base + 2)

			-- chatCommands == false logs as CHAT
			cK.Data.settings.chatCommands = false
			fireMsg(1, ";version")
			cK.Data.settings.chatCommands = true
			sert.eq(#cK.Data.logs, base + 3)

			-- Unauthorized server command from peer2 logs as CHAT
			fireMsg(222, ";ban Player1")
			sert.eq(#cK.Data.logs, base + 4)

			-- Incomplete redirected server command logs as CHAT
			fireMsg(1, ";ban")
			sert.eq(#cK.Data.logs, base + 5)

			-- Client-only command from another player produces no server COMMAND log -> logs as CHAT
			fireMsg(222, ";version")
			sert.eq(#cK.Data.logs, base + 6)

			-- Authorized complete server command suppresses echoed CHAT log
			fireMsg(1, ";testecholog hello")
			sert.eq(#cK.Data.logs, base + 6)

			-- 3. Multi-char prefix CompletionData positions & Network Studio lock
			local CompletionData = cliMounted.env:require(cliMounted.Client.CommandBar.CompletionData)
			local origPrefix = cK.Data.settings.prefix
			cK.Data.settings.prefix = { "::" }
			local cd = CompletionData(cK, "::ver", 6)
			sert.eq(cd.argPos, 3)
			local cdInv = CompletionData(cK, ":: ", 4)
			sert.eq(cdInv.invalid[1][1], "Invalid command string")
			cK.Data.settings.prefix = origPrefix

			local origAuth = cK.Data.settings.changeThemeAuthority
			cK.Data.settings.changeThemeAuthority = "Studio"
			local srvPlayer = srvMounted.env.Players:GetPlayers()[1]
			sK.Remote.Settings:Fire(srvPlayer, { changeThemeAuthority = "Client", theme = "Cyan" })
			fastRun(0.1)
			sert.eq(cK.Data.settings.changeThemeAuthority, "Studio")
			sert.eq(cK.Data.savedSettings.theme ~= "Cyan", true)
			cK.Data.settings.changeThemeAuthority = origAuth

			cK.Data.playerPrefix[1] = nil
			cK.client.playerPrefix(";")
			cK.Registry.commands.testecholog = nil
			peer2:Destroy()
		end
	)
end)

do
	return {}
end
