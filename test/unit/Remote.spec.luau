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

		local gs = sh.env.game:GetService("GroupService")
		local mps = sh.env.game:GetService("MarketplaceService")
		local getGroupsSpy = sert.spy(gs, "GetGroupsAsync")
		local ownsPassSpy = sert.spy(mps, "UserOwnsGamePassAsync")
		-- both offline targets are group SuperAdmins
		_K.Data.async.group[5100] = { { rank = 200, roles = { "superadmin" } } }
		sh.env.groups[5100] = { ranks = { [777011] = 250, [777014] = 250 }, Roles = {} }
		_K.Data.async.gamepass[558] = { "admin" }
		_K.Data.bans["777011"] = { "Banned777011", "Exploiting", 0, 1 }

		mRemote.Unban:Fire(777011)
		world:run(1)
		expect(_K.Data.bans["777011"]).toBeNil()
		expect(getGroupsSpy.callCount + ownsPassSpy.callCount).toBe(0)

		mRemote.Ban:Fire(777014, "nope", 0)
		world:run(1)
		expect(_K.Data.bans["777014"]).toBeNil()
		expect(getGroupsSpy.callCount + ownsPassSpy.callCount > 0).toBe(true)

		getGroupsSpy:restore()
		ownsPassSpy:restore()
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

	local fuzzWorld: any, fuzzK: any, fuzzGuestRemote: any, fuzzAdminRemote: any
	prop(
		"unprivileged client fuzzing Ban, Unban, Settings, PlayerPrefix, and Explorer never escalates or crashes server",
		function(g)
			if not fuzzWorld or #fuzzWorld.scheduler.errors > 0 then
				fuzzWorld = sert.sim.new({ backing = true })
				local server = fuzzWorld:server()
				local guestClient = server:client(202)
				local adminClient = server:client(101)

				local sh = Harness.newPeerEnv(server, { isStudio = false })
				fuzzK = sh:requireK()
				server:spawn(function()
					fuzzK.initialize({
						bans = {},
						userRoles = { superadmin = { 101 } },
						roles = Harness.defaultRoles(),
					})
				end)
				fuzzWorld:run(1)

				local guestEnv = Harness.newPeerEnv(guestClient, { isClient = true })
				local adminEnv = Harness.newPeerEnv(adminClient, { isClient = true })
				fuzzGuestRemote = guestEnv:requireRemote()
				fuzzAdminRemote = adminEnv:requireRemote()
				fuzzWorld:run(1)
			end
			local world, _K, gRemote, aRemote = fuzzWorld, fuzzK, fuzzGuestRemote, fuzzAdminRemote
			_K.Data.playerPrefix[202] = nil
			_K.Data.savedSettings.dashboardRank = 1
			table.clear(_K.Data.bans)

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

	test(
		"Remote.Command, Remote.PlayerPrefix, Remote.VIPUGCMethod, and Remote.EmoteType enforce rate limits and input validation",
		function()
			local world = sert.sim.new({ backing = true })
			local server = world:server()
			local guestClient = server:client(202)

			local sh = Harness.newPeerEnv(server, { isStudio = false })
			local _K = sh:requireK()
			server:spawn(function()
				_K.initialize({
					bans = {},
					userRoles = {},
					roles = Harness.defaultRoles(),
				})
			end)
			world:run(1)

			local guestEnv = Harness.newPeerEnv(guestClient, { isClient = true })
			local gRemote = guestEnv:requireRemote()
			local alerts = {}
			gRemote.Notify:Connect(function(payload)
				if type(payload) == "table" and type(payload.Text) == "string" then
					table.insert(alerts, payload.Text)
				end
			end)
			world:run(1)

			-- 1. Invalid commands via Remote.Command count against commandLimits and trigger cooldown after limit (4)
			local longInvalid = ";" .. string.rep("z", 1020)
			for _ = 1, 5 do
				gRemote.Command:Fire(longInvalid)
			end
			world:run(1)
			local sawCooldown = false
			for _, text in alerts do
				if string.find(text, "Command usage on cooldown!", 1, true) then
					sawCooldown = true
				end
			end
			expect(sawCooldown).toBe(true)
			expect(_K.Process.onCooldown(_K, 202)).toBe(true)
			world:run(4.5)
			expect(_K.Process.onCooldown(_K, 202)).toBe(false)

			-- 2. Remote.PlayerPrefix rate-limits rapid changes and cleans up on PlayerRemoving
			gRemote.PlayerPrefix:Fire("!")
			gRemote.PlayerPrefix:Fire("?")
			world:run(0.2)
			expect(_K.Data.playerPrefix[202]).toBe("!")
			world:run(1.1)
			gRemote.PlayerPrefix:Fire("?")
			world:run(0.2)
			expect(_K.Data.playerPrefix[202]).toBe("?")

			-- 3. Remote.VIPUGCMethod rejects spoofed assetId != ugcAssetMatch[assetId]
			local srvGuest = sh.env.Players:GetPlayerByUserId(202)
			local char = sh.env.Instance.new("Model")
			char.Name = srvGuest.Name
			sh.env.Instance.new("Part", char).Name = "HumanoidRootPart"
			char.Parent = sh.env.workspace
			srvGuest.Character = char
			local market = sh.env.game:GetService("MarketplaceService")
			local ownsAssetSpy = sert.spy(market, "PlayerOwnsAssetAsync", function(_self, _plr, assetId)
				return assetId == 999999 -- guest owns free item 999999, not VIP crown
			end)
			gRemote.VIPUGCMethod:Fire(999999, "rbxassetid://18966762965", true, "gold")
			world:run(0.5)
			expect(ownsAssetSpy).toHaveBeenCalledTimes(0)
			expect(char:FindFirstChild("SuperCrown")).toBeNil()
			ownsAssetSpy:restore()

			-- 4. Remote.EmoteType only sends full catalog once per player
			local emotePayloads = 0
			gRemote.EmoteType:Connect(function()
				emotePayloads += 1
			end)
			gRemote.EmoteType:Fire()
			gRemote.EmoteType:Fire()
			gRemote.EmoteType:Fire()
			world:run(0.5)
			expect(emotePayloads).toBe(1)

			-- Leaving clears playerPrefix and commandLimits
			server:leave(srvGuest)
			world:run(0.2)
			expect(_K.Data.playerPrefix[202]).toBeNil()
		end
	)

	test(
		"sert.laws.remote adversarial fuzzing of Ban, Unban, Settings, PlayerPrefix, Command, Explorer, Idled, and VIPUGCMethod",
		function()
			local world = sert.sim.new({ backing = true })
			local server = world:server()
			local sh = Harness.newPeerEnv(server, { isStudio = false })
			local _K = sh:requireK()
			local roles = Harness.defaultRoles()
			roles.everyone.commands.wait = false
			roles.everyone.commands.rejoin = false
			roles.mod.commands.explorer = true

			local adminPlr = sh.env:addPlayer(101, "SuperAdminTarget")
			local modPlr = sh.env:addPlayer(201, "ModCaller")
			local guestPlr = sh.env:addPlayer(202, "HostileGuest")
			for _, plr in { adminPlr, modPlr, guestPlr } do
				plr:SetAttribute("_KRolesLoaded", true)
				plr:SetAttribute("_K_READY", true)
				local char = sh.env.Instance.new("Model")
				char.Name = plr.Name
				sh.env.Instance.new("Part", char).Name = "HumanoidRootPart"
				char.Parent = sh.env.workspace
				plr.Character = char
			end

			server:spawn(function()
				_K.initialize({
					dashboardRank = 1,
					bans = {
						["500"] = { "SavedBannedUser", "Persistent exploit ban", -1, 101 },
					},
					userRoles = {
						superadmin = { 101 },
						mod = { 201 },
					},
					roles = roles,
				})
			end)
			world:run(1)

			local function invokeServerRemote(remoteObj: any, player: any, ...: any)
				local item = remoteObj._signal._head
				while item do
					local nextItem = item._next
					local callback = item._callback
					if item.Connected and callback then
						callback(player, ...)
					end
					item = nextItem
				end
			end

			local function assertGuestInvariants(plr: any)
				expect(_K.Auth.getRank(plr.UserId)).toBe(0)
				expect(_K.Auth.hasRestrictedRole(plr.UserId)).toBe(false)
				expect(_K.Auth.getRank(101) >= 4).toBe(true)
				expect(_K.Data.bans["101"]).toBeNil()
				expect(_K.Data.bans["500"] ~= nil).toBe(true)
				expect(_K.Data.bans["500"][3]).toBe(-1)
				expect(_K.Data.savedSettings.dashboardRank).toBe(1)
				expect(#(_K.Data.savedSettings.freeAdmin or {})).toBe(0)
				expect(_K.script.Parent ~= nil).toBe(true)
				expect(adminPlr.Character ~= nil and adminPlr.Character.Parent == sh.env.workspace).toBe(true)
			end

			-- 1. Remote.Ban from unprivileged guest
			sert.laws.remote("Remote.Ban (guest)", {
				makePlayer = function()
					return guestPlr
				end,
				argCount = 3,
				validGen = sert.gen.tuple({
					sert.gen.boundaryInt(-10, 1000),
					sert.gen.malformedString(),
					sert.gen.boundaryInt(-1, 86400),
				}),
				invalidGen = sert.gen.tuple({
					sert.gen.remotePayload(2),
					sert.gen.adversarial(2),
					sert.gen.remotePayload(2),
				}),
				handler = function(plr: any, userId: any, reason: any, duration: any)
					invokeServerRemote(_K.Remote.Ban, plr, userId, reason, duration)
				end,
				post = function(plr: any, ok: boolean)
					expect(ok).toBe(true)
					expect(_K.Auth.getRank(plr.UserId)).toBe(0)
				end,
				checkState = function(plr: any)
					assertGuestInvariants(plr)
					for k in _K.Data.bans do
						expect(k).toBe("500")
					end
				end,
			}, { runs = 40 })

			-- 2. Remote.Unban from unprivileged guest
			sert.laws.remote("Remote.Unban (guest)", {
				makePlayer = function()
					return guestPlr
				end,
				argCount = 1,
				validGen = sert.gen.oneOf({ sert.gen.constant(500), sert.gen.boundaryInt(-10, 1000) }),
				invalidGen = sert.gen.oneOf({ sert.gen.remotePayload(2), sert.gen.adversarial(2) }),
				handler = function(plr: any, userId: any)
					invokeServerRemote(_K.Remote.Unban, plr, userId)
				end,
				post = function(_plr: any, ok: boolean)
					expect(ok).toBe(true)
					expect(_K.Data.bans["500"] ~= nil).toBe(true)
				end,
				checkState = assertGuestInvariants,
			}, { runs = 40 })

			-- 3. Remote.Settings from unprivileged guest
			sert.laws.remote("Remote.Settings (guest)", {
				makePlayer = function()
					return guestPlr
				end,
				argCount = 1,
				validGen = sert.gen.map(
					sert.gen.tuple({ sert.gen.boundaryInt(0, 5), sert.gen.malformedString() }),
					function(pair)
						return {
							dashboardRank = pair[1],
							freeAdmin = { "creator", "superadmin", "admin" },
							prefix = { pair[2] },
						}
					end
				),
				invalidGen = sert.gen.oneOf({
					sert.gen.remotePayload(2),
					sert.gen.adversarial(2),
					sert.gen.sparseTable(),
				}),
				handler = function(plr: any, changes: any)
					invokeServerRemote(_K.Remote.Settings, plr, changes)
				end,
				post = function(_plr: any, ok: boolean)
					expect(ok).toBe(true)
					expect(_K.Data.savedSettings.dashboardRank).toBe(1)
				end,
				checkState = assertGuestInvariants,
			}, { runs = 40 })

			-- 4. Remote.PlayerPrefix with malformed strings and adversarial payloads
			sert.laws.remote("Remote.PlayerPrefix (guest)", {
				makePlayer = function()
					return guestPlr
				end,
				argCount = 1,
				validGen = sert.gen.pick({ "!", "?", ";", ":", "/", "-" }),
				invalidGen = sert.gen.oneOf({
					sert.gen.malformedString(),
					sert.gen.remotePayload(2),
					sert.gen.adversarial(2),
				}),
				handler = function(plr: any, prefix: any)
					_K.Data.playerPrefix[plr.UserId] = nil
					invokeServerRemote(_K.Remote.PlayerPrefix, plr, prefix)
				end,
				post = function(_plr: any, ok: boolean)
					expect(ok).toBe(true)
				end,
				checkState = function(plr: any)
					local p = _K.Data.playerPrefix[plr.UserId]
					if p ~= nil then
						expect(type(p)).toBe("string")
						expect(#p).toBe(1)
						expect(string.find(p, '[,"`@$%%*~%s]')).toBeNil()
					end
					_K.Data.playerPrefix[plr.UserId] = nil
					assertGuestInvariants(plr)
				end,
			}, { runs = 40 })

			-- 5. Remote.Command from unprivileged guest attempting privilege escalation & malformed command strings
			sert.laws.remote("Remote.Command (guest)", {
				makePlayer = function()
					return guestPlr
				end,
				argCount = 1,
				validGen = sert.gen.pick({
					";ban 101",
					";ban all",
					";unban 500",
					";role me creator",
					";superadmin me",
					";admin me",
					";mod me",
					";kick 101",
					";shutdown",
					";serverlock",
					";s workspace:ClearAllChildren()",
					";place 101 1",
					";global ban 101",
				}),
				invalidGen = sert.gen.oneOf({
					sert.gen.malformedString(),
					sert.gen.remotePayload(2),
					sert.gen.adversarial(2),
				}),
				handler = function(plr: any, message: any)
					_K.Process.resetLimit(plr.UserId)
					invokeServerRemote(_K.Remote.Command, plr, message)
				end,
				post = function(plr: any, ok: boolean)
					expect(ok).toBe(true)
					expect(_K.Auth.getRank(plr.UserId)).toBe(0)
				end,
				checkState = assertGuestInvariants,
			}, { runs = 40 })

			-- 6. Remote.Explorer from moderator attempting to delete/paste protected or higher-rank instances
			sert.laws.remote("Remote.Explorer (mod boundary)", {
				makePlayer = function()
					return modPlr
				end,
				argCount = 3,
				validGen = sert.gen.map(sert.gen.pick({ "DELETE", "PASTE", "UNKNOWN" }), function(action)
					return {
						action,
						{ _K.script, _K.Server, _K.Service.Players, adminPlr, adminPlr.Character },
						_K.script,
					}
				end),
				invalidGen = sert.gen.tuple({
					sert.gen.malformedString(),
					sert.gen.remotePayload(2),
					sert.gen.adversarial(2),
				}),
				handler = function(plr: any, action: any, data: any, selected: any)
					invokeServerRemote(_K.Remote.Explorer, plr, action, data, selected)
				end,
				post = function(_plr: any, ok: boolean)
					expect(ok).toBe(true)
				end,
				checkState = function()
					expect(_K.script.Parent ~= nil).toBe(true)
					expect(_K.Server.Parent ~= nil).toBe(true)
					expect(adminPlr.Parent == _K.Service.Players).toBe(true)
					expect(adminPlr.Character ~= nil and adminPlr.Character.Parent == sh.env.workspace).toBe(true)
				end,
			}, { runs = 40 })

			-- 7. Remote.Ban & Remote.Unban from moderator (has ban/unban, lacks banasync) against saved ban 500 & higher-rank 101
			sert.laws.remote("Remote.Ban & Unban (mod without banasync)", {
				makePlayer = function()
					return modPlr
				end,
				argCount = 3,
				validGen = sert.gen.tuple({
					sert.gen.pick({ 101, 500, -1, 0 }),
					sert.gen.malformedString(),
					sert.gen.pick({ -1, 0, 60, 3600 }),
				}),
				invalidGen = sert.gen.tuple({
					sert.gen.adversarial(2),
					sert.gen.remotePayload(2),
					sert.gen.boundaryFloat(-1e6, 1e6),
				}),
				handler = function(plr: any, userId: any, reason: any, duration: any)
					invokeServerRemote(_K.Remote.Ban, plr, userId, reason, duration)
					invokeServerRemote(_K.Remote.Unban, plr, userId)
				end,
				post = function(plr: any, ok: boolean)
					expect(ok).toBe(true)
					expect(_K.Auth.getRank(plr.UserId)).toBe(2)
				end,
				checkState = function()
					-- Moderator without banasync cannot lift or downgrade saved ban 500, and cannot ban superadmin 101
					expect(_K.Data.bans["101"]).toBeNil()
					expect(_K.Data.bans["500"] ~= nil).toBe(true)
					expect(_K.Data.bans["500"][3]).toBe(-1)
				end,
			}, { runs = 40 })

			-- 8. Remote.Idled & Remote.VIPUGCMethod with adversarial payloads
			sert.laws.remote("Remote.Idled & Remote.VIPUGCMethod (guest)", {
				makePlayer = function()
					return guestPlr
				end,
				argCount = 4,
				validGen = sert.gen.tuple({
					sert.gen.boundaryFloat(-100, 1000),
					sert.gen.malformedString(),
					sert.gen.bool(),
					sert.gen.malformedString(),
				}),
				invalidGen = sert.gen.tuple({
					sert.gen.adversarial(2),
					sert.gen.remotePayload(2),
					sert.gen.adversarial(2),
					sert.gen.remotePayload(2),
				}),
				handler = function(plr: any, a: any, b: any, c: any, d: any)
					invokeServerRemote(_K.Remote.Idled, plr, a)
					invokeServerRemote(_K.Remote.VIPUGCMethod, plr, a, b, c, d)
				end,
				post = function(plr: any, ok: boolean)
					expect(ok).toBe(true)
					expect(_K.Auth.getRank(plr.UserId)).toBe(0)
				end,
				checkState = function(plr: any)
					local idle = plr:GetAttribute("_KIdleTime")
					if idle ~= nil then
						expect(type(idle)).toBe("number")
						expect(idle >= 0 and idle < math.huge).toBe(true)
					end
					assertGuestInvariants(plr)
				end,
			}, { runs = 40 })
		end
	)

	do
		-- Actors: Guest (200, rank 0), VIP (201, rank 1), Mod (202, rank 2, session ban only),
		-- Admin (203, rank 3, persistent ban), SuperAdmin (204, rank 4, settings)
		local ACTOR_IDS = { 200, 201, 202, 203, 204 }
		local INITIAL_RANKS = {
			[200] = 0,
			[201] = 1,
			[202] = 2,
			[203] = 3,
			[204] = 4,
		}
		local RESERVED_PREFIXES = { ",", " ", "`", '"', "@", "$", "%", "*", "~" }

		local simSut: any = nil
		local function getOrCreateModelSut()
			if simSut and #simSut.world.scheduler.errors == 0 then
				return simSut
			end
			local world = sert.sim.new({ backing = true })
			local server = world:server()
			local clients = {}
			local remotes = {}
			for _, uid in ACTOR_IDS do
				clients[uid] = server:client(uid, `Actor_{uid}`)
			end

			local sh = Harness.newPeerEnv(server, { isStudio = false })
			local _K = sh:requireK()
			local roles = Harness.defaultRoles()
			roles.everyone.commands.wait = false
			roles.everyone.commands.rejoin = false

			server:spawn(function()
				_K.initialize({
					dashboardRank = 1,
					chatCommands = true,
					vip = true,
					bans = {},
					userRoles = {
						vip = { 201 },
						mod = { 202 },
						admin = { 203 },
						superadmin = { 204 },
					},
					roles = roles,
				})
			end)
			world:run(1)
			if _K.ChatCommands then
				_K.ChatCommands.schedule = function() end
			end

			local players = {}
			for _, uid in ACTOR_IDS do
				local cEnv = Harness.newPeerEnv(clients[uid], { isClient = true })
				remotes[uid] = cEnv:requireRemote()
				local srvPlr = sh.env.Players:GetPlayerByUserId(uid)
				srvPlr:SetAttribute("_KRolesLoaded", true)
				srvPlr:SetAttribute("_K_READY", true)
				local char = sh.env.Instance.new("Model")
				char.Name = srvPlr.Name
				sh.env.Instance.new("Part", char).Name = "HumanoidRootPart"
				char.Parent = sh.env.workspace
				srvPlr.Character = char
				-- Record kicks without disconnecting actor peers mid-sequence
				rawset(srvPlr, "_kickFn", function(self: any, message: string?)
					table.insert(
						sh.env.kicks,
						{ player = self, userId = self.UserId, message = message or "", at = sh.env.now }
					)
				end)
				players[uid] = srvPlr
			end
			world:run(1)

			local market = sh.env.game:GetService("MarketplaceService")
			local mktMethods = rawget(market, "_methods") or {}
			mktMethods.PlayerOwnsAssetAsync = function(_self: any, plr: any, assetId: number)
				return plr.UserId >= 201 and assetId == 18966788838
			end
			rawset(market, "_methods", mktMethods)

			simSut = {
				world = world,
				server = server,
				sh = sh,
				_K = _K,
				remotes = remotes,
				players = players,
			}
			return simSut
		end

		sert.model("Multi-Rank Remote Protocol & Authorization Model (in sert.sim)", {
			init = function()
				local sut = getOrCreateModelSut()
				local _K = sut._K
				table.clear(_K.Data.bans)
				table.clear(_K.Data.playerPrefix)
				_K.Data.savedSettings.dashboardRank = 1
				_K.Data.savedSettings.chatCommands = true
				_K.Data.savedSettings.freeAdmin = {}
				for _, uid in ACTOR_IDS do
					_K.Process.resetLimit(uid)
					sut.players[uid]:SetAttribute("_KIdleTime", nil)
				end
				return {
					ranks = table.clone(INITIAL_RANKS),
					bans = {},
					settings = {
						dashboardRank = 1,
						chatCommands = true,
					},
					prefixes = {},
					idleTimes = {},
					unauthorizedSettingsMutated = false,
					prefixContaminated = false,
				},
					sut
			end,
			commands = {
				RemoteBan = {
					gen = function(g)
						return {
							caller = g:pick(ACTOR_IDS),
							target = g:pick(ACTOR_IDS),
							duration = g:pick({ 0, -1, 60, 3600 }),
							reason = g:pick({ "rule violation", "spam", nil }),
						}
					end,
					run = function(sut, arg)
						sut.remotes[arg.caller].Ban:Fire(arg.target, arg.reason, arg.duration)
						sut.world:run(0.2)
					end,
					next = function(state, arg)
						local sut = getOrCreateModelSut()
						local _K = sut._K
						local callerRank = state.ranks[arg.caller]
						local targetRank = state.ranks[arg.target]
						local canBan = _K.Auth.hasCommand(arg.caller, "ban") ~= false
						local hasTargetOthers = _K.Auth.hasPermission(arg.caller, "targetOthers")
						local canTarget = (arg.caller ~= arg.target) and hasTargetOthers and (callerRank > targetRank)
						local hasBanAsync = _K.Auth.hasPermission(arg.caller, "banasync")
							and _K.Auth.hasRestrictedRole(arg.caller)

						if canBan and canTarget then
							local key = tostring(arg.target)
							local existing = state.bans[key]
							local isSaved = existing ~= nil and existing.persisted == true
							local effDur = if hasBanAsync then arg.duration else 0
							if not (isSaved and not hasBanAsync) then
								state.bans[key] = {
									persisted = effDur ~= 0,
									effDur = effDur,
									by = arg.caller,
									byRank = callerRank,
									targetRank = targetRank,
								}
							end
						end
						return state
					end,
				},
				RemoteUnban = {
					gen = function(g)
						return {
							caller = g:pick(ACTOR_IDS),
							target = g:pick(ACTOR_IDS),
						}
					end,
					run = function(sut, arg)
						sut.remotes[arg.caller].Unban:Fire(arg.target)
						sut.world:run(0.2)
					end,
					next = function(state, arg)
						local sut = getOrCreateModelSut()
						local _K = sut._K
						local callerRank = state.ranks[arg.caller]
						local targetRank = state.ranks[arg.target]
						local canUnban = _K.Auth.hasCommand(arg.caller, "unban") ~= false
						local hasTargetOthers = _K.Auth.hasPermission(arg.caller, "targetOthers")
						local canTarget = (arg.caller ~= arg.target) and hasTargetOthers and (callerRank > targetRank)
						local hasBanAsync = _K.Auth.hasPermission(arg.caller, "banasync")
							and _K.Auth.hasRestrictedRole(arg.caller)

						local key = tostring(arg.target)
						local existing = state.bans[key]
						if existing ~= nil and canUnban and canTarget then
							if not (existing.persisted and not hasBanAsync) then
								state.bans[key] = nil
							end
						end
						return state
					end,
				},
				RemoteSettings = {
					gen = function(g)
						return {
							caller = g:pick(ACTOR_IDS),
							dashboardRank = g:pick({ 0, 1, 2, 3 }),
							chatCommands = g:bool(),
							attemptFreeAdmin = g:bool(),
						}
					end,
					run = function(sut, arg)
						local delta: { [string]: any } = {
							dashboardRank = arg.dashboardRank,
							chatCommands = arg.chatCommands,
						}
						if arg.attemptFreeAdmin then
							delta.freeAdmin = { "superadmin" }
						end
						sut.remotes[arg.caller].Settings:Fire(delta)
						sut.world:run(0.2)
					end,
					next = function(state, arg)
						local sut = getOrCreateModelSut()
						local _K = sut._K
						local canSettings = _K.Auth.hasPermission(arg.caller, "settings")
						if canSettings then
							state.settings.dashboardRank = arg.dashboardRank
							state.settings.chatCommands = arg.chatCommands
						else
							if
								_K.Data.savedSettings.dashboardRank ~= state.settings.dashboardRank
								or _K.Data.savedSettings.chatCommands ~= state.settings.chatCommands
							then
								state.unauthorizedSettingsMutated = true
							end
						end
						return state
					end,
				},
				RemotePlayerPrefix = {
					gen = function(g)
						return {
							caller = g:pick(ACTOR_IDS),
							prefix = g:pick({ "!", "?", ":", "/", "-", "@", "$", "ab" }),
						}
					end,
					run = function(sut, arg)
						sut.world:run(1.05)
						sut.remotes[arg.caller].PlayerPrefix:Fire(arg.prefix)
						sut.world:run(0.2)
					end,
					next = function(state, arg)
						local sut = getOrCreateModelSut()
						local _K = sut._K
						local valid = type(arg.prefix) == "string"
							and utf8.len(arg.prefix) == 1
							and not table.find(RESERVED_PREFIXES, arg.prefix)
						if valid then
							state.prefixes[arg.caller] = arg.prefix
						end
						for _, uid in ACTOR_IDS do
							if uid ~= arg.caller and _K.Data.playerPrefix[uid] ~= state.prefixes[uid] then
								state.prefixContaminated = true
							end
						end
						return state
					end,
				},
				RemoteCommand = {
					gen = function(g)
						return {
							caller = g:pick(ACTOR_IDS),
							cmdStr = g:pick({
								";role me superadmin",
								";superadmin me",
								";admin me",
								";ban 204",
								";kick 204",
								";version",
								";help",
							}),
						}
					end,
					run = function(sut, arg)
						sut._K.Process.resetLimit(arg.caller)
						sut.remotes[arg.caller].Command:Fire(arg.cmdStr)
						sut.world:run(0.2)
					end,
					next = function(state)
						return state
					end,
				},
				RemoteIdled = {
					gen = function(g)
						return {
							caller = g:pick(ACTOR_IDS),
							time = g:pick({ 0, 15, 120, -10, math.huge }),
						}
					end,
					run = function(sut, arg)
						sut.remotes[arg.caller].Idled:Fire(arg.time)
						sut.world:run(0.2)
					end,
					next = function(state, arg)
						if type(arg.time) == "number" and arg.time >= 0 and arg.time < math.huge then
							state.idleTimes[arg.caller] = arg.time
						end
						return state
					end,
				},
				RemoteVIPUGCMethod = {
					gen = function(g)
						return {
							caller = g:pick(ACTOR_IDS),
							asset = {
								id = g:pick({ 18966788838, 999999 }),
								match = "rbxassetid://18966762965",
								equip = g:bool(),
								name = g:pick({ "Gold", string.rep("x", 80) }),
							},
						}
					end,
					run = function(sut, arg)
						local a = arg.asset
						sut.remotes[arg.caller].VIPUGCMethod:Fire(a.id, a.match, a.equip, a.name)
						sut.world:run(0.2)
					end,
					next = function(state)
						return state
					end,
				},
			},
			never = {
				privilegeEscalation = function(state, sut)
					for uid, expectedRank in state.ranks do
						if sut._K.Auth.getRank(uid) ~= expectedRank then
							return true
						end
					end
					if #(sut._K.Data.savedSettings.freeAdmin or {}) > 0 then
						return true
					end
					return false
				end,
				higherOrEqualRankBanned = function(state, sut)
					for key, ban in sut._K.Data.bans do
						local targetId = tonumber(key)
						local bannerId = ban[4]
						if targetId and bannerId then
							local tRank = state.ranks[targetId] or 0
							local bRank = state.ranks[bannerId] or 0
							if tRank >= bRank then
								return true
							end
						end
					end
					return sut._K.Data.bans["204"] ~= nil
				end,
				sessionModPersistedBan = function(state, sut)
					for key, ban in sut._K.Data.bans do
						if ban[4] == 202 and ban[3] ~= nil and ban[3] ~= 0 then
							return true
						end
						local ref = state.bans[key]
						if ref and ref.persisted and (ban[3] == nil or ban[3] == 0) then
							return true
						end
					end
					return false
				end,
				unauthorizedSettingsMutation = function(state, sut)
					local saved = sut._K.Data.savedSettings
					return state.unauthorizedSettingsMutated
						or saved.dashboardRank ~= state.settings.dashboardRank
						or saved.chatCommands ~= state.settings.chatCommands
				end,
				prefixCrossContamination = function(state, sut)
					if state.prefixContaminated then
						return true
					end
					for _, uid in ACTOR_IDS do
						if sut._K.Data.playerPrefix[uid] ~= state.prefixes[uid] then
							return true
						end
					end
					return false
				end,
			},
			invariant = function(state, sut)
				expect(sut.world.scheduler.errors).toEqual({})
				for _, uid in ACTOR_IDS do
					local key = tostring(uid)
					local actualBan = sut._K.Data.bans[key]
					local refBan = state.bans[key]
					if refBan == nil then
						expect(actualBan).toBeNil()
					else
						expect(actualBan ~= nil).toBe(true)
						expect(actualBan[4]).toBe(refBan.by)
						local isPersisted = actualBan[3] ~= nil and actualBan[3] ~= 0
						expect(isPersisted).toBe(refBan.persisted)
					end
					expect(sut._K.Data.playerPrefix[uid]).toBe(state.prefixes[uid])
					expect(sut.players[uid]:GetAttribute("_KIdleTime")).toBe(state.idleTimes[uid])
				end
			end,
		}, { runs = 25, length = 20 })
	end

	test(
		"sert.sim sliding-window rate limiting & broadcast cooldowns enforce per-sender and global bounds without starving normal traffic",
		function()
			local world = sert.sim.new({ backing = true })
			local server = world:server()
			local guestAClient = server:client(201, "GuestA")
			local guestBClient = server:client(202, "GuestB")
			local vipClient = server:client(203, "VIPUser")
			local adminAClient = server:client(301, "AdminA")
			local adminBClient = server:client(302, "AdminB")

			local sh = Harness.newPeerEnv(server, { isStudio = false })
			local _K = sh:requireK()
			local roles = Harness.defaultRoles()
			roles.everyone.commands.version = true
			roles.vip.commands.version = true

			server:spawn(function()
				_K.initialize({
					bans = {},
					userRoles = {
						vip = { 203 },
						admin = { 301, 302 },
					},
					roles = roles,
				})
			end)
			world:run(1)

			local guestAEnv = Harness.newPeerEnv(guestAClient, { isClient = true })
			local guestBEnv = Harness.newPeerEnv(guestBClient, { isClient = true })
			local vipEnv = Harness.newPeerEnv(vipClient, { isClient = true })
			local adminAEnv = Harness.newPeerEnv(adminAClient, { isClient = true })
			local adminBEnv = Harness.newPeerEnv(adminBClient, { isClient = true })

			local rGuestA = guestAEnv:requireRemote()
			local rGuestB = guestBEnv:requireRemote()
			local rVip = vipEnv:requireRemote()
			local rAdminA = adminAEnv:requireRemote()
			local rAdminB = adminBEnv:requireRemote()

			local cChatGuestA = guestAEnv:requireShared("Chat")
			local cChatGuestB = guestBEnv:requireShared("Chat")
			local receivedByGuestA = {}
			local receivedByGuestB = {}
			cChatGuestA.onMessage("announce", function(text, from, _data, id)
				table.insert(receivedByGuestA, { text = text, from = from, id = id })
			end)
			cChatGuestB.onMessage("announce", function(text, from, _data, id)
				table.insert(receivedByGuestB, { text = text, from = from, id = id })
			end)
			world:run(0.5)

			-- 1. Concurrent command burst from GuestA (limit 4 / 4s window) vs normal traffic from GuestB and VIP (limit 16)
			for _ = 1, 6 do
				rGuestA.Command:Fire(";version")
			end
			world:run(0.2)
			expect(_K.Process.onCooldown(_K, 201)).toBe(true)
			expect(_K.Process.onCooldown(_K, 202)).toBe(false)
			expect(_K.Process.onCooldown(_K, 203)).toBe(false)

			-- At t = 0.7s: GuestB sends 2 normal commands, VIP sends 10 commands (within VIP limit of 16)
			world:run(0.5)
			rGuestB.Command:Fire(";version")
			rGuestB.Command:Fire(";version")
			for _ = 1, 10 do
				rVip.Command:Fire(";version")
			end
			world:run(0.2)
			expect(_K.Process.onCooldown(_K, 201)).toBe(true)
			expect(_K.Process.onCooldown(_K, 202)).toBe(false)
			expect(_K.Process.onCooldown(_K, 203)).toBe(false)

			-- At t = 2.0s: GuestB sends 2 more commands (reaching exact bound of 4 -> onCooldown becomes true)
			world:run(1.1)
			rGuestB.Command:Fire(";version")
			rGuestB.Command:Fire(";version")
			world:run(0.2)
			expect(_K.Process.onCooldown(_K, 201)).toBe(true)
			expect(_K.Process.onCooldown(_K, 202)).toBe(true)
			expect(_K.Process.onCooldown(_K, 203)).toBe(false)

			-- At t = 4.2s: GuestA's 4s window from t = 0 has slid/reset, while GuestB's 4s window from t = 0.7s is still active!
			world:run(2.0)
			expect(_K.Process.onCooldown(_K, 201)).toBe(false)
			expect(_K.Process.onCooldown(_K, 202)).toBe(true)

			-- Normal command from GuestA now succeeds again
			rGuestA.Command:Fire(";version")
			world:run(0.8)
			-- At t = 5.0s: GuestB's 4s window from t = 0.7s has now also expired
			expect(_K.Process.onCooldown(_K, 202)).toBe(false)

			-- 2. Chat.limitBroadcast & Remote.ChatSystem sliding 60s broadcast cooldown across concurrent senders
			-- AdminA (301) fires a burst of 4 broadcasts; only the 1st passes the 60s per-sender gate
			rAdminA.Command:Fire(";announce AdminA first broadcast")
			rAdminA.Command:Fire(";announce AdminA burst 2")
			rAdminA.Command:Fire(";announce AdminA burst 3")
			world:run(0.5)
			expect(_K.Chat.limitBroadcast(301) ~= nil).toBe(true)
			expect(_K.Chat.limitBroadcast(302)).toBeNil() -- consumes 302's slot when called directly; let's test via Chat.send next!

			-- Advance 10s: AdminA (301) is still cooling down (~50s left)
			world:run(10)
			local errA10 = _K.Chat.limitBroadcast(301)
			expect(errA10 ~= nil and string.find(errA10, "Wait ", 1, true) ~= nil).toBe(true)

			-- Wait out 302's 60s window from the direct check above while checking 301 at t + 50s:
			-- Let's also verify a third sender (or AdminB after 50s) and Remote.ChatSystem delivery + 30s client dedup window
			local srvAdminB = sh.env.Players:GetPlayerByUserId(302)
			local countBefore = #receivedByGuestA
			-- Direct Remote.ChatSystem duplicate packet burst with same GUID is deduplicated within 30s client window
			local srvGuestA = sh.env.Players:GetPlayerByUserId(201)
			for _ = 1, 4 do
				_K.Remote.ChatSystem:Fire(srvGuestA, "announce", "Deduplicated msg", 302, nil, "fixed-guid-1")
			end
			world:run(0.5)
			expect(#receivedByGuestA).toBe(countBefore + 1)
			expect(receivedByGuestA[#receivedByGuestA].id).toBe("fixed-guid-1")

			-- At +15s (still within 30s dedup window), duplicate packet is still ignored
			world:run(15)
			_K.Remote.ChatSystem:Fire(srvGuestA, "announce", "Deduplicated msg", 302, nil, "fixed-guid-1")
			world:run(0.5)
			expect(#receivedByGuestA).toBe(countBefore + 1)

			-- At +16s (total 31.5s > 30s client dedup window), the ID is evicted and can be received again
			world:run(16)
			_K.Remote.ChatSystem:Fire(srvGuestA, "announce", "Deduplicated msg", 302, nil, "fixed-guid-1")
			world:run(0.5)
			expect(#receivedByGuestA).toBe(countBefore + 2)

			-- Advance remaining 20s so both 301 and 302 cross their 60s broadcast cooldown window
			world:run(20)
			expect(_K.Chat.limitBroadcast(301)).toBeNil()
			local msgId, sendErr = _K.Chat.send(
				{ from = 302, fromPlayer = srvAdminB },
				"announce",
				"AdminB broadcast after window",
				nil,
				{ "AdminB broadcast after window", 302, 5, "pin-guid-2" }
			)
			world:run(0.5)
			expect(sendErr).toBeNil()
			expect(type(msgId)).toBe("string")
			expect(receivedByGuestB[#receivedByGuestB].text).toBe("AdminB broadcast after window")
			expect(receivedByGuestB[#receivedByGuestB].from).toBe(302)
			local _ = rAdminB
		end
	)
end)

return {}
