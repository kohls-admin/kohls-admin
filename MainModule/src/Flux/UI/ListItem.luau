local BaseClass = require(script.Parent.BaseClass)
local UI = require(script.Parent)

local ListItem = {}
ListItem.__index = ListItem
setmetatable(ListItem, BaseClass)

function ListItem.new(definition)
	local new = UI.makeStatefulDefaults({
		Text = "ListItem Label",
	}, definition)

	new._instance = UI.new "Frame" {
		Name = "ListItem",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 32),

		UI.new "TextLabel" {
			Text = new.Text,
			Size = UDim2.new(0.5, 0, 1, 0),
			TextXAlignment = Enum.TextXAlignment.Left,
			Font = UI.Theme.Font,
			TextSize = UI.Theme.FontSize,
			TextColor3 = UI.Theme.PrimaryText,
			TextTruncate = Enum.TextTruncate.AtEnd,
			BackgroundTransparency = 1,
		},

		UI.new "Frame" {
			Name = "UIContent",
			AnchorPoint = Vector2.new(1, 0),
			Size = UDim2.new(0.5, 0, 1, 0),
			Position = UDim2.new(1, 0, 0, 0),
			BackgroundTransparency = 1,
		},
	}

	return setmetatable(new, ListItem)
end

return ListItem
