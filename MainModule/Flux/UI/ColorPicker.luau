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

	local dragging = UI.state(false)

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
				Transparency = UI.Theme.TransparencyClamped,
				Thickness = 1,
			},
			UI.new "UIGradient" {
				Color = rainbowSequence,
			},
		},
	}

	local h, s, v = Color3.toHSV(UI.peek(new.Value))
	local saturationState = UI.state(s)
	local valueState = UI.state(v)
	local hueColor = UI.computeFrom(Color3.fromHSV, hueSlider.Value, 1, 1)

	hueSlider.Value:set(h)
	UI.edit(hueSlider._slider, {
		BackgroundColor3 = hueColor,
		UI.new "UIStroke" {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = Color3.new(1, 1, 1),
			Thickness = 1.5,
		},
	})
	hueSlider._instance:FindFirstChild("Filled"):Destroy()

	local redIgnore, greenIgnore, blueIgnore, hueIgnore, svIgnore, newIgnore

	local redInput = UI.new "Input" {
		BackgroundColor3 = Color3.new(),
		BackgroundTransparency = 0,
		Size = UDim2.new(0, 36, 0, 24),
		Font = UI.Theme.FontMono,
		FontSize = 14,
		TextColor3 = Color3.new(1, 0.3, 0.3),
		Padding = UDim.new(0, 5),
		IntegerOnly = true,
		NumberRange = NumberRange.new(0, 255),
		Value = math.round(new.Value._value.R * 255),

		[UI.Hook] = {
			Value = function(value)
				if redIgnore then
					redIgnore = nil
					return
				end
				local number = tonumber(value)
				if not number then
					return
				end
				local oldColor = new.Value._value
				local newColor = Color3.new(number / 255, oldColor.G, oldColor.B)
				newIgnore = true
				new.Value:set(newColor)
				if math.round(oldColor.R * 255) == number then
					return
				end
				local h, s, v = Color3.toHSV(UI.peek(new.Value))
				hueIgnore, svIgnore = true, true
				hueSlider.Value:set(h)
				saturationState:set(s)
				valueState:set(v)
			end,
		},
	}

	local greenInput = UI.new "Input" {
		BackgroundColor3 = Color3.new(),
		BackgroundTransparency = 0,
		Size = UDim2.new(0, 36, 0, 24),
		Font = UI.Theme.FontMono,
		FontSize = 14,
		TextColor3 = Color3.new(0.4, 1, 0.4),
		Padding = UDim.new(0, 5),
		IntegerOnly = true,
		NumberRange = NumberRange.new(0, 255),
		Value = math.round(new.Value._value.G * 255),

		[UI.Hook] = {
			Value = function(value)
				if greenIgnore then
					greenIgnore = nil
					return
				end
				local number = tonumber(value)
				if not number then
					return
				end
				local oldColor = new.Value._value
				local newColor = Color3.new(oldColor.R, number / 255, oldColor.B)
				newIgnore = true
				new.Value:set(newColor)
				if math.round(oldColor.G * 255) == number then
					return
				end
				local h, s, v = Color3.toHSV(UI.peek(new.Value))
				hueIgnore, svIgnore = true, true
				hueSlider.Value:set(h)
				saturationState:set(s)
				valueState:set(v)
			end,
		},
	}

	local blueInput = UI.new "Input" {
		BackgroundColor3 = Color3.new(),
		BackgroundTransparency = 0,
		Size = UDim2.new(0, 36, 0, 24),
		Font = UI.Theme.FontMono,
		FontSize = 14,
		TextColor3 = Color3.new(0.4, 0.8, 1),
		Padding = UDim.new(0, 5),
		IntegerOnly = true,
		NumberRange = NumberRange.new(0, 255),
		Value = math.round(new.Value._value.B * 255),

		[UI.Hook] = {
			Value = function(value)
				if blueIgnore then
					blueIgnore = nil
					return
				end
				local number = tonumber(value)
				if not number then
					return
				end
				local oldColor = new.Value._value
				local newColor = Color3.new(oldColor.R, oldColor.G, number / 255)
				newIgnore = true
				new.Value:set(newColor)
				if math.round(oldColor.B * 255) == number then
					return
				end
				local h, s, v = Color3.toHSV(UI.peek(new.Value))
				hueIgnore, svIgnore = true, true
				hueSlider.Value:set(h)
				saturationState:set(s)
				valueState:set(v)
			end,
		},
	}

	local sv, dragInput
	local function update(input)
		if not dragInput then
			return
		end
		-- stylua: ignore
		local h = hueSlider._value
		local s = math.clamp((input.Position.X - sv.AbsolutePosition.X - 8) / (sv.AbsoluteSize.X - 16), 0, 1)
		local v = 1 - math.clamp((input.Position.Y - sv.AbsolutePosition.Y - 8) / (sv.AbsoluteSize.Y - 16), 0, 1)
		saturationState:set(s)
		valueState:set(v)

		if svIgnore then
			svIgnore = nil
			return
		end

		local color = Color3.fromHSV(h, s, v)
		redIgnore, greenIgnore, blueIgnore, newIgnore = true, true, true, true
		redInput._input.Text = math.round(color.R * 255)
		greenInput._input.Text = math.round(color.G * 255)
		blueInput._input.Text = math.round(color.B * 255)
		new.Value:set(color)
	end

	new.Value:hook(function(value)
		if newIgnore then
			newIgnore = nil
			return
		end
		local h, s, v = Color3.toHSV(value)
		hueSlider.Value:set(h)
		saturationState:set(s)
		valueState:set(v)
		redInput._input.Text = math.round(value.R * 255)
		greenInput._input.Text = math.round(value.G * 255)
		blueInput._input.Text = math.round(value.B * 255)
	end)

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

	hueSlider.Value:hook(function(value)
		if hueIgnore then
			hueIgnore = nil
			return
		end
		local color = Color3.fromHSV(value, saturationState._value, valueState._value)
		redIgnore, greenIgnore, blueIgnore, newIgnore = true, true, true, true
		redInput._input.Text = math.round(color.R * 255)
		greenInput._input.Text = math.round(color.G * 255)
		blueInput._input.Text = math.round(color.B * 255)
		new.Value:set(color)
	end)

	local inputFrame = UI.new "Frame" {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(36, 72),

		UI.new "UIListLayout" { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UI.Theme.Padding },
		redInput,
		greenInput,
		blueInput,
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
			Transparency = UI.Theme.TransparencyClamped,
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
			Name = "PickerContainer",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 1, 0),
			ZIndex = 3,

			UI.new "UIPadding" {
				PaddingLeft = UDim.new(0, 8),
				PaddingRight = UDim.new(0, 8),
				PaddingTop = UDim.new(0, 8),
				PaddingBottom = UDim.new(0, 8),
			},
			UI.new "Frame" {
				Name = "Picker",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = new.Value,
				Size = UI.tween(
					UI.Theme.TweenOut,
					UI.compute(function(use)
						return if use(dragging) then UDim2.new(0, 16, 0, 16) else UDim2.new(0, 8, 0, 8)
					end)
				),
				Position = UI.tween(
					UI.Theme.TweenOut,
					UI.compute(function(use)
						return UDim2.new(use(saturationState), 0, 1 - use(valueState), 0)
					end)
				),

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
