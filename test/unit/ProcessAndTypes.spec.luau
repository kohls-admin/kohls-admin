local Harness = require("./Harness")
local sert = require("../sert")

local describe, test, expect = sert.describe, sert.test, sert.expect
local prop = sert.prop

describe("Process · rawParse", function()
	local DEFAULT_PREFIX = { ";" }
	local MULTI_PREFIX = { ";", "!" }

	test("parses single, quoted, and chained commands with custom prefixes", function()
		local Process = Harness.shared():requireProcess()
		expect(Process.rawParse("hello world", DEFAULT_PREFIX, " ")).toBeNil()
		expect(Process.rawParse(";", DEFAULT_PREFIX, " ")).toBeNil()

		local single = Process.rawParse(";fly me 100", DEFAULT_PREFIX, " ")
		expect(single ~= nil).toBe(true)
		expect(#(single :: any)).toBe(1)
		expect((single :: any)[1][1][2]).toBe("fly")
		expect((single :: any)[1][2][2]).toBe("me")
		expect((single :: any)[1][3][2]).toBe("100")

		local chained = Process.rawParse(';announce "hello ; world" ;kick bob "bye"', { ";", ":" }, " ")
		expect(chained ~= nil).toBe(true)
		expect(#(chained :: any)).toBe(2)
		expect((chained :: any)[1][1][2]).toBe("announce")
		expect((chained :: any)[1][2][2]).toBe('"hello ; world"')
		expect((chained :: any)[2][1][2]).toBe("kick")
		expect((chained :: any)[2][2][2]).toBe("bob")
	end)

	prop(
		"rawParse never errors on arbitrary strings and preserves token count for clean alphanumeric tokens",
		function(g)
			local Process = Harness.shared():requireProcess()
			local noise = g:string(nil, 0, 40)
			local ok, err = pcall(Process.rawParse, noise, MULTI_PREFIX, " ")
			expect(ok).toBe(true)
			expect(err == nil or type(err) == "table").toBe(true)

			local cmd = g:string("abcdefghijklmnopqrstuvwxyz", 1, 10)
			local arg1 = g:string("abcdefghijklmnopqrstuvwxyz0123456789", 1, 10)
			local arg2 = g:string("abcdefghijklmnopqrstuvwxyz0123456789", 1, 10)
			local line = `;{cmd} {arg1} "{arg2} inside"`
			local parsed = Process.rawParse(line, DEFAULT_PREFIX, " ")
			expect(parsed ~= nil).toBe(true)
			expect(#(parsed :: any)).toBe(1)
			expect((parsed :: any)[1][1][2]).toBe(cmd)
			expect((parsed :: any)[1][2][2]).toBe(arg1)
			expect((parsed :: any)[1][3][2]).toBe(`"{arg2} inside"`)
		end,
		{ runs = 80 }
	)
end)

describe("Registry & DefaultTypes / DefaultCommands · Contract Laws", function()
	test("all DefaultTypes and DefaultCommands satisfy registry & alias laws", function()
		local h = Harness.newEnv()
		h:requireData()
		local _K = h:requireK()
		local Registry = _K.Registry
		local Argument = h.env:require(h.Shared:WaitForChild("Process"):WaitForChild("Argument"))

		expect(#Registry.commandsList > 50).toBe(true)

		sert.laws.registry({
			name = "Registry.commands",
			entries = Registry.commands,
			aliases = Registry.commandsAlias,
			check = function(def, name)
				assert(type(def.name) == "string" and #def.name > 0, `command {name} missing name`)
				assert(type(def.group) == "string" and #def.group > 0, `command {name} missing group`)
				assert(type(def.args) == "table", `command {name} missing args table`)
				for idx, argDef in def.args do
					assert(type(argDef.name) == "string", `command {name} arg {idx} missing name`)
					assert(type(argDef.type) == "string", `command {name} arg {idx} missing type`)
					local parsedType = Argument.parseTypeUnion(argDef.type, "")
					assert(
						parsedType ~= nil and Registry.types[parsedType] ~= nil,
						`command {name} arg {idx} references unregistered type {argDef.type}`
					)
				end
			end,
		})

		sert.laws.registry({
			name = "Registry.types",
			entries = Registry.types,
			check = function(typeDef, name)
				assert(type(typeDef.validate) == "function", `type {name} missing validate`)
				assert(type(typeDef.parse) == "function", `type {name} missing parse`)
			end,
		})
	end)

	local propMutant: any = nil
	local propTypes: any = nil
	local MATERIALS = { "Plastic", "Wood", "Slate", "Concrete", "Neon", "Glass" }
	local function getPropTypes()
		local curMutant = (_G :: any).__SERT_MUTANT
		if propTypes == nil or propMutant ~= curMutant then
			local h = Harness.newEnv()
			h:requireData()
			local _K = h:requireK()
			_K.Registry.registerCommand(_K, {
				name = "_propenum",
				description = "Registers Enum.Material for prop test",
				group = "utility",
				args = {
					{ type = "Enum.Material", name = "Mat", description = "Material" },
				},
				run = function() end,
			})
			propTypes = _K.Registry.types
			propMutant = curMutant
		end
		return propTypes
	end

	prop(
		"built-in scalar, color, timeSimple, vector, and enum types round-trip valid inputs and reject malformed ones",
		function(g)
			local types = getPropTypes()
			local Color3 = Harness.globals.Color3
			local Vector2 = Harness.globals.Vector2
			local Vector3 = Harness.globals.Vector3
			local Enum = Harness.globals.Enum

			local n = g:int(-10000, 10000)
			local intVal = types.integer.transform(tostring(n))
			expect((types.integer.validate(intVal))).toBe(true)
			expect(types.integer.parse(intVal)).toBe(n)
			expect((types.integer.validate(types.integer.transform("not_a_number")))).toBe(false)

			local r, gr, b = g:int(0, 255), g:int(0, 255), g:int(0, 255)
			local expectedColor = Color3.fromRGB(r, gr, b)
			local hex = string.format("#%02x%02x%02x", r, gr, b)
			local cHex = types.color.transform(hex)
			expect((types.color.validate(cHex))).toBe(true)
			expect(types.color.parse(cHex)).toEqual(expectedColor)
			local cRgb = types.color.transform(`{r},{gr},{b}`)
			expect((types.color.validate(cRgb))).toBe(true)
			expect(types.color.parse(cRgb)).toEqual(expectedColor)
			expect((types.color.validate(types.color.transform("#zzzzzz")))).toBe(false)

			local mins = g:int(1, 120)
			local secs = g:int(1, 59)
			local okTime, parsedTime = types.timeSimple.validate(`{mins}m {secs}s`)
			expect(okTime).toBe(true)
			expect(parsedTime).toBe(mins * 60 + secs)
			expect((types.timeSimple.validate("invalid_time_xyz"))).toBe(false)

			local vx, vy, vz = g:int(-500, 500), g:int(-500, 500), g:int(-500, 500)
			local v2Val = types.vector2.transform(`{vx},{vy}`)
			expect((types.vector2.validate(v2Val))).toBe(true)
			expect(types.vector2.parse(v2Val)).toEqual(Vector2.new(vx, vy))
			expect((types.vector2.validate(types.vector2.transform("1,2,3")))).toBe(false)

			local v3Val = types.vector3.transform(`{vx},{vy},{vz}`)
			expect((types.vector3.validate(v3Val))).toBe(true)
			expect(types.vector3.parse(v3Val)).toEqual(Vector3.new(vx, vy, vz))
			expect((types.vector3.validate(types.vector3.transform("1,bad,3")))).toBe(false)

			local enumType = types["Enum.Material"]
			local matName = g:pick(MATERIALS)
			expect((enumType.validate(matName))).toBe(true)
			expect(enumType.parse(matName)).toBe((Enum.Material :: any)[matName])
			expect(enumType.parse(string.lower(matName))).toBe((Enum.Material :: any)[matName])
		end,
		{ runs = 60 }
	)
end)

describe("Process · Command Preparation, Validation & Execution", function()
	test("registers custom command, validates arguments, fires pre/post hooks, and enforces permissions", function()
		local h = Harness.newEnv()
		local Data = h:requireData()
		local _K = h:requireK()
		local adminPlayer = h.env:addPlayer(10, "AdminUser")
		local guestPlayer = h.env:addPlayer(20, "GuestUser")
		_K.Auth.userRoleAdd(adminPlayer.UserId, "admin")
		Data.settings.prefix = { ";" }

		local executed: { any } = {}
		local preCount, postCount = 0, 0
		_K.Hook.preCommand:Connect(function()
			preCount += 1
		end)
		_K.Hook.postCommand:Connect(function()
			postCount += 1
		end)

		_K.Registry.registerCommand(_K, {
			name = "testgive",
			aliases = { "tgive" },
			description = "Test command for unit suite",
			group = "administration",
			args = {
				{
					type = "players",
					name = "Targets",
					description = "Target players",
				},
				{
					type = "integer",
					name = "Amount",
					description = "Points",
				},
				{
					type = "boolean",
					name = "Silent",
					description = "Silent flag",
					optional = true,
				},
			},
			run = function(context, targets, amount, silent)
				table.insert(executed, {
					from = context.from,
					targets = targets,
					amount = amount,
					silent = silent,
				})
			end,
		})

		-- Guest lacks administration group permission
		local okGuest = _K.Process.runCommands(_K, guestPlayer.UserId, ";tgive all 50 true", true)
		expect(okGuest).toBe(false)
		expect(#executed).toBe(0)

		-- Admin succeeds via alias
		local okAdmin = _K.Process.runCommands(_K, adminPlayer.UserId, ";tgive GuestUser 42 true", true)
		expect(okAdmin).toBe(true)
		expect(#executed).toBe(1)
		expect(executed[1].from).toBe(adminPlayer.UserId)
		expect(executed[1].targets[1]).toBe(guestPlayer)
		expect(executed[1].amount).toBe(42)
		expect(executed[1].silent).toBe(true)
		expect(preCount).toBe(1)
		expect(postCount).toBe(1)

		-- Missing required integer argument fails validation cleanly
		local okMissing, errMissing = _K.Process.prepareCommands(_K, adminPlayer.UserId, ";tgive GuestUser")
		expect(okMissing).toBe(false)
		expect(string.find(tostring(errMissing), "missing", 1, true) ~= nil).toBe(true)
	end)

	test("global command strings parse only with the server prefix", function()
		local h = Harness.newEnv()
		local Data = h:requireData()
		local _K = h:requireK()
		local admin = h.env:addPlayer(10, "AdminUser")
		_K.Auth.userRoleAdd(admin.UserId, "admin")
		Data.settings.prefix = { ":" }
		Data.playerPrefix[admin.UserId] = "!"
		for _, name in { "testsay", "testother" } do
			_K.Registry.registerCommand(_K, {
				name = name,
				description = "Test command for unit suite",
				group = "administration",
				args = { { type = "string", name = "Text", description = "Text" } },
				run = function() end,
			})
		end

		-- a sender's own prefix and the settings prefixes start commands in their own messages
		local ok, commands = _K.Process.prepareCommands(_K, admin.UserId, ';testsay "a !testother b"')
		expect(ok).toBe(true)
		expect(commands[1].alias).toBe("testother")
		ok, commands = _K.Process.prepareCommands(_K, admin.UserId, 'x :testsay "a ;testother b"')
		expect(ok).toBe(true)
		expect(commands[1].alias).toBe("testsay")

		-- published global strings start with the server prefix, the others are text there
		ok, commands = _K.Process.prepareCommands(_K, admin.UserId, ';testsay "a !testother b :testother c"', true)
		expect(ok).toBe(true)
		expect(#commands).toBe(1)
		expect(commands[1].alias).toBe("testsay")
		expect(commands[1].args[1].rawArg).toBe('"a !testother b :testother c"')
		expect(_K.Process.prepareCommands(_K, admin.UserId, ':testsay "a"', true)).toBeNil()
	end)

	test(
		"Registry auto-registers plural Enum.<Name>s, inline CSV enums, makeSequenceType, and command aliases",
		function()
			local h = Harness.newEnv()
			h:requireData()
			local _K = h:requireK()
			local Registry = _K.Registry

			local seenEnum, seenCsv = nil, nil
			Registry.registerCommand(_K, {
				name = "testenumcsv",
				description = "Tests plural Enum and inline CSV auto-registration",
				group = "utility",
				args = {
					{
						type = "Enum.Materials",
						name = "Mats",
						description = "Materials list",
					},
					{
						type = "alpha,beta,gamma",
						name = "Choice",
						description = "CSV choice",
					},
				},
				run = function(_context, mats, choice)
					seenEnum = mats
					seenCsv = choice
				end,
			})

			-- Both singular and plural Enum types and CSV types are now registered
			expect(Registry.types["Enum.Material"] ~= nil).toBe(true)
			expect(Registry.types["Enum.Materials"] ~= nil).toBe(true)
			expect(Registry.types["Enum.Materials"].listable).toBe(true)
			expect(Registry.types["alpha,beta,gamma"] ~= nil).toBe(true)
			expect(Registry.types["alpha,beta,gammas"] ~= nil).toBe(true)
			expect((Registry.types["alpha,beta,gamma"].validate("beta"))).toBe(true)
			expect(Registry.types["alpha,beta,gamma"].parse("beta")).toBe("beta")

			local plr = h.env:addPlayer(10, "EnumUser")
			local ok = _K.Process.runCommands(_K, plr.UserId, ";testenumcsv Plastic,Neon gamma", true)
			expect(ok).toBe(true)
			expect(#seenEnum).toBe(2)
			expect(seenCsv).toBe("gamma")

			-- makeSequenceType transforms, validates length and components, and constructs result
			local seqType = Registry.makeSequenceType({
				length = 3,
				transform = function(v)
					return tonumber(v)
				end,
				validate = function(v)
					return v ~= nil, "Must be a number"
				end,
				constructor = function(x, y, z)
					return { x = x, y = y, z = z }
				end,
			})
			local transformed = seqType.transform("10,20,30")
			expect((seqType.validate(transformed))).toBe(true)
			expect(seqType.parse(transformed)).toEqual({ x = 10, y = 20, z = 30 })
			expect((seqType.validate(seqType.transform("10,20,30,40")))).toBe(false)
			expect((seqType.validate(seqType.transform("10,bad,30")))).toBe(false)

			-- registerCommandAlias registers a Utility command and ignores duplicate registration
			Registry.registerCommandAlias(_K, "quickhelp", ";help")
			expect(Registry.commands.quickhelp ~= nil).toBe(true)
			expect(Registry.commands.quickhelp.group).toBe("Utility")
			Registry.registerCommandAlias(_K, "quickhelp", ";help")
		end
	)

	test(
		"Process.runCommands enforces rate-limits/cooldowns, truncates >1024 rawText, redacts freeText liveText, and reports errors",
		function()
			local h = Harness.newEnv()
			local Data = h:requireData()
			local _K = h:requireK()
			Data.settings.prefix = { ";" }

			local modPlayer = h.env:addPlayer(11, "ModSender")
			local guestPlayer = h.env:addPlayer(22, "LimitedGuest")
			local otherAdmin = h.env:addPlayer(33, "OtherAdmin")
			local friendAdmin = h.env:addPlayer(44, "FriendAdmin")
			modPlayer:SetAttribute("_K_READY", true)
			guestPlayer:SetAttribute("_K_READY", true)
			otherAdmin:SetAttribute("_K_READY", true)
			friendAdmin:SetAttribute("_K_READY", true)
			_K.Auth.userRoleAdd(modPlayer.UserId, "mod")
			_K.Auth.userRoleAdd(otherAdmin.UserId, "admin")
			_K.Auth.userRoleAdd(friendAdmin.UserId, "admin")

			local tcsMethods = rawget(h.env.game:GetService("TextChatService"), "_methods")
			tcsMethods.CanUsersChatAsync = function(_self, fromId, toId)
				return toId ~= otherAdmin.UserId and fromId ~= otherAdmin.UserId
			end

			-- Track Remote.Notify and Remote.Log fires
			local notifications = {}
			local remoteLogs = {}
			_K.Remote.Notify.Fire = function(_self, target, payload)
				table.insert(notifications, { to = target.UserId, text = payload.Text })
			end
			_K.Remote.Log.Fire = function(_self, target, logEntry)
				table.insert(remoteLogs, { to = target.UserId, text = logEntry[1], level = logEntry[2] })
			end

			local echoed = {}
			_K.Registry.registerCommand(_K, {
				name = "testecho",
				description = "Echoes a freeText string",
				group = "utility",
				args = {
					{
						type = "string",
						name = "Message",
						description = "Free text message",
						optional = true,
					},
				},
				run = function(_context, msg)
					table.insert(echoed, msg or "")
				end,
			})

			_K.Registry.registerCommand(_K, {
				name = "testboom",
				description = "Throws an error during run",
				group = "utility",
				args = {},
				run = function()
					error("kaboom failure")
				end,
			})

			-- 1. freeText liveText redaction ("…"): first log off cooldown is revealed immediately;
			-- second log within 60s sends full log to sender and redacted "…" to other admins and Data.logs
			local okEcho = _K.Process.runCommands(_K, modPlayer.UserId, ";testecho secret_phrase", false)
			expect(okEcho).toBe(true)
			h.env:step(0.05)
			local senderLog, otherLog
			for _, entry in remoteLogs do
				if entry.to == modPlayer.UserId and string.find(entry.text, ";testecho", 1, true) then
					senderLog = entry.text
				elseif entry.to == otherAdmin.UserId and string.find(entry.text, ";testecho", 1, true) then
					otherLog = entry.text
				end
			end
			expect(senderLog).toBe(";testecho secret_phrase")
			expect(otherLog).toBe(";testecho secret_phrase")
			expect(_K.Data.logs[#_K.Data.logs][1]).toBe(";testecho secret_phrase")

			table.clear(remoteLogs)
			local okEcho2 = _K.Process.runCommands(_K, modPlayer.UserId, ";testecho second_secret", false)
			expect(okEcho2).toBe(true)
			h.env:step(0.05)
			local friendLog
			senderLog, otherLog, friendLog = nil, nil, nil
			for _, entry in remoteLogs do
				if entry.to == modPlayer.UserId and string.find(entry.text, ";testecho", 1, true) then
					senderLog = entry.text
				elseif entry.to == otherAdmin.UserId and string.find(entry.text, ";testecho", 1, true) then
					otherLog = entry.text
				elseif entry.to == friendAdmin.UserId and string.find(entry.text, ";testecho", 1, true) then
					friendLog = entry.text
				end
			end
			expect(senderLog).toBe(";testecho second_secret")
			expect(friendLog).toBe(";testecho second_secret")
			expect(otherLog).toBe(";testecho …")
			expect(_K.Data.logs[#_K.Data.logs][1]).toBe(";testecho …")

			-- 2. Long rawText (> 1024 bytes) for non-restricted role (everyone/guest) is truncated to 1024 bytes
			local longArg = string.rep("x", 1200)
			local okLong = _K.Process.runCommands(_K, guestPlayer.UserId, ";testecho " .. longArg, true)
			expect(okLong).toBe(true)
			expect(#echoed[#echoed] < 1024).toBe(true)
			expect(#echoed[#echoed]).toBe(1024 - #";testecho ")

			-- 3. Rate limit & cooldown warning for guest (everyone role has limits.commands = 4, cooldown = 4)
			-- Guest already ran 1 command above; chaining 5 more commands hits the limit of 4
			table.clear(notifications)
			_K.Process.runCommands(
				_K,
				guestPlayer.UserId,
				";testecho a ;testecho b ;testecho c ;testecho d ;testecho e",
				true
			)
			local sawLimitAlert = false
			for _, n in notifications do
				if n.to == guestPlayer.UserId and string.find(n.text, "Command limit reached!", 1, true) then
					sawLimitAlert = true
				end
			end
			expect(sawLimitAlert).toBe(true)

			-- Subsequent command while on cooldown returns false and alerts "Command usage on cooldown!"
			table.clear(notifications)
			local okCooldown = _K.Process.runCommands(_K, guestPlayer.UserId, ";testecho blocked", true)
			expect(okCooldown).toBe(false)
			expect(string.find(notifications[1].text, "cooldown", 1, true) ~= nil).toBe(true)

			-- Stepping past the 4-second cooldown resets the limit
			h.env:step(4.5)
			expect(_K.Process.runCommands(_K, guestPlayer.UserId, ";testecho after_cooldown", true)).toBe(true)

			-- 4. Command execution failure (`run` throws) notifies caller and logs ERROR
			table.clear(notifications)
			table.clear(remoteLogs)
			local okBoom = _K.Process.runCommands(_K, modPlayer.UserId, ";testboom", false)
			expect(okBoom).toBe(false)
			expect(#notifications >= 1).toBe(true)
			expect(string.find(notifications[1].text, "command failed", 1, true) ~= nil).toBe(true)
			expect(string.find(notifications[1].text, "kaboom failure", 1, true) ~= nil).toBe(true)
		end
	)

	test("Command: shouldRequest, requestCommand accept/deny flow, and shouldFillWithSelf auto-filling", function()
		local h = Harness.newEnv()
		local Data = h:requireData()
		local _K = h:requireK()
		Data.settings.prefix = { ";" }
		Data.settings.commandRequests = true

		local mod1 = h.env:addPlayer(101, "ModCaller")
		local mod2 = h.env:addPlayer(102, "PeerMod")
		local guest = h.env:addPlayer(103, "LowGuest")
		mod1:SetAttribute("_KRolesLoaded", true)
		mod2:SetAttribute("_KRolesLoaded", true)
		guest:SetAttribute("_KRolesLoaded", true)
		_K.Auth.userRoleAdd(mod1.UserId, "mod")
		_K.Auth.userRoleAdd(mod2.UserId, "mod")

		local ranTargets = {}
		local ranPair = nil
		_K.Registry.registerCommand(_K, {
			name = "testreq",
			description = "Tests shouldRequest and shouldFillWithSelf",
			group = "moderation",
			args = {
				{
					type = "player",
					name = "Target",
					description = "Target player",
					lowerRank = true,
					shouldRequest = true,
				},
				{
					type = "integer",
					name = "Power",
					description = "Power value",
				},
			},
			run = function(_context, target, power)
				table.insert(ranTargets, { target = target, power = power })
			end,
		})

		_K.Registry.registerCommand(_K, {
			name = "testpair",
			description = "Two consecutive player args for shouldFillWithSelf",
			group = "moderation",
			args = {
				{
					type = "players",
					name = "FromPlayers",
					description = "Players to move",
				},
				{
					type = "player",
					name = "ToPlayer",
					description = "Destination player",
				},
			},
			run = function(_context, fromPlayers, toPlayer)
				ranPair = { from = fromPlayers, to = toPlayer }
			end,
		})

		-- 1. shouldFillWithSelf: omitting the player arg in ";testreq 77" auto-fills "me" (mod1) and shifts "77" to Power
		local okSelf = _K.Process.runCommands(_K, mod1.UserId, ";testreq 77", true)
		expect(okSelf).toBe(true)
		expect(#ranTargets).toBe(1)
		expect(ranTargets[1].target).toBe(mod1)
		expect(ranTargets[1].power).toBe(77)

		-- Two consecutive player args: ";testpair LowGuest" auto-fills arg 1 with "me" (mod1) and arg 2 with guest
		local okPair = _K.Process.runCommands(_K, mod1.UserId, ";testpair LowGuest", true)
		expect(okPair).toBe(true)
		expect(ranPair ~= nil).toBe(true)
		expect(ranPair.from[1]).toBe(mod1)
		expect(ranPair.to).toBe(guest)

		-- 2. shouldRequest & requestCommand when targeting equal/higher rank player (mod2):
		-- First test denied request (Invoke returns false)
		local invokeCount = 0
		_K.Remote.RequestCommand.Invoke = function(_self, _targetPlayer, _fromPlayer, _cmdText)
			invokeCount += 1
			return false
		end
		table.clear(ranTargets)
		local okDenied = _K.Process.runCommands(_K, mod1.UserId, ";testreq PeerMod 55", true)
		expect(okDenied).toBe(true)
		h.env:step(0.05)
		expect(invokeCount).toBe(1)
		expect(#ranTargets).toBe(0)

		-- Next test accepted request (Invoke returns true -> executes command)
		_K.Remote.RequestCommand.Invoke = function(_self, _targetPlayer, _fromPlayer, _cmdText)
			invokeCount += 1
			return true
		end
		local okAccepted = _K.Process.runCommands(_K, mod1.UserId, ";testreq PeerMod 88", true)
		expect(okAccepted).toBe(true)
		h.env:step(0.05)
		expect(invokeCount).toBe(2)
		expect(#ranTargets).toBe(1)
		expect(ranTargets[1].target).toBe(mod2)
		expect(ranTargets[1].power).toBe(88)

		-- a joining player's group and gamepass roles haven't loaded, so its rank reads 0 but it's still asked first
		local joining = h.env:addPlayer(104, "JoiningAdmin")
		table.clear(ranTargets)
		local okJoining = _K.Process.runCommands(_K, mod1.UserId, ";testreq JoiningAdmin 66", true)
		expect(okJoining).toBe(true)
		h.env:step(0.05)
		expect(invokeCount).toBe(3)
		expect(#ranTargets).toBe(1)
		expect(ranTargets[1].target).toBe(joining)

		-- the creator and loaded lower ranks are never asked
		table.clear(ranTargets)
		expect(_K.Process.runCommands(_K, _K.creatorId, ";testreq JoiningAdmin 67", true)).toBe(true)
		expect(_K.Process.runCommands(_K, mod1.UserId, ";testreq LowGuest 68", true)).toBe(true)
		h.env:step(0.05)
		expect(invokeCount).toBe(3)
		expect(#ranTargets).toBe(2)

		-- 3. Player list (`players`) with shouldRequest = true (strips peer/higher-rank players and requests them individually)
		local listTargets = {}
		local function registerReqList(aliases: { string })
			_K.Registry.registerCommand(_K, {
				name = "testreqlist",
				description = "Tests shouldRequest on players list",
				group = "moderation",
				aliases = aliases,
				args = {
					{
						type = "players",
						name = "Targets",
						description = "Target players",
						shouldRequest = true,
					},
				},
				run = function(_context, targets)
					for _, p in targets do
						table.insert(listTargets, p)
					end
				end,
			})
		end
		registerReqList({ "trl_old" })
		-- Re-register testreqlist with new aliases to verify old alias cleanup
		h.env:step(0.25)
		registerReqList({ "trl_new" })
		h.env:step(0.25)
		expect(_K.Registry.commands.trl_old).toBeNil()
		expect(_K.Registry.commands.trl_new ~= nil).toBe(true)
		expect(table.find(_K.Registry.commandNames, "trl_new") ~= nil).toBe(true)

		-- Verify commandNames is sorted by length then alphabetically
		for i = 2, #_K.Registry.commandNames do
			local a, b = _K.Registry.commandNames[i - 1], _K.Registry.commandNames[i]
			expect(#a < #b or (#a == #b and a <= b)).toBe(true)
		end

		-- Verify suggestCommandAlias exact match (distance == 0) and prefix match
		expect(_K.Registry.suggestCommandAlias("testreq")).toBe("testreq")
		expect(_K.Registry.suggestCommandAlias("trl_ne")).toBe("trl_new")

		-- Run testreqlist targeting only PeerMod (prepared becomes empty -> returns true early and spawns requestCommand)
		_K.Remote.RequestCommand.Invoke = function(_self, _targetPlayer, _fromPlayer, _cmdText)
			return false
		end
		table.clear(listTargets)
		local okListSolo = _K.Process.runCommands(_K, mod1.UserId, ";testreqlist PeerMod", true)
		expect(okListSolo).toBe(true)
		h.env:step(0.05)
		expect(#listTargets).toBe(0)

		-- Run testreqlist with NO arguments (`;testreqlist`) -> auto-inserts `""` for first player arg -> targets mod1 (self)
		local okAutoSelf = _K.Process.runCommands(_K, mod1.UserId, ";testreqlist", true)
		expect(okAutoSelf).toBe(true)
		expect(#listTargets).toBe(1)
		expect(listTargets[1]).toBe(mod1)

		-- Direct Command:validate() checks for missing arg, invalid arg, optional skipped arg, and client shouldFillWithSelf
		local Command = h.env:require(h.Shared.Process.Command)
		local rawMissing = _K.Process.rawParse(";testreq", { ";" }, " ")
		local cmdMissing =
			Command.new(_K, "testreq", _K.Registry.commands.testreq, rawMissing[1], mod1.UserId, ";testreq")
		local okMiss, errMiss = cmdMissing:validate()
		expect(okMiss).toBe(false)
		expect(type(errMiss)).toBe("string")
		expect(cmdMissing.invalidPos).toBe(2)
		expect(cmdMissing.invalidArg).toBe("testreq")

		local rawBad = _K.Process.rawParse(";testreq LowGuest notanint", { ";" }, " ")
		local cmdBad = Command.new(
			_K,
			"testreq",
			_K.Registry.commands.testreq,
			rawBad[1],
			mod1.UserId,
			";testreq LowGuest notanint"
		)
		local okBad, errBad = cmdBad:validate()
		expect(okBad).toBe(false)
		expect(type(errBad)).toBe("string")
		expect(cmdBad.invalidArg).toBe("notanint")
		expect(cmdBad.invalidPos ~= nil).toBe(true)
		expect(cmdBad.invalidMessage ~= nil).toBe(true)

		local rawSelfShift = _K.Process.rawParse(";testreq 42", { ";" }, " ")
		local cmdSelfShift =
			Command.new(_K, "testreq", _K.Registry.commands.testreq, rawSelfShift[1], mod1.UserId, ";testreq 42")
		local okShift = cmdSelfShift:validate()
		expect(okShift).toBe(true)
		expect(cmdSelfShift.args[1].skipped).toBe("42")

		-- Command:requestCommand when self.fromPlayer is nil (e.g. triggered via ;global by an offline admin)
		local invokedFrom
		_K.Remote.RequestCommand.Invoke = function(_self, _target, fromArg, _text)
			invokedFrom = fromArg
			return true
		end
		local notifyFiredOnNil = false
		local origNotifyFire = _K.Remote.Notify.Fire
		_K.Remote.Notify.Fire = function(_self, plr, ...)
			if plr == nil then
				notifyFiredOnNil = true
			end
			if origNotifyFire then
				return origNotifyFire(_self, plr, ...)
			end
			return
		end
		_K.Auth.userRoleAdd(9999, "mod")
		local rawOffline = _K.Process.rawParse(";testreq PeerMod 7", { ";" }, " ")
		local cmdOffline =
			Command.new(_K, "testreq", _K.Registry.commands.testreq, rawOffline[1], 9999, ";testreq PeerMod 7")
		expect(cmdOffline.fromPlayer).toBeNil()
		expect(cmdOffline:validate()).toBe(true)
		local ranOffline = false
		cmdOffline:requestCommand(mod2, { mod2, 7 }, function()
			ranOffline = true
		end)
		expect(notifyFiredOnNil).toBe(false)
		expect(invokedFrom).toBe(9999)
		expect(ranOffline).toBe(true)
		_K.Remote.Notify.Fire = origNotifyFire
	end)
end)

describe("Process · Command filters & async roles", function()
	test("command filters cancel commands and drop targets before requests and run", function()
		local h = Harness.newEnv()
		local Data = h:requireData()
		local _K = h:requireK()
		Data.settings.prefix = { ";" }
		Data.settings.commandRequests = true
		local admin = h.env:addPlayer(101, "FilterAdmin")
		local peer = h.env:addPlayer(102, "FilterPeer")
		local guest = h.env:addPlayer(103, "FilterGuest")
		for _, player in { admin, peer, guest } do
			player:SetAttribute("_KRolesLoaded", true)
		end
		_K.Auth.userRoleAdd(admin.UserId, "admin")
		_K.Auth.userRoleAdd(peer.UserId, "admin")

		local runs = {}
		_K.Registry.registerCommand(_K, {
			name = "testfilter",
			description = "Command filter target",
			group = "administration",
			args = {
				{ type = "players", name = "Targets", description = "Targets", shouldRequest = true },
			},
			run = function(_context, targets)
				table.insert(runs, { targets = table.clone(targets) })
			end,
		})
		_K.Registry.registerCommand(_K, {
			name = "testsingle",
			description = "Command filter target with one player",
			group = "administration",
			args = {
				{ type = "player", name = "Target", description = "Target" },
			},
			run = function(_context, target)
				table.insert(runs, { targets = { target } })
			end,
		})
		_K.Registry.registerCommand(_K, {
			name = "testoptsingle",
			description = "Command filter target with an optional player",
			group = "administration",
			args = {
				{ type = "player", name = "Target", description = "Target", optional = true },
				{ type = "integer", name = "Count", description = "Count", optional = true },
			},
			run = function(_context, target, count)
				table.insert(runs, { targets = { target }, count = count })
			end,
		})
		local notes = {}
		_K.Remote.Notify.Fire = function(_self, _player, props)
			table.insert(notes, props.Text)
		end
		local requested = {}
		_K.Remote.RequestCommand.Invoke = function(_self, target)
			table.insert(requested, target)
			return false
		end

		-- a filter sees the prepared command and can cancel it with a reason
		local seen
		local removeBlock = _K.Process.addCommandFilter(function(command)
			seen = command
			if command.alias == "testfilter" and table.find(command.preparedArgs[1], guest) then
				return false, "Guests are protected here."
			end
			return true
		end)
		expect(_K.Process.runCommands(_K, admin.UserId, ";testfilter me,FilterGuest", true)).toBe(false)
		expect(#runs).toBe(0)
		expect(seen.from).toBe(admin.UserId)
		expect(string.find(notes[#notes], "Guests are protected here.", 1, true) ~= nil).toBe(true)

		-- dropped targets are gone before the request split: the peer isn't asked and the rest still run
		local notTargeted = h.env:addPlayer(199, "NotTargeted")
		local dropped = {}
		local removeDrop = _K.Process.addCommandFilter(function(command)
			if command.alias == "testfilter" then
				table.insert(dropped, command:dropTarget(1, peer))
				table.insert(dropped, command:dropTarget(1, notTargeted))
			end
			return true
		end)
		expect(_K.Process.runCommands(_K, admin.UserId, ";testfilter FilterPeer,me", true)).toBe(true)
		h.env:step(0.05)
		expect(dropped).toEqual({ true, false })
		expect(#requested).toBe(0)
		expect(#runs).toBe(1)
		expect(runs[1].targets).toEqual({ admin })
		-- without targets left the command is cancelled
		expect(_K.Process.runCommands(_K, admin.UserId, ";testfilter FilterPeer", true)).toBe(false)
		expect(#runs).toBe(1)
		expect(string.find(notes[#notes], "No players left", 1, true) ~= nil).toBe(true)
		removeDrop()
		removeDrop() -- removing twice is harmless

		-- a single player argument can be dropped too, which cancels the command unless optional
		local single = {}
		local removeSingle = _K.Process.addCommandFilter(function(command)
			if command.alias == "testsingle" or command.alias == "testoptsingle" then
				single.dropped = command:dropTarget(1, admin)
				single.left = command.preparedArgs[1]
			end
			return true
		end)
		expect(_K.Process.runCommands(_K, admin.UserId, ";testsingle me", true)).toBe(false)
		expect(single.dropped).toBe(true)
		expect(single.left).toBeNil()
		expect(#runs).toBe(1)
		expect(_K.Process.runCommands(_K, admin.UserId, ";testoptsingle me 42", false)).toBe(true)
		h.env:step(0.05)
		expect(single.dropped).toBe(true)
		expect(single.left).toBeNil()
		expect(#runs).toBe(2)
		expect(runs[2].targets).toEqual({})
		expect(runs[2].count).toBe(42)
		expect(_K.Data.logs[#_K.Data.logs][1]).toBe(";testoptsingle  42")
		removeSingle()
		expect(_K.Process.runCommands(_K, admin.UserId, ";testsingle me", true)).toBe(true)
		expect(#runs).toBe(3)

		-- a filter that errors or forgets to allow cancels the command
		local removeError = _K.Process.addCommandFilter(function()
			error("filter bug")
		end)
		expect(_K.Process.runCommands(_K, admin.UserId, ";testfilter me", true)).toBe(false)
		expect(string.find(notes[#notes], "filter error", 1, true) ~= nil).toBe(true)
		removeError()
		local removeNil = _K.Process.addCommandFilter(function()
			return nil :: any
		end)
		expect(_K.Process.runCommands(_K, admin.UserId, ";testfilter me", true)).toBe(false)
		expect(string.find(notes[#notes], "Command blocked.", 1, true) ~= nil).toBe(true)
		removeNil()

		removeBlock()
		expect(_K.Process.runCommands(_K, admin.UserId, ";testfilter me,FilterGuest", true)).toBe(true)
		expect(#runs).toBe(4)
		expect(table.find(runs[4].targets, guest) ~= nil).toBe(true)
		expect(function()
			_K.Process.addCommandFilter("nope" :: any)
		end).toThrow()
	end)

	test("roles from groups and purchases outlast userRoleRemove, given roles stay per session", function()
		local h = Harness.newEnv()
		local Data = h:requireData()
		local Auth = h:requireAuth()
		local userId = 404

		-- a role given in the session isn't saved and is removed normally
		expect(Auth.userRoleAdd(userId, "mod")).toBe(true)
		expect(Data.Sync.members[tostring(userId)]).toBeNil()
		expect(Data.members[tostring(userId)].persist).toEqual({})
		expect(Auth.hasAsyncRole(userId, "mod")).toBe(false)
		expect(Auth.userRoleRemove(userId, "mod")).toBe(true)
		expect(Auth.hasRole(userId, "mod")).toBe(false)

		-- an owned role stays, only its saved copy is removed
		expect(Auth.asyncRoleAdd(userId, "mod")).toBe(true)
		expect(Auth.hasAsyncRole(userId, "mod")).toBe(true)
		expect(Auth.hasAsyncRole(tostring(userId) :: any, "mod")).toBe(true)
		expect(Auth.hasAsyncRole(userId, "admin")).toBe(false)
		expect(Auth.userRoleRemove(userId, "mod")).toBe(false)
		expect(Auth.hasRole(userId, "mod")).toBe(true)
		Auth.userRoleAdd(userId, "mod", true)
		expect(Data.members[tostring(userId)].persist).toEqual({ "mod" })
		expect(Auth.userRoleRemove(userId, "mod")).toBe(true)
		expect(Data.members[tostring(userId)].persist).toEqual({})
		expect(Auth.hasRole(userId, "mod")).toBe(true)

		-- gamepass, asset, subscription and group roles are owned
		local player = h.env:addPlayer(405, "Owner")
		Data.async.gamepass[1] = { "vip" }
		Data.async.asset[2] = { "admin" }
		Data.async.subscription.sub = { "superadmin" }
		Data.async.group[3] = { { rank = 1, roles = { "mod" } } }
		local market = rawget(h.env.game:GetService("MarketplaceService"), "_methods")
		market.UserOwnsGamePassAsync = function()
			return true
		end
		market.PlayerOwnsAssetAsync = function()
			return true
		end
		market.GetUserSubscriptionStatusAsync = function()
			return { IsSubscribed = true }
		end
		local groupMethods: any = rawget(h.env.game:GetService("GroupService"), "_methods")
		groupMethods.GetGroupsAsync = function()
			return { { Id = 3, Rank = 5 } }
		end
		local done = false
		h.env.task.spawn(function()
			Auth.userAsyncRoles(player.UserId)
			done = true
		end)
		h.env:flush()
		expect(done).toBe(true)
		for _, roleId in { "vip", "admin", "superadmin", "mod" } do
			expect(Auth.hasAsyncRole(player.UserId, roleId)).toBe(true)
			Auth.userRoleRemove(player.UserId, roleId)
			expect(Auth.hasRole(player.UserId, roleId)).toBe(true)
		end
	end)

	test(
		"rawParse handles pattern-special splitKeys, Argument:prepare counts targets once, and runCommands enforces commandLimits",
		function()
			local h = Harness.newEnv({ isStudio = false })
			local Data = h:requireData()
			local _K = h:requireK()
			Data.settings.prefix = { ";" }
			local Process = _K.Process

			-- 1. Pattern-special splitKey (% and .) does not error or split every character
			for _, delim in { "%", "." } do
				local parsed = Process.rawParse(";cmds%a%;version", { ";" }, delim)
				expect(parsed ~= nil).toBe(true)
				if delim == "%" then
					expect(#(parsed :: any)).toBe(2)
					expect((parsed :: any)[1][1][2]).toBe("cmds")
					expect((parsed :: any)[1][2][2]).toBe("a")
					expect((parsed :: any)[2][1][2]).toBe("version")
				end
			end

			-- 2. Argument:prepare with limits.targets = 1 allows 1 target across validate + parse and rejects 2
			local vipPlr = h.env:addPlayer(501, "VipTargetTester")
			local otherPlr = h.env:addPlayer(502, "OtherTargetTester")
			vipPlr:SetAttribute("_KRolesLoaded", true)
			otherPlr:SetAttribute("_KRolesLoaded", true)
			_K.Auth.userRoleAdd(vipPlr.UserId, "vip")
			_K.Data.roles.vip.permissions.targetOthers = true
			_K.Data.roles.vip.limits = { commands = 1, cooldown = 10, targets = 1 }

			local runs = 0
			_K.Registry.registerCommand(_K, {
				name = "testlimitcmd",
				description = "Test command limits",
				group = "general",
				permissions = {},
				args = {
					{ type = "players", name = "Targets", description = "Targets" },
				},
				run = function(_context, targets)
					runs += #targets
				end,
			})
			_K.Data.roles.vip.groups = { "general" }

			-- Targeting 2 players fails validation when limits.targets == 1 and still counts against commandLimits
			expect(Process.runCommands(_K, vipPlr.UserId, ";testlimitcmd me,OtherTargetTester", true)).toBe(false)
			expect(runs).toBe(0)
			expect(Process.onCooldown(_K, vipPlr.UserId)).toBe(true)
			h.env:step(10)

			-- Chaining 2 single-target commands in one message also fails validation when limits.targets == 1
			_K.Data.roles.vip.limits = { commands = 2, cooldown = 10, targets = 1 }
			expect(Process.runCommands(_K, vipPlr.UserId, ";testlimitcmd me ;testlimitcmd OtherTargetTester", true)).toBe(
				false
			)
			expect(runs).toBe(0)
			expect(Process.onCooldown(_K, vipPlr.UserId)).toBe(true)
			h.env:step(10)
			_K.Data.roles.vip.limits = { commands = 1, cooldown = 10, targets = 1 }

			-- Targeting 1 player succeeds through both validate and parse, and consumes the 1 command limit
			expect(Process.runCommands(_K, vipPlr.UserId, ";testlimitcmd me", true)).toBe(true)
			expect(runs).toBe(1)

			-- Second command within cooldown is blocked before execution
			expect(Process.runCommands(_K, vipPlr.UserId, ";testlimitcmd me", true)).toBe(false)
			expect(runs).toBe(1)
		end
	)
end)

return {}
