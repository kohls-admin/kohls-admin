local UI = require(script.Parent.Parent) :: any
local BaseClass = require(script.Parent.BaseClass)
local ColorPicker = require(script.Parent.ColorPicker)
type ColorPicker = typeof(ColorPicker.new())

-- a simple color square, when clicked shows a color picker dialog

local DEFAULT = {
	Text = "ListItem Label",
	Value = Color3.new(1, 0, 0),
}

type Properties = typeof(DEFAULT) & TextButton

local Class = {}
Class.__index = Class
setmetatable(Class, BaseClass)

function Class.new(properties: Properties?)
	local self = table.clone(DEFAULT)
	UI.makeStatefulDefaults(self, properties)

	self._instance = UI.new "TextButton" {
		AutoLocalize = false,
		Text = "",
		BackgroundColor3 = self.Value,
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
			UI.toggleState(self._dialog.Visible, "floating")
			local value = UI.raw(self._dialog.Visible)
			if value then
				UI.Sound.Hover03:Play()
			else
				UI.Sound.Hover01:Play()
			end
		end,
	} :: TextButton & { UICorner: UICorner, UIStroke: UIStroke }

	self._dialog = UI.new "ColorPicker" {
		Adornee = self._instance,
		RightAlign = true,
		Value = self.Value,
		BackgroundColor3 = UI.Theme.Primary,
		BackgroundTransparency = 0,
	} :: ColorPicker

	return setmetatable(self, Class) :: typeof(self) & typeof(Class)
end

return Class
