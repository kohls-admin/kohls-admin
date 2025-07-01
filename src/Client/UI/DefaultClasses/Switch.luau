local BaseClass = require(script.Parent.BaseClass)
local UI = require(script.Parent.Parent)

local Switch = {}
Switch.__index = Switch
setmetatable(Switch, BaseClass)

local itemHeight = UI.compute(function()
	return UI.Theme.FontSize() + UI.Theme.Padding().Offset
end)

function Switch.new(definition)
	local new = UI.makeStatefulDefaults({
		Value = false,
		Selected = false,
	}, definition)

	new.Selected._value = UI.raw(new.Value)

	local backgroundTransparency = UI.tween(function()
		return if new.Value() then 0 else UI.Theme.TransparencyHeavy()
	end, UI.Theme.TweenOut)

	local backgroundTransparencyClamped = UI.tween(function()
		return if new.Value() then 0 else UI.Theme.TransparencyClamped()
	end, UI.Theme.TweenOut)

	new._instance = UI.new "TextButton" {
		AutoLocalize = false,
		Name = "Switch",
		Active = true,
		AutoButtonColor = false,
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = UI.Theme.Secondary,
		BackgroundTransparency = backgroundTransparency,
		Position = UDim2.new(1, 0, 0, 0),
		Text = "",
		TextTransparency = 1,
		Size = function()
			local height = itemHeight()
			return UDim2.new(0, height * 2, 0, height)
		end,

		UI.new "UICorner" {
			CornerRadius = UI.Theme.CornerDiameter,
		},
		UI.new "Stroke" {},

		UI.new "Frame" {
			Name = "Circle",
			BackgroundColor3 = UI.Theme.SecondaryText,
			BackgroundTransparency = backgroundTransparencyClamped,
			Size = UDim2.new(1, -2, 1, -2),
			SizeConstraint = Enum.SizeConstraint.RelativeYY,
			Position = UI.tween(function()
				return UDim2.new(0, if new.Value() then itemHeight() + 1 else 1, 0, 1)
			end, UI.Theme.TweenOut),

			UI.new "UICorner" {
				CornerRadius = UI.Theme.CornerDiameter,
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

	return setmetatable(new, Switch)
end

return Switch
