local Harness = require("./Harness")
local sert = require("../sert")

local describe, test = sert.describe, sert.test

local G = Harness.globals
local Color3 = G.Color3
local Vector2 = G.Vector2
local Vector3 = G.Vector3
local CFrame = G.CFrame
local Enum = G.Enum
local rbxTypeof = G.typeof

local function newMountedK(opts: any?)
	local h = Harness.newEnv(opts)
	h:requireData()
	local _K = h:requireK()
	h.env:step(0.25)
	local Argument = h.env:require(h.Shared:WaitForChild("Process"):WaitForChild("Argument"))
	return h, _K, Argument
end

local function makeCommandContext(_K: any, fromUserId: number, extraCmd: { [string]: any }?)
	local fromPlayer = _K.Service.Players:GetPlayerByUserId(fromUserId)
	local rank, role = _K.Auth.getRank(fromUserId)
	local cmd: { [string]: any } = {
		_K = _K,
		alias = "testcmd",
		array = { { 1, "testcmd" } },
		definition = {
			name = "testcmd",
			group = "moderation",
			args = {},
		},
		from = fromUserId,
		fromPlayer = fromPlayer,
		fromRank = rank,
		fromRole = role,
		rank = rank,
		text = ";testcmd",
	}
	if extraCmd then
		for k, v in extraCmd do
			cmd[k] = v
		end
	end
	return cmd
end

local function makeArgSelf(
	_K: any,
	fromUserId: number,
	argDef: { [string]: any }?,
	rawArg: string?,
	extraCmd: { [string]: any }?
)
	_K.Data.targetLimits[fromUserId] = 0
	local def = argDef or { type = "string", name = "Arg" }
	local cmd = makeCommandContext(_K, fromUserId, extraCmd)
	return {
		_K = _K,
		command = cmd,
		commandArray = cmd.array,
		definition = def,
		rawArg = rawArg or "",
		rawArgs = { rawArg or "" },
		transformedArgs = {},
		transformedTypes = {},
		parsedArgs = {},
	}
end

local function attachPlayerHelpers(
	env: any,
	player: any,
	opts: {
		position: any?,
		friends: { [number]: boolean }?,
		groups: { [number]: number }?,
	}?
)
	local cfg = opts or {}
	local char = env.Instance.new("Model", env.workspace)
	char.Name = player.Name
	local hrp = env.Instance.new("Part", char)
	hrp.Name = "HumanoidRootPart"
	local pos = cfg.position or Vector3.zero
	hrp.Position = pos
	hrp.CFrame = CFrame.new(pos)
	char.PrimaryPart = hrp
	char:PivotTo(CFrame.new(pos))
	player.Character = char
	player:SetAttribute("_KRolesLoaded", true)

	local friendSet = cfg.friends or {}
	local groupRanks = cfg.groups or {}

	local methods = rawget(player, "_methods") or {}
	methods.DistanceFromCharacter = function(self: any, point: any): number
		local c = self.Character
		if not c or not c.PrimaryPart then
			return 0
		end
		return (c.PrimaryPart.Position - point).Magnitude
	end
	methods.IsFriendsWith = function(_self: any, other: any): boolean
		local otherId = if type(other) == "number" then other else other.UserId
		return friendSet[otherId] == true
	end
	methods.IsInGroupAsync = function(_self: any, groupId: number): boolean
		return (groupRanks[groupId] or 0) > 0
	end
	rawset(player, "_methods", methods)

	return char, hrp
end

local cachedMutant: any = nil
local cachedK: any = nil
local cachedArgument: any = nil

local function getSharedK(): (any, any)
	local curMutant = (_G :: any).__SERT_MUTANT
	if cachedK == nil or cachedMutant ~= curMutant then
		local _, _K, Argument = newMountedK({ isStudio = false })
		cachedK = _K
		cachedArgument = Argument
		cachedMutant = curMutant
	end
	return cachedK, cachedArgument
end

describe("DefaultTypes · Primitives", function()
	test("boolean and booleans transform, validate, parse, and suggestions", function()
		local _K, Argument = getSharedK()
		local boolType = _K.Registry.types.boolean
		local boolsType = _K.Registry.types.booleans

		sert.eq(boolType.transform("TRUE"), "true")
		sert.eq(boolType.transform("Yes"), "yes")

		-- Empty string defaults to true
		sert.eq((boolType.validate("")), true)
		sert.eq(boolType.parse(""), true)

		-- Truthy prefixes: +, true, yes, enabled
		for _, input in { "+", "t", "true", "y", "yes", "e", "enabled" } do
			local transformed = boolType.transform(input)
			sert.eq((boolType.validate(transformed)), true)
			sert.eq(boolType.parse(transformed), true)
		end

		-- Falsy prefixes: -, false, no, disabled
		for _, input in { "-", "f", "false", "n", "no", "d", "disabled" } do
			local transformed = boolType.transform(input)
			sert.eq((boolType.validate(transformed)), true)
			sert.eq(boolType.parse(transformed), false)
		end

		-- Invalid boolean
		local okInvalid, errInvalid = boolType.validate("maybe")
		sert.eq(okInvalid, false)
		sert.eq(errInvalid, "Invalid boolean")
		local parsedInvalid, parseErr = boolType.parse("maybe")
		sert.eq(parsedInvalid, nil)
		sert.eq(parseErr, "Invalid boolean")

		-- Suggestions
		local suggestions = boolType.suggestions("", 1)
		sert.eq(type(suggestions), "table")
		sert.eq(table.find(suggestions, "true") ~= nil, true)
		sert.eq(table.find(suggestions, "false") ~= nil, true)

		-- Listable booleans via Argument:prepare()
		sert.eq(boolsType.listable, true)
		local cmd = makeCommandContext(_K, 1)
		local arg = Argument.new(cmd, { type = "booleans", name = "Flags" }, 1, "true,no,+,disabled")
		local ok, parsed = arg:prepare()
		sert.eq(ok, true)
		sert.eq(parsed, { true, false, true, false })
	end)

	test("integer, integers, number, and numbers transform, validate, and parse", function()
		local _K, Argument = getSharedK()
		local intType = _K.Registry.types.integer
		local intsType = _K.Registry.types.integers
		local numType = _K.Registry.types.number
		local numsType = _K.Registry.types.numbers

		sert.eq(intType.filterLog, true)
		sert.eq(numType.filterLog, true)

		-- Empty string transforms to 0
		sert.eq(intType.transform(""), 0)
		sert.eq((intType.validate(0)), true)
		sert.eq(intType.parse(0), 0)

		-- Valid integers
		local v42 = intType.transform("42")
		sert.eq(v42, 42)
		sert.eq((intType.validate(v42)), true)
		sert.eq(intType.parse(v42), 42)

		local vNeg = intType.transform("-15")
		sert.eq((intType.validate(vNeg)), true)
		sert.eq(intType.parse(vNeg), -15)

		-- Float rejected by integer, accepted by number
		local vFloat = intType.transform("3.14")
		local okIntFloat, errIntFloat = intType.validate(vFloat)
		sert.eq(okIntFloat, false)
		sert.eq(errIntFloat, "Only whole numbers are valid")

		sert.eq((numType.validate(vFloat)), true)
		sert.eq(numType.parse(vFloat), 3.14)

		-- Non-numeric rejected by both
		local badVal, badErr = intType.transform("notanumber")
		sert.eq(badVal, nil)
		sert.eq(badErr, "Invalid number")
		sert.eq((intType.validate(badVal)), false)
		sert.eq((numType.validate(badVal)), false)

		-- Listable integers and numbers
		sert.eq(intsType.listable, true)
		sert.eq(numsType.listable, true)
		local cmd = makeCommandContext(_K, 1)
		local intArg = Argument.new(cmd, { type = "integers", name = "Ids" }, 1, "10,-20,30")
		local okInts, parsedInts = intArg:prepare()
		sert.eq(okInts, true)
		sert.eq(parsedInts, { 10, -20, 30 })

		local numArg = Argument.new(cmd, { type = "numbers", name = "Coords" }, 1, "1.5,-2.25,0")
		local okNums, parsedNums = numArg:prepare()
		sert.eq(okNums, true)
		sert.eq(parsedNums, { 1.5, -2.25, 0 })
	end)

	test("string, strings, rawString, rawStrings, chatString, and stringGreedy", function()
		local _K, Argument = getSharedK()
		local strType = _K.Registry.types.string
		local strsType = _K.Registry.types.strings
		local rawStrType = _K.Registry.types.rawString
		local rawStrsType = _K.Registry.types.rawStrings
		local chatStrType = _K.Registry.types.chatString
		local greedyStrType = _K.Registry.types.stringGreedy

		sert.eq(rawStrType.filterLog, true)
		sert.eq(rawStrType.freeText, true)
		sert.eq((rawStrType.validate("hello")), true)
		sert.eq((rawStrType.validate(nil)), false)
		sert.eq(rawStrType.parse("hello"), "hello")
		sert.eq(rawStrType.parse(123), "123")
		sert.eq(chatStrType.parse("chat msg"), "chat msg")
		sert.eq(greedyStrType.parse("greedy msg"), "greedy msg")

		sert.eq(strType.freeText, true)
		sert.eq((strType.validate("broadcast")), true)
		sert.eq((strType.validate(nil)), false)

		-- Global command bypasses chat check and returns raw string
		local globalSelf = makeArgSelf(_K, 10, { type = "string", name = "Msg" }, "global text", { global = true })
		sert.eq(strType.parse("global text", globalSelf), "global text")

		-- Server non-global command filters string via TextChat / TextService
		local serverSelf = makeArgSelf(_K, 10, { type = "string", name = "Msg" }, "server text", { global = false })
		sert.eq(strType.parse("server text", serverSelf), "server text")

		-- When CanUserChatAsync returns false, string.parse fails with "User cannot chat"
		local tcsMethods = rawget(_K.Service.TextChat, "_methods")
		local origCanChat = tcsMethods.CanUserChatAsync
		sert.afterEach(function()
			tcsMethods.CanUserChatAsync = origCanChat
		end)
		tcsMethods.CanUserChatAsync = function()
			return false
		end
		local blockedVal, blockedErr = strType.parse("blocked text", serverSelf)
		sert.eq(blockedVal, nil)
		sert.eq(blockedErr, "User cannot chat")
		tcsMethods.CanUserChatAsync = origCanChat

		-- Listable strings and rawStrings via Argument:prepare()
		sert.eq(strsType.listable, true)
		sert.eq(rawStrsType.listable, true)
		local cmd = makeCommandContext(_K, 10)
		local rawArg = Argument.new(cmd, { type = "rawStrings", name = "Reasons" }, 1, '"first reason",second')
		local okRaw, parsedRaw = rawArg:prepare()
		sert.eq(okRaw, true)
		sert.eq(parsedRaw, { "first reason", "second" })

		local strArg = Argument.new(cmd, { type = "strings", name = "Words" }, 1, "alpha,beta")
		local okStr, parsedStr = strArg:prepare()
		sert.eq(okStr, true)
		sert.eq(parsedStr, { "alpha", "beta" })
	end)
end)

describe("DefaultTypes · Time", function()
	test("timeSimple parses all units, compound durations, forever (-1), empty default, and suggestions", function()
		local _K = getSharedK()
		local timeType = _K.Registry.types.timeSimple

		sert.eq(timeType.filterLog, true)

		-- Empty string -> 1 second
		local okEmpty, valEmpty = timeType.validate("")
		sert.eq(okEmpty, true)
		sert.eq(valEmpty, 1)
		sert.eq(timeType.parse(""), 1)

		-- Forever (-1 and "-")
		local okForever, valForever = timeType.validate("-1")
		sert.eq(okForever, true)
		sert.eq(valForever, -1)
		sert.eq(timeType.parse("-1"), -1)
		sert.eq(timeType.parse("-"), -1)

		-- Session (0) and plain numbers
		sert.eq(timeType.parse("0"), 0)
		sert.eq(timeType.parse("45"), 45)

		-- Individual units: ms, s, m, h/hr, d, w/wk, month, y/yr
		sert.eq(timeType.parse("500ms"), 0.5)
		sert.eq(timeType.parse("500mss"), 0.5)
		sert.eq(timeType.parse("30s"), 30)
		sert.eq(timeType.parse("2m"), 120)
		sert.eq(timeType.parse("2h"), 7200)
		sert.eq(timeType.parse("1hr"), 3600)
		sert.eq(timeType.parse("1d"), 86400)
		sert.eq(timeType.parse("1w"), 604800)
		sert.eq(timeType.parse("1wk"), 604800)
		sert.eq(timeType.parse("1month"), 2592000)
		sert.eq(timeType.parse("1y"), 31557600)
		sert.eq(timeType.parse("1yr"), 31557600)

		-- Compound duration
		sert.eq(timeType.parse("1d 2h 30m 15s"), 86400 + 7200 + 1800 + 15)

		-- Invalid inputs
		local okNoMatch, errNoMatch = timeType.validate("not_a_time")
		sert.eq(okNoMatch, false)
		sert.eq(errNoMatch, "Invalid time format")
		sert.throws(function()
			timeType.parse("not_a_time")
		end)

		local okBadUnit, errBadUnit = timeType.validate("10qqq")
		sert.eq(okBadUnit, false)
		sert.eq(errBadUnit, "Invalid time format")
		sert.throws(function()
			timeType.parse("10qqq")
		end)

		-- Suggestions for empty, "-1", singular "1", and plural "5"
		local sugDefault = timeType.suggestions("")
		sert.eq(type(sugDefault), "table")
		sert.eq(sugDefault[1][1], "0")
		sert.eq(sugDefault[2][1], "-1")

		local sugNeg = timeType.suggestions("-")
		sert.eq(#sugNeg, 2)

		local sugOne = timeType.suggestions("1")
		sert.eq(#sugOne > 2, true)

		local sugFive = timeType.suggestions("5")
		sert.eq(#sugFive > 2, true)
	end)

	test("timeSimple accepts only input made entirely of durations", function()
		local _K = getSharedK()
		local timeType = _K.Registry.types.timeSimple

		-- every duration form still parses
		sert.eq(timeType.parse("1d2h"), 86400 + 7200)
		sert.eq(timeType.parse("1.5h"), 5400)
		sert.eq(timeType.parse("5 days"), 5 * 86400)
		sert.eq(timeType.parse("10M"), 600)
		sert.eq(timeType.parse(" 1h 30m "), 5400)

		-- only -1 and - are forever, not any part of -1
		sert.eq(timeType.parse("1"), 1)

		-- text that only contains a duration is not one
		for _, input in { "appeal in 5 days", "back in 5 minutes", "5d3", "appeal:5d", "5d!", " " } do
			local ok, err = timeType.validate(input)
			sert.eq(ok, false)
			sert.eq(err, "Invalid time format")
		end

		-- so an optional duration skips it and the text reaches the reason
		local h = Harness.newEnv()
		local Data = h:requireData()
		local _K2 = h:requireK()
		local admin = h.env:addPlayer(10, "AdminUser")
		Data.creatorId = admin.UserId
		local ok, commands = _K2.Process.prepareCommands(_K2, admin.UserId, ';shutdown "back in 5 minutes"')
		sert.eq(ok, true)
		sert.eq(commands[1].preparedArgs[1], nil)
		sert.eq(commands[1].preparedArgs[2], "back in 5 minutes")
		ok, commands = _K2.Process.prepareCommands(_K2, admin.UserId, ";shutdown 5m back soon")
		sert.eq(ok, true)
		sert.eq(commands[1].preparedArgs[1], 300)
		sert.eq(commands[1].preparedArgs[2], "back soon")
	end)

	sert.laws.codec("timeSimple duration roundtrip (d, h, m, s, -1)", {
		gen = function(g)
			if g:bool(0.15) then
				return -1
			end
			local d = g:int(0, 14)
			local h = g:int(0, 23)
			local m = g:int(0, 59)
			local s = g:int(0, 59)
			return d * 86400 + h * 3600 + m * 60 + s
		end,
		encode = function(seconds: number): string
			if seconds == -1 then
				return "-1"
			elseif seconds == 0 then
				return "0s"
			end
			local rem = seconds
			local d = math.floor(rem / 86400)
			rem %= 86400
			local h = math.floor(rem / 3600)
			rem %= 3600
			local m = math.floor(rem / 60)
			local s = rem % 60
			local parts = {}
			if d > 0 then
				table.insert(parts, `{d}d`)
			end
			if h > 0 then
				table.insert(parts, `{h}h`)
			end
			if m > 0 then
				table.insert(parts, `{m}m`)
			end
			if s > 0 then
				table.insert(parts, `{s}s`)
			end
			return table.concat(parts, " ")
		end,
		decode = function(encoded: string): number
			local _K = getSharedK()
			local timeType = _K.Registry.types.timeSimple
			local ok, validated = timeType.validate(encoded)
			sert.eq(ok, true)
			local parsed = timeType.parse(encoded)
			sert.eq(validated, parsed)
			return parsed
		end,
	}, { runs = 80 })
end)

describe("DefaultTypes · Color", function()
	test("color transforms hex, RGB, named colors, BrickColor names/ids, random, and suggestions", function()
		local _K = getSharedK()
		local colorType = _K.Registry.types.color

		-- Empty string transforms to "" and fails validate
		sert.eq(colorType.transform(""), "")
		local okEmpty, errEmpty = colorType.validate("")
		sert.eq(okEmpty, false)
		sert.eq(errEmpty, "Invalid Color3")

		-- Named colors
		local red = colorType.transform("red")
		sert.eq((colorType.validate(red)), true)
		sert.eq(colorType.parse(red), Color3.new(1, 0, 0))
		sert.eq(colorType.transform("  BLUE "), Color3.new(0, 0, 1))
		sert.eq(colorType.transform("white"), Color3.new(1, 1, 1))
		sert.eq(colorType.transform("black"), Color3.new(0, 0, 0))

		-- Random color
		local rnd = colorType.transform("random")
		sert.eq(rbxTypeof(rnd), "Color3")
		sert.eq((colorType.validate(rnd)), true)

		-- BrickColor name and number
		local bcName = colorType.transform("really red")
		sert.eq(rbxTypeof(bcName), "Color3")
		local bcNum = colorType.transform("3")
		sert.eq(rbxTypeof(bcNum), "Color3")

		-- Partial name match
		local partial = colorType.transform("magen")
		sert.eq(partial, Color3.new(1, 0, 0.5))

		-- Hex formats: #f, #fa, #0f0, #1234, #12345, #ff00aa
		sert.eq(colorType.transform("#000"), Color3.new(0, 0, 0))
		sert.eq(colorType.transform("#fff"), Color3.new(1, 1, 1))
		sert.eq(rbxTypeof(colorType.transform("#f")), "Color3")
		sert.eq(rbxTypeof(colorType.transform("#fa")), "Color3")
		sert.eq(rbxTypeof(colorType.transform("#1234")), "Color3")
		sert.eq(rbxTypeof(colorType.transform("#12345")), "Color3")
		sert.eq(colorType.transform("#ff0000"), Color3.fromRGB(255, 0, 0))

		-- Invalid hex
		sert.eq(colorType.transform("#1234567"), nil)
		sert.eq(colorType.transform("#gggggg"), nil)

		-- RGB format
		sert.eq(colorType.transform("10,20,30"), Color3.fromRGB(10, 20, 30))
		sert.eq(colorType.transform("0,0,0"), Color3.new(0, 0, 0))
		sert.eq(colorType.transform("255,255,255"), Color3.new(1, 1, 1))

		-- Out of range RGB & completely invalid color
		local badRgb, badRgbErr = colorType.transform("300,0,0")
		sert.eq(badRgb, nil)
		sert.eq(badRgbErr, "Invalid Color")

		local badColor, badColorErr = colorType.transform("not_a_color_xyz")
		sert.eq(badColor, nil)
		sert.eq(badColorErr, "Invalid Color")

		-- Suggestions for hex, random, RGB, and empty
		local sugEmpty, colorsMap = colorType.suggestions("")
		sert.eq(#sugEmpty > 10, true)
		sert.eq(type(colorsMap), "table")

		local sugShortHex = colorType.suggestions("#a")
		sert.eq(table.find(sugShortHex, "#aff") ~= nil, true)
		sert.eq(table.find(sugShortHex, "#afffff") ~= nil, true)

		local sugMidHex = colorType.suggestions("#abcd")
		sert.eq(table.find(sugMidHex, "#abcdff") ~= nil, true)

		local sugRandom = colorType.suggestions("ran")
		sert.eq(#sugRandom > 10, true)

		local sugRgb = colorType.suggestions("12,34,56")
		sert.eq(table.find(sugRgb, "12,34,56") ~= nil, true)
	end)

	local function colorEq(a: any, b: any): boolean
		return rbxTypeof(a) == "Color3"
			and rbxTypeof(b) == "Color3"
			and math.round(a.R * 255) == math.round(b.R * 255)
			and math.round(a.G * 255) == math.round(b.G * 255)
			and math.round(a.B * 255) == math.round(b.B * 255)
	end

	sert.laws.codec("color #RRGGBB hex roundtrip", {
		gen = function(g)
			return Color3.fromRGB(g:int(0, 255), g:int(0, 255), g:int(0, 255))
		end,
		encode = function(c: any): string
			return string.format("#%02x%02x%02x", math.round(c.R * 255), math.round(c.G * 255), math.round(c.B * 255))
		end,
		decode = function(hex: string): any
			local _K = getSharedK()
			local colorType = _K.Registry.types.color
			local transformed = colorType.transform(hex)
			sert.eq((colorType.validate(transformed)), true)
			return colorType.parse(transformed)
		end,
		eq = colorEq,
	}, { runs = 80 })

	sert.laws.codec("color r,g,b RGB roundtrip", {
		gen = function(g)
			return Color3.fromRGB(g:int(0, 255), g:int(0, 255), g:int(0, 255))
		end,
		encode = function(c: any): string
			return string.format("%d,%d,%d", math.round(c.R * 255), math.round(c.G * 255), math.round(c.B * 255))
		end,
		decode = function(rgb: string): any
			local _K = getSharedK()
			local colorType = _K.Registry.types.color
			local transformed = colorType.transform(rgb)
			sert.eq((colorType.validate(transformed)), true)
			return colorType.parse(transformed)
		end,
		eq = colorEq,
	}, { runs = 80 })

	sert.prop("color BrickColor name and palette number roundtrip", function(g)
		local _K = getSharedK()
		local colorType = _K.Registry.types.color
		local namesList, colorsMap = colorType.suggestions("")
		-- Index 1 is "random"; indices 2..#namesList are deterministic named and BrickColor palette entries
		local key = namesList[g:int(2, #namesList)]
		local expected = colorsMap[key]
		sert.eq(rbxTypeof(expected), "Color3")
		local transformed = colorType.transform(key)
		sert.eq((colorType.validate(transformed)), true)
		sert.eq(colorType.parse(transformed), expected)
	end, { runs = 40 })
end)

describe("DefaultTypes · Vector", function()
	test("vector2 and vector3 transform, validate, parse, and reject invalid sequences", function()
		local _K, Argument = getSharedK()
		local vec2 = _K.Registry.types.vector2
		local vec3 = _K.Registry.types.vector3

		-- Vector2 valid
		local t2 = vec2.transform("10, -25.5")
		sert.eq(t2, { 10, -25.5 })
		sert.eq((vec2.validate(t2)), true)
		sert.eq(vec2.parse(t2), Vector2.new(10, -25.5))

		-- Vector2 too many components
		local t2Many = vec2.transform("1,2,3")
		local ok2Many, err2Many = vec2.validate(t2Many)
		sert.eq(ok2Many, false)
		sert.eq(err2Many, "Maximum of 2 values allowed in sequence")

		-- Vector invalid number component (middle nil component in sequence)
		local t3Bad = vec3.transform("10,abc,30")
		local ok3Bad, err3Bad = vec3.validate(t3Bad)
		sert.eq(ok3Bad, false)
		sert.eq(string.find(tostring(err3Bad), "position 2", 1, true) ~= nil, true)

		-- Vector3 valid
		local t3 = vec3.transform("1,2,3")
		sert.eq(t3, { 1, 2, 3 })
		sert.eq((vec3.validate(t3)), true)
		sert.eq(vec3.parse(t3), Vector3.new(1, 2, 3))

		-- Vector3 too many components
		local t3Many = vec3.transform("1,2,3,4")
		local ok3Many, err3Many = vec3.validate(t3Many)
		sert.eq(ok3Many, false)
		sert.eq(err3Many, "Maximum of 3 values allowed in sequence")

		-- End-to-end via Argument:prepare()
		local cmd = makeCommandContext(_K, 1)
		local arg = Argument.new(cmd, { type = "vector3", name = "Offset" }, 1, "4,5,6")
		local okArg, valArg = arg:prepare()
		sert.eq(okArg, true)
		sert.eq(valArg, Vector3.new(4, 5, 6))
	end)

	sert.laws.codec("vector2 roundtrip", {
		gen = function(g)
			return Vector2.new(g:int(-4000, 4000) / 4, g:int(-4000, 4000) / 4)
		end,
		encode = function(v: any): string
			return string.format("%.2f,%.2f", v.X, v.Y)
		end,
		decode = function(s: string): any
			local _K = getSharedK()
			local vec2 = _K.Registry.types.vector2
			local t = vec2.transform(s)
			sert.eq((vec2.validate(t)), true)
			return vec2.parse(t)
		end,
	}, { runs = 60 })

	sert.laws.codec("vector3 roundtrip", {
		gen = function(g)
			return Vector3.new(g:int(-4000, 4000) / 4, g:int(-4000, 4000) / 4, g:int(-4000, 4000) / 4)
		end,
		encode = function(v: any): string
			return string.format("%.2f,%.2f,%.2f", v.X, v.Y, v.Z)
		end,
		decode = function(s: string): any
			local _K = getSharedK()
			local vec3 = _K.Registry.types.vector3
			local t = vec3.transform(s)
			sert.eq((vec3.validate(t)), true)
			return vec3.parse(t)
		end,
	}, { runs = 60 })
end)

describe("DefaultTypes · Ban", function()
	test("ban, bans, and allBans validate, parse, enforce permissions, and generate suggestions", function()
		local h, _K, Argument = newMountedK({ isStudio = false })
		local banType = _K.Registry.types.ban
		local bansType = _K.Registry.types.bans
		local allBansType = _K.Registry.types.allBans

		local creatorId = _K.Data.creatorId
		local modUser = h.env:addPlayer(20, "ModUser")
		local adminUser = h.env:addPlayer(30, "AdminUser")
		modUser:SetAttribute("_KRolesLoaded", true)
		adminUser:SetAttribute("_KRolesLoaded", true)
		_K.Auth.userRoleAdd(modUser.UserId, "mod")
		_K.Auth.userRoleAdd(adminUser.UserId, "admin")

		-- Seed session ban (timestamp = 0 or nil) and persistent ban (timestamp = -1) and nameless ban
		_K.Data.bans["501"] = { "BannedBob", "Griefing", 0, modUser.UserId }
		_K.Data.bans["502"] = { "SavedSally", "Exploiting", -1, creatorId }
		_K.Data.bans["503"] = { nil, "UnknownNameBan", 0, modUser.UserId }

		-- Mod can unban session ban by username prefix or userId
		local modSelf = makeArgSelf(_K, modUser.UserId, { type = "ban", name = "Ban" }, "bannedb")
		sert.eq(banType.validate("bannedb", modSelf), "501")
		sert.eq(banType.parse("501", modSelf), "501")

		-- Mod cannot unban saved/persistent ban (lacks banasync / admin)
		local okSavedMod, errSavedMod = banType.parse("savedsally", modSelf)
		sert.eq(okSavedMod, nil)
		sert.eq(errSavedMod, "No permission to unban saved bans")

		-- Mod cannot unban arbitrary unbanned userId (since not ban requires banasync/admin)
		local okUnbannedMod, errUnbannedMod = banType.parse("999", modSelf)
		sert.eq(okUnbannedMod, nil)
		sert.eq(errUnbannedMod, "No permission to unban saved bans")

		-- Admin (has banasync + restricted role) can unban saved ban and arbitrary numeric userId
		local adminSelf = makeArgSelf(_K, adminUser.UserId, { type = "ban", name = "Ban" }, "savedsally")
		sert.eq(banType.parse("savedsally", adminSelf), "502")
		sert.eq(banType.parse("999", adminSelf), "999")

		-- The admin permission counts as banasync, but saved bans still need a developer (restricted) role
		local superadmin = _K.Data.roles.superadmin.permissions
		superadmin.admin, superadmin.banasync = true, nil
		h.env:addPlayer(40, "BoughtSuperAdmin"):SetAttribute("_KRolesLoaded", true)
		h.env:addPlayer(41, "DevSuperAdmin"):SetAttribute("_KRolesLoaded", true)
		_K.Auth.userRoleAdd(40, "superadmin", false, true)
		_K.Auth.userRoleAdd(41, "superadmin")
		local boughtSelf = makeArgSelf(_K, 40, { type = "ban", name = "Ban" }, "savedsally")
		local okBought, errBought = banType.parse("savedsally", boughtSelf)
		sert.eq(okBought, nil)
		sert.eq(errBought, "No permission to unban saved bans")
		sert.eq(select(2, banType.parse("999", boughtSelf)), "No permission to unban saved bans")
		sert.eq(banType.parse("501", boughtSelf), "501")
		local devSelf = makeArgSelf(_K, 41, { type = "ban", name = "Ban" }, "savedsally")
		sert.eq(banType.parse("savedsally", devSelf), "502")
		superadmin.admin, superadmin.banasync = nil, true

		-- Invalid non-numeric, non-matching ban string
		local badBan, badBanErr = banType.parse("nonexistent_user", adminSelf)
		sert.eq(badBan, nil)
		sert.eq(badBanErr, "Invalid ban.")

		-- UserIds past 2^53 aren't real users, so they can't key a saved ban
		for _, input in { "1e300", "9007199254740994" } do
			local okHuge, errHuge = banType.parse(input, adminSelf)
			sert.eq(okHuge, nil)
			sert.eq(errHuge, "Invalid ban.")
		end
		sert.eq(banType.parse("9007199254740992", adminSelf), "9007199254740992")
		-- but a junk key saved before this check still matches by key, so it can be unbanned
		_K.Data.bans["1e+300"] = { nil, "junk", 0, 10 }
		sert.eq(banType.parse("1e+300", adminSelf), "1e+300")
		_K.Data.bans["1e+300"] = nil

		-- Suggestions include *, named bans, and UNKNOWN for nameless bans
		local suggestions = banType.suggestions("")
		sert.eq(suggestions[1][2], "*  [all] (Everyone)")
		sert.eq(#suggestions, 4)
		local foundNamed, foundUnknown = false, false
		for i = 2, #suggestions do
			if type(suggestions[i][1]) == "table" and suggestions[i][1][1] == "BannedBob" then
				foundNamed = true
			elseif suggestions[i][1] == "503" and suggestions[i][2] == "UNKNOWN [503]" then
				foundUnknown = true
			end
		end
		sert.eq(foundNamed, true)
		sert.eq(foundUnknown, true)

		-- allBans parses all unbannable users for caller
		sert.eq(allBansType.transform("ALL"), "all")
		local allForMod = allBansType.parse("all", modSelf)
		sert.eq(type(allForMod), "table")
		sert.eq(table.find(allForMod, "501") ~= nil, true)
		sert.eq(table.find(allForMod, "502"), nil)

		local allForAdmin = allBansType.parse("all", adminSelf)
		sert.eq(#allForAdmin, 3)

		-- bans listable with prefix "*" via Argument:prepare()
		sert.eq(bansType.listable, true)
		local cmd = makeCommandContext(_K, adminUser.UserId)
		local argAll = Argument.new(cmd, { type = "bans", name = "Bans" }, 1, "*")
		local okAll, parsedAll = argAll:prepare()
		sert.eq(okAll, true)
		sert.eq(#parsedAll, 3)

		-- allBans when only saved bans exist and caller is Mod -> deduplicated error feedback
		table.clear(_K.Data.bans)
		_K.Data.bans["502"] = { "SavedSally", "Exploiting", -1, creatorId }
		_K.Data.bans["504"] = { "SavedSam", "Exploiting", -1, creatorId }
		local savedOnlyAll, savedOnlyErr = allBansType.validate("all", modSelf)
		sert.eq(savedOnlyAll, nil)
		sert.eq(savedOnlyErr, "No permission to unban saved bans")

		-- Empty bans table returns "No targetable user found" on allBans
		table.clear(_K.Data.bans)
		local emptyAll, emptyErr = allBansType.validate("all", adminSelf)
		sert.eq(emptyAll, nil)
		sert.eq(emptyErr, "No targetable user found")

		-- Non-numeric ban key returns "Invalid ban."
		_K.Data.bans["bad_key"] = { "BadKeyUser", "reason", 0, modUser.UserId }
		local badKeyVal, badKeyErr = banType.parse("badkeyuser", adminSelf)
		sert.eq(badKeyVal, nil)
		sert.eq(badKeyErr, "Invalid ban.")
	end)
end)

describe("DefaultTypes · Member", function()
	test("member, members, and allMembers validate, parse, and generate rank-filtered suggestions", function()
		local h, _K, Argument = newMountedK({ isStudio = false })
		local memberType = _K.Registry.types.member
		local membersType = _K.Registry.types.members
		local allMembersType = _K.Registry.types.allMembers

		local vipPlr = h.env:addPlayer(10, "AliceVip")
		local modPlr = h.env:addPlayer(20, "BobMod")
		local adminPlr = h.env:addPlayer(30, "CharlieAdmin")
		vipPlr:SetAttribute("_KRolesLoaded", true)
		modPlr:SetAttribute("_KRolesLoaded", true)
		adminPlr:SetAttribute("_KRolesLoaded", true)

		table.clear(_K.Data.members)
		_K.Data.members["10"] = { name = "AliceVip", roles = { "vip" }, persist = {} }
		_K.Data.members["20"] = { name = "BobMod", roles = { "mod" }, persist = {} }
		_K.Data.members["30"] = { name = "CharlieAdmin", roles = { "admin" }, persist = {} }

		local adminSelf = makeArgSelf(_K, 30, { type = "member", name = "Member" }, "")

		-- Self ("", "me")
		sert.eq(memberType.parse("", adminSelf), "30")
		sert.eq(memberType.parse("me", adminSelf), "30")

		-- Exact ID, exact name, partial name
		sert.eq(memberType.parse("10", adminSelf), "10")
		sert.eq(memberType.parse("bobmod", adminSelf), "20")
		sert.eq(memberType.parse("alice", adminSelf), "10")

		-- Invalid member
		local badVal, badErr = memberType.parse("unknown_member", adminSelf)
		sert.eq(badVal, nil)
		sert.eq(badErr, "Invalid member")

		-- Suggestions include "me", "*", and rank-filtered members sorted alphabetically
		local modSuggestions = memberType.suggestions("", 20, { lowerRank = true })
		sert.eq(modSuggestions[1][1][1], "me")
		local adminSuggestions = memberType.suggestions("", 30, { lowerRank = true })
		sert.eq(adminSuggestions[1][1][1], "me")
		sert.eq(adminSuggestions[2][1][1], "*")
		sert.eq(adminSuggestions[3][1][1], "AliceVip")
		sert.eq(adminSuggestions[4][1][1], "BobMod")
		local reqSuggestions = memberType.suggestions("", 20, { shouldRequest = true })
		sert.eq(#reqSuggestions >= 2, true)
		local foundAlice, foundCharlie = false, false
		for _, item in modSuggestions do
			if type(item[1]) ~= "table" then
				continue
			end
			if item[1][1] == "AliceVip" then
				foundAlice = true
			elseif item[1][1] == "CharlieAdmin" then
				foundCharlie = true
			end
		end
		sert.eq(foundAlice, true)
		sert.eq(foundCharlie, false)

		-- allMembers and members listable via Argument:prepare()
		sert.eq(membersType.listable, true)
		sert.eq(allMembersType.transform("ALL"), "all")
		local allParsed = allMembersType.parse("all", adminSelf)
		sert.eq(#allParsed, 3)

		local cmd = makeCommandContext(_K, 30)
		local argList = Argument.new(cmd, { type = "members", name = "Members" }, 1, "alice,20")
		local okList, parsedList = argList:prepare()
		sert.eq(okList, true)
		sert.eq(parsedList, { "10", "20" })

		local argStar = Argument.new(cmd, { type = "members", name = "Members" }, 1, "*")
		local okStar, parsedStar = argStar:prepare()
		sert.eq(okStar, true)
		sert.eq(#parsedStar, 3)

		-- allMembers when caller cannot target any member (VIP with ignoreSelf = true, lowerRank = true)
		local vipNoTargetSelf =
			makeArgSelf(_K, 10, { type = "member", name = "Member", ignoreSelf = true, lowerRank = true }, "all")
		local noAllVal, noAllErr = allMembersType.validate("all", vipNoTargetSelf)
		sert.eq(noAllVal, nil)
		sert.eq(noAllErr, "Can only target yourself\nCan only target 1 user")
	end)
end)

describe("DefaultTypes · Role", function()
	test("role and roles enforce caller rank hierarchy and generate sorted suggestions", function()
		local h, _K, Argument = newMountedK({ isStudio = false })
		local roleType = _K.Registry.types.role
		local rolesType = _K.Registry.types.roles

		local modPlr = h.env:addPlayer(20, "ModUser")
		local adminPlr = h.env:addPlayer(30, "AdminUser")
		_K.Auth.userRoleAdd(modPlr.UserId, "mod")
		_K.Auth.userRoleAdd(adminPlr.UserId, "admin")

		-- Mod (rank 2) can parse "vip" (rank 1), cannot parse "mod" (rank 2), "admin" (rank 3), or "everyone"
		local modSelf = makeArgSelf(_K, 20, { type = "role", name = "Role" }, "vip")
		sert.eq(roleType.validate("vip", modSelf), "vip")
		sert.eq(roleType.parse("v", modSelf), "vip")

		local okSelfRole, errSelfRole = roleType.parse("mod", modSelf)
		sert.eq(okSelfRole, nil)
		sert.eq(errSelfRole, "Invalid role")

		local okHigherRole = roleType.parse("admin", modSelf)
		sert.eq(okHigherRole, nil)

		local okEveryone = roleType.parse("everyone", modSelf)
		sert.eq(okEveryone, nil)

		-- Creator can parse any non-everyone role
		local creatorSelf = makeArgSelf(_K, _K.creatorId, { type = "role", name = "Role" }, "superadmin")
		sert.eq(roleType.parse("super", creatorSelf), "superadmin")

		-- Suggestions for Admin (rank 3) include mod (rank 2) and vip (rank 1) sorted descending by rank
		local adminSug, rolesTable = roleType.suggestions("", 30)
		sert.eq(rolesTable, _K.Data.roles)
		sert.eq(#adminSug, 2)
		sert.eq(adminSug[1][1], "mod")
		sert.eq(adminSug[2][1], "vip")

		-- Listable roles via Argument:prepare()
		sert.eq(rolesType.listable, true)
		local cmd = makeCommandContext(_K, 30)
		local arg = Argument.new(cmd, { type = "roles", name = "Roles" }, 1, "vip,mod")
		local ok, parsed = arg:prepare()
		sert.eq(ok, true)
		sert.eq(parsed, { "vip", "mod" })
	end)
end)

describe("DefaultTypes · Team", function()
	test("team and teams handle empty teams, match prefixes, parse Team instances, and suggest", function()
		local h, _K, Argument = newMountedK()
		local teamType = _K.Registry.types.team
		local teamsType = _K.Registry.types.teams

		-- When no teams exist
		local okNoTeams, errNoTeams = teamType.validate("Red", 1)
		sert.eq(okNoTeams, false)
		sert.eq(errNoTeams, "No teams available")

		-- Seed Red and Blue teams
		local redTeam = h.env.Instance.new("Team", _K.Service.Teams)
		redTeam.Name = "Red"
		local blueTeam = h.env.Instance.new("Team", _K.Service.Teams)
		blueTeam.Name = "Blue"

		sert.eq((teamType.validate("r", 1)), true)
		sert.eq((teamType.validate("blue", 1)), true)
		local okInvalid, errInvalid = teamType.validate("Green", 1)
		sert.eq(okInvalid, false)
		sert.eq(errInvalid, "Invalid team")

		sert.eq(teamType.parse("red", 1), redTeam)
		sert.eq(teamType.parse("bl", 1), blueTeam)
		sert.throws(function()
			teamType.parse("Green", 1)
		end)

		local sugNames, sugInstances = teamType.suggestions("", 1)
		sert.eq(#sugNames, 2)
		sert.eq(#sugInstances, 2)

		-- Listable teams via Argument:prepare()
		sert.eq(teamsType.listable, true)
		local cmd = makeCommandContext(_K, 1)
		local arg = Argument.new(cmd, { type = "teams", name = "Teams" }, 1, "red,blue")
		local ok, parsed = arg:prepare()
		sert.eq(ok, true)
		sert.eq(parsed, { redTeam, blueTeam })
	end)
end)

describe("DefaultTypes · Tool", function()
	test("tool, tools, and allTools discover tools across containers, ignore _K_Ignore, and parse", function()
		local h, _K, Argument = newMountedK()
		local toolType = _K.Registry.types.tool
		local toolsType = _K.Registry.types.tools
		local allToolsType = _K.Registry.types.allTools

		-- Add tools dynamically via DescendantAdded on Lighting and StarterPack
		local sword = h.env.Instance.new("Tool")
		sword.Name = "Sword"
		sword.Parent = _K.Service.Lighting

		local swordBow = h.env.Instance.new("Tool")
		swordBow.Name = "SwordBow"
		swordBow.Parent = _K.Service.StarterPack

		-- Duplicate name should be ignored
		local dupSword = h.env.Instance.new("Tool")
		dupSword.Name = "Sword"
		dupSword.Parent = _K.Service.ServerStorage

		-- Tool with _K_Ignore tag should be ignored
		local ignoredTool = h.env.Instance.new("Tool")
		ignoredTool.Name = "SecretWand"
		ignoredTool:AddTag("_K_Ignore")
		ignoredTool.Parent = _K.Service.Lighting

		h.env:step(0.25)

		-- Validate and parse exact vs partial prefix
		sert.eq((toolType.validate("sw", 1)), true)
		sert.eq((toolType.validate("secret", 1)), false)
		sert.eq(toolType.parse("sword", 1), sword)
		sert.eq(toolType.parse("swordb", 1), swordBow)
		sert.throws(function()
			toolType.parse("nonexistent_tool", 1)
		end)

		-- Suggestions
		local sugNames = toolType.suggestions("", 1)
		sert.eq(table.find(sugNames, "Sword") ~= nil, true)
		sert.eq(table.find(sugNames, "SwordBow") ~= nil, true)
		sert.eq(table.find(sugNames, "SecretWand"), nil)

		-- allTools
		sert.eq(allToolsType.transform("ALL"), "all")
		local allParsed = allToolsType.parse()
		sert.eq(type(allParsed), "table")
		sert.eq(table.find(allParsed, sword) ~= nil, true)
		sert.eq(table.find(allParsed, swordBow) ~= nil, true)

		-- tools listable with "all" prefix and individual names via Argument:prepare()
		sert.eq(toolsType.listable, true)
		local cmd = makeCommandContext(_K, 1)
		local argAll = Argument.new(cmd, { type = "tools", name = "Tools" }, 1, "all")
		local okAll, parsedAll = argAll:prepare()
		sert.eq(okAll, true)
		sert.eq(table.find(parsedAll, sword) ~= nil, true)
		sert.eq(table.find(parsedAll, swordBow) ~= nil, true)

		local argSingleAll = Argument.new(cmd, { type = "tool", name = "Tool" }, 1, "all")
		local okSingleAll, parsedSingleAll = argSingleAll:prepare()
		sert.eq(okSingleAll, true)
		sert.eq(parsedSingleAll ~= nil, true)
	end)
end)

describe("DefaultTypes · Command", function()
	test(
		"command transforms exact, prefix, and alias matches respecting LocalPlayerAuthorized and suggestions",
		function()
			local h, _K = newMountedK()
			local cmdType = _K.Registry.types.command

			_K.Registry.registerCommand(_K, {
				name = "customfly",
				aliases = { "cfly" },
				description = "Custom fly command",
				group = "general",
				LocalPlayerAuthorized = true,
				args = {},
				run = function() end,
			})
			_K.Registry.registerCommand(_K, {
				name = "secretcmd",
				aliases = { "scmd" },
				description = "Unauthorized command",
				group = "superadmin",
				LocalPlayerAuthorized = false,
				args = {},
				run = function() end,
			})
			h.env:step(0.25)

			-- Exact match & alias match when LocalPlayerAuthorized = true
			local exact = cmdType.transform("customfly")
			sert.eq(exact ~= nil, true)
			sert.eq(exact.name, "customfly")
			sert.eq((cmdType.validate(exact)), true)
			sert.eq(cmdType.parse(exact), exact)

			local byAlias = cmdType.transform("cfly")
			sert.eq(byAlias, exact)

			-- Substring match on command key and alias
			sert.eq(cmdType.transform("ustomf"), exact)
			sert.eq(cmdType.transform("fl"), exact)

			-- Unauthorized command is not returned
			local unauth = cmdType.transform("secretcmd")
			sert.eq(unauth, nil)
			local okUnauth, errUnauth = cmdType.validate(unauth)
			sert.eq(okUnauth, false)
			sert.eq(errUnauth, "No command with that name could be found.")

			-- Suggestions with onlyShowUsableCommands = true vs false
			_K.client = {
				settings = {
					onlyShowUsableCommands = _K.Flux.signal(true),
				},
			}
			local filteredNames = cmdType.suggestions("")
			sert.eq(table.find(filteredNames, "customfly") ~= nil, true)
			sert.eq(table.find(filteredNames, "secretcmd"), nil)

			_K.client.settings.onlyShowUsableCommands:set(false)
			local allNames = cmdType.suggestions("")
			sert.eq(table.find(allNames, "secretcmd") ~= nil, true)
		end
	)
end)

describe("DefaultTypes · ReservedServer", function()
	test("reservedServer and reservedServers validate, parse exact/case-insensitive/partial, and suggest", function()
		local _, _K, Argument = newMountedK()
		local rsType = _K.Registry.types.reservedServer
		local rssType = _K.Registry.types.reservedServers

		local dataAlpha = { code = "access-alpha", creator = 1 }
		local dataBeta = { code = "access-beta", creator = 1 }
		_K.Data.reservedServers["AlphaLobby"] = dataAlpha
		_K.Data.reservedServers["BetaArena"] = dataBeta

		-- Exact, case-insensitive, and substring match
		sert.eq(rsType.validate("AlphaLobby"), dataAlpha)
		sert.eq(rsType.parse("alphalobby"), dataAlpha)
		sert.eq(rsType.parse("arena"), dataBeta)

		-- Invalid code
		local badVal, badErr = rsType.validate("NonExistentServer")
		sert.eq(badVal, nil)
		sert.eq(badErr, "Invalid reserveCode")

		-- Suggestions sorted alphabetically
		local suggestions = rsType.suggestions("", 1)
		sert.eq(suggestions, { "AlphaLobby", "BetaArena" })

		-- Listable reservedServers via Argument:prepare()
		sert.eq(rssType.listable, true)
		local cmd = makeCommandContext(_K, 1)
		local arg = Argument.new(cmd, { type = "reservedServers", name = "Servers" }, 1, "alpha,beta")
		local ok, parsed = arg:prepare()
		sert.eq(ok, true)
		sert.eq(parsed, { dataAlpha, dataBeta })
	end)
end)

describe("DefaultTypes · Image & Emote", function()
	test("image and images transform, validate whole numbers, resolve textures, and handle optional/errors", function()
		local h, _K, Argument = newMountedK()
		local imgType = _K.Registry.types.image
		local imgsType = _K.Registry.types.images

		sert.eq(imgType.filterLog, true)
		sert.eq(imgType.transform(""), 0)
		sert.eq(imgType.transform("12345"), 12345)
		sert.eq(imgType.transform("abc"), nil)

		sert.eq((imgType.validate(12345)), true)
		sert.eq((imgType.validate(12.5)), false)
		sert.eq((imgType.validate(nil)), false)

		-- Seed an Image product in MarketplaceService
		h.env.marketplace.products[777] = {
			AssetId = 777,
			Name = "TestImage",
			AssetTypeId = Enum.AssetType.Image.Value,
			IsForSale = true,
		}
		local selfArg = makeArgSelf(_K, 1, { type = "image", name = "Img" }, "777")
		sert.eq(imgType.parse(777, selfArg), "rbxassetid://777")

		-- Non-Image asset falls back to rbxthumb
		local thumbTex = imgType.parse(888, selfArg)
		sert.eq(string.find(thumbTex, "rbxthumb://type=Asset&id=888", 1, true) ~= nil, true)

		-- Optional empty rawArg when getTexture fails
		local mktMethods = rawget(_K.Service.Marketplace, "_methods")
		local origGetInfo = mktMethods.GetProductInfoAsync
		mktMethods.GetProductInfoAsync = function()
			error("network error")
		end
		local optSelf = makeArgSelf(_K, 1, { type = "image", name = "Img", optional = true }, "")
		sert.eq(imgType.parse(0, optSelf), "")

		local reqSelf = makeArgSelf(_K, 1, { type = "image", name = "Img", optional = false }, "999999")
		local failVal, failErr = imgType.parse(999999, reqSelf)
		sert.eq(failVal, nil)
		sert.eq(failErr, "Failed to load image")

		-- Client fallback placeholder
		_K.IsClient = true
		sert.eq(imgType.parse(999999, reqSelf), "rbxasset://textures/ui/GuiImagePlaceholder.png")
		_K.IsClient = false
		mktMethods.GetProductInfoAsync = origGetInfo

		-- Suggestions
		sert.eq(imgType.suggestions("12345"), { "12345" })
		sert.eq(imgType.suggestions("notnum"), {})

		-- Listable images
		sert.eq(imgsType.listable, true)
		local cmd = makeCommandContext(_K, 1)
		local arg = Argument.new(cmd, { type = "images", name = "Images" }, 1, "777,888")
		local ok, parsed = arg:prepare()
		sert.eq(ok, true)
		sert.eq(#parsed, 2)
	end)

	test("emote and emotes transform, validate, parse numeric ID and catalog name, and suggest", function()
		local h, _K = newMountedK()
		local emoteType = _K.Registry.types.emote
		local emotesType = _K.Registry.types.emotes

		sert.eq(emoteType.filterLog, true)
		sert.eq(emotesType.listable, true)

		-- Transform and validate
		sert.eq(emoteType.transform("12345"), 12345)
		sert.eq(emoteType.transform("salute"), "salute")
		sert.eq((emoteType.validate(12345)), true)
		sert.eq((emoteType.validate("salute")), true)
		local okFloat, errFloat = emoteType.validate(12.34)
		sert.eq(okFloat, false)
		sert.eq(errFloat, "Only whole numbers are valid")
		sert.eq((emoteType.validate(nil)), false)

		-- Seed catalog emotes in _K.Data.emotes
		table.insert(_K.Data.emotes, {
			name = "Salute",
			nameLower = "salute",
			emoteId = 1001,
			animationId = 5001,
		})
		table.insert(_K.Data.emotes, {
			name = "StadiumWave",
			nameLower = "stadiumwave",
			emoteId = 1002,
			animationId = 5002,
		})

		local selfArg = makeArgSelf(_K, 1, { type = "emote", name = "Emote" }, "salute")
		-- Exact and partial prefix name lookup (first prefix match wins; non-prefix substring fails)
		sert.eq(emoteType.parse("salute", selfArg), 5001)
		sert.eq(emoteType.parse("stad", selfArg), 5002)
		sert.eq(emoteType.parse("s", selfArg), 5001)
		sert.eq(emoteType.parse("wave", selfArg), nil)

		-- Numeric emote ID via MarketplaceService + InsertService:LoadAsset
		h.env.marketplace.products[1] = {
			AssetId = 1,
			Name = "FirstEmote",
			AssetTypeId = Enum.AssetType.EmoteAnimation.Value,
			IsForSale = true,
		}
		h.env.marketplace.products[2001] = {
			AssetId = 2001,
			Name = "DanceEmote",
			AssetTypeId = Enum.AssetType.EmoteAnimation.Value,
			IsForSale = true,
		}
		h.env.marketplace.products[2002] = {
			AssetId = 2002,
			Name = "OffsaleEmote",
			AssetTypeId = Enum.AssetType.EmoteAnimation.Value,
			IsForSale = false,
		}
		h.env.marketplace.products[2003] = {
			AssetId = 2003,
			Name = "LimitedEmote",
			AssetTypeId = Enum.AssetType.EmoteAnimation.Value,
			IsForSale = true,
			IsLimited = true,
		}
		h.env.marketplace.products[2004] = {
			AssetId = 2004,
			Name = "LimitedUniqueEmote",
			AssetTypeId = Enum.AssetType.EmoteAnimation.Value,
			IsForSale = true,
			IsLimitedUnique = true,
		}
		local firedEmoteBroadcasts = 0
		local origFireAll = _K.Util.Remote.EmoteType.FireAll
		_K.Util.Remote.EmoteType.FireAll = function(selfRemote: any, items: any)
			if type(items) == "table" and items[1] and items[1].emoteId then
				firedEmoteBroadcasts += 1
			end
			return origFireAll(selfRemote, items)
		end
		local insertMethods = rawget(_K.Service.Insert, "_methods")
		local origLoadAsset = insertMethods.LoadAsset
		insertMethods.LoadAsset = function(_self: any, id: number)
			local model = h.env.Instance.new("Model")
			local anim = h.env.Instance.new("Animation", model)
			anim.AnimationId = `rbxassetid://{7000 + id}`
			return model
		end
		sert.eq(emoteType.parse(1, selfArg), 7001)
		sert.eq(emoteType.parse(0, selfArg), nil)
		sert.eq(emoteType.parse(1.5, selfArg), nil)
		sert.eq(emoteType.parse(2001, selfArg), 9001)
		sert.eq(firedEmoteBroadcasts, 2)
		sert.eq(_K.Data.emoteItemFromId[2001] ~= nil, true)
		sert.eq(_K.Data.emoteItemFromId[2001].animationId, 9001)
		sert.eq(_K.Data.animationToEmoteId[9001], 2001)
		sert.eq(_K.Data.emoteToAnimationId[2001], 9001)
		sert.eq(_K.VIP.allowedBulkPurchaseIds[2001], true)
		sert.eq(emoteType.parse("danceemote", selfArg), 9001)
		-- Second call hits emoteToAnimationId cache without broadcasting again
		sert.eq(emoteType.parse(2001, selfArg), 9001)
		sert.eq(firedEmoteBroadcasts, 2)
		-- Offsale, Limited, and LimitedUnique emotes are not added to allowedBulkPurchaseIds
		sert.eq(emoteType.parse(2002, selfArg), 9002)
		sert.eq(_K.VIP.allowedBulkPurchaseIds[2002], nil)
		sert.eq(emoteType.parse(2003, selfArg), 9003)
		sert.eq(_K.VIP.allowedBulkPurchaseIds[2003], nil)
		sert.eq(emoteType.parse(2004, selfArg), 9004)
		sert.eq(_K.VIP.allowedBulkPurchaseIds[2004], nil)
		insertMethods.LoadAsset = origLoadAsset
		_K.Util.Remote.EmoteType.FireAll = origFireAll

		-- Optional empty emote (when v does not match any emote and rawArg is "")
		local optSelf = makeArgSelf(_K, 1, { type = "emote", name = "Emote", optional = true }, "")
		sert.eq(emoteType.parse(0, optSelf), "")
		local optNonEmpty = makeArgSelf(_K, 1, { type = "emote", name = "Emote", optional = true }, "nonexistent")
		sert.eq(emoteType.parse(0, optNonEmpty), nil)
		local reqEmpty = makeArgSelf(_K, 1, { type = "emote", name = "Emote", optional = false }, "")
		sert.eq(emoteType.parse(0, reqEmpty), nil)

		-- Invalid emote (both unknown string and non-emote numeric ID, plus negative cache)
		local badNumVal, badNumErr = emoteType.parse(999999, selfArg)
		sert.eq(badNumVal, nil)
		sert.eq(badNumErr, "Could not parse emote")
		sert.eq(_K.Data.emoteItemFromId[999999], false)
		h.env.marketplace.products[999999] = {
			AssetId = 999999,
			Name = "LateAddedEmote",
			AssetTypeId = Enum.AssetType.EmoteAnimation.Value,
			IsForSale = true,
		}
		sert.eq(emoteType.parse(999999, selfArg), nil)
		local badVal, badErr = emoteType.parse("unknown_emote_xyz", selfArg)
		sert.eq(badVal, nil)
		sert.eq(badErr, "Could not parse emote")

		-- Suggestions (numeric and non-numeric query)
		local sugNum = emoteType.suggestions("2001")
		sert.eq(sugNum[1], "2001")
		sert.eq(table.find(sugNum, "Salute") ~= nil, true)
		sert.eq(table.find(sugNum, "DanceEmote") ~= nil, true)
		local sugText = emoteType.suggestions("salute")
		sert.eq(sugText[1], "Salute")
	end)

	test(
		"server Emote registers Remote synchronously, queues pre-load clients, flushes on load or error, cleans PlayerRemoving, and prevents duplicate catalog pushes",
		function()
			local h = Harness.newEnv({ isStudio = false })
			local plrA = h.env:addPlayer(101, "EarlyJoiner")
			local plrB = h.env:addPlayer(102, "LeavingJoiner")
			local plrC = h.env:addPlayer(103, "LateJoiner")

			local avatarEditor = h.env.game:GetService("AvatarEditorService")
			local avatarMethods = rawget(avatarEditor, "_methods") or {}
			local catalogReady = false
			local failCatalog = false
			avatarMethods.SearchCatalogAsync = function()
				while not catalogReady do
					h.env.task.wait(0.05)
				end
				if failCatalog then
					error("Catalog service unavailable")
				end
				return {
					GetCurrentPage = function()
						return {
							{ Id = 3301, Name = "CatalogWave", IsPurchasable = true },
							{ Id = 3302, Name = "CatalogCheer", IsPurchasable = false },
						}
					end,
					IsFinished = true,
					AdvanceToNextPageAsync = function() end,
				}
			end
			rawset(avatarEditor, "_methods", avatarMethods)

			h.env.marketplace.products[3301] = {
				AssetId = 3301,
				Name = "CatalogWave",
				AssetTypeId = Enum.AssetType.EmoteAnimation.Value,
				IsForSale = true,
			}
			h.env.marketplace.products[3302] = {
				AssetId = 3302,
				Name = "CatalogCheer",
				AssetTypeId = Enum.AssetType.EmoteAnimation.Value,
				IsForSale = false,
			}
			local insertMethods = rawget(h.env.game:GetService("InsertService"), "_methods") or {}
			insertMethods.LoadAsset = function(_self: any, id: number)
				local model = h.env.Instance.new("Model")
				local anim = h.env.Instance.new("Animation", model)
				anim.AnimationId = `rbxassetid://{8000 + id}`
				return model
			end
			rawset(h.env.game:GetService("InsertService"), "_methods", insertMethods)

			h:requireData()
			local _K = h:requireK()

			local sentPayloads: { [any]: { any } } = {}
			local remote = _K.Remote.EmoteType
			local origFire = remote.Fire
			remote.Fire = function(selfRemote: any, targetPlr: any, payload: any)
				sentPayloads[targetPlr] = sentPayloads[targetPlr] or {}
				table.insert(sentPayloads[targetPlr], payload)
				return origFire(selfRemote, targetPlr, payload)
			end

			-- Fire server signal before catalog load finishes
			sert.eq(remote._signal ~= nil, true)
			remote._signal:Fire(plrA)
			remote._signal:Fire(plrB)
			-- LeavingJoiner disconnects before catalog finishes
			_K.Service.Players.PlayerRemoving:Fire(plrB)
			h.env:step(0.05)
			sert.eq(sentPayloads[plrA], nil)
			sert.eq(sentPayloads[plrB], nil)

			-- Release catalog load; EarlyJoiner receives flushed emotes, LeavingJoiner does not
			catalogReady = true
			h.env:step(0.5)
			sert.eq(sentPayloads[plrA] ~= nil and #sentPayloads[plrA] == 1, true)
			sert.eq(#sentPayloads[plrA][1], 2)
			sert.eq(sentPayloads[plrB], nil)

			-- Duplicate Remote fire from EarlyJoiner is ignored; LateJoiner receives immediately
			remote._signal:Fire(plrA)
			remote._signal:Fire(plrC)
			sert.eq(#sentPayloads[plrA], 1)
			sert.eq(sentPayloads[plrC] ~= nil and #sentPayloads[plrC] == 1, true)

			-- Re-initializing Emote module does not push duplicate items into _K.Data.emotes
			local countBefore = #_K.Data.emotes
			local emoteModule = h.env:require(h.Shared:WaitForChild("DefaultTypes"):WaitForChild("Emote"))
			emoteModule(_K)
			h.env:step(0.5)
			sert.eq(#_K.Data.emotes, countBefore)

			-- Even when catalog search errors completely, pre-load pending clients still flush cleanly
			local hErr = Harness.newEnv({ isStudio = false })
			local plrErr = hErr.env:addPlayer(201, "ErrorJoiner")
			local errAvatar = hErr.env.game:GetService("AvatarEditorService")
			local errReady = false
			rawset(errAvatar, "_methods", {
				SearchCatalogAsync = function()
					while not errReady do
						hErr.env.task.wait(0.05)
					end
					error("Catalog outage")
				end,
			})
			hErr:requireData()
			local errK = hErr:requireK()
			local flushedOnError = 0
			local origErrFire = errK.Remote.EmoteType.Fire
			errK.Remote.EmoteType.Fire = function(selfRemote: any, targetPlr: any, payload: any)
				if targetPlr == plrErr then
					flushedOnError += 1
				end
				return origErrFire(selfRemote, targetPlr, payload)
			end
			errK.Remote.EmoteType._signal:Fire(plrErr)
			sert.eq(flushedOnError, 0)
			errReady = true
			for _ = 1, 10 do
				hErr.env:step(20)
			end
			sert.eq(flushedOnError, 1)
		end
	)
end)

describe("DefaultTypes · Player, UserId & Prefix Matchers", function()
	test(
		"player, players, userId, and userIds match self, username, DisplayName, _KDisplayName, and userCache",
		function()
			local h, _K, Argument = newMountedK({ isStudio = false })
			local playerType = _K.Registry.types.player
			local playersType = _K.Registry.types.players
			local userIdType = _K.Registry.types.userId
			local userIdsType = _K.Registry.types.userIds

			local adminPlr = h.env:addPlayer(10, "AdminAlpha")
			local modPlr = h.env:addPlayer(20, "ModBravo")
			local vipPlr = h.env:addPlayer(30, "VipCharlie")
			modPlr.DisplayName = "SuperBravo"
			vipPlr:SetAttribute("_KDisplayName", "NickCharlie")

			attachPlayerHelpers(h.env, adminPlr)
			attachPlayerHelpers(h.env, modPlr)
			attachPlayerHelpers(h.env, vipPlr)
			h.env.Players._props.LocalPlayer = adminPlr

			_K.Auth.userRoleAdd(10, "admin")
			_K.Auth.userRoleAdd(20, "mod")
			_K.Auth.userRoleAdd(30, "vip")

			local adminSelf = makeArgSelf(_K, 10, { type = "player", name = "Target" }, "")

			-- Self matching ("", "me")
			sert.eq(playerType.parse("", adminSelf), adminPlr)
			sert.eq(playerType.parse("me", adminSelf), adminPlr)

			-- Exact and partial username matching
			sert.eq(playerType.parse("modbravo", adminSelf), modPlr)
			sert.eq(playerType.parse("modb", adminSelf), modPlr)

			-- Exact and partial DisplayName matching
			sert.eq(playerType.parse("superbravo", adminSelf), modPlr)
			sert.eq(playerType.parse("superb", adminSelf), modPlr)

			-- Exact and partial _KDisplayName attribute matching
			sert.eq(playerType.parse("nickcharlie", adminSelf), vipPlr)
			sert.eq(playerType.parse("nickc", adminSelf), vipPlr)

			-- Invalid player
			local badPlr, badPlrErr = playerType.validate("no_such_player", adminSelf)
			sert.eq(badPlr, nil)
			sert.eq(badPlrErr, "Invalid player")

			-- lowerRank check: Mod (20) cannot target Admin (10) when lowerRank = true and commandRequests = false
			_K.Data.settings.commandRequests = false
			local modSelf = makeArgSelf(_K, 20, { type = "player", name = "Target", lowerRank = true }, "adminalpha")
			local lowVal, lowErr = playerType.parse("adminalpha", modSelf)
			sert.eq(lowVal, nil)
			sert.eq(lowErr, "Can only target lower ranks")
			sert.eq(playerType.parse("vipcharlie", modSelf), vipPlr)
			_K.Data.settings.commandRequests = true

			-- Suggestions for player and userId (including LocalPlayer sorting, DisplayName, _KDisplayName, and ignoreSelf)
			h.env.Players._props.LocalPlayer = modPlr
			local plrSuggestions = playerType.suggestions("", 20, { lowerRank = false })
			sert.eq(#plrSuggestions > 3, true)
			sert.eq(plrSuggestions[1][1], { "me", "ModBravo", "SuperBravo" })
			sert.eq(plrSuggestions[1][3], modPlr)
			sert.eq(plrSuggestions[2][1], { "AdminAlpha" })
			sert.eq(plrSuggestions[2][3], adminPlr)
			sert.eq(plrSuggestions[3][1], { "VipCharlie", "NickCharlie" })
			sert.eq(plrSuggestions[3][3], vipPlr)

			-- When _KDisplayName equals Name, it is not duplicated in suggestions
			adminPlr:SetAttribute("_KDisplayName", "AdminAlpha")
			local noSelfSuggestions = playerType.suggestions("", 20, { lowerRank = false, ignoreSelf = true })
			sert.eq(noSelfSuggestions[1][1], { "AdminAlpha" })
			sert.eq(noSelfSuggestions[1][3], adminPlr)
			adminPlr:SetAttribute("_KDisplayName", nil)
			h.env.Players._props.LocalPlayer = adminPlr

			local uidSuggestions = userIdType.suggestions("999", 10, { lowerRank = false })
			sert.eq(uidSuggestions[1][1], "999")
			sert.eq(uidSuggestions[1][3].UserId, 999)

			-- userId online lookup, raw numeric ID, and disconnected userCache lookup
			sert.eq(userIdType.parse("modbravo", adminSelf), 20)
			sert.eq(userIdType.parse("77777", adminSelf), 77777)
			local badUid, badUidErr = userIdType.parse("no_such_user", adminSelf)
			sert.eq(badUid, nil)
			sert.eq(badUidErr, "Invalid user")
			-- so does a userId past 2^53, which getUserInfo can't look up
			for _, input in { "1e300", "9007199254740994" } do
				local okHuge, errHuge = userIdType.parse(input, adminSelf)
				sert.eq(okHuge, nil)
				sert.eq(errHuge, "Invalid user")
			end
			sert.eq(userIdType.parse("9007199254740992", adminSelf), 2 ^ 53)

			-- Disconnect vipPlr -> memoized in userCache -> userId still resolves "vipcharlie" and includes in suggestions
			h.env:removePlayer(30)
			h.env.Players.PlayerRemoving:Fire(vipPlr)
			-- Firing PlayerRemoving a second time cancels previous freeThread and re-memoizes cleanly
			h.env.Players.PlayerRemoving:Fire(vipPlr)
			sert.eq(playerType.parse("vipcharlie", adminSelf), nil)
			sert.eq(userIdType.parse("vipcharlie", adminSelf), 30)
			local cachedUidSuggestions = userIdType.suggestions("", 10, { lowerRank = false })
			local foundCachedVip = false
			for _, entry in cachedUidSuggestions do
				if type(entry[3]) == "table" and entry[3].UserId == 30 then
					foundCachedVip = true
				end
			end
			sert.eq(foundCachedVip, true)
			local nonCachedPlrSuggestions = playerType.suggestions("", 10, { lowerRank = false })
			local foundInPlr = false
			for _, entry in nonCachedPlrSuggestions do
				if type(entry[3]) == "table" and entry[3].UserId == 30 then
					foundInPlr = true
				end
			end
			sert.eq(foundInPlr, false)

			-- Re-adding player clears userCache entry
			vipPlr = h.env:addPlayer(30, "VipCharlie")
			attachPlayerHelpers(h.env, vipPlr)

			-- userId parse when parseIndividual fails with non-"Invalid player" reason (ignoreSelf)
			local noSelfArg = makeArgSelf(_K, 10, { type = "userId", name = "Target", ignoreSelf = true }, "me")
			local noSelfVal, noSelfErr = userIdType.parse("me", noSelfArg)
			sert.eq(noSelfVal, nil)
			sert.eq(noSelfErr, "Can't target yourself")

			-- players and userId postParse with nested tables and direct values
			sert.eq(playersType.postParse({ { adminPlr, modPlr }, vipPlr }), { adminPlr, modPlr, vipPlr })
			sert.eq(userIdType.postParse({ { adminPlr, { UserId = 20 }, 30 }, 40 }), { 10, 20, 30, 40 })

			-- players and userIds postParse flattening via Argument:prepare()
			local cmd = makeCommandContext(_K, 10)
			local argPlayers = Argument.new(cmd, { type = "players", name = "Targets" }, 1, "me,modbravo")
			local okPlayers, parsedPlayers = argPlayers:prepare()
			sert.eq(okPlayers, true)
			sert.eq(parsedPlayers, { adminPlr, modPlr })

			local argUserIds = Argument.new(cmd, { type = "userIds", name = "Targets" }, 1, "me,modbravo,88888")
			local okUserIds, parsedUserIds = argUserIds:prepare()
			sert.eq(okUserIds, true)
			sert.eq(parsedUserIds, { 10, 20, 88888 })
			sert.eq(playersType.listable, true)
			sert.eq(userIdsType.listable, true)
		end
	)

	test(
		"prefix matchers: *, all, others, @role, %team, ~random, and $special (distance, group, friends, admins)",
		function()
			local h, _K, Argument = newMountedK({ isStudio = false })

			local adminPlr = h.env:addPlayer(10, "AdminOne")
			local modPlr = h.env:addPlayer(20, "ModTwo")
			local guestPlr = h.env:addPlayer(30, "GuestThree")
			h.env.Players._props.LocalPlayer = adminPlr

			-- Attach characters in workspace at known positions (0, 30, 150 studs from origin)
			attachPlayerHelpers(h.env, adminPlr, {
				position = Vector3.new(0, 0, 0),
				friends = { [20] = true },
				groups = { [100] = 255 },
			})
			attachPlayerHelpers(h.env, modPlr, {
				position = Vector3.new(30, 0, 0),
				friends = { [10] = true },
				groups = { [100] = 50 },
			})
			attachPlayerHelpers(h.env, guestPlr, {
				position = Vector3.new(150, 0, 0),
				friends = {},
				groups = {},
			})

			-- Provide GroupService:GetRolesInGroupAsync for $group= matcher
			local groupMethods = rawget(_K.Service.Group, "_methods")
			groupMethods.GetRolesInGroupAsync = function(_self: any, userId: number, groupId: number)
				if groupId ~= 100 then
					return { Roles = {} }
				end
				if userId == 10 then
					return { Roles = { { Rank = 255 } } }
				elseif userId == 20 then
					return { Roles = { { Rank = 50 } } }
				end
				return { Roles = {} }
			end

			_K.Auth.userRoleAdd(10, "admin")
			_K.Auth.userRoleAdd(20, "mod")

			-- Seed Red and Blue teams with GetPlayers()
			local redTeam = h.env.Instance.new("Team", _K.Service.Teams)
			redTeam.Name = "Red"
			rawset(redTeam, "_methods", {
				GetPlayers = function()
					return { adminPlr, modPlr }
				end,
			})
			local blueTeam = h.env.Instance.new("Team", _K.Service.Teams)
			blueTeam.Name = "Blue"
			rawset(blueTeam, "_methods", {
				GetPlayers = function()
					return { guestPlr }
				end,
			})
			local emptyTeam = h.env.Instance.new("Team", _K.Service.Teams)
			emptyTeam.Name = "Green"
			rawset(emptyTeam, "_methods", {
				GetPlayers = function()
					return {}
				end,
			})

			h.env:step(0.05)

			local function parsePlayersArg(raw: string, fromId: number?, defOverrides: { [string]: any }?)
				local cmd = makeCommandContext(_K, fromId or 10)
				local def: { [string]: any } = { type = "players", name = "Targets" }
				if defOverrides then
					for k, v in defOverrides do
						def[k] = v
					end
				end
				local arg = Argument.new(cmd, def, 1, raw)
				return arg:prepare()
			end

			-- 1. All.luau (* and all)
			local okStar, starList = parsePlayersArg("*")
			sert.eq(okStar, true)
			sert.eq(#starList, 3)
			local okAll, allList = parsePlayersArg("all")
			sert.eq(okAll, true)
			sert.eq(#allList, 3)
			sert.eq(#_K.Registry.types.allPlayers.suggestions("", nil), 1)

			-- 2. Others.luau (others)
			local okOthers, othersList = parsePlayersArg("others")
			sert.eq(okOthers, true)
			sert.eq(#othersList, 2)
			sert.eq(table.find(othersList, adminPlr), nil)

			-- 3. Role.luau (@mod, @admin, invalid @unknownrole)
			local okRole, roleList = parsePlayersArg("@mod")
			sert.eq(okRole, true)
			sert.eq(roleList, { modPlr })
			local okBadRole = parsePlayersArg("@nonexistent")
			sert.eq(okBadRole, false)
			local okEmptyRole = parsePlayersArg("@vip")
			sert.eq(okEmptyRole, false)
			sert.eq(type(_K.Registry.types.rolePlayers.suggestions("", nil)), "table")

			-- 4. Team.luau (%Red, %Blue, empty %Green, invalid %Purple)
			local okRed, redList = parsePlayersArg("%red")
			sert.eq(okRed, true)
			sert.eq(redList, { adminPlr, modPlr })
			local okBlue, blueList = parsePlayersArg("%blue")
			sert.eq(okBlue, true)
			sert.eq(blueList, { guestPlr })
			sert.eq((parsePlayersArg("%green")), false)
			sert.eq((parsePlayersArg("%purple")), false)
			sert.eq(#_K.Registry.types.teamPlayers.suggestions("", nil), 3)

			-- 5. Random.luau (~, ~1, ~2, invalid ~abc)
			local okRandDefault, randDefault = parsePlayersArg("~")
			sert.eq(okRandDefault, true)
			sert.eq(#randDefault, 1)
			local okRand2, rand2 = parsePlayersArg("~2")
			sert.eq(okRand2, true)
			sert.eq(#rand2, 2)
			sert.eq((parsePlayersArg("~abc")), false)

			-- 6. Special.luau ($all, $others, $admins, $nonadmins, $friends, $close, $far, $distance, $group, invalid)
			local okSpecAll, specAll = parsePlayersArg("$all")
			sert.eq(okSpecAll, true)
			sert.eq(#specAll, 3)

			local okSpecOthers, specOthers = parsePlayersArg("$others")
			sert.eq(okSpecOthers, true)
			sert.eq(#specOthers, 2)

			local okAdmins, specAdmins = parsePlayersArg("$admins")
			sert.eq(okAdmins, true)
			sert.eq(#specAdmins, 2)

			local okNonAdmins, specNonAdmins = parsePlayersArg("$nonadmins")
			sert.eq(okNonAdmins, true)
			sert.eq(specNonAdmins, { guestPlr })

			local okFriends, specFriends = parsePlayersArg("$friends")
			sert.eq(okFriends, true)
			sert.eq(specFriends, { modPlr })

			local okClose, specClose = parsePlayersArg("$close")
			sert.eq(okClose, true)
			sert.eq(#specClose, 2) -- adminPlr (0) and modPlr (30) <= 100

			local okFar, specFar = parsePlayersArg("$far")
			sert.eq(okFar, true)
			sert.eq(specFar, { guestPlr }) -- guestPlr (150) > 100

			-- Distance matcher: $distance<50 (adminPlr at 0, modPlr at 30) and $distance>100 (guestPlr at 150)
			local okDistNear, distNear = parsePlayersArg("$distance<50")
			sert.eq(okDistNear, true)
			sert.eq(#distNear, 2)

			local okDistFar, distFar = parsePlayersArg("$distance>100")
			sert.eq(okDistFar, true)
			sert.eq(distFar, { guestPlr })

			sert.eq((parsePlayersArg("$distance<bad")), false)

			-- Characterless player during $close, $far, $distance
			local savedChar = guestPlr.Character
			guestPlr.Character = nil
			sert.eq((parsePlayersArg("$close")), true)
			sert.eq((parsePlayersArg("$far")), false)
			sert.eq((parsePlayersArg("$distance>100")), false)
			guestPlr.Character = savedChar

			-- Group matcher: $group=100=, $group=100>=50, $group=100>51, $group=100<=50, $group=100=50, $group=100<100
			local okGrpAny, grpAny = parsePlayersArg("$group=100=")
			sert.eq(okGrpAny, true)
			sert.eq(#grpAny, 2)

			local okGrpGe, grpGe = parsePlayersArg("$group=100>=50")
			sert.eq(okGrpGe, true)
			sert.eq(#grpGe, 2)

			local okGrpGt, grpGt = parsePlayersArg("$group=100>50")
			sert.eq(okGrpGt, true)
			sert.eq(grpGt, { adminPlr })

			local okGrpLe, grpLe = parsePlayersArg("$group=100<=50")
			sert.eq(okGrpLe, true)
			sert.eq(grpLe, { modPlr })

			local okGrpLt, grpLt = parsePlayersArg("$group=100<100")
			sert.eq(okGrpLt, true)
			sert.eq(grpLt, { modPlr })

			sert.eq((parsePlayersArg("$group=100<50")), false)
			sert.eq((parsePlayersArg("$group=100>255")), false)

			local okGrpEq, grpEq = parsePlayersArg("$group=100=50")
			sert.eq(okGrpEq, true)
			sert.eq(grpEq, { modPlr })

			sert.eq((parsePlayersArg("$group=invalid")), false)
			sert.eq((parsePlayersArg("$fps")), false)
			sert.eq((parsePlayersArg("!me")), false)
			sert.eq((parsePlayersArg("!@vip")), false)

			-- Untargetable feedback branches across All, Others, Random, Role, Team, Special
			-- Guest (30, everyone role) has onlyTargetSelf = true and limits.targets = 1
			_K.Auth.userRoleAdd(10, "mod")
			local selfAndLimitErr = "Can only target yourself\nCan only target 1 user"
			for _, raw in { "*", "others", "~1", "@mod", "%red", "$all" } do
				local okU, errU = parsePlayersArg(raw, 30, { ignoreSelf = true })
				sert.eq(okU, false)
				sert.eq(errU.message, selfAndLimitErr)
			end

			local specSug = _K.Registry.types.specialPlayers.suggestions("", nil)
			sert.eq(#specSug >= 9, true)

			-- userIds with prefix matchers flattens players into UserIds
			local cmd = makeCommandContext(_K, 10)
			local uidArg = Argument.new(cmd, { type = "userIds", name = "Ids" }, 1, "%blue,@mod")
			local okUids, parsedUids = uidArg:prepare()
			sert.eq(okUids, true)
			sert.eq(parsedUids, { 30, 10, 20 })

			-- Others when only 1 player is online returns "No other players online"
			h.env:removePlayer(20)
			h.env:removePlayer(30)
			local okSoloOthers, errSoloOthers = parsePlayersArg("others", 10)
			sert.eq(okSoloOthers, false)
			sert.eq(errSoloOthers.message, "No other players online")
		end
	)

	test(
		"adversarial argument type coercion fuzzing with malformedString, boundaryInt, boundaryFloat, and strict per-type postcondition contracts",
		function()
			local h, _K, Argument = newMountedK({ isStudio = false })
			local adminPlr = h.env:addPlayer(10, "AdminFuzzer")
			local modPlr = h.env:addPlayer(20, "ModFuzzer")
			local guestPlr = h.env:addPlayer(30, "GuestFuzzer")
			h.env.Players._props.LocalPlayer = adminPlr
			attachPlayerHelpers(h.env, adminPlr, { position = Vector3.new(0, 0, 0) })
			attachPlayerHelpers(h.env, modPlr, { position = Vector3.new(25, 0, 0) })
			attachPlayerHelpers(h.env, guestPlr, { position = Vector3.new(120, 0, 0) })
			_K.Auth.userRoleAdd(10, "superadmin")
			_K.Auth.userRoleAdd(20, "mod")
			_K.Data.bans["901"] = { "BannedNineZeroOne", "FuzzBan", -1, 10 }
			_K.Data.bans["902"] = { "BannedLowRank", "ModBan", 0, 20 }

			local typeNames = {
				"integer",
				"number",
				"boolean",
				"color",
				"timeSimple",
				"vector2",
				"vector3",
				"ban",
				"member",
				"role",
				"player",
				"players",
				"userId",
				"image",
				"emote",
				"command",
			}

			local function snapshotServerState()
				local bansSnap = {}
				for k, v in _K.Data.bans do
					bansSnap[k] = { v[1], v[2], v[3], v[4] }
				end
				local membersSnap = {}
				for k, v in _K.Data.members do
					membersSnap[k] = table.clone(v.roles)
				end
				local rolesSnap = {}
				for k, v in _K.Data.roles do
					rolesSnap[k] = v._rank
				end
				return { bans = bansSnap, members = membersSnap, roles = rolesSnap }
			end

			local initialState = snapshotServerState()

			local function assertRankRespectsCaller(callerId: number, targetUserId: number, lowerRank: boolean)
				if not lowerRank or targetUserId == callerId or callerId == _K.Data.creatorId then
					return
				end
				if _K.Auth.hasPermission(callerId, "admin") then
					return
				end
				local callerRank = _K.Auth.getRank(callerId)
				local targetRank = _K.Auth.getRank(targetUserId)
				sert.eq(callerRank > targetRank, true)
			end

			local function assertPostcondition(typeName: string, callerId: number, val: any, rawInput: string?)
				local stripped = if rawInput then _K.Util.String.stripQuotes(_K.Util.String.trim(rawInput)) else ""
				if typeName == "integer" then
					sert.eq(type(val), "number")
					sert.eq(val == math.floor(val), true)
				elseif typeName == "number" then
					sert.eq(type(val), "number")
					if tonumber(stripped) == tonumber(stripped) then
						sert.eq(val == val, true)
					end
				elseif typeName == "boolean" then
					sert.eq(type(val), "boolean")
				elseif typeName == "color" then
					sert.eq(rbxTypeof(val), "Color3")
				elseif typeName == "vector2" then
					sert.eq(rbxTypeof(val), "Vector2")
					if not string.find(string.lower(stripped), "nan", 1, true) then
						sert.eq(val.X == val.X and val.Y == val.Y, true)
					end
				elseif typeName == "vector3" then
					sert.eq(rbxTypeof(val), "Vector3")
					if not string.find(string.lower(stripped), "nan", 1, true) then
						sert.eq(val.X == val.X and val.Y == val.Y and val.Z == val.Z, true)
					end
				elseif typeName == "timeSimple" then
					sert.eq(type(val), "number")
					if tonumber(stripped) == nil then
						sert.eq(val == -1 or val >= 0, true)
					end
				elseif typeName == "player" then
					sert.eq(rbxTypeof(val), "Instance")
					sert.eq(val:IsA("Player"), true)
					assertRankRespectsCaller(callerId, val.UserId, true)
				elseif typeName == "players" then
					sert.eq(type(val), "table")
					sert.eq(#val >= 1, true)
					for _, plr in val do
						sert.eq(rbxTypeof(plr), "Instance")
						sert.eq(plr:IsA("Player"), true)
						assertRankRespectsCaller(callerId, plr.UserId, true)
					end
				elseif typeName == "userId" then
					sert.eq(type(val), "number")
					sert.eq(val == math.floor(val) and val > 0 and val <= 2 ^ 53, true)
					assertRankRespectsCaller(callerId, val, true)
				elseif typeName == "role" then
					sert.eq(type(val), "string")
					local roleDef = _K.Data.roles[val]
					sert.eq(roleDef ~= nil, true)
					if callerId ~= _K.Data.creatorId then
						sert.eq(_K.Auth.getRank(callerId) > roleDef._rank, true)
					end
				elseif typeName == "member" then
					if type(val) == "table" then
						for _, mId in val do
							sert.eq(_K.Data.members[tostring(mId)] ~= nil, true)
							assertRankRespectsCaller(callerId, tonumber(mId) :: number, true)
						end
					else
						sert.eq(type(val), "string")
						sert.eq(_K.Data.members[val] ~= nil, true)
						assertRankRespectsCaller(callerId, tonumber(val) :: number, true)
					end
				elseif typeName == "ban" then
					if type(val) == "table" then
						for _, bId in val do
							assertRankRespectsCaller(callerId, tonumber(bId) :: number, true)
						end
					else
						sert.eq(type(val), "string")
						assertRankRespectsCaller(callerId, tonumber(val) :: number, true)
					end
				end
			end

			local malformedGen = sert.gen.malformedString()
			local bIntGen = sert.gen.boundaryInt(-2 ^ 31, 2 ^ 31)
			local bFloatGen = sert.gen.boundaryFloat(-1e9, 1e9)

			sert.prop(
				"DefaultTypes argument coercion satisfies strict per-type postcondition contracts and preserves server state on failure",
				function(g)
					local malformed = malformedGen(g)
					local bInt = bIntGen(g)
					local bFloat = bFloatGen(g)
					local intType = _K.Registry.types.integer
					local numType = _K.Registry.types.number

					-- Finite integer strings transform, validate, and parse to exact integer within limits
					local tInt = intType.transform(tostring(bInt))
					sert.eq((intType.validate(tInt)), true)
					local parsedInt = intType.parse(tInt)
					sert.eq(parsedInt, bInt)
					sert.eq(math.abs(parsedInt) <= 2 ^ 31, true)
					assertPostcondition("integer", 10, parsedInt, tostring(bInt))

					-- Boundary float validation: NaN and ±inf are rejected by both integerType and numberType
					local floatStr = tostring(bFloat)
					local tFloat = numType.transform(floatStr)
					local isFiniteFloat = tFloat ~= nil and tFloat == tFloat and math.abs(tFloat) ~= math.huge
					if bFloat ~= bFloat then
						sert.eq((intType.validate(tFloat)), false)
					elseif math.abs(bFloat) < math.huge and bFloat == math.floor(bFloat) and tFloat ~= nil then
						sert.eq((intType.validate(tFloat)), true)
					end
					sert.eq((numType.validate(tFloat)), isFiniteFloat)
					if isFiniteFloat then
						assertPostcondition("number", 10, numType.parse(tFloat), floatStr)
					end

					_K.Data.settings.commandRequests = false
					for _, callerId in { 10, 20 } do
						local callerCmd = makeCommandContext(_K, callerId)
						for _, typeName in typeNames do
							_K.Data.targetLimits[callerId] = 0
							local arg = Argument.new(
								callerCmd,
								{ type = typeName, name = "FuzzArg", lowerRank = true },
								1,
								malformed
							)
							local okCall, okPrep, resOrErr = pcall(arg.prepare, arg)
							sert.eq(okCall, true)
							sert.eq(type(okPrep), "boolean")
							if okPrep then
								assertPostcondition(typeName, callerId, resOrErr, malformed)
							else
								local feedback = if type(resOrErr) == "table" then resOrErr.message else resOrErr
								sert.eq(type(feedback), "string")
								sert.eq(#feedback > 0, true)
							end
						end
					end

					-- Server state (bans, members, roles) is completely untouched after all coercion attempts
					sert.eq(snapshotServerState(), initialState)

					-- Guest (rank 0, everyone) attempting to target higher-rank players via player/players/userId is always rejected when lowerRank = true
					local guestCmd = makeCommandContext(_K, 30)
					for _, rawTarget in { "AdminFuzzer", "ModFuzzer", "@mod", "@superadmin", "$admins", "10", "20" } do
						_K.Data.targetLimits[30] = 0
						local guestArg = Argument.new(
							guestCmd,
							{ type = "players", name = "Target", lowerRank = true, ignoreSelf = true },
							1,
							rawTarget
						)
						local okGuest, parsedGuest = guestArg:prepare()
						sert.eq(okGuest, false)
						local feedback = if type(parsedGuest) == "table" then parsedGuest.message else parsedGuest
						sert.eq(type(feedback), "string")
						sert.eq(#feedback > 0, true)
					end
					_K.Data.settings.commandRequests = true
				end,
				{ runs = 50 }
			)
		end
	)

	describe("Player Selector Set Algebra", function()
		local h: any, _K: any, Argument: any
		local groupRanksByUser: { [number]: number } = {}
		local redMembers: { any } = {}
		local blueMembers: { any } = {}
		local rosterSpecs = {
			{ id = 10, name = "AlphaAdmin", role = "superadmin", team = "Red", dist = 0, groupRank = 255 },
			{ id = 20, name = "BravoMod", role = "mod", team = "Red", dist = 35, groupRank = 120 },
			{ id = 30, name = "CharlieVip", role = "vip", team = "Blue", dist = 75, groupRank = 50 },
			{ id = 40, name = "DeltaGuest", role = nil, team = "Blue", dist = 160, groupRank = 0 },
		}
		local playersById: { [number]: any } = {}

		local function ensureAlgebraEnv()
			if h then
				return
			end
			h, _K, Argument = newMountedK({ isStudio = false })
			local groupMethods = rawget(_K.Service.Group, "_methods")
			groupMethods.GetRolesInGroupAsync = function(_self: any, userId: number, groupId: number)
				if groupId ~= 100 then
					return { Roles = {} }
				end
				local r = groupRanksByUser[userId] or 0
				if r > 0 then
					return { Roles = { { Rank = r } } }
				end
				return { Roles = {} }
			end

			local redTeam = h.env.Instance.new("Team", _K.Service.Teams)
			redTeam.Name = "Red"
			rawset(redTeam, "_methods", {
				GetPlayers = function()
					return redMembers
				end,
			})
			local blueTeam = h.env.Instance.new("Team", _K.Service.Teams)
			blueTeam.Name = "Blue"
			rawset(blueTeam, "_methods", {
				GetPlayers = function()
					return blueMembers
				end,
			})

			for _, spec in rosterSpecs do
				local p = h.env:addPlayer(spec.id, spec.name)
				groupRanksByUser[spec.id] = spec.groupRank
				attachPlayerHelpers(h.env, p, {
					position = Vector3.new(spec.dist, 0, 0),
					groups = { [100] = spec.groupRank },
				})
				if spec.role then
					_K.Auth.userRoleAdd(spec.id, spec.role)
				end
				if spec.team == "Red" then
					table.insert(redMembers, p)
				else
					table.insert(blueMembers, p)
				end
				playersById[spec.id] = p
			end
			h.env.Players._props.LocalPlayer = playersById[10]
			h.env:step(0.05)
		end

		local function toSortedIdSet(playersList: { any }): { number }
			local seen: { [number]: boolean } = {}
			local out: { number } = {}
			for _, p in playersList do
				local uid = if type(p) == "number" then p else p.UserId
				if not seen[uid] then
					seen[uid] = true
					table.insert(out, uid)
				end
			end
			table.sort(out)
			return out
		end

		local function setUnion(a: { number }, b: { number }): { number }
			local combined = table.clone(a)
			for _, id in b do
				table.insert(combined, id)
			end
			return toSortedIdSet(combined)
		end

		local function setIntersection(a: { number }, b: { number }): { number }
			local inB: { [number]: boolean } = {}
			for _, id in b do
				inB[id] = true
			end
			local out: { number } = {}
			for _, id in a do
				if inB[id] then
					table.insert(out, id)
				end
			end
			return out
		end

		local function eligibleTargets(callerId: number, lowerRank: boolean?): { number }
			ensureAlgebraEnv()
			_K.Data.targetLimits[callerId] = 0
			local fauxArg =
				makeArgSelf(_K, callerId, { type = "players", name = "Targets", lowerRank = lowerRank == true }, "all")
			local eligible: { number } = {}
			for _, p in _K.Service.Players:GetPlayers() do
				local target = _K.Auth.targetUserArgument(fauxArg, p.UserId, p)
				if target then
					table.insert(eligible, p.UserId)
				end
			end
			table.sort(eligible)
			return eligible
		end

		local function resolveAtom(atom: string, callerId: number, lowerRank: boolean?): { number }
			ensureAlgebraEnv()
			local negCount = 0
			local core = atom
			while string.sub(core, 1, 1) == "!" do
				negCount += 1
				core = string.sub(core, 2)
			end
			_K.Data.targetLimits[callerId] = 0
			local cmd = makeCommandContext(_K, callerId)
			local arg =
				Argument.new(cmd, { type = "players", name = "Targets", lowerRank = lowerRank == true }, 1, core)
			local ok, parsed = arg:prepare()
			local baseSet = if ok and type(parsed) == "table" then toSortedIdSet(parsed) else {}
			if negCount % 2 == 1 then
				local universe = eligibleTargets(callerId, lowerRank)
				local inBase: { [number]: boolean } = {}
				for _, id in baseSet do
					inBase[id] = true
				end
				local comp: { number } = {}
				for _, id in universe do
					if not inBase[id] then
						table.insert(comp, id)
					end
				end
				return comp
			elseif negCount > 0 then
				local universe = eligibleTargets(callerId, lowerRank)
				return setIntersection(baseSet, universe)
			end
			return baseSet
		end

		local function resolve(expr: string, callerId: number?, lowerRank: boolean?): { number }
			ensureAlgebraEnv()
			local cid = callerId or 10
			-- If expr contains no "!" complement prefix, run the full comma expression directly through Argument:prepare()
			if not string.find(expr, "!", 1, true) then
				_K.Data.targetLimits[cid] = 0
				local cmd = makeCommandContext(_K, cid)
				local arg =
					Argument.new(cmd, { type = "players", name = "Targets", lowerRank = lowerRank == true }, 1, expr)
				local ok, parsed = arg:prepare()
				if ok and type(parsed) == "table" then
					return toSortedIdSet(parsed)
				end
			end
			local result: { number } = {}
			for _, piece in string.split(expr, ",") do
				result = setUnion(result, resolveAtom(piece, cid, lowerRank))
			end
			return result
		end

		local function oracleAtom(atom: string, callerId: number, lowerRank: boolean?): { number }
			ensureAlgebraEnv()
			local negCount = 0
			local core = atom
			while string.sub(core, 1, 1) == "!" do
				negCount += 1
				core = string.sub(core, 2)
			end
			local universe = eligibleTargets(callerId, lowerRank)
			local isEligible: { [number]: boolean } = {}
			for _, id in universe do
				isEligible[id] = true
			end
			local callerDist = 0
			for _, s in rosterSpecs do
				if s.id == callerId then
					callerDist = s.dist
					break
				end
			end

			local matched: { number } = {}
			for _, s in rosterSpecs do
				if not isEligible[s.id] then
					continue
				end
				local hit = false
				if core == "me" then
					hit = (s.id == callerId)
				elseif core == "all" or core == "*" or core == "$all" then
					hit = true
				elseif core == "others" or core == "$others" then
					hit = (s.id ~= callerId)
				elseif core == "@superadmin" then
					hit = (s.role == "superadmin")
				elseif core == "@mod" then
					hit = (s.role == "mod")
				elseif core == "@vip" then
					hit = (s.role == "vip")
				elseif core == "%red" then
					hit = (s.team == "Red")
				elseif core == "%blue" then
					hit = (s.team == "Blue")
				elseif core == "$admins" then
					hit = (s.role ~= nil)
				elseif core == "$nonadmins" then
					hit = (s.role == nil)
				elseif core == "$close" or core == "$distance<100" then
					hit = (math.abs(s.dist - callerDist) <= 100)
				elseif core == "$far" or core == "$distance>100" then
					hit = (math.abs(s.dist - callerDist) > 100)
				elseif core == "$distance<50" then
					hit = (math.abs(s.dist - callerDist) <= 50)
				elseif core == "$distance>50" then
					hit = (math.abs(s.dist - callerDist) > 50)
				elseif core == "$group=100>=50" then
					hit = (s.groupRank >= 50)
				elseif core == "$group=100>100" then
					hit = (s.groupRank > 100)
				elseif core == "$group=100<=120" then
					hit = (s.groupRank > 0 and s.groupRank <= 120)
				end
				if hit then
					table.insert(matched, s.id)
				end
			end
			table.sort(matched)

			if negCount % 2 == 1 then
				local inMatched: { [number]: boolean } = {}
				for _, id in matched do
					inMatched[id] = true
				end
				local comp: { number } = {}
				for _, id in universe do
					if not inMatched[id] then
						table.insert(comp, id)
					end
				end
				return comp
			end
			return matched
		end

		local selectorPool = {
			"me",
			"all",
			"others",
			"@superadmin",
			"@mod",
			"@vip",
			"%red",
			"%blue",
			"$admins",
			"$nonadmins",
			"$close",
			"$far",
			"$distance<50",
			"$distance>50",
			"$group=100>=50",
			"$group=100>100",
			"$group=100<=120",
		}

		sert.laws.algebra("Player selector comma union (a,b)", {
			gen = function(g)
				return g:pick(selectorPool)
			end,
			op = function(a: string, b: string): string
				return a .. "," .. b
			end,
			eq = function(a: string, b: string): boolean
				return sert.equals(resolve(a, 10, false), resolve(b, 10, false))
			end,
			associative = true,
			commutative = true,
			idempotent = true,
		}, { runs = 60 })

		sert.prop(
			"selector expressions satisfy oracle equivalence, disjoint complement partition, involution, union commutativity/idempotence, and self/other partition across rosters",
			function(g)
				ensureAlgebraEnv()
				-- Vary player distances and group ranks dynamically per trial
				for _, spec in rosterSpecs do
					spec.dist = g:pick({ 0, 25, 45, 80, 130, 180 })
					spec.groupRank = g:pick({ 0, 50, 120, 255 })
					groupRanksByUser[spec.id] = spec.groupRank
					local plr = playersById[spec.id]
					local hrp = plr.Character.PrimaryPart
					local pos = Vector3.new(spec.dist, 0, 0)
					hrp.Position = pos
					hrp.CFrame = CFrame.new(pos)
					plr.Character:PivotTo(CFrame.new(pos))
					sert.spy(plr, "IsInGroupAsync", function(_self: any, groupId: number): boolean
						return groupId == 100 and spec.groupRank > 0
					end)
				end

				local callerId = g:pick({ 10, 20 })
				local lowerRank = if callerId == 20 then g:bool(0.5) else false
				_K.Data.settings.commandRequests = false

				local s = g:pick(selectorPool)
				local b = g:pick(selectorPool)

				-- 1. Differential match against pure set-theory oracle
				local resolvedS = resolve(s, callerId, lowerRank)
				local expectedS = oracleAtom(s, callerId, lowerRank)
				sert.eq(resolvedS, expectedS)

				-- 2. Disjoint complement partition: resolve(s) ∩ resolve("!" .. s) == ∅ and resolve(s) ∪ resolve("!" .. s) == eligibleTargets(caller)
				local resolvedNotS = resolve("!" .. s, callerId, lowerRank)
				local expectedNotS = oracleAtom("!" .. s, callerId, lowerRank)
				sert.eq(resolvedNotS, expectedNotS)
				sert.eq(setIntersection(resolvedS, resolvedNotS), {})
				sert.eq(setUnion(resolvedS, resolvedNotS), eligibleTargets(callerId, lowerRank))

				-- 3. Involution on unrestricted universe (caller 10 = superadmin): resolve("!!" .. s) == resolve(s)
				sert.eq(resolve("!!" .. s, 10, false), resolve(s, 10, false))

				-- 4. Union commutativity & idempotence on unrestricted universe
				sert.eq(resolve(s .. "," .. b, 10, false), resolve(b .. "," .. s, 10, false))
				sert.eq(resolve(s .. "," .. s, 10, false), resolve(s, 10, false))

				-- 5. Self/other partition: resolve("all") == resolve("me,others") and resolve("me") ∩ resolve("others") == ∅
				sert.eq(resolve("all", 10, false), resolve("me,others", 10, false))
				sert.eq(setIntersection(resolve("me", 10, false), resolve("others", 10, false)), {})

				-- 6. Native _K complement pairs ($admins vs $nonadmins, $close vs $far, $distance<50 vs $distance>50)
				sert.eq(setIntersection(resolve("$admins", 10, false), resolve("$nonadmins", 10, false)), {})
				sert.eq(
					setUnion(resolve("$admins", 10, false), resolve("$nonadmins", 10, false)),
					resolve("all", 10, false)
				)
				sert.eq(setIntersection(resolve("$close", 10, false), resolve("$far", 10, false)), {})
				sert.eq(setUnion(resolve("$close", 10, false), resolve("$far", 10, false)), resolve("all", 10, false))
				sert.eq(setIntersection(resolve("$distance<50", 10, false), resolve("$distance>50", 10, false)), {})
				sert.eq(
					setUnion(resolve("$distance<50", 10, false), resolve("$distance>50", 10, false)),
					resolve("all", 10, false)
				)

				-- 7. ~random selector returns k distinct eligible targets subset of eligibleTargets(caller)
				local k = g:int(1, 3)
				local randSet = resolve(`~{k}`, callerId, lowerRank)
				local universe = eligibleTargets(callerId, lowerRank)
				sert.eq(#randSet, math.min(k, #universe))
				sert.eq(setIntersection(randSet, universe), randSet)

				_K.Data.settings.commandRequests = true
			end,
			{ runs = 60 }
		)
	end)

	test(
		"rejects NaN and ±inf in integer/number/timeSimple/~random, rejects single-element nil in makeSequenceType, and rejects bare @/%/$ selectors",
		function()
			local _K, Argument = getSharedK()
			local intType = _K.Registry.types.integer
			local numType = _K.Registry.types.number
			local timeType = _K.Registry.types.timeSimple
			local vec2 = _K.Registry.types.vector2
			local vec3 = _K.Registry.types.vector3

			for _, raw in { "nan", "inf", "-inf" } do
				sert.eq((intType.validate(intType.transform(raw))), false)
				sert.eq((numType.validate(numType.transform(raw))), false)
				sert.eq((timeType.validate(raw)), false)
			end
			sert.eq((timeType.validate("-5")), false)

			-- Single-token invalid input to makeSequenceType must fail validation instead of collapsing to {}
			sert.eq((vec2.validate(vec2.transform("abc"))), false)
			sert.eq((vec3.validate(vec3.transform("1,abc"))), false)

			-- Bare @, %, $ and invalid ~random selectors must fail prepare cleanly
			local cmd = makeCommandContext(_K, 10)
			for _, badSelector in { "@", "%", "$", "~nan", "~inf", "~-1", "~0" } do
				local arg = Argument.new(cmd, { type = "players", name = "Target", lowerRank = false }, 1, badSelector)
				local ok = arg:prepare()
				sert.eq(ok, false)
			end
		end
	)

	test(
		"Emote initialization is idempotent per context and preserves existing.owned on Remote.EmoteType updates",
		function()
			local h = Harness.newEnv({ isClient = true })
			h:mockClientRemotes()
			local Data = h:requireData()
			local Util = h:requireUtil()
			local Remote = h:requireRemote()
			local Registry = h:requireRegistry()
			local connectCalls = 0
			local origConnect = Remote.EmoteType.Connect
			Remote.EmoteType.Connect = function(selfRemote: any, cb: any)
				connectCalls += 1
				return origConnect(selfRemote, cb)
			end

			local fakeK: any = {
				Data = Data,
				Util = Util,
				Remote = Remote,
				Registry = Registry,
				VIP = { allowedBulkPurchaseIds = {} },
			}
			local Emote = h.env:require(h.Shared:WaitForChild("DefaultTypes"):WaitForChild("Emote"))
			Emote(fakeK)
			sert.eq(connectCalls, 1)
			Emote(fakeK)
			sert.eq(connectCalls, 1)
			Remote.EmoteType.Connect = origConnect

			Data.emoteItemFromId[9001] = {
				emoteId = 9001,
				name = "Wave",
				nameLower = "wave",
				animationId = 0,
				owned = true,
			}
			Remote.EmoteType._signal:Fire({
				{ emoteId = 9001, name = "Wave", nameLower = "wave", animationId = 55555 },
			})
			sert.eq(Data.emoteItemFromId[9001].owned, true)
			sert.eq(Data.emoteItemFromId[9001].animationId, 55555)
		end
	)
end)

do
	return {}
end
