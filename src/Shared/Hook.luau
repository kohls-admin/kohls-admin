local Util = require(script.Parent:WaitForChild("Util"))

--[[
	Signals games and addons can connect to. Signal:Fire runs every handler in its own thread (task.spawn), so a
	handler can't stop or change what fired it: preCommand only observes a command, use Process.addCommandFilter to
	block one or drop its targets.

	preSyncMain and postSyncMain fire around loading the saved members and settings and around every update of them
	from other servers, with the incoming changes and then the Data module. preSyncLogs and postSyncLogs do the same
	for logs, with the incoming logs.
]]

--- @class Hook
local Hook = {
	log = Util.Signal.new(),
	commandRegistered = Util.Signal.new(),
	preCommand = Util.Signal.new(),
	postCommand = Util.Signal.new(),
	runPreparedCommands = Util.Signal.new(),
	ban = Util.Signal.new(),
	unban = Util.Signal.new(),
	roleAdded = Util.Signal.new(),
	roleRemoved = Util.Signal.new(),
	authChanged = Util.Signal.new(),

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
