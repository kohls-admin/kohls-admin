local Class = require(script.Parent)

local Object
Object = Instance.new("Frame", Object)
Object.Name = "Divider"
Object.BorderSizePixel = 0
Object.BackgroundColor3 = Color3.new(1, 1, 1)
Object.Size = UDim2.new(1, 0, 0, 1)

return Class:Create({
	_name = "Divider",
	_super = "BaseClass",
	_init = function(self)
		self:rawset("_rbx", Object:Clone()) -- read-only
		self.ThemeData[self._rbx] = { BackgroundColor3 = "Secondary" }
	end,
})
