local _K = require(script.Parent.Parent)
local Notify = require(script.Parent:WaitForChild("Notify"))

return function(dialogOverride)
	return Notify(_K.Util.Table.merge(dialogOverride, { Announce = true }))
end
