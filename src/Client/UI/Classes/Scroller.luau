local UI = require(script.Parent.Parent) :: any
local BaseClass = require(script.Parent:WaitForChild("BaseClass"))

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

	local padding = UI.new "UIPadding" {
		Parent = self._instance,
		PaddingBottom = UI.Theme.PaddingWithStroke,
		PaddingTop = UI.Theme.PaddingWithStroke,
		PaddingLeft = UI.Theme.PaddingStroke,
		PaddingRight = UI.Theme.PaddingWithStroke,
	}

	local function updatePadding()
		UI.edit(padding, {
			PaddingRight = if self._instance.AbsoluteCanvasSize.Y > self._instance.AbsoluteWindowSize.Y
				then UI.Theme.PaddingWithStroke
				else UDim.new(),
		})
	end
	updatePadding()

	UI.edit(padding, {
		[UI.Clean] = {
			self._instance:GetPropertyChangedSignal("AbsoluteWindowSize"):Connect(updatePadding),
			self._instance:GetPropertyChangedSignal("AbsoluteCanvasSize"):Connect(updatePadding),
		},
	})

	return setmetatable(self, Class) :: typeof(self) & typeof(Class)
end

return Class
