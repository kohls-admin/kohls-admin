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

	local function sanitizeQuotePayload(raw: string, quoteChar: string): string
		-- Ensure valid UTF-8 and strip the enclosing quote char so the payload cannot prematurely close the quote
		local clean = if utf8.len(raw) then raw else "utf8_fallback"
		clean = string.gsub(clean, "[%z\r\n]", "")
		clean = string.gsub(clean, quoteChar, if quoteChar == '"' then "'" else '"')
		if #clean == 0 then
			clean = "payload"
		end
		return clean
	end

	local astGen = function(g: any)
		local multiChar = g:bool(0.25)
		local prefix = if multiChar then g:pick({ "::", "!!", ";;" }) else g:pick({ ";", "!", ":" })
		local cmdCount = if multiChar then 1 else g:int(1, 3)
		local leadNoise = if g:bool(0.35) then g:pick({ "", "hello ", "chat before " }) else ""
		local cmds = {}
		for c = 1, cmdCount do
			local name = g:pick({ "fly", "ban", "kick", "announce", "fuzzcmd", "fcmd" })
			local argCount = g:int(0, 4)
			local args = {}
			for a = 1, argCount do
				local kind = g:int(1, 6)
				if kind == 1 then
					args[a] = g:pick({ "me", "all", "others", "*", "@mod", "%red", "~1", "$admins" })
				elseif kind == 2 then
					local inner = g:pick({
						"hello ; world",
						"nested `tick` inside",
						"a,b,c",
						"100%s",
						"escaped \\'single\\' text",
					})
					args[a] = `"{inner}"`
				elseif kind == 3 then
					local inner = g:pick({ 'nested "double" inside', "semi ; colon", "space sep" })
					args[a] = "`" .. inner .. "`"
				elseif kind == 4 then
					local mal = sert.gen.malformedString()(g)
					local q = g:pick({ '"', "`" })
					args[a] = q .. sanitizeQuotePayload(mal, q) .. q
				elseif kind == 5 and a == argCount then
					-- Greedy trailing argument tokens
					args[a] = g:pick({ "greedy_tail_one", "reason_token", "trailing_note" })
				else
					args[a] = tostring(g:int(-1000, 1000))
				end
			end
			cmds[c] = { name = name, args = args }
		end
		return { leadNoise = leadNoise, prefix = prefix, cmds = cmds }
	end

	local function unparseAst(spec: any): (string, { { { pos: number, endPos: number, text: string } } })
		local chunks = {}
		local expected = {}
		local cursor = #spec.leadNoise + 1
		for cIdx, c in spec.cmds do
			if cIdx > 1 then
				table.insert(chunks, " ")
				cursor += 1
			end
			local cmdRow = {}
			local firstTok = spec.prefix .. c.name
			table.insert(chunks, firstTok)
			local nameStart = cursor + #spec.prefix - #spec.leadNoise
			table.insert(cmdRow, {
				pos = nameStart,
				endPos = nameStart + #c.name - 1,
				text = c.name,
			})
			cursor += #firstTok
			for _, a in c.args do
				table.insert(chunks, " ")
				cursor += 1
				table.insert(chunks, a)
				local argStart = cursor - #spec.leadNoise
				table.insert(cmdRow, {
					pos = argStart,
					endPos = argStart + #a - 1,
					text = a,
				})
				cursor += #a
			end
			expected[cIdx] = cmdRow
		end
		return spec.leadNoise .. table.concat(chunks, ""), expected
	end

	sert.laws.differential("Process.rawParse AST roundtrip & token byte spans", {
		gen = astGen,
		sut = function(spec: any)
			local Process = Harness.shared():requireProcess()
			local message = unparseAst(spec)
			local parsed = Process.rawParse(message, { spec.prefix }, " ")
			expect(parsed ~= nil).toBe(true)
			local out = {}
			local leadLen = #spec.leadNoise
			expect(string.sub(message, leadLen + 1, leadLen + #spec.prefix)).toBe(spec.prefix)
			for i, cmdArr in parsed :: { any } do
				expect(#cmdArr >= 1).toBe(true)
				local row = {}
				for j, tok in cmdArr do
					local argPos: number = tok[1]
					local argStr: string = tok[2]
					local absStart = leadLen + argPos
					local absEnd = absStart + #argStr - 1
					expect(string.sub(message, absStart, absEnd)).toBe(argStr)
					row[j] = {
						pos = argPos,
						endPos = argPos + #argStr - 1,
						text = argStr,
					}
				end
				out[i] = row
			end
			return out
		end,
		oracle = function(spec: any)
			local _, expected = unparseAst(spec)
			return expected
		end,
	}, { runs = 80 })

	prop(
		"rawParse enforces prefix, non-empty command array, exact byte span slicing, and unclosed quote offset laws",
		function(g)
			local Process = Harness.shared():requireProcess()
			local noise = g:string(nil, 0, 40)
			local ok, parsed, err = pcall(Process.rawParse, noise, MULTI_PREFIX, " ")
			expect(ok).toBe(true)
			expect(parsed == nil or type(parsed) == "table").toBe(true)
			if parsed ~= nil and utf8.len(noise) then
				expect(#parsed >= 1).toBe(true)
				local matchedPrefix, matchStart = nil, nil
				for _, p in MULTI_PREFIX do
					local escapedP = string.gsub(p, "([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
					local s = string.find(noise, string.format('%s[^%s"`, ]', escapedP, escapedP))
					if s then
						matchedPrefix = p
						matchStart = s
						break
					end
				end
				expect(matchedPrefix ~= nil).toBe(true)
				expect(matchStart ~= nil).toBe(true)
				for _, cmdArr in parsed do
					expect(#cmdArr >= 1).toBe(true)
					for _, tok in cmdArr do
						expect(type(tok[1])).toBe("number")
						expect(type(tok[2])).toBe("string")
						expect(tok[1] >= 1).toBe(true)
					end
				end
			elseif parsed == nil and err ~= nil then
				expect(type(err) == "string" or type(err) == "number").toBe(true)
			end

			-- Unclosed quote law: verify exact unmatched opening quote byte offset
			local cmd = g:string("abcdefghijklmnopqrstuvwxyz", 1, 10)
			local arg1 = g:string("abcdefghijklmnopqrstuvwxyz0123456789", 1, 10)
			local tail = g:string("abcdefghijklmnopqrstuvwxyz0123456789", 1, 10)
			local quoteChar = g:pick({ '"', "`" })
			local unclosedMsg = `;{cmd} {arg1} {quoteChar}{tail} ;not_a_new_cmd`
			local expectedQuoteOffset = 1 + #cmd + 1 + #arg1 + 1 + 1
			expect(string.sub(unclosedMsg, expectedQuoteOffset, expectedQuoteOffset)).toBe(quoteChar)

			local unclosedParsed, unclosedErr = Process.rawParse(unclosedMsg, DEFAULT_PREFIX, " ")
			if unclosedParsed == nil then
				expect(unclosedErr).toBe(expectedQuoteOffset)
			else
				expect(#unclosedParsed).toBe(1)
				local quoteTok = unclosedParsed[1][3]
				expect(quoteTok[1]).toBe(expectedQuoteOffset)
				expect(quoteTok[2]).toBe(string.sub(unclosedMsg, expectedQuoteOffset))
				expect(string.sub(unclosedMsg, quoteTok[1], quoteTok[1] + #quoteTok[2] - 1)).toBe(quoteTok[2])
			end
		end,
		{ runs = 80 }
	)
end)

describe("Process · Registry & DefaultTypes Contract Laws", function()
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

	local gen = sert.gen
	sert.check(
		"built-in scalar, color, timeSimple, vector, and enum types round-trip valid inputs and reject malformed ones",
		{
			gen.int(-10000, 10000),
			gen.color3(),
			gen.int(1, 120),
			gen.int(1, 59),
			gen.vector3(gen.int(-500, 500)),
			gen.enum(Harness.globals.Enum.Material),
		},
		function(n, expectedColor, mins, secs, vec, matItem)
			local types = getPropTypes()
			local Vector2 = Harness.globals.Vector2

			local intVal = types.integer.transform(tostring(n))
			expect((types.integer.validate(intVal))).toBe(true)
			expect(types.integer.parse(intVal)).toBe(n)
			expect((types.integer.validate(types.integer.transform("not_a_number")))).toBe(false)

			local r = math.round(expectedColor.R * 255)
			local gr = math.round(expectedColor.G * 255)
			local b = math.round(expectedColor.B * 255)
			local hex = string.format("#%02x%02x%02x", r, gr, b)
			local cHex = types.color.transform(hex)
			expect((types.color.validate(cHex))).toBe(true)
			expect(types.color.parse(cHex)).toEqual(expectedColor)
			local cRgb = types.color.transform(`{r},{gr},{b}`)
			expect((types.color.validate(cRgb))).toBe(true)
			expect(types.color.parse(cRgb)).toEqual(expectedColor)
			expect((types.color.validate(types.color.transform("#zzzzzz")))).toBe(false)

			local okTime, parsedTime = types.timeSimple.validate(`{mins}m {secs}s`)
			expect(okTime).toBe(true)
			expect(parsedTime).toBe(mins * 60 + secs)
			expect((types.timeSimple.validate("invalid_time_xyz"))).toBe(false)

			local vx, vy, vz = vec.X, vec.Y, vec.Z
			local v2Val = types.vector2.transform(`{vx},{vy}`)
			expect((types.vector2.validate(v2Val))).toBe(true)
			expect(types.vector2.parse(v2Val)).toEqual(Vector2.new(vx, vy))
			expect((types.vector2.validate(types.vector2.transform("1,2,3")))).toBe(false)

			local v3Val = types.vector3.transform(`{vx},{vy},{vz}`)
			expect((types.vector3.validate(v3Val))).toBe(true)
			expect(types.vector3.parse(v3Val)).toEqual(vec)
			expect((types.vector3.validate(types.vector3.transform("1,bad,3")))).toBe(false)

			local enumType = types["Enum.Material"]
			local matName = matItem.Name
			expect((enumType.validate(matName))).toBe(true)
			expect(enumType.parse(matName)).toBe(matItem)
			expect(enumType.parse(string.lower(matName))).toBe(matItem)
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

			-- 1. Pattern-special splitKey (% and .) does not error or split every character, and legacy "%s" normalizes to " "
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
			local legacyParsed = Process.rawParse(";m h", { ";" }, "%s")
			expect(legacyParsed).toEqual({ { { 2, "m" }, { 4, "h" } } })
			expect(Process.rawParse(";m he", { ";" }, "%s")).toEqual({ { { 2, "m" }, { 4, "he" } } })

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

			-- Chaining multiple single-target commands in one message succeeds when limits.targets == 1 (per-argument target limit, #590)
			_K.Data.roles.vip.limits = { commands = 2, cooldown = 10, targets = 1 }
			expect(Process.runCommands(_K, vipPlr.UserId, ";testlimitcmd me ;testlimitcmd OtherTargetTester", true)).toBe(
				true
			)
			expect(runs).toBe(2)
			expect(Process.onCooldown(_K, vipPlr.UserId)).toBe(true)
			h.env:step(10)

			-- Multi-player-argument command also resets targetLimits per argument when limits.targets == 1
			local dualArgRuns = 0
			_K.Registry.registerCommand(_K, {
				name = "testdualtargetcmd",
				description = "Test dual player argument limits",
				group = "general",
				permissions = {},
				args = {
					{ type = "players", name = "From", description = "From" },
					{ type = "player", name = "To", description = "To" },
				},
				run = function(_context, fromTargets, _toTarget)
					dualArgRuns += #fromTargets
				end,
			})
			expect(Process.runCommands(_K, vipPlr.UserId, ";testdualtargetcmd me OtherTargetTester", true)).toBe(true)
			expect(dualArgRuns).toBe(1)
			expect(
				Process.runCommands(
					_K,
					vipPlr.UserId,
					";testdualtargetcmd me,OtherTargetTester OtherTargetTester",
					true
				)
			).toBe(false)
			h.env:step(10)
			runs = 0
			_K.Data.roles.vip.limits = { commands = 1, cooldown = 10, targets = 1 }

			-- Targeting 1 player succeeds through both validate and parse, and consumes the 1 command limit
			expect(Process.runCommands(_K, vipPlr.UserId, ";testlimitcmd me", true)).toBe(true)
			expect(runs).toBe(1)

			-- Second command within cooldown is blocked before execution
			expect(Process.runCommands(_K, vipPlr.UserId, ";testlimitcmd me", true)).toBe(false)
			expect(runs).toBe(1)
			h.env:step(10)

			-- 3. Process.countCommand & Process.onCooldown (client vs server)
			_K.Data.roles.vip.limits = { commands = 2, cooldown = 5, targets = 4 }
			Process.resetLimit(vipPlr.UserId)
			_K.IsServer = false
			expect(Process.onCooldown(_K, vipPlr.UserId)).toBe(false)
			Process.countCommand(_K, vipPlr.UserId, 2)
			expect(Process.onCooldown(_K, vipPlr.UserId)).toBe(false)
			_K.IsServer = true
			expect(Process.onCooldown(_K, vipPlr.UserId)).toBe(false)
			Process.countCommand(_K, vipPlr.UserId)
			expect(Process.onCooldown(_K, vipPlr.UserId)).toBe(false)
			Process.countCommand(_K, vipPlr.UserId, 1)
			expect(Process.onCooldown(_K, vipPlr.UserId)).toBe(true)
			h.env:step(5)
			expect(Process.onCooldown(_K, vipPlr.UserId)).toBe(false)

			-- 4. Process.prepareCommands maxPrepare cap, command.Error, and client VIP / GamePass / RestrictedToRole
			Process.countCommand(_K, vipPlr.UserId, 1) -- 1 left in limit of 2
			local okPrepCap, cappedCmds =
				Process.prepareCommands(_K, vipPlr.UserId, ";testlimitcmd me ;testlimitcmd me")
			expect(okPrepCap).toBe(true)
			expect(#cappedCmds).toBe(2)
			expect(cappedCmds[1].validated).toBe(true)
			expect(cappedCmds[2].validated).toBeNil()
			expect(cappedCmds[2].alias).toBe("testlimitcmd")
			Process.resetLimit(vipPlr.UserId)

			local okPrepFail, failMsg, failCmds =
				Process.prepareCommands(_K, vipPlr.UserId, ";testlimitcmd NonExistentPlayerXYZ")
			expect(okPrepFail).toBe(false)
			expect(failCmds[1].Error).toBe(failMsg)

			local guestPlr = h.env:addPlayer(503, "GuestPurchaseTester")
			guestPlr:SetAttribute("_KRolesLoaded", true)
			_K.IsServer = false
			_K.IsClient = true
			_K.LocalPlayer = guestPlr
			_K.client = {
				playerPrefix = {
					peek = function()
						return ";"
					end,
				},
			} :: any
			_K.Data.settings.vip = true
			local vipPrompted = 0
			local gpPrompted: { any } = {}
			_K.PromptPurchaseVIP = function()
				vipPrompted += 1
			end
			local marketMethods = rawget(h.env.game:GetService("MarketplaceService"), "_methods")
			marketMethods.PromptGamePassPurchase = function(_self, plr, gpId)
				table.insert(gpPrompted, { plr = plr, gpId = gpId })
			end
			_K.Data.roles.mod.gamepasses = { 777 }
			_K.Registry.commands.testlimitcmd.RestrictedToRole = { name = "VIP" }
			local okClientRestr, restrMsg = Process.prepareCommands(_K, guestPlr.UserId, ";testlimitcmd me")
			expect(okClientRestr).toBe(false)
			expect(restrMsg).toBe('"<b>testlimitcmd</b>" command restricted to <b>VIP</b>')
			expect(vipPrompted).toBe(1)
			expect(#gpPrompted).toBe(1)
			expect(gpPrompted[1].plr).toBe(guestPlr)
			expect(gpPrompted[1].gpId).toBe(777)
			_K.Registry.commands.testlimitcmd.RestrictedToRole = nil
			_K.Data.roles.mod.gamepasses = nil
			_K.IsClient = false
			_K.IsServer = true

			-- 5. Process.runCommands: >1024 restricted admin vs guest, Hook.runPreparedCommands, notRan alert, clientOnly, client Remote.Command
			local superPlr = h.env:addPlayer(504, "SuperLongCmdTester")
			superPlr:SetAttribute("_KRolesLoaded", true)
			_K.Auth.userRoleAdd(superPlr.UserId, "superadmin")
			local capturedEcho = nil
			_K.Registry.registerCommand(_K, {
				name = "testecho",
				description = "Echo string",
				group = "general",
				args = {
					{ type = "rawString", name = "Text", description = "Text" },
				},
				run = function(_context, txt)
					capturedEcho = txt
				end,
				runClient = function(_context, _txt) end,
			})
			_K.Registry.registerCommand(_K, {
				name = "testclientonlycmd",
				description = "Client only",
				group = "general",
				args = {},
				runClient = function(_context) end,
			})
			local longPayload = string.rep("x", 1050)
			local hookFired = nil
			local hookConn = _K.Hook.runPreparedCommands:Connect(function(f, res, raw)
				hookFired = { from = f, count = #res, rawLen = #raw }
			end)
			expect(Process.runCommands(_K, superPlr.UserId, ";testecho " .. longPayload, true)).toBe(true)
			expect(#(capturedEcho or "")).toBe(1050)
			expect(hookFired ~= nil and hookFired.from == superPlr.UserId and hookFired.count == 1).toBe(true)
			hookConn:Disconnect()

			-- Guest / non-restricted role has >1024 truncated in prepareCommands and runCommands
			_K.Data.roles.vip.limits = { commands = 2, cooldown = 5, targets = 4 }
			Process.resetLimit(vipPlr.UserId)
			expect(Process.runCommands(_K, vipPlr.UserId, ";testecho " .. longPayload, true)).toBe(true)
			expect(#(capturedEcho or "")).toBe(1024 - #";testecho ")
			Process.resetLimit(vipPlr.UserId)

			-- Command limit reached mid-batch alerts with notRan command aliases
			_K.Data.roles.vip.limits = { commands = 1, cooldown = 5, targets = 4 }
			local lastAlert = nil
			local origAlert = _K.alert
			_K.alert = function(f, msg, s)
				lastAlert = { from = f, msg = msg, server = s }
			end
			-- Pre-prepare 3 commands when limit is 1 by temporarily raising limit during prepareCommands via hook
			local expandConn = _K.Hook.runPreparedCommands:Connect(function(_f, res)
				table.insert(res, table.clone(res[1]))
				res[2].alias = "skippedone"
				table.insert(res, table.clone(res[1]))
				res[3].alias = "skippedtwo"
			end)
			expect(Process.runCommands(_K, vipPlr.UserId, ";testecho ok", true)).toBe(true)
			expandConn:Disconnect()
			_K.alert = origAlert
			expect(lastAlert ~= nil).toBe(true)
			expect(string.find((lastAlert :: any).msg, "Commands not ran: skippedone, skippedtwo", 1, true) ~= nil).toBe(
				true
			)
			Process.resetLimit(vipPlr.UserId)

			-- Empty/non-command string returns true
			expect(Process.runCommands(_K, superPlr.UserId, "hello world not a command", true)).toBe(true)

			-- Client runCommands: clientOnly suppresses prepare error notification; normal client forwards server commands & logs errors
			_K.IsServer = false
			_K.IsClient = true
			local clientNotifies = {}
			local clientErrorLogs = {}
			local remoteCmdFired = {}
			_K.Notify = function(props)
				table.insert(clientNotifies, props)
			end
			local origLog = _K.log
			local lastGlobalLogFlag = nil
			_K.log = function(txt, lvl, f, filt, live, glob)
				if lvl == "ERROR" then
					table.insert(clientErrorLogs, { text = txt, from = f })
				end
				lastGlobalLogFlag = glob
				return origLog(txt, lvl, f, filt, live, glob)
			end
			_K.Remote.Command = {
				Fire = function(_self, cmdStr)
					table.insert(remoteCmdFired, cmdStr)
				end,
			} :: any
			expect(Process.runCommands(_K, superPlr.UserId, ";nonexistentcmd", true, false, true)).toBe(false)
			h.env:flush()
			expect(#clientNotifies).toBe(0)
			expect(#clientErrorLogs).toBe(0)

			expect(Process.runCommands(_K, superPlr.UserId, ";nonexistentcmd", true, false, false)).toBe(false)
			h.env:flush()
			expect(#clientNotifies).toBe(1)
			expect(#clientErrorLogs).toBe(1)
			expect(clientErrorLogs[1].from).toBe(superPlr.UserId)

			expect(Process.runCommands(_K, superPlr.UserId, ";testclientonlycmd ;testecho hello", false, true, false)).toBe(
				true
			)
			h.env:flush()
			expect(#remoteCmdFired).toBe(1)
			expect(remoteCmdFired[1]).toBe(";testecho hello")
			expect(lastGlobalLogFlag).toBe(true)
			_K.log = origLog
			_K.IsClient = false
			_K.IsServer = true

			-- 6. Command:requestCommand error/failure paths & Command:run multi-peer request splitting & Command:validate / Argument edge cases
			local Command = h.env:require(h.Shared:WaitForChild("Process"):WaitForChild("Command"))
			local Argument = Command.Argument
			local peer1 = h.env:addPlayer(505, "PeerReqOne")
			local peer2 = h.env:addPlayer(506, "PeerReqTwo")
			local lowPlr = h.env:addPlayer(507, "LowReqTarget")
			for _, p in { peer1, peer2, lowPlr } do
				p:SetAttribute("_KRolesLoaded", true)
			end
			_K.Auth.userRoleAdd(peer1.UserId, "superadmin")
			_K.Auth.userRoleAdd(peer2.UserId, "superadmin")

			local reqNotifies = {}
			_K.Remote.Notify.Fire = function(_self, plr, props)
				table.insert(reqNotifies, { plr = plr, text = props.Text, from = props.From })
			end
			local multiRuns = {}
			local shouldErrInRun = false
			_K.Registry.registerCommand(_K, {
				name = "testmultireq",
				description = "Multi peer request command",
				group = "general",
				args = {
					{ type = "players", name = "Targets", description = "Targets", shouldRequest = true },
				},
				run = function(_context, targets)
					if shouldErrInRun then
						error("boom_in_run")
					end
					local names = {}
					for _, t in targets do
						table.insert(names, t.Name)
					end
					table.insert(multiRuns, names)
				end,
			})

			-- Invoke throws (player left during request)
			_K.Remote.RequestCommand.Invoke = function()
				error("player disconnected")
			end
			local okPrepReq, reqCmds = Process.prepareCommands(_K, superPlr.UserId, ";testmultireq PeerReqOne")
			expect(okPrepReq).toBe(true)
			local leftRes = reqCmds[1]:requestCommand(peer1, { { peer1 } }, _K.Registry.commands.testmultireq.run)
			expect(leftRes).toBe(false)
			expect(string.find(reqNotifies[#reqNotifies].text, "left during", 1, true) ~= nil).toBe(true)

			-- Accepted request where run errors notifies sender with "command failed:"
			_K.Remote.RequestCommand.Invoke = function()
				return true
			end
			shouldErrInRun = true
			table.clear(reqNotifies)
			reqCmds[1]:requestCommand(peer1, { { peer1 } }, _K.Registry.commands.testmultireq.run)
			expect(string.find(reqNotifies[#reqNotifies].text, "command failed:", 1, true) ~= nil).toBe(true)
			shouldErrInRun = false

			-- Accepted request where run succeeds does NOT fire "command failed:"
			table.clear(reqNotifies)
			reqCmds[1]:requestCommand(peer1, { { peer1 } }, _K.Registry.commands.testmultireq.run)
			expect(string.find(reqNotifies[#reqNotifies].text, "accepted", 1, true) ~= nil).toBe(true)
			expect(#multiRuns).toBe(1)
			expect(multiRuns[1]).toEqual({ "PeerReqOne" })

			-- Multi-target list with 2 peers + 1 lower-rank player splits solo requests for each peer and runs immediately for lowPlr
			table.clear(multiRuns)
			local okMulti, multiCmds =
				Process.prepareCommands(_K, superPlr.UserId, ";testmultireq PeerReqOne,PeerReqTwo,LowReqTarget")
			expect(okMulti).toBe(true)
			local runOk = multiCmds[1]:run()
			expect(runOk).toBe(true)
			h.env:flush()
			expect(#multiRuns).toBe(3)
			expect(multiRuns[1]).toEqual({ "PeerReqTwo" })
			expect(multiRuns[2]).toEqual({ "PeerReqOne" })
			expect(multiRuns[3]).toEqual({ "LowReqTarget" })

			-- Multi-target list with ONLY peers skips running the initial command and only runs via requests
			table.clear(multiRuns)
			_K.Remote.RequestCommand.Invoke = function()
				return false
			end
			local okOnlyPeers, onlyPeerCmds =
				Process.prepareCommands(_K, superPlr.UserId, ";testmultireq PeerReqOne,PeerReqTwo")
			expect(okOnlyPeers).toBe(true)
			expect(onlyPeerCmds[1]:run()).toBe(true)
			h.env:flush()
			expect(#multiRuns).toBe(0)

			-- Direct Command:validate resets targetLimits and sets array[2] pos to start + #text
			_K.Data.targetLimits[superPlr.UserId] = 99
			local rawCmd = Command.new(
				_K,
				"testmultireq",
				_K.Registry.commands.testmultireq,
				{ { 2, "testmultireq" } },
				superPlr.UserId,
				";testmultireq"
			)
			expect(rawCmd:validate()).toBe(true)
			expect(rawCmd.array[2][1]).toBe(14)
			expect(rawCmd.array[2][2]).toBe("")
			expect(_K.Data.targetLimits[superPlr.UserId]).toBe(1)

			-- Argument:transform invalidates when transform returns nil for non-whitespace optional arg; validate/parse reset targetLimits
			_K.Registry.registerType("testniltransform", {
				transform = function(txt)
					if txt == "bad" then
						return nil, "Custom transform error"
					end
					return txt
				end,
				validate = function(v)
					_K.Data.targetLimits[superPlr.UserId] = (_K.Data.targetLimits[superPlr.UserId] or 0) + 5
					if v == "invalidval" then
						return false, nil
					end
					return true
				end,
				parse = function(v)
					_K.Data.targetLimits[superPlr.UserId] = (_K.Data.targetLimits[superPlr.UserId] or 0) + 5
					if v == "parsefail" then
						return nil, "Custom parse error"
					end
					return v
				end,
			})
			local dummyCmd = {
				_K = _K,
				from = superPlr.UserId,
				array = { { 1, "cmd" } },
			}
			local optNilArg = Argument.new(
				dummyCmd,
				{ type = "testniltransform", name = "Opt", description = "Opt", optional = true },
				5,
				"bad"
			)
			local okTr, trErr = optNilArg:transform()
			expect(okTr).toBe(false)
			expect(trErr.message).toBe("Custom transform error")

			local wsNilArg = Argument.new(
				dummyCmd,
				{ type = "testniltransform", name = "Opt", description = "Opt", optional = false },
				5,
				"   "
			)
			wsNilArg.rawType = {
				transform = function()
					return nil
				end,
				validate = function()
					return true
				end,
				parse = function(v)
					return v
				end,
			} :: any
			local okWs, wsErr = wsNilArg:transform()
			expect(okWs).toBe(false)
			expect(wsErr.message).toBe("Invalid transform: nil")

			_K.Data.targetLimits[superPlr.UserId] = 7
			local valFailArg =
				Argument.new(dummyCmd, { type = "testniltransform", name = "V", description = "V" }, 5, "invalidval")
			expect(valFailArg:transform()).toBe(true)
			local okVal, valErr = valFailArg:validate()
			expect(okVal).toBe(false)
			expect(valErr.message).toBe("Invalid argument: invalidval")
			expect(_K.Data.targetLimits[superPlr.UserId]).toBe(0)

			_K.Data.targetLimits[superPlr.UserId] = 7
			local parseFailArg =
				Argument.new(dummyCmd, { type = "testniltransform", name = "P", description = "P" }, 5, "parsefail")
			expect(parseFailArg:transform()).toBe(true)
			expect(parseFailArg:validate()).toBe(true)
			expect(_K.Data.targetLimits[superPlr.UserId]).toBe(5)
			local okParse, parseErr = parseFailArg:parse()
			expect(okParse).toBe(false)
			expect(parseErr.message).toBe("Custom parse error")
			expect(_K.Data.targetLimits[superPlr.UserId]).toBe(0)

			-- Prefix type switching listable -> non-listable and listable -> different listable
			_K.Registry.registerType("testsublist", {
				listable = true,
				validate = function()
					return true
				end,
				parse = function(v)
					return { "sub_" .. v, "sub2_" .. v }
				end,
			})
			_K.Registry.registerType("testsinglepref", {
				listable = false,
				prefixes = { ["^@"] = "testsublist" },
				validate = function()
					return true
				end,
				parse = function(v)
					return v
				end,
			})
			_K.Registry.registerType("testlistpref", {
				listable = true,
				prefixes = { ["^@"] = "testsublist" },
				validate = function()
					return true
				end,
				parse = function(v)
					return v
				end,
			})
			local singlePrefArg =
				Argument.new(dummyCmd, { type = "testsinglepref", name = "SP", description = "SP" }, 5, "@item")
			local okSP, resSP = singlePrefArg:prepare()
			expect(okSP).toBe(true)
			expect(resSP).toBe("sub_item")

			local listPrefArg =
				Argument.new(dummyCmd, { type = "testlistpref", name = "LP", description = "LP" }, 5, "@item")
			local okLP, resLP = listPrefArg:prepare()
			expect(okLP).toBe(true)
			expect(resLP).toEqual({ "sub_item", "sub2_item" })

			-- 7. Registry edge cases: re-registering command aliases, suggestCommandAlias >32 chars, makeSequenceType, registerCommandModule
			local regHookCmd = nil
			local regConn = _K.Hook.commandRegistered:Connect(function(c)
				regHookCmd = c
			end)
			_K.Registry.registerCommand(_K, {
				name = "testregoverride",
				aliases = { "tro_old" },
				description = "Old cmd",
				group = "moderation",
				args = {},
				run = function() end,
			})
			h.env:step(0.3)
			expect(table.find(_K.Registry.commandNames, "tro_old") ~= nil).toBe(true)
			_K.Registry.registerCommand(_K, {
				name = "testregoverride",
				aliases = { "tro_new" },
				description = "New cmd without explicit group",
				args = {},
				run = function() end,
			})
			h.env:step(0.3)
			regConn:Disconnect()
			expect(regHookCmd ~= nil and regHookCmd.name == "testregoverride").toBe(true)
			expect(_K.Registry.commands.testregoverride.group).toBe("moderation")
			expect(_K.Registry.commands.tro_old).toBeNil()
			expect(table.find(_K.Registry.commandNames, "tro_old")).toBeNil()
			expect(table.find(_K.Registry.commandNames, "tro_new") ~= nil).toBe(true)

			local longAliasQuery = "testregoverride" .. string.rep("z", 30)
			expect(#_K.Registry.suggestCommandAlias(longAliasQuery) > 0).toBe(true)

			-- Command:validate client suggestions disabling shouldFillWithSelf, and filledSelf second optional arg skipping
			_K.Registry.registerType("testplayeropt", {
				validate = function(v)
					return v == "me" or v == "PeerReqOne", "Not a player"
				end,
				parse = function(v)
					return v
				end,
				suggestions = function()
					return { "PeerReqOne" }, { peer1 }
				end,
			})
			_K.Registry.registerCommand(_K, {
				name = "testfillsug",
				description = "Fill suggestion test",
				group = "general",
				args = {
					{ type = "testplayeropt", name = "Target1", description = "Target1" },
					{ type = "testplayeropt", name = "Target2", description = "Target2", optional = true },
					{ type = "integer", name = "Num", description = "Num" },
				},
				run = function() end,
			})
			_K.IsServer = false
			_K.IsClient = true
			local okFillCli, fillCliErr = Process.prepareCommands(_K, superPlr.UserId, ";testfillsug PeerReq 10")
			expect(okFillCli).toBe(false)
			expect(fillCliErr).toBe("Not a player")
			_K.IsClient = false
			_K.IsServer = true

			local okFillSrv, fillSrvCmds = Process.prepareCommands(_K, superPlr.UserId, ";testfillsug 42")
			expect(okFillSrv).toBe(true)
			expect(fillSrvCmds[1].preparedArgs[1]).toBe("me")
			expect(fillSrvCmds[1].args[2].skipped).toBe("42")
			expect(fillSrvCmds[1].preparedArgs[3]).toBe(42)

			local okFillSrv2, fillSrvCmds2 = Process.prepareCommands(_K, superPlr.UserId, ";testfillsug PeerReqOne 42")
			expect(okFillSrv2).toBe(true)
			expect(fillSrvCmds2[1].preparedArgs[1]).toBe("PeerReqOne")
			expect(fillSrvCmds2[1].args[2].skipped).toBe("42")
			expect(fillSrvCmds2[1].preparedArgs[3]).toBe(42)

			-- Process.runCommands liveText redaction for freeText / redactLog args and failed command liveText
			local capturedLogs = {}
			local origLog2 = _K.log
			_K.log = function(txt, lvl, f, filt, live, glob)
				table.insert(capturedLogs, { txt = txt, lvl = lvl, live = live, glob = glob })
				return origLog2(txt, lvl, f, filt, live, glob)
			end
			_K.Registry.registerType("testfreetext", {
				freeText = true,
				filterLog = true,
				validate = function()
					return true
				end,
				parse = function(v)
					return v
				end,
			})
			_K.Registry.registerCommand(_K, {
				name = "testlogredact",
				description = "Log redact test",
				group = "general",
				args = {
					{ type = "testfreetext", name = "Msg", description = "Msg" },
				},
				run = function() end,
			})
			expect(Process.runCommands(_K, superPlr.UserId, ";testlogredact secretword", false)).toBe(true)
			h.env:flush()
			expect(capturedLogs[#capturedLogs].txt).toBe(";testlogredact secretword")
			expect(capturedLogs[#capturedLogs].live).toBe(";testlogredact …")

			expect(Process.runCommands(_K, superPlr.UserId, ";testlimitcmd NonExistentPlrXYZ", false)).toBe(false)
			h.env:flush()
			expect(capturedLogs[#capturedLogs].live).toBe(";testlimitcmd …")
			_K.log = origLog2
		end
	)

	test(
		"sert.laws.differential and adversarial fuzzing of rawParse, prepareCommands, runCommands, and Argument coercion",
		function()
			local h = Harness.newEnv({ isStudio = false })
			local Data = h:requireData()
			local Process = h:requireProcess()
			local _K = h:requireK()
			Data.settings.prefix = { ";", "!" }

			local admin = h.env:addPlayer(101, "FuzzAdmin")
			local guest = h.env:addPlayer(202, "FuzzGuest")
			admin:SetAttribute("_KRolesLoaded", true)
			guest:SetAttribute("_KRolesLoaded", true)
			_K.Auth.userRoleAdd(admin.UserId, "superadmin")

			local capturedCalls = {}
			_K.Registry.registerCommand(_K, {
				name = "fuzzcmd",
				aliases = { "fcmd" },
				description = "Fuzz target command",
				group = "moderation",
				args = {
					{ type = "players", name = "Targets", description = "Target players", lowerRank = true },
					{ type = "integer", name = "Count", description = "Count", optional = true },
					{ type = "number", name = "Scale", description = "Scale", optional = true },
					{ type = "string", name = "Note", description = "Note", optional = true },
				},
				run = function(_context, targets, count, scale, note)
					table.insert(capturedCalls, {
						n = #targets,
						count = count,
						scale = scale,
						note = note,
					})
				end,
			})

			-- 1. sert.laws.differential on Process.rawParse with multi-command chains, nested quotes, prefixes, and byte spans
			local chainGen = function(g: any)
				local prefix = g:pick({ ";", "!", ":" })
				local cmdCount = g:int(1, 3)
				local cmds = {}
				for c = 1, cmdCount do
					local name = g:pick({ "fly", "ban", "kick", "announce", "fuzzcmd", "fcmd" })
					local argCount = g:int(0, 3)
					local args = {}
					for a = 1, argCount do
						local kind = g:int(1, 4)
						if kind == 1 then
							args[a] = g:pick({ "me", "all", "others", "*", "@mod", "%red", "~1", "$admins" })
						elseif kind == 2 then
							local inner = g:pick({ "hello ; world", "nested `tick` inside", "a,b,c", "100%s" })
							args[a] = `"{inner}"`
						elseif kind == 3 then
							local inner = g:pick({ 'nested "double" inside', "semi ; colon", "space sep" })
							args[a] = "`" .. inner .. "`"
						else
							args[a] = tostring(g:int(-1000, 1000))
						end
					end
					cmds[c] = { name = name, args = args }
				end
				return { prefix = prefix, cmds = cmds }
			end

			sert.laws.differential("Process.rawParse command chain & quote tokenization", {
				gen = chainGen,
				sut = function(spec: any)
					local parts = {}
					for _, c in spec.cmds do
						local tokens = { spec.prefix .. c.name }
						for _, a in c.args do
							table.insert(tokens, a)
						end
						table.insert(parts, table.concat(tokens, " "))
					end
					local raw = table.concat(parts, " ")
					local parsed = Process.rawParse(raw, { spec.prefix }, " ")
					expect(parsed ~= nil).toBe(true)
					local simplified = {}
					for i, cmdArr in parsed or {} do
						expect(#cmdArr >= 1).toBe(true)
						local row = {}
						for j, tok in cmdArr do
							local pos = tok[1]
							local text = tok[2]
							expect(string.sub(raw, pos, pos + #text - 1)).toBe(text)
							row[j] = { pos = pos, endPos = pos + #text - 1, text = text }
						end
						simplified[i] = row
					end
					return simplified
				end,
				oracle = function(spec: any)
					local expected = {}
					local cursor = 1
					for i, c in spec.cmds do
						if i > 1 then
							cursor += 1 -- space between commands
						end
						local namePos = cursor + #spec.prefix
						local row = {
							{ pos = namePos, endPos = namePos + #c.name - 1, text = c.name },
						}
						cursor = namePos + #c.name
						for _, a in c.args do
							cursor += 1 -- space before arg
							table.insert(row, { pos = cursor, endPos = cursor + #a - 1, text = a })
							cursor += #a
						end
						expected[i] = row
					end
					return expected
				end,
			}, { runs = 60 })

			-- 2. Strict grammar & execution contracts on rawParse, prepareCommands, and runCommands
			local malformedGen = sert.gen.malformedString()
			local bIntGen = sert.gen.boundaryInt(-1e9, 1e9)
			local bFloatGen = sert.gen.boundaryFloat(-1e6, 1e6)
			local selectorGen = sert.gen.pick({
				"*",
				"all",
				"others",
				"me",
				"@mod",
				"@admin",
				"@nonexistent",
				"%red",
				"~",
				"~2",
				"~-1",
				"$all",
				"$others",
				"$admins",
				"$nonadmins",
				"$close",
				"$far",
				"$distance<50",
				"$distance>100",
				"$group=100>=50",
				"!me",
			})

			sert.check(
				"Process.rawParse, prepareCommands, and runCommands satisfy strict grammar and authorization contracts",
				{ malformedGen, bIntGen, bFloatGen, selectorGen },
				function(malformed, bInt, bFloat, selector)
					for _, candidate in
						{
							malformed,
							`;fuzzcmd {selector} {bInt} {bFloat} "{malformed}"`,
							";fuzzcmd `quote \"inner\"` 'single' \\n\\t\\0 ;fuzzcmd " .. malformed,
							`;{malformed} "{malformed}"`,
						}
					do
						local okRaw, resRaw = pcall(Process.rawParse, candidate, { ";", "!" }, " ")
						expect(okRaw).toBe(true)
						expect(resRaw == nil or type(resRaw) == "table").toBe(true)
						if resRaw ~= nil then
							expect(#resRaw >= 1).toBe(true)
							for _, cmdArr in resRaw do
								expect(#cmdArr >= 1).toBe(true)
								for _, tok in cmdArr do
									expect(type(tok[1])).toBe("number")
									expect(type(tok[2])).toBe("string")
									expect(tok[1] >= 1).toBe(true)
								end
							end
						end

						-- Unprivileged guest can never prepare or execute moderation command fuzzcmd
						local beforeCount = #capturedCalls
						Process.resetLimit(guest.UserId)
						local okPrepGuest, prepGuest, guestErrOrCmds =
							pcall(Process.prepareCommands, _K, guest.UserId, candidate)
						expect(okPrepGuest).toBe(true)
						expect(prepGuest ~= true).toBe(true)
						if prepGuest == false then
							expect(type(guestErrOrCmds)).toBe("string")
							expect(#guestErrOrCmds > 0).toBe(true)
						end

						Process.resetLimit(guest.UserId)
						local okRunGuest, runGuestRes = pcall(Process.runCommands, _K, guest.UserId, candidate, true)
						expect(okRunGuest).toBe(true)
						if prepGuest == false then
							expect(runGuestRes).toBe(false)
						end
						expect(#capturedCalls).toBe(beforeCount)
						expect(_K.Auth.getRank(guest.UserId)).toBe(0)

						-- Admin preparing arbitrary fuzzed command strings returns validated Command objects or non-empty error string
						Process.resetLimit(admin.UserId)
						local okPrepAdmin, prepAdminOk, prepAdminResult =
							pcall(Process.prepareCommands, _K, admin.UserId, candidate)
						expect(okPrepAdmin).toBe(true)
						if prepAdminOk == true then
							expect(type(prepAdminResult)).toBe("table")
							for _, cmdObj in prepAdminResult do
								expect(cmdObj.validated).toBe(true)
								expect(cmdObj.from).toBe(admin.UserId)
							end
						elseif prepAdminOk == false then
							local errMsg = if type(prepAdminResult) == "table"
								then prepAdminResult.message
								else prepAdminResult
							expect(type(errMsg)).toBe("string")
							expect(#errMsg > 0).toBe(true)
						end
					end
				end,
				{ runs = 60 }
			)
		end
	)

	local cachedModelSut: any = nil
	local cachedModelMutant: any = "unset"
	sert.model("Command Execution, Hook & Request Protocol", {
		setup = function()
			local currentMutant = rawget(_G, "__SERT_MUTANT")
			if cachedModelSut ~= nil and cachedModelMutant == currentMutant then
				local sut = cachedModelSut
				sut.h.env:step(6)
				sut.Data.settings.prefix = { ";" }
				sut.Data.settings.commandRequests = true
				sut.Data.roles.mod.limits = { commands = 2, cooldown = 5, targets = 4 }
				sut.filterCancel = false
				sut.nextRequestOutcome = "accept"
				sut.preHookCount = 0
				sut.postHookCount = 0
				table.clear(sut.executedRuns)
				sut.preHookCancelledButCommandRan = false
				sut.deniedOrTimedOutRequestRan = false
				sut.rankCeilingBypassed = false
				for _, p in { sut.superadmin, sut.mod, sut.peerMod, sut.guest } do
					sut.Process.resetLimit(p.UserId)
				end
				return sut
			end

			local h = Harness.newEnv({ isStudio = false })
			local Data = h:requireData()
			local Process = h:requireProcess()
			local _K = h:requireK()
			Data.settings.prefix = { ";" }
			Data.settings.commandRequests = true

			local superadmin = h.env:addPlayer(101, "ModelSuper")
			local mod = h.env:addPlayer(102, "ModelMod")
			local peerMod = h.env:addPlayer(103, "ModelPeer")
			local guest = h.env:addPlayer(104, "ModelGuest")
			for _, p in { superadmin, mod, peerMod, guest } do
				p:SetAttribute("_KRolesLoaded", true)
			end
			_K.Auth.userRoleAdd(superadmin.UserId, "superadmin")
			_K.Auth.userRoleAdd(mod.UserId, "mod")
			_K.Auth.userRoleAdd(peerMod.UserId, "mod")

			Data.roles.mod.limits = { commands = 2, cooldown = 5, targets = 4 }

			local sut = {
				h = h,
				_K = _K,
				Data = Data,
				Process = Process,
				superadmin = superadmin,
				mod = mod,
				peerMod = peerMod,
				guest = guest,
				filterCancel = false,
				nextRequestOutcome = "accept",
				preHookCount = 0,
				postHookCount = 0,
				executedRuns = {} :: { { from: number, targetId: number, value: number } },
				preHookCancelledButCommandRan = false,
				deniedOrTimedOutRequestRan = false,
				rankCeilingBypassed = false,
			}

			_K.Hook.preCommand:Connect(function(_cmd)
				sut.preHookCount += 1
			end)
			_K.Hook.postCommand:Connect(function(_cmd)
				sut.postHookCount += 1
			end)

			local removeFilter = Process.addCommandFilter(function(cmd)
				if cmd.alias == "modelcmd" and sut.filterCancel then
					return false, "Cancelled by pre-command filter"
				end
				return true
			end)
			sut.removeFilter = removeFilter

			_K.Remote.RequestCommand.Invoke = function(_self, _targetPlayer, _fromPlayer, _cmdText)
				if sut.nextRequestOutcome == "accept" then
					return true
				elseif sut.nextRequestOutcome == "deny" then
					return false
				else
					error("RequestCommand timed out / player disconnected")
				end
			end

			_K.Registry.registerCommand(_K, {
				name = "modelcmd",
				description = "Stateful protocol model command",
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
						name = "Value",
						description = "Value",
					},
				},
				run = function(context, target, value)
					if sut.filterCancel then
						sut.preHookCancelledButCommandRan = true
					end
					local callerRank = _K.Auth.getRank(context.from)
					local targetRank = _K.Auth.getRank(target.UserId)
					if target.UserId ~= context.from and callerRank <= targetRank then
						if Data.settings.commandRequests == false then
							sut.rankCeilingBypassed = true
						elseif sut.nextRequestOutcome ~= "accept" then
							sut.deniedOrTimedOutRequestRan = true
						end
					end
					if callerRank == 0 then
						sut.rankCeilingBypassed = true
					end
					table.insert(sut.executedRuns, {
						from = context.from,
						targetId = target.UserId,
						value = value,
					})
				end,
			})

			cachedModelSut = sut
			cachedModelMutant = currentMutant
			return sut
		end,
		teardown = function(_sut) end,
		init = function()
			return {
				filterCancel = false,
				commandRequests = true,
				nextRequestOutcome = "accept",
				modCommandsUsed = 0,
				modCommandLimit = 2,
				expectedExecutions = 0,
			}
		end,
		commands = {
			setPolicy = {
				gen = function(g)
					return {
						filterCancel = g:bool(0.25),
						commandRequests = g:bool(0.75),
						outcome = g:pick({ "accept", "deny", "timeout" }),
					}
				end,
				run = function(sut, arg)
					sut.filterCancel = arg.filterCancel
					sut.Data.settings.commandRequests = arg.commandRequests
					sut.nextRequestOutcome = arg.outcome
					return true
				end,
				next = function(state, arg)
					state.filterCancel = arg.filterCancel
					state.commandRequests = arg.commandRequests
					state.nextRequestOutcome = arg.outcome
				end,
			},
			modRunOnLower = {
				gen = function(g)
					return g:int(1, 100)
				end,
				run = function(sut, val)
					local ok = sut.Process.runCommands(sut._K, sut.mod.UserId, `;modelcmd ModelGuest {val}`, true)
					sut.h.env:step(0.05)
					return ok
				end,
				post = function(state, _val, ok)
					if state.modCommandsUsed >= state.modCommandLimit or state.filterCancel then
						expect(ok).toBe(false)
					else
						expect(ok).toBe(true)
					end
				end,
				next = function(state)
					if state.modCommandsUsed < state.modCommandLimit then
						state.modCommandsUsed += 1
						if not state.filterCancel then
							state.expectedExecutions += 1
						end
					end
				end,
			},
			modRunOnPeerOrHigher = {
				gen = function(g)
					return {
						targetName = g:pick({ "ModelPeer", "ModelSuper" }),
						val = g:int(1, 100),
					}
				end,
				run = function(sut, arg)
					local ok =
						sut.Process.runCommands(sut._K, sut.mod.UserId, `;modelcmd {arg.targetName} {arg.val}`, true)
					sut.h.env:step(0.05)
					return ok
				end,
				post = function(state, _arg, ok)
					if
						state.modCommandsUsed >= state.modCommandLimit
						or not state.commandRequests
						or state.filterCancel
					then
						-- Rejected due to cooldown limit, lowerRank without commandRequests, or pre-command filter
						expect(ok).toBe(false)
					else
						-- requestCommand is spawned asynchronously; runCommands returns true
						expect(ok).toBe(true)
					end
				end,
				next = function(state)
					if state.modCommandsUsed < state.modCommandLimit then
						if not state.commandRequests then
							-- Failed prepareCommands increments commandLimits by #prepared + 1 (2)
							state.modCommandsUsed += 2
						else
							state.modCommandsUsed += 1
							if not state.filterCancel and state.nextRequestOutcome == "accept" then
								state.expectedExecutions += 1
							end
						end
					end
				end,
			},
			guestAttemptCommand = {
				gen = function(g)
					return {
						targetName = g:pick({ "ModelGuest", "ModelMod", "ModelSuper" }),
						val = g:int(1, 100),
					}
				end,
				run = function(sut, arg)
					return sut.Process.runCommands(
						sut._K,
						sut.guest.UserId,
						`;modelcmd {arg.targetName} {arg.val}`,
						true
					)
				end,
				post = function(_state, _arg, ok)
					expect(ok).toBe(false)
				end,
			},
			resetOrExpireCooldown = {
				gen = function(g)
					return g:pick({ "step", "reset" })
				end,
				run = function(sut, mode)
					if mode == "step" then
						sut.h.env:step(5.5)
					else
						sut.Process.resetLimit(sut.mod.UserId)
					end
					return true
				end,
				next = function(state)
					state.modCommandsUsed = 0
				end,
			},
		},
		invariants = {
			prePostHookSymmetry = function(state, sut)
				return sut.preHookCount == sut.postHookCount and sut.postHookCount == state.expectedExecutions
			end,
			executionLogMatchesModel = function(state, sut)
				return #sut.executedRuns == state.expectedExecutions
			end,
			cooldownMatchesModel = function(state, sut)
				return sut.Process.onCooldown(sut._K, sut.mod.UserId)
					== (state.modCommandsUsed >= state.modCommandLimit)
			end,
		},
		never = {
			preHookCancelledButCommandRan = function(_state, sut)
				return sut.preHookCancelledButCommandRan
			end,
			deniedOrTimedOutRequestRan = function(_state, sut)
				return sut.deniedOrTimedOutRequestRan
			end,
			rankCeilingBypassed = function(_state, sut)
				return sut.rankCeilingBypassed
			end,
		},
	}, { runs = 40, length = 15 })
end)

return {}
