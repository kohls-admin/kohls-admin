local BaseClass = require(script.Parent.BaseClass)
local UI = require(script.Parent.Parent)

local List = {}
List.__index = List
setmetatable(List, BaseClass)

function List.new(definition)
	local new = UI.makeStatefulDefaults({
		Collapsible = false,
		Collapsed = false,
		Label = "New List",
		Padding = UI.Theme.Padding,
	}, definition)

	local listLayout = UI.new "UIListLayout" {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = new.Padding,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		VerticalAlignment = Enum.VerticalAlignment.Top,
	}

	local contentSize = UI.state(listLayout, "AbsoluteContentSize")

	local headerTransparency = UI.tween(function()
		return if new.Collapsed() then 0.5 else 0
	end, UI.Theme.TweenOut)

	new._instance = UI.new "Frame" {
		Name = "List",
		BackgroundColor3 = UI.Theme.Secondary,
		BackgroundTransparency = UI.Theme.TransparencyMax,
		ClipsDescendants = true,
		Size = UI.tween(function()
			return UDim2.new(
				1,
				0,
				0,
				if new.Collapsed()
					then UI.Theme.FontSize() + UI.Theme.Padding().Offset * 4
					else contentSize().Y + UI.Theme.FontSize() + UI.Theme.Padding().Offset * 6
			)
		end, UI.Theme.TweenOut),

		UI.new "UICorner" {
			CornerRadius = UI.Theme.CornerRadius,
		},
		UI.new "Stroke" { Transparency = UI.Theme.TransparencyBalanced },

		UI.new "TextButton" {
			AutoLocalize = false,
			Name = "Header",
			Active = true,
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			TextTransparency = 1,
			Text = "",
			Size = UDim2.new(1, 0, 0, 0),

			UI.new "UIPadding" {
				PaddingLeft = new.Padding,
				PaddingRight = new.Padding,
				PaddingTop = new.Padding,
				PaddingBottom = new.Padding,
			},

			UI.new "ImageLabel" {
				Name = "Arrow",
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 0, 0.5, 0),
				Size = UDim2.new(0.75, 0, 0.75, 0),
				Image = UI.Theme.Image.Down,
				ImageColor3 = UI.Theme.PrimaryText,
				ImageTransparency = headerTransparency,
				Visible = new.Collapsible,
				Rotation = UI.tween(function()
					return if new.Collapsed() then -90 else 0
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
				TextTransparency = headerTransparency,
				TextTruncate = Enum.TextTruncate.SplitWord,
				TextXAlignment = "Left",
			},

			Activated = function()
				if new.Collapsible._value then
					new.Collapsed(not new.Collapsed._value)
					if new.Collapsed._value then
						UI.Sound.Hover01:Play()
					else
						UI.Sound.Hover03:Play()
					end
				end
			end,
		},
	}

	new._content = UI.new "Frame" {
		Name = "UIContent",
		Parent = new._instance,
		BackgroundTransparency = 1,
		Position = function()
			return UDim2.new(0, 0, 0, UI.Theme.FontSize + new.Padding().Offset * 2)
		end,
		Size = UI.tween(function()
			local collapse = new.Collapsed()
			return UDim2.new(
				1,
				0,
				if collapse then 0 else 1,
				if collapse then 0 else -UI.Theme.FontSize + new.Padding().Offset * 2
			)
		end, UI.Theme.TweenOut),
		ClipsDescendants = true,

		listLayout,
		UI.new "UIPadding" {
			PaddingLeft = new.Padding,
			PaddingRight = new.Padding,
			PaddingTop = UDim.new(0, 1),
			PaddingBottom = UDim.new(0, 1),
		},
	}

	return setmetatable(new, List)
end

return List
