--!strict
--[[
Control flow, list mapping, and keyed selection: `show`, `showKeyed`, `switch` and `presence` mount one branch at a
time in its own scope; `pick` and `fallback` choose between values without mounting anything; `forValue` and `forIndex`
map reactive arrays; `selector` tracks which key matches a source in O(1).

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
Mounts the branch keyed by `source`'s current value. Curries: pass the reactive
`source`, then a map of <code>value → factory</code>; the matching factory runs once in its own
branch [scope](https://flux.kohl.gg/guide/concepts/scopes) and receives a `value`
accessor. For a keyed branch `value()` is the matched key (fixed for the branch's lifetime); under
`Flux.otherwise` (which mounts for any unmatched value), `value()` tracks the live unmatched value.
Returns a [node](https://flux.kohl.gg/guide/concepts/signals)
usable at a numeric index of [`Flux.new`](https://flux.kohl.gg/guide/roblox/creation#the-flux-new-function) /
[`Flux.edit`](https://flux.kohl.gg/guide/roblox/hydration#the-flux-edit-function).

[Open Documentation](https://flux.kohl.gg/guide/concepts/conditionals#switching-between-many-branches)
]]
local function switch<S>(source: S)
	return function<T>(map: { [Graph.Unwrap<S>]: (value: () -> Graph.Unwrap<S>) -> T }): Node<T?>
		local mounted: any = mount(source, switchSelect, map, nil, nil)
		return mounted
	end
end

--[[
Mounts `component` while `condition` is truthy and keeps it mounted through its exit transition. `component`
receives `(exiting, done)`: when `condition` turns falsy, the branch stays mounted with its boolean `exiting`
[node](https://flux.kohl.gg/guide/concepts/signals) set to `true`, and unmounts once it calls `done()` (ignored
unless exiting), typically when its exit animation settles. A truthy `condition` before then reverses the exit
(`exiting` returns to `false`) instead of remounting. The factory runs once per mount in its own branch
[scope](https://flux.kohl.gg/guide/concepts/scopes), like
[`Flux.show`](https://flux.kohl.gg/guide/concepts/conditionals#showing-one-of-two-branches), and the returned node works
at a numeric index of [`Flux.new`](https://flux.kohl.gg/guide/roblox/creation#the-flux-new-function) /
[`Flux.edit`](https://flux.kohl.gg/guide/roblox/hydration#the-flux-edit-function).

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
Derives a [node](https://flux.kohl.gg/guide/concepts/signals) that is `whenTrue` while `condition` is truthy and
`whenFalse` otherwise (`nil` when omitted): the terse form of
`Flux.computed(function() return if Flux.read(cond) then Flux.read(a) else Flux.read(b) end)`{luau}. Every argument may be a plain
value, a node, or a `() -> T`{luau} getter, and <strong>only the branch actually taken is read</strong>, so the
untaken side never becomes a dependency and never re-runs the derivation.
- Unlike [`Flux.show`](https://flux.kohl.gg/guide/concepts/conditionals#showing-one-of-two-branches) this picks a
  <em>value</em>, not a subtree: nothing is mounted, no branch [scope](https://flux.kohl.gg/guide/concepts/scopes) is
  created, and swapping sides does not rebuild anything.
- Omit `whenFalse` for a value that is present only while `condition` holds.

[Open Documentation](https://flux.kohl.gg/guide/concepts/conditionals#picking-between-values)
]]
local pick = function(condition: unknown, whenTrue: any, whenFalse: any?): Node<any>
	return computed(function(): any
		return if read(condition) then read(whenTrue) else read(whenFalse)
	end)
end :: (<A, B>(condition: unknown, whenTrue: A, whenFalse: B) -> Node<Graph.Unwrap<A> | Graph.Unwrap<B>>) & (<A>(condition: unknown, whenTrue: A) -> Node<Graph.Unwrap<A>?>)

--[[
Derives a [node](https://flux.kohl.gg/guide/concepts/signals) that is `value` while it is non-`nil` and `default`
otherwise: the terse form of
`Flux.computed(function() return Flux.read(value) or default end)`{luau}, and the idiomatic way to give an optional
prop a default. Either argument may be a plain value, a node, or a `() -> T`{luau} getter, and `default` is read
<strong>only</strong> while `value` is `nil`, so it never becomes a dependency otherwise.
- Coalesces on `nil` alone, <strong>not</strong> on falsiness: a `value` of `false` is kept, where `or`{luau} would
  have replaced it with `default`. That is the point of reaching for this over `or`{luau} on a
  `Reactive<boolean>?`{luau} prop.

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
Maps `list` (a plain array, [node](https://flux.kohl.gg/guide/concepts/signals), or getter) by
<strong>index</strong> (<em>unkeyed</em>): `mapFn(index, item)` runs once per position, reusing the mapped result and
passing the item as a reactive [node](https://flux.kohl.gg/guide/concepts/signals) that updates in place as the value
at that index changes. Reach for this over `Flux.forValue` when the array holds primitives, has duplicates, or churns
by position rather than identity.

[Open Documentation](https://flux.kohl.gg/guide/concepts/mapping#flux-forindex-keyed-by-index)
]]
local function forIndex<L, U>(list: L, mapFn: (index: number, item: Node<Item<L>>) -> U): Node<{ U }>
	return createMapper(list, mapFn, false)
end

--[[
Maps `list` (a plain array, [node](https://flux.kohl.gg/guide/concepts/signals), or getter) by
<strong>value</strong> (<em>keyed</em>): `mapFn(index, value)` runs once per unique value, caching each item's mapped
result against the value itself so results stay stable across reorders and only the item's reactive `index`
[node](https://flux.kohl.gg/guide/concepts/signals) updates when it moves. Values must be <strong>unique</strong>:
the value is the cache key, so duplicates collapse onto one mapped instance; for primitives, duplicates, or
position-based churn use `Flux.forIndex` instead.

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
	Reactively reads whether `key` is currently selected, returning a `boolean`.
	Call inside a [computed](https://flux.kohl.gg/guide/concepts/computeds) or
	[effect](https://flux.kohl.gg/guide/concepts/effects) so it re-runs when this key
	gains or loses selection. The shorthand `selector(key)` is equivalent to
	`selector:get(key)`. Each key tracks its own
	[node](https://flux.kohl.gg/guide/concepts/signals), so only the two keys whose
	selection actually flipped re-run; nodes no reaction observes anymore are swept as new keys are read. The
	answer is current even before the next [flush](https://flux.kohl.gg/guide/concepts/effects).

	[Open Documentation](https://flux.kohl.gg/guide/concepts/selectors#reading-a-selection)
	]]
	get: (self: any, key: K) -> boolean,
	--[[
	Tears down the selector: disposes the internal watcher and every per-key
	[node](https://flux.kohl.gg/guide/concepts/signals), then empties the object.
	Call when the source [node](https://flux.kohl.gg/guide/concepts/signals) outlives
	the selector; a selector created inside a
	[scope](https://flux.kohl.gg/guide/concepts/scopes) is cleaned up automatically.

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
Reactively reads whether `key` is currently selected, returning a `boolean`.
Call inside a [computed](https://flux.kohl.gg/guide/concepts/computeds) or
[effect](https://flux.kohl.gg/guide/concepts/effects) so it re-runs when this key
gains or loses selection. The shorthand `selector(key)` is equivalent to
`selector:get(key)`. Each key tracks its own
[node](https://flux.kohl.gg/guide/concepts/signals), so only the two keys whose
selection actually flipped re-run; nodes no reaction observes anymore are swept as new keys are read. The
answer is current even before the next [flush](https://flux.kohl.gg/guide/concepts/effects).

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
Tears down the selector: disposes the internal watcher and every per-key
[node](https://flux.kohl.gg/guide/concepts/signals), then empties the object.
Call when the source [node](https://flux.kohl.gg/guide/concepts/signals) outlives
the selector; a selector created inside a
[scope](https://flux.kohl.gg/guide/concepts/scopes) is cleaned up automatically.

[Open Documentation](https://flux.kohl.gg/guide/concepts/selectors#cleaning-up)
]]
function SelectorMT.Destroy(self: SelectorData)
	if self._watcher ~= nil then
		self._watcher:Destroy()
	end
end

--[[
Creates an <strong>O(1)</strong> keyed selector that tracks which of many keys matches `source` (a
[node](https://flux.kohl.gg/guide/concepts/signals), `() -> S`
[computed](https://flux.kohl.gg/guide/concepts/computeds), or plain value) for row, tab, or focus selection.
The returned object is callable: `selector(key)` reactively reads whether `key` is selected, so flipping the
selection re-runs only the two affected keys instead of every observer. By default keys are compared with `==`,
flipping at most two per-key [node](https://flux.kohl.gg/guide/concepts/signals)s per change
(<strong>O(1)</strong>); passing a custom `equals(sourceValue, key)` comparator re-tests every live key on each
change (<strong>O(live keys)</strong>).

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
	The catch-all key of a `Flux.switch` map: its factory mounts whenever the source matches no other key. Every
	unmatched value shares it, so moving between two unmatched values keeps the branch mounted.

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
	Mounts `component` while `condition` is truthy, swapping to `fallback` (if given) when it
	turns falsy. Re-evaluates only when `condition`'s truthiness flips, not on every value change.
	The chosen factory runs once per mount in its own branch
	[scope](https://flux.kohl.gg/guide/concepts/scopes) (the effects and cleanups it registers are
	torn down automatically on the next swap) and receives a `value` accessor for the live
	`condition` value. Returns a
	[node](https://flux.kohl.gg/guide/concepts/signals) usable at a numeric
	index of [`Flux.new`](https://flux.kohl.gg/guide/roblox/creation#the-flux-new-function) /
	[`Flux.edit`](https://flux.kohl.gg/guide/roblox/hydration#the-flux-edit-function).

	[Open Documentation](https://flux.kohl.gg/guide/concepts/conditionals#showing-one-of-two-branches)
	]]
	show = show :: (<T>(condition: unknown, component: (value: () -> any) -> T) -> Node<T?>) & (<T, F>(
		condition: unknown,
		component: (value: () -> any) -> T,
		fallback: (value: () -> any) -> F
	) -> Node<(T | F)?>),
	--[[
	Identity-keyed variant of [`Flux.show`](https://flux.kohl.gg/guide/concepts/conditionals#keyed-show): instead
	of rebuilding only when `condition`'s truthiness flips, it rebuilds whenever the value's <em>identity</em>
	changes, so swapping one truthy value for another remounts `component` (or `fallback` when falsy) with fresh
	state. The chosen factory runs in its own branch [scope](https://flux.kohl.gg/guide/concepts/scopes) and
	receives a `value` accessor; since the value is fixed for the branch's lifetime, reading `value()` in the
	factory body yields it directly. Mirrors SolidJS's <code>&lt;Show keyed&gt;</code>.

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
