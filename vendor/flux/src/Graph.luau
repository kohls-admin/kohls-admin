--!strict
--!optimize 2
--[[
The reactive graph: signals hold values, computeds derive them lazily, effects react to them, and scopes own the
reactions and cleanups created inside them. The documented members are flat on `Flux`.

```luau
local count = Flux.signal(0)
local doubled = Flux.computed(function()
	return count() * 2
end)
Flux.effect(function() print(doubled()) end) -- prints 0, then 10 on the flush after `count(5)`
count(5)
```
]]

local Compat = require("./Compat")

local IS_ROBLOX = Compat.isRoblox
local compatTypeof = Compat.typeof
local task = Compat.task
local traceback = Compat.traceback
local warn = Compat.warn

-- Clean ---------------------------------------------------------------------------------------------------------------

-- A callback is listed per arity: the solver refuses a `() -> ()` (an unsubscribe, say) against a two-parameter one.
export type Cleanable =
	(() -> ())
	| ((oldValue: any) -> ())
	| ((oldValue: any, destroyed: boolean) -> ())
	| thread
	| Instance
	| RBXScriptConnection
	| { read Destroy: (self: any) -> () }
	| { read destroy: (self: any) -> () }
	| { read Disconnect: (self: any) -> () }
	| { read disconnect: (self: any) -> () }
	| { read [number]: Cleanable }

local function kindOf(value: any): string
	local kind = typeof(value)
	if kind == "table" and not IS_ROBLOX then
		return compatTypeof(value)
	end
	return kind
end

local destroyInstance: (instance: Instance) -> () = if IS_ROBLOX
	then (game :: { Destroy: (Instance) -> () }).Destroy
	else function(instance: Instance)
		instance:Destroy()
	end

local disposeTable: (obj: any) -> ()

local registry: { [any]: (obj: any) -> () } = setmetatable({}, { __mode = "k" })

local function register(obj: { [any]: any }, teardown: ((obj: any) -> ())?)
	registry[obj] = teardown
end

local function teardownOf(obj: any): ((obj: any) -> ())?
	return if type(obj.Destroy) == "function"
		then obj.Destroy
		elseif type(obj.destroy) == "function" then obj.destroy
		elseif type(obj.Disconnect) == "function" then obj.Disconnect
		elseif type(obj.disconnect) == "function" then obj.disconnect
		else nil
end

local function protect(kind: string, fn: (...any) -> ...any, ...: any): boolean
	local ok, err = xpcall(fn, traceback, ...)
	if not ok then
		warn(`[Flux] {kind} error:\n{err}`)
	end
	return ok
end

local function userdataTeardown(obj: any): ((obj: any) -> ())?
	if getmetatable(obj) == nil then
		return nil
	end
	local ok, method = pcall(teardownOf, obj)
	return if ok then method else nil
end

local cleanSeen: { [any]: boolean } = {}

local function clean(obj: any)
	local kind = kindOf(obj)
	if kind == "function" then
		protect("cleanup", obj :: () -> ())
	elseif kind == "table" then
		local teardown: (obj: any) -> () = registry[obj] or disposeTable
		protect("cleanup", teardown, obj)
	elseif kind == "Instance" then
		protect("cleanup", destroyInstance, obj :: Instance)
	elseif kind == "RBXScriptConnection" then
		local connection = obj :: RBXScriptConnection
		if connection.Connected then
			connection:Disconnect()
		end
	elseif kind == "userdata" then
		local method = userdataTeardown(obj)
		if method ~= nil then
			protect("cleanup", method, obj)
		end
	elseif kind == "thread" then
		if coroutine.status(obj :: thread) == "suspended" then
			protect("cleanup", task.cancel, obj :: thread)
		end
	end
end

local function cleanArrayItems(obj: any)
	for _, item in obj do
		clean(item)
	end
end

function disposeTable(obj: any)
	local method = teardownOf(obj)
	if method ~= nil then
		method(obj)
	elseif obj[1] ~= nil then
		if cleanSeen[obj] then
			return
		end
		cleanSeen[obj] = true
		local ok, err = pcall(cleanArrayItems, obj)
		cleanSeen[obj] = nil
		if not ok then
			error(err, 0)
		end
	end
end

local function isCleanable(obj: any): boolean
	local kind = kindOf(obj)
	if kind == "table" then
		return registry[obj] ~= nil or teardownOf(obj) ~= nil or obj[1] ~= nil or next(obj) == nil
	elseif kind == "userdata" then
		return userdataTeardown(obj) ~= nil
	end
	return kind == "function" or kind == "Instance" or kind == "RBXScriptConnection" or kind == "thread"
end

-- Node layout & scheduling state --------------------------------------------------------------------------------------

--- @ignore
type node = any

-- Node slots. Cache Line 0 (slots 1..4 = 64B) packs the 4 hot fields (VALUE, HEIGHT, STAMP, OBSERVERS):
-- signal:   VALUE nil    CHANGED NOBS    SEEN                                            | observers from SIG_OBS0+1
-- computed: VALUE HEIGHT STAMP OBSERVERS SEEN CHANGED FN NSRC NEXT CHILDREN              | (source, back) from SRC1
-- effect:   E_FN  INF    STAMP E_NSRC    E_CHILDREN                                      | (source, back) from E_SRC1
-- scope:    nil   SCOPE  INF   true      false false true false false CHILDREN
local VALUE = 1
local HEIGHT = 2 -- nil for signals, >= 1 for computeds, INF for effects, SCOPE for scopes, false for observer lists
local STAMP = 3 -- signal: epoch of last change; computed: 0 dirty, DEFERRED, STALE/ERRORED, LIVE_BASE+h live, epoch dead; INF clean effect/scope
local SIG_CHANGED = 3
local OBSERVERS = 4 -- computed: false, its one live observer, or a list of 2+ (see subscribe). signal: the count of its inline observers
local SEEN = 5 -- run id of the last run that stamped this node as read (dedupes repeated reads)
local CHANGED = 6 -- computed: epoch of the last value change
local FN = 7 -- nil once disposed
local NSRC = 8 -- next source slot past the end of source pairs
local NEXT = 9 -- intrusive heap link: false when not queued, else the next node in its bucket or true
local CHILDREN = 10 -- owned nodes (cleanups under `fns`); false, or nil once a reader has dropped this computed
local SRC1 = 11
local SIG_OBS0 = 5
local SIG_OBS1 = 6
local OBS1 = 3

local E_FN = 1 -- nil once disposed (in VALUE's slot: an effect has no cached value)
local E_NSRC = 4 -- in OBSERVERS's slot (>= E_SRC1, always truthy)
local E_CHILDREN = 5
local E_SRC1 = 6

local INF = math.huge
local SCOPE = -1
local DEFERRED = -1
local STALE = -2
local ERRORED = -3
local LIVE_MAX_IDLE = -4
local LIVE_BASE = -1073741824

local epoch = 1

local failed: { [any]: true } = setmetatable({}, { __mode = "k" })
local nFailed = 0

local heap: { any } = table.create(512, false)
local heapMin = INF
local liveMax = LIVE_MAX_IDLE
local heapMax = 0

local queue: { any } = {}
local queueHead = 1
local queueTail = 0
local queueCap = 0
local flushing = false

local RERUN_LIMIT = 100
local GUARD_PASSES = 32
local passes = 0
local counted = 0
local reruns: { [any]: number } = {}
local cycles: { [any]: number } = {}
local anyReruns = false

local curNode: any = nil
local curIdx = 0
local curNew: any = nil
local DIVERGED = 2
local DISPOSED_NSRC = 2 ^ 30
-- Run id for `SEEN` and `suspRun`. Runs start at `-1`, and `track` or `untrack()` allocates a positive id on first use.
local curRun: number = -1
local runId = 0

local curOwner: any = nil
local curChildren: any = nil
local ownerSet = false

local susp: any = nil
local suspRun = 0

local evalNode: any = nil
local evalFromUntrack = false
local runningEffect: any = nil
local OUTER_ACTIVE: any = {}
local noEffect: any = nil
type RunningFrame = { idx: number, newList: any, run: number, canCheck: boolean, written: boolean }
local activeEffects: { [any]: RunningFrame } = {}
local nestedRunning = 0

--- @ignore
type ContextFrame = { parent: ContextFrame?, key: any, value: any, tokens: { [any]: any }? }
local curCtx: ContextFrame? = nil

local liveHooks = 0
local hasHooks = false
local liveDestroys = 0
local hasDestroys = false
local anyCleanups = false
local liveSigEquals = 0
local hasSigEquals = false
local hasCompEquals = false
local slowCommit = false
local ownExtra = false

local OWNER_TOKEN: any = {}
local SAME_VALUE: any = {}
local FORCE_COMMIT: any = {}

@native
local function isReactive(): boolean
	return curNode ~= nil
end

@native
local function isObserved(node: any): boolean
	local inner = rawget(node, 1)
	local h = inner[HEIGHT]
	if h == nil then
		local n = inner[OBSERVERS]
		return n ~= nil and n > 0
	elseif h == INF or h == SCOPE then
		return false
	end
	local obs = inner[OBSERVERS]
	return obs ~= nil and obs ~= false
end

@native
local function insert(node: any)
	if not node[NEXT] then
		local h = node[HEIGHT]
		node[NEXT] = heap[h] or true
		heap[h] = node
		if h < heapMin then
			heapMin = h
			liveMax = h + LIVE_BASE
		end
		if h > heapMax then
			heapMax = h
		end
	end
end

local function readThisRunFrom(r: any, idx: number, newList: any, run: number, s: any): boolean
	if run > 0 and s[SEEN] == run then
		return true
	end
	if idx == DIVERGED then
		local base = if r[HEIGHT] == INF then E_SRC1 else SRC1
		for i = base, newList[1] - 2, 2 do
			if r[i] == s then
				return true
			end
		end
		for i = 3, newList[2] do
			if newList[i] == s then
				return true
			end
		end
		return false
	end
	local base = if r[HEIGHT] == INF then E_SRC1 else SRC1
	for i = base, idx - 2, 2 do
		if r[i] == s then
			return true
		end
	end
	return false
end

local function readThisRun(r: any, s: any): boolean
	return readThisRunFrom(r, curIdx, curNew, curRun, s)
end

local compRuns: { [any]: number } = {}
local compRunActive = false

local function checkCompRun(node: any, ...: any)
	compRunActive = true
	anyReruns = true
	local cn = (compRuns[node] or 0) + 1
	compRuns[node] = cn
	if cn > RERUN_LIMIT then
		curNode, curIdx, curNew, evalNode, evalFromUntrack = node, node[NSRC], nil, node, false
		error("Flux detected a cyclic or unstable computed in stabilize()", 0)
	end
end

@native
local function markOne(o: any)
	if o[STAMP] ~= 0 then
		o[STAMP] = 0
		local h = o[HEIGHT]
		if h == INF then
			queueTail += 1
			queue[queueTail] = o
		elseif not o[NEXT] then
			o[NEXT] = heap[h] or true
			heap[h] = o
			if h < heapMin then
				heapMin = h
				liveMax = h + LIVE_BASE
			end
			if h > heapMax then
				heapMax = h
			end
		end
	end
end

local selfWritten: any = nil

local function deferOuterEffect(e: any, s: any, ...: any)
	local frame = activeEffects[e]
	if frame.canCheck then
		if readThisRunFrom(e, frame.idx, frame.newList, frame.run, s) then
			frame.written = true
		end
		return
	end
	markOne(e)
end

local function deferSelf(e: any, s: any, ...: any)
	if curNode == nil and not readThisRun(e, s) then
		return
	end
	selfWritten = e
end

@native
local function markOrDefer(o: any, src: any, re: any)
	if o == re then
		deferSelf(o, src)
	elseif nestedRunning > 0 and activeEffects[o] then
		deferOuterEffect(o, src)
	else
		markOne(o)
	end
end

@native
local function markObservers(sig: any, n: number)
	local r = curNode
	local re = runningEffect
	if re == nil then
		for i = SIG_OBS1, n + SIG_OBS0 do
			local o = sig[i]
			if o ~= r then
				markOne(o)
			end
		end
	else
		for i = SIG_OBS1, n + SIG_OBS0 do
			local o = sig[i]
			if o ~= r then
				markOrDefer(o, sig, re)
			end
		end
	end
end

@native
local function markList(node: any, obs: any)
	local r = curNode
	local re = runningEffect
	if obs[HEIGHT] then
		if obs ~= r then
			if re ~= nil then
				markOrDefer(obs, node, re)
			else
				markOne(obs)
			end
		end
		return
	end
	if re == nil then
		for i = OBS1, obs[1] do
			local o = obs[i]
			if o ~= r then
				markOne(o)
			end
		end
	else
		for i = OBS1, obs[1] do
			local o = obs[i]
			if o ~= r then
				markOrDefer(o, node, re)
			end
		end
	end
end

@native
local function markSelf(node: any)
	local r = curNode
	if r and readThisRun(r, node) then
		if r[HEIGHT] == INF then
			selfWritten = r
		else
			markOne(r)
		end
	elseif
		r == nil
		and runningEffect ~= noEffect
		and selfWritten ~= runningEffect
		and (evalNode == nil or evalNode == runningEffect)
	then
		local re = runningEffect
		if readThisRun(re, node) then
			selfWritten = re
		end
	end
end

local CYCLE_ERR = "Flux detected a circular dependency between computeds"
local ITER_DEPTH = 128

local raiseActive: { [any]: boolean } = {}

local function raiseIter(root: any, rootH: number, ...: any): boolean
	local stNode: { any } = { root }
	local stH: { number } = { rootH }
	local stObs: { any } = { false }
	local stIdx: { number } = { 0 }
	local sp = 1
	while sp > 0 do
		local node, h, idx = stNode[sp], stH[sp], stIdx[sp]
		if idx == 0 then
			local obs = node[OBSERVERS]
			if obs and raiseActive[node] then
				for k = sp - 1, 1, -1 do
					if stIdx[k] ~= 0 then
						raiseActive[stNode[k]] = nil
					end
				end
				return false
			end
			node[HEIGHT] = h
			if node[STAMP] <= LIVE_MAX_IDLE then
				node[STAMP] = h + LIVE_BASE
			end
			if not obs then
				sp -= 1
				continue
			end
			local oh = obs[HEIGHT]
			if oh then
				if oh > h then
					sp -= 1
					continue
				end
				raiseActive[node] = true
				stIdx[sp] = -1
				sp += 1
				stNode[sp], stH[sp], stObs[sp], stIdx[sp] = obs, h + 1, false, 0
			else
				raiseActive[node] = true
				stObs[sp] = obs
				stIdx[sp] = OBS1
			end
		elseif idx < 0 then
			raiseActive[node] = nil
			sp -= 1
		else
			local obs = stObs[sp]
			local maxI = obs[1]
			local pushed = false
			while idx <= maxI do
				local o = obs[idx]
				idx += 1
				if o[HEIGHT] <= h then
					stIdx[sp] = idx
					sp += 1
					stNode[sp], stH[sp], stObs[sp], stIdx[sp] = o, h + 1, false, 0
					pushed = true
					break
				end
			end
			if not pushed then
				raiseActive[node] = nil
				sp -= 1
			end
		end
	end
	return true
end

@native
local function raiseVisit(node: any, h: number, depth: number): boolean
	if depth >= ITER_DEPTH then
		return raiseIter(node, h)
	end
	local obs = node[OBSERVERS]
	if obs and raiseActive[node] then
		return false
	end
	node[HEIGHT] = h
	if node[STAMP] <= LIVE_MAX_IDLE then
		node[STAMP] = h + LIVE_BASE
	end
	if not obs then
		return true
	end
	local oh = obs[HEIGHT]
	if oh then
		if oh > h then
			return true
		end
		raiseActive[node] = true
		local ok = raiseVisit(obs, h + 1, depth + 1)
		raiseActive[node] = nil
		return ok
	end
	raiseActive[node] = true
	for i = OBS1, obs[1] do
		local o = obs[i]
		if o[HEIGHT] <= h then
			if not raiseVisit(o, h + 1, depth + 1) then
				raiseActive[node] = nil
				return false
			end
		end
	end
	raiseActive[node] = nil
	return true
end
local hookQueue: { any } = {}
local hookHead = 1
local hookTail = 0
local hookDepth = 0

local function isNodeObserved(n: any): boolean
	local h = n[HEIGHT]
	if h == nil then
		local obs = n[OBSERVERS]
		return obs ~= nil and obs > 0
	elseif h == INF or h == SCOPE then
		return false
	end
	local obs = n[OBSERVERS]
	return obs ~= nil and obs ~= false
end

local function flushHooks()
	local pNode, pEval, pRunning, pOwner, pSet, pCtx, pExtra, pSusp, pSuspRun, pChildren =
		curNode, evalNode, runningEffect, curOwner, ownerSet, curCtx, ownExtra, susp, suspRun, curChildren
	curNode, evalNode, runningEffect, curOwner, ownerSet, curCtx, ownExtra, susp, curChildren =
		nil, nil, noEffect, nil, false, nil, false, nil, nil
	while hookHead <= hookTail do
		local n = hookQueue[hookHead]
		hookQueue[hookHead] = nil
		hookHead += 1
		local h = n.hooks
		if h then
			h[4] = false
			local now = isNodeObserved(n)
			if now ~= h[3] then
				h[3] = now
				local f = h[if now then 1 else 2]
				if f then
					protect(if now then "onObserved" else "onUnobserved", f)
				end
			end
		end
	end
	hookHead, hookTail = 1, 0
	curNode, evalNode, runningEffect, curOwner, ownerSet, curCtx, ownExtra, susp, suspRun, curChildren =
		pNode, pEval, pRunning, pOwner, pSet, pCtx, pExtra, pSusp, pSuspRun, pChildren
end

local function endHooks(...: any)
	if hookDepth == 1 and hookTail >= hookHead then
		flushHooks()
	end
	hookDepth -= 1
end

local function fireHook(n: any, _which: number, ...: any)
	local h = n.hooks
	if not h or (not h[1] and not h[2]) then
		return
	end
	if not h[4] then
		h[4] = true
		hookTail += 1
		hookQueue[hookTail] = n
	end
	if hookDepth == 0 then
		hookDepth = 1
		endHooks()
	end
end

@native
local function fixBack(moved: any, s: any, oldJ: number, j: number)
	local base, nslot = SRC1, NSRC
	if moved[HEIGHT] == INF then
		base, nslot = E_SRC1, E_NSRC
	end
	for i = base, moved[nslot] - 2, 2 do
		if moved[i] == s and moved[i + 1] == oldJ then
			moved[i + 1] = j
			return
		end
	end
end

local oldTail: { any } = {}
local tailBusy = false
local freeNew: { any }? = {}

local goLive: (any, any, number) -> boolean
local goDead: (any, number) -> ()

local function rollbackSubRaise(s: any, list: any, n: number, ...: any): number
	if not list then
		s[OBSERVERS] = false
		goDead(s, 0)
	elseif list[HEIGHT] then
		s[OBSERVERS] = list
	else
		list[n] = nil
		list[1] = n - 1
	end
	return -1
end

@native
local function subscribe(s: any, o: any, depth: number): number
	local sh = s[HEIGHT]
	if not sh then
		local n0 = s[OBSERVERS]
		if n0 == nil then
			return 0
		end
		local n = n0 + 1
		s[OBSERVERS] = n
		s[n + SIG_OBS0] = o
		if hasHooks and n == 1 then
			fireHook(s, 1)
		end
		return n
	end
	if s == o then
		return -1
	end
	local list = s[OBSERVERS]
	local n
	if list == nil then
		return 0
	elseif not list then
		n = OBS1
		if not goLive(s, o, depth) then
			return -1
		end
		sh = s[HEIGHT]
	elseif list[HEIGHT] then
		s[OBSERVERS] = { 4, false, list, o, nil, nil, nil, nil }
		n = 4
	else
		n = list[1] + 1
		list[1] = n
		list[n] = o
	end
	if sh >= o[HEIGHT] then
		if o[OBSERVERS] then
			if not raiseVisit(o, sh + 1, 0) then
				return rollbackSubRaise(s, list, n)
			end
		else
			o[HEIGHT] = sh + 1
		end
	end
	return n
end

@native
local function unsubscribe(s: any, o: any, j: number)
	local h = s[HEIGHT]
	if not h then
		local n = s[OBSERVERS]
		if n == nil then
			return
		end
		local last = n + SIG_OBS0
		if j ~= n then
			local moved = s[last]
			s[j + SIG_OBS0] = moved
			fixBack(moved, s, n, j)
		end
		s[last] = nil
		s[OBSERVERS] = n - 1
		if hasHooks and n == 1 then
			fireHook(s, 2)
		end
		return
	end
	local list = s[OBSERVERS]
	if list == o then
		s[OBSERVERS] = false
		goDead(s, 0)
		return
	elseif not list or list[HEIGHT] then
		return
	end
	local n = list[1]
	if j ~= n then
		local moved = list[n]
		list[j] = moved
		fixBack(moved, s, n, j)
	end
	list[n] = nil
	if n == OBS1 then
		s[OBSERVERS] = false
		goDead(s, 0)
	else
		list[1] = n - 1
	end
end

do
	local function rollbackGoLive(node: any, i: number, hooked: boolean): boolean
		for j = i - 2, SRC1, -2 do
			unsubscribe(node[j], node, node[j + 1])
			node[j + 1] = 0
		end
		node[OBSERVERS] = false
		if hooked then
			endHooks()
		end
		return false
	end

	@native
	local function finishGoLive(node: any, last: number, hooked: boolean)
		local st = node[STAMP]
		if st == epoch then
			node[STAMP] = node[HEIGHT] + LIVE_BASE
		elseif st ~= STALE and st ~= ERRORED then
			local dirty = st == 0 or st == DEFERRED
			if not dirty then
				for i = SRC1, last, 2 do
					local s = node[i]
					local c = if s[HEIGHT] then s[CHANGED] else s[SIG_CHANGED]
					if c == nil or c > st then
						dirty = true
						break
					end
				end
			end
			if dirty then
				node[STAMP] = 0
				epoch += 1
				insert(node)
			end
		end
		if hooked then
			fireHook(node, 1)
			endHooks()
		end
	end

	local function goLiveIter(rootNode: any, rootObs: any, ...: any): boolean
		local stNode: { any } = { rootNode }
		local stI: { number } = { SRC1 }
		local stLast: { number } = { rootNode[NSRC] - 2 }
		local stHooked: { boolean } = { hasHooks }
		local sp = 1
		if stHooked[1] then
			hookDepth += 1
		end
		rootNode[OBSERVERS] = rootObs
		while sp > 0 do
			local node, i, last = stNode[sp], stI[sp], stLast[sp]
			local pushed = false
			while i <= last do
				local s = node[i]
				if not s[HEIGHT] then
					local n0 = s[OBSERVERS]
					if n0 then
						local n = n0 + 1
						s[OBSERVERS] = n
						s[n + SIG_OBS0] = node
						node[i + 1] = n
						if stHooked[sp] and n == 1 then
							fireHook(s, 1)
						end
					else
						node[i + 1] = 0
					end
					i += 2
				else
					local list = s[OBSERVERS]
					if list == nil then
						node[i + 1] = 0
						i += 2
					elseif not list then
						stI[sp] = i
						sp += 1
						local ch = hasHooks
						if ch then
							hookDepth += 1
						end
						s[OBSERVERS] = node
						stNode[sp], stI[sp], stLast[sp], stHooked[sp] = s, SRC1, s[NSRC] - 2, ch
						pushed = true
						break
					else
						local res = subscribe(s, node, 0)
						if res < 0 then
							rollbackGoLive(node, i, stHooked[sp])
							for k = sp - 1, 1, -1 do
								rollbackGoLive(stNode[k], stI[k], stHooked[k])
							end
							return false
						end
						node[i + 1] = res
						i += 2
					end
				end
			end
			if not pushed then
				local hooked = stHooked[sp]
				finishGoLive(node, last, hooked)
				sp -= 1
				if sp > 0 then
					local p = stNode[sp]
					local pi = stI[sp]
					p[pi + 1] = OBS1
					local sh = node[HEIGHT]
					if sh >= p[HEIGHT] then
						if not raiseVisit(p, sh + 1, 0) then
							rollbackGoLive(p, pi + 2, stHooked[sp])
							for k = sp - 1, 1, -1 do
								rollbackGoLive(stNode[k], stI[k], stHooked[k])
							end
							return false
						end
					end
					stI[sp] = pi + 2
				end
			end
		end
		return true
	end

	@native
	function goLive(node: any, o: any, depth: number): boolean
		if depth >= ITER_DEPTH then
			return goLiveIter(node, o)
		end
		local hooked = hasHooks
		if hooked then
			hookDepth += 1
		end
		node[OBSERVERS] = o
		local last = node[NSRC] - 2
		for i = SRC1, last, 2 do
			local s = node[i]
			if not s[HEIGHT] then
				local n0 = s[OBSERVERS]
				if n0 then
					local n = n0 + 1
					s[OBSERVERS] = n
					s[n + SIG_OBS0] = node
					node[i + 1] = n
					if hooked and n == 1 then
						fireHook(s, 1)
					end
				else
					node[i + 1] = 0
				end
			else
				local res = subscribe(s, node, depth + 1)
				if res < 0 then
					return rollbackGoLive(node, i, hooked)
				end
				node[i + 1] = res
			end
		end
		node[OBSERVERS] = o
		finishGoLive(node, last, hooked)
		return true
	end
end

do
	@native
	local function finishGoDead(node: any, hooked: boolean)
		local st = node[STAMP]
		if st <= liveMax or (st > 0 and heapMin == INF) then
			node[STAMP] = epoch
		elseif st <= LIVE_MAX_IDLE then
			epoch += 1
			node[STAMP] = epoch - 1
		elseif st == DEFERRED then
			node[STAMP] = 0
		elseif st == ERRORED then
			node[STAMP] = STALE
		end
		if hooked then
			fireHook(node, 2)
			endHooks()
		end
	end

	local function goDeadIter(root: any, ...: any)
		local stNode: { any } = { root }
		local stI: { number } = { root[NSRC] - 2 }
		local stHooked: { boolean } = { hasHooks }
		local sp = 1
		if stHooked[1] then
			hookDepth += 1
		end
		while sp > 0 do
			local node, i, hooked = stNode[sp], stI[sp], stHooked[sp]
			local pushed = false
			while i >= SRC1 do
				local s, j = node[i], node[i + 1]
				local obs = s[OBSERVERS]
				if obs == j and not hooked then
					s[j + SIG_OBS0] = nil
					s[OBSERVERS] = j - 1
					i -= 2
				elseif obs == node then
					s[OBSERVERS] = false
					stI[sp] = i - 2
					sp += 1
					local ch = hasHooks
					if ch then
						hookDepth += 1
					end
					stNode[sp], stI[sp], stHooked[sp] = s, s[NSRC] - 2, ch
					pushed = true
					break
				else
					unsubscribe(s, node, j)
					i -= 2
				end
			end
			if not pushed then
				finishGoDead(node, hooked)
				sp -= 1
			end
		end
	end

	@native
	function goDead(node: any, depth: number)
		if depth >= ITER_DEPTH then
			goDeadIter(node)
			return
		end
		local hooked = hasHooks
		if hooked then
			hookDepth += 1
		end
		for i = node[NSRC] - 2, SRC1, -2 do
			local s, j = node[i], node[i + 1]
			local obs = s[OBSERVERS]
			if obs == j and not hooked then
				s[j + SIG_OBS0] = nil
				s[OBSERVERS] = j - 1
			elseif obs == node then
				s[OBSERVERS] = false
				goDead(s, depth + 1)
			else
				unsubscribe(s, node, j)
			end
		end
		finishGoDead(node, hooked)
	end
end

local function cleanupTail(node: any, tail: { any }, nOld: number)
	for j = nOld - 1, 1, -2 do
		local oldDep = tail[j]
		if oldDep then
			tail[j] = false
			unsubscribe(oldDep, node, tail[j + 1])
			if oldDep[CHILDREN] == false then
				oldDep[CHILDREN] = nil
			end
		end
	end
end

local function rollbackReconcileAdd(node: any, nslot: number, i: number, idx: number, hooked: boolean, ...: any)
	for c = i, idx - 1 do
		node[c] = nil
	end
	node[nslot] = i
	curIdx = i
	if hooked then
		endHooks()
	end
	error(CYCLE_ERR, 0)
end

local function rollbackReconcileTail(
	node: any,
	nslot: number,
	k: number,
	last: number,
	tail: { any },
	nOld: number,
	wasBusy: boolean,
	newList: any,
	i: number,
	nNew: number,
	hooked: boolean,
	...: any
)
	for c = i + 1, nNew do
		newList[c] = nil
	end
	freeNew, node[nslot], curIdx, curNew = newList, k, k, nil
	for c = k, last - 1 do
		node[c] = nil
	end
	cleanupTail(node, tail, nOld)
	tailBusy = wasBusy
	if hooked then
		endHooks()
	end
	error(CYCLE_ERR, 0)
end

@native
local function reconcile(node: any, nslot: number, last: number, idx: number, newList: any, live: boolean)
	local hooked = hasHooks and live
	if hooked then
		hookDepth += 1
	end
	if not newList then
		if idx > last then
			if live then
				for i = last, idx - 2, 2 do
					local back = subscribe(node[i], node, 0)
					if back < 0 then
						rollbackReconcileAdd(node, nslot, i, idx, hooked)
					end
					node[i + 1] = back
				end
			end
		else
			for i = last - 2, idx, -2 do
				local s = node[i]
				if live then
					unsubscribe(s, node, node[i + 1])
					if s[CHILDREN] == false then
						s[CHILDREN] = nil
					end
				end
				node[i], node[i + 1] = nil, nil
			end
		end
		node[nslot] = idx
		if hooked then
			endHooks()
		end
		return
	end
	local nNew = newList[2]
	if not live then
		local k = idx
		for i = 3, nNew do
			node[k], node[k + 1], newList[i] = newList[i], 0, nil
			k += 2
		end
		freeNew, node[nslot] = newList, k
		for i = k, last - 1 do
			node[i] = nil
		end
		return
	end
	local nOld = last - idx
	if nOld == 2 and nNew == 3 then
		local oldS, oldBack, s = node[idx], node[idx + 1], newList[3]
		newList[3], freeNew = nil, newList
		local back = subscribe(s, node, 0)
		if back < 0 then
			if hooked then
				endHooks()
			end
			error(CYCLE_ERR, 0)
		end
		node[idx], node[idx + 1] = s, back
		unsubscribe(oldS, node, oldBack)
		if oldS[CHILDREN] == false then
			oldS[CHILDREN] = nil
		end
		if hooked then
			endHooks()
		end
		return
	end
	local tail: { any } = if tailBusy then {} else oldTail
	local wasBusy = tailBusy
	tailBusy = true
	table.move(node, idx, last - 1, 1, tail)
	local k, prevJ = idx, 1
	for i = 3, nNew do
		local s = newList[i]
		newList[i] = nil
		local back, hint = 0, prevJ + 2
		if hint <= nOld and tail[hint] == s then
			back, tail[hint], prevJ = tail[hint + 1], false, hint
		else
			for j = 1, nOld, 2 do
				if tail[j] == s then
					back, tail[j], prevJ = tail[j + 1], false, j
					break
				end
			end
			if back == 0 then
				local res = subscribe(s, node, 0)
				if res < 0 then
					rollbackReconcileTail(node, nslot, k, last, tail, nOld, wasBusy, newList, i, nNew, hooked)
				end
				back = res
				if prevJ == 1 then
					prevJ = -1
				end
			end
		end
		node[k], node[k + 1] = s, back
		k += 2
	end
	freeNew, node[nslot] = newList, k
	for i = k, last - 1 do
		node[i] = nil
	end
	cleanupTail(node, tail, nOld)
	tailBusy = wasBusy
	if hooked then
		endHooks()
	end
end

local removeSource: (o: any, src: any) -> ()
do
	local TOMB = {}

	@native
	function removeSource(o: any, src: any)
		local base, nslot = SRC1, NSRC
		if o[HEIGHT] == INF then
			base, nslot = E_SRC1, E_NSRC
		end
		for i = base, o[nslot] - 2, 2 do
			if o[i] == src then
				o[i] = TOMB
				return
			end
		end
	end
end

local runProtected: (callbacks: { any }, oldValue: any, destroyed: boolean, kind: string) -> ()
do
	local callbackIndex = 0

	local function runCallbacks(callbacks: { any }, from: number, oldValue: any, destroyed: boolean)
		for i = from, #callbacks do
			callbackIndex = i
			local callback = callbacks[i]
			if type(callback) == "function" then
				(callback :: (any, boolean) -> ())(oldValue, destroyed)
			else
				clean(callback)
			end
		end
	end

	function runProtected(callbacks: { any }, oldValue: any, destroyed: boolean, kind: string)
		local pNode, pSusp, pOwner, pSet, pIndex = curNode, susp, curOwner, ownerSet, callbackIndex
		local pSuspRun = suspRun
		curNode, susp, curChildren, curOwner, ownerSet = nil, nil, nil, nil, false
		local from = 1
		while true do
			local ok, err = (xpcall :: (...any) -> (boolean, any))(
				runCallbacks,
				traceback,
				callbacks,
				from,
				oldValue,
				destroyed
			)
			if ok then
				break
			end
			warn(`[Flux] {kind} error:\n{err}`)
			from = callbackIndex + 1
		end
		curNode, susp, curOwner, ownerSet, callbackIndex, curChildren = pNode, pSusp, pOwner, pSet, pIndex, nil
		suspRun = pSuspRun
	end
end

local disposeOne: (any) -> ()

@native
local function unlinkSource(s: any, node: any, j: number)
	local obs = s[OBSERVERS]
	if obs == j then
		s[j + SIG_OBS0] = nil
		s[OBSERVERS] = j - 1
	elseif obs == node then
		s[OBSERVERS] = false
		goDead(s, 0)
	else
		unsubscribe(s, node, j)
	end
end

@native
local function clearCompSrcs(s: any, snsrc: number, ...: any)
	for si = snsrc - 2, SRC1, -2 do
		unlinkSource(s[si], s, s[si + 1])
		s[si], s[si + 1] = nil, nil
	end
end

@native
local function disposeChained(s: any)
	local snsrc = s[NSRC]
	if snsrc == SRC1 + 2 then
		unlinkSource(s[SRC1], s, s[SRC1 + 1])
		s[SRC1], s[SRC1 + 1] = nil, nil
	elseif snsrc > SRC1 then
		clearCompSrcs(s, snsrc)
	end
	s[FN] = nil
	s[NSRC] = DISPOSED_NSRC
	s[STAMP] = LIVE_MAX_IDLE
	s[VALUE] = nil
	s[OBSERVERS] = nil
end

@native
local function disposeMultiEffect(c: any, k: number, node: any, nsrc: number, ...: any): number
	for i = nsrc - 2, E_SRC1, -2 do
		local s = node[i]
		if s[OBSERVERS] == node and c[k - 1] == s and not s[CHILDREN] and s[FN] then
			disposeChained(s)
			k -= 1
		else
			unlinkSource(s, node, node[i + 1])
		end
		node[i], node[i + 1] = nil, nil
	end
	return k
end

@native
local function disposeChildren(owner: any, slot: number, value: any, destroyed: boolean)
	local c = owner[slot]
	owner[slot] = false
	curChildren = nil
	if not hasHooks and not hasDestroys then
		local k = c[1]
		while k >= 2 do
			local node = c[k]
			if not node[OBSERVERS] then
				if node[FN] then
					if not node[CHILDREN] then
						for i = SRC1, node[NSRC] - 1 do
							node[i] = nil
						end
						node[FN] = nil
						node[NSRC] = DISPOSED_NSRC
						node[STAMP] = LIVE_MAX_IDLE
						node[VALUE] = nil
						node[OBSERVERS] = nil
					else
						disposeOne(node)
					end
				end
			elseif node[HEIGHT] == INF and node[E_FN] then
				node[E_FN] = nil
				node[STAMP] = INF
				if node[E_CHILDREN] then
					disposeChildren(node, E_CHILDREN, nil, true)
				end
				local nsrc = node[E_NSRC]
				if nsrc == E_SRC1 + 2 then
					local s = node[E_SRC1]
					if s[OBSERVERS] == node and c[k - 1] == s and not s[CHILDREN] and s[FN] then
						local snsrc = s[NSRC]
						if snsrc == SRC1 + 2 then
							unlinkSource(s[SRC1], s, s[SRC1 + 1])
							s[SRC1], s[SRC1 + 1] = nil, nil
						elseif snsrc > SRC1 then
							clearCompSrcs(s, snsrc)
						end
						s[FN] = nil
						s[NSRC] = DISPOSED_NSRC
						s[STAMP] = LIVE_MAX_IDLE
						s[VALUE] = nil
						s[OBSERVERS] = nil
						k -= 1
					else
						unlinkSource(s, node, node[E_SRC1 + 1])
					end
					node[E_SRC1], node[E_SRC1 + 1] = nil, nil
				elseif nsrc > E_SRC1 then
					k = disposeMultiEffect(c, k, node, nsrc)
				end
				node[E_NSRC] = DISPOSED_NSRC
			else
				disposeOne(node)
			end
			k -= 1
		end
	else
		for k = c[1], 2, -1 do
			disposeOne(c[k])
		end
	end
	if anyCleanups then
		local fns = c.fns
		if fns then
			runProtected(fns, value, destroyed, "cleanup")
		end
	end
end

@native
function disposeOne(node: any)
	local h = node[HEIGHT]
	if h == nil then
		local n = node[OBSERVERS]
		if n == nil then
			return
		end
		for i = SIG_OBS1, n + SIG_OBS0 do
			removeSource(node[i], node)
		end
		local destroys = node.destroys
		if node.hooks then
			liveHooks -= 1
			if liveHooks == 0 then
				hasHooks = false
			end
		end
		if node.equals then
			liveSigEquals -= 1
			if liveSigEquals == 0 then
				hasSigEquals = false
			end
		end
		local value = node[VALUE]
		local owned = node.owned
		if owned then
			node.owned = nil
			disposeChildren({ owned }, 1, value, true)
		end
		table.clear(node)
		if destroys then
			liveDestroys -= 1
			if liveDestroys == 0 then
				hasDestroys = false
			end
			runProtected(destroys, value, true, "onDestroy")
		end
		return
	end
	local value
	if h == INF then
		if node[E_FN] == nil then
			return
		end
		node[E_FN] = nil
		node[STAMP] = INF
		local nsrc = node[E_NSRC]
		node[E_NSRC] = DISPOSED_NSRC
		local hooked = hasHooks
		if hooked then
			hookDepth += 1
		end
		if node[E_CHILDREN] then
			disposeChildren(node, E_CHILDREN, nil, true)
		end
		for i = nsrc - 2, E_SRC1, -2 do
			unsubscribe(node[i], node, node[i + 1])
			node[i], node[i + 1] = nil, nil
		end
		if hooked then
			endHooks()
		end
	elseif h == SCOPE then
		if node[FN] == false then
			return
		end
		node[FN] = false
		if node[CHILDREN] then
			disposeChildren(node, CHILDREN, nil, true)
		end
		if queueCap > 4096 and queueHead > queueTail and curOwner == nil and curNode == nil and not flushing then
			queue = {}
			queueCap = 0
		end
	else
		if node[FN] == nil then
			return
		end
		node[FN] = nil
		node[STAMP] = LIVE_MAX_IDLE
		value = node[VALUE]
		local hooked = hasHooks
		if hooked then
			hookDepth += 1
		end
		if node[CHILDREN] then
			disposeChildren(node, CHILDREN, value, true)
		end
		local obs = node[OBSERVERS]
		local nsrc = node[NSRC]
		node[NSRC] = DISPOSED_NSRC
		if obs then
			if obs[HEIGHT] then
				removeSource(obs, node)
			else
				for i = OBS1, obs[1] do
					removeSource(obs[i], node)
				end
			end
			node[OBSERVERS] = false
			for i = nsrc - 2, SRC1, -2 do
				unsubscribe(node[i], node, node[i + 1])
				node[i], node[i + 1] = nil, nil
			end
			if hooked then
				fireHook(node, 2)
			end
		else
			for i = SRC1, nsrc - 1 do
				node[i] = nil
			end
		end
		node[VALUE] = nil
		node[OBSERVERS] = nil
		if hooked then
			endHooks()
		end
	end
	if node.hooks then
		node.hooks = nil
		liveHooks -= 1
		if liveHooks == 0 then
			hasHooks = false
		end
	end
	local destroys = node.destroys
	if destroys then
		node.destroys = nil
		liveDestroys -= 1
		if liveDestroys == 0 then
			hasDestroys = false
		end
		runProtected(destroys, value, true, "onDestroy")
	end
end

@native
local function reap(o: any)
	local h = o[HEIGHT]
	if h == nil then
		local owned = o.owned
		if owned then
			o.owned = nil
			disposeChildren({ owned }, 1, nil, true)
		end
		return
	end
	local slot = if h == INF then E_CHILDREN else CHILDREN
	if o[slot] then
		disposeChildren(o, slot, nil, true)
	end
end

@native
local function notifyObservers(obs: any, node: any)
	local r, e, x = curNode, evalNode, runningEffect
	if obs[HEIGHT] then
		if obs ~= r and obs ~= e then
			if x ~= nil then
				markOrDefer(obs, node, x)
			else
				markOne(obs)
			end
		end
	elseif x == nil then
		for i = OBS1, obs[1] do
			local o = obs[i]
			if o ~= r and o ~= e then
				markOne(o)
			end
		end
	else
		for i = OBS1, obs[1] do
			local o = obs[i]
			if o ~= r and o ~= e then
				markOrDefer(o, node, x)
			end
		end
	end
end

local function markChanged(node: any)
	epoch += 1
	node[CHANGED] = epoch
	local obs = node[OBSERVERS]
	if obs then
		notifyObservers(obs, node)
	end
end

local function finishErrored(node: any, idx: number, newList: any, err: any)
	if newList then
		idx = newList[1]
	end
	local h = node[HEIGHT]
	if h == INF then
		if node[E_FN] then
			local last = node[E_NSRC]
			if newList or idx ~= last then
				pcall(reconcile, node, E_NSRC, last, idx, newList, true)
			end
		else
			reap(node)
		end
		return
	end
	if not node[FN] then
		reap(node)
		return
	end
	local live = node[OBSERVERS] ~= false
	local last = node[NSRC]
	if newList or idx ~= last then
		pcall(reconcile, node, NSRC, last, idx, newList, live)
	end
	node.err = err
	node[STAMP] = if node[OBSERVERS] then ERRORED else STALE
	markChanged(node)
	if not failed[node] then
		nFailed += 1
		slowCommit = true
	end
	failed[node] = node[CHANGED]
end

local function unfail(node: any): boolean
	local at = failed[node]
	if at == nil then
		return false
	end
	failed[node] = nil
	nFailed -= 1
	if nFailed == 0 then
		slowCommit = hasCompEquals
	end
	return at == node[CHANGED]
end

local function healed(node: any)
	markChanged(node)
	node[STAMP] = epoch
end

@native
local function runComputed(node: any)
	local deferred = node[STAMP] == DEFERRED
	node[STAMP] = epoch
	if node[CHILDREN] then
		disposeChildren(node, CHILDREN, node[VALUE], false)
	end
	local pNode, pIdx, pNew, pRun, pEval = curNode, curIdx, curNew, curRun, evalNode
	local hadExtra = ownExtra
	local pSusp, pSuspRun, pCtx, pSet
	if hadExtra then
		pSusp, pSuspRun, pCtx, pSet = susp, suspRun, curCtx, ownerSet
		susp, ownerSet = nil, false
	end
	evalNode = node
	curRun = -1
	curNode, curIdx, curNew, curChildren = node, SRC1, nil, nil
	local new = node[FN](node[VALUE])
	local idx, newList = curIdx, curNew
	curNode, curIdx, curNew, curRun, evalNode, curChildren = pNode, pIdx, pNew, pRun, pEval, nil
	if hadExtra then
		susp, suspRun, curCtx, ownerSet, ownExtra = pSusp, pSuspRun, pCtx, pSet, true
	elseif susp then
		susp = nil
		ownExtra = curCtx ~= nil
	end
	local obs = node[OBSERVERS]
	local last = node[NSRC]
	if idx ~= last then
		if not obs and idx > last then
			node[NSRC] = idx
		else
			if not node[FN] then
				node[VALUE] = nil
				reap(node)
				return
			end
			if newList then
				idx = newList[1]
			end
			reconcile(node, NSRC, last, idx, newList, obs ~= false)
			obs = node[OBSERVERS]
		end
	end
	local selfDirty = node[STAMP] == 0
	node[STAMP] = if obs and node[HEIGHT] <= heapMin then node[HEIGHT] + LIVE_BASE else epoch
	local prevVal = node[VALUE]
	if new ~= prevVal and (prevVal == prevVal or new ~= SAME_VALUE) then
		node[VALUE] = new
		node[CHANGED] = epoch
		if obs and not deferred then
			notifyObservers(obs, node)
		end
	elseif nFailed > 0 and unfail(node) then
		healed(node)
	end
	if selfDirty then
		runComputed(node)
	end
end

local refresh: (any, number?) -> ()

local settle: (node: any, depth: number?) -> ()
do
	local function settleIter(root: any, ...: any)
		local pNode = curNode
		curNode = nil
		local stNode: { any } = { root }
		local stI: { number } = { SRC1 }
		local stLast: { number } = { root[NSRC] - 2 }
		local sp = 1
		while sp > 0 do
			local node, i, last = stNode[sp], stI[sp], stLast[sp]
			local pushed = false
			while i <= last do
				local s = node[i]
				i += 2
				local h = s[HEIGHT]
				if h and h >= heapMin then
					local st = s[STAMP]
					if st > liveMax and st ~= epoch and st ~= STALE and st ~= ERRORED then
						stI[sp] = i
						sp += 1
						stNode[sp], stI[sp], stLast[sp] = s, SRC1, s[NSRC] - 2
						pushed = true
						break
					end
				end
			end
			if not pushed then
				sp -= 1
				local st = node[STAMP]
				if st <= 0 and st >= STALE then
					runComputed(node)
				elseif st ~= ERRORED then
					local h = node[HEIGHT]
					node[STAMP] = if h <= heapMin then h + LIVE_BASE else epoch
				end
			end
		end
		curNode = pNode
	end

	@native
	function settle(node: any, depth: number?)
		local d = depth or 0
		if d >= ITER_DEPTH then
			settleIter(node)
			return
		end
		for i = SRC1, node[NSRC] - 2, 2 do
			local s = node[i]
			local h = s[HEIGHT]
			if h and h >= heapMin then
				local st = s[STAMP]
				if st > liveMax and st ~= epoch and st ~= STALE and st ~= ERRORED then
					local pNode = curNode
					curNode = nil
					settle(s, d + 1)
					curNode = pNode
				end
			end
		end
		local st = node[STAMP]
		if st <= 0 and st >= STALE then
			runComputed(node)
		elseif st ~= ERRORED then
			local h = node[HEIGHT]
			node[STAMP] = if h <= heapMin then h + LIVE_BASE else epoch
		end
	end
end

local pullDead: (node: any, depth: number?) -> ()
do
	local function pullDeadIter(root: any, ...: any)
		local pNode = curNode
		curNode = nil
		local stNode: { any } = { root }
		local stI: { number } = { SRC1 }
		local stDirty: { boolean } = { root[STAMP] <= 0 }
		local stWaiting: { boolean } = { false }
		local sp = 1
		while sp > 0 do
			local node = stNode[sp]
			if stDirty[sp] then
				sp -= 1
				runComputed(node)
				continue
			end
			local i = stI[sp]
			local last = node[NSRC] - 2
			if stWaiting[sp] then
				stWaiting[sp] = false
				local s = node[i]
				local c = s[CHANGED]
				if c == nil or c > node[STAMP] then
					stDirty[sp] = true
					continue
				end
				i += 2
			end
			local stamp = node[STAMP]
			local dirty = false
			local pushed = false
			while i <= last do
				local s = node[i]
				local st = s[STAMP]
				local sh = s[HEIGHT]
				if st == STALE then
					if s[OBSERVERS] then
						refresh(s, 0)
						dirty = true
						break
					elseif s[FN] then
						stDirty[sp] = true
						stI[sp] = i
						sp += 1
						stNode[sp], stI[sp], stDirty[sp], stWaiting[sp] = s, SRC1, s[STAMP] <= 0, false
						pushed = true
						break
					else
						dirty = true
						break
					end
				elseif sh and st > liveMax and st ~= epoch and st ~= ERRORED then
					if s[OBSERVERS] then
						refresh(s, 0)
					elseif s[FN] then
						stI[sp] = i
						stWaiting[sp] = true
						sp += 1
						stNode[sp], stI[sp], stDirty[sp], stWaiting[sp] = s, SRC1, s[STAMP] <= 0, false
						pushed = true
						break
					end
				end
				local c = if sh then s[CHANGED] else st
				if c == nil or c > stamp then
					dirty = true
					break
				end
				i += 2
			end
			if not pushed then
				sp -= 1
				if dirty then
					runComputed(node)
				else
					node[STAMP] = epoch
				end
			end
		end
		curNode = pNode
	end

	@native
	function pullDead(node: any, depth: number?)
		local d = depth or 0
		if d >= ITER_DEPTH then
			pullDeadIter(node)
			return
		end
		local stamp = node[STAMP]
		local dirty = stamp <= 0
		if not dirty then
			for i = SRC1, node[NSRC] - 2, 2 do
				local s = node[i]
				local st = s[STAMP]
				local sh = s[HEIGHT]
				if st == STALE then
					local pNode = curNode
					curNode = nil
					refresh(s, d + 1)
					curNode = pNode
					dirty = true
					break
				elseif sh and st > liveMax and st ~= epoch and st ~= ERRORED then
					local pNode = curNode
					curNode = nil
					refresh(s, d + 1)
					curNode = pNode
				end
				local c = if sh then s[CHANGED] else st
				if c == nil or c > stamp then
					dirty = true
					break
				end
			end
		end
		if dirty then
			runComputed(node)
		else
			node[STAMP] = epoch
		end
	end
end

@native
function refresh(node: any, depth: number?)
	if node[OBSERVERS] then
		local st = node[STAMP]
		if st == DEFERRED then
			if node[CHILDREN] == nil then
				node[CHILDREN] = false
			end
			runComputed(node)
		elseif st >= ERRORED or node[HEIGHT] > heapMin then
			settle(node, depth)
		else
			node[STAMP] = node[HEIGHT] + LIVE_BASE
		end
	elseif node[FN] then
		pullDead(node, depth)
	end
end

local function runComputedProtected(node: any)
	local st0 = node[STAMP]
	node[STAMP] = epoch
	if node[CHILDREN] then
		disposeChildren(node, CHILDREN, node[VALUE], false)
	end
	local pNode, pIdx, pNew, pRun, pEval = curNode, curIdx, curNew, curRun, evalNode
	local hadExtra = ownExtra
	local pSusp, pSuspRun, pCtx, pOwner, pSet, pRunning
	if hadExtra then
		pSusp, pSuspRun, pCtx, pOwner, pSet, pRunning = susp, suspRun, curCtx, curOwner, ownerSet, runningEffect
		susp, ownerSet = nil, false
	end
	evalNode = node
	curRun = -1
	curNode, curIdx, curNew, curChildren = node, SRC1, nil, nil
	local ok, new = pcall(node[FN], node[VALUE])
	local idx, newList = curIdx, curNew
	curNode, curIdx, curNew, curRun, evalNode, curChildren = pNode, pIdx, pNew, pRun, pEval, nil
	if hadExtra then
		susp, suspRun, curCtx, curOwner, ownerSet, runningEffect, ownExtra =
			pSusp, pSuspRun, pCtx, pOwner, pSet, pRunning, true
	elseif susp then
		susp = nil
		ownExtra = curCtx ~= nil
	end
	if not ok then
		if not hadExtra and ownExtra then
			curCtx, ownerSet, ownExtra = nil, false, false
		end
		finishErrored(node, idx, newList, new)
		error(new, 0)
	end
	local obs = node[OBSERVERS]
	local last = node[NSRC]
	if idx ~= last then
		if not obs and idx > last then
			node[NSRC] = idx
		else
			if not node[FN] then
				node[VALUE] = nil
				reap(node)
				return
			end
			if newList then
				idx = newList[1]
			end
			reconcile(node, NSRC, last, idx, newList, obs ~= false)
			obs = node[OBSERVERS]
		end
	end
	local selfDirty = node[STAMP] == 0
	node[STAMP] = if obs and node[HEIGHT] <= heapMin then node[HEIGHT] + LIVE_BASE else epoch
	local prevVal = node[VALUE]
	if new ~= prevVal and (prevVal == prevVal or new ~= SAME_VALUE) then
		node[VALUE] = new
		node[CHANGED] = epoch
		if obs and st0 ~= DEFERRED then
			notifyObservers(obs, node)
		end
	elseif nFailed > 0 and unfail(node) then
		healed(node)
	end
	if selfDirty then
		runComputedProtected(node)
	end
end

local function guarded(f: (any) -> (), node: any, check: number?)
	local pNode, pIdx, pNew, pRun, pEval, pFromUntrack, pRunning =
		curNode, curIdx, curNew, curRun, evalNode, evalFromUntrack, runningEffect
	local hadExtra = ownExtra
	local pCtx, pSusp, pSuspRun, pOwner, pSet
	if hadExtra then
		pCtx, pSusp, pSuspRun, pOwner, pSet = curCtx, susp, suspRun, curOwner, ownerSet
	end
	local ok, err = pcall(f, node)
	if not ok then
		local e, idx, new = evalNode, curIdx, curNew
		curNode, curIdx, curNew, curRun, evalNode, evalFromUntrack, runningEffect, curChildren =
			pNode, pIdx, pNew, pRun, pEval, pFromUntrack, pRunning, nil
		if hadExtra then
			curCtx, susp, suspRun, curOwner, ownerSet, ownExtra = pCtx, pSusp, pSuspRun, pOwner, pSet, true
		elseif ownExtra or susp then
			curCtx, susp, ownerSet, ownExtra = nil, nil, false, false
		end
		if e ~= pEval and e then
			finishErrored(e, idx, new, err)
		end
		local st = e and e[STAMP]
		if check and check < 64 and e ~= node and (st == STALE or st == ERRORED) and node[FN] then
			local held = st == STALE
			if held then
				e[STAMP] = ERRORED
			end
			ok, err = pcall(guarded, f, node, check + 1)
			if held and e[STAMP] == ERRORED then
				e[STAMP] = STALE
			end
			if ok then
				return
			end
		end
		error(err, 0)
	end
end

@native
local function pull(node: any)
	local st = node[STAMP]
	if st == 0 then
		if node[OBSERVERS] then
			guarded(settle, node, 1)
		else
			runComputedProtected(node)
		end
		return
	end
	if st == ERRORED and node[FN] then
		local live = node[OBSERVERS]
		if live and not flushing and curNode == nil and evalNode == nil and susp == nil then
			node[STAMP] = 0
			guarded(settle, node, 1)
			return
		elseif live and node[HEIGHT] > heapMin then
			guarded(settle, node, 1)
		end
		if node[STAMP] == ERRORED then
			error(node.err, 0)
		end
		return
	end
	if node[OBSERVERS] then
		if st == DEFERRED then
			if node[CHILDREN] == nil then
				node[CHILDREN] = false
			end
			runComputedProtected(node)
		elseif st >= STALE or node[HEIGHT] > heapMin then
			guarded(settle, node, 1)
		else
			node[STAMP] = node[HEIGHT] + LIVE_BASE
		end
	elseif node[FN] then
		if st > 0 then
			local dirty = false
			for i = SRC1, node[NSRC] - 2, 2 do
				local s = node[i]
				local sst = s[STAMP]
				local sh = s[HEIGHT]
				if sst == STALE or (sh and sst > liveMax and sst ~= epoch and sst ~= ERRORED) then
					guarded(pullDead, node, 1)
					return
				end
				local c = if sh then s[CHANGED] else sst
				if c == nil or c > st then
					dirty = true
					break
				end
			end
			if dirty then
				runComputedProtected(node)
			else
				node[STAMP] = epoch
			end
			return
		end
		guarded(pullDead, node, 1)
	end
end

local function runaway(e: any, ran: string)
	local source, line = (debug.info :: (any, string) -> (string, number))(e[E_FN], "sl")
	warn(`[Flux] an effect ({source}:{line}) {ran} in one flush and was disposed: does it write what it reads?`)
	disposeOne(e)
end

local function requeue(e: any, ...: any)
	local n = (reruns[e] or 1) + 1
	if n > RERUN_LIMIT then
		runaway(e, `ran {RERUN_LIMIT} times`)
	else
		reruns[e] = n
		anyReruns = true
		markOne(e)
	end
end

local function runEffectNow(e: any)
	for i = E_SRC1, e[E_NSRC] - 2, 2 do
		local s = e[i]
		if s[HEIGHT] and s[STAMP] > liveMax and s[STAMP] ~= epoch then
			refresh(s)
		end
	end
	if e[STAMP] ~= 0 or not e[E_FN] then
		return
	end
	local pNode, pIdx, pNew, pRun, pEval, pFromUntrack, pSusp, pCtx =
		curNode, curIdx, curNew, curRun, evalNode, evalFromUntrack, susp, curCtx
	local pSuspRun = suspRun
	local pSet, pExtra = ownerSet, ownExtra
	susp, ownerSet = nil, false
	if e[E_CHILDREN] then
		disposeChildren(e, E_CHILDREN, nil, false)
	end
	e[STAMP] = INF
	evalNode = e
	evalFromUntrack = false
	local pRunning, pSelf = runningEffect, selfWritten
	local outerFrame: RunningFrame? = nil
	if pRunning ~= noEffect then
		outerFrame = {
			idx = pIdx,
			newList = pNew,
			run = pRun,
			canCheck = pEval == nil or pEval == pRunning,
			written = false,
		}
		activeEffects[pRunning] = outerFrame
		nestedRunning += 1
		noEffect = OUTER_ACTIVE
	end
	runningEffect, selfWritten = e, nil
	curNode, curIdx, curNew, curRun, curChildren = e, E_SRC1, nil, -1, nil
	local okFn, fnErr = pcall(e[E_FN])
	runningEffect = pRunning
	if outerFrame ~= nil then
		activeEffects[pRunning] = nil
		nestedRunning -= 1
		if nestedRunning == 0 then
			noEffect = nil
		end
	end
	if not okFn then
		if outerFrame ~= nil and outerFrame.written then
			requeue(pRunning)
		end
		error(fnErr, 0)
	end
	if selfWritten == e then
		selfWritten = pSelf
		requeue(e)
	elseif selfWritten == nil then
		selfWritten = pSelf
	end
	if outerFrame ~= nil and outerFrame.written then
		requeue(pRunning)
	end
	if e[E_FN] then
		local idx = curIdx
		local last = e[E_NSRC]
		if idx ~= last then
			local newList = curNew
			curIdx, curNew = last, nil
			if newList then
				idx = newList[1]
			end
			reconcile(e, E_NSRC, last, idx, newList, true)
		end
	end
	curNode, curIdx, curNew, curRun, evalNode, evalFromUntrack, susp, curCtx, curChildren =
		pNode, pIdx, pNew, pRun, pEval, pFromUntrack, pSusp, pCtx, nil
	suspRun = pSuspRun
	ownerSet, ownExtra = pSet, pExtra
	if not e[E_FN] then
		reap(e)
	end
end

local function stabilizeSameSlow(node: any, new: any, obs: any, ...: any)
	if hasCompEquals and node[VALUE] == FORCE_COMMIT then
		if nFailed > 0 then
			unfail(node)
		end
		node[VALUE] = new
		node[CHANGED] = epoch
		if obs then
			notifyObservers(obs, node)
		end
	elseif nFailed > 0 and unfail(node) then
		healed(node)
	end
end

-- plexer-ignore[monster_functions]: hot-path stabilization loop kept inlined for zero-overhead benchmark throughput
@native
local function stabilize()
	local hp, q = heap, queue
	curNew, curChildren = nil, nil
	local h = heapMin
	while h <= heapMax do
		local node = hp[h]
		if node then
			local lMax = h + LIVE_BASE
			liveMax = lMax
			repeat
				local nx = node[NEXT]
				if nx == true then
					hp[h] = false
					heapMin = h + 1
				else
					hp[h] = nx
				end
				node[NEXT] = false
				if node[STAMP] == 0 then
					if node[HEIGHT] ~= h then
						insert(node)
					else
						while true do
							local obs = node[OBSERVERS]
							if not obs then
								break
							end
							local children = node[CHILDREN]
							if children ~= false then
								if not children then
									local list = not obs[HEIGHT]
									local o1 = if list then obs[OBS1] else obs
									local st1 = o1[STAMP]
									if (st1 == 0 or st1 == DEFERRED) and o1[HEIGHT] ~= INF then
										local defer = true
										if list then
											for i = OBS1 + 1, obs[1] do
												local o = obs[i]
												local ost = o[STAMP]
												if (ost ~= 0 and ost ~= DEFERRED) or o[HEIGHT] == INF then
													defer = false
													break
												end
											end
										end
										if defer then
											node[STAMP] = DEFERRED
											break
										end
									end
								else
									disposeChildren(node, CHILDREN, node[VALUE], false)
								end
							end
							node[STAMP] = lMax
							curRun = -1
							curNode, curIdx = node, SRC1
							local old = node[VALUE]
							local new = node[FN](old)
							local idx = curIdx
							local last = node[NSRC]
							if idx ~= last or not curNode then
								if not curNode then
									curNode = node
									if susp or evalFromUntrack then
										susp, evalNode, evalFromUntrack = nil, nil, false
										ownExtra = curCtx ~= nil
									end
								end
								if not node[FN] then
									curNew = nil
									curNode = nil
									node[VALUE] = nil
									reap(node)
									break
								elseif idx ~= last then
									local newList = curNew
									curIdx, curNew = last, nil
									if newList then
										idx = newList[1]
									end
									local live = node[OBSERVERS] ~= false
									reconcile(node, NSRC, last, idx, newList, live)
									if not node[FN] then
										break
									end
									if node[STAMP] ~= 0 then
										node[STAMP] = if node[OBSERVERS] ~= false
											then node[HEIGHT] + LIVE_BASE
											else epoch
									end
								end
							end
							obs = node[OBSERVERS]
							if new ~= old then
								if slowCommit and new == SAME_VALUE then
									stabilizeSameSlow(node, new, nil)
									break
								end
								node[VALUE] = new
								node[CHANGED] = epoch
								if obs then
									local oh = obs[HEIGHT]
									if oh then
										local o = obs
										if o[STAMP] ~= 0 then
											if oh == INF then
												o[STAMP] = 0
												local qt = queueTail + 1
												queueTail = qt
												q[qt] = o
											elseif oh <= heapMin and o[CHILDREN] ~= nil then
												h = oh
												nx = hp[oh] or true
												if nx == true then
													heapMin = oh + 1
												end
												lMax = oh + LIVE_BASE
												liveMax = lMax
												node = o
												continue
											else
												o[STAMP] = 0
												if not o[NEXT] then
													o[NEXT] = hp[oh] or true
													hp[oh] = o
													if oh > heapMax then
														heapMax = oh
													end
												end
											end
										end
									else
										local qt, hMax = queueTail, heapMax
										for i = OBS1, obs[1] do
											local o = obs[i]
											if o[STAMP] ~= 0 then
												o[STAMP] = 0
												local oHeight = o[HEIGHT]
												if oHeight ~= INF then
													if not o[NEXT] then
														o[NEXT] = hp[oHeight] or true
														hp[oHeight] = o
														if oHeight > hMax then
															hMax = oHeight
														end
													end
												else
													qt += 1
													q[qt] = o
												end
											end
										end
										queueTail, heapMax = qt, hMax
									end
								end
							elseif slowCommit then
								stabilizeSameSlow(node, new, obs)
							end
							break
						end
					end
				end
				local nextH = heapMin
				if nextH == h then
					node = hp[h]
					if node ~= nx then
						checkCompRun(node)
					end
				else
					if nextH < h then
						local target = hp[nextH]
						if target then
							checkCompRun(target)
						end
					end
					h = nextH
					break
				end
			until false
		else
			h += 1
			heapMin = h
		end
	end
	curNode = nil
	heapMin = INF
	liveMax = LIVE_MAX_IDLE
	heapMax = 0
end

local flush: () -> ()
do
	local function guard(tail: number, ...: any)
		for i = math.max(queueHead, counted + 1), tail do
			local e = queue[i]
			if e[STAMP] == 0 and e[E_FN] then
				local n = (cycles[e] or 0) + 1
				if n > RERUN_LIMIT then
					runaway(e, "kept re-running")
				else
					cycles[e] = n
				end
			end
		end
		counted = tail
		anyReruns = true
	end

	@native
	local function reconcileEffect(e: any, idx: number, last: number)
		local untracked = not curNode
		curNode, runningEffect = nil, noEffect
		if untracked then
			susp = nil
			if evalFromUntrack then
				evalNode, evalFromUntrack = nil, false
			end
			ownExtra = curCtx ~= nil
			if idx == last and e[E_FN] then
				return
			end
		end
		if not e[E_FN] then
			curNew = nil
			evalNode = nil
			reap(e)
			return
		end
		local newList = curNew
		curIdx, curNew, evalNode = last, nil, e
		if newList then
			idx = newList[1]
		end
		reconcile(e, E_NSRC, last, idx, newList, true)
		evalNode = nil
		if not e[E_FN] then
			reap(e)
		end
	end

	@native
	local function drain()
		while true do
			if heapMin ~= INF then
				stabilize()
			end
			local qh = queueHead
			local tail = queueTail
			if qh > tail then
				break
			end
			passes += 1
			if passes > GUARD_PASSES then
				guard(tail)
			end
			curNew, curChildren = nil, nil
			local q = queue
			for i = qh, tail do
				local e = q[i]
				queueHead = i + 1
				if e[STAMP] == 0 then
					local fn: (() -> ())? = e[E_FN]
					if fn then
						if e[E_CHILDREN] then
							runningEffect = noEffect
							disposeChildren(e, E_CHILDREN, nil, false)
						end
						e[STAMP] = INF
						curRun = -1
						runningEffect, curNode, curIdx = e, e, E_SRC1
						fn()
						local idx = curIdx
						if selfWritten and selfWritten == e then
							selfWritten = nil
							requeue(e)
						end
						local last = e[E_NSRC]
						if idx ~= last or not curNode then
							if idx > last and curNode and e[E_FN] then
								curNode, runningEffect, evalNode, curIdx = nil, noEffect, e, last
								local hooked = hasHooks
								if hooked then
									hookDepth += 1
								end
								for j = last, idx - 2, 2 do
									local s = e[j]
									if not s[HEIGHT] then
										local n0 = s[OBSERVERS]
										if n0 ~= nil then
											local n = n0 + 1
											s[OBSERVERS] = n
											s[n + SIG_OBS0] = e
											e[j + 1] = n
											if hooked and n == 1 then
												fireHook(s, 1)
											end
										else
											e[j + 1] = 0
										end
									else
										local back = subscribe(s, e, 0)
										if back < 0 then
											rollbackReconcileAdd(e, E_NSRC, j, idx, hooked)
										end
										e[j + 1] = back
									end
								end
								e[E_NSRC] = idx
								evalNode = nil
								if hooked then
									endHooks()
								end
								if not e[E_FN] then
									reap(e)
								end
							else
								reconcileEffect(e, idx, last)
							end
						end
					end
					if heapMin ~= INF then
						break
					end
				end
			end
			curNode, runningEffect = nil, noEffect
			if queueHead > queueTail then
				if queueTail > 16384 then
					queue = {}
					queueCap = 0
				elseif queueHead == 2 and queueTail == 1 then
					q[1] = nil
				else
					if queueTail > queueCap then
						queueCap = queueTail
					end
					table.clear(q)
				end
				queueHead, queueTail = 1, 0
				counted = 0
				if heapMin == INF then
					break
				end
			end
		end
	end

	local rawError: any = nil
	local function drainTraceback(err: any): any
		rawError = err
		return traceback(err)
	end

	local function recover(err: any, pCtx: any?, pExtra: boolean?)
		repeat
			local e = curNode or evalNode or (if suspRun == curRun then susp else nil)
			local raw = rawError
			local idx = curIdx
			curNode, evalNode, evalFromUntrack, susp, rawError, curCtx, curChildren =
				nil, nil, false, nil, nil, pCtx, nil
			ownExtra = pExtra == true
			runningEffect = noEffect
			if e then
				finishErrored(e, idx, curNew, raw)
				curNew = nil
				local h = e[HEIGHT]
				if (h == INF and e[E_FN]) or (h and h ~= SCOPE and e[FN] and not e[OBSERVERS]) then
					warn(`[Flux] suppressed effect error:\n{err}`)
				end
			end
			local ok
			ok, err = (xpcall :: (any, any) -> (boolean, any))(drain, drainTraceback)
		until ok
		rawError = nil
	end

	local function clearRerunState(...: any)
		table.clear(reruns)
		table.clear(cycles)
		anyReruns = false
		if compRunActive then
			table.clear(compRuns)
			compRunActive = false
		end
	end

	local function flushRecoverFast(err: any)
		local okFlush, flushErr = pcall(recover, err, nil, nil)
		runningEffect = noEffect
		curNode, evalNode, evalFromUntrack, susp, curChildren = nil, nil, false, nil, nil
		ownExtra = false
		if anyReruns then
			clearRerunState()
		end
		passes = 0
		flushing = false
		if not okFlush then
			error(flushErr, 0)
		end
	end

	local function flushRecoverSlow(err: any, pCtx: any?, pExtra: boolean?): (boolean, any)
		return pcall(recover, err, pCtx, pExtra)
	end

	@native
	function flush()
		if flushing or (heapMin == INF and queueHead > queueTail) then
			return
		end
		flushing = true
		if curNode == nil and runningEffect == nil and not ownExtra then
			local ok, err = (xpcall :: (any, any) -> (boolean, any))(drain, drainTraceback)
			if not ok then
				flushRecoverFast(err)
				return
			end
			if anyReruns then
				clearRerunState()
			end
			passes = 0
			flushing = false
			return
		end
		local pNode, pIdx, pNew, pRun, pCtx, pEval, pSusp = curNode, curIdx, curNew, curRun, curCtx, evalNode, susp
		local pSuspRun, pRunning, pSelf, pFromUntrack = suspRun, runningEffect, selfWritten, evalFromUntrack
		local pSet, pExtra = ownerSet, ownExtra
		curNode, evalNode, evalFromUntrack, susp, ownerSet, curChildren = nil, nil, false, nil, false, nil
		local ok, err = (xpcall :: (any, any) -> (boolean, any))(drain, drainTraceback)
		local okFlush = true
		local flushErr: any = nil
		if not ok then
			okFlush, flushErr = flushRecoverSlow(err, pCtx, pExtra)
		end
		if anyReruns then
			clearRerunState()
		end
		passes = 0
		curNode, curIdx, curNew, curRun, curCtx, evalNode, evalFromUntrack, susp, curChildren =
			pNode, pIdx, pNew, pRun, pCtx, pEval, pFromUntrack, pSusp, nil
		suspRun, runningEffect, selfWritten = pSuspRun, pRunning, pSelf
		ownerSet, ownExtra = pSet, pExtra
		flushing = false
		if not okFlush then
			error(flushErr, 0)
		end
	end
end

@native
local function currentOwner(): any
	if ownerSet then
		return curOwner
	end
	local o = curNode
	if not o then
		if susp and suspRun == curRun then
			o = susp
		else
			o = curOwner
		end
	end
	return o
end

@native
local function childrenOf(o: any): any
	local h = o[HEIGHT]
	if h == nil then
		local c = o.owned
		if not c then
			c = { 1 }
			o.owned = c
		end
		return c
	end
	local slot = if h == INF then E_CHILDREN else CHILDREN
	local c = o[slot]
	if not c then
		c = { 1 }
		o[slot] = c
	end
	return c
end

@native
local function ownSlow(node: any)
	local o = currentOwner()
	if o then
		local c = childrenOf(o)
		local n = c[1] + 1
		c[1] = n
		c[n] = node
	end
	local ctx = curCtx
	if ctx then
		node.ctx = ctx
		local h = node[HEIGHT]
		if h == INF then
			local fn = node[E_FN]
			node[E_FN] = function()
				local p, pExtra = curCtx, ownExtra
				curCtx, ownExtra = ctx, true
				fn()
				curCtx, ownExtra = p, pExtra or susp ~= nil
			end
		elseif h and h ~= SCOPE then
			local fn = node[FN]
			node[FN] = function(prev: any)
				local p, pExtra = curCtx, ownExtra
				curCtx, ownExtra = ctx, true
				local v = fn(prev)
				curCtx, ownExtra = p, pExtra
				return v
			end
		end
	end
end

local stampedRun, stampedTo = 0, 0

@native
local function trackSlow(node: any, r: any, run: number, new: any, idx: number, ...: any)
	if new then
		if stampedRun ~= run then
			stampedRun = run
			local base = if r[HEIGHT] == INF then E_SRC1 else SRC1
			for i = base, new[1] - 2, 2 do
				r[i][SEEN] = run
			end
			for i = 3, new[2] do
				new[i][SEEN] = run
			end
			if node[SEEN] == run then
				return
			end
		end
		node[SEEN] = run
		local n = new[2] + 1
		new[2] = n
		new[n] = node
		return
	end
	local st = stampedTo
	if stampedRun ~= run then
		stampedRun = run
		st = if idx < SRC1 or r[HEIGHT] == INF then E_SRC1 else SRC1
	end
	if st < idx then
		for i = st, idx - 2, 2 do
			r[i][SEEN] = run
		end
		if node[SEEN] == run then
			stampedTo = idx
			return
		end
	end
	node[SEEN] = run
	stampedTo = idx
	local f = freeNew
	if f then
		freeNew = nil
		f[1] = idx
		f[2] = 3
		f[3] = node
		curNew = f
	else
		curNew = { idx, 3, node }
	end
	curIdx = DIVERGED
end

@native
local function track(node: any)
	local r = curNode
	if node[OBSERVERS] == nil or node == r then
		return
	end
	local run: number
	local cur = curRun
	if cur > 0 then
		run = cur
	else
		run = runId + 1
		runId, curRun = run, run
	end
	local new = curNew
	local idx = curIdx
	if not new and r[idx] == nil then
		local st = stampedTo
		if stampedRun ~= run then
			stampedRun = run
			st = if idx < SRC1 or r[HEIGHT] == INF then E_SRC1 else SRC1
		end
		if st < idx then
			for i = st, idx - 2, 2 do
				r[i][SEEN] = run
			end
			if node[SEEN] == run then
				stampedTo = idx
				r[idx] = false
				r[idx] = nil
				return
			end
		end
		node[SEEN] = run
		r[idx] = node
		r[idx + 1] = 0
		local nextIdx = idx + 2
		curIdx = nextIdx
		stampedTo = nextIdx
		return
	end
	trackSlow(node, r, run, new, idx)
end

@native
local function pullValue(node: any, h: number): any
	local st = node[STAMP]
	if h == INF then
		if node[E_FN] and (st == 0 or heapMin ~= INF) then
			guarded(runEffectNow, node)
		end
		return nil
	elseif h ~= SCOPE and st > liveMax and st ~= epoch then
		pull(node)
	end
	return node[VALUE]
end

@native
local function getData(node: any): any
	local h = node[HEIGHT]
	local r = curNode
	if r then
		local i = curIdx
		if r[i] == node then
			curIdx = i + 2
		elseif node[SEEN] ~= curRun and h ~= INF and h ~= SCOPE then
			track(node)
		end
	end
	if h then
		return pullValue(node, h)
	end
	return node[VALUE]
end

@native
local function getSignal(node: any): any
	local r = curNode
	if r then
		local i = curIdx
		if r[i] == node then
			curIdx = i + 2
			return node[VALUE]
		elseif node[SEEN] ~= curRun then
			track(node)
		end
	end
	return node[VALUE]
end

@native
local function getMemo(node: any): any
	local r = curNode
	if r then
		local i = curIdx
		if r[i] == node then
			curIdx = i + 2
			if node[STAMP] <= liveMax then
				return node[VALUE]
			end
			if node[STAMP] ~= epoch then
				pull(node)
			end
			return node[VALUE]
		elseif node[SEEN] ~= curRun then
			track(node)
		end
	end
	if node[STAMP] <= liveMax then
		return node[VALUE]
	end
	if node[STAMP] ~= epoch then
		pull(node)
	end
	return node[VALUE]
end

@native
local function peekData(node: any): any
	local h = node[HEIGHT]
	if h then
		return pullValue(node, h)
	end
	return node[VALUE]
end

@native
local function writeComputed(node: any, value: any, force: boolean?)
	if node[FN] == nil then
		return
	end
	local st = node[STAMP]
	if st > liveMax and st ~= epoch then
		local n = curNode
		curNode = nil
		pull(node)
		curNode = n
	end
	local old = node[VALUE]
	if not force then
		local eq: ((any, any) -> boolean)? = node.equals
		if if eq then eq(old, value) else old == value then
			return
		end
	end
	node[VALUE] = value
	epoch += 1
	node[CHANGED] = epoch
	local obs = node[OBSERVERS]
	node[STAMP] = if obs and node[HEIGHT] <= heapMin then node[HEIGHT] + LIVE_BASE else epoch
	if obs then
		markList(node, obs)
	end
	if curNode or runningEffect then
		markSelf(node)
	end
end

@native
local function setSignalSlow(node: any, n: number, r: any, ...: any)
	if n > 0 then
		if n == 1 then
			local o = node[SIG_OBS1]
			if o[STAMP] ~= 0 and o ~= r then
				if runningEffect ~= nil then
					markOrDefer(o, node, runningEffect)
				else
					markOne(o)
				end
			end
		else
			markObservers(node, n)
		end
	end
	markSelf(node)
end

@native
local function setSignal(node: any, value: any, force: boolean?): any
	if not hasSigEquals then
		if node[VALUE] == value and not force then
			return value
		end
	elseif not force then
		local eq: ((any, any) -> boolean)? = node.equals
		if if eq then eq(node[VALUE], value) else node[VALUE] == value then
			return value
		end
	end
	local n = node[OBSERVERS]
	if not n then
		return value
	end
	node[VALUE] = value
	local ep = epoch + 1
	epoch = ep
	node[SIG_CHANGED] = ep
	local r = curNode
	if not r and not runningEffect then
		if n > 0 then
			if n == 1 then
				local o = node[SIG_OBS1]
				if o[STAMP] ~= 0 then
					local h = o[HEIGHT]
					if h == INF then
						o[STAMP] = 0
						local qt = queueTail + 1
						queueTail = qt
						queue[qt] = o
					else
						o[STAMP] = 0
						if not o[NEXT] then
							local hp = heap
							o[NEXT] = hp[h] or true
							hp[h] = o
							if h < heapMin then
								heapMin = h
								liveMax = h + LIVE_BASE
							end
							if h > heapMax then
								heapMax = h
							end
						end
					end
				end
			else
				local hp = heap
				local q = queue
				local qt = queueTail
				local hMin = heapMin
				local hMax = heapMax
				for i = SIG_OBS1, n + SIG_OBS0 do
					local o = node[i]
					if o[STAMP] ~= 0 then
						local h = o[HEIGHT]
						if h == INF then
							o[STAMP] = 0
							qt += 1
							q[qt] = o
						else
							o[STAMP] = 0
							if not o[NEXT] then
								o[NEXT] = hp[h] or true
								hp[h] = o
								if h < hMin then
									hMin = h
								end
								if h > hMax then
									hMax = h
								end
							end
						end
					end
				end
				queueTail = qt
				if hMin < heapMin then
					heapMin = hMin
					liveMax = hMin + LIVE_BASE
				end
				if hMax > heapMax then
					heapMax = hMax
				end
			end
		end
		return value
	end
	setSignalSlow(node, n, r)
	return value
end

@native
local function setData(node: any, value: any, force: boolean?): any
	local h = node[HEIGHT]
	if h == nil then
		return setSignal(node, value, force)
	elseif h ~= INF and h ~= SCOPE then
		writeComputed(node, value, force)
	end
	return value
end

@native
local function updateNode(node: any)
	local h = node[HEIGHT]
	if h == nil then
		local n = node[OBSERVERS]
		if n == nil then
			return
		end
		epoch += 1
		node[SIG_CHANGED] = epoch
		if n > 0 then
			markObservers(node, n)
		end
		if curNode or runningEffect then
			markSelf(node)
		end
	elseif h ~= INF and h ~= SCOPE and node[FN] then
		local obs = node[OBSERVERS]
		local st = node[STAMP]
		if st > liveMax and st ~= epoch then
			if obs then
				local n = curNode
				curNode = nil
				pull(node)
				curNode = n
				obs = node[OBSERVERS]
				st = node[STAMP]
			else
				epoch += 1
				node[CHANGED] = epoch
				node[STAMP] = STALE
				if curNode or runningEffect then
					markSelf(node)
				end
				return
			end
		end
		epoch += 1
		node[CHANGED] = epoch
		if st > 0 or not obs then
			node[STAMP] = if obs and h <= heapMin then h + LIVE_BASE else epoch
		end
		if obs then
			markList(node, obs)
		end
		if curNode or runningEffect then
			markSelf(node)
		end
	end
end

local function onDestroy(node: node, fn: (oldValue: any) -> ())
	local destroys = node.destroys
	if destroys then
		table.insert(destroys, fn)
	else
		node.destroys = { fn }
		liveDestroys += 1
		hasDestroys = true
	end
end

local function onHook(node: node, which: number, fn: () -> ())
	local nh = node[HEIGHT]
	if
		if nh == nil
			then node[OBSERVERS] == nil
			elseif nh == SCOPE then node[FN] == false
			else not node[if nh == INF then E_FN else FN]
	then
		return
	end
	local h = node.hooks
	if not h then
		h = { [3] = isNodeObserved(node) }
		node.hooks = h
		liveHooks += 1
		hasHooks = true
	end
	local prev: (() -> ())? = h[which]
	if prev then
		h[which] = function()
			prev()
			fn()
		end
	else
		h[which] = fn
	end
end

local untrack: (fn: (() -> ...any)?) -> ...any

local Node: any, SignalMT: any, ComputedMT: any = (function(): (any, any, any)
	@native
	local function nodeCall(self: any, value: any?, force: boolean?): any
		local node = rawget(self, 1)
		if value == nil and not force then
			return getData(node)
		end
		return setData(node, value, force)
	end

	@native
	local function nodePeek(self: any): any
		return peekData(rawget(self, 1))
	end

	@native
	local function nodeGet(self: any): any
		return getData(rawget(self, 1))
	end

	@native
	local function nodeSet(self: any, value: any, force: boolean?): any
		return setData(rawget(self, 1), value, force)
	end

	@native
	local function nodeUpdate(self: any, fn: ((current: any) -> any)?): any
		if fn ~= nil then
			if type(fn) ~= "function" then
				error(`node:update expected a function or nil, got {compatTypeof(fn)}`, 2)
			end
			local current = self:peek()
			local nextValue = if curNode ~= nil or susp ~= nil
				then untrack(function()
					return fn(current)
				end)
				else fn(current)
			self:set(nextValue)
			return self
		end
		updateNode(rawget(self, 1))
		return self
	end

	@native
	local function nodeDestroy(self: any)
		disposeOne(rawget(self, 1))
	end

	local Node: any = {
		__call = nodeCall,
		--stylua: ignore start
		__tostring = function(a: any): string return tostring(getData(rawget(a, 1))) end,
		__unm = function(a: any): number return -getData(rawget(a, 1)) end,
		__lt = function(a: any, b: any): boolean return getData(rawget(a, 1)) < getData(rawget(b, 1)) end,
		__le = function(a: any, b: any): boolean return getData(rawget(a, 1)) <= getData(rawget(b, 1)) end,
		--stylua: ignore end
		--[[
		Reads the node's current value without subscribing the caller.

		[Open Documentation](https://flux.kohl.gg/guide/concepts/signals#reading-a-signal)
		]]
		peek = nodePeek,
		--[[
		Reads the node's current value (`node()` does the same) and subscribes the running
		[computed](https://flux.kohl.gg/guide/concepts/computeds) or [effect](https://flux.kohl.gg/guide/concepts/effects).

		[Open Documentation](https://flux.kohl.gg/guide/concepts/signals#reading-a-signal)
		]]
		get = nodeGet,
		--[[
		Writes `value` (`node(value)` does the same), skipping propagation when it equals the current value (`~=` or the
		node's `equals`). Pass `force = true` to notify dependents anyway.

		[Open Documentation](https://flux.kohl.gg/guide/concepts/signals#updating-a-signal)
		]]
		set = nodeSet,
		--[[
		Notifies the node's dependents without changing its value, or updates it untracked via `fn(current)` when `fn` is provided.

		[Open Documentation](https://flux.kohl.gg/guide/concepts/signals#forcing-an-update)
		]]
		update = nodeUpdate,
		--[[
		Disconnects the node from its sources and observers, then runs its pending [`Flux.cleanup`](https://flux.kohl.gg/guide/concepts/effects#cleanup-with-flux-cleanup)
		values and `onDestroy` callbacks. Later reads return `nil`.

		[Open Documentation](https://flux.kohl.gg/guide/concepts/signals#destroying-a-signal)
		]]
		Destroy = nodeDestroy,
		--[[
		Registers `fn` to run with the node's last value when the node is destroyed. Unlike `Flux.cleanup`, `onDestroy`
		callbacks only run on final teardown and survive re-runs.

		[Open Documentation](https://flux.kohl.gg/guide/concepts/signals#destroying-a-signal)
		]]
		onDestroy = function(self: any, fn: (oldValue: any) -> ())
			onDestroy(rawget(self, 1), fn)
		end,
		--[[
		Registers `fn` to run when the node gains its first transitive effect observer. Pair with `onUnobserved` to start
		and stop external listeners on demand.
		]]
		onObserved = function(self: any, fn: () -> ())
			onHook(rawget(self, 1), 1, fn)
		end,
		--[[
		Registers `fn` to run when the node loses its last transitive effect observer.
		]]
		onUnobserved = function(self: any, fn: () -> ())
			onHook(rawget(self, 1), 2, fn)
		end,
	}
	Node.__type = Node
	Node.__index = Node

	do
		@native
		local function data(a: any): any
			local mt = getmetatable(a)
			return if mt ~= nil and type(mt) == "table" and mt.__type == Node then getData(rawget(a, 1)) else a
		end

		Node.__concat = function(a: any, b: any): string
			return data(a) .. data(b)
		end
		Node.__add = function(a: any, b: any): number
			return data(a) + data(b)
		end
		Node.__sub = function(a: any, b: any): number
			return data(a) - data(b)
		end
		Node.__mul = function(a: any, b: any): number
			return data(a) * data(b)
		end
		Node.__div = function(a: any, b: any): number
			return data(a) / data(b)
		end
		Node.__idiv = function(a: any, b: any): number
			return data(a) // data(b)
		end
		Node.__mod = function(a: any, b: any): number
			return data(a) % data(b)
		end
		Node.__pow = function(a: any, b: any): number
			return data(a) ^ data(b)
		end
	end

	@native
	local function signalCall(self: any, value: any?, force: boolean?): any
		local node = rawget(self, 1)
		if value == nil and not force then
			local r = curNode
			if r then
				local i = curIdx
				if r[i] == node then
					curIdx = i + 2
					return node[VALUE]
				elseif node[SEEN] ~= curRun then
					track(node)
				end
			end
			return node[VALUE]
		end
		return setSignal(node, value, force)
	end

	@native
	local function signalPeek(self: any): any
		return rawget(self, 1)[VALUE]
	end

	@native
	local function signalGet(self: any): any
		local node = rawget(self, 1)
		local r = curNode
		if r then
			local i = curIdx
			if r[i] == node then
				curIdx = i + 2
				return node[VALUE]
			elseif node[SEEN] ~= curRun then
				track(node)
			end
		end
		return node[VALUE]
	end

	@native
	local function signalSet(self: any, value: any, force: boolean?): any
		return setSignal(rawget(self, 1), value, force)
	end

	local SignalMT: any = {
		__call = signalCall,
		__concat = Node.__concat,
		__tostring = Node.__tostring,
		__unm = Node.__unm,
		__add = Node.__add,
		__sub = Node.__sub,
		__mul = Node.__mul,
		__div = Node.__div,
		__idiv = Node.__idiv,
		__mod = Node.__mod,
		__pow = Node.__pow,
		__lt = Node.__lt,
		__le = Node.__le,
		__type = Node,
		peek = signalPeek,
		get = signalGet,
		set = signalSet,
		update = Node.update,
		Destroy = Node.Destroy,
		onDestroy = Node.onDestroy,
		onObserved = Node.onObserved,
		onUnobserved = Node.onUnobserved,
	}

	@native
	local function computedCall(self: any, value: any?, force: boolean?): any
		local node = rawget(self, 1)
		if value == nil and not force then
			local r = curNode
			if r then
				local i = curIdx
				if r[i] == node then
					curIdx = i + 2
					if node[STAMP] <= liveMax then
						return node[VALUE]
					end
					if node[STAMP] ~= epoch then
						pull(node)
					end
					return node[VALUE]
				elseif node[SEEN] ~= curRun then
					track(node)
				end
			end
			if node[STAMP] <= liveMax then
				return node[VALUE]
			end
			if node[STAMP] ~= epoch then
				pull(node)
			end
			return node[VALUE]
		end
		writeComputed(node, value, force)
		return value
	end

	@native
	local function computedPeek(self: any): any
		local node = rawget(self, 1)
		if node[STAMP] <= liveMax then
			return node[VALUE]
		end
		if node[STAMP] ~= epoch then
			pull(node)
		end
		return node[VALUE]
	end

	@native
	local function computedGet(self: any): any
		local node = rawget(self, 1)
		local r = curNode
		if r then
			local i = curIdx
			if r[i] == node then
				curIdx = i + 2
				if node[STAMP] <= liveMax then
					return node[VALUE]
				end
				if node[STAMP] ~= epoch then
					pull(node)
				end
				return node[VALUE]
			elseif node[SEEN] ~= curRun then
				track(node)
			end
		end
		if node[STAMP] <= liveMax then
			return node[VALUE]
		end
		if node[STAMP] ~= epoch then
			pull(node)
		end
		return node[VALUE]
	end

	@native
	local function computedSet(self: any, value: any, force: boolean?): any
		writeComputed(rawget(self, 1), value, force)
		return value
	end

	local ComputedMT: any = {
		__call = computedCall,
		__concat = Node.__concat,
		__tostring = Node.__tostring,
		__unm = Node.__unm,
		__add = Node.__add,
		__sub = Node.__sub,
		__mul = Node.__mul,
		__div = Node.__div,
		__idiv = Node.__idiv,
		__mod = Node.__mod,
		__pow = Node.__pow,
		__lt = Node.__lt,
		__le = Node.__le,
		__type = Node,
		peek = computedPeek,
		get = computedGet,
		set = computedSet,
		update = Node.update,
		Destroy = Node.Destroy,
		onDestroy = Node.onDestroy,
		onObserved = Node.onObserved,
		onUnobserved = Node.onUnobserved,
	}

	for _, mt in { SignalMT, ComputedMT } do
		mt.__index = mt
		table.freeze(mt)
	end

	return Node, SignalMT, ComputedMT
end)()

@native
local function isNode(object: any): boolean
	local mt = getmetatable(object)
	return mt ~= nil
		and (mt == SignalMT or mt == ComputedMT or mt == Node or (type(mt) == "table" and mt.__type == Node))
end

@native
local function isDynamic(object: any): boolean
	return type(object) == "function" or isNode(object)
end

local raw: (object: any) -> any
do
	local function rawFn(object: () -> any, n: any, s: any): any
		local pSuspRun, pOwner, pSet, pExtra, pEval = suspRun, curOwner, ownerSet, ownExtra, evalNode
		curNode, susp, curChildren = nil, nil, nil
		local active = n or (if s ~= nil and pSuspRun == curRun then s else nil)
		if active then
			if pEval == nil and active ~= runningEffect then
				evalNode = active
			end
			if not pSet then
				curOwner, ownerSet, ownExtra = active, true, true
			end
		end
		local ok, result = pcall(object)
		curNode, susp, curChildren, curOwner, ownerSet, ownExtra, evalNode = n, s, nil, pOwner, pSet, pExtra, pEval
		suspRun = pSuspRun
		if not ok then
			error(result, 0)
		end
		return result
	end

	@native
	function raw(object: any): any
		local mt = getmetatable(object)
		if mt ~= nil then
			if mt == SignalMT then
				return rawget(object, 1)[VALUE]
			elseif mt == ComputedMT then
				local node = rawget(object, 1)
				if node[STAMP] <= liveMax then
					return node[VALUE]
				end
				if node[STAMP] ~= epoch then
					pull(node)
				end
				return node[VALUE]
			elseif mt == Node or (type(mt) == "table" and mt.__type == Node) then
				return peekData(rawget(object, 1))
			end
			return object
		elseif type(object) == "function" then
			local n, s = curNode, susp
			if n == nil and s == nil then
				return (object :: () -> any)()
			end
			return rawFn(object :: () -> any, n, s)
		end
		return object
	end
end

@native
local function read(object: any): any
	local mt = getmetatable(object)
	if mt ~= nil then
		if mt == SignalMT then
			return getSignal(rawget(object, 1))
		elseif mt == ComputedMT then
			return getMemo(rawget(object, 1))
		elseif mt == Node or (type(mt) == "table" and mt.__type == Node) then
			return getData(rawget(object, 1))
		end
		return object
	elseif type(object) == "function" then
		return (object :: () -> any)()
	end
	return object
end

@native
local function cleanup(obj: Cleanable)
	local owner = currentOwner()
	if not owner then
		error("cannot cleanup outside a reactive owner", 2)
	elseif type(obj) ~= "function" and not isCleanable(obj) then
		error(`cannot cleanup given object: {typeof(obj)}`, 2)
	end
	anyCleanups = true
	local c = childrenOf(owner)
	local fns = c.fns
	if fns then
		table.insert(fns, obj)
	else
		c.fns = { obj }
	end
end

@native
local function getOwner(): Owner?
	local o = currentOwner()
	local ctx = curCtx
	if o ~= nil and ctx ~= nil and o.ctx ~= ctx then
		local tokens: { [any]: any } = ctx.tokens or setmetatable({}, { __mode = "kv" })
		ctx.tokens = tokens
		local tok = tokens[o]
		if tok == nil then
			tok = { [HEIGHT] = OWNER_TOKEN, owner = o, ctx = ctx }
			tokens[o] = tok
		end
		return tok
	end
	return o
end

@native
local function isDisposed(o: any): boolean
	local h = o[HEIGHT]
	if h == nil then
		return o[OBSERVERS] == nil
	end
	return not o[if h == INF then E_FN else FN]
end

local withOwner: (node: any, fn: () -> ...any) -> ...any
do
	local function finishWithOwner(
		owner: any,
		root: any,
		pOwner: any,
		pSet: boolean,
		pSusp: any,
		pCtx: any,
		pExtra: boolean,
		pSuspRun: number,
		ok: boolean,
		...: any
	): ...any
		curOwner, ownerSet, susp, curCtx, ownExtra, curChildren = pOwner, pSet, pSusp, pCtx, pExtra, nil
		suspRun = pSuspRun
		if root then
			disposeOne(root)
		elseif owner and isDisposed(owner) then
			reap(owner)
		end
		if not ok then
			local err = (...)
			error(if type(err) == "string" then `error while running withOwner():\n{err}` else err, 0)
		end
		return ...
	end

	function withOwner(node: any, fn: () -> ...any): ...any
		local rawOwner: any = if node == nil then nil elseif isNode(node) then rawget(node, 1) else node
		local owner: node? = rawOwner
		local tokenCtx: ContextFrame? = nil
		if rawOwner ~= nil and rawOwner[HEIGHT] == OWNER_TOKEN then
			owner = rawOwner.owner
			tokenCtx = rawOwner.ctx
		end
		local pOwner, pSet, pSusp, pCtx, pExtra = curOwner, ownerSet, susp, curCtx, ownExtra
		local pSuspRun = suspRun
		local root = nil
		if owner then
			curCtx = tokenCtx or owner.ctx or pCtx
			if isDisposed(owner) then
				root = { nil, SCOPE, INF, true, false, false, true, false, false, false } :: node
				owner = root
			end
		elseif tokenCtx then
			curCtx = tokenCtx
		end
		curOwner, ownerSet, susp, ownExtra, curChildren = owner, true, nil, true, nil
		return finishWithOwner(owner, root, pOwner, pSet, pSusp, pCtx, pExtra, pSuspRun, xpcall(fn, traceback))
	end
end

do
	local function finishUntrack(
		n: any,
		pSusp: any,
		pOwner: any,
		pSet: boolean,
		pExtra: boolean,
		pSuspRun: number,
		pEval: any,
		ok: boolean,
		...: any
	): ...any
		curNode, susp, curOwner, ownerSet, ownExtra, evalNode, curChildren = n, pSusp, pOwner, pSet, pExtra, pEval, nil
		suspRun = pSuspRun
		if not ok then
			local err = ...
			error(if type(err) == "string" then `error while running untrack():\n{err}` else err, 0)
		end
		return ...
	end

	@native
	function untrack(fn: (() -> ...any)?): ...any
		local n = curNode
		if not fn then
			if n then
				local run: number
				local cur = curRun
				if cur > 0 then
					run = cur
				else
					run = runId + 1
					runId, curRun = run, run
				end
				susp, suspRun = n, run
				if evalNode == nil and n ~= runningEffect then
					evalNode = n
					evalFromUntrack = true
				end
				curNode = nil
				ownExtra = true
				curChildren = nil
			end
			return
		end
		local pSusp, pOwner, pSet, pExtra, pEval = susp, curOwner, ownerSet, ownExtra, evalNode
		local pSuspRun = suspRun
		curNode, susp, curChildren = nil, nil, nil
		local active = n or (if pSusp ~= nil and pSuspRun == curRun then pSusp else nil)
		if active then
			if pEval == nil and active ~= runningEffect then
				evalNode = active
			end
			if not ownerSet then
				curOwner, ownerSet, ownExtra = active, true, true
			end
		end
		return finishUntrack(n, pSusp, pOwner, pSet, pExtra, pSuspRun, pEval, xpcall(fn, traceback))
	end
end

@native
local function retrack()
	if curNode == nil and susp and suspRun == curRun then
		if evalFromUntrack then
			evalNode = nil
			evalFromUntrack = false
		end
		curNode = susp
		susp = nil
		ownExtra = curCtx ~= nil or ownerSet
	end
end

local function finishIsolate(
	pNode: any,
	pSusp: any,
	pSuspRun: number,
	pOwner: any,
	pSet: boolean,
	pCtx: any,
	pExtra: boolean,
	pEval: any,
	pFromUntrack: boolean,
	pChildren: any,
	ok: boolean,
	...: any
): ...any
	curNode, susp, curOwner, ownerSet, curCtx, ownExtra, evalNode, evalFromUntrack, curChildren =
		pNode, pSusp, pOwner, pSet, pCtx, pExtra, pEval, pFromUntrack, pChildren
	suspRun = pSuspRun
	if not ok then
		error((...), 0)
	end
	return ...
end

local function isolate<A..., R...>(fn: (A...) -> R..., ...: A...): R...
	if curNode == nil and curOwner == nil and not ownerSet and susp == nil and evalNode == nil then
		return fn(...)
	end
	local pNode, pSusp, pSuspRun = curNode, susp, suspRun
	local pOwner, pSet, pCtx, pExtra = curOwner, ownerSet, curCtx, ownExtra
	local pEval, pFromUntrack, pChildren = evalNode, evalFromUntrack, curChildren
	curNode, susp, curOwner, ownerSet, ownExtra, evalNode, evalFromUntrack, curChildren =
		nil, nil, nil, false, curCtx ~= nil, nil, false, nil
	suspRun = 0
	return finishIsolate(
		pNode,
		pSusp,
		pSuspRun,
		pOwner,
		pSet,
		pCtx,
		pExtra,
		pEval,
		pFromUntrack,
		pChildren,
		(pcall :: (...any) -> (boolean, ...any))(fn, ...)
	)
end

@native
local function dispose(obj: Cleanable?)
	local n, pSusp, pEval = curNode, susp, evalNode
	local pSuspRun = suspRun
	if pEval == nil and n ~= nil and n ~= runningEffect then
		evalNode = n
	end
	curNode, susp, curChildren = nil, nil, nil
	clean(obj)
	curNode, susp, evalNode, curChildren = n, pSusp, pEval, nil
	suspRun = pSuspRun
end

-- A context: `get` reads it and `provide` sets it for a function's extent. A frame's key is the context itself.
export type Context<T> = {
	read default: T,
	--[[
	Returns the value from the innermost active `provide` call, or `default` if none is active. Computeds, effects, and
	scopes remember the context values active when they were created.

	[Open Documentation](https://flux.kohl.gg/guide/concepts/context#providing-and-reading)
	]]
	get: (self: any) -> T,
	--[[
	Runs `fn` with this context set to `value` for all code and reactive nodes created inside `fn`, then restores the
	previous value.

	[Open Documentation](https://flux.kohl.gg/guide/concepts/context#providing-and-reading)
	]]
	provide: <R>(self: any, value: T, fn: () -> R) -> R,
}

--- @ignore
type ContextData<T> = { default: T }

local context: <T>(default: T) -> Context<T>
do
	local Context = {}
	Context.__index = Context
	--[[
	Returns the value from the innermost active `provide` call, or `default` if none is active. Computeds, effects, and
	scopes remember the context values active when they were created.

	[Open Documentation](https://flux.kohl.gg/guide/concepts/context#providing-and-reading)
	]]
	@native
	function Context.get<T>(self: ContextData<T>): T
		local frame = curCtx
		while frame do
			if frame.key == self then
				return frame.value
			end
			frame = frame.parent
		end
		return self.default
	end

	--[[
	Runs `fn` with this context set to `value` for all code and reactive nodes created inside `fn`, then restores the
	previous value.

	[Open Documentation](https://flux.kohl.gg/guide/concepts/context#providing-and-reading)
	]]
	function Context.provide<T, R>(self: ContextData<T>, value: T, fn: () -> R): R
		if type(fn) ~= "function" then
			error("Context:provide() expects a function as its second argument", 2)
		end
		local prevContext, prevExtra = curCtx, ownExtra
		ownExtra, curChildren = true, nil
		curCtx = { parent = prevContext, key = self, value = value }
		local ok, result = xpcall(fn, traceback)
		curCtx, ownExtra, curChildren = prevContext, prevExtra or susp ~= nil, nil
		if not ok then
			error(result, 0)
		end
		return result
	end

	function context(default: any): any
		return setmetatable({ default = default }, Context)
	end
end

local function finishBindContext(prevContext: any, prevExtra: boolean, ok: boolean, ...: any): ...any
	curCtx, ownExtra = prevContext, prevExtra or susp ~= nil
	if not ok then
		error((...), 0)
	end
	return ...
end

local function bindContext<A..., R...>(fn: (A...) -> R...): (A...) -> R...
	if type(fn) ~= "function" then
		error("bindContext expects a function", 2)
	end
	local ctx = curCtx
	if ctx == nil then
		return fn
	end
	return function(...: A...): R...
		local prevContext, prevExtra = curCtx, ownExtra
		curCtx, ownExtra, curChildren = ctx, true, nil
		return finishBindContext(prevContext, prevExtra, xpcall(fn :: (...any) -> ...any, traceback, ...))
	end
end

@native
local function attachSlow(node: any)
	if ownExtra then
		ownSlow(node)
		return
	end
	local o = curNode or curOwner
	if o then
		local slot = if o[HEIGHT] == INF then E_CHILDREN else CHILDREN
		local c = o[slot]
		if c then
			local n = c[1] + 1
			c[1] = n
			c[n] = node
		else
			c = { 2, node }
			o[slot] = c
		end
		if curNode == nil and not flushing and o[HEIGHT] == SCOPE then
			curChildren = c
		end
	end
end

@native
local function scope<T>(fn: (scope: Node<any>) -> T): (Node<any>, T)
	local inner = { nil, SCOPE, INF, true, false, false, true, false, false, false }
	local c = curChildren
	if c then
		local n = c[1] + 1
		c[1] = n
		c[n] = inner
	elseif ownExtra or curNode or curOwner then
		attachSlow(inner)
	end
	local node: any = setmetatable({ inner }, Node)
	local pNode, pOwner, pSet, pSusp, pIdx, pNew, pEval = curNode, curOwner, ownerSet, susp, curIdx, curNew, evalNode
	local pSuspRun = suspRun
	if pEval == nil and pNode ~= nil and pNode ~= runningEffect then
		evalNode = pNode
	end
	curNode, curOwner, ownerSet, susp, curChildren = nil, inner, false, nil, nil
	local ok, result = xpcall(fn, traceback, node)
	curNode, curOwner, ownerSet, susp, curIdx, curNew, evalNode, curChildren =
		pNode, pOwner, pSet, pSusp, pIdx, pNew, pEval, nil
	suspRun = pSuspRun
	if inner[FN] == false then
		reap(inner)
	end
	if not ok then
		disposeOne(inner)
		error(if type(result) == "string" then `error while running scope():\n{result}` else result, 0)
	end
	return node, result
end

@native
local function signal(initial: any, equals: any): any
	local node: any = { initial, nil, 0, 0, 0, nil }
	if equals then
		node.equals = equals
		liveSigEquals += 1
		hasSigEquals = true
	end
	return setmetatable({ node }, SignalMT)
end

local function wrapComputedEquals(node: any, fn: any, equals: any, ...: any)
	hasCompEquals = true
	slowCommit = true
	node.equals = equals
	local initialized = false
	node[FN] = function(prev: any)
		local v = fn(prev)
		if not initialized then
			initialized = true
			if v == prev and node[FN] ~= nil then
				node[VALUE] = FORCE_COMMIT
			end
			return v
		end
		local pNode, pEval = curNode, evalNode
		curNode, evalNode = nil, node
		local okEq, same = pcall(equals, prev, v)
		curNode, evalNode = pNode, pEval
		if not okEq then
			error(same, 0)
		end
		if same then
			if prev == prev then
				return prev
			end
			return SAME_VALUE
		end
		if v == prev and node[FN] ~= nil then
			node[VALUE] = FORCE_COMMIT
		end
		return v
	end
end

@native
local function computed(fn: any, equals: any): any
	local node: any = { nil, 1, 0, false, 0, 0, fn, SRC1, false, false, nil, nil }
	if equals then
		wrapComputedEquals(node, fn, equals)
	end
	local c = curChildren
	if c then
		local n = c[1] + 1
		c[1] = n
		c[n] = node
	elseif ownExtra or curNode or curOwner then
		attachSlow(node)
	end
	return setmetatable({ node }, ComputedMT)
end

@native
local function newEffectNode(fn: (...any) -> ...any): any
	local node: any = { fn, INF, 0, E_SRC1, false, nil, nil }
	local c = curChildren
	if c then
		local n = c[1] + 1
		c[1] = n
		c[n] = node
	elseif ownExtra or curNode or curOwner then
		attachSlow(node)
	end
	local qt = queueTail + 1
	queueTail = qt
	queue[qt] = node
	return node
end

@native
local function createEffect(fn: (...any) -> ...any)
	newEffectNode(fn)
end

@native
local function effect(fn: (...any) -> ...any): any
	return setmetatable({ newEffectNode(fn) }, Node)
end

@native
local function memoSlow(n: any, needTrack: boolean, ...: any): any
	if needTrack then
		track(n)
	end
	local st = n[STAMP]
	if st > liveMax and st ~= epoch then
		pull(n)
	end
	return n[VALUE]
end

@native
local function getter(node: any): any
	local mt = getmetatable(node)
	if mt == SignalMT then
		local inner = rawget(node, 1)
		@native
		local function get(): any
			local n = inner
			local r = curNode
			if r then
				local i = curIdx
				if r[i] == n then
					curIdx = i + 2
					return n[VALUE]
				elseif n[SEEN] ~= curRun then
					track(n)
				end
			end
			return n[VALUE]
		end
		return get
	elseif mt == ComputedMT then
		local inner = rawget(node, 1)
		@native
		local function get(): any
			local n = inner
			local r = curNode
			if r then
				local i = curIdx
				if r[i] == n then
					curIdx = i + 2
					local st = n[STAMP]
					if st > liveMax and st ~= epoch then
						return memoSlow(n, false)
					end
					return n[VALUE]
				end
				if n[SEEN] ~= curRun then
					return memoSlow(n, true)
				end
			end
			local st = n[STAMP]
			if st > liveMax and st ~= epoch then
				return memoSlow(n, false)
			end
			return n[VALUE]
		end
		return get
	elseif mt == Node or (mt ~= nil and type(mt) == "table" and mt.__type == Node) then
		local inner = rawget(node, 1)
		@native
		local function get(): any
			return getData(inner)
		end
		return get
	end
	error(`Flux.getter expects a node, got {typeof(node)}`, 2)
end

@native
local function setter(node: any): any
	local mt = getmetatable(node)
	if mt == SignalMT then
		local inner = rawget(node, 1)
		@native
		local function set(value: any, force: boolean?): any
			return setSignal(inner, value, force)
		end
		return set
	elseif mt == ComputedMT or mt == Node or (mt ~= nil and type(mt) == "table" and mt.__type == Node) then
		local inner = rawget(node, 1)
		@native
		local function set(value: any, force: boolean?): any
			return setData(inner, value, force)
		end
		return set
	end
	error(`Flux.setter expects a node, got {typeof(node)}`, 2)
end

@native
local function createSignal<T>(initial: T, equals: ((T, T: any) -> boolean)?): (() -> T, (value: T, force: boolean?) -> T)
	local node: any = { initial, nil, 0, 0, 0, nil }
	if equals then
		node.equals = equals
		liveSigEquals += 1
		hasSigEquals = true
	end
	@native
	local function get(): any
		local n = node
		local r = curNode
		if r then
			local i = curIdx
			if r[i] == n then
				curIdx = i + 2
				return n[VALUE]
			elseif n[SEEN] ~= curRun then
				track(n)
			end
		end
		return n[VALUE]
	end
	@native
	local function set(value: any, force: boolean?): any
		return setSignal(node, value, force)
	end
	return get, set
end

@native
local function createMemo<T>(fn: (prev: any) -> T, equals: ((T, T) -> boolean)?): () -> T
	local node: any = { nil, 1, 0, false, 0, 0, fn, SRC1, false, false, nil, nil }
	if equals then
		wrapComputedEquals(node, fn, equals)
	end
	local c = curChildren
	if c then
		local n = c[1] + 1
		c[1] = n
		c[n] = node
	elseif ownExtra or curNode or curOwner then
		attachSlow(node)
	end
	@native
	local function get(): any
		local n = node
		local r = curNode
		if r then
			local i = curIdx
			if r[i] == n then
				curIdx = i + 2
				local st = n[STAMP]
				if st > liveMax and st ~= epoch then
					return memoSlow(n, false)
				end
				return n[VALUE]
			end
			if n[SEEN] ~= curRun then
				return memoSlow(n, true)
			end
		end
		local st = n[STAMP]
		if st > liveMax and st ~= epoch then
			return memoSlow(n, false)
		end
		return n[VALUE]
	end
	return get
end

@native
local function new(obj: any, isEffect: boolean?, equals: any): any
	if isNode(obj) then
		return obj
	end
	if type(obj) == "function" then
		if isEffect then
			return effect(obj)
		end
		return computed(obj, equals)
	end
	return signal(obj, equals)
end

local safe: (tryFn: () -> any, fallback: any, equals: any) -> Node<any>
do
	local function recoverSafe(
		owner: any,
		handler: (err: unknown, reset: () -> ()) -> any,
		err: unknown,
		reset: () -> ()
	): any
		local n, s, sr, pOwner, pSet, pExtra = curNode, susp, suspRun, curOwner, ownerSet, ownExtra
		curNode, susp, curChildren, curOwner, ownerSet, ownExtra = nil, nil, nil, owner, true, true
		local ok, result = pcall(handler, err, reset)
		curNode, susp, suspRun, curChildren, curOwner, ownerSet, ownExtra = n, s, sr, nil, pOwner, pSet, pExtra
		if not ok then
			error(result, 0)
		end
		return result
	end

	local function noop() end

	function safe(tryFn: () -> any, fallback: any, equals: any): Node<any>
		local retries: any = nil
		local resetFn: (() -> ())? = nil
		local destroyed = false
		return computed(function()
			local self = curNode
			local pSuspRun, pOwner, pCtx, pExtra, pEval, pFromUntrack =
				suspRun, curOwner, curCtx, ownExtra, evalNode, evalFromUntrack
			local ok, result = pcall(tryFn)
			if ok then
				return result
			end
			curNode = self
			curChildren = nil
			if
				susp ~= nil
				or ownerSet
				or curCtx ~= pCtx
				or ownExtra ~= pExtra
				or evalNode ~= pEval
				or evalFromUntrack ~= pFromUntrack
			then
				susp, suspRun, curOwner, ownerSet, curCtx, ownExtra, evalNode, evalFromUntrack =
					nil, pSuspRun, pOwner, false, pCtx, pExtra, pEval, pFromUntrack
			end
			if self and self[CHILDREN] then
				disposeChildren(self, CHILDREN, self[VALUE], false)
			end
			if type(fallback) == "function" then
				if retries == nil and not destroyed and self and self[FN] ~= nil then
					local retryNode: { any } = { 0, nil, 0, 0, 0, nil }
					retries = retryNode
					resetFn = function()
						if not destroyed then
							setSignal(retryNode, retryNode[VALUE] + 1)
						end
					end
					onDestroy(self, function()
						destroyed = true
						disposeOne(retryNode)
					end)
				end
				if retries ~= nil then
					getData(retries)
				end
				return recoverSafe(self, fallback, result, resetFn or noop)
			end
			return fallback
		end, equals)
	end
end

@native
local function isStale(node: any): boolean
	return rawget(node, 1)[STAMP] == 0 or heapMin ~= INF
end

@native
local function nodeVersion(node: any): number
	local inner = rawget(node, 1)
	local h = inner[HEIGHT]
	return if h == nil then inner[SIG_CHANGED] elseif h == INF or h == SCOPE then 0 else inner[CHANGED]
end

-- Methods every node has that sit behind `__index` in the types, so the solver only expands them on use.
--- @ignore
type Hooks = {
	--[[
	Runs `fn` when an effect starts depending on the node, either directly or through computeds. Pair it with
	`node:onUnobserved` to start and stop external work only while anything is listening.
	]]
	read onObserved: (self: any, fn: () -> ()) -> (),
	--[[
	Runs `fn` when no effect depends on the node anymore, either directly or through computeds.
	]]
	read onUnobserved: (self: any, fn: () -> ()) -> (),
}

-- A node's operators. Every member is `read` and `T` appears only in results, so nodes are covariant in `T`. A typed
-- write parameter on `__call` makes the solver stop checking the rest of a node, so calls are never write-checked.
--- @ignore
export type Operators<T> = {
	read __call: (self: any, value: any, force: boolean?) -> T,
	read __concat: (a: any, b: any) -> string,
	read __tostring: (self: any) -> string,
	read __unm: (self: any) -> number,
	read __add: (a: any, b: any) -> number,
	read __sub: (a: any, b: any) -> number,
	read __mul: (a: any, b: any) -> number,
	read __div: (a: any, b: any) -> number,
	read __idiv: (a: any, b: any) -> number,
	read __mod: (a: any, b: any) -> number,
	read __pow: (a: any, b: any) -> number,
	read __lt: (a: any, b: any) -> boolean,
	read __le: (a: any, b: any) -> boolean,
	read __index: Hooks,
}

--[[
A reactive node holding a `T` (a signal, computed, effect, or scope). Covariant in `T` so `Node<"a">` is assignable to
`Node<string>`.
]]
export type Node<T = any> = setmetatable<{
	--[[
	Reads the node's current value without subscribing the caller.

	[Open Documentation](https://flux.kohl.gg/guide/concepts/signals#reading-a-signal)
	]]
	read peek: (self: any) -> T,
	--[[
	Reads the node's current value (`node()` does the same) and subscribes the running
	[computed](https://flux.kohl.gg/guide/concepts/computeds) or [effect](https://flux.kohl.gg/guide/concepts/effects).

	[Open Documentation](https://flux.kohl.gg/guide/concepts/signals#reading-a-signal)
	]]
	read get: (self: any) -> T,
	--[[
	Writes `value` (`node(value)` does the same), skipping propagation when it equals the current value (`~=` or the
	node's `equals`). Pass `force = true` to notify dependents anyway.

	[Open Documentation](https://flux.kohl.gg/guide/concepts/signals#updating-a-signal)
	]]
	read set: (self: any, value: any, force: boolean?) -> T,
	--[[
	Notifies the node's dependents without changing its value, or updates it untracked via `fn(current)` when `fn` is provided.

	[Open Documentation](https://flux.kohl.gg/guide/concepts/signals#forcing-an-update)
	]]
	read update: <N>(self: N, fn: ((current: T) -> any)?) -> N,
	--[[
	Disconnects the node from its sources and observers, then runs its pending [`Flux.cleanup`](https://flux.kohl.gg/guide/concepts/effects#cleanup-with-flux-cleanup)
	values and `onDestroy` callbacks. Later reads return `nil`.

	[Open Documentation](https://flux.kohl.gg/guide/concepts/signals#destroying-a-signal)
	]]
	read Destroy: (self: any) -> (),
	--[[
	Registers `fn` to run with the node's last value when the node is destroyed. Unlike `Flux.cleanup`, `onDestroy`
	callbacks only run on final teardown and survive re-runs.

	[Open Documentation](https://flux.kohl.gg/guide/concepts/signals#destroying-a-signal)
	]]
	read onDestroy: (self: any, fn: (oldValue: T) -> ()) -> (),
}, Operators<T>>

--[[
A writable signal node whose `:set(value)` method is type-checked against `T`. Assignable wherever `Node<T>` or
`Reactive<T>` is expected.
]]
export type State<T = any> = setmetatable<{
	--[[
	Reads the node's current value without subscribing the caller.

	[Open Documentation](https://flux.kohl.gg/guide/concepts/signals#reading-a-signal)
	]]
	read peek: (self: any) -> T,
	--[[
	Reads the node's current value (`node()` does the same) and subscribes the running
	[computed](https://flux.kohl.gg/guide/concepts/computeds) or [effect](https://flux.kohl.gg/guide/concepts/effects).

	[Open Documentation](https://flux.kohl.gg/guide/concepts/signals#reading-a-signal)
	]]
	read get: (self: any) -> T,
	--[[
	Writes `value` (`node(value)` does the same), skipping propagation when it equals the current value (`~=` or the
	node's `equals`). Pass `force = true` to notify dependents anyway.

	[Open Documentation](https://flux.kohl.gg/guide/concepts/signals#updating-a-signal)
	]]
	read set: (self: any, value: T, force: boolean?) -> T,
	--[[
	Notifies the node's dependents without changing its value, or updates it untracked via `fn(current)` when `fn` is provided.

	[Open Documentation](https://flux.kohl.gg/guide/concepts/signals#forcing-an-update)
	]]
	read update: <N>(self: N, fn: ((current: T) -> T)?) -> N,
	--[[
	Disconnects the node from its sources and observers, then runs its pending [`Flux.cleanup`](https://flux.kohl.gg/guide/concepts/effects#cleanup-with-flux-cleanup)
	values and `onDestroy` callbacks. Later reads return `nil`.

	[Open Documentation](https://flux.kohl.gg/guide/concepts/signals#destroying-a-signal)
	]]
	read Destroy: (self: any) -> (),
	--[[
	Registers `fn` to run with the node's last value when the node is destroyed. Unlike `Flux.cleanup`, `onDestroy`
	callbacks only run on final teardown and survive re-runs.

	[Open Documentation](https://flux.kohl.gg/guide/concepts/signals#destroying-a-signal)
	]]
	read onDestroy: (self: any, fn: (oldValue: T) -> ()) -> (),
}, Operators<T>>

--[[
A plain `T`, a `Node<T>`, or a `() -> T` getter function. Read it with `Flux.read` or `Flux.raw`.

```luau
type Props = { label: Flux.Reactive<string>, disabled: Flux.Reactive<boolean>? }
local function Label(props: Props) end

local function label<A>(value: A): Flux.Node<Flux.Unwrap<A>>
	return Flux.computed(function()
		return Flux.read(value)
	end)
end
```
]]
export type Reactive<T> = T | Node<T> | (() -> T)

--[[
Extracts the underlying value type `T` from a `Node<T>`, getter `() -> T`, or plain `T` (distributing over unions).
]]
export type function Unwrap(value: type): type
	local function returned(fn: type): type
		local head = fn:returns().head
		return if head and head[1] then head[1] else types.singleton(nil)
	end

	local function nodeValue(t: type): type?
		if not t:is("table") then
			return nil
		end
		local get = t:readproperty(types.singleton("get"))
		if get and get:is("function") and t:readproperty(types.singleton("peek")) then
			return returned(get)
		end
		return nil
	end

	local function unwrap(t: type): type
		if t:is("union") then
			local parts: { type } = {}
			local function add(part: type)
				if part:is("union") then
					for _, member in part:components() do
						add(member)
					end
				elseif not table.find(parts, part) then
					table.insert(parts, part)
				end
			end
			for _, part in t:components() do
				add(unwrap(part))
			end
			return if #parts == 1 then parts[1] else types.unionof(table.unpack(parts))
		elseif t:is("intersection") then
			for _, part in t:components() do
				local found = nodeValue(part)
				if found then
					return found
				end
			end
			return t
		elseif t:is("function") then
			return returned(t)
		end
		return nodeValue(t) or t
	end

	return unwrap(value)
end

-- An owner handle from `getOwner`, for `withOwner`.
export type Owner = { any }

--- @ignore
type function NonFunction(t: type): type
	if t:is("function") then
		return types.never
	elseif t:is("union") then
		local keep = {}
		for _, c in t:components() do
			if not c:is("function") then
				table.insert(keep, c)
			end
		end
		return if #keep == 0 then types.never elseif #keep == 1 then keep[1] else types.unionof(table.unpack(keep))
	end
	return t
end

local Graph = {
	--[[
	Wraps `obj` in a reactive node: a [signal](https://flux.kohl.gg/guide/concepts/signals) for a plain value, a
	[computed](https://flux.kohl.gg/guide/concepts/computeds) for a function, or an
	[effect](https://flux.kohl.gg/guide/concepts/effects) when `isEffect` is `true` (existing nodes pass through as-is).
	]]
	new = new :: <T>(obj: T, isEffect: boolean?, equals: ((T, T: any) -> boolean)?) -> Node<T>,
	--[[
	Creates a writable [signal](https://flux.kohl.gg/guide/concepts/signals) holding `initial`, using `equals` (default
	`==`) to skip unchanged writes. Signals aren't owned by enclosing scopes and are garbage-collected once unreferenced.

	```luau
	local count = Flux.signal(0)
	count(count() + 1)
	```

	[Open Documentation](https://flux.kohl.gg/guide/concepts/signals)
	]]
	signal = signal :: <T>(initial: T, equals: ((T, T: any) -> boolean)?) -> State<T>,
	--[[
	Creates a lazily cached [computed](https://flux.kohl.gg/guide/concepts/computeds) node derived from `fn`. Re-evaluates
	only when read after a dependency changes, and runs `equals` (default `==`) untracked to keep the previous cached
	value and stop propagation when unchanged.

	```luau
	local total = Flux.computed(function()
		return price() * quantity()
	end)
	```

	[Open Documentation](https://flux.kohl.gg/guide/concepts/computeds)
	]]
	computed = computed :: <T>(fn: (prev: any) -> T, equals: ((T, T) -> boolean)?) -> Node<T>,
	--[[
	Schedules `fn` to run on the next flush and re-run whenever any node it reads changes. Owned by the enclosing scope or
	stopped manually with `node:Destroy()`.

	```luau
	Flux.effect(function() print("count is", count()) end)
	```

	[Open Documentation](https://flux.kohl.gg/guide/concepts/effects)
	]]
	effect = effect :: (fn: (...any) -> ...any) -> Node<any>,
	--[[
	Returns a plain function that reads `node` with tracking, avoiding wrapper `__call` overhead in hot loops.

	```luau
	local count = Flux.signal(0)
	local getCount = Flux.getter(count)
	Flux.effect(function()
		print(getCount())
	end)
	```
	]]
	getter = getter :: <A>(node: A) -> () -> Unwrap<A>,
	--[[
	Returns a plain function that writes `node` (`setter(value, force)`), avoiding wrapper `__call` overhead in hot loops.
	]]
	setter = setter :: <T>(node: State<T>) -> (value: T, force: boolean?) -> T,
	--[[
	Creates a lightweight signal without a node wrapper and returns `(getter, setter)`. Faster and smaller than
	`Flux.signal`, with no methods (`Destroy`, `onObserved`, etc.).

	```luau
	local count, setCount = Flux.createSignal(0)
	Flux.effect(function()
		print(count())
	end)
	setCount(count() + 1)
	```
	]]
	createSignal = createSignal,
	--[[
	Creates a lightweight computed without a node wrapper and returns its tracked getter function. Owned by the active
	scope or reaction like `Flux.computed`.

	```luau
	local count, setCount = Flux.createSignal(1)
	local doubled = Flux.createMemo(function()
		return count() * 2
	end)
	```
	]]
	createMemo = createMemo,
	--[[
	Creates a lightweight effect without returning a node wrapper. Owned by the active scope or reaction like `Flux.effect`.

	```luau
	local count, setCount = Flux.createSignal(0)
	Flux.createEffect(function()
		print("count is", count())
	end)
	```
	]]
	createEffect = createEffect,
	--[[
	Runs all queued [effects](https://flux.kohl.gg/guide/concepts/effects) immediately instead of waiting for the next frame.

	[Open Documentation](https://flux.kohl.gg/guide/tips/testing#deterministic-effects-with-flux-flush)
	]]
	flush = flush,
	-- Overloaded so a body that returns nothing type-checks: a generic `T` can't stand for an empty return.
	--[[
	Runs `fn` in a new owner [scope](https://flux.kohl.gg/guide/concepts/scopes) and returns `(scope, result)`. Calling
	`scope:Destroy()` tears down every computed, effect, instance, and `cleanup` created inside `fn`.

	```luau
	local scope, frame = Flux.scope(function() return Flux.new "Frame" { Parent = gui } end)
	scope:Destroy() -- destroys the frame and everything bound to it
	```

	[Open Documentation](https://flux.kohl.gg/guide/concepts/scopes#creating-a-scope)
	]]
	scope = scope :: ((fn: (scope: Node<any>) -> ()) -> Node<any>) & (<T>(fn: (scope: Node<any>) -> T) -> (Node<any>, T)),
	--[[
	Registers `obj` to be disposed via [`Flux.dispose`](https://flux.kohl.gg/guide/concepts/scopes#disposing-by-hand-with-flux-dispose)
	before the running reaction re-runs and when its owner is destroyed. Cleanup functions receive `(previousValue, isDestroyed)`.

	```luau
	Flux.effect(function()
		local connection = button.Activated:Connect(onClick)
		Flux.cleanup(connection)
	end)
	```

	[Open Documentation](https://flux.kohl.gg/guide/concepts/effects#cleanup-with-flux-cleanup)
	]]
	cleanup = cleanup,
	--[[
	Tears down `obj` immediately (functions, instances, connections, threads, objects with `Destroy`/`Disconnect` methods,
	or array-shaped tables traversed with cycle protection). Runs untracked and warns on error instead of throwing.

	```luau
	local connections = { part.Touched:Connect(onTouched), part.Destroying:Connect(onGone) }
	Flux.dispose(connections)
	```

	[Open Documentation](https://flux.kohl.gg/guide/concepts/scopes#disposing-by-hand-with-flux-dispose)
	]]
	dispose = dispose,
	--[[
	Returns the active reactive owner, or `nil` at the root. Pass it to [`Flux.withOwner`](https://flux.kohl.gg/guide/concepts/scopes#capturing-the-active-scope)
	to attach deferred work to the same scope.

	[Open Documentation](https://flux.kohl.gg/guide/concepts/scopes#capturing-the-active-scope)
	]]
	getOwner = getOwner,
	--[[
	Runs `fn` with `owner` (from `Flux.getOwner`, a node, or `nil` for unowned roots) as the active owner and restores its
	captured [context](https://flux.kohl.gg/guide/concepts/context#deferred-code). If `owner` is already destroyed, anything
	created inside `fn` is disposed as soon as `fn` finishes.

	[Open Documentation](https://flux.kohl.gg/guide/concepts/scopes#capturing-the-active-scope)
	]]
	withOwner = withOwner :: <T...>(node: Node<any> | Owner | nil, fn: () -> T...) -> T...,
	--[[
	Runs `fn` without dependency [tracking](https://flux.kohl.gg/guide/concepts/tracking) and returns its result. Called with
	no arguments (`Flux.untrack()`), it suspends tracking for the rest of the current reaction body or until `Flux.retrack()`.

	```luau
	Flux.effect(function()
		local id = selected() -- tracked
		local name = Flux.untrack(function() return names()[id] end) -- not tracked
	end)
	```

	[Open Documentation](https://flux.kohl.gg/guide/concepts/tracking#flux-untrack)
	]]
	untrack = untrack :: <T>(fn: (() -> ...T)?) -> ...T,
	--[[
	Resumes [tracking](https://flux.kohl.gg/guide/concepts/tracking) after a bare `Flux.untrack()` in the same function body.

	```luau
	Flux.untrack()
	local snapshot = rows()
	Flux.retrack()
	```

	[Open Documentation](https://flux.kohl.gg/guide/concepts/tracking#imperative-pairing-flux-untrack-flux-retrack)
	]]
	retrack = retrack,
	--[[
	Reads a `Reactive` value (node, getter function, or plain value) without subscribing the running reaction.

	[Open Documentation](https://flux.kohl.gg/guide/concepts/tracking#flux-raw)
	]]
	raw = raw :: <T>(object: T) -> Unwrap<T>,
	--[[
	Reads a `Reactive` value (node, getter function, or plain value) and subscribes the running reaction if it's dynamic.

	```luau
	local function Label(props: { text: Flux.Reactive<string> })
		return Flux.new "TextLabel" { Text = function() return string.upper(Flux.read(props.text)) end }
	end
	```

	[Open Documentation](https://flux.kohl.gg/guide/concepts/tracking#flux-read)
	]]
	read = read :: <T>(object: T) -> Unwrap<T>,
	--[[
	Creates a [computed](https://flux.kohl.gg/guide/concepts/computeds) that evaluates `tryFn` and returns `fallback` (a
	static value or an untracked `(err, reset) -> T` function) if `tryFn` throws. Partial child scopes and cleanups from
	`tryFn` dispose before `fallback` runs, and it recovers automatically on tracked dependency changes or `reset()`.

	[Open Documentation](https://flux.kohl.gg/guide/tips/errors#structured-error-handling-flux-safe)
	]]
	safe = safe :: (<T>(
		tryFn: () -> T,
		fallback: (err: unknown, reset: () -> ()) -> T,
		equals: ((a: T, b: T) -> boolean)?
	) -> Node<T>) & (<T>(tryFn: () -> T, fallback: NonFunction<T>, equals: ((a: T, b: T) -> boolean)?) -> Node<T>),
	--[[
	Creates a [context](https://flux.kohl.gg/guide/concepts/context) with the given `default` value for passing data down a
	component tree without prop drilling.

	```luau
	local Theme = Flux.context("dark")
	Theme:provide("light", function() return App {} end) -- App and everything it builds reads "light"
	```

	[Open Documentation](https://flux.kohl.gg/guide/concepts/context#creating-a-context)
	]]
	context = context :: <T>(default: T) -> Context<T>,
	--[[
	Wraps `fn` so every call sees the [context](https://flux.kohl.gg/guide/concepts/context#deferred-code) values active
	when `bindContext` was called. Event handlers in `Flux.new`/`Flux.edit` do this automatically.

	```luau
	local onClick = Flux.bindContext(function()
		print(ThemeContext:get()) -- the value provided where onClick was made
	end)
	```

	[Open Documentation](https://flux.kohl.gg/guide/concepts/context#deferred-code)
	]]
	bindContext = bindContext,
	--[[
	Returns `true` if `object` is a Flux [node](https://flux.kohl.gg/guide/concepts/signals).

	[Open Documentation](https://flux.kohl.gg/guide/concepts/components#_2-reading-node-or-value-props-with-flux-read)
	]]
	isNode = isNode,
	-- Internal (not on `Flux`): whether `value` is a node or a getter, a value a binding must track.
	--- @ignore
	isDynamic = isDynamic,
	--[[
	Returns `true` if called inside a tracking [computed](https://flux.kohl.gg/guide/concepts/computeds) or
	[effect](https://flux.kohl.gg/guide/concepts/effects).
	]]
	isReactive = isReactive,
	-- Internal (not on `Flux`): whether an effect node may be stale before the next flush (Selector's watcher).
	--- @ignore
	isStale = isStale,
	-- Internal (not on `Flux`): monotonic write/commit epoch of a signal or computed node.
	--- @ignore
	version = nodeVersion,
	-- Internal (not on `Flux`): whether any reaction observes a node (Selector's sweep).
	--- @ignore
	isObserved = isObserved,
	-- Internal (not on `Flux`): whether `dispose` would tear `obj` down.
	--- @ignore
	isCleanable = isCleanable,
	-- Internal (not on `Flux`): registers `teardown` as how `dispose` tears `obj` down.
	--- @ignore
	register = register,
	--- @ignore
	isolate = isolate,
	--- @ignore
	kindOf = kindOf,
	Node = table.freeze(Node),
}

return table.freeze(Graph)
