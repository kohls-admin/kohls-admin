local BaseClass = require(script.Parent.BaseClass)
local UI = require(script.Parent.Parent)

local ListItem = {}
ListItem.__index = ListItem
setmetatable(ListItem, BaseClass)

function ListItem.new(definition)
	local new = UI.makeStatefulDefaults({
		Text = "ListItem",
		ContentAutomaticSize = true,
		ContentListLayout = true,
		Tooltip = UI.Nil,
	}, definition)

	new._label = UI.new "TextLabel" {
		AutoLocalize = false,
		AutomaticSize = Enum.AutomaticSize.XY,
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.new(0, 0, 0, 0),
		Font = UI.Theme.Font,
		RichText = true,
		Text = new.Text,
		TextColor3 = UI.Theme.PrimaryText,
		TextSize = UI.Theme.FontSize,
		TextStrokeColor3 = UI.Theme.Primary,
		TextStrokeTransparency = UI.Theme.TextStrokeTransparency,
		TextXAlignment = Enum.TextXAlignment.Left,
	}

	local labelSize = UI.state(new._label, "AbsoluteSize")
	local automaticSize = function()
		return new.ContentAutomaticSize() and Enum.AutomaticSize.Y or Enum.AutomaticSize.None
	end

	new._content = UI.new "Frame" {
		Name = "UIContent",
		AnchorPoint = Vector2.new(1, 0),
		AutomaticSize = automaticSize,
		Size = function()
			return UDim2.new(1, -labelSize().X - UI.Theme.Padding().Offset, new.ContentAutomaticSize() and 0 or 1, 0)
		end,
		Position = UDim2.new(1, 0, 0, 0),
		BackgroundTransparency = 1,

		UI.new "UIPadding" {
			PaddingRight = UDim.new(0, 1),
		},
	}

	local layout = UI.new "UIListLayout" {
		Parent = new._content,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UI.Theme.Padding,
	}

	new._layoutParentCompute = UI.compute(function()
		layout.Parent = if new.ContentListLayout() then new._content else nil
	end)

	new._instance = UI.new "Frame" {
		Name = new.Text._value,
		AutomaticSize = automaticSize,
		BackgroundTransparency = 1,
		Size = function()
			return UDim2.new(1, 0, 0, new.ContentAutomaticSize() and 0 or labelSize().Y + UI.Theme.Padding().Offset)
		end,
		new._label,
		new._content,
		if new.Tooltip then UI.new "Tooltip" { Text = new.Tooltip } else nil,
	}

	return setmetatable(new, ListItem)
end

return ListItem
