local Harness = require("./Harness")
local sert = require("../sert")

local describe, test, expect = sert.describe, sert.test, sert.expect

-- Live Studio UI & hover suite (play mode: a server and one client). Declared before the headless globals below so
-- it uses the real engine Enum/UDim2/Vector2. Headless `luau` skips these (a skip is not a pass).
do
	local IS_ROBLOX = game ~= nil and typeof(game) == "Instance"
	local IS_CLIENT = IS_ROBLOX and game:GetService("RunService"):IsClient()
	local serverTest = if IS_ROBLOX and not IS_CLIENT then sert.rtest else sert.skip
	local clientTest = if IS_CLIENT then sert.rtest else sert.skip

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
		end, 15, "the Kohl's Admin client never became ready")
	end

	local function frames(UI: any, n: number?)
		for _ = 1, n or 2 do
			game:GetService("RunService").Heartbeat:Wait()
		end
		UI.flush()
	end

	local function openDashboard(_K: any)
		local window = _K.client.dashboard.Window
		if not window._instance.Visible then
			local flicker = sert.roblox.Flicker.around(function()
				return window._instance
			end, function()
				_K.client.hotkeys.dashboard.callback()
			end, { label = "Dashboard", fromSettledSize = true })
			sert.roblox.Flicker.expect(flicker)
		end
		local settled, moving = sert.roblox.Layout.settle(window._instance)
		sert(settled, `Dashboard layout settled ({moving})`)
		frames(_K.UI, 3)
		-- Opening the dashboard must never auto-open the VIP modal
		if _K.VIP and _K.VIP.popup then
			expect(_K.VIP.popup.Visible).toBe(false)
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
			expect(_K ~= nil and _K.ready).toBe(true)
			local player = game:GetService("Players"):GetPlayers()[1]
			expect(player ~= nil).toBe(true)
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
			end, 5, "UI.textWidth initial measurement")
			expect(width:peek()).toBe(expected)

			text:set("Kohl's Admin, but wider")
			UI.flush()
			sert.waitFor(function()
				return width:peek() > expected
			end, 5, "UI.textWidth updated measurement")
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
				Position = UDim2.fromOffset(240, 240),
				Size = UDim2.fromOffset(140, 40),
			}
			frames(UI, 2)
			local instance = button._instance
			local center = instance.AbsolutePosition + instance.AbsoluteSize / 2
			local hits = game:GetService("Players").LocalPlayer.PlayerGui:GetGuiObjectsAtPosition(center.X, center.Y)
			local found = false
			for _, gui in hits do
				if gui == instance then
					found = true
				end
			end
			sert(found, "the button is under its own center")
			expect(UI.Interact.sunk(center.X, center.Y, instance)).toBe(false)
			expect(UI.Interact.covered(center.X, center.Y, instance)).toBe(false)
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
				expect(tipA.Visible:peek()).toBe(false)

				-- hovering again shows it after the delay
				hoverA(false)
				UI.flush()
				hoverA(true)
				UI.flush()
				task.wait(0.6)
				UI.flush()
				expect(tipA.Visible:peek()).toBe(true)
				label = label or UI.LayerTop:FindFirstChild("Tooltip")
				sert(
					label ~= nil and label.Visible and label.Text == "Tip A tip",
					"the shared tooltip label shows tip A"
				)

				-- clearing the hover state (scroll, tab switch, window close) hides a shown tip
				UI.clearState("hover")
				frames(UI, 1)
				expect(tipA.Visible:peek()).toBe(false)
				sert(not label.Visible, "the shared tooltip label hides")

				-- hovering another tooltip releases the first
				hoverA(false)
				UI.flush()
				hoverA(true)
				UI.flush()
				task.wait(0.6)
				UI.flush()
				expect(tipA.Visible:peek()).toBe(true)
				hoverB(true)
				UI.flush()
				frames(UI, 1)
				expect(tipA.Visible:peek()).toBe(false)
				task.wait(0.6)
				UI.flush()
				expect(tipB.Visible:peek()).toBe(true)
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
			expect(dashboard.Window._instance.Visible).toBe(true)

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
				expect(dashboard.Tabs.CurrentPage:peek()).toBe(page._instance)
				if page._lineItemCache then
					sert.waitFor(
						function()
							return next(page._lineItemCache) ~= nil
						end,
						3,
						`{name} rows rendered`,
						function()
							frames(UI, 1)
						end
					)
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
					local credits = sert.waitFor(
						function()
							local c = page._instance:FindFirstChild("Credits", true)
							return if c and c:FindFirstChild("Contributors") then c else nil
						end,
						3,
						"About credits sections rendered",
						function()
							frames(UI, 1)
						end
					)
					local activeSection = credits:FindFirstChild("Active contributors")
					local plainSection = credits:FindFirstChild("Contributors")
					local specialSection = credits:FindFirstChild("Special Thanks")
					expect(activeSection ~= nil).toBe(true)
					expect(plainSection ~= nil).toBe(true)
					expect(specialSection ~= nil).toBe(true)
					expect(activeSection.LayoutOrder < plainSection.LayoutOrder).toBe(true)
					expect(plainSection.LayoutOrder < specialSection.LayoutOrder).toBe(true)
					local plainUsers = plainSection:FindFirstChild("Users")
					expect(plainUsers ~= nil and plainUsers:FindFirstChild("Header") == nil).toBe(true)
					expect(plainUsers:FindFirstChild("Credit") ~= nil).toBe(true)

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
					expect(linkA._instance:IsFocused()).toBe(true)
					expect(linkA._instance.SelectionStart).toBe(1)
					expect(linkA._instance.CursorPosition).toBe(#linkA._instance.Text + 1)

					-- Switching focus to a second Link must not lose focus when linkA's FocusLost fires
					linkB:Select()
					frames(UI, 2)
					expect(linkA._instance:IsFocused()).toBe(false)
					expect(linkA._instance.SelectionStart).toBe(-1)
					expect(linkB._instance:IsFocused()).toBe(true)
					expect(linkB._instance.SelectionStart).toBe(1)
					expect(linkB._instance.CursorPosition).toBe(#linkB._instance.Text + 1)

					-- Mutating cursor/selection while focused snaps back to full-text selection
					linkB._instance.SelectionStart = -1
					linkB._instance.CursorPosition = 1
					frames(UI, 1)
					expect(linkB._instance.SelectionStart).toBe(1)
					expect(linkB._instance.CursorPosition).toBe(#linkB._instance.Text + 1)

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

			-- Verify VIP Popup layout, PromptPurchaseVIP, View button, and sale state sync in real Studio
			local vip = _K.VIP.popup
			expect(vip ~= nil).toBe(true)
			expect(vip.Visible).toBe(false)
			_K.PromptPurchaseVIP()
			frames(_K.UI, 2)
			expect(vip.Visible).toBe(true)
			expect(vip.Frame:FindFirstChild("Preview") ~= nil).toBe(true)
			local previewCount = 0
			for cmdName in string.gmatch(vip.Frame.Preview.Text, "<b>;([%w_]+)</b>") do
				previewCount += 1
				local cmd = _K.Registry.commands[cmdName]
				sert(cmd ~= nil, `VIP preview command {cmdName} exists`)
				sert(_K.Auth.roleCanUseCommand("vip", cmd), `VIP preview command {cmdName} is usable by vip role`)
			end
			expect(previewCount).toBe(5)
			expect(vip.Frame.BuyFrame.Favorite:IsA("ImageButton")).toBe(true)
			expect(vip.Frame.BuyFrame.Favorite.Visible).toBe(true)
			expect(vip.Frame.BuyFrame.Buy.Price.AutomaticSize).toBe(Enum.AutomaticSize.X)
			expect(vip.Frame.BuyFrame.OriginalPrice.Label.AutomaticSize).toBe(Enum.AutomaticSize.X)
			-- Calling _K.VIP.openFromView() exercises the View button action in live Studio
			vip.Visible = false
			_K.client.dashboard.Commands._instance.Visible = true
			frames(_K.UI, 2)
			expect(vip.Visible).toBe(false)
			expect(_K.client.dashboard.Commands._instance.Visible).toBe(true)
			expect(vip.ZIndex).toBe(9e8)

			-- Verify _K.VIP.saleStateChanged and _K.client.ownsKAModel signals in live Studio
			expect(_K.VIP.getActiveAssetId()).toBe(110019084552349)
			expect(type(_K.client.promptGetKA)).toBe("function")
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

local baseGlobals = Harness.globals
local Enum = baseGlobals.Enum
local Font = baseGlobals.Font
local Color3 = baseGlobals.Color3
local UDim = baseGlobals.UDim
local UDim2 = baseGlobals.UDim2
local Vector2 = baseGlobals.Vector2
local Vector3 = baseGlobals.Vector3
local NumberRange = baseGlobals.NumberRange
local BrickColor = baseGlobals.BrickColor
local Rect = baseGlobals.Rect

local function setupClientEnv(peer: any, opts: { mockRemote: boolean? }?)
	local mounted = Harness.newPeerEnv(peer, { isClient = true })
	local env = mounted.env
	local LocalPlayer = env.Players.LocalPlayer
	if LocalPlayer then
		if not LocalPlayer:FindFirstChild("PlayerGui") then
			local pg = env.createInstance("PlayerGui")
			pg.Name = "PlayerGui"
			pg.Parent = LocalPlayer
		end
		LocalPlayer:SetAttribute("_KInitialJoin", 0)
	end
	local tcs = env.game:GetService("TextChatService")
	if not tcs:FindFirstChildOfClass("ChatInputBarConfiguration") then
		env.createInstance("ChatInputBarConfiguration", tcs)
	end
	rawset(tcs, "_methods", {
		DisplayBubble = function() end,
	})
	local chatSvc = env.game:GetService("Chat")
	rawset(chatSvc, "_methods", {
		Chat = function() end,
	})
	local soundSvc = env.game:GetService("SoundService")
	rawset(soundSvc, "_methods", {
		PlayLocalSound = function() end,
	})
	local runService = env.game:GetService("RunService")
	rawset(runService, "_signals", {
		Heartbeat = runService._props.Heartbeat,
		RenderStepped = runService._props.RenderStepped,
		Stepped = runService._props.Stepped,
		PreRender = runService._props.PreRender,
		PreAnimation = runService._props.PreAnimation,
		PreSimulation = runService._props.PreSimulation,
		PostSimulation = runService._props.PostSimulation,
	})
	local contentProvider = env.game:GetService("ContentProvider")
	rawset(contentProvider, "_methods", {
		PreloadAsync = function(_self: any, assets: { any }?, callback: ((string, any) -> ())?)
			if not callback or not assets then
				return
			end
			for _, asset in assets do
				local id = tostring(asset)
				local status = if string.find(id, "Part", 1, true)
					then Enum.AssetFetchStatus.Success
					else Enum.AssetFetchStatus.Failure
				callback(id, status)
			end
		end,
	})
	local market = env.game:GetService("MarketplaceService")
	if not market._props.PromptBulkPurchaseFinished then
		market._props.PromptBulkPurchaseFinished = env:signal()
	end
	local marketMethods = rawget(market, "_methods") or {}
	marketMethods.PromptBulkPurchase = function() end
	rawset(market, "_methods", marketMethods)

	local avatarEditor = env.game:GetService("AvatarEditorService")
	local aeMethods = rawget(avatarEditor, "_methods") or {}
	aeMethods.PromptSetFavorite = function() end
	rawset(avatarEditor, "_methods", aeMethods)

	local logSvc = env.game:GetService("LogService")
	if not logSvc._props.MessageOut then
		logSvc._props.MessageOut = env:signal()
	end

	local origInstanceNew = env.Instance.new
	env.Instance = {
		new = function(className: string, parent: any?)
			local inst = origInstanceNew(className, parent)
			if inst:IsA("GuiObject") and not inst._props.TouchLongPress then
				inst._props.TouchLongPress = env:signal()
			end
			return inst
		end,
		fromExisting = env.Instance.fromExisting,
	}
	if env.globals then
		env.globals.Instance = env.Instance
	end

	mounted.KA:SetAttribute("ServerStartTime", 0)
	if not mounted.KA:FindFirstChild("Addons") then
		local addons = env.Instance.new("Folder")
		addons.Name = "Addons"
		addons.Parent = mounted.KA
	end
	local defaultAddons = mounted.Shared:FindFirstChild("DefaultAddons")
	if defaultAddons then
		for _, child in defaultAddons:GetChildren() do
			if string.find(child.Name, "Server", 1, true) then
				child:Destroy()
			end
		end
	end
	if opts and opts.mockRemote then
		mounted:mockClientRemotes()
	end
	return mounted
end

local function makeInput(env: any, props: { [string]: any })
	local input = env.createInstance("InputObject")
	rawset(input, "_methods", {
		IsModifierKeyDown = function(_self: any, mod: any)
			return props.Modifiers ~= nil and props.Modifiers[mod] == true
		end,
	})
	for k, v in props do
		pcall(function()
			(input :: any)[k] = v
		end)
	end
	return input
end

local sharedFullWorld: any = nil
local sharedFullServerMounted: any = nil
local sharedFullClientMounted: any = nil
local sharedFullSK: any = nil
local sharedFullCK: any = nil
local sharedFullPingLabel: any = nil
local sharedFullMutant: any = nil

local function getOrCreateFullClientSut()
	if
		sharedFullWorld
		and sharedFullServerMounted
		and sharedFullClientMounted
		and sharedFullSK
		and sharedFullCK
		and sharedFullMutant == (_G :: any).__SERT_MUTANT
		and #sharedFullWorld.scheduler.errors == 0
	then
		return sharedFullWorld, sharedFullServerMounted, sharedFullClientMounted, sharedFullSK, sharedFullCK
	end

	local world = sert.sim.new({ backing = true })
	local server = world:server()
	local client = server:client(1, "Player1")

	local srvMounted = Harness.newPeerEnv(server, { isStudio = true })
	local cliMounted = setupClientEnv(client);
	(srvMounted :: any).peer = server;
	(cliMounted :: any).peer = client

	local sK = srvMounted:requireK()
	server:spawn(function()
		sK.initialize({
			bans = {
				["202"] = { "BannedBob", "Griefing", 0, 1 },
				["303"] = { "TimedTim", "Spam", 1800000000, 1 },
				["404"] = { "PermPete", "Exploits", -1, nil },
			},
			userRoles = { creator = { 1 }, admin = { 505 }, vip = {} },
			assetRoles = {},
			gamepassRoles = {},
			subscriptionRoles = {},
			groupRoles = {},
			friendRoles = {},
			freeAdmin = { "vip" },
			announcements = { { Text = "Welcome Announcement", Duration = 1 } },
			notifications = { { Text = "Welcome Notification", Duration = 1 } },
			prefix = { ";" },
			splitKey = " ",
			commands = {},
			vip = true,
			chatCommandsNotification = true,
			joinNotificationRank = 0,
			roles = Harness.defaultRoles(),
		})
	end)
	for _ = 1, 5 do
		world:step(0.1)
	end

	local cK = cliMounted:requireK()
	local preUI = cliMounted.env:require(cliMounted.Client.UI)
	preUI.Pointer = preUI.signal({ Position = Vector3.new(100, 100, 0) })
	client:spawn(function()
		cliMounted.env:require(cliMounted.Client)
	end)
	for _ = 1, 8 do
		world:step(0.125)
	end

	if sK.ChatCommands then
		sK.ChatCommands.schedule = function() end
	end

	local cEnv = cliMounted.env
	cEnv.userNames[202] = "BannedBob"
	cEnv.userNames[303] = "TimedTim"
	cEnv.userNames[404] = "PermPete"
	cEnv.userNames[505] = "AdminAlice"
	cEnv.userNames[707] = "ModMary"
	cEnv.userNames[808] = "Spaced User"

	if not cK.Registry.types.testRichValues then
		cK.Registry.registerType("testRichValues", {
			filterLog = true,
			transform = function(v)
				return v
			end,
			validate = function()
				return true
			end,
			parse = function(v)
				return v
			end,
			suggestions = function()
				return {
					{ "playerVal", "Player1", cEnv.Players.LocalPlayer },
					{ "colorVal", "Red", Color3.fromRGB(255, 0, 0) },
					{ "brickVal", "Bright red", BrickColor.new("Bright red") },
					{ "enumFontVal", "Gotham", Enum.Font.Gotham },
					{ "fontVal", "GothamFont", Font.fromEnum(Enum.Font.Gotham) },
					{ "userTableVal", "UserTable", { userId = 1 } },
				}
			end,
		})
		cK.Registry.registerCommand(cK, {
			name = "uitestcmd",
			aliases = {},
			description = "Test rich suggestions",
			group = "General",
			args = {
				{ type = "testRichValues", name = "rich", description = "rich values" },
				{ type = "image", name = "img", description = "image arg" },
			},
			run = function() end,
		})
		cK.Registry.commands.uitestcmd.LocalPlayerAuthorized = true
	end

	sharedFullWorld = world
	sharedFullServerMounted = srvMounted
	sharedFullClientMounted = cliMounted
	sharedFullSK = sK
	sharedFullCK = cK
	sharedFullPingLabel = cK.client.dashboard.Window._instance:FindFirstChild("StatusBar", true).Content.Ping.Label
	sharedFullMutant = (_G :: any).__SERT_MUTANT

	return world, srvMounted, cliMounted, sK, cK
end

describe("Client and UI", function()
	describe("Part 1 · UI Engine, Theme, Fonts & Stateful Primitives", function()
		test("registers classes, resolves fonts, manages active states, luminance, and edits instances", function()
			local world = sert.sim.new({ backing = true })
			local server = world:server()
			local client = server:client(1, "Player1")
			local cliMounted = setupClientEnv(client)

			local UI = cliMounted.env:require(cliMounted.Client.UI)
			if UI.registerClasses then
				expect(UI.registerClasses()).toBe(UI)
			end
			expect(rawequal(UI.new("Frame"), UI.new("Frame"))).toBe(true)

			-- Double registration throws
			local okDup = pcall(function()
				UI.register("Button", UI.Class.Button)
			end)
			expect(okDup).toBe(false)

			-- Fonts (Enum, family json path, known assetId, unknown assetId)
			expect(UI.getFontName(Enum.Font.Gotham)).toBe("Gotham")
			expect(UI.getFontName(Font.fromEnum(Enum.Font.Gotham))).toBe("Gotham")
			expect(UI.getFontName(Font.new("rbxasset://fonts/families/GothamSSm.json"))).toBe("GothamSSm")
			expect(UI.getFontName(Font.fromId(12187368317))).toBe("Akronim")
			expect(UI.getFontName(Font.fromId(999999999))).toBeNil()

			-- TopbarInset reactivity
			UI.GuiService.TopbarInset = Rect.new(0, 0, 1280, 48)
			world:step()
			expect(UI.TopbarPadding().Offset).toBe(2)
			expect(UI.TopbarFrame.Visible).toBe(true)
			UI.GuiService.TopbarInset = Rect.new(0, 0, 1280, 0)
			world:step()
			expect(UI.TopbarFrame.Visible).toBe(false)
			UI.GuiService.TopbarInset = Rect.new(0, 0, 1280, 36)
			world:step()
			expect(UI.TopbarFrame.Visible).toBe(true)

			-- Active state management (hover, floating, dialog)
			local s1 = UI.signal(false)
			local s2 = UI.signal(false)
			local s1Changes = 0
			local s1Effect = UI.effect(function()
				s1()
				s2()
				s1Changes += 1
			end)
			s1Effect:get()
			expect(s1Changes).toBe(1)
			UI.activateState(s1, "hover")
			expect(s1()).toBe(true)
			expect(s1Changes).toBe(2)
			UI.activateState(s2, "hover")
			expect(s1()).toBe(false)
			expect(s2()).toBe(true)

			-- Deactivating a non-matching state does not clear activeState
			UI.deactivateState(s1, "hover")
			expect(rawequal(UI._activeState.hover, s2)).toBe(true)

			UI.toggleState(s2, "hover")
			expect(s2()).toBe(false)
			UI.toggleState(s2, "hover")
			expect(s2()).toBe(true)

			local beforeDeactivate = s1Changes
			UI.deactivateState(s2, "hover")
			expect(s2()).toBe(false)
			expect(s1Changes).toBe(beforeDeactivate + 1)
			expect(UI._activeState.hover).toBeNil()

			UI.activateState(s1, "floating")
			UI.activateState(s2, "dialog")
			expect(s1()).toBe(true)
			expect(s2()).toBe(true)
			local prevS1Changes = s1Changes
			UI.clearState("floating")
			expect(s1()).toBe(false)
			expect(s1Changes).toBe(prevS1Changes + 1)
			expect(UI._activeState.floating).toBeNil()
			UI.clearActiveStates()
			expect(s2()).toBe(false)
			expect(UI._activeState.dialog).toBeNil()
			s1Effect:Destroy()

			-- Invalid state throws
			expect(pcall(UI.activateState, "not_a_state", "hover")).toBe(false)
			expect(pcall(UI.deactivateState, "not_a_state", "hover")).toBe(false)
			expect(pcall(UI.toggleState, "not_a_state", "hover")).toBe(false)

			-- Luminance & invertLuminance
			local blackLum = UI.getLuminance(Color3.new(0, 0, 0))
			local whiteLum = UI.getLuminance(Color3.new(1, 1, 1))
			expect(blackLum).toBeCloseTo(0, 3)
			expect(whiteLum).toBeCloseTo(1, 3)

			local invertedDark = UI.invertLuminance(Color3.new(0.1, 0.1, 0.1), 0.2)
			expect(UI.getLuminance(invertedDark) > UI.getLuminance(Color3.new(0.1, 0.1, 0.1))).toBe(true)
			local invertedLight = UI.invertLuminance(Color3.new(0.9, 0.9, 0.9), 0.2)
			expect(UI.getLuminance(invertedLight) < UI.getLuminance(Color3.new(0.9, 0.9, 0.9))).toBe(true)

			-- pointInGuiObject & sinkInput
			local frame = UI.new "Frame" {
				Parent = UI.LayerDefault,
				Position = UDim2.fromOffset(10, 20),
				Size = UDim2.fromOffset(100, 50),
			}
			local pos = frame.AbsolutePosition
			local sz = frame.AbsoluteSize
			expect(UI.pointInGuiObject(pos.X, pos.Y, frame)).toBe(true)
			expect(UI.pointInGuiObject(pos.X + sz.X + 50, pos.Y + sz.Y + 50, frame)).toBe(false)
			expect(type(UI.sinkInput(0, 0, frame))).toBe("boolean")

			-- retryGetTextBoundsAsync with retry on transient failure
			local origTextMethods = rawget(UI.TextService, "_methods")
			local attempts = 0
			rawset(UI.TextService, "_methods", {
				GetTextSize = origTextMethods.GetTextSize,
				FilterStringAsync = origTextMethods.FilterStringAsync,
				GetTextBoundsAsync = function(self, params)
					attempts += 1
					if attempts == 1 then
						error("transient TextService failure")
					end
					return origTextMethods.GetTextBoundsAsync(self, params)
				end,
			})
			local retryBounds = nil
			client:spawn(function()
				retryBounds = UI.retryGetTextBoundsAsync({ Text = "Hello", Size = 14, Width = 200 })
			end)
			world:run(3)
			expect(attempts).toBe(2)
			expect(retryBounds ~= nil).toBe(true)

			-- retryGetTextBoundsAsync falls back to Vector2.zero after 5 failed attempts
			local failAttempts = 0
			rawset(UI.TextService, "_methods", {
				GetTextSize = origTextMethods.GetTextSize,
				FilterStringAsync = origTextMethods.FilterStringAsync,
				GetTextBoundsAsync = function()
					failAttempts += 1
					error("permanent TextService failure")
				end,
			})
			local fallbackBounds = nil
			client:spawn(function()
				fallbackBounds = UI.retryGetTextBoundsAsync({ Text = "Hello", Size = 14, Width = 200 })
			end)
			for _ = 1, 6 do
				world:run(1)
			end
			expect(failAttempts).toBe(5)
			expect(fallbackBounds).toBe(Vector2.zero)
			rawset(UI.TextService, "_methods", origTextMethods)

			-- makeStatefulDefaults with Nil, Function, compute, and values
			local fn = function()
				return 42
			end
			local defs = UI.makeStatefulDefaults({
				a = 10,
				b = UI.Nil,
				c = UI.Function,
				d = function()
					return 99
				end,
			}, {
				a = 20,
				c = fn,
			})
			expect(UI.isNode(defs.a)).toBe(true)
			expect(defs.a()).toBe(20)
			expect(defs.b).toBeNil()
			expect(UI.isNode(defs.c)).toBe(true)
			expect(defs.c()).toBe(fn)
			expect(UI.isNode(defs.d)).toBe(true)
			expect(defs.d()).toBe(99)
			expect(#defs._createdNodes).toBe(3)

			-- UI.textWidth
			local twSig, twMeasure = UI.textWidth(function()
				return {
					{
						Text = "<b>Hello</b>",
						Font = Font.fromEnum(Enum.Font.Gotham),
						Size = 16,
						RichText = true,
					},
				}
			end)
			expect(twSig:peek() > 0).toBe(true)
			world:run(2)
			expect(twSig:peek() > 0).toBe(true)
			twMeasure:Destroy()
			twSig:Destroy()

			-- newSinkHoverState (processed vs unprocessed)
			local hoverFrame = UI.new "Frame" { Parent = UI.LayerDefault }
			local hoverState = UI.newSinkHoverState(hoverFrame)
			expect(UI.isNode(hoverState)).toBe(true)
			expect(hoverState()).toBe(false)
			UI.GuiService.MenuIsOpen = true
			hoverFrame.InputChanged:Fire(
				makeInput(
					cliMounted.env,
					{ UserInputType = Enum.UserInputType.MouseMovement, Position = Vector3.new(5, 5, 0) }
				),
				true
			)
			expect(hoverState()).toBe(false)
			UI.GuiService.MenuIsOpen = false
			hoverFrame.InputChanged:Fire(
				makeInput(
					cliMounted.env,
					{ UserInputType = Enum.UserInputType.MouseMovement, Position = Vector3.new(5, 5, 0) }
				),
				false
			)
			expect(hoverState()).toBe(true)
			hoverFrame.InputEnded:Fire(
				makeInput(
					cliMounted.env,
					{ UserInputType = Enum.UserInputType.MouseMovement, Position = Vector3.new(5, 5, 0) }
				)
			)
			expect(hoverState()).toBe(false)
			local externalHover = UI.signal(true)
			local hoverFrame2 = UI.new "Frame" { Parent = UI.LayerDefault }
			UI.newSinkHoverState(hoverFrame2, externalHover)
			expect(externalHover()).toBe(false)
			hoverFrame2:Destroy()

			-- UI.edit with numeric children (including wrapped class child & preset LayoutOrder), UI.Hook, and DefaultProperties
			local child1 = UI.new "Frame" { Name = "Child1" }
			local child2 = UI.new "TextButton" { Name = "Child2", LayoutOrder = 7 }
			local child3 = { _instance = UI.new "Frame" { Name = "Child3" } }
			local imgBtn = UI.new "ImageButton" { Name = "ImgBtn" }
			expect(child2.HoverHapticEffect).toBe(UI.Haptic.Hover)
			expect(imgBtn.PressHapticEffect).toBe(UI.Haptic.Click)

			local hookedVal = nil
			local customComp = {
				_instance = UI.new "Frame" {},
				_content = UI.new "Frame" {},
				MyState = UI.signal("init"),
			}
			UI.edit(customComp) {
				Name = "EditedRoot",
				[1] = child1,
				[2] = child2,
				[3] = child3,
				[UI.Hook] = {
					MyState = function(v)
						hookedVal = v
					end,
				},
			}
			expect(customComp._instance.Name).toBe("EditedRoot")
			expect(child1.Parent).toBe(customComp._content)
			expect(child1.LayoutOrder).toBe(1)
			expect(child2.LayoutOrder).toBe(7)
			expect(child3._instance.Parent).toBe(customComp._content)
			expect(child3._instance.LayoutOrder).toBe(2)
			customComp.MyState("updated")
			UI.flush()
			expect(hookedVal).toBe("updated")

			-- Invalid UI.Hook throws
			expect(pcall(function()
				UI.edit(customComp) {
					[UI.Hook] = { NonExistent = function() end },
				}
			end)).toBe(false)

			-- Theme states and computed properties
			local soundGroup = cliMounted.env.game:GetService("SoundService"):FindFirstChild("_KASounds")
			UI.Theme.SoundEnabled(false)
			UI.flush()
			if soundGroup then
				expect(soundGroup.Volume).toBe(0)
			end
			UI.Theme.SoundEnabled(true)
			UI.flush()
			if soundGroup then
				expect(soundGroup.Volume).toBe(UI.Theme.Volume())
			end
			UI.Theme.TypingSounds(false)
			expect(UI.Theme.TypingSounds()).toBe(false)
			UI.Theme.TypingSounds(true)
			expect(UI.Theme.TypingSounds()).toBe(true)
			UI.Theme.TypingSoundsOnEveryTextBox(false)
			expect(UI.Theme.TypingSoundsOnEveryTextBox()).toBe(false)
			UI.Theme.TypingSoundsOnEveryTextBox(true)
			expect(UI.Theme.TypingSoundsOnEveryTextBox()).toBe(true)
			UI.Theme.FontSize(18)
			expect(UI.Theme.FontSizeDouble()).toBe(36)
			expect(UI.Theme.FontSizeLargest()).toBe(math.round(18 * 1.75))
			expect(UI.Theme.FontSizeLarger()).toBe(27)
			expect(UI.Theme.FontSizeLarge()).toBe(math.round(18 * 1.25))
			expect(UI.Theme.FontSizeSmall()).toBe(math.round(18 * 0.75))
			expect(UI.Theme.FontSizeSmaller()).toBe(9)
			expect(UI.Theme.FontSizeSmallest()).toBe(math.round(18 * 0.25))
			UI.Theme.FontSize(16)

			UI.Theme.CornerRadius(UDim.new(0, 0))
			expect(UI.Theme.ScrollTopImage()).toBe("rbxassetid://18370268668")
			expect(UI.Theme.ScrollBottomImage()).toBe("rbxassetid://18370268668")
			UI.Theme.CornerRadius(UDim.new(0, 8))
			expect(UI.Theme.CornerHalf().Offset).toBe(4)
			expect(UI.Theme.CornerDiameter().Offset).toBe(16)

			-- UI.new custom class constructor, unwrapChild in UI.new, direct GuiObject LayoutOrder, and parent._content unwrapping
			local customChild1 = { _instance = UI.new "Frame" { Name = "WrappedChild1" } }
			local customChild2 = { _instance = UI.new "Frame" { Name = "WrappedChild2" } }
			local customChild3 = { { _instance = UI.new "Frame" { Name = "NestedWrappedChild3" } } }
			local directChild1 = UI.new "Frame" { Name = "DirectChild1" }
			local directChild2 = UI.new "Frame" { Name = "DirectChild2", LayoutOrder = 9 }
			local hostFrame = UI.new "Frame" {
				Parent = customComp,
				customChild1,
				customChild2,
				customChild3,
				directChild1,
				directChild2,
			}
			expect(hostFrame.Parent).toBe(customComp._content)
			expect(customChild1._instance.Parent).toBe(hostFrame)
			expect(customChild1._instance.LayoutOrder).toBe(1)
			expect(customChild2._instance.Parent).toBe(hostFrame)
			expect(customChild2._instance.LayoutOrder).toBe(2)
			expect(customChild3[1].Parent).toBe(hostFrame)
			expect(directChild1.LayoutOrder).toBe(4)
			expect(directChild2.LayoutOrder).toBe(9)

			local customBtn = UI.new "Button" {
				Parent = customComp,
				Label = "Part1Btn",
			}
			expect(customBtn._instance.Parent).toBe(customComp._content)
			expect(#customBtn._createdNodes > 0).toBe(true)
			local btnNodeDestroyed = 0
			customBtn.ActiveSound:onDestroy(function()
				btnNodeDestroyed += 1
			end)
			customBtn._instance:Destroy()
			expect(btnNodeDestroyed).toBe(1)

			-- Hover state cleanup on destroy
			local hoverDestroyFrame = UI.new "Frame" { Parent = UI.LayerDefault }
			local hoverDestroyState = UI.newSinkHoverState(hoverDestroyFrame)
			local hoverDestroyed = 0
			hoverDestroyState:onDestroy(function()
				hoverDestroyed += 1
			end)
			hoverDestroyFrame:Destroy()
			expect(hoverDestroyed).toBe(1)

			-- Invalid UTF-8 text width estimation falls back to #text
			local badUtf8Sig, badUtf8Eff = UI.textWidth(function()
				return {
					{
						Text = "\255\255\255\255",
						Font = Font.fromEnum(Enum.Font.Gotham),
						Size = 20,
					},
				}
			end)
			expect(badUtf8Sig:peek()).toBe(math.ceil(4 * 20 * 0.55))
			badUtf8Eff:Destroy()
			badUtf8Sig:Destroy()

			-- Non-integer numeric key in UI.new is not overwritten by unwrapChild
			local fracFrame = UI.new "Frame" {
				[1.5] = "custom_frac" :: any,
			}
			expect(fracFrame ~= nil).toBe(true)

			local reactiveTxt = UI.signal("InitialTxt")
			local reactiveLbl = UI.new "TextLabel" {
				Text = function()
					return reactiveTxt()
				end,
			}
			expect(reactiveLbl.Text).toBe("InitialTxt")
		end)
	end)

	describe("Part 1b · Console Top Bar", function()
		test("console screens keep the fixed top bar layout and stay visible with a zero-height TopbarInset", function()
			local world = sert.sim.new({ backing = true })
			local server = world:server()
			local client = server:client(1, "Player1")
			local cliMounted = setupClientEnv(client)

			-- UI reads IsTenFootInterface once at load, so fake a console before the first require
			local guiService: any = cliMounted.env.game:GetService("GuiService")
			local methods: any = rawget(guiService, "_methods")
			methods.IsTenFootInterface = function()
				return true
			end
			local UI = cliMounted.env:require(cliMounted.Client.UI)
			expect(UI.IsConsoleScreen).toBe(true)

			UI.GuiService.TopbarInset = Rect.new(0, 0, 1280, 0)
			world:step()
			UI.flush()

			expect(UI.TopbarPadding().Offset).toBe(10)
			expect(UI.TopbarFrame.Visible).toBe(true)
			expect(UI.TopbarFrame.Position).toEqual(UDim2.fromOffset(0, 4))
			expect(UI.TopbarFrame.Size.Y.Offset).toBe(50)
			expect(UI.LayerTopInset.Size.Y.Offset).toBe(-54)

			local padding = UI.TopbarFrame:FindFirstChildOfClass("UIPadding")
			expect(padding ~= nil).toBe(true)
			expect(padding.PaddingLeft.Offset).toBe(10)
			expect(padding.PaddingTop.Offset).toBe(6)
			expect(padding.PaddingBottom.Offset).toBe(0)
			expect(padding.PaddingRight.Offset).toBe(10)

			-- the console layout does not follow TopbarInset
			UI.GuiService.TopbarInset = Rect.new(0, 0, 1280, 58)
			world:step()
			UI.flush()
			expect(UI.TopbarPadding().Offset).toBe(10)
			expect(UI.LayerTopInset.Size.Y.Offset).toBe(-54)
			expect(UI.TopbarFrame.Size.Y.Offset).toBe(108)
			expect(padding.PaddingTop.Offset).toBe(6)
		end)
	end)

	describe("Part 2 · UI.Class Component Suite", function()
		test("instantiates and exercises all 21 UI.Class components and Clack", function()
			local world = sert.sim.new({ backing = true })
			local server = world:server()
			local client = server:client(1, "Player1")
			local cliMounted = setupClientEnv(client)
			local env = cliMounted.env

			local UI = env:require(cliMounted.Client.UI)
			if UI.registerClasses then
				UI.registerClasses()
			end
			local Clack = env:require(cliMounted.Client.UI.Classes.Input.Clack)

			-- 1. Button
			local btnClicked = 0
			local hoverSoundPlays = 0
			local origHover01 = UI.Sound.Hover01
			UI.Sound.Hover01 = {
				Play = function()
					hoverSoundPlays += 1
				end,
			} :: any
			local btn = UI.new "Button" {
				Parent = UI.LayerDefault,
				Position = UDim2.fromOffset(30, 0),
				Label = "Click Me",
				Icon = "rbxassetid://12345",
				IconRightAlign = true,
				AutomaticSize = Enum.AutomaticSize.XY,
				Activated = function()
					btnClicked += 1
				end,
			}
			expect(btn._content.Label.Visible).toBe(true)
			expect(btn._content.Label.Text).toBe("Click Me")
			expect(btn._content.IconFrame.Visible).toBe(true)
			expect(btn._instance.Size.X.Scale).toBe(0)
			btn.AutomaticSize(Enum.AutomaticSize.X)
			btn.AutomaticSize(Enum.AutomaticSize.Y)
			btn.AutomaticSize(Enum.AutomaticSize.None)
			UI.flush()
			expect(btn._instance.Size.X.Scale).toBe(1)
			env:input():click(btn._instance)
			expect(btnClicked).toBe(1)
			expect(hoverSoundPlays).toBe(1)
			btn.ActiveSound(false)
			env:input():click(btn._instance)
			expect(hoverSoundPlays).toBe(1)
			btn.ActiveSound(true)
			UI.Sound.Hover01 = origHover01
			btn._instance.InputBegan:Fire(
				makeInput(env, { UserInputType = Enum.UserInputType.MouseButton1, Position = Vector3.new(50, 10, 0) }),
				false
			)
			expect(btn._instance.Ripple.Position.X.Offset).toBe(50 - btn._instance.AbsolutePosition.X)
			btn._instance.InputChanged:Fire(
				makeInput(env, { UserInputType = Enum.UserInputType.MouseMovement, Position = Vector3.new(10, 10, 0) }),
				false
			)
			expect(btn._hovering()).toBe(true)

			-- Button + child Tooltip hover never flickers across repeated MouseMovement events
			local btnTip = UI.new "Tooltip" {
				Parent = btn,
				Text = "Button Tip",
			}
			for px = 11, 20 do
				btn._instance.InputChanged:Fire(
					makeInput(
						env,
						{ UserInputType = Enum.UserInputType.MouseMovement, Position = Vector3.new(px, 10, 0) }
					),
					false
				)
				UI.flush()
				expect(btn._hovering()).toBe(true)
				expect(btnTip.Hovering()).toBe(true)
			end

			btn._instance.InputEnded:Fire(
				makeInput(env, { UserInputType = Enum.UserInputType.MouseMovement, Position = Vector3.new(10, 10, 0) })
			)
			UI.flush()
			expect(btn._hovering()).toBe(false)
			expect(btnTip.Hovering()).toBe(false)
			btn:Destroy()
			expect(UI.Theme.Font:peek() ~= nil).toBe(true)

			-- 2. Checkbox
			local cb = UI.new "Checkbox" {
				Parent = UI.LayerDefault,
				Value = false,
			}
			expect(cb.Value()).toBe(false)
			cb._instance.Activated:Fire()
			expect(cb.Value()).toBe(true)
			cb._instance.Activated:Fire()
			expect(cb.Value()).toBe(false)
			cb:Destroy()

			-- 3. Switch
			local sw = UI.new "Switch" {
				Parent = UI.LayerDefault,
				Value = false,
			}
			expect(sw.Value()).toBe(false)
			sw._instance.Activated:Fire()
			expect(sw.Value()).toBe(true)
			sw._instance.Activated:Fire()
			expect(sw.Value()).toBe(false)
			sw:Destroy()

			-- 4. CircleProgress
			local cp = UI.new "CircleProgress" {
				Parent = UI.LayerDefault,
				Alpha = 0,
			}
			expect(cp._instance.Left.Visible).toBe(false)
			expect(cp._instance.Right.Visible).toBe(false)
			cp.Alpha(0.25)
			UI.flush()
			expect(cp._instance.Left.Visible).toBe(false)
			expect(cp._instance.Right.Visible).toBe(true)
			cp.Alpha(0.75)
			UI.flush()
			expect(cp._instance.Left.Visible).toBe(true)
			expect(cp._instance.Right.Visible).toBe(true)
			cp.Alpha(1)
			UI.flush()
			expect(cp._instance.Left.ImageLabel.UIGradient.Rotation).toBe(0)
			expect(cp._instance.Right.ImageLabel.UIGradient.Rotation).toBe(180)
			cp:Destroy()

			-- 5 & 6. Color & ColorPicker
			local colorComp = UI.new "Color" {
				Parent = UI.LayerDefault,
				Value = Color3.fromRGB(255, 0, 0),
			}
			expect(colorComp._dialog.Visible()).toBe(false)
			colorComp._instance.Activated:Fire()
			expect(colorComp._dialog.Visible()).toBe(true)
			colorComp._instance.Activated:Fire()
			expect(colorComp._dialog.Visible()).toBe(false)

			local picker = colorComp._dialog
			picker.hueSlider.Value(0.5)
			UI.flush()
			picker.hexInput._input.Text = "#00ff00"
			picker.hexInput._input.FocusLost:Fire(true)
			UI.flush()
			expect(colorComp.Value():ToHex()).toBe("00ff00")

			-- ColorPicker hueSlider on 0-saturation color (pure white)
			colorComp.Value(Color3.new(1, 1, 1), true)
			UI.flush()
			picker.hueSlider.Value(0.5, true)
			UI.flush()
			local hWhite, sWhite, vWhite = picker.sv.BackgroundColor3:ToHSV()
			expect(hWhite).toBeCloseTo(0.5, 2)
			expect(sWhite).toBeCloseTo(1, 2)
			expect(vWhite).toBeCloseTo(1, 2)

			-- Dragging SV box in ColorPicker
			local svDragInput = makeInput(env, {
				UserInputType = Enum.UserInputType.MouseButton1,
				UserInputState = Enum.UserInputState.Begin,
				Position = Vector3.new(20, 20, 0),
			})
			picker.sv.InputBegan:Fire(svDragInput)
			UI.UserInputService.InputChanged:Fire(
				makeInput(env, { UserInputType = Enum.UserInputType.MouseMovement, Position = Vector3.new(30, 30, 0) })
			)
			svDragInput.UserInputState = Enum.UserInputState.End
			colorComp:Destroy()

			-- 7. Dialog (confirm/cancel, drag, duration)
			local dialogActionResult = nil
			local dialogClosed = false
			local dlg = UI.new "Dialog" {
				Parent = UI.LayerDefault,
				Title = "Confirm Dialog",
				Text = "Are you sure?",
				ActionText = "Confirm?",
				Action = true,
				LeftAction = true,
				RightAction = true,
				ExitButton = true,
				Draggable = true,
				Duration = 0.05,
				Close = function()
					dialogClosed = true
				end,
				[UI.Hook] = {
					Action = function(val)
						dialogActionResult = val
					end,
				},
			}
			-- Drag dialog via title
			local dlgDragInput = makeInput(env, {
				UserInputType = Enum.UserInputType.MouseButton1,
				UserInputState = Enum.UserInputState.Begin,
				Position = Vector3.new(50, 50, 0),
			})
			dlg._content.Title.InputBegan:Fire(dlgDragInput, false)
			UI.UserInputService.InputChanged:Fire(
				makeInput(env, { UserInputType = Enum.UserInputType.MouseMovement, Position = Vector3.new(70, 80, 0) })
			)
			dlgDragInput.UserInputState = Enum.UserInputState.End

			-- Trigger RightAction (true)
			local actionsFrame = dlg._instance.Frame:FindFirstChild("Actions")
			expect(actionsFrame ~= nil).toBe(true)
			actionsFrame.RightAction.Activated:Fire()
			UI.flush()
			expect(dialogActionResult).toBe(true)
			expect(dialogClosed).toBe(true)
			dlg:Destroy()

			-- Timed dialog auto-closes on PreRender
			local timedDlg = UI.new "Dialog" {
				Parent = UI.LayerDefault,
				Text = "Timed",
				Duration = 0.05,
				LeftAction = true,
			}
			world:run(0.2)
			expect(timedDlg._instance.Parent).toBeNil()

			-- Dialog with Options and OptionColors fires Action with selected option index
			local optionActionIndex = nil
			local optDlg = UI.new "Dialog" {
				Parent = UI.LayerDefault,
				Text = "Pick one",
				ActionText = "<b>CAST YOUR VOTE</b>",
				Action = true,
				Options = { "Alpha", "Beta", "Gamma" },
				OptionColors = { UI.Theme.Valid, UI.Theme.Invalid, UI.Theme.Secondary },
				[UI.Hook] = {
					Action = function(idx)
						optionActionIndex = idx
					end,
				},
			}
			local optionsFrame = optDlg._instance.Frame:FindFirstChild("Options")
			expect(optionsFrame ~= nil).toBe(true)
			expect(optionsFrame.Text.LayoutOrder).toBe(-1)
			optionsFrame.Option2.Activated:Fire()
			UI.flush()
			expect(optionActionIndex).toBe(2)
			optDlg:Destroy()

			-- 8, 9, 10, 11, 12. Gradient, Stroke, Spacer, Link, Tooltip
			local grad = UI.new "Gradient" { Parent = UI.LayerDefault }
			expect(grad._instance.ClassName).toBe("UIGradient")
			grad:Destroy()

			local stroke = UI.new "Stroke" { Parent = UI.LayerDefault }
			expect(stroke._instance.ClassName).toBe("UIStroke")
			stroke:Destroy()

			local spacer = UI.new "Spacer" { Parent = UI.LayerDefault }
			expect(spacer._instance.ClassName).toBe("Frame")
			spacer:Destroy()

			local link = UI.new "Link" {
				Parent = UI.LayerDefault,
				Text = "https://example.com",
				Tooltip = "Click to copy",
			}
			link:Select()
			link._instance.Focused:Fire()
			expect(link._instance.SelectionStart).toBe(1)
			expect(link._instance.CursorPosition).toBe(#link._instance.Text + 1)
			link._instance.CursorPosition = 1
			expect(link._instance.SelectionStart).toBe(1)
			expect(link._instance.CursorPosition).toBe(#link._instance.Text + 1)
			link._instance.InputEnded:Fire(
				makeInput(env, { UserInputType = Enum.UserInputType.MouseButton1, Position = Vector3.new(10, 10, 0) })
			)
			expect(link._instance.SelectionStart).toBe(1)
			expect(link._instance.CursorPosition).toBe(#link._instance.Text + 1)
			link._instance:ReleaseFocus()
			link._instance.FocusLost:Fire()
			expect(link._instance.SelectionStart).toBe(-1)
			expect(link._instance.Text).toBe("https://example.com")
			link:Destroy()
			-- Firing Focused / FocusLost after Link:Destroy() is a safe no-op
			link._instance.Focused:Fire()
			link._instance.FocusLost:Fire()
			world:run(0.05)

			-- Theme.load keeps Theme.Themes entries as plain value tables (no nested Flux signals)
			local lightThemeModule = cliMounted.Client.UI.Theme.Themes.Light
			UI.Theme.Themes.Light = nil
			UI.Theme.load(lightThemeModule)
			expect(env.globals.typeof(UI.Theme.Themes.Light.Primary)).toBe("Color3")
			expect(UI.isNode(UI.Theme.Themes.Light.Primary)).toBe(false)

			local tipTarget = UI.new "Frame" {
				Parent = UI.LayerDefault,
				Position = UDim2.fromOffset(1250, 710),
				Size = UDim2.fromOffset(100, 750),
			}
			local tip = UI.new "Tooltip" {
				Parent = tipTarget,
				Text = "Helpful tip",
			}
			-- gamepad/keyboard selection drives tooltips through GuiService.SelectedObject (UI.Interact.selected)
			local guiService = UI.GuiService
			guiService.SelectedObject = tipTarget
			UI.flush()
			expect(tip.Hovering()).toBe(true)
			world:run(0.5)
			expect(tip.Visible()).toBe(true)
			tipTarget.Position = UDim2.fromOffset(1260, 5)
			tipTarget.Size = UDim2.fromOffset(100, 750)
			guiService.SelectedObject = nil
			UI.flush()
			expect(tip.Visible()).toBe(false)
			tip:Destroy()

			-- 13 & 14. Input & Clack
			Clack.sound(Enum.KeyCode.A)
			Clack.sound(Enum.KeyCode.B)

			local textInput = UI.new "Input" {
				Parent = UI.LayerDefault,
				Placeholder = "Enter text",
				ClearTextButton = true,
				MaxChars = 5,
				Icon = "rbxassetid://123",
				IconProperties = { ImageTransparency = 0.1 },
				Validate = function(v)
					return v ~= "bad"
				end,
			}
			UI.UserInputService.TextBoxFocused:Fire(textInput._input)
			UI.UserInputService.InputBegan:Fire(
				makeInput(env, { UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.A }),
				false
			)
			UI.UserInputService.TextBoxFocusReleased:Fire(textInput._input)

			textInput._input.Text = "hello_world"
			expect(textInput._input.Text).toBe("hello") -- MaxChars = 5
			textInput._input.SelectionStart = 1
			textInput._input.CursorPosition = 3
			world:run(0.1)
			textInput._input.SelectionStart = -1
			textInput._input.CursorPosition = -1
			textInput._input.FocusLost:Fire(true)
			expect(textInput.Value()).toBe("hello")

			-- Reject invalid via Validate
			textInput._input.Text = "bad"
			textInput._input.FocusLost:Fire(true)
			expect(textInput.Value()).toBe("hello")

			-- SetValue reaches the TextBox before the next flush, so FocusLost keeps it instead of the stale text
			textInput:SetValue("abc")
			expect(textInput._input.Text).toBe("abc")
			textInput._input.FocusLost:Fire(true)
			expect(textInput.Value()).toBe("abc")

			-- ClearTextButton
			textInput._instance.ImageButton.Activated:Fire()
			expect(textInput.Value()).toBe("")
			textInput:Destroy()

			-- NumberOnly / IntegerOnly Input
			local numInput = UI.new "Input" {
				Parent = UI.LayerDefault,
				NumberOnly = true,
				IntegerOnly = true,
				NumberRange = NumberRange.new(10, 50),
				Value = 20,
			}
			numInput._input.Text = ""
			numInput._input.FocusLost:Fire(true)
			expect(numInput.Value()).toBe(10)
			expect(numInput._input.Text).toBe("10")
			-- Clearing again while Value is already at NumberRange.Min still restores _input.Text to Min
			numInput._input.Text = ""
			numInput._input.FocusLost:Fire(true)
			expect(numInput.Value()).toBe(10)
			expect(numInput._input.Text).toBe("10")
			numInput._input.Text = "999"
			numInput._input.FocusLost:Fire(true)
			expect(tonumber(numInput.Value())).toBe(50)
			numInput._input.Text = "abc"
			numInput._input.FocusLost:Fire(true)
			numInput:Destroy()

			-- HotkeyInput mode
			local hkInput = UI.new "Input" {
				Parent = UI.LayerDefault,
				HotkeyInput = true,
				Hotkey = Enum.KeyCode.Semicolon,
				Modifiers = {},
			}
			hkInput._input:CaptureFocus()
			UI.UserInputService.InputBegan:Fire(
				makeInput(env, { UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.LeftShift }),
				false
			)
			UI.UserInputService.InputBegan:Fire(
				makeInput(env, { UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.K }),
				false
			)
			expect(hkInput.Hotkey()).toBe(Enum.KeyCode.K)
			hkInput:Destroy()

			-- 15 & 16. List & ListItem
			local listComp = UI.new "List" {
				Parent = UI.LayerDefault,
				Label = "Section",
				Collapsible = true,
				Collapsed = false,
				UI.new "ListItem" {
					Text = "Row 1",
					Tooltip = "Row 1 tip",
					ContentAutomaticSize = false,
					ContentListLayout = false,
				},
			}
			expect(listComp.Collapsed()).toBe(false)
			listComp._instance.Header.Activated:Fire()
			expect(listComp.Collapsed()).toBe(true)
			listComp._instance.Header.Activated:Fire()
			expect(listComp.Collapsed()).toBe(false)
			listComp:Destroy()

			-- 17. Menu
			local adorneeBtn = UI.new "Frame" {
				Parent = UI.LayerDefault,
				Position = UDim2.fromOffset(100, 100),
				Size = UDim2.fromOffset(40, 20),
			}
			local menuComp = UI.new "Menu" {
				Adornee = adorneeBtn,
				RightAlign = true,
				Visible = false,
			}
			UI.activateState(menuComp.Visible, "floating")
			expect(menuComp.Visible()).toBe(true)
			menuComp._content.CanvasPosition = Vector2.new(0, 10)
			-- Clicking outside closes menu
			UI.UserInputService.InputBegan:Fire(
				makeInput(env, { UserInputType = Enum.UserInputType.MouseButton1, Position = Vector3.new(500, 500, 0) }),
				false
			)
			expect(menuComp.Visible()).toBe(false)
			menuComp:Destroy()

			-- 18 & 19. Scroller & ScrollerFast
			local scroller = UI.new "Scroller" { Parent = UI.LayerDefault }
			expect(scroller._instance.ClassName).toBe("ScrollingFrame")
			scroller:Destroy()

			expect(UI.Class.ScrollerFast.escapeRichText(`<a&"b'>`)).toBe("&lt;a&amp;&quot;b&apos;&gt;")
			local arrayState = UI.signal({ "Alpha", "Beta", "Gamma" })
			local fastArray = UI.new "ScrollerFast" {
				Parent = UI.LayerDefault,
				List = arrayState,
				FilterInput = true,
				FilterInputDebounce = 0.02,
				Visible = true,
			}
			world:run(0.2)
			fastArray:forceRender()
			expect(next(fastArray._lineItemCache) ~= nil).toBe(true)
			-- Scroll canvas (> sizeY and < sizeY) and trigger pause-canvas adjustment on refresh
			fastArray._scroller.CanvasPosition = Vector2.new(0, 200)
			fastArray._scroller.CanvasPosition = Vector2.new(0, 210)
			fastArray:refreshList()
			world:run(0.2)
			arrayState({ "Alpha", "Beta", "Gamma", "Delta" })
			world:run(0.2)
			fastArray._scroller.CanvasPosition = Vector2.zero
			fastArray._input._input.Text = "be"
			fastArray._input._input.Text = "beta"
			world:run(0.2)
			fastArray:forceRender()
			expect(#fastArray._filteredList).toBe(1)
			fastArray._input._input.Text = ""
			world:run(0.2)
			fastArray:sort(function(a, b)
				return a > b
			end)
			world:run(0.2)
			expect(fastArray._filteredList[1]).toBe("Gamma")
			fastArray:sort(nil :: any)
			world:run(0.2)
			fastArray._scroller._props.AbsoluteCanvasSize = Vector2.new(100, 50)
			fastArray._scroller:GetPropertyChangedSignal("AbsoluteCanvasSize"):Fire()
			-- Calling render(true) while hidden defers cache invalidation until forceRender() runs while visible
			fastArray._instance.Visible = false
			expect(next(fastArray._lineItemCache) ~= nil).toBe(true)
			fastArray:render(true)
			expect(fastArray._bustCache).toBe(true)
			expect(next(fastArray._lineItemCache) ~= nil).toBe(true)
			fastArray._instance.Visible = true
			world:run(0.2)
			expect(fastArray._bustCache).toBeNil()
			expect(next(fastArray._lineItemCache) ~= nil).toBe(true)
			fastArray:Destroy()

			local fastDict = UI.new "ScrollerFast" {
				Parent = UI.LayerDefault,
				List = { k1 = "Val1", k2 = "Val2" },
				DictList = true,
				ReverseOrder = true,
				Visible = true,
				CreateItem = function(self)
					return UI.new "TextLabel" { Size = self.ItemSize }
				end,
				RenderItem = function(_self, item, val)
					item.Text = tostring(val)
				end,
			}
			world:run(0.2)
			fastDict:forceRender()
			expect(next(fastDict._lineItemCache) ~= nil).toBe(true)
			fastDict:filter(function(_self, list)
				local out = {}
				for _, k in list do
					if k == "k1" then
						table.insert(out, k)
					end
				end
				return out
			end)
			world:run(0.2)
			expect(#fastDict._filteredList).toBe(1)
			expect(fastDict._filteredList[1]).toBe("k1")
			fastDict:freeCache()
			fastDict:Destroy()

			-- 20. Select
			local sel = UI.new "Select" {
				Parent = UI.LayerDefault,
				Value = "Choice A",
				Choices = {
					"Default",
					"Choice A",
					"Choice B",
					Enum.Font.Code,
					Font.fromEnum(Enum.Font.Gotham),
					{ Name = "TableChoice" },
				},
			}
			sel._instance.Header.Activated:Fire()
			expect(sel.menu.Visible()).toBe(true)
			local choiceBBtn = sel.menu._content:FindFirstChild("Choice B") :: TextButton
			expect(choiceBBtn ~= nil).toBe(true)
			choiceBBtn.Activated:Fire()
			expect(sel.Value()).toBe("Choice B")
			sel.Choices({ "New 1", "New 2" })
			expect(#sel.Choices()).toBe(2)
			sel:Destroy()

			-- 21. Slider
			local slider = UI.new "Slider" {
				Parent = UI.LayerDefault,
				Snap = 5,
				Value = 1,
				Vertical = false,
			}
			local sldInput = makeInput(env, {
				UserInputType = Enum.UserInputType.MouseButton1,
				UserInputState = Enum.UserInputState.Begin,
				Position = Vector3.new(50, 10, 0),
			})
			slider._instance.InputBegan:Fire(sldInput)
			UI.UserInputService.InputChanged:Fire(
				makeInput(env, { UserInputType = Enum.UserInputType.MouseMovement, Position = Vector3.new(100, 10, 0) })
			)
			sldInput.UserInputState = Enum.UserInputState.End
			slider.Vertical(true)
			expect(slider.Vertical()).toBe(true)
			slider:Destroy()

			-- 22. Tabs (including tab dragging and mousewheel scrolling)
			local page1 = UI.new "Frame" { Name = "Page1" }
			local page2 = UI.new "Frame" { Name = "Page2" }
			local tabsComp = UI.new "Tabs" {
				Parent = UI.LayerDefault,
				CurrentPage = page1,
				Tabs = {
					{ page1, "rbxassetid://111" },
					{ page2, "rbxassetid://222" },
				},
				Vertical = false,
			}
			local barTabs = tabsComp._instance.Bar.Tabs
			barTabs._props.AbsoluteCanvasSize = Vector2.new(500, 30)
			barTabs._props.AbsoluteSize = Vector2.new(100, 30)
			local page1Btn = barTabs:FindFirstChild("Page1") :: TextButton
			local page2Btn = barTabs:FindFirstChild("Page2") :: TextButton
			expect(page2Btn ~= nil).toBe(true)
			page2Btn.Activated:Fire()
			expect(tabsComp.CurrentPage()).toBe(page2)

			if page1Btn and page2Btn then
				page1Btn._props.AbsolutePosition = Vector2.new(0, 0)
				page1Btn._props.AbsoluteSize = Vector2.new(40, 24)
				page2Btn._props.AbsolutePosition = Vector2.new(45, 0)
				page2Btn._props.AbsoluteSize = Vector2.new(40, 24)
				local tabDragInput = makeInput(env, {
					UserInputType = Enum.UserInputType.MouseButton1,
					UserInputState = Enum.UserInputState.Begin,
					Position = Vector3.new(10, 10, 0),
				})
				page1Btn.InputBegan:Fire(tabDragInput, false)
				UI.UserInputService.InputChanged:Fire(
					makeInput(
						env,
						{ UserInputType = Enum.UserInputType.MouseMovement, Position = Vector3.new(60, 10, 0) }
					)
				)
				world:run(0.1)
				tabDragInput.UserInputState = Enum.UserInputState.End
				world:run(0.1)
			end

			tabsComp._pages:Previous()
			tabsComp._pages:Next()
			barTabs.MouseWheelBackward:Fire()
			world:run(0.1)
			barTabs.MouseWheelForward:Fire()
			world:run(0.1)
			tabsComp.Vertical(true)
			expect(tabsComp.Vertical()).toBe(true)
			tabsComp:Destroy()

			-- 23. Window
			local winClosed = false
			local paddedParent = UI.new "Frame" {
				Parent = UI.LayerDefault,
				Size = UDim2.fromOffset(800, 600),
				UI.new "UIPadding" {
					PaddingLeft = UDim.new(0, 10),
					PaddingRight = UDim.new(0, 10),
					PaddingTop = UDim.new(0, 10),
					PaddingBottom = UDim.new(0, 10),
				},
			}
			local win1 = UI.new "Window" {
				Parent = UI.LayerDefault,
				Title = "Win1",
				Icon = "rbxassetid://123",
				Position = UDim2.fromOffset(100, 100),
				Size = UDim2.fromOffset(300, 300),
				Close = function()
					winClosed = true
				end,
			}
			win1._instance.Visible = true
			win1._instance.Parent = paddedParent
			paddedParent.Size = UDim2.fromOffset(700, 500)
			expect(win1._instance.UISizeConstraint.MaxSize).toEqual(Vector2.new(680, 480))
			paddedParent.Size = UDim2.fromOffset(200, 180)
			expect(win1._instance.UISizeConstraint.MaxSize).toEqual(Vector2.new(180, 160))
			expect(win1.Size()).toEqual(UDim2.fromOffset(300, 300))
			win1._instance.Parent = UI.LayerDefault
			win1.Position(UDim2.fromOffset(100, 100))
			UI.flush()

			local win2 = UI.new "Window" {
				Parent = UI.LayerDefault,
				Title = "Win2",
				Position = UDim2.fromOffset(100, 100),
				Size = UDim2.fromOffset(300, 300),
				RemoveOnClose = true,
			}
			win2._instance.Visible = true
			-- Setting Visible = true nudges win2 and preserves the nudged Position on the instance synchronously
			expect(win2._instance.Position).never.toEqual(UDim2.fromOffset(100, 100))
			UI.Class.Window.bringToFront(win1)
			expect(win2.Position()).never.toEqual(UDim2.fromOffset(100, 100))

			local win3 = UI.new "Window" {
				Parent = UI.LayerDefault,
				Title = "Win3",
				Position = UDim2.fromOffset(100, 100),
				Size = UDim2.fromOffset(300, 300),
				Visible = true,
			}
			expect(win3._instance.Position).never.toEqual(UDim2.fromOffset(100, 100))
			win3:Destroy()

			-- Drag window via TitleBar (updates _instance.Position synchronously on InputChanged)
			local preDragPos = win1._instance.Position
			local winDrag = makeInput(env, {
				UserInputType = Enum.UserInputType.MouseButton1,
				UserInputState = Enum.UserInputState.Begin,
				Position = Vector3.new(150, 110, 0),
			})
			win1._instance.Frame.TitleBar.InputBegan:Fire(winDrag, false)
			UI.UserInputService.InputChanged:Fire(
				makeInput(
					env,
					{ UserInputType = Enum.UserInputType.MouseMovement, Position = Vector3.new(180, 140, 0) }
				)
			)
			expect(win1._instance.Position).never.toEqual(preDragPos)
			winDrag.UserInputState = Enum.UserInputState.End

			-- Hover & resize window at top-left corner of win1 (with MouseIconEnabled true)
			UI.UserInputService.MouseIconEnabled = true
			local wPos = win1._instance.AbsolutePosition
			UI.UserInputService.InputChanged:Fire(
				makeInput(
					env,
					{ UserInputType = Enum.UserInputType.MouseMovement, Position = Vector3.new(wPos.X, wPos.Y, 0) }
				)
			)
			expect(UI.UserInputService.MouseIconEnabled).toBe(false)
			expect(win1._instance.ResizeIcon.Visible).toBe(true)
			local winResize = makeInput(env, {
				UserInputType = Enum.UserInputType.MouseButton1,
				UserInputState = Enum.UserInputState.Begin,
				Position = Vector3.new(wPos.X, wPos.Y, 0),
			})
			UI.UserInputService.InputBegan:Fire(winResize, false)
			UI.UserInputService.InputChanged:Fire(makeInput(env, {
				UserInputType = Enum.UserInputType.MouseMovement,
				Position = Vector3.new(wPos.X - 10, wPos.Y - 10, 0),
			}))
			winResize.UserInputState = Enum.UserInputState.End
			UI.UserInputService.InputChanged:Fire(makeInput(env, {
				UserInputType = Enum.UserInputType.MouseMovement,
				Position = Vector3.new(wPos.X + 100, wPos.Y + 100, 0),
			}))
			expect(UI.UserInputService.MouseIconEnabled).toBe(true)

			-- AutomaticSize.Y window preserves auto-sized Y scale/offset and disables vertical resize
			local autoWin = UI.new "Window" {
				Parent = UI.LayerDefault,
				Title = "AutoWin",
				AutomaticSize = Enum.AutomaticSize.Y,
				Position = UDim2.fromOffset(50, 50),
				Size = UDim2.fromOffset(420, 0),
			}
			expect(autoWin._content.Size).toEqual(UDim2.fromScale(1, 0))
			expect(autoWin._instance.Frame.Size).toEqual(UDim2.fromScale(1, 0))
			expect(autoWin._content.UIFlexItem.FlexMode).toBe(Enum.UIFlexMode.None)
			autoWin._instance.Visible = true
			expect(autoWin._instance.Size).toEqual(UDim2.fromOffset(420, 0))
			-- Top edge hover does not trigger vertical resize on AutomaticSize.Y
			local awPos = autoWin._instance.AbsolutePosition
			UI.UserInputService.InputChanged:Fire(makeInput(env, {
				UserInputType = Enum.UserInputType.MouseMovement,
				Position = Vector3.new(awPos.X + 100, awPos.Y, 0),
			}))
			expect(autoWin._instance.ResizeIcon.Visible).toBe(false)
			-- Left edge hover still allows horizontal resize
			UI.UserInputService.InputChanged:Fire(makeInput(env, {
				UserInputType = Enum.UserInputType.MouseMovement,
				Position = Vector3.new(awPos.X, awPos.Y, 0),
			}))
			expect(autoWin._instance.ResizeIcon.Visible).toBe(true)
			expect(autoWin._instance.ResizeIcon.ImageRectOffset).toEqual(Vector2.new(48, 0))
			-- When AutomaticSize grows the window's AbsoluteSize past the bottom edge, Position re-clamps on-screen
			local parentHeight = UI.LayerDefault.AbsoluteSize.Y
			autoWin.Position(UDim2.fromOffset(50, parentHeight - 20))
			UI.flush()
			autoWin.Size(UDim2.fromOffset(420, 120))
			UI.flush()
			expect(autoWin._instance.Position.Y.Offset).toBe(math.max(0, parentHeight - 120))
			autoWin:Destroy()

			-- Exit buttons
			win1._exitButton._instance.Activated:Fire()
			expect(winClosed).toBe(true)
			win2._exitButton._instance.Activated:Fire()
			expect(win2._instance.Parent).toBeNil()
		end)
	end)

	describe("Part 3 · CompletionData & CommandBar", function()
		test(
			"CompletionData handles history, invalid strings, command suggestions, chaining, and argument completion",
			function()
				local world = sert.sim.new({ backing = true })
				local server = world:server()
				local client = server:client(1, "Player1")
				local cliMounted = setupClientEnv(client, { mockRemote = true })

				local _K = cliMounted:requireK()
				Harness.seedRoles(_K.Data)
				_K.Data.settings.prefix = { ";" }
				_K.Data.settings.splitKey = " "
				_K.client = {
					playerPrefix = _K.Flux.signal(";"),
					settings = {
						prefix = _K.Flux.signal({ ";" }),
						onlyShowUsableCommands = _K.Flux.signal(false),
					},
					hotkeys = {},
				}

				-- Authorize everyone commands, restrict ban initially
				for _, cmd in _K.Registry.commands do
					cmd.LocalPlayerAuthorized = _K.Auth.roleCanUseCommand("everyone", cmd)
					cmd.RestrictedToRole = _K.Data.roles.admin
				end
				if _K.Registry.commands.version then
					_K.Registry.commands.version.LocalPlayerAuthorized = true
				end
				if _K.Registry.commands.ban then
					_K.Registry.commands.ban.LocalPlayerAuthorized = false
					_K.Registry.commands.ban.RestrictedToRole = _K.Data.roles.admin
				end

				local CompletionData = cliMounted.env:require(cliMounted.Client.CommandBar.CompletionData)

				-- 1. Empty prefix -> History
				local dHist = CompletionData(_K, ";", 2)
				expect(dHist.suggestionType).toBe("History")
				expect(dHist.argPos).toBe(2)
				expect(dHist.argIndex).toBe(0)
				expect(dHist.rawArg).toBe("")
				expect(dHist.query).toBe("")

				-- 2. Invalid command string (`; `)
				local dInvalidStr = CompletionData(_K, "; ", 3)
				expect(#dInvalidStr.invalid > 0).toBe(true)
				expect(dInvalidStr.invalid[1][1]).toBe("Invalid command string")

				-- 3. Cursor within command name (`;ver` at pos 5) and mid-word (`;version` at pos 5) and exact command (`;version` at pos 9)
				local dCmd = CompletionData(_K, ";ver", 5)
				expect(dCmd.argIndex).toBe(1)
				expect(dCmd.argPos).toBe(2)
				expect(dCmd.rawArg).toBe("ver")
				expect(dCmd.query).toBe("ver")
				expect(dCmd.suggestionType).toBe(_K.Registry.types.command)
				expect(#dCmd.suggestions > 0).toBe(true)
				expect(dCmd.validSuggestion).toBe(true)
				expect(dCmd.commandDefinition).toBe(_K.Registry.commands.version)

				local dMidCmd = CompletionData(_K, ";version", 5)
				expect(dMidCmd.rawArg).toBe("version")
				expect(dMidCmd.query).toBe("ver")

				local dExactCmd = CompletionData(_K, ";version", 9)
				expect(dExactCmd.commandDefinition).toBe(_K.Registry.commands.version)
				expect(#dExactCmd.commands).toBe(1)
				expect(dExactCmd.commands[1].validated).toBe(true)

				-- 4. Restricted command when cursor is on command (with onlyShowUsableCommands false and true) or after command
				local dRestrIn = CompletionData(_K, ";ban", 5)
				expect(dRestrIn.argIndex).toBe(1)
				expect(dRestrIn.commandDefinition).toBe(_K.Registry.commands.ban)
				local foundInvalidSug = false
				for _, sug in dRestrIn.suggestions do
					if sug[4] == true then
						foundInvalidSug = true
					end
				end
				expect(foundInvalidSug).toBe(true)
				_K.client.settings.onlyShowUsableCommands(true)
				local dRestrHidden = CompletionData(_K, ";ban", 5)
				expect(#dRestrHidden.invalid > 0).toBe(true)
				_K.client.settings.onlyShowUsableCommands(false)

				local dRestrAfter = CompletionData(_K, ";ban ", 6)
				expect(#dRestrAfter.invalid > 0).toBe(true)
				expect(string.find(dRestrAfter.invalid[1][1], "restricted") ~= nil).toBe(true)

				-- Chained command where first command is restricted (`;ban ;ver`)
				local dChainRestr = CompletionData(_K, ";ban ;ver", 10)
				expect(#dChainRestr.invalid > 0).toBe(true)
				expect(#dChainRestr.commands).toBe(1)

				-- 5. Invalid command name outside (`;notacommand `) and inside args (`;notacommand arg1`)
				local dBadCmd = CompletionData(_K, ";notacommand ", 14)
				expect(#dBadCmd.invalid > 0).toBe(true)
				expect(string.find(dBadCmd.invalid[1][1], "did you mean") ~= nil).toBe(true)

				local dBadCmdInArgs = CompletionData(_K, ";notacommand arg1", 18)
				expect(#dBadCmdInArgs.invalid > 0).toBe(true)
				expect(string.find(dBadCmdInArgs.invalid[1][1], "did you mean") ~= nil).toBe(true)

				-- 6. Chained command where cursor is in second command (`;version ;ver`)
				local dChain = CompletionData(_K, ";version ;ver", 14)
				expect(#dChain.commands).toBe(1)
				expect(dChain.commands[1].validated).toBe(true)
				expect(dChain.argIndex).toBe(1)

				-- Chained command where first command is invalid (`;notacommand ;help`)
				local dChainBad = CompletionData(_K, ";notacommand ;help", 19)
				expect(dChainBad.argIndex).toBe(1)
				expect(dChainBad.argPos).toBe(2)
				expect(dChainBad.rawArg).toBe("notacommand")
				expect(dChainBad.query).toBe("notacommand")
				expect(#dChainBad.invalid > 0).toBe(true)

				-- 7. Grant creator role and authorize all commands to test argument completion
				_K.Auth.userRoleAdd(1, "creator")
				for _, cmd in _K.Registry.commands do
					cmd.LocalPlayerAuthorized = true
				end

				-- Chained command where first command is authorized but has an invalid arg (`;ban Player1 ;ver`)
				local dChainBadArg = CompletionData(_K, ";ban Player1 ;ver", 18)
				expect(#dChainBadArg.invalid > 0).toBe(true)

				-- Cursor on 1st arg, 2nd arg, 3rd (greedy string) arg of `;ban`
				local dArg1 = CompletionData(_K, ';ban "2"', 8)
				expect(dArg1.commandDefinition).toBe(_K.Registry.commands.ban)
				expect(#dArg1.commands).toBe(1)
				expect(dArg1.arg ~= nil).toBe(true)
				expect(dArg1.argIndex).toBe(2)
				expect(dArg1.argPos).toBe(6)
				expect(dArg1.rawArg).toBe('"2"')
				expect(dArg1.rawQuery).toBe('"2')
				expect(dArg1.query).toBe("2")
				expect(dArg1.argDefinition).toBe(_K.Registry.commands.ban.args[1])
				expect(dArg1.transformedArg).toBe("2")
				expect(dArg1.suggestionType).toBe(_K.Registry.types.userIds)
				expect(dArg1.suggestions ~= nil).toBe(true)

				-- Prefix arg (`@admin`) transforms to rolePlayers suggestionType
				local dPrefixArg = CompletionData(_K, ";ban @admin", 12)
				expect(dPrefixArg.argPos).toBe(6)
				expect(dPrefixArg.rawArg).toBe("@admin")
				expect(dPrefixArg.suggestionType).toBe(_K.Registry.types.rolePlayers)

				-- Listable arg with `,` delimiter
				local dArgList = CompletionData(_K, ';ban 2,"34"', 10)
				expect(dArgList.argIndex).toBe(2)
				expect(dArgList.argPos).toBe(8)
				expect(dArgList.rawArg).toBe('"34"')
				expect(dArgList.rawQuery).toBe('"3')
				expect(dArgList.query).toBe("3")
				expect(CompletionData(_K, ';ban 2,"34"', 7).rawArg).toBe("2")

				local dArg2 = CompletionData(_K, ";ban 2 10", 10)
				expect(dArg2.argIndex).toBe(3)
				expect(dArg2.argPos).toBe(8)
				expect(dArg2.rawArg).toBe("10")
				expect(CompletionData(_K, ';ban 2 "seconds"', 17).skipped).toBeNil()
				expect(#CompletionData(_K, ";ban ", 5).invalid).toBe(0)

				-- Skipped optional argument with suggestions (`;ban 2 "seconds"` with cursor inside skipped arg)
				local dSkipped = CompletionData(_K, ';ban 2 "seconds"', 10)
				expect(dSkipped.skipped).toBe(true)
				expect(dSkipped.rawQuery).toBe('"s')
				expect(dSkipped.query).toBe("s")
				expect(dSkipped.suggestions ~= nil and #dSkipped.suggestions > 0).toBe(true)
				expect(dSkipped.suggestions[1][1] ~= "0").toBe(true)

				local dArg3 = CompletionData(_K, ";ban 2 10m some reason here   ", 31)
				expect(dArg3.argIndex).toBe(4)
				expect(dArg3.rawArg).toBe("some reason here   ")

				-- Greedy chatString / stringGreedy commands (`;m h` and `;m he`) with legacy splitKey = "%s"
				_K.Data.settings.splitKey = "%s"
				local dMsgH = CompletionData(_K, ";m h", 5)
				expect(dMsgH.commandDefinition).toBe(_K.Registry.commands.message)
				expect(dMsgH.argIndex).toBe(2)
				expect(dMsgH.rawArg).toBe("h")
				expect(#dMsgH.invalid).toBe(0)
				local dMsgHe = CompletionData(_K, ";m he   ", 9)
				expect(dMsgHe.commandDefinition).toBe(_K.Registry.commands.message)
				expect(dMsgHe.argIndex).toBe(2)
				expect(dMsgHe.rawArg).toBe("he   ")
				expect(dMsgHe.suggestionType).toBe(_K.Registry.types.chatString)
				expect(#dMsgHe.invalid).toBe(0)
				_K.Data.settings.splitKey = " "

				-- Invalid argument value (targeting self when ignoreSelf = true)
				local dBadArg = CompletionData(_K, ";ban Player1 10m", 17)
				expect(#dBadArg.invalid > 0).toBe(true)
				expect(dBadArg.commands[1].Error ~= nil).toBe(true)

				-- Mid-token cursor slicing and empty rawArgs / nil suggestions / non-invalidArg command failure
				local dMidArg = CompletionData(_K, ';ban "2345" 10m', 8)
				expect(dMidArg.rawArg).toBe('"2345"')
				expect(dMidArg.rawQuery).toBe('"2')
				expect(dMidArg.query).toBe("2")

				local dMidSkip = CompletionData(_K, ';ban 2 "seconds"', 11)
				expect(dMidSkip.skipped).toBe(true)
				expect(dMidSkip.rawQuery).toBe('"se')
				expect(dMidSkip.query).toBe("se")

				_K.Registry.registerType("testnosuggest", {
					listable = false,
					validate = function()
						return true
					end,
					parse = function(v)
						return v
					end,
				})
				_K.Registry.registerCommand(_K, {
					name = "testcompedge",
					aliases = {},
					description = "Completion edge cases",
					group = "Utility",
					LocalPlayerAuthorized = true,
					args = {
						{ type = "testnosuggest", name = "NoSug", description = "NoSug", optional = true },
						{ type = "players", name = "Plr", description = "Plr" },
						{ type = "integer", name = "Num", description = "Num" },
					},
					runClient = function() end,
				})
				-- When shouldFillWithSelf fills "me" for arg 2 (players), arg.rawArg is "me" while arg.skipped is '"xyz"'
				local dSelfSkip = CompletionData(_K, ';testcompedge 1 "xyz" 5', 18)
				expect(dSelfSkip.skipped).toBe(true)
				expect(dSelfSkip.rawQuery).toBe('"')
				expect(dSelfSkip.query).toBe("")
				local origSplit = _K.Util.String.splitOutsideQuotes
				_K.Registry.types.testnosuggest.listable = true
				_K.Util.String.splitOutsideQuotes = function()
					return {}
				end
				local dNoRawArgs = CompletionData(_K, ';testcompedge "abc" 5', 18)
				expect(dNoRawArgs.argPos).toBe(15)
				expect(dNoRawArgs.rawArg).toBe('"abc"')
				expect(dNoRawArgs.rawQuery).toBe('"ab')
				expect(dNoRawArgs.query).toBe("ab")
				expect(dNoRawArgs.suggestionType).toBe(_K.Registry.types.testnosuggest)
				_K.Util.String.splitOutsideQuotes = origSplit
				_K.Registry.types.testnosuggest.listable = false

				-- Skipped arg when rawType.suggestions returns {} or is nil falls through to next arg without breaking
				_K.Registry.types.testnosuggest.validate = function()
					return false
				end
				_K.Registry.types.testnosuggest.suggestions = function()
					return {}
				end
				expect(CompletionData(_K, ';testcompedge "xyz" 42', 16).argIndex).toBe(3)
				_K.Registry.types.testnosuggest.suggestions = nil
				local dSkipNilSug = CompletionData(_K, ";testcompedge 42", 16)
				expect(dSkipNilSug.suggestions == nil or type(dSkipNilSug.suggestions) == "table").toBe(true)
				_K.Registry.types.testnosuggest.validate = function()
					return true
				end
			end
		)

		do
			local cbSut: any = nil
			local liveHistory: { string } = {}

			local function getOrCreateCommandBarSut()
				if cbSut and #cbSut.world.scheduler.errors == 0 then
					return cbSut
				end
				local world = sert.sim.new({ backing = true })
				local server = world:server()
				local client = server:client(1, "Player1")
				local cliMounted = setupClientEnv(client, { mockRemote = true })

				local _K = cliMounted:requireK()
				Harness.seedRoles(_K.Data)
				_K.Data.settings.prefix = { ";" }
				_K.Data.settings.splitKey = " "
				_K.Auth.userRoleAdd(1, "admin")

				local UI = cliMounted.env:require(cliMounted.Client.UI)
				if UI.registerClasses then
					UI.registerClasses()
				end
				_K.UI = UI
				_K.IsClient = true
				_K.LocalPlayer = cliMounted.env.Players.LocalPlayer
				_K.Notify = function() end
				_K.client = {
					rank = _K.Flux.signal(3),
					commandBarEnabled = true,
					dashboardButtonEnabled = true,
					dashboardButton = { Visible = true },
					playerPrefix = _K.Flux.signal(";"),
					settings = {
						prefix = _K.Flux.signal({ ";" }),
						onlyShowUsableCommands = _K.Flux.signal(false),
					},
					hotkeys = {},
				}

				for _, extraName in { "testalpha", "testbeta" } do
					_K.Registry.registerCommand(_K, {
						name = extraName,
						aliases = {},
						description = `Test command {extraName}`,
						group = "Utility",
						args = {},
						runClient = function() end,
					})
				end

				for _, cmd in _K.Registry.commands do
					cmd.LocalPlayerAuthorized = _K.Auth.roleCanUseCommand("admin", cmd)
						or _K.Auth.roleCanUseCommand("mod", cmd)
						or _K.Auth.roleCanUseCommand("everyone", cmd)
					cmd.RestrictedToRole = _K.Data.roles.superadmin
				end
				for _, name in { "version", "help", "cmds", "fly", "ban", "testalpha", "testbeta" } do
					if _K.Registry.commands[name] then
						_K.Registry.commands[name].LocalPlayerAuthorized = true
					end
				end
				if _K.Registry.commands.shutdown then
					_K.Registry.commands.shutdown.LocalPlayerAuthorized = false
					_K.Registry.commands.shutdown.RestrictedToRole = _K.Data.roles.superadmin
				end

				local CompletionData = cliMounted.env:require(cliMounted.Client.CommandBar.CompletionData)
				local CommandBar = cliMounted.env:require(cliMounted.Client.CommandBar)
				CommandBar:init(_K)
				world:run(0.1)

				table.clear(liveHistory)
				cbSut = {
					world = world,
					env = cliMounted.env,
					_K = _K,
					UI = UI,
					CompletionData = CompletionData,
					CommandBar = CommandBar,
				}
				return cbSut
			end

			local TOKEN_INPUTS = {
				";",
				";ver",
				";version",
				";help",
				";testalpha",
				";testbeta",
				";fly",
				";fly me",
				";ban 2 10m reason",
				";version ;help",
				";shutdown",
				";notacommand ",
			}
			local EXECUTABLE_INPUTS = {
				";version",
				";help",
				";testalpha",
				";testbeta",
				";notacommand ",
				";",
			}

			sert.model("CommandBar & CompletionData Autocomplete and History State Machine", {
				init = function()
					local sut = getOrCreateCommandBarSut()
					local input = sut.CommandBar.Input
					input._input.SelectionStart = -1
					input:SetValue(";")
					input._input.CursorPosition = 2
					sut.CommandBar.updateCompletionData()
					sut.world:step()
					return {
						prefix = ";",
						text = ";",
						cursor = 2,
						suggestionIndex = 1,
						history = table.clone(liveHistory),
					},
						sut
				end,
				commands = {
					TypeToken = {
						gen = function(g)
							return g:pick(TOKEN_INPUTS)
						end,
						run = function(sut, text)
							local input = sut.CommandBar.Input
							input._input.SelectionStart = -1
							input:SetValue(text)
							input._input.CursorPosition = #text + 1
							sut.CommandBar.updateCompletionData()
							sut.world:step()
						end,
						next = function(state, text)
							state.text = text
							state.cursor = #text + 1
							state.suggestionIndex = 1
							return state
						end,
					},
					MoveCursor = {
						gen = function(g, state)
							return g:int(1, #state.text + 1)
						end,
						run = function(sut, pos)
							local input = sut.CommandBar.Input
							input._input.SelectionStart = -1
							input._input.CursorPosition = pos
							sut.CommandBar.updateCompletionData()
							sut.world:step()
						end,
						next = function(state, pos)
							state.cursor = math.max(#state.prefix + 1, pos)
							state.suggestionIndex = 1
							return state
						end,
					},
					CycleSuggestion = {
						gen = function(g)
							return {
								dir = g:pick({ "Up", "Down" }),
								steps = g:int(1, 3),
							}
						end,
						run = function(sut, arg)
							local input = sut.CommandBar.Input
							input._input:CaptureFocus()
							local keyCode = if arg.dir == "Up" then Enum.KeyCode.Up else Enum.KeyCode.Down
							for _ = 1, arg.steps do
								sut.UI.UserInputService.InputBegan:Fire(
									makeInput(
										sut.env,
										{ UserInputType = Enum.UserInputType.Keyboard, KeyCode = keyCode }
									),
									false
								)
							end
							sut.world:step()
						end,
						next = function(state, arg)
							local sut = getOrCreateCommandBarSut()
							local isHistory = (state.text == state.prefix)
							local count = 1
							if isHistory then
								count = math.max(1, #state.history)
							else
								local d = sut.CompletionData(sut._K, state.text, state.cursor)
								count = math.max(1, if d.suggestions then #d.suggestions else 1)
							end
							for _ = 1, arg.steps do
								if isHistory then
									if arg.dir == "Up" then
										state.suggestionIndex = math.min(count, state.suggestionIndex + 1)
									else
										state.suggestionIndex = math.max(1, state.suggestionIndex - 1)
									end
								else
									if arg.dir == "Up" then
										state.suggestionIndex = math.max(1, state.suggestionIndex - 1)
									else
										state.suggestionIndex = math.min(count, state.suggestionIndex + 1)
									end
								end
							end
							return state
						end,
					},
					NavigateHistory = {
						gen = function(g)
							return g:int(0, 3)
						end,
						run = function(sut, upSteps)
							local input = sut.CommandBar.Input
							input._input.SelectionStart = -1
							input:SetValue(";")
							input._input.CursorPosition = 2
							input._input:CaptureFocus()
							sut.world:step()
							sut.CommandBar.updateCompletionData()
							for _ = 1, upSteps do
								sut.UI.UserInputService.InputBegan:Fire(
									makeInput(
										sut.env,
										{ UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.Up }
									),
									false
								)
							end
							sut.world:step()
						end,
						next = function(state, upSteps)
							state.text = state.prefix
							state.cursor = 2
							state.suggestionIndex = 1
							local count = math.max(1, #state.history)
							for _ = 1, upSteps do
								state.suggestionIndex = math.min(count, state.suggestionIndex + 1)
							end
							return state
						end,
					},
					ExecuteCommand = {
						gen = function(g)
							return g:pick(EXECUTABLE_INPUTS)
						end,
						run = function(sut, cmdText)
							local input = sut.CommandBar.Input
							input._input.SelectionStart = -1
							input._input:ReleaseFocus()
							input:SetValue(cmdText)
							input._input.CursorPosition = #cmdText + 1
							sut.CommandBar.updateCompletionData()
							input._input.FocusLost:Fire(true)
							sut.world:step()
							input._input.SelectionStart = -1
							input._input.CursorPosition = #input._input.Text + 1
							sut.CommandBar.updateCompletionData()
							sut.world:step()
						end,
						next = function(state, cmdText)
							local sut = getOrCreateCommandBarSut()
							local d = sut.CompletionData(sut._K, cmdText, #cmdText + 1)
							local hasInvalidArg = false
							for _, cmd in d.commands do
								if cmd.invalidArg then
									hasInvalidArg = true
									break
								end
							end
							if #d.invalid > 0 or (cmdText ~= state.prefix and #d.commands < 1) or hasInvalidArg then
								local trimmedInvalid = sut._K.Util.String.trimEnd(cmdText)
								state.text = trimmedInvalid
								state.cursor = #trimmedInvalid + 1
								state.suggestionIndex = 1
								return state
							end
							if cmdText ~= state.prefix then
								local trimmed = sut._K.Util.String.trimEnd(cmdText)
								local entry = string.sub(trimmed, 2)
								for _, hist in { state.history, liveHistory } do
									local idx = table.find(hist, entry)
									if idx ~= 1 then
										if idx then
											table.remove(hist, idx)
										end
										table.insert(hist, 1, entry)
										if #hist > 32 then
											table.remove(hist)
										end
									end
								end
							end
							state.text = state.prefix
							state.cursor = 2
							state.suggestionIndex = 1
							return state
						end,
					},
				},
				invariant = function(state, sut)
					expect(sut.world.scheduler.errors).toEqual({})
					local input = sut.CommandBar.Input
					expect(input._input.Text).toBe(state.text)
					expect(input._input.CursorPosition).toBe(state.cursor)
					expect(input._input.CursorPosition >= #state.prefix + 1).toBe(true)

					local d = sut.CompletionData(sut._K, state.text, state.cursor)
					if state.text == state.prefix then
						expect(d.suggestionType).toBe("History")
						expect(d.argIndex).toBe(0)
						expect(d.argPos).toBe(2)
						if #state.history > 0 then
							local expectedCmd = state.history[state.suggestionIndex]
							local display = input.DisplayText:peek()
							expect(string.find(display, expectedCmd, 1, true) ~= nil).toBe(true)
						end
					else
						local validSignal = sut._K.client.CommandBarState[1]:peek()
						if #d.invalid > 0 then
							expect(validSignal).toBe(false)
						end
					end
				end,
			}, { runs = 12, length = 12 })
		end
	end)

	describe(
		"Part 4 · Full Client Initialization, CommandBar, Dashboard Tabs, Network, Notify, Character & Explorer",
		function()
			local function makeFastRun(world: any)
				return function(seconds: number)
					local dt = 1 / 60
					if seconds <= dt * 3 then
						world:run(seconds)
					else
						world:step(dt)
						world:step(seconds - dt * 2)
						world:step(dt)
					end
				end
			end

			test("initializes full Server + Client pair, Theme, UserFrame, Notify, Announce, and CommandBar", function()
				local world, _srvMounted, cliMounted, _sK, cK = getOrCreateFullClientSut()
				local fastRun = makeFastRun(world)

				expect(cK.ready).toBe(true)
				expect(cK.client.dashboard ~= nil).toBe(true)
				expect(cK.client.CommandBar ~= nil).toBe(true)

				local UI = cK.UI
				local cEnv = cliMounted.env

				-- 1. UI.changeTheme
				if UI.Themes.Default then
					UI.changeTheme(UI.Themes.Default)
				end

				-- 2. UserFrame variations
				local uf1 = cK.client.UserFrame(1, "CustomDisplay")
				expect(uf1.Name).toBe("Header")
				local ufK = cK.client.UserFrame("_K")
				expect(ufK.Name).toBe("Header")
				local ufCustom = cK.client.UserFrame("SystemSender", nil, "rbxassetid://12345", false)
				expect(ufCustom.Name).toBe("Header")
				local ufBadge = cK.client.UserFrame(1, nil, nil, true)
				expect(ufBadge.Name).toBe("Header")
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
				expect(nDialog ~= nil).toBe(true)
				expect(nDialog._content.Header.LayoutOrder).toBe(-3)
				expect(nDialog._content.Header.LayoutOrder < nDialog._content.Title.LayoutOrder).toBe(true)
				expect(nDialog._content.Title.LayoutOrder < nDialog._content.Text.LayoutOrder).toBe(true)
				nDialog._instance.Activated:Fire()
				fastRun(0.2)
				expect(notifActivated).toBe(true)
				expect(notifClosed).toBe(true)

				local aDialog = cK.Announce({
					Text = "Pinned Announcement",
					From = "_K",
					Duration = 2,
				})
				expect(aDialog ~= nil).toBe(true)
				aDialog._exitButton._instance.Activated:Fire()
				fastRun(0.2)

				-- 4. CommandBar interactions & rich suggestion types
				local CommandBar = cK.client.CommandBar
				CommandBar.show()
				fastRun(0.2)
				expect(CommandBar.Bar.Visible).toBe(true)

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
				expect(string.sub(CommandBar.Input._input.Text, 1, 1)).toBe(";")

				CommandBar.Input._input.Text = ";;help"
				CommandBar.Input._input.CursorPosition = 7
				fastRun(0.2)
				expect(CommandBar.Input._input.Text).toBe(";help")

				-- SelectionStart ~= -1 and CursorPosition < prefixPosition clamping
				CommandBar.Input._input.SelectionStart = 2
				CommandBar.Input._input.CursorPosition = 1
				fastRun(0.1)
				CommandBar.Input._input.SelectionStart = -1
				CommandBar.Input._input.CursorPosition = 1
				fastRun(0.1)
				expect(CommandBar.Input._input.CursorPosition >= 2).toBe(true)

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
					expect(CommandBar.Input._input.Text).toBe(";")
					expect(CommandBar.Input.Value()).toBe(";")
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
				expect(CommandBar.Bar.Visible).toBe(false)
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
				sK.Remote.Servers:Fire(srvPlayer, "job_abc123", { 12345, 4, os.time() - 60 })
				sK.Remote.Servers:Fire(srvPlayer, nil, {
					job_abc123 = { 12345, 4, os.time() - 60 },
					job_def456 = { 12345, 8, os.time() - 120 },
					job_ghi789 = { 67890, 2, os.time() - 30 },
				})
				fastRun(1)

				expect(cK.Data.bans["202"] ~= nil).toBe(true)
				expect(cK.Data.bans["404"] ~= nil).toBe(true)
				expect(cK.Data.members["707"] ~= nil).toBe(true)
				expect(cK.Data.members["808"] ~= nil).toBe(true)
				expect(cK.Data.servers["job_abc123"] ~= nil).toBe(true)
				expect(cK.Data.servers["job_ghi789"] ~= nil).toBe(true)

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
				-- chat text is neither parsed nor logged on the client, platform-integrated chat hides it
				local tcs = cEnv.game:GetService("TextChatService")
				local logCount = #cK.Data.logs
				tcs.SendingMessage:Fire({ Text = ";version" })
				tcs.MessageReceived:Fire({
					TextSource = { UserId = 1 },
					Text = "Hello chat",
				})
				fastRun(0.1)
				expect(#cK.Data.logs).toBe(logCount)
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
				expect(reqResult).toBe(true)

				-- Verify RequestCommand.OnInvoke accepts a numeric userId (from cross-server ;global request)
				local reqThread = client:spawn(function()
					return cK.Remote.RequestCommand.OnInvoke(101, ";kill Target")
				end)
				fastRun(0.1)
				expect(coroutine.status(reqThread)).toBe("suspended")
				client:spawn(function()
					coroutine.close(reqThread)
				end)

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
				expect(errorLogs()).toBe(errorsBefore)
				sK.Remote.Command:Fire(srvPlayer, ";nosuchcommand")
				fastRun(0.3)
				expect(errorLogs()).toBe(errorsBefore + 1)

				-- chat commands missing required arguments open CommandBar pre-filled with trailing space for argument autocomplete
				cK.client.CommandBar.hide()
				fastRun(0.1)
				expect(cK.client.CommandBar.Bar.Visible).toBe(false)
				sK.Remote.Command:Fire(srvPlayer, ";ban", true)
				fastRun(0.3)
				expect(cK.client.CommandBar.Bar.Visible).toBe(true)
				expect(cK.client.CommandBar.Input._input.Text).toBe(";ban ")
				expect(cK.client.CommandBar.Input._input.CursorPosition).toBe(6)
				cK.client.CommandBar.hide()
				fastRun(0.1)

				-- kick (ignoreSelf first player arg) with no args also opens CommandBar pre-filled
				sK.Remote.Command:Fire(srvPlayer, ";kick", true)
				fastRun(0.3)
				expect(cK.client.CommandBar.Bar.Visible).toBe(true)
				expect(cK.client.CommandBar.Input._input.Text).toBe(";kick ")
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
				expect(dash.Commands._instance.Visible).toBe(true)
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
					expect(next(tab._lineItemCache) ~= nil).toBe(true)
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
				expect(emptyBanBtn ~= nil).toBe(true)
				expect(emptyBanBtn.LayoutOrder).toBe(1)
				expect(dash.Bans._scroller.LayoutOrder).toBe(2)
				expect(emptyBanBtn.LayoutOrder < dash.Bans._scroller.LayoutOrder).toBe(true)

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
					expect(banDialog ~= nil).toBe(true)
					local banAvatar, banBox, banButton = dialogParts(banDialog, "Ban")
					expect(banAvatar ~= nil and banBox ~= nil and banButton ~= nil).toBe(true)
					local bansFired = {}
					local origBanFire = cK.Remote.Ban.Fire
					cK.Remote.Ban.Fire = function(_self, userId)
						table.insert(bansFired, userId)
					end

					enter(banBox, "707")
					fastRun(0.1)
					expect(targetId(banAvatar)).toBe("707")

					enter(banBox, "BannedBob")
					fastRun(0.1)
					expect(targetId(banAvatar)).toBe("nil")
					banButton.Activated:Fire()
					expect(#bansFired).toBe(0)

					-- AdminAlice resolves first, then the slower BannedBob lookup is dropped
					enter(banBox, "AdminAlice")
					fastRun(0.1)
					expect(targetId(banAvatar)).toBe("nil")
					fastRun(0.1)
					expect(targetId(banAvatar)).toBe("505")
					fastRun(0.2)
					expect(targetId(banAvatar)).toBe("505")
					banButton.Activated:Fire()
					expect(bansFired).toEqual({ 505 })
					cK.Remote.Ban.Fire = origBanFire

					-- Members role dialog
					local roleDialog = findDialog({ "Add Role" })
					expect(roleDialog ~= nil).toBe(true)
					local roleAvatar, roleBox, confirmButton = dialogParts(roleDialog, "Confirm")
					expect(roleAvatar ~= nil and roleBox ~= nil and confirmButton ~= nil).toBe(true)
					local commandsRun = {}
					local origRunCommands = cK.Process.runCommands
					cK.Process.runCommands = function(_K, _from, cmd)
						table.insert(commandsRun, cmd)
					end

					enter(roleBox, "707")
					fastRun(0.1)
					expect(targetId(roleAvatar)).toBe("707")

					enter(roleBox, "BannedBob")
					fastRun(0.1)
					expect(targetId(roleAvatar)).toBe("nil")
					confirmButton.Activated:Fire()
					expect(#commandsRun).toBe(0)

					enter(roleBox, "AdminAlice")
					fastRun(0.1)
					expect(targetId(roleAvatar)).toBe("nil")
					fastRun(0.1)
					expect(targetId(roleAvatar)).toBe("505")
					fastRun(0.2)
					expect(targetId(roleAvatar)).toBe("505")
					confirmButton.Activated:Fire()
					expect(#commandsRun).toBe(1)
					expect(string.find(commandsRun[1], "role 505 ", 1, true) ~= nil).toBe(true)
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
					expect(next(tab._lineItemCache) ~= nil).toBe(true)
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
				-- chat logs have no filter and never show, even old saved ones
				expect(dash.Logs.logTypeFilter.CHAT).toBeNil()
				table.insert(
					cK.Data.logs,
					{ "Legacy chat line", cK.Logger:encode("CHAT"), os.time(), 1, "Player1", false }
				)
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
					expect(pingCmd ~= nil and pingCmd.AutocompleteVisible).toBe(true)
					local pingCmd2 = clientCmdFolder:FindFirstChild("ping2")
					if pingCmd2 then
						expect(pingCmd2.AutocompleteVisible).toBe(false)
					end
				end
				cK.client.settings.chatCommands(false)
				cK.Data.settings.chatCommands = false
				fastRun(0.25)
				if clientCmdFolder then
					local pingCmd = clientCmdFolder:FindFirstChild("ping")
					expect(pingCmd ~= nil and pingCmd.AutocompleteVisible).toBe(false)
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
				expect(emptyServersLabel ~= nil).toBe(true)
				expect(emptyServersLabel.LayoutOrder).toBe(1)
				expect(dash.Servers._scroller.LayoutOrder).toBe(2)
				expect(emptyServersLabel.LayoutOrder < dash.Servers._scroller.LayoutOrder).toBe(true)
				expect(dash.Logs._input._instance.LayoutOrder).toBe(-1)
				expect(dash.Members._input._instance.LayoutOrder).toBe(-1)
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
					expect(ids(Order.active(fixturePeople, fixtureData))).toEqual({ 3, 5, 14, 2, 16 })
					expect(ids(Order.plain(fixturePeople, fixtureData))).toEqual({
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
					expect(ids(Order.active(tiePeople, tieData))).toEqual({ 10, 20, 30 })

					-- Generated data invariants + luv2trilogy (3727541395)
					local activeList = Order.active(Credits.people)
					local plainList = Order.plain(Credits.people)
					expect(#activeList + #plainList).toBe(#Credits.people)
					expect(Credits.specialThanks.Id).toBe(16)
					local foundLuv2 = false
					for _, person in Credits.people do
						expect(Contributions.names[person.Id] ~= nil).toBe(true)
						expect(person.Id ~= 16).toBe(true)
						if person.Id == 3727541395 then
							foundLuv2 = true
							expect(person.GitHub).toBe("luv2trilogy")
						end
					end
					expect(foundLuv2).toBe(true)

					local creditsFrame = dash.About._instance:FindFirstChild("Credits", true)
					expect(creditsFrame ~= nil).toBe(true)
					expect(creditsFrame:FindFirstChild("Active contributors") ~= nil).toBe(true)
					expect(creditsFrame:FindFirstChild("Contributors") ~= nil).toBe(true)
					expect(creditsFrame:FindFirstChild("Special Thanks") ~= nil).toBe(true)
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
					expect(rootPart.CanCollide).toBe(false)
					Character.noclip(false)
					expect(rootPart.CanCollide).toBe(true)

					Character.fly(true, true)
					expect(hum.PlatformStand).toBe(true)
					hum.Jump = true
					hum.MoveDirection = Vector3.new(1, 0, 0)
					fastRun(0.2)
					hum.Jump = false
					hum.MoveDirection = Vector3.zero
					fastRun(0.2)
					Character.fly(false)
					expect(hum.PlatformStand).toBe(false)

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
					expect(hum.PlatformStand).toBe(true)
					hum.StateChanged:Fire(Enum.HumanoidStateType.Freefall, Enum.HumanoidStateType.Landed)
					-- Double-tap JumpRequest (< 0.4s since lastJump in tick()) stops fly & noclip
					UI.UserInputService.JumpRequest:Fire()
					expect(hum.PlatformStand).toBe(false)
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
					expect(expWin ~= nil).toBe(true)
					local expScrollerFrame = expWin:FindFirstChild("UIContent", true)
						and expWin.Frame.UIContent:FindFirstChild("ScrollerFast")
					expect(expScrollerFrame ~= nil).toBe(true)

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
					expect(#renderedBtns > 0).toBe(true)
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

describe("Client and UI · Tabs, Dashboard & UI.edit regressions", function()
	local function newClientUI()
		local world = sert.sim.new({ backing = true })
		local server = world:server()
		local client = server:client(1, "Player1")
		local cliMounted = setupClientEnv(client)
		local UI = cliMounted.env:require(cliMounted.Client.UI)
		if UI.registerClasses then
			UI.registerClasses()
		end
		return world, cliMounted.env, UI
	end

	test("Tabs snaps CanvasPosition when a resize clamps it, but still animates scrolling", function()
		local world, env, UI = newClientUI()
		local page1 = UI.new "Frame" { Name = "Page1" }
		local page2 = UI.new "Frame" { Name = "Page2" }
		local tabsComp = UI.new "Tabs" {
			Parent = UI.LayerDefault,
			CurrentPage = page1,
			Tabs = { { page1 }, { page2 } },
		}
		local barTabs = tabsComp._instance.Bar.Tabs
		world:run(0.5)
		env:setAbsolute(tabsComp._instance, Vector2.new(100, 30), Vector2.new(0, 0))
		env:setAbsolute(barTabs, Vector2.new(100, 30), Vector2.new(0, 0))
		env:setAbsolute(barTabs:FindFirstChild("Page1"), Vector2.new(40, 24), Vector2.new(0, 0))
		env:setAbsolute(barTabs:FindFirstChild("Page2"), Vector2.new(40, 24), Vector2.new(150, 0))
		world:run(0.5)
		expect(barTabs.CanvasPosition.X).toBe(0)

		-- a mousewheel scroll eases toward the next tab over several frames (the first frame only retargets)
		barTabs.MouseWheelBackward:Fire()
		world:step()
		world:step()
		local scrolling = barTabs.CanvasPosition.X
		sert(scrolling > 0 and scrolling < 150, `scroll animates, CanvasPosition.X = {scrolling}`)

		-- shrinking the bar mid-scroll clamps the offset and lands there on the next frame instead of easing behind
		env:setAbsolute(barTabs, Vector2.new(90, 30))
		world:step()
		world:step()
		local snapped = barTabs.CanvasPosition.X
		world:run(1)
		expect(barTabs.CanvasPosition.X).toBe(snapped)

		-- the next scroll animates again
		env:setAbsolute(barTabs:FindFirstChild("Page2"), Vector2.new(40, 24), Vector2.new(snapped + 60, 0))
		barTabs.MouseWheelBackward:Fire()
		world:step()
		world:step()
		local resumed = barTabs.CanvasPosition.X
		sert(resumed ~= snapped, "scrolling after a resize moves the canvas")
		world:run(1)
		sert(barTabs.CanvasPosition.X ~= resumed, `scrolling after a resize animates, stuck at {resumed}`)
		tabsComp:Destroy()
	end)

	test("Dashboard ping color walks the Oklab hue from Valid through yellow to Invalid", function()
		local world, _srvMounted, cliMounted, _sK, cK = getOrCreateFullClientSut()
		expect(cK.ready).toBe(true)

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
		local label = sharedFullPingLabel
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
	end)

	test("UI.edit leaves a Find selection passed as a child untouched", function()
		local world, _, UI = newClientUI()
		local host = UI.new "Frame" {
			Parent = UI.LayerDefault,
			UI.new "Frame" { Name = "Inner" },
		}
		local selection = UI.Find.Child("Inner")({ Name = "Renamed" })
		UI.edit(host)({ selection })
		UI.flush()
		world:step()
		expect(host:FindFirstChild("Renamed") ~= nil).toBe(true)

		-- the selection's own children are not unwrapped in place (Flux may reject them; only the rewrite matters)
		local marker = { _instance = UI.new "Frame" { Name = "Marker" } }
		local props = { marker }
		local nested = UI.Find.Child("Renamed")(props)
		pcall(UI.edit(host), { nested })
		expect(nested[1]).toBe(selection[1])
		expect(nested[3]).toBe(props)
		expect(props[1]).toBe(marker)
		host:Destroy()
	end)
end)

describe("Client and UI · motion nodes die with their component", function()
	-- A tween/spring passed straight to a property is only bound, not owned (Flux owns getter functions, not motion
	-- nodes), and a class constructor runs with no owner. A leaked motion keeps its driving effect subscribed to the
	-- theme forever, so the observer count of a theme signal it reads must return to its baseline after Destroy. A nil
	-- guard inside the getter would hide the error but leave the effect subscribed, and still fails this.
	local function observers(sig: any): number
		-- a Flux signal is { inner }, and inner[2] counts the nodes observing it
		local inner: any = rawget(sig, 1)
		return inner[2]
	end

	local function newClientUI()
		local world = sert.sim.new({ backing = true })
		local server = world:server()
		local client = server:client(1, "Player1")
		local cliMounted = setupClientEnv(client)
		local UI = cliMounted.env:require(cliMounted.Client.UI)
		if UI.registerClasses then
			UI.registerClasses()
		end
		return world, UI
	end

	local cases: { { name: string, build: (UI: any) -> any, poke: ((comp: any, UI: any) -> ())? } } = {
		{
			name = "List",
			build = function(UI)
				return UI.new "List" {
					Parent = UI.LayerDefault,
					Label = "Section",
					Collapsible = true,
					UI.new "ListItem" { Text = "Row" },
				}
			end,
			poke = function(comp)
				comp._instance.Header.Activated:Fire()
			end,
		},
		{
			name = "Switch",
			build = function(UI)
				return UI.new "Switch" { Parent = UI.LayerDefault }
			end,
			poke = function(comp)
				comp._instance.Activated:Fire()
			end,
		},
		{
			name = "Checkbox",
			build = function(UI)
				return UI.new "Checkbox" { Parent = UI.LayerDefault }
			end,
			poke = function(comp)
				comp._instance.Activated:Fire()
			end,
		},
		{
			name = "Slider",
			build = function(UI)
				return UI.new "Slider" { Parent = UI.LayerDefault, Snap = 5, Value = 2 }
			end,
		},
		{
			name = "ColorPicker",
			build = function(UI)
				return UI.new "ColorPicker" { Parent = UI.LayerDefault, Value = Color3.new(0, 1, 0) }
			end,
		},
		{
			name = "Tabs",
			build = function(UI)
				local page1 = UI.new "Frame" { Name = "Page1" }
				local page2 = UI.new "Frame" { Name = "Page2" }
				return UI.new "Tabs" {
					Parent = UI.LayerDefault,
					CurrentPage = page1,
					Tabs = { { page1 }, { page2 } },
				}
			end,
			poke = function(comp)
				comp._instance.Bar.Tabs:FindFirstChild("Page2").Activated:Fire()
			end,
		},
	}

	for _, case in cases do
		test(`{case.name} releases its tweens on Destroy`, function()
			local world, UI = newClientUI()
			world:run(0.5)
			UI.flush()
			local baseline = observers(UI.Theme.TweenOut)

			local comp = case.build(UI)
			UI.flush()
			world:run(0.1)
			if case.poke then
				case.poke(comp, UI)
				UI.flush()
				world:run(0.5)
			end
			local alive = observers(UI.Theme.TweenOut)
			sert(alive > baseline, `{case.name} tweens read Theme.TweenOut while alive ({alive} vs {baseline})`)

			comp:Destroy()
			UI.flush()
			world:step()
			-- a theme change after Destroy would re-run any leaked effect against the destroyed instance
			UI.Theme.TweenOut(UI.Theme.TweenOut:peek(), true)
			UI.Theme.FontSize(UI.Theme.FontSize:peek() + 1)
			UI.flush()
			world:run(0.5)
			expect(observers(UI.Theme.TweenOut)).toBe(baseline)
		end)
	end

	test("a notification keeps its spring through the hide animation and releases it with the card", function()
		local world = sert.sim.new({ backing = true })
		local server = world:server()
		local client = server:client(1, "Player1")
		local cliMounted = setupClientEnv(client, { mockRemote = true })
		local cK = cliMounted:requireK()
		Harness.seedRoles(cK.Data)
		local UI = cliMounted.env:require(cliMounted.Client.UI)
		if UI.registerClasses then
			UI.registerClasses()
		end
		cK.UI = UI
		cK.IsClient = true
		cK.LocalPlayer = cliMounted.env.Players.LocalPlayer
		cK.client = {
			rank = cK.Flux.signal(0),
			UserFrame = cliMounted.env:require(cliMounted.Client.UserFrame),
		}
		cK.Notify = cliMounted.env:require(cliMounted.Client.Notify)

		world:run(0.2)
		UI.flush()
		local baseline = observers(UI.Theme.Padding)

		local dialog = cK.Notify({ Text = "leak check" })
		local card = dialog._instance
		world:run(0.5)
		UI.flush()
		local alive = observers(UI.Theme.Padding)
		sert(alive > baseline, `the notification reads Theme.Padding while shown ({alive} vs {baseline})`)

		-- Duration is 4 + 0.0625 * #Text (4.625 s); just after it the card is hidden but still animating out
		world:run(4.35)
		UI.flush()
		sert(card.Parent ~= nil, "the card is still mounted during its hide animation")
		local beforeDestroy = card.Position
		world:step()
		world:step()
		sert(card.Position ~= beforeDestroy, "the hide animation is still moving the card")
		sert(observers(UI.Theme.Padding) > baseline, "the spring is not released before the hide animation ends")

		world:run(2)
		UI.flush()
		expect(card.Parent).toBe(nil)
		UI.Theme.Padding(UDim.new(0, UI.Theme.Padding:peek().Offset + 1))
		UI.flush()
		world:run(0.5)
		expect(observers(UI.Theme.Padding)).toBe(baseline)

		-- Verify UserFrame system notification (from = nil) does not leak Theme observers after Destroy
		local fontBaseline = observers(UI.Theme.Font)
		local sysHeader = cK.client.UserFrame(nil, "System")
		UI.flush()
		sysHeader:Destroy()
		UI.flush()
		expect(observers(UI.Theme.Font)).toBe(fontBaseline)

		-- Verify Tooltip.Cache clears adornee on adornee change and tooltip destroy
		local adornee1 = cliMounted.env.Instance.new("TextButton")
		local adornee2 = cliMounted.env.Instance.new("TextButton")
		local tip = UI.new "Tooltip" { Parent = adornee1, Text = "Tip" }
		UI.flush()
		expect(UI.Class.Tooltip.Cache[adornee1]).toBe(tip)
		tip._instance.Parent = adornee2
		UI.flush()
		expect(UI.Class.Tooltip.Cache[adornee1]).toBeNil()
		expect(UI.Class.Tooltip.Cache[adornee2]).toBe(tip)
		tip:Destroy()
		UI.flush()
		expect(UI.Class.Tooltip.Cache[adornee2]).toBeNil()
		adornee1:Destroy()
		adornee2:Destroy()
	end)

	do
		local ExplorerOrder: any
		local explorerClasses: { string }
		local function getExplorerOrder()
			if not ExplorerOrder then
				local h = Harness.shared()
				ExplorerOrder = h.env:require(h.Client:WaitForChild("Explorer"):WaitForChild("ExplorerOrder"))
				explorerClasses = {}
				for className in ExplorerOrder do
					table.insert(explorerClasses, className)
				end
				table.sort(explorerClasses)
			end
			return ExplorerOrder, explorerClasses
		end

		sert.laws.order("ExplorerOrder · sortChildren", {
			gen = function(g)
				local _, classes = getExplorerOrder()
				return {
					ClassName = g:pick(classes),
					Name = sert.gen.string("abcd", 1, 4)(g),
				}
			end,
			lt = function(a, b)
				local orderMap = getExplorerOrder()
				local orderA = orderMap[a.ClassName]
				local orderB = orderMap[b.ClassName]
				if orderA and orderB and orderA ~= orderB then
					return orderA < orderB
				end
				if a.ClassName == b.ClassName then
					return a.Name < b.Name
				end
				return a.ClassName < b.ClassName
			end,
		})
	end

	do
		sert.laws.ui("UI Components · Multi-Viewport Responsive Layout Audit", {
			viewports = {
				{ name = "Phone", size = Vector2.new(390, 844) },
				{ name = "Tablet", size = Vector2.new(820, 1180) },
				{ name = "Desktop", size = Vector2.new(1920, 1080) },
				{ name = "Console", size = Vector2.new(1920, 1080) },
			},
			noOverlap = true,
			fitsViewport = true,
			noTextOverflow = true,
			mount = function(_env, _parent, viewport)
				local world, UI = newClientUI()
				local screenGui = UI.LayerDefault.Parent
				if screenGui then
					screenGui.Size = UDim2.fromOffset(viewport.X, viewport.Y)
				end

				local panelW = math.min(viewport.X - 24, 560)
				local panelH = math.min(viewport.Y - 48, 380)

				local btnExecute = UI.new "Button" {
					Name = "ExecuteButton",
					Label = "Execute",
					Size = UDim2.fromOffset(100, 32),
				}
				btnExecute._instance.Ripple.Size = UDim2.fromOffset(0, 0)
				local btnClear = UI.new "Button" {
					Name = "ClearButton",
					Label = "Clear",
					Size = UDim2.fromOffset(88, 32),
				}
				btnClear._instance.Ripple.Size = UDim2.fromOffset(0, 0)
				local swToggle = UI.new "Switch" {
					Name = "ModeSwitch",
					AnchorPoint = Vector2.new(0, 0),
					Position = UDim2.fromOffset(0, 0),
					Value = true,
				}
				local cbCheck = UI.new "Checkbox" {
					Name = "ConfirmCheck",
					AnchorPoint = Vector2.new(0, 0),
					Position = UDim2.fromOffset(0, 0),
					Value = true,
				}

				local panel = UI.new "Frame" {
					Name = "AuditPanel",
					Parent = UI.LayerDefault,
					Position = UDim2.fromOffset(12, 24),
					Size = UDim2.fromOffset(panelW, panelH),
					BackgroundColor3 = UI.Theme.Primary,

					UI.padding(UDim.new(0, 8)),
					UI.list {
						gap = UDim.new(0, 8),
						horizontalAlign = "start",
						verticalAlign = "start",
					},

					UI.new "TextLabel" {
						Name = "HeaderTitle",
						LayoutOrder = 1,
						BackgroundTransparency = 1,
						Size = UDim2.new(1, 0, 0, 28),
						FontFace = UI.Theme.FontBold,
						TextSize = 18,
						TextXAlignment = Enum.TextXAlignment.Left,
						Text = "Kohl's Admin Controls",
					},

					UI.new "Frame" {
						Name = "Toolbar",
						LayoutOrder = 2,
						BackgroundTransparency = 1,
						Size = UDim2.new(1, 0, 0, 36),

						UI.list {
							direction = "x",
							gap = UDim.new(0, 8),
							verticalAlign = "center",
						},

						btnExecute._instance,
						btnClear._instance,
						swToggle._instance,
						cbCheck._instance,
					},

					UI.new "Frame" {
						Name = "RowsSection",
						LayoutOrder = 3,
						BackgroundTransparency = 1,
						Size = UDim2.new(1, 0, 0, 120),

						UI.list {
							gap = UDim.new(0, 6),
						},

						UI.new "TextLabel" {
							Name = "Row1",
							LayoutOrder = 1,
							BackgroundTransparency = 0.5,
							Size = UDim2.new(1, 0, 0, 28),
							FontFace = UI.Theme.Font,
							TextSize = 14,
							TextXAlignment = Enum.TextXAlignment.Left,
							Text = "Prefix: ;",
						},
						UI.new "TextLabel" {
							Name = "Row2",
							LayoutOrder = 2,
							BackgroundTransparency = 0.5,
							Size = UDim2.new(1, 0, 0, 28),
							FontFace = UI.Theme.Font,
							TextSize = 14,
							TextXAlignment = Enum.TextXAlignment.Left,
							Text = "Role: SuperAdmin",
						},
					},
				}

				UI.flush()
				world:run(0.1)
				return panel
			end,
			check = function(_env, root, vp)
				expect(root.AbsoluteSize.X > 0 and root.AbsoluteSize.X <= vp.size.X).toBe(true)
				expect(root.AbsoluteSize.Y > 0 and root.AbsoluteSize.Y <= vp.size.Y).toBe(true)
				local toolbar = root:FindFirstChild("Toolbar")
				expect(toolbar ~= nil).toBe(true)
				local execBtn = toolbar:FindFirstChild("ExecuteButton")
				local modeSw = toolbar:FindFirstChild("ModeSwitch")
				local confirmCb = toolbar:FindFirstChild("ConfirmCheck")
				expect(execBtn ~= nil and execBtn.AbsoluteSize.X > 0).toBe(true)
				expect(modeSw ~= nil and modeSw.AbsoluteSize.X > 0).toBe(true)
				expect(confirmCb ~= nil and confirmCb.AbsoluteSize.X > 0).toBe(true)
			end,
		})
	end
end)

return {}
