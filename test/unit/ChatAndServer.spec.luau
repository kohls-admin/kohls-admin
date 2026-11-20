local Harness = require("./Harness")
local sert = require("../sert")

local describe, test = sert.describe, sert.test

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
				sert.eq(
					Chat.restoreRichText(simple),
					"<b>bold</b> <i>italic</i> <u>under</u> <s>strike</s> <sc>small</sc> <uc>upper</uc><br />line2"
				)

				-- 2. Valid <font> with hex color (#rrggbb and #rgb), rgb(r,g,b), clamped size, and transparency
				local fontHex = esc('<font color="#ff0000" size="20" transparency="0.5">red</font>')
				sert.eq(Chat.restoreRichText(fontHex), '<font color="#ff0000" size="20" transparency="0.5">red</font>')

				local fontShortAndRgb =
					esc('<font color="#0f0">green</font> <font color="rgb(255,128,0)" size="99">clamped</font>')
				sert.eq(
					Chat.restoreRichText(fontShortAndRgb),
					'<font color="#0f0">green</font> <font color="rgb(255,128,0)" size="40">clamped</font>'
				)

				-- 3. Compact mode: strips <br/> to space and drops font size (inserting transparency="0" if size was sole attribute)
				local compactInput =
					esc('<font size="24">big</font><br/><font color="#ff0000" size="24">colored</font>')
				sert.eq(
					Chat.restoreRichText(compactInput, true),
					'<font transparency="0">big</font> <font color="#ff0000">colored</font>'
				)

				-- 4. Rejects unbalanced tags, disallowed tags (<script>), and invalid <font> attributes (face, weight, bad color)
				local unbalanced = esc("<b>hello</i>")
				sert.eq(Chat.restoreRichText(unbalanced), unbalanced)

				local unclosed = esc("<b>hello")
				sert.eq(Chat.restoreRichText(unclosed), unclosed)

				local scriptTag = esc("<script>evil()</script>")
				sert.eq(Chat.restoreRichText(scriptTag), scriptTag)

				local badFont = esc('<font color="#ff0000" size="20" face="Gotham" weight="Bold">bad attrs</font>')
				sert.eq(Chat.restoreRichText(badFont), badFont)

				local badRgb = esc('<font color="rgb(999,0,0)">overflow</font>')
				sert.eq(Chat.restoreRichText(badRgb), badRgb)
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

			sert.eq(Chat.hasRestrictedPeer, nil)
			sert.eq(type(Chat.canUsersChat), "function")

			-- cooldown returns nil first, then wait string, then nil after duration expires (and defaults to shared "text" key)
			sert.eq(Chat.cooldown(guest.UserId, "customKey", 5), nil)
			local waitMsg = Chat.cooldown(guest.UserId, "customKey", 5)
			sert.eq(type(waitMsg), "string")
			sert.eq(string.find(waitMsg :: string, "Wait", 1, true) ~= nil, true)
			h.env:step(5.5)
			sert.eq(Chat.cooldown(guest.UserId, "customKey", 5), nil)

			-- limitBroadcast checks CanUserChatAsync and enforces the shared 60s text cooldown
			sert.eq(Chat.limitBroadcast(admin.UserId), nil)
			sert.eq(Chat.limitBroadcast(admin.UserId) ~= nil, true)
			sert.eq(Chat.cooldown(admin.UserId) ~= nil, true)
			h.env:step(61)

			-- limitReason checks nil, CanUserChatAsync, and unconditional shared 60s cooldown (even when CanUsersChatAsync is true)
			sert.eq(Chat.limitReason(admin.UserId, nil), nil)
			local tcs = h.env.game:GetService("TextChatService")
			local tcsMethods = rawget(tcs, "_methods")
			local origCanUserChat = tcsMethods.CanUserChatAsync
			local origCanUsersChat = tcsMethods.CanUsersChatAsync
			tcsMethods.CanUsersChatAsync = function()
				return true
			end

			sert.eq(Chat.limitReason(admin.UserId, "First valid reason"), "First valid reason")
			-- limitBroadcast shares the same 60s bucket with limitReason
			sert.eq(Chat.limitBroadcast(admin.UserId) ~= nil, true)

			local notifiedReason = nil
			Remote.Notify.Fire = function(_self, _plr, payload)
				notifiedReason = payload.Text
			end
			sert.eq(Chat.limitReason(admin.UserId, "Second rate-limited reason"), nil)
			sert.eq(string.find(tostring(notifiedReason), "Reason removed:", 1, true) ~= nil, true)

			h.env:step(61)
			tcsMethods.CanUsersChatAsync = origCanUsersChat

			-- CanUserChatAsync returning false blocks limitReason and limitBroadcast without spending cooldown
			tcsMethods.CanUserChatAsync = function()
				return false
			end
			sert.eq(Chat.limitBroadcast(guest.UserId), "User cannot chat")
			sert.eq(Chat.limitReason(guest.UserId, "Blocked by privacy"), nil)
			tcsMethods.CanUserChatAsync = origCanUserChat

			-- canUsersChat allows self, delegates to TextChatService outside Studio, fails closed on error,
			-- and allows restricted roles in Studio
			sert.eq(Chat.canUsersChat(guest.UserId, guest.UserId), true)
			tcsMethods.CanUsersChatAsync = function()
				return true
			end
			sert.eq(Chat.canUsersChat(admin.UserId, guest.UserId), true)
			tcsMethods.CanUsersChatAsync = function()
				return false
			end
			sert.eq(Chat.canUsersChat(admin.UserId, guest.UserId), false)
			tcsMethods.CanUsersChatAsync = function()
				error("TextChatService unavailable")
			end
			sert.eq(Chat.canUsersChat(admin.UserId, guest.UserId), false)
			tcsMethods.CanUsersChatAsync = origCanUsersChat

			local studioEnv = Harness.newEnv({ isStudio = true })
			local studioAuth = studioEnv:requireAuth()
			local studioChat = studioEnv:requireShared("Chat")
			local studioAdmin = studioEnv.env:addPlayer(30, "StudioAdmin")
			studioAuth.userRoleAdd(studioAdmin.UserId, "admin")
			local studioTcsMethods = rawget(studioEnv.env.game:GetService("TextChatService"), "_methods")
			studioTcsMethods.CanUsersChatAsync = function()
				return false
			end
			sert.eq(studioChat.canUsersChat(studioAdmin.UserId, 10), true)
			sert.eq(studioChat.canUsersChat(10, studioAdmin.UserId), false)
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
			sert.eq(badId, nil)
			sert.eq(string.find(tostring(badErr), "must be run by a player", 1, true) ~= nil, true)

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
			sert.eq(type(id), "string")
			sert.eq(err, nil)
			sert.eq(reached(delivered), { 101, 102, 103 })
			sert.eq(reached(), { 101, 102, 103 })
			sert.eq(argObj.parsedArgs, { "Hello <b>now</b> #######" })
			sert.eq(argObj.redactLog, false)
			sert.eq(filtered, {
				{
					text = rawText,
					from = 101,
					context = h.env.globals.Enum.TextFilterContext.PublicChat,
				},
			})
			for _, packet in packets do
				sert.eq(packet.kind, "message")
				sert.eq(packet.text, Util.String.escapeRichText("Hello <b>now</b> #######"))
				sert.eq(packet.from, 101)
				sert.eq(packet.data, 7)
				sert.eq(packet.id, id)
			end
			-- nothing goes through TextChannels
			for _, child in tcs:GetDescendants() do
				sert.eq(child:IsA("TextChannel"), false)
			end
			sert.eq(Chat.isChannel, nil)
			sert.eq(Chat.canReply, nil)

			-- every non-self send (including chat-allowed friends, broadcasts, and votes) shares the 60s cooldown
			table.clear(packets)
			local limitedId, limitedErr = Chat.send(context, "hint", "Too soon", { target })
			sert.eq(limitedId, nil)
			sert.eq(string.find(tostring(limitedErr), "Wait", 1, true) ~= nil, true)
			sert.eq(#packets, 0)

			local friendBlockedId, friendBlockedErr = Chat.send(context, "hint", "Friend too soon", { friend })
			sert.eq(friendBlockedId, nil)
			sert.eq(string.find(tostring(friendBlockedErr), "Wait", 1, true) ~= nil, true)
			sert.eq(#packets, 0)

			local bcastBlockedId, bcastBlockedErr = Chat.send(context, "message", "Broadcast too soon")
			sert.eq(bcastBlockedId, nil)
			sert.eq(string.find(tostring(bcastBlockedErr), "Wait", 1, true) ~= nil, true)
			sert.eq(#packets, 0)

			local voteBlockedId, voteBlockedErr = Chat.send(context, "vote", "Vote too soon?", { friend })
			sert.eq(voteBlockedId, nil)
			sert.eq(string.find(tostring(voteBlockedErr), "Wait", 1, true) ~= nil, true)
			sert.eq(#packets, 0)

			-- messaging only yourself is never limited and keeps freeText redactLog unset
			table.clear(packets)
			local selfArg = {
				rawArg = "Self note",
				parsedArgs = { "Self note" },
				rawType = { freeText = true },
				filtered = nil :: boolean?,
				redactLog = nil :: boolean?,
			}
			local _, _, selfOnly = Chat.send(
				{ from = sender.UserId, fromPlayer = sender, args = { selfArg } },
				"hint",
				"Self note",
				{ sender }
			)
			sert.eq(reached(selfOnly), { 101 })
			sert.eq(selfArg.filtered, true)
			sert.eq(selfArg.redactLog, nil)

			h.env:step(61)
			local voteId, voteErr, voters = Chat.send(context, "vote", "After 60s?", { target })
			sert.eq(type(voteId), "string")
			sert.eq(voteErr, nil)
			sert.eq(reached(voters), { 102 })
			h.env:step(61)

			-- a sender who can't chat sends nothing and keeps their cooldown
			tcsMethods.CanUserChatAsync = function()
				return false
			end
			local blockedId, blockedErr = Chat.send(context, "message", "Blocked")
			sert.eq(blockedId, nil)
			sert.eq(blockedErr, "User cannot chat")
			tcsMethods.CanUserChatAsync = function()
				return true
			end

			-- text that can't be filtered isn't sent and does not spend the cooldown
			table.clear(packets)
			textMethods.FilterStringAsync = function()
				error("filter down")
			end
			local unfilteredId, unfilteredErr = Chat.send(context, "message", "Unfiltered")
			sert.eq(unfilteredId, nil)
			sert.eq(string.find(tostring(unfilteredErr), "filtered", 1, true) ~= nil, true)
			textMethods.FilterStringAsync = function()
				return {
					GetNonChatStringForBroadcastAsync = function()
						error("broadcast filter down")
					end,
				}
			end
			sert.eq((Chat.send(context, "message", "Unfiltered")), nil)
			sert.eq(#packets, 0)
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
			sert.eq(type(recoveredId), "string")
			sert.eq(recoveredErr, nil)
			sert.eq(reached(recoveredDelivered), { 102 })
			table.clear(packets)

			-- global messages were already filtered in their origin server
			local globalId, globalErr, globalDelivered =
				Chat.send({ global = true, from = 999 }, "announce", "<b>see</b> global", nil, 10)
			sert.eq(type(globalId), "string")
			sert.eq(globalErr, nil)
			sert.eq(reached(globalDelivered), { 101, 102, 103 })
			sert.eq(packets[1].text, Util.String.escapeRichText("<b>see</b> global"))
			sert.eq(packets[1].from, 999)
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
			sert.eq(reached, { 101, 102 })
			-- other senders are still checked
			table.clear(reached)
			local _, err = Chat.send({ from = 102, fromPlayer = other }, "message", "Not a developer")
			sert.eq(err, "User cannot chat")
			sert.eq(#reached, 0)
		end)

		test("Chat.commandPrefixes keeps single non-alphanumeric characters once", function()
			local Chat = Harness.newEnv():requireShared("Chat")
			sert.eq(Chat.commandPrefixes({ ";", ":", ";", "a", "1", " ", "!!", 5 :: any, "/" }), {
				";",
				":",
				"/",
			})
			sert.eq(Chat.commandPrefixes(nil), {})
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
			sert.eq(preWaitedText, "<b>PreWaited</b>")
			sert.eq(#receivedMsgs, 1)

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

			sert.eq(waitedText, '<b>Hello</b> <font color="#00ff00">Client</font>')
			sert.eq(#receivedMsgs, 2)
			sert.eq(receivedMsgs[2].text, '<b>Hello</b> <font color="#00ff00">Client</font>')
			sert.eq(receivedMsgs[2].from, 999)
			sert.eq(receivedMsgs[2].data, 15)

			-- 3. waitForMessage timeout returns nil when id never arrives
			local timedOutVal = "unset"
			client:spawn(function()
				timedOutVal = cChat.waitForMessage("nonexistent-id", 0.2)
			end)
			world:run(0.5)
			sert.eq(timedOutVal, nil)

			-- 4. TextChannels are never touched: OnIncomingMessage can't be set and message text is empty with
			-- platform-integrated chat
			local cTcs = ch.env.game:GetService("TextChatService")
			local kaChannel = ch.env.Instance.new("TextChannel")
			kaChannel.Name = "Admin"
			kaChannel:SetAttribute("KohlsAdmin", true)
			kaChannel.Parent = cTcs
			world:run(0.1)
			sert.eq(kaChannel.OnIncomingMessage, nil)
			local HttpService = ch.env.game:GetService("HttpService")
			kaChannel.MessageReceived:Fire({
				MessageId = "m-1",
				Metadata = HttpService:JSONEncode({ k = "announce", id = "chan-msg-1", d = 5 }),
				Text = "",
				Status = ch.env.globals.Enum.TextChatMessageStatus.Success,
				TextSource = { UserId = 101 },
			})
			world:run(0.2)
			sert.eq(#receivedMsgs, 2)
			sert.eq(cChat.onMessage ~= nil and cChat.send == nil, true)

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
				sert.spy(badgeService, "AwardBadgeAsync", function()
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
					sert.eq(sh:requireK(), _K)
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
					sert.eq(_K.initialize(), _K)
				end)
				world:run(2)
				sert.eq(_K.ready, true)
				sert.eq(sh.KA:GetAttribute("ServerStartTime") ~= nil, true)
				sert.eq(_K.Server:FindFirstChild("Shared").Value, sh.KA.Shared)
				sert.eq(sh.KA.Name, "Kohl's Admin Source")
				sert.eq(sh.KA.Parent, sh.env.game:GetService("ReplicatedStorage"))
				sert.eq(sh.KA:FindFirstChild("Client").Enabled, true)
				sert.eq(sh.KA:FindFirstChild("Addons") ~= nil, true)
				sert.eq(sh.env.game:GetService("ServerStorage"):FindFirstChild("_KServerAddons") ~= nil, true)
				sert.eq(_K.Data.bans["303"][1] ~= nil, true)
				sert.eq(type(_K.LoadScript), "function")
				sert.eq(type(_K.Data.settingsModuleData), "table")
				sert.eq(_K.Data.settingsModuleData.roles.default, nil)
				sert.eq(_K.Data.settingsModuleData.roles[1], nil)
				sert.eq(_K.Data.roles.everyone.name, "EveryoneCustom")
				sert.eq(_K.Data.roles.vip._rank, 0)
				sert.eq(_K.Data.roles.everyone.permissions.targetOthers, false)
				sert.eq(_K.Data.roles.customStr._key, "customStr")
				sert.eq(_K.Data.roles.customStr.name, "CustomRole")
				sert.eq(_K.Data.roles.customStr.permissions.targetOthers, true)
				sert.eq(_K.Data.roles.customDef._rank, 0)
				sert.eq(_K.Data.roles.customDef.permissions.targetOthers, false)
				sert.eq(table.find(_K.Data.rolesList, _K.Data.roles.customStr) ~= nil, true)
				sert.eq(_K.Data.rolesList[1]._rank <= _K.Data.rolesList[#_K.Data.rolesList]._rank, true)
				sert.eq(_K.Data.defaultSettings.vip, true)
				sert.eq(_K.Data.defaultSettings.splitKey, " ")
				sert.eq(_K.Data.defaultSettings.welcomeBadgeId, 1234)
				sert.eq(_K.Data.settings, _K.Data.savedSettings)
				sert.eq(_K.Data.roles.mod.commands.ban, true)
				sert.eq(_K.Data.roles.mod.commands.kick, true)
				sert.eq(badgesAwarded > 0, true)
				sert.eq(_K.Data.async.asset[777], { "vip" })
				sert.eq(_K.Data.async.gamepass[888], { "vip" })
				sert.eq(_K.Data.async.subscription["sub_vip"], { "vip" })
				sert.eq(table.find(_K.Data.roles.vip.assets, 777) ~= nil, true)
				sert.eq(table.find(_K.Data.roles.vip.gamepasses, 888) ~= nil, true)
				sert.eq(table.find(_K.Data.roles.vip.subscriptions, "sub_vip") ~= nil, true)
				sert.eq(_K.Data.roles.vip.gamepasss ~= nil, true)
				sert.eq(_K.Data.async.group[100], { { rank = 10, roles = { "mod" } } })
				sert.eq(_K.Data.async.group[200], { { rank = 5, roles = { "vip" } } })
				sert.eq(_K.Data.async.group[300], { { rank = 15, roles = { "mod" } } })
				sert.eq(_K.Data.friendRoles, { "vip" })
				sert.eq(_K.Data.savedSettings.theme, "MigratedTheme")

				-- _K.log edge cases: logsHidden, >16KB truncation, liveText, and removeExcessLogs (src/init.luau lines 106-162)
				_K.Data.logsHidden[9999] = true
				sert.eq(_K.log("hidden", "INFO", 9999), nil)
				_K.Data.logsHidden[9999] = nil

				local bigLog = _K.log(string.rep("X", 17000), "COMMAND", 101, true, "live replacement")
				sert.eq(bigLog ~= nil, true)
				local origLimit = _K.Logger.limit
				_K.Logger.limit = 5
				world:run(0.2)
				sert.eq(#_K.Data.logs <= 5, true)
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
				sert.eq(srvAdmin:GetAttribute("_K_READY"), true)
				sert.eq(srvAdmin:GetAttribute("_KPlatform"), "PC")
				sert.eq(srvAdmin:GetAttribute("_KSessionStart"), 1700000000)
				sert.eq(srvGuest:GetAttribute("_K_READY"), true)
				sert.eq(srvGuest:GetAttribute("_KPlatform"), "Mobile")
				sert.eq(srvMod:GetAttribute("_K_READY"), true)
				sert.eq(srvMod:GetAttribute("_KPlatform"), nil)
				sert.eq(srvMod:GetAttribute("_KSessionStart"), nil)

				sert.eq(adminInitPayload ~= nil, true)
				sert.eq(adminInitPayload.bans ~= nil, true)
				sert.eq(adminInitPayload.logs ~= nil, true)
				sert.eq(adminInitPayload.reserved ~= nil, true)
				sert.eq(adminInitPayload.servers ~= nil, true)

				sert.eq(guestInitPayload ~= nil, true)
				sert.eq(guestInitPayload.bans, nil)
				sert.eq(guestInitPayload.logs, nil)

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
				sert.eq(cmdFolder ~= nil, true)
				local headless = cmdFolder:FindFirstChild("headless")
				sert.eq(headless.PrimaryAlias, "/headless")
				sert.eq(headless.SecondaryAlias, ";headless")
				sert.eq(headless.Enabled, true)
				sert.eq(headless.AutocompleteVisible, false)
				local ping = cmdFolder:FindFirstChild("ping")
				sert.eq(ping.PrimaryAlias, "/ping")
				sert.eq(ping.SecondaryAlias, ";ping")
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
				sert.eq(bubbles, { ";headless" })
				sert.eq(guestBubbleFired, true)

				-- later Inits are held to the same values
				for _, attributes in
					{ { Platform = "Desktop", SessionStart = 0 / 0 }, { Platform = 1, SessionStart = "1" } }
				do
					mRemote.Init:Fire({ Attributes = attributes })
				end
				world:run(1)
				sert.eq(srvMod:GetAttribute("_KPlatform"), nil)
				sert.eq(srvMod:GetAttribute("_KSessionStart"), nil)
				mRemote.Init:Fire({ Attributes = { Platform = "VR", SessionStart = -1700000010 } })
				world:run(1)
				sert.eq(srvMod:GetAttribute("_KPlatform"), "VR")
				sert.eq(srvMod:GetAttribute("_KSessionStart"), -1700000010)

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
				sert.eq(_K.Auth.hasRole(202, "mod"), false)
				sert.eq(passChecks, 3) -- it gives up after three checks
				passChecks, ownedFromCheck = 0, 2
				MarketplaceService.PromptGamePassPurchaseFinished:Fire(srvGuest, 889, true)
				world:run(10)
				sert.eq(_K.Auth.hasRole(202, "mod"), true)
				sert.eq(passChecks, 2)
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
				sert.eq(sawDamage, true)
				sert.eq(damage40Count, 1)
				sert.eq(damage60Count, 1)
				sert.eq(sawDeath, true)
				sert.eq(sawKill, true)

				-- CharacterRemoving cleans up connections synchronously before deferred Destroy
				srvGuest.CharacterRemoving:Fire(char)
				hum.Died:Fire()
				world:run(0.1)
				sert.eq(char.Parent, nil)

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
				sert.eq(deathCountAfterRemove, deathCountBeforeRemove)
				sert.eq(damage90Count, 0)

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

				sert.eq(_K.Data.savedSettings.prefix, { "!" })
				sert.eq(_K.Data.savedSettings.splitKey, "/")
				sert.eq(_K.Data.savedSettings.freeAdmin, { "vip" })
				sert.eq(_K.Data.savedSettings.theme, "Cyan")
				sert.eq(_K.Data.savedSettings.themeBackgroundImage, "rbxassetid://123456")
				sert.eq(_K.Data.savedSettings.changeThemeAuthority, "Server")
				sert.eq(_K.Data.savedSettings.dashboardRank, 2)
				sert.eq(_K.Data.savedSettings.nonExistentKey, nil)
				sert.eq(sh.env.globals.typeof(_K.Data.savedSettings.themePrimary), "Color3")
				sert.eq(sh.env.globals.typeof(_K.Data.savedSettings.themeCornerRadius), "UDim")
				sert.eq(_K.Data.savedSettings.themeCornerRadius.Offset, 10)
				_K.Data.settings.testEnumSetting = nil
				_K.Data.settings.testFontSetting = nil

				-- useSavedSettings = false branch (line 788) and restore to true
				aRemote.Settings:Fire({ useSavedSettings = false })
				world:run(0.5)
				sert.eq(_K.Data.savedSettings.useSavedSettings, false)
				aRemote.Settings:Fire({ useSavedSettings = true })
				world:run(0.5)
				sert.eq(_K.Data.savedSettings.useSavedSettings, true)

				-- Restricted mod attempting freeAdmin >= own rank is blocked (line 707), non-developer (unrestricted mod) attempting freeAdmin is blocked (line 698)
				_K.Data.roles.mod.permissions.settings = true
				mRemote.Settings:Fire({
					freeAdmin = { "creator" },
				})
				world:run(0.2)
				sert.eq(_K.Data.savedSettings.freeAdmin, { "vip" })

				_K.Data.members["301"].unrestricted = { mod = true }
				mRemote.Settings:Fire({
					freeAdmin = { "mod" },
					prefix = { "?", "extra" },
				})
				world:run(0.5)
				mRemote.Settings:Fire({
					prefix = { "?" },
					splitKey = ",",
				})
				world:run(0.5)
				-- Immediate second prefix change by non-developer hits cooldown (line 860)
				mRemote.Settings:Fire({
					prefix = { ":" },
				})
				world:run(0.5)
				sert.eq(_K.Data.savedSettings.freeAdmin, { "vip" })
				sert.eq(_K.Data.savedSettings.prefix, { "?" })
				sert.eq(_K.Data.savedSettings.splitKey, ",")
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
				sert.eq(_K.Data.savedSettings.prefix, { "?" })
				sert.eq(_K.Data.savedSettings.freeAdmin, { "vip" })
				sert.eq(_K.Data.savedSettings.themeBackgroundImage, "rbxassetid://123456")
				sert.eq(_K.Data.savedSettings.saveChatLogs, false)
				sert.eq(_K.Data.savedSettings.changeThemeAuthority, "Server")
				sert.eq(_K.Data.savedSettings.theme, "Cyan")
				sert.eq(_K.Data.savedSettings.dashboardRank, 2)
				sert.eq(_K.Data.savedSettings.testStrSetting, "origStr")
				sert.eq(_K.Data.savedSettings.testTblSetting, { 1 })
				_K.Data.defaultSettings.testStrSetting = nil
				_K.Data.savedSettings.testStrSetting = nil
				_K.Data.defaultSettings.testTblSetting = nil
				_K.Data.savedSettings.testTblSetting = nil

				-- Multi-prefix existing list (#existing = 2) allows replacing with 2 prefixes (math.max(#existing, 1)); shares 60s cooldown for all roles
				_K.Data.savedSettings.prefix = { ";", "!" }
				_K.Remote.Settings._signal:Fire(srvAdmin, {
					prefix = { ";", "?" },
				})
				-- Blocked within 60s of line 852's prefix change
				sert.eq(_K.Data.savedSettings.prefix, { ";", "!" })

				world:run(61)
				_K.Remote.Settings._signal:Fire(srvAdmin, {
					prefix = { ";", "?" },
				})
				sert.eq(_K.Data.savedSettings.prefix, { ";", "?" })

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
				sert.eq(_K.Data.savedSettings.announcement, false)
				sert.eq(#_K.Data.savedSettings.announcements, 1)
				sert.eq(_K.Data.savedSettings.announcements[1].Text, "Allowed after cooldown")

				-- 4. Remote.Explorer (unauthorized guard, PASTE, DELETE Part, and DELETE Player with targetLimits)
				_K.Remote.Explorer._signal:Fire(srvGuest, "DELETE", {}) -- unauthorized guest ignored (line 910)

				local folder = sh.env.Instance.new("Folder", sh.env.workspace)
				folder.Name = "ExplorerTarget"
				local template = sh.env.Instance.new("Part", sh.env.workspace)
				template.Name = "PasteMe"
				template.Archivable = false

				-- Trigger server handler directly with server Instances (simulating Explorer remote with Instance refs)
				_K.Remote.Explorer._signal:Fire(srvAdmin, "PASTE", { template }, folder)
				sert.eq(folder:FindFirstChild("PasteMe") ~= nil, true)
				sert.eq(template.Archivable, false)

				local pasted = folder:FindFirstChild("PasteMe")
				_K.Remote.Explorer._signal:Fire(srvAdmin, "DELETE", { pasted })
				sert.eq(folder:FindFirstChild("PasteMe"), nil)

				-- Deleting a Player instance via Explorer is rejected on the server as well
				local tempVictim = sh.env:addPlayer(808, "ExplorerVictim")
				local victimParent = tempVictim.Parent
				_K.Remote.Explorer._signal:Fire(srvAdmin, "DELETE", { tempVictim })
				sert.eq(tempVictim.Parent ~= nil, true)
				sert.eq(tempVictim.Parent, victimParent)
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
				sert.eq(modPart.Parent, nil)
				sert.eq(charContainer.Parent, sh.env.workspace)
				sert.eq(adminChar.Parent, charContainer)
				sert.eq(adminHead.Parent, adminChar)
				sert.eq(sh.KA.Parent, sh.env.game:GetService("ReplicatedStorage"))
				sert.eq(sh.env.Players.Parent, sh.env.game)
				adminChar.Parent = sh.env.workspace
				charContainer:Destroy()
				_K.Data.roles.mod.commands = { ban = true }
				if _K.ChatCommands and _K.ChatCommands.folder then
					_K.Remote.Explorer._signal:Fire(srvAdmin, "DELETE", { _K.ChatCommands.folder })
					sert.eq(_K.ChatCommands.folder.Parent ~= nil, true)
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
				sert.eq(srvAdmin:GetAttribute("_KIdleTime"), 42)
				sert.eq(_K.Data.bans["404"] ~= nil, true)
				sert.eq(_K.Data.bans["405"], nil)
				sert.eq(_K.Data.bans["406"][3], -1)

				-- Mod without banasync forces duration = 0 on Remote.Ban (line 825) and is blocked from unbanning persistent ban (line 875)
				_K.Data.roles.mod.permissions.ban = true
				_K.Data.roles.mod.permissions.unban = true
				local modNotices = {}
				mRemote.Notify:Connect(function(data)
					table.insert(modNotices, data.Text)
				end)
				mRemote.Ban:Fire(407, "mod server ban", 300)
				world:run(0.05)
				mRemote.Unban:Fire(406) -- persistent ban (-1) blocked for mod without banasync
				mRemote.Ban:Fire(406, "mod server ban", 0) -- and re-banning can't demote it to a server ban
				mRemote.Unban:Fire(999999) -- non-existent ban ignored (line 863)
				world:run(1)
				sert.eq(_K.Data.bans["407"] ~= nil, true)
				sert.eq(_K.Data.bans["407"][3], nil)
				sert.eq(_K.Data.bans["406"] ~= nil, true)
				sert.eq(_K.Data.bans["406"][3], -1)
				-- the kept saved ban isn't logged as a ban, and the mod is told it was kept
				local banLogs = {}
				for _, log in _K.Data.logs do
					if string.find(log[1], "ban 40", 1, true) then
						table.insert(banLogs, log[1])
					end
				end
				sert.eq(table.find(banLogs, ";ban 407 0 mod server ban") ~= nil, true)
				sert.eq(table.find(banLogs, ";ban 406 0 mod server ban"), nil)
				sert.eq(table.find(modNotices, "Kept saved ban for <b>406</b>.") ~= nil, true)
				sert.eq(table.find(modNotices, "Kept saved ban for <b>407</b>."), nil)

				-- The admin permission from a role a non-developer gave still can't lift a saved ban
				_K.Data.roles.mod.permissions.admin = true
				_K.Data.members["301"].unrestricted = { mod = true }
				mRemote.Unban:Fire(406)
				world:run(1)
				sert.eq(_K.Data.bans["406"][3], -1)
				-- refused before it's logged as an unban
				for _, log in _K.Data.logs do
					sert.eq(log[1] == ";unban 406", false)
				end
				_K.Data.roles.mod.permissions.admin = nil
				_K.Data.members["301"].unrestricted = nil

				-- Banning an online player kicks them (line 840)
				local function wasPlayerKicked(srv: any, plr: any): boolean
					for _, entry in srv.kicks do
						if entry.player == plr or entry.userId == plr.UserId then
							return true
						end
					end
					return false
				end
				server:client(408)
				local onlineBanTarget = sh.env.Players:GetPlayerByUserId(408)
				world:run(0.2)
				aRemote.Ban:Fire(408, "kicked on ban", 0)
				aRemote.Unban:Fire(404)
				world:run(1)
				sert.eq(wasPlayerKicked(server, onlineBanTarget), true)
				sert.eq(_K.Data.bans["404"], nil)

				-- Hook.roleAdded and Hook.roleRemoved update ServersSubscribers (lines 956-969)
				local serversTable = sh.env:require(_K.Server:WaitForChild("Servers"))
				_K.Auth.userRoleAdd(srvGuest.UserId, "admin")
				sert.eq(serversTable.Subscribers[srvGuest], true)
				_K.Auth.userRoleRemove(srvGuest.UserId, "admin")

				-- Remote.Command executes a server command (e.g., ;serverlock and ;unserverlock)
				aRemote.Command:Fire(";serverlock")
				world:run(1)
				sert.eq(_K._serverLock, srvAdmin.Name)

				-- Player joining while _K._serverLock is active gets kicked (lines 1041-1042)
				server:client(501)
				local lockedPlr = sh.env.Players:GetPlayerByUserId(501)
				sh.env.Players.PlayerAdded:Fire(lockedPlr)
				world:run(0.5)
				sert.eq(wasPlayerKicked(server, lockedPlr), true)

				aRemote.Command:Fire(";unserverlock")
				world:run(1)
				sert.eq(_K._serverLock, nil)

				-- Banned player joining returns early when kicked (line 1033)
				server:client(407)
				local bannedJoiner = sh.env.Players:GetPlayerByUserId(407)
				sh.env.Players.PlayerAdded:Fire(bannedJoiner)
				world:run(0.5)
				sert.eq(wasPlayerKicked(server, bannedJoiner), true)

				-- Player.Chatted never fires with platform-integrated chat, nothing listens to it
				srvAdmin.Chatted:Fire(";serverlock")
				srvAdmin.Chatted:Fire("/e ;serverlock")
				world:run(0.5)
				sert.eq(_K._serverLock, nil)

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
				sert.eq(serversTable.Enabled, true)
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
				sert.eq(serversTable.Enabled, true)
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
				sert.eq(_K.Data.servers["remote-job-99"] ~= nil, true)
				sert.eq(_K.Data.servers["remote-job-99"][2], 7)
				sert.eq(#serverBroadcasts, 2)
				sert.eq(modBroadcasts, 0)
				sert.eq(serverBroadcasts[1].player, srvAdmin)
				sert.eq(serverBroadcasts[1].jobId, "remote-job-99")
				sert.eq(serverBroadcasts[1].count, 5)
				sert.eq(serverBroadcasts[2].count, 7)

				aRemote.TeleportToServer:Fire(1000, "remote-job-99")
				world:run(1)
				sert.eq(#sh.env.teleports >= 1, true)
				sert.eq(sh.env.teleports[#sh.env.teleports].placeId, 1000)

				-- Advance past EXPIRE (35s) while keeping a fresh server entry to verify selective stale server removal
				_K.Data.servers["remote-job-fresh"] = { 1000, 3, sh.env.globals.os.time(), sh.env.globals.tick() + 45 }
				world:run(50)
				sert.eq(_K.Data.servers["remote-job-99"], nil)
				sert.eq(_K.Data.servers["remote-job-fresh"] ~= nil, true)
				sert.eq(#serverBroadcasts, 3)
				sert.eq(serverBroadcasts[3].jobId, "remote-job-99")

				-- Unsubscribing all admins disconnects topic listener while keeping fresh entries warm; re-subscribing purges expired entries
				table.clear(serversTable.Subscribers)
				serversTable.syncSubscription()
				sert.eq(_K.Data.servers["remote-job-fresh"] ~= nil, true)
				_K.Data.servers["remote-job-stale"] = { 1000, 2, sh.env.globals.os.time(), sh.env.globals.tick() - 40 }
				serversTable.Subscribers[srvAdmin] = true
				serversTable.syncSubscription()
				world:run(0.5)
				sert.eq(_K.Data.servers["remote-job-stale"], nil)
				sert.eq(_K.Data.servers["remote-job-fresh"] ~= nil, true)
				sert.eq(serverBroadcasts[3].count, nil)
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
				sert.eq(okClientSrv, false)
				sert.eq(
					string.find(tostring(errClientSrv), "Cannot load server-side code on the client", 1, true) ~= nil,
					true
				)
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

				local collectionService = hStudio.env.game:GetService("CollectionService")
				local addonsFolder = hStudio.env.Instance.new("Folder", configObj)
				addonsFolder.Name = "Addons"
				collectionService:AddTag(addonsFolder, "Kohl's Admin Addon")
				local sharedAddonRuns, serverAddonRan, subAddonRan, dupAddonRan = 0, false, false, false
				local sharedAddon = hStudio.env.Instance.new("ModuleScript", addonsFolder)
				sharedAddon.Name = "SharedTestAddon"
				collectionService:AddTag(sharedAddon, "Kohl's Admin Addon")
				rawset(sharedAddon, "_factory", function()
					return function()
						sharedAddonRuns += 1
					end
				end)

				local dupModel = hStudio.env.Instance.new("Folder", hStudio.env.workspace)
				dupModel.Name = "Kohl's Admin"
				local dupLoader = hStudio.env.Instance.new("Script", dupModel)
				dupLoader.Name = "Loader"
				local dupConfig = hStudio.env.Instance.new("Configuration", dupModel)
				dupConfig.Name = "Config"
				local dupAddons = hStudio.env.Instance.new("Folder", dupConfig)
				dupAddons.Name = "Addons"
				collectionService:AddTag(dupAddons, "Kohl's Admin Addon")
				local dupAddon = hStudio.env.Instance.new("ModuleScript", dupAddons)
				dupAddon.Name = "DuplicateAddon"
				rawset(dupAddon, "_factory", function()
					return function()
						dupAddonRan = true
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
				local studioServer = hStudio.KA:WaitForChild("Server")
				local serverAddonsFolder = studioServer:FindFirstChild("Addons")
				if not serverAddonsFolder then
					serverAddonsFolder = hStudio.env.Instance.new("Folder", studioServer)
					serverAddonsFolder.Name = "Addons"
				end
				local legacyAddon = hStudio.env.Instance.new("Folder", serverAddonsFolder)
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

				sert.eq(initRet, sK)
				sert.eq(studioRolesTable[1], nil)
				sert.eq(type(sK.Data.settingsModuleData.bans), "table")
				sert.eq(initHookFired, true)
				sert.eq(syncedThemes, 1)
				sert.eq(prefetchedGroups, 1)
				sert.eq(sK.ready, true)
				sert.eq(sK.groupId, 500)
				sert.eq(table.find(sK.Data.settingsModuleData.userRoles.superadmin, 777) ~= nil, true)
				sert.eq(sharedAddonRuns, 1)
				sert.eq(dupAddonRan, false)
				sert.eq(dupModel.Parent, nil)
				sert.eq(serverAddonRan, true)
				sert.eq(subAddonRan, true)
				sert.eq(configObj.Parent, hStudio.KA)
				sert.eq(addonsFolder.Parent, sK.Server)
				sert.eq(hStudio.KA.Client.UI.Theme.Themes:FindFirstChild("CustomTheme") ~= nil, true)
				sert.eq(serverAddon.Parent ~= nil and serverAddon.Parent.Name == "_KServerAddons", true)
				sert.eq(sharedAddon.Parent, hStudio.KA:FindFirstChild("Addons"))
				sert.eq(clientAddon.Parent, hStudio.KA:FindFirstChild("Addons"))

				-- Studio Remote.Init with PlaceId == 0 alerts admin about publishing to save data (line 572)
				sK.Remote.Init._signal:Fire(prePlr, { Attributes = { Platform = "Desktop" } })
				hStudio.env:step(1)
				sert.eq(prePlr:GetAttribute("_K_READY"), true)

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
				sert.eq(sK.getCommandPrefix(), "!")
				sK.alert(prePlr, "Client alert")
				sert.eq(notifiedClient ~= nil, true)
				sert.eq(notifiedClient.Text, "Client alert")
				sK.log("Client command log", "COMMAND")
				hStudio.env:step(0.1)
				sert.eq(updatedLogsList, true)
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
		sert.eq(_K.ready, true)

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
		sert.eq(#(_K.Data.savedSettings.announcements or {}), 0)
		sert.eq(_K.Chat.cooldown(101, "announce"), nil)
		world:run(61)

		-- the editor gets the filtered pinned announcement back, other players get it with the changes
		table.clear(adminSettings)
		table.clear(guestSettings)
		aRemote.Settings:Fire({ announcement = { "Pinned via settings", 101 } })
		world:run(0.5)
		sert.eq(#adminSettings, 1)
		sert.eq(adminSettings[1].announcement[1], "Pinned via settings")
		sert.eq(adminSettings[1].announcement[2], 101)
		sert.eq(#guestSettings, 1)
		sert.eq(guestSettings[1].announcement[1], "Pinned via settings")
		world:run(61)

		-- ;announce messages carry the pinned announcement so clients can tell it apart from a settings sync
		aRemote.Command:Fire(";announce Pinned via command")
		world:run(1)
		world.backing.messaging.drain()
		world:run(1)
		sert.eq(#guestAnnounces >= 1, true)
		local last = guestAnnounces[#guestAnnounces]
		sert.eq(last.text, "Pinned via command")
		sert.eq(type(last.data), "table")
		sert.eq(last.data[1], "Pinned via command")
		sert.eq(last.data[2], 101)

		-- ;unannounce tells clients to forget it, so the same announcement shows again later
		table.clear(guestSettings)
		aRemote.Command:Fire(";unannounce")
		world:run(1)
		world.backing.messaging.drain()
		world:run(1)
		local cleared = false
		for _, settings in guestSettings do
			if settings.announcement == false then
				cleared = true
			end
		end
		sert.eq(cleared, true)
	end)

	test("clients show a pinned announcement once across settings and announce messages", function()
		local world = sert.sim.new({ backing = true })
		local server = world:server()
		local client = server:client(101)
		local sh = Harness.newPeerEnv(server, { isStudio = false })
		local ch = Harness.newPeerEnv(client, { isClient = true })
		local sRemote = sh:requireRemote()
		sh:requireUtil()
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
		sert.eq(cChat.pinAnnouncement(pinned), true)
		sRemote.ChatSystem:Fire(srvPlr, "announce", "Pinned", 7, pinned, "pin-1")
		world:run(0.2)
		sert.eq(#shown, 0)
		-- an unchanged full settings sync doesn't show it again either
		sert.eq(cChat.pinAnnouncement({ "Pinned", 7 }), false)

		-- a replaced announcement shows once, however it arrives
		sRemote.ChatSystem:Fire(srvPlr, "announce", "Replaced", 7, { "Replaced", 7 }, "pin-2")
		sRemote.ChatSystem:Fire(srvPlr, "announce", "Replaced", 7, { "Replaced", 7 }, "pin-3")
		world:run(0.2)
		sert.eq(shown, { "Replaced" })
		sert.eq(cChat.pinAnnouncement({ "Replaced", 7 }), false)

		-- clearing it lets the same announcement show again
		sert.eq(cChat.pinAnnouncement(false), false)
		sRemote.ChatSystem:Fire(srvPlr, "announce", "Replaced", 7, { "Replaced", 7 }, "pin-4")
		-- announce messages without a pinned announcement always show
		sRemote.ChatSystem:Fire(srvPlr, "announce", "Plain", 7, 5, "plain-1")
		sRemote.ChatSystem:Fire(srvPlr, "announce", "Plain", 7, 5, "plain-2")
		world:run(0.2)
		sert.eq(shown, { "Replaced", "Replaced", "Plain", "Plain" })

		-- pins with an id show once each, so a settings sync that arrives after a clear or a replacement doesn't
		-- bring the old pin back
		local first, second = { "First", 7, 0, "id-1" }, { "Second", 7, 0, "id-2" }
		sert.eq(cChat.pinAnnouncement(first), true)
		sert.eq(cChat.pinAnnouncement(false), false)
		sert.eq(cChat.pinAnnouncement(table.clone(first)), false)
		sert.eq(cChat.pinAnnouncement(second), true)
		sert.eq(cChat.pinAnnouncement(table.clone(first)), false)
		sert.eq(cChat.pinAnnouncement(table.clone(second)), false)
		-- the same text pinned again gets a new id and shows
		sert.eq(cChat.pinAnnouncement({ "First", 7, 0, "id-3" }), true)
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
			sert.eq(command.run, nil)
			sert.eq(#command.args, 0)
			command.runClient(context)
		end
		sert.eq(string.find(hints[1], "disabled", 1, true) ~= nil, true)
		sert.eq(#hints, 2)
		sert.eq(type(commands.privatemessage.run), "function")
		sert.eq(#commands.privatemessage.args, 2)
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
		sert.eq(_K.ready, true)

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
			world.backing.messaging.drain()
			world:run(1)
			sert.eq(#pins >= 1, true)
			for _, pin in pins do
				if gChat.pinAnnouncement(pin) then
					table.insert(shown, pin[1])
				end
			end
			-- a later full settings sync repeats it unchanged
			sert.eq(gChat.pinAnnouncement(table.clone(_K.Data.savedSettings.announcement)), false)
			world:run(61)
		end
		sert.eq(shown, { "Server restarting soon", "Server restarting soon" })

		-- the same text pinned twice from the settings UI shows twice too
		table.clear(shown)
		for _ = 1, 2 do
			table.clear(pins)
			aRemote.Settings:Fire({ announcement = { "Pinned twice", 101 } })
			world:run(0.5)
			sert.eq(#pins, 1)
			if gChat.pinAnnouncement(pins[1]) then
				table.insert(shown, pins[1][1])
			end
			world:run(61)
		end
		sert.eq(shown, { "Pinned twice", "Pinned twice" })
	end)
end)

describe("Chat commands · TextChatCommands with platform-integrated chat", function()
	test("aliasGroups puts the primary slash alias first, then prefixed aliases, and skips taken ones", function()
		local h = Harness.newEnv({ isStudio = false })
		local ChatCommands = h.env:require(h.Server:WaitForChild("ChatCommands"))
		local message = { name = "Message", aliases = { "m", "MSG", "two words" } }
		local groups, skipped = ChatCommands.aliasGroups(message, { ";", ":" }, { ["/m"] = true, [":msg"] = true })
		sert.eq(groups, {
			{ "/message", ";message" },
			{ ":message", ";m" },
			{ ":m", ";msg" },
			{ "/msg" },
		})
		sert.eq(skipped, { ":msg", "/m" })
		-- "/" as a prefix isn't repeated, and every alias has a prefix
		local slashGroups = ChatCommands.aliasGroups({ name = "kill" }, { "/" }, {})
		sert.eq(slashGroups, { { "/kill" } })
		sert.eq(ChatCommands.aliasGroups({ name = "kill" }, {}, { ["/kill"] = true }), {})
		sert.eq(table.find(ChatCommands.DEFAULT_ALIASES, "/team") ~= nil, true)
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
		sert.eq(_K.ready, true)
		sert.eq(type(_K.VERSION), "string")
		sert.eq(_K.features.platformIntegratedChat, true)

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
		sert.eq(serverlock.PrimaryAlias, "/serverlock")
		sert.eq(serverlock.SecondaryAlias, ";serverlock")
		sert.eq(aliasesOf("serverlock"), {
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
			sert.eq(instance.AutocompleteVisible, false)
			sert.eq(instance.Enabled, true)
			for _, alias in { instance.PrimaryAlias, instance.SecondaryAlias } do
				if alias ~= "" then
					sert.eq(seen[alias], nil)
					seen[alias] = true
					sert.eq(string.find(alias, "^[;:/]..*") ~= nil, true)
				end
			end
		end
		sert.eq(count >= #_K.Registry.commandsList, true)
		-- Roblox's defaults and the game's commands keep their aliases, both would run otherwise
		for _, alias in { "/ping", "/m", "/e", "/team", "/help", "/w" } do
			sert.eq(seen[alias], nil)
		end
		sert.eq(seen[";m"] and seen[";ping"], true)
		sert.eq(string.find(skippedLog(), "/ping", 1, true) ~= nil, true)
		sert.eq(string.find(skippedLog(), "/m", 1, true) ~= nil, true)
		sert.eq(_K.chatCommandAlias("SLOCK"), ";slock")
		sert.eq(_K.chatCommandAlias("ping"), ";ping")
		sert.eq(_K.chatCommandAlias("nope"), ";nope")

		-- Triggered gets the whole line, the server runs it and forwards it so the client runs its part
		local srvAdmin = sh.env.Players:GetPlayerByUserId(101)
		serverlock.Triggered:Fire({ UserId = 101 }, ";serverlock")
		world:run(1)
		sert.eq(_K._serverLock, srvAdmin.Name)
		sert.eq(forwarded[#forwarded].text, ";serverlock")
		sert.eq(forwarded[#forwarded].clientOnly, true)
		-- "/" isn't a configured prefix, it becomes the first one
		folder:FindFirstChild("unserverlock3").Triggered:Fire({ UserId = 101 }, "  /UNSLOCK")
		world:run(1)
		sert.eq(_K._serverLock, nil)
		sert.eq(forwarded[#forwarded].text, ";UNSLOCK")
		-- only players in the server, and only with the command's permission (unauthorized isn't forwarded to client)
		serverlock.Triggered:Fire({ UserId = 99999 }, ";serverlock")
		serverlock.Triggered:Fire({ UserId = 202 }, ";serverlock")
		world:run(1)
		sert.eq(_K._serverLock, nil)
		sert.eq(#guestForwarded, 0)
		sert.eq(string.find(table.concat(guestNotes, "\n"), "restricted", 1, true) ~= nil, true)
		-- client-only commands run on the client and stay out of the server's logs
		folder:FindFirstChild("commands").Triggered:Fire({ UserId = 101 }, ";cmds")
		world:run(1)
		sert.eq(forwarded[#forwarded].text, ";cmds")
		for _, log in _K.Data.logs do
			sert.eq(log[1] == ";cmds" or log[1] == ";commands", false)
		end

		-- Player.Chatted isn't a command path
		srvAdmin.Chatted:Fire(";serverlock")
		world:run(0.5)
		sert.eq(_K._serverLock, nil)

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
		sert.eq(aliasesOf("lateping"), { "/lateping", "/lp", ":lateping", ":lp", ";lateping", ";lp" })
		folder:FindFirstChild("lateping2").Triggered:Fire({ UserId = 202 }, ":lp")
		world:run(1)
		sert.eq(lateRuns, 1)

		-- another TextChatCommand taking an alias later wins it, and so does an alias change
		local later = sh.env.Instance.new("TextChatCommand")
		later.PrimaryAlias = ";LP"
		later.Parent = tcs
		world:run(0.2)
		sert.eq(aliasesOf("lateping"), { "/lateping", "/lp", ":lateping", ":lp", ";lateping" })
		sert.eq(string.find(skippedLog(), ";lp", 1, true) ~= nil, true)
		later.PrimaryAlias = ";lateping"
		world:run(0.2)
		sert.eq(aliasesOf("lateping"), { "/lateping", "/lp", ":lateping", ":lp", ";lp" })
		server:spawn(function()
			later:Destroy()
		end)
		world:run(0.2)
		sert.eq(#aliasesOf("lateping"), 6)

		-- changing the prefixes re-aliases every command
		aRemote.Settings:Fire({ prefix = { "!" } })
		world:run(0.5)
		sert.eq(_K.Data.settings.prefix, { "!" })
		sert.eq(aliasesOf("serverlock"), { "!serverlock", "!slock", "/serverlock", "/slock" })
		sert.eq(_K.chatCommandAlias("serverlock"), "!serverlock")
		folder:FindFirstChild("serverlock").Triggered:Fire({ UserId = 101 }, "!slock")
		world:run(1)
		sert.eq(_K._serverLock, srvAdmin.Name)
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
		sert.eq(_K.Process.onCooldown(_K, 101), true)
		world:run(1)
		_K.Process.resetLimit(101)
		_K.Data.roles.creator.limits = nil
		sert.eq(#forwarded, beforeForwarded + 1)
		sert.eq(forwarded[#forwarded].text, "!announce")
		sert.eq(forwarded[#forwarded].clientOnly, true)
		sert.eq(#adminNotes, 0)

		-- commandBarRank = false disables the missing-arg handoff so server reports the missing argument error
		_K.Data.settings.commandBarRank = false
		folder:FindFirstChild("announce").Triggered:Fire({ UserId = 101 }, "/announce ")
		world:run(1)
		sert.eq(#adminNotes > 0, true)
		_K.Data.settings.commandBarRank = 0
		table.clear(adminNotes)

		-- explicit invalid arguments still report the server validation error
		folder:FindFirstChild("ban").Triggered:Fire({ UserId = 101 }, "/ban nonexistentplayer")
		world:run(1)
		sert.eq(#adminNotes > 0, true)

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
		sert.eq(#bubblesFired, 0)
		folder:FindFirstChild("fire").Triggered:Fire({ UserId = 101 }, "/fire me")
		world:run(0.5)
		sert.eq(#bubblesFired, 1)
		sert.eq(bubblesFired[1].char, srvAdminChar)
		sert.eq(bubblesFired[1].word, "!fire")
		_K.Remote.DisplayBubble.FireAll = origBubbleFireAll

		-- Direct refreshCommand without batchSkipped logs skipped aliases immediately
		_K.ChatCommands.taken["!lateping"] = true
		_K.ChatCommands.refreshCommand(_K.Registry.commands.lateping)
		world:run(0.2)
		sert.eq(string.find(skippedLog(), "!lateping", 1, true) ~= nil, true)

		-- Removing lateping from commandsList and refreshing cleans up its TextChatCommand instances
		local lpIdx = table.find(_K.Registry.commandsList, _K.Registry.commands.lateping)
		if lpIdx then
			table.remove(_K.Registry.commandsList, lpIdx)
		end
		_K.ChatCommands.refresh()
		sert.eq(_K.ChatCommands.instances.lateping, nil)
		sert.eq(_K.ChatCommands.aliases.lateping, {})

		-- chat text is never logged, and the setting can't turn that back on
		aRemote.Settings:Fire({ saveChatLogs = true })
		world:run(0.5)
		sert.eq(_K.Data.savedSettings.saveChatLogs, false)

		-- turning chat commands off disables every instance, so lines reach chat again
		aRemote.Settings:Fire({ chatCommands = false })
		world:run(0.5)
		for _, instance in folder:GetChildren() do
			sert.eq(instance.Enabled, false)
		end
		folder:FindFirstChild("serverlock").Triggered:Fire({ UserId = 101 }, "!serverlock")
		world:run(1)
		sert.eq(_K._serverLock, nil)
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
		local replSource = sh.env.game:GetService("ReplicatedStorage"):FindFirstChild("Kohl's Admin Source")
		sert.ok(replSource ~= nil)
		sert.eq(replSource.Shared.VIP.UGC.AlphaWings:FindFirstChild("Bones"), nil)
		sert.eq(replSource.Shared.VIP.UGC.AlphaWings:FindFirstChild("Animate"), nil)
		local folder = sh.env.game:GetService("TextChatService"):FindFirstChild("TextChatCommands_KA")
		-- With 0 connected players, everyone commands materialize while restricted commands stay deferred
		local commandsCmd = folder:FindFirstChild("commands")
		sert.ok(commandsCmd ~= nil)
		sert.eq(commandsCmd.PrimaryAlias, "/commands")
		sert.eq(commandsCmd.SecondaryAlias, ";commands")
		sert.eq(commandsCmd.AutocompleteVisible, false)
		sert.eq(folder:FindFirstChild("kill"), nil)
		-- a letter prefix still parses, and all command aliases remain queryable even when unmaterialized
		sert.eq(_K.chatCommandAlias("kill"), ";kill")
		sert.eq(_K.ChatCommands.alias("nosuchcommand"), nil)

		-- Connecting a permitted player (creator 101) materializes kill; replacing with a guest tears it down
		local creator = sh.env:addPlayer(101, "Creator101")
		world:run(0.2)
		local kill = folder:FindFirstChild("kill")
		sert.ok(kill ~= nil)
		sert.eq(kill.PrimaryAlias, "/kill")
		sert.eq(kill.SecondaryAlias, ";kill")
		sert.eq(kill.AutocompleteVisible, false)

		sh.env:removePlayer(creator)
		local guest = sh.env:addPlayer(202, "Guest202")
		world:run(0.2)
		sert.eq(folder:FindFirstChild("kill"), nil)

		-- Granting then revoking a role dynamically syncs restricted commands
		sert.eq(_K.Auth.userRoleAdd(guest.UserId, "admin"), true)
		world:run(0.2)
		sert.ok(folder:FindFirstChild("kill") ~= nil)
		sert.eq(_K.Auth.userRoleRemove(guest.UserId, "admin"), true)
		world:run(0.2)
		sert.eq(folder:FindFirstChild("kill"), nil)
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
		sert.eq(texts, { ";announce secret words", ";kill me ;announce hi ;nosuch x", "info ;announce kept" })

		local names = {}
		for _, item in fired do
			table.insert(names, item.name)
			if item.name == "postSyncMain" then
				sert.eq(item.value, Data1)
			end
		end
		sert.eq(names, { "preSyncMain", "postSyncMain", "preSyncLogs", "postSyncLogs" })
		sert.eq(Data1.members["202"] ~= nil, true)
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

			-- 1. First command log with liveText is redacted for all other admins (including chat-allowed p3) and Sync.logs,
			--    and reveals after 60s without spending the sender's shared text cooldown
			local firstLog = _K.log(";kick Guest First reason", "COMMAND", 101, true, ";kick Guest …")
			world:run(0.1)
			local firstStored = _K.Data.logs[#_K.Data.logs]
			sert.eq(firstLog[1], ";kick Guest First reason")
			sert.eq(firstStored[1], ";kick Guest …")
			sert.eq(receivedBy1[#receivedBy1][1], ";kick Guest First reason")
			sert.eq(receivedBy2[#receivedBy2][1], ";kick Guest …")
			sert.eq(receivedBy3[#receivedBy3][1], ";kick Guest …")
			sert.eq(#_K.Data.Sync.logs, 0)

			-- 2. Second command log 30s later also starts redacted and must not flush early when the first 60s timer fires
			world:run(30)
			_K.log(";kick Guest Later reason", "COMMAND", 101, true, ";kick Guest …")
			world:run(0.1)
			local laterStored = _K.Data.logs[#_K.Data.logs]
			sert.eq(laterStored[1], ";kick Guest …")
			sert.eq(receivedBy1[#receivedBy1][1], ";kick Guest Later reason")
			sert.eq(receivedBy2[#receivedBy2][1], ";kick Guest …")
			sert.eq(receivedBy3[#receivedBy3][1], ";kick Guest …")
			local p2CountBeforeReveal, p3CountBeforeReveal = #receivedBy2, #receivedBy3

			-- Advance 31s (61s total): firstStored reveals to BOTH p2 and p3 and Sync.logs, while laterStored remains redacted
			world:run(31)
			sert.eq(firstStored[1], ";kick Guest First reason")
			sert.eq(#receivedBy2, p2CountBeforeReveal + 1)
			sert.eq(receivedBy2[#receivedBy2][1], ";kick Guest First reason")
			sert.eq(#receivedBy3, p3CountBeforeReveal + 1)
			sert.eq(receivedBy3[#receivedBy3][1], ";kick Guest First reason")
			sert.eq(_K.Data.Sync.logs[#_K.Data.Sync.logs][1], ";kick Guest First reason")
			sert.eq(laterStored[1], ";kick Guest …")

			world:run(31)
			sert.eq(laterStored[1], ";kick Guest Later reason")
			sert.eq(receivedBy2[#receivedBy2][1], ";kick Guest Later reason")
			sert.eq(receivedBy3[#receivedBy3][1], ";kick Guest Later reason")
			sert.eq(_K.Data.Sync.logs[#_K.Data.Sync.logs][1], ";kick Guest Later reason")

			-- Logging redacted text does NOT consume the sender's shared text cooldown
			_K.log(";kick Guest Typo only", "COMMAND", 101, true, ";kick Guest …")
			world:run(0.1)
			sert.eq(_K.Chat.limitBroadcast(101), nil)
			world:run(61)

			-- 3. If CanUserChatAsync is false, liveText stays permanently redacted for other admins and Sync.logs
			tcsMethods.CanUserChatAsync = function()
				return false
			end
			_K.log(";kick Guest Muted reason", "COMMAND", 101, true, ";kick Guest …")
			world:run(0.1)
			local mutedStored = _K.Data.logs[#_K.Data.logs]
			sert.eq(mutedStored[1], ";kick Guest …")
			sert.eq(receivedBy1[#receivedBy1][1], ";kick Guest Muted reason")
			sert.eq(receivedBy2[#receivedBy2][1], ";kick Guest …")
			sert.eq(receivedBy3[#receivedBy3][1], ";kick Guest …")
			sert.eq(_K.Data.Sync.logs[#_K.Data.Sync.logs][1], ";kick Guest …")
			world:run(61)
			sert.eq(mutedStored[1], ";kick Guest …")
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
				sert.eq(_K.Data.roles[roleKey] ~= nil, true)
			end
			sert.eq(_K.Data.roles.mod.color, "#123456")
			sert.eq(_K.Data.roles.mod._rank, 2)
			sert.eq(type(_K.Data.bans), "table")
			sert.eq(_K.Data.SEPARATE_DATASTORE, true)

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
			_K.Remote.Servers.Fire = function(_self, plr)
				if plr == p2 then
					backfilled.servers = true
				end
			end

			_K.Auth.userRoleAdd(202, "superadmin")
			sert.eq(backfilled.bans, true)
			sert.eq(backfilled.members, true)
			sert.eq(backfilled.reserved, true)
			sert.eq(backfilled.logs, true)
			sert.eq(backfilled.servers, true)

			-- _K.chatCommandAlias, _K.removeExcessLogs logsVersion, and client _K.log log[6]
			_K.ChatCommands = {
				alias = function(w)
					return if w == "fly" then "/fly" else nil
				end,
			}
			sert.eq(_K.chatCommandAlias("FLY"), "/fly")
			sert.eq(_K.chatCommandAlias("KILL"), "!kill")
			_K.ChatCommands = nil
			local origPrefixes = _K.Data.settings.prefix
			_K.Data.settings.prefix = {}
			sert.eq(_K.chatCommandAlias("KILL"), ";kill")
			_K.Data.settings.prefix = origPrefixes

			local prevLogsVer = _K.Data.logsVersion or 0
			local origLimit = _K.Logger.limit
			_K.Logger.limit = 1
			_K.Logger:log("one", "INFO")
			_K.Logger:log("two", "INFO")
			_K.removeExcessLogs()
			sert.eq(#_K.Data.logs, 1)
			sert.eq(_K.Data.logsVersion, prevLogsVer + 1)
			_K.Logger.limit = origLimit

			_K.IsServer = false
			_K.IsClient = true
			local clientInfoLog = _K.log("client info", "INFO")
			local clientChatLog = _K.log("client chat", "CHAT")
			sert.eq(clientInfoLog ~= nil and clientInfoLog[6] == true, true)
			sert.eq(clientChatLog ~= nil and clientChatLog[6] == nil, true)
			_K.IsClient = false
			_K.IsServer = true
		end
	)

	test(
		"Chat.restoreRichText handles spaced rgb() quotes, rejects duplicate/malformed font attrs, and preserves outer tags around escaped_font",
		function()
			local h = Harness.newEnv({ isStudio = false })
			local Chat = h:requireShared("Chat")
			local Util = h:requireUtil()
			local esc = Util.String.escapeRichText

			-- Double-quoted rgb() with spaces, single-quoted size, and unquoted transparency succeed
			local spacedRgb = esc("<font color=\"rgb(255, 165, 0)\" size='20' transparency=0.5>warm</font>")
			sert.eq(
				Chat.restoreRichText(spacedRgb),
				'<font color="rgb(255,165,0)" size="20" transparency="0.5">warm</font>'
			)

			-- Duplicate attributes, missing whitespace between attributes, and leftover garbage are rejected
			local dupAttr = esc('<font color="#f00" color="#0f0">dup</font>')
			sert.eq(Chat.restoreRichText(dupAttr), dupAttr)
			local jammedAttr = esc('<font color="#f00"size="20">jammed</font>')
			sert.eq(Chat.restoreRichText(jammedAttr), jammedAttr)
			local trailingGarbage = esc('<font color="#f00" bogus>garbage</font>')
			sert.eq(Chat.restoreRichText(trailingGarbage), trailingGarbage)

			-- Invalid <font ...> or bare <font> inside valid outer tags keeps outer tags restored while escaping only the bad font pair
			local outerBoldWithBadFont = esc('<b><font face="Gotham">styled</font></b>')
			sert.eq(
				Chat.restoreRichText(outerBoldWithBadFont),
				"<b>&lt;font face=&quot;Gotham&quot;&gt;styled&lt;/font&gt;</b>"
			)
			local outerValidFontWithBadInner = esc('<font color="#ff0000"><font>plain</font></font>')
			sert.eq(
				Chat.restoreRichText(outerValidFontWithBadInner),
				'<font color="#ff0000">&lt;font&gt;plain&lt;/font&gt;</font>'
			)

			-- Unclosed or mis-nested escaped_font still fails balance and returns original escaped text unchanged
			local unclosedBadFont = esc('<b>ok</b><font face="Gotham">dangling')
			sert.eq(Chat.restoreRichText(unclosedBadFont), unclosedBadFont)
			local misnestedBadFont = esc('<b><font face="Gotham">oops</b></font>')
			sert.eq(Chat.restoreRichText(misnestedBadFont), misnestedBadFont)
		end
	)

	test(
		"Chat.send, Process.runCommands freeText filtering, and flushLogReveals prevent double-filtering, redaction leaks, and duplicate ellipsis reveals",
		function()
			local world = sert.sim.new({ backing = true })
			local server = world:server()
			local sh = Harness.newPeerEnv(server, { isStudio = false })
			sh.env.game._props.CreatorId = 101
			local _K = sh:requireK()
			-- shared._K_INTERFACE is exposed only after Server init defines _K.initialize
			sert.eq(sh.env.globals.shared._K_INTERFACE, _K)
			sert.eq(type(_K.initialize), "function")

			server:spawn(function()
				_K.initialize({
					bans = {},
					userRoles = { superadmin = { 101, 102 } },
					roles = Harness.defaultRoles(),
				})
			end)
			world:run(1)

			local sender = sh.env:addPlayer(101, "AdminSender")
			local friend = sh.env:addPlayer(201, "AllowedFriend")
			local restrictedObserver = sh.env:addPlayer(102, "RestrictedAdminObserver")
			sender:SetAttribute("_K_READY", true)
			friend:SetAttribute("_K_READY", true)
			restrictedObserver:SetAttribute("_K_READY", true)

			local tcsMethods = rawget(sh.env.game:GetService("TextChatService"), "_methods")
			tcsMethods.CanUserChatAsync = function()
				return true
			end
			tcsMethods.CanUsersChatAsync = function(_self, fromId, toId)
				-- sender (101) can chat with friend (201) ONLY, NOT with restrictedObserver (102)
				return (fromId == 101 and toId == 201) or (fromId == 201 and toId == 101)
			end

			local broadcastFilterCalls = 0
			local origFilterForBroadcast = _K.Util.String.filterForBroadcast
			_K.Util.String.filterForBroadcast = function(str: string, fromId: number)
				broadcastFilterCalls += 1
				return origFilterForBroadcast(str, fromId)
			end

			-- Register a custom command that delegates to Chat.send with a rawString (filterLog=true, freeText=true) arg
			_K.Registry.registerCommand(_K, {
				name = "testpm",
				aliases = {},
				description = "Test direct Chat.send",
				group = "Moderation",
				args = {
					{ type = "player", name = "Recipient" },
					{ type = "rawString", name = "Message" },
				},
				run = function(context, targetPlr, msg)
					_K.Chat.send(context, "pm", msg, { targetPlr })
				end,
			})

			-- 1. Self-only Chat.send sets arg.filtered = true (no double filterForBroadcast in Process)
			--    and leaves redactLog unset so restrictedObserver sees redacted "…" for 60s without spending cooldown
			local observerLogs = {}
			_K.Remote.Log.Fire = function(_self, plr, payload)
				if plr == restrictedObserver then
					table.insert(observerLogs, table.clone(payload))
				end
			end

			broadcastFilterCalls = 0
			server:spawn(function()
				_K.Process.runCommands(_K, 101, ";testpm AdminSender secret self")
			end)
			world:run(0.5)
			sert.eq(broadcastFilterCalls, 0) -- Chat.send filtered via filterResult; Process skipped second filterForBroadcast
			sert.eq(#observerLogs, 1)
			sert.eq(observerLogs[1][1], ";testpm AdminSender …")

			-- 2. First Chat.send to another player (friend) spends the shared cooldown and sets arg.filtered = true & arg.redactLog = false;
			--    a subsequent send within 60s is blocked completely without setting redactLog = false
			local mixedArg: { [string]: any } = {
				rawType = { freeText = true, filterLog = true },
				rawArg = "first public",
				parsedArgs = { "first public" },
			}
			local id1, err1, recips1 = _K.Chat.send(
				{ from = 101, fromPlayer = sender, args = { mixedArg } },
				"message",
				"first public",
				{ friend, restrictedObserver }
			)
			sert.eq(id1 ~= nil and err1 == nil, true)
			sert.eq(#(recips1 :: { any }), 2)
			sert.eq(mixedArg.filtered, true)
			sert.eq(mixedArg.redactLog, false)

			local rateLimitedArg: { [string]: any } = {
				rawType = { freeText = true, filterLog = true },
				rawArg = "second rate limited",
				parsedArgs = { "second rate limited" },
			}
			local id2, err2, recips2 = _K.Chat.send(
				{ from = 101, fromPlayer = sender, args = { rateLimitedArg } },
				"message",
				"second rate limited",
				{ friend, restrictedObserver }
			)
			sert.eq(id2, nil)
			sert.eq(string.find(tostring(err2), "Wait", 1, true) ~= nil, true)
			sert.eq(recips2, nil)
			sert.eq(rateLimitedArg.filtered, nil)
			sert.eq(rateLimitedArg.redactLog, nil)

			-- 3. flushLogReveals skips firing duplicate Remote.Log when fullText == prevText (literal "…")
			table.clear(observerLogs)
			server:spawn(function()
				_K.Process.runCommands(_K, 101, ";testpm AdminSender …")
			end)
			world:run(0.5)
			sert.eq(#observerLogs, 1)
			sert.eq(observerLogs[1][1], ";testpm AdminSender …")
			-- Advance past the 60s reveal timer: entry1 ("secret self") reveals, entry3 (literal "…") does NOT re-fire!
			world:run(61)
			sert.eq(#observerLogs, 2)
			sert.eq(observerLogs[2][1], ";testpm AdminSender secret self")

			_K.Util.String.filterForBroadcast = origFilterForBroadcast
		end
	)

	test(
		"ChatCommands isolates per-player playerPrefix buckets, preserves global VIP_BUBBLES prefix, hands off purchasable VIP commands without server error, and Dual-Admin routing honors _K_MODERN_LOADER",
		function()
			local world = sert.sim.new({ backing = true })
			local server = world:server()
			local guestClient = server:client(202)
			local sh = Harness.newPeerEnv(server, { isStudio = false })
			sh.env.game._props.CreatorId = 101
			local _K = sh:requireK()
			server:spawn(function()
				_K.initialize({
					bans = {},
					prefix = { ";" },
					vip = true,
					userRoles = { creator = { 101 } },
					roles = Harness.defaultRoles(),
				})
			end)
			world:run(1)

			local guestEnv = Harness.newPeerEnv(guestClient, { isClient = true })
			local gRemote = guestEnv:requireRemote()
			local guestForwarded = {}
			local guestErrors = {}
			gRemote.Command:Connect(function(text, clientOnly)
				table.insert(guestForwarded, { text = text, clientOnly = clientOnly })
			end)
			gRemote.Notify:Connect(function(props)
				if type(props) == "table" and type(props.Text) == "string" then
					table.insert(guestErrors, props.Text)
				end
			end)
			gRemote.Init:Fire({ Attributes = { Platform = "PC" } })
			world:run(1)

			local srvGuest = sh.env.Players:GetPlayerByUserId(202)
			local guestChar = sh.env.Instance.new("Model")
			srvGuest.Character = guestChar
			local folder = sh.env.game:GetService("TextChatService"):FindFirstChild("TextChatCommands_KA")

			-- 1. Setting playerPrefix = "?" creates isolated _KPlayer_63_<key> instances without polluting global prefixes/aliases
			gRemote.PlayerPrefix:Fire("?")
			world:run(0.3)
			sert.eq(_K.Data.playerPrefix[202], "?")
			sert.eq(_K.ChatCommands.prefixes, { ";" })
			sert.eq(_K.chatCommandAlias("fire"), ";fire")
			local playerFire = folder:FindFirstChild("_KPlayer_63_fire")
			sert.eq(playerFire ~= nil, true)
			sert.eq(playerFire:GetAttribute("PlayerPrefix"), "?")
			sert.eq(playerFire.PrimaryAlias, "?fire")

			-- 2. Triggering /fire by a guest with custom playerPrefix = "?":
			--    - DisplayBubble shows global ";fire" (NOT "?fire")
			--    - Server does NOT run Process.runCommands (0 restricted error notifications)
			--    - Server counts the command and forwards to client so VIP modal can open
			local bubbles = {}
			local origBubble = _K.Remote.DisplayBubble.FireAll
			_K.Remote.DisplayBubble.FireAll = function(_self, _char, word)
				table.insert(bubbles, word)
			end
			folder:FindFirstChild("fire").Triggered:Fire({ UserId = 202 }, "/fire")
			world:run(0.5)
			_K.Remote.DisplayBubble.FireAll = origBubble

			sert.eq(bubbles, { ";fire" })
			sert.eq(#guestErrors, 0)
			sert.eq(#guestForwarded, 1)
			sert.eq(guestForwarded[1].text, "?fire")
			sert.eq(guestForwarded[1].clientOnly, true)

			-- 3. Resetting playerPrefix to default ";" clears _K.Data.playerPrefix[202] and destroys _KPlayer_63_* bucket
			world:run(2.1)
			gRemote.PlayerPrefix:Fire(";")
			world:run(0.3)
			sert.eq(_K.Data.playerPrefix[202], nil)
			sert.eq(folder:FindFirstChild("_KPlayer_63_fire"), nil)

			-- 4. Re-add "?" then disconnect player -> PlayerRemoving destroys bucket immediately
			world:run(2.1)
			gRemote.PlayerPrefix:Fire("?")
			world:run(0.3)
			sert.eq(folder:FindFirstChild("_KPlayer_63_fire") ~= nil, true)
			sh.env:removePlayer(srvGuest)
			world:run(0.2)
			sert.eq(folder:FindFirstChild("_KPlayer_63_fire"), nil)

			-- 5. Dual-admin routing in test/migrate/init.luau routes to modern KA when _K_MODERN_LOADER == true
			local hDual = Harness.newEnv({ isStudio = false })
			hDual.env.globals._G.KAU = true
			hDual.env.globals.shared._K_MODERN_LOADER = true
			local routed = hDual.env:require(hDual.root)
			sert.eq(type(routed), "table")
			sert.eq(type(routed.initialize), "function")

			-- 6. Servers.luau handles table serversSync payload { jobId, count } with jitter without error
			local Servers = sh.env:require(sh.Server:WaitForChild("Servers"))
			Servers.Enabled = true
			_K.Data.publishTopic("serversSync", { "remote-job-999", 42 })
			world:run(2.5)
			sert.eq(world.scheduler.errors, {})
		end
	)

	test(
		"Remote.PlayerPrefix decouples from chatCommands & rejects /, ChatCommands pairs >2 aliases, Remote.Settings enforces Studio lock, and Servers bounds TTL",
		function()
			local world = sert.sim.new({ backing = true })
			local server = world:server()
			local guestClient = server:client(202)
			local sh = Harness.newPeerEnv(server, { isStudio = false })
			sh.env.game._props.CreatorId = 101
			local srvAdmin = sh.env:addPlayer(101, "Creator101")
			srvAdmin:SetAttribute("_KRolesLoaded", true)
			srvAdmin:SetAttribute("_K_READY", true)
			local _K = sh:requireK()
			server:spawn(function()
				_K.initialize({
					bans = {},
					prefix = { ";" },
					vip = true,
					userRoles = { creator = { 101 } },
					roles = Harness.defaultRoles(),
				})
			end)
			world:run(1)

			local guestEnv = Harness.newPeerEnv(guestClient, { isClient = true })
			local gRemote = guestEnv:requireRemote()
			gRemote.Init:Fire({ Attributes = { Platform = "PC" } })
			world:run(1)

			local srvGuest = sh.env.Players:GetPlayerByUserId(202)
			local folder = sh.env.game:GetService("TextChatService"):FindFirstChild("TextChatCommands_KA")

			-- 1. Remote.PlayerPrefix updates prefix & attribute even when chatCommands == false, and rejects "/"
			_K.Data.savedSettings.chatCommands = false
			_K.Data.settings.chatCommands = false
			world:run(2.1)
			gRemote.PlayerPrefix:Fire("!")
			world:run(0.3)
			sert.eq(_K.Data.playerPrefix[202], "!")
			sert.eq(srvGuest:GetAttribute("_KPlayerPrefix"), "!")

			world:run(2.1)
			gRemote.PlayerPrefix:Fire("/")
			world:run(0.3)
			sert.eq(_K.Data.playerPrefix[202], "!")

			-- 2. ChatCommands pairs >2 aliases into _KPlayer_<cp>_<key> and _KPlayer_<cp>_<key>_2
			_K.Data.savedSettings.chatCommands = true
			_K.Data.settings.chatCommands = true
			_K.Registry.registerCommand(_K, {
				name = "multialiascmd",
				aliases = { "ma1", "ma2", "ma3" },
				group = "utility",
				args = {},
				run = function() end,
			})
			world:run(2.1)
			gRemote.PlayerPrefix:Fire("?")
			world:run(0.5)
			local firstPair = folder:FindFirstChild("_KPlayer_63_multialiascmd")
			local secondPair = folder:FindFirstChild("_KPlayer_63_multialiascmd_2")
			sert.eq(firstPair ~= nil, true)
			sert.eq(secondPair ~= nil, true)

			-- 3. Remote.Settings ignores changeThemeAuthority and theme* when locked to Studio
			_K.Data.settings.changeThemeAuthority = "Studio"
			local origTheme = _K.Data.settings.theme
			_K.Remote.Settings._signal:Fire(srvAdmin, { changeThemeAuthority = "Client", theme = "Cyan" })
			world:run(0.2)
			sert.eq(_K.Data.settings.changeThemeAuthority, "Studio")
			sert.eq(_K.Data.settings.theme, origTheme)

			-- 4. Servers clamps TTL > 600 and ignores NaN TTL
			local Servers = sh.env:require(sh.Server:WaitForChild("Servers"))
			Servers.Enabled = true
			Servers.Subscribers[srvAdmin] = true
			Servers.syncSubscription()
			world:run(0.2)
			local MessagingService = sh.env.game:GetService("MessagingService")
			MessagingService:PublishAsync("_KAdminServers", {
				"ttl-cap-job",
				1000,
				4,
				sh.env.globals.os.time(),
				999999,
			})
			MessagingService:PublishAsync("_KAdminServers", {
				"ttl-nan-job",
				1000,
				4,
				sh.env.globals.os.time(),
				0 / 0,
			})
			world:run(0.3)
			sert.eq(_K.Data.servers["ttl-cap-job"][5], 600)
			sert.eq(_K.Data.servers["ttl-nan-job"][5], 35)
		end
	)

	test(
		"Config.Themes replacing built-in themes under Deferred signals does not warn or drop themes, while true duplicates warn once",
		function()
			local function makeThemeFolder(env: any, defs: { { name: string, primary: any } })
				local configObj = env.Instance.new("Configuration")
				local folder = env.Instance.new("Folder", configObj)
				folder.Name = "Themes"
				local modules: { [string]: { any } } = {}
				for _, def in defs do
					local mod = env.Instance.new("ModuleScript", folder)
					mod.Name = def.name
					local primary = def.primary
					rawset(mod, "_factory", function()
						return { Primary = primary }
					end)
					modules[def.name] = modules[def.name] or {}
					table.insert(modules[def.name], mod)
				end
				return configObj, modules
			end

			local function countDupWarnings(list: { string }): number
				local count = 0
				for _, msg in list do
					if string.find(msg, "Duplicate theme", 1, true) then
						count += 1
					end
				end
				return count
			end

			-- 1. Mirror Loader/Config.Themes (Default, Legacy, Light) plus a custom theme under Deferred signals
			local hd = Harness.newEnv({ signalBehavior = "Deferred" })
			local warnings: { string } = {}
			local origWarn = hd.env.globals.warn
			hd.env.globals.warn = function(...: any)
				table.insert(warnings, table.concat({ ... }, " "))
			end

			local Color3 = hd.env.globals.Color3
			local defaultColor = Color3.fromRGB(11, 22, 33)
			local legacyColor = Color3.fromRGB(44, 55, 66)
			local lightColor = Color3.fromRGB(77, 88, 99)
			local cyberColor = Color3.fromRGB(100, 110, 120)

			local configObj = makeThemeFolder(hd.env, {
				{ name = "Default", primary = defaultColor },
				{ name = "Legacy", primary = legacyColor },
				{ name = "Light", primary = lightColor },
				{ name = "Cyberpunk", primary = cyberColor },
			})

			local dK = hd:requireK()
			local Theme = hd.env:require(hd.Client:WaitForChild("UI"):WaitForChild("Theme"))
			dK.initialize(configObj)

			-- Before deferred ChildRemoved/ChildAdded flush
			sert.eq(countDupWarnings(warnings), 0)
			sert.eq(Theme.Themes.Default ~= nil and Theme.Themes.Default.Primary, defaultColor)
			sert.eq(Theme.Themes.Legacy ~= nil and Theme.Themes.Legacy.Primary, legacyColor)
			sert.eq(Theme.Themes.Light ~= nil and Theme.Themes.Light.Primary, lightColor)
			sert.eq(Theme.Themes.Cyberpunk ~= nil and Theme.Themes.Cyberpunk.Primary, cyberColor)
			sert.eq(Theme.Primary:peek(), defaultColor)

			-- After deferred ChildRemoved/ChildAdded flush
			hd.env:step(0.1)
			hd.env.globals.warn = origWarn

			sert.eq(countDupWarnings(warnings), 0)
			sert.eq(Theme.Themes.Default ~= nil and Theme.Themes.Default.Primary, defaultColor)
			sert.eq(Theme.Themes.Legacy ~= nil and Theme.Themes.Legacy.Primary, legacyColor)
			sert.eq(Theme.Themes.Light ~= nil and Theme.Themes.Light.Primary, lightColor)
			sert.eq(Theme.Themes.Cyberpunk ~= nil and Theme.Themes.Cyberpunk.Primary, cyberColor)
			sert.eq(Theme.Primary:peek(), defaultColor)

			-- 2. Genuine duplicate modules in Config.Themes warn exactly once, and removal promotes the surviving sibling or Default fallback
			local hdDup = Harness.newEnv({ signalBehavior = "Deferred" })
			local dupWarnings: { string } = {}
			local origDupWarn = hdDup.env.globals.warn
			hdDup.env.globals.warn = function(...: any)
				table.insert(dupWarnings, table.concat({ ... }, " "))
			end

			local Color3Dup = hdDup.env.globals.Color3
			local neon1Color = Color3Dup.fromRGB(10, 20, 30)
			local neon2Color = Color3Dup.fromRGB(40, 50, 60)
			local customDefaultColor = Color3Dup.fromRGB(70, 80, 90)

			local dupConfig, dupMods = makeThemeFolder(hdDup.env, {
				{ name = "Light", primary = Color3Dup.fromRGB(200, 200, 200) },
				{ name = "Neon", primary = neon1Color },
				{ name = "Neon", primary = neon2Color },
				{ name = "Default", primary = customDefaultColor },
			})

			local dK2 = hdDup:requireK()
			local Theme2 = hdDup.env:require(hdDup.Client:WaitForChild("UI"):WaitForChild("Theme"))
			dK2.initialize(dupConfig)
			hdDup.env:step(0.1)

			sert.eq(countDupWarnings(dupWarnings), 1)
			sert.eq(Theme2.Themes.Neon ~= nil and Theme2.Themes.Neon.Primary, neon2Color)
			sert.eq(Theme2.Primary:peek(), customDefaultColor)

			-- Removing the active duplicate promotes the surviving sibling without warning
			dupMods.Neon[2]:Destroy()
			hdDup.env:step(0.1)
			sert.eq(countDupWarnings(dupWarnings), 1)
			sert.eq(Theme2.Themes.Neon ~= nil and Theme2.Themes.Neon.Primary, neon1Color)

			-- Removing the Default override falls back to built-in Default and updates Theme signals
			dupMods.Default[1]:Destroy()
			hdDup.env:step(0.1)
			hdDup.env.globals.warn = origDupWarn
			sert.eq(Theme2.Themes.Default ~= nil and Theme2.Themes.Default.Primary, Color3Dup.fromRGB(18, 18, 21))
			sert.eq(Theme2.Primary:peek(), Color3Dup.fromRGB(18, 18, 21))
		end
	)
end)

do
	return {}
end
