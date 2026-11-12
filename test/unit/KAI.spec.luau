--!strict
local sert = require("../sert")

local describe, test = sert.describe, sert.test
local headlessTest = test
local serverTest = sert.test.server

type AnyTable = { [any]: any }

-- selene: allow(shadowing)
local require: (any) -> any = require :: any

-- ============================================================================
-- Headless KAI Server & Client Harnesses
-- ============================================================================

type KaiServerHarness = {
	env: any,
	kai: AnyTable,
	firedClients: { { player: any, action: string, payload: any } },
	filterFail: boolean,
	filterFn: ((text: string, fromUserId: number) -> string)?,
	canChatMap: { [number]: boolean },
	pairChatFn: ((a: number, b: number) -> boolean)?,
	savedData: { [string]: any },
	promptedBulk: { { player: any, items: any } },
	promptedSingle: { { player: any, assetId: number } },
	reservedTeleports: { { placeId: number, code: string, players: { any } } },
	reset: () -> (),
}

local cachedServerHarness: KaiServerHarness? = nil

local function getKaiServer(): KaiServerHarness
	if cachedServerHarness ~= nil then
		cachedServerHarness.reset()
		return cachedServerHarness
	end

	local env = sert.env.new({
		isServer = true,
		isStudio = false,
		creatorId = 999999,
		strict = false,
		signalBehavior = "Immediate",
	})
	local firedClients: { { player: any, action: string, payload: any } } = {}
	local savedData: { [string]: any } = {
		KPrivateServers = {
			lobby = { Code = "RES_CODE_123", Id = 555000 },
		},
	}
	local promptedBulk: { { player: any, items: any } } = {}
	local promptedSingle: { { player: any, assetId: number } } = {}
	local reservedTeleports: { { placeId: number, code: string, players: { any } } } = {}

	local stateBox = {
		filterFail = false,
		filterFn = nil :: ((text: string, fromUserId: number) -> string)?,
		canChatMap = {} :: { [number]: boolean },
		pairChatFn = nil :: ((a: number, b: number) -> boolean)?,
	}

	-- Configure InsertService:LoadAsset(47433) so SWORD initializes cleanly
	local insertService = env.game:GetService("InsertService")
	local insertMethods = rawget(insertService, "_methods") or {}
	rawset(insertService, "_methods", insertMethods)
	insertMethods.LoadAsset = function(_self: any, _assetId: number)
		local model = env.Instance.new("Model")
		local sword = env.Instance.new("Tool", model)
		sword.Name = "ClassicSword"
		return model
	end

	-- Configure DataStoreService GlobalDataStore
	local dsService = env.game:GetService("DataStoreService")
	local dsMethods = rawget(dsService, "_methods") or {}
	rawset(dsService, "_methods", dsMethods)
	local globalStore = {
		GetAsync = function(_self: any, key: string)
			return savedData[key]
		end,
		SetAsync = function(_self: any, key: string, value: any)
			savedData[key] = value
		end,
		UpdateAsync = function(_self: any, key: string, transform: (any) -> any)
			local nextVal = transform(savedData[key])
			if nextVal ~= nil then
				savedData[key] = nextVal
			end
			return nextVal
		end,
	}
	dsMethods.GetGlobalDataStore = function()
		return globalStore
	end

	-- Configure TextService:FilterStringAsync
	local textService = env.game:GetService("TextService")
	local textMethods = rawget(textService, "_methods") or {}
	rawset(textService, "_methods", textMethods)
	textMethods.FilterStringAsync = function(_self: any, text: string, fromUserId: number, _ctx: any)
		if fromUserId <= 0 then
			error("FilterStringAsync called with non-positive UserId", 0)
		end
		if stateBox.filterFail then
			error("Simulated TextService filter failure", 0)
		end
		local out = if stateBox.filterFn then stateBox.filterFn(text, fromUserId) else text
		return {
			GetNonChatStringForBroadcastAsync = function()
				return out
			end,
			GetNonChatStringForUserAsync = function()
				return out
			end,
		}
	end

	-- Configure TextChatService CanUserChatAsync / CanUsersChatAsync
	local tcs = env.game:GetService("TextChatService")
	local tcsMethods = rawget(tcs, "_methods") or {}
	rawset(tcs, "_methods", tcsMethods)
	tcsMethods.CanUserChatAsync = function(_self: any, userId: number)
		if userId <= 0 then
			error("CanUserChatAsync called with non-positive UserId", 0)
		end
		local mapped = stateBox.canChatMap[userId]
		if mapped ~= nil then
			return mapped
		end
		return true
	end
	tcsMethods.CanUsersChatAsync = function(_self: any, fromId: number, toId: number)
		if fromId <= 0 or toId <= 0 then
			error("CanUsersChatAsync called with non-positive UserId", 0)
		end
		if stateBox.pairChatFn then
			return stateBox.pairChatFn(fromId, toId)
		end
		return true
	end

	-- Configure MarketplaceService prompt hooks & asset ownership
	local mps = env.game:GetService("MarketplaceService")
	local mpsMethods = rawget(mps, "_methods") or {}
	rawset(mps, "_methods", mpsMethods)
	local origOwnsAssetAsync = mpsMethods.PlayerOwnsAssetAsync
	mpsMethods.PlayerOwnsAssetAsync = function(self: any, plr: any, assetId: number)
		local owned = env.marketplace.assets[plr.UserId]
		if owned and owned[assetId] then
			return true
		end
		if origOwnsAssetAsync then
			return origOwnsAssetAsync(self, plr, assetId)
		end
		return false
	end
	mpsMethods.PromptBulkPurchase = function(_self: any, plr: any, items: any, _opts: any)
		if (env :: AnyTable)._failBulkPrompt then
			error("PromptBulkPurchase unavailable", 0)
		end
		table.insert(promptedBulk, { player = plr, items = items })
	end
	mpsMethods.PromptPurchase = function(_self: any, plr: any, assetId: number)
		table.insert(promptedSingle, { player = plr, assetId = assetId })
	end

	-- Configure TeleportService:TeleportToPrivateServer
	local tpService = env.game:GetService("TeleportService")
	local tpMethods = rawget(tpService, "_methods") or {}
	rawset(tpService, "_methods", tpMethods)
	tpMethods.TeleportToPrivateServer = function(_self: any, placeId: number, code: string, players: { any })
		table.insert(reservedTeleports, { placeId = placeId, code = code, players = players })
	end

	-- Build script tree expected by test/migrate/KAI/init.luau
	local kaiScript = env.Instance.new("ModuleScript")
	kaiScript.Name = "KAI"
	local deps = env.Instance.new("Folder", kaiScript)
	deps.Name = "D"

	local superCrownMod = env.Instance.new("ModuleScript", deps)
	superCrownMod.Name = "SuperCrown"
	rawset(superCrownMod, "_factory", function()
		local acc = env.Instance.new("Accessory")
		acc.Name = "SuperCrown"
		local handle = env.Instance.new("Part", acc)
		handle.Name = "Handle"
		local fire = env.Instance.new("Fire", handle)
		fire.Name = "Fire"
		return acc
	end)

	local shine = env.Instance.new("ParticleEmitter", deps)
	shine.Name = "Shine"

	local clientStub = env.Instance.new("LocalScript", deps)
	clientStub.Name = "Client"

	local extras = env.Instance.new("Folder", deps)
	extras.Name = "Extras"
	local explorerGui = env.Instance.new("ScreenGui", extras)
	explorerGui.Name = "Explorer"

	local toolsFolder = env.Instance.new("Folder", kaiScript)
	toolsFolder.Name = "Tools"
	local btools = env.Instance.new("Tool", toolsFolder)
	btools.Name = "Building Tools"

	-- Build ServerScriptService["Kohl's Admin Infinite"] Script + Settings + Custom_Commands
	local sss = env.game:GetService("ServerScriptService")
	local loaderScript = env.Instance.new("Script", sss)
	loaderScript.Name = "Kohl's Admin Infinite"

	local customMod = env.Instance.new("ModuleScript", loaderScript)
	customMod.Name = "Custom_Commands"
	rawset(customMod, "_factory", function()
		return {}
	end)

	local settingsMod = env.Instance.new("ModuleScript", loaderScript)
	settingsMod.Name = "Settings"
	rawset(settingsMod, "_factory", function(): { any }
		return {
			{
				Flat = true,
				ForcedColor = false,
				Color = env.Color3.new(0, 0, 0),
				ColorTransparency = 0.75,
				Chat = false,
				BubbleChat = false,
				AdminCredit = true,
				AutoClean = false,
				AutoCleanDelay = 60,
				CommandBar = true,
				FunCommands = true,
				FreeAdmin = false,
				PublicLogs = false,
				Prefix = ":",
				GroupAdmin = {},
				VIPAdmin = {},
				Permissions = {},
				HttpWait = 60,
			} :: any,
			{ {}, {}, {}, {}, {}, {} } :: any,
		}
	end)

	rawset(env, "_pendingScript", kaiScript)
	local loadErr: any = nil
	env.task.spawn(function()
		local ok, err = pcall(function()
			return require("../migrate/KAI")
		end)
		if not ok then
			loadErr = err
		end
	end)
	env:advance(0.25)
	rawset(env, "_pendingScript", nil)
	if loadErr ~= nil then
		error(`Failed to load headless KAI server: {tostring(loadErr)}`, 0)
	end

	local kai = env.shared._KAI_INTERNAL
	assert(type(kai) == "table", "shared._KAI_INTERNAL must be populated")

	-- Intercept RemoteEvent:FireClient to record all server->client deliveries
	local remoteMethods = rawget(kai.RemoteEvent, "_methods") or {}
	rawset(kai.RemoteEvent, "_methods", remoteMethods)
	local origFireClient = remoteMethods.FireClient
	remoteMethods.FireClient = function(self: any, plr: any, action: string, payload: any)
		table.insert(firedClients, { player = plr, action = action, payload = payload })
		if origFireClient then
			origFireClient(self, plr, action, payload)
		end
	end

	local harness: KaiServerHarness
	local function reset()
		for _, p in table.clone(env.Players:GetPlayers()) do
			env:removePlayer(p)
		end
		table.clear(firedClients)
		table.clear(promptedBulk)
		table.clear(promptedSingle)
		table.clear(reservedTeleports)
		table.clear(stateBox.canChatMap)
		stateBox.filterFail = false
		stateBox.filterFn = nil
		stateBox.pairChatFn = nil
		(env :: AnyTable)._failBulkPrompt = false
		savedData.KPrivateServers = {
			lobby = { Code = "RES_CODE_123", Id = 555000 },
		}
		savedData.KLogs = nil
		savedData.KSave = nil

		table.clear(kai.getAdmins())
		table.clear(kai.getBans())
		table.clear(kai.getDonorCache())
		table.clear(kai.state.Logs)
		table.clear(kai.state.Votes)
		table.clear(kai.state.VoteTargets)
		kai.clearChatCaches()
		kai.clearCooldowns()

		local set = kai.getSet()
		set.Prefix = ":"
		set.PublicLogs = false
		set.ForceLogs = false
		set.AdminCredit = true
		set.FreeAdmin = 0
		kai.f.Chatted(kai.serverContext, ":unnotify", true)
		table.clear(kai.state.Logs)
		table.clear(firedClients)
		kai.syncTextChatCommands()
	end

	harness = setmetatable({
		env = env,
		kai = kai,
		firedClients = firedClients,
		savedData = savedData,
		promptedBulk = promptedBulk,
		promptedSingle = promptedSingle,
		reservedTeleports = reservedTeleports,
		reset = reset,
	}, {
		__index = function(_self: any, k: string): any
			return (stateBox :: AnyTable)[k]
		end,
		__newindex = function(_self: any, k: string, v: any)
			(stateBox :: AnyTable)[k] = v
		end,
	}) :: any

	cachedServerHarness = harness
	return harness
end

type KaiClientHarness = {
	env: any,
	client: AnyTable,
	remote: any,
	admstr: any,
	banstr: any,
	logb: any,
	clogb: any,
	sentChannelMessages: { { text: string, metadata: string? } },
	creditTemplate: any,
}

local cachedClientHarness: KaiClientHarness? = nil

local function makeMockUiTemplates(env: any, creditTemplate: any): AnyTable
	local InstanceNew = env.Instance.new

	local function withCommonGui(name: string): any
		local root = InstanceNew("Frame")
		root.Name = name
		local bg = InstanceNew("Frame", root)
		bg.Name = "BG"
		local title = InstanceNew("TextLabel", root)
		title.Name = "Title"
		local hide = InstanceNew("TextButton", root)
		hide.Name = "Hide"
		local close = InstanceNew("TextButton", root)
		close.Name = "Close"
		return root
	end

	local cmdBarRoot = InstanceNew("Frame")
	cmdBarRoot.Name = "CommandBar"
	local cmdBox = InstanceNew("TextBox", cmdBarRoot)
	cmdBox.Name = "CmdBar"
	local cmdList = InstanceNew("Frame", cmdBarRoot)
	cmdList.Name = "List"

	local direct = InstanceNew("Frame")
	direct.Name = "Direct"
	local directClose = InstanceNew("TextButton", direct)
	directClose.Name = "Close"
	local directLink = InstanceNew("TextBox", direct)
	directLink.Name = "Link"

	local listRoot = withCommonGui("List")
	local scroller = InstanceNew("ScrollingFrame", listRoot)
	scroller.Name = "List"

	local searchRoot = InstanceNew("Frame")
	searchRoot.Name = "Search"
	local searchBox = InstanceNew("TextBox", searchRoot)
	searchBox.Name = "BG"

	local note = InstanceNew("TextLabel")
	note.Name = "Note"

	local resize = InstanceNew("ImageButton")
	resize.Name = "Resize"

	local msg = InstanceNew("Frame")
	msg.Name = "Msg"
	local msgOwner = InstanceNew("TextLabel", msg)
	msgOwner.Name = "Owner"
	local msgTitle = InstanceNew("TextLabel", msg)
	msgTitle.Name = "Title"
	local msgBody = InstanceNew("TextLabel", msg)
	msgBody.Name = "Msg"
	local msgUser = InstanceNew("ImageLabel", msg)
	msgUser.Name = "User"

	local hint = InstanceNew("Frame")
	hint.Name = "Hint"
	local hintBg = InstanceNew("TextLabel", hint)
	hintBg.Name = "BG"

	local errFrame = InstanceNew("Frame")
	errFrame.Name = "Error"
	local errMsg = InstanceNew("TextLabel", errFrame)
	errMsg.Name = "Msg"

	local vote = InstanceNew("Frame")
	vote.Name = "Vote"
	local voteMsg = InstanceNew("TextLabel", vote)
	voteMsg.Name = "Msg"
	local voteY = InstanceNew("TextButton", vote)
	voteY.Name = "Y"
	local voteN = InstanceNew("TextButton", vote)
	voteN.Name = "N"

	local help = withCommonGui("Help")
	local helpList = InstanceNew("ScrollingFrame", help)
	helpList.Name = "List"
	local helpPrefix = InstanceNew("TextLabel", helpList)
	helpPrefix.Name = "Prefix"

	return {
		Blank = InstanceNew("Frame"),
		Blind = InstanceNew("Frame"),
		Chat = InstanceNew("Frame"),
		CommandBar = cmdBarRoot,
		Credit = creditTemplate,
		Direct = direct,
		Error = errFrame,
		Help = help,
		Hint = hint,
		List = listRoot,
		Msg = msg,
		Note = note,
		Resize = resize,
		Search = searchRoot,
		Settings = withCommonGui("Settings"),
		Timer = InstanceNew("Frame"),
		Vote = vote,
	}
end

local function getKaiClient(): KaiClientHarness
	if cachedClientHarness ~= nil then
		return cachedClientHarness
	end

	local env = sert.env.new({ isClient = true, isStudio = false, strict = false, signalBehavior = "Immediate" })
	local plr = env.LocalPlayer
	local plrMethods = rawget(plr, "_methods") or {}
	rawset(plr, "_methods", plrMethods)
	plrMethods.GetMouse = function()
		return { X = 0, Y = 0 }
	end
	local initChar = env.Instance.new("Model", env.workspace)
	initChar.Name = plr.Name
	env.Instance.new("Humanoid", initChar)
	plr.Character = initChar
	local kdonor = env.Instance.new("IntValue", plr)
	kdonor.Name = "KDonor"
	kdonor.Value = 0

	local rs = env.game:GetService("ReplicatedStorage")
	local remote = env.Instance.new("RemoteEvent", rs)
	remote.Name = "b\a\n\a\n\a"
	local admstr = env.Instance.new("StringValue", remote)
	admstr.Name = "\admi\n"
	local banstr = env.Instance.new("StringValue", remote)
	banstr.Name = "\b\a\n"
	local logb = env.Instance.new("BoolValue", remote)
	logb.Name = "log"
	local clogb = env.Instance.new("BoolValue", remote)
	clogb.Name = "clog"

	-- Create TextChatService.TextChannels.RBXGeneral and spy on SendAsync
	local tcs = env.game:GetService("TextChatService")
	local channels = tcs:FindFirstChild("TextChannels") or env.Instance.new("Folder", tcs)
	channels.Name = "TextChannels"
	local general = channels:FindFirstChild("RBXGeneral") or env.Instance.new("TextChannel", channels)
	general.Name = "RBXGeneral"

	local sentChannelMessages: { { text: string, metadata: string? } } = {}
	local genMethods = rawget(general, "_methods") or {}
	rawset(general, "_methods", genMethods)
	genMethods.SendAsync = function(_self: any, text: string, metadata: string?)
		table.insert(sentChannelMessages, { text = text, metadata = metadata })
	end

	-- Load real Serialized_Credit.luau in this client env
	local creditTemplate: any = nil
	env.task.spawn(function()
		creditTemplate = require("../migrate/KAI/D/Client/Templates/Serialized_Credit")
	end)
	env:advance(0.05)
	assert(creditTemplate ~= nil, "Serialized_Credit must return a Frame")

	local clientScript = env.Instance.new("LocalScript")
	clientScript.Name = "\n\a\n"
	local templatesMod = env.Instance.new("ModuleScript", clientScript)
	templatesMod.Name = "Templates"
	local mockTemplates = makeMockUiTemplates(env, creditTemplate)
	rawset(templatesMod, "_factory", function()
		return mockTemplates
	end)

	rawset(env, "_pendingScript", clientScript)
	local clientLoadErr: any = nil
	env.task.spawn(function()
		local ok, err = pcall(function()
			return require("../migrate/KAI/D/Client/init.client")
		end)
		if not ok then
			clientLoadErr = err
		end
	end)
	env:advance(0.25)
	rawset(env, "_pendingScript", nil)
	if clientLoadErr ~= nil then
		error(`Failed to load headless KAI client: {tostring(clientLoadErr)}`, 0)
	end

	local clientInternal = env.shared._KAI_CLIENT_INTERNAL
	assert(type(clientInternal) == "table", "shared._KAI_CLIENT_INTERNAL must be populated")

	local harness: KaiClientHarness = {
		env = env,
		client = clientInternal,
		remote = remote,
		admstr = admstr,
		banstr = banstr,
		logb = logb,
		clogb = clogb,
		sentChannelMessages = sentChannelMessages,
		creditTemplate = creditTemplate,
	}
	cachedClientHarness = harness
	return harness
end

-- ============================================================================
-- Headless Luau Unit Specs
-- ============================================================================

describe("KAI · Legacy PIC Compliance & 2026 Regressions", function()
	headlessTest(
		"TextChatCommands_KAI avoids default/external slash collisions, syncs prefix updates, and preserves Triggered case",
		function()
			local s = getKaiServer()
			local tcs = s.env.game:GetService("TextChatService")

			-- Add an external developer TextChatCommand claiming /fly before resync
			local extCmd = s.env.Instance.new("TextChatCommand", tcs)
			extCmd.Name = "ExternalFly"
			extCmd.PrimaryAlias = "/fly"
			extCmd.SecondaryAlias = "/soar"
			s.kai.syncTextChatCommands()

			local folder = tcs:FindFirstChild("TextChatCommands_KAI")
			sert.eq(folder ~= nil, true)

			-- Default Roblox command /help is reserved -> KAI_help falls back to ":help" primary
			local helpCmd = folder:FindFirstChild("KAI_help")
			sert.eq(helpCmd ~= nil, true)
			sert.eq(helpCmd.PrimaryAlias, ":help")
			sert.eq(helpCmd.SecondaryAlias, "")

			-- External /fly collision falls back to ":fly" primary
			local flyCmd = folder:FindFirstChild("KAI_fly")
			sert.eq(flyCmd ~= nil, true)
			sert.eq(flyCmd.PrimaryAlias, ":fly")
			sert.eq(flyCmd.SecondaryAlias, "")
			sert.eq(flyCmd:GetAttribute("Power"), 2)

			-- Non-colliding command uses "/ping" primary and ":ping" secondary
			local pingCmd = folder:FindFirstChild("KAI_ping")
			sert.eq(pingCmd ~= nil, true)
			sert.eq(pingCmd.PrimaryAlias, "/ping")
			sert.eq(pingCmd.SecondaryAlias, ":ping")

			extCmd:Destroy()
			s.kai.syncTextChatCommands()
			sert.eq(folder:FindFirstChild("KAI_fly").PrimaryAlias, "/fly")
			sert.eq(folder:FindFirstChild("KAI_fly").SecondaryAlias, ":fly")

			-- Updating Set.Prefix via KUpdate resyncs SecondaryAlias & collision fallback PrimaryAlias
			local owner = s.env:addPlayer(10, "OwnerPlr")
			s.kai.getAdmins()[owner.UserId] = 5
			local uID = s.kai.f.uID

			-- Unchanged prefix in KUpdate does NOT consume the 60s "prefix" cooldown
			s.kai.ServerEvent(owner, uID .. "KUpdate", { IGS = true, Prefix = ":" })
			s.kai.ServerEvent(owner, uID .. "KUpdate", { IGS = true, Prefix = "!" })
			sert.eq(s.kai.getSet().Prefix, "!")
			sert.eq(folder:FindFirstChild("KAI_ping").SecondaryAlias, "!ping")
			sert.eq(folder:FindFirstChild("KAI_help").PrimaryAlias, "!help")

			-- Triggered strips leading "/" or Set.Prefix while preserving exact argument casing
			local _target = s.env:addPlayer(20, "TargetPlr")
			table.clear(s.firedClients)

			local notifyCmd = folder:FindFirstChild("KAI_notify")
			sert.eq(notifyCmd ~= nil, true)
			notifyCmd.Triggered:Fire({ UserId = owner.UserId }, "/notify MixedCase Notice!")
			s.env:flush()

			local gotMixedCase = false
			for _, ev in s.firedClients do
				if ev.action == "KNotify" and string.find(tostring(ev.payload), "MixedCase Notice!", 1, true) then
					gotMixedCase = true
				end
			end
			sert.eq(gotMixedCase, true)
		end
	)

	headlessTest(
		"_G.KServerCommand executes broadcast/sticky commands with UserId 0 without calling CanUserChatAsync or FilterStringAsync",
		function()
			local s = getKaiServer()
			local p1 = s.env:addPlayer(101, "Alice")
			table.clear(s.firedClients)

			-- Note: our mock CanUserChatAsync and FilterStringAsync throw if called with userId <= 0!
			s.env._G.KServerCommand(":m Server Broadcast Hello")
			s.env._G.KServerCommand(":h Server Hint Hello")
			s.env._G.KServerCommand(":notify Server Sticky Banner")

			local seenMsg, seenHint, seenNotify = false, false, false
			for _, ev in s.firedClients do
				if ev.player == p1 and ev.action == "KMsg" and ev.payload[3] == "Server Broadcast Hello" then
					seenMsg = true
				elseif ev.player == p1 and ev.action == "KHint" and ev.payload == "Server: Server Hint Hello" then
					seenHint = true
				elseif ev.player == p1 and ev.action == "KNotify" and ev.payload == "Server Sticky Banner" then
					seenNotify = true
				end
			end
			sert.eq(seenMsg, true)
			sert.eq(seenHint, true)
			sert.eq(seenNotify, true)
			sert.eq(s.kai.getActiveNotify() ~= nil, true)

			-- Late joiner receives sticky server notify on PlayerAdded (f.Load), and :unnotify clears it
			table.clear(s.firedClients)
			local lateJoiner = s.env:addPlayer(102, "Bob")
			local lateGotSticky = false
			for _, ev in s.firedClients do
				if ev.player == lateJoiner and ev.action == "KNotify" and ev.payload == "Server Sticky Banner" then
					lateGotSticky = true
				end
			end
			sert.eq(lateGotSticky, true)

			s.env._G.KServerCommand(":unnotify")
			sert.eq(s.kai.getActiveNotify(), nil)
		end
	)

	headlessTest(
		"f.chatSend filters broadcast text, aborts on filter error, enforces 60s cooldown on restricted peers, and gates KVote on VoteTargets",
		function()
			local s = getKaiServer()
			local admin = s.env:addPlayer(11, "AdminSender")
			local unrestrictedPeer = s.env:addPlayer(12, "FriendPeer")
			local restrictedPeer = s.env:addPlayer(13, "RestrictedPeer")
			s.kai.getAdmins()[admin.UserId] = 5
			local uID = s.kai.f.uID

			-- Pair chat: admin <-> unrestrictedPeer allowed; admin <-> restrictedPeer blocked
			s.pairChatFn = function(a: number, b: number): boolean
				if (a == 11 and b == 13) or (a == 13 and b == 11) then
					return false
				end
				return true
			end
			s.filterFn = function(text: string): string
				return "[filtered] " .. text
			end

			-- 1. Filter failure aborts delivery completely without leaking raw text
			s.filterFail = true
			table.clear(s.firedClients)
			s.kai.f.Chatted(admin, ":m secret unfiltered", false)
			for _, ev in s.firedClients do
				sert.eq(ev.action ~= "KMsg", true)
			end

			-- 2. First broadcast succeeds to ALL recipients (consumes 60s "msg" cooldown)
			s.env:advance(1.5)
			s.filterFail = false
			table.clear(s.firedClients)
			s.kai.f.Chatted(admin, ":m First Announcement", false)
			local firstRecipients: { [number]: string } = {}
			for _, ev in s.firedClients do
				if ev.action == "KMsg" then
					firstRecipients[ev.player.UserId] = ev.payload[3]
				end
			end
			sert.eq(firstRecipients[11], "[filtered] First Announcement")
			sert.eq(firstRecipients[12], "[filtered] First Announcement")
			sert.eq(firstRecipients[13], "[filtered] First Announcement")

			-- 3. Second broadcast within 60s skips restrictedPeer (13) while still delivering to self (11) & unrestrictedPeer (12)
			s.env:advance(1.5)
			table.clear(s.firedClients)
			s.kai.f.Chatted(admin, ":m Second Announcement", false)
			local secondRecipients: { [number]: boolean } = {}
			local gotCooldownError = false
			for _, ev in s.firedClients do
				if ev.action == "KMsg" then
					secondRecipients[ev.player.UserId] = true
				elseif ev.action == "KError" and ev.player == admin then
					gotCooldownError = true
				end
			end
			sert.eq(gotCooldownError, true)
			sert.eq(secondRecipients[11], true)
			sert.eq(secondRecipients[12], true)
			sert.eq(secondRecipients[13], nil)

			-- 4. :vote while on cooldown only marks actually-delivered recipients in VoteTargets
			-- Consume "vote" cooldown first, then run a second :vote so restrictedPeer does not receive it
			s.env:advance(1.5)
			s.kai.f.Chatted(admin, ":vote all First Poll?", false)
			s.env:advance(1.5)
			s.kai.state.LastVote = 0
			s.kai.f.Chatted(admin, ":vote all Second Poll?", false)
			sert.eq(s.kai.state.VoteTargets[unrestrictedPeer], true)
			sert.eq(s.kai.state.VoteTargets[restrictedPeer], nil)

			s.kai.ServerEvent(unrestrictedPeer, uID .. "KVote", true)
			s.kai.ServerEvent(restrictedPeer, uID .. "KVote", true)
			sert.eq(s.kai.state.Votes[unrestrictedPeer.UserId], true)
			sert.eq(s.kai.state.Votes[restrictedPeer.UserId], nil)

			-- 5. Sender with CanUserChatAsync == false cannot send chat/messages
			s.env:advance(1.5)
			s.canChatMap[admin.UserId] = false
			s.kai.clearChatCaches()
			table.clear(s.firedClients)
			s.kai.f.Chatted(admin, ":pm FriendPeer blocked", false)
			for _, ev in s.firedClients do
				sert.eq(ev.action ~= "KMsg", true)
			end
		end
	)

	headlessTest(
		":kick passes filtered reason to unrestricted targets without spending cooldown and falls back to 'Kicked' when rate-limited",
		function()
			local s = getKaiServer()
			local admin = s.env:addPlayer(30, "ModAdmin")
			local _friendTarget = s.env:addPlayer(31, "FriendTarget")
			local _stranger1 = s.env:addPlayer(32, "StrangerOne")
			local _stranger2 = s.env:addPlayer(33, "StrangerTwo")
			s.kai.getAdmins()[admin.UserId] = 5

			s.pairChatFn = function(a: number, b: number): boolean
				return (a == 30 and b == 31) or (a == 31 and b == 30)
			end

			-- Unrestricted peer gets custom reason without spending the 60s "reason" cooldown
			s.kai.f.Chatted(admin, ":kick FriendTarget See you soon", false)
			sert.eq(#s.env.kicks, 1)
			sert.eq(s.env.kicks[1].userId, 31)
			sert.eq(s.env.kicks[1].message, "See you soon")

			-- First restricted peer consumes the 60s "reason" cooldown and receives the filtered custom reason
			s.env:advance(1.5)
			s.kai.f.Chatted(admin, ":kick StrangerOne Rule violation", false)
			sert.eq(#s.env.kicks, 2)
			sert.eq(s.env.kicks[2].userId, 32)
			sert.eq(s.env.kicks[2].message, "Rule violation")

			-- Second restricted peer within 60s STILL gets kicked, but with generic "Kicked" reason
			s.env:advance(1.5)
			s.kai.f.Chatted(admin, ":kick StrangerTwo Spamming reason", false)
			sert.eq(#s.env.kicks, 3)
			sert.eq(s.env.kicks[3].userId, 33)
			sert.eq(s.env.kicks[3].message, "Kicked")
		end
	)

	headlessTest(
		"Logs redact unconfirmed free-text arguments for restricted viewers & DataStore saves, then reveal non-private args after 60s",
		function()
			local s = getKaiServer()
			local sender = s.env:addPlayer(40, "SenderAdmin")
			local friendAdmin = s.env:addPlayer(41, "FriendAdmin")
			local restrictedAdmin = s.env:addPlayer(42, "RestrictedAdmin")
			local friendTarget = s.env:addPlayer(43, "KickableFriend")
			s.kai.getAdmins()[sender.UserId] = 5
			s.kai.getAdmins()[friendAdmin.UserId] = 4
			s.kai.getAdmins()[restrictedAdmin.UserId] = 4
			local _ = friendTarget

			s.pairChatFn = function(a: number, b: number): boolean
				return (a == 40 and (b == 41 or b == 43)) or ((a == 41 or a == 43) and b == 40)
			end

			-- :kick to an unrestricted target has free-text reason WITHOUT spending a 60s broadcast cooldown -> redacted for restrictedAdmin, full for sender & friendAdmin
			table.clear(s.firedClients)
			s.kai.f.Chatted(sender, ":kick KickableFriend SecretKickReason", false)
			sert.eq(#s.kai.state.Logs, 1)
			sert.eq(string.find(tostring(s.kai.state.Logs[1][2]), ":kick KickableFriend …", 1, true) ~= nil, true)

			local liveLogByUser: { [number]: string } = {}
			for _, ev in s.firedClients do
				if ev.action == "KUpdateLog" then
					liveLogByUser[ev.player.UserId] = ev.payload[2]
				end
			end
			sert.eq(string.find(liveLogByUser[40] or "", "SecretKickReason", 1, true) ~= nil, true)
			sert.eq(string.find(liveLogByUser[41] or "", "SecretKickReason", 1, true) ~= nil, true)
			sert.eq(string.find(liveLogByUser[42] or "", ":kick KickableFriend …", 1, true) ~= nil, true)

			-- Advancing 60s reveals non-private log entry
			s.env:advance(61)
			sert.eq(string.find(tostring(s.kai.state.Logs[1][2]), "SecretKickReason", 1, true) ~= nil, true)

			-- Private command (:pm) stays redacted even after 60s!
			s.kai.f.Chatted(sender, ":pm FriendAdmin WhisperTextOnly", false)
			sert.eq(string.find(tostring(s.kai.state.Logs[1][2]), ":pm FriendAdmin …", 1, true) ~= nil, true)
			s.env:advance(61)
			sert.eq(string.find(tostring(s.kai.state.Logs[1][2]), ":pm FriendAdmin …", 1, true) ~= nil, true)
		end
	)

	headlessTest(
		"2026 regressions fixed: :place teleports via returned DataStore table, :hat guards nil info, DonorCache/VIP & KDelete/KPaste hardened",
		function()
			local s = getKaiServer()
			-- Pre-grant new 2026 D2 asset 77680874300094 BEFORE addPlayer triggers PlayerAdded -> f.Load!
			s.env.marketplace.assets[51] = { [77680874300094] = true }
			local owner = s.env:addPlayer(50, "OwnerFifty")
			local regular = s.env:addPlayer(51, "RegularFiftyOne")
			s.kai.getAdmins()[owner.UserId] = 5
			local uID = s.kai.f.uID

			-- 1. New D2 asset (77680874300094) grants donor tier >= 1 on f.Load and KVIPCheck
			sert.eq(regular:FindFirstChild("KDonor").Value >= 1, true)
			s.kai.getDonorCache()[regular.UserId] = nil
			sert.ok((regular:FindFirstChild("KDonor")))
			-- Nil DonorCache guards do not crash on KHat / KTrail / KShine / :crownrainbow
			s.kai.ServerEvent(regular, uID .. "KHat")
			s.kai.ServerEvent(regular, uID .. "KTrail")
			s.kai.ServerEvent(regular, uID .. "KShine")
			s.kai.getDonorCache()[owner.UserId] = nil
			s.kai.f.Chatted(owner, ":crownrainbow", false)
			sert.eq(owner:GetAttribute("KCrownRainbow"), nil)
			s.env:advance(1.5)
			s.kai.getDonorCache()[owner.UserId] = 4
			s.kai.f.Chatted(owner, ":crownrainbow", false)
			sert.eq(owner:GetAttribute("KCrownRainbow"), true)

			-- 2. VIP command by non-VIP triggers pcall-wrapped PromptBulkPurchase (and falls back to PromptPurchase on error)
			local guest = s.env:addPlayer(52, "NoVipGuest");
			(s.env :: AnyTable)._failBulkPrompt = true
			s.kai.f.Chatted(guest, ":shine", false)
			s.env:advance(1.5)
			sert.eq(#s.promptedSingle, 1)
			sert.eq(s.promptedSingle[1].assetId, 88978146769822)

			-- When Set.AdminCredit is false, VIP prompt is suppressed
			table.clear(s.promptedSingle)
			s.kai.getSet().AdminCredit = false
			s.env:advance(11)
			s.kai.f.Chatted(guest, ":shine", false)
			s.env:advance(1.5)
			sert.eq(#s.promptedSingle, 0)

			-- 3. :place reads returned KPrivateServers table from GlobalDataStore and teleports player
			s.kai.f.Chatted(owner, ":place me lobby", false)
			sert.eq(#s.reservedTeleports, 1)
			sert.eq(s.reservedTeleports[1].placeId, 555000)
			sert.eq(s.reservedTeleports[1].code, "RES_CODE_123")

			-- 4. :hat guards nil GetProductInfoAsync result without throwing
			s.env:advance(1.5)
			local char = s.env.Instance.new("Model", s.env.workspace)
			char.Name = owner.Name
			s.env.Instance.new("Part", char).Name = "Head"
			owner.Character = char
			s.env:setProductInfo(99999999, nil)
			s.kai.f.Chatted(owner, ":hat me 99999999", false)

			-- 5. KDelete / KPaste blocks TextChatService, services, and RemoteEvent while allowing normal Workspace parts
			local tcs = s.env.game:GetService("TextChatService")
			local safePart = s.env.Instance.new("Part", s.env.workspace)
			safePart.Name = "SafeDeletablePart"

			s.kai.ServerEvent(owner, uID .. "KDelete", tcs)
			s.kai.ServerEvent(owner, uID .. "KDelete", s.kai.RemoteEvent)
			sert.eq(tcs.Parent, s.env.game)
			sert.eq(s.kai.RemoteEvent.Parent, s.env.game:GetService("ReplicatedStorage"))

			s.kai.ServerEvent(owner, uID .. "KDelete", safePart)
			sert.eq(safePart.Parent, nil)
		end
	)

	headlessTest(
		"KAI Client & Serialized_Credit: non-overlapping Join button, AutocompleteVisible, non-slash echo, CLogs gating/UTF-8/RichText, and KBans sort",
		function()
			local c = getKaiClient()
			local tcs = c.env.game:GetService("TextChatService")
			local plr = c.env.LocalPlayer

			-- 1. Serialized_Credit regression checks: Join button below D5 (Y=288) and UIGradient parented to T4
			local main = c.creditTemplate:FindFirstChild("Main")
			local bg = if main then main:FindFirstChild("BG") else nil
			local joinBtn = if main then main:FindFirstChild("Join") else nil
			local t4 = if bg then bg:FindFirstChild("T4") else nil
			sert.eq(joinBtn ~= nil, true)
			sert.eq(joinBtn.Position, c.env.UDim2.fromOffset(0, 288))
			sert.eq(t4 ~= nil and t4:FindFirstChildOfClass("UIGradient") ~= nil, true)

			-- 2. Create TextChatCommands_KAI before KuID and verify AutocompleteVisible updates by local power
			local folder = c.env.Instance.new("Folder")
			folder.Name = "TextChatCommands_KAI"
			local helpCmd = c.env.Instance.new("TextChatCommand")
			helpCmd.Name = "KAI_help"
			helpCmd.PrimaryAlias = ":help"
			helpCmd.AutocompleteVisible = false
			helpCmd:SetAttribute("Power", 0)
			helpCmd.Parent = folder
			local flyCmd = c.env.Instance.new("TextChatCommand")
			flyCmd.Name = "KAI_fly"
			flyCmd.PrimaryAlias = "/fly"
			flyCmd.SecondaryAlias = ":fly"
			flyCmd.AutocompleteVisible = false
			flyCmd:SetAttribute("Power", 2)
			flyCmd.Parent = folder
			folder.Parent = tcs
			c.env:flush()

			-- Before KuID (clientReady == false), MessageReceived does NOT record CLogs
			tcs.MessageReceived:Fire({
				Status = c.env.Enum.TextChatMessageStatus.Success,
				TextSource = { UserId = plr.UserId },
				Text = "Early unready chat",
				Metadata = "",
			})
			sert.eq(#c.client.CLogs, 0)

			-- Initialize client as non-admin with PublicLogs = false
			c.admstr.Value = ""
			c.client.ClientEvent("KuID", {
				"UID_" :: any,
				{} :: any,
				{
					Color = c.env.Color3.new(),
					ColorTransparency = 0.8,
					AdminCredit = true,
					CommandBar = true,
					FunCommands = true,
					PublicLogs = false,
					Prefix = ":",
				} :: any,
				{} :: any,
				{} :: any,
			})
			sert.eq(helpCmd.AutocompleteVisible, true)
			sert.eq(flyCmd.AutocompleteVisible, false)

			-- Non-admin with PublicLogs == false still does NOT accumulate CLogs
			tcs.MessageReceived:Fire({
				Status = c.env.Enum.TextChatMessageStatus.Success,
				TextSource = { UserId = plr.UserId },
				Text = "Blocked for non-admin",
				Metadata = "",
			})
			sert.eq(#c.client.CLogs, 0)

			-- Promote local player to power 3 -> flyCmd AutocompleteVisible becomes true & CLogs start recording
			c.admstr.Value = `{plr.UserId}:3`
			c.env:flush()
			sert.eq(flyCmd.AutocompleteVisible, true)

			-- Non-slash Triggered skips echo when ChatTranslationEnabled is true, and echoes to RBXGeneral when false; slash Triggered never echoes
			table.clear(c.sentChannelMessages)
			rawset(tcs, "_props", rawget(tcs, "_props") or {})
			tcs._props.ChatTranslationEnabled = true
			flyCmd.Triggered:Fire({ UserId = plr.UserId }, ":fly me")
			c.env:advance(0.05)
			sert.eq(#c.sentChannelMessages, 0)

			tcs._props.ChatTranslationEnabled = false
			flyCmd.Triggered:Fire({ UserId = plr.UserId }, "/fly me")
			c.env:advance(0.05)
			sert.eq(#c.sentChannelMessages, 0)

			flyCmd.Triggered:Fire({ UserId = plr.UserId }, ":fly me")
			c.env:advance(0.05)
			sert.eq(#c.sentChannelMessages, 1)
			sert.eq(c.sentChannelMessages[1].text, ":fly me")
			sert.eq(c.sentChannelMessages[1].metadata, "KAI_CommandEcho")

			-- CLogs skips KAI_CommandEcho, enabled custom command ":fly", and "/e dance", but ALLOWS normal metadata & "/everyone"
			for _, msg in
				{
					{ text = ":fly me", meta = "KAI_CommandEcho" },
					{ text = ":fly fallback", meta = "" },
					{ text = "/e dance", meta = "" },
					{ text = "/EMOTE wave", meta = "" },
				}
			do
				tcs.MessageReceived:Fire({
					Status = c.env.Enum.TextChatMessageStatus.Success,
					TextSource = { UserId = plr.UserId },
					Text = msg.text,
					Metadata = msg.meta,
				})
			end
			sert.eq(#c.client.CLogs, 0)

			-- RichText entities unescaped, custom Metadata allowed, and UTF-8 multi-byte emoji safely truncated without splitting codepoints
			local longEmoji = string.rep("🔥", 210)
			tcs.MessageReceived:Fire({
				Status = c.env.Enum.TextChatMessageStatus.Success,
				TextSource = { UserId = plr.UserId },
				Text = "/everyone &lt;b&gt;Hi &amp; Welcome&lt;/b&gt;",
				Metadata = "CustomChatTag",
			})
			tcs.MessageReceived:Fire({
				Status = c.env.Enum.TextChatMessageStatus.Success,
				TextSource = { UserId = plr.UserId },
				Text = longEmoji,
				Metadata = "",
			})
			sert.eq(#c.client.CLogs, 2)
			sert.eq(string.find(tostring(c.client.CLogs[2][2]), "/everyone <b>Hi & Welcome</b>", 1, true) ~= nil, true)
			sert.eq(utf8.len(tostring(c.client.CLogs[1][2])) ~= nil, true)

			-- Client KMsg, KHint, KNotify, and KBans numeric/nil sort safety
			c.banstr.Value = "101:1 102:2"
			c.env:flush()
			c.client.f.getNamesFromIds = function(_ids: { number })
				return {
					{ Id = 101, Username = "BannedOne" },
					{ Id = 102, Username = "BannedTwo" },
					{ Id = 999, Username = "UnbannedNilEntry" },
				}
			end
			c.env.task.spawn(function()
				c.client.ClientEvent("KBans")
				c.client.ClientEvent("KNotify", "Sticky Client Notice")
			end)
			c.env:advance(0.5)
			sert.eq(c.client.CoreUI:FindFirstChild("Bans") ~= nil, true)
			sert.eq(c.client.CoreUI:FindFirstChild("Notify") ~= nil, true)
			sert.eq(c.client.CoreUI:FindFirstChild("Notify").BG.Text, "Sticky Client Notice")
		end
	)
end)

-- ============================================================================
-- Roblox Studio Server Specs (MainModuleLegacy / KAI)
-- ============================================================================

describe("Studio · Server", function()
	serverTest(
		"MainModuleLegacy creates TextChatCommands_KAI, syncs prefixes, runs Triggered & _G.KServerCommand, and enforces KMsg/KHint cooldowns",
		function()
			local Players = game:GetService("Players")
			local ReplicatedStorage = game:GetService("ReplicatedStorage")
			local ServerScriptService = game:GetService("ServerScriptService")
			local TextChatService = game:GetService("TextChatService")

			local mainModule = ServerScriptService:FindFirstChild("MainModule")
			local kaiSource = if mainModule then mainModule:FindFirstChild("KAI") else nil
			local kaiTesting = ServerScriptService:FindFirstChild("KAI_Testing")
			sert.eq(kaiSource ~= nil, true)
			sert.eq(kaiTesting ~= nil, true)
			if not kaiSource or not kaiTesting then
				return
			end

			local loaderClone = kaiTesting:Clone()
			loaderClone.Name = "Kohl's Admin Infinite"
			loaderClone.Parent = ServerScriptService

			local kaiClone = kaiSource:Clone()
			local toolsSource = if mainModule then mainModule:FindFirstChild("Tools") else nil
			if toolsSource and not kaiClone:FindFirstChild("Tools") then
				toolsSource:Clone().Parent = kaiClone
			end

			local okReq, reqResult = pcall(require, kaiClone)
			sert.eq(okReq, true)
			sert.eq(reqResult, true)

			local kai = shared._KAI_INTERNAL
			sert.eq(type(kai), "table")

			local okTest, testErr = pcall(function(): any
				local folder = TextChatService:FindFirstChild("TextChatCommands_KAI")
				sert.eq(folder ~= nil, true)
				if not folder then
					return false
				end

				-- Modern KA (`TextChatCommands_KA`) owns `/fly` and `;fly`, so KAI avoids collision on `fly`
				-- while claiming `/faq` + `;faq` for KAI-unique commands!
				sert.eq(folder:FindFirstChild("KAI_fly"), nil)
				local faqCmd = folder:FindFirstChild("KAI_faq") :: TextChatCommand?
				sert.eq(faqCmd ~= nil, true)
				if faqCmd then
					sert.eq(faqCmd.PrimaryAlias, "/faq")
					sert.eq(faqCmd.SecondaryAlias, ";faq")
				end

				local player = Players:GetPlayers()[1]
				sert.eq(player ~= nil, true)
				if player then
					local uID = kai.f.uID
					kai.getAdmins()[player.UserId] = 7

					-- Update Prefix to "!" and verify PrimaryAlias / SecondaryAlias resync
					-- (`/fly` is still owned by TextChatCommands_KA, so KAI_fly claims `!fly`!)
					kai.ServerEvent(player, uID .. "KUpdate", { IGS = true, Prefix = "!" })
					sert.eq(kai.getSet().Prefix, "!")
					local flyCmd = folder:FindFirstChild("KAI_fly") :: TextChatCommand?
					local helpCmd = folder:FindFirstChild("KAI_help") :: TextChatCommand?
					sert.eq(flyCmd ~= nil, true)
					sert.eq(helpCmd ~= nil, true)
					if flyCmd and helpCmd and faqCmd then
						sert.eq(flyCmd.PrimaryAlias, "!fly")
						sert.eq(flyCmd.SecondaryAlias, "")
						sert.eq(helpCmd.PrimaryAlias, "!help")
						sert.eq(faqCmd.PrimaryAlias, "/faq")
						sert.eq(faqCmd.SecondaryAlias, "!faq")
					end

					-- Unchanged Prefix update does NOT consume cooldown, so switching to "?" works cleanly
					kai.clearCooldowns()
					kai.ServerEvent(player, uID .. "KUpdate", { IGS = true, Prefix = "!" })
					kai.ServerEvent(player, uID .. "KUpdate", { IGS = true, Prefix = "?" })
					sert.eq(kai.getSet().Prefix, "?")
					if flyCmd and helpCmd and faqCmd then
						sert.eq(flyCmd.PrimaryAlias, "?fly")
						sert.eq(helpCmd.PrimaryAlias, "?help")
						sert.eq(faqCmd.SecondaryAlias, "?faq")
					end

					-- Switching Prefix to ":" yields `:fly` back to modern KA (`Settings.prefix = { ";", ":" }`)
					-- while keeping `:faq` on KAI-unique `KAI_faq`
					kai.clearCooldowns()
					kai.ServerEvent(player, uID .. "KUpdate", { IGS = true, Prefix = ":" })
					sert.eq(kai.getSet().Prefix, ":")
					sert.eq(folder:FindFirstChild("KAI_fly"), nil)
					if faqCmd then
						sert.eq(faqCmd.PrimaryAlias, "/faq")
						sert.eq(faqCmd.SecondaryAlias, ":faq")
					end

					-- _G.KServerCommand sticky :notify and :unnotify
					local globalEnv = _G :: any
					globalEnv.KServerCommand(":notify Studio KAI Sticky")
					sert.eq(kai.getActiveNotify() ~= nil, true)
					globalEnv.KServerCommand(":unnotify")
					sert.eq(kai.getActiveNotify(), nil)

					-- Broadcast KMsg / KHint cooldown enforcement
					kai.clearCooldowns()
					sert.eq(kai.f.cooldown(player.UserId, "announce"), true)
					sert.eq(kai.f.cooldown(player.UserId, "announce"), false)
					kai.clearCooldowns()
				end
				return true
			end)

			-- Clean up legacy instances and connections so modern KA Studio specs remain isolated
			if kai and type(kai.shutdown) == "function" then
				kai.shutdown()
			end
			pcall(function()
				loaderClone:Destroy()
			end)
			pcall(function()
				kaiClone:Destroy()
			end)
			local tcsFolder = TextChatService:FindFirstChild("TextChatCommands_KAI")
			if tcsFolder then
				tcsFolder:Destroy()
			end
			local legacyClient = ReplicatedStorage:FindFirstChild("\n\a\n")
			if legacyClient then
				legacyClient:Destroy()
			end
			local legacyRemote = ReplicatedStorage:FindFirstChild("b\a\n\a\n\a")
			if legacyRemote then
				legacyRemote:Destroy()
			end
			shared._KAI_INTERNAL = nil

			if not okTest then
				error(testErr, 0)
			end
		end
	)
end)

do
	return {}
end
