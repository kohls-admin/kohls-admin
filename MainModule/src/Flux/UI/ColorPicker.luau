local UserInputService = game:GetService("UserInputService")

local UI = require(script.Parent)
local BaseClass = require(script.Parent.BaseClass)

local rainbowSequence = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
	ColorSequenceKeypoint.new(1 / 6, Color3.fromRGB(255, 255, 0)),
	ColorSequenceKeypoint.new(1 / 3, Color3.fromRGB(0, 255, 0)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 255, 255)),
	ColorSequenceKeypoint.new(2 / 3, Color3.fromRGB(0, 0, 255)),
	ColorSequenceKeypoint.new(5 / 6, Color3.fromRGB(255, 0, 255)),
	ColorSequenceKeypoint.new(1.0, Color3.fromRGB(255, 0, 0)),
})

local ColorPicker = {}
ColorPicker.__index = ColorPicker
setmetatable(ColorPicker, BaseClass)

function ColorPicker.new(definition)
	local new = UI.makeStatefulDefaults({
		Value = Color3.new(1, 0, 0),
	}, definition)

	-- TODO: create hue vertical slider
	local hueSlider = UI.new "Slider" {
		Name = "HueSlider",
		Size = UI.compute(function(use)
			return UDim2.new(0, 36 + (24 + use(UI.Theme.Padding).Offset) * 3, 0, 24)
		end),

		UI.new "Frame" {
			Name = "Rainbow",
			BackgroundColor3 = Color3.new(1, 1, 1),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.new(1, 0, 1, 0),
			Position = UDim2.new(0.5, 0, 0.5, 0),

			UI.new "UICorner" {
				CornerRadius = UI.Theme.CornerDiameter,
			},
			UI.new "UIStroke" {
				Enabled = UI.Theme.StrokeEnabled,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Color = UI.Theme.Border,
				Transparency = UI.Theme.Transparency,
				Thickness = 1,
			},
			UI.new "UIGradient" {
				Color = rainbowSequence,
			},
		},
	}

	local h, s, v = Color3.toHSV(UI.peek(new.Value))
	hueSlider.Value:set(h)

	local dragging = UI.state(false)
	local saturationState = UI.state(s)
	local valueState = UI.state(v)
	local hueColor = UI.computeFrom(Color3.fromHSV, hueSlider.Value, 1, 1)
	new.Value = UI.computeFrom(Color3.fromHSV, hueSlider.Value, saturationState, valueState)

	UI.edit(hueSlider._slider, {
		BackgroundColor3 = hueColor,
		UI.new "UIStroke" {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = Color3.new(1, 1, 1),
			Thickness = 1.5,
		},
	})
	hueSlider._instance:FindFirstChild("Filled"):Destroy()

	local sv, dragInput
	local function update(input)
		if not dragInput then
			return
		end
		saturationState:set(math.clamp((input.Position.X - sv.AbsolutePosition.X) / sv.AbsoluteSize.X, 0, 1))
		valueState:set(1 - math.clamp((input.Position.Y - sv.AbsolutePosition.Y) / sv.AbsoluteSize.Y, 0, 1))
	end

	local function inputBegan(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragInput = input
			dragging:set(true)
			local con
			con = input:GetPropertyChangedSignal("UserInputState"):Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					con:Disconnect()
					if dragInput == input then
						dragInput = nil
						dragging:set(false)
					end
				end
			end)
			update(input)
		end
	end

	UserInputService.InputChanged:Connect(update)

	local inputFrame = UI.new "Frame" {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(36, 72),

		UI.new "UIListLayout" { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UI.Theme.Padding },
		UI.new "Input" {
			Size = UDim2.new(0, 36, 0, 24),
			Font = UI.Theme.FontMono,
			FontSize = 14,
			TextColor3 = Color3.new(1, 0.3, 0.3),
			Padding = UDim.new(0, 5),
			IntegerOnly = true,
			NumberRange = NumberRange.new(0, 255),
			Value = UI.compute(function(use)
				return math.round(use(new.Value).R * 255)
			end),

			[UI.Hook] = {
				Value = function(value)
					local oldColor = new.Value._value
					if math.round(oldColor.R * 255) == value then
						return
					end
					new.Value:set(Color3.new(value / 255, oldColor.G, oldColor.B))
				end,
			},
		},
		UI.new "Input" {
			Size = UDim2.new(0, 36, 0, 24),
			Font = UI.Theme.FontMono,
			FontSize = 14,
			TextColor3 = Color3.new(0.4, 1, 0.4),
			Padding = UDim.new(0, 5),
			IntegerOnly = true,
			NumberRange = NumberRange.new(0, 255),
			Value = UI.compute(function(use)
				return math.round(use(new.Value).G * 255)
			end),

			[UI.Hook] = {
				Value = function(value)
					local oldColor = new.Value._value
					if math.round(oldColor.G * 255) == value then
						return
					end
					new.Value:set(Color3.new(oldColor.B, value / 255, oldColor.B))
				end,
			},
		},
		UI.new "Input" {
			Size = UDim2.new(0, 36, 0, 24),
			Font = UI.Theme.FontMono,
			FontSize = 14,
			TextColor3 = Color3.new(0.4, 0.6, 1),
			Padding = UDim.new(0, 5),
			IntegerOnly = true,
			NumberRange = NumberRange.new(0, 255),
			Value = UI.compute(function(use)
				return math.round(use(new.Value).B * 255)
			end),

			[UI.Hook] = {
				Value = function(value)
					local oldColor = new.Value._value
					if math.round(oldColor.B * 255) == value then
						return
					end
					new.Value:set(Color3.new(oldColor.R, oldColor.G, value / 255))
				end,
			},
		},
	}

	sv = UI.new "Frame" {
		Name = "SaturationValue",
		BackgroundColor3 = hueColor,
		Size = UI.compute(function(use)
			local size = 24 * 3 + use(UI.Theme.PaddingDouble).Offset
			return UDim2.fromOffset(size, size)
		end),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,

		UI.new "UICorner" {
			CornerRadius = UI.Theme.CornerRadius,
		},
		UI.new "UIStroke" {
			Enabled = UI.Theme.StrokeEnabled,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = UI.Theme.Border,
			Transparency = UI.Theme.Transparency,
			Thickness = 1,
		},
		UI.new "Frame" {
			Name = "Saturation",
			BackgroundColor3 = Color3.new(1, 1, 1),
			Size = UDim2.new(1, 0, 1, 0),

			UI.new "UICorner" {
				CornerRadius = UI.Theme.CornerRadius,
			},
			UI.new "UIGradient" {
				Color = ColorSequence.new(Color3.new(1, 1, 1)),
				Transparency = NumberSequence.new(0, 1),
			},
		},
		UI.new "Frame" {
			Name = "Value",
			BackgroundColor3 = Color3.new(0, 0, 0),
			Size = UDim2.new(1, 0, 1, 0),
			ZIndex = 2,

			UI.new "UICorner" {
				CornerRadius = UI.Theme.CornerRadius,
			},
			UI.new "UIGradient" {
				Color = ColorSequence.new(Color3.new()),
				Transparency = NumberSequence.new(0, 1),
				Rotation = -90,
			},
		},
		UI.new "Frame" {
			Name = "Picker",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = new.Value,
			Size = UI.tween(
				UI.Theme.NormalTween,
				UI.compute(function(use)
					return if use(dragging) then UDim2.new(0, 16, 0, 16) else UDim2.new(0, 8, 0, 8)
				end)
			),
			Position = UI.tween(
				UI.Theme.NormalTween,
				UI.compute(function(use)
					return UDim2.new(use(saturationState), 0, 1 - use(valueState), 0)
				end)
			),
			ZIndex = 3,

			UI.new "UICorner" {
				CornerRadius = UI.Theme.CornerDiameter,
			},
			UI.new "UIStroke" {
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Color = Color3.new(1, 1, 1),
				Thickness = 1.5,
			},

			[UI.Event] = {
				InputBegan = inputBegan,
			},
		},
		[UI.Event] = {
			InputBegan = inputBegan,
		},
	}

	new._instance = UI.new "Frame" {
		Name = "ColorPicker",
		Active = true,
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.new(0, 88, 0, 72),

		UI.new "UIListLayout" {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UI.Theme.Padding,
		},
		UI.new "UIPadding" {
			PaddingLeft = UI.Theme.Padding,
			PaddingRight = UI.Theme.Padding,
			PaddingTop = UI.Theme.Padding,
			PaddingBottom = UI.Theme.Padding,
		},

		UI.new "Frame" {
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.XY,

			UI.new "UIListLayout" {
				SortOrder = Enum.SortOrder.LayoutOrder,
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UI.Theme.Padding,
			},

			inputFrame,
			sv,
		},
		hueSlider,
	}

	return setmetatable(new, ColorPicker)
end

return ColorPicker
