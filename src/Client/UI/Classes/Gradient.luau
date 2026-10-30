local UI = require(script.Parent.Parent)
local BaseClass = require(script.Parent:WaitForChild("BaseClass"))

local DEFAULT = {
	Enabled = UI.Theme.BackgroundGradientEnabled,
	Start = UI.Theme.BackgroundGradient,
	Stop = UI.Theme.BackgroundGradientStop,
	Rotation = UI.Theme.BackgroundGradientAngle,
}

type Properties = typeof(DEFAULT) & UIGradient

local Class = {}
Class.__index = Class
setmetatable(Class, BaseClass)

function Class.new(properties: Properties?)
	local self = table.clone(DEFAULT)
	UI.makeStatefulDefaults(self, properties)

	self._instance = UI.gradient {
		color = function()
			return ColorSequence.new(self.Start(), self.Stop())
		end,
		enabled = self.Enabled,
		rotation = self.Rotation,
	} :: UIGradient

	return setmetatable(self, Class) :: typeof(self) & typeof(Class)
end

return Class
