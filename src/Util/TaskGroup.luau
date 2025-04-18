--- A utility for managing concurrent tasks and awaiting their completion.
--- @class TaskGroup
local TaskGroup = {}
TaskGroup.__index = TaskGroup

export type TaskGroup = {
	numTasks: number,
	running: thread,
	yielding: boolean?,
	new: () -> TaskGroup,
	add: (self: TaskGroup, callback: (...any) -> ...any, ...any) -> (),
}

--- Creates a new TaskGroup instance.
function TaskGroup.new(): TaskGroup
	return setmetatable({
		numTasks = 0,
		running = coroutine.running(),
		yielding = false,
	}, TaskGroup) :: any
end

--- Adds a new task to be executed concurrently.
function TaskGroup:add(callback: (...any) -> ...any, ...: any)
	assert(typeof(callback) == "function", "Callback must be a function")

	self.numTasks += 1
	task.defer(function(...)
		local success, err = pcall(callback, ...)
		self.numTasks -= 1

		if not success then
			warn("TaskGroup: Task failed with error:", err)
		end

		if self.yielding and self.numTasks == 0 then
			self.yielding = false
			task.spawn(self.running)
		end
	end, ...)
end

--- Waits for all tasks to complete.
function TaskGroup:wait()
	if self.numTasks > 0 then
		self.yielding = true
		coroutine.yield()
	end
end

return TaskGroup
