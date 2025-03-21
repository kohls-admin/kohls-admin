local BaseClass = require(script.Parent.BaseClass)
local UI = require(script.Parent.Parent)

local Scroller = {}
Scroller.__index = Scroller
setmetatable(Scroller, BaseClass)

function Scroller.new(definition)
	local new = UI.makeStatefulDefaults({}, definition)

	new._instance = UI.new "ScrollingFrame" {
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

		[UI.Event.Property] = {
			CanvasPosition = function()
				UI.clearState("hover")
				UI.clearState("floating")
			end,
		},
	}

	local canvasAbsolute = UI.state(new._instance, "AbsoluteCanvasSize")
	local windowAbsolute = UI.state(new._instance, "AbsoluteWindowSize")

	UI.new "UIPadding" {
		Parent = new._instance,
		PaddingRight = UI.compute(function(use)
			return if use(canvasAbsolute).Y > use(windowAbsolute).Y then use(UI.Theme.Padding) else UDim.new()
		end),
	}

	return setmetatable(new, Scroller)
end

return Scroller
