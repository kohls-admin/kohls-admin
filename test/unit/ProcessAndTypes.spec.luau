local Harness = require("./Harness")
local sert = require("../sert")

local describe, test = sert.describe, sert.test
local prop = sert.prop

describe("Process · rawParse", function()
	local DEFAULT_PREFIX = { ";" }
	local MULTI_PREFIX = { ";", "!" }

	test("parses single, quoted, and chained commands with custom prefixes", function()
		local Process = Harness.shared():requireProcess()
		sert.eq(Process.rawParse("hello world", DEFAULT_PREFIX, " "), nil)
		sert.eq(Process.rawParse(";", DEFAULT_PREFIX, " "), nil)

		local single = Process.rawParse(";fly me 100", DEFAULT_PREFIX, " ")
		sert.eq(single ~= nil, true)
		sert.eq(#(single :: any), 1)
		sert.eq((single :: any)[1][1][2], "fly")
		sert.eq((single :: any)[1][2][2], "me")
		sert.eq((single :: any)[1][3][2], "100")

		local chained = Process.rawParse(';announce "hello ; world" ;kick bob "bye"', { ";", ":" }, " ")
		sert.eq(chained ~= nil, true)
		sert.eq(#(chained :: any), 2)
		sert.eq((chained :: any)[1][1][2], "announce")
		sert.eq((chained :: any)[1][2][2], '"hello ; world"')
		sert.eq((chained :: any)[2][1][2], "kick")
		sert.eq((chained :: any)[2][2][2], "bob")
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
			local nameStart = cursor + #spec.prefix
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
				local argStart = cursor
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
			sert.eq(parsed ~= nil, true)
			local out = {}
			local leadLen = #spec.leadNoise
			sert.eq(string.sub(message, leadLen + 1, leadLen + #spec.prefix), spec.prefix)
			for i, cmdArr in parsed :: { any } do
				sert.eq(#cmdArr >= 1, true)
				local row = {}
				for j, tok in cmdArr do
					local argPos: number = tok[1]
					local argStr: string = tok[2]
					local absEnd = argPos + #argStr - 1
					sert.eq(string.sub(message, argPos, absEnd), argStr)
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
			sert.eq(ok, true)
			sert.eq(parsed == nil or type(parsed) == "table", true)
			if parsed ~= nil and utf8.len(noise) then
				sert.eq(#parsed >= 1, true)
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
				sert.eq(matchedPrefix ~= nil, true)
				sert.eq(matchStart ~= nil, true)
				for _, cmdArr in parsed do
					sert.eq(#cmdArr >= 1, true)
					for _, tok in cmdArr do
						sert.eq(type(tok[1]), "number")
						sert.eq(type(tok[2]), "string")
						sert.eq(tok[1] >= 1, true)
					end
				end
			elseif parsed == nil and err ~= nil then
				sert.eq(type(err) == "string" or type(err) == "number", true)
			end

			-- Unclosed quote law: verify exact unmatched opening quote byte offset
			local cmd = g:string("abcdefghijklmnopqrstuvwxyz", 1, 10)
			local arg1 = g:string("abcdefghijklmnopqrstuvwxyz0123456789", 1, 10)
			local tail = g:string("abcdefghijklmnopqrstuvwxyz0123456789", 1, 10)
			local quoteChar = g:pick({ '"', "`" })
			local unclosedMsg = `;{cmd} {arg1} {quoteChar}{tail} ;not_a_new_cmd`
			local expectedQuoteOffset = 1 + #cmd + 1 + #arg1 + 1 + 1
			sert.eq(string.sub(unclosedMsg, expectedQuoteOffset, expectedQuoteOffset), quoteChar)

			local unclosedParsed, unclosedErr = Process.rawParse(unclosedMsg, DEFAULT_PREFIX, " ")
			if unclosedParsed == nil then
				sert.eq(unclosedErr, expectedQuoteOffset)
			else
				sert.eq(#unclosedParsed, 1)
				local quoteTok = unclosedParsed[1][3]
				sert.eq(quoteTok[1], expectedQuoteOffset)
				sert.eq(quoteTok[2], string.sub(unclosedMsg, expectedQuoteOffset))
				sert.eq(string.sub(unclosedMsg, quoteTok[1], quoteTok[1] + #quoteTok[2] - 1), quoteTok[2])
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

		sert.eq(#Registry.commandsList > 50, true)

		sert.ok(next(Registry.commands) ~= nil, "Registry.commands non-empty")
		for name, def in Registry.commands do
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
		end
		for alias, target in Registry.aliases do
			if type(target) == "string" then
				assert(Registry.commands[target] ~= nil, `command alias {alias} points to missing command {target}`)
			else
				assert(
					type(target) == "table" and Registry.commands[target.name] ~= nil,
					`command alias {alias} invalid`
				)
			end
		end

		sert.ok(next(Registry.types) ~= nil, "Registry.types non-empty")
		for name, typeDef in Registry.types do
			assert(type(typeDef.validate) == "function", `type {name} missing validate`)
			assert(type(typeDef.parse) == "function", `type {name} missing parse`)
		end
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
	sert.prop(
		"built-in scalar, color, timeSimple, vector, and enum types round-trip valid inputs and reject malformed ones",
		function(g)
			local n = g:int(-10000, 10000)
			local expectedColor = gen.color3()(g)
			local mins = g:int(1, 120)
			local secs = g:int(1, 59)
			local vec = gen.vector3(gen.int(-500, 500))(g)
			local matItem = gen.enum(Harness.globals.Enum.Material)(g)
			local types = getPropTypes()
			local Vector2 = Harness.globals.Vector2

			local intVal = types.integer.transform(tostring(n))
			sert.eq((types.integer.validate(intVal)), true)
			sert.eq(types.integer.parse(intVal), n)
			sert.eq((types.integer.validate(types.integer.transform("not_a_number"))), false)

			local r = math.round(expectedColor.R * 255)
			local gr = math.round(expectedColor.G * 255)
			local b = math.round(expectedColor.B * 255)
			local hex = string.format("#%02x%02x%02x", r, gr, b)
			local cHex = types.color.transform(hex)
			sert.eq((types.color.validate(cHex)), true)
			sert.eq(types.color.parse(cHex), expectedColor)
			local cRgb = types.color.transform(`{r},{gr},{b}`)
			sert.eq((types.color.validate(cRgb)), true)
			sert.eq(types.color.parse(cRgb), expectedColor)
			sert.eq((types.color.validate(types.color.transform("#zzzzzz"))), false)

			local okTime, parsedTime = types.timeSimple.validate(`{mins}m {secs}s`)
			sert.eq(okTime, true)
			sert.eq(parsedTime, mins * 60 + secs)
			sert.eq((types.timeSimple.validate("invalid_time_xyz")), false)

			local vx, vy, vz = vec.X, vec.Y, vec.Z
			local v2Val = types.vector2.transform(`{vx},{vy}`)
			sert.eq((types.vector2.validate(v2Val)), true)
			sert.eq(types.vector2.parse(v2Val), Vector2.new(vx, vy))
			sert.eq((types.vector2.validate(types.vector2.transform("1,2,3"))), false)

			local v3Val = types.vector3.transform(`{vx},{vy},{vz}`)
			sert.eq((types.vector3.validate(v3Val)), true)
			sert.eq(types.vector3.parse(v3Val), vec)
			sert.eq((types.vector3.validate(types.vector3.transform("1,bad,3"))), false)

			local enumType = types["Enum.Material"]
			local matName = matItem.Name
			sert.eq((enumType.validate(matName)), true)
			sert.eq(enumType.parse(matName), matItem)
			sert.eq(enumType.parse(string.lower(matName)), matItem)
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
		sert.eq(okGuest, false)
		sert.eq(#executed, 0)

		-- Admin succeeds via alias
		local okAdmin = _K.Process.runCommands(_K, adminPlayer.UserId, ";tgive GuestUser 42 true", true)
		sert.eq(okAdmin, true)
		sert.eq(#executed, 1)
		sert.eq(executed[1].from, adminPlayer.UserId)
		sert.eq(executed[1].targets[1], guestPlayer)
		sert.eq(executed[1].amount, 42)
		sert.eq(executed[1].silent, true)
		sert.eq(preCount, 1)
		sert.eq(postCount, 1)

		-- Missing required integer argument fails validation cleanly
		local okMissing, errMissing = _K.Process.prepareCommands(_K, adminPlayer.UserId, ";tgive GuestUser")
		sert.eq(okMissing, false)
		sert.eq(string.find(tostring(errMissing), "missing", 1, true) ~= nil, true)
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
		sert.eq(ok, true)
		sert.eq(commands[1].alias, "testother")
		ok, commands = _K.Process.prepareCommands(_K, admin.UserId, 'x :testsay "a ;testother b"')
		sert.eq(ok, true)
		sert.eq(commands[1].alias, "testsay")

		-- published global strings start with the server prefix (:), the others are text there
		ok, commands = _K.Process.prepareCommands(_K, admin.UserId, ':testsay "a !testother b ;testother c"', true)
		sert.eq(ok, true)
		sert.eq(#commands, 1)
		sert.eq(commands[1].alias, "testsay")
		sert.eq(commands[1].args[1].rawArg, '"a !testother b ;testother c"')
		sert.eq(_K.Process.prepareCommands(_K, admin.UserId, ';testsay "a"', true), nil)
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
			sert.eq(Registry.types["Enum.Material"] ~= nil, true)
			sert.eq(Registry.types["Enum.Materials"] ~= nil, true)
			sert.eq(Registry.types["Enum.Materials"].listable, true)
			sert.eq(Registry.types["alpha,beta,gamma"] ~= nil, true)
			sert.eq(Registry.types["alpha,beta,gammas"] ~= nil, true)
			sert.eq((Registry.types["alpha,beta,gamma"].validate("beta")), true)
			sert.eq(Registry.types["alpha,beta,gamma"].parse("beta"), "beta")

			local plr = h.env:addPlayer(10, "EnumUser")
			local ok = _K.Process.runCommands(_K, plr.UserId, ";testenumcsv Plastic,Neon gamma", true)
			sert.eq(ok, true)
			sert.eq(#seenEnum, 2)
			sert.eq(seenCsv, "gamma")

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
			sert.eq((seqType.validate(transformed)), true)
			sert.eq(seqType.parse(transformed), { x = 10, y = 20, z = 30 })
			sert.eq((seqType.validate(seqType.transform("10,20,30,40"))), false)
			sert.eq((seqType.validate(seqType.transform("10,bad,30"))), false)

			-- registerCommandAlias registers a Utility command and ignores duplicate registration
			Registry.registerCommandAlias(_K, "quickhelp", ";help")
			sert.eq(Registry.commands.quickhelp ~= nil, true)
			sert.eq(Registry.commands.quickhelp.group, "Utility")
			Registry.registerCommandAlias(_K, "quickhelp", ";help")

			-- #358: Process.rawParse parses commands starting with the same alphanumeric prefix character (e.g. prefix "e" -> "emote", prefix "f" -> "fly")
			local parsedEmote = _K.Process.rawParse("eemote", "e", " ")
			sert.eq(parsedEmote ~= nil, true)
			sert.eq(parsedEmote[1][1][2], "emote")
			local parsedFlyChain = _K.Process.rawParse("ffly me fff", "f", " ")
			sert.eq(parsedFlyChain ~= nil, true)
			sert.eq(#parsedFlyChain, 2)
			sert.eq(parsedFlyChain[1][1][2], "fly")
			sert.eq(parsedFlyChain[2][1][2], "ff")
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
			sert.eq(okEcho, true)
			h.env:step(0.05)
			local senderLog, otherLog
			for _, entry in remoteLogs do
				if entry.to == modPlayer.UserId and string.find(entry.text, ";testecho", 1, true) then
					senderLog = entry.text
				elseif entry.to == otherAdmin.UserId and string.find(entry.text, ";testecho", 1, true) then
					otherLog = entry.text
				end
			end
			sert.eq(senderLog, ";testecho secret_phrase")
			sert.eq(otherLog, ";testecho secret_phrase")
			sert.eq(_K.Data.logs[#_K.Data.logs][1], ";testecho secret_phrase")

			table.clear(remoteLogs)
			local okEcho2 = _K.Process.runCommands(_K, modPlayer.UserId, ";testecho second_secret", false)
			sert.eq(okEcho2, true)
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
			sert.eq(senderLog, ";testecho second_secret")
			sert.eq(friendLog, ";testecho second_secret")
			sert.eq(otherLog, ";testecho …")
			sert.eq(_K.Data.logs[#_K.Data.logs][1], ";testecho …")

			-- 2. Long rawText (> 1024 bytes) for non-restricted role (everyone/guest) is truncated to 1024 bytes
			local longArg = string.rep("x", 1200)
			local okLong = _K.Process.runCommands(_K, guestPlayer.UserId, ";testecho " .. longArg, true)
			sert.eq(okLong, true)
			sert.eq(#echoed[#echoed] < 1024, true)
			sert.eq(#echoed[#echoed], 1024 - #";testecho ")

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
			sert.eq(sawLimitAlert, true)

			-- Subsequent command while on cooldown returns false and alerts "Command usage on cooldown!"
			table.clear(notifications)
			local okCooldown = _K.Process.runCommands(_K, guestPlayer.UserId, ";testecho blocked", true)
			sert.eq(okCooldown, false)
			sert.eq(string.find(notifications[1].text, "cooldown", 1, true) ~= nil, true)

			-- Stepping past the 4-second cooldown resets the limit
			h.env:step(4.5)
			sert.eq(_K.Process.runCommands(_K, guestPlayer.UserId, ";testecho after_cooldown", true), true)

			-- 4. Command execution failure (`run` throws) notifies caller and logs ERROR
			table.clear(notifications)
			table.clear(remoteLogs)
			local okBoom = _K.Process.runCommands(_K, modPlayer.UserId, ";testboom", false)
			sert.eq(okBoom, false)
			sert.eq(#notifications >= 1, true)
			sert.eq(string.find(notifications[1].text, "command failed", 1, true) ~= nil, true)
			sert.eq(string.find(notifications[1].text, "kaboom failure", 1, true) ~= nil, true)
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
		sert.eq(okSelf, true)
		sert.eq(#ranTargets, 1)
		sert.eq(ranTargets[1].target, mod1)
		sert.eq(ranTargets[1].power, 77)

		-- Two consecutive player args: ";testpair LowGuest" auto-fills arg 1 with "me" (mod1) and arg 2 with guest
		local okPair = _K.Process.runCommands(_K, mod1.UserId, ";testpair LowGuest", true)
		sert.eq(okPair, true)
		sert.eq(ranPair ~= nil, true)
		sert.eq(ranPair.from[1], mod1)
		sert.eq(ranPair.to, guest)

		-- 2. shouldRequest & requestCommand when targeting equal/higher rank player (mod2):
		-- First test denied request (Invoke returns false)
		local invokeCount = 0
		_K.Remote.RequestCommand.Invoke = function(_self, _targetPlayer, _fromPlayer, _cmdText)
			invokeCount += 1
			return false
		end
		table.clear(ranTargets)
		local okDenied = _K.Process.runCommands(_K, mod1.UserId, ";testreq PeerMod 55", true)
		sert.eq(okDenied, true)
		h.env:step(0.05)
		sert.eq(invokeCount, 1)
		sert.eq(#ranTargets, 0)

		-- Next test accepted request (Invoke returns true -> executes command)
		_K.Remote.RequestCommand.Invoke = function(_self, _targetPlayer, _fromPlayer, _cmdText)
			invokeCount += 1
			return true
		end
		local okAccepted = _K.Process.runCommands(_K, mod1.UserId, ";testreq PeerMod 88", true)
		sert.eq(okAccepted, true)
		h.env:step(0.05)
		sert.eq(invokeCount, 2)
		sert.eq(#ranTargets, 1)
		sert.eq(ranTargets[1].target, mod2)
		sert.eq(ranTargets[1].power, 88)

		-- a joining player's group and gamepass roles haven't loaded, so its rank reads 0 but it's still asked first
		local joining = h.env:addPlayer(104, "JoiningAdmin")
		table.clear(ranTargets)
		local okJoining = _K.Process.runCommands(_K, mod1.UserId, ";testreq JoiningAdmin 66", true)
		sert.eq(okJoining, true)
		h.env:step(0.05)
		sert.eq(invokeCount, 3)
		sert.eq(#ranTargets, 1)
		sert.eq(ranTargets[1].target, joining)

		-- the creator and loaded lower ranks are never asked
		table.clear(ranTargets)
		sert.eq(_K.Process.runCommands(_K, _K.creatorId, ";testreq JoiningAdmin 67", true), true)
		sert.eq(_K.Process.runCommands(_K, mod1.UserId, ";testreq LowGuest 68", true), true)
		h.env:step(0.05)
		sert.eq(invokeCount, 3)
		sert.eq(#ranTargets, 2)

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
		sert.eq(_K.Registry.commands.trl_old, nil)
		sert.eq(_K.Registry.commands.trl_new ~= nil, true)
		sert.eq(table.find(_K.Registry.commandNames, "trl_new") ~= nil, true)

		-- Verify commandNames is sorted by length then alphabetically
		for i = 2, #_K.Registry.commandNames do
			local a, b = _K.Registry.commandNames[i - 1], _K.Registry.commandNames[i]
			sert.eq(#a < #b or (#a == #b and a <= b), true)
		end

		-- Verify suggestCommandAlias exact match (distance == 0) and prefix match
		sert.eq(_K.Registry.suggestCommandAlias("testreq"), "testreq")
		sert.eq(_K.Registry.suggestCommandAlias("trl_ne"), "trl_new")

		-- Run testreqlist targeting only PeerMod (prepared becomes empty -> returns true early and spawns requestCommand)
		_K.Remote.RequestCommand.Invoke = function(_self, _targetPlayer, _fromPlayer, _cmdText)
			return false
		end
		table.clear(listTargets)
		local okListSolo = _K.Process.runCommands(_K, mod1.UserId, ";testreqlist PeerMod", true)
		sert.eq(okListSolo, true)
		h.env:step(0.05)
		sert.eq(#listTargets, 0)

		-- Run testreqlist with NO arguments (`;testreqlist`) -> auto-inserts `""` for first player arg -> targets mod1 (self)
		local okAutoSelf = _K.Process.runCommands(_K, mod1.UserId, ";testreqlist", true)
		sert.eq(okAutoSelf, true)
		sert.eq(#listTargets, 1)
		sert.eq(listTargets[1], mod1)

		-- Direct Command:validate() checks for missing arg, invalid arg, optional skipped arg, and client shouldFillWithSelf
		local Command = h.env:require(h.Shared.Process.Command)
		local rawMissing = _K.Process.rawParse(";testreq", { ";" }, " ")
		local cmdMissing =
			Command.new(_K, "testreq", _K.Registry.commands.testreq, rawMissing[1], mod1.UserId, ";testreq")
		local okMiss, errMiss = cmdMissing:validate()
		sert.eq(okMiss, false)
		sert.eq(type(errMiss), "string")
		sert.eq(cmdMissing.invalidPos, 2)
		sert.eq(cmdMissing.invalidArg, "testreq")

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
		sert.eq(okBad, false)
		sert.eq(type(errBad), "string")
		sert.eq(cmdBad.invalidArg, "notanint")
		sert.eq(cmdBad.invalidPos ~= nil, true)
		sert.eq(cmdBad.invalidMessage ~= nil, true)

		local rawSelfShift = _K.Process.rawParse(";testreq 42", { ";" }, " ")
		local cmdSelfShift =
			Command.new(_K, "testreq", _K.Registry.commands.testreq, rawSelfShift[1], mod1.UserId, ";testreq 42")
		local okShift = cmdSelfShift:validate()
		sert.eq(okShift, true)
		sert.eq(cmdSelfShift.args[1].skipped, "42")

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
		sert.eq(cmdOffline.fromPlayer, nil)
		sert.eq(cmdOffline:validate(), true)
		local ranOffline = false
		cmdOffline:requestCommand(mod2, { mod2, 7 }, function()
			ranOffline = true
		end)
		sert.eq(notifyFiredOnNil, false)
		sert.eq(invokedFrom, 9999)
		sert.eq(ranOffline, true)
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
		sert.eq(_K.Process.runCommands(_K, admin.UserId, ";testfilter me,FilterGuest", true), false)
		sert.eq(#runs, 0)
		sert.eq(seen.from, admin.UserId)
		sert.eq(string.find(notes[#notes], "Guests are protected here.", 1, true) ~= nil, true)

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
		sert.eq(_K.Process.runCommands(_K, admin.UserId, ";testfilter FilterPeer,me", true), true)
		h.env:step(0.05)
		sert.eq(dropped, { true, false })
		sert.eq(#requested, 0)
		sert.eq(#runs, 1)
		sert.eq(runs[1].targets, { admin })
		-- without targets left the command is cancelled
		sert.eq(_K.Process.runCommands(_K, admin.UserId, ";testfilter FilterPeer", true), false)
		sert.eq(#runs, 1)
		sert.eq(string.find(notes[#notes], "No players left", 1, true) ~= nil, true)
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
		sert.eq(_K.Process.runCommands(_K, admin.UserId, ";testsingle me", true), false)
		sert.eq(single.dropped, true)
		sert.eq(single.left, nil)
		sert.eq(#runs, 1)
		sert.eq(_K.Process.runCommands(_K, admin.UserId, ";testoptsingle me 42", false), true)
		h.env:step(0.05)
		sert.eq(single.dropped, true)
		sert.eq(single.left, nil)
		sert.eq(#runs, 2)
		sert.eq(runs[2].targets, {})
		sert.eq(runs[2].count, 42)
		sert.eq(_K.Data.logs[#_K.Data.logs][1], ";testoptsingle  42")
		removeSingle()
		sert.eq(_K.Process.runCommands(_K, admin.UserId, ";testsingle me", true), true)
		sert.eq(#runs, 3)

		-- a filter that errors or forgets to allow cancels the command
		local removeError = _K.Process.addCommandFilter(function()
			error("filter bug")
		end)
		sert.eq(_K.Process.runCommands(_K, admin.UserId, ";testfilter me", true), false)
		sert.eq(string.find(notes[#notes], "filter error", 1, true) ~= nil, true)
		removeError()
		local removeNil = _K.Process.addCommandFilter(function()
			return nil :: any
		end)
		sert.eq(_K.Process.runCommands(_K, admin.UserId, ";testfilter me", true), false)
		sert.eq(string.find(notes[#notes], "Command blocked.", 1, true) ~= nil, true)
		removeNil()

		removeBlock()
		sert.eq(_K.Process.runCommands(_K, admin.UserId, ";testfilter me,FilterGuest", true), true)
		sert.eq(#runs, 4)
		sert.eq(table.find(runs[4].targets, guest) ~= nil, true)
		sert.throws(function()
			_K.Process.addCommandFilter("nope" :: any)
		end)
	end)

	test("roles from groups and purchases outlast userRoleRemove, given roles stay per session", function()
		local h = Harness.newEnv()
		local Data = h:requireData()
		local Auth = h:requireAuth()
		local userId = 404

		-- a role given in the session isn't saved and is removed normally
		sert.eq(Auth.userRoleAdd(userId, "mod"), true)
		sert.eq(Data.Sync.members[tostring(userId)], nil)
		sert.eq(Data.members[tostring(userId)].persist, {})
		sert.eq(Auth.hasAsyncRole(userId, "mod"), false)
		sert.eq(Auth.userRoleRemove(userId, "mod"), true)
		sert.eq(Auth.hasRole(userId, "mod"), false)

		-- an owned role stays, only its saved copy is removed
		sert.eq(Auth.asyncRoleAdd(userId, "mod"), true)
		sert.eq(Auth.hasAsyncRole(userId, "mod"), true)
		sert.eq(Auth.hasAsyncRole(tostring(userId) :: any, "mod"), true)
		sert.eq(Auth.hasAsyncRole(userId, "admin"), false)
		sert.eq(Auth.userRoleRemove(userId, "mod"), false)
		sert.eq(Auth.hasRole(userId, "mod"), true)
		Auth.userRoleAdd(userId, "mod", true)
		sert.eq(Data.members[tostring(userId)].persist, { "mod" })
		sert.eq(Auth.userRoleRemove(userId, "mod"), true)
		sert.eq(Data.members[tostring(userId)].persist, {})
		sert.eq(Auth.hasRole(userId, "mod"), true)

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
		sert.eq(done, true)
		for _, roleId in { "vip", "admin", "superadmin", "mod" } do
			sert.eq(Auth.hasAsyncRole(player.UserId, roleId), true)
			Auth.userRoleRemove(player.UserId, roleId)
			sert.eq(Auth.hasRole(player.UserId, roleId), true)
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
				sert.eq(parsed ~= nil, true)
				if delim == "%" then
					sert.eq(#(parsed :: any), 2)
					sert.eq((parsed :: any)[1][1][2], "cmds")
					sert.eq((parsed :: any)[1][2][2], "a")
					sert.eq((parsed :: any)[2][1][2], "version")
				end
			end
			local legacyParsed = Process.rawParse(";m h", { ";" }, "%s")
			sert.eq(legacyParsed, { { { 2, "m" }, { 4, "h" } } })
			sert.eq(Process.rawParse(";m he", { ";" }, "%s"), { { { 2, "m" }, { 4, "he" } } })

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
			sert.eq(Process.runCommands(_K, vipPlr.UserId, ";testlimitcmd me,OtherTargetTester", true), false)
			sert.eq(runs, 0)
			sert.eq(Process.onCooldown(_K, vipPlr.UserId), true)
			h.env:step(10)

			-- Chaining multiple single-target commands in one message succeeds when limits.targets == 1 (per-argument target limit, #590)
			_K.Data.roles.vip.limits = { commands = 2, cooldown = 10, targets = 1 }
			sert.eq(
				Process.runCommands(_K, vipPlr.UserId, ";testlimitcmd me ;testlimitcmd OtherTargetTester", true),
				true
			)
			sert.eq(runs, 2)
			sert.eq(Process.onCooldown(_K, vipPlr.UserId), true)
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
			sert.eq(Process.runCommands(_K, vipPlr.UserId, ";testdualtargetcmd me OtherTargetTester", true), true)
			sert.eq(dualArgRuns, 1)
			sert.eq(
				Process.runCommands(
					_K,
					vipPlr.UserId,
					";testdualtargetcmd me,OtherTargetTester OtherTargetTester",
					true
				),
				false
			)
			h.env:step(10)
			runs = 0
			_K.Data.roles.vip.limits = { commands = 1, cooldown = 10, targets = 1 }

			-- Targeting 1 player succeeds through both validate and parse, and consumes the 1 command limit
			sert.eq(Process.runCommands(_K, vipPlr.UserId, ";testlimitcmd me", true), true)
			sert.eq(runs, 1)

			-- Second command within cooldown is blocked before execution
			sert.eq(Process.runCommands(_K, vipPlr.UserId, ";testlimitcmd me", true), false)
			sert.eq(runs, 1)
			h.env:step(10)

			-- 3. Process.countCommand & Process.onCooldown (client vs server)
			_K.Data.roles.vip.limits = { commands = 2, cooldown = 5, targets = 4 }
			Process.resetLimit(vipPlr.UserId)
			_K.IsServer = false
			sert.eq(Process.onCooldown(_K, vipPlr.UserId), false)
			Process.countCommand(_K, vipPlr.UserId, 2)
			sert.eq(Process.onCooldown(_K, vipPlr.UserId), false)
			_K.IsServer = true
			sert.eq(Process.onCooldown(_K, vipPlr.UserId), false)
			Process.countCommand(_K, vipPlr.UserId)
			sert.eq(Process.onCooldown(_K, vipPlr.UserId), false)
			Process.countCommand(_K, vipPlr.UserId, 1)
			sert.eq(Process.onCooldown(_K, vipPlr.UserId), true)
			h.env:step(5)
			sert.eq(Process.onCooldown(_K, vipPlr.UserId), false)

			-- 4. Process.prepareCommands maxPrepare cap, command.Error, and client VIP / GamePass / RestrictedToRole
			Process.countCommand(_K, vipPlr.UserId, 1) -- 1 left in limit of 2
			local okPrepCap, cappedCmds =
				Process.prepareCommands(_K, vipPlr.UserId, ";testlimitcmd me ;testlimitcmd me")
			sert.eq(okPrepCap, true)
			sert.eq(#cappedCmds, 2)
			sert.eq(cappedCmds[1].validated, true)
			sert.eq(cappedCmds[2].validated, nil)
			sert.eq(cappedCmds[2].alias, "testlimitcmd")
			Process.resetLimit(vipPlr.UserId)

			local okPrepFail, failMsg, failCmds =
				Process.prepareCommands(_K, vipPlr.UserId, ";testlimitcmd NonExistentPlayerXYZ")
			sert.eq(okPrepFail, false)
			sert.eq(failCmds[1].Error, failMsg)

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
			sert.eq(okClientRestr, false)
			sert.eq(restrMsg, '"<b>testlimitcmd</b>" command restricted to <b>VIP</b>')
			sert.eq(vipPrompted, 1)
			sert.eq(#gpPrompted, 0)
			_K.Data.settings.vip = false
			Process.prepareCommands(_K, guestPlr.UserId, ";testlimitcmd me")
			sert.eq(vipPrompted, 1)
			sert.eq(#gpPrompted, 1)
			sert.eq(gpPrompted[1].plr, guestPlr)
			sert.eq(gpPrompted[1].gpId, 777)
			_K.Data.settings.vip = true
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
			sert.eq(Process.runCommands(_K, superPlr.UserId, ";testecho " .. longPayload, true), true)
			sert.eq(#(capturedEcho or ""), 1050)
			sert.eq(hookFired ~= nil and hookFired.from == superPlr.UserId and hookFired.count == 1, true)
			hookConn:Disconnect()

			-- Guest / non-restricted role has >1024 truncated in prepareCommands and runCommands
			_K.Data.roles.vip.limits = { commands = 2, cooldown = 5, targets = 4 }
			Process.resetLimit(vipPlr.UserId)
			sert.eq(Process.runCommands(_K, vipPlr.UserId, ";testecho " .. longPayload, true), true)
			sert.eq(#(capturedEcho or ""), 1024 - #";testecho ")
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
			sert.eq(Process.runCommands(_K, vipPlr.UserId, ";testecho ok", true), true)
			expandConn:Disconnect()
			_K.alert = origAlert
			sert.eq(lastAlert ~= nil, true)
			sert.eq(
				string.find((lastAlert :: any).msg, "Commands not ran: skippedone, skippedtwo", 1, true) ~= nil,
				true
			)
			Process.resetLimit(vipPlr.UserId)

			-- Empty/non-command string returns true
			sert.eq(Process.runCommands(_K, superPlr.UserId, "hello world not a command", true), true)

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
			sert.eq(Process.runCommands(_K, superPlr.UserId, ";nonexistentcmd", true, false, true), false)
			h.env:flush()
			sert.eq(#clientNotifies, 0)
			sert.eq(#clientErrorLogs, 0)

			sert.eq(Process.runCommands(_K, superPlr.UserId, ";nonexistentcmd", true, false, false), false)
			h.env:flush()
			sert.eq(#clientNotifies, 1)
			sert.eq(#clientErrorLogs, 1)
			sert.eq(clientErrorLogs[1].from, superPlr.UserId)

			sert.eq(
				Process.runCommands(_K, superPlr.UserId, ";testclientonlycmd ;testecho hello", false, true, false),
				true
			)
			h.env:flush()
			sert.eq(#remoteCmdFired, 1)
			sert.eq(remoteCmdFired[1], ";testecho hello")
			sert.eq(lastGlobalLogFlag, true)
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
			sert.eq(okPrepReq, true)
			local leftRes = reqCmds[1]:requestCommand(peer1, { { peer1 } }, _K.Registry.commands.testmultireq.run)
			sert.eq(leftRes, false)
			sert.eq(string.find(reqNotifies[#reqNotifies].text, "left during", 1, true) ~= nil, true)

			-- Accepted request where run errors notifies sender with "command failed:"
			_K.Remote.RequestCommand.Invoke = function()
				return true
			end
			shouldErrInRun = true
			table.clear(reqNotifies)
			reqCmds[1]:requestCommand(peer1, { { peer1 } }, _K.Registry.commands.testmultireq.run)
			sert.eq(string.find(reqNotifies[#reqNotifies].text, "command failed:", 1, true) ~= nil, true)
			shouldErrInRun = false

			-- Accepted request where run succeeds does NOT fire "command failed:"
			table.clear(reqNotifies)
			reqCmds[1]:requestCommand(peer1, { { peer1 } }, _K.Registry.commands.testmultireq.run)
			sert.eq(string.find(reqNotifies[#reqNotifies].text, "accepted", 1, true) ~= nil, true)
			sert.eq(#multiRuns, 1)
			sert.eq(multiRuns[1], { "PeerReqOne" })

			-- Multi-target list with 2 peers + 1 lower-rank player splits solo requests for each peer and runs immediately for lowPlr
			table.clear(multiRuns)
			local okMulti, multiCmds =
				Process.prepareCommands(_K, superPlr.UserId, ";testmultireq PeerReqOne,PeerReqTwo,LowReqTarget")
			sert.eq(okMulti, true)
			local runOk = multiCmds[1]:run()
			sert.eq(runOk, true)
			h.env:flush()
			sert.eq(#multiRuns, 3)
			sert.eq(multiRuns[1], { "PeerReqTwo" })
			sert.eq(multiRuns[2], { "PeerReqOne" })
			sert.eq(multiRuns[3], { "LowReqTarget" })

			-- Multi-target list with ONLY peers skips running the initial command and only runs via requests
			table.clear(multiRuns)
			_K.Remote.RequestCommand.Invoke = function()
				return false
			end
			local okOnlyPeers, onlyPeerCmds =
				Process.prepareCommands(_K, superPlr.UserId, ";testmultireq PeerReqOne,PeerReqTwo")
			sert.eq(okOnlyPeers, true)
			sert.eq(onlyPeerCmds[1]:run(), true)
			h.env:flush()
			sert.eq(#multiRuns, 0)

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
			sert.eq(rawCmd:validate(), true)
			sert.eq(rawCmd.array[2][1], 14)
			sert.eq(rawCmd.array[2][2], "")
			sert.eq(_K.Data.targetLimits[superPlr.UserId], 1)

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
			sert.eq(okTr, false)
			sert.eq(trErr.message, "Custom transform error")

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
			sert.eq(okWs, false)
			sert.eq(wsErr.message, "Invalid transform: nil")

			_K.Data.targetLimits[superPlr.UserId] = 7
			local valFailArg =
				Argument.new(dummyCmd, { type = "testniltransform", name = "V", description = "V" }, 5, "invalidval")
			sert.eq(valFailArg:transform(), true)
			local okVal, valErr = valFailArg:validate()
			sert.eq(okVal, false)
			sert.eq(valErr.message, "Invalid argument: invalidval")
			sert.eq(_K.Data.targetLimits[superPlr.UserId], 0)

			_K.Data.targetLimits[superPlr.UserId] = 7
			local parseFailArg =
				Argument.new(dummyCmd, { type = "testniltransform", name = "P", description = "P" }, 5, "parsefail")
			sert.eq(parseFailArg:transform(), true)
			sert.eq(parseFailArg:validate(), true)
			sert.eq(_K.Data.targetLimits[superPlr.UserId], 5)
			local okParse, parseErr = parseFailArg:parse()
			sert.eq(okParse, false)
			sert.eq(parseErr.message, "Custom parse error")
			sert.eq(_K.Data.targetLimits[superPlr.UserId], 0)

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
			sert.eq(okSP, true)
			sert.eq(resSP, "sub_item")

			local listPrefArg =
				Argument.new(dummyCmd, { type = "testlistpref", name = "LP", description = "LP" }, 5, "@item")
			local okLP, resLP = listPrefArg:prepare()
			sert.eq(okLP, true)
			sert.eq(resLP, { "sub_item", "sub2_item" })

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
			sert.eq(table.find(_K.Registry.commandNames, "tro_old") ~= nil, true)
			_K.Registry.registerCommand(_K, {
				name = "testregoverride",
				aliases = { "tro_new" },
				description = "New cmd without explicit group",
				args = {},
				run = function() end,
			})
			h.env:step(0.3)
			regConn:Disconnect()
			sert.eq(regHookCmd ~= nil and regHookCmd.name == "testregoverride", true)
			sert.eq(_K.Registry.commands.testregoverride.group, "moderation")
			sert.eq(_K.Registry.commands.tro_old, nil)
			sert.eq(table.find(_K.Registry.commandNames, "tro_old"), nil)
			sert.eq(table.find(_K.Registry.commandNames, "tro_new") ~= nil, true)

			local longAliasQuery = "testregoverride" .. string.rep("z", 30)
			sert.eq(#_K.Registry.suggestCommandAlias(longAliasQuery) > 0, true)

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
			sert.eq(okFillCli, false)
			sert.eq(fillCliErr, "Not a player")
			_K.IsClient = false
			_K.IsServer = true

			local okFillSrv, fillSrvCmds = Process.prepareCommands(_K, superPlr.UserId, ";testfillsug 42")
			sert.eq(okFillSrv, true)
			sert.eq(fillSrvCmds[1].preparedArgs[1], "me")
			sert.eq(fillSrvCmds[1].args[2].skipped, "42")
			sert.eq(fillSrvCmds[1].preparedArgs[3], 42)

			local okFillSrv2, fillSrvCmds2 = Process.prepareCommands(_K, superPlr.UserId, ";testfillsug PeerReqOne 42")
			sert.eq(okFillSrv2, true)
			sert.eq(fillSrvCmds2[1].preparedArgs[1], "PeerReqOne")
			sert.eq(fillSrvCmds2[1].args[2].skipped, "42")
			sert.eq(fillSrvCmds2[1].preparedArgs[3], 42)

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
			sert.eq(Process.runCommands(_K, superPlr.UserId, ";testlogredact secretword", false), true)
			h.env:flush()
			sert.eq(capturedLogs[#capturedLogs].txt, ";testlogredact secretword")
			sert.eq(capturedLogs[#capturedLogs].live, ";testlogredact …")

			sert.eq(Process.runCommands(_K, superPlr.UserId, ";testlimitcmd NonExistentPlrXYZ", false), false)
			h.env:flush()
			sert.eq(capturedLogs[#capturedLogs].live, ";testlimitcmd …")
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
					sert.eq(parsed ~= nil, true)
					local simplified = {}
					for i, cmdArr in parsed or {} do
						sert.eq(#cmdArr >= 1, true)
						local row = {}
						for j, tok in cmdArr do
							local pos = tok[1]
							local text = tok[2]
							sert.eq(string.sub(raw, pos, pos + #text - 1), text)
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

			sert.prop(
				"Process.rawParse, prepareCommands, and runCommands satisfy strict grammar and authorization contracts",
				function(g)
					local malformed = malformedGen(g)
					local bInt = bIntGen(g)
					local bFloat = bFloatGen(g)
					local selector = selectorGen(g)
					for _, candidate in
						{
							malformed,
							`;fuzzcmd {selector} {bInt} {bFloat} "{malformed}"`,
							";fuzzcmd `quote \"inner\"` 'single' \\n\\t\\0 ;fuzzcmd " .. malformed,
							`;{malformed} "{malformed}"`,
						}
					do
						local okRaw, resRaw = pcall(Process.rawParse, candidate, { ";", "!" }, " ")
						sert.eq(okRaw, true)
						sert.eq(resRaw == nil or type(resRaw) == "table", true)
						if resRaw ~= nil then
							sert.eq(#resRaw >= 1, true)
							for _, cmdArr in resRaw do
								sert.eq(#cmdArr >= 1, true)
								for _, tok in cmdArr do
									sert.eq(type(tok[1]), "number")
									sert.eq(type(tok[2]), "string")
									sert.eq(tok[1] >= 1, true)
								end
							end
						end

						-- Unprivileged guest can never prepare or execute moderation command fuzzcmd
						local beforeCount = #capturedCalls
						Process.resetLimit(guest.UserId)
						local okPrepGuest, prepGuest, guestErrOrCmds =
							pcall(Process.prepareCommands, _K, guest.UserId, candidate)
						sert.eq(okPrepGuest, true)
						sert.eq(prepGuest ~= true, true)
						if prepGuest == false then
							sert.eq(type(guestErrOrCmds), "string")
							sert.eq(#guestErrOrCmds > 0, true)
						end

						Process.resetLimit(guest.UserId)
						local okRunGuest, runGuestRes = pcall(Process.runCommands, _K, guest.UserId, candidate, true)
						sert.eq(okRunGuest, true)
						if prepGuest == false then
							sert.eq(runGuestRes, false)
						end
						sert.eq(#capturedCalls, beforeCount)
						sert.eq(_K.Auth.getRank(guest.UserId), 0)

						-- Admin preparing arbitrary fuzzed command strings returns validated Command objects or non-empty error string
						Process.resetLimit(admin.UserId)
						local okPrepAdmin, prepAdminOk, prepAdminResult =
							pcall(Process.prepareCommands, _K, admin.UserId, candidate)
						sert.eq(okPrepAdmin, true)
						if prepAdminOk == true then
							sert.eq(type(prepAdminResult), "table")
							for _, cmdObj in prepAdminResult do
								sert.eq(cmdObj.validated, true)
								sert.eq(cmdObj.from, admin.UserId)
							end
						elseif prepAdminOk == false then
							local errMsg = if type(prepAdminResult) == "table"
								then prepAdminResult.message
								else prepAdminResult
							sert.eq(type(errMsg), "string")
							sert.eq(#errMsg > 0, true)
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
				gen = function(_state, g)
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
				gen = function(_state, g)
					return g:int(1, 100)
				end,
				run = function(sut, val)
					local ok = sut.Process.runCommands(sut._K, sut.mod.UserId, `;modelcmd ModelGuest {val}`, true)
					sut.h.env:step(0.05)
					return ok
				end,
				post = function(state, _sut, _val, ok)
					sert.eq(ok, state.lastModAllowed == true)
				end,
				next = function(state)
					local underLimit = state.modCommandsUsed < state.modCommandLimit
					state.lastModAllowed = underLimit and not state.filterCancel
					if underLimit then
						state.modCommandsUsed += 1
						if not state.filterCancel then
							state.expectedExecutions += 1
						end
					end
				end,
			},
			modRunOnPeerOrHigher = {
				gen = function(_state, g)
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
				post = function(state, _sut, _arg, ok)
					sert.eq(ok, state.lastModAllowed == true)
				end,
				next = function(state)
					local underLimit = state.modCommandsUsed < state.modCommandLimit
					state.lastModAllowed = underLimit and state.commandRequests and not state.filterCancel
					if underLimit then
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
				gen = function(_state, g)
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
				post = function(_state, _sut, _arg, ok)
					sert.eq(ok, false)
				end,
			},
			resetOrExpireCooldown = {
				gen = function(_state, g)
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
			noPreHookCancelledButCommandRan = function(_state, sut)
				return not sut.preHookCancelledButCommandRan
			end,
			noDeniedOrTimedOutRequestRan = function(_state, sut)
				return not sut.deniedOrTimedOutRequestRan
			end,
			noRankCeilingBypassed = function(_state, sut)
				return not sut.rankCeilingBypassed
			end,
		},
	}, { runs = 40, length = 15 })

	test(
		"rawParse earliest-prefix/invalid-UTF8/leading-space slicing, omitted optional log args, asset/subscription purchase prompts, and registerCommandAlias",
		function()
			local h = Harness.newEnv({ isStudio = false })
			h:requireData()
			local _K = h:requireK()
			local Process = _K.Process
			local Registry = _K.Registry

			-- 1. rawParse picks smallest commandStart across prefixList (and longest prefix on tie)
			local parsedEarliest = Process.rawParse("chat before !fly me :god me", { ":", "!" }, " ")
			sert.eq(parsedEarliest ~= nil, true)
			sert.eq(parsedEarliest[1][1][2], "fly")
			sert.eq(parsedEarliest[1][1][1], 14)

			local parsedLongestTie = Process.rawParse("  ::fly me", { ":", "::" }, " ")
			sert.eq(parsedLongestTie ~= nil, true)
			sert.eq(parsedLongestTie[1][1][2], "fly")
			sert.eq(parsedLongestTie[1][1][1], 5)

			-- 2. Invalid UTF-8 fallback keeps valid prefix before invalidPos instead of slicing tail
			local parsedBadUtf8 = Process.rawParse(";fly me\255garbage", ";", " ")
			sert.eq(parsedBadUtf8 ~= nil, true)
			sert.eq(parsedBadUtf8[1][1][2], "fly")
			sert.eq(parsedBadUtf8[1][2][2], "me")

			-- 3. Client runCommands slices single commands accurately even with leading whitespace and comma splitKey
			local adminPlr = h.env:addPlayer(601, "SliceAdmin")
			adminPlr:SetAttribute("_KRolesLoaded", true)
			_K.Auth.userRoleAdd(601, "superadmin")
			Registry.registerCommand(_K, {
				name = "testslicesa",
				aliases = {},
				description = "Test server slice",
				group = "Moderation",
				args = {
					{ type = "integer", name = "Num", optional = true },
					{ type = "rawString", name = "Note", optional = true },
				},
				run = function() end,
				runClient = function() end,
			})

			_K.IsServer = false
			_K.IsClient = true
			_K.LocalPlayer = adminPlr
			_K.client = {
				playerPrefix = {
					peek = function()
						return ";"
					end,
				},
			} :: any
			local firedToServer = {}
			local origCmdFire = _K.Remote.Command.Fire
			_K.Remote.Command.Fire = function(_self, payload)
				table.insert(firedToServer, payload)
			end
			sert.eq(Process.runCommands(_K, 601, "   ;testslicesa 1 hello ;testslicesa 2 world", true), true)
			sert.eq(firedToServer[#firedToServer], ";testslicesa 1 hello ;testslicesa 2 world")

			_K.Data.settings.splitKey = ","
			sert.eq(Process.runCommands(_K, 601, "  ;testslicesa,1,hi,;testslicesa,2,bye", true), true)
			sert.eq(firedToServer[#firedToServer], ";testslicesa,1,hi ;testslicesa,2,bye")
			_K.Data.settings.splitKey = " "
			_K.Remote.Command.Fire = origCmdFire

			-- 4. VIP role purchase prompts support roleData.assets (first unowned) and roleData.subscriptions
			local guestPlr = h.env:addPlayer(602, "AssetSubGuest")
			guestPlr:SetAttribute("_KRolesLoaded", true)
			_K.LocalPlayer = guestPlr
			_K.Data.roles.assetTier = {
				_key = "assetTier",
				_rank = 2,
				name = "Asset Tier",
				groups = {},
				permissions = {},
				commands = { testslicesa = true },
				assets = { 11111, 22222 },
			}
			_K.Data.roles.subTier = {
				_key = "subTier",
				_rank = 3,
				name = "Sub Tier",
				groups = {},
				permissions = {},
				commands = { testslicesa = true },
				subscriptions = { "EXP-999" },
			}
			local promptedAssets = {}
			local promptedSubs = {}
			local mktMethods = rawget(h.env.game:GetService("MarketplaceService"), "_methods")
			local origOwnsAsset = mktMethods.PlayerOwnsAssetAsync
			local origPromptPurchase = mktMethods.PromptPurchase
			local origPromptSub = mktMethods.PromptSubscriptionPurchase
			mktMethods.PlayerOwnsAssetAsync = function(_self, _plr, assetId)
				return assetId == 11111 -- owns first asset, does NOT own second asset 22222
			end
			mktMethods.PromptPurchase = function(_self, plr, assetId)
				table.insert(promptedAssets, { plr = plr, assetId = assetId })
			end
			mktMethods.PromptSubscriptionPurchase = function(_self, plr, subId)
				table.insert(promptedSubs, { plr = plr, subId = subId })
			end

			local okPrepPrompt = Process.prepareCommands(_K, 602, ";testslicesa")
			sert.eq(okPrepPrompt, false)
			sert.eq(#promptedAssets, 1)
			sert.eq(promptedAssets[1].assetId, 22222)
			sert.eq(#promptedSubs, 0)

			-- noPrompt = true suppresses all purchase prompts
			Process.prepareCommands(_K, 602, ";testslicesa", nil, true)
			sert.eq(#promptedAssets, 1)
			sert.eq(#promptedSubs, 0)

			-- Removing lower-rank assetTier allows subTier to be prompted next
			_K.Data.roles.assetTier = nil
			Process.prepareCommands(_K, 602, ";testslicesa")
			sert.eq(#promptedSubs, 1)
			sert.eq(promptedSubs[1].subId, "EXP-999")

			mktMethods.PlayerOwnsAssetAsync = origOwnsAsset
			mktMethods.PromptPurchase = origPromptPurchase
			mktMethods.PromptSubscriptionPurchase = origPromptSub
			_K.Data.roles.assetTier = nil
			_K.Data.roles.subTier = nil

			-- 5. Registry.registerCommandAlias tracks Registry.aliases, allows re-registering aliases, and avoids double-prefixing
			_K.LocalPlayer = adminPlr
			local aliasRan = {}
			Registry.registerCommand(_K, {
				name = "testaliasdest",
				aliases = {},
				description = "Alias target",
				group = "Utility",
				args = { { type = "rawString", name = "Val", optional = true } },
				runClient = function(_ctx, val)
					table.insert(aliasRan, val or "none")
				end,
			})
			Registry.registerCommandAlias(_K, "myshortcut", "testaliasdest first")
			sert.eq(Registry.aliases.myshortcut ~= nil, true)
			-- Re-registering with already-prefixed command overrides cleanly without double-prefixing
			Registry.registerCommandAlias(_K, "MYSHORTCUT", ";testaliasdest second")
			sert.eq(Process.runCommands(_K, 601, ";myshortcut", true), true)
			sert.eq(aliasRan, { "second" })

			-- Built-in command name cannot be overwritten by registerCommandAlias
			Registry.registerCommandAlias(_K, "testaliasdest", ";testslicesa")
			sert.eq(Registry.aliases.testaliasdest, nil)

			-- 6. Server runCommands skips omitted middle and trailing-space optional arguments in command logs
			_K.IsClient = false
			_K.IsServer = true
			table.clear(_K.Data.logs)
			-- Skipped middle optional integer ("noteOnly" goes to arg 2 Note, arg 1 Num is skipped) -> single space, no ";testslicesa  noteOnly"
			sert.eq(Process.runCommands(_K, 601, ";testslicesa noteOnly"), true)
			h.env:step(0.1)
			sert.eq(_K.Data.logs[#_K.Data.logs][1], ";testslicesa noteOnly")

			-- Trailing space with omitted optional rawString (";testslicesa 42 ") -> logs ";testslicesa 42" with NO trailing "…" redaction
			local restrictedPeer = h.env:addPlayer(603, "RestrictedPeer")
			restrictedPeer:SetAttribute("_K_READY", true)
			local tcsMethods = rawget(h.env.game:GetService("TextChatService"), "_methods")
			local origCanUsersChat = tcsMethods.CanUsersChatAsync
			tcsMethods.CanUsersChatAsync = function()
				return false
			end
			_K.Chat.cooldown(601, "log")
			sert.eq(Process.runCommands(_K, 601, ";testslicesa 42 "), true)
			h.env:step(0.1)
			sert.eq(_K.Data.logs[#_K.Data.logs][1], ";testslicesa 42")
			tcsMethods.CanUsersChatAsync = origCanUsersChat
		end
	)

	test(
		"rawParse returns matchedPrefix, client preserves prefix across forwarding, countCommand/resetLimit toggle cooldown, and registerCommandAlias keeps alphanumeric prefix chars",
		function()
			local h = Harness.newEnv({ isStudio = false })
			local Data = h:requireData()
			local _K = h:requireK()
			local Process = _K.Process
			local Registry = _K.Registry

			local parsed, matched = Process.rawParse("::fly me ::god me", { "::", ";" }, " ")
			sert.eq(parsed ~= nil, true)
			sert.eq(#(parsed :: any), 2)
			sert.eq(matched, "::")

			local p701 = h.env:addPlayer(701, "ChainPlr")
			p701:SetAttribute("_KRolesLoaded", true)
			_K.Auth.userRoleAdd(701, "admin")

			local explodeRuns = 0
			Registry.registerCommand(_K, {
				name = "explode",
				group = "Utility",
				args = {},
				runClient = function()
					explodeRuns += 1
				end,
			})
			Registry.registerCommand(_K, {
				name = "testecho",
				group = "Utility",
				args = { { type = "rawString", name = "Msg" } },
				run = function() end,
			})

			local origLocalPlayer = h.env.Players.LocalPlayer
			local origClient = _K.client
			h.env.Players.LocalPlayer = p701
			_K.IsClient = true
			_K.IsServer = false
			_K.LocalPlayer = p701
			local prefixSig = _K.Flux.signal("e")
			_K.client = { playerPrefix = prefixSig } :: any

			Data.playerPrefix[701] = "e"
			Registry.registerCommandAlias(_K, "boom", "explode")
			sert.eq(Registry.aliases.boom ~= nil, true)
			sert.eq(Process.runCommands(_K, 701, "eboom", true), true)
			sert.eq(explodeRuns, 1)

			Data.settings.prefix = { ";" }
			Data.playerPrefix[701] = ":"
			prefixSig(":")
			local forwarded: { string } = {}
			local origCommandFire = _K.Remote.Command.Fire
			_K.Remote.Command.Fire = function(_self: any, text: string)
				table.insert(forwarded, text)
			end
			sert.eq(Process.runCommands(_K, 701, ":testecho ;all", true), true)
			_K.Remote.Command.Fire = origCommandFire
			sert.eq(forwarded, { ":testecho ;all" })

			h.env.Players.LocalPlayer = origLocalPlayer
			_K.client = origClient
			_K.IsClient = false
			_K.IsServer = true
			_K.LocalPlayer = nil

			local p702 = h.env:addPlayer(702, "LimitPlr")
			p702:SetAttribute("_KRolesLoaded", true)
			_K.Auth.userRoleAdd(702, "vip")
			Data.roles.vip.limits = { commands = 1, cooldown = 5 }
			Process.countCommand(_K, 702)
			sert.eq(p702:GetAttribute("_KCommandCooldown"), true)
			Process.resetLimit(702)
			sert.eq(p702:GetAttribute("_KCommandCooldown"), nil)
		end
	)
end)

do
	return {}
end
