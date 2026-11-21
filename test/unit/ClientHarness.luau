local Harness = require("./Harness")
local sert = require("../sert")

local baseGlobals = Harness.globals
local Enum = baseGlobals.Enum
local Font = baseGlobals.Font
local Color3 = baseGlobals.Color3
local Vector3 = baseGlobals.Vector3
local BrickColor = baseGlobals.BrickColor

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
	local stats = env.game:GetService("Stats")
	stats._props.FrameTime = 1 / 60

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
		local okCli, errCli = pcall(cliMounted.env.require, cliMounted.env, cliMounted.Client)
		if not okCli and not string.find(tostring(errCli), "did not return exactly one value", 1, true) then
			error(errCli, 0)
		end
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

local function getSharedFullPingLabel()
	return sharedFullPingLabel
end

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

local function observers(sig: any): number
	-- a Flux signal is { inner }, and inner[4] counts the nodes observing it
	local inner: any = rawget(sig, 1)
	return inner[4]
end

return {
	setupClientEnv = setupClientEnv,
	makeInput = makeInput,
	getOrCreateFullClientSut = getOrCreateFullClientSut,
	getSharedFullPingLabel = getSharedFullPingLabel,
	makeFastRun = makeFastRun,
	newClientUI = newClientUI,
	observers = observers,
}
