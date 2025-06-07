local UserInputService = game:GetService("UserInputService")

local UI = require(script.Parent.Parent)
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

local menuCornerRadius = UI.compute(function(use)
	return UDim.new(0, use(UI.Theme.CornerRadius).Offset + use(UI.Theme.Padding).Offset)
end)

function ColorPicker.new(definition)
	local new = UI.makeStatefulDefaults({
		Adornee = false,
		RightAlign = false,
		Visible = false,
		Value = Color3.new(1, 0, 0),
		Selected = Color3.new(1, 0, 0),
	}, definition)

	new.Selected._value = UI.peek(new.Value)

	local dragging = UI.state(false)

	local hueSlider = UI.new "Slider" {
		Name = "HueSlider",
		SnapSound = false,
		Size = UI.compute(function(use)
			return UDim2.new(0, 36 + (24 + use(UI.Theme.Padding).Offset) * 3, 0, 24)
		end),
		Value = UI.compute(function(use)
			local h = use(new.Value):ToHSV()
			return h
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

		[UI.Hook] = {
			Selected = function(value)
				local _, s, v = new.Value._value:ToHSV()
				local color = Color3.fromHSV(value, s, v)
				new.Selected:set(color, true)
				new.Value:set(color)
			end,
		},
	}

	local hueColor = UI.computeFrom(Color3.fromHSV, hueSlider.Value, 1, 1)
	UI.edit(hueSlider._slider, {
		BackgroundColor3 = hueColor,
		UI.new "UIStroke" {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = Color3.new(1, 1, 1),
			Thickness = 1.5,
		},
	})
	hueSlider._instance:FindFirstChild("Filled"):Destroy()

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
		Value = UI.compute(function(use)
			return math.round(use(new.Value).R * 255)
		end),

		[UI.Hook] = {
			Selected = function(value)
				local number = tonumber(value)
				if not number then
					return
				end
				local oldColor = new.Value._value
				local newColor = Color3.new(number / 255, oldColor.G, oldColor.B)
				new.Selected:set(newColor, true)
				new.Value:set(newColor)
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
		Value = UI.compute(function(use)
			return math.round(use(new.Value).G * 255)
		end),

		[UI.Hook] = {
			Selected = function(value)
				local number = tonumber(value)
				if not number then
					return
				end
				local oldColor = new.Value._value
				local newColor = Color3.new(oldColor.R, number / 255, oldColor.B)
				new.Selected:set(newColor, true)
				new.Value:set(newColor)
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
		Value = UI.compute(function(use)
			return math.round(use(new.Value).B * 255)
		end),

		[UI.Hook] = {
			Selected = function(value)
				local number = tonumber(value)
				if not number then
					return
				end
				local oldColor = new.Value._value
				local newColor = Color3.new(oldColor.R, oldColor.G, number / 255)
				new.Selected:set(newColor, true)
				new.Value:set(newColor)
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

		local color = Color3.fromHSV(h, s, v)
		new.Selected:set(color, true)
		new.Value:set(color)
	end

	local function inputBegan(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			UI.Sound.Hover03:Play()
			dragInput = input
			dragging:set(true)
			local con
			con = input:GetPropertyChangedSignal("UserInputState"):Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					con:Disconnect()
					if dragInput == input then
						UI.Sound.Hover01:Play()
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
						local _, s, v = use(new.Value):ToHSV()
						return UDim2.new(s, 0, 1 - v, 0)
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

	new._menu = UI.new "Menu" {
		Name = "ColorPicker",
		Adornee = new.Adornee,
		RightAlign = new.RightAlign,
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.new(0, 88, 0, 72),
		Visible = new.Visible,

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
	new._menu._content.AutomaticSize = Enum.AutomaticSize.XY
	UI.edit(new._menu._list, { Padding = UI.Theme.Padding })
	new._instance = new._menu._instance
	UI.edit(new._instance.UICorner, { CornerRadius = menuCornerRadius })

	return setmetatable(new, ColorPicker)
end

return ColorPicker
