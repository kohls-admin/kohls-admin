local Harness = require("./Harness")
local sert = require("../sert")

local describe, test, expect = sert.describe, sert.test, sert.expect
local prop = sert.prop

describe("Util · String", function()
	test("trim, trimStart, and trimEnd strip ASCII whitespace", function()
		local String = Harness.shared():requireUtil().String
		expect(String.trim("  \t\nhello world\r\n ")).toBe("hello world")
		expect(String.trimStart("  hello  ")).toBe("hello  ")
		expect(String.trimEnd("  hello  ")).toBe("  hello")
		expect(String.trim("   ")).toBe("")
	end)

	prop("escapePattern makes any literal match itself via string.find", function(g)
		local String = Harness.shared():requireUtil().String
		local raw = g:string("abc123().%+-*?[]^$", 1, 24)
		local prefix = g:string("xyz", 0, 8)
		local suffix = g:string("xyz", 0, 8)
		local haystack = prefix .. raw .. suffix
		local escaped = String.escapePattern(raw)
		local s, e = string.find(haystack, escaped)
		expect(s).toBe(#prefix + 1)
		expect(e).toBe(#prefix + #raw)
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
		expect(String.stripQuotes('"hello"')).toBe("hello")
		expect(String.stripQuotes("`world`")).toBe("world")
		expect(String.stripQuotes("plain")).toBe("plain")
		expect(#String.toFlag("US") > 0).toBe(true)
		expect(String.toFlag("")).toBe("")

		local parts = String.splitOutsideQuotes('cmd "arg with spaces" second', " ")
		expect(#parts).toBe(3)
		expect(parts[1]).toBe("cmd")
		expect(parts[2]).toBe('"arg with spaces"')
		expect(parts[3]).toBe("second")
		expect(String.splitOutsideQuotes(nil :: any)).toEqual({})
	end)

	prop("levenshteinDistance satisfies metric axioms (identity, symmetry, triangle inequality)", function(g)
		local String = Harness.shared():requireUtil().String
		local a = g:string("abcd", 0, 10)
		local b = g:string("abcd", 0, 10)
		local c = g:string("abcd", 0, 10)

		expect(String.levenshteinDistance(a, a)).toBe(0)
		local dab = String.levenshteinDistance(a, b)
		local dba = String.levenshteinDistance(b, a)
		expect(dab).toBe(dba)
		if a ~= b then
			expect(dab > 0).toBe(true)
		end
		local dbc = String.levenshteinDistance(b, c)
		local dac = String.levenshteinDistance(a, c)
		expect(dac <= dab + dbc).toBe(true)
	end, { runs = 60 })

	test("filterResult, filterForBroadcast, and filterForUser handle normal and error fallback paths", function()
		local h = Harness.newEnv()
		local Util = h:requireUtil()
		local hString = Util.String
		local p1 = h.env:addPlayer(1, "Sender")
		h.env:addPlayer(2, "Receiver")

		local ok, res = hString.filterResult("hello", 1)
		expect(ok).toBe(true)
		expect(hString.filterResultForBroadcast(res, 1)).toBe("hello")
		expect(hString.filterResultForUser(res, p1.UserId, 2)).toBe("hello")
		expect(hString.filterResultForUser(res, 9999, 2)).toBe("hello")

		-- Error string passed directly to filterResultForBroadcast / filterResultForUser
		expect(hString.filterResultForBroadcast("error msg", 1)).toBe("[Filter Error]")
		expect(hString.filterResultForUser("error msg", 1, 2)).toBe("[Filter Error]")

		-- Broken filterResult object where methods throw
		local brokenResult: any = {
			GetNonChatStringForBroadcastAsync = function()
				error("broadcast fail")
			end,
			GetNonChatStringForUserAsync = function()
				error("user fail")
			end,
		}
		expect(hString.filterResultForBroadcast(brokenResult, 1)).toBe("[Filter Error]")
		expect(hString.filterResultForUser(brokenResult, 1, 2)).toBe("[Filter Error]")

		-- Same-user shortcut in filterForUser
		expect(hString.filterForUser("secret", 1, 1)).toBe("secret")
		expect(hString.filterForBroadcast("hello", 1)).toBe("hello")
		expect(hString.filterForUser("hello", 1, 2)).toBe("hello")

		-- TextService:FilterStringAsync failure fallback -> hashes ("#")
		local TextService = h.env.game:GetService("TextService")
		local textMethods = rawget(TextService, "_methods")
		local origFilter = textMethods.FilterStringAsync
		textMethods.FilterStringAsync = function()
			error("TextService down")
		end
		expect(hString.filterForBroadcast("hello", 1)).toBe("#####")
		expect(hString.filterForUser("world!", 1, 2)).toBe("######")

		-- FilterStringAsync returns object whose GetNonChatStringForBroadcastAsync throws
		textMethods.FilterStringAsync = function()
			return brokenResult
		end
		expect(hString.filterForBroadcast("abc", 1)).toBe("###")
		textMethods.FilterStringAsync = origFilter
	end)
end)

describe("Util · Table", function()
	test("concat, countKeys, toHashMap, map, and isArray", function()
		local Table = Harness.shared():requireUtil().Table
		expect(Table.concat({ 1, "a", true }, ",")).toBe("1,a,true")
		expect(Table.countKeys({ a = 1, b = 2, c = 3 })).toBe(3)
		expect(Table.toHashMap({ "x", "y" })).toEqual({ x = true, y = true })
		expect(Table.map({ 1, 2, 3 }, function(v)
			return v * 10
		end)).toEqual({ 10, 20, 30 })
		expect(Table.isArray({ 10, 20, 30 })).toBe(true)
		expect(Table.isArray({ a = 1 })).toBe(false)
	end)

	test("merge, mergeList, deepCompare, deepMerge, and deepCopy isolation", function()
		local Table = Harness.shared():requireUtil().Table
		local dst: { [string]: any } = { a = 1, nested = { x = 10, arr = { 1, 2 } } }
		local copy = Table.deepCopy(dst)
		expect(Table.deepCompare(dst, copy)).toBe(true)
		copy.nested.x = 99
		expect(dst.nested.x).toBe(10)
		expect(Table.deepCompare(dst, copy)).toBe(false)

		Table.deepMerge(dst, { b = 2, nested = { y = 20, arr = { 3 } } }, true)
		expect(dst.b).toBe(2)
		expect(dst.nested.x).toBe(10)
		expect(dst.nested.y).toBe(20)
		expect(dst.nested.arr).toEqual({ 1, 2, 3 })

		-- deepMerge with appendArrays = true when target is a non-array dictionary
		local nonArr: { [any]: any } = { key = "val" }
		Table.deepMerge(nonArr, { "elem1", "elem2" }, true)
		expect(nonArr.key).toBe("val")
		expect(nonArr[1]).toBe("elem1")
		expect(nonArr[2]).toBe("elem2")

		local list = { 1, 2 }
		Table.mergeList(list, { 3, 4 })
		expect(list).toEqual({ 1, 2, 3, 4 })
		expect(Table.merge({ a = 1 }, { b = 2 })).toEqual({ a = 1, b = 2 })
	end)

	test("fastRemove multi-count range removal, settle sparse tables, and shuffle", function()
		local Table = Harness.shared():requireUtil().Table
		local arr = { "a", "b", "c", "d", "e", "f" }
		Table.fastRemove(arr, 2, 4)
		expect(arr).toEqual({ "a", "e", "f" })
		Table.fastRemove(arr, 5, 10)
		expect(arr).toEqual({ "a", "e", "f" })
		Table.fastRemove(arr, 2, 10)
		expect(arr).toEqual({ "a" })

		local sparse = { [1] = "x", [3] = "y", [6] = "z" }
		Table.settle(sparse)
		expect(sparse).toEqual({ "x", "y", "z" })

		local items = { 1, 2, 3, 4, 5, 6, 7, 8 }
		local shuffled = Table.shuffle(table.clone(items))
		expect(#shuffled).toBe(#items)
		table.sort(shuffled)
		expect(shuffled).toEqual(items)
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
		expect(arr).toEqual(expectedRemaining)

		sparse[idx] = nil
		Table.settle(sparse)
		expect(sparse).toEqual(expectedRemaining)

		local shuffled = Table.shuffle(table.clone(arr))
		expect(#shuffled).toBe(#arr)
		table.sort(shuffled)
		expect(shuffled).toEqual(expectedRemaining)
	end, { runs = 40 })
end)

describe("Util · Time & Logger", function()
	test("Time.fromUnit, Time.clock, and Time.readable", function()
		local Time = Harness.shared():requireUtil().Time
		expect(Time.fromUnit("m")).toBe(60)
		expect(Time.fromUnit("mss")).toBe(1 / 1000)
		expect(Time.fromUnit("hours")).toBe(3600)
		expect(Time.fromUnit("d")).toBe(86400)
		expect(Time.fromUnit("invalid_unit_xyz")).toBeNil()

		expect(Time.clock(45)).toBe("45")
		expect(Time.clock(125)).toBe("02:05")
		expect(Time.clock(3661)).toBe("01:01:01")
		expect(Time.readable(3661)).toBe("1 hour, 1 minute, 1 second")
		expect(Time.readable(172800)).toBe("2 days")
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

		expect(logger:log("ignored debug", "DEBUG")).toBeNil()
		local debugLogger = Logger.new(true)
		local entry = debugLogger:log("hello", "INFO", -42)
		expect(entry ~= nil).toBe(true)
		expect((entry :: any)[1]).toBe("hello")
		expect((entry :: any)[4]).toBe(42)
		expect(#debugLogger.logs).toBe(1)
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
				expect(q:Dequeue()).toBe(expected)
			end
			expect(q:IsEmpty()).toBe(#ref == 0)
		end
		while not q:IsEmpty() do
			expect(q:Dequeue()).toBe(table.remove(ref, 1))
		end
		expect(function()
			q:Dequeue()
		end).toThrow()
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
		expect(onceConn.Connected).toBe(false)
		expect(c1.Connected).toBeNil()
		sig:Fire(2)
		c2:Disconnect()
		-- Calling Disconnect a second time is a safe no-op
		c2:Disconnect()
		sig:Fire(3)
		expect(seen).toEqual({ "once:1", "c2:1", "c2:2" })

		local waited, waited2 = nil, nil
		h.env.task.spawn(function()
			waited, waited2 = sig:Wait()
		end)
		sig:Fire("woken", 99)
		expect(waited).toBe("woken")
		expect(waited2).toBe(99)

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
		expect(neverWoken).toBe(false)
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
		expect(#results).toBe(3)
		expect(results[1][1]).toBe(true)
		expect(results[1][2]).toBe(11)
		expect(results[2][1]).toBe(true)
		expect(results[2][2]).toBe(40)
		expect(results[3][1]).toBe(false)

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
		expect(firstOk).toBe(true)
		expect(firstVal).toBe("fast")
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
		expect(ok).toBe(true)
		expect(val).toBe(42)
		expect(calls).toBe(3)

		local failCalls = 0
		local ok2 = Retry(function()
			failCalls += 1
			error("permanent")
		end, 3, 0.01)
		expect(ok2).toBe(false)
		expect(failCalls).toBe(3)

		-- 0 attempts skips loop and returns false (line 21 of Retry.luau)
		expect(Retry(function()
			return true
		end, 0)).toBe(false)
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
		expect(#debouncedArgs).toBe(0)
		h.env:step(0.03)
		expect(#debouncedArgs).toBe(1)
		expect(debouncedArgs[1]).toEqual({ "second", 2 })

		local throttledCalls = {}
		local throttled = Util.Function.throttle(0.05, function(v)
			table.insert(throttledCalls, v)
		end)
		throttled("immediate")
		throttled("replaced_trailing")
		throttled("final_trailing")
		expect(throttledCalls).toEqual({ "immediate" })
		h.env:step(0.06)
		expect(throttledCalls).toEqual({ "immediate", "final_trailing" })

		local r = Util.Rollout.new("2025-01-01", "2025-12-31", "TestFeature", 42, 1)
		expect(type(r:test(12345))).toBe("boolean")
		r:setFFlagDictionary({ TestFeature = true })
		expect(r:test(12345)).toBe(true)
		r:setFFlagDictionary({ TestFeature = false })
		expect(r:test(12345)).toBe(false)
		r:setFFlagDictionary(nil)
	end)

	test(
		"Suggest.new and Suggest.query rank exact, prefix, substring, and levenshtein matches and validate inputs",
		function()
			local h = Harness.newEnv()
			local Suggest = h:requireUtil().Suggest

			local names = { "teleport", "tempban", "kick", "ban", " blind " }
			local exact = Suggest.query("ban", names)
			expect(exact[1][1]).toBe("ban")
			expect(exact[2][1]).toBe("tempban")

			local prefix = Suggest.query("tele", names)
			expect(prefix[1][1]).toBe("teleport")

			local typo = Suggest.query("kic", names)
			expect(typo[1][1]).toBe("kick")

			local lev = Suggest.query("kixk", names)
			expect(lev[1][1]).toBe("kick")

			local enumNames, enumInsts = Suggest.new(h.env.globals.Enum.Font)
			expect(#enumNames > 0).toBe(true)
			expect(#enumInsts > 0).toBe(true)

			local folder = h.env.Instance.new("Folder")
			local child = h.env.Instance.new("Part", folder)
			child.Name = "AlphaPart"
			local folderNames = Suggest.new(folder)
			expect(folderNames[1]).toBe("AlphaPart")

			-- Table of tables with .Name / .name fields (line 115 of Suggest.luau)
			local tblNames, tblItems = Suggest.new({ { Name = "ObjA" }, { name = "ObjB" } })
			expect(tblNames).toEqual({ "ObjA", "ObjB" })
			expect(#tblItems).toBe(2)

			-- Empty table returns empty names
			local emptyNames = Suggest.new({})
			expect(emptyNames).toEqual({})

			-- Invalid element type or non-table/Enum/Instance argument throws
			expect(function()
				Suggest.new({ 12345 } :: any)
			end).toThrow()
			expect(function()
				Suggest.new(12345 :: any)
			end).toThrow()
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
			expect(part.Name).toBe("Locked")

			-- Updating an already-overridden property updates the lock target
			Util.Property.override(part, "Name", "Relocked")
			expect(part.Name).toBe("Relocked")

			part.Name = "UpdatedUnderlying"
			expect(part.Name).toBe("Relocked")

			Util.Property.reset(part, "Name")
			expect(part.Name).toBe("UpdatedUnderlying")

			-- Destroying an instance cleans up active overrides
			Util.Property.override(part, "Name", "BeforeDestroy")
			expect(Util.Property.cache[part] ~= nil).toBe(true)
			part:Destroy()
			expect(Util.Property.cache[part]).toBeNil()
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
				expect(applySpy.callCount).toBe(0)

				Util.Humanoid.attributeDescription(player, "Shirt", 999)
				expect(desc.Shirt).toBe(999)
				expect(player:GetAttribute("_KShirtOriginal")).toBe(111)
				expect(applySpy.callCount).toBe(1)

				desc.Shirt = 111
				Util.Humanoid.reapplyDescription(player)
				expect(desc.Shirt).toBe(999)
				expect(applySpy.callCount).toBe(2)

				-- Also test _KHumanoidDescription restoration on player
				local savedDesc = h.env.Instance.new("HumanoidDescription", player)
				savedDesc.Name = "_KHumanoidDescription"
				savedDesc.Shirt = 222

				Util.Humanoid.resetDescription(player)
				expect(hum:FindFirstChildOfClass("HumanoidDescription")).toBe(savedDesc)
				expect(savedDesc.Name).toBe("HumanoidDescription")
				expect(savedDesc.Shirt).toBe(111)
				expect(player:GetAttribute("_KShirtOriginal")).toBeNil()
				expect(applySpy.callCount).toBe(3)
				expect(root:FindFirstChild("_KFire")).toBeNil()

				-- Fallback to character.PrimaryPart when HumanoidRootPart is absent (line 69 of Humanoid.luau)
				root.Name = "Torso"
				character.PrimaryPart = root
				local smoke = h.env.Instance.new("Smoke", root)
				smoke.Name = "_KSmoke"
				savedDesc:Destroy()
				Util.Humanoid.resetDescription(player)
				expect(applySpy.callCount).toBe(3)
				expect(root:FindFirstChild("_KSmoke")).toBeNil()
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
				expect(seenPages.p1).toEqual({ val = 10, page = 1 })
				expect(seenPages.p2).toEqual({ val = 20, page = 2 })

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
				expect(advanceAttempts).toBe(2)
				expect(retrySeen.p1).toEqual({ val = 10, page = 1 })
				expect(retrySeen.p2).toEqual({ val = 20, page = 2 })

				-- MemoryStore.getSharded returns (true, nil) when shards are empty vs (false, nil) when all GetAsync calls fail
				local probeCount = 0
				local emptyShardMap: any = {
					GetAsync = function()
						probeCount += 1
						return nil
					end,
				}
				expect({ Util.MemoryStore.getSharded(emptyShardMap, "ZeroShards", 0) }).toEqual({ false, nil })
				local emptyOk, emptyVal = Util.MemoryStore.getSharded(emptyShardMap, "EmptyPrefix", 4, 2)
				expect(emptyOk).toBe(true)
				expect(emptyVal).toBeNil()
				expect(probeCount).toBe(2)

				probeCount = 0
				local defaultProbesOk = Util.MemoryStore.getSharded(emptyShardMap, "DefaultProbes", 4)
				expect(defaultProbesOk).toBe(true)
				expect(probeCount).toBe(4)

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
				expect(setOk).toBe(true)
				expect(shardedData["HitPrefix_1"]).toBe("payload_val")
				expect(shardedData["HitPrefix_2"]).toBe("payload_val")
				expect(shardedData["HitPrefix_3"]).toBe("payload_val")
				local hitOk, hitVal = Util.MemoryStore.getSharded(shardMap, "HitPrefix", 3, 2, 1)
				expect(hitOk).toBe(true)
				expect(hitVal).toBe("payload_val")

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
				expect(failOk).toBe(false)
				expect(failVal).toBeNil()

				local fakeMap: any = {
					ListItemsAsync = function()
						return makeMultiPages()
					end,
				}
				local multiItems = Util.MemoryStore.getItemsFromHashMap(fakeMap)
				expect(multiItems).toEqual({ p1 = 10, p2 = 20 })

				local ms = h.env.game:GetService("MemoryStoreService")
				local map = ms:GetHashMap("TestMap")
				map:SetAsync("k1", { v = 1 }, 60)
				map:SetAsync("k2", { v = 2 }, 60)

				local items = Util.MemoryStore.getItemsFromHashMap(map)
				expect(items.k1.v).toBe(1)
				expect(items.k2.v).toBe(2)

				-- String.hash (32-bit FNV-1a) and MemoryStore.shardIndex full-ring permutation & uniform distribution
				expect(Util.String.hash("")).toBe(0x811C9DC5)
				expect(Util.String.hash("a")).toBe(0xE40C292C)
				expect(Util.String.hash("foobar")).toBe(0xBF9CF968)
				expect(Util.MemoryStore.shardIndex("any", 1)).toBe(1)

				for _, shardCount in { 7, 8, 16, 64, 67 } do
					local visited = {}
					for offset = 0, shardCount - 1 do
						local idx = Util.MemoryStore.shardIndex("chunk_key", shardCount, offset, "job-seed-123")
						expect(idx >= 1 and idx <= shardCount).toBe(true)
						expect(visited[idx]).toBeNil()
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
					expect(counts[s] >= 65 and counts[s] <= 135).toBe(true)
				end

				-- SafePlayerAdded duplicate PlayerAdded guard & last-player PlayerRemoving cleanup
				local pA = h.env:addPlayer(50, "PlayerA")
				local addedCount = 0
				Util.SafePlayerAdded(function(_plr)
					addedCount += 1
				end)
				expect(addedCount).toBe(1)
				-- Firing PlayerAdded again for already-processed pA is a no-op (line 25)
				h.env.Players.PlayerAdded:Fire(pA)
				expect(addedCount).toBe(1)
				-- Adding a second player then removing one, then removing the last player clears cache[processed] (lines 14-15)
				h.env:addPlayer(51, "PlayerB")
				expect(addedCount).toBe(2)
				h.env:removePlayer(50)
				h.env:removePlayer(51)
				expect(#h.env.Players:GetPlayers()).toBe(0)
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
			expect(ok1).toBe(true)

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
			expect(retryOk).toBe(true)
			expect(retryRes).toBe("teleport_result")
			expect(attempts).toBe(3)
			expect(lastOptions.custom).toBe(true)

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
			expect(failOk).toBe(false)
			expect(attempts).toBe(5)

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
			expect(initRetryCalls).toBe(0)

			-- Failure waits RETRY_DELAY (1s) and Flooded waits FLOOD_DELAY (15s) then calls SafeTeleport
			local tBeforeFail = h.env.globals.os.clock()
			TeleportService.TeleportInitFailed:Fire(
				plr,
				h.env.globals.Enum.TeleportResult.Failure,
				"network error",
				12345,
				options
			)
			local failElapsed = h.env.globals.os.clock() - tBeforeFail
			expect(failElapsed >= 1 and failElapsed < 5).toBe(true)
			expect(initRetryCalls).toBe(1)

			local tBeforeFlood = h.env.globals.os.clock()
			TeleportService.TeleportInitFailed:Fire(
				plr,
				h.env.globals.Enum.TeleportResult.Flooded,
				"flooded",
				12345,
				options
			)
			local floodElapsed = h.env.globals.os.clock() - tBeforeFlood
			expect(floodElapsed >= 15).toBe(true)
			expect(initRetryCalls).toBe(2)

			tpMethods.TeleportAsync = origTeleport

			-- Defer.reset and Defer.wait budget enforcement
			local deferYields = 0
			Util.Defer.reset()
			h.env.task.delay(0, function()
				deferYields += 1
			end)
			Util.Defer.wait()
			expect(deferYields).toBe(0)
			h.env:step(1.1)
			expect(deferYields).toBe(1)
			h.env.task.delay(0, function()
				deferYields += 1
			end)
			Util.Defer.wait()
			expect(deferYields).toBe(2)
			h.env.task.delay(0, function()
				deferYields += 1
			end)
			Util.Defer.wait()
			expect(deferYields).toBe(2)

			-- Service.__index lazy caching into raw table
			expect(rawget(Util.Service, "Debris")).toBeNil()
			local debrisSvc = Util.Service.Debris
			expect(debrisSvc).toBe(h.env.game:GetService("Debris"))
			expect(rawget(Util.Service, "Debris")).toBe(debrisSvc)
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
			expect(Util.getTexture(1001)).toBeNil()

			-- 2. Image AssetTypeId (1) returns rbxassetid:// directly and caches
			local infoCalls = 0
			marketSpy:mockImplementation(function(_self, assetId)
				infoCalls += 1
				return { AssetTypeId = h.env.globals.Enum.AssetType.Image.Value, AssetId = assetId }
			end)
			expect(Util.getTexture(1002)).toBe("rbxassetid://1002")
			expect(Util.getTexture(1002)).toBe("rbxassetid://1002")
			expect(infoCalls).toBe(1)

			-- 3. Server LoadAsset branch (Face/Shirt/Pants/TShirt) extracts Decal.Texture
			marketSpy:mockImplementation(function()
				return { AssetTypeId = h.env.globals.Enum.AssetType.Face.Value }
			end)
			local insertSpy = sert.spy(InsertService, "LoadAsset", function()
				local model = h.env.Instance.new("Model")
				local decal = h.env.Instance.new("Decal", model)
				decal.Texture = "rbxassetid://999888"
				return model
			end)
			expect(Util.getTexture(1003)).toBe("rbxassetid://999888")

			-- 4. Fallback to rbxthumb when LoadAsset fails (both small=true 150 and small=false 420)
			insertSpy:mockImplementation(function()
				error("LoadAsset blocked")
			end)
			expect(Util.getTexture(1004, true)).toBe("rbxthumb://type=Asset&id=1004&w=150&h=150")
			expect(Util.getTexture(1005, false)).toBe("rbxthumb://type=Asset&id=1005&w=420&h=420")
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
				expect(unknown.Username).toBe("Unknown")

				-- Online player via SafePlayerAdded populates cache immediately
				local online = h.env:addPlayer(10, "OnlineUser")
				expect(Util.getUserInfo(online.UserId, true).Username).toBe("OnlineUser")
				expect(Util.getUserInfo(online.UserId).Username).toBe("OnlineUser")

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
				expect(info202 ~= nil).toBe(true)
				expect(info202.Username).toBe("BatchUser202")
				expect(infoDeleted ~= nil).toBe(true)
				expect(infoDeleted.Username).toBe("Deleted")
				expect(infoDeleted.Deleted).toBe(true)

				-- UserService transient error followed by recovery retry
				local attempts = 0
				userSpy:mockImplementation(function(_self, _ids)
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
				expect(info303 ~= nil).toBe(true)
				expect(info303.Username).toBe("Recovered303")
				expect(attempts).toBe(2)

				-- >200 concurrent userIds triggers chunked re-deferral (lines 31 & 69)
				userSpy:mockImplementation(function(_self, ids)
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
				expect(got205 ~= nil).toBe(true)
				expect(got205.Username).toBe("U1205")

				-- Permanent failure across all 6 attempts triggers warn + 5s delay retry, then succeeds (lines 74 & 76)
				local permFails = 0
				userSpy:mockImplementation(function(_self, ids)
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
				expect(infoOutage ~= nil).toBe(true)
				expect(infoOutage.Username).toBe("AfterOutage")
				userSpy:restore()

				-- Server OnServerInvoke and Client InvokeServer paths (lines 90-95 & 113)
				local getUserInfoMod = h.Shared:WaitForChild("Util"):WaitForChild("getUserInfo")
				local rf = getUserInfoMod:FindFirstChildOfClass("RemoteFunction")
				expect(rf ~= nil).toBe(true)
				local srvInvokeRes = rf.OnServerInvoke(online, online.UserId)
				expect(srvInvokeRes.Username).toBe("OnlineUser")

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
				expect(cInfo777.Username).toBe("ClientFetched777")
				local cInfoNil = cGetUserInfo(888)
				expect(cInfoNil.Username).toBe("Unknown")
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
			expect(calls).toEqual({ { 501 } })

			-- a new lookup during the backoff must not cancel and restart 501's batch
			h.env.task.spawn(function()
				info502 = Util.getUserInfo(502)
			end)
			h.env:step(0.5)
			expect(calls).toEqual({ { 501 } })

			for _ = 1, 4 do
				h.env:step(0.5)
			end
			expect(calls).toEqual({ { 501 }, { 501 }, { 502 } })
			expect(info501.Username).toBe("U501")
			expect(info502.Username).toBe("U502")
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
			expect(info501.Username).toBe("U501")
			table.sort(calls[1])
			expect(calls[1]).toEqual({ 501, 10001, 10002 })
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
			expect(#calls).toBe(7)
			for _, ids in calls do
				expect(ids).toEqual({ 601 })
			end
			expect(info601.Username).toBe("U601")
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
				expect(rf.OnServerInvoke(player, bad)).toBe(nil)
			end
			h.env:step(1)
			expect(calls).toBe(0)

			-- Studio local server players have negative ids the server already cached
			h.env:addPlayer(-1, "Player1")
			expect(rf.OnServerInvoke(player, -1).Username).toBe("Player1")

			local info
			h.env.task.spawn(function()
				info = rf.OnServerInvoke(player, 1)
			end)
			h.env:step(1)
			expect(info.Username).toBe("U1")
			expect(Util.getUserInfo(1).Username).toBe("U1")
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
			expect(results[2032]).toBe(nil)
			expect(results[2033]).toBe(false)
			expect(results[2034]).toBe(false)
			-- another player's lookup is not refused for it
			invoke(other, 3001)
			h.env:step(1)
			expect(#calls).toBe(1)
			expect(#calls[1]).toBe(33)
			expect(results[2001].Username).toBe("U2001")
			expect(results[2032].Username).toBe("U2032")
			expect(results[3001].Username).toBe("U3001")

			-- finished lookups free the cap
			for userId = 2101, 2132 do
				invoke(flooder, userId)
			end
			h.env:step(1)
			expect(results[2132].Username).toBe("U2132")

			-- lookups still waiting when their player leaves finish without error
			userMethods.GetUserInfosByUserIdsAsync = function()
				error("UserService 500")
			end
			for userId = 2201, 2232 do
				invoke(flooder, userId)
			end
			h.env:step(0.5)
			expect(rf.OnServerInvoke(flooder, 2233)).toBe(nil)
			h.env:removePlayer(12)
			-- a request handled after the player left is refused, not counted again
			invoke(flooder, 2234)
			expect(results[2234]).toBe(false)
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
			expect(results[2201].Username).toBe("U2201")
			expect(results[2232].Username).toBe("U2232")

			-- the same user rejoining gets a full cap again
			local rejoined = h.env:addPlayer(12, "Flooder")
			for userId = 2301, 2333 do
				invoke(rejoined, userId)
			end
			expect(results[2332]).toBe(nil)
			expect(results[2333]).toBe(false)
			h.env:step(1)
			expect(results[2332].Username).toBe("U2332")
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

			expect(peak).toBe(32)
			expect(names.failed).toBe("Unknown")
			expect(names.missing).toBe("Unknown")
			for i = 1, 100 do
				expect(names[i]).toBe(`U{5000 + i}`)
			end
			for i = 101, 200 do
				expect(names[i]).toBe("U5001")
			end
			-- lookups of one id share a single invoke
			expect(invokes[5001]).toBe(1)
			expect(active).toBe(0)

			-- every slot was handed back, including those of the failed and missing lookups
			peak = 0
			for i = 1, 33 do
				lookup(`after{i}`, 6000 + i)
			end
			expect(active).toBe(32)

			-- an id that came back Unknown is looked up again next time
			lookup("missingAgain", 4998)
			for _ = 1, 4 do
				hc.env:step(0.5)
			end
			expect(peak).toBe(32)
			expect(names.after33).toBe("U6033")
			expect(invokes[4998]).toBe(2)
			expect(names.missingAgain).toBe("Unknown")
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
			expect(huge.Username).toBe("Unknown")
			expect(calls).toEqual({ { 701 } })
			expect(info701.Username).toBe("U701")
		end)

		test(
			"Remote handles client ServerReady wait, duplicate syncPayload, unindexed server remote, failed queued Invoke, and 5s infinite yield warn",
			function()
				local world = sert.sim.new({ backing = true })
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
				expect(cRemote ~= nil).toBe(true)

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
				expect(cRemote.QueuedErrorInvoke._fireQueue ~= nil).toBe(true)
				client:spawn(function()
					cRemote.QueuedErrorInvoke:Invoke("arg1")
					invokeReturned = true
				end)
				expect(cRemote.QueuedErrorInvoke._invokeQueue ~= nil).toBe(true)
				sRemote.QueuedErrorInvoke:Connect(function(_plr, arg)
					if arg == "queued_fire_arg" then
						queuedFires += 1
					end
				end)
				sRemote.QueuedErrorInvoke.OnInvoke = function()
					error("Queued OnInvoke boom")
				end
				world:run(1)
				expect(invokeReturned).toBe(true)
				expect(queuedFires).toBe(1)
				expect(cRemote.QueuedErrorInvoke._fireQueue).toBeNil()
				expect(cRemote.QueuedErrorInvoke._invokeQueue).toBeNil()

				-- SetUnreliable on server updates _remote and replicates to client; on client it warns without mutating _remote
				local cUnreliableEvent = cRemoteMod:WaitForChild("UnreliableRemoteEvent")
				sRemote.ServerCreatedOnly:SetUnreliable(true)
				world:run(0.2)
				expect(cRemote.ServerCreatedOnly._remote).toBe(cUnreliableEvent)
				sRemote.ServerCreatedOnly:SetUnreliable(false)
				world:run(0.2)
				expect(cRemote.ServerCreatedOnly._remote).toBe(cEvent)
				cRemote.ServerCreatedOnly:SetUnreliable(true)
				expect(cRemote.ServerCreatedOnly._remote).toBe(cEvent)

				-- Server and Client RemoteFunction guard against unknown remote id or remote without OnInvoke
				local sFunc = sh.Shared:WaitForChild("Util"):WaitForChild("Remote"):WaitForChild("RemoteFunction")
				local cFunc = cRemoteMod:WaitForChild("RemoteFunction")
				expect(sFunc.OnServerInvoke(sh.env.Players:GetPlayerByUserId(101), "\255\255")).toBeNil()
				expect(sFunc.OnServerInvoke(sh.env.Players:GetPlayerByUserId(101), sRemote.ServerCreatedOnly._id)).toBeNil()
				expect(cFunc.OnClientInvoke("\255\255")).toBeNil()
				expect(cFunc.OnClientInvoke(cRemote.ServerCreatedOnly._id)).toBeNil()

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
				expect(standaloneRemote ~= nil).toBe(true)
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
			expect(LuaY:getcompopr("TK_ASSIGN_ADD")).toBe("OP_ADD")

			-- 1. LoadScript caches bytecode, clones Server/Client base scripts, and rejects invalid base
			expect(LoadScript("return 1", "InvalidBase" :: any)).toBeNil()
			local sScript1 = LoadScript("return 42", "Server")
			local sScript2 = LoadScript("return 42", "Server") -- hits bytecodeCache (line 14)
			expect(sScript1 ~= nil).toBe(true)
			expect(sScript2 ~= nil).toBe(true)
			expect(sScript1:GetAttribute("Source")).toBe("return 42")

			local clientFolder = h.env.Instance.new("Folder")
			local cScript = LoadScript("return 99", "Client", clientFolder)
			expect(cScript ~= nil).toBe(true)
			expect(cScript.Parent).toBe(clientFolder)
			expect(cScript:GetAttribute("Source")).toBeNil()

			-- 2. LuaZ & LuaP direct helper coverage
			expect(LuaZ:init(nil)).toBeNil()
			local zStream = LuaZ:init(LuaZ:make_getS("abc"), "data_str")
			expect(zStream.n).toBe(8)

			local inst = LuaP:CREATE_Inst(64 * 5 + 1)
			expect(type(inst)).toBe("table")
			local abcInst = LuaP:CREATE_ABC("OP_MOVE", 1, 2, 3)
			expect(LuaP:GETARG_B(abcInst)).toBe(2)
			expect(LuaP:GETARG_C(abcInst)).toBe(3)
			LuaP:SET_OPCODE(inst, "OP_MOVE")
			LuaP:SETARG_Bx(inst, 123)
			expect(LuaP:GETARG_Bx(inst)).toBe(123)
			expect(LuaP:INDEXK(256)).toBe(0)
			expect(type(LuaP:testAMode("OP_MOVE"))).toBe("number")
			local decoded = LuaP:DecodeInst("\0\1\2\3")
			expect(type(decoded.OP)).toBe("number")
			local decodedBx = LuaP:DecodeInst("\1\1\2\3") -- OP_LOADK (iABx)
			expect(type(decodedBx.Bx)).toBe("number")

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
			expect(errProto).toBeNil()
			expect(type(fnProto)).toBe("function")
			local resProto = fnProto()
			expect(resProto.long1).toBe("hello\nworld")
			expect(resProto.long2).toBe("alpha\nbeta")
			expect(resProto.escEnd).toBe("tail")
			expect(resProto.escNl).toBe("line1\nline2")
			expect(resProto.folded).toBe(37)
			expect(resProto.arith).toBe(188)
			expect(resProto.ca).toBe(1000)
			expect(resProto.cs).toBe("ok!")
			expect(resProto.catStr).toBe("ABC")
			expect(resProto.catNum).toBe("1234")
			expect(resProto.rel1).toBe(true)
			expect(resProto.rel2).toBe(true)
			expect(resProto.logic).toBe(25)
			expect(resProto.truthyOr).toBe(true)
			expect(resProto.boolTrue).toBe(11)
			expect(resProto.boolFalse).toBe(22)
			expect(resProto.bigLen).toBe(55)
			expect(resProto.big55).toBe(55)
			expect(resProto.ct1).toBe(99)
			expect(resProto.ci).toBe(2)
			expect(resProto.ct2_1).toBe(77)
			expect(resProto.branch).toBe(10)
			expect(resProto.wsum).toBe(14)
			expect(resProto.r1).toBe(5)
			expect(resProto.fsum).toBe(19)
			expect(resProto.gsum).toBe(10)
			expect(resProto.gval).toBe(50)
			expect(resProto.l2).toBeNil()
			expect(resProto.e2).toBe(20)
			expect(resProto.mres).toBe(131)
			expect(resProto.mrSum).toBe(15)
			expect(resProto.varRes).toBe(32)
			expect(resProto.legacyRes).toBe(40)
			expect(resProto.tailRes).toBe(15)

			-- 3b. Execute via LuaC bytecode dump + FiOne bc_to_state / __call path
			local fnLuaC, bytecode = Loadstring(richProgram, "LuaC")
			expect(type(fnLuaC)).toBe("function")
			expect(type(bytecode)).toBe("string")
			local fnFromBc = FiOne(bytecode, customEnv)
			local resBc = fnFromBc()
			expect(resBc.folded).toBe(37)
			expect(resBc.arith).toBe(188)
			expect(resBc.legacyRes).toBe(17)
			expect(resBc.tailRes).toBe(15)
			expect(resBc.bigLen).toBe(55)

			-- 4. Runtime error inside FiOne VM formats source:line error via on_lua_error
			local errFn = Loadstring('local a = 1\nerror("vm_runtime_boom")', customEnv)
			expect(type(errFn)).toBe("function")
			local okRun, runErr = pcall(errFn)
			expect(okRun).toBe(false)
			expect(string.find(tostring(runErr), "vm_runtime_boom", 1, true) ~= nil).toBe(true)

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
				expect(badFn).toBeNil()
				expect(type(badErr)).toBe("string")
			end
		end
	)
end)

describe("Util · Color", function()
	local Vector3 = Harness.globals.Vector3

	test("hclToRGB maps Oklab hues to known sRGB colors", function()
		local hclToRGB = Harness.shared():requireUtil().Color.hclToRGB
		local function near(c: any, r: number, g: number, b: number)
			expect(c.R).toBeCloseTo(r, 2)
			expect(c.G).toBeCloseTo(g, 2)
			expect(c.B).toBeCloseTo(b, 2)
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
			expect(v).toBeCloseTo(1, 6)
		end
		expect({ black.R, black.G, black.B }).toEqual({ 0, 0, 0 })
		for i = 0, 35 do
			local c = hclToRGB(Vector3.new(i / 36, 1, 1))
			for _, v in { c.R, c.G, c.B } do
				sert(v >= 0 and v <= 1 and v == v, `hue {i}/36 channel {v} is in [0, 1]`)
			end
		end
	end)
end)

return {}
