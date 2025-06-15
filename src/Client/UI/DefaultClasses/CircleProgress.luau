local BaseClass = require(script.Parent.BaseClass)
local UI = require(script.Parent.Parent)

export type Function = UI.Function
export type List<T> = UI.List<T>
export type Set<T> = UI.Set<T>
export type Dict<T> = UI.Dict<T>
export type State<T> = UI.State<T>
export type Stateful<T> = UI.Stateful<T>
export type Symbol = UI.Symbol
export type SpecialDefinition = UI.SpecialDefinition

--- A circular progress indicator type
--- @within CircleProgress
--- @type CircleProgressDefinition { Value: Types.Stateful<boolean>,Padding: UDim, Size: UDim2, _instance: TextButton }
type CircleProgressDefinition = SpecialDefinition & {
	Value: Stateful<boolean>,
	Padding: UDim,
	Size: UDim2,
	_instance: TextButton,
}

type CircleProgressClass = {
	__index: CircleProgressClass,
	new: (definition: CircleProgressDefinition) -> CircleProgress,
}

type CircleProgress = typeof(setmetatable({} :: CircleProgressDefinition, {} :: CircleProgressClass))

--- @class CircleProgress
local CircleProgress = {} :: CircleProgressClass
CircleProgress.__index = CircleProgress
setmetatable(CircleProgress, BaseClass)

function CircleProgress:setProgress(alpha)
	alpha = math.clamp(alpha, 0, 1)
	for i, circle in self._circles do
		local circleAlpha = math.clamp((alpha - (i - 1) / 4) * 4, 0, 1)
		if circleAlpha > 0 then
			local index = math.floor(circleAlpha * ((16 * 16) - 1))
			local column = index % 16
			local row = math.floor(index / 16)
			circle.ImageRectOffset = Vector2.new(column * 64, row * 64)
			circle.Visible = true
		else
			circle.Visible = false
		end
	end
end

--- Creates a new circular progress indicator.
function CircleProgress.new(definition: CircleProgressDefinition)
	local new = UI.makeStatefulDefaults({
		Value = 0,
		Padding = UI.Theme.Padding,
		Size = UDim2.new(0, 64, 0, 64),
	}, definition)

	local halfSize = UI.compute(function(use)
		local size = math.round(use(new.Size).X.Offset / 2)
		return UDim2.fromOffset(size, size)
	end)

	new._circles = {
		UI.new "ImageLabel" {
			Name = "TopRight",
			BackgroundTransparency = 1,
			Position = UDim2.new(0.5, 0, 0, 0),
			Size = halfSize,
			ImageColor3 = UI.Theme.Secondary,
			ImageRectOffset = Vector2.new(960, 960),
			ImageRectSize = Vector2.new(64, 64),
			Image = "rbxassetid://14622698257",
		},

		UI.new "ImageLabel" {
			Name = "BottomRight",
			Rotation = 90,
			BackgroundTransparency = 1,
			Position = UDim2.new(0.5, 0, 0.5, 0),
			Size = halfSize,
			ImageColor3 = UI.Theme.Secondary,
			ImageRectOffset = Vector2.new(960, 960),
			ImageRectSize = Vector2.new(64, 64),
			Image = "rbxassetid://14622698257",
		},

		UI.new "ImageLabel" {
			Name = "BottomLeft",
			Rotation = 180,
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 0, 0.5, 0),
			Size = halfSize,
			ImageColor3 = UI.Theme.Secondary,
			ImageRectOffset = Vector2.new(960, 960),
			ImageRectSize = Vector2.new(64, 64),
			Image = "rbxassetid://14622698257",
		},

		UI.new "ImageLabel" {
			Name = "TopLeft",
			Rotation = 270,
			BackgroundTransparency = 1,
			Size = halfSize,
			ImageColor3 = UI.Theme.Secondary,
			ImageRectOffset = Vector2.new(960, 960),
			ImageRectSize = Vector2.new(64, 64),
			Image = "rbxassetid://14622698257",
		},
	}

	new._instance = UI.new "Frame" {
		Name = "CircleProgress",
		AnchorPoint = Vector2.new(0, 0),
		BackgroundTransparency = 1,
		Size = new.Size,

		UI.new "Frame" {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = UI.Theme.Primary,
			BackgroundTransparency = UI.Theme.Transparency,
			Position = UDim2.new(0.5, 0, 0.5, 0),
			Size = function(use)
				local padding = use(new.Padding).Offset * 2
				return UDim2.new(1, padding, 1, padding)
			end,

			UI.new "UICorner" {
				CornerRadius = UDim.new(1, 0),
			},

			UI.new "UIStroke" {
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Transparency = UI.Theme.TransparencyClamped,
				Color = UI.Theme.Border,
			},
		},
		unpack(new._circles),
	}

	return setmetatable(new, CircleProgress)
end

return CircleProgress
