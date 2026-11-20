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
	proxy: any,
	parents: { [any]: boolean }?,
	children: { [any]: boolean }?,
	root: boolean?,
}

local proxyCache: { [any]: any } = setmetatable({}, { __mode = "v" })
local proxyToRaw: { [any]: { [any]: any } } = setmetatable({}, { __mode = "k" })

local STORE_SYMBOL: any = table.freeze({})
local NAN_KEY: any = table.freeze({})

local function toRaw(value: any): any
	return if type(value) == "table" then proxyToRaw[value] or value else value
end

local function isPlainMutable(value: any): boolean
	return type(value) == "table" and getmetatable(value) == nil and not table.isfrozen(value)
end

local function isRootReachable(startProxy: any): boolean
	local meta = getmetatable(startProxy) :: Meta?
	if meta == nil then
		return false
	elseif meta.root then
		return true
	end
	local parents = meta.parents
	if parents == nil or next(parents) == nil then
		return false
	end
	local seen: { [any]: boolean } = { [startProxy] = true }
	local stack: { any } = { startProxy }
	while #stack > 0 do
		local cur = table.remove(stack)
		local curMeta = getmetatable(cur) :: Meta?
		local curParents = if curMeta then curMeta.parents else nil
		if curParents then
			for parentProxy in curParents do
				if not seen[parentProxy] then
					local parentMeta = getmetatable(parentProxy) :: Meta?
					if parentMeta then
						if parentMeta.root then
							return true
						end
						seen[parentProxy] = true
						table.insert(stack, parentProxy)
					end
				end
			end
		end
	end
	return false
end

local function linkParent(childProxy: any, parentProxy: any)
	if parentProxy == nil or childProxy == parentProxy then
		return
	end
	local childMeta = getmetatable(childProxy) :: Meta?
	local parentMeta = getmetatable(parentProxy) :: Meta?
	if childMeta == nil or parentMeta == nil then
		return
	end
	local parents = childMeta.parents
	if parents == nil then
		parents = {}
		childMeta.parents = parents
	end
	(parents :: { [any]: boolean })[parentProxy] = true
	local children = parentMeta.children
	if children == nil then
		children = {}
		parentMeta.children = children
	end
	(children :: { [any]: boolean })[childProxy] = true
end

local function linkIfProxied(rawVal: any, parentProxy: any)
	if type(rawVal) == "table" and proxyCache[rawVal] ~= nil then
		linkParent(proxyCache[rawVal], parentProxy)
	end
end

local index: (proxy: any, key: any) -> any
local newindex: (proxy: any, key: any, value: any) -> ()
local iter: (proxy: any) -> ...any
local len: (proxy: any) -> number

local function destroyProxy(proxy: any, visited: { [any]: boolean }?)
	local target = proxyToRaw[proxy]
	if target == nil then
		return
	end
	local seen = visited or {}
	if seen[proxy] then
		return
	end
	seen[proxy] = true

	local meta = getmetatable(proxy) :: Meta
	if proxyCache[target] == proxy then
		proxyCache[target] = nil
	end
	proxyToRaw[proxy] = nil
	register(proxy, nil)
	setmetatable(proxy, nil)

	local parents = meta.parents
	if parents then
		meta.parents = nil
		for parentProxy in parents do
			local parentMeta = getmetatable(parentProxy) :: Meta?
			if parentMeta and parentMeta.children then
				parentMeta.children[proxy] = nil
			end
		end
	end
	local children = meta.children
	if children then
		meta.children = nil
		for childProxy in children do
			local childMeta = getmetatable(childProxy) :: Meta?
			if childMeta then
				local cParents = childMeta.parents
				if cParents then
					cParents[proxy] = nil
				end
				if not isRootReachable(childProxy) then
					destroyProxy(childProxy, seen)
				end
			end
		end
	end
	local nodes = meta.nodes
	for _, node in nodes do
		destroyNode(node)
	end
	table.clear(nodes)
end

local function disposeRootProxy(proxy: any)
	destroyProxy(proxy)
end

local function createProxy<T>(target: T, parentProxy: any?): T
	local rawTarget: any = target
	local cached = proxyCache[rawTarget]
	if cached then
		if parentProxy ~= nil then
			linkParent(cached, parentProxy)
		else
			local cachedMeta = getmetatable(cached) :: Meta?
			if cachedMeta ~= nil then
				local wasRoot = cachedMeta.root
				cachedMeta.root = true
				if not wasRoot and getOwner() ~= nil then
					cleanup(cached)
				end
			end
		end
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
		proxy = nil,
		parents = nil,
		children = nil,
		root = parentProxy == nil,
	}
	local proxy: any = setmetatable({}, meta)
	meta.proxy = proxy

	proxyCache[rawTarget] = proxy
	proxyToRaw[proxy] = rawTarget
	register(proxy, disposeRootProxy)

	if parentProxy ~= nil then
		linkParent(proxy, parentProxy)
	elseif getOwner() ~= nil then
		cleanup(proxy)
	end

	return proxy
end

local function teardownDisplaced(parentProxy: any, target: { [any]: any }, displaced: any)
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
	local parentMeta = getmetatable(parentProxy) :: Meta?
	if parentMeta and parentMeta.children then
		parentMeta.children[displacedProxy] = nil
	end
	local childMeta = getmetatable(displacedProxy) :: Meta?
	if childMeta then
		if childMeta.parents then
			childMeta.parents[parentProxy] = nil
		end
		if not isRootReachable(displacedProxy) then
			destroyProxy(displacedProxy)
		end
	end
end

local function setKeyValue(nodes: { [any]: any }, key: any, node: any, value: any)
	setValue(node, value)
	if value == nil and not isReactive() and getOwner() == nil and not isObserved(node) then
		nodes[key] = nil
		destroyNode(node)
	end
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

	if isPlainMutable(value) then
		return createProxy(value, proxy)
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
	linkIfProxied(rawValue, proxy)
	if type(oldValue) == "table" and oldValue ~= rawValue then
		teardownDisplaced(proxy, target, oldValue)
	end

	local nodes = meta.nodes
	local node = nodes[key]
	if node ~= nil then
		setKeyValue(nodes, key, node, rawValue)
	end

	fireTracker(nodes, target)
end

local function nextProxy(meta: Meta, k: any): (any, any)
	local key, value = next(meta.target, k)
	if isPlainMutable(value) then
		return key, createProxy(value, meta.proxy)
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
Wraps a plain table in a deep reactive proxy that tracks each read key, nested table, and array length independently.
Values that already have a metatable (such as Flux nodes or class instances) are left untouched.

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
Tears down a store and all of its nested proxies, disposing their per-key nodes via [`Flux.dispose`](https://flux.kohl.gg/api/Flux#dispose) while leaving the raw backing table intact.

[Open Documentation](https://flux.kohl.gg/guide/concepts/stores#destroying-a-store)
]]
function Store.Destroy<T>(proxy: T)
	destroyProxy(proxy)
end

--[[
Returns the raw, unproxied backing table of a store for untracked reads or serialization.

[Open Documentation](https://flux.kohl.gg/guide/concepts/stores#unwrapping-a-store)
]]
function Store.unwrap<T>(proxy: T): T
	return (proxyToRaw[proxy] or proxy) :: T
end

--[[
Inserts `value` into a store array (appending with 2 arguments, or inserting at `posOrValue` with 3) and notifies length and index observers.

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
	linkIfProxied(rawValue, proxy)

	local nodes = (getmetatable(proxy) :: Meta).nodes
	resyncIndices(nodes, target, pos, #target)
	fireTracker(nodes, target)
end

--[[
Removes and returns the element at `pos` (defaulting to the last element) from a store array and notifies length and index observers.

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

	teardownDisplaced(proxy, target, removed)

	local nodes = (getmetatable(proxy) :: Meta).nodes
	resyncIndices(nodes, target, idx, length - 1)
	local tailNode = nodes[length]
	if tailNode then
		setKeyValue(nodes, length, tailNode, nil)
	end

	fireTracker(nodes, target)
	return removed
end

--[[
Moves the element at 1-based index `from` to `to` in a single tracked step without tearing down nested item proxies.

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

local reconcileTable: (
	proxy: any,
	target: { [any]: any },
	newData: { [any]: any },
	reconcileKey: string?,
	seen: { [any]: boolean }?
) -> ()

local function destroyOrphanedProxy(rawVal: any)
	if type(rawVal) == "table" then
		local p = proxyCache[rawVal]
		if p ~= nil and not isRootReachable(p) then
			destroyProxy(p)
		end
	end
end

local function syncUnproxied(
	old: { [any]: any },
	newData: { [any]: any },
	reconcileKey: string?,
	seen: { [any]: boolean }
)
	if seen[old] then
		return
	end
	seen[old] = true
	for field, oldFieldVal in old do
		if rawget(newData, field) == nil then
			old[field] = nil
			destroyOrphanedProxy(oldFieldVal)
		end
	end
	for field, value in newData do
		local rawNew = toRaw(value)
		local oldVal = rawget(old, field)
		if isPlainMutable(oldVal) and isPlainMutable(rawNew) then
			local subProxy = proxyCache[oldVal]
			if subProxy ~= nil then
				reconcileTable(subProxy, oldVal, rawNew, reconcileKey, seen)
			elseif oldVal ~= rawNew then
				syncUnproxied(oldVal, rawNew, reconcileKey, seen)
			end
		else
			rawset(old, field, rawNew)
			if oldVal ~= rawNew then
				destroyOrphanedProxy(oldVal)
			end
		end
	end
end

local function reconcileLeaf(
	proxy: any,
	target: { [any]: any },
	nodes: { [any]: any },
	key: any,
	rawNew: any,
	reconcileKey: string?,
	seen: { [any]: boolean }
): boolean
	local oldValue = rawget(target, key)
	if oldValue == rawNew then
		return false
	end
	if isPlainMutable(oldValue) and isPlainMutable(rawNew) then
		local oldProxy = proxyCache[oldValue]
		if oldProxy ~= nil then
			reconcileTable(oldProxy, oldValue, rawNew, reconcileKey, seen)
		else
			syncUnproxied(oldValue, rawNew, reconcileKey, seen)
		end
		return false
	end
	rawset(target, key, rawNew)
	if type(oldValue) == "table" then
		teardownDisplaced(proxy, target, oldValue)
	end
	linkIfProxied(rawNew, proxy)
	local node = nodes[key]
	if node ~= nil then
		setKeyValue(nodes, key, node, rawNew)
	end
	return true
end

local function reconcileArray(
	proxy: any,
	target: { [any]: any },
	newData: { [any]: any },
	nodes: { [any]: any },
	seen: { [any]: boolean }
): (number, boolean)
	local oldLen = #target
	local newLen = #newData
	local span = if oldLen > newLen then oldLen else newLen
	local structural = false

	for i = 1, span do
		structural = reconcileLeaf(proxy, target, nodes, i, toRaw(rawget(newData, i)), nil, seen) or structural
	end

	return span, structural
end

local function toKeySlot(k: any): any
	return if k ~= k then NAN_KEY else k
end

local function reconcileArrayKeyed(
	proxy: any,
	target: { [any]: any },
	newData: { [any]: any },
	nodes: { [any]: any },
	reconcileKey: string,
	seen: { [any]: boolean }
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
				oldByKey[toKeySlot(k)] = el
			end
		end
	end

	local matched: { [any]: boolean } = {}
	local seenKeys: { [any]: boolean } = {}
	for i = 1, span do
		local rawNew = toRaw(rawget(newData, i))

		local placed = rawNew
		if isPlainMutable(rawNew) then
			local k = rawget(rawNew, reconcileKey)
			local reuse
			if k ~= nil then
				local kSlot = toKeySlot(k)
				if seenKeys[kSlot] then
					warn(
						`[Flux] Store.reconcile: duplicate key "{tostring(k)}" on field "{reconcileKey}"; keys must be unique or the duplicate aliases one element`
					)
				else
					seenKeys[kSlot] = true
				end
				reuse = oldByKey[kSlot]
			else
				local old: any = oldElems[i]
				if isPlainMutable(old) and rawget(old, reconcileKey) == nil then
					reuse = old
				end
			end
			if reuse ~= nil and isPlainMutable(reuse) then
				matched[reuse] = true
				local childProxy = proxyCache[reuse]
				if childProxy ~= nil then
					reconcileTable(childProxy, reuse, rawNew, reconcileKey, seen)
				else
					syncUnproxied(reuse, rawNew, reconcileKey, seen)
				end
				placed = reuse
			end
		end

		if rawget(target, i) ~= placed then
			structural = true
			rawset(target, i, placed)
			if placed == rawNew then
				linkIfProxied(placed, proxy)
			end
			local node = nodes[i]
			if node ~= nil then
				setKeyValue(nodes, i, node, placed)
			end
		end
	end

	for i = 1, span do
		local el = oldElems[i]
		if type(el) == "table" and not matched[el] then
			teardownDisplaced(proxy, target, el)
		end
	end

	return span, structural
end

function reconcileTable(
	proxy: any,
	target: { [any]: any },
	newData: { [any]: any },
	reconcileKey: string?,
	seen: { [any]: boolean }?
)
	local visited = seen or {}
	if visited[target] then
		return
	end
	visited[target] = true
	local nodes = (getmetatable(proxy) :: Meta).nodes
	local structural = false

	local arrayLen = 0
	if isArrayLike(target) or isArrayLike(newData) then
		if reconcileKey ~= nil then
			arrayLen, structural = reconcileArrayKeyed(proxy, target, newData, nodes, reconcileKey, visited)
		else
			arrayLen, structural = reconcileArray(proxy, target, newData, nodes, visited)
		end
	end

	for key, newVal in newData do
		if isArrayIndex(key, arrayLen) then
			continue
		end
		structural = reconcileLeaf(proxy, target, nodes, key, toRaw(newVal), reconcileKey, visited) or structural
	end

	for key in target do
		if isArrayIndex(key, arrayLen) then
			continue
		end
		if rawget(newData, key) == nil then
			structural = true
			reconcileLeaf(proxy, target, nodes, key, nil, reconcileKey, visited)
		end
	end

	if structural then
		fireTracker(nodes, target)
	end
end

--[[
Diffs `newData` into the store `proxy` in place, firing only changed leaf nodes and reusing unchanged nested proxies.
Pass `key` to match array elements by `element[key]` instead of array index.

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
