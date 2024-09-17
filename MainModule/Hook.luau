local Util = require(script.Parent:WaitForChild("Util"))

-- TODO: add hooks for auth, registry, etc

--- @class Hook
local Hook = {
	log = Util.Signal.new(),
	logFiltered = Util.Signal.new(),
	preCommand = Util.Signal.new(),
	postCommand = Util.Signal.new(),

	initDataStore = Util.Signal.new(),
	preSyncMain = Util.Signal.new(),
	postSyncMain = Util.Signal.new(),
	preSyncLogs = Util.Signal.new(),
	postSyncLogs = Util.Signal.new(),
}

return Hook
