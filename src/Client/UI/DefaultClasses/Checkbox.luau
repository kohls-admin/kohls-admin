local BaseClass = require(script.Parent.BaseClass)
local UI = require(script.Parent.Parent)

export type Function = UI.Function
export type Set<T> = UI.Set<T>
export type Dict<T> = UI.Dict<T>
export type State<T> = UI.State<T>
export type Stateful<T> = UI.Stateful<T>
export type Symbol = UI.Symbol

--- A generic function type
--- @within Checkbox
--- @type CheckboxDefinition { Value: Types.Stateful<boolean>, _instance: TextButton }
type CheckboxDefinition = Dict<any> & {
	Value: Stateful<boolean>,
	_instance: TextButton,
}

type CheckboxClass = {
	__index: CheckboxClass,
	new: (definition: CheckboxDefinition) -> Checkbox,
}

type Checkbox = typeof(setmetatable({} :: CheckboxDefinition, {} :: CheckboxClass))

--- @class Checkbox
local Checkbox = {} :: CheckboxClass
Checkbox.__index = Checkbox
setmetatable(Checkbox, BaseClass)

local boxSize = UI.compute(function()
	return UDim2.fromOffset(UI.Theme.FontSizeLarger(), UI.Theme.FontSizeLarger())
end)

--- Creates a new checkbox.
function Checkbox.new(definition: CheckboxDefinition)
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

		UI.new "UIStroke" {
			Enabled = UI.Theme.StrokeEnabled,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Transparency = UI.Theme.TransparencyClamped,
			Color = UI.Theme.Border,
		},

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
