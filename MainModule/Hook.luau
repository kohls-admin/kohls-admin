local Util = require(script.Parent:WaitForChild("Util"))

--- @class Hook
local Hook = {
	log = Util.SignalGood.new(),
	preCommand = Util.SignalGood.new(),
	postCommand = Util.SignalGood.new(),
}

return Hook
