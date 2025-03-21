local UI = require(script.Parent.Parent)
local BaseClass = require(script.Parent.BaseClass)

local Tween = game:GetService("TweenService")

local Button = {}
Button.__index = Button
setmetatable(Button, BaseClass)

function Button.new(definition)
	local new = UI.makeStatefulDefaults({
		Icon = "",
		IconProperties = {},
		IconRightAlign = false,
		Label = "",
		LabelProperties = {},
		ActiveSound = true,
		BackgroundColor3 = UI.Theme.Border,
		BackgroundTransparency = 1,
		HoverTransparency = 0,
		TextSize = UI.Theme.FontSize,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		Padding = UI.Theme.Padding,
	}, definition)

	local hovering = UI.state(false)
	new._hovering = hovering

	new._content = UI.new "Frame" {
		Name = "UIContent",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0),

		[UI.Children] = {
			ListLayout = UI.new "UIListLayout" {
				FillDirection = Enum.FillDirection.Horizontal,
				SortOrder = Enum.SortOrder.LayoutOrder,
				VerticalAlignment = Enum.VerticalAlignment.Center,
			},

			Label = UI.edit(
				UI.new "TextLabel" {
					LayoutOrder = 2,
					AutoLocalize = false,
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 1, 0),
					Font = UI.Theme.Font,
					RichText = true,
					Text = UI.computeFrom(tostring, new.Label),
					TextSize = new.TextSize,
					TextColor3 = UI.Theme.PrimaryText,
					TextTransparency = 0,
					TextStrokeTransparency = 0.9,
					TextTruncate = Enum.TextTruncate.SplitWord,
					TextXAlignment = new.TextXAlignment,
					TextYAlignment = new.TextYAlignment,
					Visible = UI.compute(function(use)
						return use(new.Label) ~= ""
					end),

					UI.new "UIFlexItem" {
						FlexMode = Enum.UIFlexMode.Fill,
					},
					UI.new "UIPadding" {
						PaddingLeft = new.Padding,
						PaddingRight = new.Padding,
					},
				},
				new.LabelProperties._value
			),

			IconFrame = UI.new "Frame" {
				LayoutOrder = UI.compute(function(use)
					return if use(new.IconRightAlign) then 9 else -9
				end),
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 1, 0),
				SizeConstraint = Enum.SizeConstraint.RelativeYY,
				Visible = UI.compute(function(use)
					return use(new.Icon) ~= ""
				end),

				UI.edit(
					UI.new "ImageLabel" {
						Name = "Icon",
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.new(0.5, 0, 0.5, 0),
						BackgroundTransparency = 1,
						Size = UDim2.new(1, 0, 1, 0),
						Image = new.Icon,
					},
					new.IconProperties._value
				),
			},
		},
	}

	local ripple = UI.new "Frame" {
		Name = "Ripple",
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		BackgroundColor3 = UI.compute(function(use)
			return if UI.getLuminance(use(new.BackgroundColor3)) > 0.5 then Color3.new() else Color3.new(1, 1, 1)
		end),

		UI.new "UICorner" {
			CornerRadius = UI.Theme.CornerRadius,
		},
	}

	new._instance = UI.new "TextButton" {
		AutoLocalize = false,
		Name = "Button",
		Active = true,
		AutoButtonColor = false,
		BackgroundColor3 = new.BackgroundColor3,
		BackgroundTransparency = UI.compute(function(use)
			return if use(hovering) then use(new.HoverTransparency) else use(new.BackgroundTransparency)
		end),
		ClipsDescendants = true,
		Text = "",
		TextTransparency = 1,
		Size = UDim2.new(1, 0, 0, 32),

		UI.new "UICorner" {
			CornerRadius = UI.Theme.CornerRadius,
		},
		UI.new "UIStroke" {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Transparency = UI.Theme.TransparencyClamped,
			Color = UI.Theme.Border,
		},

		new._content,
		ripple,

		[UI.Event] = {
			Activated = function()
				if new.ActiveSound._value then
					UI.Sound.Hover01:Play()
				end
			end,
			InputBegan = function(input, processed)
				if
					processed
					or not (
						input.UserInputType == Enum.UserInputType.MouseButton1
						or input.UserInputType == Enum.UserInputType.Touch
					)
				then
					return
				end
				local ap = new._instance.AbsolutePosition
				local x = input.Position.X
				ripple.Size = UDim2.new(0, 0, 1, 0)
				ripple.Position = UDim2.new(0, x - ap.x, 0, 0)
				Tween:Create(ripple, UI.Theme.TweenOut._value, {
					BackgroundTransparency = 0.9,
					Size = UDim2.new(1, 0, 1, 0),
					Position = UDim2.new(0.5, 0, 0, 0),
				}):Play()
			end,
			InputEnded = function(input)
				if
					not (
						input.UserInputType == Enum.UserInputType.MouseButton1
						or input.UserInputType == Enum.UserInputType.MouseMovement
						or input.UserInputType == Enum.UserInputType.Touch
					)
				then
					return
				end
				Tween:Create(ripple, UI.Theme.TweenOut._value, { BackgroundTransparency = 1 }):Play()
			end,
			MouseEnter = function()
				UI.activateState(hovering, "hover")
			end,
			MouseLeave = function()
				UI.deactivateState(hovering, "hover")
			end,
		},
	}
	new.Activated = new._instance.Activated

	return setmetatable(new, Button)
end

return Button
