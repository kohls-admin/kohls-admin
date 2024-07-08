local BaseClass = require(script.Parent.BaseClass)
local UI = require(script.Parent)

local List = {}
List.__index = List
setmetatable(List, BaseClass)

function List.new(definition)
	local new = UI.makeStatefulDefaults({
		Collapsible = false,
		Label = "NEW LIST New List",
		-- Padding = UDim.new(0, 8),
	}, definition)

	local listLayout = UI.new "UIListLayout" {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UI.Theme.Padding,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		VerticalAlignment = Enum.VerticalAlignment.Top,
	}

	local collapsed = UI.state(false)
	local contentSize = UI.state(listLayout, "AbsoluteContentSize")

	new._instance = UI.new "Frame" {
		Name = "List",
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Size = UI.tween(
			UI.Theme.NormalTween,
			UI.compute(function(use)
				return UDim2.new(
					1,
					0,
					0,
					if use(collapsed) then 24 else use(contentSize).Y + 24 + use(UI.Theme.Padding).Offset * 2
				)
			end)
		),

		[UI.Children] = {
			Header = UI.new "TextButton" {
				Active = true,
				BackgroundTransparency = 1,
				TextTransparency = 1,
				Text = "",
				Size = UDim2.new(1, 0, 0, 24), -- TODO: use fontsize offset

				[UI.Children] = {
					Arrow = UI.new "ImageLabel" {
						BackgroundTransparency = 1,
						AnchorPoint = Vector2.new(0, 0.5),
						Position = UDim2.new(0, 0, 0.5, 0),
						Size = UDim2.new(0, 18, 0, 18),
						Image = "rbxassetid://2374890977",
						ImageTransparency = 0.5,
						Visible = new.Collapsible,
						Rotation = UI.tween(
							UI.Theme.NormalTween,
							UI.compute(function(use)
								return if use(collapsed) then -90 else 0
							end)
						),
					},

					Label = UI.new "TextLabel" {
						BackgroundTransparency = 1,
						Position = UI.compute(function(use)
							return UDim2.new(0, if use(new.Collapsible) then 18 else 12, 0, 0)
						end),
						Size = UDim2.new(1, -18, 1, 0),
						FontFace = UI.Theme.FontBold,
						Text = UI.computeFrom(string.upper, new.Label),
						TextSize = UI.Theme.FontSize,
						TextColor3 = UI.Theme.PrimaryText,
						TextTransparency = 0.5,
						TextTruncate = Enum.TextTruncate.AtEnd,
						TextXAlignment = "Left",
					},
				},

				[UI.Event] = {
					Activated = function()
						if new.Collapsible._value then
							collapsed:set(not collapsed._value)
						end
					end,
				},
			},
		},
	}

	local content = UI.new "Frame" {
		Name = "UIContent",
		Parent = new._instance,
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 0, 0, 24),
		Size = UI.tween(
			UI.Theme.NormalTween,
			UI.compute(function(use)
				local collapse = use(collapsed)
				return UDim2.new(
					1,
					0,
					if collapse then 0 else 1,
					if collapse then 0 else -24 + use(UI.Theme.Padding).Offset * 2
				)
			end)
		),
		ClipsDescendants = true,

		[UI.Children] = {
			ListLayout = listLayout,
			UIPadding = UI.new "UIPadding" {
				PaddingLeft = UI.Theme.Padding,
				PaddingRight = UI.Theme.Padding,
				PaddingTop = UI.Theme.Padding,
				PaddingBottom = UI.Theme.Padding,
			},
		},
	}

	return setmetatable(new, List)
end

return List
