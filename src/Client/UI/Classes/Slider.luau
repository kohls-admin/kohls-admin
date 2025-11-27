local UI = require(script.Parent.Parent) :: any
local BaseClass = require(script.Parent.BaseClass)

local DEFAULT = {
	Snap = 0,
	SnapSound = true,
	Value = 1,
	Vertical = false,
}

type Properties = typeof(DEFAULT) & Frame

local Class = {}
Class.__index = Class
setmetatable(Class, BaseClass)

function Class.new(properties: Properties?)
	local self = table.clone(DEFAULT)
	UI.makeStatefulDefaults(self, properties)

	local cleanup = {}

	local dragInput
	local dragging = UI.state(false)
	self._dragging = dragging

	local valueAlpha = UI.compute(function()
		local snap = self.Snap()
		local value = self.Value()
		return if snap > 1 then math.max(0, value - 1) / (snap - 1) else value
	end)

	table.insert(cleanup, valueAlpha)

	local function update(input)
		if not dragInput then
			return
		end
		-- stylua: ignore
		local value = if self.Vertical._value
			then math.clamp((input.Position.Y - self._instance.AbsolutePosition.Y - 12) / (self._instance.AbsoluteSize.Y - 24), 0, 1)
			else math.clamp((input.Position.X - self._instance.AbsolutePosition.X - 12) / (self._instance.AbsoluteSize.X - 24), 0, 1)
		local snap = self.Snap._value

		if snap > 1 then
			value = math.round(1 + value * (snap - 1))

			if self.SnapSound._value and self.Value._value ~= value then
				UI.Sound.Hover02:Play()
			end
		end

		self.Value(value, true)
	end

	local function inputBegan(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			UI.Sound.Hover03:Play()
			dragInput = input
			dragging(true)
			local con
			con = input:GetPropertyChangedSignal("UserInputState"):Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					con:Disconnect()
					if dragInput == input then
						UI.Sound.Hover01:Play()
						dragInput = nil
						dragging(false)
					end
				end
			end)
			update(input)
		end
	end

	table.insert(cleanup, UI.UserInputService.InputChanged:Connect(update))

	self._slider = UI.new "Frame" {
		Name = "Slider",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = UI.Theme.SecondaryText,
		Position = function()
			return if self.Vertical() then UDim2.new(0.5, 0, valueAlpha(), 0) else UDim2.new(valueAlpha(), 0, 0.5, 0)
		end,
		Size = UI.tween(function()
			local size = UI.Theme.FontSize()
			local half = size / 2
			return if dragging() then UDim2.new(0, size, 0, size) else UDim2.new(0, half, 0, half)
		end, UI.Theme.TweenOut),

		UI.new "UICorner" {
			CornerRadius = UI.Theme.CornerPadded,
		},

		InputBegan = inputBegan,
	} :: Frame & { UICorner: UICorner }

	local padding = UI.compute(function()
		return UDim.new(0, UI.Theme.FontSizeSmaller() + UI.Theme.PaddingHalf().Offset)
	end)

	table.insert(cleanup, padding)

	self._instance = UI.new "Frame" {
		Name = "Slider",
		Active = true,
		BackgroundColor3 = UI.Theme.Secondary,
		BackgroundTransparency = UI.Theme.TransparencyHeavy,
		Size = function()
			local height = UI.Theme.FontSize() + UI.Theme.Padding().Offset
			return if self.Vertical() then UDim2.new(0, height, 1, 0) else UDim2.new(1, 0, 0, height)
		end,

		UI.new "UICorner" {
			CornerRadius = UI.Theme.CornerPadded,
		},
		UI.new "Stroke" {},

		UI.new "Frame" {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 1, 0),
			ZIndex = 2,

			UI.new "UIPadding" {
				PaddingTop = padding,
				PaddingBottom = padding,
				PaddingLeft = padding,
				PaddingRight = padding,
			},
			self._slider,
		},

		UI.new "Frame" {
			Name = "Filled",
			BackgroundColor3 = UI.Theme.Secondary,
			BorderSizePixel = 0,
			Size = function()
				local alpha = valueAlpha()
				local buffer = (UI.Theme.FontSize() + UI.Theme.Padding().Offset) * (1 - alpha)
				return if self.Vertical() then UDim2.new(1, 0, alpha, buffer) else UDim2.new(alpha, buffer, 1, 0)
			end,

			UI.new "UICorner" {
				CornerRadius = UI.Theme.CornerPadded,
			},
		},

		InputBegan = inputBegan,

		[UI.Clean] = cleanup,
	} :: Frame & {
		UICorner: UICorner,
		UIStroke: UIStroke,
		Frame: Frame & { UIPadding: UIPadding, Slider: typeof(self._slider) },
		Filled: Frame & { UICorner: UICorner },
	}

	return setmetatable(self, Class) :: typeof(self) & typeof(Class)
end

return Class
