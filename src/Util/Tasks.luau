--- A utility for managing concurrent tasks and awaiting their completion.
--- @class Tasks
local Tasks = {}
Tasks.__index = Tasks

type self = {
	_numTasks: number,
	_results: { any },
	_returnFirstResult: boolean,
	_running: thread,
	_waiting: boolean,
}

export type Tasks = typeof(setmetatable({} :: self, Tasks))

--- Creates a new Tasks instance.
function Tasks.new(): Tasks
	return setmetatable({
		_numTasks = 0,
		_results = {},
		_returnFirstResult = false,
		_running = coroutine.running(),
		_waiting = false,
	}, Tasks)
end

local function _run(self: Tasks, callback: (...any) -> ...any, ...: any)
	local result = { pcall(callback, ...) }
	self._numTasks -= 1

	if not result[1] then
		warn("Tasks: Task failed with error:", result[2])
	end

	if self._waiting then
		table.insert(self._results, result)
		if self._returnFirstResult or self._numTasks == 0 then
			self._waiting = false
			task.spawn(self._running, if self._returnFirstResult then result else self._results)
		end
	end
end

--- Adds a new task to be executed concurrently.
function Tasks.add(self: Tasks, callback: (...any) -> ...any, ...: any)
	assert(typeof(callback) == "function", "Callback must be a function")
	self._numTasks += 1
	task.defer(_run, self, callback, ...)
end

--- Waits for all tasks to complete, returning the results in a list.
function Tasks.wait(self: Tasks): { { any } }?
	if self._numTasks > 0 then
		self._waiting = true
		return coroutine.yield()
	end
	return
end

--- Waits for the first task to complete, returning the function's success and its results.
function Tasks.waitForFirst(self: Tasks): (boolean, ...any)
	self._returnFirstResult = true
	return unpack(self:wait())
end

return Tasks
