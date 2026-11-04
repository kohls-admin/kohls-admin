--!strict
--[[
Shared clock for timers, frame callbacks, and deterministic stepping in tests.
Delegates to `os.clock()`, `workspace:GetServerTimeNow()`, `task.*`, and `RunService` in live games, or steps virtual time in manual mode (`Clock.manual(true)`).

```luau
local Clock = Flux.Clock
Clock.manual(true)
Clock.delay(1, function() print("one second later") end)
Clock.step(1) -- advances 1 second in 1/60s frames
```
]]

local IS_ROBLOX = game ~= nil

export type Phase = "PreRender" | "RenderStepped" | "Heartbeat"

local EPOCH = 1767225600 -- 2026-01-01T00:00:00Z
local EPSILON = 1e-9
local DRAIN_LIMIT = 10000

local osClock = os.clock
local engineTask: any = task
local RunService: any = if IS_ROBLOX then game:GetService("RunService") else nil

local manual = not IS_ROBLOX
local virtualNow = 0

--- @ignore
type Timer = {
	due: number,
	seq: number,
	thread: thread,
	start: number?,
	args: { any }?,
	cancelled: boolean?,
}

--- @ignore
type Deferred = {
	thread: thread,
	args: { any }?,
	cancelled: boolean?,
}

local heap: { Timer } = {}
local seq = 0
local timerOf: { [thread]: Timer } = {}

local queue: { Deferred } = {}
local head, tail = 1, 0
local deferredOf: { [thread]: Deferred } = {}

local render: { (dt: number) -> () } = {}
local heartbeat: { (dt: number) -> () } = {}

local frameHook: ((dt: number) -> ())? = nil
local report: (...any) -> () = if IS_ROBLOX then warn else print

local function before(a: Timer, b: Timer): boolean
	return a.due < b.due or (a.due == b.due and a.seq < b.seq)
end

local function push(timer: Timer)
	local index = #heap + 1
	heap[index] = timer
	while index > 1 do
		local parent = index // 2
		if not before(heap[index], heap[parent]) then
			break
		end
		heap[index], heap[parent] = heap[parent], heap[index]
		index = parent
	end
end

local function pop(): Timer
	local top = heap[1]
	local last = table.remove(heap) :: Timer
	local size = #heap
	if size > 0 then
		heap[1] = last
		local index = 1
		while true do
			local left, right, smallest = index * 2, index * 2 + 1, index
			if left <= size and before(heap[left], heap[smallest]) then
				smallest = left
			end
			if right <= size and before(heap[right], heap[smallest]) then
				smallest = right
			end
			if smallest == index then
				break
			end
			heap[index], heap[smallest] = heap[smallest], heap[index]
			index = smallest
		end
	end
	return top
end

local function resume(thread: thread, ...: any)
	if coroutine.status(thread) ~= "suspended" then
		return
	end
	if IS_ROBLOX then
		engineTask.spawn(thread, ...)
		return
	end
	local ok, err = coroutine.resume(thread, ...)
	if not ok then
		report(debug.traceback(thread, `[Flux] Clock: error in a resumed thread: {err}`))
	end
end

local function resumeArgs(thread: thread, args: any)
	if args then
		resume(thread, table.unpack(args, 1, args.n))
	else
		resume(thread)
	end
end

local function toThread(fnOrThread: any): thread
	return if type(fnOrThread) == "thread" then fnOrThread else coroutine.create(fnOrThread)
end

local function scheduleTimer(seconds: number?, thread: thread, start: number?, args: { any }?)
	seq += 1
	local timer: Timer = {
		due = virtualNow + math.max(seconds or 0, 0),
		seq = seq,
		thread = thread,
		start = start,
		args = args,
	}
	timerOf[thread] = timer
	push(timer)
end

local function canWait(): boolean
	if not coroutine.isyieldable() then
		return false
	elseif IS_ROBLOX then
		return true
	end
	local level, bottom = 2, nil
	while true do
		local fn = debug.info(level, "f")
		if fn == nil then
			break
		end
		bottom = fn
		level += 1
	end
	if bottom == nil or debug.info(bottom, "s") == "[C]" then
		return true
	end
	local params, vararg = debug.info(bottom, "a")
	return not (debug.info(bottom, "l") <= 1 and params == 0 and vararg)
end

local Clock = {}

--[[
Seconds on a monotonic clock, for measuring intervals: `os.clock()` in a game, virtual time on a manual clock.
]]
function Clock.now(): number
	return if manual then virtualNow else osClock()
end

--[[
Unix time in seconds, for dates and countdowns shared between players: `workspace:GetServerTimeNow()` in a game,
`2026-01-01T00:00:00Z + now()` on a manual clock.
]]
function Clock.wall(): number
	if manual then
		return EPOCH + virtualNow
	end
	return if IS_ROBLOX then workspace:GetServerTimeNow() else os.time()
end

local function pack(...: any): { any }?
	if select("#", ...) == 0 then
		return nil
	end
	local packed: { any } = table.pack(...)
	return packed
end

--[[
Runs `fn(...)` (or resumes a thread) after `seconds`, like `task.delay`. Returns the thread, for `cancel`.
]]
function Clock.delay<A...>(seconds: number?, fn: ((A...) -> ...any) | thread, ...: A...): thread
	if not manual then
		return engineTask.delay(seconds, fn, ...)
	end
	local thread = toThread(fn)
	scheduleTimer(seconds, thread, nil, pack(...))
	return thread
end

--[[
Yields the running thread for `seconds` (default: one frame), like `task.wait`, and returns the time it waited. On a
manual clock it waits for a `step` to pass the deadline, so it needs a coroutine to yield.
]]
function Clock.wait(seconds: number?): number
	if not manual then
		return engineTask.wait(seconds)
	end
	local thread = coroutine.running()
	if not canWait() then
		error("Clock.wait on a manual clock needs a yieldable coroutine; run it in a thread a step can resume", 2)
	end
	scheduleTimer(seconds, thread, virtualNow, nil)
	return coroutine.yield()
end

--[[
Runs `fn(...)` (or resumes a thread) once the current work finishes, like `task.defer`. On a manual clock it waits for
`drain()` (which every `step` frame calls). Returns the thread, for `cancel`.
]]
function Clock.defer<A...>(fn: ((A...) -> ...any) | thread, ...: A...): thread
	if not manual then
		return engineTask.defer(fn, ...)
	end
	local thread = toThread(fn)
	local entry: Deferred = { thread = thread, args = pack(...) }
	deferredOf[thread] = entry
	tail += 1
	queue[tail] = entry
	return thread
end

--[[
Cancels a thread from `delay`, `defer` or a `wait`, like `task.cancel`.
]]
function Clock.cancel(thread: thread)
	if not manual then
		engineTask.cancel(thread)
		return
	end
	local timer = timerOf[thread]
	if timer then
		timer.cancelled = true
		timer.args = nil
		timerOf[thread] = nil
	end
	local entry = deferredOf[thread]
	if entry then
		entry.cancelled = true
		entry.args = nil
		deferredOf[thread] = nil
	end
	if IS_ROBLOX then
		engineTask.cancel(thread)
	elseif coroutine.status(thread) == "suspended" then
		coroutine.close(thread)
	end
end

--[[
Calls `fn(dt)` every frame at `phase` ("PreRender", "RenderStepped" or "Heartbeat"). Returns a function that
disconnects it. A manual clock calls it from `step` instead of the engine's frames.
]]
function Clock.connect(phase: Phase, fn: (dt: number) -> ()): () -> ()
	local list = if phase == "Heartbeat"
		then heartbeat
		elseif phase == "PreRender" or phase == "RenderStepped" then render
		else error(`Clock.connect: unknown phase "{phase}" (PreRender, RenderStepped or Heartbeat)`, 2)
	if not manual then
		local connection = RunService[phase]:Connect(fn)
		return function()
			connection:Disconnect()
		end
	end
	local entry = function(dt: number)
		fn(dt)
	end
	table.insert(list, entry)
	return function()
		local index = table.find(list, entry)
		if index then
			table.remove(list, index)
		end
	end
end

--[[
Toggles manual clock mode for tests (headless Luau is always manual).
Disabling manual mode clears pending tasks via `Clock.reset()`.
]]
function Clock.manual(on: boolean)
	if not IS_ROBLOX or on == manual then
		return
	end
	if on then
		virtualNow = math.max(virtualNow, osClock())
		manual = true
	else
		Clock.reset()
		manual = false
	end
end

--[[
Tests only: whether the clock is manual.
]]
function Clock.isManual(): boolean
	return manual
end

--[[
Tests only: runs deferred work until none is left, including work it defers in turn. Errors after 10000 calls, when
deferred work keeps deferring more.
]]
function Clock.drain()
	local count = 0
	while head <= tail do
		count += 1
		if count > DRAIN_LIMIT then
			table.clear(queue)
			table.clear(deferredOf)
			head, tail = 1, 0
			error(`Clock.drain: deferred work did not settle after {DRAIN_LIMIT} calls`, 2)
		end
		local entry = queue[head]
		queue[head] = nil
		head += 1
		if not entry.cancelled then
			if deferredOf[entry.thread] == entry then
				deferredOf[entry.thread] = nil
			end
			resumeArgs(entry.thread, entry.args)
		end
	end
	head, tail = 1, 0
end

local function runFrame(dt: number)
	local last = seq
	while heap[1] ~= nil and heap[1].due <= virtualNow + EPSILON and heap[1].seq <= last do
		local timer = pop()
		if not timer.cancelled then
			if timerOf[timer.thread] == timer then
				timerOf[timer.thread] = nil
			end
			if timer.start then
				resume(timer.thread, virtualNow - timer.start)
			else
				resumeArgs(timer.thread, timer.args)
			end
		end
	end
	Clock.drain()
	if #render > 0 then
		for _, subscriber in table.clone(render) do
			subscriber(dt)
		end
		Clock.drain()
	end
	if frameHook then
		frameHook(dt)
		Clock.drain()
	end
	if #heartbeat > 0 then
		for _, subscriber in table.clone(heartbeat) do
			subscriber(dt)
		end
		Clock.drain()
	end
end

--[[
Tests only: advances a manual clock by `seconds`, in frames of at most `frameLength` seconds (default 1/60). `step(0)`
runs one frame of zero length: due timers, subscribers, a Flux step and the deferred work.
]]
function Clock.step(seconds: number, frameLength: number?)
	if not manual then
		error("Clock.step needs a manual clock; call Clock.manual(true) first", 2)
	end
	local length = frameLength or 1 / 60
	assert(seconds >= 0, "Clock.step: seconds must not be negative")
	assert(length > 0, "Clock.step: the frame length must be positive")
	local start = virtualNow
	local frames = math.max(math.ceil(seconds / length - EPSILON), 1)
	for index = 1, frames do
		local target = if index == frames then start + seconds else start + index * length
		local dt = target - virtualNow
		virtualNow = target
		runFrame(dt)
	end
end

--[[
Tests only: drops every pending timer, `wait`, deferred call and manual subscriber. `now` keeps its value.
]]
function Clock.reset()
	table.clear(heap)
	table.clear(timerOf)
	table.clear(queue)
	table.clear(deferredOf)
	head, tail = 1, 0
	table.clear(render)
	table.clear(heartbeat)
end

-- Internal, not part of `Flux.Clock`: init.luau installs the Flux frame step, Compat routes errors through its `warn`
-- and runs its headless `task.spawn` through `resume`.
--- @ignore
Clock._internal = table.freeze({
	setFrame = function(fn: ((dt: number) -> ())?)
		frameHook = fn
	end,
	setReport = function(fn: (message: string) -> ())
		report = fn
	end,
	spawn = function(fnOrThread: any, ...: any): thread
		local thread = toThread(fnOrThread)
		resume(thread, ...)
		return thread
	end,
})

return table.freeze(Clock)
