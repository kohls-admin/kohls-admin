local BaseClass = {}
BaseClass.__index = BaseClass

function BaseClass:Destroy()
	for key, value in self do
		if typeof(value) == "Instance" then
			value:Destroy()
		end
	end
end

return BaseClass
