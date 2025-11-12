local UI = require(script.Parent.Parent) :: any
local BaseClass = require(script.Parent.BaseClass)

local Tween = game:GetService("TweenService")

local DEFAULT = {
	--- A test property.
	Icon = "",
	IconProperties = {},
	IconRightAlign = false,
	Label = "",
	LabelProperties = {},
	ActiveSound = true,
	BackgroundColor3 = UI.Theme.Secondary,
	BackgroundTransparency = UI.Theme.TransparencyHeavy,
	HoverTransparency = 0.75,
	FontFace = UI.Theme.Font,
	TextSize = UI.Theme.FontSize,
	TextScaled = false,
	TextXAlignment = Enum.TextXAlignment.Center,
	TextYAlignment = Enum.TextYAlignment.Center,
	Padding = UI.Theme.Padding,
}

type Properties = typeof(DEFAULT) & TextButton

local Class = {}
Class.__index = Class
setmetatable(Class, BaseClass)

function Class.new(properties: Properties?)
	local self = table.clone(DEFAULT)
	self.IconProperties, self.LabelProperties = {}, {}
	UI.makeStatefulDefaults(self, properties)

	local hovering = UI.state(false) :: boolean
	self._hovering = hovering

	self._content = UI.new "Frame" {
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
				FontFace = self.FontFace,
				RichText = true,
				Text = function()
					return tostring(self.Label)
				end,
				TextSize = self.TextSize,
				TextScaled = self.TextScaled,
				TextColor3 = UI.Theme.PrimaryText,
				TextStrokeColor3 = UI.Theme.Primary,
				TextStrokeTransparency = UI.Theme.TextStrokeTransparency,
				TextTruncate = Enum.TextTruncate.SplitWord,
				TextXAlignment = self.TextXAlignment,
				TextYAlignment = self.TextYAlignment,
				Visible = function()
					return self.Label() ~= ""
				end,

				UI.new "UIFlexItem" {
					FlexMode = Enum.UIFlexMode.Fill,
				},
				UI.new "UIPadding" {
					PaddingLeft = self.Padding,
					PaddingRight = self.Padding,
				},
			},
			self.LabelProperties._value
		),

		UI.new "Frame" {
			Name = "IconFrame",
			LayoutOrder = function()
				return if self.IconRightAlign() then 9 else -9
			end,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 1, 0),
			SizeConstraint = Enum.SizeConstraint.RelativeYY,
			Visible = function()
				return self.Icon() ~= ""
			end,

			UI.edit(
				UI.new "ImageLabel" {
					Name = "Icon",
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.new(0.5, 0, 0.5, 0),
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 1, 0),
					Image = self.Icon,
					ScaleType = Enum.ScaleType.Fit,
				},
				self.IconProperties._value
			),
		},
	} :: Frame & {
		UIListLayout: UIListLayout,
		Label: TextLabel & { UIFlexItem: UIFlexItem, UIPadding: UIPadding },
		IconFrame: Frame & { Icon: ImageLabel },
	}

	local ripple = UI.new "Frame" {
		Name = "Ripple",
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		BackgroundColor3 = function()
			return if UI.getLuminance(self.BackgroundColor3()) > 0.5 then Color3.new() else Color3.new(1, 1, 1)
		end,

		UI.new "UICorner" {
			CornerRadius = UI.Theme.CornerPadded,
		},
	}

	local instance = UI.new "TextButton" {
		AutoLocalize = false,
		Name = "Button",
		Active = true,
		AutoButtonColor = false,
		BackgroundColor3 = self.BackgroundColor3,
		BackgroundTransparency = function()
			return if hovering() then self.HoverTransparency() else self.BackgroundTransparency()
		end,
		ClipsDescendants = true,
		Text = "",
		TextTransparency = 1,
		Size = UDim2.new(1, 0, 0, 32),

		UI.new "UICorner" {
			CornerRadius = UI.Theme.CornerPadded,
		},
		UI.new "Stroke" {},

		self._content,
		ripple,

		Activated = function()
			if self.ActiveSound._value then
				UI.Sound.Hover01:Play()
			end
		end,
		InputBegan = function(input, processed)
			if
				processed
				or (
					input.UserInputType ~= Enum.UserInputType.MouseButton1
					and input.UserInputType ~= Enum.UserInputType.Touch
				)
			then
				return
			end
			local x = input.Position.X
			ripple.Size = UDim2.new(0, 0, 1, 0)
			ripple.Position = UDim2.new(0, x - self._instance.AbsolutePosition.x, 0, 0)
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
				if UI.sinkInput(input.Position.X, input.Position.Y, self._instance) then
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
	self._instance = instance :: TextButton & {
		UICorner: UICorner,
		UIStroke: UIStroke,
		UIContent: typeof(self._content),
		Ripple: typeof(ripple) & { UICorner: UICorner },
	}

	return setmetatable(self, Class) :: typeof(self) & typeof(Class)
end

return Class
