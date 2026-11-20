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
local isolate = Graph.isolate
local raw = Graph.raw
local read = Graph.read
local signal = Graph.signal
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
	_effectRan: boolean,
	_preFlushHandled: boolean,
	_preFlushInput: any,
}

local function sameInput(a: any, b: any): boolean
	return a == b or (a ~= a and b ~= b)
end

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
	isolate(task.spawn, runFetcher, self, input, currentId, refetching)
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
		_effectRan = false,
		_preFlushHandled = false,
		_preFlushInput = nil,
	}, Async)

	self._effect = effect(function()
		local input = read(src)
		if not self._effectRan then
			self._effectRan = true
			if self._preFlushHandled and (src == nil or sameInput(input, self._preFlushInput)) then
				return
			end
		end
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
	if not self._effectRan then
		self._preFlushHandled = true
		self._preFlushInput = raw(self._src)
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
	if not self._effectRan then
		self._preFlushHandled = true
		self._preFlushInput = input
	end
	trigger(self, input, if refetching == nil then true else refetching)
end

--- @ignore
type function NonFunction(t: type): type
	if t:is("function") then
		return types.never
	elseif not t:is("union") then
		return t
	end
	local parts = {}
	for _, part in t:components() do
		if not part:is("function") then
			table.insert(parts, part)
		end
	end
	return if #parts == 0 then types.never elseif #parts == 1 then parts[1] else types.unionof(table.unpack(parts))
end

--[[
Runs yielding work off the reactive graph and exposes its progress as `.data`, `.error`, `.loading`, and `.state` nodes.
`fetcher(value, previous, refetching)` runs untracked whenever `source` is truthy, and stale in-flight results are discarded automatically.

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
) -> Async<T>) & (<T>(
	fetcher: (value: nil, previous: T?, refetching: any) -> T,
	initialValue: NonFunction<T>?
) -> Async<T>)

return table.freeze(Async)
