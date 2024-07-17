local BaseClass = require(script.Parent.BaseClass)
local UI = require(script.Parent)

local Checkbox = {}
Checkbox.__index = Checkbox
setmetatable(Checkbox, BaseClass)

function Checkbox.new(definition)
	local new = UI.makeStatefulDefaults({
		Value = false,
	}, definition)

	new._instance = UI.new "TextButton" {
		Name = "Checkbox",
		Active = true,
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.new(1, 0, 0.5, 0),
		Text = "",
		TextTransparency = 1,
		Size = UDim2.new(0, 24, 0, 24),

		UI.new "UICorner" {
			CornerRadius = UI.Theme.CornerRadius,
		},

		UI.new "UIStroke" {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Transparency = UI.Theme.TransparencyClamped,
			Color = UI.Theme.Border,
		},

		UI.new "Frame" {
			Name = "Checkmark",
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			Size = UI.tween(
				UI.Theme.NormalTween,
				UI.compute(function(use)
					return UDim2.new(if use(new.Value) then 1 else 0, 0, 1, 0)
				end)
			),

			UI.new "ImageLabel" {
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundTransparency = 1,
				Position = UDim2.new(0, 5, 0.5, 0),
				Size = UDim2.new(0, 14, 0, 14),
				Image = "rbxassetid://2340153468",
				ImageColor3 = UI.Theme.Secondary,
			},
		},

		[UI.Event] = {
			Activated = function()
				new.Value:set(not UI.peek(new.Value))
			end,
		},
	}

	return setmetatable(new, Checkbox)
end

return Checkbox
