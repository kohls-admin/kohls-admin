local BaseClass = require(script.Parent.BaseClass)
local UI = require(script.Parent)

local ListItem = {}
ListItem.__index = ListItem
setmetatable(ListItem, BaseClass)

function ListItem.new(definition)
	local new = UI.makeStatefulDefaults({
		Text = "ListItem Label",
		ContentAutomaticSize = false,
		ContentListLayout = true,
	}, definition)

	new._content = UI.new "Frame" {
		Name = "UIContent",
		AnchorPoint = Vector2.new(1, 0),
		AutomaticSize = UI.compute(function(use)
			return if use(new.ContentAutomaticSize) then Enum.AutomaticSize.X else Enum.AutomaticSize.None
		end),
		Size = UI.compute(function(use)
			return UDim2.fromScale(if use(new.ContentAutomaticSize) then 0 else 0.5, 1)
		end),
		Position = UDim2.new(1, 0, 0, 0),
		BackgroundTransparency = 1,

		UI.new "UIPadding" {
			PaddingRight = UDim.new(0, 1),
		},
	}

	local layout = UI.new "UIListLayout" {
		Parent = new._content,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UI.Theme.Padding,
	}

	new._layoutParentCompute = UI.compute(function(use)
		layout.Parent = if use(new.ContentListLayout) then new._content else nil
	end)

	new._instance = UI.new "Frame" {
		Name = new.Text._value,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 24),

		UI.new "TextLabel" {
			AutoLocalize = false,
			Text = new.Text,
			Size = UDim2.new(1, 0, 1, 0),
			TextXAlignment = Enum.TextXAlignment.Left,
			RichText = true,
			Font = UI.Theme.Font,
			TextSize = UI.Theme.FontSize,
			TextColor3 = UI.Theme.PrimaryText,
			TextTruncate = Enum.TextTruncate.SplitWord,
			BackgroundTransparency = 1,

			UI.new "UIFlexItem" {
				FlexMode = Enum.UIFlexMode.Fill,
			},
		},

		new._content,
	}

	return setmetatable(new, ListItem)
end

return ListItem
