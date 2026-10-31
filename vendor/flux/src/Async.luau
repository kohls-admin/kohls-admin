--!strict
--[[
Async resources: a fetcher runs off the graph, and its progress is exposed as nodes (`data`, `error`, `loading`,
`state`). A race guard keeps only the latest fetch's result.

```luau
local profile = Flux.async(userId, function(id) return fetchProfile(id) end)
```
]]

local Compat = require("./Compat")
local Graph = require("./Graph")

local effect = Graph.effect
local raw = Graph.raw
local read = Graph.read
local signal = Graph.signal
local untrack = Graph.untrack
local retrack = Graph.retrack
local task = Compat.task

local function gatedOff(src: any, input: any): boolean
	return src ~= nil and (input == nil or input == false)
end

--[[
The state of an [async](https://flux.kohl.gg/guide/concepts/async) node, derived from its `.error`/`.loading` and whether a fetch has resolved.
- `unresolved` (nothing fetched yet)
- `pending` (first fetch in flight, no value)
- `refreshing` (fetch in flight over an existing value)
- `ready` (resolved)
- `errored` (last fetch threw)
]]
export type AsyncState = "unresolved" | "pending" | "ready" | "refreshing" | "errored"

-- An async resource: its progress as nodes, and `refetch`, `mutate` and `Destroy`.
export type Async<T> = {
	data: Graph.Node<T?>,
	error: Graph.Node<string?>,
	loading: Graph.Node<boolean>,
	state: Graph.Node<AsyncState>,
	--[[
	Destroys the async node, cleaning up all resources.

	[Open Documentation](https://flux.kohl.gg/guide/concepts/async)
	]]
	Destroy: (self: any) -> (),
	--[[
	Re-runs the fetcher with the current source value without writing the source node.
	An optional `refetching` payload is forwarded to the fetcher (defaults to `true`).

	[Open Documentation](https://flux.kohl.gg/guide/concepts/async)
	]]
	refetch: (self: any, refetching: any?) -> (),
	--[[
	Optimistically writes `data` and invalidates any in-flight fetch.

	[Open Documentation](https://flux.kohl.gg/guide/concepts/async)
	]]
	mutate: (self: any, value: T) -> (),
}

--- @ignore
type Data = {
	data: Graph.Node<any>,
	error: Graph.Node<string?>,
	loading: Graph.Node<boolean>,
	state: Graph.Node<AsyncState>,
	_resolved: boolean,
	_effect: Graph.Node<any>,
	_src: any,
	_fetcher: any,
	_fetchId: number,
}

local function runFetcher(self: Data, input: any, currentId: number, refetching: any)
	local ok, result = pcall(self._fetcher, input, raw(self.data), refetching)
	if currentId ~= self._fetchId then
		return
	end
	self.loading:set(false)
	if ok then
		self._resolved = true
		self.data:set(result)
		self.state:set("ready")
	else
		self.error:set(tostring(result))
		self.state:set("errored")
	end
end

local function trigger(self: Data, input: any, refetching: any)
	self._fetchId += 1
	local currentId = self._fetchId
	self.loading:set(true)
	self.error:set(nil)
	self.state:set(if self._resolved then "refreshing" else "pending")
	untrack()
	task.spawn(runFetcher, self, input, currentId, refetching)
	retrack()
end

local Async = {}
Async.__index = Async

local function new(source: any, fetcher: any, initialValue: any): Async<any>
	local src: any = source
	local fetch: any = fetcher
	local init: any = initialValue
	if type(fetch) ~= "function" then
		src, fetch, init = nil, source, fetcher
	end

	local self: any = setmetatable({
		data = signal(init),
		error = signal(nil :: string?),
		loading = signal(false),
		state = signal("unresolved" :: AsyncState),
		_resolved = false,
		_effect = nil,
		_src = src,
		_fetcher = fetch,
		_fetchId = 0,
	}, Async)

	self._effect = effect(function()
		local input = read(src)
		if gatedOff(src, input) then
			self._fetchId += 1
			self.loading:set(false)
			self.error:set(nil)
			self.state:set(if self._resolved then "ready" else "unresolved")
			return
		end
		trigger(self, input, false)
	end)

	if Graph.getOwner() then
		Graph.cleanup(self)
	end

	return self
end

--[[
Destroys the async node, cleaning up all resources.

[Open Documentation](https://flux.kohl.gg/guide/concepts/async)
]]
function Async.Destroy(self: Data)
	if self._effect == nil then
		return
	end
	self.state:Destroy()
	self.data:Destroy()
	self.error:Destroy()
	self.loading:Destroy()
	self._effect:Destroy()
	local nextId = self._fetchId + 1
	local rawSelf: any = self
	table.clear(rawSelf)
	self._fetchId = nextId
end

--[[
Optimistically writes `data` and invalidates any in-flight fetch.

[Open Documentation](https://flux.kohl.gg/guide/concepts/async)
]]
function Async.mutate(self: Data, value: any)
	if self._effect == nil then
		return
	end
	self._fetchId += 1
	self._resolved = true
	self.loading:set(false)
	self.error:set(nil)
	self.data:set(value)
	self.state:set("ready")
end

--[[
Re-runs the fetcher with the current source value without writing the source node.
An optional `refetching` payload is forwarded to the fetcher (defaults to `true`).

[Open Documentation](https://flux.kohl.gg/guide/concepts/async)
]]
function Async.refetch(self: Data, refetching: any?)
	if self._effect == nil then
		return
	end
	local src = self._src
	local input = raw(src)
	if gatedOff(src, input) then
		return
	end
	trigger(self, input, if refetching == nil then true else refetching)
end

--[[
Creates a non-blocking asynchronous [node](https://flux.kohl.gg/guide/concepts/signals) that runs yielding
work off the reactive graph and exposes its progress as four nodes: `.data` (seeded with `initialValue` before
the first fetch resolves), `.error`, `.loading`, and `.state`. `source` is a tracked input (a
[node](https://flux.kohl.gg/guide/concepts/signals) or computation) whose value is passed to `fetcher` and
re-runs it on every change; omit `source` and pass `fetcher` first for a one-shot fetch, or let `source`
evaluate to `nil`/`false` to gate the fetch off until it turns truthy. `fetcher(value, previous, refetching)`
runs untracked (where `previous` is the last resolved data and `refetching` flags a manual refetch, so reactive
reads inside it are <strong>not</strong> tracked as dependencies), and a race guard discards stale results so
only the latest fetch ever writes back.

```luau
local profile = Flux.async(userId, function(id) return Players:GetNameFromUserIdAsync(id) end)
Flux.new "TextLabel" { Text = function() return profile.data() or "Loading" end }
```

[Open Documentation](https://flux.kohl.gg/guide/concepts/async#creating-an-async-node)
]]
Async.new = new :: (<S, T>(
	source: S,
	fetcher: (value: Graph.Unwrap<S>, previous: T?, refetching: any) -> T,
	initialValue: T?
) -> Async<T>) & (<T>(fetcher: (value: nil, previous: T?, refetching: any) -> T, initialValue: T?) -> Async<T>)

return table.freeze(Async)
