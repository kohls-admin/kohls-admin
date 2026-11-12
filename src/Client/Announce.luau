local _K = require(script.Parent.Parent)
local Notify = require(script.Parent:WaitForChild("Notify"))

return function(dialogOverride)
	if type(dialogOverride) ~= "table" then
		return
	end
	dialogOverride = table.clone(dialogOverride)
	dialogOverride.Announce = true
	return Notify(dialogOverride)
end
