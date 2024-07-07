local BaseClass = require(script.Parent.BaseClass)
local UI = require(script.Parent)

-- a simple color square, when clicked shows a color picker dialog

local Color = {}
Color.__index = Color
setmetatable(Color, BaseClass)

function Color.new(definition)
	local new = UI.makeStatefulDefaults({
		Text = "ListItem Label",
		Value = Color3.new(1, 0, 0),
	}, definition)

	new._instance = UI.new "TextButton" {
		Text = "",
		BackgroundColor3 = new.Value,
		AnchorPoint = Vector2.new(1, 0),
		Size = UDim2.new(0, 32, 0, 32),
		Position = UDim2.new(1, 0, 0, 0),

		UI.new "UICorner" {
			CornerRadius = UI.Theme.CornerRadius,
		},
		UI.new "UIStroke" {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Transparency = UI.Theme.Transparency,
			Color = UI.Theme.Border,
		},

		[UI.Event] = {
			Activated = function(value)
				new._dialog._instance.Visible = not new._dialog._instance.Visible
			end,
		},
	}

	local absolutePosition = UI.state(new._instance, "AbsolutePosition")

	new._dialog = UI.new "ColorPicker" {
		ZIndex = 100,
		Visible = false,
		Parent = UI.LayerTop,
		Value = new.Value,
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = UI.Theme.Primary,
		BackgroundTransparency = 0,
		Position = UI.compute(function(use)
			local pos = use(absolutePosition)
			return UDim2.fromOffset(
				pos.x + 32,
				pos.y + 32 + use(UI.Theme.PaddingHalf).Offset + use(UI.TopbarInset).Height
			)
		end),

		UI.new "UICorner" {
			CornerRadius = UI.compute(function(use)
				return UDim.new(0, use(UI.Theme.CornerRadius).Offset + use(UI.Theme.Padding).Offset)
			end),
		},
		UI.new "UIStroke" {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Transparency = UI.Theme.Transparency,
			Color = UI.Theme.Border,
		},

		[UI.Hook] = {
			Value = function(value)
				new.Value:set(value)
			end,
		},
	}

	return setmetatable(new, Color)
end

return Color
