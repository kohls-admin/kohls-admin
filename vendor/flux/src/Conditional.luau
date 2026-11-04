--!strict
--[[
Control flow, list mapping, and keyed selection helpers (`show`, `showKeyed`, `switch`, `presence`, `pick`, `fallback`, `forValue`, `forIndex`, `selector`).

```luau
Flux.show(loggedIn, function() return Profile {} end, function() return SignIn {} end)
```
]]

local Compat = require("./Compat")
local Graph = require("./Graph")

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
type function NonNil(t: type): type
	if t:is("nil") then
		return types.never
	elseif not t:is("union") then
		return t
	end
	local parts = {}
	for _, part in t:components() do
		if not part:is("nil") then
			table.insert(parts, part)
		end
	end
	return if #parts == 0 then types.never elseif #parts == 1 then parts[1] else types.unionof(table.unpack(parts))
end

local OTHERWISE: any = table.freeze({ type = "SwitchOtherwise" })
local UNSET = table.freeze({})
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
	local output = newValue(NO_VALUE)

	local function valueOf()
		local current = read(source)
		return current
	end

	local driver = effect(function()
		local value = read(source)
		local key, factory = selectBranch(value, argA, argB, argC)

		if key == activeKey then
			return
		end
		activeKey = key

		untrack()
		local previous = activeBranch
		activeBranch = nil
		if previous ~= nil then
			previous:Destroy()
		end

		if factory ~= nil then
			local ok, branch, result = mountBranch(factory, valueOf)
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

	local function done()
		local leaving = exiting
		if leaving ~= nil and leaving:peek() then
			set(finished, finished:peek() + 1)
		end
	end

	local driver = effect(function()
		local present = read(condition)
		local finishes = get(finished)

		untrack()
		local current, leaving = branch, exiting
		if present then
			handled = finishes
			if current == nil then
				local exit = newValue(false)
				local ok, mounted, result = mountBranch(component, exit, done)
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

-- For (forIndex, forValue) --------------------------------------------------------------------------------------------

local function createMapper(list: any, mapFn: any, keyedByValue: boolean): Node<any>
	local cache: { [any]: any } = {}
	local nodes: { [any]: Node<any> } = {}
	local currentKeys: { [any]: boolean } = {}
	local cacheN = 0
	local rebuildAborted = false
	local rowA: any, rowB: any

	local function build()
		local a, b = rowA, rowB
		rowA, rowB = nil, nil
		return mapFn(a, b)
	end

	local self = computed(function()
		local current = read(list) :: { any }
		if type(current) ~= "table" then
			return {}
		end

		table.clear(currentKeys)
		local out = table.create(#current)

		local mustScan = rebuildAborted
		rebuildAborted = true
		untrack()

		local seen, added = 0, 0
		for index, value in current do
			local key: any, held: any = index, value
			if keyedByValue then
				key, held = value, index
				if currentKeys[key] ~= nil then
					warn(
						"[Flux] Flux.forValue: duplicate values share one mapped instance (the value is the cache key); use Flux.forIndex"
					)
					seen -= 1
				end
			end
			currentKeys[key] = true
			seen += 1
			local node = nodes[key]
			if node ~= nil then
				set(node, held)
				out[index] = cache[key]
			else
				node = newValue(held)
				if keyedByValue then
					rowA, rowB = node, value
				else
					rowA, rowB = index, node
				end
				local mapped = withOwner(node, build)
				cache[key] = mapped
				nodes[key] = node
				added += 1
				out[index] = mapped
			end
		end

		rebuildAborted = false

		if mustScan or seen ~= cacheN + added then
			local liveN = 0
			for key, node in nodes do
				if currentKeys[key] == nil then
					node:Destroy()
					nodes[key] = nil
					dispose(cache[key])
					cache[key] = nil
				else
					liveN += 1
				end
			end
			cacheN = liveN
		else
			cacheN += added
		end

		return out
	end)

	self:onDestroy(function()
		for key, node in nodes do
			node:Destroy()
			dispose(cache[key])
		end
		table.clear(nodes)
		table.clear(cache)
		table.clear(currentKeys)
	end)

	return self
end

--[[
Maps `list` by numeric index, running `mapFn(index, item)` once per slot and updating `item` in place when the value at that index changes.

[Open Documentation](https://flux.kohl.gg/guide/concepts/mapping#flux-forindex-keyed-by-index)
]]
local function forIndex<L, U>(list: L, mapFn: (index: number, item: Node<Item<L>>) -> U): Node<{ U }>
	return createMapper(list, mapFn, false)
end

--[[
Maps `list` by item identity, running `mapFn(index, value)` once per unique value and updating `index` when an item moves.
Values must be unique (use `Flux.forIndex` for primitive or duplicate values).

[Open Documentation](https://flux.kohl.gg/guide/concepts/mapping#flux-forvalue-keyed-by-value)
]]
local function forValue<L, U>(list: L, mapFn: (index: Node<number>, value: Item<L>) -> U): Node<{ U }>
	return createMapper(list, mapFn, true)
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
	if isStale(self._watcher) then
		raw(self._watcher)
	end
	local nodes = self._nodes
	local node = nodes[key]
	if node ~= nil then
		return get(node :: Graph.Node<boolean>)
	end

	local equals = self._equals
	local selected = if equals ~= nil then equals(self._active, key) else self._active == key
	if not isReactive() then
		return selected
	end

	if self._count >= self._sweepAt then
		self._sweepAt = SWEEP_REQUESTED
		set(self._sweepSignal, true, true)
	end
	node = newValue(selected)
	nodes[key] = node
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
		if equals == nil and prev == value then
			return
		end
		self._active = value
		if self._count == 0 then
			return
		end

		untrack()
		if equals == nil then
			local prevNode = if prev ~= nil then nodes[prev] else nil
			if prevNode ~= nil then
				set(prevNode, false)
			end
			local nextNode = if value ~= nil then nodes[value] else nil
			if nextNode ~= nil then
				set(nextNode, true)
			end
		else
			for key, node in nodes do
				set(node, equals(value, key))
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
	show = show :: (<T>(condition: unknown, component: (value: () -> any) -> T) -> Node<T?>) & (<T, F>(
		condition: unknown,
		component: (value: () -> any) -> T,
		fallback: (value: () -> any) -> F
	) -> Node<(T | F)?>),
	--[[
	Mounts `component` while `condition` is truthy (or `fallback` when falsy) and remounts in a fresh [scope](https://flux.kohl.gg/guide/concepts/scopes) whenever `condition` changes identity.

	[Open Documentation](https://flux.kohl.gg/guide/concepts/conditionals#keyed-show)
	]]
	showKeyed = showKeyed :: (<T>(condition: unknown, component: (value: () -> any) -> T) -> Node<T?>) & (<T, F>(
		condition: unknown,
		component: (value: () -> any) -> T,
		fallback: (value: () -> any) -> F
	) -> Node<(T | F)?>),
	switch = switch,
	presence = presence,
	pick = pick,
	fallback = fallback,
	forIndex = forIndex,
	forValue = forValue,
	selector = selector,
})
