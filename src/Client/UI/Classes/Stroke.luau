local UI = require(script.Parent.Parent) :: any
local BaseClass = require(script.Parent.BaseClass)

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
		Color = UI.Theme.Border,

		UI.new "UIGradient" {
			Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(1, 1, 1)),
			Transparency = NumberSequence.new(1, 0),
			Rotation = -90,
		},
	} :: UIStroke

	return setmetatable(self, Class) :: typeof(self) & typeof(Class)
end

return Class
