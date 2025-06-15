local BaseClass = require(script.Parent.BaseClass)
local UI = require(script.Parent.Parent)

local ListItem = {}
ListItem.__index = ListItem
setmetatable(ListItem, BaseClass)

function ListItem.new(definition)
	local new = UI.makeStatefulDefaults({
		Text = "ListItem Label",
		ContentAutomaticSize = true,
		ContentListLayout = true,
	}, definition)

	new._content = UI.new "Frame" {
		Name = "UIContent",
		AnchorPoint = Vector2.new(1, 0),
		AutomaticSize = function(use)
			return if use(new.ContentAutomaticSize) then Enum.AutomaticSize.XY else Enum.AutomaticSize.Y
		end,
		Size = function(use)
			return UDim2.fromScale(if use(new.ContentAutomaticSize) then 0 else 0.5, 0)
		end,
		Position = UDim2.new(1, 0, 0, 0),
		BackgroundTransparency = 1,

		UI.new "UIPadding" {
			PaddingRight = UDim.new(0, 1),
		},
	}

	local layout = UI.new "UIListLayout" {
		Parent = new._content,
		HorizontalAlignment = function(use)
			return if use(new.ContentAutomaticSize)
				then Enum.HorizontalAlignment.Left
				else Enum.HorizontalAlignment.Right
		end,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UI.Theme.Padding,
	}

	new._layoutParentCompute = UI.compute(function(use)
		layout.Parent = if use(new.ContentListLayout) then new._content else nil
	end)

	new._instance = UI.new "Frame" {
		Name = new.Text._value,
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),

		UI.new "TextLabel" {
			AutoLocalize = false,
			AutomaticSize = Enum.AutomaticSize.Y,
			AnchorPoint = Vector2.new(0, 0.5),
			Text = new.Text,
			Size = UDim2.new(1, 0, 0, 0),
			Position = UDim2.fromScale(0, 0.5),
			TextXAlignment = Enum.TextXAlignment.Left,
			RichText = true,
			Font = UI.Theme.Font,
			TextSize = UI.Theme.FontSize,
			TextColor3 = UI.Theme.PrimaryText,
			TextStrokeColor3 = UI.Theme.Primary,
			TextStrokeTransparency = UI.Theme.TextStrokeTransparency,
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
