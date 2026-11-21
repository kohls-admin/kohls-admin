--!nocheck
local CommandHarness = require("./CommandHarness")
local Harness = require("./Harness")
local sert = require("../sert")

local describe, test = sert.describe, sert.test

local _globals = Harness.globals
local CFrame = _globals.CFrame
local Color3 = _globals.Color3
local Enum = _globals.Enum

local buildCharacter = CommandHarness.buildCharacter
local createSimCluster = CommandHarness.createSimCluster
local clusteringUtf8 = CommandHarness.clusteringUtf8

describe("DefaultCommands", function()
	describe("Process · SuperAdmin ;global", function()
		test(";global doesn't publish the raw token of a skipped optional argument", function()
			local c = createSimCluster(nil, true)
			local _K = c._K
			_K.Util.String.filterForBroadcast = function()
				return "Filtered"
			end
			local published = {}
			c._K.Data.subscribeTopic("global", function(message)
				table.insert(published, message.Data[2])
			end)

			-- "Raw" isn't a delay, so the reason takes it again and only the reason is filtered
			c.runSrv(';global shutdown "Raw" text')
			c.world:run(0.1)
			sert.eq(published[1], ';shutdown "Filtered"')
			sert.eq(string.find(tostring(c.srvP2._props._kicked), "Raw", 1, true), nil)
			sert.eq(string.find(tostring(c.srvP2._props._kicked), "Reason: Filtered", 1, true) ~= nil, true)

			-- an optional argument that took its token is still published
			c.world:fastForward(61)
			c.runSrv(";global shutdown 0 text")
			c.world:run(0.1)
			sert.eq(published[2], ';shutdown 0 "Filtered"')
		end)

		test(";global always quotes text so receiving servers can't read commands out of it", function()
			local c = createSimCluster(nil, true)
			local _K = c._K
			local filterResult
			_K.Util.String.filterForBroadcast = function(text)
				return filterResult or text
			end
			local published = {}
			c._K.Data.subscribeTopic("global", function(message)
				table.insert(published, message.Data[2])
			end)
			local received, voted = {}, false
			_K.Registry.commands.message.run = function(_context, message)
				table.insert(received, message)
			end
			_K.Registry.commands.vote.run = function()
				voted = true
			end
			local function runGlobal(commandString: string)
				c.world:fastForward(61) -- past the broadcast cooldown
				c.runSrv(commandString)
				c.world:run(0.5)
			end

			-- the last text argument of a single command used to be published unquoted and ran as two commands
			runGlobal(';global m "x ;vote all question"')
			sert.eq(published[1], ';m "x ;vote all question"')
			sert.eq(received, { "x ;vote all question" })
			sert.eq(voted, false)

			-- text holding a double quote takes backticks, quotes have no escapes
			runGlobal(';global `m "say ;vote all" now`')
			sert.eq(published[2], ';m `say ;vote all" now`')
			sert.eq(received[2], 'say ;vote all" now')

			-- text holding both quotes keeps the double quotes and loses the backticks
			filterResult = 'a "b" `c` ;vote all q'
			runGlobal(";global m text")
			sert.eq(published[3], ";m `a \"b\" 'c' ;vote all q`")
			sert.eq(received[3], "a \"b\" 'c' ;vote all q")
			sert.eq(voted, false)
			filterResult = nil

			-- commands without text are published as before
			runGlobal(";global gravity 80")
			sert.eq(published[4], ";gravity 80")
			sert.eq(c.sh.env.workspace.Gravity, 80)
		end)

		test(";global text arguments of every text type reach receiving servers without their quotes", function()
			local c = createSimCluster(nil, true)
			local _K = c._K
			_K.Util.String.filterForBroadcast = function(text)
				return text
			end
			local published = {}
			c._K.Data.subscribeTopic("global", function(message)
				table.insert(published, message.Data[2])
			end)
			local received = {}
			for _, argType in { "string", "strings", "chatString", "stringGreedy" } do
				_K.Registry.registerCommand(_K, {
					name = "global" .. argType,
					description = "Records its text",
					group = "superadmin",
					args = { { type = argType, name = "Text", description = "The text." } },
					run = function(_context, text)
						received[argType] = text
					end,
				})
			end
			c.world:run(0.1)

			for i, argType in { "string", "strings", "chatString", "stringGreedy" } do
				c.world:fastForward(61)
				c.runSrv(`;global global{argType} "x ;vote all q"`)
				c.world:run(0.5)
				sert.eq(published[i], `;global{string.lower(argType)} "x ;vote all q"`)
			end
			sert.eq(received, {
				string = "x ;vote all q",
				strings = { "x ;vote all q" },
				chatString = "x ;vote all q",
				stringGreedy = "x ;vote all q",
			})

			-- a list is quoted per item so receivers get the same items, text that isn't a list keeps its commas
			c.world:fastForward(61)
			c.runSrv(';global globalstrings a,"b, ;vote all q",c')
			c.world:run(0.5)
			sert.eq(published[5], ';globalstrings "a","b, ;vote all q","c"')
			sert.eq(received.strings, { "a", "b, ;vote all q", "c" })
			c.world:fastForward(61)
			c.runSrv(";global globalstring a,b")
			c.world:run(0.5)
			sert.eq(published[6], ';globalstring "a,b"')
			sert.eq(received.string, "a,b")
		end)

		test(";global change publishes the leaderstat value quoted and receivers still apply it", function()
			local c = createSimCluster(nil, true)
			local _K = c._K
			_K.Util.String.filterForBroadcast = function(text)
				return text
			end
			local published = {}
			c._K.Data.subscribeTopic("global", function(message)
				table.insert(published, message.Data[2])
			end)
			local leaderstats = c.sh.env.Instance.new("Folder", c.srvP2)
			leaderstats.Name = "leaderstats"
			local coins = c.sh.env.Instance.new("IntValue", leaderstats)
			coins.Name = "Coins"

			c.runSrv(";global change TargetPlr Coins 5")
			c.world:run(0.5)
			sert.eq(published[1], ';change TargetPlr Coins "5"')
			sert.eq(coins.Value, 5)
		end)

		test(";global receivers only parse the server prefix, not the sender's own prefix inside the text", function()
			local c = createSimCluster(nil, true)
			local _K = c._K
			_K.Util.String.filterForBroadcast = function(text)
				return text
			end
			local published = {}
			c._K.Data.subscribeTopic("global", function(message)
				table.insert(published, message.Data[2])
			end)
			local received = {}
			_K.Registry.commands.message.run = function(_context, message)
				table.insert(received, message)
			end
			_K.Data.playerPrefix[1] = "!"
			local gravity = c.sh.env.workspace.Gravity

			c.runSrv('!global m "hello !gravity 33 !m z"')
			c.world:run(0.5)
			sert.eq(published[1], ';m "hello !gravity 33 !m z"')
			sert.eq(received, { "hello !gravity 33 !m z" })
			sert.eq(c.sh.env.workspace.Gravity, gravity)
		end)

		test(";global refuses command strings that receiving servers would parse differently", function()
			local c = createSimCluster(nil, true)
			local _K = c._K
			local filterResult
			_K.Util.String.filterForBroadcast = function(text)
				return filterResult or text
			end
			local published = {}
			c._K.Data.subscribeTopic("global", function(message)
				table.insert(published, message.Data[2])
			end)
			local gravity = c.sh.env.workspace.Gravity
			local notices = {}
			local origNotifyFire = _K.Remote.Notify.Fire
			_K.Remote.Notify.Fire = function(self, player, data)
				table.insert(notices, data.Text)
				return origNotifyFire(self, player, data)
			end

			-- the sender's prefix leaves ";gravity" as the time argument, receiving servers would split it off
			_K.Data.playerPrefix[1] = "!"
			c.runSrv("!global time ;gravity 33")
			c.world:run(0.5)
			sert.eq(#published, 0)
			sert.eq(c.sh.env.workspace.Gravity, gravity)
			sert.eq(
				string.find(tostring(notices[1]), "would parse this command string differently", 1, true) ~= nil,
				true
			)

			-- or opens a quote there that swallows the next command while keeping the command count
			local voted = false
			_K.Registry.commands.vote.run = function()
				voted = true
			end
			c.runSrv('!global `time ;" ;vote all q" !gravity 33`')
			c.world:run(0.5)
			sert.eq(#published, 0)
			sert.eq(voted, false)
			sert.eq(c.sh.env.workspace.Gravity, gravity)
			_K.Data.playerPrefix[1] = nil

			-- the same text parses back while graphemes keep the quote apart
			filterResult = '\u{301}x"q" ;gravity 33 ;m z'
			c.world:fastForward(61)
			c.runSrv(";global m text")
			c.world:run(0.5)
			sert.eq(published[1], ';m `\u{301}x"q" ;gravity 33 ;m z`')
			sert.eq(c.sh.env.workspace.Gravity, gravity)
			_K.Remote.Notify.Fire = origNotifyFire

			-- in Roblox a combining mark after the opening quote joins its grapheme, so the quote isn't read as one
			c = createSimCluster({ utf8 = clusteringUtf8() }, true)
			filterResult = '\u{301}x"q" ;gravity 33 ;m z'
			c._K.Util.String.filterForBroadcast = function()
				return filterResult
			end
			table.clear(published)
			c._K.Data.subscribeTopic("global", function(message)
				table.insert(published, message.Data[2])
			end)
			c.runSrv(";global m text")
			c.world:run(0.5)
			sert.eq(c.sh.env.workspace.Gravity, gravity)
			sert.eq(#published, 0)

			-- or text that splits into the next argument without adding a command
			c._K.Registry.registerCommand(c._K, {
				name = "globalpair",
				description = "Records its text and number",
				group = "superadmin",
				args = {
					{ type = "string", name = "Text", description = "The text." },
					{ type = "number", name = "Number", description = "The number." },
				},
				run = function() end,
			})
			c.world:run(0.1)
			filterResult = '\u{301}x"q" 7'
			c.world:fastForward(61)
			c.runSrv(';global globalpair "text" 5')
			c.world:run(0.5)
			sert.eq(#published, 0)

			-- or a list item whose opening quote joins its grapheme, so receivers split it at its comma
			c._K.Registry.registerCommand(c._K, {
				name = "globallist",
				description = "Records its items",
				group = "superadmin",
				args = { { type = "strings", name = "Items", description = "The items." } },
				run = function() end,
			})
			c.world:run(0.1)
			filterResult = "\u{301}a,b"
			c.world:fastForward(61)
			c.runSrv(";global globallist text")
			c.world:run(0.5)
			sert.eq(#published, 0)
			-- text that isn't a list isn't split there
			c.world:fastForward(61)
			c.runSrv(";global m text")
			c.world:run(0.5)
			sert.eq(published[1], ';m "\u{301}a,b"')
		end)

		test(";global keeps a skipped optional argument skipped when the text starts with its type", function()
			local c = createSimCluster(nil, true)
			local _K = c._K
			_K.Util.String.filterForBroadcast = function(text)
				return text
			end
			local published = {}
			c._K.Data.subscribeTopic("global", function(message)
				table.insert(published, message.Data[2])
			end)

			-- "3 strikes" isn't a duration, so receiving servers must not read its "3" as one
			c.runSrv(';global ban 777005 "3 strikes"')
			c.world:run(1)
			sert.eq(published[1], ';ban 777005 "3 strikes"')
			local ban = _K.Data.bans["777005"]
			sert.eq(ban ~= nil, true)
			sert.eq(ban[2], "3 strikes")
			sert.eq(ban[3], nil) -- a server ban, not a 3 second one

			-- nor find "5 days" in the quoted reason and ban for 5 days
			c.world:fastForward(61) -- past the broadcast cooldown
			c.runSrv(";global ban 777006 appeal in 5 days")
			c.world:run(1)
			sert.eq(published[2], ';ban 777006 "appeal in 5 days"')
			ban = _K.Data.bans["777006"]
			sert.eq(ban ~= nil, true)
			sert.eq(ban[2], "appeal in 5 days")
			sert.eq(ban[3], nil)
		end)

		test(";global refuses strings where receivers bind arguments differently or cut them", function()
			local c = createSimCluster(nil, true)
			local _K = c._K
			local filterResult
			_K.Util.String.filterForBroadcast = function(text)
				return filterResult or text
			end
			local published = {}
			c._K.Data.subscribeTopic("global", function(message)
				table.insert(published, message.Data[2])
			end)
			local notices = {}
			local origNotifyFire = _K.Remote.Notify.Fire
			_K.Remote.Notify.Fire = function(self, player, data)
				table.insert(notices, data.Text)
				return origNotifyFire(self, player, data)
			end
			local function runGlobal(commandString: string)
				c.world:fastForward(61) -- past the broadcast cooldown
				c.runSrv(commandString)
				c.world:run(1)
			end

			-- a quote after the sender's prefix in a raw token opens a quote on receivers and drops a token
			_K.Data.playerPrefix[1] = "!"
			runGlobal('!global change all !"coins 5')
			sert.eq(#published, 0)
			sert.eq(
				string.find(tostring(notices[#notices]), "would parse this command string differently", 1, true) ~= nil,
				true
			)
			_K.Data.playerPrefix[1] = nil

			-- receivers cut command strings past 1024 bytes from users without a restricted role
			local hasRestrictedRole = _K.Auth.hasRestrictedRole
			_K.Auth.hasRestrictedRole = function()
				return false
			end
			filterResult = string.rep("a", 1020)
			runGlobal(";global m text")
			sert.eq(#published, 0)
			sert.eq(string.find(tostring(notices[#notices]), "too long to run globally", 1, true) ~= nil, true)
			_K.Auth.hasRestrictedRole = hasRestrictedRole
			runGlobal(";global m text")
			sert.eq(#published, 1)
			_K.Remote.Notify.Fire = origNotifyFire
		end)

		test(
			";global refuses strings receivers would parse differently before they spend the announcement cooldown",
			function()
				local c = createSimCluster({ utf8 = clusteringUtf8() }, true)
				local _K = c._K
				local filterResult
				_K.Util.String.filterForBroadcast = function(text)
					return filterResult or text
				end
				local published = {}
				c._K.Data.subscribeTopic("global", function(message)
					table.insert(published, message.Data[2])
				end)
				local notices = {}
				local origNotifyFire = _K.Remote.Notify.Fire
				_K.Remote.Notify.Fire = function(self, player, data)
					table.insert(notices, data.Text)
					return origNotifyFire(self, player, data)
				end
				local function refused()
					return string.find(
						tostring(notices[#notices]),
						"would parse this command string differently",
						1,
						true
					) ~= nil
				end

				-- the text as typed already splits differently on receivers
				_K.Data.playerPrefix[1] = "!"
				c.runSrv('!global change all !"coins 5')
				c.world:run(1)
				sert.eq(refused(), true)
				_K.Data.playerPrefix[1] = nil

				-- and a string too long for receivers, once each list item is quoted
				_K.Registry.registerCommand(_K, {
					name = "globalitems",
					description = "Takes items",
					group = "superadmin",
					args = { { type = "strings", name = "Items", description = "The items." } },
					run = function() end,
				})
				c.world:run(0.1)
				local hasRestrictedRole = _K.Auth.hasRestrictedRole
				_K.Auth.hasRestrictedRole = function()
					return false
				end
				c.runSrv(";global globalitems " .. string.rep("a,", 299) .. "a")
				c.world:run(1)
				sert.eq(string.find(tostring(notices[#notices]), "too long to run globally", 1, true) ~= nil, true)
				_K.Auth.hasRestrictedRole = hasRestrictedRole
				sert.eq(#published, 0)

				-- so the next announcement doesn't wait for the cooldown
				c.runSrv(";announce Hello world")
				c.world:run(0.5)
				sert.eq(_K.Data.savedSettings.announcement[1], "Hello world")

				-- filtered text that starts with a combining mark is still refused, after the cooldown it spends
				filterResult = '\u{301}x"q" ;gravity 33 ;m z'
				local gravity = c.sh.env.workspace.Gravity
				c.world:fastForward(61)
				c.runSrv(";global m text")
				c.world:run(0.5)
				sert.eq(refused(), true)
				sert.eq(#published, 0)
				sert.eq(c.sh.env.workspace.Gravity, gravity)
				filterResult = nil
				c.runSrv(";global m text")
				c.world:run(0.5)
				sert.eq(string.find(tostring(notices[#notices]), "before using this again", 1, true) ~= nil, true)
				sert.eq(#published, 0)
				_K.Remote.Notify.Fire = origNotifyFire
			end
		)
	end)

	test(";whois shows ? for a Platform or SessionStart the server dropped", function()
		local c = createSimCluster()
		local _K, clientK, srvP1, world = c._K, c.clientK, c.srvP1, c.world
		clientK.Remote.ShowFPS.OnClientInvoke = function()
			return 60
		end
		local sent
		local origFire = _K.Remote.Notify.Fire
		_K.Remote.Notify.Fire = function(self, player, data)
			sent = data
			return origFire(self, player, data)
		end
		local function whois(): string
			sent = nil
			c.runSrv(";whois CreatorPlr")
			world:run(1)
			return sent and sent.Text
		end

		-- Remote.Init leaves these unset when a client sends bad values
		srvP1:SetAttribute("_KPlatform", nil)
		srvP1:SetAttribute("_KSessionStart", nil)
		local text = whois()
		sert.eq(string.find(text, "<b>Platform:</b> ?\n", 1, true) ~= nil, true)
		sert.eq(string.find(text, "<b>Session:</b> ?\n", 1, true) ~= nil, true)

		srvP1:SetAttribute("_KPlatform", "PC")
		srvP1:SetAttribute("_KSessionStart", c.sh.env.workspace:GetServerTimeNow() - 120)
		text = whois()
		sert.eq(string.find(text, "<b>Platform:</b> 🖥️ PC\n", 1, true) ~= nil, true)
		sert.eq(string.find(text, "<b>Session:</b> 2 minutes\n", 1, true) ~= nil, true)
		_K.Remote.Notify.Fire = origFire
	end)

	test(
		";poll, ;vote, and SuperAdmin ;global validate options, deduplicate targets, tally choices, and render results below question",
		function()
			local c = createSimCluster()
			local _K, clientK, srvP1, srvP2 = c._K, c.clientK, c.srvP1, c.srvP2
			local pollDef = _K.Registry.commands.poll
			local voteDef = _K.Registry.commands.vote

			local function makeCtx(args: any?)
				return {
					_K = _K,
					from = srvP1.UserId,
					fromPlayer = srvP1,
					env = pollDef.env,
					args = args or {},
				}
			end

			-- Validation errors: 0 targets, blank question, <2 options, blank/pipe-only options, duplicates, >8 options, >200 chars
			sert.eq(pollDef.run(makeCtx(), {}, "Map?"), "No players to poll.")
			sert.eq(pollDef.run(makeCtx(), { srvP1 }, "   "), "A poll needs a question.")
			sert.eq(
				pollDef.run(makeCtx(), { srvP1 }, string.rep("q", 201)),
				"The question can be at most 200 characters."
			)
			sert.eq(pollDef.run(makeCtx(), { srvP1 }, "Map?", { "OnlyOne" }), "A poll needs at least 2 options.")
			sert.eq(
				pollDef.run(
					makeCtx({ [2] = { rawArg = '"Map?"' }, [3] = { rawArg = '"OnlyOne" ""' } }),
					{ srvP1 },
					"Map?",
					{ 'OnlyOne" "' }
				),
				"A poll needs at least 2 options."
			)
			sert.eq(pollDef.run(makeCtx(), { srvP1 }, "Map?", { "   ", "" }), "A poll needs at least 2 options.")
			sert.eq(
				pollDef.run(makeCtx(), { srvP1 }, "Map?", { "Desert", "desert" }),
				"Poll options must be different from each other."
			)
			sert.eq(
				pollDef.run(makeCtx(), { srvP1 }, "Map?", { "A", string.rep("b", 201) }),
				"Each option can be at most 200 characters."
			)
			sert.eq(
				pollDef.run(makeCtx(), { srvP1 }, "Map?", { "1", "2", "3", "4", "5", "6", "7", "8", "9" }),
				"A poll can have at most 8 options."
			)

			-- Global command block for both vote and poll
			local globalDef = _K.Registry.commands.global
			sert.eq(
				globalDef.run({ _K = _K, from = srvP1.UserId, fromPlayer = srvP1 }, ";vote all Question?"),
				'"vote" can\'t run globally.'
			)
			sert.eq(
				globalDef.run({ _K = _K, from = srvP1.UserId, fromPlayer = srvP1 }, ';poll all "Question?" A,B'),
				'"poll" can\'t run globally.'
			)

			-- Mount Dialog on client for VoteResults & OnInvoke
			local lastDialog
			clientK.Notify = function(override: any)
				lastDialog = clientK.UI.new("Dialog")(override)
				return lastDialog
			end

			-- End-to-end poll with duplicate player entry, RichText question/options, and client choice = 2
			local origInvoke = pollDef.env.remote.Invoke
			pollDef.env.remote.Invoke = function(
				_self: any,
				player: any,
				_id: string,
				_from: any,
				count: number,
				labels: { string }
			)
				sert.eq(count, 3)
				sert.eq(labels, { "<b>Red</b>", "Blue", "Green" })
				if player == srvP1 then
					return 2
				end
				return 99 -- invalid out-of-range choice from srvP2 is ignored (counts as missing)
			end

			local lastResults
			local resultsCon = clientK.Remote.VoteResults:Connect(function(q, labels, tally, missing, yesNo)
				lastResults = { q = q, labels = labels, tally = tally, missing = missing, yesNo = yesNo }
			end)

			local qArg = { rawType = { freeText = true }, rawArg = '"<b>Color?</b>"', parsedArgs = { "<b>Color?</b>" } }
			local oArg = {
				rawType = { freeText = true },
				rawArg = '"<b>Red</b>" Blue "Green"',
				parsedArgs = { '<b>Red</b>" Blue "Green' },
			}
			local err = "unset"
			c.sh.env.task.spawn(function()
				err = pollDef.run(
					makeCtx({ [2] = qArg, [3] = oArg }),
					{ srvP1, srvP1, srvP2 }, -- duplicate srvP1 should be deduplicated
					"<b>Color?</b>",
					{ '<b>Red</b>" Blue "Green' }
				)
			end)
			c.world:run(0.1)
			sert.eq(err, nil)
			sert.eq(qArg.redactLog, false)
			sert.eq(oArg.redactLog, false)

			sert.eq(lastResults ~= nil, true)
			sert.eq(lastResults.q, "<b>Color?</b>")
			sert.eq(lastResults.labels, { "<b>Red</b>", "Blue", "Green" })
			sert.eq(lastResults.tally, { 0, 1, 0 })
			sert.eq(lastResults.missing, 1) -- 2 unique players - 1 valid vote = 1 missing
			sert.eq(lastResults.yesNo, false)

			-- Verify Results Frame LayoutOrder is 3 (below Dialog's Title -2 and Text -1)
			sert.eq(lastDialog ~= nil, true)
			local resultsFrame = lastDialog._content:FindFirstChild("Results")
			sert.eq(resultsFrame ~= nil, true)
			sert.eq(lastDialog._content.Title.LayoutOrder, -2)
			sert.eq(lastDialog._content.Text.LayoutOrder, -1)
			sert.eq(resultsFrame.LayoutOrder, 3)
			sert.eq(resultsFrame.LayoutOrder > lastDialog._content.Text.LayoutOrder, true)

			-- Unquoted multi-word question in ;poll falls back to a yes/no vote
			c.world:fastForward(61)
			pollDef.env.remote.Invoke = function()
				return true
			end
			local errYesNo = "unset"
			local unquotedCtx = makeCtx({ [2] = { rawArg = "Are" }, [3] = { rawArg = "you ready?" } })
			c.sh.env.task.spawn(function()
				errYesNo = pollDef.run(unquotedCtx, { srvP1 }, "Are", { "you ready?" })
			end)
			c.world:run(0.1)
			sert.eq(errYesNo, nil)
			sert.eq(unquotedCtx.args[3], nil)
			sert.eq(lastResults.q, "Are you ready?")
			sert.eq(lastResults.yesNo, true)
			sert.eq(lastResults.tally, { 1, 0 })

			-- Client OnInvoke resolves nil if dialog is destroyed externally (e.g. overflow eviction)
			local origVoteOnInvoke = clientK.Remote.Vote.OnInvoke
			_K.Remote.ChatSystem:Fire(srvP1, "vote", "Evict test?", 1, { "A", "B" }, "vote_evict")
			c.world:run(0.05)
			local invokeResolved = false
			local invokeResult = "unset"
			c.ch1.env.task.spawn(function()
				invokeResult = origVoteOnInvoke("vote_evict", 1, 2, { "A", "B" })
				invokeResolved = true
			end)
			c.world:run(0.05)
			sert.eq(lastDialog ~= nil, true)
			c.ch1.env.task.spawn(function()
				lastDialog._instance:Destroy()
			end)
			c.world:run(0.05)
			sert.eq(invokeResolved, true)
			sert.eq(invokeResult, nil)

			resultsCon:Disconnect()
			pollDef.env.remote.Invoke = origInvoke
			voteDef.env.remote.Invoke = origInvoke
		end
	)

	test(
		"SuperAdmin and Administration PIC compliance enforces unconditional shared 60s cooldown, allows predefined titles, and preserves moderation actions when sender cannot chat",
		function()
			local c = createSimCluster(nil, true)
			local _K, srvP1, srvP2 = c._K, c.srvP1, c.srvP2
			local srvP3 = c.sh.env:addPlayer(3, "RestrictedPlr")
			buildCharacter(c.sh.env, srvP3)

			local tcs = c.sh.env.game:GetService("TextChatService")
			local tcMethods = rawget(tcs, "_methods")
			local origCanUserChat = tcMethods.CanUserChatAsync
			local origCanUsersChat = tcMethods.CanUsersChatAsync

			-- 1. ;time marks its Time argument redactLog = false
			local timeArg = { rawArg = "14:30", parsedArgs = { "14:30" }, rawType = { freeText = true } }
			_K.Registry.commands.time.run({ _K = _K, from = 1, args = { timeArg } }, "14:30", nil)
			sert.eq(timeArg.redactLog, false)

			-- 2. Even when all peers pass CanUsersChatAsync, world-text commands (name, custom title, createteam, editteam, change) share the 60s cooldown
			tcMethods.CanUsersChatAsync = function()
				return true
			end
			c.runSrv(";name TargetPlr FirstNick")
			c.runSrv(";name TargetPlr SecondNick")
			sert.eq(srvP2:GetAttribute("_KDisplayName"), "FirstNick")

			-- Shared cooldown also blocks ;createteam within 60s of ;name
			c.runSrv(";createteam TeamAlpha #ff0000")
			sert.eq(c.sh.env.game:GetService("Teams"):FindFirstChild("TeamAlpha"), nil)

			c.world:fastForward(61)
			c.runSrv(";createteam TeamAlpha #ff0000")
			c.runSrv(";createteam TeamBeta #00ff00")
			local teamAlpha = c.sh.env.game:GetService("Teams"):FindFirstChild("TeamAlpha")
			sert.eq(teamAlpha ~= nil, true)
			sert.eq(c.sh.env.game:GetService("Teams"):FindFirstChild("TeamBeta"), nil)

			c.world:fastForward(61)
			c.runSrv(";editteam TeamAlpha TeamGamma")
			c.runSrv(";editteam TeamGamma TeamDelta")
			sert.eq(teamAlpha.Name, "TeamGamma")

			local ls = c.sh.env.Instance.new("Folder", srvP2)
			ls.Name = "leaderstats"
			local rankStat = c.sh.env.Instance.new("StringValue", ls)
			rankStat.Name = "Rank"
			local scoreStat = c.sh.env.Instance.new("IntValue", ls)
			scoreStat.Name = "Score"
			c.world:fastForward(61)
			c.runSrv(";change TargetPlr Rank Bronze")
			c.runSrv(";change TargetPlr Rank Silver")
			sert.eq(rankStat.Value, "Bronze")
			-- Non-text leaderstats still apply while on shared text cooldown
			c.runSrv(";change TargetPlr Score 42")
			sert.eq(scoreStat.Value, 42)

			-- 3. Custom titles share the 60s cooldown; predefined VIP titles remain exempt even when sender cannot chat or is cooling down
			c.world:fastForward(61)
			c.runSrv(";title TargetPlr CustomOne")
			c.world:run(0.05)
			sert.eq(srvP2.Character:FindFirstChild("_K_Title").Title.Text, "CustomOne")
			local titleErr = _K.Registry.commands.title.run(
				{ _K = _K, from = 1, fromPlayer = srvP1, args = {} },
				{ srvP2 },
				"CustomTwo"
			)
			sert.eq(string.find(tostring(titleErr), "Wait", 1, true) ~= nil, true)

			-- Predefined VIP title ("vip") succeeds even while on cooldown and even when CanUserChatAsync is false
			_K.VIP.titleDefinition.vip.ownerCache[srvP2.UserId] = true
			tcMethods.CanUserChatAsync = function()
				return false
			end
			c.runSrv(";title TargetPlr vip")
			c.world:run(0.05)
			sert.eq(string.lower(srvP2.Character:FindFirstChild("_K_Title").Title.Text), "vip")

			-- 4. ban, kick, and shutdown still execute with reason stripped when CanUserChatAsync is false
			srvP2._props._kicked = nil
			c.runSrv(";ban TargetPlr 0 ShouldStripReason")
			sert.eq(_K.Data.bans["2"] ~= nil, true)
			sert.eq(_K.Data.bans["2"][2], nil)
			sert.eq(srvP2._props._kicked, "No reason.")
			_K.Data.bans["2"] = nil

			srvP2._props._kicked = nil
			c.runSrv(";kick TargetPlr ShouldAlsoStrip")
			sert.eq(srvP2._props._kicked, true) -- nil reason passed to Kick

			srvP2._props._kicked = nil
			srvP3._props._kicked = nil
			_K.Registry.commands.shutdown.run({ _K = _K, from = 1, fromPlayer = srvP1, args = {} }, nil, "MutedReason")
			sert.eq(string.find(tostring(srvP2._props._kicked), "Reason:", 1, true), nil)

			-- 5. On shared cooldown, kick strips reason for ALL targets (even chat-allowed peers)
			tcMethods.CanUserChatAsync = origCanUserChat
			c.world:fastForward(61)
			_K.Registry.commands.kick.run(
				{ _K = _K, from = 1, fromPlayer = srvP1, args = {} },
				{ srvP3 },
				"FirstKickReason"
			)
			sert.eq(srvP3._props._kicked, "FirstKickReason")
			-- Now on shared cooldown: kicking both srvP2 (allowed) and srvP3 (restricted) strips reason for BOTH
			srvP2._props._kicked = nil
			srvP3._props._kicked = nil
			_K.Registry.commands.kick.run(
				{ _K = _K, from = 1, fromPlayer = srvP1, args = {} },
				{ srvP2, srvP3 },
				"SecondKickReason"
			)
			sert.eq(srvP2._props._kicked, true)
			sert.eq(srvP3._props._kicked, true)

			-- 6. ;vote shares the 60s cooldown, delivers to all recipients once off cooldown, and blocks repeat polls within 60s
			local voteDef = _K.Registry.commands.vote
			local origVoteInvoke = voteDef.env.remote.Invoke
			local polledIds = {}
			voteDef.env.remote.Invoke = function(_self, plr)
				table.insert(polledIds, plr.UserId)
				return 1
			end
			tcMethods.CanUsersChatAsync = function(_self, _from, to)
				return to ~= 3
			end
			-- Blocked while kick reason cooldown is still active
			local blockedVoteErr = voteDef.run(
				{ _K = _K, from = 1, fromPlayer = srvP1, env = voteDef.env, args = {} },
				{ srvP2, srvP3 },
				"Blocked vote?"
			)
			sert.eq(string.find(tostring(blockedVoteErr), "Wait", 1, true) ~= nil, true)
			sert.eq(polledIds, {})

			-- Off cooldown: delivers to both srvP2 and restricted srvP3
			c.world:fastForward(61)
			c.sh.env.task.spawn(function()
				voteDef.run(
					{ _K = _K, from = 1, fromPlayer = srvP1, env = voteDef.env, args = {} },
					{ srvP2, srvP3 },
					"First vote?"
				)
			end)
			c.world:run(0.1)
			table.sort(polledIds)
			sert.eq(polledIds, { 2, 3 })

			-- Cross-command shared cooldown: ;m is blocked within 60s of ;vote
			local msgErr = select(
				2,
				_K.Chat.send({ from = 1, fromPlayer = srvP1, args = {} }, "message", "Blocked after vote", { srvP2 })
			)
			sert.eq(string.find(tostring(msgErr), "Wait", 1, true) ~= nil, true)

			voteDef.env.remote.Invoke = origVoteInvoke
			tcMethods.CanUserChatAsync = origCanUserChat
			tcMethods.CanUsersChatAsync = origCanUsersChat
		end
	)

	test(
		"Batch 2 regressions: track persistence & stream-in, R15 AnimationConstraint dog, R6/dynamic head face & bundle, BindToClose pcall, jail streaming, createteam duplicates, and respawn/punish tool unequip",
		function()
			local c = createSimCluster()
			local _K, clientK, srvP1, srvP2 = c._K, c.clientK, c.srvP1, c.srvP2

			-- #519: BindToClose wrapped in pcall in Data/init.luau
			sert.eq(_K.Data.gameClosing, false)

			-- #481: ;createteam rejects duplicate team names (case-insensitive) and duplicate explicit TeamColors, and picks an unused BrickColor when omitted
			local teams = c.sh.env.game:GetService("Teams")
			for _, t in teams:GetChildren() do
				t:Destroy()
			end
			local createTeamRun = _K.Registry.commands.createteam.run
			local ctx = { _K = _K, from = 1, fromPlayer = srvP1, args = {} }
			local err1 = createTeamRun(ctx, "RedGuard", Color3.fromRGB(255, 0, 0))
			sert.eq(err1, nil)
			local redTeam = teams:FindFirstChild("RedGuard")
			sert.eq(redTeam ~= nil, true)

			-- Case-insensitive duplicate name rejected
			local errDupName = createTeamRun(ctx, "redguard", Color3.fromRGB(0, 255, 0))
			sert.eq(string.find(tostring(errDupName), "already exists", 1, true) ~= nil, true)

			-- Duplicate explicit TeamColor rejected
			local errDupColor = createTeamRun(ctx, "CrimsonCopy", redTeam.TeamColor.Color)
			sert.eq(string.find(tostring(errDupColor), "already in use", 1, true) ~= nil, true)

			-- Omitted color picks an unused BrickColor (after 60s shared cooldown)
			c.world:fastForward(61)
			local errAutoColor = createTeamRun(ctx, "AutoTeam", nil)
			sert.eq(errAutoColor, nil)
			local autoTeam = teams:FindFirstChild("AutoTeam")
			sert.eq(autoTeam ~= nil, true)
			sert.eq(autoTeam.TeamColor ~= redTeam.TeamColor, true)

			-- #517: ;jail sets root CanCollide = false and attaches ChildAdded watcher on client so streamed-in wall BaseParts get CanCollide = true
			c.runSrv(";jail TargetPlr")
			local jailPart = _K.Registry.commands.jail.env.parts[srvP2.UserId]
			sert.eq(jailPart ~= nil, true)
			sert.eq(jailPart.CanCollide, false)
			local srvJail = c.sh.env.Instance.new("Part", c.sh.env.workspace)
			srvJail.Name = "JailCollideTestPart"
			srvJail.CanCollide = true
			c.world:run(0.05)
			local cliJail = c.ch1.env.workspace:FindFirstChild("JailCollideTestPart")
			sert.eq(cliJail ~= nil, true)
			_K.Remote.JailCollide:Fire(srvP1, srvJail)
			c.world:run(0.05)
			sert.eq(cliJail.CanCollide, false)
			local streamedWall = c.ch1.env.Instance.new("Part")
			streamedWall.CanCollide = false
			streamedWall.Parent = cliJail
			sert.eq(streamedWall.CanCollide, true)
			srvJail:Destroy()
			c.runSrv(";unjail TargetPlr")

			-- #398: ;punish and ;respawn call Humanoid:UnequipTools() before removing/reloading character
			local unequippedCount = 0
			local humMethods = rawget(srvP2.Character:FindFirstChildOfClass("Humanoid"), "_methods")
			local origUnequip = humMethods.UnequipTools
			humMethods.UnequipTools = function(self)
				unequippedCount += 1
				if origUnequip then
					origUnequip(self)
				end
			end
			c.runSrv(";punish TargetPlr")
			sert.eq(unequippedCount, 1)
			c.runSrv(";unpunish TargetPlr")
			c.runSrv(";respawn TargetPlr")
			sert.eq(unequippedCount, 2)

			-- #534: ;dog on R15 rig with AnimationConstraint joints modifies Attachment0.CFrame instead of throwing read-only C0 error
			local r15Char = buildCharacter(c.sh.env, srvP2, Enum.HumanoidRigType.R15)
			local upperTorso = r15Char:FindFirstChild("UpperTorso")
			local existingWaist = upperTorso:FindFirstChild("Waist")
			if existingWaist then
				existingWaist:Destroy()
			end
			local att0 = c.sh.env.Instance.new("Attachment", upperTorso)
			local origAttCFrame = CFrame.new(1, 2, 3)
			att0.CFrame = origAttCFrame
			local waistConstraint = c.sh.env.Instance.new("AnimationConstraint", upperTorso)
			waistConstraint.Name = "Waist"
			waistConstraint.Attachment0 = att0
			c.runSrv(";dog TargetPlr")
			sert.eq(att0.CFrame, origAttCFrame * CFrame.Angles(-math.rad(30), 0, 0))
			c.runSrv(";undog TargetPlr")
			sert.eq(att0.CFrame.Position, origAttCFrame.Position)

			-- #532: ;face clears Head SpecialMesh.TextureId and MeshPart.TextureID and restores them on ;unface
			local head = srvP2.Character:FindFirstChild("Head")
			local headMesh = head:FindFirstChildOfClass("SpecialMesh") or c.sh.env.Instance.new("SpecialMesh", head)
			headMesh.TextureId = "rbxassetid://999888"
			c.runSrv(";face TargetPlr 1800")
			sert.eq(headMesh.TextureId, "")
			c.runSrv(";unface TargetPlr")
			sert.eq(headMesh.TextureId, "rbxassetid://999888")

			-- #255: ;bundle with BundleType == "DynamicHead" merges only Head and MoodAnimation onto existing HumanoidDescription
			local assetSvc = c.sh.env.game:GetService("AssetService")
			local playersSvc = c.sh.env.game:GetService("Players")
			local assetMethods = rawget(assetSvc, "_methods")
			local playersMethods = rawget(playersSvc, "_methods")
			local origGetBundleDetails = assetMethods.GetBundleDetailsAsync
			local origGetDescFromOutfit = playersMethods.GetHumanoidDescriptionFromOutfitIdAsync
			assetMethods.GetBundleDetailsAsync = function(_self, bundleId)
				if bundleId == 777 then
					return {
						BundleType = "DynamicHead",
						Items = { { Type = "UserOutfit", Id = 888 } },
					}
				end
				return origGetBundleDetails and origGetBundleDetails(_self, bundleId)
			end
			playersMethods.GetHumanoidDescriptionFromOutfitIdAsync = function(_self, outfitId)
				if outfitId == 888 then
					local d = c.sh.env.Instance.new("HumanoidDescription")
					d.Head = 555444
					d.MoodAnimation = 666333
					d.Torso = 111222 -- should NOT overwrite player's existing Torso on DynamicHead bundle
					return d
				end
				return origGetDescFromOutfit and origGetDescFromOutfit(_self, outfitId)
			end
			local hum = srvP2.Character:FindFirstChildOfClass("Humanoid")
			local baseDesc = hum:FindFirstChildOfClass("HumanoidDescription")
				or c.sh.env.Instance.new("HumanoidDescription", hum)
			baseDesc.Torso = 424242
			c.runSrv(";bundle TargetPlr 777")
			local appliedDesc = hum:GetAppliedDescription()
			sert.eq(appliedDesc.Head, 555444)
			sert.eq(appliedDesc.MoodAnimation, 666333)
			sert.eq(appliedDesc.Torso, 424242)
			c.runSrv(";unbundle TargetPlr")
			assetMethods.GetBundleDetailsAsync = origGetBundleDetails
			playersMethods.GetHumanoidDescriptionFromOutfitIdAsync = origGetDescFromOutfit

			-- #536: ;track defaults to persistent = true and auto-attaches when HumanoidRootPart streams in later
			local cliLinkDef = clientK.Registry.commands.link
			local cliP1 = c.ch1.env.Players.LocalPlayer
			local cliP2 = c.ch1.env:addPlayer(2, "TargetPlr")
			buildCharacter(c.ch1.env, cliP1)
			-- Start with a character whose HumanoidRootPart hasn't streamed in yet
			local partialChar = c.ch1.env.Instance.new("Model")
			partialChar.Name = "TargetPlr"
			cliP2.Character = partialChar
			partialChar.Parent = c.ch1.env.workspace
			cliLinkDef.runClient({ _K = clientK, env = cliLinkDef.env, from = 1 }, { cliP2 }, nil)
			sert.eq(cliLinkDef.env.persist[cliP2] ~= nil, true)
			sert.eq(cliLinkDef.env.watchCleanup[cliP2] ~= nil, true)
			-- Now stream in HumanoidRootPart + Attachment
			local streamedHrp = c.ch1.env.Instance.new("Part")
			streamedHrp.Name = "HumanoidRootPart"
			c.ch1.env.Instance.new("Attachment", streamedHrp)
			streamedHrp.Parent = partialChar
			c.world:run(0.05)
			sert.eq(streamedHrp:FindFirstChild("_KLink") ~= nil, true)
			-- Unlink cleans up both persist and watchCleanup
			clientK.Registry.commands.unlink.runClient({ _K = clientK, env = cliLinkDef.env, from = 1 }, { cliP2 })
			sert.eq(cliLinkDef.env.persist[cliP2], nil)
			sert.eq(cliLinkDef.env.watchCleanup[cliP2], nil)
		end
	)

	test(
		"Slice 2 regressions: dog/undog exact Root.C0 identity, shirt nil AssetId, bodycolor/crm undo & ForceField textures, VIP single-asset purchases, antilag MeshPart/destroyed safety, team edits & RichText escaping, pre-load emotes preview, link/unlink race, and play/jumpscare/tts hardening",
		function()
			local c = createSimCluster()
			local _K, clientK, srvP1, srvP2 = c._K, c.clientK, c.srvP1, c.srvP2

			-- 1. dog / undog restores R15 Root.C0 (both Motor6D and AnimationConstraint) to exact original CFrame without drift
			local dogChar = buildCharacter(c.sh.env, srvP2, Enum.HumanoidRigType.R15)
			local rootMotor = dogChar.LowerTorso:FindFirstChild("Root")
			local origRootC0 = CFrame.new(0.25, -1, 0.5) * CFrame.Angles(0.1, 0.2, -0.1)
			rootMotor.C0 = origRootC0
			for _ = 1, 3 do
				c.runSrv(";dog TargetPlr")
				sert.eq(rootMotor.C0:FuzzyEq(origRootC0), false)
				c.runSrv(";undog TargetPlr")
				sert.eq(rootMotor.C0:FuzzyEq(origRootC0), true)
			end

			-- 2. jumpscare and play reject <= 0, non-audio, and failed/nil GetProductInfoAsync
			local playDef = _K.Registry.commands.play
			local jumpDef = _K.Registry.commands.jumpscare
			local playCtx = { _K = _K, env = playDef.env, from = 1, fromPlayer = srvP1 }
			local jumpCtx = { _K = _K, env = jumpDef.env, from = 1, fromPlayer = srvP1 }
			sert.eq(playDef.run(playCtx, 0), "Invalid audio asset.")
			sert.eq(playDef.run(playCtx, -42), "Invalid audio asset.")
			sert.eq(jumpDef.run(jumpCtx, { srvP2 }, nil, 0), "Invalid audio asset.")
			sert.eq(jumpDef.run(jumpCtx, { srvP2 }, nil, -42), "Invalid audio asset.")

			local marketMethods = rawget(_K.Service.Marketplace, "_methods")
			local origGetProductInfo = marketMethods.GetProductInfoAsync
			marketMethods.GetProductInfoAsync = function()
				error("Marketplace HTTP timeout")
			end
			sert.eq(playDef.run(playCtx, 888777), "Invalid audio asset.")
			sert.eq(jumpDef.run(jumpCtx, { srvP2 }, nil, 888777), "Invalid audio asset.")
			-- Transient HTTP failure must not poison audioCache
			sert.eq(playDef.env.audioCache[888777], nil)
			sert.eq(jumpDef.env.audioCache[888777], nil)
			marketMethods.GetProductInfoAsync = origGetProductInfo

			-- 3. ;shirt / ;pants / ;tshirt with nil AssetId resets/destroys applied clothing cleanly without crashing Property.override
			local shirtInst = srvP2.Character:FindFirstChildOfClass("Shirt")
			shirtInst.ShirtTemplate = "rbxassetid://555"
			c.runSrv(";shirt TargetPlr 1100")
			sert.eq(string.find(shirtInst.ShirtTemplate, "1100", 1, true) ~= nil, true)
			c.runSrv(";shirt TargetPlr") -- omitted AssetId == nil
			sert.eq(shirtInst.ShirtTemplate, "rbxassetid://555")

			-- Character originally without Shirt: created Shirt is destroyed on omitted AssetId, and bare ;shirt on shirtless character is a safe no-op
			shirtInst:Destroy()
			sert.eq(srvP2.Character:FindFirstChildOfClass("Shirt"), nil)
			c.runSrv(";shirt TargetPlr")
			sert.eq(srvP2.Character:FindFirstChildOfClass("Shirt"), nil)
			c.runSrv(";shirt TargetPlr 1100")
			sert.eq(srvP2.Character:FindFirstChildOfClass("Shirt") ~= nil, true)
			c.runSrv(";shirt TargetPlr")
			sert.eq(srvP2.Character:FindFirstChildOfClass("Shirt"), nil)

			-- 4. bodycolor / unbodycolor and crm / uncrm undo aliases + ForceField texture restoration
			buildCharacter(c.sh.env, srvP2, Enum.HumanoidRigType.R15)
			local bc = srvP2.Character:FindFirstChildOfClass("BodyColors")
			local origHeadColor = Color3.fromRGB(245, 205, 48)
			bc.HeadColor3 = origHeadColor
			c.runSrv(";bodycolor TargetPlr 255,0,0")
			sert.eq(bc.HeadColor3, Color3.fromRGB(255, 0, 0))
			-- ;unbodycolor with extra color arg still honors context.undo and restores original color
			c.runSrv(";unbodycolor TargetPlr 0,255,0")
			sert.eq(bc.HeadColor3, origHeadColor)

			local headPart = srvP2.Character:FindFirstChild("Head")
			headPart.TextureID = "rbxassetid://7001"
			local headSpecialMesh = headPart:FindFirstChildOfClass("SpecialMesh")
			headSpecialMesh.TextureId = "rbxassetid://7002"
			local charShirt = srvP2.Character:FindFirstChildOfClass("Shirt")
			charShirt.ShirtTemplate = "rbxassetid://7003"
			local charPants = srvP2.Character:FindFirstChildOfClass("Pants")
			charPants.PantsTemplate = "rbxassetid://7004"

			-- Opaque crm clears textures
			c.runSrv(";crm TargetPlr 255,0,0 0.25 SmoothPlastic")
			sert.eq(headPart.TextureID, "")
			sert.eq(headSpecialMesh.TextureId, "")
			sert.eq(charShirt.ShirtTemplate, "")
			sert.eq(charPants.PantsTemplate, "")

			-- Switching to ForceField restores original textures while applying ForceField
			c.runSrv(";crm TargetPlr 0,128,255 0 ForceField")
			sert.eq(headPart.Material, Enum.Material.ForceField)
			sert.eq(headPart.TextureID, "rbxassetid://7001")
			sert.eq(headSpecialMesh.TextureId, "rbxassetid://7002")
			sert.eq(charShirt.ShirtTemplate, "rbxassetid://7003")
			sert.eq(charPants.PantsTemplate, "rbxassetid://7004")

			-- ;uncrm with extra args honors context.undo and resets Material/Color/Reflectance
			c.runSrv(";uncrm TargetPlr 255,0,0 0.5 Neon")
			sert.eq(headPart.Reflectance, 0)

			-- 5. VIP single-asset PromptPurchaseFinished credits chatCommandsLower and assetDonations when verified
			local plrDonor = c.sh.env:addPlayer(55, "SingleAssetDonor")
			plrDonor:SetAttribute("_KDonationLevel", 0)
			local origOwnsAsset = marketMethods.PlayerOwnsAssetAsync
			local ownedByDonor: { [number]: boolean } = {
				[441133423] = true, -- assetDonations[1] -> level 1
				[115403290087767] = true, -- chatCommandsLower[2] (Patron) -> level 2
				[110019084552349] = true, -- chatCommands -> level 4
			}
			marketMethods.PlayerOwnsAssetAsync = function(_self, plr, id)
				if plr == plrDonor then
					return ownedByDonor[id] == true
				end
				return origOwnsAsset and origOwnsAsset(_self, plr, id) or false
			end
			_K.Service.Marketplace.PromptPurchaseFinished:Fire(plrDonor, 441133423, true)
			c.world:run(0.5)
			sert.eq(plrDonor:GetAttribute("_KDonationLevel"), 1)

			_K.Service.Marketplace.PromptPurchaseFinished:Fire(plrDonor, 115403290087767, true)
			c.world:run(0.5)
			sert.eq(plrDonor:GetAttribute("_KDonationLevel"), 2)

			_K.Service.Marketplace.PromptPurchaseFinished:Fire(plrDonor, 110019084552349, true)
			c.world:run(0.5)
			sert.eq(plrDonor:GetAttribute("_KDonationLevel"), 4)
			marketMethods.PlayerOwnsAssetAsync = origOwnsAsset

			-- 6. antilag resets MeshPart.TextureID and survives destroyed hidden instances on unantilag
			local origDeferWait = clientK.Util.Defer.wait
			clientK.Util.Defer.wait = function() end
			local worldMesh = c.ch1.env.Instance.new("MeshPart", c.ch1.env.workspace)
			worldMesh.Material = Enum.Material.Brick
			worldMesh.TextureID = "rbxassetid://424242"
			local worldDecalHolder = c.ch1.env.Instance.new("Part", c.ch1.env.workspace)
			local worldDecal = c.ch1.env.Instance.new("Decal", worldDecalHolder)
			local destroyedDecal = c.ch1.env.Instance.new("Decal", worldDecalHolder)
			sert.eq(worldDecal.Parent, worldDecalHolder)

			_K.Remote.AntiLag:Fire(srvP1, false)
			c.world:run(0.1)
			sert.eq(worldMesh.Material, Enum.Material.SmoothPlastic)
			sert.eq(worldMesh.TextureID, "")
			sert.eq(worldDecal.Parent, nil)
			sert.eq(destroyedDecal.Parent, nil)

			-- Destroy one hidden decal so its Parent is locked (throws on reparent), then verify unantilag still restores worldDecal
			destroyedDecal:Destroy()
			local okLocked = pcall(function()
				destroyedDecal.Parent = worldDecalHolder
			end)
			sert.eq(okLocked, false)
			_K.Remote.AntiLag:Fire(srvP1, true)
			c.world:run(0.1)
			clientK.Util.Defer.wait = origDeferWait
			sert.eq(worldMesh.Material, Enum.Material.Brick)
			sert.eq(worldMesh.TextureID, "rbxassetid://424242")
			sert.eq(worldDecal.Parent, worldDecalHolder)
			worldMesh:Destroy()
			worldDecalHolder:Destroy()

			-- 7. createteam / editteam / removeteam: optional preservation, duplicate checks, nil safety, BrickColor.palette, RichText escaping, and nil fromPlayer safety
			local teams = c.sh.env.game:GetService("Teams")
			for _, t in teams:GetChildren() do
				t:Destroy()
			end
			local teamCtx = { _K = _K, from = 1, fromPlayer = srvP1, global = true, args = {} }
			local createTeamRun = _K.Registry.commands.createteam.run
			local editTeamRun = _K.Registry.commands.editteam.run
			local removeTeamRun = _K.Registry.commands.removeteam.run

			local lastNotifyText = ""
			local origNotifyFire = _K.Remote.Notify.Fire
			_K.Remote.Notify.Fire = function(selfRemote, plr, payload)
				if type(payload) == "table" and type(payload.Text) == "string" then
					lastNotifyText = payload.Text
				end
				return origNotifyFire(selfRemote, plr, payload)
			end

			sert.eq(createTeamRun(teamCtx, "<b>Alpha&One</b>", Color3.fromRGB(255, 0, 0), false), nil)
			sert.eq(string.find(lastNotifyText, "&lt;b&gt;Alpha&amp;One&lt;/b&gt;", 1, true) ~= nil, true)
			local alphaTeam = teams:FindFirstChild("<b>Alpha&One</b>")
			sert.eq(alphaTeam ~= nil, true)
			local origAlphaBrickColor = alphaTeam.TeamColor
			sert.eq(alphaTeam.AutoAssignable, false)

			sert.eq(createTeamRun(teamCtx, "BravoTeam", Color3.fromRGB(0, 0, 255), true), nil)
			local bravoTeam = teams:FindFirstChild("BravoTeam")

			-- editteam preserves TeamColor and AutoAssignable when omitted
			sert.eq(editTeamRun(teamCtx, alphaTeam, "AlphaRenamed", nil, nil), nil)
			sert.eq(alphaTeam.Name, "AlphaRenamed")
			sert.eq(alphaTeam.TeamColor, origAlphaBrickColor)
			sert.eq(alphaTeam.AutoAssignable, false)

			-- editteam rejects name and color collisions with BravoTeam
			sert.eq(
				string.find(tostring(editTeamRun(teamCtx, alphaTeam, "bravoteam", nil, nil)), "already exists", 1, true)
					~= nil,
				true
			)
			sert.eq(
				string.find(
					tostring(editTeamRun(teamCtx, alphaTeam, "AlphaRenamed", bravoTeam.TeamColor.Color, nil)),
					"already in use",
					1,
					true
				) ~= nil,
				true
			)

			-- editteam and removeteam safely handle nil team without crashing
			sert.eq(editTeamRun(teamCtx, nil, "Missing", nil, nil), nil)
			removeTeamRun(teamCtx, nil)

			-- Ban notification escapes RichText in ban reason
			_K.Registry.commands.ban.run(
				{ _K = _K, from = 1, fromPlayer = srvP1, global = true, args = {} },
				{ 2 },
				0,
				"<font color='bad'>Exploit & Spam"
			)
			sert.eq(string.find(lastNotifyText, "&lt;font", 1, true) ~= nil, true)
			sert.eq(string.find(lastNotifyText, "Exploit &amp; Spam", 1, true) ~= nil, true)
			_K.Data.bans["2"] = nil
			_K.Remote.Notify.Fire = origNotifyFire

			-- Nil fromPlayer under global context does not crash serverlock / bring / to / join / rejoin / spectate
			local globalNilCtx = { _K = _K, from = 0, fromPlayer = nil, global = true, args = {} }
			_K.Registry.commands.serverlock.run(globalNilCtx)
			sert.eq(_K._serverLock ~= nil, true)
			_K._serverLock = nil
			_K.Registry.commands.bring.run(globalNilCtx, { srvP2 })
			_K.Registry.commands.to.run(globalNilCtx, srvP2)
			_K.Registry.commands.join.run(globalNilCtx, 2)
			_K.Registry.commands.rejoin.run(globalNilCtx)
			_K.Registry.commands.spectate.run(
				{ _K = _K, env = _K.Registry.commands.spectate.env, from = 0, fromPlayer = nil, global = true },
				srvP2
			)

			-- 8. ;emotes preview click before CreateHumanoidModelFromUserId resolves queues preview without crashing
			local cliPlayersMethods = rawget(c.ch1.env.Players, "_methods")
			local origCreateModel = cliPlayersMethods.CreateHumanoidModelFromUserId
			local previewRigReady = false
			cliPlayersMethods.CreateHumanoidModelFromUserId = function(selfPlr, uid)
				while not previewRigReady do
					c.ch1.env.task.wait(0.05)
				end
				return origCreateModel(selfPlr, uid)
			end
			clientK.Data.emoteItemFromId[7777] = {
				emoteId = 7777,
				animationId = 8888,
				name = "QueuedDance",
				nameLower = "queueddance",
				owned = false,
			}
			-- Re-run setup via fresh emote envClient in ch1
			local utilityDefs = c.ch1.env:require(c.ch1.Shared.DefaultCommands.Utility)
			local emoteDefCli
			for _, d in utilityDefs do
				if d.name == "emote" then
					emoteDefCli = d
					break
				end
			end
			local freshEmoteEnv = emoteDefCli.envClient(clientK)
			-- Calling updatePreview even before task.defer runs and while CreateHumanoidModelFromUserId yields must not throw
			freshEmoteEnv.updatePreview(7777)
			c.world:run(0.05)
			sert.eq(freshEmoteEnv.preview ~= nil, true)
			sert.eq(freshEmoteEnv.preview.Visible, true)
			sert.eq(freshEmoteEnv.preview.Title.Text, "QueuedDance")
			previewRigReady = true
			c.world:run(0.2)
			cliPlayersMethods.CreateHumanoidModelFromUserId = origCreateModel

			-- 9. link / unlink deferred race, cleanup[player], and localPlayer.Character == nil stream-in
			local cliLinkDef = clientK.Registry.commands.link
			local cliUnlinkDef = clientK.Registry.commands.unlink
			local cliP1 = c.ch1.env.Players.LocalPlayer
			local cliP3 = c.ch1.env:addPlayer(33, "RaceTarget")
			local charP1 = buildCharacter(c.ch1.env, cliP1)
			cliP1.Character = charP1
			charP1.Parent = c.ch1.env.workspace
			local charP3 = buildCharacter(c.ch1.env, cliP3)
			cliP3.Character = charP3
			charP3.Parent = c.ch1.env.workspace

			cliLinkDef.runClient({ _K = clientK, env = cliLinkDef.env, from = 1 }, { cliP3 }, true)
			sert.eq(charP3.HumanoidRootPart:FindFirstChild("_KLink") ~= nil, true)
			sert.eq(cliLinkDef.env.cleanup[cliP3] ~= nil, true)

			-- Queue deferred re-link via CharacterAdded, then immediately unlink before deferred runs
			local respawnCharP3 = buildCharacter(c.ch1.env, cliP3)
			cliP3.Character = respawnCharP3
			respawnCharP3.Parent = c.ch1.env.workspace
			cliP3.CharacterAdded:Fire(respawnCharP3)
			cliUnlinkDef.runClient({ _K = clientK, env = cliLinkDef.env, from = 1 }, { cliP3 })
			c.world:run(0.1)
			sert.eq(respawnCharP3.HumanoidRootPart:FindFirstChild("_KLink"), nil)
			sert.eq(cliLinkDef.env.active[cliP3], nil)
			sert.eq(cliLinkDef.env.cleanup[cliP3], nil)

			-- Link while localPlayer.Character == nil watches localPlayer.CharacterAdded and links on spawn
			cliP1.Character = nil
			cliLinkDef.runClient({ _K = clientK, env = cliLinkDef.env, from = 1 }, { cliP3 }, false)
			sert.eq(respawnCharP3.HumanoidRootPart:FindFirstChild("_KLink"), nil)
			local spawnedLocalChar = buildCharacter(c.ch1.env, cliP1)
			cliP1.Character = spawnedLocalChar
			spawnedLocalChar.Parent = c.ch1.env.workspace
			cliP1.CharacterAdded:Fire(spawnedLocalChar)
			c.world:run(0.1)
			sert.eq(respawnCharP3.HumanoidRootPart:FindFirstChild("_KLink") ~= nil, true)
			cliUnlinkDef.runClient({ _K = clientK, env = cliLinkDef.env, from = 1 }, { cliP3 })

			-- 10. tts ignores RichText-only empty strings and cleans up instances when LoadAsync errors
			local beforeChildren = #c.ch1.env.workspace:GetChildren()
			c.runSrv(';tts "British male" "<b>   </b>"')
			c.world:run(0.1)
			sert.eq(#c.ch1.env.workspace:GetChildren(), beforeChildren)

			-- Force AudioTextToSpeech:LoadAsync to throw and verify no Wire / AudioTextToSpeech leaks in workspace
			local ttsConn = c.ch1.env.workspace.DescendantAdded:Connect(function(inst)
				if inst.ClassName == "AudioTextToSpeech" then
					local m = rawget(inst, "_methods") or {}
					m.LoadAsync = function()
						error("TTS LoadAsync failure")
					end
					rawset(inst, "_methods", m)
				end
			end)
			c.world:fastForward(61)
			c.runSrv(';tts "British male" "Hello world"')
			c.world:run(0.1)
			ttsConn:Disconnect()
			for _, child in c.ch1.env.workspace:GetChildren() do
				sert.eq(child.ClassName ~= "AudioTextToSpeech", true)
				sert.eq(child.ClassName ~= "AudioDeviceOutput", true)
				sert.eq(child.ClassName ~= "Wire", true)
			end
		end
	)

	test(
		"badge validates IDs and RichText-escapes alerts, btools cleans orphan GUIs, bundle respects undo, and VIP checks Player leaving",
		function()
			local c = createSimCluster()
			local _K, clientK, srvP1, srvP2 = c._K, c.clientK, c.srvP1, c.srvP2

			-- 1. badge rejects badge <= 0, records "player left", and RichText-escapes badge name in alert
			local badgeCmd = _K.Registry.commands.badge
			local zeroErr: string?
			c.server:spawn(function()
				zeroErr = badgeCmd.run({ _K = _K, from = 1, fromPlayer = srvP1 }, { srvP2 }, 0)
			end)
			c.world:run(0.1)
			sert.eq(zeroErr, "Badge ID must be a positive whole number.")

			local badgeMethods = rawget(_K.Service.Badge, "_methods") or {}
			local origGetBadgeInfo = badgeMethods.GetBadgeInfoAsync
			local origUserHasBadge = badgeMethods.UserHasBadgeAsync
			badgeMethods.GetBadgeInfoAsync = function(_self: any, _id: number)
				return { Name = "<script>TagBadge", IsEnabled = true }
			end
			badgeMethods.UserHasBadgeAsync = function()
				return true
			end
			rawset(_K.Service.Badge, "_methods", badgeMethods)

			local alerts = {}
			local origAlert = _K.alert
			_K.alert = function(player: any, msg: string, isErr: boolean?)
				table.insert(alerts, { player = player, msg = msg, isErr = isErr })
			end

			local tempLeft = c.sh.env:addPlayer(909, "LeftUser")
			c.world:run(0.05)
			c.sh.env:removePlayer(tempLeft)
			c.server:spawn(function()
				badgeCmd.run({ _K = _K, from = 1, fromPlayer = srvP1 }, { srvP1, tempLeft }, 123)
			end)
			c.world:run(0.2)
			_K.alert = origAlert
			badgeMethods.GetBadgeInfoAsync = origGetBadgeInfo
			badgeMethods.UserHasBadgeAsync = origUserHasBadge
			sert.eq(#alerts, 1)
			sert(string.find(alerts[1].msg, "&lt;script&gt;TagBadge", 1, true) ~= nil, alerts[1].msg)
			sert(string.find(alerts[1].msg, "LeftUser: player left", 1, true) ~= nil, alerts[1].msg)

			-- 2. btools.envClient cleans orphaned F3X GUIs in PlayerGui on Character.ChildRemoved
			local cliP1 = c.ch1.env.Players.LocalPlayer
			local pGui = cliP1:FindFirstChildOfClass("PlayerGui") or c.ch1.env.Instance.new("PlayerGui", cliP1)
			c.client1:spawn(function()
				local superAdminDefs = c.ch1.env:require(c.ch1.Shared.DefaultCommands.SuperAdmin)
				local btoolsDefCli
				for _, def in superAdminDefs do
					if def.name == "btools" then
						btoolsDefCli = def
						break
					end
				end
				btoolsDefCli.envClient(clientK)
				local orphanUi = c.ch1.env.Instance.new("ScreenGui", pGui)
				orphanUi.Name = "Building Tools by F3X (UI)"
				local orphanHandles = c.ch1.env.Instance.new("ScreenGui", pGui)
				orphanHandles.Name = "BTHandles"
				local btTool = c.ch1.env.Instance.new("Tool", cliP1.Character)
				btTool.Name = "Building Tools"
				btTool.Parent = nil
			end)
			c.world:run(0.2)
			sert.eq(pGui:FindFirstChild("Building Tools by F3X (UI)"), nil)
			sert.eq(pGui:FindFirstChild("BTHandles"), nil)

			-- 3. bundle handles GetHumanoidDescriptionFromOutfitIdAsync errors and undo restores without fetching bundle
			local hum = srvP2.Character:FindFirstChildOfClass("Humanoid")
			if not hum:FindFirstChildOfClass("HumanoidDescription") then
				c.sh.env.Instance.new("HumanoidDescription", hum)
			end
			local plMethods = rawget(c.sh.env.Players, "_methods") or {}
			local origGetOutfitDesc = plMethods.GetHumanoidDescriptionFromOutfitIdAsync
			local outfitFetchCalls = 0
			plMethods.GetHumanoidDescriptionFromOutfitIdAsync = function()
				outfitFetchCalls += 1
				error("Outfit load failed")
			end
			rawset(c.sh.env.Players, "_methods", plMethods)

			local bundleCmd = _K.Registry.commands.bundle
			local bundleErr: string?
			c.server:spawn(function()
				bundleErr = bundleCmd.run({ _K = _K, env = bundleCmd.env, undo = false }, { srvP2 }, 777)
			end)
			c.world:run(0.2)
			sert.eq(bundleErr, "Failed to load bundle.")
			sert.eq(outfitFetchCalls, 1)

			local origDesc = c.sh.env.Instance.new("HumanoidDescription", srvP2)
			origDesc.Name = "_KHumanoidDescription"
			c.server:spawn(function()
				bundleCmd.run({ _K = _K, env = bundleCmd.env, undo = true }, { srvP2 }, 777)
			end)
			c.world:run(0.2)
			sert.eq(outfitFetchCalls, 1)
			origDesc:Destroy()
			plMethods.GetHumanoidDescriptionFromOutfitIdAsync = origGetOutfitDesc

			-- 4. VIP PromptGamePassPurchaseFinished skips awarding when player disconnects during verifyPurchase
			local tempBuyer = c.sh.env:addPlayer(910, "TempBuyer")
			c.world:run(0.05)
			local mkt = c.sh.env.game:GetService("MarketplaceService")
			local mktMethods = rawget(mkt, "_methods") or {}
			local origOwnsGP = mktMethods.UserOwnsGamePassAsync
			mktMethods.UserOwnsGamePassAsync = function()
				c.sh.env:removePlayer(tempBuyer)
				return true
			end
			rawset(mkt, "_methods", mktMethods)
			c.server:spawn(function()
				mkt.PromptGamePassPurchaseFinished:Fire(tempBuyer, 5391359, true)
			end)
			c.world:run(0.2)
			mktMethods.UserOwnsGamePassAsync = origOwnsGP
			sert.eq(_K.Auth.hasRole(tempBuyer.UserId, "vip"), false)
			sert.eq(tempBuyer:GetAttribute("_KDonationLevel"), 0)
		end
	)
end)

do
	return {}
end
