local Harness = require("./Harness")
local sert = require("../sert")

local describe, test = sert.describe, sert.test
local prop = sert.prop

describe("Remote · Multiplexed Packet Framing, Queue Flushing & Reliability", function()
	test(
		"synchronizes packed IDs, flushes pre-sync client queues, and supports bidirectional Fire/Invoke/SetUnreliable",
		function()
			local world = sert.sim.new({ backing = true, latency = { remotes = 0.02 } })
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
			sert.eq(preQueuedSeen, "queued_before_sync")

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

			sert.eq(#sReceived, 1)
			sert.eq(sReceived[1].uid, 101)
			sert.eq(sReceived[1].text, "hello server")
			sert.eq(sReceived[1].code, 42)
			sert.eq(cReceived[1], "welcome all")
			sert.eq(fastSeen, 999)

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
			sert.eq(rpcResult, 131)
			sert.eq(clientRpcResult, "pong:check")

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
			sert.eq(onceVal, "first_once")
			sert.eq(waitVal, "waited_payload")

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
			sert.eq(preInvokeVal, 154)
			sert.eq(highIdSeen, "two_byte_id")
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
		sert.eq(_K.Data.bans["777011"], nil)
		sert.eq(getGroupsSpy.callCount + ownsPassSpy.callCount, 0)

		mRemote.Ban:Fire(777014, "nope", 0)
		world:run(1)
		sert.eq(_K.Data.bans["777014"], nil)
		sert.eq(getGroupsSpy.callCount + ownsPassSpy.callCount > 0, true)

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
		sert.eq(next(_K.Data.bans), nil)

		aRemote.Ban:Fire(2 ^ 53, "edge")
		world:run(1)
		sert.eq(world.scheduler.errors, {})
		sert.eq(_K.Data.bans["9007199254740992"] ~= nil, true)
		aRemote.Unban:Fire(2 ^ 53)
		world:run(1)
		sert.eq(_K.Data.bans["9007199254740992"], nil)

		-- Unban takes the same bound, a junk key saved before this check is left to ;unban
		_K.Data.bans["1e+300"] = { "Unknown", "junk", 0, 101 }
		_K.Data.bans["9007199254740994"] = { "Unknown", "junk", 0, 101 }
		aRemote.Unban:Fire(1e300)
		aRemote.Unban:Fire(2 ^ 53 + 2)
		world:run(1)
		sert.eq(_K.Data.bans["1e+300"] ~= nil, true)
		sert.eq(_K.Data.bans["9007199254740994"] ~= nil, true)
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
				fuzzWorld:run(0.5)
				if fuzzK.ChatCommands then
					fuzzK.ChatCommands.resync = function() end
				end
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
			world:run(0.1)

			sert.eq(world.scheduler.errors, {})
			sert.eq(next(_K.Data.bans), nil)
			sert.eq(_K.Data.playerPrefix[202], nil)

			-- Valid single-char prefix from guest is accepted
			gRemote.PlayerPrefix:Fire("!")
			-- Authorized superadmin client bans user 303 and updates dashboardRank
			aRemote.Ban:Fire(303, "legit ban", -1)
			aRemote.Settings:Fire({ dashboardRank = 2 })
			world:run(0.1)

			sert.eq(world.scheduler.errors, {})
			sert.eq(_K.Data.playerPrefix[202], "!")
			sert.eq(_K.Data.bans["303"] ~= nil, true)
			sert.eq(_K.Data.savedSettings.dashboardRank, 2)

			-- Authorized superadmin unbans user 303
			aRemote.Unban:Fire(303)
			world:run(2.1)
			sert.eq(_K.Data.bans["303"], nil)
		end,
		{ runs = 25 }
	)

	test(
		"Remote.Settings sanitizes announcement/notification Duration and rejects invalid UTF-8 or >1000-byte Text",
		function()
			local world = sert.sim.new({ backing = true, latency = { remotes = 0.02 } })
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
			sert.ok(not _K.Data.savedSettings.announcement)
			sert.eq(#(_K.Data.savedSettings.announcements or {}), 0)

			-- Single valid item with NaN Duration -> Duration becomes nil
			aRemote.Settings:Fire({
				announcements = {
					{ Text = "nan duration msg", Duration = 0 / 0 },
				},
			})
			world:run(1)
			sert.eq(#_K.Data.savedSettings.announcements, 1)
			sert.eq(_K.Data.savedSettings.announcements[1].Text, "nan duration msg")
			sert.eq(_K.Data.savedSettings.announcements[1].Duration, nil)

			-- Wait out broadcast cooldown (60s), then test math.huge Duration -> clamped to 600
			world:run(61)
			aRemote.Settings:Fire({
				notifications = {
					{ Text = "clamped duration msg", Duration = math.huge },
				},
			})
			world:run(1)
			sert.eq(#_K.Data.savedSettings.notifications, 1)
			sert.eq(_K.Data.savedSettings.notifications[1].Duration, 600)

			-- Wait out broadcast cooldown (60s), then test negative Duration -> clamped to 0
			world:run(61)
			aRemote.Settings:Fire({
				notifications = {
					{ Text = "clamped duration msg", Duration = 600, From = 101 },
					{ Text = "neg duration msg", Duration = -50 },
				},
			})
			world:run(1)
			sert.eq(_K.Data.savedSettings.notifications[#_K.Data.savedSettings.notifications].Duration, 0)
		end
	)

	test(
		"Remote.Command, Remote.PlayerPrefix, Remote.VIPUGCMethod, and Remote.EmoteType enforce rate limits and input validation",
		function()
			local world = sert.sim.new({ backing = true, latency = { remotes = 0.02 } })
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
			sert.eq(sawCooldown, true)
			sert.eq(_K.Process.onCooldown(_K, 202), true)
			world:run(4.5)
			sert.eq(_K.Process.onCooldown(_K, 202), false)

			-- 2. Remote.PlayerPrefix rate-limits rapid changes and cleans up on PlayerRemoving
			local resyncSpy = if _K.ChatCommands then sert.spy(_K.ChatCommands, "resync", function() end) else nil
			gRemote.PlayerPrefix:Fire("!")
			gRemote.PlayerPrefix:Fire("?")
			world:run(0.2)
			sert.eq(_K.Data.playerPrefix[202], "!")
			world:run(2.1)
			gRemote.PlayerPrefix:Fire("?")
			world:run(0.2)
			sert.eq(_K.Data.playerPrefix[202], "?")
			if resyncSpy then
				sert.eq(resyncSpy.callCount, 2)
			end

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
			sert.calledTimes(ownsAssetSpy, 0)
			sert.eq(char:FindFirstChild("SuperCrown"), nil)
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
			sert.eq(emotePayloads, 1)

			-- Leaving clears playerPrefix and commandLimits
			server:leave(srvGuest)
			world:run(0.2)
			sert.eq(_K.Data.playerPrefix[202], nil)
		end
	)

	test(
		"sert.laws.remote adversarial fuzzing of Ban, Unban, Settings, PlayerPrefix, Command, Explorer, Idled, and VIPUGCMethod",
		function()
			local world = sert.sim.new({ backing = true, latency = { remotes = 0.02 } })
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
				sert.eq(_K.Auth.getRank(plr.UserId), 0)
				sert.eq(_K.Auth.hasRestrictedRole(plr.UserId), false)
				sert.eq(_K.Auth.getRank(101) >= 4, true)
				sert.eq(_K.Data.bans["101"], nil)
				sert.eq(_K.Data.bans["500"] ~= nil, true)
				sert.eq(_K.Data.bans["500"][3], -1)
				sert.eq(_K.Data.savedSettings.dashboardRank, 1)
				sert.eq(#(_K.Data.savedSettings.freeAdmin or {}), 0)
				sert.eq(_K.script.Parent ~= nil, true)
				sert.eq(adminPlr.Character ~= nil and adminPlr.Character.Parent == sh.env.workspace, true)
			end

			-- 1. Remote.Ban from unprivileged guest
			sert.roblox.fuzzRemote("Remote.Ban (guest)", {
				runs = 40,
				maxArgs = 3,
				makePlayer = function()
					return guestPlr
				end,
				validGen = sert.gen.map(
					sert.gen.tuple({
						sert.gen.boundaryInt(-10, 1000),
						sert.gen.malformedString(),
						sert.gen.boundaryInt(-1, 86400),
					}),
					function(tup)
						tup._validTuple = true
						return tup
					end
				),
				handler = function(plr: any, userId: any, reason: any, duration: any)
					if type(userId) == "table" and rawget(userId, "_validTuple") then
						userId, reason, duration = userId[1], userId[2], userId[3]
					end
					invokeServerRemote(_K.Remote.Ban, plr, userId, reason, duration)
				end,
				checkState = function(plr: any)
					assertGuestInvariants(plr)
					for k in _K.Data.bans do
						sert.eq(k, "500")
					end
				end,
			})

			-- 2. Remote.Unban from unprivileged guest
			sert.roblox.fuzzRemote("Remote.Unban (guest)", {
				runs = 40,
				maxArgs = 1,
				makePlayer = function()
					return guestPlr
				end,
				validGen = sert.gen.oneOf({ sert.gen.constant(500), sert.gen.boundaryInt(-10, 1000) }),
				handler = function(plr: any, userId: any)
					invokeServerRemote(_K.Remote.Unban, plr, userId)
				end,
				checkState = assertGuestInvariants,
			})

			-- 3. Remote.Settings from unprivileged guest
			sert.roblox.fuzzRemote("Remote.Settings (guest)", {
				runs = 40,
				maxArgs = 1,
				makePlayer = function()
					return guestPlr
				end,
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
				handler = function(plr: any, changes: any)
					invokeServerRemote(_K.Remote.Settings, plr, changes)
				end,
				checkState = assertGuestInvariants,
			})

			-- 4. Remote.PlayerPrefix with malformed strings and adversarial payloads
			sert.roblox.fuzzRemote("Remote.PlayerPrefix (guest)", {
				runs = 40,
				maxArgs = 1,
				makePlayer = function()
					return guestPlr
				end,
				validGen = sert.gen.pick({ "!", "?", ";", ":", "/", "-" }),
				handler = function(plr: any, prefix: any)
					_K.Data.playerPrefix[plr.UserId] = nil
					invokeServerRemote(_K.Remote.PlayerPrefix, plr, prefix)
				end,
				checkState = function(plr: any)
					local p = _K.Data.playerPrefix[plr.UserId]
					if p ~= nil then
						sert.eq(type(p), "string")
						sert.eq(#p, 1)
						sert.eq(string.find(p, '[,"`@$%%*~%s]'), nil)
					end
					_K.Data.playerPrefix[plr.UserId] = nil
					assertGuestInvariants(plr)
				end,
			})

			-- 5. Remote.Command from unprivileged guest attempting privilege escalation & malformed command strings
			sert.roblox.fuzzRemote("Remote.Command (guest)", {
				runs = 40,
				maxArgs = 1,
				makePlayer = function()
					return guestPlr
				end,
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
				handler = function(plr: any, message: any)
					_K.Process.resetLimit(plr.UserId)
					invokeServerRemote(_K.Remote.Command, plr, message)
				end,
				checkState = assertGuestInvariants,
			})

			-- 6. Remote.Explorer from moderator attempting to delete/paste protected or higher-rank instances
			sert.roblox.fuzzRemote("Remote.Explorer (mod boundary)", {
				runs = 40,
				maxArgs = 3,
				makePlayer = function()
					return modPlr
				end,
				validGen = sert.gen.map(sert.gen.pick({ "DELETE", "PASTE", "UNKNOWN" }), function(action)
					return {
						_validTuple = true,
						action,
						{ _K.script, _K.Server, _K.Service.Players, adminPlr, adminPlr.Character },
						_K.script,
					}
				end),
				handler = function(plr: any, action: any, data: any, selected: any)
					if type(action) == "table" and rawget(action, "_validTuple") then
						action, data, selected = action[1], action[2], action[3]
					end
					invokeServerRemote(_K.Remote.Explorer, plr, action, data, selected)
				end,
				checkState = function()
					sert.eq(_K.script.Parent ~= nil, true)
					sert.eq(_K.Server.Parent ~= nil, true)
					sert.eq(adminPlr.Parent == _K.Service.Players, true)
					sert.eq(adminPlr.Character ~= nil and adminPlr.Character.Parent == sh.env.workspace, true)
				end,
			})

			-- 7. Remote.Ban & Remote.Unban from moderator (has ban/unban, lacks banasync) against saved ban 500 & higher-rank 101
			sert.roblox.fuzzRemote("Remote.Ban & Unban (mod without banasync)", {
				runs = 40,
				maxArgs = 3,
				makePlayer = function()
					return modPlr
				end,
				validGen = sert.gen.map(
					sert.gen.tuple({
						sert.gen.pick({ 101, 500, -1, 0 }),
						sert.gen.malformedString(),
						sert.gen.pick({ -1, 0, 60, 3600 }),
					}),
					function(tup)
						tup._validTuple = true
						return tup
					end
				),
				handler = function(plr: any, userId: any, reason: any, duration: any)
					if type(userId) == "table" and rawget(userId, "_validTuple") then
						userId, reason, duration = userId[1], userId[2], userId[3]
					end
					invokeServerRemote(_K.Remote.Ban, plr, userId, reason, duration)
					invokeServerRemote(_K.Remote.Unban, plr, userId)
				end,
				checkState = function(plr: any)
					-- Moderator without banasync cannot lift or downgrade saved ban 500, and cannot ban superadmin 101
					sert.eq(_K.Auth.getRank(plr.UserId), 2)
					sert.eq(_K.Data.bans["101"], nil)
					sert.eq(_K.Data.bans["500"] ~= nil, true)
					sert.eq(_K.Data.bans["500"][3], -1)
				end,
			})

			-- 8. Remote.Idled & Remote.VIPUGCMethod with adversarial payloads
			sert.roblox.fuzzRemote("Remote.Idled & Remote.VIPUGCMethod (guest)", {
				runs = 40,
				maxArgs = 4,
				makePlayer = function()
					return guestPlr
				end,
				validGen = sert.gen.map(
					sert.gen.tuple({
						sert.gen.boundaryFloat(-100, 1000),
						sert.gen.malformedString(),
						sert.gen.bool(),
						sert.gen.malformedString(),
					}),
					function(tup)
						tup._validTuple = true
						return tup
					end
				),
				handler = function(plr: any, a: any, b: any, c: any, d: any)
					if type(a) == "table" and rawget(a, "_validTuple") then
						a, b, c, d = a[1], a[2], a[3], a[4]
					end
					invokeServerRemote(_K.Remote.Idled, plr, a)
					invokeServerRemote(_K.Remote.VIPUGCMethod, plr, a, b, c, d)
				end,
				checkState = function(plr: any)
					local idle = plr:GetAttribute("_KIdleTime")
					if idle ~= nil then
						sert.eq(type(idle), "number")
						sert.eq(idle >= 0 and idle < math.huge, true)
					end
					assertGuestInvariants(plr)
				end,
			})
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
			local world = sert.sim.new({ backing = true, latency = { remotes = 0.02 } })
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
			setup = function()
				local sut = getOrCreateModelSut()
				local _K = sut._K
				sut.world:run(2.1)
				table.clear(_K.Data.bans)
				table.clear(_K.Data.playerPrefix)
				_K.Data.savedSettings.dashboardRank = 1
				_K.Data.savedSettings.chatCommands = true
				_K.Data.savedSettings.freeAdmin = {}
				for _, uid in ACTOR_IDS do
					_K.Process.resetLimit(uid)
					sut.players[uid]:SetAttribute("_KIdleTime", nil)
					sut.players[uid]:SetAttribute("_KPlayerPrefix", nil)
				end
				return sut
			end,
			init = function()
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
				}
			end,
			commands = {
				RemoteBan = {
					gen = function(_state, g)
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
					gen = function(_state, g)
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
					gen = function(_state, g)
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
					gen = function(_state, g)
						return {
							caller = g:pick(ACTOR_IDS),
							prefix = g:pick({ "", "!", "?", ":", "/", "-", ";", "@", "$", "ab" }),
						}
					end,
					run = function(sut, arg)
						sut.world:run(2.1)
						sut.remotes[arg.caller].PlayerPrefix:Fire(arg.prefix)
						sut.world:run(0.2)
					end,
					next = function(state, arg)
						local sut = getOrCreateModelSut()
						local _K = sut._K
						local valid = type(arg.prefix) == "string"
							and (
								arg.prefix == ""
								or (
									arg.prefix ~= "/"
									and #_K.Chat.commandPrefixes({ arg.prefix }) == 1
									and not table.find(RESERVED_PREFIXES, arg.prefix)
								)
							)
						if valid then
							local defaultPrefix = _K.Data.settings.prefix[1] or ";"
							state.prefixes[arg.caller] = if arg.prefix == "" or arg.prefix == defaultPrefix
								then nil
								else arg.prefix
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
					gen = function(_state, g)
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
					gen = function(_state, g)
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
					gen = function(_state, g)
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
			invariants = {
				noPrivilegeEscalation = function(state, sut)
					for uid, expectedRank in state.ranks do
						if sut._K.Auth.getRank(uid) ~= expectedRank then
							return false
						end
					end
					if #(sut._K.Data.savedSettings.freeAdmin or {}) > 0 then
						return false
					end
					return true
				end,
				noHigherOrEqualRankBanned = function(state, sut)
					for key, ban in sut._K.Data.bans do
						local targetId = tonumber(key)
						local bannerId = ban[4]
						if targetId and bannerId then
							local tRank = state.ranks[targetId] or 0
							local bRank = state.ranks[bannerId] or 0
							if tRank >= bRank then
								return false
							end
						end
					end
					return sut._K.Data.bans["204"] == nil
				end,
				noSessionModPersistedBan = function(state, sut)
					for key, ban in sut._K.Data.bans do
						if ban[4] == 202 and ban[3] ~= nil and ban[3] ~= 0 then
							return false
						end
						local ref = state.bans[key]
						if ref and ref.persisted and (ban[3] == nil or ban[3] == 0) then
							return false
						end
					end
					return true
				end,
				noUnauthorizedSettingsMutation = function(state, sut)
					local saved = sut._K.Data.savedSettings
					return not (
						state.unauthorizedSettingsMutated
						or saved.dashboardRank ~= state.settings.dashboardRank
						or saved.chatCommands ~= state.settings.chatCommands
					)
				end,
				noPrefixCrossContamination = function(state, sut)
					if state.prefixContaminated then
						return false
					end
					for _, uid in ACTOR_IDS do
						if sut._K.Data.playerPrefix[uid] ~= state.prefixes[uid] then
							return false
						end
					end
					return true
				end,
				modelMatchesSut = function(state, sut)
					sert.eq(sut.world.scheduler.errors, {})
					for _, uid in ACTOR_IDS do
						local key = tostring(uid)
						local actualBan = sut._K.Data.bans[key]
						local refBan = state.bans[key]
						if refBan == nil then
							sert.eq(actualBan, nil)
						else
							sert.eq(actualBan ~= nil, true)
							sert.eq(actualBan[4], refBan.by)
							local isPersisted = actualBan[3] ~= nil and actualBan[3] ~= 0
							sert.eq(isPersisted, refBan.persisted)
						end
						sert.eq(sut._K.Data.playerPrefix[uid], state.prefixes[uid])
						sert.eq(sut.players[uid]:GetAttribute("_KPlayerPrefix"), state.prefixes[uid])
						sert.eq(sut.players[uid]:GetAttribute("_KIdleTime"), state.idleTimes[uid])
					end
				end,
			},
		}, { runs = 25, length = 20 })
	end

	test(
		"sert.sim sliding-window rate limiting & broadcast cooldowns enforce per-sender and global bounds without starving normal traffic",
		function()
			local world = sert.sim.new({ backing = true, latency = { remotes = 0.02 } })
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
			sert.eq(_K.Process.onCooldown(_K, 201), true)
			sert.eq(_K.Process.onCooldown(_K, 202), false)
			sert.eq(_K.Process.onCooldown(_K, 203), false)

			-- At t = 0.7s: GuestB sends 2 normal commands, VIP sends 10 commands (within VIP limit of 16)
			world:run(0.5)
			rGuestB.Command:Fire(";version")
			rGuestB.Command:Fire(";version")
			for _ = 1, 10 do
				rVip.Command:Fire(";version")
			end
			world:run(0.2)
			sert.eq(_K.Process.onCooldown(_K, 201), true)
			sert.eq(_K.Process.onCooldown(_K, 202), false)
			sert.eq(_K.Process.onCooldown(_K, 203), false)

			-- At t = 2.0s: GuestB sends 2 more commands (reaching exact bound of 4 -> onCooldown becomes true)
			world:run(1.1)
			rGuestB.Command:Fire(";version")
			rGuestB.Command:Fire(";version")
			world:run(0.2)
			sert.eq(_K.Process.onCooldown(_K, 201), true)
			sert.eq(_K.Process.onCooldown(_K, 202), true)
			sert.eq(_K.Process.onCooldown(_K, 203), false)

			-- At t = 4.2s: GuestA's 4s window from t = 0 has slid/reset, while GuestB's 4s window from t = 0.7s is still active!
			world:run(2.0)
			sert.eq(_K.Process.onCooldown(_K, 201), false)
			sert.eq(_K.Process.onCooldown(_K, 202), true)

			-- Normal command from GuestA now succeeds again
			rGuestA.Command:Fire(";version")
			world:run(0.8)
			-- At t = 5.0s: GuestB's 4s window from t = 0.7s has now also expired
			sert.eq(_K.Process.onCooldown(_K, 202), false)

			-- 2. Chat.limitBroadcast & Remote.ChatSystem sliding 60s broadcast cooldown across concurrent senders
			-- AdminA (301) fires a burst of 4 broadcasts; only the 1st passes the 60s per-sender gate
			rAdminA.Command:Fire(";announce AdminA first broadcast")
			rAdminA.Command:Fire(";announce AdminA burst 2")
			rAdminA.Command:Fire(";announce AdminA burst 3")
			world:run(0.5)
			sert.eq(_K.Chat.limitBroadcast(301) ~= nil, true)
			sert.eq(_K.Chat.limitBroadcast(302), nil) -- consumes 302's slot when called directly; let's test via Chat.send next!

			-- Advance 10s: AdminA (301) is still cooling down (~50s left)
			world:run(10)
			local errA10 = _K.Chat.limitBroadcast(301)
			sert.eq(errA10 ~= nil and string.find(errA10, "Wait ", 1, true) ~= nil, true)

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
			sert.eq(#receivedByGuestA, countBefore + 1)
			sert.eq(receivedByGuestA[#receivedByGuestA].id, "fixed-guid-1")

			-- At +15s (still within 30s dedup window), duplicate packet is still ignored
			world:run(15)
			_K.Remote.ChatSystem:Fire(srvGuestA, "announce", "Deduplicated msg", 302, nil, "fixed-guid-1")
			world:run(0.5)
			sert.eq(#receivedByGuestA, countBefore + 1)

			-- At +16s (total 31.5s > 30s client dedup window), the ID is evicted and can be received again
			world:run(16)
			_K.Remote.ChatSystem:Fire(srvGuestA, "announce", "Deduplicated msg", 302, nil, "fixed-guid-1")
			world:run(0.5)
			sert.eq(#receivedByGuestA, countBefore + 2)

			-- Advance remaining 20s so both 301 and 302 cross their 60s broadcast cooldown window
			world:run(20)
			sert.eq(_K.Chat.limitBroadcast(301), nil)
			local msgId, sendErr = _K.Chat.send(
				{ from = 302, fromPlayer = srvAdminB },
				"announce",
				"AdminB broadcast after window",
				nil,
				{ "AdminB broadcast after window", 302, 5, "pin-guid-2" }
			)
			world:run(0.5)
			sert.eq(sendErr, nil)
			sert.eq(type(msgId), "string")
			sert.eq(receivedByGuestB[#receivedByGuestB].text, "AdminB broadcast after window")
			sert.eq(receivedByGuestB[#receivedByGuestB].from, 302)
			local _ = rAdminB
		end
	)

	test(
		"Remote.Once avoids false unlinked warnings, Server Remote.Fire ignores nil/non-Player, Settings preserves announcements on cooldown and allows 8 prefixes, and Explorer enforces PARENT/TextChatService/cap/rate-limit",
		function()
			-- 1. Client Remote.Once does NOT warn after 5s when unlinked, while Wait still warns
			do
				local hc = Harness.newEnv({ isStudio = false, isClient = true })
				hc:mockClientRemotes()
				local warnings = {}
				local origWarn = hc.env.globals.warn
				hc.env.globals.warn = function(...: any)
					table.insert(warnings, table.concat({ ... }, " "))
				end
				local cRemote = hc:requireRemote()
				cRemote.UnlinkedOnceTest:Once(function() end)
				hc.env:step(6)
				sert.eq(#warnings, 0)

				hc.env.task.spawn(function()
					cRemote.UnlinkedWaitTest:Wait()
				end)
				hc.env:step(6)
				sert.eq(#warnings, 1)
				sert.eq(string.find(warnings[1], "Infinite yield possible", 1, true) ~= nil, true)
				hc.env.globals.warn = origWarn
			end

			local world = sert.sim.new({ backing = true, latency = { remotes = 0.02 } })
			local server = world:server()
			local creatorClient = server:client(101)
			local guestClient = server:client(202)

			local sh = Harness.newPeerEnv(server, { isStudio = false })
			sh.env.game._props.CreatorId = 101
			local _K = sh:requireK()
			server:spawn(function()
				_K.initialize({
					bans = {},
					prefix = { ";" },
					vip = false,
					userRoles = { creator = { 101 } },
					roles = Harness.defaultRoles(),
				})
			end)
			world:run(1)

			-- 2. Server Remote:Fire(nil, ...) and non-Player Instance is a safe no-op
			_K.Remote.Notify:Fire(nil :: any, { Text = "global no-player" })
			_K.Remote.Notify:Fire(sh.env.workspace :: any, { Text = "not a player" })
			sert.eq(world.scheduler.errors, {})

			local creatorEnv = Harness.newPeerEnv(creatorClient, { isClient = true })
			local guestEnv = Harness.newPeerEnv(guestClient, { isClient = true })
			local cRemote = creatorEnv:requireRemote()
			local gRemote = guestEnv:requireRemote()
			world:run(0.5)

			-- 3. Remote.PlayerPrefix rejects caller when caller has 0 usable and 0 VIP-purchasable commands
			local origEveryoneGroups = _K.Data.roles.everyone.groups
			_K.Data.roles.everyone.groups = {}
			gRemote.PlayerPrefix:Fire("!")
			world:run(0.3)
			sert.eq(_K.Data.playerPrefix[202], nil)
			_K.Data.roles.everyone.groups = origEveryoneGroups

			-- 4. Remote.Settings allows developer/creator up to 8 prefixes, rejects 9, sanitizes richText, and preserves announcements when rate-limited
			local eightPrefixes = { ";", ":", "!", "?", "/", "-", "+", "=" }
			cRemote.Settings:Fire({ prefix = eightPrefixes })
			world:run(0.3)
			sert.eq(_K.Data.savedSettings.prefix, eightPrefixes)

			cRemote.Settings:Fire({ prefix = { ";", ":", "!", "?", "/", "-", "+", "=", "&" } })
			world:run(0.3)
			sert.eq(_K.Data.savedSettings.prefix, eightPrefixes)

			-- First announcement with valid & invalid rich text: <b> + spaced rgb() restored, <font face="Gotham"> escaped
			cRemote.Settings:Fire({
				announcements = {
					{
						Text = '<b><font color="rgb(255, 165, 0)">Hello</font> <font face="Gotham">World</font></b>',
						Duration = 30,
					},
				},
			})
			world:run(0.5)
			sert.eq(#_K.Data.savedSettings.announcements, 1)
			sert.eq(
				_K.Data.savedSettings.announcements[1].Text,
				'<b><font color="rgb(255,165,0)">Hello</font> &lt;font face=&quot;Gotham&quot;&gt;World&lt;/font&gt;</b>'
			)

			-- Rate-limited edit right afterward (within 60s broadcast cooldown) MUST NOT wipe savedSettings.announcements to {}!
			cRemote.Settings:Fire({
				announcements = {
					{ Text = "Replacement while cooling down", Duration = 15 },
				},
			})
			world:run(0.5)
			sert.eq(#_K.Data.savedSettings.announcements, 1)
			sert.eq(string.find(_K.Data.savedSettings.announcements[1].Text, "Hello", 1, true) ~= nil, true)

			-- 5. Remote.Explorer protects TextChatService, supports PARENT, caps batch at 64, and rate-limits at 15/sec
			local function toCli(inst: any): any
				return creatorEnv.env._mirrorOf[inst] or inst
			end
			local tcs = sh.env.game:GetService("TextChatService")
			local customCmd = sh.env.Instance.new("TextChatCommand", tcs)
			customCmd.Name = "ProtectedGameCmd"
			world:run(0.05)
			cRemote.Explorer:Fire("DELETE", { toCli(customCmd), toCli(tcs) })
			world:run(0.3)
			sert.eq(customCmd.Parent, tcs)

			local destFolder = sh.env.Instance.new("Folder", sh.env.workspace)
			destFolder.Name = "ReparentDest"
			local childFolder = sh.env.Instance.new("Folder", destFolder)
			childFolder.Name = "ChildInsideDest"
			local movablePart = sh.env.Instance.new("Part", sh.env.workspace)
			local srvGuest = sh.env.Players:GetPlayerByUserId(202)
			world:run(0.05)

			-- PARENT moves movablePart into destFolder, while ignoring Player, selected itself, ancestor of selected, and protected instances
			cRemote.Explorer:Fire(
				"PARENT",
				{ toCli(movablePart), toCli(srvGuest), toCli(destFolder), toCli(sh.env.workspace), toCli(customCmd) },
				toCli(childFolder)
			)
			world:run(0.3)
			sert.eq(movablePart.Parent, childFolder)
			sert.eq(destFolder.Parent, sh.env.workspace)
			sert.eq(customCmd.Parent, tcs)

			-- 64-item cap: deleting 70 parts in one Explorer call deletes at most 64
			local parts70 = {}
			for i = 1, 70 do
				local p = sh.env.Instance.new("Part", sh.env.workspace)
				p.Name = `BulkPart_{i}`
				parts70[i] = p
			end
			world:run(0.05)
			local cliParts70 = {}
			for i = 1, 70 do
				cliParts70[i] = toCli(parts70[i])
			end
			cRemote.Explorer:Fire("DELETE", cliParts70)
			world:run(0.3)
			local remaining = 0
			for i = 1, 70 do
				if parts70[i].Parent ~= nil then
					remaining += 1
				end
			end
			sert.eq(remaining, 6)

			-- 15 calls/sec rate limit: Wait for clean 1s window, then fire 20 single-part deletes; only first 15 execute
			world:run(1.1)
			local burstParts = {}
			for i = 1, 20 do
				burstParts[i] = sh.env.Instance.new("Part", sh.env.workspace)
			end
			world:run(0.05)
			for i = 1, 20 do
				cRemote.Explorer:Fire("DELETE", { toCli(burstParts[i]) })
			end
			world:run(0.3)
			local burstRemaining = 0
			for i = 1, 20 do
				if burstParts[i].Parent ~= nil then
					burstRemaining += 1
				end
			end
			sert.eq(burstRemaining, 5)
		end
	)
end)

do
	return {}
end
