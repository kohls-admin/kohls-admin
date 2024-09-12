local Util = require(script.Parent:WaitForChild("Util"))

--- @class Hook
local Hook = {
	log = Util.SignalGood.new(),
	preCommand = Util.SignalGood.new(),
	postCommand = Util.SignalGood.new(),

	initDataStore = Util.SignalGood.new(),
	preSyncMain = Util.SignalGood.new(),
	postSyncMain = Util.SignalGood.new(),
	preSyncLogs = Util.SignalGood.new(),
	postSyncLogs = Util.SignalGood.new(),
}

return Hook
