local UI = require(script.Parent)

local BaseClass = {}
BaseClass.__index = BaseClass

function BaseClass:Destroy()
	for key, value in self do
		if UI.isState(value) or typeof(value) == "Instance" then
			value:Destroy()
		end
	end
end

return BaseClass
