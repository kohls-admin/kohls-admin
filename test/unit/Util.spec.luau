local Harness = require("./Harness")
local sert = require("../sert")

local describe, test = sert.describe, sert.test
local prop = sert.prop

describe("Util · String", function()
	test("trim, trimStart, and trimEnd strip ASCII whitespace", function()
		local String = Harness.shared():requireUtil().String
		sert.eq(String.trim("  \t\nhello world\r\n "), "hello world")
		sert.eq(String.trimStart("  hello  "), "hello  ")
		sert.eq(String.trimEnd("  hello  "), "  hello")
		sert.eq(String.trim("   "), "")
	end)

	prop("escapePattern makes any literal match itself via string.find", function(g)
		local String = Harness.shared():requireUtil().String
		local raw = g:string("abc123().%+-*?[]^$", 1, 24)
		local prefix = g:string("xyz", 0, 8)
		local suffix = g:string("xyz", 0, 8)
		local haystack = prefix .. raw .. suffix
		local escaped = String.escapePattern(raw)
		local s, e = string.find(haystack, escaped)
		sert.eq(s, #prefix + 1)
		sert.eq(e, #prefix + #raw)
	end, { runs = 80 })

	test("escapeRichText and unescapeRichText satisfy codec round-trip laws", function()
		local String = Harness.shared():requireUtil().String
		sert.laws.codec({
			name = "String.RichText",
			gen = function(g)
				return g:string("ab<>\"'&123 ", 0, 32)
			end,
			encode = String.escapeRichText,
			decode = String.unescapeRichText,
		}, { runs = 60 })
	end)

	test("stripQuotes, toFlag, and splitOutsideQuotes handle quoted segments", function()
		local String = Harness.shared():requireUtil().String
		sert.eq(String.stripQuotes('"hello"'), "hello")
		sert.eq(String.stripQuotes("`world`"), "world")
		sert.eq(String.stripQuotes("plain"), "plain")
		sert.eq(#String.toFlag("US") > 0, true)
		sert.eq(String.toFlag(""), "")

		local parts = String.splitOutsideQuotes('cmd "arg with spaces" second', " ")
		sert.eq(#parts, 3)
		sert.eq(parts[1], "cmd")
		sert.eq(parts[2], '"arg with spaces"')
		sert.eq(parts[3], "second")
		sert.eq(String.splitOutsideQuotes(nil :: any), {})
	end)

	prop("levenshteinDistance satisfies metric axioms (identity, symmetry, triangle inequality)", function(g)
		local String = Harness.shared():requireUtil().String
		local a = g:string("abcd", 0, 10)
		local b = g:string("abcd", 0, 10)
		local c = g:string("abcd", 0, 10)

		sert.eq(String.levenshteinDistance(a, a), 0)
		local dab = String.levenshteinDistance(a, b)
		local dba = String.levenshteinDistance(b, a)
		sert.eq(dab, dba)
		if a ~= b then
			sert.eq(dab > 0, true)
		end
		local dbc = String.levenshteinDistance(b, c)
		local dac = String.levenshteinDistance(a, c)
		sert.eq(dac <= dab + dbc, true)
	end, { runs = 60 })

	test("filterResult, filterForBroadcast, and filterForUser handle normal and error fallback paths", function()
		local h = Harness.newEnv()
		local Util = h:requireUtil()
		local hString = Util.String
		local p1 = h.env:addPlayer(1, "Sender")
		h.env:addPlayer(2, "Receiver")

		local ok, res = hString.filterResult("hello", 1)
		sert.eq(ok, true)
		sert.eq(hString.filterResultForBroadcast(res, 1), "hello")
		sert.eq(hString.filterResultForUser(res, p1.UserId, 2), "hello")
		sert.eq(hString.filterResultForUser(res, 9999, 2), "hello")

		-- Error string passed directly to filterResultForBroadcast / filterResultForUser
		sert.eq(hString.filterResultForBroadcast("error msg", 1), "[Filter Error]")
		sert.eq(hString.filterResultForUser("error msg", 1, 2), "[Filter Error]")

		-- Broken filterResult object where methods throw
		local brokenResult: any = {
			GetNonChatStringForBroadcastAsync = function()
				error("broadcast fail")
			end,
			GetNonChatStringForUserAsync = function()
				error("user fail")
			end,
		}
		sert.eq(hString.filterResultForBroadcast(brokenResult, 1), "[Filter Error]")
		sert.eq(hString.filterResultForUser(brokenResult, 1, 2), "[Filter Error]")

		-- Same-user shortcut in filterForUser
		sert.eq(hString.filterForUser("secret", 1, 1), "secret")
		sert.eq(hString.filterForBroadcast("hello", 1), "hello")
		sert.eq(hString.filterForUser("hello", 1, 2), "hello")

		-- TextService:FilterStringAsync failure fallback -> hashes ("#")
		local TextService = h.env.game:GetService("TextService")
		local textMethods = rawget(TextService, "_methods")
		local origFilter = textMethods.FilterStringAsync
		textMethods.FilterStringAsync = function()
			error("TextService down")
		end
		sert.eq(hString.filterForBroadcast("hello", 1), "#####")
		sert.eq(hString.filterForUser("world!", 1, 2), "######")

		-- FilterStringAsync returns object whose GetNonChatStringForBroadcastAsync throws
		textMethods.FilterStringAsync = function()
			return brokenResult
		end
		sert.eq(hString.filterForBroadcast("abc", 1), "###")
		textMethods.FilterStringAsync = origFilter
	end)
end)

describe("Util · Table", function()
	test("concat, countKeys, toHashMap, map, and isArray", function()
		local Table = Harness.shared():requireUtil().Table
		sert.eq(Table.concat({ 1, "a", true }, ","), "1,a,true")
		sert.eq(Table.countKeys({ a = 1, b = 2, c = 3 }), 3)
		sert.eq(Table.toHashMap({ "x", "y" }), { x = true, y = true })
		sert.eq(
			Table.map({ 1, 2, 3 }, function(v)
				return v * 10
			end),
			{ 10, 20, 30 }
		)
		sert.eq(Table.isArray({ 10, 20, 30 }), true)
		sert.eq(Table.isArray({ a = 1 }), false)
	end)

	test("merge, mergeList, deepCompare, deepMerge, and deepCopy isolation", function()
		local Table = Harness.shared():requireUtil().Table
		local dst: { [string]: any } = { a = 1, nested = { x = 10, arr = { 1, 2 } } }
		local copy = Table.deepCopy(dst)
		sert.eq(Table.deepCompare(dst, copy), true)
		copy.nested.x = 99
		sert.eq(dst.nested.x, 10)
		sert.eq(Table.deepCompare(dst, copy), false)
		sert.eq(Table.deepCompare(1, { 1 }), false)
		sert.eq(Table.deepCompare({ 1 }, 1), false)
		sert.eq(Table.deepCompare(1, 2), false)
		local cyclic: { [string]: any } = {}
		cyclic.self = cyclic
		sert.eq(Table.deepCompare(cyclic, cyclic), true)

		Table.deepMerge(dst, { b = 2, nested = { y = 20, arr = { 3 } } }, true)
		sert.eq(dst.b, 2)
		sert.eq(dst.nested.x, 10)
		sert.eq(dst.nested.y, 20)
		sert.eq(dst.nested.arr, { 1, 2, 3 })

		local mixedDst: { [string]: any } = { a = { x = 1 }, b = 5 }
		Table.deepMerge(mixedDst, { a = 5, b = { y = 2 } })
		sert.eq(mixedDst.a, 5)
		sert.eq(mixedDst.b, { y = 2 })

		-- deepMerge with appendArrays = true when target is a non-array dictionary
		local nonArr: { [any]: any } = { key = "val" }
		Table.deepMerge(nonArr, { "elem1", "elem2" }, true)
		sert.eq(nonArr.key, "val")
		sert.eq(nonArr[1], "elem1")
		sert.eq(nonArr[2], "elem2")

		local list = { 1, 2 }
		Table.mergeList(list, { 3, 4 })
		sert.eq(list, { 1, 2, 3, 4 })
		sert.eq(Table.merge({ a = 1 }, { b = 2 }), { a = 1, b = 2 })
	end)

	test("fastRemove multi-count range removal, settle sparse tables, and shuffle", function()
		local Table = Harness.shared():requireUtil().Table
		local arr = { "a", "b", "c", "d", "e", "f" }
		Table.fastRemove(arr, 2, 4)
		sert.eq(arr, { "a", "e", "f" })
		Table.fastRemove(arr, 5, 10)
		sert.eq(arr, { "a", "e", "f" })
		Table.fastRemove(arr, 2, 10)
		sert.eq(arr, { "a" })

		local sparse = { [1] = "x", [3] = "y", [6] = "z" }
		Table.settle(sparse)
		sert.eq(sparse, { "x", "y", "z" })

		local items = { 1, 2, 3, 4, 5, 6, 7, 8 }
		local shuffled = Table.shuffle(table.clone(items))
		sert.eq(#shuffled, #items)
		table.sort(shuffled)
		sert.eq(shuffled, items)
	end)

	prop("fastRemove, settle, and shuffle preserve expected elements", function(g)
		local Table = Harness.shared():requireUtil().Table
		local n = g:int(2, 12)
		local arr = {}
		local sparse = {}
		local expectedRemaining = {}
		local idx = g:int(1, n)
		for i = 1, n do
			arr[i] = i
			sparse[i] = i
			if i ~= idx then
				table.insert(expectedRemaining, i)
			end
		end
		Table.fastRemove(arr, idx)
		sert.eq(arr, expectedRemaining)

		sparse[idx] = nil
		Table.settle(sparse)
		sert.eq(sparse, expectedRemaining)

		local shuffled = Table.shuffle(table.clone(arr))
		sert.eq(#shuffled, #arr)
		table.sort(shuffled)
		sert.eq(shuffled, expectedRemaining)
	end, { runs = 40 })
end)

describe("Util · Time & Logger", function()
	test("Time.fromUnit, Time.clock, and Time.readable", function()
		local Time = Harness.shared():requireUtil().Time
		sert.eq(Time.fromUnit("m"), 60)
		sert.eq(Time.fromUnit("mss"), 1 / 1000)
		sert.eq(Time.fromUnit("hours"), 3600)
		sert.eq(Time.fromUnit("d"), 86400)
		sert.eq(Time.fromUnit("."), nil)
		sert.eq(Time.fromUnit("invalid_unit_xyz"), nil)

		sert.eq(Time.clock(45), "45")
		sert.eq(Time.clock(125), "02:05")
		sert.eq(Time.clock(3661), "01:01:01")
		sert.eq(Time.readable(3661), "1 hour, 1 minute, 1 second")
		sert.eq(Time.readable(172800), "2 days")
	end)

	test("Logger level codec and sortTime order laws", function()
		local Logger = Harness.shared():requireUtil().Logger
		local logger = Logger.new(false)
		local levels = {
			"INFO",
			"WARN",
			"ERROR",
			"DEBUG",
			"CHAT",
			"COMMAND",
			"PURCHASE",
			"DAMAGE",
			"DEATH",
			"KILL",
			"JOIN",
			"LEAVE",
		}

		sert.laws.codec({
			name = "Logger.level",
			gen = function(g)
				return g:pick(levels)
			end,
			encode = function(lv)
				return logger:encode(lv)
			end,
			decode = function(enc)
				return logger:decode(enc)
			end,
		}, { runs = 40 })

		sert.laws.order({
			name = "Logger.sortTime",
			gen = function(g)
				return { "msg", "INFO", g:int(1, 10000) }
			end,
			lt = Logger.sortTime,
			eq = function(a, b)
				return a[3] == b[3]
			end,
		}, { runs = 40 })

		sert.eq(logger:log("ignored debug", "DEBUG"), nil)
		local debugLogger = Logger.new(true)
		local entry = debugLogger:log("hello", "INFO", -42)
		sert.eq(entry ~= nil, true)
		sert.eq((entry :: any)[1], "hello")
		sert.eq((entry :: any)[4], 42)
		sert.eq(#debugLogger.logs, 1)
	end)
end)

describe("Util · Queue, Signal, Tasks, Retry, Defer, Function, Rollout, Suggest", function()
	prop("Queue FIFO matches reference array across random Enqueue/Dequeue sequences", function(g)
		local Queue = Harness.shared():requireUtil().Queue
		local q = Queue.new()
		local ref = {}
		local steps = g:int(5, 30)
		for _ = 1, steps do
			if #ref == 0 or g:bool() then
				local val = g:int(1, 1000)
				q:Enqueue(val)
				table.insert(ref, val)
			else
				local expected = table.remove(ref, 1)
				sert.eq(q:Dequeue(), expected)
			end
			sert.eq(q:IsEmpty(), #ref == 0)
		end
		while not q:IsEmpty() do
			sert.eq(q:Dequeue(), table.remove(ref, 1))
		end
		sert.throws(function()
			q:Dequeue()
		end)
	end, { runs = 40 })

	test("Signal Connect, Once, Fire, mid-fire Disconnect, Wait, and Destroy", function()
		local h = Harness.newEnv()
		local Util = h:requireUtil()
		local sig = Util.Signal.new()
		local seen = {}
		local c1: any
		c1 = sig:Connect(function(v)
			table.insert(seen, "c1:" .. tostring(v))
		end)
		-- c2 is added after c1 (so c2 is _head and runs BEFORE c1); disconnecting c1 inside c2 exercises
		-- the mid-fire Disconnected branch (lines 97-98) and non-head prevConn._next unlink (line 52)
		local c2 = sig:Connect(function(v)
			table.insert(seen, "c2:" .. tostring(v))
			if v == 1 and c1 then
				c1:Disconnect()
			end
		end)
		local onceConn = sig:Once(function(v)
			table.insert(seen, "once:" .. tostring(v))
		end)

		-- Also test non-head disconnect explicitly before firing
		local cExtra1 = sig:Connect(function() end)
		local cExtra2 = sig:Connect(function() end)
		cExtra1:Disconnect() -- cExtra2 is _head, so cExtra1 has prevConn == cExtra2 (line 52)
		cExtra2:Disconnect()

		sig:Fire(1)
		sert.eq(onceConn.Connected, false)
		sert.eq(c1.Connected, nil)
		sig:Fire(2)
		c2:Disconnect()
		-- Calling Disconnect a second time is a safe no-op
		c2:Disconnect()
		sig:Fire(3)
		sert.eq(seen, { "once:1", "c2:1", "c2:2" })

		local waited, waited2 = nil, nil
		h.env.task.spawn(function()
			waited, waited2 = sig:Wait()
		end)
		sig:Fire("woken", 99)
		sert.eq(waited, "woken")
		sert.eq(waited2, 99)

		-- Destroy cancels any suspended Wait threads and clears all connections
		local neverWoken = false
		h.env.task.spawn(function()
			sig:Wait()
			neverWoken = true
		end)
		sig:Connect(function()
			neverWoken = true
		end)
		sig:Destroy()
		sig:Fire("after_destroy")
		sert.eq(neverWoken, false)
	end)

	test("Tasks.add, wait, error warning, and waitForFirst", function()
		local h = Harness.newEnv()
		local Util = h:requireUtil()
		local results: any = nil
		h.env.task.spawn(function()
			local tasks = Util.Tasks.new()
			tasks:add(function(x)
				h.env.task.wait(0.01)
				return x + 1
			end, 10)
			tasks:add(function(x)
				h.env.task.wait(0.01)
				return x * 2
			end, 20)
			tasks:add(function()
				h.env.task.wait(0.01)
				error("task failure inside wait")
			end)
			results = tasks:wait()
		end)
		h.env:step(0.05)
		sert.eq(#results, 3)
		sert.eq(results[1][1], true)
		sert.eq(results[1][2], 11)
		sert.eq(results[2][1], true)
		sert.eq(results[2][2], 40)
		sert.eq(results[3][1], false)

		local firstOk, firstVal
		h.env.task.spawn(function()
			local tasks = Util.Tasks.new()
			tasks:add(function()
				h.env.task.wait(0.01)
				return "fast"
			end)
			firstOk, firstVal = tasks:waitForFirst()
		end)
		h.env:step(0.05)
		sert.eq(firstOk, true)
		sert.eq(firstVal, "fast")
	end)

	test("Retry succeeds after transient failures, stops at attempt limit, and returns false on 0 attempts", function()
		local Retry = Harness.shared():requireUtil().Retry
		local calls = 0
		local ok, val = Retry(function(arg)
			calls += 1
			if calls < 3 then
				error("transient")
			end
			return arg * 2
		end, 4, 0.01, 21)
		sert.eq(ok, true)
		sert.eq(val, 42)
		sert.eq(calls, 3)

		local failCalls = 0
		local ok2 = Retry(function()
			failCalls += 1
			error("permanent")
		end, 3, 0.01)
		sert.eq(ok2, false)
		sert.eq(failCalls, 3)

		-- 0 attempts skips loop and returns false (line 21 of Retry.luau)
		sert.eq(
			Retry(function()
				return true
			end, 0),
			false
		)
	end)

	test("Defer, Function.debounce/throttle, and Rollout", function()
		local h = Harness.newEnv()
		local Util = h:requireUtil()
		Util.Defer.reset(0.01)
		Util.Defer.wait(0.01)

		local debouncedArgs = {}
		local debounced = Util.Function.debounce(0.02, function(a, b)
			table.insert(debouncedArgs, { a, b })
		end)
		debounced("first", 1)
		debounced("second", 2)
		sert.eq(#debouncedArgs, 0)
		h.env:step(0.03)
		sert.eq(#debouncedArgs, 1)
		sert.eq(debouncedArgs[1], { "second", 2 })

		local throttledCalls = {}
		local throttled = Util.Function.throttle(0.05, function(v)
			table.insert(throttledCalls, v)
		end)
		throttled("immediate")
		throttled("replaced_trailing")
		throttled("final_trailing")
		sert.eq(throttledCalls, { "immediate" })
		h.env:step(0.06)
		sert.eq(throttledCalls, { "immediate", "final_trailing" })
		throttled("post_trailing")
		sert.eq(throttledCalls, { "immediate", "final_trailing" })
		h.env:step(0.06)
		sert.eq(throttledCalls, { "immediate", "final_trailing", "post_trailing" })

		local r = Util.Rollout.new("2025-01-01", "2025-12-31", "TestFeature", 42, 1)
		sert.eq(type(r:test(12345)), "boolean")
		r:setFFlagDictionary({ TestFeature = true })
		sert.eq(r:test(12345), true)
		r:setFFlagDictionary({ TestFeature = false })
		sert.eq(r:test(12345), false)
		r:setFFlagDictionary(nil)

		sert.eq(Util.Rollout.new("2099-01-01", "2099-12-31", "FutureRollout", 1, 1):test(1), false)
		local earlyRollout = Util.Rollout.new("2000-01-01", "2099-12-31", "EarlyRollout", 1, 1)
		local earlyHits = 0
		for sampleId = 1, 100 do
			if earlyRollout:test(sampleId) then
				earlyHits += 1
			end
		end
		sert.eq(earlyHits < 50, true)
	end)

	test(
		"Suggest.new and Suggest.query rank exact, prefix, substring, and levenshtein matches and validate inputs",
		function()
			local h = Harness.newEnv()
			local Suggest = h:requireUtil().Suggest

			local names = { "teleport", "tempban", "kick", "ban", " blind " }
			local exact = Suggest.query("ban", names)
			sert.eq(exact[1][1], "ban")
			sert.eq(exact[2][1], "tempban")

			local prefix = Suggest.query("tele", names)
			sert.eq(prefix[1][1], "teleport")

			local typo = Suggest.query("kic", names)
			sert.eq(typo[1][1], "kick")

			local lev = Suggest.query("kixk", names)
			sert.eq(lev[1][1], "kick")

			local tableSuggest = Suggest.query("alp", { { "alpha", "Alpha Display", "alpha_key" } })
			sert.eq(tableSuggest[1][1], "alpha")
			sert.eq(tableSuggest[1][2], "Alpha Display")
			sert.eq(tableSuggest[1][3], "alpha_key")

			local enumNames, enumInsts = Suggest.new(h.env.globals.Enum.Font)
			sert.eq(#enumNames > 0, true)
			sert.eq(#enumInsts > 0, true)

			local folder = h.env.Instance.new("Folder")
			local child = h.env.Instance.new("Part", folder)
			child.Name = "AlphaPart"
			local folderNames = Suggest.new(folder)
			sert.eq(folderNames[1], "AlphaPart")

			-- Table of tables with .Name / .name fields (line 115 of Suggest.luau)
			local tblNames, tblItems = Suggest.new({ { Name = "ObjA" }, { name = "ObjB" } })
			sert.eq(tblNames, { "ObjA", "ObjB" })
			sert.eq(#tblItems, 2)

			-- Empty table returns empty names
			local emptyNames = Suggest.new({})
			sert.eq(emptyNames, {})

			-- Invalid element type or non-table/Enum/Instance argument throws
			sert.throws(function()
				Suggest.new({ 12345 } :: any)
			end)
			sert.throws(function()
				Suggest.new(12345 :: any)
			end)
		end
	)
end)

describe(
	"Util · Property, Humanoid, MemoryStore, iterPageItems, SafePlayerAdded, SafeTeleport, getTexture, getUserInfo, Remote",
	function()
		test("Property.override locks property against external edits and cleans up on Destroying", function()
			local h = Harness.newEnv()
			local Util = h:requireUtil()
			local part = h.env.Instance.new("Part")
			part.Name = "Original"

			Util.Property.override(part, "Name", "Locked")
			sert.eq(part.Name, "Locked")

			-- Updating an already-overridden property updates the lock target
			Util.Property.override(part, "Name", "Relocked")
			sert.eq(part.Name, "Relocked")

			part.Name = "UpdatedUnderlying"
			sert.eq(part.Name, "Relocked")

			Util.Property.reset(part, "Name")
			sert.eq(part.Name, "UpdatedUnderlying")

			-- Destroying an instance cleans up active overrides
			Util.Property.override(part, "Name", "BeforeDestroy")
			sert.eq(Util.Property.cache[part] ~= nil, true)
			part:Destroy()
			sert.eq(Util.Property.cache[part], nil)
		end)

		test(
			"Humanoid description helpers save original attributes and restore on resetDescription (with HumanoidRootPart and PrimaryPart fallback)",
			function()
				local h = Harness.newEnv()
				local Util = h:requireUtil()
				local player = h.env:addPlayer(101, "Alice")

				-- Early return when character/humanoid is missing
				Util.Humanoid.attributeDescription(player, "Shirt", 999)
				Util.Humanoid.reapplyDescription(player)

				local character = h.env.Instance.new("Model")
				local root = h.env.Instance.new("Part", character)
				root.Name = "HumanoidRootPart"
				local fire = h.env.Instance.new("Fire", root)
				fire.Name = "_KFire"
				local hum = h.env.Instance.new("Humanoid", character)
				local desc = h.env.Instance.new("HumanoidDescription", hum)
				desc.Shirt = 111
				player.Character = character

				local applySpy = sert.spy(Util.Humanoid, "applyDescription")
				Util.Humanoid.reapplyDescription(player)
				sert.eq(applySpy.callCount, 0)

				Util.Humanoid.attributeDescription(player, "Shirt", 999)
				sert.eq(desc.Shirt, 999)
				sert.eq(player:GetAttribute("_KShirtOriginal"), 111)
				sert.eq(applySpy.callCount, 1)

				desc.Shirt = 111
				Util.Humanoid.reapplyDescription(player)
				sert.eq(desc.Shirt, 999)
				sert.eq(applySpy.callCount, 2)

				-- Also test _KHumanoidDescription restoration on player
				local savedDesc = h.env.Instance.new("HumanoidDescription", player)
				savedDesc.Name = "_KHumanoidDescription"
				savedDesc.Shirt = 222

				Util.Humanoid.resetDescription(player)
				sert.eq(hum:FindFirstChildOfClass("HumanoidDescription"), savedDesc)
				sert.eq(savedDesc.Name, "HumanoidDescription")
				sert.eq(savedDesc.Shirt, 111)
				sert.eq(player:GetAttribute("_KShirtOriginal"), nil)
				sert.eq(applySpy.callCount, 3)
				sert.eq(root:FindFirstChild("_KFire"), nil)

				-- Fallback to character.PrimaryPart when HumanoidRootPart is absent (line 69 of Humanoid.luau)
				root.Name = "Torso"
				character.PrimaryPart = root
				local smoke = h.env.Instance.new("Smoke", root)
				smoke.Name = "_KSmoke"
				savedDesc:Destroy()
				Util.Humanoid.resetDescription(player)
				sert.eq(applySpy.callCount, 3)
				sert.eq(root:FindFirstChild("_KSmoke"), nil)
				applySpy:restore()
			end
		)

		test(
			"MemoryStore.getItemsFromHashMap, iterPageItems multi-page pagination, and SafePlayerAdded lifecycle",
			function()
				local h = Harness.newEnv()
				local Util = h:requireUtil()
				-- Multi-page mock exercising AdvanceToNextPageAsync in both iterPageItems and MemoryStore.getItemsFromHashMap
				local function makeMultiPages()
					local pageIdx = 1
					local getCalls = 0
					local pageData = {
						{ { key = "p1", value = 10 } },
						{ { key = "p2", value = 20 } },
					}
					return {
						IsFinished = false,
						GetCurrentPage = function()
							getCalls += 1
							assert(getCalls <= #pageData + 1, "AdvanceToNextPageAsync was not called")
							return pageData[pageIdx]
						end,
						AdvanceToNextPageAsync = function(self)
							assert(not self.IsFinished, "No more pages")
							pageIdx += 1
							self.IsFinished = pageIdx >= #pageData
						end,
					}
				end

				local seenPages = {}
				for item, pageNum in Util.iterPageItems(makeMultiPages() :: any) do
					seenPages[item.key] = { val = item.value, page = pageNum }
				end
				sert.eq(seenPages.p1, { val = 10, page = 1 })
				sert.eq(seenPages.p2, { val = 20, page = 2 })

				-- iterPageItems retries transient AdvanceToNextPageAsync failure
				local retryPages = makeMultiPages()
				local origAdvance = retryPages.AdvanceToNextPageAsync
				local advanceAttempts = 0
				retryPages.AdvanceToNextPageAsync = function(self)
					advanceAttempts += 1
					if advanceAttempts == 1 then
						error("transient pagination error")
					end
					return origAdvance(self)
				end
				local retrySeen = {}
				h.env.task.spawn(function()
					for item, pageNum in Util.iterPageItems(retryPages :: any) do
						retrySeen[item.key] = { val = item.value, page = pageNum }
					end
				end)
				h.env:advance(5)
				sert.eq(advanceAttempts, 2)
				sert.eq(retrySeen.p1, { val = 10, page = 1 })
				sert.eq(retrySeen.p2, { val = 20, page = 2 })

				-- MemoryStore.getSharded returns (true, nil) when shards are empty vs (false, nil) when all GetAsync calls fail
				local probeCount = 0
				local emptyShardMap: any = {
					GetAsync = function()
						probeCount += 1
						return nil
					end,
				}
				sert.eq({ Util.MemoryStore.getSharded(emptyShardMap, "ZeroShards", 0) }, { false, nil })
				local emptyOk, emptyVal = Util.MemoryStore.getSharded(emptyShardMap, "EmptyPrefix", 4, 2)
				sert.eq(emptyOk, true)
				sert.eq(emptyVal, nil)
				sert.eq(probeCount, 2)

				probeCount = 0
				local defaultProbesOk = Util.MemoryStore.getSharded(emptyShardMap, "DefaultProbes", 4)
				sert.eq(defaultProbesOk, true)
				sert.eq(probeCount, 4)

				local shardedData: { [string]: any } = {}
				local shardMap: any = {
					GetAsync = function(_self, key: string)
						return shardedData[key]
					end,
					SetAsync = function(_self, key: string, value: any)
						h.env.task.wait(0.1)
						shardedData[key] = value
						return true
					end,
				}
				local setOk = nil
				h.env.task.spawn(function()
					setOk = Util.MemoryStore.setSharded(shardMap, "HitPrefix", "payload_val", 60, 3, 1)
				end)
				h.env:advance(1)
				sert.eq(setOk, true)
				sert.eq(shardedData["HitPrefix_1"], "payload_val")
				sert.eq(shardedData["HitPrefix_2"], "payload_val")
				sert.eq(shardedData["HitPrefix_3"], "payload_val")
				local hitOk, hitVal = Util.MemoryStore.getSharded(shardMap, "HitPrefix", 3, 2, 1)
				sert.eq(hitOk, true)
				sert.eq(hitVal, "payload_val")

				local failingShardMap: any = {
					GetAsync = function()
						error("MemoryStore unavailable")
					end,
				}
				local failOk, failVal
				h.env.task.spawn(function()
					failOk, failVal = Util.MemoryStore.getSharded(failingShardMap, "FailPrefix", 4, 2)
				end)
				h.env:advance(10)
				sert.eq(failOk, false)
				sert.eq(failVal, nil)

				local fakeMap: any = {
					ListItemsAsync = function()
						return makeMultiPages()
					end,
				}
				local multiItems = Util.MemoryStore.getItemsFromHashMap(fakeMap)
				sert.eq(multiItems, { p1 = 10, p2 = 20 })

				local ms = h.env.game:GetService("MemoryStoreService")
				local map = ms:GetHashMap("TestMap")
				map:SetAsync("k1", { v = 1 }, 60)
				map:SetAsync("k2", { v = 2 }, 60)

				local items = Util.MemoryStore.getItemsFromHashMap(map)
				sert.eq(items.k1.v, 1)
				sert.eq(items.k2.v, 2)

				-- String.hash (32-bit FNV-1a) and MemoryStore.shardIndex full-ring permutation & uniform distribution
				sert.eq(Util.String.hash(""), 0x811C9DC5)
				sert.eq(Util.String.hash("a"), 0xE40C292C)
				sert.eq(Util.String.hash("foobar"), 0xBF9CF968)
				sert.eq(Util.MemoryStore.shardIndex("any", 1), 1)

				for _, shardCount in { 7, 8, 16, 64, 67 } do
					local visited = {}
					for offset = 0, shardCount - 1 do
						local idx = Util.MemoryStore.shardIndex("chunk_key", shardCount, offset, "job-seed-123")
						sert.eq(idx >= 1 and idx <= shardCount, true)
						sert.eq(visited[idx], nil)
						visited[idx] = true
					end
				end

				-- Check uniform dispersion across 8 shards for 800 distinct server JobIds
				local counts = table.create(8, 0)
				for i = 1, 800 do
					local idx = Util.MemoryStore.shardIndex("Main_100", 8, 0, `server-job-{i}`)
					counts[idx] += 1
				end
				for s = 1, 8 do
					sert.eq(counts[s] >= 65 and counts[s] <= 135, true)
				end

				-- SafePlayerAdded duplicate PlayerAdded guard & last-player PlayerRemoving cleanup
				local pA = h.env:addPlayer(50, "PlayerA")
				local addedCount = 0
				Util.SafePlayerAdded(function(_plr)
					addedCount += 1
				end)
				sert.eq(addedCount, 1)
				-- Firing PlayerAdded again for already-processed pA is a no-op (line 25)
				h.env.Players.PlayerAdded:Fire(pA)
				sert.eq(addedCount, 1)
				-- Adding a second player then removing one, then removing the last player clears cache[processed] (lines 14-15)
				h.env:addPlayer(51, "PlayerB")
				sert.eq(addedCount, 2)
				h.env:removePlayer(50)
				h.env:removePlayer(51)
				sert.eq(#h.env.Players:GetPlayers(), 0)
			end
		)

		test("SafeTeleport handles TeleportOptions, pcall retries, and TeleportInitFailed signal", function()
			local h = Harness.newEnv()
			local Util = h:requireUtil()
			local plr = h.env:addPlayer(1, "TeleportPlayer")
			local TeleportService = h.env.game:GetService("TeleportService")
			local tpMethods = rawget(TeleportService, "_methods")

			local options = h.env.Instance.new("TeleportOptions")
			options.ServerInstanceId = "job-123"
			local ok1 = Util.SafeTeleport(12345, { plr }, options)
			sert.eq(ok1, true)

			-- Transient failure (2 failures then success on attempt 3)
			local origTeleport = tpMethods.TeleportAsync
			local attempts = 0
			local lastOptions = nil
			tpMethods.TeleportAsync = function(_self, _placeId, _players, opts)
				attempts += 1
				lastOptions = opts
				if attempts < 3 then
					error("Temporary teleport failure")
				end
				return "teleport_result"
			end

			local retryOk, retryRes
			h.env.task.spawn(function()
				retryOk, retryRes = Util.SafeTeleport(12345, { plr }, { custom = true })
			end)
			h.env:advance(5)
			sert.eq(retryOk, true)
			sert.eq(retryRes, "teleport_result")
			sert.eq(attempts, 3)
			sert.eq(lastOptions.custom, true)

			-- Permanent failure across all 5 attempts
			attempts = 0
			tpMethods.TeleportAsync = function()
				attempts += 1
				error("Permanent teleport failure")
			end
			local failOk = nil
			h.env.task.spawn(function()
				failOk = Util.SafeTeleport(12345, { plr })
			end)
			h.env:advance(10)
			sert.eq(failOk, false)
			sert.eq(attempts, 5)

			-- TeleportInitFailed signal handling: GameNotFound / Unauthorized / GameFull / GameEnded / IsTeleporting / Studio should NOT retry
			local initRetryCalls = 0
			tpMethods.TeleportAsync = function()
				initRetryCalls += 1
				return true
			end
			for _, nonRetryable in
				{
					h.env.globals.Enum.TeleportResult.GameNotFound,
					h.env.globals.Enum.TeleportResult.Unauthorized,
					h.env.globals.Enum.TeleportResult.GameFull,
					h.env.globals.Enum.TeleportResult.GameEnded,
					h.env.globals.Enum.TeleportResult.IsTeleporting,
				}
			do
				TeleportService.TeleportInitFailed:Fire(plr, nonRetryable, "non-retryable", 12345, options)
			end
			TeleportService.TeleportInitFailed:Fire(
				plr,
				h.env.globals.Enum.TeleportResult.Failure,
				"Cannot teleport in Roblox Studio",
				12345,
				options
			)
			sert.eq(initRetryCalls, 0)

			-- Failure waits RETRY_DELAY (1s) and Flooded waits FLOOD_DELAY (15s) then calls SafeTeleport
			local tBeforeFail = h.env.globals.os.clock()
			TeleportService.TeleportInitFailed:Fire(
				plr,
				h.env.globals.Enum.TeleportResult.Failure,
				"network error",
				12345,
				options
			)
			h.env:step(1.1)
			local failElapsed = h.env.globals.os.clock() - tBeforeFail
			sert.eq(failElapsed >= 1 and failElapsed < 5, true)
			sert.eq(initRetryCalls, 1)

			local tBeforeFlood = h.env.globals.os.clock()
			TeleportService.TeleportInitFailed:Fire(
				plr,
				h.env.globals.Enum.TeleportResult.Flooded,
				"flooded",
				12345,
				options
			)
			h.env:step(15.1)
			local floodElapsed = h.env.globals.os.clock() - tBeforeFlood
			sert.eq(floodElapsed >= 15, true)
			sert.eq(initRetryCalls, 2)

			tpMethods.TeleportAsync = origTeleport

			-- Defer.reset and Defer.wait budget enforcement
			local deferYields = 0
			Util.Defer.reset()
			h.env.task.delay(0, function()
				deferYields += 1
			end)
			Util.Defer.wait()
			sert.eq(deferYields, 0)
			h.env:step(1.1)
			sert.eq(deferYields, 1)
			h.env.task.delay(0, function()
				deferYields += 1
			end)
			Util.Defer.wait()
			sert.eq(deferYields, 2)
			h.env.task.delay(0, function()
				deferYields += 1
			end)
			Util.Defer.wait()
			sert.eq(deferYields, 2)

			-- Service.__index lazy caching into raw table
			sert.eq(rawget(Util.Service, "Debris"), nil)
			local debrisSvc = Util.Service.Debris
			sert.eq(debrisSvc, h.env.game:GetService("Debris"))
			sert.eq(rawget(Util.Service, "Debris"), debrisSvc)
		end)

		test("getTexture caches results and handles Image asset type, LoadAsset decal, and error fallback", function()
			local h = Harness.newEnv()
			local Util = h:requireUtil()
			local MarketplaceService = h.env.game:GetService("MarketplaceService")
			local InsertService = h.env.game:GetService("InsertService")

			-- 1. Error fallback when GetProductInfoAsync throws
			local marketSpy = sert.spy(MarketplaceService, "GetProductInfoAsync", function()
				error("Marketplace unavailable")
			end)
			sert.eq(Util.getTexture(1001), nil)

			-- 2. Image AssetTypeId (1) returns rbxassetid:// directly and caches
			local infoCalls = 0
			marketSpy:calls(function(_self, assetId)
				infoCalls += 1
				return { AssetTypeId = h.env.globals.Enum.AssetType.Image.Value, AssetId = assetId }
			end)
			sert.eq(Util.getTexture(1002), "rbxassetid://1002")
			sert.eq(Util.getTexture(1002), "rbxassetid://1002")
			sert.eq(infoCalls, 1)

			-- 3. Server LoadAsset branch (Face/Shirt/Pants/TShirt) extracts Decal.Texture
			marketSpy:calls(function()
				return { AssetTypeId = h.env.globals.Enum.AssetType.Face.Value }
			end)
			local insertSpy = sert.spy(InsertService, "LoadAsset", function()
				local model = h.env.Instance.new("Model")
				local decal = h.env.Instance.new("Decal", model)
				decal.Texture = "rbxassetid://999888"
				return model
			end)
			sert.eq(Util.getTexture(1003), "rbxassetid://999888")

			-- 4. Empty texture property and LoadAsset failure both fall back to rbxthumb (small=true 150 and small=false 420)
			insertSpy:calls(function()
				local model = h.env.Instance.new("Model")
				local decal = h.env.Instance.new("Decal", model)
				decal.Texture = ""
				return model
			end)
			sert.eq(Util.getTexture(1006, true), "rbxthumb://type=Asset&id=1006&w=150&h=150")
			insertSpy:calls(function()
				error("LoadAsset blocked")
			end)
			sert.eq(Util.getTexture(1004, true), "rbxthumb://type=Asset&id=1004&w=150&h=150")
			sert.eq(Util.getTexture(1005, false), "rbxthumb://type=Asset&id=1005&w=420&h=420")
			marketSpy:restore()
			insertSpy:restore()
		end)

		test(
			"getUserInfo handles cache hits, online Players, >200 batch overflow, permanent failure retry, and client RemoteFunction",
			function()
				local h = Harness.newEnv()
				local Util = h:requireUtil()
				local UserService = h.env.game:GetService("UserService")

				-- Invalid non-numeric userId fallback
				local unknown = Util.getUserInfo(nil :: any)
				sert.eq(unknown.Username, "Unknown")

				-- Online player via SafePlayerAdded populates cache immediately
				local online = h.env:addPlayer(10, "OnlineUser")
				sert.eq(Util.getUserInfo(online.UserId, true).Username, "OnlineUser")
				sert.eq(Util.getUserInfo(online.UserId).Username, "OnlineUser")

				-- UserService:GetUserInfosByUserIdsAsync batch lookup + deleted user fallback
				local userSpy = sert.spy(UserService, "GetUserInfosByUserIdsAsync", function(_self, ids)
					local out = {}
					for _, id in ids do
						if id == 202 then
							table.insert(out, {
								Id = 202,
								Username = "BatchUser202",
								DisplayName = "BatchDisplay",
								HasVerifiedBadge = true,
							})
						end
					end
					return out
				end)

				local info202, infoDeleted
				h.env.task.spawn(function()
					info202 = Util.getUserInfo(202)
				end)
				h.env.task.spawn(function()
					-- Concurrent call for same userId joins the existing hook
					Util.getUserInfo(202)
				end)
				h.env.task.spawn(function()
					infoDeleted = Util.getUserInfo(404)
				end)
				h.env:step(1)
				sert.eq(info202 ~= nil, true)
				sert.eq(info202.Username, "BatchUser202")
				sert.eq(infoDeleted ~= nil, true)
				sert.eq(infoDeleted.Username, "Deleted")
				sert.eq(infoDeleted.Deleted, true)

				-- UserService transient error followed by recovery retry
				local attempts = 0
				userSpy:calls(function(_self, _ids)
					attempts += 1
					if attempts == 1 then
						error("UserService 500")
					end
					return {
						{ Id = 303, Username = "Recovered303", DisplayName = "Rec", HasVerifiedBadge = false },
					}
				end)
				local info303
				h.env.task.spawn(function()
					info303 = Util.getUserInfo(303)
				end)
				h.env:advance(5)
				sert.eq(info303 ~= nil, true)
				sert.eq(info303.Username, "Recovered303")
				sert.eq(attempts, 2)

				-- >200 concurrent userIds triggers chunked re-deferral (lines 31 & 69)
				userSpy:calls(function(_self, ids)
					local out = {}
					for _, id in ids do
						table.insert(
							out,
							{ Id = id, Username = `U{id}`, DisplayName = `D{id}`, HasVerifiedBadge = false }
						)
					end
					return out
				end)
				local got205 = nil
				for uid = 1001, 1205 do
					h.env.task.spawn(function()
						local res = Util.getUserInfo(uid)
						if uid == 1205 then
							got205 = res
						end
					end)
				end
				for _ = 1, 5 do
					h.env:step(0.5)
				end
				sert.eq(got205 ~= nil, true)
				sert.eq(got205.Username, "U1205")

				-- Permanent failure across all 6 attempts triggers warn + 5s delay retry, then succeeds (lines 74 & 76)
				local permFails = 0
				userSpy:calls(function(_self, ids)
					permFails += 1
					if permFails <= 6 then
						error("UserService total outage")
					end
					return {
						{ Id = ids[1], Username = "AfterOutage", DisplayName = "AO", HasVerifiedBadge = true },
					}
				end)
				local infoOutage
				h.env.task.spawn(function()
					infoOutage = Util.getUserInfo(9001)
				end)
				for _ = 1, 15 do
					h.env:step(10)
				end
				sert.eq(infoOutage ~= nil, true)
				sert.eq(infoOutage.Username, "AfterOutage")
				userSpy:restore()

				-- Server OnServerInvoke and Client InvokeServer paths (lines 90-95 & 113)
				local getUserInfoMod = h.Shared:WaitForChild("Util"):WaitForChild("getUserInfo")
				local rf = getUserInfoMod:FindFirstChildOfClass("RemoteFunction")
				sert.eq(rf ~= nil, true)
				local srvInvokeRes = rf.OnServerInvoke(online, online.UserId)
				sert.eq(srvInvokeRes.Username, "OnlineUser")

				local hc = Harness.newEnv({ isClient = true })
				local cGetUserInfoMod = hc.Shared:WaitForChild("Util"):WaitForChild("getUserInfo")
				local cRf = hc.env.Instance.new("RemoteFunction", cGetUserInfoMod)
				cRf.Name = "RemoteFunction"
				local cRfSpy = sert.spy(cRf, "InvokeServer", function(_self, uid)
					if uid == 777 then
						return {
							Id = 777,
							Username = "ClientFetched777",
							DisplayName = "CF",
							HasVerifiedBadge = true,
						}
					end
					return nil
				end)
				local cGetUserInfo = hc.env:require(cGetUserInfoMod)
				local cInfo777 = cGetUserInfo(777)
				sert.eq(cInfo777.Username, "ClientFetched777")
				local cInfoNil = cGetUserInfo(888)
				sert.eq(cInfoNil.Username, "Unknown")
				cRfSpy:restore()
			end
		)

		test("getUserInfo lets a batch waiting on UserService finish when another lookup starts", function()
			local h = Harness.newEnv()
			local Util = h:requireUtil()
			local userMethods = rawget(h.env.game:GetService("UserService"), "_methods")

			-- the first request fails, so the batch for 501 backs off for 2s before retrying
			local calls = {}
			userMethods.GetUserInfosByUserIdsAsync = function(_self, ids)
				table.insert(calls, table.clone(ids))
				if #calls == 1 then
					error("UserService 500")
				end
				local out = {}
				for _, id in ids do
					table.insert(out, { Id = id, Username = `U{id}`, DisplayName = `D{id}`, HasVerifiedBadge = false })
				end
				return out
			end

			local info501, info502
			h.env.task.spawn(function()
				info501 = Util.getUserInfo(501)
			end)
			h.env:step(0.5)
			sert.eq(calls, { { 501 } })

			-- a new lookup during the backoff must not cancel and restart 501's batch
			h.env.task.spawn(function()
				info502 = Util.getUserInfo(502)
			end)
			h.env:step(0.5)
			sert.eq(calls, { { 501 } })

			for _ = 1, 4 do
				h.env:step(0.5)
			end
			sert.eq(calls, { { 501 }, { 501 }, { 502 } })
			sert.eq(info501.Username, "U501")
			sert.eq(info502.Username, "U502")
		end)

		test("getUserInfo starts a batch within 0.2s while new lookups keep arriving", function()
			local h = Harness.newEnv()
			local Util = h:requireUtil()
			local userMethods = rawget(h.env.game:GetService("UserService"), "_methods")
			local calls = {}
			userMethods.GetUserInfosByUserIdsAsync = function(_self, ids)
				table.insert(calls, table.clone(ids))
				local out = {}
				for _, id in ids do
					table.insert(out, { Id = id, Username = `U{id}`, DisplayName = `D{id}`, HasVerifiedBadge = false })
				end
				return out
			end

			local info501
			h.env.task.spawn(function()
				info501 = Util.getUserInfo(501)
			end)
			-- a distinct lookup every 0.1s must not keep pushing 501's batch back
			for i = 1, 3 do
				h.env.task.spawn(function()
					Util.getUserInfo(10000 + i)
				end)
				h.env:step(0.1)
			end
			-- the first batch ran 0.2s after 501 was queued, with the ids queued before then
			sert.eq(info501.Username, "U501")
			table.sort(calls[1])
			sert.eq(calls[1], { 501, 10001, 10002 })
		end)

		test("getUserInfo retries a failed or broken batch without duplicating or latching ids", function()
			local h = Harness.newEnv()
			local Util = h:requireUtil()
			local userMethods = rawget(h.env.game:GetService("UserService"), "_methods")
			local calls = {}
			userMethods.GetUserInfosByUserIdsAsync = function(_self, ids)
				table.insert(calls, table.clone(ids))
				if #calls <= 5 then
					error("UserService total outage")
				elseif #calls == 6 then
					-- a malformed entry throws while the batch stores results
					return { { Username = "NoId" } }
				end
				local out = {}
				for _, id in ids do
					table.insert(out, { Id = id, Username = `U{id}`, DisplayName = `D{id}`, HasVerifiedBadge = false })
				end
				return out
			end

			local info601
			h.env.task.spawn(function()
				info601 = Util.getUserInfo(601)
			end)
			for _ = 1, 20 do
				h.env:step(5)
			end
			sert.eq(#calls, 7)
			for _, ids in calls do
				sert.eq(ids, { 601 })
			end
			sert.eq(info601.Username, "U601")
		end)

		test("getUserInfo RemoteFunction returns cached ids and only looks up valid user ids", function()
			local h = Harness.newEnv()
			local Util = h:requireUtil()
			local userMethods = rawget(h.env.game:GetService("UserService"), "_methods")
			local calls = 0
			userMethods.GetUserInfosByUserIdsAsync = function(_self, ids)
				calls += 1
				return { { Id = ids[1], Username = `U{ids[1]}`, DisplayName = "D", HasVerifiedBadge = false } }
			end
			local player = h.env:addPlayer(11, "Asker")
			local rf = h.Shared:WaitForChild("Util"):WaitForChild("getUserInfo"):FindFirstChildOfClass("RemoteFunction")

			for _, bad in { "123", 0, -5, 1.5, 1e300, 2 ^ 63, math.huge, 0 / 0, true, {} } do
				sert.eq(rf.OnServerInvoke(player, bad), nil)
			end
			h.env:step(1)
			sert.eq(calls, 0)

			-- Studio local server players have negative ids the server already cached
			h.env:addPlayer(-1, "Player1")
			sert.eq(rf.OnServerInvoke(player, -1).Username, "Player1")

			local info
			h.env.task.spawn(function()
				info = rf.OnServerInvoke(player, 1)
			end)
			h.env:step(1)
			sert.eq(info.Username, "U1")
			sert.eq(Util.getUserInfo(1).Username, "U1")
		end)

		test("getUserInfo RemoteFunction caps each player's in-flight lookups", function()
			local h = Harness.newEnv()
			local userMethods = rawget(h.env.game:GetService("UserService"), "_methods")
			local calls = {}
			userMethods.GetUserInfosByUserIdsAsync = function(_self, ids)
				table.insert(calls, table.clone(ids))
				local out = {}
				for _, id in ids do
					table.insert(out, { Id = id, Username = `U{id}`, DisplayName = `D{id}`, HasVerifiedBadge = false })
				end
				return out
			end
			h:requireUtil()
			local flooder = h.env:addPlayer(12, "Flooder")
			local other = h.env:addPlayer(13, "Other")
			local rf = h.Shared:WaitForChild("Util"):WaitForChild("getUserInfo"):FindFirstChildOfClass("RemoteFunction")

			local results = {}
			local function invoke(player, userId)
				h.env.task.spawn(function()
					results[userId] = rf.OnServerInvoke(player, userId) or false
				end)
			end

			-- 32 lookups park on the next batch; the flooder's 33rd and 34th return nil at once
			for userId = 2001, 2034 do
				invoke(flooder, userId)
			end
			sert.eq(results[2032], nil)
			sert.eq(results[2033], false)
			sert.eq(results[2034], false)
			-- another player's lookup is not refused for it
			invoke(other, 3001)
			h.env:step(1)
			sert.eq(#calls, 1)
			sert.eq(#calls[1], 33)
			sert.eq(results[2001].Username, "U2001")
			sert.eq(results[2032].Username, "U2032")
			sert.eq(results[3001].Username, "U3001")

			-- finished lookups free the cap
			for userId = 2101, 2132 do
				invoke(flooder, userId)
			end
			h.env:step(1)
			sert.eq(results[2132].Username, "U2132")

			-- lookups still waiting when their player leaves finish without error
			userMethods.GetUserInfosByUserIdsAsync = function()
				error("UserService 500")
			end
			for userId = 2201, 2232 do
				invoke(flooder, userId)
			end
			h.env:step(0.5)
			sert.eq(rf.OnServerInvoke(flooder, 2233), nil)
			h.env:removePlayer(12)
			-- a request handled after the player left is refused, not counted again
			invoke(flooder, 2234)
			sert.eq(results[2234], false)
			userMethods.GetUserInfosByUserIdsAsync = function(_self, ids)
				local out = {}
				for _, id in ids do
					table.insert(out, { Id = id, Username = `U{id}`, DisplayName = `D{id}`, HasVerifiedBadge = false })
				end
				return out
			end
			for _ = 1, 10 do
				h.env:step(2)
			end
			sert.eq(results[2201].Username, "U2201")
			sert.eq(results[2232].Username, "U2232")

			-- the same user rejoining gets a full cap again
			local rejoined = h.env:addPlayer(12, "Flooder")
			for userId = 2301, 2333 do
				invoke(rejoined, userId)
			end
			sert.eq(results[2332], nil)
			sert.eq(results[2333], false)
			h.env:step(1)
			sert.eq(results[2332].Username, "U2332")
		end)

		test("getUserInfo client queues lookups past the server cap and resolves every name", function()
			local hc = Harness.newEnv({ isClient = true })
			local mod = hc.Shared:WaitForChild("Util"):WaitForChild("getUserInfo")
			local rf = hc.env.Instance.new("RemoteFunction", mod)
			rf.Name = "RemoteFunction"
			local active, peak, invokes = 0, 0, {}
			rawset(rf, "_methods", {
				InvokeServer = function(_self, uid)
					active += 1
					peak = math.max(peak, active)
					invokes[uid] = (invokes[uid] or 0) + 1
					hc.env.task.wait(0.5)
					active -= 1
					if uid == 4999 then
						error("player left")
					elseif uid == 4998 then
						return nil
					end
					return { Id = uid, Username = `U{uid}`, DisplayName = `D{uid}`, HasVerifiedBadge = false }
				end,
			})
			local getUserInfo = hc.env:require(mod)

			-- e.g. the bans list looks up each row's author, many of them the same admin
			local names = {}
			local function lookup(key, uid)
				hc.env.task.spawn(function()
					names[key] = getUserInfo(uid).Username
				end)
			end
			lookup("failed", 4999)
			lookup("missing", 4998)
			for i = 1, 100 do
				lookup(i, 5000 + i)
			end
			for i = 101, 200 do
				lookup(i, 5001)
			end
			for _ = 1, 30 do
				hc.env:step(0.5)
			end

			sert.eq(peak, 32)
			sert.eq(names.failed, "Unknown")
			sert.eq(names.missing, "Unknown")
			for i = 1, 100 do
				sert.eq(names[i], `U{5000 + i}`)
			end
			for i = 101, 200 do
				sert.eq(names[i], "U5001")
			end
			-- lookups of one id share a single invoke
			sert.eq(invokes[5001], 1)
			sert.eq(active, 0)

			-- every slot was handed back, including those of the failed and missing lookups
			peak = 0
			for i = 1, 33 do
				lookup(`after{i}`, 6000 + i)
			end
			sert.eq(active, 32)

			-- an id that came back Unknown is looked up again next time
			lookup("missingAgain", 4998)
			for _ = 1, 4 do
				hc.env:step(0.5)
			end
			sert.eq(peak, 32)
			sert.eq(names.after33, "U6033")
			sert.eq(invokes[4998], 2)
			sert.eq(names.missingAgain, "Unknown")
		end)

		test("getUserInfo never queues an id outside the Web API range", function()
			local h = Harness.newEnv()
			local Util = h:requireUtil()
			local userMethods = rawget(h.env.game:GetService("UserService"), "_methods")
			local calls = {}
			userMethods.GetUserInfosByUserIdsAsync = function(_self, ids)
				table.insert(calls, table.clone(ids))
				for _, id in ids do
					if id > 2 ^ 53 then
						error("id out of range")
					end
				end
				local out = {}
				for _, id in ids do
					table.insert(out, { Id = id, Username = `U{id}`, DisplayName = `D{id}`, HasVerifiedBadge = false })
				end
				return out
			end

			-- e.g. `ban 1e300` reaches saveBan's lookup through the command parsers
			local huge, info701
			h.env.task.spawn(function()
				huge = Util.getUserInfo(1e300)
			end)
			h.env.task.spawn(function()
				info701 = Util.getUserInfo(701)
			end)
			h.env:step(1)
			sert.eq(huge.Username, "Unknown")
			sert.eq(calls, { { 701 } })
			sert.eq(info701.Username, "U701")
		end)

		test(
			"Remote handles client ServerReady wait, duplicate syncPayload, unindexed server remote, failed queued Invoke, and 5s infinite yield warn",
			function()
				local world = sert.sim.new({ backing = true, latency = { remotes = 0.01 } })
				local server = world:server()
				local client = server:client(101)

				local sh = Harness.newPeerEnv(server, { isStudio = false })
				local ch = Harness.newPeerEnv(client, { isClient = true })

				local sRemote = sh:requireRemote()
				-- Register a remote on server that the client never pre-indexes (exercises line 311 on initial sync)
				sRemote.ServerCreatedOnly:Connect(function() end)

				-- Clear ServerReady before client requires Remote so client waits on GetAttributeChangedSignal("ServerReady") (line 362)
				local cRemoteMod = ch.Shared:WaitForChild("Util"):WaitForChild("Remote")
				local cEvent = cRemoteMod:WaitForChild("RemoteEvent")
				cEvent:SetAttribute("ServerReady", false)

				local cRemote: any
				client:spawn(function()
					cRemote = ch:requireRemote()
				end)
				world:run(0.05)
				cEvent:SetAttribute("ServerReady", true)
				world:run(0.5)
				sert.eq(cRemote ~= nil, true)

				-- Firing script sync a second time from client hits loaded[player] early return on server
				cEvent:FireServer(cRemoteMod)
				world:run(0.2)

				-- Reconnecting with the same UserId (new Player instance) queues server->client fires until the new Player initializes
				local reconnectedPlr = sh.env.Instance.new("Player")
				reconnectedPlr.UserId = 101
				reconnectedPlr.Name = "Reconnected101"
				reconnectedPlr.Parent = sh.env.Players
				sRemote.ServerCreatedOnly:Fire(reconnectedPlr, "queued_for_reconnect")
				sh.env.Players.PlayerRemoving:Fire(reconnectedPlr)
				reconnectedPlr.Parent = nil

				-- Queue a Fire and an Invoke on an unlinked remote on client, then create it on server with throwing OnInvoke so flushQueue hits error path (lines 298-299)
				local invokeReturned = false
				local queuedFires = 0
				cRemote.QueuedErrorInvoke:Fire("queued_fire_arg")
				sert.eq(cRemote.QueuedErrorInvoke._fireQueue ~= nil, true)
				client:spawn(function()
					cRemote.QueuedErrorInvoke:Invoke("arg1")
					invokeReturned = true
				end)
				sert.eq(cRemote.QueuedErrorInvoke._invokeQueue ~= nil, true)
				sRemote.QueuedErrorInvoke:Connect(function(_plr, arg)
					if arg == "queued_fire_arg" then
						queuedFires += 1
					end
				end)
				sRemote.QueuedErrorInvoke.OnInvoke = function()
					error("Queued OnInvoke boom")
				end
				world:run(1)
				sert.eq(invokeReturned, true)
				sert.eq(queuedFires, 1)
				sert.eq(cRemote.QueuedErrorInvoke._fireQueue, nil)
				sert.eq(cRemote.QueuedErrorInvoke._invokeQueue, nil)

				-- SetUnreliable on server updates _remote and replicates to client; on client it warns without mutating _remote
				local cUnreliableEvent = cRemoteMod:WaitForChild("UnreliableRemoteEvent")
				sRemote.ServerCreatedOnly:SetUnreliable(true)
				world:run(0.2)
				sert.eq(cRemote.ServerCreatedOnly._remote, cUnreliableEvent)
				sRemote.ServerCreatedOnly:SetUnreliable(false)
				world:run(0.2)
				sert.eq(cRemote.ServerCreatedOnly._remote, cEvent)
				cRemote.ServerCreatedOnly:SetUnreliable(true)
				sert.eq(cRemote.ServerCreatedOnly._remote, cEvent)

				-- Server and Client RemoteFunction guard against unknown remote id or remote without OnInvoke
				local sFunc = sh.Shared:WaitForChild("Util"):WaitForChild("Remote"):WaitForChild("RemoteFunction")
				local cFunc = cRemoteMod:WaitForChild("RemoteFunction")
				sert.eq(sFunc.OnServerInvoke(sh.env.Players:GetPlayerByUserId(101), "\255\255"), nil)
				sert.eq(sFunc.OnServerInvoke(sh.env.Players:GetPlayerByUserId(101), sRemote.ServerCreatedOnly._id), nil)
				sert.eq(cFunc.OnClientInvoke("\255\255"), nil)
				sert.eq(cFunc.OnClientInvoke(cRemote.ServerCreatedOnly._id), nil)

				-- Passive indexing/Connect/Fire on client does not warn after 5s, whereas yielding (Wait/Invoke) on an unlinked remote warns once after 5s
				local _passive = cRemote.PassiveClientListener:Connect(function() end)
				cRemote.NeverRegisteredOnServer:Fire("queued_without_server")
				cRemote.NeverRegisteredOnServer:Fire("second_queued_fire")
				client:spawn(function()
					cRemote.NeverRegisteredWait:Wait()
				end)
				client:spawn(function()
					cRemote.NeverRegisteredWait:Wait()
				end)
				world:run(5.5)

				-- Requiring Remote on client when script is not a descendant of ReplicatedStorage warns (line 93)
				local hStandalone = Harness.newEnv({ isClient = true })
				hStandalone:mockClientRemotes()
				hStandalone.KA.Parent = hStandalone.env.workspace
				local standaloneRemote = hStandalone:requireRemote()
				sert.eq(standaloneRemote ~= nil, true)
			end
		)
	end
)

describe("Server · LoadScript & Loadstring (LuaX, LuaY, LuaK, LuaP, LuaU, LuaZ, FiOne)", function()
	test(
		"Loadstring and LoadScript compile and execute full Lua 5.1 / Luau grammar, bytecode dump/undump, and VM opcodes",
		function()
			local h = Harness.newEnv()
			local Server = h.KA:WaitForChild("Server")
			local LoadScriptMod = Server:WaitForChild("LoadScript")
			local LoadstringMod = LoadScriptMod:WaitForChild("Loadstring")

			local LoadScript = h.env:require(LoadScriptMod)
			local Loadstring = h.env:require(LoadstringMod)
			local FiOne = h.env:require(LoadstringMod:WaitForChild("FiOne"))
			local LuaP = h.env:require(LoadstringMod:WaitForChild("LuaP"))
			local LuaY = h.env:require(LoadstringMod:WaitForChild("LuaY"))
			local LuaZ = h.env:require(LoadstringMod:WaitForChild("LuaZ"))
			sert.eq(LuaY:getcompopr("TK_ASSIGN_ADD"), "OP_ADD")

			-- 1. LoadScript caches bytecode, clones Server/Client base scripts, and rejects invalid base
			sert.eq(LoadScript("return 1", "InvalidBase" :: any), nil)
			local sScript1 = LoadScript("return 42", "Server")
			local sScript2 = LoadScript("return 42", "Server") -- hits bytecodeCache (line 14)
			sert.eq(sScript1 ~= nil, true)
			sert.eq(sScript2 ~= nil, true)
			sert.eq(sScript1:GetAttribute("Source"), "return 42")

			local clientFolder = h.env.Instance.new("Folder")
			local cScript = LoadScript("return 99", "Client", clientFolder)
			sert.eq(cScript ~= nil, true)
			sert.eq(cScript.Parent, clientFolder)
			sert.eq(cScript:GetAttribute("Source"), nil)

			-- 2. LuaZ & LuaP direct helper coverage
			sert.eq(LuaZ:init(nil), nil)
			local zStream = LuaZ:init(LuaZ:make_getS("abc"), "data_str")
			sert.eq(zStream.n, 8)

			local inst = LuaP:CREATE_Inst(64 * 5 + 1)
			sert.eq(type(inst), "table")
			local abcInst = LuaP:CREATE_ABC("OP_MOVE", 1, 2, 3)
			sert.eq(LuaP:GETARG_B(abcInst), 2)
			sert.eq(LuaP:GETARG_C(abcInst), 3)
			LuaP:SET_OPCODE(inst, "OP_MOVE")
			LuaP:SETARG_Bx(inst, 123)
			sert.eq(LuaP:GETARG_Bx(inst), 123)
			sert.eq(LuaP:INDEXK(256), 0)
			sert.eq(type(LuaP:testAMode("OP_MOVE")), "number")
			local decoded = LuaP:DecodeInst("\0\1\2\3")
			sert.eq(type(decoded.OP), "number")
			local decodedBx = LuaP:DecodeInst("\1\1\2\3") -- OP_LOADK (iABx)
			sert.eq(type(decodedBx.Bx), "number")

			-- 3. Rich program exercising LuaX tokens/escapes, LuaY grammar, LuaK codegen/folding, LuaU dump, and FiOne VM
			local richProgram = table.concat({
				"-- short comment\r\n",
				"--[[ multiline\nblock comment ]]\n\r",
				"--[==[ nested = block comment ]==]\n",
				"do local _scoped = 1 end",
				"local long1 = [[\nhello\nworld]]",
				"local long2 = [==[\nalpha\nbeta]==]",
				'local esc = "\\a\\b\\f\\n\\r\\t\\v\\\\\\\'\\"\\65\\065\\x42\\u{43}hi\\zthere"',
				'local escEnd = "tail\\z"',
				'local escNl = "line1\\\nline2"',
				"local hexAndBin = 0xff + 0x10 + 0b1010 + 1.5e-2 + 2E+3 + 0 + (-0)",
				"local infAndSub = (1e400 > 1e300) and (1e-320 >= 0)",
				-- Constant folding (+, -, *, /, %, ^, unary -, div/mod by 0, NaN)
				"local folded = (10 - 3) + (4 * 5) + (20 / 4) + (17 % 5) + (2 ^ 3) + (-5)",
				"local divZero, modZero, nanVal = 1 / 0, 1 % 0, 0 / 0",
				-- Runtime arithmetic with register and constant operands (is_KB / is_KC)
				"local x, y = 10, 3",
				"local arith = (x + 2) + (2 + x) + (x - 2) + (20 - x) + (x * 2) + (2 * x)",
				"arith = arith + (x / 2) + (20 / x) + (x % 3) + (20 % x) + (x ^ 2) + (2 ^ y) + (-x)",
				-- Compound assignments (+=, -=, *=, /=, %=, ^=)
				"local function testComp() local r0 = 0; local c = 10; c += 5; c -= 3; c *= 2; c /= 4; c %= 4; c ^= 3; return r0 end",
				"local ca = testComp()",
				'local cs = "ok"; cs = cs .. "!"',
				-- Concatenation (string chain + number concatenation fallback in FiOne)
				'local sA, sB, sC = "A", "B", "C"',
				"local catStr = sA .. sB .. sC",
				"local catNum = 12 .. 34",
				-- Relational & logical expressions (==, ~=, <, <=, >, >=, and, or, not)
				"local rel1 = (x < 20) and (5 < x) and (x <= 10) and (10 <= x) and (x > 5) and (20 > x) and (x >= 10) and (10 >= x)",
				"local rel2 = (x == 10) and (10 == x) and (x ~= 9) and (not false) and (not nil) and (not (x == 99))",
				'local logic = ((true and x) or (false and y)) + ((nil or 7) + (false or 8)) + ((not "s" and 1) or 0) + ((not 1 and 1) or 0)',
				"local truthyOr = (true or x) and (not true == false)",
				-- Tables: boolean/nil keys, >50 array elements (LFIELDS_PER_FLUSH & int2fb >= 16), conflict assignment
				'local boolTbl = { [true] = 11, [false] = 22, ["key"] = 33 }',
				"local bigArr = {",
				"  1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,",
				"  21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,",
				"  41,42,43,44,45,46,47,48,49,50,51,52,53,54,55",
				"}",
				"local ct = { 10, 20 }; local ci = 1; ct[ci], ci = 99, 2",
				"local ct2 = { 10, 20 }; ct2[1], ct2 = 88, { 77 }",
				-- Control flow: if/elseif/else, if/elseif without else, while+break+upval, repeat+until (with & without upval), for numeric (pos & neg step), for generic
				"local branch = 0",
				"if x == 1 then branch = 1 elseif x == 2 then branch = 2 elseif x == 10 then branch = 10 else branch = -1 end",
				"if x == 999 then branch = 999 elseif x == 888 then branch = 888 end",
				"local wsum = 0",
				"while wsum < 100 do local u = 7; local function getU() return u end; wsum = wsum + getU(); if wsum > 10 then break end end",
				"local r1 = 0; repeat r1 = r1 + 1 until r1 >= 3",
				"repeat local ru = r1; local function getRu() return ru end; r1 = getRu() + 1 until r1 >= 5",
				"local fsum = 0",
				"for i = 1, 4 do fsum = fsum + i end",
				"for i = 5, 1, -2 do fsum = fsum + i end",
				"local gsum = 0",
				"for k, v in pairs({ a = 4, b = 6 }) do gsum = gsum + v end",
				-- Globals, local nil padding, extra assignment dropping, method definitions & calls, varargs, tailcalls
				"GLOBAL_TEST_VAL = 50",
				"local l1, l2, l3 = 1",
				"local e1, e2; e1, e2 = 10, 20, 30",
				"local uninit; uninit = nil",
				"local obj = { sub = { base = 100 } }",
				"function obj.sub:add(d) return self.base + d end",
				'local mres = obj.sub:add(25) + #tostring"abc" + #{ 1, 2, 3 }',
				"local function noop() return end; noop()",
				"local function multiRet() return 3, 4, 5 end",
				"local mr1, mr2, mr3 = multiRet()",
				"local tailTbl = { multiRet() }",
				"local function varfn(a, ...)",
				"  local firstVar = ...",
				"  local listVar = { ... }",
				"  return a + firstVar + #listVar",
				"end",
				"local function legacyArg(...)",
				"  return (arg and (arg.n + arg[1])) or 40",
				"end",
				"local function tailSum(n, acc)",
				"  if n <= 0 then return acc end",
				"  return tailSum(n - 1, acc + n)",
				"end",
				"return {",
				"  long1 = long1, long2 = long2, escEnd = escEnd, escNl = escNl,",
				"  folded = folded, arith = arith, ca = ca, cs = cs,",
				"  catStr = catStr, catNum = catNum, rel1 = rel1, rel2 = rel2, logic = logic, truthyOr = truthyOr,",
				"  boolTrue = boolTbl[true], boolFalse = boolTbl[false], bigLen = #bigArr, big55 = bigArr[55],",
				"  ct1 = ct[1], ci = ci, ct2_1 = ct2[1],",
				"  branch = branch, wsum = wsum, r1 = r1, fsum = fsum, gsum = gsum,",
				"  gval = GLOBAL_TEST_VAL, l2 = l2, e2 = e2, mres = mres,",
				"  mrSum = mr1 + mr2 + mr3 + #tailTbl,",
				"  varRes = varfn(10, 20, 30),",
				"  legacyRes = legacyArg(15, 25),",
				"  tailRes = tailSum(5, 0),",
				"}",
			}, "\n")

			-- 3a. Execute via PROTO_CONVERT path (custom env table)
			local customEnv = setmetatable({
				pairs = pairs,
				tostring = tostring,
				script = h.env.Instance.new("Script"),
			}, { __index = h.env.globals })
			local fnProto, errProto = Loadstring(richProgram, customEnv)
			sert.eq(errProto, nil)
			sert.eq(type(fnProto), "function")
			local resProto = fnProto()
			sert.eq(resProto.long1, "hello\nworld")
			sert.eq(resProto.long2, "alpha\nbeta")
			sert.eq(resProto.escEnd, "tail")
			sert.eq(resProto.escNl, "line1\nline2")
			sert.eq(resProto.folded, 37)
			sert.eq(resProto.arith, 188)
			sert.eq(resProto.ca, 1000)
			sert.eq(resProto.cs, "ok!")
			sert.eq(resProto.catStr, "ABC")
			sert.eq(resProto.catNum, "1234")
			sert.eq(resProto.rel1, true)
			sert.eq(resProto.rel2, true)
			sert.eq(resProto.logic, 25)
			sert.eq(resProto.truthyOr, true)
			sert.eq(resProto.boolTrue, 11)
			sert.eq(resProto.boolFalse, 22)
			sert.eq(resProto.bigLen, 55)
			sert.eq(resProto.big55, 55)
			sert.eq(resProto.ct1, 99)
			sert.eq(resProto.ci, 2)
			sert.eq(resProto.ct2_1, 77)
			sert.eq(resProto.branch, 10)
			sert.eq(resProto.wsum, 14)
			sert.eq(resProto.r1, 5)
			sert.eq(resProto.fsum, 19)
			sert.eq(resProto.gsum, 10)
			sert.eq(resProto.gval, 50)
			sert.eq(resProto.l2, nil)
			sert.eq(resProto.e2, 20)
			sert.eq(resProto.mres, 131)
			sert.eq(resProto.mrSum, 15)
			sert.eq(resProto.varRes, 32)
			sert.eq(resProto.legacyRes, 40)
			sert.eq(resProto.tailRes, 15)

			-- 3b. Execute via LuaC bytecode dump + FiOne bc_to_state / __call path
			local fnLuaC, bytecode = Loadstring(richProgram, "LuaC")
			sert.eq(type(fnLuaC), "function")
			sert.eq(type(bytecode), "string")
			local fnFromBc = FiOne(bytecode, customEnv)
			local resBc = fnFromBc()
			sert.eq(resBc.folded, 37)
			sert.eq(resBc.arith, 188)
			sert.eq(resBc.legacyRes, 17)
			sert.eq(resBc.tailRes, 15)
			sert.eq(resBc.bigLen, 55)

			-- 4. Runtime error inside FiOne VM formats source:line error via on_lua_error
			local errFn = Loadstring('local a = 1\nerror("vm_runtime_boom")', customEnv)
			sert.eq(type(errFn), "function")
			local okRun, runErr = pcall(errFn)
			sert.eq(okRun, false)
			sert.eq(string.find(tostring(runErr), "vm_runtime_boom", 1, true) ~= nil, true)

			-- 5. Lexer and parser syntax error diagnostics return (nil, errorString)
			local invalidSnippets = {
				"if true then",
				"if true then\nlocal a = 1",
				'local s = "unterminated string',
				'local s = "unterminated\nnewline"',
				"local s = [[unterminated long string",
				"local s = [==x==[ bad sep",
				'local s = "\\u123"',
				'local s = "\\u{xyz}"',
				'local s = "\\u{FFFFFF}"',
				'local s = "\\xZZ"',
				'local s = "\\300"',
				"local n = 0b102",
				"local n = 0xGG",
				"local n = 1.2.3",
				"break",
				"continue",
				"for i 1, 10 do end",
				"local function bad(123) end",
				"local f = print\n(f)(1)",
				"\1",
				string.rep(" ", 100) .. "if then",
			}
			for _, badSrc in invalidSnippets do
				local badFn, badErr = Loadstring(badSrc)
				sert.eq(badFn, nil)
				sert.eq(type(badErr), "string")
			end
		end
	)
end)

describe("Util · Color", function()
	local Vector3 = Harness.globals.Vector3

	test("hclToRGB maps Oklab hues to known sRGB colors", function()
		local hclToRGB = Harness.shared():requireUtil().Color.hclToRGB
		local function near(c: any, r: number, g: number, b: number)
			sert.near(c.R, r, 5e-3)
			sert.near(c.G, g, 5e-3)
			sert.near(c.B, b, 5e-3)
		end
		near(hclToRGB(Vector3.new(0.25, 0.4, 1)), 1, 0.881, 0) -- yellow
		near(hclToRGB(Vector3.new(0.5, 0.4, 1)), 0, 1, 1) -- cyan
		near(hclToRGB(Vector3.new(1.25, 0.4, 1)), 1, 0.881, 0) -- hue wraps every turn
		near(hclToRGB(Vector3.new(0.7, 0, 0.5)), 0.389, 0.389, 0.389) -- zero chroma is grey at any hue
	end)

	test("hclToRGB clamps every channel to [0, 1]", function()
		local hclToRGB = Harness.shared():requireUtil().Color.hclToRGB
		local white, black = hclToRGB(Vector3.new(0, 0, 2)), hclToRGB(Vector3.new(0, 0, -1))
		for _, v in { white.R, white.G, white.B } do
			sert.near(v, 1, 5e-7)
		end
		sert.eq({ black.R, black.G, black.B }, { 0, 0, 0 })
		for i = 0, 35 do
			local c = hclToRGB(Vector3.new(i / 36, 1, 1))
			for _, v in { c.R, c.G, c.B } do
				sert(v >= 0 and v <= 1 and v == v, `hue {i}/36 channel {v} is in [0, 1]`)
			end
		end
	end)
end)

return {}
