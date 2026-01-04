local UI = require(script.Parent.Parent) :: any
local BaseClass = require(script.Parent:WaitForChild("BaseClass"))

local DEFAULT = {
	Alpha = 0,
	Image = UI.Theme.Image.Circle,
}

type Properties = typeof(DEFAULT) & Frame

local halfMask = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0),
	NumberSequenceKeypoint.new(0.5, 0),
	NumberSequenceKeypoint.new(0.5, 1),
	NumberSequenceKeypoint.new(1, 1),
})

local Class = {}
Class.__index = Class
setmetatable(Class, BaseClass)

function Class.new(properties: Properties?)
	local self = table.clone(DEFAULT)
	UI.makeStatefulDefaults(self, properties)

	self._instance = UI.new "Frame" {
		Name = "CircleProgress",
		AnchorPoint = Vector2.new(0, 0),
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(64, 64),

		UI.new "Frame" {
			Name = "Left",
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			Size = UDim2.fromScale(0.5, 1),
			Visible = function()
				return self.Alpha() > 0.5
			end,

			UI.new "ImageLabel" {
				BackgroundTransparency = 1,
				ImageColor3 = UI.Theme.Secondary,
				Image = self.Image,
				Size = UDim2.fromScale(2, 1),

				UI.new "UIGradient" {
					Transparency = halfMask,
					Rotation = function()
						return math.clamp(self.Alpha() * 360 - 360, -180, 0)
					end,
				},
			},
		},

		UI.new "Frame" {
			Name = "Right",
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			Position = UDim2.fromScale(0.5, 0),
			Size = UDim2.fromScale(0.5, 1),
			Visible = function()
				return self.Alpha() > 0
			end,

			UI.new "ImageLabel" {
				BackgroundTransparency = 1,
				ImageColor3 = UI.Theme.Secondary,
				Image = self.Image,
				Position = UDim2.fromScale(-1, 0),
				Size = UDim2.fromScale(2, 1),

				UI.new "UIGradient" {
					Transparency = halfMask,
					Rotation = function()
						return math.clamp(self.Alpha() * 360, 0, 180)
					end,
				},
			},
		},
	} :: Frame & {
		Left: Frame & { ImageLabel: ImageLabel & { UIGradient: UIGradient } },
		Right: Frame & { ImageLabel: ImageLabel & { UIGradient: UIGradient } },
	}

	return setmetatable(self, Class) :: typeof(self) & typeof(Class)
end

return Class
