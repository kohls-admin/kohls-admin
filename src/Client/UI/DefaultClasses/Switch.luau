local BaseClass = require(script.Parent.BaseClass)
local UI = require(script.Parent.Parent)

local Switch = {}
Switch.__index = Switch
setmetatable(Switch, BaseClass)

local itemHeight = UI.compute(function(use)
	return use(UI.Theme.FontSize) + use(UI.Theme.Padding).Offset
end)

function Switch.new(definition)
	local new = UI.makeStatefulDefaults({
		Value = false,
		Selected = false,
	}, definition)

	new.Selected._value = UI.peek(new.Value)

	local backgroundTransparency = UI.tween(
		UI.Theme.TweenOut,
		UI.compute(function(use)
			return if use(new.Value) then 0 else use(UI.Theme.TransparencyOverlay)
		end)
	)

	local backgroundTransparencyClamped = UI.tween(
		UI.Theme.TweenOut,
		UI.compute(function(use)
			return if use(new.Value) then 0 else use(UI.Theme.TransparencyClamped)
		end)
	)

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
		Size = function(use)
			local height = use(itemHeight)
			return UDim2.new(0, height * 2, 0, height)
		end,

		UI.new "UICorner" {
			CornerRadius = UI.Theme.CornerDiameter,
		},
		UI.new "UIStroke" {
			Enabled = UI.Theme.StrokeEnabled,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Transparency = UI.Theme.TransparencyClamped,
			Color = UI.Theme.Border,
		},

		UI.new "Frame" {
			Name = "Circle",
			BackgroundColor3 = UI.Theme.SecondaryText,
			BackgroundTransparency = backgroundTransparencyClamped,
			Size = UDim2.new(1, -2, 1, -2),
			SizeConstraint = Enum.SizeConstraint.RelativeYY,
			Position = UI.tween(
				UI.Theme.TweenOut,
				UI.compute(function(use)
					return UDim2.new(0, if use(new.Value) then use(itemHeight) + 1 else 1, 0, 1)
				end)
			),

			UI.new "UICorner" {
				CornerRadius = UI.Theme.CornerDiameter,
			},
		},

		Activated = function()
			local value = not UI.peek(new.Value)
			new.Selected:set(value, true)
			new.Value:set(value)

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
