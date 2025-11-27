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
		TopImage = UI.Theme.ScrollMidImage,
		MidImage = UI.Theme.ScrollMidImage,
		BottomImage = UI.Theme.ScrollMidImage,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,

		UI.new "UIListLayout" { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UI.Theme.Padding },

		[UI.Event] = {
			CanvasPosition = UI.clearActiveStates,
		},
	} :: ScrollingFrame & { UIListLayout: UIListLayout, UIPadding: UIPadding }

	UI.new "UIPadding" {
		Parent = self._instance,
		PaddingBottom = UI.Theme.PaddingWithStroke,
		PaddingTop = UI.Theme.PaddingWithStroke,
		PaddingLeft = UI.Theme.PaddingStroke,
		PaddingRight = UI.Theme.PaddingWithStroke,
	}

	return setmetatable(self, Class) :: typeof(self) & typeof(Class)
end

return Class
