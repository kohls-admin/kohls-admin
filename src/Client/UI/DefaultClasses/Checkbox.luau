local BaseClass = require(script.Parent.BaseClass)
local UI = require(script.Parent.Parent)

local Checkbox = {}
Checkbox.__index = Checkbox
setmetatable(Checkbox, BaseClass)

local boxSize = UI.compute(function()
	return UDim2.fromOffset(UI.Theme.FontSizeLarger(), UI.Theme.FontSizeLarger())
end)

function Checkbox.new(definition)
	local new = UI.makeStatefulDefaults({
		Value = false,
		Selected = false,
	}, definition)

	new.Selected._value = UI.raw(new.Value)

	new._instance = UI.new "TextButton" {
		AutoLocalize = false,
		Name = "Checkbox",
		Active = true,
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundColor3 = UI.Theme.Secondary,
		BackgroundTransparency = UI.Theme.TransparencyOverlay,
		Position = UDim2.new(1, 0, 0.5, 0),
		Text = "",
		TextTransparency = 1,
		Size = boxSize,

		UI.new "UICorner" {
			CornerRadius = UI.Theme.CornerRadius,
		},

		UI.new "Stroke" {},

		UI.new "UIPadding" {
			PaddingTop = UI.Theme.PaddingHalf,
			PaddingRight = UI.Theme.PaddingHalf,
			PaddingBottom = UI.Theme.PaddingHalf,
			PaddingLeft = UI.Theme.PaddingHalf,
		},

		UI.new "Frame" {
			Name = "Checkmark",
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			Size = UI.tween(function()
				return UDim2.new(if new.Value() then 1 else 0, 0, 1, 0)
			end, UI.Theme.TweenOut),

			UI.new "ImageLabel" {
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundTransparency = 1,
				Position = UDim2.new(0, 0, 0.5, 0),
				Size = UDim2.fromScale(1, 1),
				SizeConstraint = Enum.SizeConstraint.RelativeYY,
				Image = UI.Theme.Image.Check,
				ImageColor3 = UI.Theme.Secondary,
			},
		},

		Activated = function()
			local value = not UI.raw(new.Value)
			new.Selected(value, true)
			new.Value(value)

			if value then
				UI.Sound.Hover03:Play()
			else
				UI.Sound.Hover01:Play()
			end
		end,
	}

	return setmetatable(new, Checkbox)
end

return Checkbox
