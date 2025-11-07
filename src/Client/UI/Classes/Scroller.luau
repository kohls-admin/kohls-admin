local UI = require(script.Parent.Parent) :: any
local BaseClass = require(script.Parent.BaseClass)

local DEFAULT = {}

type Properties = typeof(DEFAULT) & ScrollingFrame

local Class = {}
Class.__index = Class
setmetatable(Class, BaseClass)

function Class.new(properties: Properties?)
	local self = table.clone(DEFAULT)
	UI.makeStatefulDefaults(self, properties)

	self._instance = UI.new "ScrollingFrame" {
		Name = "Scroller",
		BorderSizePixel = 0,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0),
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = UI.Theme.Secondary,
		ScrollBarImageTransparency = UI.Theme.TransparencyClamped,
		TopImage = UI.Theme.ScrollTopImage,
		MidImage = UI.Theme.ScrollMidImage,
		BottomImage = UI.Theme.ScrollBottomImage,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,

		UI.new "UIListLayout" { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UI.Theme.Padding },

		[UI.Event] = {
			CanvasPosition = UI.clearActiveStates,
		},
	} :: ScrollingFrame & { UIListLayout: UIListLayout, UIPadding: UIPadding }

	local canvasAbsolute = UI.state(self._instance, "AbsoluteCanvasSize")
	local windowAbsolute = UI.state(self._instance, "AbsoluteWindowSize")

	UI.new "UIPadding" {
		Parent = self._instance,
		PaddingBottom = UI.Theme.Padding,
		PaddingTop = UI.Theme.Padding,
		PaddingLeft = UDim.new(0, 1),
		PaddingRight = function()
			return if canvasAbsolute().Y > windowAbsolute().Y then UI.Theme.Padding() else UDim.new(0, 1)
		end,
	}

	return setmetatable(self, Class) :: typeof(self) & typeof(Class)
end

return Class
