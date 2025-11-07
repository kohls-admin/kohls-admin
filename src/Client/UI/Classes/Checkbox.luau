local UI = require(script.Parent.Parent) :: any
local BaseClass = require(script.Parent.BaseClass)

local DEFAULT = {
	--- Whether or not the checkbox is selected.
	Value = false,
}

type Properties = typeof(DEFAULT) & TextButton

local Class = {}
Class.__index = Class
setmetatable(Class, BaseClass)

local boxSize = UI.compute(function()
	return UDim2.fromOffset(UI.Theme.FontSizeLarger(), UI.Theme.FontSizeLarger())
end)

function Class.new(properties: Properties?)
	local self = table.clone(DEFAULT)
	UI.makeStatefulDefaults(self, properties)

	self._instance = UI.new "TextButton" {
		AutoLocalize = false,
		Name = "Checkbox",
		Active = true,
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundColor3 = UI.Theme.Secondary,
		BackgroundTransparency = UI.Theme.TransparencyHeavy,
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
				return UDim2.new(if self.Value() then 1 else 0, 0, 1, 0)
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
			local value = not UI.raw(self.Value)
			self.Value(value)
			if value then
				UI.Sound.Hover03:Play()
			else
				UI.Sound.Hover01:Play()
			end
		end,
	} :: TextButton & {
		UICorner: UICorner,
		UIStroke: UIStroke,
		UIPadding: UIPadding,
		Checkmark: Frame & { ImageLabel: ImageLabel },
	}

	return setmetatable(self, Class) :: typeof(self) & typeof(Class)
end

return Class
