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
		BackgroundColor3 = UI.Theme.Secondary,
		BackgroundTransparency = UI.Theme.TransparencyHeavy,
		HoverTransparency = 0.75,
		Font = UI.Theme.Font,
		TextSize = UI.Theme.FontSize,
		TextScaled = false,
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

		UI.new "UIListLayout" {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		},

		UI.edit(
			UI.new "TextLabel" {
				Name = "Label",
				LayoutOrder = 2,
				AutoLocalize = false,
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 1, 0),
				Font = new.Font,
				RichText = true,
				Text = function()
					return tostring(new.Label)
				end,
				TextSize = new.TextSize,
				TextScaled = new.TextScaled,
				TextColor3 = UI.Theme.PrimaryText,
				TextStrokeColor3 = UI.Theme.Primary,
				TextStrokeTransparency = UI.Theme.TextStrokeTransparency,
				TextTruncate = Enum.TextTruncate.SplitWord,
				TextXAlignment = new.TextXAlignment,
				TextYAlignment = new.TextYAlignment,
				Visible = function()
					return new.Label() ~= ""
				end,

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

		UI.new "Frame" {
			Name = "IconFrame",
			LayoutOrder = function()
				return if new.IconRightAlign() then 9 else -9
			end,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 1, 0),
			SizeConstraint = Enum.SizeConstraint.RelativeYY,
			Visible = function()
				return new.Icon() ~= ""
			end,

			UI.edit(
				UI.new "ImageLabel" {
					Name = "Icon",
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.new(0.5, 0, 0.5, 0),
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 1, 0),
					Image = new.Icon,
					ScaleType = Enum.ScaleType.Fit,
				},
				new.IconProperties._value
			),
		},
	}

	local ripple = UI.new "Frame" {
		Name = "Ripple",
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		BackgroundColor3 = function()
			return if UI.getLuminance(new.BackgroundColor3()) > 0.5 then Color3.new() else Color3.new(1, 1, 1)
		end,

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
		BackgroundTransparency = function()
			return if hovering() then new.HoverTransparency() else new.BackgroundTransparency()
		end,
		ClipsDescendants = true,
		Text = "",
		TextTransparency = 1,
		Size = UDim2.new(1, 0, 0, 32),

		UI.new "UICorner" {
			CornerRadius = UI.Theme.CornerRadius,
		},
		UI.new "Stroke" {},

		new._content,
		ripple,

		Activated = function()
			if new.ActiveSound._value then
				UI.Sound.Hover01:Play()
			end
		end,
		InputBegan = function(input, processed)
			if
				processed
				or input.UserInputType ~= Enum.UserInputType.MouseButton1
				or input.UserInputType ~= Enum.UserInputType.Touch
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
		InputChanged = function(input, processed)
			if processed then
				return
			end
			if
				input.UserInputType == Enum.UserInputType.MouseMovement
				or input.UserInputType == Enum.UserInputType.Touch
			then
				if UI.sinkInput(input.Position.X, input.Position.Y, new._instance) then
					UI.deactivateState(hovering, "hover")
					return
				end
				UI.activateState(hovering, "hover")
			end
		end,
		InputEnded = function(input)
			if
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.MouseMovement
				or input.UserInputType == Enum.UserInputType.Touch
			then
				UI.deactivateState(hovering, "hover")
				Tween:Create(ripple, UI.Theme.TweenOut._value, { BackgroundTransparency = 1 }):Play()
			end
		end,
	}
	new.Activated = new._instance.Activated

	return setmetatable(new, Button)
end

return Button
