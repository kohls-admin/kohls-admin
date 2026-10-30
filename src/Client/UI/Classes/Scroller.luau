local UI = require(script.Parent.Parent)
local BaseClass = require(script.Parent:WaitForChild("BaseClass"))

local DEFAULT = {}

type Properties = typeof(DEFAULT) & ScrollingFrame

local Class = {}
Class.__index = Class
setmetatable(Class, BaseClass)

function Class.new(properties: Properties?)
	local self = table.clone(DEFAULT)
	UI.makeStatefulDefaults(self, properties)

	-- PaddingRight follows a signal so a resize only writes it, instead of re-editing the UIPadding each time
	local scrollBarShown = UI.signal(false)
	local padding = UI.padding {
		y = UI.Theme.PaddingWithStroke,
		left = UI.Theme.PaddingStroke,
		right = function()
			return if scrollBarShown() then UI.Theme.PaddingWithStroke() else UDim.new()
		end,
	}

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

		UI.list { gap = UI.Theme.Padding },
		padding,

		_CanvasPosition = UI.clearActiveStates,
	} :: ScrollingFrame & { UIListLayout: UIListLayout, UIPadding: UIPadding }

	local function updatePadding()
		scrollBarShown(self._instance.AbsoluteCanvasSize.Y > self._instance.AbsoluteWindowSize.Y)
		if not UI.isReactive() then
			UI.flush()
		end
	end
	updatePadding()

	UI.edit(padding)({
		__CLEAN = {
			scrollBarShown,
			self._instance:GetPropertyChangedSignal("AbsoluteWindowSize"):Connect(updatePadding),
			self._instance:GetPropertyChangedSignal("AbsoluteCanvasSize"):Connect(updatePadding),
		},
	})

	return setmetatable(self, Class) :: typeof(self) & typeof(Class)
end

return Class
