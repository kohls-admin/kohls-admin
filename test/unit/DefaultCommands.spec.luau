--!nocheck
local CommandHarness = require("./CommandHarness")
local Harness = require("./Harness")
local sert = require("../sert")

local describe, test = sert.describe, sert.test

local _globals = Harness.globals
local CFrame = _globals.CFrame
local Color3 = _globals.Color3
local Vector3 = _globals.Vector3
local Enum = _globals.Enum

local buildCharacter = CommandHarness.buildCharacter
local createSimCluster = CommandHarness.createSimCluster

describe("DefaultCommands", function()
	test(
		"registers all default command modules and executes Administration, Creator, Environment, and SuperAdmin commands",
		function()
			local c = createSimCluster()
			local _K, clientK, srvP1, srvP2 = c._K, c.clientK, c.srvP1, c.srvP2
			local runSrv, runCli = c.runSrv, c.runCli

			local notifications: { { plr: any, msg: any } } = {}
			local origNotifyFire = _K.Remote.Notify.Fire
			_K.Remote.Notify.Fire = function(self: any, plr: any, msg: any)
				table.insert(notifications, { plr = plr, msg = msg })
				return origNotifyFire(self, plr, msg)
			end

			-- === Administration.luau ===
			sert.eq(
				_K.Registry.commands.announce.run({ _K = _K, from = 1, fromPlayer = srvP1, global = true }, "GlobalMsg"),
				"Announcements are disabled in private servers."
			)
			_K.Data.SEPARATE_DATASTORE = true
			sert.eq(
				_K.Registry.commands.announce.run({ _K = _K, from = 1, fromPlayer = srvP1, global = false }, "PrivMsg"),
				"Announcements are disabled in private servers."
			)
			_K.Data.SEPARATE_DATASTORE = false

			local announceArg = { redactLog = true }
			local origPublishTopic = _K.Data.publishTopic
			local publishedTopics = {}
			_K.Data.publishTopic = function(topic: string, data: any)
				table.insert(publishedTopics, { topic = topic, data = data })
				return true
			end
			_K.Registry.commands.announce.run(
				{ _K = _K, from = 1, fromPlayer = srvP1, args = { announceArg } },
				"DirectAnnounce"
			)
			sert.eq(announceArg.redactLog, false)
			sert.eq(_K.Data.savedSettings.announcement[1], "DirectAnnounce")
			sert.eq(#publishedTopics, 1)
			sert.eq(publishedTopics[1].topic, "announce")
			_K.Registry.commands.unannounce.run({ _K = _K, from = 1, fromPlayer = srvP1 })
			sert.eq(_K.Data.savedSettings.announcement, false)
			sert.eq(_K.Data._skipNextAnnounceSync, _K.Data.REMOVE)
			sert.eq(#publishedTopics, 2)
			sert.eq(publishedTopics[2].topic, "announce")
			_K.Data.publishTopic = origPublishTopic
			c.world:fastForward(61)

			runSrv(";announce Hello world")
			-- { text, from, duration, id }, the id tells a repeated announcement apart from a settings sync
			local pinned = _K.Data.savedSettings.announcement
			sert.eq({ pinned[1], pinned[2], pinned[3] }, { "Hello world", 1, 0 })
			sert.eq(type(pinned[4]), "string")
			sert.eq(_K.Data.Sync.settings.announcement, pinned)
			-- Advance past 60s broadcast cooldown so subsequent announce/chat/global calls succeed
			c.world:fastForward(61)
			runSrv(";unannounce")
			sert.eq(_K.Data.savedSettings.announcement, false)
			sert.eq(_K.Data.Sync.settings.announcement, _K.Data.REMOVE)

			table.clear(notifications)
			runSrv(";role TargetPlr vip")
			sert.eq(_K.Auth.hasRole(2, "vip"), true)
			sert.eq(#notifications >= 1, true)
			sert.eq(notifications[1].plr, srvP2)
			sert.eq(string.find(notifications[1].msg.Text, "Gave you the", 1, true) ~= nil, true)

			-- Re-giving the same role exercises "already has role" branch (no duplicate target notification)
			table.clear(notifications)
			runSrv(";role TargetPlr vip")
			local gaveTargetAgain = false
			for _, n in notifications do
				if n.plr == srvP2 then
					gaveTargetAgain = true
				end
			end
			sert.eq(gaveTargetAgain, false)

			table.clear(notifications)
			runSrv(";temprole TargetPlr mod")
			sert.eq(_K.Auth.hasRole(2, "mod"), true)
			sert.eq(#notifications >= 1, true)
			sert.eq(notifications[1].plr, srvP2)

			table.clear(notifications)
			runSrv(";unrole TargetPlr mod")
			sert.eq(_K.Auth.hasRole(2, "mod"), false)
			sert.eq(#notifications >= 1, true)
			sert.eq(string.find(notifications[1].msg.Text, "TargetPlr", 1, true) ~= nil, true)

			table.clear(notifications)
			runSrv(";removemember TargetPlr")
			sert.eq(_K.Data.members["2"], nil)
			sert.eq(_K.Data.Sync.members["2"], _K.Data.REMOVE)
			sert.eq(#notifications, 1)
			sert.eq(string.find(notifications[1].msg.Text, "TargetPlr", 1, true) ~= nil, true)

			-- Removing a non-member exercises "not a member" guard branch (no notification sent)
			table.clear(notifications)
			_K.Registry.commands.removemember.run({ _K = _K, from = 1, fromPlayer = srvP1 }, { "2" })
			sert.eq(#notifications, 0)

			runSrv(";gear TargetPlr 12345")
			sert.ok((srvP2.Backpack:FindFirstChild("Tool12345")))
			local savedBp = srvP2.Backpack
			savedBp.Parent = nil
			runSrv(";gear TargetPlr 12345")
			sert.ok((srvP2.Character:FindFirstChild("Tool12345")))
			savedBp.Parent = srvP2
			-- Authorized error & generic error branches in gear
			runSrv(";gear TargetPlr 999998")
			runSrv(";gear TargetPlr 999997")

			runSrv(";insert 12345")
			sert.eq(#_K.cleanupCommands > 0, true)
			sert.eq(_K.cleanupCommands[1].Parent, c.sh.env.workspace)
			-- Test blocked insert asset id, packageRef path, and authorized/generic error paths
			local insertCtx = { _K = _K, from = 1, fromPlayer = srvP1, env = _K.Registry.commands.insert.env }
			sert.eq(_K.Registry.commands.insert.run(insertCtx, 59524079), "Model has been blocked.")
			sert.eq(_K.Registry.commands.insert.run(insertCtx, 999999), "Model has been blocked.")
			local errAuth = _K.Registry.commands.insert.run(insertCtx, 999998)
			sert.eq(string.find(tostring(errAuth), "Game Creator's inventory!", 1, true) ~= nil, true)
			local errGen = _K.Registry.commands.insert.run(insertCtx, 999997)
			sert.eq(string.find(tostring(errGen), "Generic insert failure", 1, true) ~= nil, true)
			sert.eq(#_K.cleanupCommands, 1)

			local prevTeleports = #c.sh.env.teleports
			runSrv(";place TargetPlr 100")
			sert.eq(#c.sh.env.teleports > prevTeleports, true)

			runSrv(";serverlock")
			sert.eq(_K._serverLock, "CreatorPlr")
			-- Calling serverlock again exercises "already locked" guard branch
			runSrv(";serverlock")
			sert.eq(_K._serverLock, "CreatorPlr")

			runSrv(";unserverlock")
			sert.eq(_K._serverLock, nil)

			-- === Creator.luau ===
			runSrv(";hidelogs")
			sert.eq(_K.Data.logsHidden[1], true)
			runSrv(";unhidelogs")
			sert.ok(not _K.Data.logsHidden[1])
			-- Verify clearlogs envClient preserves client logs (log[6] == true) and refreshes dashboard.Logs
			local clientLogKept = { "client log", 0, 1, 1, "CreatorPlr", true }
			local serverLogCleared = { "server log", 0, 2, 1, "CreatorPlr" }
			clientK.Data.logs = { clientLogKept, serverLogCleared }
			local logsDashboardRefreshed = 0
			local origUpdateList = clientK.client.dashboard.Logs.updateList
			clientK.client.dashboard.Logs.updateList = function(self: any, ...: any)
				logsDashboardRefreshed += 1
				if origUpdateList then
					return origUpdateList(self, ...)
				end
			end
			_K.Remote.ClearLogs:Fire(srvP1)
			c.world:run(0.05)
			clientK.client.dashboard.Logs.updateList = origUpdateList
			sert.eq(#clientK.Data.logs, 1)
			sert.eq(clientK.Data.logs[1], clientLogKept)
			sert.eq(logsDashboardRefreshed, 1)

			local removedLogKeys = {}
			local origRemoveAsync = _K.Data.Store.removeAsync
			_K.Data.Store.removeAsync = function(key: string)
				table.insert(removedLogKeys, key)
				return true
			end
			table.insert(_K.Data.pendingLogReveals, { log = { "pending" }, targets = {} })
			local prevLogsVersion = _K.Data.logsVersion
			_K.Registry.commands.clearlogs.run({
				_K = _K,
				from = 1,
				fromPlayer = srvP1,
				env = _K.Registry.commands.clearlogs.env,
			})
			c.world:run(0.05)
			sert.eq(#_K.Data.logs, 0)
			sert.eq(#_K.Data.pendingLogReveals, 0)
			sert.eq(_K.Data.logsVersion > prevLogsVersion, true)
			sert.eq(#removedLogKeys, 4)

			table.clear(removedLogKeys)
			_K.Data.SEPARATE_DATASTORE = true
			table.insert(_K.Data.logs, { "priv_log", 0, 1, 1, "CreatorPlr" })
			_K.Registry.commands.clearlogs.run({
				_K = _K,
				from = 1,
				fromPlayer = srvP1,
				env = _K.Registry.commands.clearlogs.env,
			})
			c.world:run(0.05)
			sert.eq(#_K.Data.logs, 0)
			sert.eq(#removedLogKeys, 0)
			_K.Data.SEPARATE_DATASTORE = false
			_K.Data.Store.removeAsync = origRemoveAsync

			-- Verify ;global unannounce does not queue a local REMOVE sync and Settings UI edit is not suppressed by _skipNextAnnounceSync
			runSrv(";announce LocalPinned")
			local pinnedBeforeGlobalUnannounce = _K.Data.savedSettings.announcement
			sert.eq(pinnedBeforeGlobalUnannounce[1], "LocalPinned")
			sert.eq(_K.Data._skipNextAnnounceSync, pinnedBeforeGlobalUnannounce)
			-- Simulate a different announcement value modified before processSync runs
			local editedAnnouncement = { "EditedViaSettings", 1, 0, "edited_id" }
			_K.Data.Sync.settings.announcement = editedAnnouncement
			sert.eq(_K.Data._skipNextAnnounceSync ~= _K.Data.Sync.settings.announcement, true)
			-- Running ;global unannounce publishes to MessagingService without queuing REMOVE in local Sync.settings
			_K.Registry.commands.unannounce.run({ _K = _K, from = 1, fromPlayer = srvP1, global = true })
			sert.eq(_K.Data.Sync.settings.announcement, editedAnnouncement)
			_K.Registry.commands.unannounce.run({ _K = _K, from = 1, fromPlayer = srvP1, global = false })
			sert.eq(_K.Data.Sync.settings.announcement, _K.Data.REMOVE)
			local prevCleanupCount = #_K.cleanupCommands
			runSrv(";script local x = 1 + 1")
			sert.eq(#_K.cleanupCommands, prevCleanupCount + 1)
			runSrv(";localscript CreatorPlr local y = 2 + 2")
			sert.ok((srvP1:FindFirstChildOfClass("PlayerGui"):FindFirstChild("local y = 2 + 2")))

			-- === Environment.luau ===
			local lighting = c.sh.env.game:GetService("Lighting")
			local terrain = c.sh.env.workspace.Terrain
			local atmosphere = lighting:FindFirstChildOfClass("Atmosphere")
			runSrv(";ambient 255,0,0")
			sert.eq(lighting.Ambient, Color3.fromRGB(255, 0, 0))
			runSrv(";outdoorambient 0,255,0")
			sert.eq(lighting.OutdoorAmbient, Color3.fromRGB(0, 255, 0))
			runSrv(";atmosphere 0.5 0.1 255,255,255 10,20,30 0.2 0.3")
			sert.eq(atmosphere.Density, 0.5)
			sert.eq(atmosphere.Offset, 0.1)
			sert.eq(atmosphere.Color, Color3.fromRGB(255, 255, 255))
			sert.eq(atmosphere.Decay, Color3.fromRGB(10, 20, 30))
			sert.eq(atmosphere.Glare, 0.2)
			sert.eq(atmosphere.Haze, 0.3)
			runSrv(";fogcolor 100,100,100")
			sert.eq(lighting.FogColor, Color3.fromRGB(100, 100, 100))
			sert.eq(atmosphere.Color, Color3.fromRGB(100, 100, 100))
			sert.eq(atmosphere.Haze >= 2 ^ -32, true)
			runSrv(";fogstart 10")
			sert.eq(lighting.FogStart, 10)
			sert.eq(math.abs(atmosphere.Density - (64 / 10) ^ 0.25) < 1e-4, true)
			sert.eq(math.abs(atmosphere.Haze - 5 / 10 ^ 0.1) < 1e-4, true)
			runSrv(";fogend 500")
			sert.eq(lighting.FogEnd, 500)
			sert.eq(math.abs(atmosphere.Density - (64 / 500) ^ 0.25) < 1e-4, true)
			sert.eq(math.abs(atmosphere.Haze - 5 / 500 ^ 0.1) < 1e-4, true)
			runSrv(";brightness 3")
			sert.eq(lighting.Brightness, 3)
			runSrv(";colorshift 255,0,0 0,0,255")
			sert.eq(lighting.ColorShift_Bottom, Color3.fromRGB(255, 0, 0))
			sert.eq(lighting.ColorShift_Top, Color3.fromRGB(0, 0, 255))
			runSrv(";diffusescale 0.5")
			sert.eq(lighting.EnvironmentDiffuseScale, 0.5)
			runSrv(";specularscale 0.5")
			sert.eq(lighting.EnvironmentSpecularScale, 0.5)
			runSrv(";exposure 1.5")
			sert.eq(lighting.ExposureCompensation, 1.5)
			runSrv(";time 6")
			sert.eq(lighting.ClockTime, 6)
			runSrv(";time 12:30:36")
			sert.eq(math.abs(lighting.ClockTime - (12 + 30 / 60 + 36 / 3600)) < 1e-4, true)
			runSrv(";time 12 0.01")
			c.sh.env:advance(0.05)
			sert.eq(lighting.ClockTime, 12)
			runSrv(";latitude 45")
			sert.eq(lighting.GeographicLatitude, 45)
			runSrv(";latitude")
			sert.eq(lighting.GeographicLatitude, _K.Registry.commands.latitude.env.defaultLatitude)
			runSrv(";shadows false")
			sert.eq(lighting.GlobalShadows, false)
			runSrv(";skybox 1 2 3 4 5 6")
			local sky = lighting:FindFirstChild("_KSky")
			sert.ok(sky)
			sert.ok(sky.SkyboxDn)
			sert.eq(sky.SkyboxBk ~= sky.SkyboxDn, true)
			sert.eq(sky.SkyboxLf ~= sky.SkyboxDn, true)
			sert.eq(sky.SkyboxUp ~= sky.SkyboxDn, true)
			sert.eq(sky.SkyboxFt ~= sky.SkyboxDn, true)
			sert.eq(sky.SkyboxRt ~= sky.SkyboxDn, true)
			runSrv(";skybox 7")
			sert.eq(sky.SkyboxBk, sky.SkyboxDn)
			sert.eq(sky.SkyboxLf, sky.SkyboxDn)
			sert.eq(sky.SkyboxUp, sky.SkyboxDn)
			sert.eq(sky.SkyboxFt, sky.SkyboxDn)
			sert.eq(sky.SkyboxRt, sky.SkyboxDn)
			runSrv(";unskybox")
			sert.eq(lighting:FindFirstChild("_KSky"), nil)
			runSrv(";airdensity 0.05")
			sert.eq(c.sh.env.workspace.AirDensity, 0.05)
			runSrv(";gravity 100")
			sert.eq(c.sh.env.workspace.Gravity, 100)
			runSrv(";gravity")
			sert.eq(c.sh.env.workspace.Gravity, _K.Registry.commands.gravity.env.gravity)
			runSrv(";windspeed 20")
			sert.eq(math.round(c.sh.env.workspace.GlobalWind.Magnitude), 20)
			local windDirThread = c.sh.env.task.spawn(function()
				runSrv(";winddir")
			end)
			c.world:run(0.05)
			_K.Remote.SpectateSubject:Fire(srvP1, CFrame.new(0, 0, -1))
			c.world:run(0.05)
			c.sh.env.task.cancel(windDirThread)
			sert.eq(math.round(c.sh.env.workspace.GlobalWind.Magnitude), 20)
			runSrv(";watercolor 0,100,200")
			sert.eq(terrain.WaterColor, Color3.fromRGB(0, 100, 200))
			runSrv(";waterreflectance 0.5")
			sert.eq(terrain.WaterReflectance, 0.5)
			runSrv(";watertransparency 0.5")
			sert.eq(terrain.WaterTransparency, 0.5)
			runSrv(";watersize 0.2")
			sert.eq(terrain.WaterWaveSize, 0.2)
			runSrv(";waterspeed 15")
			sert.eq(terrain.WaterWaveSpeed, 15)
			runSrv(";fix")
			sert.eq(c.sh.env.workspace.Gravity, 196.2)
			sert.eq(lighting.Brightness, _K.Registry.commands.fix.env[lighting].Brightness)

			-- === SuperAdmin.luau ===
			-- the sert BadgeService double predates AwardBadgeAsync
			local badgeService = _K.Service.Badge
			local function awardToEnv(_self, userId, badgeId)
				local badges = c.sh.env.badges
				badges[userId] = badges[userId] or {}
				badges[userId][badgeId] = true
				return true
			end
			badgeService.AwardBadgeAsync = awardToEnv
			local function runBadge(badgeId)
				local res = nil
				c.sh.env.task.spawn(function()
					res = _K.Registry.commands.badge.run({ _K = _K, fromPlayer = srvP1 }, { srvP2 }, badgeId)
				end)
				c.world:fastForward(20)
				return tostring(res)
			end
			local function has(text, needle)
				return string.find(text, needle, 1, true) ~= nil
			end

			runSrv(";badge TargetPlr 555")
			sert.eq(c.sh.env.badges[2][555], true)
			-- Second award counts as already owned, not a failure
			sert.eq(runBadge(555), "nil")
			sert.eq(c.sh.env.badges[2][555], true)
			-- AwardBadgeAsync erroring every retry reports the error
			badgeService.AwardBadgeAsync = function()
				error("BadgeAPIError")
			end
			local badgeErrRes = runBadge(999)
			sert.eq(has(badgeErrRes, "failed 1"), true)
			sert.eq(has(badgeErrRes, "BadgeAPIError"), true)
			-- AwardBadgeAsync returning false (e.g. badge from another experience) is a failure, not a success
			badgeService.AwardBadgeAsync = function()
				return false
			end
			local declinedRes = runBadge(998)
			sert.eq(has(declinedRes, "Roblox declined"), true)
			sert.eq(c.sh.env.badges[2][998], nil)
			badgeService.AwardBadgeAsync = awardToEnv
			-- disabled badge fails fast without awarding
			local origGetBadgeInfo = badgeService.GetBadgeInfoAsync
			badgeService.GetBadgeInfoAsync = function(_self, badgeId)
				return { Name = `Badge{badgeId}`, IsEnabled = false }
			end
			sert.eq(has(runBadge(997), "is disabled"), true)
			sert.eq(c.sh.env.badges[2][997], nil)
			-- missing badge info reports the lookup failure
			badgeService.GetBadgeInfoAsync = function()
				error("BadgeNotFound")
			end
			local missingRes = runBadge(996)
			sert.eq(has(missingRes, "Couldn't load badge 996"), true)
			sert.eq(has(missingRes, "BadgeNotFound"), true)
			badgeService.GetBadgeInfoAsync = origGetBadgeInfo

			-- btools
			local btoolMock = c.sh.env.Instance.new("Tool")
			btoolMock.Name = "Building Tools"
			_K.Registry.commands.btools.env.tool = btoolMock
			runSrv(";btools TargetPlr")
			sert.ok((srvP2.Backpack:FindFirstChild("Building Tools")))
			-- Second btools run skips duplicating when "Building Tools" is already in Backpack
			runSrv(";btools TargetPlr")
			local btoolCount = 0
			for _, child in srvP2.Backpack:GetChildren() do
				if child.Name == "Building Tools" then
					btoolCount += 1
				end
			end
			sert.eq(btoolCount, 1)

			c.world:fastForward(61)
			runCli(";chat")
			c.world:run(0.05)
			sert.eq(
				string.find(tostring(clientK._lastNotify and clientK._lastNotify.Text), "disabled", 1, true) ~= nil,
				true
			)

			runSrv(";clearterrain")
			sert.eq(c.sh.env.workspace.Terrain._props._cleared, true)

			runCli(";explorer")
			sert.eq(clientK._explorerShown, true)

			local incogSrvEnv = _K.Registry.commands.incognito.env
			local incogFired = {}
			local origIncogFireAll = incogSrvEnv.remote.FireAll
			incogSrvEnv.remote.FireAll = function(self, ...)
				table.insert(incogFired, { ... })
				return origIncogFireAll(self, ...)
			end
			runSrv(";incognito TargetPlr false")
			sert.eq(incogSrvEnv.hidden[srvP2], false)
			sert.eq(incogFired[#incogFired][1], srvP2.UserId)
			sert.eq(incogFired[#incogFired][3], false)
			runSrv(";incognito TargetPlr true")
			sert.eq(incogSrvEnv.hidden[srvP2], true)
			sert.eq(incogFired[#incogFired][1], srvP2.Name)
			sert.eq(incogFired[#incogFired][3], true)
			incogSrvEnv.remote.FireAll = origIncogFireAll
			c.world:run(0.05)
			runCli(";incognitolist")
			local incogEnv = clientK.Registry.commands.incognitolist.env
			sert.eq(incogEnv.window._instance.Visible, true)
			if incogEnv.scroller and incogEnv.scroller.CreateItem then
				local item = incogEnv.scroller:CreateItem()
				incogEnv.scroller:RenderItem(item, 2)
				sert.ok(item)
			end
			-- Toggle window visibility false to exercise close handler
			incogEnv.window._instance.Visible = false

			table.clear(notifications)
			local ensuredServersCount = 0
			local origEnsureServers = _K.Data.ensureServersLoaded
			_K.Data.ensureServersLoaded = function(...)
				ensuredServersCount += 1
				return origEnsureServers(...)
			end
			local publishedReserve = {}
			local origPublish = _K.Data.publishTopic
			_K.Data.publishTopic = function(topic, payload)
				if topic == "reserve" then
					table.insert(publishedReserve, payload)
				end
				return origPublish(topic, payload)
			end
			runSrv(";reserve TestServer")
			sert.eq(ensuredServersCount, 1)
			sert.ok(_K.Data.reservedServers["TestServer"])
			sert.eq(#publishedReserve, 1)
			sert.eq(type(publishedReserve[1]), "table")
			sert.eq(publishedReserve[1][1], "TestServer")
			sert.eq(#notifications >= 1, true)
			sert.eq(string.find(notifications[#notifications].msg.Text, "has been reserved", 1, true) ~= nil, true)
			-- Re-reserving same server code returns already-reserved message
			local dupRes = _K.Registry.commands.reserve.run(
				{ _K = _K, from = srvP1.UserId, fromPlayer = srvP1, args = { {} } },
				"TestServer"
			)
			sert.eq(string.find(tostring(dupRes), "already reserved", 1, true) ~= nil, true)

			local tpBefore = #c.sh.env.teleports
			runSrv(";place TargetPlr @TestServer")
			sert.eq(#c.sh.env.teleports, tpBefore + 1)
			sert.eq(
				c.sh.env.teleports[#c.sh.env.teleports].options.ReservedServerAccessCode,
				_K.Data.reservedServers["TestServer"][2]
			)

			table.clear(notifications)
			local beforeUnreserveEnsure = ensuredServersCount
			runSrv(";unreserve TestServer")
			sert.eq(ensuredServersCount > beforeUnreserveEnsure, true)
			sert.eq(_K.Data.reservedServers["TestServer"], nil)
			sert.eq(#publishedReserve, 2)
			sert.eq(publishedReserve[2], "TestServer")
			sert.eq(#notifications >= 1, true)
			sert.eq(string.find(notifications[#notifications].msg.Text, "has been removed", 1, true) ~= nil, true)
			_K.Data.ensureServersLoaded = origEnsureServers
			_K.Data.publishTopic = origPublish

			c.world:fastForward(61)
			runSrv(";global announce GlobalTest")
			runSrv(";global gravity 80")
			c.world:run(0.1)
			sert.eq(c.sh.env.workspace.Gravity, 80)
			local sawTimeLog, sawGlobalLog = false, false
			for _, logEntry in _K.Data.logs do
				local text = tostring(logEntry[1])
				if text == ";time 12:30:36" then
					sawTimeLog = true
				elseif string.find(text, ';global ;announce "GlobalTest"', 1, true) then
					sawGlobalLog = true
				end
			end
			sert.eq(sawTimeLog, true)
			sert.eq(sawGlobalLog, true)
			-- Test Shutdown server cancellation branch and countdown > 0
			local announceCount = 0
			local origAnnounceFireAll = _K.Remote.Announce.FireAll
			_K.Remote.Announce.FireAll = function(self, ...)
				announceCount += 1
				return origAnnounceFireAll(self, ...)
			end
			local shutThread = c.sh.env.task.spawn(function()
				runSrv(";shutdown 2 Maintenance soon")
			end)
			c.world:run(0.05)
			sert.eq(announceCount, 1)
			runSrv(";shutdown") -- cancel active shutdown (no delay -> no Announce:FireAll)
			sert.eq(announceCount, 1)
			c.sh.env.task.cancel(shutThread)
			_K.Remote.Announce.FireAll = origAnnounceFireAll
			-- Trigger client Shutdown remote listener
			_K.Remote.Shutdown:Fire(srvP1, 2, "CreatorPlr", "Test reason")
			_K.Remote.Shutdown:Fire(srvP1, nil)
			c.world:run(0.05)

			c.world:fastForward(61)
			runSrv(";shutdown 0 Server maintenance")
			c.world:run(0.05)
			sert.eq(string.find(tostring(srvP2._props._kicked), "has shutdown the server.", 1, true) ~= nil, true)
			sert.eq(string.find(tostring(srvP2._props._kicked), "Reason: Server maintenance", 1, true) ~= nil, true)
			-- Direct shutdown with nil fromPlayer falls back to tostring(context.from) and updates args[2].parsedArgs
			local shutArg2: any = {}
			_K.Registry.commands.shutdown.run(
				{ _K = _K, from = 77777, fromPlayer = nil, args = { {}, shutArg2 } },
				nil,
				"OfflineReason"
			)
			sert.eq(shutArg2.parsedArgs, { "OfflineReason" })
			sert.eq(shutArg2.filtered, true)
			sert.eq(shutArg2.redactLog, false)
			sert.eq(string.find(tostring(srvP2._props._kicked), "77777 has shutdown the server.", 1, true) ~= nil, true)
		end
	)

	test("executes General and Utility commands on server and client", function()
		local c = createSimCluster()
		local _K, clientK, srvP1, srvP2 = c._K, c.clientK, c.srvP1, c.srvP2
		local runSrv, runCli = c.runSrv, c.runCli

		c.sh.env.groups[100] = {
			Name = "TestGroup",
			ranks = { [1] = 255, [2] = 50 },
		}
		c.ch1.env.groups[100] = c.sh.env.groups[100]

		-- Populate clientK.Data.emotes so emotes scroller has items to filter/render
		clientK.Data.emotes = {
			["507771019"] = "Dance1",
			["507771955"] = "Dance2",
		}
		_K.Data.emotes = clientK.Data.emotes

		-- === General.luau ===
		runSrv(";hint Server hint")
		c.world:fastForward(61)
		runSrv(";privatehint TargetPlr Private hint")
		c.world:fastForward(61)
		runSrv(";message Server message")
		c.world:fastForward(61)
		runSrv(";fullmessage Full message")
		c.world:fastForward(61)
		runSrv(";notify TargetPlr Notification text")
		c.world:fastForward(61)
		runSrv(";privatemessage TargetPlr Secret PM")
		c.world:run(0.05)

		-- Trigger client _K.Chat.onMessage handlers via _K.Remote.ChatSystem
		for _, kind in { "announce", "hint", "privatehint", "message", "fullmessage", "notify", "privatemessage" } do
			_K.Remote.ChatSystem:Fire(srvP1, kind, "Hello " .. kind, 1, "British male", "msg_" .. kind)
		end
		c.world:run(0.1)
		sert.ok(clientK._lastAnnounce)
		sert.ok(clientK._lastNotify)

		-- Countdown start and cancel + client StartCountdown display
		runSrv(";countdown 2")
		c.world:run(0.05)
		c.ch1.env.game:GetService("RunService").Heartbeat:Fire(0.016)
		runSrv(";countdown") -- cancel countdown
		c.world:run(0.05)

		c.world:fastForward(61)
		runSrv(";title TargetPlr Champion #ff0000 #00ff00 Legacy")
		sert.ok((srvP2.Character:FindFirstChild("_K_Title")))
		runSrv(";untitle TargetPlr")
		sert.eq(srvP2.Character:FindFirstChild("_K_Title"), nil)

		-- Vote & Poll: invoke the real client Vote OnInvoke handler inside ch1.env.task.spawn
		local origVoteInvoke = clientK.Remote.Vote.OnInvoke
		if type(origVoteInvoke) == "function" then
			_K.Remote.ChatSystem:Fire(srvP1, "vote", "Continue?", 1, nil, "vote_1")
			c.world:run(0.05)
			local voteInvokeThread = c.ch1.env.task.spawn(function()
				origVoteInvoke("vote_1", c.ch1.env.Players.LocalPlayer, 2, { "YES", "NO" })
			end)
			c.world:run(0.05)
			c.ch1.env.task.cancel(voteInvokeThread)
		end
		clientK.Remote.Vote.OnClientInvoke = function()
			return 1
		end
		c.world:fastForward(61)
		local voteThread = c.sh.env.task.spawn(function()
			runSrv(";vote CreatorPlr Continue?")
		end)
		c.world:run(0.1)
		c.sh.env.task.cancel(voteThread)

		c.world:fastForward(61)
		local pollThread = c.sh.env.task.spawn(function()
			runSrv(';poll CreatorPlr "Best map?" Crossroads,SFOTH,Doomspire')
		end)
		c.world:run(0.1)
		c.sh.env.task.cancel(pollThread)

		-- Client link / unlink / watch / spectate / unspectate
		local cliP2Root = c.ch1.env.Players:GetPlayerByUserId(2).Character.HumanoidRootPart
		runCli(";link TargetPlr true")
		sert.ok((cliP2Root:FindFirstChild("_KLink")))
		c.ch1.env.game:GetService("RunService").RenderStepped:Fire(0.016)
		runCli(";unlink TargetPlr")
		sert.eq(cliP2Root:FindFirstChild("_KLink"), nil)
		runCli(";watch TargetPlr")
		sert.eq(
			c.ch1.env.workspace.CurrentCamera.CameraSubject,
			c.ch1.env.Players:GetPlayerByUserId(2).Character.Humanoid
		)

		runSrv(";spectate TargetPlr")
		runCli(";spectate TargetPlr")
		local runServiceCli = c.ch1.env.game:GetService("RunService")
		-- Exercise spectate PreRender across R15 (scaling true/false), R6, and Dead states
		runServiceCli.PreRender:Fire(0.016)
		local localHum = c.ch1.env.Players.LocalPlayer.Character.Humanoid
		localHum._props.AutomaticScalingEnabled = false
		runServiceCli.PreRender:Fire(0.016)
		localHum.RigType = Enum.HumanoidRigType.R6
		runServiceCli.PreRender:Fire(0.016)
		localHum:ChangeState(Enum.HumanoidStateType.Dead)
		runServiceCli.PreRender:Fire(0.016)
		localHum:ChangeState(Enum.HumanoidStateType.Running)
		localHum.RigType = Enum.HumanoidRigType.R15
		localHum._props.AutomaticScalingEnabled = true

		clientK.Remote.Spectate:Fire(CFrame.identity)
		c.world:run(0.05)
		runSrv(";unspectate TargetPlr")
		runCli(";unspectate")
		sert.eq(c.ch1.env.workspace.CurrentCamera.CameraSubject, localHum)

		-- Fly / noclip / clip / notrip / xray
		runSrv(";fly TargetPlr 50")
		sert.eq(srvP2:GetAttribute("_KFly"), 50)
		runSrv(";unfly TargetPlr")
		sert.eq(srvP2:GetAttribute("_KFly"), nil)

		runSrv(";noclip TargetPlr")
		sert.eq(srvP2:GetAttribute("_KNoClip"), true)
		sert.eq(srvP2:GetAttribute("_KFly"), 128)
		runSrv(";clip TargetPlr")
		sert.eq(srvP2:GetAttribute("_KNoClip"), nil)

		runSrv(";notrip TargetPlr")
		_K.Remote.Notrip:Fire(srvP1, true)
		c.world:run(0.05)
		sert.ok((localHum:GetState()))
		runSrv(";unnotrip TargetPlr")
		_K.Remote.Notrip:Fire(srvP1, false)
		c.world:run(0.05)

		runCli(";xray")
		sert.eq(clientK.Registry.commands.xray.env.xray(), true)
		runCli(";unxray")
		sert.eq(clientK.Registry.commands.xray.env.xray(), false)

		runServiceCli.Heartbeat:Fire(0.016)
		c.world:fastForward(1.1)
		runServiceCli.Heartbeat:Fire(0.016)
		sert.eq(type(clientK.Registry.commands.showfps.env.fps), "number")
		local lastSrvNotify
		local origSrvNotifyFire = _K.Remote.Notify.Fire
		_K.Remote.Notify.Fire = function(self, player, data)
			lastSrvNotify = data
			return origSrvNotifyFire(self, player, data)
		end
		runSrv(";whois CreatorPlr")
		c.world:run(0.1)
		_K.Remote.Notify.Fire = origSrvNotifyFire
		sert.ok(lastSrvNotify and lastSrvNotify.Text)
		sert.eq(string.find(lastSrvNotify.Text, "<b>FPS:</b> ", 1, true) ~= nil, true)

		runCli(";grouprank TargetPlr 100")
		sert.ok(clientK._lastNotify.Text)
		runCli(";playercount")
		sert.eq(clientK._lastNotify.Text, "<b>Player Count:</b> 2")

		c.world:fastForward(61)
		runSrv(';tts "British male" Hello voice')
		_K.Remote.ChatSystem:Fire(srvP1, "tts", "Hello voice", 1, "British male", "tts_1")
		c.world:run(0.05)

		runSrv(";play 123456")
		sert.eq(_K.Registry.commands.play.env.playing.SoundId, "rbxassetid://123456")
		runSrv(";pause")
		runSrv(";resume")
		runSrv(";pitch 1.5")
		sert.eq(_K.Registry.commands.play.env.playing.Pitch, 1.5)
		runSrv(";volume 0.3")
		sert.eq(_K.Registry.commands.play.env.playing.Volume, 0.3)
		runSrv(";stop")
		sert.eq(_K.Registry.commands.play.env.playing.Parent, nil)
		runSrv(";clean")

		-- === Utility.luau ===
		runCli(";version")
		sert.ok(clientK._lastNotify.Text)
		runCli(";prefix")
		sert.ok(clientK._lastNotify.Text)
		runCli(";cmdbar2")
		local cmdbar2Window = clientK.Registry.commands.cmdbar2.env.window
		sert.eq(cmdbar2Window._instance.Visible, true)
		runCli(";cmdbar2")
		sert.eq(cmdbar2Window._instance.Visible, false)

		runCli(";about")
		sert.eq(clientK.client.dashboard.About._instance.Visible, true)
		clientK.client.dashboard.About._instance.Visible = false

		runCli(";commands")
		sert.eq(clientK.client.dashboard.Commands._instance.Visible, true)
		clientK.client.dashboard.Commands._instance.Visible = false

		runCli(";commandbar")
		c.world:run(0.05)
		sert.eq(clientK._cmdBarShown, true)
		runCli(";dashboard")
		sert.eq(clientK.client.dashboard.Window._instance.Visible, true)

		runCli(";donate")
		sert.eq(clientK.client.dashboard.Market._instance.Visible, true)
		clientK.client.dashboard.Market._instance.Visible = false

		runCli(";log")
		sert.eq(clientK.client.dashboard.Logs._instance.Visible, true)
		runCli(";debuglogs")
		runCli(";errorlogs")
		runCli(";chatlogs")
		sert.eq(clientK.client.dashboard.Logs.logTypeFilter.CHAT:peek(), true)
		sert.eq(clientK.client.dashboard.Logs.logTypeFilter.COMMAND:peek(), false)
		runCli(";clogs")
		sert.eq(clientK.client.dashboard.Logs.logTypeFilter.CHAT:peek(), true)
		runCli(";commandlogs")
		runCli(";joinlogs")
		runCli(";damagelogs")
		runCli(";killlogs")
		runCli(";purchaselogs")
		clientK.client.dashboard.Logs._instance.Visible = false

		runCli(";settings")
		sert.eq(clientK.client.dashboard.Settings._instance.Visible, true)
		clientK.client.dashboard.Settings._instance.Visible = false

		runSrv(";emote TargetPlr 507771019")
		_K.Remote.Emote:Fire(srvP1, 507771019)
		c.world:run(0.05)
		local emoteEnv = clientK.Registry.commands.emote.env
		sert.eq(emoteEnv.window._instance.Visible, true)
		runSrv(";stopemote TargetPlr")
		_K.Remote.Emote:Fire(srvP1, nil)
		c.world:run(0.05)
		sert.eq(emoteEnv.window._instance.Visible, false)

		-- Verify emote ownership & VIP bypass in emote.run
		do
			local emoteCmd = _K.Registry.commands.emote
			local bulkPrompts: { any } = {}
			local emoteFires: { any } = {}
			local mktMethods = rawget(_K.Service.Marketplace, "_methods")
			local origPromptBulk = mktMethods and mktMethods.PromptBulkPurchase
			local origOwnsAsset = mktMethods and mktMethods.PlayerOwnsAssetAsync
			local ownedAssets: { [number]: boolean } = {}
			if mktMethods then
				mktMethods.PromptBulkPurchase = function(_self: any, plr: any, items: any)
					table.insert(bulkPrompts, { plr = plr, items = items })
				end
				mktMethods.PlayerOwnsAssetAsync = function(_self: any, _plr: any, assetId: number)
					return ownedAssets[assetId] == true
				end
			end
			local origEmoteFire = emoteCmd.env.remote.Fire
			emoteCmd.env.remote.Fire = function(_self: any, plr: any, anim: any, loop: any, spd: any)
				table.insert(emoteFires, { plr = plr, anim = anim, loop = loop, spd = spd })
			end

			_K.Data.animationToEmoteId[9001] = 2001
			_K.VIP.allowedBulkPurchaseIds[2001] = true
			_K.Data.animationToEmoteId[9002] = 2002
			_K.VIP.allowedBulkPurchaseIds[2002] = nil

			local p2Ctx = {
				_K = _K,
				env = emoteCmd.env,
				from = srvP2.UserId,
				fromPlayer = srvP2,
			}

			-- 1. Non-VIP who does not own a sellable emote gets prompted for emoteId (2001)
			srvP2:SetAttribute("_KDonationLevel", 0)
			emoteCmd.run(p2Ctx, { srvP2 }, 9001)
			sert.eq(#emoteFires, 0)
			sert.eq(#bulkPrompts, 1)
			sert.eq(bulkPrompts[1].items[1].Id, "2001")

			-- 2. Non-VIP who does not own an offsale/non-bulk emote gets the VIP Popup via Remote.VIPNotification:Fire(plr, true)
			table.clear(bulkPrompts)
			local vipNotifications: { any } = {}
			local origVipNotifFire = _K.Remote.VIPNotification.Fire
			_K.Remote.VIPNotification.Fire = function(_self: any, plr: any, forcePopup: any)
				table.insert(vipNotifications, { plr = plr, forcePopup = forcePopup })
				return origVipNotifFire(_self, plr, forcePopup)
			end
			clientK.VIP.popup.Visible = false
			emoteCmd.run(p2Ctx, { srvP2 }, 9002)
			sert.eq(#emoteFires, 0)
			sert.eq(#bulkPrompts, 0)
			sert.eq(#vipNotifications, 1)
			sert.eq(vipNotifications[1].plr, srvP2)
			sert.eq(vipNotifications[1].forcePopup, true)

			-- 3. Non-VIP who owns the emote asset (2001) plays it without purchase prompt
			table.clear(bulkPrompts)
			ownedAssets[2001] = true
			emoteCmd.run(p2Ctx, { srvP2 }, 9001)
			sert.eq(#bulkPrompts, 0)
			sert.eq(#emoteFires, 1)
			sert.eq(emoteFires[1].anim, 9001)

			-- 4. VIP user (via _KDonationLevel >= 1, vip role, freeAdmin vip, or custom VIP group role) plays unowned emote without purchase prompt
			table.clear(emoteFires)
			ownedAssets[2001] = false
			srvP2:SetAttribute("_KDonationLevel", 1)
			emoteCmd.run(p2Ctx, { srvP2 }, 9001)
			sert.eq(#bulkPrompts, 0)
			sert.eq(#emoteFires, 1)

			table.clear(emoteFires)
			srvP2:SetAttribute("_KDonationLevel", 0)
			_K.Auth.userRoleAdd(srvP2.UserId, "vip")
			emoteCmd.run(p2Ctx, { srvP2 }, 9001)
			sert.eq(#bulkPrompts, 0)
			sert.eq(#emoteFires, 1)
			_K.Auth.userRoleRemove(srvP2.UserId, "vip")

			-- 4b. freeAdmin = { "vip" } grants free emote access even when Auth.hasRole is false for same rank
			table.clear(emoteFires)
			_K.Data.settings.freeAdmin = { "vip" }
			emoteCmd.run(p2Ctx, { srvP2 }, 9002)
			sert.eq(#bulkPrompts, 0)
			sert.eq(#emoteFires, 1)
			_K.Data.settings.freeAdmin = {}

			-- 4c. Custom role with groups = { "vip" } at rank 0 grants free emote access
			table.clear(emoteFires)
			_K.Data.roles.customVip = {
				_key = "customVip",
				_rank = 0,
				name = "CustomVIP",
				color = "#0ff",
				groups = { "vip" },
				permissions = {},
			}
			_K.Auth.userRoleAdd(srvP2.UserId, "customVip")
			emoteCmd.run(p2Ctx, { srvP2 }, 9002)
			sert.eq(#bulkPrompts, 0)
			sert.eq(#emoteFires, 1)
			_K.Auth.userRoleRemove(srvP2.UserId, "customVip")
			_K.Data.roles.customVip = nil

			-- 4d. Joining player with _KDonationLevel == nil awaits VIP.setDonationLevel before prompting
			table.clear(emoteFires)
			srvP2:SetAttribute("_KDonationLevel", nil)
			ownedAssets[115444443724463] = true
			_K.Data.settings.vip = false
			emoteCmd.run(p2Ctx, { srvP2 }, 9002)
			_K.Data.settings.vip = true
			sert.eq(srvP2:GetAttribute("_KDonationLevel"), 4)
			sert.eq(#bulkPrompts, 0)
			sert.eq(#emoteFires, 1)
			ownedAssets[115444443724463] = false
			srvP2:SetAttribute("_KDonationLevel", 0)

			-- 5. Stopping an emote (animation == nil) does not prompt purchase
			table.clear(emoteFires)
			emoteCmd.run(p2Ctx, { srvP2 }, nil :: any)
			sert.eq(#bulkPrompts, 0)
			sert.eq(#emoteFires, 1)

			-- 6. When settings.vip == false, offsale/non-bulk emotes (9002) do not prompt purchase and do not play
			table.clear(bulkPrompts)
			table.clear(emoteFires)
			table.clear(vipNotifications)
			_K.Data.settings.vip = false
			emoteCmd.run(p2Ctx, { srvP2 }, 9002)
			sert.eq(#bulkPrompts, 0)
			sert.eq(#vipNotifications, 0)
			sert.eq(#emoteFires, 0)
			_K.Data.settings.vip = true

			-- 7. Disconnected fromPlayer (Parent == nil) is a safe no-op
			local origParent = srvP2.Parent
			srvP2.Parent = nil
			emoteCmd.run(p2Ctx, { srvP2 }, 9001)
			srvP2.Parent = origParent
			sert.eq(#bulkPrompts, 0)
			sert.eq(#emoteFires, 0)

			-- 8. Client Emote preview Unlock button opens VIP popup on off-sale emotes and updates owned state on PromptBulkPurchaseFinished
			clientK.Data.emoteItemFromId[2002] = {
				emoteId = 2002,
				animationId = 9002,
				name = "OffsaleEmote",
				nameLower = "offsaleemote",
				canSell = false,
				owned = false,
			}
			clientK.Data.emoteItemFromId[2001] = {
				emoteId = 2001,
				animationId = 9001,
				name = "SellableEmote",
				nameLower = "sellableemote",
				canSell = true,
				owned = false,
			}
			if emoteEnv.updatePreview and emoteEnv.preview then
				emoteEnv.updatePreview(2002)
				emoteEnv.preview.Visible = true
				clientK.VIP.popup.Visible = false
				emoteEnv.preview.Unlock.Activated:Fire()
				sert.eq(emoteEnv.preview.Visible, false)
				sert.eq(clientK.VIP.popup.Visible, true)
				clientK.VIP.popup.Visible = false

				emoteEnv.updatePreview(2001)
				emoteEnv.preview.Visible = true
				local cliMkt = c.ch1.env.game:GetService("MarketplaceService")
				cliMkt.PromptBulkPurchaseFinished:Fire(
					c.ch1.env.Players.LocalPlayer,
					Enum.MarketplaceBulkPurchasePromptStatus.Completed,
					{ Items = { { Id = "2001", Status = Enum.MarketplaceItemPurchaseStatus.Success } } }
				)
				c.world:run(0.05)
				sert.eq(clientK.Data.emoteItemFromId[2001].owned, true)
				sert.eq(emoteEnv.preview.Visible, false)
			end

			_K.Remote.VIPNotification.Fire = origVipNotifFire
			emoteCmd.env.remote.Fire = origEmoteFire
			if mktMethods then
				mktMethods.PromptBulkPurchase = origPromptBulk
				mktMethods.PlayerOwnsAssetAsync = origOwnsAsset
			end
		end

		runCli(";emotes")
		local emotesEnv = clientK.Registry.commands.emotes.env
		sert.eq(emotesEnv.window._instance.Visible, true)
		if emotesEnv.scroller and emotesEnv.scroller.CreateItem then
			local createItemFn = if type(emotesEnv.scroller.CreateItem) == "table"
				then emotesEnv.scroller.CreateItem:peek()
				else emotesEnv.scroller.CreateItem
			local renderItemFn = if type(emotesEnv.scroller.RenderItem) == "table"
				then emotesEnv.scroller.RenderItem:peek()
				else emotesEnv.scroller.RenderItem
			local waveData = { name = "Wave", emoteId = 507771019, owned = true }
			local emoteItem = createItemFn(emotesEnv.scroller, waveData)
			renderItemFn(emotesEnv.scroller, emoteItem, waveData)
			sert.ok(emoteItem)
			local imgButton = emoteItem._instance:FindFirstChildOfClass("ImageButton")
			sert.ok(imgButton)
			sert.eq(type(imgButton.Image), "string")
			sert.eq(imgButton.Image, clientK.UI.Theme.Image.Play:peek())
		end
		emotesEnv.window._instance.Visible = false

		runCli(";age TargetPlr")
		sert.ok(clientK._lastNotify.Text)
		runCli(";serverage")
		sert.ok(clientK._lastNotify.Text)
		runCli(";gameid")
		sert.ok(clientK._lastNotify.Text)
		runCli(";jobid")
		sert.ok(clientK._lastNotify.Text)
		runCli(";placeid")
		sert.ok(clientK._lastNotify.Text)

		local lastFpsNotify
		local origFpsNotifyFire = _K.Remote.Notify.Fire
		_K.Remote.Notify.Fire = function(self, player, data)
			lastFpsNotify = data
			return origFpsNotifyFire(self, player, data)
		end
		runSrv(";showfps CreatorPlr")
		local waitThread = c.sh.env.task.spawn(function()
			runSrv(";wait 0.01")
		end)
		c.world:run(0.1)
		_K.Remote.Notify.Fire = origFpsNotifyFire
		sert.ok(lastFpsNotify and lastFpsNotify.Text)
		sert.eq(string.find(lastFpsNotify.Text, "<b>FPS:</b> ", 1, true) ~= nil, true)
		c.sh.env.task.cancel(waitThread)

		runSrv(";ping TargetPlr")
		runSrv(";rejoin")

		runCli(";viewas vip")
		sert.eq(clientK.Registry.commands.viewas.env.originalCreatorId, 1)
		runCli(";unviewas")
		sert.eq(clientK.Registry.commands.viewas.env.originalCreatorId, nil)
	end)

	test(
		"executes all Moderation commands including teams, leaderstats, tools, health, movement, and punishments",
		function()
			local c = createSimCluster()
			local _K, clientK, srvP1, srvP2 = c._K, c.clientK, c.srvP1, c.srvP2
			local runSrv, runCli = c.runSrv, c.runCli

			-- Populate StarterPack and clientK.tools with a tool for give/startergive/tools/startertools/viewtools
			local spTool = c.sh.env.Instance.new("Tool", c.sh.env.game:GetService("StarterPack"))
			spTool.Name = "Launcher"
			c.sh.env.Instance.new("Part", spTool).Name = "Handle"

			local cliSpTool = c.ch1.env.Instance.new("Tool", c.ch1.env.game:GetService("StarterPack"))
			cliSpTool.Name = "Launcher"
			cliSpTool.ToolTip = "Rocket Launcher"
			local cliSpTool2 = c.ch1.env.Instance.new("Tool", c.ch1.env.game:GetService("StarterPack"))
			cliSpTool2.Name = "Grapple"
			clientK.tools = { cliSpTool, cliSpTool2 }
			local cliP2OnC1 = c.ch1.env.Players:GetPlayerByUserId(2)
			if cliP2OnC1 then
				local p2Tool = c.ch1.env.Instance.new("Tool", cliP2OnC1.Backpack)
				p2Tool.Name = "Sword"
				p2Tool.ToolTip = "Classic Sword"
			end

			-- Populate leaderstats on srvP2
			local ls = c.sh.env.Instance.new("Folder", srvP2)
			ls.Name = "leaderstats"
			local coins = c.sh.env.Instance.new("IntValue", ls)
			coins.Name = "Coins"
			coins.Value = 10
			local statusStat = c.sh.env.Instance.new("StringValue", ls)
			statusStat.Name = "Status"
			statusStat.Value = "Idle"
			local activeStat = c.sh.env.Instance.new("BoolValue", ls)
			activeStat.Name = "Active"
			activeStat.Value = false

			-- Client dashboard/window tabs in Moderation
			runCli(";bans")
			sert.eq(clientK.client.dashboard.Bans._instance.Visible, true)
			clientK.client.dashboard.Bans._instance.Visible = false

			runCli(";members")
			sert.eq(clientK.client.dashboard.Members._instance.Visible, true)
			clientK.client.dashboard.Members._instance.Visible = false

			runCli(";servers")
			sert.eq(clientK.client.dashboard.Servers._instance.Visible, true)
			clientK.client.dashboard.Servers._instance.Visible = false

			runCli(";tools")
			local toolsEnv = clientK.Registry.commands.tools.env
			sert.eq(toolsEnv.window._instance.Visible, true)
			if toolsEnv.scroller and toolsEnv.scroller.CreateItem then
				local item = toolsEnv.scroller:CreateItem()
				toolsEnv.scroller:RenderItem(item, "Launcher")
				sert.ok(item)
			end
			toolsEnv.window._instance.Visible = false

			runCli(";startertools")
			sert.eq(toolsEnv.window._instance.Visible, true)
			toolsEnv.window._instance.Visible = false

			runCli(";viewtools TargetPlr")
			sert.eq(toolsEnv.window._instance.Visible, true)
			toolsEnv.window._instance.Visible = false

			-- Mute / unmute
			runSrv(";mute TargetPlr")
			sert.ok(_K.Registry.commands.mute.env.muted[2])
			_K.Remote.Mute:Fire(srvP1, true)
			c.world:run(0.05)
			runSrv(";unmute TargetPlr")
			sert.eq(_K.Registry.commands.mute.env.muted[2], nil)
			_K.Remote.Mute:Fire(srvP1, false)
			c.world:run(0.05)

			-- Punish / unpunish
			runSrv(";punish TargetPlr")
			sert.eq(srvP2.Character, nil)
			runSrv(";unpunish TargetPlr")
			sert.eq(srvP2.Character.Parent, c.sh.env.workspace)

			-- Name / hidename / showname / unname
			runSrv(";name TargetPlr CustomNick")
			sert.eq(srvP2.Character.Humanoid.DisplayName, "CustomNick")
			runSrv(";hidename TargetPlr")
			sert.eq(srvP2.Character.Humanoid.DisplayDistanceType, Enum.HumanoidDisplayDistanceType.None)
			runSrv(";showname TargetPlr")
			sert.eq(srvP2.Character.Humanoid.DisplayDistanceType, Enum.HumanoidDisplayDistanceType.Viewer)
			runSrv(";unname TargetPlr")
			sert.eq(srvP2.Character.Humanoid.DisplayName, "TargetPlr")

			-- CoreGui
			runSrv(";setcoregui TargetPlr Backpack false")
			_K.Remote.SetCoreGuiEnabled:Fire(srvP1, Enum.CoreGuiType.Backpack, false)
			c.world:run(0.05)
			sert.eq(c.ch1.env.game:GetService("StarterGui"):GetCoreGuiEnabled(Enum.CoreGuiType.Backpack), false)

			-- Tools: give, startergive, starterremove, copytools, removetools, sword, toolban, untoolban
			runSrv(";give TargetPlr Launcher")
			sert.ok((srvP2.Backpack:FindFirstChild("Launcher")))
			runSrv(";give TargetPlr all")
			sert.eq(#srvP2.Backpack:GetChildren() >= 1, true)
			runSrv(";startergive TargetPlr Launcher")
			sert.ok((srvP2.StarterGear:FindFirstChild("Launcher")))
			runSrv(";starterremove TargetPlr Launcher")
			sert.eq(srvP2.StarterGear:FindFirstChild("Launcher"), nil)
			runSrv(";copytools TargetPlr CreatorPlr")
			sert.ok((srvP1.Backpack:FindFirstChild("Launcher")))
			runSrv(";sword TargetPlr")
			runSrv(";removetools TargetPlr")
			sert.eq(#srvP2.Backpack:GetChildren(), 0)
			runSrv(";toolban TargetPlr")
			local toolBanHandle = _K.Registry.commands.toolban.env.bans[srvP2]
			sert.ok(toolBanHandle)
			sert.eq(toolBanHandle.Connected, true)
			-- Adding a tool to Backpack or Character while toolbanned destroys it via task.defer
			local bannedTool = c.sh.env.Instance.new("Tool", srvP2.Backpack)
			local charBannedTool = c.sh.env.Instance.new("Tool", srvP2.Character)
			c.world:run(0.05)
			sert.eq(bannedTool.Parent, nil)
			sert.eq(charBannedTool.Parent, nil)
			-- Respawn creating a new Backpack keeps toolban active
			srvP2.Backpack:Destroy()
			local respawnBp = c.sh.env.Instance.new("Backpack", srvP2)
			local respawnTool = c.sh.env.Instance.new("Tool", respawnBp)
			c.world:run(0.05)
			sert.eq(respawnTool.Parent, nil)
			runSrv(";untoolban TargetPlr")
			sert.eq(toolBanHandle.Connected, false)
			sert.eq(_K.Registry.commands.toolban.env.bans[srvP2], nil)

			-- Health, damage, forcefield, immortal, kill, loopkill
			runSrv(";health TargetPlr 250")
			sert.eq(srvP2.Character.Humanoid.MaxHealth, 250)
			runSrv(";hurt TargetPlr 50")
			sert.eq(srvP2.Character.Humanoid.Health, 200)
			runSrv(";heal TargetPlr")
			sert.eq(srvP2.Character.Humanoid.Health, 250)
			runSrv(";forcefield TargetPlr")
			sert.ok((srvP2.Character:FindFirstChildOfClass("ForceField")))
			runSrv(";unforcefield TargetPlr")
			sert.eq(srvP2.Character:FindFirstChildOfClass("ForceField"), nil)
			runSrv(";immortal TargetPlr")
			sert.eq(srvP2.Character.Humanoid.MaxHealth, math.huge)
			sert.ok((srvP2.Character:FindFirstChild("_Kff")))
			runSrv(";mortal TargetPlr")
			sert.eq(srvP2.Character.Humanoid.MaxHealth, 250)
			sert.eq(srvP2.Character:FindFirstChild("_Kff"), nil)
			runSrv(";kill TargetPlr")
			sert.eq(srvP2.Character.Humanoid.Health, 0)
			buildCharacter(c.sh.env, srvP2)
			runSrv(";loopkill TargetPlr")
			sert.eq(_K.Registry.commands.loopkill.env.killing[srvP2.UserId], true)
			c.world:run(0.1)
			runSrv(";unloopkill TargetPlr")
			sert.eq(_K.Registry.commands.loopkill.env.killing[srvP2.UserId], nil)
			buildCharacter(c.sh.env, srvP2)

			-- Visibility, blind, freeze, jail, lock, stun
			runSrv(";invisible TargetPlr")
			sert.eq(srvP2.Character.Head.Transparency, 1)
			sert.eq(srvP2.Character.HumanoidRootPart:FindFirstChildOfClass("PointLight").Enabled, false)
			runSrv(";visible TargetPlr")
			sert.eq(srvP2.Character.Head.Transparency, 0)
			sert.eq(srvP2.Character.HumanoidRootPart:FindFirstChildOfClass("PointLight").Enabled, true)

			runSrv(";blind TargetPlr")
			_K.Remote.Blind:Fire(srvP1, true)
			c.world:run(0.05)
			sert.eq(clientK.Registry.commands.blind.env.frame.Visible, true)
			runSrv(";unblind TargetPlr")
			_K.Remote.Blind:Fire(srvP1, false)
			c.world:run(0.05)
			sert.eq(clientK.Registry.commands.blind.env.frame.Visible, false)

			runSrv(";freeze TargetPlr")
			sert.ok((srvP2.Character:FindFirstChild("kFreeze")))
			sert.eq(srvP2.Character.HumanoidRootPart.Anchored, true)
			runSrv(";thaw TargetPlr")
			sert.eq(srvP2.Character:FindFirstChild("kFreeze"), nil)
			sert.eq(srvP2.Character.HumanoidRootPart.Anchored, false)

			runSrv(";jail TargetPlr")
			sert.ok(_K.Registry.commands.jail.env.parts[srvP2.UserId])
			-- Re-jailing exercises existing jail guard, and respawn while jailed recaptures
			runSrv(";jail TargetPlr")
			_K.Registry.commands.jail.env.recapture(srvP2.Character)
			runSrv(";unjail TargetPlr")
			sert.eq(_K.Registry.commands.jail.env.parts[srvP2.UserId], nil)

			runSrv(";lock TargetPlr")
			sert.eq(srvP2.Character.HumanoidRootPart.Locked, true)
			runSrv(";unlock TargetPlr")
			sert.eq(srvP2.Character.HumanoidRootPart.Locked, false)
			runSrv(";stun TargetPlr")
			sert.eq(srvP2.Character.Humanoid.PlatformStand, true)
			runSrv(";unstun TargetPlr")
			sert.eq(srvP2.Character.Humanoid.PlatformStand, false)

			-- CameraOffset, antilag, fps, fov
			runSrv(";cameraoffset CreatorPlr 1,2,3")
			c.world:run(0.05)
			sert.eq(c.ch1.env.Players.LocalPlayer.Character.Humanoid.CameraOffset, Vector3.new(1, 2, 3))
			runSrv(";antilag TargetPlr")
			runSrv(";unantilag TargetPlr")
			runSrv(";fps TargetPlr 120")
			_K.Remote.FPS:Fire(srvP1, 120)
			c.world:run(0.05)
			runSrv(";unfps TargetPlr")
			_K.Remote.FPS:Fire(srvP1)
			c.world:run(0.05)
			runSrv(";fov TargetPlr 90")
			_K.Remote.FOV:Fire(srvP1, 90)
			c.world:run(0.05)
			sert.eq(c.ch1.env.workspace.CurrentCamera.FieldOfView, 90)
			runSrv(";unfov TargetPlr")
			_K.Remote.FOV:Fire(srvP1, nil)
			c.world:run(0.05)
			sert.eq(c.ch1.env.workspace.CurrentCamera.FieldOfView, 70)

			-- Teleportation & movement
			srvP2.Character:PivotTo(CFrame.new(100, 0, 100))
			runSrv(";bring TargetPlr")
			sert.eq((srvP2.Character:GetPivot().Position - srvP1.Character:GetPivot().Position).Magnitude <= 10, true)
			srvP2.Character:PivotTo(CFrame.new(200, 0, 200))
			runSrv(";to TargetPlr")
			sert.eq((srvP1.Character:GetPivot().Position - srvP2.Character:GetPivot().Position).Magnitude <= 10, true)
			srvP2.Character:PivotTo(CFrame.new(0, 0, 0))
			runSrv(";tp TargetPlr CreatorPlr")
			sert.eq((srvP2.Character:GetPivot().Position - srvP1.Character:GetPivot().Position).Magnitude <= 10, true)
			runSrv(";jump TargetPlr")
			sert.eq(srvP2.Character.Humanoid.Jump, true)
			runSrv(";jumppower TargetPlr 75")
			sert.eq(srvP2.Character.Humanoid.JumpPower, 75)
			runSrv(";starterjumppower 80")
			sert.eq(c.sh.env.game:GetService("StarterPlayer").CharacterJumpPower, 80)
			runSrv(";sit TargetPlr")
			sert.eq(srvP2.Character.Humanoid.Sit, true)
			runSrv(";unsit TargetPlr")
			sert.eq(srvP2.Character.Humanoid.Sit, false)
			runSrv(";speed TargetPlr 32")
			sert.eq(srvP2.Character.Humanoid.WalkSpeed, 32)
			runSrv(";starterspeed 24")
			sert.eq(c.sh.env.game:GetService("StarterPlayer").CharacterWalkSpeed, 24)
			runSrv(";slopeangle TargetPlr 60")
			sert.eq(srvP2.Character.Humanoid.MaxSlopeAngle, 60)
			runSrv(";starterslopeangle 60")
			sert.eq(c.sh.env.game:GetService("StarterPlayer").CharacterMaxSlopeAngle, 60)

			-- VehicleSpeed / VehicleTorque with a VehicleSeat
			local vSeat = c.sh.env.Instance.new("VehicleSeat", srvP2.Character)
			srvP2.Character.Humanoid._props.SeatPart = vSeat
			runSrv(";vehiclespeed TargetPlr 100")
			sert.eq(vSeat.MaxSpeed, 100)
			runSrv(";vehicletorque TargetPlr 50")
			sert.eq(vSeat.Torque, 50)

			-- Collide / nocollide
			srvP2.Character.HumanoidRootPart.CollisionGroup = "Default"
			runSrv(";nocollide TargetPlr")
			sert.eq(srvP2.Character.HumanoidRootPart.CollisionGroup, "_KNoCollide")
			runSrv(";collide TargetPlr")
			sert.eq(srvP2.Character.HumanoidRootPart.CollisionGroup, "Default")

			-- Limbs & rig / respawn / refresh
			runSrv(";removearms TargetPlr")
			sert.eq(srvP2.Character:FindFirstChild("LeftUpperArm"), nil)
			buildCharacter(c.sh.env, srvP2)
			runSrv(";removelegs TargetPlr")
			sert.eq(srvP2.Character:FindFirstChild("LeftUpperLeg"), nil)
			buildCharacter(c.sh.env, srvP2)
			runSrv(";removelimbs TargetPlr")
			sert.eq(srvP2.Character:FindFirstChild("RightUpperArm"), nil)
			sert.eq(srvP2.Character:FindFirstChild("RightUpperLeg"), nil)
			buildCharacter(c.sh.env, srvP2)
			runSrv(";r6 TargetPlr")
			sert.ok(srvP2.Character)
			runSrv(";r15 TargetPlr")
			sert.ok(srvP2.Character)
			runSrv(";respawn TargetPlr")
			sert.ok(srvP2.Character)
			runSrv(";refresh TargetPlr")
			sert.ok(srvP2.Character)

			-- Marketplace & Group commands: buy, has, promptgroup (arg order: players, infoType, id)
			c.sh.env.marketplace.assets[2] = { [101] = true }
			c.sh.env.marketplace.gamePasses[2] = { [102] = true }
			c.sh.env.marketplace.bundles[2] = { [103] = true }
			c.sh.env.marketplace.subscriptions[2] = { ["EXP-104"] = true }
			runSrv(";buy TargetPlr Asset 101")
			runSrv(";buy TargetPlr GamePass 102")
			runSrv(";buy TargetPlr Product 105")
			runSrv(";buy TargetPlr Bundle 103")
			runSrv(";buy TargetPlr Subscription 104")
			runSrv(";has TargetPlr Asset 101")
			runSrv(";has TargetPlr GamePass 102")
			runSrv(";has TargetPlr Bundle 103")
			runSrv(";has TargetPlr Subscription 104")
			c.world:run(0.05)
			sert.ok(_K.Registry.commands.has.env.method[Enum.InfoType.Subscription])
			runSrv(";promptgroup TargetPlr 100")

			-- Leaderstats: change & resetstats
			runSrv(";change TargetPlr Coins 999")
			sert.eq(coins.Value, 999)
			c.world:fastForward(61)
			runSrv(";change TargetPlr Status Ready")
			sert.eq(statusStat.Value, "Ready")
			runSrv(";change TargetPlr Active true")
			sert.eq(activeStat.Value, true)
			runSrv(";resetstats TargetPlr")
			sert.eq(coins.Value, 0)

			-- Teams: createteam, editteam, team, substitute, randomizeteams, teamrespawn, removeteam, clearteams
			c.world:fastForward(61)
			runSrv(";createteam Red 255,0,0")
			c.world:fastForward(61)
			runSrv(";createteam Blue 0,0,255")
			local teams = c.sh.env.game:GetService("Teams")
			local redTeam = teams:FindFirstChild("Red")
			local blueTeam = teams:FindFirstChild("Blue")
			sert.ok(redTeam)
			sert.ok(blueTeam)
			c.world:fastForward(61)
			runSrv(";editteam Red Crimson 200,0,0")
			sert.eq(redTeam.Name, "Crimson")
			runSrv(";team CreatorPlr Crimson")
			runSrv(";team TargetPlr Blue")
			sert.eq(srvP1.Team, redTeam)
			sert.eq(srvP2.Team, blueTeam)
			runSrv(";substitute CreatorPlr TargetPlr")
			sert.eq(srvP1.Team, blueTeam)
			sert.eq(srvP2.Team, redTeam)
			runSrv(";randomizeteams all Crimson Blue")
			sert.eq(srvP1.Team ~= nil or srvP2.Team ~= nil, true)
			runSrv(";teamrespawn Blue")
			runSrv(";removeteam Crimson")
			sert.eq(teams:FindFirstChild("Crimson"), nil)
			runSrv(";clearteams")
			sert.eq(#teams:GetChildren(), 0)

			-- Ban / unban / kick / crash (server run)
			runSrv(";crash TargetPlr")
			c.world:fastForward(61)
			runSrv(";ban TargetPlr 10m Griefing")
			sert.ok(_K.Data.bans["2"])
			runSrv(";unban 2")
			sert.eq(_K.Data.bans["2"], nil)
			c.world:fastForward(61)
			runSrv(";kick TargetPlr Bye")
			sert.eq(srvP2._props._kicked, "Bye")
		end
	)

	test("executes all VIP and Fun commands including R6/R15 rigs, effects, accessories, and undo aliases", function()
		local c = createSimCluster()
		local _K, srvP1, srvP2 = c._K, c.srvP1, c.srvP2
		local runSrv, runCli = c.runSrv, c.runCli

		-- Configure marketplace AssetTypeIds for VIP commands (hat=8, head=17, face=18, shirt=11, pants=12, tshirt=2)
		c.sh.env.marketplace.products[800] = { AssetId = 800, AssetTypeId = 8, Name = "Hat" }
		c.sh.env.marketplace.products[1700] = { AssetId = 1700, AssetTypeId = 17, Name = "Head" }
		c.sh.env.marketplace.products[1800] = { AssetId = 1800, AssetTypeId = 18, Name = "Face" }
		c.sh.env.marketplace.products[1100] = { AssetId = 1100, AssetTypeId = 11, Name = "Shirt" }
		c.sh.env.marketplace.products[1200] = { AssetId = 1200, AssetTypeId = 12, Name = "Pants" }
		c.sh.env.marketplace.products[200] = { AssetId = 200, AssetTypeId = 2, Name = "TShirt" }

		-- === VIP.luau ===
		runSrv(";fire TargetPlr 5 255,0,0 255,128,0")
		sert.ok((srvP2.Character.HumanoidRootPart:FindFirstChild("_KFire")))
		runSrv(";unfire TargetPlr")
		sert.eq(srvP2.Character.HumanoidRootPart:FindFirstChild("_KFire"), nil)

		runSrv(";smoke TargetPlr 255,255,255")
		sert.ok((srvP2.Character.HumanoidRootPart:FindFirstChild("_KSmoke")))
		runSrv(";unsmoke TargetPlr")
		sert.eq(srvP2.Character.HumanoidRootPart:FindFirstChild("_KSmoke"), nil)

		runSrv(";sparkles TargetPlr 0,255,255")
		sert.ok((srvP2.Character.HumanoidRootPart:FindFirstChild("_KSparkles")))
		runSrv(";unsparkles TargetPlr")
		sert.eq(srvP2.Character.HumanoidRootPart:FindFirstChild("_KSparkles"), nil)

		runSrv(";light TargetPlr 10 255,255,0")
		sert.ok((srvP2.Character.HumanoidRootPart:FindFirstChild("_KLight")))
		runSrv(";unlight TargetPlr")
		sert.eq(srvP2.Character.HumanoidRootPart:FindFirstChild("_KLight"), nil)

		runSrv(";highlight TargetPlr 255,0,0 255,255,255 0.5 0")
		sert.ok((srvP2.Character:FindFirstChild("_KHighlight")))
		runSrv(";unhighlight TargetPlr")
		sert.eq(srvP2.Character:FindFirstChild("_KHighlight"), nil)

		runSrv(";particle TargetPlr 12345 255,0,0")
		sert.ok((srvP2.Character.HumanoidRootPart:FindFirstChild("_KParticleEffect")))
		_K.Remote.DonorTrail:Fire(srvP1, true)
		_K.Remote.DonorTrail:Fire(srvP1, false)
		runSrv(";unparticle TargetPlr")
		sert.eq(srvP2.Character.HumanoidRootPart:FindFirstChild("_KParticleEffect"), nil)

		runSrv(";trail TargetPlr 255,0,0")
		sert.ok((srvP2.Character.Torso:FindFirstChild("_KTrailEffect")))
		runSrv(";untrail TargetPlr")
		sert.eq(srvP2.Character.Torso:FindFirstChild("_KTrailEffect"), nil)

		runSrv(";shine TargetPlr")
		sert.ok((srvP2.Character.HumanoidRootPart:FindFirstChild("_KShineEffect")))
		runSrv(";unshine TargetPlr")
		sert.eq(srvP2.Character.HumanoidRootPart:FindFirstChild("_KShineEffect"), nil)

		runSrv(";cape TargetPlr 255,0,0 0.5 Neon 12345")
		sert.ok((srvP2.Character:FindFirstChild("_KCape")))
		c.sh.env.game:GetService("RunService").Heartbeat:Fire(0.016)
		runSrv(";uncape TargetPlr")
		sert.eq(srvP2.Character:FindFirstChild("_KCape"), nil)

		runSrv(";hat TargetPlr 800 12345 255,0,0 0.5 Neon")
		sert.ok((srvP2.Character:FindFirstChild("_KHat800")))
		-- Calling hat again replaces existing _KHat800
		runSrv(";hat TargetPlr 800")
		sert.ok((srvP2.Character:FindFirstChild("_KHat800")))
		runSrv(";removehats TargetPlr")
		sert.eq(srvP2.Character:FindFirstChild("_KHat800"), nil)

		runSrv(";head TargetPlr 1700")
		sert.eq(srvP2.Character.Humanoid._props._description.Head, 1700)
		runSrv(";unhead TargetPlr")
		sert.eq(srvP2.Character.Humanoid._props._description.Head, 0)
		runSrv(";headsize TargetPlr 2")
		sert.eq(srvP2.Character.Humanoid:FindFirstChild("HeadScale").Value, 2)
		runSrv(";bighead TargetPlr")
		sert.eq(srvP2.Character.Humanoid:FindFirstChild("HeadScale").Value > 1, true)
		runSrv(";smallhead TargetPlr")
		sert.eq(srvP2.Character.Humanoid:FindFirstChild("HeadScale").Value < 1, true)
		runSrv(";normalhead TargetPlr")
		sert.eq(srvP2.Character.Humanoid:FindFirstChild("HeadScale").Value, 1)

		-- Also test R6 headsize & normalhead branch
		srvP2.Character.Humanoid.RigType = Enum.HumanoidRigType.R6
		runSrv(";headsize TargetPlr 2")
		sert.eq(srvP2.Character.Head.Mesh.Scale, Vector3.new(2, 2, 2))
		runSrv(";normalhead TargetPlr")
		sert.eq(srvP2.Character.Head.Mesh.Scale, Vector3.one)
		srvP2.Character.Humanoid.RigType = Enum.HumanoidRigType.R15

		runSrv(";face TargetPlr 1800")
		sert.eq(string.find(srvP2.Character.Head.face.Texture, "1800", 1, true) ~= nil, true)
		runSrv(";unface TargetPlr")
		sert.eq(srvP2.Character.Head.face.Texture, "rbxasset://textures/face.png")
		runSrv(";shirt TargetPlr 1100")
		sert.eq(string.find(srvP2.Character:FindFirstChildOfClass("Shirt").ShirtTemplate, "1100", 1, true) ~= nil, true)
		runSrv(";unshirt TargetPlr")
		sert.eq(srvP2.Character:FindFirstChildOfClass("Shirt").ShirtTemplate, "")
		runSrv(";pants TargetPlr 1200")
		sert.eq(string.find(srvP2.Character:FindFirstChildOfClass("Pants").PantsTemplate, "1200", 1, true) ~= nil, true)
		runSrv(";unpants TargetPlr")
		sert.eq(srvP2.Character:FindFirstChildOfClass("Pants").PantsTemplate, "")
		runSrv(";tshirt TargetPlr 200")
		sert.eq(string.find(srvP2.Character:FindFirstChildOfClass("ShirtGraphic").Graphic, "200", 1, true) ~= nil, true)
		runSrv(";untshirt TargetPlr")
		sert.eq(srvP2.Character:FindFirstChildOfClass("ShirtGraphic").Graphic, "")
		runSrv(";bodycolor TargetPlr 255,200,150")
		sert.eq(srvP2.Character.BodyColors.HeadColor3, Color3.fromRGB(255, 200, 150))
		runSrv(";unbodycolor TargetPlr")

		runSrv(";crm TargetPlr 255,0,0 0.5 Neon")
		sert.eq(srvP2.Character.Head.Material, Enum.Material.Neon)
		runSrv(";uncrm TargetPlr")
		sert.eq(srvP2.Character.Head.Reflectance, 0)
		runSrv(";goldify TargetPlr")
		sert.eq(srvP2.Character.Head.Material, Enum.Material.Metal)
		runSrv(";shiny TargetPlr")
		sert.eq(srvP2.Character.Head.Reflectance, 1)
		runSrv(";silverify TargetPlr")
		sert.eq(srvP2.Character.Head.Material, Enum.Material.Metal)
		runSrv(";ungoldify TargetPlr")
		sert.eq(srvP2.Character.Head.Reflectance, 0)
		runSrv(";swagify TargetPlr")
		sert.ok((srvP2.Character:FindFirstChild("_KCape")))
		runSrv(";unswagify TargetPlr")
		sert.eq(srvP2.Character:FindFirstChild("_KCape"), nil)

		runSrv(";bundle TargetPlr 101")
		sert.ok((srvP2:FindFirstChild("_KHumanoidDescription")))
		runSrv(";unbundle TargetPlr")
		runSrv(";headless TargetPlr")
		sert.eq(srvP2.Character.Humanoid._props._description.Head, 15093053680)
		runSrv(";korblox TargetPlr")
		runSrv(";werewolf TargetPlr")
		runSrv(";vampire TargetPlr")

		-- Wings & Crown VIP commands with _KAlphaWings and SuperCrown instances
		srvP1:SetAttribute("_KDonationLevel", 4)
		c.ch1.env.Players.LocalPlayer:SetAttribute("_KDonationLevel", 4)
		local wings = c.sh.env.Instance.new("Accessory", srvP1.Character)
		wings.Name = "_KAlphaWings"
		local wingsPart = c.sh.env.Instance.new("Part", wings)
		wingsPart.Name = "Wings"
		local crown = c.sh.env.Instance.new("Accessory", srvP1.Character)
		crown.Name = "SuperCrown"
		local crownHandle = c.sh.env.Instance.new("Part", crown)
		crownHandle.Name = "Handle"
		c.sh.env.Instance.new("Fire", crownHandle).Name = "Fire"

		runCli(";wingscolor 255,0,0")
		runSrv(";wingscolor 255,0,0")
		c.world:run(0.05)
		sert.eq(wingsPart.Color, Color3.fromRGB(255, 0, 0))
		runCli(";rainbowwings")
		runSrv(";rainbowwings")
		sert.eq(wings:HasTag("_KAlphaWingsRainbow"), true)
		runCli(";crowncolor 255,215,0 0,0,0")
		runSrv(";crowncolor 255,215,0 0,0,0")
		c.world:run(0.05)
		sert.eq(crownHandle.Color, Color3.fromRGB(255, 215, 0))
		runCli(";rainbowcrown")
		runSrv(";rainbowcrown")
		sert.eq(crown:HasTag("_KSuperCrownRainbow"), true)

		-- === Fun.luau ===
		local lighting = c.sh.env.game:GetService("Lighting")
		runSrv(";disco")
		sert.ok(_K.Registry.commands.disco.env.id)
		runSrv(";undisco")
		sert.eq(_K.Registry.commands.disco.env.id, false)
		sert.ok(lighting.Ambient)

		for _, rigType in { Enum.HumanoidRigType.R15, Enum.HumanoidRigType.R6 } do
			buildCharacter(c.sh.env, srvP2, rigType)
			runSrv(";creeper TargetPlr")
			sert.ok((srvP2.Character:GetAttribute("_KCreeper")))
			runSrv(";uncreeper TargetPlr")
			sert.eq(srvP2.Character:GetAttribute("_KCreeper"), nil)
			runSrv(";dog TargetPlr")
			sert.ok((srvP2.Character:FindFirstChild("_KDogSeat")))
			runSrv(";undog TargetPlr")
			sert.eq(srvP2.Character:FindFirstChild("_KDogSeat"), nil)
		end

		buildCharacter(c.sh.env, srvP2, Enum.HumanoidRigType.R15)
		runSrv(";char TargetPlr 1")
		sert.eq(srvP2.CharacterAppearanceId, 1)
		runSrv(";unchar TargetPlr")
		sert.eq(srvP2.CharacterAppearanceId, 2)
		runSrv(";clone TargetPlr")
		sert.eq(#_K.cleanupCommands >= 1, true)

		runSrv(";jumpscare TargetPlr")
		runSrv(";jumpscare TargetPlr 1119705746 999999")
		runSrv(";jumpscare TargetPlr 1119705746 999999")
		sert.eq(
			_K.Registry.commands.play.run(
				{ _K = _K, env = _K.Registry.commands.play.env, from = 1, fromPlayer = srvP1 },
				10764744805
			),
			"Invalid audio asset."
		)
		sert.eq(
			_K.Registry.commands.play.run(
				{ _K = _K, env = _K.Registry.commands.play.env, from = 1, fromPlayer = srvP1 },
				10764744805
			),
			"Invalid audio asset."
		)
		sert.eq(
			_K.Registry.commands.jumpscare.run(
				{ _K = _K, env = _K.Registry.commands.jumpscare.env, from = 1, fromPlayer = srvP1 },
				{ srvP2 },
				nil,
				10764744805
			),
			"Invalid audio asset."
		)
		_K.Remote.Jumpscare:Fire(srvP1)
		c.world:run(0.05)

		runSrv(";glitch CreatorPlr 2")
		c.world:run(0.05)
		c.ch1.env.game:GetService("RunService").PreRender:Fire(0.016)
		runSrv(";unglitch CreatorPlr")
		c.world:run(0.05)

		local seizeThread = c.sh.env.task.spawn(function()
			runSrv(";seizure TargetPlr")
		end)
		c.world:run(0.05)
		sert.eq(srvP2.Character:GetAttribute("_KSeizure"), true)
		runSrv(";unseizure TargetPlr")
		sert.eq(srvP2.Character:GetAttribute("_KSeizure"), nil)
		c.sh.env.task.cancel(seizeThread)

		runSrv(";infect TargetPlr")
		sert.ok(_K.Registry.commands.infect.env.infected[srvP2.Character])
		-- Touching another character's HumanoidRootPart spreads infection
		srvP2.Character.Humanoid.Touched:Fire(srvP1.Character.HumanoidRootPart)
		sert.ok(_K.Registry.commands.infect.env.infected[srvP1.Character])
		runSrv(";normal TargetPlr")
		runSrv(";normal CreatorPlr")

		buildCharacter(c.sh.env, srvP1)
		buildCharacter(c.sh.env, srvP2)
		runSrv(";confuse CreatorPlr")
		c.world:run(0.05)
		runSrv(";unconfuse CreatorPlr")
		c.world:run(0.05)

		runSrv(";fling TargetPlr")
		sert.eq(srvP2.Character.HumanoidRootPart.AssemblyLinearVelocity.Magnitude > 0, true)
		runSrv(";loopfling TargetPlr")
		sert.eq(_K.Registry.commands.loopfling.env.flinging[srvP2.UserId], 1)
		c.world:run(0.05)
		runSrv(";unloopfling TargetPlr")
		sert.eq(_K.Registry.commands.loopfling.env.flinging[srvP2.UserId], nil)

		local poisonThread = c.sh.env.task.spawn(function()
			runSrv(";poison TargetPlr 10 1")
		end)
		c.world:run(0.9)
		c.sh.env.task.cancel(poisonThread)
		sert.eq(srvP2.Character.Humanoid.Health < 100, true)

		runSrv(";spin TargetPlr 1")
		sert.ok((srvP2.Character:FindFirstChild("_KSpin")))
		runSrv(";unspin TargetPlr")
		sert.eq(srvP2.Character:FindFirstChild("_KSpin"), nil)

		runSrv(";setgravity TargetPlr 0.5")
		sert.ok((srvP2.Character:FindFirstChild("_KGravityForce")))
		runSrv(";nograv TargetPlr")
		sert.ok((srvP2.Character:FindFirstChild("_KGravityForce")))
		runSrv(";ungravity TargetPlr")
		sert.eq(srvP2.Character:FindFirstChild("_KGravityForce"), nil)

		runSrv(";skydive TargetPlr 500")
		sert.eq(srvP2.Character:GetPivot().Position.Y > 100, true)
		runSrv(";trip CreatorPlr")
		c.world:run(0.05)
		sert.eq(c.ch1.env.Players.LocalPlayer.Character.Humanoid:GetState(), Enum.HumanoidStateType.FallingDown)
		runSrv(";size TargetPlr 1.5")
		sert.eq(srvP2.Character:GetScale(), 1.5)
		runSrv(";unsize TargetPlr 1")
		sert.eq(srvP2.Character:GetScale(), 1)

		runSrv(";slim TargetPlr")
		sert.eq(srvP2.Character.Humanoid:GetAttribute("_KSlim"), true)
		runSrv(";unslim TargetPlr")
		sert.eq(srvP2.Character.Humanoid:GetAttribute("_KSlim"), false)
		runSrv(";noobify TargetPlr")
		c.world:run(0.05)
		sert.ok((srvP2:FindFirstChild("_KHumanoidDescription")))

		-- Run slippery on CreatorPlr so both server command and client Slippery remote run on ch1
		runSrv(";slippery CreatorPlr")
		c.world:run(0.05)
		sert.ok((srvP1.Character.HumanoidRootPart:FindFirstChild("_K_Slippery")))
		_K.Registry.commands.slippery.run({ _K = _K, env = _K.Registry.commands.slippery.env, undo = true }, { srvP1 })
		_K.Remote.Slippery:Fire(srvP1, nil)
		c.world:run(0.05)
		sert.eq(srvP1.Character.HumanoidRootPart:FindFirstChild("_K_Slippery"), nil)

		local smiteThread = c.sh.env.task.spawn(function()
			runSrv(";smite TargetPlr")
		end)
		c.world:run(0.3)
		c.sh.env.task.cancel(smiteThread)
		buildCharacter(c.sh.env, srvP2)

		runSrv(";explode TargetPlr")
		sert.eq(srvP2.Character.Humanoid.Health, 0)
		buildCharacter(c.sh.env, srvP2)

		local rocketThread = c.sh.env.task.spawn(function()
			runSrv(";rocket TargetPlr")
		end)
		c.world:run(0.05)
		sert.ok((srvP2.Character:FindFirstChild("_KRocket")))
		c.sh.env.task.cancel(rocketThread)

		local nukeThread = c.sh.env.task.spawn(function()
			runSrv(";nuke TargetPlr")
		end)
		c.world:run(0.05)
		c.sh.env.task.cancel(nukeThread)

		buildCharacter(c.sh.env, srvP2)
		runSrv(";control TargetPlr")
		sert.eq(srvP1.Character, srvP2.Character)
		buildCharacter(c.sh.env, srvP1)
		buildCharacter(c.sh.env, srvP2)
	end)

	test(
		"loads DefaultAddons/Legacy.luau, migrates legacy settings and custom commands, and runs legacy role aliases",
		function()
			local c = createSimCluster(nil, true)
			local _K = c._K
			_K.setupPurchasables = function() end

			-- Stage a Config/Legacy hierarchy under sh.Shared to exercise full Legacy migration
			local configFolder = c.sh.env.Instance.new("Folder", c.sh.Shared)
			configFolder.Name = "Config"
			local legacyFolder = c.sh.env.Instance.new("Folder", configFolder)
			legacyFolder.Name = "Legacy"

			local settingsMod = c.sh.env.Instance.new("ModuleScript", legacyFolder)
			settingsMod.Name = "Settings"
			rawset(settingsMod, "_factory", function()
				return {
					{
						Prefix = ":",
						AdminCredit = false,
						CommandBar = false,
						JoinMessage = false,
						PublicLogs = true,
						FreeAdmin = 1,
						Permissions = {
							fly = 2,
						},
						GroupAdmin = {
							[100] = { [255] = 4 },
						},
						VIPAdmin = {
							[101] = 1,
							[-102] = 1,
						},
					},
					{
						{ "LegacyOwner", 500 },
						{ 400 },
						{ 300 },
						{ 200 },
						{ 100 },
						{ 50 },
					},
				}
			end)

			local customCmdsMod = c.sh.env.Instance.new("ModuleScript", legacyFolder)
			customCmdsMod.Name = "Custom_Commands"
			local customRan = false
			rawset(customCmdsMod, "_factory", function()
				return {
					{
						{ "legacyhello", "lhello" },
						{ "Test legacy custom command" },
						1,
						{ "player", "string/" },
						function(_fromPlr, _args)
							customRan = true
						end,
					},
				}
			end)

			local legacyAddon = c.sh.Shared.DefaultAddons:FindFirstChild("Legacy")
			c.sh.env:require(legacyAddon)(_K)
			c.world:run(0.3)

			-- Verify legacy settings migration
			sert.eq(_K.Data.defaultSettings.prefix[1], ":")
			sert.eq(_K.Auth.hasRole(500, "creator"), true)
			sert.eq(_K.Auth.hasRole(400, "superadmin"), true)
			sert.eq(_K.Auth.hasRole(300, "admin"), true)
			sert.eq(_K.Auth.hasRole(200, "mod"), true)
			sert.eq(_K.Auth.hasRole(100, "vip"), true)
			sert.ok(_K.Data.bans["50"])

			-- Verify legacy custom command registration & execution
			sert.ok(_K.Registry.commands.legacyhello)
			c.runSrv(":legacyhello TargetPlr Greetings")
			sert.eq(customRan, true)

			-- Verify legacy role commands (creator, superadmin, admin, mod, vip + temp* + un*)
			local legacyNotifies: { any } = {}
			local origLegacyNotify = _K.Remote.Notify.Fire
			_K.Remote.Notify.Fire = function(self: any, plr: any, msg: any)
				table.insert(legacyNotifies, { plr = plr, msg = msg })
				return origLegacyNotify(self, plr, msg)
			end
			for _, roleId in { "creator", "superadmin", "admin", "mod", "vip" } do
				table.clear(legacyNotifies)
				c.runSrv(`:temp{roleId} TargetPlr`)
				sert.eq(_K.Auth.hasRole(2, roleId), true)
				sert.eq(#legacyNotifies >= 1, true)
				table.clear(legacyNotifies)
				c.runSrv(`:un{roleId} TargetPlr`)
				sert.eq(_K.Auth.hasRole(2, roleId), false)
				sert.eq(#legacyNotifies >= 1, true)
				sert.eq(string.find(legacyNotifies[1].msg.Text, "TargetPlr", 1, true) ~= nil, true)
				-- Running un<role> when member does not have that role sends no notification
				table.clear(legacyNotifies)
				_K.Registry.commands["un" .. roleId].run({ _K = _K, from = 1, fromPlayer = c.srvP1 }, { "2" })
				sert.eq(#legacyNotifies, 0)
				c.runSrv(`:{roleId} TargetPlr`)
				sert.eq(_K.Auth.hasRole(2, roleId), true)
				c.runSrv(`:un{roleId} TargetPlr`)
				sert.eq(_K.Auth.hasRole(2, roleId), false)
			end
			-- Also test giving role to an offline userId so `if not player then continue` is verified
			table.clear(legacyNotifies)
			c.runSrv(":vip 777777")
			c.world:run(0.25)
			sert.eq(_K.Auth.hasRole(777777, "vip"), true)
			sert.eq(#legacyNotifies, 1)
			sert.eq(legacyNotifies[1].plr, c.srvP1)
		end
	)

	test(
		"Legacy addon validates custom command defs, lowercases/falls back args, guards Prefix/freeAdmin/role.commands",
		function()
			local function runLegacy(c: any, legacyFolder: Instance, settingsTbl: any, customCmdsTbl: any?)
				local prevSettings = legacyFolder:FindFirstChild("Settings")
				if prevSettings then
					prevSettings:Destroy()
				end
				local settingsMod = c.sh.env.Instance.new("ModuleScript", legacyFolder)
				settingsMod.Name = "Settings"
				rawset(settingsMod, "_factory", function()
					return { settingsTbl, {} }
				end)

				local prevCmds = legacyFolder:FindFirstChild("Custom_Commands")
				if prevCmds then
					prevCmds:Destroy()
				end
				if customCmdsTbl ~= nil then
					local cmdsMod = c.sh.env.Instance.new("ModuleScript", legacyFolder)
					cmdsMod.Name = "Custom_Commands"
					rawset(cmdsMod, "_factory", function()
						return customCmdsTbl
					end)
				end

				local warnings: { string } = {}
				local origWarn = c.sh.env.globals.warn
				c.sh.env.globals.warn = function(...: any)
					table.insert(warnings, table.concat({ ... }, " "))
				end
				c.sh.env:require(c.sh.Shared.DefaultAddons:FindFirstChild("Legacy"))(c._K)
				c.world:run(0.3)
				c.sh.env.globals.warn = origWarn
				return warnings
			end

			local function makeLegacyCluster(preSetup: ((any) -> ())?)
				local c = createSimCluster(nil, true)
				c._K.setupPurchasables = function() end
				if preSetup then
					preSetup(c._K)
				end
				local configFolder = c.sh.env.Instance.new("Folder", c.sh.Shared)
				configFolder.Name = "Config"
				local legacyFolder = c.sh.env.Instance.new("Folder", configFolder)
				legacyFolder.Name = "Legacy"
				return c, legacyFolder
			end

			-- Cluster 1: Invalid custom command defs, uppercase/unknown arg fallback, duplicate freeAdmin, and bad Prefix values
			local c1, f1 = makeLegacyCluster(function(_K)
				_K.Data.defaultSettings.prefix = { ";" }
				_K.Data.settings.freeAdmin = { "vip" }
			end)
			local w1 = runLegacy(c1, f1, { Prefix = 123, FreeAdmin = 1 }, {
				{ "not_a_table", "Bad aliases type", 1, {}, function() end },
				{ { 123 }, "Non-string alias[1]", 1, {}, function() end },
				{ { "legacy_nonfn" }, "Non-function run", 1, {}, "not_a_function" },
				{ { "legacy_good" }, "Valid cmd", 1, { "PLAYER", "WEIRD_ARG/" }, function() end },
			})
			sert.eq(#c1.world.scheduler.errors, 0)
			sert.eq(c1._K.Registry.commands.legacy_nonfn, nil)
			sert.eq(c1._K.Registry.commands.legacy_good ~= nil, true)
			sert.eq(c1._K.Registry.commands.legacy_good.args[1].type, "players")
			sert.eq(c1._K.Registry.commands.legacy_good.args[2].type, "rawString")
			sert.eq(c1._K.Registry.commands.legacy_good.args[2].optional ~= nil, true)
			sert.eq(#w1 >= 3, true)
			sert.eq(c1._K.Data.settings.freeAdmin, { "vip" })
			for _, badPrefix in { "", ";" } do
				runLegacy(c1, f1, { Prefix = badPrefix })
				sert.eq(c1._K.Data.defaultSettings.prefix[1], ";")
			end

			-- Cluster 2: Valid custom Prefix, non-table freeAdmin recovery, and nil role.commands initialization
			local c2, f2 = makeLegacyCluster(function(_K)
				_K.Data.settings.freeAdmin = "bad_non_table"
				_K.Data.roles.vip.commands = nil
				_K.Data.roles.mod.commands = { keep = true }
			end)
			runLegacy(c2, f2, { Prefix = "!", FreeAdmin = 1, Permissions = { fly = 2 } })
			sert.eq(#c2.world.scheduler.errors, 0)
			sert.eq(c2._K.Data.defaultSettings.prefix[1], "!")
			sert.eq(c2._K.Data.settings.freeAdmin, { "vip" })
			sert.eq(c2._K.Data.roles.vip.commands.fly, false)
			sert.eq(c2._K.Data.roles.mod.commands.keep, true)
			sert.eq(c2._K.Data.roles.mod.commands.fly, true)
		end
	)

	test("legacy role commands give unrestricted, unsaved roles unless the giver is a developer", function()
		local c = createSimCluster(nil, true)
		local _K = c._K
		_K.setupPurchasables = function() end
		c.sh.env:require(c.sh.Shared.DefaultAddons:FindFirstChild("Legacy"))(_K)
		c.world:run(0.3)

		local function runAs(from: number, raw: string)
			c.sh.env.task.spawn(function()
				_K.Process.runCommands(_K, from, raw)
			end)
			c.world:run(0.3)
		end

		-- TargetPlr bought Administrator, so it has banasync but no developer powers (timed bans)
		_K.Data.roles.admin.gamepasses = { 123 }
		_K.Data.roles.superadmin.gamepasses = { 124 }
		_K.Auth.userRoleAdd(2, "admin")
		sert.eq(_K.Auth.hasRestrictedRole(2), false)

		-- giving itself a lower role doesn't make it a developer
		runAs(2, ";tempmod me")
		local member = _K.Data.members["2"]
		sert.eq(table.find(member.roles, "mod") ~= nil, true)
		sert.eq(member.unrestricted and member.unrestricted.mod, true)
		sert.eq(_K.Auth.hasRestrictedRole(2), false)

		-- a bought SuperAdmin has saveRoles, but its ;mod only lasts the session
		_K.Auth.userRoleAdd(2, "superadmin")
		runAs(2, ";mod 777001")
		local given = _K.Data.members["777001"]
		sert.eq(table.find(given.roles, "mod") ~= nil, true)
		sert.eq(table.find(given.persist, "mod"), nil)
		sert.eq(given.unrestricted and given.unrestricted.mod, true)

		-- the developer still saves restricted roles
		runAs(1, ";mod 777002")
		local saved = _K.Data.members["777002"]
		sert.eq(table.find(saved.persist, "mod") ~= nil, true)
		sert.eq(saved.unrestricted, nil)
	end)

	test("a moderator's ;ban can't turn a saved ban into a server ban", function()
		local c = createSimCluster(nil, true)
		local _K = c._K
		_K.Auth.userRoleAdd(2, "mod")
		_K.Data.bans["777003"] = { "SavedBan", "Exploiting", -1, 1 }

		local notices = {}
		local origNotifyFire = _K.Remote.Notify.Fire
		_K.Remote.Notify.Fire = function(self: any, plr: any, msg: any)
			table.insert(notices, msg.Text)
			return origNotifyFire(self, plr, msg)
		end

		c.server:client(3, "OnlinePlr")
		c.world:run(0.1)
		local online = c.sh.env.Players:GetPlayerByUserId(3)
		online:SetAttribute("_KRolesLoaded", true)

		c.sh.env.task.spawn(function()
			_K.Process.runCommands(_K, 2, ";ban 777003,777004,3")
		end)
		c.world:run(0.3)
		sert.eq(_K.Data.bans["777003"][2], "Exploiting")
		sert.eq(_K.Data.bans["777003"][3], -1)
		sert.eq(_K.Data.bans["777004"] ~= nil, true)
		sert.eq(_K.Data.bans["3"] ~= nil, true)
		local kickedOnline = false
		for _, entry in c.server.kicks do
			if entry.player == online or entry.userId == online.UserId then
				kickedOnline = true
				break
			end
		end
		sert.eq(kickedOnline, true)

		-- the kept saved ban is reported apart from the new server bans
		local saved = _K.Util.getUserInfo(777003).Username
		local fresh = _K.Util.getUserInfo(777004).Username
		sert.eq(notices, {
			`Banned <b>{fresh}, {online.Name}</b> for <b>no reason</b>.\nDuration: <b>Server</b>\nKept saved ban for <b>{saved}</b>.`,
		})

		-- only kept saved bans: no "Banned" line
		table.clear(notices)
		c.sh.env.task.spawn(function()
			_K.Process.runCommands(_K, 2, ";ban 777003")
		end)
		c.world:run(0.3)
		sert.eq(notices, { `Kept saved ban for <b>{saved}</b>.` })
		_K.Remote.Notify.Fire = origNotifyFire
	end)

	test(";unban doesn't look up offline ranks, ;ban still does", function()
		local c = createSimCluster(nil, true)
		local _K = c._K
		_K.Auth.userRoleAdd(2, "mod")
		c.srvP2:SetAttribute("_KRolesLoaded", true)

		local gMethods = rawget(c.sh.env.game:GetService("GroupService"), "_methods")
		local mMethods = rawget(c.sh.env.game:GetService("MarketplaceService"), "_methods")
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
		-- every offline target is a group SuperAdmin
		_K.Data.async.group[5100] = { { rank = 200, roles = { "superadmin" } } }
		c.sh.env.groups[5100] = {
			ranks = { [777010] = 250, [777011] = 250, [777012] = 250, [777013] = 250 },
			Roles = {},
		}
		_K.Data.async.gamepass[558] = { "admin" }
		for _, userId in { "777010", "777011", "777012" } do
			_K.Data.bans[userId] = { `Banned{userId}`, "Exploiting", 0, 1 }
		end

		local function run(raw)
			c.sh.env.task.spawn(function()
				_K.Process.runCommands(_K, 2, raw)
			end)
			c.world:run(0.3)
		end

		run(";unban 777010")
		sert.eq(_K.Data.bans["777010"], nil)
		run(";unban all")
		sert.eq(_K.Data.bans["777011"], nil)
		sert.eq(_K.Data.bans["777012"], nil)
		sert.eq(webCalls, 0)

		run(";ban 777013")
		sert.eq(_K.Data.bans["777013"], nil)
		sert.eq(webCalls > 0, true)

		gMethods.GetGroupsAsync, mMethods.UserOwnsGamePassAsync = origGetGroups, origOwnsPass
	end)

	test("VIPUGCMethod only takes a color name, and UGC Methods only replace the wearer's accessory", function()
		local c = createSimCluster(nil, true)
		local _K, srvP1, srvP2 = c._K, c.srvP1, c.srvP2
		local env = c.sh.env
		srvP1:SetAttribute("_KDonationLevel", 3) -- owns every UGC effect, so each call reaches Method

		local function wear(className: string, name: string, character: any)
			local item = env.Instance.new(className)
			item.Name = name
			env.Instance.new("Part", item).Name = "Handle"
			item.Parent = character
			return item
		end
		wear("Tool", "VictimTool", srvP2.Character)
		local victimHat = wear("Accessory", "VictimHat", srvP2.Character)

		-- Instances sent over the remote are refused before any Method runs
		for _, name in { "VictimTool", "VictimHat" } do
			local target = srvP2.Character:FindFirstChild(name)
			_K.VIP.Effect(srvP1, 18966788838, "rbxassetid://18966762965", true, target)
			_K.VIP.Effect(srvP1, 133292294488871, "rbxassetid://89119211625300", true, target)
			sert.eq(srvP2.Character:FindFirstChild(name), target)
		end
		-- even the caller's own accessory, which the Methods would accept
		local ownHat = wear("Accessory", "OwnHat", srvP1.Character)
		_K.VIP.Effect(srvP1, 18966788838, "rbxassetid://18966762965", true, ownHat)
		sert.eq(srvP1.Character:FindFirstChild("OwnHat"), ownHat)
		ownHat:Destroy()
		sert.eq(srvP1.Character:FindFirstChild("SuperCrown"), nil)

		-- a color name still equips the effect
		_K.VIP.Effect(srvP1, 18966788838, "rbxassetid://18966762965", true, "gold")
		sert.ok((srvP1.Character:FindFirstChild("SuperCrown")))

		-- a non-number asset id or a non-boolean equip is ignored, so it can't unequip or touch the caches
		_K.VIP.Effect(srvP1, "18966788838", "rbxassetid://18966762965", false, "gold")
		_K.VIP.Effect(srvP1, { 18966788838 }, "rbxassetid://18966762965", false, "gold")
		_K.VIP.Effect(srvP1, 18966788838, "rbxassetid://18966762965", 0, "gold")
		_K.VIP.Effect(srvP1, 18966788838, "rbxassetid://18966762965", nil, "gold")
		sert.ok((srvP1.Character:FindFirstChild("SuperCrown")))
		sert.ok(_K.VIP.effects[1]["rbxassetid://18966762965"])

		-- equip = false (what the client sends to hide it) still unequips, and it equips again afterwards
		_K.VIP.Effect(srvP1, 18966788838, "rbxassetid://18966762965", false, "gold")
		sert.eq(srvP1.Character:FindFirstChild("SuperCrown"), nil)
		sert.eq(_K.VIP.effects[1]["rbxassetid://18966762965"], nil)
		_K.VIP.Effect(srvP1, 18966788838, "rbxassetid://18966762965", true, "gold")
		sert.ok((srvP1.Character:FindFirstChild("SuperCrown")))

		-- the Methods never destroy another character's accessory or a non-Accessory, and still replace the
		-- wearer's own accessory, with or without a Handle
		local ownTool = wear("Tool", "OwnTool", srvP1.Character)
		for _, module in { c.sh.Shared.VIP.UGC.Crown, c.sh.Shared.VIP.UGC.AlphaWings } do
			local ugc = env:require(module)
			sert.eq(ugc.Method(srvP1.Character, victimHat), nil)
			sert.eq(srvP2.Character:FindFirstChild("VictimHat"), victimHat)
			sert.eq(ugc.Method(srvP1.Character, ownTool), nil)
			sert.eq(srvP1.Character:FindFirstChild("OwnTool"), ownTool)
			wear("Accessory", "OwnHat", srvP1.Character)
			sert.ok((ugc.Method(srvP1.Character, srvP1.Character:FindFirstChild("OwnHat"))))
			sert.eq(srvP1.Character:FindFirstChild("OwnHat"), nil)
			local bareHat = env.Instance.new("Accessory", srvP1.Character)
			bareHat.Name = "BareHat"
			sert.ok((ugc.Method(srvP1.Character, bareHat)))
			sert.eq(srvP1.Character:FindFirstChild("BareHat"), nil)
		end
	end)

	test("VIP purchase signals only grant perks the player owns, even when ownership shows up late", function()
		local c = createSimCluster(nil, true)
		local _K, srvP2, world = c._K, c.srvP2, c.world
		local env = c.sh.env
		local market = env.game:GetService("MarketplaceService")
		local Title = env:require(c.sh.Shared.VIP.Title)
		local vip, hero = Title.definition.vip, Title.definition.hero
		srvP2:SetAttribute("_KDonationLevel", 0)

		-- each check by Shared/VIP counts, and the player owns the item from check number `ownedFrom` on
		local methods = rawget(market, "_methods")
		local checks, ownedFrom = { pass = 0, asset = 0, other = 0 }, math.huge
		local function check(kind: string, owner: any, id: number, expectedId: number): boolean
			local fromVIP = string.find(debug.info(3, "s"), "src/Shared/VIP/init", 1, true)
			if not (fromVIP and (owner == srvP2 or owner == 2)) then
				return false
			elseif id ~= expectedId then
				checks.other += 1
				return false
			end
			checks[kind] += 1
			return checks[kind] >= ownedFrom
		end
		methods.UserOwnsGamePassAsync = function(_self, userId, passId)
			return check("pass", userId, passId, 5411126)
		end
		methods.PlayerOwnsAssetAsync = function(_self, player, assetId)
			return check("asset", player, assetId, 129439770798699)
		end

		local function purchase(times: number?)
			for _ = 1, times or 1 do
				-- like the engine, run each handler in its own thread so the checks overlap
				env.task.spawn(
					market.PromptGamePassPurchaseFinished.Fire,
					market.PromptGamePassPurchaseFinished,
					srvP2,
					5411126,
					true
				)
				env.task.spawn(
					market.PromptPurchaseFinished.Fire,
					market.PromptPurchaseFinished,
					srvP2,
					129439770798699,
					true
				)
			end
			world:fastForward(10)
		end
		local function expectPerks(granted: boolean)
			sert.eq(srvP2:GetAttribute("_KDonationLevel"), if granted then 4 else 0)
			sert.eq(_K.Auth.hasRole(2, "vip"), granted)
			sert.eq(vip.ownerCache[2], if granted then true else nil)
			sert.eq(hero.ownerCache[2], if granted then true else nil)
		end

		-- fakes for ids KA grants nothing for are never checked
		market.PromptGamePassPurchaseFinished:Fire(srvP2, 123, true)
		market.PromptPurchaseFinished:Fire(srvP2, 456, true)
		world:fastForward(10)
		sert.eq(checks.other, 0)

		-- an exploit fakes both purchases twice at once: nothing is granted, only one check per id runs at a
		-- time and gives up after three tries, and a title it was already refused is checked again on next use
		hero.ownerCache[2] = false
		purchase(2)
		expectPerks(false)
		sert.eq(checks.pass, 3)
		sert.eq(checks.asset, 3)

		-- a real purchase that the ownership checks only see on the second try still grants every perk
		checks.pass, checks.asset, ownedFrom = 0, 0, 2
		purchase()
		expectPerks(true)
		sert.eq(checks.pass, 2)
		sert.eq(checks.asset, 2)
	end)

	test("exercises Shared/VIP modules (Title, Crown, AlphaWings, Bones, Animate, Popup, Purchasables)", function()
		local c = createSimCluster()
		local _K, clientK, srvP1 = c._K, c.clientK, c.srvP1
		local srvChar = srvP1.Character
		local cliRunService = c.ch1.env.game:GetService("RunService")

		-- 1. Title module (`Shared.VIP.Title`)
		local Title = c.sh.env:require(c.sh.Shared.VIP.Title)
		Title.Method(srvChar, "Patron", Color3.new(1, 0, 0), Color3.new(1, 1, 0), Enum.Font.Code)
		local titleGui = srvChar:FindFirstChild("_K_Title")
		sert.ok(titleGui)
		for _, defName in { "epic", "hero", "legend", "mythic", "eternal" } do
			local def = Title.definition[defName]
			local seq = def.getValue(1.5)
			sert.ok(seq)
			def.update(titleGui, seq)
			local seqBoundary = def.getValue(0)
			sert.ok(seqBoundary)
			for i = 2, #seqBoundary.Keypoints do
				sert.eq(seqBoundary.Keypoints[i].Time > seqBoundary.Keypoints[i - 1].Time, true)
			end
		end
		-- Remove title when title == nil
		Title.Method(srvChar, nil)
		sert.eq(srvChar:FindFirstChild("_K_Title"), nil)

		-- Client Title heartbeat loop
		local cliTitle = c.ch1.env:require(c.ch1.Shared.VIP.Title)
		local cliChar = c.ch1.env.Players.LocalPlayer.Character
		cliTitle.Method(cliChar, "eternal")
		local cliTitleGui = cliChar:FindFirstChild("_K_Title")
		if cliTitleGui then
			cliTitleGui._props.AbsoluteSize = _globals.Vector2.new(100, 30)
		end
		cliRunService.Heartbeat:Fire(0.016)

		-- 2. Crown module (`Shared.VIP.UGC.Crown`)
		local Crown = c.sh.env:require(c.sh.Shared.VIP.UGC.Crown)
		sert.eq(Crown.Name, "SuperCrown")
		local crownAcc = Crown.Method(srvChar, "gold")
		sert.ok(crownAcc)
		sert.eq(crownAcc.Name, "SuperCrown")
		local crownDark = Crown.Method(srvChar, "dark")
		sert.ok(crownDark)
		crownDark:Destroy()

		-- Client Crown heartbeat loop
		local cliCrown = c.ch1.env:require(c.ch1.Shared.VIP.UGC.Crown)
		local cliCrownAcc = cliCrown.Method(cliChar, "gold")
		cliCrownAcc:AddTag("_KSuperCrownRainbow")
		cliRunService.Heartbeat:Fire(0.016)
		cliCrownAcc:Destroy()

		-- 3. AlphaWings, Bones, and Animate (`Server.Bones` / `Server.Animate` moved out of replicated `Shared.VIP.UGC.AlphaWings`)
		local AlphaWings = c.sh.env:require(c.sh.Shared.VIP.UGC.AlphaWings)
		AlphaWings.detachServerAssets(c.sh.Server)
		sert.eq(c.sh.Shared.VIP.UGC.AlphaWings:FindFirstChild("Bones"), nil)
		sert.eq(c.sh.Shared.VIP.UGC.AlphaWings:FindFirstChild("Animate"), nil)
		local srvBones = c.sh.Server:FindFirstChild("Bones")
		sert.ok(srvBones)
		local Bones = c.sh.env:require(srvBones)
		sert.ok(Bones)
		sert.eq(AlphaWings.Name, "_KAlphaWings")
		local wingsAcc = AlphaWings.Method(srvChar, "gold")
		sert.ok(wingsAcc)
		sert.eq(wingsAcc.Name, "_KAlphaWings")
		if wingsAcc:FindFirstChild("Wings") then
			sert.ok(wingsAcc.Wings:FindFirstChild("Animate") ~= nil)
		end

		-- Client AlphaWings heartbeat loop without server-only Bones/Animate assets
		for _, serverOnlyName in { "Bones", "Animate" } do
			local child = c.ch1.Shared.VIP.UGC.AlphaWings:FindFirstChild(serverOnlyName)
			if child then
				child:Destroy()
			end
		end
		sert.eq(c.ch1.Shared.VIP.UGC.AlphaWings:FindFirstChild("Bones"), nil)
		sert.eq(c.ch1.Shared.VIP.UGC.AlphaWings:FindFirstChild("Animate"), nil)
		local cliWings = c.ch1.env:require(c.ch1.Shared.VIP.UGC.AlphaWings)
		local cliWingsAcc = cliWings.Method(cliChar, "dark")
		cliWingsAcc:AddTag("_KAlphaWingsRainbow")
		cliRunService.Heartbeat:Fire(0.016)

		-- Exercise Animate module (`Server.Animate.Animate`)
		local srvAnimate = c.sh.Server:FindFirstChild("Animate")
		sert.ok(srvAnimate)
		local Animate = c.sh.env:require(srvAnimate:FindFirstChild("Animate"))
		local idleSeq = c.sh.env.Instance.new("KeyframeSequence")
		local kf1 = c.sh.env.Instance.new("Keyframe", idleSeq)
		kf1.Time = 0
		local parentPose = c.sh.env.Instance.new("Pose", kf1)
		parentPose.Name = "LeftWingRig"
		local childPose = c.sh.env.Instance.new("Pose", parentPose)
		childPose.Name = "Wing1"
		childPose.CFrame = CFrame.Angles(0.1, 0, 0)
		childPose.EasingStyle = Enum.PoseEasingStyle.Linear
		childPose.EasingDirection = Enum.PoseEasingDirection.In
		local kf2 = c.sh.env.Instance.new("Keyframe", idleSeq)
		kf2.Time = 0.02
		rawset(idleSeq, "_methods", {
			GetKeyframes = function()
				return { kf1, kf2 }
			end,
		})
		if wingsAcc:FindFirstChild("Wings") then
			sert.ok((Animate.getBoneFromPose(wingsAcc.Wings, childPose)))
			local playThread = c.sh.env.task.spawn(function()
				Animate.play(wingsAcc.Wings, idleSeq, false)
			end)
			c.world:run(0.6)
			c.sh.env.task.cancel(playThread)
		end
		wingsAcc:Destroy()
		cliWingsAcc:Destroy()

		-- 4. Purchasables (`Shared.VIP.Purchasables`)
		local Purchasables = c.sh.env:require(c.sh.Shared.VIP.Purchasables)
		sert.eq(#Purchasables.donations, 11)
		sert.eq(#Purchasables.scriptedUGC, 6)
		sert.eq(#Purchasables.chatCommands, 8)

		-- 5. Popup (`Shared.VIP.Popup`) defers Frame construction until first Visible = true / PromptPurchaseVIP
		local srvPopup = c.sh.env:require(c.sh.Shared.VIP.Popup)
		sert.eq(srvPopup, false)
		sert.ok(clientK.VIP.popup)
		sert.eq(clientK.VIP.popup.Name, "VIP")
		sert.eq(clientK.VIP.popup:FindFirstChild("Frame"), nil)

		-- PromptPurchaseVIP opens and builds the popup when hidden, and View hides the popup while opening Commands
		clientK.VIP.popup.Visible = false
		clientK.PromptPurchaseVIP()
		sert.eq(clientK.VIP.popup.Visible, true)
		sert.ok(clientK.VIP.popup.Frame:FindFirstChild("Preview"))
		sert.eq(clientK.VIP.popup.Frame.BuyFrame.Favorite:IsA("ImageButton"), true)
		sert.eq(clientK.VIP.popup.Frame.BuyFrame.Favorite.Visible, true)
		clientK.VIP.popup.Visible = false
		clientK.PromptPurchaseVIP()
		sert.eq(clientK.VIP.popup.Visible, true)
		clientK.VIP.popup.Frame.BuyFrame.View.Activated:Fire()
		sert.eq(clientK.VIP.popup.Visible, false)
		sert.eq(clientK.client.dashboard.Commands._instance.Visible, true)
		sert.eq(clientK.VIP.popup.ZIndex, 9e8)

		-- Completing a bulk purchase for the 40% OFF asset (capital .Id) hides the popup and disables VIPNotification
		local cliMarket = c.ch1.env.game:GetService("MarketplaceService")
		clientK.VIP.popup.Visible = true
		cliMarket.PromptBulkPurchaseFinished:Fire(
			c.ch1.env.Players.LocalPlayer,
			Enum.MarketplaceBulkPurchasePromptStatus.Completed,
			{ Items = { { Id = "115444443724463", Status = Enum.MarketplaceItemPurchaseStatus.Success } } }
		)
		c.world:run(0.1)
		sert.eq(clientK.VIP.popup.Visible, false)

		-- 6. VIP purchase & receipt signals (`Shared.VIP.init`)
		local market = c.sh.env.game:GetService("MarketplaceService")
		market.PromptGamePassPurchaseFinished:Fire(srvP1, 5411126, true)
		market.PromptPurchaseFinished:Fire(srvP1, 129439770798699, true)
		clientK.Remote.VIPCheck:Fire(115444443724463)
		clientK.Remote.VIPCheck:Fire(129439770798699)
		_K.VIP.Effect(srvP1, 18966788838, "rbxassetid://18966762965", true, "Light Crown")
		_K.VIP.EffectHandler(srvChar)
		_K.VIP.Effect(srvP1, 18966788838, "rbxassetid://18966762965", false, "Light Crown")
		_K.VIP.Title(srvP1, "Hero")
		clientK.Remote.VIPCheck:Fire(110019084552349)
		clientK.Remote.PromptBulkPurchase:Fire(110019084552349)
		clientK.Remote.Title:Fire("Hero")
		c.world:run(0.1)

		-- Verify ;localscript parents script to each target player's PlayerGui (even when fromPlayer is nil)
		local p1Gui = srvP1:FindFirstChildOfClass("PlayerGui")
		local loadedParents: { Instance } = {}
		local origLoadScript = _K.LoadScript
		_K.LoadScript = function(src: string, mode: string, parent: Instance)
			table.insert(loadedParents, parent)
			return origLoadScript(src, mode, parent)
		end
		_K.Registry.commands.localscript.run({ _K = _K, fromPlayer = nil }, { srvP1 }, "local x = 1")
		_K.LoadScript = origLoadScript
		sert.eq(loadedParents, { p1Gui })

		-- Verify ;prefix / ;hotkeys reads Shift+ and Alt+ from mods:peek()
		clientK.client.hotkeys.commandBar.mods({ Shift = true, Alt = true })
		clientK.client.hotkeys.dashboard.mods({ Shift = true, Alt = false })
		_K.Registry.commands.prefix.runClient({ _K = clientK })
		sert.eq(string.find(clientK._lastNotify.Text, "Shift+Alt+", 1, true) ~= nil, true)
	end)

	test("disco tweens each client's Lighting at <= 1 Hz and honors KAH_NoFx and ReducedMotionEnabled", function()
		local c = createSimCluster()
		local _K, clientK, runSrv = c._K, c.clientK, c.runSrv
		local srvLighting = c.sh.env.game:GetService("Lighting")
		local cliLighting = c.ch1.env.game:GetService("Lighting")
		local cliGui = c.ch1.env.game:GetService("GuiService")
		local cliPlayer = c.ch1.env.Players.LocalPlayer
		local cliEnv = clientK.Registry.commands.disco.env
		local original = Color3.new(0.1, 0.2, 0.3)
		cliLighting.Ambient, cliLighting.FogColor = original, original

		-- the server only marks disco active, it never changes Lighting itself
		local srvAmbient = srvLighting.Ambient
		runSrv(";disco")
		c.world:run(0.05)
		sert.ok(_K.Registry.commands.disco.env.id)
		sert.eq(srvLighting:GetAttribute("_KDisco"), _K.Registry.commands.disco.env.id)
		c.world:run(2)
		sert.eq(srvLighting.Ambient, srvAmbient)

		-- the attribute replicates in Roblox, in the sim each peer has its own Lighting
		local tweens = {}
		local tween = c.ch1.env.game:GetService("TweenService")
		local tweenMethods = rawget(tween, "_methods")
		local origCreate = tweenMethods.Create
		tweenMethods.Create = function(self: any, target: any, info: any, goals: any)
			table.insert(tweens, { target = target, info = info, goals = goals })
			return origCreate(self, target, info, goals)
		end
		cliLighting:SetAttribute("_KDisco", 1)
		c.world:run(0.05)
		sert.eq(cliEnv.restore, { original, original })
		sert.eq(#tweens, 1)
		sert.eq(tweens[1].target, cliLighting)
		-- one color per tween of at least a second: luminance changes at <= 1 Hz, eased, never a hard jump
		sert.eq(tweens[1].info.Time >= 1, true)
		sert.eq(tweens[1].info.EasingStyle, Enum.EasingStyle.Sine)
		sert.eq(tweens[1].goals.Ambient, cliEnv.COLORS[1])
		sert.eq(tweens[1].goals.FogColor, cliEnv.COLORS[1])
		sert.ne(cliLighting.Ambient, cliEnv.COLORS[1])
		c.world:run(cliEnv.STEP)
		sert.eq(#tweens, 2)
		sert.eq(tweens[2].goals.Ambient, cliEnv.COLORS[2])
		-- the colors wrap around
		c.world:run(cliEnv.STEP * (#cliEnv.COLORS - 1))
		sert.eq(tweens[#tweens].goals.Ambient, cliEnv.COLORS[1])
		sert.eq(#tweens, #cliEnv.COLORS + 1)
		-- re-marking an active disco doesn't start a second loop
		cliLighting:SetAttribute("_KDisco", 2)
		c.world:run(0.05)
		sert.eq(#tweens, #cliEnv.COLORS + 1)

		-- opting out mid-effect stops the tweens and restores the player's lighting
		cliPlayer:SetAttribute("KAH_NoFx", true)
		c.world:run(0.05)
		sert.eq(cliEnv.running, false)
		sert.eq(cliEnv.tween, false)
		sert.eq(cliLighting.Ambient, original)
		sert.eq(cliLighting.FogColor, original)
		local count = #tweens
		c.world:run(cliEnv.STEP * 2)
		sert.eq(#tweens, count)
		-- a false attribute isn't an opt-out
		cliPlayer:SetAttribute("KAH_NoFx", false)
		c.world:run(0.05)
		sert.ok(cliEnv.running)
		sert.eq(#tweens, count + 1)

		cliGui.ReducedMotionEnabled = true
		c.world:run(0.05)
		sert.eq(cliEnv.running, false)
		sert.eq(cliLighting.Ambient, original)
		c.world:run(cliEnv.STEP * 2)
		sert.eq(#tweens, count + 1)
		cliGui.ReducedMotionEnabled = false
		c.world:run(0.05)
		sert.ok(cliEnv.running)

		-- undisco clears the mark, every client restores its lighting
		runSrv(";undisco")
		c.world:run(0.05)
		sert.eq(srvLighting:GetAttribute("_KDisco"), nil)
		sert.eq(_K.Registry.commands.disco.env.id, false)
		cliLighting:SetAttribute("_KDisco", nil)
		c.world:run(0.05)
		sert.eq(cliEnv.running, false)
		sert.eq(cliEnv.restore, false)
		sert.eq(cliLighting.Ambient, original)
		sert.eq(cliLighting.FogColor, original)
		count = #tweens
		c.world:run(cliEnv.STEP * 2)
		sert.eq(#tweens, count)

		-- a player who opted out before disco started never gets it
		cliPlayer:SetAttribute("KAH_NoFx", "yes")
		cliLighting:SetAttribute("_KDisco", 3)
		c.world:run(cliEnv.STEP * 2)
		sert.eq(#tweens, count)
		sert.eq(cliEnv.restore, false)
		sert.eq(cliLighting.Ambient, original)
	end)

	test("registers and runs ExampleAddon, ExampleAddonClient, and ExampleAddonServer", function()
		local c = createSimCluster()
		local _K, clientK = c._K, c.clientK
		local ExampleAddon = require("../../model/Config/addons/src/ExampleAddon")
		local ExampleAddonClient = require("../../model/Config/addons/src/ExampleAddonClient")
		local ExampleAddonServer = require("../../model/Config/addons/src/ExampleAddonServer")

		ExampleAddon(_K)
		ExampleAddon(clientK)
		ExampleAddonClient(clientK)
		ExampleAddonServer(_K)

		local customcommand = _K.Registry.commands.customcommand
		sert.ok(customcommand)
		setfenv(customcommand.run, c.sh.env.globals)
		local srvEnv = customcommand.env
		local cliEnv = clientK.Registry.commands.customcommand.env
		sert.eq(srvEnv.countServer, 0)
		sert.eq(cliEnv.countClient, 0)

		customcommand.run({ _K = _K, env = srvEnv, from = 1 }, nil)
		sert.eq(srvEnv.countServer, 1)
		customcommand.runClient({ _K = clientK, env = cliEnv, from = 1 }, "hello")
		sert.eq(cliEnv.countClient, 1)
	end)

	test("cleans up toolban, spectate, control, and re-infect state on PlayerRemoving and re-run", function()
		local c = createSimCluster()
		local _K, srvP1, srvP2 = c._K, c.srvP1, c.srvP2
		local runSrv = c.runSrv

		-- Re-infecting the same character reuses the existing Touched connection without overwriting/leaking it
		buildCharacter(c.sh.env, srvP2)
		runSrv(";infect TargetPlr")
		local firstInfectConn = _K.Registry.commands.infect.env.infected[srvP2.Character]
		sert.ok(firstInfectConn)
		sert.eq(firstInfectConn.Connected, true)
		runSrv(";infect TargetPlr")
		sert.eq(_K.Registry.commands.infect.env.infected[srvP2.Character], firstInfectConn)
		sert.eq(firstInfectConn.Connected, true)

		-- Target PlayerRemoving disconnects and clears toolban and control state
		runSrv(";toolban TargetPlr")
		local toolBanConn = _K.Registry.commands.toolban.env.bans[srvP2]
		sert.ok(toolBanConn)
		sert.eq(toolBanConn.Connected, true)

		buildCharacter(c.sh.env, srvP2)
		runSrv(";control TargetPlr")
		local targetControlConn = _K.Registry.commands.control.env.connections[srvP2]
		sert.ok(targetControlConn)
		sert.eq(targetControlConn.Connected, true)

		_K.Service.Players.PlayerRemoving:Fire(srvP2)
		c.world:run(0.05)
		sert.eq(toolBanConn.Connected, false)
		sert.eq(_K.Registry.commands.toolban.env.bans[srvP2], nil)
		sert.eq(targetControlConn.Connected, false)
		sert.eq(_K.Registry.commands.control.env.connections[srvP2], nil)
		sert.eq(_K.Registry.commands.control.env.controllers[srvP2], nil)

		-- Spectator / controller PlayerRemoving cleans up spectate subject entry and pending control connection
		buildCharacter(c.sh.env, srvP1)
		buildCharacter(c.sh.env, srvP2)
		runSrv(";spectate TargetPlr")
		sert.ok(_K.Registry.commands.spectate.env.spectators[srvP2])
		runSrv(";control TargetPlr")
		local ctrlConnByController = _K.Registry.commands.control.env.connections[srvP2]
		sert.ok(ctrlConnByController)
		sert.eq(ctrlConnByController.Connected, true)

		_K.Service.Players.PlayerRemoving:Fire(srvP1)
		c.world:run(0.05)
		sert.eq(_K.Registry.commands.spectate.env.spectators[srvP2], nil)
		sert.eq(ctrlConnByController.Connected, false)
		sert.eq(_K.Registry.commands.control.env.connections[srvP2], nil)
		sert.eq(_K.Registry.commands.control.env.controllers[srvP2], nil)
	end)

	test("VIP.ownsDonation targets requested pass, caches negative checks, and clears cache on purchase", function()
		local c = createSimCluster()
		local _K, srvP1, srvP2, world = c._K, c.srvP1, c.srvP2, c.world
		local market = c.sh.env.game:GetService("MarketplaceService")
		local methods = rawget(market, "_methods")
		srvP1:SetAttribute("_KDonationLevel", 0)
		srvP2:SetAttribute("_KDonationLevel", 0)

		local calls = 0
		local ownsTip = false
		methods.UserOwnsGamePassAsync = function()
			calls += 1
			return ownsTip
		end
		methods.PlayerOwnsAssetAsync = function()
			calls += 1
			return false
		end

		sert.eq(_K.VIP.ownsDonation(srvP2, "NotARealPass"), false)
		sert.eq(calls, 0)
		sert.eq(_K.VIP.ownsDonation(srvP2, "Tip"), false)
		sert.eq(calls, 2)
		-- Second check within 30s uses negative cache
		sert.eq(_K.VIP.ownsDonation(srvP2, "Tip"), false)
		sert.eq(calls, 2)

		-- Real purchase clears negative cache immediately and grants access
		ownsTip = true
		c.sh.env.task.spawn(
			market.PromptGamePassPurchaseFinished.Fire,
			market.PromptGamePassPurchaseFinished,
			srvP2,
			5391355,
			true
		)
		world:fastForward(10)
		sert.eq(_K.VIP.ownsDonation(srvP2, "Tip"), true)
		sert.eq(_K.VIP.ownsDonation(srvP2, nil), true)

		-- Non-donor client firing Remote.DonorTrail with non-owned pass does not create a _KParticleEffect
		ownsTip = false
		local trailChar = buildCharacter(c.sh.env, srvP1)
		local trailRoot = trailChar:FindFirstChild("HumanoidRootPart")
		c.clientK.Remote.DonorTrail:Fire("Tip")
		world:run(0.1)
		sert.eq(trailRoot and trailRoot:FindFirstChild("_KParticleEffect"), nil)

		-- Setting _KDonationLevel >= 1 bypasses Marketplace lookups and equips _KParticleEffect
		srvP1:SetAttribute("_KDonationLevel", 1)
		local beforeCalls = calls
		sert.eq(_K.VIP.ownsDonation(srvP1, "Gift"), true)
		sert.eq(calls, beforeCalls)
		c.clientK.Remote.DonorTrail:Fire("Tip")
		world:run(0.1)
		sert.eq(trailRoot and trailRoot:FindFirstChild("_KParticleEffect") ~= nil, true)
	end)

	test(
		"showfps.env.getFPS coalesces concurrent calls, handles timeout/PlayerRemoving, and spectate guards post-unspectate Humanoid",
		function()
			local c = createSimCluster()
			local _K, srvP1, srvP2, world = c._K, c.srvP1, c.srvP2, c.world
			local getFPS = _K.Registry.commands.showfps.env.getFPS

			-- Concurrent calls for connected client coalesce into a single Remote.ShowFPS request
			local origClientFire = c.clientK.Remote.ShowFPS.Fire
			c.clientK.Remote.ShowFPS.Fire = function(selfRemote, ...)
				local args = table.pack(...)
				c.ch1.env.task.delay(0.03, function()
					origClientFire(selfRemote, table.unpack(args, 1, args.n))
				end)
			end
			local firesToP1 = 0
			local origFire = _K.Remote.ShowFPS.Fire
			_K.Remote.ShowFPS.Fire = function(selfRemote, player, ...)
				if player == srvP1 then
					firesToP1 += 1
				end
				return origFire(selfRemote, player, ...)
			end
			local fpsA, fpsB
			c.sh.env.task.spawn(function()
				fpsA = getFPS(srvP1, 0.2)
			end)
			c.sh.env.task.spawn(function()
				fpsB = getFPS(srvP1, 0.2)
			end)
			world:run(0.15)
			_K.Remote.ShowFPS.Fire = origFire
			c.clientK.Remote.ShowFPS.Fire = origClientFire
			sert.eq(firesToP1, 1)
			sert.eq(type(fpsA), "number")
			sert.eq(fpsA, fpsB)

			-- Unsolicited client ShowFPS reply does not error
			c.clientK.Remote.ShowFPS:Fire(999)
			world:run(0.05)

			-- Unresponsive player resolves to 0 on timeout
			local timedOutFps = -1
			c.sh.env.task.spawn(function()
				timedOutFps = getFPS(srvP2, 0.05)
			end)
			world:run(0.1)
			sert.eq(timedOutFps, 0)

			-- Pending request resolves immediately to 0 on PlayerRemoving
			local removedFps = -1
			c.sh.env.task.spawn(function()
				removedFps = getFPS(srvP2, 5)
			end)
			world:run(0.02)
			_K.Service.Players.PlayerRemoving:Fire(srvP2)
			world:run(0.02)
			sert.eq(removedFps, 0)

			-- Spectate: unspectate before WaitForChild("Humanoid") resolves does not re-attach subject
			local bareChar = c.sh.env.Instance.new("Model", c.sh.env.workspace)
			bareChar.Name = "BareTarget"
			srvP2.Character = bareChar
			local specEnv = _K.Registry.commands.spectate.env
			c.sh.env.task.spawn(function()
				_K.Registry.commands.spectate.run({ _K = _K, from = 1, fromPlayer = srvP1, env = specEnv }, { srvP2 })
			end)
			world:run(0.02)
			_K.Registry.commands.unspectate.run({ _K = _K, from = 1, fromPlayer = srvP1, env = specEnv })
			local delayedHum = c.sh.env.Instance.new("Humanoid", bareChar)
			world:run(0.1)
			sert.eq(specEnv.currentSubject, nil)
			sert.eq(specEnv.spectators[srvP2], nil)
			sert.eq(delayedHum ~= nil, true)
		end
	)
end)

do
	return {}
end
