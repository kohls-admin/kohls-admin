local UI = require(script.Parent.Parent) :: any
local BaseClass = require(script.Parent:WaitForChild("BaseClass"))

local DEFAULT = {}

type Properties = typeof(DEFAULT) & Frame

local Class = {}
Class.__index = Class
setmetatable(Class, BaseClass)

function Class.new(properties: Properties?)
	local self = table.clone(DEFAULT)
	UI.makeStatefulDefaults(self, properties)

	self._instance = UI.new "Frame" {
		Name = "Spacer",
		BackgroundTransparency = 1,

		UI.new "UIFlexItem" {
			FlexMode = Enum.UIFlexMode.Fill,
		},
	} :: Frame & { UIFlexItem: UIFlexItem }

	return setmetatable(self, Class) :: typeof(self) & typeof(Class)
end

return Class
