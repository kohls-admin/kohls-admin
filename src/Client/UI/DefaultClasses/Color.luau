local BaseClass = require(script.Parent.BaseClass)
local UI = require(script.Parent.Parent)

-- a simple color square, when clicked shows a color picker dialog

local Color = {}
Color.__index = Color
setmetatable(Color, BaseClass)

function Color.new(definition)
	local new = UI.makeStatefulDefaults({
		Text = "ListItem Label",
		Value = Color3.new(1, 0, 0),
		Selected = Color3.new(1, 0, 0),
	}, definition)

	new.Selected._value = UI.raw(new.Value)

	new._instance = UI.new "TextButton" {
		AutoLocalize = false,
		Text = "",
		BackgroundColor3 = new.Value,
		AnchorPoint = Vector2.new(1, 0.5),
		Size = function()
			local height = UI.Theme.FontSize() + UI.Theme.Padding().Offset
			return UDim2.new(0, height, 0, height)
		end,
		Position = UDim2.new(1, 0, 0.5, 0),

		UI.new "UICorner" {
			CornerRadius = UI.Theme.CornerRadius,
		},
		UI.new "Stroke" {},

		Activated = function()
			UI.toggleState(new._dialog.Visible, "floating")
			local value = UI.raw(new._dialog.Visible)
			if value then
				UI.Sound.Hover03:Play()
			else
				UI.Sound.Hover01:Play()
			end
		end,
	}

	new._dialog = UI.new "ColorPicker" {
		Adornee = new._instance,
		RightAlign = true,
		Value = new.Value,
		Selected = new.Selected,
		BackgroundColor3 = UI.Theme.Primary,
		BackgroundTransparency = 0,
	}

	return setmetatable(new, Color)
end

return Color
