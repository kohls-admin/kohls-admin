local UI = require(script.Parent.Parent) :: any
local BaseClass = require(script.Parent:WaitForChild("BaseClass"))

local DEFAULT = {}

type Properties = typeof(DEFAULT) & UIStroke

local Class = {}
Class.__index = Class
setmetatable(Class, BaseClass)

function Class.new(properties: Properties?)
	local self = table.clone(DEFAULT)
	UI.makeStatefulDefaults(self, properties)

	self._instance = UI.new "UIStroke" {
		Enabled = UI.Theme.StrokeEnabled,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Transparency = UI.Theme.TransparencyLight,
		Color = Color3.new(1, 1, 1),

		UI.new "UIGradient" {
			Color = function()
				return ColorSequence.new(UI.Theme.Border(), UI.Theme.BorderStop())
			end,
			Rotation = UI.Theme.BorderAngle,
		},
	} :: UIStroke

	return setmetatable(self, Class) :: typeof(self) & typeof(Class)
end

return Class
