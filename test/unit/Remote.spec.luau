local Harness = require("./Harness")
local sert = require("../sert")

local describe, test, expect = sert.describe, sert.test, sert.expect
local prop = sert.prop

describe("Remote · Multiplexed Packet Framing, Queue Flushing & Reliability", function()
	test(
		"synchronizes packed IDs, flushes pre-sync client queues, and supports bidirectional Fire/Invoke/SetUnreliable",
		function()
			local world = sert.sim.new({ backing = true })
			local server = world:server()
			local client = server:client(101)

			local sh = Harness.newPeerEnv(server, { isStudio = false })
			local ch = Harness.newPeerEnv(client, { isClient = true })

			local sRemote = sh:requireRemote()
			local sReceived = {}
			sRemote.ChatMsg:Connect(function(plr, text, code)
				table.insert(sReceived, { uid = plr.UserId, text = text, code = code })
			end)
			sRemote.Compute.OnInvoke = function(plr, a, b)
				return plr.UserId + a + b
			end
			local _ = sRemote.ClientPing

			local cRemote = ch:requireRemote()
			local cReceived = {}
			cRemote.AnnounceMsg:Connect(function(msg)
				table.insert(cReceived, msg)
			end)
			cRemote.ClientPing.OnInvoke = function(val)
				return `pong:{val}`
			end

			-- Queue a client Fire before initial sync packet arrives from server
			cRemote.PreQueued:Fire("queued_before_sync")
			local preQueuedSeen = nil
			sRemote.PreQueued:Connect(function(_plr, payload)
				preQueuedSeen = payload
			end)

			-- Step the world so initial handshake and queued packets flush
			world:run(1)
			expect(preQueuedSeen).toBe("queued_before_sync")

			-- Client -> Server Fire
			cRemote.ChatMsg:Fire("hello server", 42)
			-- Server -> Client FireAll
			sRemote.AnnounceMsg:FireAll("welcome all")
			-- Toggle reliability and Fire
			sRemote.FastTick:SetUnreliable(true)
			local fastSeen = nil
			cRemote.FastTick:Connect(function(v)
				fastSeen = v
			end)
			world:run(0.5)
			local srvPlr = sh.env.Players:GetPlayerByUserId(101)
			sRemote.FastTick:Fire(srvPlr, 999)
			world:run(1)

			expect(#sReceived).toBe(1)
			expect(sReceived[1].uid).toBe(101)
			expect(sReceived[1].text).toBe("hello server")
			expect(sReceived[1].code).toBe(42)
			expect(cReceived[1]).toBe("welcome all")
			expect(fastSeen).toBe(999)

			-- Bidirectional RPC Invoke (Client -> Server and Server -> Client)
			local rpcResult = nil
			client:spawn(function()
				rpcResult = cRemote.Compute:Invoke(10, 20)
			end)
			local clientRpcResult = nil
			server:spawn(function()
				clientRpcResult = sRemote.ClientPing:Invoke(srvPlr, "check")
			end)
			world:run(1)
			expect(rpcResult).toBe(131)
			expect(clientRpcResult).toBe("pong:check")

			-- Once, Wait, and client SetUnreliable guard
			cRemote.FastTick:SetUnreliable(false) -- client guard warns and does not throw
			local onceVal, waitVal = nil, nil
			cRemote.OnceEvt:Once(function(v)
				onceVal = v
			end)
			client:spawn(function()
				waitVal = cRemote.WaitEvt:Wait()
			end)
			sRemote.OnceEvt:Fire(srvPlr, "first_once")
			sRemote.OnceEvt:Fire(srvPlr, "second_ignored")
			sRemote.WaitEvt:Fire(srvPlr, "waited_payload")
			world:run(1)
			expect(onceVal).toBe("first_once")
			expect(waitVal).toBe("waited_payload")

			-- Pre-sync client Invoke queue flushing & >256 2-byte packed IDs
			local preInvokeVal = nil
			client:spawn(function()
				preInvokeVal = cRemote.PreQueuedRpc:Invoke(77)
			end)
			sRemote.PreQueuedRpc.OnInvoke = function(_plr, x)
				return x * 2
			end
			for i = 1, 260 do
				local _ = sRemote[`BulkEvent_{i}`]
			end
			local highIdSeen = nil
			cRemote.BulkEvent_260:Connect(function(v)
				highIdSeen = v
			end)
			world:run(0.5)
			sRemote.BulkEvent_260:Fire(srvPlr, "two_byte_id")
			world:run(1)
			expect(preInvokeVal).toBe(154)
			expect(highIdSeen).toBe("two_byte_id")
		end
	)
end)

describe("Remote · Server Endpoint Authorization & Hostile Client Fuzzing", function()
	test("Remote.Unban doesn't look up offline ranks, Remote.Ban still does", function()
		local world = sert.sim.new({ backing = true })
		local server = world:server()
		local modClient = server:client(301)

		local sh = Harness.newPeerEnv(server, { isStudio = false })
		local _K = sh:requireK()
		server:spawn(function()
			_K.initialize({
				bans = {},
				userRoles = { mod = { 301 } },
				roles = Harness.defaultRoles(),
			})
		end)
		world:run(1)
		local mRemote = Harness.newPeerEnv(modClient, { isClient = true }):requireRemote()
		world:run(1)
		_K.Data.roles.mod.permissions.ban = true
		_K.Data.roles.mod.permissions.unban = true

		local gMethods = rawget(sh.env.game:GetService("GroupService"), "_methods")
		local mMethods = rawget(sh.env.game:GetService("MarketplaceService"), "_methods")
		local origGetGroups, origOwnsPass = gMethods.GetGroupsAsync, mMethods.UserOwnsGamePassAsync
		local webCalls = 0
		gMethods.GetGroupsAsync = function(...)
			webCalls += 1
			return origGetGroups(...)
		end
		mMethods.UserOwnsGamePassAsync = function(...)
			webCalls += 1
			return origOwnsPass(...)
		end
		-- both offline targets are group SuperAdmins
		_K.Data.async.group[5100] = { { rank = 200, roles = { "superadmin" } } }
		sh.env.groups[5100] = { ranks = { [777011] = 250, [777014] = 250 }, Roles = {} }
		_K.Data.async.gamepass[558] = { "admin" }
		_K.Data.bans["777011"] = { "Banned777011", "Exploiting", 0, 1 }

		mRemote.Unban:Fire(777011)
		world:run(1)
		expect(_K.Data.bans["777011"]).toBeNil()
		expect(webCalls).toBe(0)

		mRemote.Ban:Fire(777014, "nope", 0)
		world:run(1)
		expect(_K.Data.bans["777014"]).toBeNil()
		expect(webCalls > 0).toBe(true)

		gMethods.GetGroupsAsync, mMethods.UserOwnsGamePassAsync = origGetGroups, origOwnsPass
	end)

	test("Remote.Ban and Remote.Unban only take userIds in 1..2^53", function()
		local world = sert.sim.new({ backing = true })
		local server = world:server()
		local adminClient = server:client(101)

		local sh = Harness.newPeerEnv(server, { isStudio = false })
		local _K = sh:requireK()
		server:spawn(function()
			_K.initialize({
				bans = {},
				userRoles = { superadmin = { 101 } },
				roles = Harness.defaultRoles(),
			})
		end)
		world:run(1)
		local aRemote = Harness.newPeerEnv(adminClient, { isClient = true }):requireRemote()
		world:run(1)

		aRemote.Ban:Fire(1e300, "junk")
		aRemote.Ban:Fire(2 ^ 53 + 2, "junk")
		world:run(1)
		expect(next(_K.Data.bans)).toBeNil()

		aRemote.Ban:Fire(2 ^ 53, "edge")
		world:run(1)
		expect(world.scheduler.errors).toEqual({})
		expect(_K.Data.bans["9007199254740992"] ~= nil).toBe(true)
		aRemote.Unban:Fire(2 ^ 53)
		world:run(1)
		expect(_K.Data.bans["9007199254740992"]).toBeNil()

		-- Unban takes the same bound, a junk key saved before this check is left to ;unban
		_K.Data.bans["1e+300"] = { "Unknown", "junk", 0, 101 }
		_K.Data.bans["9007199254740994"] = { "Unknown", "junk", 0, 101 }
		aRemote.Unban:Fire(1e300)
		aRemote.Unban:Fire(2 ^ 53 + 2)
		world:run(1)
		expect(_K.Data.bans["1e+300"] ~= nil).toBe(true)
		expect(_K.Data.bans["9007199254740994"] ~= nil).toBe(true)
	end)

	prop(
		"unprivileged client fuzzing Ban, Unban, Settings, PlayerPrefix, and Explorer never escalates or crashes server",
		function(g)
			local world = sert.sim.new({ backing = true })
			local server = world:server()
			local guestClient = server:client(202)
			local adminClient = server:client(101)

			local sh = Harness.newPeerEnv(server, { isStudio = false })
			local _K = sh:requireK()
			server:spawn(function()
				_K.initialize({
					bans = {},
					userRoles = { superadmin = { 101 } },
					roles = Harness.defaultRoles(),
				})
			end)
			world:run(1)

			local guestEnv = Harness.newPeerEnv(guestClient, { isClient = true })
			local adminEnv = Harness.newPeerEnv(adminClient, { isClient = true })
			local gRemote = guestEnv:requireRemote()
			local aRemote = adminEnv:requireRemote()
			world:run(1)

			-- Hostile guest attempts unauthorized Ban, Unban, Settings, and invalid PlayerPrefix
			local bogusId = g:pick({ -5, 0, 101, 99999, 0 / 0, math.huge })
			local bogusDur = g:pick({ -1, 0, 60, 0 / 0, math.huge })
			gRemote.Ban:Fire(bogusId, "hostile ban", bogusDur)
			gRemote.Unban:Fire(bogusId)
			gRemote.Settings:Fire({
				dashboardRank = 0,
				freeAdmin = { "creator" },
				prefix = { "@" },
			})
			local reserved = g:pick({ ",", " ", "`", '"', "@", "$", "%", "*", "~", "twochars" })
			gRemote.PlayerPrefix:Fire(reserved)
			gRemote.Idled:Fire("not_a_number")
			world:run(1)

			expect(world.scheduler.errors).toEqual({})
			expect(next(_K.Data.bans)).toBeNil()
			expect(_K.Data.playerPrefix[202]).toBeNil()

			-- Valid single-char prefix from guest is accepted
			gRemote.PlayerPrefix:Fire("!")
			-- Authorized superadmin client bans user 303 and updates dashboardRank
			aRemote.Ban:Fire(303, "legit ban", -1)
			aRemote.Settings:Fire({ dashboardRank = 2 })
			world:run(1)

			expect(world.scheduler.errors).toEqual({})
			expect(_K.Data.playerPrefix[202]).toBe("!")
			expect(_K.Data.bans["303"] ~= nil).toBe(true)
			expect(_K.Data.savedSettings.dashboardRank).toBe(2)

			-- Authorized superadmin unbans user 303
			aRemote.Unban:Fire(303)
			world:run(1)
			expect(_K.Data.bans["303"]).toBeNil()
		end,
		{ runs = 25 }
	)

	test(
		"Remote.Settings sanitizes announcement/notification Duration and rejects invalid UTF-8 or >1000-byte Text",
		function()
			local world = sert.sim.new({ backing = true })
			local server = world:server()
			local adminClient = server:client(101)

			local sh = Harness.newPeerEnv(server, { isStudio = false })
			local _K = sh:requireK()
			server:spawn(function()
				_K.initialize({
					bans = {},
					userRoles = { superadmin = { 101 } },
					roles = Harness.defaultRoles(),
				})
			end)
			world:run(1)

			local adminEnv = Harness.newPeerEnv(adminClient, { isClient = true })
			local aRemote = adminEnv:requireRemote()
			world:run(1)

			-- Invalid UTF-8 or >1000-byte announcement and list entries are ignored
			aRemote.Settings:Fire({
				announcement = { "\255\254invalid" },
				announcements = {
					{ Text = string.rep("x", 1001), Duration = 10 },
					{ Text = "\192\128badutf8", Duration = 10 },
					{ Text = "valid nan", Duration = 0 / 0 },
				},
				notifications = {
					{ Text = "valid inf", Duration = math.huge },
				},
			})
			world:run(1)
			-- Two valid new items in one burst trigger the burst guard ("Please wait before adding another message.")
			expect(_K.Data.savedSettings.announcement).toBeFalsy()
			expect(#(_K.Data.savedSettings.announcements or {})).toBe(0)

			-- Single valid item with NaN Duration -> Duration becomes nil
			aRemote.Settings:Fire({
				announcements = {
					{ Text = "nan duration msg", Duration = 0 / 0 },
				},
			})
			world:run(1)
			expect(#_K.Data.savedSettings.announcements).toBe(1)
			expect(_K.Data.savedSettings.announcements[1].Text).toBe("nan duration msg")
			expect(_K.Data.savedSettings.announcements[1].Duration).toBeNil()

			-- Wait out broadcast cooldown (60s), then test math.huge Duration -> clamped to 600
			world:run(61)
			aRemote.Settings:Fire({
				notifications = {
					{ Text = "clamped duration msg", Duration = math.huge },
				},
			})
			world:run(1)
			expect(#_K.Data.savedSettings.notifications).toBe(1)
			expect(_K.Data.savedSettings.notifications[1].Duration).toBe(600)

			-- Wait out broadcast cooldown (60s), then test negative Duration -> clamped to 0
			world:run(61)
			aRemote.Settings:Fire({
				notifications = {
					{ Text = "clamped duration msg", Duration = 600, From = 101 },
					{ Text = "neg duration msg", Duration = -50 },
				},
			})
			world:run(1)
			expect(_K.Data.savedSettings.notifications[#_K.Data.savedSettings.notifications].Duration).toBe(0)
		end
	)
end)

return {}
