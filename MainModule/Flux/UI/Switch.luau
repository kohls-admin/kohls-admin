local BaseClass = require(script.Parent.BaseClass)
local UI = require(script.Parent)

local Switch = {}
Switch.__index = Switch
setmetatable(Switch, BaseClass)

function Switch.new(definition)
	local new = UI.makeStatefulDefaults({
		Value = false,
	}, definition)

	local backgroundTransparency = UI.tween(
		UI.Theme.NormalTween,
		UI.compute(function(use)
			return if use(new.Value) then 0 else use(UI.Theme.TransparencyClamped)
		end)
	)

	local cappedPadding = UI.compute(function(use)
		return UDim.new(0, math.min(use(UI.Theme.PaddingHalf).Offset, 4))
	end)

	new._instance = UI.new "TextButton" {
		Name = "Switch",
		Active = true,
		AutoButtonColor = false,
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = UI.tween(
			UI.Theme.NormalTween,
			UI.compute(function(use)
				local border, secondary = use(UI.Theme.Border), use(UI.Theme.Secondary)
				return if use(new.Value) then secondary else border
			end)
		),
		BackgroundTransparency = backgroundTransparency,
		Position = UDim2.new(1, 0, 0, 0),
		Text = "",
		TextTransparency = 1,
		Size = UDim2.new(0, 48, 0, 24),

		UI.new "UICorner" {
			CornerRadius = UI.Theme.CornerDiameter,
		},
		UI.new "UIStroke" {
			Enabled = UI.Theme.StrokeEnabled,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Transparency = UI.Theme.Transparency,
			Color = UI.Theme.Border,
		},
		UI.new "UIPadding" {
			PaddingLeft = cappedPadding,
			PaddingRight = cappedPadding,
			PaddingTop = cappedPadding,
			PaddingBottom = cappedPadding,
		},

		UI.new "Frame" {
			Name = "Circle",
			BackgroundColor3 = UI.Theme.SecondaryText,
			BackgroundTransparency = backgroundTransparency,
			Size = UDim2.new(1, 0, 1, 0),
			SizeConstraint = Enum.SizeConstraint.RelativeYY,
			Position = UI.tween(
				UI.Theme.NormalTween,
				UI.compute(function(use)
					return UDim2.new(0, if use(new.Value) then 24 else 0, 0, 0)
				end)
			),

			UI.new "UICorner" {
				CornerRadius = UI.Theme.CornerDiameter,
			},
		},

		[UI.Event] = {
			Activated = function()
				new.Value:set(not UI.peek(new.Value))
			end,
		},
	}

	return setmetatable(new, Switch)
end

return Switch
