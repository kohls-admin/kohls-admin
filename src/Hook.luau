local Util = require(script.Parent:WaitForChild("Util"))

-- TODO: add hooks for auth, registry, etc

--- @class Hook
local Hook = {
	log = Util.Signal.new(),
	commandRegistered = Util.Signal.new(),
	preCommand = Util.Signal.new(),
	postCommand = Util.Signal.new(),
	runPreparedCommands = Util.Signal.new(),
	roleAdded = Util.Signal.new(),
	roleRemoved = Util.Signal.new(),

	init = Util.Signal.new(),
	initDataStore = Util.Signal.new(),
	preSyncBans = Util.Signal.new(),
	postSyncBans = Util.Signal.new(),
	preSyncMain = Util.Signal.new(),
	postSyncMain = Util.Signal.new(),
	preSyncLogs = Util.Signal.new(),
	postSyncLogs = Util.Signal.new(),
}

return Hook
