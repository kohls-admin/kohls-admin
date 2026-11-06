local Harness = require("./Harness")
local sert = require("../sert")

local describe, test, expect = sert.describe, sert.test, sert.expect

describe("Chat and Server", function()
	describe("Chat · RichText Restoration, Rate-Limiting & Channel Routing", function()
		test(
			"Chat.restoreRichText restores allowed tags/font attributes, supports compact mode, and rejects malformed markup",
			function()
				local h = Harness.newEnv()
				local Util = h:requireUtil()
				local Chat = h:requireShared("Chat")
				local esc = Util.String.escapeRichText

				-- 1. Valid simple tags (b, i, u, s, sc, uc, br)
				local simple =
					esc("<b>bold</b> <i>italic</i> <u>under</u> <s>strike</s> <sc>small</sc> <uc>upper</uc><br/>line2")
				expect(Chat.restoreRichText(simple)).toBe(
					"<b>bold</b> <i>italic</i> <u>under</u> <s>strike</s> <sc>small</sc> <uc>upper</uc><br />line2"
				)

				-- 2. Valid <font> with hex color (#rrggbb and #rgb), rgb(r,g,b), clamped size, and transparency
				local fontHex = esc('<font color="#ff0000" size="20" transparency="0.5">red</font>')
				expect(Chat.restoreRichText(fontHex)).toBe(
					'<font color="#ff0000" size="20" transparency="0.5">red</font>'
				)

				local fontShortAndRgb =
					esc('<font color="#0f0">green</font> <font color="rgb(255,128,0)" size="99">clamped</font>')
				expect(Chat.restoreRichText(fontShortAndRgb)).toBe(
					'<font color="#0f0">green</font> <font color="rgb(255,128,0)" size="40">clamped</font>'
				)

				-- 3. Compact mode: strips <br/> to space and drops font size (inserting transparency="0" if size was sole attribute)
				local compactInput =
					esc('<font size="24">big</font><br/><font color="#ff0000" size="24">colored</font>')
				expect(Chat.restoreRichText(compactInput, true)).toBe(
					'<font transparency="0">big</font> <font color="#ff0000">colored</font>'
				)

				-- 4. Rejects unbalanced tags, disallowed tags (<script>), and invalid <font> attributes (face, weight, bad color)
				local unbalanced = esc("<b>hello</i>")
				expect(Chat.restoreRichText(unbalanced)).toBe(unbalanced)

				local unclosed = esc("<b>hello")
				expect(Chat.restoreRichText(unclosed)).toBe(unclosed)

				local scriptTag = esc("<script>evil()</script>")
				expect(Chat.restoreRichText(scriptTag)).toBe(scriptTag)

				local badFont = esc('<font color="#ff0000" size="20" face="Gotham" weight="Bold">bad attrs</font>')
				expect(Chat.restoreRichText(badFont)).toBe(badFont)

				local badRgb = esc('<font color="rgb(999,0,0)">overflow</font>')
				expect(Chat.restoreRichText(badRgb)).toBe(badRgb)
			end
		)

		test("Chat.cooldown, Chat.limitBroadcast, and Chat.limitReason enforce rate limits and permissions", function()
			local h = Harness.newEnv({ isStudio = false })
			local Auth = h:requireAuth()
			local Chat = h:requireShared("Chat")
			local Remote = h:requireRemote()

			local guest = h.env:addPlayer(10, "GuestPlr")
			local admin = h.env:addPlayer(20, "AdminPlr")
			Auth.userRoleAdd(admin.UserId, "admin")

			-- cooldown returns nil first, then wait string, then nil after duration expires
			expect(Chat.cooldown(guest.UserId, "customKey", 5)).toBeNil()
			local waitMsg = Chat.cooldown(guest.UserId, "customKey", 5)
			expect(type(waitMsg)).toBe("string")
			expect(string.find(waitMsg :: string, "Wait", 1, true) ~= nil).toBe(true)
			h.env:step(5.5)
			expect(Chat.cooldown(guest.UserId, "customKey", 5)).toBeNil()

			-- limitBroadcast checks CanUserChatAsync and enforces the announce cooldown
			expect(Chat.limitBroadcast(admin.UserId)).toBeNil()
			expect(Chat.limitBroadcast(admin.UserId) ~= nil).toBe(true)

			-- limitReason checks nil, CanUserChatAsync, and reason cooldown (notifying player when rate-limited)
			expect(Chat.limitReason(admin.UserId, nil)).toBeNil()
			local tcs = h.env.game:GetService("TextChatService")
			local tcsMethods = rawget(tcs, "_methods")
			local origCanUsersChat = tcsMethods.CanUsersChatAsync
			-- When all target players can chat with admin, limitReason doesn't spend the cooldown
			local allowedReason, restrictedReason = Chat.limitReason(admin.UserId, "Friendly kick", { guest })
			expect(allowedReason).toBe("Friendly kick")
			expect(restrictedReason).toBe("Friendly kick")

			expect(Chat.limitReason(admin.UserId, "First valid reason")).toBe("First valid reason")

			local notifiedReason = nil
			Remote.Notify.Fire = function(_self, _plr, payload)
				notifiedReason = payload.Text
			end
			expect(Chat.limitReason(admin.UserId, "Second rate-limited reason")).toBeNil()
			expect(string.find(tostring(notifiedReason), "Reason removed:", 1, true) ~= nil).toBe(true)

			-- When cooling down with a restricted target, chat-allowed targets still get allowedReason while restricted get nil
			tcsMethods.CanUsersChatAsync = function(_self, _from, to)
				return to ~= guest.UserId
			end
			local allowedOnCd, restrictedOnCd = Chat.limitReason(admin.UserId, "Partial kick reason", { guest })
			expect(allowedOnCd).toBe("Partial kick reason")
			expect(restrictedOnCd).toBeNil()
			tcsMethods.CanUsersChatAsync = origCanUsersChat

			-- CanUserChatAsync returning false blocks limitReason and limitBroadcast
			local origCanChat = tcsMethods.CanUserChatAsync
			tcsMethods.CanUserChatAsync = function()
				return false
			end
			expect(Chat.limitBroadcast(guest.UserId)).toBe("User cannot chat")
			expect(Chat.limitReason(guest.UserId, "Blocked by privacy")).toBeNil()
			tcsMethods.CanUserChatAsync = origCanChat
		end)

		test("Chat.send filters for broadcast and enforces 60s per-sender cooldown over Remote.ChatSystem", function()
			local h = Harness.newEnv({ isStudio = false })
			local Auth = h:requireAuth()
			local Chat = h:requireShared("Chat")
			local Remote = h:requireRemote()
			local Util = h:requireUtil()
			local tcs = h.env.game:GetService("TextChatService")
			local tcsMethods = rawget(tcs, "_methods")
			local textMethods = rawget(h.env.game:GetService("TextService"), "_methods")

			local sender = h.env:addPlayer(101, "SenderAdmin")
			local target = h.env:addPlayer(102, "TargetUser")
			local friend = h.env:addPlayer(103, "BystanderUser")
			Auth.userRoleAdd(sender.UserId, "admin")
			local context = { from = sender.UserId, fromPlayer = sender }

			-- sender can chat with friend (103), but cannot chat with target (102)
			tcsMethods.CanUsersChatAsync = function(_self, _from, to)
				return to ~= target.UserId
			end

			local packets = {}
			Remote.ChatSystem.Fire = function(_self, plr, kind, text, from, data, id)
				table.insert(packets, { to = plr.UserId, kind = kind, text = text, from = from, data = data, id = id })
			end
			local function reached(list: { any }?): { number }
				local ids, items: { any } = {}, list or packets
				for _, item in items do
					table.insert(ids, item.UserId or item.to)
				end
				table.sort(ids)
				return ids
			end
			local filtered = {}
			textMethods.FilterStringAsync = function(_self, text, fromUserId, filterContext)
				table.insert(filtered, { text = text, from = fromUserId, context = filterContext })
				local result = string.gsub(text, "badword", "#######")
				return {
					GetNonChatStringForBroadcastAsync = function()
						return result
					end,
				}
			end

			-- a sender who isn't in the server can't send
			local badId, badErr = Chat.send({ from = 99999 }, "announce", "ghost")
			expect(badId).toBeNil()
			expect(string.find(tostring(badErr), "must be run by a player", 1, true) ~= nil).toBe(true)

			-- everyone gets the text TextService filtered for broadcast, and freeText command args get the filtered text with redactLog = false
			local rawText = "Hello <b>now</b> badword"
			local argObj = {
				rawArg = rawText,
				parsedArgs = { rawText },
				rawType = { freeText = true },
				redactLog = nil :: boolean?,
			}
			local cmdCtx = { from = sender.UserId, fromPlayer = sender, args = { argObj } }
			local id, err, delivered = Chat.send(cmdCtx, "message", rawText, nil, 7)
			expect(type(id)).toBe("string")
			expect(err).toBeNil()
			expect(reached(delivered)).toEqual({ 101, 102, 103 })
			expect(reached()).toEqual({ 101, 102, 103 })
			expect(argObj.parsedArgs).toEqual({ "Hello <b>now</b> #######" })
			expect(argObj.redactLog).toBe(false)
			expect(filtered).toEqual({
				{
					text = rawText,
					from = 101,
					context = h.env.globals.Enum.TextFilterContext.PublicChat,
				},
			})
			for _, packet in packets do
				expect(packet.kind).toBe("message")
				expect(packet.text).toBe(Util.String.escapeRichText("Hello <b>now</b> #######"))
				expect(packet.from).toBe(101)
				expect(packet.data).toBe(7)
				expect(packet.id).toBe(id)
			end
			-- nothing goes through TextChannels
			for _, child in tcs:GetDescendants() do
				expect(child:IsA("TextChannel")).toBe(false)
			end
			expect(Chat.isChannel).toBeNil()
			expect(Chat.canReply).toBeNil()

			-- messaging players the sender can chat with is never limited, while restricted players are limited to 1/60s
			table.clear(packets)
			local limitedId, limitedErr = Chat.send(context, "hint", "Too soon", { target })
			expect(limitedId).toBeNil()
			expect(string.find(tostring(limitedErr), "Wait", 1, true) ~= nil).toBe(true)
			expect(#packets).toBe(0)

			-- broadcasting to both restricted and chat-allowed players while on cooldown skips restricted and delivers to allowed
			local skipNotices = {}
			Remote.Notify.Fire = function(_self, plr, payload)
				table.insert(skipNotices, { to = plr.UserId, text = payload.Text })
			end
			local partialId, partialErr, partialDelivered = Chat.send(context, "message", "Partial broadcast")
			expect(type(partialId)).toBe("string")
			expect(partialErr).toBeNil()
			expect(reached(partialDelivered)).toEqual({ 101, 103 })
			expect(reached()).toEqual({ 101, 103 })
			expect(#skipNotices).toBe(1)
			expect(string.find(skipNotices[1].text, "Players you can't chat with were skipped.", 1, true) ~= nil).toBe(
				true
			)

			-- messaging only yourself or a player you can chat with is never limited
			table.clear(packets)
			local _, _, friendOnly = Chat.send(context, "hint", "Friend", { friend })
			expect(reached(friendOnly)).toEqual({ 103 })
			table.clear(packets)
			local _, _, selfOnly = Chat.send(context, "hint", "Self", { sender })
			expect(reached(selfOnly)).toEqual({ 101 })
			local voteId, voteErr, voters = Chat.send(context, "vote", "Own timer?", { target })
			expect(type(voteId)).toBe("string")
			expect(voteErr).toBeNil()
			expect(reached(voters)).toEqual({ 102 })
			h.env:step(61)

			-- a sender who can't chat sends nothing and keeps their cooldown
			tcsMethods.CanUserChatAsync = function()
				return false
			end
			local blockedId, blockedErr = Chat.send(context, "message", "Blocked")
			expect(blockedId).toBeNil()
			expect(blockedErr).toBe("User cannot chat")
			tcsMethods.CanUserChatAsync = function()
				return true
			end

			-- text that can't be filtered isn't sent and does not spend the cooldown
			table.clear(packets)
			textMethods.FilterStringAsync = function()
				error("filter down")
			end
			local unfilteredId, unfilteredErr = Chat.send(context, "message", "Unfiltered")
			expect(unfilteredId).toBeNil()
			expect(string.find(tostring(unfilteredErr), "filtered", 1, true) ~= nil).toBe(true)
			textMethods.FilterStringAsync = function()
				return {
					GetNonChatStringForBroadcastAsync = function()
						error("broadcast filter down")
					end,
				}
			end
			expect((Chat.send(context, "message", "Unfiltered"))).toBeNil()
			expect(#packets).toBe(0)
			-- cooldown was not spent by filter failures, so once filtering recovers it sends immediately
			textMethods.FilterStringAsync = function(_self, text)
				return {
					GetNonChatStringForBroadcastAsync = function()
						return text
					end,
				}
			end
			local recoveredId, recoveredErr, recoveredDelivered =
				Chat.send(context, "message", "Recovered after filter error", { target })
			expect(type(recoveredId)).toBe("string")
			expect(recoveredErr).toBeNil()
			expect(reached(recoveredDelivered)).toEqual({ 102 })
			table.clear(packets)

			-- global messages were already filtered in their origin server
			local globalId, globalErr, globalDelivered =
				Chat.send({ global = true, from = 999 }, "announce", "<b>see</b> global", nil, 10)
			expect(type(globalId)).toBe("string")
			expect(globalErr).toBeNil()
			expect(reached(globalDelivered)).toEqual({ 101, 102, 103 })
			expect(packets[1].text).toBe(Util.String.escapeRichText("<b>see</b> global"))
			expect(packets[1].from).toBe(999)
		end)

		test("Chat.send skips CanUserChatAsync for a developer testing in Studio", function()
			local h = Harness.newEnv({ isStudio = true })
			local Auth = h:requireAuth()
			local Chat = h:requireShared("Chat")
			local Remote = h:requireRemote()
			local tcsMethods = rawget(h.env.game:GetService("TextChatService"), "_methods")
			local sender = h.env:addPlayer(101, "Developer")
			local other = h.env:addPlayer(102, "Tester")
			Auth.userRoleAdd(sender.UserId, "creator")
			tcsMethods.CanUserChatAsync = function()
				return false
			end
			local reached = {}
			Remote.ChatSystem.Fire = function(_self, plr)
				table.insert(reached, plr.UserId)
			end
			Chat.send({ from = 101, fromPlayer = sender }, "message", "Studio test")
			table.sort(reached)
			expect(reached).toEqual({ 101, 102 })
			-- other senders are still checked
			table.clear(reached)
			local _, err = Chat.send({ from = 102, fromPlayer = other }, "message", "Not a developer")
			expect(err).toBe("User cannot chat")
			expect(#reached).toBe(0)
		end)

		test("Chat.commandPrefixes keeps single non-alphanumeric characters once", function()
			local Chat = Harness.newEnv():requireShared("Chat")
			expect(Chat.commandPrefixes({ ";", ":", ";", "a", "1", " ", "!!", 5 :: any, "/" })).toEqual({
				";",
				":",
				"/",
			})
			expect(Chat.commandPrefixes(nil)).toEqual({})
		end)

		test("Client Chat dispatches Remote.ChatSystem messages and leaves TextChannels alone", function()
			local world = sert.sim.new({ backing = true })
			local server = world:server()
			local client = server:client(101)

			local sh = Harness.newPeerEnv(server, { isStudio = false })
			local ch = Harness.newPeerEnv(client, { isClient = true })

			local sChat = sh:requireShared("Chat")
			local sRemote = sh:requireRemote()
			local cChat = ch:requireShared("Chat")
			world:run(1)

			local srvPlr = sh.env.Players:GetPlayerByUserId(101)
			local receivedMsgs = {}
			cChat.onMessage("announce", function(text, from, data, id)
				table.insert(receivedMsgs, { text = text, from = from, data = data, id = id })
			end)

			-- 1. Pre-registered waitForMessage wakes up when message arrives
			local preWaitedText = nil
			client:spawn(function()
				preWaitedText = cChat.waitForMessage("pre-wait-id", 5)
			end)
			world:run(0.1)
			sRemote.ChatSystem:Fire(srvPlr, "announce", "&lt;b&gt;PreWaited&lt;/b&gt;", 999, 10, "pre-wait-id")
			-- Duplicate id is ignored
			sRemote.ChatSystem:Fire(srvPlr, "announce", "&lt;b&gt;Duplicate&lt;/b&gt;", 999, 10, "pre-wait-id")
			world:run(0.2)
			expect(preWaitedText).toBe("<b>PreWaited</b>")
			expect(#receivedMsgs).toBe(1)

			-- 2. Global/System dispatch via Remote.ChatSystem caches in received[id] for subsequent waitForMessage
			local waitedText = nil
			local sysId = nil
			server:spawn(function()
				sysId = sChat.send(
					{ global = true, from = 999 },
					"announce",
					'<b>Hello</b> <font color="#00ff00">Client</font>',
					{ srvPlr },
					15
				)
			end)
			world:run(0.2)
			client:spawn(function()
				waitedText = cChat.waitForMessage(sysId, 2)
			end)
			world:run(1)

			expect(waitedText).toBe('<b>Hello</b> <font color="#00ff00">Client</font>')
			expect(#receivedMsgs).toBe(2)
			expect(receivedMsgs[2].text).toBe('<b>Hello</b> <font color="#00ff00">Client</font>')
			expect(receivedMsgs[2].from).toBe(999)
			expect(receivedMsgs[2].data).toBe(15)

			-- 3. waitForMessage timeout returns nil when id never arrives
			local timedOutVal = "unset"
			client:spawn(function()
				timedOutVal = cChat.waitForMessage("nonexistent-id", 0.2)
			end)
			world:run(0.5)
			expect(timedOutVal).toBeNil()

			-- 4. TextChannels are never touched: OnIncomingMessage can't be set and message text is empty with
			-- platform-integrated chat
			local cTcs = ch.env.game:GetService("TextChatService")
			local kaChannel = ch.env.Instance.new("TextChannel")
			kaChannel.Name = "Admin"
			kaChannel:SetAttribute("KohlsAdmin", true)
			kaChannel.Parent = cTcs
			world:run(0.1)
			expect(kaChannel.OnIncomingMessage).toBeNil()
			local HttpService = ch.env.game:GetService("HttpService")
			kaChannel.MessageReceived:Fire({
				MessageId = "m-1",
				Metadata = HttpService:JSONEncode({ k = "announce", id = "chan-msg-1", d = 5 }),
				Text = "",
				Status = ch.env.globals.Enum.TextChatMessageStatus.Success,
				TextSource = { UserId = 101 },
			})
			world:run(0.2)
			expect(#receivedMsgs).toBe(2)
			expect(cChat.onMessage ~= nil and cChat.send == nil).toBe(true)

			-- Advance past 30s to trigger received[id] cleanup timers
			world:run(31)
		end)
	end)

	describe("Server · Initialization, Character Damage/Death Logs, Remotes & Servers", function()
		test(
			"Server initializes _K, batches character damage & kill/death logs, and handles Remote endpoints and Servers",
			function()
				local world = sert.sim.new({
					mode = "random",
					faults = "none",
					backing = true,
					latency = { DataStoreService = 0.01, MemoryStoreService = 0.01, MessagingService = 0.01 },
				})
				local server = world:server({ jobId = "server-job-1" })
				local adminClient = server:client(101)
				local guestClient = server:client(202)
				local modClient = server:client(301)

				local sh = Harness.newPeerEnv(
					server,
					{ isStudio = false, creatorId = 101, jobId = "server-job-1", placeId = 1000 }
				)
				sert.spy(sh.env.Players, "GetFriendsAsync", function()
					return {
						IsFinished = true,
						GetCurrentPage = function()
							return { { Id = 202 } }
						end,
					}
				end)
				local badgesAwarded = 0
				local badgeService = sh.env.game:GetService("BadgeService")
				sert.spy(badgeService, "GetBadgeInfoAsync", function(_self, badgeId)
					return { IsEnabled = badgeId == 1234 }
				end)
				sert.spy(badgeService, "UserHasBadgeAsync", function()
					return false
				end)
				sert.spy(badgeService, "AwardBadge", function()
					badgesAwarded += 1
					return true
				end)
				local _K: any
				local roles = Harness.defaultRoles()
				roles.everyone.limits = { targetOthers = true }
				roles.vip.asset = { 555 }
				roles.vip.gamepass = { 666 }
				roles.vip.subscription = { "sub_inline" }
				roles.vip.commands = { ping = true }
				roles.mod.commands = { kick = true }

				server:spawn(function()
					_K = sh:requireK()
					-- Requiring _K a second time returns shared._K_INTERFACE (src/init.luau line 4)
					expect(sh:requireK()).toBe(_K)
					_K.initialize({
						bans = {
							["303"] = { nil, "preban reason", 0, 101 },
						},
						userRoles = {
							superadmin = { 101 },
							mod = { "ModByName", 301 },
							admin = {},
							vip = {},
							creator = {},
						},
						assetRoles = { [777] = { "vip" } },
						gamepassRoles = { [888] = { "vip" } },
						subscriptionRoles = { ["sub_vip"] = { "vip" } },
						groupRoles = {
							[100] = { { rank = 10, roles = { "mod" } }, { rank = 20 }, { roles = { "mod" } } },
							[200] = { rank = 5, roles = { "vip" } },
							[300] = { [15] = "mod", [25] = "nonexistent_role" },
						},
						friendRoles = { "vip" },
						announcement = { "Welcome to the server!", 101, 5 },
						welcomeBadgeId = 1234,
						vip = true,
						chatCommands = true,
						commandRequests = true,
						prefix = ";",
						splitKey = "%s",
						defaultTheme = "MigratedTheme",
						commands = {
							mod = { ban = true },
						},
						roles = {
							default = table.isfrozen(roles.everyone) and roles.everyone or (function()
								local r = table.clone(roles.everyone)
								r.name = "EveryoneCustom"
								return r
							end)(),
							[1] = roles.vip,
							[2] = roles.mod,
							[3] = roles.admin,
							[4] = roles.superadmin,
							customStr = {
								_rank = 5,
								name = "CustomRole",
								color = "#ffffff",
								permissions = {},
								groups = {},
							},
							customDef = {
								name = "DefaultedRole",
								color = "#eeeeee",
								onlyTargetSelf = true,
							},
							[math.huge] = roles.creator,
						},
					})
					-- Duplicate _K.initialize call returns _K immediately (line 111)
					expect(_K.initialize()).toBe(_K)
				end)
				world:run(2)
				expect(_K.ready).toBe(true)
				expect(sh.KA:GetAttribute("ServerStartTime") ~= nil).toBe(true)
				expect(_K.Server:FindFirstChild("Shared").Value).toBe(sh.KA.Shared)
				expect(sh.KA.Name).toBe("Kohl's Admin Source")
				expect(sh.KA.Parent).toBe(sh.env.game:GetService("ReplicatedStorage"))
				expect(sh.KA:FindFirstChild("Client").Enabled).toBe(true)
				expect(sh.KA:FindFirstChild("Addons") ~= nil).toBe(true)
				expect(sh.env.game:GetService("ServerStorage"):FindFirstChild("_KServerAddons") ~= nil).toBe(true)
				expect(_K.Data.bans["303"][1] ~= nil).toBe(true)
				expect(type(_K.LoadScript)).toBe("function")
				expect(type(_K.Data.settingsModuleData)).toBe("table")
				expect(_K.Data.settingsModuleData.roles.default).toBeNil()
				expect(_K.Data.settingsModuleData.roles[1]).toBeNil()
				expect(_K.Data.roles.everyone.name).toBe("EveryoneCustom")
				expect(_K.Data.roles.vip._rank).toBe(0)
				expect(_K.Data.roles.everyone.permissions.targetOthers).toBe(false)
				expect(_K.Data.roles.customStr._key).toBe("customStr")
				expect(_K.Data.roles.customStr.name).toBe("CustomRole")
				expect(_K.Data.roles.customStr.permissions.targetOthers).toBe(true)
				expect(_K.Data.roles.customDef._rank).toBe(0)
				expect(_K.Data.roles.customDef.permissions.targetOthers).toBe(false)
				expect(table.find(_K.Data.rolesList, _K.Data.roles.customStr) ~= nil).toBe(true)
				expect(_K.Data.rolesList[1]._rank <= _K.Data.rolesList[#_K.Data.rolesList]._rank).toBe(true)
				expect(_K.Data.defaultSettings.vip).toBe(true)
				expect(_K.Data.defaultSettings.splitKey).toBe(" ")
				expect(_K.Data.defaultSettings.welcomeBadgeId).toBe(1234)
				expect(_K.Data.settings).toBe(_K.Data.savedSettings)
				expect(_K.Data.roles.mod.commands.ban).toBe(true)
				expect(_K.Data.roles.mod.commands.kick).toBe(true)
				expect(badgesAwarded > 0).toBe(true)
				expect(_K.Data.async.asset[777]).toEqual({ "vip" })
				expect(_K.Data.async.gamepass[888]).toEqual({ "vip" })
				expect(_K.Data.async.subscription["sub_vip"]).toEqual({ "vip" })
				expect(table.find(_K.Data.roles.vip.assets, 777) ~= nil).toBe(true)
				expect(table.find(_K.Data.roles.vip.gamepasses, 888) ~= nil).toBe(true)
				expect(table.find(_K.Data.roles.vip.subscriptions, "sub_vip") ~= nil).toBe(true)
				expect(_K.Data.roles.vip.gamepasss ~= nil).toBe(true)
				expect(_K.Data.async.group[100]).toEqual({ { rank = 10, roles = { "mod" } } })
				expect(_K.Data.async.group[200]).toEqual({ { rank = 5, roles = { "vip" } } })
				expect(_K.Data.async.group[300]).toEqual({ { rank = 15, roles = { "mod" } } })
				expect(_K.Data.friendRoles).toEqual({ "vip" })
				expect(_K.Data.savedSettings.theme).toBe("MigratedTheme")

				-- _K.log edge cases: logsHidden, >16KB truncation, liveText, and removeExcessLogs (src/init.luau lines 106-162)
				_K.Data.logsHidden[9999] = true
				expect(_K.log("hidden", "INFO", 9999)).toBeNil()
				_K.Data.logsHidden[9999] = nil

				local bigLog = _K.log(string.rep("X", 17000), "COMMAND", 101, true, "live replacement")
				expect(bigLog ~= nil).toBe(true)
				local origLimit = _K.Logger.limit
				_K.Logger.limit = 5
				world:run(0.2)
				expect(#_K.Data.logs <= 5).toBe(true)
				_K.Logger.limit = origLimit

				-- _K.alert with number userId and Player instance, info and error modes (src/init.luau lines 172-188)
				_K.alert(101, "Info alert by userId", false)
				_K.alert(sh.env.Players:GetPlayerByUserId(101), "Error alert by Player", true)

				local adminEnv = Harness.newPeerEnv(adminClient, { isClient = true })
				local guestEnv = Harness.newPeerEnv(guestClient, { isClient = true })
				local modEnv = Harness.newPeerEnv(modClient, { isClient = true })
				local aRemote = adminEnv:requireRemote()
				local gRemote = guestEnv:requireRemote()
				local mRemote = modEnv:requireRemote()
				world:run(1)

				-- 1. Remote.Init listener for admin (101), guest (202), and mod (301) (plus HTTP disabled Games Hub notice)
				local HttpService = sh.env.game:GetService("HttpService")
				local httpMethods = rawget(HttpService, "_methods")
				local origGetAsync = httpMethods.GetAsync
				httpMethods.GetAsync = function()
					error("HTTP 403 Forbidden")
				end

				local adminInitPayload, guestInitPayload = nil, nil
				aRemote.Init:Connect(function(bans, logs, members, rRoles, reserved, servers, savedSet, defSet)
					adminInitPayload = {
						bans = bans,
						logs = logs,
						members = members,
						roles = rRoles,
						reserved = reserved,
						servers = servers,
						savedSettings = savedSet,
						defaultSettings = defSet,
					}
				end)
				gRemote.Init:Connect(function(bans, logs, members)
					guestInitPayload = {
						bans = bans,
						logs = logs,
						members = members,
					}
				end)

				aRemote.Init:Fire({ Attributes = { Platform = "PC", SessionStart = 1700000000 } })
				gRemote.Init:Fire({ Attributes = { Platform = "Mobile", SessionStart = 1700000005 } })
				-- ;whois shows _KPlatform as RichText, so only UI.Platform values and finite session starts are kept
				mRemote.Init:Fire({
					Attributes = { Platform = '<font size="99">Hacked</font>', SessionStart = math.huge },
				})
				world:run(4.5)
				httpMethods.GetAsync = origGetAsync

				local srvAdmin = sh.env.Players:GetPlayerByUserId(101)
				local srvGuest = sh.env.Players:GetPlayerByUserId(202)
				local srvMod = sh.env.Players:GetPlayerByUserId(301)
				expect(srvAdmin:GetAttribute("_K_READY")).toBe(true)
				expect(srvAdmin:GetAttribute("_KPlatform")).toBe("PC")
				expect(srvAdmin:GetAttribute("_KSessionStart")).toBe(1700000000)
				expect(srvGuest:GetAttribute("_K_READY")).toBe(true)
				expect(srvGuest:GetAttribute("_KPlatform")).toBe("Mobile")
				expect(srvMod:GetAttribute("_K_READY")).toBe(true)
				expect(srvMod:GetAttribute("_KPlatform")).toBeNil()
				expect(srvMod:GetAttribute("_KSessionStart")).toBeNil()

				expect(adminInitPayload ~= nil).toBe(true)
				expect(adminInitPayload.bans ~= nil).toBe(true)
				expect(adminInitPayload.logs ~= nil).toBe(true)
				expect(adminInitPayload.reserved ~= nil).toBe(true)
				expect(adminInitPayload.servers ~= nil).toBe(true)

				expect(guestInitPayload ~= nil).toBe(true)
				expect(guestInitPayload.bans).toBeNil()
				expect(guestInitPayload.logs).toBeNil()

				-- 1b. every command is a TextChatCommand: ";" with the name or an alias, then "/" where it is free
				local adminChar = sh.env.Instance.new("Model", sh.env.workspace)
				adminChar.Name = srvAdmin.Name
				local adminHead = sh.env.Instance.new("Part", adminChar)
				adminHead.Name = "Head"
				adminChar.PrimaryPart = adminHead
				sh.env.Instance.new("Humanoid", adminChar)
				srvAdmin.Character = adminChar

				local tcs = sh.env.game:GetService("TextChatService")
				local cmdFolder = tcs:FindFirstChild("TextChatCommands_KA")
				expect(cmdFolder ~= nil).toBe(true)
				local headless = cmdFolder:FindFirstChild("headless")
				expect(headless.PrimaryAlias).toBe("/headless")
				expect(headless.SecondaryAlias).toBe(";headless")
				expect(headless.Enabled).toBe(true)
				expect(headless.AutocompleteVisible).toBe(false)
				local ping = cmdFolder:FindFirstChild("ping")
				expect(ping.PrimaryAlias).toBe("/ping")
				expect(ping.SecondaryAlias).toBe(";ping")
				local bubbles = {}
				local bubbleConn = aRemote.DisplayBubble:Connect(function(_character, text)
					table.insert(bubbles, text)
				end)
				local guestBubbleFired = false
				local guestBubbleConn = gRemote.DisplayBubble:Connect(function()
					guestBubbleFired = true
				end)
				-- VIP commands show their alias above the speaker, other commands and other speakers don't
				headless.Triggered:Fire({ UserId = srvAdmin.UserId }, "/headless")
				headless.Triggered:Fire({ UserId = 99999 }, "/headless")
				ping.Triggered:Fire({ UserId = srvAdmin.UserId }, ";ping")
				-- long enough for the simulated latency to the other client
				world:run(1)
				bubbleConn:Disconnect()
				guestBubbleConn:Disconnect()
				expect(bubbles).toEqual({ ";headless" })
				expect(guestBubbleFired).toBe(true)

				-- later Inits are held to the same values
				for _, attributes in
					{ { Platform = "Desktop", SessionStart = 0 / 0 }, { Platform = 1, SessionStart = "1" } }
				do
					mRemote.Init:Fire({ Attributes = attributes })
				end
				world:run(1)
				expect(srvMod:GetAttribute("_KPlatform")).toBeNil()
				expect(srvMod:GetAttribute("_KSessionStart")).toBeNil()
				mRemote.Init:Fire({ Attributes = { Platform = "VR", SessionStart = -1700000010 } })
				world:run(1)
				expect(srvMod:GetAttribute("_KPlatform")).toBe("VR")
				expect(srvMod:GetAttribute("_KSessionStart")).toBe(-1700000010)

				-- 1c. PromptGamePassPurchaseFinished (false and true granting role, lines 438-462)
				local MarketplaceService = sh.env.game:GetService("MarketplaceService")
				MarketplaceService.PromptGamePassPurchaseFinished:Fire(srvGuest, 888, false)
				MarketplaceService.PromptGamePassPurchaseFinished:Fire(srvGuest, 888, true)
				world:run(0.2)

				-- an exploit can fake purchaseSuccess, so roles need ownership; a real purchase may show up late
				local marketMethods = rawget(MarketplaceService, "_methods")
				local origOwnsPass = marketMethods.UserOwnsGamePassAsync
				local passChecks, ownedFromCheck = 0, math.huge
				marketMethods.UserOwnsGamePassAsync = function(_self, userId, gamePassId)
					-- count only the server's role check; Shared/VIP checks the same pass for its own perks
					local fromServer = string.find(debug.info(2, "s"), "src/Server/init", 1, true)
					if not (fromServer and userId == 202 and gamePassId == 889) then
						return false
					end
					passChecks += 1
					return passChecks >= ownedFromCheck
				end
				_K.Data.async.gamepass[889] = { "mod" }
				MarketplaceService.PromptGamePassPurchaseFinished:Fire(srvGuest, 889, true)
				world:run(10)
				expect(_K.Auth.hasRole(202, "mod")).toBe(false)
				expect(passChecks).toBe(3) -- it gives up after three checks
				passChecks, ownedFromCheck = 0, 2
				MarketplaceService.PromptGamePassPurchaseFinished:Fire(srvGuest, 889, true)
				world:run(10)
				expect(_K.Auth.hasRole(202, "mod")).toBe(true)
				expect(passChecks).toBe(2)
				marketMethods.UserOwnsGamePassAsync = origOwnsPass
				_K.Auth.userRoleRemove(202, "mod")
				_K.Data.async.gamepass[889] = nil

				-- 2. Character damage batching & kill/death logs (with and without creator tag)
				local char = sh.env.Instance.new("Model", sh.env.workspace)
				char.Name = srvGuest.Name
				local hum = sh.env.Instance.new("Humanoid", char)
				hum._props.ApplyDescriptionFinished = sh.env:signal()
				hum.Health = 100
				local creatorTag = sh.env.Instance.new("ObjectValue", hum)
				creatorTag.Name = "creator"
				creatorTag.Value = srvAdmin
				srvGuest.Character = char
				srvGuest.CharacterAdded:Fire(char)
				world:run(0.1)

				-- Deal 25 + 15 = 40 batched damage from srvAdmin
				hum.Health = 75
				hum.HealthChanged:Fire(75)
				hum.Health = 60
				hum.HealthChanged:Fire(60)
				-- Step 1.5s to flush the 1s damage debounce
				world:run(1.5)

				-- Deal fatal damage (35) and fire Died
				hum.Health = 25
				hum.HealthChanged:Fire(25)
				hum.Health = 0
				hum.Died:Fire()
				world:run(0.5)

				-- Also test damage and death WITHOUT a creator tag (lines 53, 89) and WITH a non-Player Instance creator tag (line 54)
				local partAttacker = sh.env.Instance.new("Part")
				partAttacker.Name = "LavaBrick"
				creatorTag.Value = partAttacker
				hum.Health = 90
				hum.HealthChanged:Fire(90)
				world:run(1.5)
				creatorTag:Destroy()
				hum.Health = 80
				hum.HealthChanged:Fire(80)
				hum.Health = 0
				hum.Died:Fire()
				world:run(0.5)

				-- Character without Humanoid is ignored on CharacterAdded (line 39)
				local noHumChar = sh.env.Instance.new("Model", sh.env.workspace)
				srvGuest.Character = noHumChar
				srvGuest.CharacterAdded:Fire(noHumChar)

				local sawDamage, sawDeath, sawKill = false, false, false
				local damage40Count, damage60Count = 0, 0
				local deathCountBeforeRemove = 0
				for _, entry in _K.Data.logs do
					local text = tostring(entry[1])
					if string.find(text, "damaged", 1, true) then
						sawDamage = true
						if string.find(text, "for 40 damage.", 1, true) then
							damage40Count += 1
						elseif string.find(text, "for 60 damage.", 1, true) then
							damage60Count += 1
						end
					elseif string.find(text, "died", 1, true) then
						sawDeath = true
						deathCountBeforeRemove += 1
					elseif string.find(text, "killed", 1, true) then
						sawKill = true
					end
				end
				expect(sawDamage).toBe(true)
				expect(damage40Count).toBe(1)
				expect(damage60Count).toBe(1)
				expect(sawDeath).toBe(true)
				expect(sawKill).toBe(true)

				-- CharacterRemoving cleans up connections synchronously before deferred Destroy
				srvGuest.CharacterRemoving:Fire(char)
				hum.Died:Fire()
				world:run(0.1)
				expect(char.Parent).toBeNil()

				local char2 = sh.env.Instance.new("Model", sh.env.workspace)
				local hum2 = sh.env.Instance.new("Humanoid", char2)
				hum2._props.ApplyDescriptionFinished = sh.env:signal()
				hum2.Health = 100
				srvGuest.Character = char2
				srvGuest.CharacterAdded:Fire(char2)
				srvGuest.CharacterRemoving:Fire(char2)
				hum2.Health = 10
				hum2.HealthChanged:Fire(10)
				hum2.Died:Fire()
				world:run(0.05)

				local deathCountAfterRemove, damage90Count = 0, 0
				for _, entry in _K.Data.logs do
					local text = tostring(entry[1])
					if string.find(text, "died", 1, true) then
						deathCountAfterRemove += 1
					elseif string.find(text, "90 damage", 1, true) then
						damage90Count += 1
					end
				end
				expect(deathCountAfterRemove).toBe(deathCountBeforeRemove)
				expect(damage90Count).toBe(0)

				-- 3. Remote.Settings listener: valid prefix, splitKey, freeAdmin, theme, datatypes, EnumItem/Font, useSavedSettings, and non-developer limits
				-- Temporarily add a fake EnumItem and Font setting to test serialization branches (lines 656, 770, 774)
				_K.Data.settings.testEnumSetting = sh.env.globals.Enum.Font.Roboto
				_K.Data.settings.testFontSetting = sh.env.globals.Font.fromEnum(sh.env.globals.Enum.Font.Roboto)
				aRemote.Settings:Fire({
					prefix = { "!" },
					splitKey = "/",
					freeAdmin = { "vip" },
					theme = "Cyan",
					themeBackgroundImage = "rbxassetid://123456",
					changeThemeAuthority = "Server",
					dashboardRank = 2,
					themePrimary = sh.env.globals.Color3.new(0.2, 0.4, 0.8),
					themeCornerRadius = sh.env.globals.UDim.new(0, 10),
					testEnumSetting = sh.env.globals.Enum.Font.BuilderSans,
					testFontSetting = sh.env.globals.Font.fromEnum(sh.env.globals.Enum.Font.BuilderSans),
					nonExistentKey = "ignored",
				})
				world:run(1)

				expect(_K.Data.savedSettings.prefix).toEqual({ "!" })
				expect(_K.Data.savedSettings.splitKey).toBe("/")
				expect(_K.Data.savedSettings.freeAdmin).toEqual({ "vip" })
				expect(_K.Data.savedSettings.theme).toBe("Cyan")
				expect(_K.Data.savedSettings.themeBackgroundImage).toBe("rbxassetid://123456")
				expect(_K.Data.savedSettings.changeThemeAuthority).toBe("Server")
				expect(_K.Data.savedSettings.dashboardRank).toBe(2)
				expect(_K.Data.savedSettings.nonExistentKey).toBeNil()
				expect(sh.env.globals.typeof(_K.Data.savedSettings.themePrimary)).toBe("Color3")
				expect(sh.env.globals.typeof(_K.Data.savedSettings.themeCornerRadius)).toBe("UDim")
				expect(_K.Data.savedSettings.themeCornerRadius.Offset).toBe(10)
				_K.Data.settings.testEnumSetting = nil
				_K.Data.settings.testFontSetting = nil

				-- useSavedSettings = false branch (line 788) and restore to true
				aRemote.Settings:Fire({ useSavedSettings = false })
				world:run(0.5)
				expect(_K.Data.savedSettings.useSavedSettings).toBe(false)
				aRemote.Settings:Fire({ useSavedSettings = true })
				world:run(0.5)
				expect(_K.Data.savedSettings.useSavedSettings).toBe(true)

				-- Restricted mod attempting freeAdmin >= own rank is blocked (line 707), non-developer (unrestricted mod) attempting freeAdmin is blocked (line 698)
				_K.Data.roles.mod.permissions.settings = true
				mRemote.Settings:Fire({
					freeAdmin = { "creator" },
				})
				world:run(0.2)
				expect(_K.Data.savedSettings.freeAdmin).toEqual({ "vip" })

				_K.Data.members["301"].unrestricted = { mod = true }
				mRemote.Settings:Fire({
					freeAdmin = { "mod" },
					prefix = { "?", "extra" },
				})
				mRemote.Settings:Fire({
					prefix = { "?" },
					splitKey = ",",
				})
				-- Immediate second prefix change by non-developer hits cooldown (line 860)
				mRemote.Settings:Fire({
					prefix = { ":" },
				})
				world:run(0.5)
				expect(_K.Data.savedSettings.freeAdmin).toEqual({ "vip" })
				expect(_K.Data.savedSettings.prefix).toEqual({ "?" })
				expect(_K.Data.savedSettings.splitKey).toBe(",")
				_K.Data.roles.mod.permissions.settings = nil
				_K.Data.members["301"].unrestricted = nil

				-- Invalid settings (multi-char prefix, freeAdmin everyone, bad rbxassetid, string/table defaultType, etc.) are rejected
				_K.Data.defaultSettings.testStrSetting = "origStr"
				_K.Data.savedSettings.testStrSetting = "origStr"
				_K.Data.defaultSettings.testTblSetting = { 1 }
				_K.Data.savedSettings.testTblSetting = { 1 }
				aRemote.Settings:Fire({
					prefix = { "twochars" },
					freeAdmin = { "everyone" },
					themeBackgroundImage = "http://bad.url",
					saveChatLogs = true,
					changeThemeAuthority = "InvalidAuthority",
					theme = string.rep("a", 70),
					dashboardRank = 0 / 0,
					testStrSetting = "mutatedStr",
					testTblSetting = { 2 },
				})
				aRemote.Settings:Fire({
					prefix = "not_a_table",
				})
				aRemote.Settings:Fire({
					prefix = {},
				})
				world:run(1)
				expect(_K.Data.savedSettings.prefix).toEqual({ "?" })
				expect(_K.Data.savedSettings.freeAdmin).toEqual({ "vip" })
				expect(_K.Data.savedSettings.themeBackgroundImage).toBe("rbxassetid://123456")
				expect(_K.Data.savedSettings.saveChatLogs).toBe(false)
				expect(_K.Data.savedSettings.changeThemeAuthority).toBe("Server")
				expect(_K.Data.savedSettings.theme).toBe("Cyan")
				expect(_K.Data.savedSettings.dashboardRank).toBe(2)
				expect(_K.Data.savedSettings.testStrSetting).toBe("origStr")
				expect(_K.Data.savedSettings.testTblSetting).toEqual({ 1 })
				_K.Data.defaultSettings.testStrSetting = nil
				_K.Data.savedSettings.testStrSetting = nil
				_K.Data.defaultSettings.testTblSetting = nil
				_K.Data.savedSettings.testTblSetting = nil

				-- Multi-prefix existing list (#existing = 2) allows replacing with 2 prefixes (math.max(#existing, 1))
				_K.Data.savedSettings.prefix = { ";", "!" }
				_K.Remote.Settings._signal:Fire(srvAdmin, {
					prefix = { ";", "?" },
				})
				expect(_K.Data.savedSettings.prefix).toEqual({ ";", "?" })

				-- Reset prefix/splitKey/freeAdmin back to standard, and test announcement/announcements/notifications via Remote.Settings
				world:run(61)
				aRemote.Settings:Fire({
					prefix = { ";" },
					splitKey = " ",
					freeAdmin = {},
					announcement = { "Pinned via Settings", srvAdmin.UserId },
					announcements = { { Text = "Auto announce", Duration = 5 } },
				})
				world:run(1)
				-- Adding 2 new messages at once (> 1 newCount) is blocked; adding 1 new message within 60s hits limitBroadcast
				aRemote.Settings:Fire({
					announcements = { { Text = "Second new", Duration = 5 } },
				})
				world:run(61)
				aRemote.Settings:Fire({
					announcement = false,
					announcements = { { Text = "Allowed after cooldown", Duration = 5 } },
				})
				world:run(1)
				expect(_K.Data.savedSettings.announcement).toBe(false)
				expect(#_K.Data.savedSettings.announcements).toBe(1)
				expect(_K.Data.savedSettings.announcements[1].Text).toBe("Allowed after cooldown")

				-- 4. Remote.Explorer (unauthorized guard, PASTE, DELETE Part, and DELETE Player with targetLimits)
				_K.Remote.Explorer._signal:Fire(srvGuest, "DELETE", {}) -- unauthorized guest ignored (line 910)

				local folder = sh.env.Instance.new("Folder", sh.env.workspace)
				folder.Name = "ExplorerTarget"
				local template = sh.env.Instance.new("Part", sh.env.workspace)
				template.Name = "PasteMe"
				template.Archivable = false

				-- Trigger server handler directly with server Instances (simulating Explorer remote with Instance refs)
				_K.Remote.Explorer._signal:Fire(srvAdmin, "PASTE", { template }, folder)
				expect(folder:FindFirstChild("PasteMe") ~= nil).toBe(true)
				expect(template.Archivable).toBe(false)

				local pasted = folder:FindFirstChild("PasteMe")
				_K.Remote.Explorer._signal:Fire(srvAdmin, "DELETE", { pasted })
				expect(folder:FindFirstChild("PasteMe")).toBeNil()

				-- Deleting a Player instance via Explorer checks targetUserArgument and targetLimits (lines 940-945)
				local tempVictim = sh.env:addPlayer(808, "ExplorerVictim")
				_K.Remote.Explorer._signal:Fire(srvAdmin, "DELETE", { tempVictim })
				expect(tempVictim.Parent).toBeNil()
				server:leave(tempVictim)

				-- Deleting a container holding a higher-rank player's character or TextChatCommands_KA is blocked, while unowned parts succeed
				_K.Data.roles.mod.commands = { ban = true, explorer = true }
				local charContainer = sh.env.Instance.new("Folder", sh.env.workspace)
				local modPart = sh.env.Instance.new("Part", folder)
				adminChar.Parent = charContainer
				_K.Remote.Explorer._signal:Fire(
					srvMod,
					"DELETE",
					{ charContainer, adminChar, adminHead, sh.KA, sh.env.Players, modPart }
				)
				expect(modPart.Parent).toBeNil()
				expect(charContainer.Parent).toBe(sh.env.workspace)
				expect(adminChar.Parent).toBe(charContainer)
				expect(adminHead.Parent).toBe(adminChar)
				expect(sh.KA.Parent).toBe(sh.env.game:GetService("ReplicatedStorage"))
				expect(sh.env.Players.Parent).toBe(sh.env.game)
				adminChar.Parent = sh.env.workspace
				charContainer:Destroy()
				_K.Data.roles.mod.commands = { ban = true }
				if _K.ChatCommands and _K.ChatCommands.folder then
					_K.Remote.Explorer._signal:Fire(srvAdmin, "DELETE", { _K.ChatCommands.folder })
					expect(_K.ChatCommands.folder.Parent ~= nil).toBe(true)
				end

				-- 5. Remote.Ban, Remote.Unban, Remote.Command, Remote.Idled, Hook.roleAdded/roleRemoved, and VIP remotes
				aRemote.Idled:Fire(42)
				aRemote.Ban:Fire(404, "test ban reason", 120)
				-- Banning already-banned user with same reason is a no-op (line 829)
				aRemote.Ban:Fire(404, "test ban reason", 120)
				-- NaN and math.huge duration branches are rejected (line 804), while -1 creates a permanent ban
				aRemote.Ban:Fire(405, "nan ban", 0 / 0)
				aRemote.Ban:Fire(405, "inf ban", math.huge)
				aRemote.Ban:Fire(406, "perm ban", -1)
				-- saveBan waits on Util.getUserInfo's batched lookup, which can still be busy with earlier lookups
				world:run(2)
				expect(srvAdmin:GetAttribute("_KIdleTime")).toBe(42)
				expect(_K.Data.bans["404"] ~= nil).toBe(true)
				expect(_K.Data.bans["405"]).toBeNil()
				expect(_K.Data.bans["406"][3]).toBe(-1)

				-- Mod without banasync forces duration = 0 on Remote.Ban (line 825) and is blocked from unbanning persistent ban (line 875)
				_K.Data.roles.mod.permissions.ban = true
				_K.Data.roles.mod.permissions.unban = true
				local modNotices = {}
				mRemote.Notify:Connect(function(data)
					table.insert(modNotices, data.Text)
				end)
				mRemote.Ban:Fire(407, "mod server ban", 300)
				mRemote.Unban:Fire(406) -- persistent ban (-1) blocked for mod without banasync
				mRemote.Ban:Fire(406, "mod server ban", 0) -- and re-banning can't demote it to a server ban
				mRemote.Unban:Fire(999999) -- non-existent ban ignored (line 863)
				world:run(1)
				expect(_K.Data.bans["407"] ~= nil).toBe(true)
				expect(_K.Data.bans["407"][3]).toBeNil()
				expect(_K.Data.bans["406"] ~= nil).toBe(true)
				expect(_K.Data.bans["406"][3]).toBe(-1)
				-- the kept saved ban isn't logged as a ban, and the mod is told it was kept
				local banLogs = {}
				for _, log in _K.Data.logs do
					if string.find(log[1], "ban 40", 1, true) then
						table.insert(banLogs, log[1])
					end
				end
				expect(table.find(banLogs, ";ban 407 0 mod server ban") ~= nil).toBe(true)
				expect(table.find(banLogs, ";ban 406 0 mod server ban")).toBeNil()
				expect(table.find(modNotices, "Kept saved ban for <b>406</b>.") ~= nil).toBe(true)
				expect(table.find(modNotices, "Kept saved ban for <b>407</b>.")).toBeNil()

				-- The admin permission from a role a non-developer gave still can't lift a saved ban
				_K.Data.roles.mod.permissions.admin = true
				_K.Data.members["301"].unrestricted = { mod = true }
				mRemote.Unban:Fire(406)
				world:run(1)
				expect(_K.Data.bans["406"][3]).toBe(-1)
				-- refused before it's logged as an unban
				for _, log in _K.Data.logs do
					expect(log[1] == ";unban 406").toBe(false)
				end
				_K.Data.roles.mod.permissions.admin = nil
				_K.Data.members["301"].unrestricted = nil

				-- Banning an online player kicks them (line 840)
				server:client(408)
				local onlineBanTarget = sh.env.Players:GetPlayerByUserId(408)
				world:run(0.2)
				aRemote.Ban:Fire(408, "kicked on ban", 0)
				aRemote.Unban:Fire(404)
				world:run(1)
				expect(server.kicked[onlineBanTarget] ~= nil).toBe(true)
				expect(_K.Data.bans["404"]).toBeNil()

				-- Hook.roleAdded and Hook.roleRemoved update ServersSubscribers (lines 956-969)
				local serversTable = sh.env:require(_K.Server:WaitForChild("Servers"))
				_K.Auth.userRoleAdd(srvGuest.UserId, "admin")
				expect(serversTable.Subscribers[srvGuest]).toBe(true)
				_K.Auth.userRoleRemove(srvGuest.UserId, "admin")

				-- Remote.Command executes a server command (e.g., ;serverlock and ;unserverlock)
				aRemote.Command:Fire(";serverlock")
				world:run(1)
				expect(_K._serverLock).toBe(srvAdmin.Name)

				-- Player joining while _K._serverLock is active gets kicked (lines 1041-1042)
				server:client(501)
				local lockedPlr = sh.env.Players:GetPlayerByUserId(501)
				sh.env.Players.PlayerAdded:Fire(lockedPlr)
				world:run(0.5)
				expect(server.kicked[lockedPlr] ~= nil).toBe(true)

				aRemote.Command:Fire(";unserverlock")
				world:run(1)
				expect(_K._serverLock).toBeNil()

				-- Banned player joining returns early when kicked (line 1033)
				server:client(407)
				local bannedJoiner = sh.env.Players:GetPlayerByUserId(407)
				sh.env.Players.PlayerAdded:Fire(bannedJoiner)
				world:run(0.5)
				expect(server.kicked[bannedJoiner] ~= nil).toBe(true)

				-- Player.Chatted never fires with platform-integrated chat, nothing listens to it
				srvAdmin.Chatted:Fire(";serverlock")
				srvAdmin.Chatted:Fire("/e ;serverlock")
				world:run(0.5)
				expect(_K._serverLock).toBeNil()

				-- PlayerRemoving logs LEAVE and cleans up state (lines 1047-1055)
				sh.env.Players.PlayerRemoving:Fire(srvMod)
				world:run(0.2)

				-- VIP remotes (Title, VIPUGCMethod, VIPCheck, PromptBulkPurchase)
				aRemote.Title:Fire("vip")
				aRemote.VIPUGCMethod:Fire(18966788838, "rbxassetid://18966762965", true, "Gold")
				aRemote.VIPUGCMethod:Fire(18966788838, "rbxassetid://18966762965", false, "Gold")
				aRemote.VIPCheck:Fire(88978146769822)
				aRemote.PromptBulkPurchase:Fire(88978146769822)
				world:run(1)

				-- 6. Servers.luau cross-server discovery & TeleportToServer
				expect(serversTable.Enabled).toBe(false)
				serversTable.Subscribers[srvAdmin] = true
				serversTable.Subscribers[srvMod] = false
				local serverBroadcasts = {}
				local modBroadcasts = 0
				local origServersFire = _K.Remote.Servers.Fire
				_K.Remote.Servers.Fire = function(selfRemote: any, player: any, jobId: any, data: any)
					if player == srvAdmin then
						table.insert(serverBroadcasts, { player = player, jobId = jobId, count = data and data[2] })
					elseif player == srvMod then
						modBroadcasts += 1
					end
					return origServersFire(selfRemote, player, jobId, data)
				end
				server:spawn(function()
					serversTable.start()
				end)
				world:run(0.5)
				expect(serversTable.Enabled).toBe(true)
				local MessagingService = sh.env.game:GetService("MessagingService")
				server:spawn(function()
					-- Invalid payload is ignored; same SERVER_ID is already published by Servers.start()
					MessagingService:PublishAsync("_KAdminServers", "invalid_string_payload")
					MessagingService:PublishAsync(
						"_KAdminServers",
						{ "remote-job-99", 1000, 5, sh.env.globals.os.time() }
					)
					sh.env.globals.task.wait(0.5)
					-- Identical player count does not re-broadcast (changed == false)
					MessagingService:PublishAsync(
						"_KAdminServers",
						{ "remote-job-99", 1000, 5, sh.env.globals.os.time() }
					)
					sh.env.globals.task.wait(0.5)
					-- Changed player count updates existing Map["remote-job-99"] entry and broadcasts
					MessagingService:PublishAsync(
						"_KAdminServers",
						{ "remote-job-99", 1000, 7, sh.env.globals.os.time() }
					)
				end)
				world:run(5)
				expect(_K.Data.servers["remote-job-99"] ~= nil).toBe(true)
				expect(_K.Data.servers["remote-job-99"][2]).toBe(7)
				expect(#serverBroadcasts).toBe(2)
				expect(modBroadcasts).toBe(0)
				expect(serverBroadcasts[1].player).toBe(srvAdmin)
				expect(serverBroadcasts[1].jobId).toBe("remote-job-99")
				expect(serverBroadcasts[1].count).toBe(5)
				expect(serverBroadcasts[2].count).toBe(7)

				aRemote.TeleportToServer:Fire(1000, "remote-job-99")
				world:run(1)
				expect(#sh.env.teleports >= 1).toBe(true)
				expect(sh.env.teleports[#sh.env.teleports].placeId).toBe(1000)

				-- Advance past EXPIRE (35s) while keeping a fresh server entry to verify selective stale server removal
				_K.Data.servers["remote-job-fresh"] = { 1000, 3, sh.env.globals.os.time(), sh.env.globals.tick() + 45 }
				world:run(50)
				expect(_K.Data.servers["remote-job-99"]).toBeNil()
				expect(_K.Data.servers["remote-job-fresh"] ~= nil).toBe(true)
				expect(#serverBroadcasts).toBe(3)
				expect(serverBroadcasts[3].jobId).toBe("remote-job-99")
				expect(serverBroadcasts[3].count).toBeNil()
				_K.Remote.Servers.Fire = origServersFire
			end
		)

		test(
			"Server handles Configuration/ModuleScript settings, Addons, Group creator, PrivateServer scope, and Studio/Client guards",
			function()
				-- 1. Group creator resolution (src/init.luau lines 76-81), Configuration instance with Addons/Settings/Themes, PrivateServer scope, and Studio PlaceId == 0 alerts
				local hStudio = Harness.newEnv({ isStudio = true, placeId = 0 })

				-- Requiring and calling Server/init.luau when Util.Service.Run:IsClient() is true errors with guard (line 23)
				local clientServerFn = hStudio.env:require(hStudio.KA:WaitForChild("Server"))
				local fakeClientK = {
					script = hStudio.KA,
					Server = hStudio.KA:WaitForChild("Server"),
					Util = {
						Service = {
							Run = {
								IsClient = function()
									return true
								end,
							},
						},
					},
					Data = {},
				}
				local okClientSrv, errClientSrv = pcall(clientServerFn, fakeClientK)
				expect(okClientSrv).toBe(false)
				expect(
					string.find(tostring(errClientSrv), "Cannot load server-side code on the client", 1, true) ~= nil
				).toBe(true)
				local leftoverSharedRef = hStudio.KA:WaitForChild("Server"):FindFirstChild("Shared")
				if leftoverSharedRef then
					leftoverSharedRef:Destroy()
				end
				hStudio.env.game._props.CreatorType = hStudio.env.globals.Enum.CreatorType.Group
				hStudio.env.game._props.CreatorId = 500
				hStudio.env.game._props.PrivateServerId = "priv-srv-1"
				hStudio.env.game._props.PrivateServerOwnerId = 777

				-- Pre-existing player with pre-existing Character before _K.initialize (line 1020)
				local prePlr = hStudio.env:addPlayer(777, "PrivServerOwner")
				local preChar = hStudio.env.Instance.new("Model")
				local preHum = hStudio.env.Instance.new("Humanoid", preChar)
				preHum._props.ApplyDescriptionFinished = hStudio.env:signal()
				preHum.Health = 100
				prePlr.Character = preChar

				-- Create a Configuration instance with Settings, Addons, and Themes children (lines 121-135, 476-497)
				local configObj = hStudio.env.Instance.new("Configuration")
				local settingsMod = hStudio.env.Instance.new("ModuleScript", configObj)
				settingsMod.Name = "Settings"
				local studioRolesTable = Harness.defaultRoles()
				studioRolesTable[1] = studioRolesTable.vip
				studioRolesTable.vip = nil
				rawset(settingsMod, "_factory", function()
					return {
						userRoles = {
							superadmin = { 777 },
						},
						assetRoles = {},
						gamepassRoles = {},
						subscriptionRoles = {},
						groupRoles = {},
						friendRoles = {},
						freeAdmin = {},
						commands = {},
						prefix = ";",
						splitKey = " ",
						roles = studioRolesTable,
					}
				end)

				local themesFolder = hStudio.env.Instance.new("Folder", configObj)
				themesFolder.Name = "Themes"
				local customTheme = hStudio.env.Instance.new("ModuleScript", themesFolder)
				customTheme.Name = "CustomTheme"

				local addonsFolder = hStudio.env.Instance.new("Folder", configObj)
				addonsFolder.Name = "Addons"
				local sharedAddonran, serverAddonRan, subAddonRan = false, false, false
				local sharedAddon = hStudio.env.Instance.new("ModuleScript", addonsFolder)
				sharedAddon.Name = "SharedTestAddon"
				rawset(sharedAddon, "_factory", function()
					return function()
						sharedAddonran = true
					end
				end)
				local serverAddon = hStudio.env.Instance.new("ModuleScript", addonsFolder)
				serverAddon.Name = "ServerTestAddon.server"
				rawset(serverAddon, "_factory", function()
					return function()
						serverAddonRan = true
					end
				end)
				local clientAddon = hStudio.env.Instance.new("ModuleScript", addonsFolder)
				clientAddon.Name = "ClientTestAddon.client"
				local subFolder = hStudio.env.Instance.new("Folder", addonsFolder)
				subFolder.Name = "SubGroup"
				local subAddon = hStudio.env.Instance.new("ModuleScript", subFolder)
				subAddon.Name = "NestedAddon"
				rawset(subAddon, "_factory", function()
					return function()
						subAddonRan = true
					end
				end)

				-- Also add a legacy child inside Server/Addons to trigger oldAddonStructure warning (line 469)
				local legacyAddon =
					hStudio.env.Instance.new("Folder", hStudio.KA:WaitForChild("Server"):WaitForChild("Addons"))
				legacyAddon.Name = "LegacyChild"

				local sK = hStudio:requireK()
				local syncedThemes = 0
				local origSyncThemes = sK.Data.syncThemeDefaults
				sK.Data.syncThemeDefaults = function(...)
					syncedThemes += 1
					return origSyncThemes(...)
				end
				local prefetchedGroups = 0
				local origPrefetchGroups = sK.Auth.prefetchGroupEntryRanks
				sK.Auth.prefetchGroupEntryRanks = function(...)
					prefetchedGroups += 1
					return origPrefetchGroups(...)
				end
				local initHookFired = false
				sK.Hook.init:Connect(function()
					initHookFired = true
				end)
				local initRet = sK.initialize(configObj, addonsFolder)
				for _ = 1, 10 do
					hStudio.env:step(0.5)
				end
				sK.Data.syncThemeDefaults = origSyncThemes
				sK.Auth.prefetchGroupEntryRanks = origPrefetchGroups

				expect(initRet).toBe(sK)
				expect(studioRolesTable[1]).toBeNil()
				expect(type(sK.Data.settingsModuleData.bans)).toBe("table")
				expect(initHookFired).toBe(true)
				expect(syncedThemes).toBe(1)
				expect(prefetchedGroups).toBe(1)
				expect(sK.ready).toBe(true)
				expect(sK.groupId).toBe(500)
				expect(table.find(sK.Data.settingsModuleData.userRoles.superadmin, 777) ~= nil).toBe(true)
				expect(sharedAddonran).toBe(true)
				expect(serverAddonRan).toBe(true)
				expect(subAddonRan).toBe(true)
				expect(configObj.Parent).toBe(hStudio.KA)
				expect(addonsFolder.Parent).toBe(sK.Server)
				expect(hStudio.KA.Client.UI.Theme.Themes:FindFirstChild("CustomTheme") ~= nil).toBe(true)
				expect(serverAddon.Parent ~= nil and serverAddon.Parent.Name == "_KServerAddons").toBe(true)
				expect(sharedAddon.Parent).toBe(hStudio.KA:FindFirstChild("Addons"))
				expect(clientAddon.Parent).toBe(hStudio.KA:FindFirstChild("Addons"))

				-- Studio Remote.Init with PlaceId == 0 alerts admin about publishing to save data (line 572)
				sK.Remote.Init._signal:Fire(prePlr, { Attributes = { Platform = "Desktop" } })
				hStudio.env:step(1)
				expect(prePlr:GetAttribute("_K_READY")).toBe(true)

				-- Client helper branches in src/init.luau (_K.getCommandPrefix, _K.alert, _K.log when _K.IsClient is true)
				local updatedLogsList = false
				local notifiedClient = nil
				local origNotify = sK.Notify
				sK.IsClient = true
				sK.IsServer = false
				sK.Service.Players._props.LocalPlayer = prePlr
				sK.client = {
					playerPrefix = sK.Flux.signal("!"),
					dashboard = {
						Logs = {
							updateList = function()
								updatedLogsList = true
							end,
						},
					},
				}
				sK.Notify = function(props)
					notifiedClient = props
				end
				expect(sK.getCommandPrefix()).toBe("!")
				sK.alert(prePlr, "Client alert")
				expect(notifiedClient ~= nil).toBe(true)
				expect(notifiedClient.Text).toBe("Client alert")
				sK.log("Client command log", "COMMAND")
				hStudio.env:step(0.1)
				expect(updatedLogsList).toBe(true)
				sK.Notify = origNotify
				sK.IsClient = false
				sK.IsServer = true
			end
		)
	end)
end)

describe("Chat and Server · Pinned announcements and disabled forced chat", function()
	test("pinned announcements reach every client with their identity, bursts keep the cooldown", function()
		local world = sert.sim.new({
			backing = true,
			latency = { DataStoreService = 0.01, MemoryStoreService = 0.01, MessagingService = 0.01 },
		})
		local server = world:server({ jobId = "pin-job" })
		-- messages wait in world.messaging.pending until drained
		local adminClient = server:client(101)
		local guestClient = server:client(202)
		local sh = Harness.newPeerEnv(server, { isStudio = false, jobId = "pin-job", placeId = 1000 })
		sh.env.game._props.CreatorId = 101

		local _K: any
		server:spawn(function()
			_K = sh:requireK()
			_K.initialize({
				bans = {},
				userRoles = { superadmin = { 101 } },
				assetRoles = {},
				gamepassRoles = {},
				subscriptionRoles = {},
				groupRoles = {},
				friendRoles = {},
				freeAdmin = {},
				prefix = ";",
				splitKey = " ",
				commands = {},
				roles = Harness.defaultRoles(),
			})
		end)
		world:run(2)
		expect(_K.ready).toBe(true)

		local aRemote = Harness.newPeerEnv(adminClient, { isClient = true }):requireRemote()
		local gRemote = Harness.newPeerEnv(guestClient, { isClient = true }):requireRemote()
		world:run(1)
		local adminSettings, guestSettings, guestAnnounces = {}, {}, {}
		aRemote.Settings:Connect(function(settings)
			table.insert(adminSettings, settings)
		end)
		gRemote.Settings:Connect(function(settings)
			table.insert(guestSettings, settings)
		end)
		gRemote.ChatSystem:Connect(function(kind, text, from, data)
			if kind == "announce" then
				table.insert(guestAnnounces, { text = text, from = from, data = data })
			end
		end)
		aRemote.Init:Fire({ Attributes = { Platform = "Desktop" } })
		gRemote.Init:Fire({ Attributes = { Platform = "Desktop" } })
		world:run(4)

		-- a rejected burst of new messages doesn't start the cooldown shared with ;announce
		aRemote.Settings:Fire({ announcements = { { Text = "One", Duration = 5 }, { Text = "Two", Duration = 5 } } })
		world:run(0.5)
		expect(#(_K.Data.savedSettings.announcements or {})).toBe(0)
		expect(_K.Chat.cooldown(101, "announce")).toBeNil()
		world:run(61)

		-- the editor gets the filtered pinned announcement back, other players get it with the changes
		table.clear(adminSettings)
		table.clear(guestSettings)
		aRemote.Settings:Fire({ announcement = { "Pinned via settings", 101 } })
		world:run(0.5)
		expect(#adminSettings).toBe(1)
		expect(adminSettings[1].announcement[1]).toBe("Pinned via settings")
		expect(adminSettings[1].announcement[2]).toBe(101)
		expect(#guestSettings).toBe(1)
		expect(guestSettings[1].announcement[1]).toBe("Pinned via settings")
		world:run(61)

		-- ;announce messages carry the pinned announcement so clients can tell it apart from a settings sync
		aRemote.Command:Fire(";announce Pinned via command")
		world:run(1)
		world.messaging:drain()
		world:run(1)
		expect(#guestAnnounces >= 1).toBe(true)
		local last = guestAnnounces[#guestAnnounces]
		expect(last.text).toBe("Pinned via command")
		expect(type(last.data)).toBe("table")
		expect(last.data[1]).toBe("Pinned via command")
		expect(last.data[2]).toBe(101)

		-- ;unannounce tells clients to forget it, so the same announcement shows again later
		table.clear(guestSettings)
		aRemote.Command:Fire(";unannounce")
		world:run(1)
		world.messaging:drain()
		world:run(1)
		local cleared = false
		for _, settings in guestSettings do
			if settings.announcement == false then
				cleared = true
			end
		end
		expect(cleared).toBe(true)
	end)

	test("clients show a pinned announcement once across settings and announce messages", function()
		local world = sert.sim.new({ backing = true })
		local server = world:server()
		local client = server:client(101)
		local sh = Harness.newPeerEnv(server, { isStudio = false })
		local ch = Harness.newPeerEnv(client, { isClient = true })
		local sRemote = sh:requireRemote()
		local cChat = ch:requireShared("Chat")
		world:run(1)

		local shown = {}
		local commands = ch.env:require(ch.Shared:WaitForChild("DefaultCommands"):WaitForChild("Administration"))
		for _, command in commands do
			if command.name == "announce" then
				command.envClient({
					Chat = cChat,
					Announce = function(props)
						table.insert(shown, props.Text)
					end,
				})
			end
		end

		local srvPlr = sh.env.Players:GetPlayerByUserId(101)
		local pinned = { "Pinned", 7 }
		-- Remote.Settings delivered it first, the announce message that follows doesn't show it again
		expect(cChat.pinAnnouncement(pinned)).toBe(true)
		sRemote.ChatSystem:Fire(srvPlr, "announce", "Pinned", 7, pinned, "pin-1")
		world:run(0.2)
		expect(#shown).toBe(0)
		-- an unchanged full settings sync doesn't show it again either
		expect(cChat.pinAnnouncement({ "Pinned", 7 })).toBe(false)

		-- a replaced announcement shows once, however it arrives
		sRemote.ChatSystem:Fire(srvPlr, "announce", "Replaced", 7, { "Replaced", 7 }, "pin-2")
		sRemote.ChatSystem:Fire(srvPlr, "announce", "Replaced", 7, { "Replaced", 7 }, "pin-3")
		world:run(0.2)
		expect(shown).toEqual({ "Replaced" })
		expect(cChat.pinAnnouncement({ "Replaced", 7 })).toBe(false)

		-- clearing it lets the same announcement show again
		expect(cChat.pinAnnouncement(false)).toBe(false)
		sRemote.ChatSystem:Fire(srvPlr, "announce", "Replaced", 7, { "Replaced", 7 }, "pin-4")
		-- announce messages without a pinned announcement always show
		sRemote.ChatSystem:Fire(srvPlr, "announce", "Plain", 7, 5, "plain-1")
		sRemote.ChatSystem:Fire(srvPlr, "announce", "Plain", 7, 5, "plain-2")
		world:run(0.2)
		expect(shown).toEqual({ "Replaced", "Replaced", "Plain", "Plain" })

		-- pins with an id show once each, so a settings sync that arrives after a clear or a replacement doesn't
		-- bring the old pin back
		local first, second = { "First", 7, 0, "id-1" }, { "Second", 7, 0, "id-2" }
		expect(cChat.pinAnnouncement(first)).toBe(true)
		expect(cChat.pinAnnouncement(false)).toBe(false)
		expect(cChat.pinAnnouncement(table.clone(first))).toBe(false)
		expect(cChat.pinAnnouncement(second)).toBe(true)
		expect(cChat.pinAnnouncement(table.clone(first))).toBe(false)
		expect(cChat.pinAnnouncement(table.clone(second))).toBe(false)
		-- the same text pinned again gets a new id and shows
		expect(cChat.pinAnnouncement({ "First", 7, 0, "id-3" })).toBe(true)
	end)

	test("forced chat is disabled with a hint while privatemessage stays enabled", function()
		local h = Harness.newEnv({ isStudio = false })
		local commands = {}
		for _, module in { "General", "SuperAdmin" } do
			for _, command in h.env:require(h.Shared:WaitForChild("DefaultCommands"):WaitForChild(module)) do
				commands[command.name] = command
				for _, alias in command.aliases or {} do
					commands[alias] = command
				end
			end
		end
		local hints = {}
		local context = {
			_K = {
				Notify = function(props)
					table.insert(hints, props.Text)
				end,
			},
		}
		for _, alias in { "chat", "forcechat" } do
			local command = commands[alias]
			expect(command.run).toBeNil()
			expect(#command.args).toBe(0)
			command.runClient(context)
		end
		expect(string.find(hints[1], "disabled", 1, true) ~= nil).toBe(true)
		expect(#hints).toBe(2)
		expect(type(commands.privatemessage.run)).toBe("function")
		expect(#commands.privatemessage.args).toBe(2)
	end)
end)

describe("Chat and Server · Repeated pinned announcements", function()
	test("pinning the same text again shows it again, a settings sync of it doesn't", function()
		local world = sert.sim.new({
			backing = true,
			latency = { DataStoreService = 0.01, MemoryStoreService = 0.01, MessagingService = 0.01 },
		})
		local server = world:server({ jobId = "repin-job" })
		local adminClient = server:client(101)
		local guestClient = server:client(202)
		local sh = Harness.newPeerEnv(server, { isStudio = false, jobId = "repin-job", placeId = 1000 })
		sh.env.game._props.CreatorId = 101

		local _K: any
		server:spawn(function()
			_K = sh:requireK()
			_K.initialize({
				bans = {},
				userRoles = { superadmin = { 101 } },
				assetRoles = {},
				gamepassRoles = {},
				subscriptionRoles = {},
				groupRoles = {},
				friendRoles = {},
				freeAdmin = {},
				prefix = ";",
				splitKey = " ",
				commands = {},
				roles = Harness.defaultRoles(),
			})
		end)
		world:run(2)
		expect(_K.ready).toBe(true)

		local aRemote = Harness.newPeerEnv(adminClient, { isClient = true }):requireRemote()
		local gh = Harness.newPeerEnv(guestClient, { isClient = true })
		local gRemote = gh:requireRemote()
		local gChat = gh:requireShared("Chat")
		world:run(1)
		local pins = {}
		gRemote.Settings:Connect(function(settings)
			if type(settings.announcement) == "table" then
				table.insert(pins, settings.announcement)
			end
		end)
		gRemote.ChatSystem:Connect(function(kind, _text, _from, data)
			if kind == "announce" and type(data) == "table" then
				table.insert(pins, data)
			end
		end)
		aRemote.Init:Fire({ Attributes = { Platform = "Desktop" } })
		gRemote.Init:Fire({ Attributes = { Platform = "Desktop" } })
		world:run(4)

		-- the same ;announce twice, past the cooldown and without ;unannounce in between
		local shown = {}
		for _ = 1, 2 do
			table.clear(pins)
			aRemote.Command:Fire(";announce Server restarting soon")
			world:run(1)
			world.messaging:drain()
			world:run(1)
			expect(#pins >= 1).toBe(true)
			for _, pin in pins do
				if gChat.pinAnnouncement(pin) then
					table.insert(shown, pin[1])
				end
			end
			-- a later full settings sync repeats it unchanged
			expect(gChat.pinAnnouncement(table.clone(_K.Data.savedSettings.announcement))).toBe(false)
			world:run(61)
		end
		expect(shown).toEqual({ "Server restarting soon", "Server restarting soon" })

		-- the same text pinned twice from the settings UI shows twice too
		table.clear(shown)
		for _ = 1, 2 do
			table.clear(pins)
			aRemote.Settings:Fire({ announcement = { "Pinned twice", 101 } })
			world:run(0.5)
			expect(#pins).toBe(1)
			if gChat.pinAnnouncement(pins[1]) then
				table.insert(shown, pins[1][1])
			end
			world:run(61)
		end
		expect(shown).toEqual({ "Pinned twice", "Pinned twice" })
	end)
end)

describe("Chat commands · TextChatCommands with platform-integrated chat", function()
	test("aliasGroups puts the primary slash alias first, then prefixed aliases, and skips taken ones", function()
		local h = Harness.newEnv({ isStudio = false })
		local ChatCommands = h.env:require(h.Server:WaitForChild("ChatCommands"))
		local message = { name = "Message", aliases = { "m", "MSG", "two words" } }
		local groups, skipped = ChatCommands.aliasGroups(message, { ";", ":" }, { ["/m"] = true, [":msg"] = true })
		expect(groups).toEqual({
			{ "/message", ";message" },
			{ ":message", ";m" },
			{ ":m", ";msg" },
			{ "/msg" },
		})
		expect(skipped).toEqual({ ":msg", "/m" })
		-- "/" as a prefix isn't repeated, and every alias has a prefix
		local slashGroups = ChatCommands.aliasGroups({ name = "kill" }, { "/" }, {})
		expect(slashGroups).toEqual({ { "/kill" } })
		expect(ChatCommands.aliasGroups({ name = "kill" }, {}, { ["/kill"] = true })).toEqual({})
		expect(table.find(ChatCommands.DEFAULT_ALIASES, "/team") ~= nil).toBe(true)
	end)

	test("every command runs from chat on the server, with re-aliasing and late commands", function()
		local world = sert.sim.new({ backing = true })
		local server = world:server({ jobId = "chat-job" })
		local adminClient = server:client(101)
		local guestClient = server:client(202)
		local sh = Harness.newPeerEnv(server, { isStudio = false, jobId = "chat-job", placeId = 1000 })
		sh.env.game._props.CreatorId = 101
		local tcs = sh.env.game:GetService("TextChatService")
		-- the game's own command, made before Kohl's Admin starts
		local gameCommand = sh.env.Instance.new("TextChatCommand")
		gameCommand.PrimaryAlias = "/PING"
		gameCommand.Parent = tcs

		local _K: any
		server:spawn(function()
			_K = sh:requireK()
			_K.initialize({
				bans = {},
				userRoles = { superadmin = { 101 } },
				assetRoles = {},
				gamepassRoles = {},
				subscriptionRoles = {},
				groupRoles = {},
				friendRoles = {},
				freeAdmin = {},
				vip = false,
				splitKey = " ",
				commands = {},
				roles = Harness.defaultRoles(),
			})
		end)
		world:run(2)
		expect(_K.ready).toBe(true)
		expect(type(_K.VERSION)).toBe("string")
		expect(_K.features.platformIntegratedChat).toBe(true)

		local adminEnv = Harness.newPeerEnv(adminClient, { isClient = true })
		local aRemote = adminEnv:requireRemote()
		local gRemote = Harness.newPeerEnv(guestClient, { isClient = true }):requireRemote()
		world:run(1)
		local forwarded, guestForwarded, guestNotes = {}, {}, {}
		aRemote.Command:Connect(function(text, clientOnly)
			table.insert(forwarded, { text = text, clientOnly = clientOnly })
		end)
		gRemote.Command:Connect(function(text, clientOnly)
			table.insert(guestForwarded, { text = text, clientOnly = clientOnly })
		end)
		gRemote.Notify:Connect(function(props)
			table.insert(guestNotes, props.Text)
		end)
		aRemote.Init:Fire({ Attributes = { Platform = "PC" } })
		gRemote.Init:Fire({ Attributes = { Platform = "PC" } })
		world:run(4)

		local folder = tcs:FindFirstChild("TextChatCommands_KA")
		local function aliasesOf(name: string): { string }
			local list = {}
			for _, instance in folder:GetChildren() do
				local key = string.match(instance.Name, "^(%D+)%d*$")
				if key == name then
					table.insert(list, instance.PrimaryAlias)
					if instance.SecondaryAlias ~= "" then
						table.insert(list, instance.SecondaryAlias)
					end
				end
			end
			table.sort(list)
			return list
		end
		local function skippedLog(): string
			local texts = {}
			for _, log in _K.Data.logs do
				if string.find(log[1], "Skipped chat command aliases", 1, true) then
					table.insert(texts, log[1])
				end
			end
			return table.concat(texts, "\n")
		end

		-- the primary "/" alias is first so ExperienceChat can index it, followed by the configured prefixes
		local serverlock = folder:FindFirstChild("serverlock")
		expect(serverlock.PrimaryAlias).toBe("/serverlock")
		expect(serverlock.SecondaryAlias).toBe(";serverlock")
		expect(aliasesOf("serverlock")).toEqual({
			"/serverlock",
			"/slock",
			":serverlock",
			":slock",
			";serverlock",
			";slock",
		})
		local seen, count = {}, 0
		for _, instance in folder:GetChildren() do
			count += 1
			expect(instance.AutocompleteVisible).toBe(false)
			expect(instance.Enabled).toBe(true)
			for _, alias in { instance.PrimaryAlias, instance.SecondaryAlias } do
				if alias ~= "" then
					expect(seen[alias]).toBeNil()
					seen[alias] = true
					expect(string.find(alias, "^[;:/]..*") ~= nil).toBe(true)
				end
			end
		end
		expect(count >= #_K.Registry.commandsList).toBe(true)
		-- Roblox's defaults and the game's commands keep their aliases, both would run otherwise
		for _, alias in { "/ping", "/m", "/e", "/team", "/help", "/w" } do
			expect(seen[alias]).toBeNil()
		end
		expect(seen[";m"] and seen[";ping"]).toBe(true)
		expect(string.find(skippedLog(), "/ping", 1, true) ~= nil).toBe(true)
		expect(string.find(skippedLog(), "/m", 1, true) ~= nil).toBe(true)
		expect(_K.chatCommandAlias("SLOCK")).toBe(";slock")
		expect(_K.chatCommandAlias("ping")).toBe(";ping")
		expect(_K.chatCommandAlias("nope")).toBe(";nope")

		-- Triggered gets the whole line, the server runs it and forwards it so the client runs its part
		local srvAdmin = sh.env.Players:GetPlayerByUserId(101)
		serverlock.Triggered:Fire({ UserId = 101 }, ";serverlock")
		world:run(1)
		expect(_K._serverLock).toBe(srvAdmin.Name)
		expect(forwarded[#forwarded].text).toBe(";serverlock")
		expect(forwarded[#forwarded].clientOnly).toBe(true)
		-- "/" isn't a configured prefix, it becomes the first one
		folder:FindFirstChild("unserverlock3").Triggered:Fire({ UserId = 101 }, "  /UNSLOCK")
		world:run(1)
		expect(_K._serverLock).toBeNil()
		expect(forwarded[#forwarded].text).toBe(";UNSLOCK")
		-- only players in the server, and only with the command's permission (unauthorized isn't forwarded to client)
		serverlock.Triggered:Fire({ UserId = 99999 }, ";serverlock")
		serverlock.Triggered:Fire({ UserId = 202 }, ";serverlock")
		world:run(1)
		expect(_K._serverLock).toBeNil()
		expect(#guestForwarded).toBe(0)
		expect(string.find(table.concat(guestNotes, "\n"), "restricted", 1, true) ~= nil).toBe(true)
		-- client-only commands run on the client and stay out of the server's logs
		folder:FindFirstChild("commands").Triggered:Fire({ UserId = 101 }, ";cmds")
		world:run(1)
		expect(forwarded[#forwarded].text).toBe(";cmds")
		for _, log in _K.Data.logs do
			expect(log[1] == ";cmds" or log[1] == ";commands").toBe(false)
		end

		-- Player.Chatted isn't a command path
		srvAdmin.Chatted:Fire(";serverlock")
		world:run(0.5)
		expect(_K._serverLock).toBeNil()

		-- commands registered later get instances too
		local lateRuns = 0
		_K.Registry.registerCommand(_K, {
			name = "lateping",
			aliases = { "lp" },
			description = "Registered by an addon after start",
			group = "Utility",
			args = {},
			run = function()
				lateRuns += 1
			end,
		})
		world:run(0.2)
		expect(aliasesOf("lateping")).toEqual({ "/lateping", "/lp", ":lateping", ":lp", ";lateping", ";lp" })
		folder:FindFirstChild("lateping2").Triggered:Fire({ UserId = 202 }, ":lp")
		world:run(1)
		expect(lateRuns).toBe(1)

		-- another TextChatCommand taking an alias later wins it, and so does an alias change
		local later = sh.env.Instance.new("TextChatCommand")
		later.PrimaryAlias = ";LP"
		later.Parent = tcs
		world:run(0.2)
		expect(aliasesOf("lateping")).toEqual({ "/lateping", "/lp", ":lateping", ":lp", ";lateping" })
		expect(string.find(skippedLog(), ";lp", 1, true) ~= nil).toBe(true)
		later.PrimaryAlias = ";lateping"
		world:run(0.2)
		expect(aliasesOf("lateping")).toEqual({ "/lateping", "/lp", ":lateping", ":lp", ";lp" })
		later:Destroy()
		world:run(0.2)
		expect(#aliasesOf("lateping")).toBe(6)

		-- changing the prefixes re-aliases every command
		aRemote.Settings:Fire({ prefix = { "!" } })
		world:run(0.5)
		expect(_K.Data.settings.prefix).toEqual({ "!" })
		expect(aliasesOf("serverlock")).toEqual({ "!serverlock", "!slock", "/serverlock", "/slock" })
		expect(_K.chatCommandAlias("serverlock")).toBe("!serverlock")
		folder:FindFirstChild("serverlock").Triggered:Fire({ UserId = 101 }, "!slock")
		world:run(1)
		expect(_K._serverLock).toBe(srvAdmin.Name)
		_K._serverLock = nil

		-- chat commands missing required arguments hand off to the client CommandBar without firing server error notifications
		local adminNotes = {}
		aRemote.Notify:Connect(function(props)
			table.insert(adminNotes, props.Text)
		end)
		local beforeForwarded = #forwarded
		_K.Data.roles.creator.limits = { commands = 1, cooldown = 10, targets = 10 }
		_K.Process.resetLimit(101)
		folder:FindFirstChild("announce").Triggered:Fire({ UserId = 101 }, "/announce ")
		expect(_K.Process.onCooldown(_K, 101)).toBe(true)
		world:run(1)
		_K.Process.resetLimit(101)
		_K.Data.roles.creator.limits = nil
		expect(#forwarded).toBe(beforeForwarded + 1)
		expect(forwarded[#forwarded].text).toBe("!announce")
		expect(forwarded[#forwarded].clientOnly).toBe(true)
		expect(#adminNotes).toBe(0)

		-- commandBarRank = false disables the missing-arg handoff so server reports the missing argument error
		_K.Data.settings.commandBarRank = false
		folder:FindFirstChild("announce").Triggered:Fire({ UserId = 101 }, "/announce ")
		world:run(1)
		expect(#adminNotes > 0).toBe(true)
		_K.Data.settings.commandBarRank = 0
		table.clear(adminNotes)

		-- explicit invalid arguments still report the server validation error
		folder:FindFirstChild("ban").Triggered:Fire({ UserId = 101 }, "/ban nonexistentplayer")
		world:run(1)
		expect(#adminNotes > 0).toBe(true)

		-- VIP bubble display on VIP command, commandBarRank gating, and sync cleanup when a command is removed from commandsList
		_K.Data.settings.vip = true
		local srvAdminChar = sh.env.Instance.new("Model")
		srvAdmin.Character = srvAdminChar
		local bubblesFired = {}
		local origBubbleFireAll = _K.Remote.DisplayBubble.FireAll
		_K.Remote.DisplayBubble.FireAll = function(_self, char, w)
			table.insert(bubblesFired, { char = char, word = w })
		end
		folder:FindFirstChild("fire").Triggered:Fire({ UserId = 101 }, "!fire me")
		world:run(0.5)
		expect(#bubblesFired).toBe(1)
		expect(bubblesFired[1].char).toBe(srvAdminChar)
		expect(bubblesFired[1].word).toBe("!fire")
		_K.Remote.DisplayBubble.FireAll = origBubbleFireAll

		-- Direct refreshCommand without batchSkipped logs skipped aliases immediately
		_K.ChatCommands.taken["!lateping"] = true
		_K.ChatCommands.refreshCommand(_K.Registry.commands.lateping)
		world:run(0.2)
		expect(string.find(skippedLog(), "!lateping", 1, true) ~= nil).toBe(true)

		-- Removing lateping from commandsList and refreshing cleans up its TextChatCommand instances
		local lpIdx = table.find(_K.Registry.commandsList, _K.Registry.commands.lateping)
		if lpIdx then
			table.remove(_K.Registry.commandsList, lpIdx)
		end
		_K.ChatCommands.refresh()
		expect(_K.ChatCommands.instances.lateping).toBeNil()
		expect(_K.ChatCommands.aliases.lateping).toEqual({})

		-- chat text is never logged, and the setting can't turn that back on
		aRemote.Settings:Fire({ saveChatLogs = true })
		world:run(0.5)
		expect(_K.Data.savedSettings.saveChatLogs).toBe(false)

		-- turning chat commands off disables every instance, so lines reach chat again
		aRemote.Settings:Fire({ chatCommands = false })
		world:run(0.5)
		for _, instance in folder:GetChildren() do
			expect(instance.Enabled).toBe(false)
		end
		folder:FindFirstChild("serverlock").Triggered:Fire({ UserId = 101 }, "!serverlock")
		world:run(1)
		expect(_K._serverLock).toBeNil()
	end)

	test("other prefixes than single symbols get no chat aliases and primary slash alias leads", function()
		local world = sert.sim.new({ backing = true })
		local server = world:server()
		local sh = Harness.newPeerEnv(server, { isStudio = false })
		sh.env.game._props.CreatorId = 101
		local _K: any
		server:spawn(function()
			_K = sh:requireK()
			_K.initialize({
				bans = {},
				userRoles = {},
				friendRoles = {},
				prefix = { "k", ";" },
				commands = {},
				roles = Harness.defaultRoles(),
			})
		end)
		world:run(2)
		local folder = sh.env.game:GetService("TextChatService"):FindFirstChild("TextChatCommands_KA")
		local kill = folder:FindFirstChild("kill")
		expect(kill.PrimaryAlias).toBe("/kill")
		expect(kill.SecondaryAlias).toBe(";kill")
		expect(kill.AutocompleteVisible).toBe(false)
		-- a letter prefix still parses, it just isn't a chat alias
		expect(_K.chatCommandAlias("kill")).toBe(";kill")
		expect(_K.ChatCommands.alias("nosuchcommand")).toBeNil()
	end)
end)

describe("Chat and Server · Saved logs, sync hooks & 60s command log reveal", function()
	test("CHAT logs are dropped on load while command logs are preserved and sync hooks fire around loads", function()
		local world = sert.sim.new({ backing = true })
		local s1 = world:server({ skew = 0 })
		local h1 = Harness.newPeerEnv(s1, { isStudio = false })
		local Data1 = h1:requireData()
		Data1.defaultSettings = table.clone(Data1.settings)
		Data1.savedSettings = table.clone(Data1.settings)
		local Hook1 = h1:requireShared("Hook")
		local Z1 = h1.env:require(h1.KA:WaitForChild("Z"))
		Z1.BUFFER = buffer.create(4 * 1024 ^ 2)

		local scope = "_K_LogsHooks"
		local rawStore = h1.env.game:GetService("DataStoreService"):GetDataStore("_KData", scope)
		local now = h1.env.workspace:GetServerTimeNow()
		local COMMAND, CHAT = string.char(6), string.char(5)
		rawStore:SetAsync(
			"Logs_1",
			Z1.ser(Data1.Schema.logsV0, {
				{ level = COMMAND, from = 101, name = "A", text = ";announce secret words", time = now - 3 },
				{ level = COMMAND, from = 101, name = "A", text = ";kill me ;announce hi ;nosuch x", time = now - 2 },
				{ level = CHAT, from = 101, name = "A", text = "old chat line", time = now - 1 },
				{ level = string.char(1), from = 101, name = "A", text = "info ;announce kept", time = now },
			})
		)
		rawStore:SetAsync("Main", { { ["202"] = { "Synced", { "mod" } } }, { prefix = "!" } })

		local fired = {}
		for _, name in { "preSyncMain", "postSyncMain", "preSyncLogs", "postSyncLogs" } do
			Hook1[name]:Connect(function(value)
				table.insert(fired, { name = name, value = value })
			end)
		end
		s1:spawn(function()
			Data1.initialize(scope)
			Data1.ensureLogsLoaded()
		end)
		world:run(3)

		local texts = {}
		for _, log in Data1.logs do
			table.insert(texts, log[1])
		end
		table.sort(texts)
		expect(texts).toEqual({ ";announce secret words", ";kill me ;announce hi ;nosuch x", "info ;announce kept" })

		local names = {}
		for _, item in fired do
			table.insert(names, item.name)
			if item.name == "postSyncMain" then
				expect(item.value).toBe(Data1)
			end
		end
		expect(names).toEqual({ "preSyncMain", "postSyncMain", "preSyncLogs", "postSyncLogs" })
		expect(Data1.members["202"] ~= nil).toBe(true)
	end)

	test(
		"command logs filter freeText for broadcast, reveal immediately off cooldown, and reveal after 60s when cooling down",
		function()
			local world = sert.sim.new({ backing = true })
			local server = world:server({ jobId = "reveal-job" })
			local sh = Harness.newPeerEnv(server, { isStudio = false, jobId = "reveal-job", placeId = 1000 })
			sh.env.game._props.CreatorId = 101
			local textMethods = rawget(sh.env.game:GetService("TextService"), "_methods")
			textMethods.FilterStringAsync = function(_self, text)
				local res = string.gsub(text, "badword", "#######")
				return {
					GetNonChatStringForBroadcastAsync = function()
						return res
					end,
				}
			end

			local _K = sh:requireK()
			_K.Data.creatorId = 101
			_K.Data.SEPARATE_DATASTORE = false
			Harness.seedRoles(_K.Data)
			local p1 = sh.env:addPlayer(101, "Admin1")
			local p2 = sh.env:addPlayer(102, "Admin2")
			local p3 = sh.env:addPlayer(103, "Admin3")
			p1:SetAttribute("_K_READY", true)
			p2:SetAttribute("_K_READY", true)
			p3:SetAttribute("_K_READY", true)
			_K.Auth.userRoleAdd(101, "superadmin")
			_K.Auth.userRoleAdd(102, "superadmin")
			_K.Auth.userRoleAdd(103, "superadmin")

			-- p1 can chat with p3 (103), but cannot chat with p2 (102)
			local tcsMethods = rawget(sh.env.game:GetService("TextChatService"), "_methods")
			tcsMethods.CanUsersChatAsync = function(_self, _from, to)
				return to ~= 102
			end

			local receivedBy1, receivedBy2, receivedBy3 = {}, {}, {}
			_K.Remote.Log.Fire = function(_self, plr, log)
				if plr == p1 then
					table.insert(receivedBy1, table.clone(log))
				elseif plr == p2 then
					table.insert(receivedBy2, table.clone(log))
				elseif plr == p3 then
					table.insert(receivedBy3, table.clone(log))
				end
			end

			-- 1. First command log off cooldown is immediately revealed to all admins and Sync.logs
			local firstLog = _K.log(";kick Guest First reason", "COMMAND", 101, true, ";kick Guest …")
			world:run(0.1)
			expect(firstLog[1]).toBe(";kick Guest First reason")
			expect(receivedBy1[#receivedBy1][1]).toBe(";kick Guest First reason")
			expect(receivedBy2[#receivedBy2][1]).toBe(";kick Guest First reason")
			expect(receivedBy3[#receivedBy3][1]).toBe(";kick Guest First reason")
			expect(_K.Data.Sync.logs[#_K.Data.Sync.logs][1]).toBe(";kick Guest First reason")

			-- 2. Second command log within 60s sends full log to chat-allowed p3 and redacted liveText to restricted p2, then reveals after 60s
			local syncCountBefore = #_K.Data.Sync.logs
			_K.log(";kick Guest Second reason", "COMMAND", 101, true, ";kick Guest …")
			world:run(0.1)
			local secondStored = _K.Data.logs[#_K.Data.logs]
			expect(secondStored[1]).toBe(";kick Guest …")
			expect(receivedBy1[#receivedBy1][1]).toBe(";kick Guest Second reason")
			expect(receivedBy2[#receivedBy2][1]).toBe(";kick Guest …")
			expect(receivedBy3[#receivedBy3][1]).toBe(";kick Guest Second reason")
			expect(#_K.Data.Sync.logs).toBe(syncCountBefore)
			local p3CountBeforeReveal = #receivedBy3

			-- Another redacted log 30s later must not flush early when the first 60s timer fires
			world:run(30)
			_K.log(";kick Guest Later reason", "COMMAND", 101, true, ";kick Guest …")
			world:run(0.1)
			local laterStored = _K.Data.logs[#_K.Data.logs]
			expect(laterStored[1]).toBe(";kick Guest …")
			expect(receivedBy3[#receivedBy3][1]).toBe(";kick Guest Later reason")
			p3CountBeforeReveal = #receivedBy3

			-- Advance 31s (61s total): secondStored reveals to p2, while p3 (already revealed) gets no duplicate and laterStored remains redacted
			world:run(31)
			expect(secondStored[1]).toBe(";kick Guest Second reason")
			expect(receivedBy2[#receivedBy2][1]).toBe(";kick Guest Second reason")
			expect(#receivedBy3).toBe(p3CountBeforeReveal)
			expect(_K.Data.Sync.logs[#_K.Data.Sync.logs][1]).toBe(";kick Guest Second reason")
			expect(laterStored[1]).toBe(";kick Guest …")

			world:run(31)
			expect(laterStored[1]).toBe(";kick Guest Later reason")
			expect(receivedBy2[#receivedBy2][1]).toBe(";kick Guest Later reason")
			expect(_K.Data.Sync.logs[#_K.Data.Sync.logs][1]).toBe(";kick Guest Later reason")

			-- 3. If CanUserChatAsync is false, liveText stays permanently redacted for other admins and Sync.logs
			tcsMethods.CanUserChatAsync = function()
				return false
			end
			_K.log(";kick Guest Muted reason", "COMMAND", 101, true, ";kick Guest …")
			world:run(0.1)
			local mutedStored = _K.Data.logs[#_K.Data.logs]
			expect(mutedStored[1]).toBe(";kick Guest …")
			expect(receivedBy1[#receivedBy1][1]).toBe(";kick Guest Muted reason")
			expect(receivedBy2[#receivedBy2][1]).toBe(";kick Guest …")
			expect(receivedBy3[#receivedBy3][1]).toBe(";kick Guest …")
			expect(_K.Data.Sync.logs[#_K.Data.Sync.logs][1]).toBe(";kick Guest …")
			world:run(61)
			expect(mutedStored[1]).toBe(";kick Guest …")
		end
	)

	test(
		"Wally partial-table _K.initialize seeds default roles, isolates private-server DataStore scope without userRoles, and backfills admin data on roleAdded",
		function()
			local world = sert.sim.new({ backing = true })
			local server = world:server({ jobId = "wally-init-job" })
			local sh = Harness.newPeerEnv(server, { isStudio = false, jobId = "wally-init-job", placeId = 2000 })
			sh.env.game._props.CreatorId = 101
			sh.env.game._props.PrivateServerId = "priv-uuid-1"
			sh.env.game._props.PrivateServerOwnerId = 555

			local _K = sh:requireK()
			_K.Data.IS_PRIVATE_SERVER = true

			-- Initialize with a minimal Wally-style table omitting roles, bans, and userRoles
			_K.initialize({
				prefix = "!",
				roles = {
					mod = { color = "#123456" },
				},
			})
			world:run(1)

			-- All 6 default roles exist and partial override on mod was merged
			for _, roleKey in { "everyone", "vip", "mod", "admin", "superadmin", "creator" } do
				expect(_K.Data.roles[roleKey] ~= nil).toBe(true)
			end
			expect(_K.Data.roles.mod.color).toBe("#123456")
			expect(_K.Data.roles.mod._rank).toBe(2)
			expect(type(_K.Data.bans)).toBe("table")
			expect(_K.Data.SEPARATE_DATASTORE).toBe(true)

			-- Promoting an already-ready player mid-session backfills Bans, Members, ReservedServers, and Logs
			local p2 = sh.env:addPlayer(202, "PromotedAdmin")
			p2:SetAttribute("_K_READY", true)
			local backfilled = {}
			_K.Remote.Bans.Fire = function(_self, plr)
				if plr == p2 then
					backfilled.bans = true
				end
			end
			_K.Remote.Members.Fire = function(_self, plr)
				if plr == p2 then
					backfilled.members = true
				end
			end
			_K.Remote.ReservedServers.Fire = function(_self, plr)
				if plr == p2 then
					backfilled.reserved = true
				end
			end
			_K.Remote.Logs.Fire = function(_self, plr)
				if plr == p2 then
					backfilled.logs = true
				end
			end

			_K.Auth.userRoleAdd(202, "superadmin")
			expect(backfilled.bans).toBe(true)
			expect(backfilled.members).toBe(true)
			expect(backfilled.reserved).toBe(true)
			expect(backfilled.logs).toBe(true)

			-- _K.chatCommandAlias, _K.removeExcessLogs logsVersion, and client _K.log log[6]
			_K.ChatCommands = {
				alias = function(w)
					return if w == "fly" then "/fly" else nil
				end,
			}
			expect(_K.chatCommandAlias("FLY")).toBe("/fly")
			expect(_K.chatCommandAlias("KILL")).toBe("!kill")
			_K.ChatCommands = nil
			local origPrefixes = _K.Data.settings.prefix
			_K.Data.settings.prefix = {}
			expect(_K.chatCommandAlias("KILL")).toBe(";kill")
			_K.Data.settings.prefix = origPrefixes

			local prevLogsVer = _K.Data.logsVersion or 0
			local origLimit = _K.Logger.limit
			_K.Logger.limit = 1
			_K.Logger:log("one", "INFO")
			_K.Logger:log("two", "INFO")
			_K.removeExcessLogs()
			expect(#_K.Data.logs).toBe(1)
			expect(_K.Data.logsVersion).toBe(prevLogsVer + 1)
			_K.Logger.limit = origLimit

			_K.IsServer = false
			_K.IsClient = true
			local clientInfoLog = _K.log("client info", "INFO")
			local clientChatLog = _K.log("client chat", "CHAT")
			expect(clientInfoLog ~= nil and clientInfoLog[6] == true).toBe(true)
			expect(clientChatLog ~= nil and clientChatLog[6] == nil).toBe(true)
			_K.IsClient = false
			_K.IsServer = true
		end
	)
end)

return {}
