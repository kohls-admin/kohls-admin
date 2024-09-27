local BaseClass = require(script.Parent.BaseClass)
local UI = require(script.Parent)

export type Function = UI.Function
export type List<T> = UI.List<T>
export type Set<T> = UI.Set<T>
export type Dict<T> = UI.Dict<T>
export type State<T> = UI.State<T>
export type Stateful<T> = UI.Stateful<T>
export type SpecialKey = UI.SpecialKey
export type SpecialDefinition = UI.SpecialDefinition

--- A generic function type
--- @within Checkbox
--- @type CheckboxDefinition { Value: Types.Stateful<boolean>, _instance: TextButton }
type CheckboxDefinition = SpecialDefinition & {
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

--- Creates a new checkbox.
function Checkbox.new(definition: CheckboxDefinition)
	local new = UI.makeStatefulDefaults({
		Value = false,
		Selected = false,
	}, definition)

	new.Selected._value = UI.peek(new.Value)

	new._instance = UI.new "TextButton" {
		AutoLocalize = false,
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
				UI.Theme.TweenOut,
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
				local value = not UI.peek(new.Value)
				new.Selected:set(value, true)
				new.Value:set(value)

				if value then
					UI.Sound.Hover03:Play()
				else
					UI.Sound.Hover01:Play()
				end
			end,
		},
	}

	return setmetatable(new, Checkbox)
end

return Checkbox
