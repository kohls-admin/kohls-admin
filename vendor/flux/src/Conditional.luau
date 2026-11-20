--!strict
--[[
Control flow, list mapping, and keyed selection helpers (`show`, `showKeyed`, `switch`, `presence`, `pick`, `fallback`, `forValue`, `forKey`, `forIndex`, `selector`).

```luau
Flux.show(loggedIn, function() return Profile {} end, function() return SignIn {} end)
```
]]

local Compat = require("./Compat")
local Graph = require("./Graph")
local Type = require("./Type")

local warn = Compat.warn
local computed = Graph.computed
local dispose = Graph.dispose
local effect = Graph.effect
local newValue = Graph.signal
local raw = Graph.raw
local read = Graph.read
local get = Graph.Node.get
local set = Graph.Node.set
local destroyNode = Graph.Node.Destroy
local untrack = Graph.untrack
local retrack = Graph.retrack
local scope = Graph.scope
local withOwner = Graph.withOwner
local isReactive = Graph.isReactive
local isStale = Graph.isStale
local isObserved = Graph.isObserved

--- @ignore
type Node<T> = Graph.Node<T>
--- @ignore
type Item<L> = index<Graph.Unwrap<L>, number>

--- @ignore
type NonNil<T> = Type.NonNil<T>
--- @ignore
type Truthy<T> = Type.Truthy<T>

local OTHERWISE: any = table.freeze({ type = "SwitchOtherwise" })
local UNSET = table.freeze({})
local NAN_KEY: any = table.freeze({ type = "NaNKey" })
local NIL_KEY: any = table.freeze({ type = "NilKey" })
local NO_VALUE: any = nil

-- Conditional (show, showKeyed, switch, presence, pick, fallback) -----------------------------------------------------

local function bindLifetime(output: Node<any>)
	if Graph.getOwner() ~= nil then
		Graph.cleanup(output)
	end
end

local function mountBranch(fn: any, a: any, b: any): (boolean, any, any)
	local ok, branch, result = pcall(withOwner, NO_VALUE, function()
		return scope(function(): any
			return fn(a, b)
		end)
	end)
	if ok then
		return true, branch, result
	end
	return false, branch, nil
end

local function mount(
	source: any,
	selectBranch: (value: any, a: any, b: any, c: any) -> (any, ((value: () -> any) -> any)?),
	argA: any,
	argB: any,
	argC: any
): Node<any>
	local activeKey: any = UNSET
	local activeBranch: Node<any>? = nil
	local lastValid: any = NO_VALUE
	local output = newValue(NO_VALUE)
	local destroyed = false

	local function valueOf()
		local current = read(source)
		local key = selectBranch(current, argA, argB, argC)
		if key == activeKey or (key ~= key and activeKey ~= activeKey) then
			lastValid = current
			return current
		end
		return lastValid
	end

	local driver = effect(function()
		local value = read(source)
		local key, factory = selectBranch(value, argA, argB, argC)

		if key == activeKey or (key ~= key and activeKey ~= activeKey) then
			lastValid = value
			return
		end

		untrack()
		local previous = activeBranch
		activeBranch = nil
		if previous ~= nil then
			previous:Destroy()
		end
		if destroyed then
			retrack()
			return
		end
		activeKey = key
		lastValid = value

		if factory ~= nil then
			local ok, branch, result = mountBranch(factory, valueOf)
			if destroyed then
				if ok and branch ~= nil then
					branch:Destroy()
				end
				retrack()
				return
			end
			if ok then
				activeBranch = branch
				set(output, result)
			else
				set(output, nil)
				activeKey = UNSET
				retrack()
				error(branch, 0)
			end
		else
			set(output, nil)
		end
		retrack()
	end)

	output:onDestroy(function()
		destroyed = true
		driver:Destroy()
		local branch = activeBranch
		activeBranch = nil
		if branch ~= nil then
			branch:Destroy()
		end
	end)
	bindLifetime(output)

	return output
end

local function showSelect(value: any, component: any, fallback: any, keyed: any): (any, any)
	local factory = if value then component else fallback
	return (if keyed then value else not not value), factory
end

local function switchSelect(value: any, map: { [any]: any }): (any, any)
	local factory = map[value]
	if factory == nil then
		local otherwise = map[OTHERWISE]
		if otherwise ~= nil then
			return OTHERWISE, otherwise
		end
	end
	return value, factory
end

local function show<T, F>(
	condition: unknown,
	component: (value: () -> any) -> T,
	fallback: ((value: () -> any) -> F)?
): Node<T | F>
	return mount(condition, showSelect, component, fallback, false)
end

local function showKeyed<T, F>(
	condition: unknown,
	component: (value: () -> any) -> T,
	fallback: ((value: () -> any) -> F)?
): Node<T | F>
	return mount(condition, showSelect, component, fallback, true)
end

--[[
Mounts the branch factory matching `source`'s current value in its own child [scope](https://flux.kohl.gg/guide/concepts/scopes).
Use `[Flux.otherwise]` in `map` as a catch-all branch for unmatched values.

[Open Documentation](https://flux.kohl.gg/guide/concepts/conditionals#switching-between-many-branches)
]]
local function switch<S>(source: S)
	return function<T>(map: { [Graph.Unwrap<S>]: (value: () -> Graph.Unwrap<S>) -> T }): Node<T?>
		local mounted: any = mount(source, switchSelect, map, nil, nil)
		return mounted
	end
end

--[[
Mounts `component(exiting, done)` while `condition` is truthy and keeps it mounted while `exiting()` is `true` until `done()` is called.
If `condition` turns truthy again before `done()` runs, `exiting` flips back to `false` without remounting.

[Open Documentation](https://flux.kohl.gg/guide/concepts/conditionals#animating-exits-with-presence)
]]
local function presence<T>(condition: unknown, component: (exiting: Node<boolean>, done: () -> ()) -> T): Node<T?>
	local output: any = newValue(NO_VALUE)
	local branch: Node<any>? = nil
	local exiting: Node<boolean>? = nil
	local finished = newValue(0)
	local handled = 0
	local destroyed = false

	local driver = effect(function()
		local present = read(condition)
		local finishes = get(finished)

		untrack()
		local current, leaving = branch, exiting
		if present then
			handled = finishes
			if current == nil then
				local exit = newValue(false)
				local function done()
					if exiting == exit and exit:peek() then
						set(finished, finished:peek() + 1)
					end
				end
				local ok, mounted, result = mountBranch(component, exit, done)
				if destroyed then
					destroyNode(exit)
					if ok and mounted ~= nil then
						mounted:Destroy()
					end
					retrack()
					return
				end
				if not ok then
					destroyNode(exit)
					set(output, nil)
					retrack()
					error(mounted, 0)
				end
				branch, exiting = mounted, exit
				set(output, result)
			elseif leaving ~= nil and leaving:peek() then
				set(leaving, false)
			end
		elseif current ~= nil and leaving ~= nil then
			if not leaving:peek() then
				handled = finishes
				set(leaving, true)
			elseif finishes ~= handled then
				branch, exiting = nil, nil
				current:Destroy()
				destroyNode(leaving)
				set(output, nil)
			end
		end
		retrack()
	end)

	output:onDestroy(function()
		destroyed = true
		driver:Destroy()
		local current, leaving = branch, exiting
		branch, exiting = nil, nil
		if leaving ~= nil then
			destroyNode(leaving)
		end
		destroyNode(finished)
		if current ~= nil then
			current:Destroy()
		end
	end)
	bindLifetime(output)

	return output
end

--[[
Derives a [node](https://flux.kohl.gg/guide/concepts/signals) returning `whenTrue` while `condition` is truthy and `whenFalse` otherwise.
Only the active branch is read, and no branch scope is created.

[Open Documentation](https://flux.kohl.gg/guide/concepts/conditionals#picking-between-values)
]]
local pick = function(condition: unknown, whenTrue: any, whenFalse: any?): Node<any>
	return computed(function(): any
		return if read(condition) then read(whenTrue) else read(whenFalse)
	end)
end :: (<A, B>(condition: unknown, whenTrue: A, whenFalse: B) -> Node<Graph.Unwrap<A> | Graph.Unwrap<B>>) & (<A>(condition: unknown, whenTrue: A) -> Node<Graph.Unwrap<A>?>)

--[[
Derives a [node](https://flux.kohl.gg/guide/concepts/signals) returning `value` when non-`nil`, or `default` when `value` is `nil`.
Preserves `false` instead of replacing it like `or`.

[Open Documentation](https://flux.kohl.gg/guide/concepts/conditionals#defaulting-a-nil-value)
]]
local function fallback<V, D>(value: V, default: D): Node<NonNil<Graph.Unwrap<V>> | Graph.Unwrap<D>>
	return computed(function(): any
		local current = read(value)
		return if current == nil then read(default) else current
	end)
end

-- For (forIndex, forValue, forKey) ------------------------------------------------------------------------------------

local function sweepMapperRows(
	nodes: { [any]: Node<any> },
	items: { [any]: Node<any> }?,
	cache: { [any]: any },
	currentKeys: { [any]: boolean }
): number
	local liveN = 0
	for key, node in nodes do
		if currentKeys[key] == nil then
			destroyNode(node)
			nodes[key] = nil
			if items ~= nil then
				destroyNode(items[key])
				items[key] = nil
			end
			dispose(cache[key])
			cache[key] = nil
		else
			liveN += 1
		end
	end
	return liveN
end

local function destroyMapperRows(
	nodes: { [any]: Node<any> },
	items: { [any]: Node<any> }?,
	cache: { [any]: any },
	currentKeys: { [any]: boolean }
)
	for key, node in nodes do
		destroyNode(node)
		if items ~= nil then
			destroyNode(items[key])
		end
		dispose(cache[key])
	end
	table.clear(nodes)
	if items ~= nil then
		table.clear(items)
	end
	table.clear(cache)
	table.clear(currentKeys)
end

local function createMapper(
	list: any,
	mapFn: any,
	keyedByValue: boolean,
	keyOf: ((any) -> any)?,
	fallbackFn: any?
): Node<any>
	local map: (any, any) -> any = mapFn
	assert(type(mapFn) == "function", "mapFn must be a function")
	local emptyFn: (() -> any)? = nil
	if fallbackFn ~= nil then
		local fb: () -> any = fallbackFn
		assert(type(fallbackFn) == "function", "fallback must be a function")
		emptyFn = fb
	end
	local cache: { [any]: any } = {}
	local nodes: { [any]: Node<any> } = {}
	local items: { [any]: Node<any> }? = if keyOf ~= nil then {} else nil
	local currentKeys: { [any]: boolean } = {}
	local cacheN = 0
	local rebuildAborted = false
	local rowA: any, rowB: any
	local fallbackOwner: Node<any>? = nil
	local fallbackItem: any = nil
	local fallbackOut: { any }? = nil
	local destroyed = false

	local function clearFallback()
		local owner = fallbackOwner
		if owner ~= nil then
			local item = fallbackItem
			fallbackOwner = nil
			fallbackItem = nil
			fallbackOut = nil
			destroyNode(owner)
			dispose(item)
		end
	end

	local function build()
		local a, b = rowA, rowB
		rowA, rowB = nil, nil
		return map(a, b)
	end

	local self = computed(function()
		local current = read(list) :: { any }
		if type(current) ~= "table" then
			if cacheN > 0 or rebuildAborted or next(nodes) ~= nil or fallbackOwner ~= nil then
				untrack()
				clearFallback()
				destroyMapperRows(nodes, items, cache, currentKeys)
				cacheN = 0
				rebuildAborted = false
				retrack()
			end
			return {}
		end

		table.clear(currentKeys)
		local out = table.create(#current)

		local mustScan = rebuildAborted
		rebuildAborted = true
		untrack()

		local getKey = keyOf
		local itemsMap = items
		local seen, added = 0, 0
		for index, value in current do
			if destroyed then
				retrack()
				return {}
			end
			local key: any, held: any = index, value
			if keyedByValue then
				if getKey ~= nil then
					local okKey, rawKey = pcall(getKey, value)
					if not okKey then
						retrack()
						error(rawKey, 0)
					end
					if rawKey ~= rawKey then
						warn("[Flux] Flux.forKey: NaN key fell back to item identity; keys must not be NaN")
						key = value
					else
						key = if rawKey == nil then value else rawKey
					end
				else
					if value == nil then
						warn("[Flux] Flux.forValue: nil item skipped; use Flux.forIndex for sparse lists")
						continue
					end
					key = value
				end
				if key ~= key then
					key = NAN_KEY
				end
				held = index
				if currentKeys[key] ~= nil then
					warn(
						if getKey ~= nil
							then "[Flux] Flux.forKey: duplicate keys share one mapped instance; keys must be unique"
							else "[Flux] Flux.forValue: duplicate values share one mapped instance (the value is the cache key); use Flux.forIndex"
					)
					seen -= 1
				end
			end
			currentKeys[key] = true
			seen += 1
			local node = nodes[key]
			if node ~= nil then
				set(node, held)
				if itemsMap ~= nil then
					set(itemsMap[key], value)
				end
				out[index] = cache[key]
			else
				node = newValue(held)
				local itemNode: Node<any>? = nil
				if itemsMap ~= nil then
					itemNode = newValue(value)
					rowA, rowB = node, itemNode
				elseif keyedByValue then
					rowA, rowB = node, value
				else
					rowA, rowB = index, node
				end
				local ok, mapped = pcall(withOwner, node, build)
				if destroyed then
					rowA, rowB = nil, nil
					destroyNode(node)
					if itemNode ~= nil then
						destroyNode(itemNode)
					end
					if ok then
						dispose(mapped)
					end
					retrack()
					return {}
				end
				if not ok then
					rowA, rowB = nil, nil
					destroyNode(node)
					if itemNode ~= nil then
						destroyNode(itemNode)
					end
					retrack()
					error(mapped, 0)
				end
				if itemNode ~= nil then
					(itemsMap :: { [any]: Node<any> })[key] = itemNode
				end
				cache[key] = mapped
				nodes[key] = node
				added += 1
				out[index] = mapped
			end
		end

		rebuildAborted = false

		if mustScan or seen ~= cacheN + added then
			cacheN = sweepMapperRows(nodes, itemsMap, cache, currentKeys)
		else
			cacheN += added
		end

		if seen == 0 and emptyFn ~= nil then
			if fallbackOwner == nil then
				local ok, branch, mapped = mountBranch(emptyFn, nil, nil)
				if destroyed then
					if ok then
						if branch ~= nil then
							destroyNode(branch)
						end
						dispose(mapped)
					end
					retrack()
					return {}
				end
				if not ok then
					retrack()
					error(branch, 0)
				end
				fallbackOwner = branch
				fallbackItem = mapped
				fallbackOut = if mapped == nil then {} else { mapped }
			end
			retrack()
			return fallbackOut :: { any }
		end

		clearFallback()
		retrack()
		return out
	end)

	self:onDestroy(function()
		destroyed = true
		clearFallback()
		destroyMapperRows(nodes, items, cache, currentKeys)
	end)

	return self
end

--[[
Maps `list` by numeric index, running `mapFn(index, item)` once per slot and updating `item` in place when the value at that index changes.
When `fallback` is given, mounts `fallback()` in a child [scope](https://flux.kohl.gg/guide/concepts/scopes) while `list` is empty.

[Open Documentation](https://flux.kohl.gg/guide/concepts/mapping#flux-forindex-keyed-by-index)
]]
local function forIndex(list: any, mapFn: any, fallback: any?): Node<any>
	return createMapper(list, mapFn, false, nil, fallback)
end

--[[
Maps `list` by item identity, running `mapFn(index, value)` once per unique value and updating `index` when an item moves.
Values must be unique (use `Flux.forIndex` for primitive or duplicate values).
When `fallback` is given, mounts `fallback()` in a child [scope](https://flux.kohl.gg/guide/concepts/scopes) while `list` is empty.

[Open Documentation](https://flux.kohl.gg/guide/concepts/mapping#flux-forvalue-keyed-by-value)
]]
local function forValue(list: any, mapFn: any, fallback: any?): Node<any>
	return createMapper(list, mapFn, true, nil, fallback)
end

--[[
Maps `list` by `keyOf(item)`, running `mapFn(index, item)` once per unique key and updating both `index` and `item` in place when entries with that key move or rebuild.
Entries whose key is `nil` fall back to item identity. Keys must be unique.
When `fallback` is given, mounts `fallback()` in a child [scope](https://flux.kohl.gg/guide/concepts/scopes) while `list` is empty.

[Open Documentation](https://flux.kohl.gg/guide/concepts/mapping#flux-forkey-keyed-by-function)
]]
local function forKey(list: any, keyOf: any, mapFn: any, fallback: any?): Node<any>
	assert(type(keyOf) == "function", "keyOf must be a function")
	return createMapper(list, mapFn, true, keyOf, fallback)
end

-- Selector ------------------------------------------------------------------------------------------------------------

local SWEEP_MIN = 32
local SWEEP_REQUESTED = math.huge

-- A selector: `selector(key)` or `selector:get(key)` reads whether `key` is selected.
export type Selector<K> = setmetatable<{
	--[[
	Reactively reads whether `key` matches the selector's source.

	[Open Documentation](https://flux.kohl.gg/guide/concepts/selectors#reading-a-selection)
	]]
	get: (self: any, key: K) -> boolean,
	--[[
	Destroys the selector and disposes its internal watcher and per-key nodes.

	[Open Documentation](https://flux.kohl.gg/guide/concepts/selectors#cleaning-up)
	]]
	Destroy: (self: any) -> (),
}, { __call: (self: any, key: K) -> boolean }>

--- @ignore
type SelectorData = {
	_nodes: { [any]: Graph.Node<boolean> },
	_count: number,
	_sweepAt: number,
	_watcher: Graph.Node<any>,
	_sweepSignal: Graph.State<boolean>,
	_equals: ((sourceValue: any, key: any) -> boolean)?,
	_active: any,
}

--- @class Selector
local SelectorMT = {}
SelectorMT.__index = SelectorMT

local function keyToSlot(key: any): any
	return if key == nil then NIL_KEY elseif key ~= key then NAN_KEY else key
end

local function slotToKey(slot: any): any
	return if slot == NIL_KEY then nil elseif slot == NAN_KEY then 0 / 0 else slot
end

local function sweep(self: SelectorData)
	local nodes = self._nodes
	local count = 0
	for key, node in nodes do
		if isObserved(node) then
			count += 1
		else
			nodes[key] = nil
			destroyNode(node)
		end
	end
	self._count = count
	self._sweepAt = math.max(SWEEP_MIN, 2 * count)
end

--[[
Reactively reads whether `key` matches the selector's source.

[Open Documentation](https://flux.kohl.gg/guide/concepts/selectors#reading-a-selection)
]]
function SelectorMT.get(self: SelectorData, key: any): boolean
	if self._watcher == nil then
		error("Cannot read a destroyed selector", 2)
	end
	if isStale(self._watcher) then
		raw(self._watcher)
	end
	local nodes = self._nodes
	local slot = keyToSlot(key)
	local node = nodes[slot]
	if node ~= nil then
		return get(node :: Graph.Node<boolean>)
	end

	local equals = self._equals
	local selected = if equals ~= nil then equals(self._active, key) else self._active ~= UNSET and self._active == key
	if not isReactive() then
		return selected
	end

	if self._count >= self._sweepAt then
		self._sweepAt = SWEEP_REQUESTED
		set(self._sweepSignal, true, true)
	end
	node = newValue(selected)
	nodes[slot] = node
	self._count += 1
	return get(node)
end

SelectorMT.__call = SelectorMT.get

--[[
Destroys the selector and disposes its internal watcher and per-key nodes.

[Open Documentation](https://flux.kohl.gg/guide/concepts/selectors#cleaning-up)
]]
function SelectorMT.Destroy(self: SelectorData)
	if self._watcher ~= nil then
		self._watcher:Destroy()
	end
end

--[[
Creates a keyed selector that tracks which key matches `source` in O(1) (or O(observed keys) with a custom `equals` comparator).

[Open Documentation](https://flux.kohl.gg/guide/concepts/selectors#creating-a-selector)
]]
local function selector<S, K>(source: S, equals: ((sourceValue: Graph.Unwrap<S>, key: K) -> boolean)?): Selector<K>
	local sweepSignal = newValue(false)
	local nodes: { [any]: Graph.Node<boolean> } = {}
	local self: any = setmetatable({
		_nodes = nodes,
		_count = 0,
		_sweepAt = SWEEP_MIN,
		_equals = equals,
		_active = UNSET,
		_watcher = NO_VALUE,
		_sweepSignal = sweepSignal,
	}, SelectorMT)

	self._watcher = effect(function()
		local value = read(source)
		local prev = self._active
		if equals == nil and (prev == value or (prev ~= prev and value ~= value)) then
			return
		end
		self._active = value
		if self._count == 0 then
			return
		end

		untrack()
		if equals == nil then
			if prev ~= UNSET and prev == prev then
				local prevNode = nodes[keyToSlot(prev)]
				if prevNode ~= nil then
					set(prevNode, false)
				end
			end
			if value == value then
				local nextNode = nodes[keyToSlot(value)]
				if nextNode ~= nil then
					set(nextNode, true)
				end
			end
		else
			for key, node in nodes do
				set(node, equals(value, slotToKey(key)))
			end
		end
		retrack()
	end)

	local sweeper = effect(function()
		get(sweepSignal)
		if self._sweepAt == SWEEP_REQUESTED then
			sweep(self)
		end
	end)

	self._watcher:onDestroy(function()
		for _, node in nodes do
			destroyNode(node)
		end
		sweeper:Destroy()
		destroyNode(sweepSignal)
		table.clear(self)
	end)

	return self
end

--- @ignore
type function NonUnknown(t: type): type
	if t:is("unknown") or t:is("never") then
		return types.never
	end
	return t
end

return table.freeze({
	--[[
	Catch-all branch key for [`Flux.switch`](https://flux.kohl.gg/guide/concepts/conditionals#a-catch-all-branch) maps when `source` matches no explicit key.

	```luau
	Flux.switch(state) {
		loading = function() return Spinner {} end,
		[Flux.otherwise] = function(value) return Label { text = value } end,
	}
	```

	[Open Documentation](https://flux.kohl.gg/guide/concepts/conditionals#a-catch-all-branch)
	]]
	otherwise = OTHERWISE,
	--[[
	Mounts `component` while `condition` is truthy, or `fallback` when falsy, in its own child [scope](https://flux.kohl.gg/guide/concepts/scopes).
	Rebuilds only when truthiness flips (use [`Flux.showKeyed`](https://flux.kohl.gg/guide/concepts/conditionals#keyed-show) to rebuild on every identity change).

	[Open Documentation](https://flux.kohl.gg/guide/concepts/conditionals#showing-one-of-two-branches)
	]]
	show = show :: (<S, T>(condition: S, component: (value: () -> Truthy<Graph.Unwrap<S>>) -> T) -> Node<T?>) & (<S, T, F>(
		condition: S,
		component: (value: () -> Truthy<Graph.Unwrap<S>>) -> T,
		fallback: (value: () -> Graph.Unwrap<S>) -> F
	) -> Node<(T | F)?>),
	--[[
	Mounts `component` while `condition` is truthy (or `fallback` when falsy) and remounts in a fresh [scope](https://flux.kohl.gg/guide/concepts/scopes) whenever `condition` changes identity.

	[Open Documentation](https://flux.kohl.gg/guide/concepts/conditionals#keyed-show)
	]]
	showKeyed = showKeyed :: (<S, T>(condition: S, component: (value: () -> Truthy<Graph.Unwrap<S>>) -> T) -> Node<T?>) & (<S, T, F>(
		condition: S,
		component: (value: () -> Truthy<Graph.Unwrap<S>>) -> T,
		fallback: (value: () -> Graph.Unwrap<S>) -> F
	) -> Node<(T | F)?>),
	switch = switch,
	presence = presence,
	pick = pick,
	fallback = fallback,
	forIndex = forIndex :: <L, U, F>(
		list: L,
		mapFn: (index: number, item: Node<Item<L>>) -> U,
		fallback: (() -> F)?
	) -> Node<{ U | NonUnknown<F> }>,
	forValue = forValue :: <L, U, F>(
		list: L,
		mapFn: (index: Node<number>, value: Item<L>) -> U,
		fallback: (() -> F)?
	) -> Node<{ U | NonUnknown<F> }>,
	forKey = forKey :: <L, U, F>(
		list: L,
		keyOf: (item: Item<L>) -> any,
		mapFn: (index: Node<number>, item: Node<Item<L>>) -> U,
		fallback: (() -> F)?
	) -> Node<{ U | NonUnknown<F> }>,
	selector = selector,
})
