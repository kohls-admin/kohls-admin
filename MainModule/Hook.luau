local Util = require(script.Parent:WaitForChild("Util"))

local Hook = {
	log = Util.SignalGood.new(),
	preCommand = Util.SignalGood.new(),
	postCommand = Util.SignalGood.new(),
}

return Hook
