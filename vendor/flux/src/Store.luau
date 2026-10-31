--!strict
--[[
Deep reactive stores: `Flux.store(table)` returns a proxy whose fields are tracked per key, with `Flux.Store` helpers
for arrays, snapshots and teardown.

```luau
local state = Flux.store({ player = { hp = 100 } })
Flux.effect(function() print(state.player.hp) end)
state.player.hp = 90
```
]]

local Compat = require("./Compat")
local Graph = require("./Graph")

local cleanup = Graph.cleanup
local newValue = Graph.signal
local get = Graph.Node.get
local setValue = Graph.Node.set
local destroyNode = Graph.Node.Destroy
local isReactive = Graph.isReactive
local isObserved = Graph.isObserved
local getOwner = Graph.getOwner
local register = Graph.register
local warn = Compat.warn

--- @ignore
type Meta = {
	__index: (proxy: any, key: any) -> any,
	__newindex: (proxy: any, key: any, value: any) -> (),
	__iter: (proxy: any) -> ...any,
	__len: (proxy: any) -> number,
	target: { [any]: any },
	nodes: { [any]: Graph.Node<any> },
	parent: Meta?,
	children: { [any]: boolean }?,
}

local proxyCache: { [any]: any } = setmetatable({}, { __mode = "v" })
local proxyToRaw: { [any]: { [any]: any } } = setmetatable({}, { __mode = "k" })

local STORE_SYMBOL: any = table.freeze({})

local function toRaw(value: any): any
	return if type(value) == "table" then proxyToRaw[value] or value else value
end

local index: (proxy: any, key: any) -> any
local newindex: (proxy: any, key: any, value: any) -> ()
local iter: (proxy: any) -> ...any
local len: (proxy: any) -> number

local function destroyProxy(proxy: any)
	local target = proxyToRaw[proxy]
	if target == nil then
		return
	end
	local meta = getmetatable(proxy) :: Meta
	if proxyCache[target] == proxy then
		proxyCache[target] = nil
	end
	proxyToRaw[proxy] = nil
	register(proxy, nil)
	setmetatable(proxy, nil)

	local parent = meta.parent
	if parent and parent.children then
		parent.children[proxy] = nil
	end
	local children = meta.children
	if children then
		meta.children = nil
		for child in children do
			destroyProxy(child)
		end
	end
	local nodes = meta.nodes
	for _, node in nodes do
		destroyNode(node)
	end
	table.clear(nodes)
end

local function createProxy<T>(target: T, parentMeta: Meta?): T
	local rawTarget: any = target
	local cached = proxyCache[rawTarget]
	if cached then
		return cached
	end

	local nodes: { [any]: Graph.Node<any> } = {}
	local meta: Meta = {
		__index = index,
		__newindex = newindex,
		__iter = iter,
		__len = len,
		target = rawTarget,
		nodes = nodes,
		parent = parentMeta,
		children = nil,
	}
	local proxy: any = setmetatable({}, meta)

	proxyCache[rawTarget] = proxy
	proxyToRaw[proxy] = rawTarget
	register(proxy, destroyProxy)

	if parentMeta then
		local children = parentMeta.children
		if children == nil then
			children = {}
			parentMeta.children = children
		end
		(children :: { [any]: boolean })[proxy] = true
	elseif getOwner() ~= nil then
		cleanup(proxy)
	end

	return proxy
end

local function teardownDisplaced(target: { [any]: any }, displaced: any)
	if type(displaced) ~= "table" then
		return
	end
	local displacedProxy = proxyCache[displaced]
	if displacedProxy == nil then
		return
	end
	for _, value in target do
		if value == displaced then
			return
		end
	end
	destroyProxy(displacedProxy)
end

local function fireTracker(nodes: { [any]: any }, target: { [any]: any })
	local tracker = nodes[STORE_SYMBOL]
	if tracker then
		setValue(tracker, target, true)
	end
end

local function resyncIndices(nodes: { [any]: any }, target: { [any]: any }, from: number, to: number)
	for i = from, to do
		local node = nodes[i]
		if node then
			setValue(node, target[i])
		end
	end
end

local function readTracker(meta: Meta): { [any]: any }
	local target = meta.target
	local nodes = meta.nodes

	local tracker = nodes[STORE_SYMBOL]
	if not tracker then
		tracker = newValue(target)
		nodes[STORE_SYMBOL] = tracker
	end
	get(tracker)

	return target
end

local function validatePos(pos: any, max: number): number
	if type(pos) ~= "number" then
		error(`Position must be a number, got {typeof(pos)}`, 3)
	elseif pos ~= math.floor(pos) or pos < 1 or pos > max then
		error(`Position {pos} out of range [1, {max}]`, 3)
	end
	return pos
end

function index(proxy: any, key: any): any
	local meta: Meta = getmetatable(proxy)
	local value = rawget(meta.target, key)

	if isReactive() then
		local nodes = meta.nodes
		local node = nodes[key]
		if node == nil then
			node = newValue(value)
			nodes[key] = node
		end
		get(node)
	end

	if type(value) == "table" and getmetatable(value) == nil then
		return createProxy(value, meta)
	end
	return value
end

function newindex(proxy: any, key: any, newVal: any)
	local meta: Meta = getmetatable(proxy)
	local target = meta.target
	local rawValue = toRaw(newVal)
	local oldValue = rawget(target, key)
	if oldValue == rawValue and type(rawValue) ~= "table" then
		return
	end

	rawset(target, key, rawValue)
	if type(oldValue) == "table" and oldValue ~= rawValue then
		teardownDisplaced(target, oldValue)
	end

	local nodes = meta.nodes
	local node = nodes[key]
	if node ~= nil then
		setValue(node, rawValue)
		if rawValue == nil and not isReactive() and getOwner() == nil and not isObserved(node) then
			nodes[key] = nil
			destroyNode(node)
		end
	end

	fireTracker(nodes, target)
end

local function nextProxy(meta: Meta, k: any): (any, any)
	local key, value = next(meta.target, k)
	if type(value) == "table" and getmetatable(value) == nil then
		return key, createProxy(value, meta)
	end
	return key, value
end

function iter(proxy: any)
	local meta: Meta = getmetatable(proxy)
	readTracker(meta)
	return nextProxy, meta
end

function len(proxy: any): number
	return #readTracker(getmetatable(proxy))
end

local Store = {}

--[[
Wraps a plain table in a deep reactive proxy: reading a field inside a
[computed](https://flux.kohl.gg/guide/concepts/computeds) or
[effect](https://flux.kohl.gg/guide/concepts/effects) subscribes to that field, and assigning a new value
re-runs only the dependents of the leaves that changed. Nested plain tables are proxied recursively on
access; metatable'd values (Flux [node](https://flux.kohl.gg/guide/concepts/signals)s, class instances) stay
atomic. Available as `Flux.store`.

[Open Documentation](https://flux.kohl.gg/guide/concepts/stores#creating-a-store)
]]
function Store.new<T>(initialState: T): T
	local state: any = initialState
	assert(type(state) == "table", "Store initialState must be a table")
	if proxyToRaw[state] ~= nil then
		return state
	end
	return createProxy(state)
end

--[[
Tears down a store and every nested proxy beneath it, destroying their per-key
[node](https://flux.kohl.gg/guide/concepts/signals)s so dependents stop tracking them; the proxy is left an empty
plain table and the raw table is left intact. A store created inside a
[scope](https://flux.kohl.gg/guide/concepts/scopes) is torn down when the scope is destroyed; [Flux.dispose] performs the
same cleanup. An unreferenced store is garbage-collected automatically; call this method only to disconnect its
dependents early.

[Open Documentation](https://flux.kohl.gg/guide/concepts/stores#destroying-a-store)
]]
function Store.Destroy<T>(proxy: T)
	destroyProxy(proxy)
end

--[[
Returns the raw, un-proxied table underlying a store: the live backing object,
not a copy. Reads through it bypass tracking entirely (no
[node](https://flux.kohl.gg/guide/concepts/signals) is subscribed), so use it for cheap snapshots or to hand a
plain table to non-reactive code. Passing a value that is not a store returns it unchanged.

[Open Documentation](https://flux.kohl.gg/guide/concepts/stores#unwrapping-a-store)
]]
function Store.unwrap<T>(proxy: T): T
	return (proxyToRaw[proxy] or proxy) :: T
end

--[[
Reactive counterpart of [`table.insert`](https://create.roblox.com/docs/reference/engine/libraries/table#insert):
with no third argument, appends `posOrValue` to the end; with a third argument, inserts `value` at 1-based position
`posOrValue` and shifts subsequent elements up. Use this instead of assigning past the array's length so iteration
and `#` watchers fire and the shifted indices re-sync. An out-of-range position errors.

[Open Documentation](https://flux.kohl.gg/guide/concepts/stores#arrays-and-iteration)
]]
function Store.insert(proxy: any, posOrValue: any, value: any?)
	local target = proxyToRaw[proxy]
	if not target then
		if value == nil then
			table.insert(proxy, posOrValue)
		else
			table.insert(proxy, posOrValue, value)
		end
		return
	end

	local pos: number
	local val: any
	if value == nil then
		pos = #target + 1
		val = posOrValue
	else
		pos = validatePos(posOrValue, #target + 1)
		val = value
	end

	local rawValue = toRaw(val)
	table.insert(target, pos, rawValue)

	local nodes = (getmetatable(proxy) :: Meta).nodes
	resyncIndices(nodes, target, pos, #target)
	fireTracker(nodes, target)
end

--[[
Reactive counterpart of [`table.remove`](https://create.roblox.com/docs/reference/engine/libraries/table#remove):
removes and returns the element at `pos` (default: the last), shifting subsequent elements down. Use this
instead of `proxy[i] = nil`, which leaves a hole that corrupts the array part. An out-of-range `pos` errors.

[Open Documentation](https://flux.kohl.gg/guide/concepts/stores#arrays-and-iteration)
]]
function Store.remove(proxy: any, pos: number?): any
	local target = proxyToRaw[proxy]
	if not target then
		return table.remove(proxy, pos)
	end

	local length = #target
	if pos ~= nil then
		validatePos(pos, length)
	end
	if length == 0 then
		return nil
	end

	local idx = pos or length
	local removed = table.remove(target, idx)

	teardownDisplaced(target, removed)

	local nodes = (getmetatable(proxy) :: Meta).nodes
	resyncIndices(nodes, target, idx, length - 1)
	local tailNode = nodes[length]
	if tailNode then
		setValue(tailNode, nil)
	end

	fireTracker(nodes, target)
	return removed
end

--[[
Reactively reorders the array, moving the element at 1-based index `from` to `to` and shifting the elements between
them so positional readers and `#`/iteration watchers follow. Equivalent to a
[`table.remove`](https://create.roblox.com/docs/reference/engine/libraries/table#remove) +
[`table.insert`](https://create.roblox.com/docs/reference/engine/libraries/table#insert) but as a single tracked
step: the length is unchanged, so nothing is removed and no nested proxy is torn down, ideal for drag-and-drop
list reordering. Both indices must be in `[1, #proxy]`; an out-of-range index errors.

[Open Documentation](https://flux.kohl.gg/guide/concepts/stores#arrays-and-iteration)
]]
function Store.move(proxy: any, from: number, to: number)
	local target = proxyToRaw[proxy]
	if not target then
		table.insert(proxy, to, table.remove(proxy, from))
		return
	end

	local length = #target
	validatePos(from, length)
	validatePos(to, length)
	if from == to then
		return
	end

	table.insert(target, to, table.remove(target, from))

	local nodes = (getmetatable(proxy) :: Meta).nodes
	resyncIndices(nodes, target, math.min(from, to), math.max(from, to))
	fireTracker(nodes, target)
end

local function isArrayLike(t: { [any]: any }): boolean
	return rawget(t, 1) ~= nil
end

local function isArrayIndex(key: any, arrayLen: number): boolean
	return type(key) == "number" and key >= 1 and key <= arrayLen and key == math.floor(key)
end

local reconcileTable: (proxy: any, target: { [any]: any }, newData: { [any]: any }, reconcileKey: string?) -> ()

local function syncRaw(old: { [any]: any }, newData: { [any]: any })
	for field in old do
		if rawget(newData, field) == nil then
			old[field] = nil
		end
	end
	for field, value in newData do
		old[field] = toRaw(value)
	end
end

local function reconcileLeaf(
	target: { [any]: any },
	nodes: { [any]: any },
	key: any,
	rawNew: any,
	reconcileKey: string?
): boolean
	local oldValue = rawget(target, key)
	if oldValue == rawNew then
		return false
	end
	if type(oldValue) == "table" and type(rawNew) == "table" then
		local oldProxy = proxyCache[oldValue]
		if oldProxy ~= nil then
			reconcileTable(oldProxy, oldValue, rawNew, reconcileKey)
		else
			syncRaw(oldValue, rawNew)
		end
		return false
	end
	rawset(target, key, rawNew)
	if type(oldValue) == "table" then
		teardownDisplaced(target, oldValue)
	end
	local node = nodes[key]
	if node ~= nil then
		setValue(node, rawNew)
	end
	return true
end

local function reconcileArray(target: { [any]: any }, newData: { [any]: any }, nodes: { [any]: any }): (number, boolean)
	local oldLen = #target
	local newLen = #newData
	local span = if oldLen > newLen then oldLen else newLen
	local structural = false

	for i = 1, span do
		structural = reconcileLeaf(target, nodes, i, toRaw(rawget(newData, i)), nil) or structural
	end

	return span, structural
end

local function reconcileArrayKeyed(
	target: { [any]: any },
	newData: { [any]: any },
	nodes: { [any]: any },
	reconcileKey: string
): (number, boolean)
	local oldLen = #target
	local newLen = #newData
	local span = if oldLen > newLen then oldLen else newLen
	local structural = false

	local oldElems = table.create(span)
	local oldByKey: { [any]: any } = {}
	for i = 1, span do
		local el = rawget(target, i)
		if el == nil then
			continue
		end
		oldElems[i] = el
		if type(el) == "table" then
			local k = rawget(el, reconcileKey)
			if k ~= nil then
				oldByKey[k] = el
			end
		end
	end

	local matched: { [any]: boolean } = {}
	local seenKeys: { [any]: boolean } = {}
	for i = 1, span do
		local rawNew = toRaw(rawget(newData, i))

		local placed = rawNew
		if type(rawNew) == "table" then
			local k = rawget(rawNew, reconcileKey)
			local reuse
			if k ~= nil then
				if seenKeys[k] then
					warn(
						`[Flux] Store.reconcile: duplicate key "{tostring(k)}" on field "{reconcileKey}"; keys must be unique or the duplicate aliases one element`
					)
				else
					seenKeys[k] = true
				end
				reuse = oldByKey[k]
			else
				local old: any = oldElems[i]
				if type(old) == "table" and rawget(old, reconcileKey) == nil then
					reuse = old
				end
			end
			if reuse ~= nil then
				matched[reuse] = true
				local childProxy = proxyCache[reuse]
				if childProxy ~= nil then
					reconcileTable(childProxy, reuse, rawNew, reconcileKey)
				else
					syncRaw(reuse, rawNew)
				end
				placed = reuse
			end
		end

		if rawget(target, i) ~= placed then
			structural = true
			rawset(target, i, placed)
			local node = nodes[i]
			if node ~= nil then
				setValue(node, placed)
			end
		end
	end

	for i = 1, span do
		local el = oldElems[i]
		if type(el) == "table" and not matched[el] then
			teardownDisplaced(target, el)
		end
	end

	return span, structural
end

function reconcileTable(proxy: any, target: { [any]: any }, newData: { [any]: any }, reconcileKey: string?)
	local nodes = (getmetatable(proxy) :: Meta).nodes
	local structural = false

	local arrayLen = 0
	if isArrayLike(target) or isArrayLike(newData) then
		if reconcileKey ~= nil then
			arrayLen, structural = reconcileArrayKeyed(target, newData, nodes, reconcileKey)
		else
			arrayLen, structural = reconcileArray(target, newData, nodes)
		end
	end

	for key, newVal in newData do
		if isArrayIndex(key, arrayLen) then
			continue
		end
		structural = reconcileLeaf(target, nodes, key, toRaw(newVal), reconcileKey) or structural
	end

	for key in target do
		if isArrayIndex(key, arrayLen) then
			continue
		end
		if rawget(newData, key) == nil then
			structural = true
			reconcileLeaf(target, nodes, key, nil, reconcileKey)
		end
	end

	if structural then
		fireTracker(nodes, target)
	end
end

--[[
Diffs the snapshot `newData` into the live store `proxy`, firing only the
[node](https://flux.kohl.gg/guide/concepts/signals)s whose leaves actually changed and reusing unchanged
nested proxies instead of tearing them down. Arrays diff positionally by default; when `key` is given, array
elements are matched by `element[key]` instead (recursively through every nested array), so reordered or inserted
rows keep their proxy (and their
[`Flux.forValue`](https://flux.kohl.gg/guide/concepts/mapping#flux-forvalue-keyed-by-value) result) and only
changed rows fire. `newData` should be a plain, acyclic snapshot. Returns `proxy`.

[Open Documentation](https://flux.kohl.gg/guide/concepts/stores#reconciling-snapshots)
]]
function Store.reconcile<T>(proxy: T, newData: T, key: string?): T
	local target = proxyToRaw[proxy]
	assert(target ~= nil, "Store.reconcile expects a store proxy")
	assert(type(newData) == "table", "Store.reconcile newData must be a table")

	local rawNew: { [any]: any } = toRaw(newData)
	reconcileTable(proxy, target, rawNew, key)
	return proxy
end

return table.freeze(Store)
