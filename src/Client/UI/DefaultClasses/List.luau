local BaseClass = require(script.Parent.BaseClass)
local UI = require(script.Parent.Parent)

local List = {}
List.__index = List
setmetatable(List, BaseClass)

function List.new(definition)
	local new = UI.makeStatefulDefaults({
		Collapsible = false,
		Label = "New List",
		Padding = UI.Theme.Padding,
	}, definition)

	local listLayout = UI.new "UIListLayout" {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = new.Padding,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		VerticalAlignment = Enum.VerticalAlignment.Top,
	}

	local collapsed = UI.state(false)
	local contentSize = UI.state(listLayout, "AbsoluteContentSize")

	new._instance = UI.new "Frame" {
		Name = "List",
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Size = UI.tween(function()
			return UDim2.new(
				1,
				0,
				0,
				if collapsed()
					then UI.Theme.FontSize()
					else contentSize().Y + UI.Theme.FontSize() + UI.Theme.Padding().Offset
			)
		end, UI.Theme.TweenOut),

		UI.new "TextButton" {
			AutoLocalize = false,
			Name = "Header",
			Active = true,
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			TextTransparency = 1,
			Text = "",
			Size = UDim2.new(1, 0, 0, 0),

			UI.new "ImageLabel" {
				Name = "Arrow",
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 0, 0.5, 0),
				Size = UDim2.new(0.75, 0, 0.75, 0),
				Image = UI.Theme.Image.Down,
				ImageColor3 = UI.Theme.PrimaryText,
				ImageTransparency = 0.5,
				Visible = new.Collapsible,
				Rotation = UI.tween(function()
					return if collapsed() then -90 else 0
				end, UI.Theme.TweenOut),

				UI.new "UIAspectRatioConstraint" {},
			},

			UI.new "TextLabel" {
				AutoLocalize = false,
				Name = "Label",
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				Position = function()
					return UDim2.new(0, if new.Collapsible() then UI.Theme.FontSize() else UI.Theme.Padding(), 0, 0)
				end,
				Size = function()
					return UDim2.new(1, -UI.Theme.FontSize(), 0, 0)
				end,
				FontFace = UI.Theme.FontBold,
				Text = function()
					return string.upper(new.Label())
				end,
				TextSize = UI.Theme.FontSize,
				TextColor3 = UI.Theme.PrimaryText,
				TextStrokeColor3 = UI.Theme.Primary,
				TextStrokeTransparency = UI.Theme.TextStrokeTransparency,
				TextTransparency = 0.5,
				TextTruncate = Enum.TextTruncate.SplitWord,
				TextXAlignment = "Left",
			},

			Activated = function()
				if new.Collapsible._value then
					collapsed(not collapsed._value)
					UI.Sound.Swipe:Play()
				end
			end,
		},
	}

	new._content = UI.new "Frame" {
		Name = "UIContent",
		Parent = new._instance,
		BackgroundTransparency = 1,
		Position = function()
			return UDim2.new(0, 0, 0, UI.Theme.FontSize())
		end,
		Size = UI.tween(function()
			local collapse = collapsed()
			return UDim2.new(1, 0, if collapse then 0 else 1, if collapse then 0 else -UI.Theme.FontSize())
		end, UI.Theme.TweenOut),
		ClipsDescendants = true,

		listLayout,
		UI.new "UIPadding" {
			PaddingTop = UI.Theme.Padding,
			PaddingLeft = UI.Theme.Padding,
		},
	}

	return setmetatable(new, List)
end

return List
