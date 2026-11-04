--!strict
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
	elseif kind == "thread" then
		if coroutine.status(obj :: thread) == "suspended" then
			protect("cleanup", task.cancel, obj :: thread)
		end
	end
end

function disposeTable(obj: any)
	local method = teardownOf(obj)
	if method ~= nil then
		method(obj)
	elseif obj[1] ~= nil then
		for _, item in obj do
			clean(item)
		end
	end
end

local function isCleanable(obj: any): boolean
	local kind = kindOf(obj)
	if kind == "table" then
		return registry[obj] ~= nil or teardownOf(obj) ~= nil or obj[1] ~= nil or next(obj) == nil
	end
	return kind == "function" or kind == "Instance" or kind == "RBXScriptConnection" or kind == "thread"
end

-- Node layout & scheduling state --------------------------------------------------------------------------------------

--- @ignore
type node = any

-- Node slots. Each kind is only as long as it needs:
-- signal:   VALUE NOBS SEEN CHANGED nil                                                  | observers from SIG_OBS0+1
-- computed: VALUE OBSERVERS SEEN CHANGED HEIGHT>=1 STAMP FN NSRC NEXT CHILDREN           | (source, back) from SRC1
-- effect:   false E_NSRC E_FN E_CHILDREN HEIGHT=INF STAMP                                | (source, back) from E_SRC1
-- scope:    HEIGHT=SCOPE, STAMP=INF, FN, CHILDREN
local VALUE = 1
local OBSERVERS = 2 -- computed: false, its one live observer, or a list of 2+ (see subscribe). signal: the count of its inline observers
local SEEN = 3 -- run id of the last run that stamped this node as read (dedupes repeated reads)
local CHANGED = 4 -- epoch of the last value change
local HEIGHT = 5 -- nil for signals, >= 1 for computeds, INF for effects, SCOPE for scopes
local STAMP = 6 -- 0 when dirty, DEFERRED when deferred, STALE/ERRORED on error, LIVE_BASE+h when live, epoch when dead, INF for clean effect/scope
local FN = 7 -- nil once disposed
local NSRC = 8 -- next source slot past the end of source pairs
local NEXT = 9 -- intrusive heap link: false when not queued, else the next node in its bucket or true
local CHILDREN = 10 -- owned nodes (cleanups under `fns`); false, or nil once a reader has dropped this computed
local SRC1 = 11
local SIG_OBS0 = 5

local E_NSRC = 2
local E_FN = 3 -- false once disposed (in SEEN's slot: an effect is never tracked as a source)
local E_CHILDREN = 4
local E_SRC1 = 7

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

local heap: { any } = table.create(64, false)
local heapMin = INF
local liveMax = LIVE_MAX_IDLE
local heapMax = 0

local queue: { any } = {}
local queueHead = 1
local queueTail = 0
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
local DIVERGED = 5
local DISPOSED_NSRC = 2 ^ 30
local curRun = 0
local runId = 0

local curOwner: any = nil
local ownerSet = false

local susp: any = nil
local suspRun = 0

local evalNode: any = nil
local runningEffect: any = nil

--- @ignore
type ContextFrame = { parent: ContextFrame?, key: any, value: any }
local curCtx: ContextFrame? = nil

local anyHooks = false
local anyDestroys = false
local anyCleanups = false
local anySigEquals = false
local ownExtra = false

local function isReactive(): boolean
	return curNode ~= nil
end

local function isObserved(node: any): boolean
	local inner = node[1]
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

local function readDiverged(r: any, s: any): boolean
	local base = if r[HEIGHT] == INF then E_SRC1 else SRC1
	local new = curNew
	for i = base, new[1] - 2, 2 do
		if r[i] == s then
			return true
		end
	end
	for i = 3, new[2] do
		if new[i] == s then
			return true
		end
	end
	return false
end

local function readThisRun(r: any, s: any): boolean
	if s[SEEN] == curRun then
		return true
	end
	if curIdx == DIVERGED then
		return readDiverged(r, s)
	end
	local base = if r[HEIGHT] == INF then E_SRC1 else SRC1
	for i = base, curIdx - 2, 2 do
		if r[i] == s then
			return true
		end
	end
	return false
end

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

local function deferSelf(e: any, s: any)
	if curNode == nil and not readThisRun(e, s) then
		return
	end
	selfWritten = e
end

local function markObservers(sig: any, n: number)
	local r = curNode
	for i = 6, n + SIG_OBS0 do
		local o = sig[i]
		if o ~= r then
			if o == runningEffect then
				deferSelf(o, sig)
			else
				markOne(o)
			end
		end
	end
end

local function markList(node: any, obs: any)
	local r = curNode
	if type(obs[HEIGHT]) == "number" then
		if obs ~= r then
			if obs == runningEffect then
				deferSelf(obs, node)
			else
				markOne(obs)
			end
		end
		return
	end
	for i = 2, obs[1] do
		local o = obs[i]
		if o ~= r then
			if o == runningEffect then
				deferSelf(o, node)
			else
				markOne(o)
			end
		end
	end
end

local function markSelf(node: any)
	local r = curNode
	if r and readThisRun(r, node) then
		if r[HEIGHT] == INF then
			selfWritten = r
		else
			markOne(r)
		end
	end
end

local function raise(node: any, h: number)
	node[HEIGHT] = h
	if node[STAMP] <= LIVE_MAX_IDLE then
		node[STAMP] = h + LIVE_BASE
	end
	local obs = node[OBSERVERS]
	if obs then
		local oh = obs[HEIGHT]
		if type(oh) == "number" then
			if oh <= h then
				raise(obs, h + 1)
			end
			return
		end
		for i = 2, obs[1] do
			local o = obs[i]
			if o[HEIGHT] <= h then
				raise(o, h + 1)
			end
		end
	end
end

local function fireHook(n: any, which: number)
	local h = n.hooks
	local f = h and h[which]
	if f then
		protect(if which == 1 then "onObserved" else "onUnobserved", f)
	end
end

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

local goLive: (any, any) -> ()
local goDead: (any) -> ()

local function subscribe(s: any, o: any): number
	local sh = s[HEIGHT]
	if not sh then
		local n0 = s[OBSERVERS]
		if n0 == nil then
			return 0
		end
		local n = n0 + 1
		s[OBSERVERS] = n
		s[n + SIG_OBS0] = o
		if anyHooks and n == 1 then
			fireHook(s, 1)
		end
		return n
	end
	local list = s[OBSERVERS]
	local n
	if list == nil then
		return 0
	elseif not list then
		n = 2
		goLive(s, o)
		sh = s[HEIGHT]
	elseif type(list[HEIGHT]) == "number" then
		s[OBSERVERS] = { 3, list, o }
		n = 3
	else
		n = list[1] + 1
		list[1] = n
		list[n] = o
	end
	if sh >= o[HEIGHT] then
		if o[OBSERVERS] then
			raise(o, sh + 1)
		else
			o[HEIGHT] = sh + 1
		end
	end
	return n
end

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
		if anyHooks and n == 1 then
			fireHook(s, 2)
		end
		return
	end
	local list = s[OBSERVERS]
	if list == o then
		s[OBSERVERS] = false
		goDead(s)
		return
	elseif not list or type(list[HEIGHT]) == "number" then
		return
	end
	local n = list[1]
	if j ~= n then
		local moved = list[n]
		list[j] = moved
		fixBack(moved, s, n, j)
	end
	list[n] = nil
	if n == 2 then
		s[OBSERVERS] = false
		goDead(s)
	else
		list[1] = n - 1
	end
end

function goLive(node: any, o: any)
	if anyHooks then
		node[OBSERVERS] = o
	end
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
				if anyHooks and n == 1 then
					fireHook(s, 1)
				end
			else
				node[i + 1] = 0
			end
		else
			node[i + 1] = subscribe(s, node)
		end
	end
	node[OBSERVERS] = o
	local st = node[STAMP]
	if st == epoch then
		node[STAMP] = node[HEIGHT] + LIVE_BASE
	elseif st ~= STALE and st ~= ERRORED then
		local dirty = st == 0 or st == DEFERRED
		if not dirty then
			for i = SRC1, last, 2 do
				local c = node[i][CHANGED]
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
	if anyHooks then
		fireHook(node, 1)
	end
end

function goDead(node: any)
	for i = node[NSRC] - 2, SRC1, -2 do
		local s, j = node[i], node[i + 1]
		local obs = s[OBSERVERS]
		if obs == j and not anyHooks then
			s[j + SIG_OBS0] = nil
			s[OBSERVERS] = j - 1
		elseif obs == node then
			s[OBSERVERS] = false
			goDead(s)
		else
			unsubscribe(s, node, j)
		end
	end
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
	if anyHooks then
		fireHook(node, 2)
	end
end

local function reconcile(node: any, nslot: number, last: number, idx: number, newList: any, live: boolean)
	if not newList then
		if idx > last then
			if live then
				for i = last, idx - 2, 2 do
					node[i + 1] = subscribe(node[i], node)
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
		node[idx], node[idx + 1] = s, subscribe(s, node)
		unsubscribe(oldS, node, oldBack)
		if oldS[CHILDREN] == false then
			oldS[CHILDREN] = nil
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
		newList[i], node[k] = nil, s
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
				back = subscribe(s, node)
				if prevJ == 1 then
					prevJ = -1
				end
			end
		end
		node[k + 1] = back
		k += 2
	end
	freeNew, node[nslot] = newList, k
	for i = k, last - 1 do
		node[i] = nil
	end
	for j = nOld - 1, 1, -2 do
		local s = tail[j]
		if s then
			tail[j] = false
			unsubscribe(s, node, tail[j + 1])
			if s[CHILDREN] == false then
				s[CHILDREN] = nil
			end
		end
	end
	tailBusy = wasBusy
end

local TOMB = {}

local function removeSource(o: any, src: any)
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

local function runProtected(callbacks: { any }, oldValue: any, destroyed: boolean, kind: string)
	local pNode, pSusp, pOwner, pSet, pIndex = curNode, susp, curOwner, ownerSet, callbackIndex
	local pSuspRun = suspRun
	curNode, susp = nil, nil
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
	curNode, susp, curOwner, ownerSet, callbackIndex = pNode, pSusp, pOwner, pSet, pIndex
	suspRun = pSuspRun
end

local disposeOne: (any) -> ()

local function disposeChildren(owner: any, slot: number, value: any, destroyed: boolean)
	local c = owner[slot]
	owner[slot] = false
	if not anyDestroys and not anyHooks then
		for k = c[1], 2, -1 do
			local node = c[k]
			if not node[OBSERVERS] then
				if not node[CHILDREN] and node[FN] then
					node[FN] = nil
					node[NSRC] = DISPOSED_NSRC
					node[STAMP] = LIVE_MAX_IDLE
					node[VALUE] = nil
					node[OBSERVERS] = nil
				else
					disposeOne(node)
				end
			elseif node[HEIGHT] == INF and node[E_FN] then
				node[E_FN] = nil
				node[STAMP] = INF
				if node[E_CHILDREN] then
					disposeChildren(node, E_CHILDREN, nil, true)
				end
				for i = node[E_NSRC] - 2, E_SRC1, -2 do
					local s, j = node[i], node[i + 1]
					local obs = s[OBSERVERS]
					if obs == j then
						s[j + SIG_OBS0] = nil
						s[OBSERVERS] = j - 1
					elseif obs == node then
						s[OBSERVERS] = false
						goDead(s)
					else
						unsubscribe(s, node, j)
					end
				end
				node[E_NSRC] = DISPOSED_NSRC
			else
				disposeOne(node)
			end
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

function disposeOne(node: any)
	local h = node[HEIGHT]
	if h == nil then
		local n = node[OBSERVERS]
		if n == nil then
			return
		end
		for i = 6, n + SIG_OBS0 do
			removeSource(node[i], node)
		end
		local destroys = anyDestroys and node.destroys
		local value = node[VALUE]
		local owned = node.owned
		if owned then
			node.owned = nil
			disposeChildren({ owned }, 1, value, true)
		end
		table.clear(node)
		if destroys then
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
		if node[E_CHILDREN] then
			disposeChildren(node, E_CHILDREN, nil, true)
		end
		for i = node[E_NSRC] - 2, E_SRC1, -2 do
			unsubscribe(node[i], node, node[i + 1])
		end
		node[E_NSRC] = DISPOSED_NSRC
	elseif h == SCOPE then
		if node[FN] == false then
			return
		end
		node[FN] = false
		if node[CHILDREN] then
			disposeChildren(node, CHILDREN, nil, true)
		end
	else
		if node[FN] == nil then
			return
		end
		node[FN] = nil
		node[STAMP] = LIVE_MAX_IDLE
		value = node[VALUE]
		if node[CHILDREN] then
			disposeChildren(node, CHILDREN, value, true)
		end
		local obs = node[OBSERVERS]
		if obs then
			if type(obs[HEIGHT]) == "number" then
				removeSource(obs, node)
			else
				for i = 2, obs[1] do
					removeSource(obs[i], node)
				end
			end
			node[OBSERVERS] = false
			for i = node[NSRC] - 2, SRC1, -2 do
				unsubscribe(node[i], node, node[i + 1])
			end
			if anyHooks then
				fireHook(node, 2)
			end
		end
		node[NSRC] = DISPOSED_NSRC
		node[VALUE] = nil
		node[OBSERVERS] = nil
	end
	if anyDestroys then
		local destroys = node.destroys
		if destroys then
			runProtected(destroys, value, true, "onDestroy")
		end
	end
end

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

local function notifyObservers(obs: any, node: any)
	local r, e, x = curNode, evalNode, runningEffect
	if type(obs[HEIGHT]) == "number" then
		if obs ~= r and obs ~= e then
			if obs ~= x then
				markOne(obs)
			else
				deferSelf(obs, node)
			end
		end
	else
		for i = 2, obs[1] do
			local o = obs[i]
			if o ~= r and o ~= e then
				if o ~= x then
					markOne(o)
				else
					deferSelf(o, node)
				end
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
				reconcile(node, E_NSRC, last, idx, newList, true)
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
		reconcile(node, NSRC, last, idx, newList, live)
	end
	node.err = err
	node[STAMP] = if node[OBSERVERS] then ERRORED else STALE
	markChanged(node)
	if not failed[node] then
		nFailed += 1
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
	return at == node[CHANGED]
end

local function healed(node: any)
	markChanged(node)
	node[STAMP] = epoch
end

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
	do
		local rid = runId + 1
		runId, curRun = rid, rid
	end
	curNode, curIdx, curNew = node, SRC1, nil
	local old = node[VALUE]
	local new = node[FN](old)
	local idx, newList = curIdx, curNew
	curNode, curIdx, curNew, curRun, evalNode = pNode, pIdx, pNew, pRun, pEval
	if hadExtra then
		susp, suspRun, curCtx, ownerSet = pSusp, pSuspRun, pCtx, pSet
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
	if new ~= old then
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

local function settle(node: any)
	for i = SRC1, node[NSRC] - 2, 2 do
		local s = node[i]
		local h = s[HEIGHT]
		if h and h >= heapMin then
			local st = s[STAMP]
			if st > liveMax and st ~= epoch and st ~= STALE and st ~= ERRORED then
				local pNode = curNode
				curNode = nil
				settle(s)
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

local refresh: (any) -> ()

local function pullDead(node: any)
	local stamp = node[STAMP]
	local dirty = stamp <= 0
	if not dirty then
		for i = SRC1, node[NSRC] - 2, 2 do
			local s = node[i]
			local st = s[STAMP]
			if st == STALE then
				local pNode = curNode
				curNode = nil
				refresh(s)
				curNode = pNode
				dirty = true
				break
			elseif s[HEIGHT] and st > liveMax and st ~= epoch and st ~= ERRORED then
				local pNode = curNode
				curNode = nil
				refresh(s)
				curNode = pNode
			end
			local c = s[CHANGED]
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

function refresh(node: any)
	if node[OBSERVERS] then
		local st = node[STAMP]
		if st == DEFERRED then
			if node[CHILDREN] == nil then
				node[CHILDREN] = false
			end
			runComputed(node)
		elseif st >= ERRORED or node[HEIGHT] > heapMin then
			settle(node)
		else
			node[STAMP] = node[HEIGHT] + LIVE_BASE
		end
	elseif node[FN] then
		pullDead(node)
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
	do
		local rid = runId + 1
		runId, curRun = rid, rid
	end
	curNode, curIdx, curNew = node, SRC1, nil
	local old = node[VALUE]
	local ok, new = pcall(node[FN], old)
	local idx, newList = curIdx, curNew
	curNode, curIdx, curNew, curRun, evalNode = pNode, pIdx, pNew, pRun, pEval
	if hadExtra then
		susp, suspRun, curCtx, curOwner, ownerSet, runningEffect = pSusp, pSuspRun, pCtx, pOwner, pSet, pRunning
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
	if new ~= old then
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
	local pNode, pIdx, pNew, pRun, pEval, pRunning = curNode, curIdx, curNew, curRun, evalNode, runningEffect
	local hadExtra = ownExtra
	local pCtx, pSusp, pSuspRun, pOwner, pSet
	if hadExtra then
		pCtx, pSusp, pSuspRun, pOwner, pSet = curCtx, susp, suspRun, curOwner, ownerSet
	end
	local ok, err = pcall(f, node)
	if not ok then
		local e, idx, new = evalNode, curIdx, curNew
		curNode, curIdx, curNew, curRun, evalNode, runningEffect = pNode, pIdx, pNew, pRun, pEval, pRunning
		if hadExtra then
			curCtx, susp, suspRun, curOwner, ownerSet = pCtx, pSusp, pSuspRun, pOwner, pSet
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
		if live and curNode == nil then
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
				if sst == STALE or (s[HEIGHT] and sst > liveMax and sst ~= epoch and sst ~= ERRORED) then
					guarded(pullDead, node, 1)
					return
				end
				local c = s[CHANGED]
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

local function requeue(e: any)
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
	local pNode, pIdx, pNew, pRun, pEval, pSusp, pCtx = curNode, curIdx, curNew, curRun, evalNode, susp, curCtx
	local pSuspRun = suspRun
	local pSet, pExtra = ownerSet, ownExtra
	susp, ownerSet = nil, false
	if e[E_CHILDREN] then
		disposeChildren(e, E_CHILDREN, nil, false)
	end
	e[STAMP] = INF
	evalNode = e
	runId += 1
	local pRunning, pSelf = runningEffect, selfWritten
	runningEffect, selfWritten = e, nil
	curNode, curIdx, curNew, curRun = e, E_SRC1, nil, runId
	e[E_FN]()
	runningEffect = pRunning
	if selfWritten == e then
		selfWritten = pSelf
		requeue(e)
	elseif selfWritten == nil then
		selfWritten = pSelf
	end
	if e[E_FN] then
		local idx = curIdx
		local last = e[E_NSRC]
		if idx ~= last then
			local newList = curNew
			if newList then
				idx = newList[1]
			end
			reconcile(e, E_NSRC, last, idx, newList, true)
		end
	end
	curNode, curIdx, curNew, curRun, evalNode, susp, curCtx = pNode, pIdx, pNew, pRun, pEval, pSusp, pCtx
	suspRun = pSuspRun
	ownerSet, ownExtra = pSet, pExtra
	if not e[E_FN] then
		reap(e)
	end
end

local function stabilize()
	local hp, q = heap, queue
	curNew = nil
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
									local list = type(obs[HEIGHT]) ~= "number"
									local o1 = if list then obs[2] else obs
									local st1 = o1[STAMP]
									if (st1 == 0 or st1 == DEFERRED) and o1[HEIGHT] ~= INF then
										local defer = true
										if list then
											for i = 3, obs[1] do
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
							do
								local rid = runId + 1
								runId, curRun = rid, rid
							end
							curNode, curIdx = node, SRC1
							local old = node[VALUE]
							local new = node[FN](old)
							local idx = curIdx
							local last = node[NSRC]
							if idx ~= last then
								if not node[FN] then
									curNew = nil
									curNode, evalNode = nil, nil
									if susp then
										susp = nil
										ownExtra = curCtx ~= nil
									end
									node[VALUE] = nil
									reap(node)
									break
								end
								local newList = curNew
								if newList then
									idx = newList[1]
									curNew = nil
								end
								local live = node[OBSERVERS] ~= false
								reconcile(node, NSRC, last, idx, newList, live)
								if node[STAMP] ~= 0 then
									node[STAMP] = if live then node[HEIGHT] + LIVE_BASE else epoch
								end
							end
							if new ~= old then
								node[VALUE] = new
								node[CHANGED] = epoch
								local oh = obs[HEIGHT]
								if type(oh) == "number" then
									local o = obs
									if o[STAMP] ~= 0 then
										if oh == INF then
											o[STAMP] = 0
											local qt = queueTail + 1
											queueTail = qt
											q[qt] = o
										elseif oh <= heapMin and o[CHILDREN] ~= nil then
											h = oh
											if not hp[oh] then
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
									for i = 2, obs[1] do
										local o = obs[i]
										if o[STAMP] ~= 0 then
											o[STAMP] = 0
											local oHeight = o[HEIGHT]
											if oHeight == INF then
												qt += 1
												q[qt] = o
											elseif not o[NEXT] then
												o[NEXT] = hp[oHeight] or true
												hp[oHeight] = o
												if oHeight > hMax then
													hMax = oHeight
												end
											end
										end
									end
									queueTail, heapMax = qt, hMax
								end
							elseif nFailed > 0 and unfail(node) then
								healed(node)
							end
							break
						end
					end
				end
				if heapMin ~= h then
					break
				end
				node = hp[h]
			until false
			h = heapMin
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
	local function guard(tail: number)
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

	local function drain()
		while true do
			if heapMin ~= INF then
				stabilize()
			end
			local tail = queueTail
			if queueHead > tail then
				break
			end
			passes += 1
			if passes > GUARD_PASSES then
				guard(tail)
			end
			curNew = nil
			local q = queue
			for i = queueHead, tail do
				local e = q[i]
				q[i] = nil
				queueHead = i + 1
				if e[STAMP] == 0 then
					local fn: (() -> ())? = e[E_FN]
					if fn then
						if e[E_CHILDREN] then
							disposeChildren(e, E_CHILDREN, nil, false)
						end
						e[STAMP] = INF
						do
							local rid = runId + 1
							runId, curRun = rid, rid
						end
						runningEffect, curNode, curIdx = e, e, E_SRC1
						fn()
						runningEffect = nil
						local idx = curIdx
						if selfWritten == e then
							selfWritten = nil
							requeue(e)
						end
						local last = e[E_NSRC]
						if idx ~= last then
							if idx > last then
								for j = last, idx - 2, 2 do
									local s = e[j]
									if not s[HEIGHT] then
										local n = s[OBSERVERS] + 1
										s[OBSERVERS] = n
										s[n + SIG_OBS0] = e
										e[j + 1] = n
										if anyHooks and n == 1 then
											fireHook(s, 1)
										end
									else
										e[j + 1] = subscribe(s, e)
									end
								end
								e[E_NSRC] = idx
							elseif e[E_FN] then
								local newList = curNew
								if newList then
									idx = newList[1]
									curNew = nil
								end
								reconcile(e, E_NSRC, last, idx, newList, true)
							else
								curNew = nil
								curNode, evalNode = nil, nil
								reap(e)
							end
						end
					end
					if heapMin ~= INF then
						break
					end
				end
			end
			curNode = nil
			if queueHead > queueTail then
				if queueTail > 4096 then
					queue = {}
				end
				queueHead, queueTail = 1, 0
				counted = 0
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
			curNode, evalNode, susp, rawError, curCtx = nil, nil, nil, nil, pCtx
			ownExtra = pExtra == true
			runningEffect = nil
			if e then
				finishErrored(e, curIdx, curNew, raw)
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

	function flush()
		if flushing or (heapMin == INF and queueHead > queueTail) then
			return
		end
		flushing = true
		if curNode == nil and not ownExtra then
			local ok, err = (xpcall :: (any, any) -> (boolean, any))(drain, drainTraceback)
			if not ok then
				recover(err)
			end
			if anyReruns then
				table.clear(reruns)
				table.clear(cycles)
				anyReruns = false
			end
			passes = 0
			curNode, evalNode = nil, nil
			if susp then
				susp = nil
				ownExtra = curCtx ~= nil
			end
			flushing = false
			return
		end
		local pNode, pIdx, pNew, pRun, pCtx, pEval, pSusp = curNode, curIdx, curNew, curRun, curCtx, evalNode, susp
		local pSuspRun = suspRun
		local pSet, pExtra = ownerSet, ownExtra
		curNode, evalNode, susp, ownerSet = nil, nil, nil, false
		local ok, err = (xpcall :: (any, any) -> (boolean, any))(drain, drainTraceback)
		if not ok then
			recover(err, pCtx, pExtra)
		end
		if anyReruns then
			table.clear(reruns)
			table.clear(cycles)
			anyReruns = false
		end
		passes = 0
		curNode, curIdx, curNew, curRun, curCtx, evalNode, susp = pNode, pIdx, pNew, pRun, pCtx, pEval, pSusp
		suspRun = pSuspRun
		ownerSet, ownExtra = pSet, pExtra
		flushing = false
	end
end

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
				curCtx, ownExtra = p, pExtra
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

local function track(node: any)
	local r = curNode
	if node[OBSERVERS] == nil or node == r then
		return
	end
	local run = curRun
	local new = curNew
	if new then
		node[SEEN] = run
		local n = new[2] + 1
		new[2] = n
		new[n] = node
		return
	end
	local idx = curIdx
	local old = r[idx]
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
			if old == nil then
				r[idx] = false
				r[idx] = nil
			end
			return
		end
	end
	node[SEEN] = run
	if old == nil then
		r[idx] = node
		r[idx + 1] = 0
		local nextIdx = idx + 2
		curIdx = nextIdx
		stampedTo = nextIdx
	else
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
end

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

local function getMemo(node: any): any
	local r = curNode
	if r then
		local i = curIdx
		if r[i] == node then
			curIdx = i + 2
		elseif node[SEEN] ~= curRun then
			track(node)
		end
	end
	local st = node[STAMP]
	if st > liveMax and st ~= epoch then
		pull(node)
	end
	return node[VALUE]
end

local function peekData(node: any): any
	local h = node[HEIGHT]
	if h then
		return pullValue(node, h)
	end
	return node[VALUE]
end

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
	if curNode then
		markSelf(node)
	end
end

local function setSignal(node: any, value: any, force: boolean?): any
	if not anySigEquals then
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
	node[CHANGED] = ep
	local r = curNode
	if n > 0 then
		if n == 1 then
			local o = node[6]
			if o[STAMP] ~= 0 and o ~= r then
				local h = o[HEIGHT]
				if h == INF then
					if o == runningEffect then
						deferSelf(o, node)
					else
						o[STAMP] = 0
						local qt = queueTail + 1
						queueTail = qt
						queue[qt] = o
					end
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
			local re = runningEffect
			local hp = heap
			local q = queue
			local qt = queueTail
			local hMin = heapMin
			local hMax = heapMax
			for i = 6, n + SIG_OBS0 do
				local o = node[i]
				if o[STAMP] ~= 0 and o ~= r then
					local h = o[HEIGHT]
					if h == INF then
						if o == re then
							deferSelf(o, node)
						else
							o[STAMP] = 0
							qt += 1
							q[qt] = o
						end
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
	if r then
		markSelf(node)
	end
	return value
end

local function setData(node: any, value: any, force: boolean?): any
	local h = node[HEIGHT]
	if h == nil then
		return setSignal(node, value, force)
	elseif h ~= INF and h ~= SCOPE then
		writeComputed(node, value, force)
	end
	return value
end

local function updateNode(node: any)
	local h = node[HEIGHT]
	if h == nil then
		local n = node[OBSERVERS]
		if n == nil then
			return
		end
		epoch += 1
		node[CHANGED] = epoch
		if n > 0 then
			markObservers(node, n)
		end
		if curNode then
			markSelf(node)
		end
	elseif h ~= INF and h ~= SCOPE and node[FN] then
		epoch += 1
		node[CHANGED] = epoch
		local obs = node[OBSERVERS]
		node[STAMP] = if obs and h <= heapMin then h + LIVE_BASE else epoch
		if obs then
			markList(node, obs)
		end
		if curNode then
			markSelf(node)
		end
	end
end

local function onDestroy(node: node, fn: (oldValue: any) -> ())
	anyDestroys = true
	local destroys = node.destroys
	if destroys then
		table.insert(destroys, fn)
	else
		node.destroys = { fn }
	end
end

local function onHook(node: node, which: number, fn: () -> ())
	local h = node.hooks
	if not h then
		h = {}
		node.hooks = h
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
	anyHooks = true
end

local Node: any = {
	__call = function(self: any, value: any?, force: boolean?): any
		local node = self[1]
		if value == nil and not force then
			return getData(node)
		end
		return setData(node, value, force)
	end,
	--stylua: ignore start
	__tostring = function(a: any): string return tostring(getData(a[1])) end,
	__unm = function(a: any): number return -getData(a[1]) end,
	__lt = function(a: any, b: any): boolean return getData(a[1]) < getData(b[1]) end,
	__le = function(a: any, b: any): boolean return getData(a[1]) <= getData(b[1]) end,
	--stylua: ignore end
	--[[
	Reads the node's current value without subscribing the caller.

	[Open Documentation](https://flux.kohl.gg/guide/concepts/signals#reading-a-signal)
	]]
	peek = function(self: any): any
		return peekData(self[1])
	end,
	--[[
	Reads the node's current value (`node()` does the same) and subscribes the running
	[computed](https://flux.kohl.gg/guide/concepts/computeds) or [effect](https://flux.kohl.gg/guide/concepts/effects).

	[Open Documentation](https://flux.kohl.gg/guide/concepts/signals#reading-a-signal)
	]]
	get = function(self: any): any
		return getData(self[1])
	end,
	--[[
	Writes `value` (`node(value)` does the same), skipping propagation when it equals the current value (`~=` or the
	node's `equals`). Pass `force = true` to notify dependents anyway.

	[Open Documentation](https://flux.kohl.gg/guide/concepts/signals#updating-a-signal)
	]]
	set = function(self: any, value: any, force: boolean?): any
		return setData(self[1], value, force)
	end,
	--[[
	Notifies the node's dependents without changing its value, useful after mutating a table in place.

	[Open Documentation](https://flux.kohl.gg/guide/concepts/signals#forcing-an-update)
	]]
	update = function(self: any): any
		updateNode(self[1])
		return self
	end,
	--[[
	Disconnects the node from its sources and observers, then runs its pending [`Flux.cleanup`](https://flux.kohl.gg/guide/concepts/effects#cleanup-with-flux-cleanup)
	values and `onDestroy` callbacks. Later reads return `nil`.

	[Open Documentation](https://flux.kohl.gg/guide/concepts/signals#destroying-a-signal)
	]]
	Destroy = function(self: any)
		disposeOne(self[1])
	end,
	--[[
	Registers `fn` to run with the node's last value when the node is destroyed. Unlike `Flux.cleanup`, `onDestroy`
	callbacks only run on final teardown and survive re-runs.

	[Open Documentation](https://flux.kohl.gg/guide/concepts/signals#destroying-a-signal)
	]]
	onDestroy = function(self: any, fn: (oldValue: any) -> ())
		onDestroy(self[1], fn)
	end,
	--[[
	Registers `fn` to run when the node gains its first transitive effect observer. Pair with `onUnobserved` to start
	and stop external listeners on demand.
	]]
	onObserved = function(self: any, fn: () -> ())
		onHook(self[1], 1, fn)
	end,
	--[[
	Registers `fn` to run when the node loses its last transitive effect observer.
	]]
	onUnobserved = function(self: any, fn: () -> ())
		onHook(self[1], 2, fn)
	end,
}
Node.__type = Node
Node.__index = Node

do
	local function data(a: any): any
		local mt = getmetatable(a)
		return if mt ~= nil and type(mt) == "table" and mt.__type == Node then getData(a[1]) else a
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

local SignalMT: any = {
	__call = function(self: any, value: any?, force: boolean?): any
		local node = self[1]
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
	end,
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
	peek = function(self: any): any
		return self[1][VALUE]
	end,
	get = function(self: any): any
		local node = self[1]
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
	end,
	set = function(self: any, value: any, force: boolean?): any
		return setSignal(self[1], value, force)
	end,
	update = Node.update,
	Destroy = Node.Destroy,
	onDestroy = Node.onDestroy,
	onObserved = Node.onObserved,
	onUnobserved = Node.onUnobserved,
}

local ComputedMT: any = {
	__call = function(self: any, value: any?, force: boolean?): any
		local node = self[1]
		if value == nil and not force then
			local r = curNode
			if r then
				local i = curIdx
				if r[i] == node then
					curIdx = i + 2
					local st = node[STAMP]
					if st > liveMax and st ~= epoch then
						pull(node)
					end
					return node[VALUE]
				elseif node[SEEN] ~= curRun then
					track(node)
				end
			end
			local st = node[STAMP]
			if st > liveMax and st ~= epoch then
				pull(node)
			end
			return node[VALUE]
		end
		writeComputed(node, value, force)
		return value
	end,
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
	peek = function(self: any): any
		local node = self[1]
		local st = node[STAMP]
		if st > liveMax and st ~= epoch then
			pull(node)
		end
		return node[VALUE]
	end,
	get = function(self: any): any
		local node = self[1]
		local r = curNode
		if r then
			local i = curIdx
			if r[i] == node then
				curIdx = i + 2
				local st = node[STAMP]
				if st > liveMax and st ~= epoch then
					pull(node)
				end
				return node[VALUE]
			elseif node[SEEN] ~= curRun then
				track(node)
			end
		end
		local st = node[STAMP]
		if st > liveMax and st ~= epoch then
			pull(node)
		end
		return node[VALUE]
	end,
	set = function(self: any, value: any, force: boolean?): any
		writeComputed(self[1], value, force)
		return value
	end,
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

local function isNode(object: any): boolean
	local mt = getmetatable(object)
	return mt ~= nil
		and (mt == SignalMT or mt == ComputedMT or mt == Node or (type(mt) == "table" and mt.__type == Node))
end

local function isDynamic(object: any): boolean
	return type(object) == "function" or isNode(object)
end

local function raw(object: any): any
	local mt = getmetatable(object)
	if mt ~= nil then
		if mt == SignalMT then
			return object[1][VALUE]
		elseif mt == ComputedMT then
			local node = object[1]
			local st = node[STAMP]
			if st > liveMax and st ~= epoch then
				pull(node)
			end
			return node[VALUE]
		elseif mt == Node or (type(mt) == "table" and mt.__type == Node) then
			return peekData(object[1])
		end
		return object
	elseif type(object) == "function" then
		local n, s = curNode, susp
		if n == nil and s == nil then
			return (object :: () -> any)()
		end
		local pSuspRun = suspRun
		curNode, susp = nil, nil
		local ok, result = pcall(object)
		curNode, susp = n, s
		suspRun = pSuspRun
		if not ok then
			error(result, 0)
		end
		return result
	end
	return object
end

local function read(object: any): any
	local mt = getmetatable(object)
	if mt ~= nil then
		if mt == SignalMT then
			return getSignal(object[1])
		elseif mt == ComputedMT then
			return getMemo(object[1])
		elseif mt == Node or (type(mt) == "table" and mt.__type == Node) then
			return getData(object[1])
		end
		return object
	elseif type(object) == "function" then
		return (object :: () -> any)()
	end
	return object
end

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

local function getOwner(): Owner?
	return currentOwner()
end

local function isDisposed(o: any): boolean
	local h = o[HEIGHT]
	if h == nil then
		return o[OBSERVERS] == nil
	end
	return not o[if h == INF then E_FN else FN]
end

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
	curOwner, ownerSet, susp, curCtx, ownExtra = pOwner, pSet, pSusp, pCtx, pExtra
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

local function withOwner(node: any, fn: () -> ...any): ...any
	local owner: node? = if node == nil then nil elseif isNode(node) then node[1] else node
	local pOwner, pSet, pSusp, pCtx, pExtra = curOwner, ownerSet, susp, curCtx, ownExtra
	local pSuspRun = suspRun
	local root = nil
	if owner then
		curCtx = owner.ctx or pCtx
		if isDisposed(owner) then
			root = { nil, true, false, false, SCOPE, INF, true, false, false, false } :: node
			owner = root
		end
	end
	curOwner, ownerSet, susp, ownExtra = owner, true, nil, true
	return finishWithOwner(owner, root, pOwner, pSet, pSusp, pCtx, pExtra, pSuspRun, xpcall(fn, traceback))
end

local function finishUntrack(
	n: any,
	pSusp: any,
	pOwner: any,
	pSet: boolean,
	pExtra: boolean,
	pSuspRun: number,
	ok: boolean,
	...: any
): ...any
	curNode, susp, curOwner, ownerSet, ownExtra = n, pSusp, pOwner, pSet, pExtra
	suspRun = pSuspRun
	if not ok then
		local err = ...
		error(if type(err) == "string" then `error while running untrack():\n{err}` else err, 0)
	end
	return ...
end

local function untrack(fn: (() -> ...any)?): ...any
	local n = curNode
	if not fn then
		if n then
			susp, suspRun = n, curRun
			curNode = nil
			ownExtra = true
		end
		return
	end
	local pSusp, pOwner, pSet, pExtra = susp, curOwner, ownerSet, ownExtra
	local pSuspRun = suspRun
	curNode, susp = nil, nil
	if n and not ownerSet then
		curOwner, ownerSet, ownExtra = n, true, true
	end
	return finishUntrack(n, pSusp, pOwner, pSet, pExtra, pSuspRun, xpcall(fn, traceback))
end

local function retrack()
	if curNode == nil and susp and suspRun == curRun then
		curNode = susp
		susp = nil
		ownExtra = curCtx ~= nil or ownerSet
	end
end

local function dispose(obj: Cleanable?)
	local n, pSusp = curNode, susp
	local pSuspRun = suspRun
	curNode, susp = nil, nil
	clean(obj)
	curNode, susp = n, pSusp
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
		ownExtra = true
		curCtx = { parent = prevContext, key = self, value = value }
		local ok, result = xpcall(fn, traceback)
		curCtx, ownExtra = prevContext, prevExtra
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
	curCtx, ownExtra = prevContext, prevExtra
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
		curCtx, ownExtra = ctx, true
		return finishBindContext(prevContext, prevExtra, xpcall(fn :: (...any) -> ...any, traceback, ...))
	end
end

local function attach(o: any, node: any)
	if o then
		local slot = if o[HEIGHT] == INF then E_CHILDREN else CHILDREN
		local c = o[slot]
		if c then
			local n = c[1] + 1
			c[1] = n
			c[n] = node
		else
			o[slot] = { 2, node }
		end
	end
end

local function enqueue(node: any)
	local qt = queueTail + 1
	queueTail = qt
	queue[qt] = node
end

local function scope<T>(fn: (scope: Node<any>) -> T): (Node<any>, T)
	local inner = { nil, true, false, false, SCOPE, INF, true, false, false, false }
	if ownExtra then
		ownSlow(inner)
	else
		attach(curNode or curOwner, inner)
	end
	local node: any = setmetatable({ inner }, Node)
	local pNode, pOwner, pSet, pSusp, pIdx, pNew = curNode, curOwner, ownerSet, susp, curIdx, curNew
	local pSuspRun = suspRun
	curNode, curOwner, ownerSet, susp = nil, inner, false, nil
	local ok, result = xpcall(fn, traceback, node)
	curNode, curOwner, ownerSet, susp, curIdx, curNew = pNode, pOwner, pSet, pSusp, pIdx, pNew
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

local function signal(initial: any, equals: any): any
	local node = { initial, 0, 0, 0, nil, nil }
	if equals then
		node.equals = equals
		anySigEquals = true
	end
	return setmetatable({ node }, SignalMT)
end

local function wrapComputedEquals(node: any, fn: any, equals: any)
	node.equals = equals
	node[FN] = function(prev: any)
		local v = fn(prev)
		if v ~= prev and node[CHANGED] ~= 0 and equals(prev, v) then
			node[VALUE] = v
			return prev
		end
		return v
	end
end

local function computed(fn: any, equals: any): any
	local node = { nil, false, 0, 0, 1, 0, fn, SRC1, false, false, nil, nil }
	if equals then
		wrapComputedEquals(node, fn, equals)
	end
	if ownExtra then
		ownSlow(node)
	else
		attach(curNode or curOwner, node)
	end
	return setmetatable({ node }, ComputedMT)
end

local function createEffect(fn: (...any) -> ...any)
	local node: any = { nil, E_SRC1, fn, false, INF, 0, nil, nil }
	if ownExtra then
		ownSlow(node)
	else
		attach(curNode or curOwner, node)
	end
	enqueue(node)
end

local function effect(fn: (...any) -> ...any): any
	local node: any = { nil, E_SRC1, fn, false, INF, 0, nil, nil }
	if ownExtra then
		ownSlow(node)
	else
		attach(curNode or curOwner, node)
	end
	enqueue(node)
	return setmetatable({ node }, Node)
end

local function getter(node: any): any
	local mt = getmetatable(node)
	if mt == SignalMT then
		local inner = node[1]
		return function(): any
			return getSignal(inner)
		end
	elseif mt == ComputedMT then
		local inner = node[1]
		return function(): any
			return getMemo(inner)
		end
	elseif mt == Node or (mt ~= nil and type(mt) == "table" and mt.__type == Node) then
		local inner = node[1]
		return function(): any
			return getData(inner)
		end
	end
	error(`Flux.getter expects a node, got {typeof(node)}`, 2)
end

local function setter(node: any): any
	local mt = getmetatable(node)
	if mt == SignalMT then
		local inner = node[1]
		return function(value: any, force: boolean?): any
			return setSignal(inner, value, force)
		end
	elseif mt == ComputedMT or mt == Node or (mt ~= nil and type(mt) == "table" and mt.__type == Node) then
		local inner = node[1]
		return function(value: any, force: boolean?): any
			return setData(inner, value, force)
		end
	end
	error(`Flux.setter expects a node, got {typeof(node)}`, 2)
end

local function createSignal<T>(initial: T, equals: ((T, T: any) -> boolean)?): (() -> T, (value: T, force: boolean?) -> T)
	local node = { initial, 0, 0, 0, nil, nil }
	if equals then
		node.equals = equals
		anySigEquals = true
	end
	return function(): any
		return getSignal(node)
	end, function(value: any, force: boolean?): any
		return setSignal(node, value, force)
	end
end

local function createMemo<T>(fn: () -> T, equals: ((T, T) -> boolean)?): () -> T
	local node = { nil, false, 0, 0, 1, 0, fn, SRC1, false, false, nil, nil }
	if equals then
		wrapComputedEquals(node, fn, equals)
	end
	if ownExtra then
		ownSlow(node)
	else
		attach(curNode or curOwner, node)
	end
	return function(): any
		return getMemo(node)
	end
end

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

local safe: <T>(tryFn: () -> T, fallback: T | (err: unknown) -> T, equals: ((a: T, b: T) -> boolean)?) -> Node<T>
do
	local function recoverSafe<T>(handler: (err: unknown) -> T, err: unknown): T
		local n, s, sr = curNode, susp, suspRun
		curNode, susp = nil, nil
		local ok, result = pcall(handler, err)
		curNode, susp, suspRun = n, s, sr
		if not ok then
			error(result, 0)
		end
		return result
	end

	function safe<T>(tryFn: () -> T, fallback: T | (err: unknown) -> T, equals: ((a: T, b: T) -> boolean)?): Node<T>
		return computed(function()
			local ok, result = pcall(tryFn)
			if ok then
				return result
			end
			if type(fallback) == "function" then
				return recoverSafe(fallback :: (unknown) -> T, result)
			end
			return fallback
		end, equals)
	end
end

local function isStale(node: any): boolean
	return node[1][STAMP] == 0 or heapMin ~= INF
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
type Operators<T> = {
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
	Notifies the node's dependents without changing its value, useful after mutating a table in place.

	[Open Documentation](https://flux.kohl.gg/guide/concepts/signals#forcing-an-update)
	]]
	read update: <N>(self: N) -> N,
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
	Notifies the node's dependents without changing its value, useful after mutating a table in place.

	[Open Documentation](https://flux.kohl.gg/guide/concepts/signals#forcing-an-update)
	]]
	read update: <N>(self: N) -> N,
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
	only when read after a dependency changes, and uses `equals` (default `==`) to stop propagation when the result is unchanged.

	```luau
	local total = Flux.computed(function()
		return price() * quantity()
	end)
	```

	[Open Documentation](https://flux.kohl.gg/guide/concepts/computeds)
	]]
	computed = computed :: <T>(fn: () -> T, equals: ((T, T) -> boolean)?) -> Node<T>,
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
	or arrays of cleanables). Runs untracked and warns on error instead of throwing.

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
	static value or an untracked `(err) -> T` function) if `tryFn` throws. Automatically recovers when tracked dependencies
	change.

	[Open Documentation](https://flux.kohl.gg/guide/tips/errors#structured-error-handling-flux-safe)
	]]
	safe = safe,
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
	kindOf = kindOf,
	Node = table.freeze(Node),
}

return table.freeze(Graph)
