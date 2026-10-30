local Harness = require("./Harness")
local sert = require("../sert")

local describe, test, expect = sert.describe, sert.test, sert.expect

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

	rawset(player, "_methods", {
		DistanceFromCharacter = function(self: any, point: any): number
			local c = self.Character
			if not c or not c.PrimaryPart then
				return 0
			end
			return (c.PrimaryPart.Position - point).Magnitude
		end,
		IsFriendsWith = function(_self: any, other: any): boolean
			local otherId = if type(other) == "number" then other else other.UserId
			return friendSet[otherId] == true
		end,
		IsInGroupAsync = function(_self: any, groupId: number): boolean
			return (groupRanks[groupId] or 0) > 0
		end,
	})

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

		expect(boolType.transform("TRUE")).toBe("true")
		expect(boolType.transform("Yes")).toBe("yes")

		-- Empty string defaults to true
		expect((boolType.validate(""))).toBe(true)
		expect(boolType.parse("")).toBe(true)

		-- Truthy prefixes: +, true, yes, enabled
		for _, input in { "+", "t", "true", "y", "yes", "e", "enabled" } do
			local transformed = boolType.transform(input)
			expect((boolType.validate(transformed))).toBe(true)
			expect(boolType.parse(transformed)).toBe(true)
		end

		-- Falsy prefixes: -, false, no, disabled
		for _, input in { "-", "f", "false", "n", "no", "d", "disabled" } do
			local transformed = boolType.transform(input)
			expect((boolType.validate(transformed))).toBe(true)
			expect(boolType.parse(transformed)).toBe(false)
		end

		-- Invalid boolean
		local okInvalid, errInvalid = boolType.validate("maybe")
		expect(okInvalid).toBe(false)
		expect(errInvalid).toBe("Invalid boolean")
		local parsedInvalid, parseErr = boolType.parse("maybe")
		expect(parsedInvalid).toBeNil()
		expect(parseErr).toBe("Invalid boolean")

		-- Suggestions
		local suggestions = boolType.suggestions("", 1)
		expect(type(suggestions)).toBe("table")
		expect(table.find(suggestions, "true") ~= nil).toBe(true)
		expect(table.find(suggestions, "false") ~= nil).toBe(true)

		-- Listable booleans via Argument:prepare()
		expect(boolsType.listable).toBe(true)
		local cmd = makeCommandContext(_K, 1)
		local arg = Argument.new(cmd, { type = "booleans", name = "Flags" }, 1, "true,no,+,disabled")
		local ok, parsed = arg:prepare()
		expect(ok).toBe(true)
		expect(parsed).toEqual({ true, false, true, false })
	end)

	test("integer, integers, number, and numbers transform, validate, and parse", function()
		local _K, Argument = getSharedK()
		local intType = _K.Registry.types.integer
		local intsType = _K.Registry.types.integers
		local numType = _K.Registry.types.number
		local numsType = _K.Registry.types.numbers

		expect(intType.filterLog).toBe(true)
		expect(numType.filterLog).toBe(true)

		-- Empty string transforms to 0
		expect(intType.transform("")).toBe(0)
		expect((intType.validate(0))).toBe(true)
		expect(intType.parse(0)).toBe(0)

		-- Valid integers
		local v42 = intType.transform("42")
		expect(v42).toBe(42)
		expect((intType.validate(v42))).toBe(true)
		expect(intType.parse(v42)).toBe(42)

		local vNeg = intType.transform("-15")
		expect((intType.validate(vNeg))).toBe(true)
		expect(intType.parse(vNeg)).toBe(-15)

		-- Float rejected by integer, accepted by number
		local vFloat = intType.transform("3.14")
		local okIntFloat, errIntFloat = intType.validate(vFloat)
		expect(okIntFloat).toBe(false)
		expect(errIntFloat).toBe("Only whole numbers are valid")

		expect((numType.validate(vFloat))).toBe(true)
		expect(numType.parse(vFloat)).toBe(3.14)

		-- Non-numeric rejected by both
		local badVal, badErr = intType.transform("notanumber")
		expect(badVal).toBeNil()
		expect(badErr).toBe("Invalid number")
		expect((intType.validate(badVal))).toBe(false)
		expect((numType.validate(badVal))).toBe(false)

		-- Listable integers and numbers
		expect(intsType.listable).toBe(true)
		expect(numsType.listable).toBe(true)
		local cmd = makeCommandContext(_K, 1)
		local intArg = Argument.new(cmd, { type = "integers", name = "Ids" }, 1, "10,-20,30")
		local okInts, parsedInts = intArg:prepare()
		expect(okInts).toBe(true)
		expect(parsedInts).toEqual({ 10, -20, 30 })

		local numArg = Argument.new(cmd, { type = "numbers", name = "Coords" }, 1, "1.5,-2.25,0")
		local okNums, parsedNums = numArg:prepare()
		expect(okNums).toBe(true)
		expect(parsedNums).toEqual({ 1.5, -2.25, 0 })
	end)

	test("string, strings, rawString, rawStrings, chatString, and stringGreedy", function()
		local _K, Argument = getSharedK()
		local strType = _K.Registry.types.string
		local strsType = _K.Registry.types.strings
		local rawStrType = _K.Registry.types.rawString
		local rawStrsType = _K.Registry.types.rawStrings
		local chatStrType = _K.Registry.types.chatString
		local greedyStrType = _K.Registry.types.stringGreedy

		expect(rawStrType.filterLog).toBe(true)
		expect(rawStrType.freeText).toBe(true)
		expect((rawStrType.validate("hello"))).toBe(true)
		expect((rawStrType.validate(nil))).toBe(false)
		expect(rawStrType.parse("hello")).toBe("hello")
		expect(rawStrType.parse(123)).toBe("123")
		expect(chatStrType.parse("chat msg")).toBe("chat msg")
		expect(greedyStrType.parse("greedy msg")).toBe("greedy msg")

		expect(strType.freeText).toBe(true)
		expect((strType.validate("broadcast"))).toBe(true)
		expect((strType.validate(nil))).toBe(false)

		-- Global command bypasses chat check and returns raw string
		local globalSelf = makeArgSelf(_K, 10, { type = "string", name = "Msg" }, "global text", { global = true })
		expect(strType.parse("global text", globalSelf)).toBe("global text")

		-- Server non-global command filters string via TextChat / TextService
		local serverSelf = makeArgSelf(_K, 10, { type = "string", name = "Msg" }, "server text", { global = false })
		expect(strType.parse("server text", serverSelf)).toBe("server text")

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
		expect(blockedVal).toBeNil()
		expect(blockedErr).toBe("User cannot chat")
		tcsMethods.CanUserChatAsync = origCanChat

		-- Listable strings and rawStrings via Argument:prepare()
		expect(strsType.listable).toBe(true)
		expect(rawStrsType.listable).toBe(true)
		local cmd = makeCommandContext(_K, 10)
		local rawArg = Argument.new(cmd, { type = "rawStrings", name = "Reasons" }, 1, '"first reason",second')
		local okRaw, parsedRaw = rawArg:prepare()
		expect(okRaw).toBe(true)
		expect(parsedRaw).toEqual({ "first reason", "second" })

		local strArg = Argument.new(cmd, { type = "strings", name = "Words" }, 1, "alpha,beta")
		local okStr, parsedStr = strArg:prepare()
		expect(okStr).toBe(true)
		expect(parsedStr).toEqual({ "alpha", "beta" })
	end)
end)

describe("DefaultTypes · Time", function()
	test("timeSimple parses all units, compound durations, forever (-1), empty default, and suggestions", function()
		local _K = getSharedK()
		local timeType = _K.Registry.types.timeSimple

		expect(timeType.filterLog).toBe(true)

		-- Empty string -> 1 second
		local okEmpty, valEmpty = timeType.validate("")
		expect(okEmpty).toBe(true)
		expect(valEmpty).toBe(1)
		expect(timeType.parse("")).toBe(1)

		-- Forever (-1 and "-")
		local okForever, valForever = timeType.validate("-1")
		expect(okForever).toBe(true)
		expect(valForever).toBe(-1)
		expect(timeType.parse("-1")).toBe(-1)
		expect(timeType.parse("-")).toBe(-1)

		-- Session (0) and plain numbers
		expect(timeType.parse("0")).toBe(0)
		expect(timeType.parse("45")).toBe(45)

		-- Individual units: ms, s, m, h/hr, d, w/wk, month, y/yr
		expect(timeType.parse("500ms")).toBe(0.5)
		expect(timeType.parse("500mss")).toBe(0.5)
		expect(timeType.parse("30s")).toBe(30)
		expect(timeType.parse("2m")).toBe(120)
		expect(timeType.parse("2h")).toBe(7200)
		expect(timeType.parse("1hr")).toBe(3600)
		expect(timeType.parse("1d")).toBe(86400)
		expect(timeType.parse("1w")).toBe(604800)
		expect(timeType.parse("1wk")).toBe(604800)
		expect(timeType.parse("1month")).toBe(2592000)
		expect(timeType.parse("1y")).toBe(31557600)
		expect(timeType.parse("1yr")).toBe(31557600)

		-- Compound duration
		expect(timeType.parse("1d 2h 30m 15s")).toBe(86400 + 7200 + 1800 + 15)

		-- Invalid inputs
		local okNoMatch, errNoMatch = timeType.validate("not_a_time")
		expect(okNoMatch).toBe(false)
		expect(errNoMatch).toBe("Invalid time format")
		expect(function()
			timeType.parse("not_a_time")
		end).toThrow()

		local okBadUnit, errBadUnit = timeType.validate("10qqq")
		expect(okBadUnit).toBe(false)
		expect(errBadUnit).toBe("Invalid time format")
		expect(function()
			timeType.parse("10qqq")
		end).toThrow()

		-- Suggestions for empty, "-1", singular "1", and plural "5"
		local sugDefault = timeType.suggestions("")
		expect(type(sugDefault)).toBe("table")
		expect(sugDefault[1][1]).toBe("0")
		expect(sugDefault[2][1]).toBe("-1")

		local sugNeg = timeType.suggestions("-")
		expect(#sugNeg).toBe(2)

		local sugOne = timeType.suggestions("1")
		expect(#sugOne > 2).toBe(true)

		local sugFive = timeType.suggestions("5")
		expect(#sugFive > 2).toBe(true)
	end)

	test("timeSimple accepts only input made entirely of durations", function()
		local _K = getSharedK()
		local timeType = _K.Registry.types.timeSimple

		-- every duration form still parses
		expect(timeType.parse("1d2h")).toBe(86400 + 7200)
		expect(timeType.parse("1.5h")).toBe(5400)
		expect(timeType.parse("5 days")).toBe(5 * 86400)
		expect(timeType.parse("10M")).toBe(600)
		expect(timeType.parse(" 1h 30m ")).toBe(5400)

		-- only -1 and - are forever, not any part of -1
		expect(timeType.parse("1")).toBe(1)

		-- text that only contains a duration is not one
		for _, input in { "appeal in 5 days", "back in 5 minutes", "5d3", "appeal:5d", "5d!", " " } do
			local ok, err = timeType.validate(input)
			expect(ok).toBe(false)
			expect(err).toBe("Invalid time format")
		end

		-- so an optional duration skips it and the text reaches the reason
		local h = Harness.newEnv()
		local Data = h:requireData()
		local _K2 = h:requireK()
		local admin = h.env:addPlayer(10, "AdminUser")
		Data.creatorId = admin.UserId
		local ok, commands = _K2.Process.prepareCommands(_K2, admin.UserId, ';shutdown "back in 5 minutes"')
		expect(ok).toBe(true)
		expect(commands[1].preparedArgs[1]).toBeNil()
		expect(commands[1].preparedArgs[2]).toBe("back in 5 minutes")
		ok, commands = _K2.Process.prepareCommands(_K2, admin.UserId, ";shutdown 5m back soon")
		expect(ok).toBe(true)
		expect(commands[1].preparedArgs[1]).toBe(300)
		expect(commands[1].preparedArgs[2]).toBe("back soon")
	end)
end)

describe("DefaultTypes · Color", function()
	test("color transforms hex, RGB, named colors, BrickColor names/ids, random, and suggestions", function()
		local _K = getSharedK()
		local colorType = _K.Registry.types.color

		-- Empty string transforms to "" and fails validate
		expect(colorType.transform("")).toBe("")
		local okEmpty, errEmpty = colorType.validate("")
		expect(okEmpty).toBe(false)
		expect(errEmpty).toBe("Invalid Color3")

		-- Named colors
		local red = colorType.transform("red")
		expect((colorType.validate(red))).toBe(true)
		expect(colorType.parse(red)).toEqual(Color3.new(1, 0, 0))
		expect(colorType.transform("  BLUE ")).toEqual(Color3.new(0, 0, 1))
		expect(colorType.transform("white")).toEqual(Color3.new(1, 1, 1))
		expect(colorType.transform("black")).toEqual(Color3.new(0, 0, 0))

		-- Random color
		local rnd = colorType.transform("random")
		expect(rbxTypeof(rnd)).toBe("Color3")
		expect((colorType.validate(rnd))).toBe(true)

		-- BrickColor name and number
		local bcName = colorType.transform("really red")
		expect(rbxTypeof(bcName)).toBe("Color3")
		local bcNum = colorType.transform("3")
		expect(rbxTypeof(bcNum)).toBe("Color3")

		-- Partial name match
		local partial = colorType.transform("magen")
		expect(partial).toEqual(Color3.new(1, 0, 0.5))

		-- Hex formats: #f, #fa, #0f0, #1234, #12345, #ff00aa
		expect(colorType.transform("#000")).toEqual(Color3.new(0, 0, 0))
		expect(colorType.transform("#fff")).toEqual(Color3.new(1, 1, 1))
		expect(rbxTypeof(colorType.transform("#f"))).toBe("Color3")
		expect(rbxTypeof(colorType.transform("#fa"))).toBe("Color3")
		expect(rbxTypeof(colorType.transform("#1234"))).toBe("Color3")
		expect(rbxTypeof(colorType.transform("#12345"))).toBe("Color3")
		expect(colorType.transform("#ff0000")).toEqual(Color3.fromRGB(255, 0, 0))

		-- Invalid hex
		expect(colorType.transform("#1234567")).toBeNil()
		expect(colorType.transform("#gggggg")).toBeNil()

		-- RGB format
		expect(colorType.transform("10,20,30")).toEqual(Color3.fromRGB(10, 20, 30))
		expect(colorType.transform("0,0,0")).toEqual(Color3.new(0, 0, 0))
		expect(colorType.transform("255,255,255")).toEqual(Color3.new(1, 1, 1))

		-- Out of range RGB & completely invalid color
		local badRgb, badRgbErr = colorType.transform("300,0,0")
		expect(badRgb).toBeNil()
		expect(badRgbErr).toBe("Invalid Color")

		local badColor, badColorErr = colorType.transform("not_a_color_xyz")
		expect(badColor).toBeNil()
		expect(badColorErr).toBe("Invalid Color")

		-- Suggestions for hex, random, RGB, and empty
		local sugEmpty, colorsMap = colorType.suggestions("")
		expect(#sugEmpty > 10).toBe(true)
		expect(type(colorsMap)).toBe("table")

		local sugShortHex = colorType.suggestions("#a")
		expect(table.find(sugShortHex, "#aff") ~= nil).toBe(true)
		expect(table.find(sugShortHex, "#afffff") ~= nil).toBe(true)

		local sugMidHex = colorType.suggestions("#abcd")
		expect(table.find(sugMidHex, "#abcdff") ~= nil).toBe(true)

		local sugRandom = colorType.suggestions("ran")
		expect(#sugRandom > 10).toBe(true)

		local sugRgb = colorType.suggestions("12,34,56")
		expect(table.find(sugRgb, "12,34,56") ~= nil).toBe(true)
	end)
end)

describe("DefaultTypes · Vector", function()
	test("vector2 and vector3 transform, validate, parse, and reject invalid sequences", function()
		local _K, Argument = getSharedK()
		local vec2 = _K.Registry.types.vector2
		local vec3 = _K.Registry.types.vector3

		-- Vector2 valid
		local t2 = vec2.transform("10, -25.5")
		expect(t2).toEqual({ 10, -25.5 })
		expect((vec2.validate(t2))).toBe(true)
		expect(vec2.parse(t2)).toEqual(Vector2.new(10, -25.5))

		-- Vector2 too many components
		local t2Many = vec2.transform("1,2,3")
		local ok2Many, err2Many = vec2.validate(t2Many)
		expect(ok2Many).toBe(false)
		expect(err2Many).toBe("Maximum of 2 values allowed in sequence")

		-- Vector invalid number component (middle nil component in sequence)
		local t3Bad = vec3.transform("10,abc,30")
		local ok3Bad, err3Bad = vec3.validate(t3Bad)
		expect(ok3Bad).toBe(false)
		expect(string.find(tostring(err3Bad), "position 2", 1, true) ~= nil).toBe(true)

		-- Vector3 valid
		local t3 = vec3.transform("1,2,3")
		expect(t3).toEqual({ 1, 2, 3 })
		expect((vec3.validate(t3))).toBe(true)
		expect(vec3.parse(t3)).toEqual(Vector3.new(1, 2, 3))

		-- Vector3 too many components
		local t3Many = vec3.transform("1,2,3,4")
		local ok3Many, err3Many = vec3.validate(t3Many)
		expect(ok3Many).toBe(false)
		expect(err3Many).toBe("Maximum of 3 values allowed in sequence")

		-- End-to-end via Argument:prepare()
		local cmd = makeCommandContext(_K, 1)
		local arg = Argument.new(cmd, { type = "vector3", name = "Offset" }, 1, "4,5,6")
		local okArg, valArg = arg:prepare()
		expect(okArg).toBe(true)
		expect(valArg).toEqual(Vector3.new(4, 5, 6))
	end)
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
		expect(banType.validate("bannedb", modSelf)).toBe("501")
		expect(banType.parse("501", modSelf)).toBe("501")

		-- Mod cannot unban saved/persistent ban (lacks banasync / admin)
		local okSavedMod, errSavedMod = banType.parse("savedsally", modSelf)
		expect(okSavedMod).toBeNil()
		expect(errSavedMod).toBe("No permission to unban saved bans")

		-- Mod cannot unban arbitrary unbanned userId (since not ban requires banasync/admin)
		local okUnbannedMod, errUnbannedMod = banType.parse("999", modSelf)
		expect(okUnbannedMod).toBeNil()
		expect(errUnbannedMod).toBe("No permission to unban saved bans")

		-- Admin (has banasync + restricted role) can unban saved ban and arbitrary numeric userId
		local adminSelf = makeArgSelf(_K, adminUser.UserId, { type = "ban", name = "Ban" }, "savedsally")
		expect(banType.parse("savedsally", adminSelf)).toBe("502")
		expect(banType.parse("999", adminSelf)).toBe("999")

		-- The admin permission counts as banasync, but saved bans still need a developer (restricted) role
		local superadmin = _K.Data.roles.superadmin.permissions
		superadmin.admin, superadmin.banasync = true, nil
		h.env:addPlayer(40, "BoughtSuperAdmin"):SetAttribute("_KRolesLoaded", true)
		h.env:addPlayer(41, "DevSuperAdmin"):SetAttribute("_KRolesLoaded", true)
		_K.Auth.userRoleAdd(40, "superadmin", false, true)
		_K.Auth.userRoleAdd(41, "superadmin")
		local boughtSelf = makeArgSelf(_K, 40, { type = "ban", name = "Ban" }, "savedsally")
		local okBought, errBought = banType.parse("savedsally", boughtSelf)
		expect(okBought).toBeNil()
		expect(errBought).toBe("No permission to unban saved bans")
		expect(select(2, banType.parse("999", boughtSelf))).toBe("No permission to unban saved bans")
		expect(banType.parse("501", boughtSelf)).toBe("501")
		local devSelf = makeArgSelf(_K, 41, { type = "ban", name = "Ban" }, "savedsally")
		expect(banType.parse("savedsally", devSelf)).toBe("502")
		superadmin.admin, superadmin.banasync = nil, true

		-- Invalid non-numeric, non-matching ban string
		local badBan, badBanErr = banType.parse("nonexistent_user", adminSelf)
		expect(badBan).toBeNil()
		expect(badBanErr).toBe("Invalid ban.")

		-- UserIds past 2^53 aren't real users, so they can't key a saved ban
		for _, input in { "1e300", "9007199254740994" } do
			local okHuge, errHuge = banType.parse(input, adminSelf)
			expect(okHuge).toBeNil()
			expect(errHuge).toBe("Invalid ban.")
		end
		expect(banType.parse("9007199254740992", adminSelf)).toBe("9007199254740992")
		-- but a junk key saved before this check still matches by key, so it can be unbanned
		_K.Data.bans["1e+300"] = { nil, "junk", 0, 10 }
		expect(banType.parse("1e+300", adminSelf)).toBe("1e+300")
		_K.Data.bans["1e+300"] = nil

		-- Suggestions include *, named bans, and UNKNOWN for nameless bans
		local suggestions = banType.suggestions("")
		expect(suggestions[1][2]).toBe("*  [all] (Everyone)")
		expect(#suggestions).toBe(4)
		local foundNamed, foundUnknown = false, false
		for i = 2, #suggestions do
			if type(suggestions[i][1]) == "table" and suggestions[i][1][1] == "BannedBob" then
				foundNamed = true
			elseif suggestions[i][1] == "503" and suggestions[i][2] == "UNKNOWN [503]" then
				foundUnknown = true
			end
		end
		expect(foundNamed).toBe(true)
		expect(foundUnknown).toBe(true)

		-- allBans parses all unbannable users for caller
		expect(allBansType.transform("ALL")).toBe("all")
		local allForMod = allBansType.parse("all", modSelf)
		expect(type(allForMod)).toBe("table")
		expect(table.find(allForMod, "501") ~= nil).toBe(true)
		expect(table.find(allForMod, "502")).toBeNil()

		local allForAdmin = allBansType.parse("all", adminSelf)
		expect(#allForAdmin).toBe(3)

		-- bans listable with prefix "*" via Argument:prepare()
		expect(bansType.listable).toBe(true)
		local cmd = makeCommandContext(_K, adminUser.UserId)
		local argAll = Argument.new(cmd, { type = "bans", name = "Bans" }, 1, "*")
		local okAll, parsedAll = argAll:prepare()
		expect(okAll).toBe(true)
		expect(#parsedAll).toBe(3)

		-- allBans when only saved bans exist and caller is Mod -> deduplicated error feedback
		table.clear(_K.Data.bans)
		_K.Data.bans["502"] = { "SavedSally", "Exploiting", -1, creatorId }
		_K.Data.bans["504"] = { "SavedSam", "Exploiting", -1, creatorId }
		local savedOnlyAll, savedOnlyErr = allBansType.validate("all", modSelf)
		expect(savedOnlyAll).toBeNil()
		expect(savedOnlyErr).toBe("No permission to unban saved bans")

		-- Empty bans table returns "No targetable user found" on allBans
		table.clear(_K.Data.bans)
		local emptyAll, emptyErr = allBansType.validate("all", adminSelf)
		expect(emptyAll).toBeNil()
		expect(emptyErr).toBe("No targetable user found")

		-- Non-numeric ban key returns "Invalid ban."
		_K.Data.bans["bad_key"] = { "BadKeyUser", "reason", 0, modUser.UserId }
		local badKeyVal, badKeyErr = banType.parse("badkeyuser", adminSelf)
		expect(badKeyVal).toBeNil()
		expect(badKeyErr).toBe("Invalid ban.")
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
		expect(memberType.parse("", adminSelf)).toBe("30")
		expect(memberType.parse("me", adminSelf)).toBe("30")

		-- Exact ID, exact name, partial name
		expect(memberType.parse("10", adminSelf)).toBe("10")
		expect(memberType.parse("bobmod", adminSelf)).toBe("20")
		expect(memberType.parse("alice", adminSelf)).toBe("10")

		-- Invalid member
		local badVal, badErr = memberType.parse("unknown_member", adminSelf)
		expect(badVal).toBeNil()
		expect(badErr).toBe("Invalid member")

		-- Suggestions include "me", "*", and rank-filtered members sorted alphabetically
		local modSuggestions = memberType.suggestions("", 20, { lowerRank = true })
		expect(modSuggestions[1][1][1]).toBe("me")
		local adminSuggestions = memberType.suggestions("", 30, { lowerRank = true })
		expect(adminSuggestions[1][1][1]).toBe("me")
		expect(adminSuggestions[2][1][1]).toBe("*")
		expect(adminSuggestions[3][1][1]).toBe("AliceVip")
		expect(adminSuggestions[4][1][1]).toBe("BobMod")
		local reqSuggestions = memberType.suggestions("", 20, { shouldRequest = true })
		expect(#reqSuggestions >= 2).toBe(true)
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
		expect(foundAlice).toBe(true)
		expect(foundCharlie).toBe(false)

		-- allMembers and members listable via Argument:prepare()
		expect(membersType.listable).toBe(true)
		expect(allMembersType.transform("ALL")).toBe("all")
		local allParsed = allMembersType.parse("all", adminSelf)
		expect(#allParsed).toBe(3)

		local cmd = makeCommandContext(_K, 30)
		local argList = Argument.new(cmd, { type = "members", name = "Members" }, 1, "alice,20")
		local okList, parsedList = argList:prepare()
		expect(okList).toBe(true)
		expect(parsedList).toEqual({ "10", "20" })

		local argStar = Argument.new(cmd, { type = "members", name = "Members" }, 1, "*")
		local okStar, parsedStar = argStar:prepare()
		expect(okStar).toBe(true)
		expect(#parsedStar).toBe(3)

		-- allMembers when caller cannot target any member (VIP with ignoreSelf = true, lowerRank = true)
		local vipNoTargetSelf =
			makeArgSelf(_K, 10, { type = "member", name = "Member", ignoreSelf = true, lowerRank = true }, "all")
		local noAllVal, noAllErr = allMembersType.validate("all", vipNoTargetSelf)
		expect(noAllVal).toBeNil()
		expect(noAllErr).toBe("Can only target yourself\nCan only target 1 user")
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
		expect(roleType.validate("vip", modSelf)).toBe("vip")
		expect(roleType.parse("v", modSelf)).toBe("vip")

		local okSelfRole, errSelfRole = roleType.parse("mod", modSelf)
		expect(okSelfRole).toBeNil()
		expect(errSelfRole).toBe("Invalid role")

		local okHigherRole = roleType.parse("admin", modSelf)
		expect(okHigherRole).toBeNil()

		local okEveryone = roleType.parse("everyone", modSelf)
		expect(okEveryone).toBeNil()

		-- Creator can parse any non-everyone role
		local creatorSelf = makeArgSelf(_K, _K.creatorId, { type = "role", name = "Role" }, "superadmin")
		expect(roleType.parse("super", creatorSelf)).toBe("superadmin")

		-- Suggestions for Admin (rank 3) include mod (rank 2) and vip (rank 1) sorted descending by rank
		local adminSug, rolesTable = roleType.suggestions("", 30)
		expect(rolesTable).toBe(_K.Data.roles)
		expect(#adminSug).toBe(2)
		expect(adminSug[1][1]).toBe("mod")
		expect(adminSug[2][1]).toBe("vip")

		-- Listable roles via Argument:prepare()
		expect(rolesType.listable).toBe(true)
		local cmd = makeCommandContext(_K, 30)
		local arg = Argument.new(cmd, { type = "roles", name = "Roles" }, 1, "vip,mod")
		local ok, parsed = arg:prepare()
		expect(ok).toBe(true)
		expect(parsed).toEqual({ "vip", "mod" })
	end)
end)

describe("DefaultTypes · Team", function()
	test("team and teams handle empty teams, match prefixes, parse Team instances, and suggest", function()
		local h, _K, Argument = newMountedK()
		local teamType = _K.Registry.types.team
		local teamsType = _K.Registry.types.teams

		-- When no teams exist
		local okNoTeams, errNoTeams = teamType.validate("Red", 1)
		expect(okNoTeams).toBe(false)
		expect(errNoTeams).toBe("No teams available")

		-- Seed Red and Blue teams
		local redTeam = h.env.Instance.new("Team", _K.Service.Teams)
		redTeam.Name = "Red"
		local blueTeam = h.env.Instance.new("Team", _K.Service.Teams)
		blueTeam.Name = "Blue"

		expect((teamType.validate("r", 1))).toBe(true)
		expect((teamType.validate("blue", 1))).toBe(true)
		local okInvalid, errInvalid = teamType.validate("Green", 1)
		expect(okInvalid).toBe(false)
		expect(errInvalid).toBe("Invalid team")

		expect(teamType.parse("red", 1)).toBe(redTeam)
		expect(teamType.parse("bl", 1)).toBe(blueTeam)
		expect(function()
			teamType.parse("Green", 1)
		end).toThrow()

		local sugNames, sugInstances = teamType.suggestions("", 1)
		expect(#sugNames).toBe(2)
		expect(#sugInstances).toBe(2)

		-- Listable teams via Argument:prepare()
		expect(teamsType.listable).toBe(true)
		local cmd = makeCommandContext(_K, 1)
		local arg = Argument.new(cmd, { type = "teams", name = "Teams" }, 1, "red,blue")
		local ok, parsed = arg:prepare()
		expect(ok).toBe(true)
		expect(parsed).toEqual({ redTeam, blueTeam })
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
		expect((toolType.validate("sw", 1))).toBe(true)
		expect((toolType.validate("secret", 1))).toBe(false)
		expect(toolType.parse("sword", 1)).toBe(sword)
		expect(toolType.parse("swordb", 1)).toBe(swordBow)
		expect(function()
			toolType.parse("nonexistent_tool", 1)
		end).toThrow()

		-- Suggestions
		local sugNames = toolType.suggestions("", 1)
		expect(table.find(sugNames, "Sword") ~= nil).toBe(true)
		expect(table.find(sugNames, "SwordBow") ~= nil).toBe(true)
		expect(table.find(sugNames, "SecretWand")).toBeNil()

		-- allTools
		expect(allToolsType.transform("ALL")).toBe("all")
		local allParsed = allToolsType.parse()
		expect(type(allParsed)).toBe("table")
		expect(table.find(allParsed, sword) ~= nil).toBe(true)
		expect(table.find(allParsed, swordBow) ~= nil).toBe(true)

		-- tools listable with "all" prefix and individual names via Argument:prepare()
		expect(toolsType.listable).toBe(true)
		local cmd = makeCommandContext(_K, 1)
		local argAll = Argument.new(cmd, { type = "tools", name = "Tools" }, 1, "all")
		local okAll, parsedAll = argAll:prepare()
		expect(okAll).toBe(true)
		expect(table.find(parsedAll, sword) ~= nil).toBe(true)
		expect(table.find(parsedAll, swordBow) ~= nil).toBe(true)

		local argSingleAll = Argument.new(cmd, { type = "tool", name = "Tool" }, 1, "all")
		local okSingleAll, parsedSingleAll = argSingleAll:prepare()
		expect(okSingleAll).toBe(true)
		expect(parsedSingleAll ~= nil).toBe(true)
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
			expect(exact ~= nil).toBe(true)
			expect(exact.name).toBe("customfly")
			expect((cmdType.validate(exact))).toBe(true)
			expect(cmdType.parse(exact)).toBe(exact)

			local byAlias = cmdType.transform("cfly")
			expect(byAlias).toBe(exact)

			-- Substring match on command key and alias
			expect(cmdType.transform("ustomf")).toBe(exact)
			expect(cmdType.transform("fl")).toBe(exact)

			-- Unauthorized command is not returned
			local unauth = cmdType.transform("secretcmd")
			expect(unauth).toBeNil()
			local okUnauth, errUnauth = cmdType.validate(unauth)
			expect(okUnauth).toBe(false)
			expect(errUnauth).toBe("No command with that name could be found.")

			-- Suggestions with onlyShowUsableCommands = true vs false
			_K.client = {
				settings = {
					onlyShowUsableCommands = _K.Flux.signal(true),
				},
			}
			local filteredNames = cmdType.suggestions("")
			expect(table.find(filteredNames, "customfly") ~= nil).toBe(true)
			expect(table.find(filteredNames, "secretcmd")).toBeNil()

			_K.client.settings.onlyShowUsableCommands:set(false)
			local allNames = cmdType.suggestions("")
			expect(table.find(allNames, "secretcmd") ~= nil).toBe(true)
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
		expect(rsType.validate("AlphaLobby")).toBe(dataAlpha)
		expect(rsType.parse("alphalobby")).toBe(dataAlpha)
		expect(rsType.parse("arena")).toBe(dataBeta)

		-- Invalid code
		local badVal, badErr = rsType.validate("NonExistentServer")
		expect(badVal).toBeNil()
		expect(badErr).toBe("Invalid reserveCode")

		-- Suggestions sorted alphabetically
		local suggestions = rsType.suggestions("", 1)
		expect(suggestions).toEqual({ "AlphaLobby", "BetaArena" })

		-- Listable reservedServers via Argument:prepare()
		expect(rssType.listable).toBe(true)
		local cmd = makeCommandContext(_K, 1)
		local arg = Argument.new(cmd, { type = "reservedServers", name = "Servers" }, 1, "alpha,beta")
		local ok, parsed = arg:prepare()
		expect(ok).toBe(true)
		expect(parsed).toEqual({ dataAlpha, dataBeta })
	end)
end)

describe("DefaultTypes · Image & Emote", function()
	test("image and images transform, validate whole numbers, resolve textures, and handle optional/errors", function()
		local h, _K, Argument = newMountedK()
		local imgType = _K.Registry.types.image
		local imgsType = _K.Registry.types.images

		expect(imgType.filterLog).toBe(true)
		expect(imgType.transform("")).toBe(0)
		expect(imgType.transform("12345")).toBe(12345)
		expect(imgType.transform("abc")).toBeNil()

		expect((imgType.validate(12345))).toBe(true)
		expect((imgType.validate(12.5))).toBe(false)
		expect((imgType.validate(nil))).toBe(false)

		-- Seed an Image product in MarketplaceService
		h.env.marketplace.products[777] = {
			AssetId = 777,
			Name = "TestImage",
			AssetTypeId = Enum.AssetType.Image.Value,
			IsForSale = true,
		}
		local selfArg = makeArgSelf(_K, 1, { type = "image", name = "Img" }, "777")
		expect(imgType.parse(777, selfArg)).toBe("rbxassetid://777")

		-- Non-Image asset falls back to rbxthumb
		local thumbTex = imgType.parse(888, selfArg)
		expect(string.find(thumbTex, "rbxthumb://type=Asset&id=888", 1, true) ~= nil).toBe(true)

		-- Optional empty rawArg when getTexture fails
		local mktMethods = rawget(_K.Service.Marketplace, "_methods")
		local origGetInfo = mktMethods.GetProductInfoAsync
		mktMethods.GetProductInfoAsync = function()
			error("network error")
		end
		local optSelf = makeArgSelf(_K, 1, { type = "image", name = "Img", optional = true }, "")
		expect(imgType.parse(0, optSelf)).toBe("")

		local reqSelf = makeArgSelf(_K, 1, { type = "image", name = "Img", optional = false }, "999999")
		local failVal, failErr = imgType.parse(999999, reqSelf)
		expect(failVal).toBeNil()
		expect(failErr).toBe("Failed to load image")

		-- Client fallback placeholder
		_K.IsClient = true
		expect(imgType.parse(999999, reqSelf)).toBe("rbxasset://textures/ui/GuiImagePlaceholder.png")
		_K.IsClient = false
		mktMethods.GetProductInfoAsync = origGetInfo

		-- Suggestions
		expect(imgType.suggestions("12345")).toEqual({ "12345" })
		expect(imgType.suggestions("notnum")).toEqual({})

		-- Listable images
		expect(imgsType.listable).toBe(true)
		local cmd = makeCommandContext(_K, 1)
		local arg = Argument.new(cmd, { type = "images", name = "Images" }, 1, "777,888")
		local ok, parsed = arg:prepare()
		expect(ok).toBe(true)
		expect(#parsed).toBe(2)
	end)

	test("emote and emotes transform, validate, parse numeric ID and catalog name, and suggest", function()
		local h, _K = newMountedK()
		local emoteType = _K.Registry.types.emote
		local emotesType = _K.Registry.types.emotes

		expect(emoteType.filterLog).toBe(true)
		expect(emotesType.listable).toBe(true)

		-- Transform and validate
		expect(emoteType.transform("12345")).toBe(12345)
		expect(emoteType.transform("salute")).toBe("salute")
		expect((emoteType.validate(12345))).toBe(true)
		expect((emoteType.validate("salute"))).toBe(true)
		local okFloat, errFloat = emoteType.validate(12.34)
		expect(okFloat).toBe(false)
		expect(errFloat).toBe("Only whole numbers are valid")
		expect((emoteType.validate(nil))).toBe(false)

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
		-- Exact and partial name lookup
		expect(emoteType.parse("salute", selfArg)).toBe(5001)
		expect(emoteType.parse("stad", selfArg)).toBe(5002)

		-- Numeric emote ID via MarketplaceService + InsertService:LoadAsset
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
		local insertMethods = rawget(_K.Service.Insert, "_methods")
		local origLoadAsset = insertMethods.LoadAsset
		insertMethods.LoadAsset = function(_self: any, id: number)
			local model = h.env.Instance.new("Model")
			local anim = h.env.Instance.new("Animation", model)
			anim.AnimationId = `rbxassetid://{7000 + id}`
			return model
		end
		expect(emoteType.parse(2001, selfArg)).toBe(9001)
		expect(_K.Data.emoteItemFromId[2001] ~= nil).toBe(true)
		expect(_K.Data.emoteItemFromId[2001].animationId).toBe(9001)
		expect(_K.Data.animationToEmoteId[9001]).toBe(2001)
		expect(_K.Data.emoteToAnimationId[2001]).toBe(9001)
		expect(_K.VIP.allowedBulkPurchaseIds[2001]).toBe(true)
		expect(emoteType.parse("danceemote", selfArg)).toBe(9001)
		-- Second call hits emoteToAnimationId cache
		expect(emoteType.parse(2001, selfArg)).toBe(9001)
		-- Offsale emote is not added to allowedBulkPurchaseIds
		expect(emoteType.parse(2002, selfArg)).toBe(9002)
		expect(_K.VIP.allowedBulkPurchaseIds[2002]).toBeNil()
		insertMethods.LoadAsset = origLoadAsset

		-- Optional empty emote (when v does not match any emote and rawArg is "")
		local optSelf = makeArgSelf(_K, 1, { type = "emote", name = "Emote", optional = true }, "")
		expect(emoteType.parse(0, optSelf)).toBe("")

		-- Invalid emote (both unknown string and non-emote numeric ID)
		local badNumVal, badNumErr = emoteType.parse(999999, selfArg)
		expect(badNumVal).toBeNil()
		expect(badNumErr).toBe("Could not parse emote")
		local badVal, badErr = emoteType.parse("unknown_emote_xyz", selfArg)
		expect(badVal).toBeNil()
		expect(badErr).toBe("Could not parse emote")

		-- Suggestions
		local sugNum = emoteType.suggestions("2001")
		expect(sugNum[1]).toBe("2001")
		expect(table.find(sugNum, "Salute") ~= nil).toBe(true)
		expect(table.find(sugNum, "DanceEmote") ~= nil).toBe(true)
	end)
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
			expect(playerType.parse("", adminSelf)).toBe(adminPlr)
			expect(playerType.parse("me", adminSelf)).toBe(adminPlr)

			-- Exact and partial username matching
			expect(playerType.parse("modbravo", adminSelf)).toBe(modPlr)
			expect(playerType.parse("modb", adminSelf)).toBe(modPlr)

			-- Exact and partial DisplayName matching
			expect(playerType.parse("superbravo", adminSelf)).toBe(modPlr)
			expect(playerType.parse("superb", adminSelf)).toBe(modPlr)

			-- Exact and partial _KDisplayName attribute matching
			expect(playerType.parse("nickcharlie", adminSelf)).toBe(vipPlr)
			expect(playerType.parse("nickc", adminSelf)).toBe(vipPlr)

			-- Invalid player
			local badPlr, badPlrErr = playerType.validate("no_such_player", adminSelf)
			expect(badPlr).toBeNil()
			expect(badPlrErr).toBe("Invalid player")

			-- lowerRank check: Mod (20) cannot target Admin (10) when lowerRank = true and commandRequests = false
			_K.Data.settings.commandRequests = false
			local modSelf = makeArgSelf(_K, 20, { type = "player", name = "Target", lowerRank = true }, "adminalpha")
			local lowVal, lowErr = playerType.parse("adminalpha", modSelf)
			expect(lowVal).toBeNil()
			expect(lowErr).toBe("Can only target lower ranks")
			expect(playerType.parse("vipcharlie", modSelf)).toBe(vipPlr)
			_K.Data.settings.commandRequests = true

			-- Suggestions for player and userId (including LocalPlayer sorting, DisplayName, _KDisplayName, and ignoreSelf)
			h.env.Players._props.LocalPlayer = modPlr
			local plrSuggestions = playerType.suggestions("", 20, { lowerRank = false })
			expect(#plrSuggestions > 3).toBe(true)
			expect(plrSuggestions[1][1]).toEqual({ "me", "ModBravo", "SuperBravo" })
			expect(plrSuggestions[1][3]).toBe(modPlr)
			expect(plrSuggestions[2][1]).toEqual({ "AdminAlpha" })
			expect(plrSuggestions[2][3]).toBe(adminPlr)
			expect(plrSuggestions[3][1]).toEqual({ "VipCharlie", "NickCharlie" })
			expect(plrSuggestions[3][3]).toBe(vipPlr)

			-- When _KDisplayName equals Name, it is not duplicated in suggestions
			adminPlr:SetAttribute("_KDisplayName", "AdminAlpha")
			local noSelfSuggestions = playerType.suggestions("", 20, { lowerRank = false, ignoreSelf = true })
			expect(noSelfSuggestions[1][1]).toEqual({ "AdminAlpha" })
			expect(noSelfSuggestions[1][3]).toBe(adminPlr)
			adminPlr:SetAttribute("_KDisplayName", nil)
			h.env.Players._props.LocalPlayer = adminPlr

			local uidSuggestions = userIdType.suggestions("999", 10, { lowerRank = false })
			expect(uidSuggestions[1][1]).toBe("999")
			expect(uidSuggestions[1][3].UserId).toBe(999)

			-- userId online lookup, raw numeric ID, and disconnected userCache lookup
			expect(userIdType.parse("modbravo", adminSelf)).toBe(20)
			expect(userIdType.parse("77777", adminSelf)).toBe(77777)
			local badUid, badUidErr = userIdType.parse("no_such_user", adminSelf)
			expect(badUid).toBeNil()
			expect(badUidErr).toBe("Invalid user")
			-- so does a userId past 2^53, which getUserInfo can't look up
			for _, input in { "1e300", "9007199254740994" } do
				local okHuge, errHuge = userIdType.parse(input, adminSelf)
				expect(okHuge).toBeNil()
				expect(errHuge).toBe("Invalid user")
			end
			expect(userIdType.parse("9007199254740992", adminSelf)).toBe(2 ^ 53)

			-- Disconnect vipPlr -> memoized in userCache -> userId still resolves "vipcharlie" and includes in suggestions
			h.env:removePlayer(30)
			h.env.Players.PlayerRemoving:Fire(vipPlr)
			-- Firing PlayerRemoving a second time cancels previous freeThread and re-memoizes cleanly
			h.env.Players.PlayerRemoving:Fire(vipPlr)
			expect(playerType.parse("vipcharlie", adminSelf)).toBeNil()
			expect(userIdType.parse("vipcharlie", adminSelf)).toBe(30)
			local cachedUidSuggestions = userIdType.suggestions("", 10, { lowerRank = false })
			local foundCachedVip = false
			for _, entry in cachedUidSuggestions do
				if type(entry[3]) == "table" and entry[3].UserId == 30 then
					foundCachedVip = true
				end
			end
			expect(foundCachedVip).toBe(true)
			local nonCachedPlrSuggestions = playerType.suggestions("", 10, { lowerRank = false })
			local foundInPlr = false
			for _, entry in nonCachedPlrSuggestions do
				if type(entry[3]) == "table" and entry[3].UserId == 30 then
					foundInPlr = true
				end
			end
			expect(foundInPlr).toBe(false)

			-- Re-adding player clears userCache entry
			vipPlr = h.env:addPlayer(30, "VipCharlie")
			attachPlayerHelpers(h.env, vipPlr)

			-- userId parse when parseIndividual fails with non-"Invalid player" reason (ignoreSelf)
			local noSelfArg = makeArgSelf(_K, 10, { type = "userId", name = "Target", ignoreSelf = true }, "me")
			local noSelfVal, noSelfErr = userIdType.parse("me", noSelfArg)
			expect(noSelfVal).toBeNil()
			expect(noSelfErr).toBe("Can't target yourself")

			-- players and userId postParse with nested tables and direct values
			expect(playersType.postParse({ { adminPlr, modPlr }, vipPlr })).toEqual({ adminPlr, modPlr, vipPlr })
			expect(userIdType.postParse({ { adminPlr, { UserId = 20 }, 30 }, 40 })).toEqual({ 10, 20, 30, 40 })

			-- players and userIds postParse flattening via Argument:prepare()
			local cmd = makeCommandContext(_K, 10)
			local argPlayers = Argument.new(cmd, { type = "players", name = "Targets" }, 1, "me,modbravo")
			local okPlayers, parsedPlayers = argPlayers:prepare()
			expect(okPlayers).toBe(true)
			expect(parsedPlayers).toEqual({ adminPlr, modPlr })

			local argUserIds = Argument.new(cmd, { type = "userIds", name = "Targets" }, 1, "me,modbravo,88888")
			local okUserIds, parsedUserIds = argUserIds:prepare()
			expect(okUserIds).toBe(true)
			expect(parsedUserIds).toEqual({ 10, 20, 88888 })
			expect(playersType.listable).toBe(true)
			expect(userIdsType.listable).toBe(true)
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
			expect(okStar).toBe(true)
			expect(#starList).toBe(3)
			local okAll, allList = parsePlayersArg("all")
			expect(okAll).toBe(true)
			expect(#allList).toBe(3)
			expect(#_K.Registry.types.allPlayers.suggestions("", nil)).toBe(1)

			-- 2. Others.luau (others)
			local okOthers, othersList = parsePlayersArg("others")
			expect(okOthers).toBe(true)
			expect(#othersList).toBe(2)
			expect(table.find(othersList, adminPlr)).toBeNil()

			-- 3. Role.luau (@mod, @admin, invalid @unknownrole)
			local okRole, roleList = parsePlayersArg("@mod")
			expect(okRole).toBe(true)
			expect(roleList).toEqual({ modPlr })
			local okBadRole = parsePlayersArg("@nonexistent")
			expect(okBadRole).toBe(false)
			local okEmptyRole = parsePlayersArg("@vip")
			expect(okEmptyRole).toBe(false)
			expect(type(_K.Registry.types.rolePlayers.suggestions("", nil))).toBe("table")

			-- 4. Team.luau (%Red, %Blue, empty %Green, invalid %Purple)
			local okRed, redList = parsePlayersArg("%red")
			expect(okRed).toBe(true)
			expect(redList).toEqual({ adminPlr, modPlr })
			local okBlue, blueList = parsePlayersArg("%blue")
			expect(okBlue).toBe(true)
			expect(blueList).toEqual({ guestPlr })
			expect((parsePlayersArg("%green"))).toBe(false)
			expect((parsePlayersArg("%purple"))).toBe(false)
			expect(#_K.Registry.types.teamPlayers.suggestions("", nil)).toBe(3)

			-- 5. Random.luau (~, ~1, ~2, invalid ~abc)
			local okRandDefault, randDefault = parsePlayersArg("~")
			expect(okRandDefault).toBe(true)
			expect(#randDefault).toBe(1)
			local okRand2, rand2 = parsePlayersArg("~2")
			expect(okRand2).toBe(true)
			expect(#rand2).toBe(2)
			expect((parsePlayersArg("~abc"))).toBe(false)

			-- 6. Special.luau ($all, $others, $admins, $nonadmins, $friends, $close, $far, $distance, $group, invalid)
			local okSpecAll, specAll = parsePlayersArg("$all")
			expect(okSpecAll).toBe(true)
			expect(#specAll).toBe(3)

			local okSpecOthers, specOthers = parsePlayersArg("$others")
			expect(okSpecOthers).toBe(true)
			expect(#specOthers).toBe(2)

			local okAdmins, specAdmins = parsePlayersArg("$admins")
			expect(okAdmins).toBe(true)
			expect(#specAdmins).toBe(2)

			local okNonAdmins, specNonAdmins = parsePlayersArg("$nonadmins")
			expect(okNonAdmins).toBe(true)
			expect(specNonAdmins).toEqual({ guestPlr })

			local okFriends, specFriends = parsePlayersArg("$friends")
			expect(okFriends).toBe(true)
			expect(specFriends).toEqual({ modPlr })

			local okClose, specClose = parsePlayersArg("$close")
			expect(okClose).toBe(true)
			expect(#specClose).toBe(2) -- adminPlr (0) and modPlr (30) <= 100

			local okFar, specFar = parsePlayersArg("$far")
			expect(okFar).toBe(true)
			expect(specFar).toEqual({ guestPlr }) -- guestPlr (150) > 100

			-- Distance matcher: $distance<50 (adminPlr at 0, modPlr at 30) and $distance>100 (guestPlr at 150)
			local okDistNear, distNear = parsePlayersArg("$distance<50")
			expect(okDistNear).toBe(true)
			expect(#distNear).toBe(2)

			local okDistFar, distFar = parsePlayersArg("$distance>100")
			expect(okDistFar).toBe(true)
			expect(distFar).toEqual({ guestPlr })

			expect((parsePlayersArg("$distance<bad"))).toBe(false)

			-- Characterless player during $close, $far, $distance
			local savedChar = guestPlr.Character
			guestPlr.Character = nil
			expect((parsePlayersArg("$close"))).toBe(true)
			expect((parsePlayersArg("$far"))).toBe(false)
			expect((parsePlayersArg("$distance>100"))).toBe(false)
			guestPlr.Character = savedChar

			-- Group matcher: $group=100=, $group=100>=50, $group=100>51, $group=100<=50, $group=100=50, $group=100<100
			local okGrpAny, grpAny = parsePlayersArg("$group=100=")
			expect(okGrpAny).toBe(true)
			expect(#grpAny).toBe(2)

			local okGrpGe, grpGe = parsePlayersArg("$group=100>=50")
			expect(okGrpGe).toBe(true)
			expect(#grpGe).toBe(2)

			local okGrpGt, grpGt = parsePlayersArg("$group=100>50")
			expect(okGrpGt).toBe(true)
			expect(grpGt).toEqual({ adminPlr })

			local okGrpLe, grpLe = parsePlayersArg("$group=100<=50")
			expect(okGrpLe).toBe(true)
			expect(grpLe).toEqual({ modPlr })

			local okGrpLt, grpLt = parsePlayersArg("$group=100<100")
			expect(okGrpLt).toBe(true)
			expect(grpLt).toEqual({ modPlr })

			expect((parsePlayersArg("$group=100<50"))).toBe(false)
			expect((parsePlayersArg("$group=100>255"))).toBe(false)

			local okGrpEq, grpEq = parsePlayersArg("$group=100=50")
			expect(okGrpEq).toBe(true)
			expect(grpEq).toEqual({ modPlr })

			expect((parsePlayersArg("$group=invalid"))).toBe(false)
			expect((parsePlayersArg("$fps"))).toBe(false)
			expect((parsePlayersArg("!me"))).toBe(false)
			expect((parsePlayersArg("!@vip"))).toBe(false)

			-- Untargetable feedback branches across All, Others, Random, Role, Team, Special
			-- Guest (30, everyone role) has onlyTargetSelf = true and limits.targets = 1
			_K.Auth.userRoleAdd(10, "mod")
			local selfAndLimitErr = "Can only target yourself\nCan only target 1 user"
			for _, raw in { "*", "others", "~1", "@mod", "%red", "$all" } do
				local okU, errU = parsePlayersArg(raw, 30, { ignoreSelf = true })
				expect(okU).toBe(false)
				expect(errU.message).toBe(selfAndLimitErr)
			end

			local specSug = _K.Registry.types.specialPlayers.suggestions("", nil)
			expect(#specSug >= 9).toBe(true)

			-- userIds with prefix matchers flattens players into UserIds
			local cmd = makeCommandContext(_K, 10)
			local uidArg = Argument.new(cmd, { type = "userIds", name = "Ids" }, 1, "%blue,@mod")
			local okUids, parsedUids = uidArg:prepare()
			expect(okUids).toBe(true)
			expect(parsedUids).toEqual({ 30, 10, 20 })

			-- Others when only 1 player is online returns "No other players online"
			h.env:removePlayer(20)
			h.env:removePlayer(30)
			local okSoloOthers, errSoloOthers = parsePlayersArg("others", 10)
			expect(okSoloOthers).toBe(false)
			expect(errSoloOthers.message).toBe("No other players online")
		end
	)
end)

return {}
