local UI = require(script.Parent)
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
		Label = "Default Button Text",
		TextSize = UI.Theme.FontSize,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		Padding = UI.Theme.Padding,
	}, definition)

	local hovering = UI.state(false)
	new._hovering = hovering

	local listFrame = UI.new "Frame" {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0),

		[UI.Children] = {
			ListLayout = UI.new "UIListLayout" {
				FillDirection = Enum.FillDirection.Horizontal,
				SortOrder = Enum.SortOrder.LayoutOrder,
			},

			Label = UI.new "TextLabel" {
				LayoutOrder = 2,
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 1, 0),
				Font = UI.Theme.Font,
				Text = new.Label,
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

			IconFrame = UI.new "Frame" {
				LayoutOrder = UI.compute(function(use)
					return if use(new.IconRightAlign) then 3 else 1
				end),
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 1, 0),
				SizeConstraint = Enum.SizeConstraint.RelativeYY,
				Visible = UI.compute(function(use)
					return use(new.Icon) ~= ""
				end),

				UI.new "ImageLabel" {
					Name = "Icon",
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.new(0.5, 0, 0.5, 0),
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 1, 0),
					Image = new.Icon,
				},
			},
		},
	}

	local ripple = UI.new "Frame" {
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		BackgroundColor3 = UI.compute(function(use)
			return if UI.getLuminance(use(UI.Theme.Border)) > 0.5 then Color3.new() else Color3.new(1, 1, 1)
		end),

		UI.new "UICorner" {
			CornerRadius = UI.Theme.CornerRadius,
		},
	}

	new._instance = UI.new "TextButton" {
		Name = "Button",
		Active = true,
		AutoButtonColor = false,
		BackgroundColor3 = UI.compute(function(use)
			return if use(hovering) or use(UI.Theme.Transparency) > 0
				then use(UI.Theme.Border)
				else use(UI.Theme.Primary)
		end),
		BackgroundTransparency = UI.compute(function(use)
			return if not use(hovering) and use(UI.Theme.Transparency) > 0 then 1 else 0
		end),
		ClipsDescendants = true,
		Text = "",
		TextTransparency = 1,
		Size = UDim2.new(1, 0, 0, 32),

		UI.new "UICorner" {
			CornerRadius = UI.Theme.CornerRadius,
		},
		UI.new "UIStroke" {
			Enabled = UI.Theme.StrokeEnabled,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Transparency = UI.Theme.Transparency,
			Color = UI.Theme.Border,
		},

		listFrame,
		ripple,

		[UI.Event] = {
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
				UI.handleHover(hovering)
			end,
			MouseLeave = function()
				hovering:set(false)
			end,
		},
	}
	new.Activated = new._instance.Activated

	if definition.IconProperties then
		-- TODO: whenever new.IconProperties is changed we need to update!
		UI.edit(listFrame:FindFirstChild("IconFrame"):FindFirstChild("Icon"), definition.IconProperties)
	end

	return setmetatable(new, Button)
end

return Button
