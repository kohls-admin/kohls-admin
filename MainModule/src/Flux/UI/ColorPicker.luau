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
		Vertical = true,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.new(0, 16, 1, 0),

		[UI.Children] = {
			Rainbow = UI.new "Frame" {
				BackgroundColor3 = Color3.new(1, 1, 1),
				AnchorPoint = Vector2.new(0.5, 0),
				Size = UDim2.new(0, 4, 1, 0),
				Position = UDim2.new(0.5, 0, 0, 0),

				[UI.Children] = {
					UICorner = UI.new "UICorner" {
						CornerRadius = UI.Theme.CornerRadius,
					},
					UIStroke = UI.new "UIStroke" {
						Enabled = UI.Theme.StrokeEnabled,
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
						Color = UI.Theme.Border,
						Transparency = UI.Theme.Transparency,
						Thickness = 1,
					},
					UIGradient = UI.new "UIGradient" {
						Color = rainbowSequence,
						Rotation = 90,
					},
				},
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

	UI.edit(hueSlider._instance:FindFirstChild("Slider"), {
		BackgroundColor3 = hueColor,

		[UI.Children] = {
			UIStroke = UI.new "UIStroke" {
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Color = Color3.new(1, 1, 1),
				Thickness = 1.5,
			},
		},
	})
	hueSlider._instance:FindFirstChild("Filled"):Destroy()
	hueSlider._instance:FindFirstChild("Unfilled"):Destroy()

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
					print("End")
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

	new._instance = UI.new "Frame" {
		Name = "ColorPicker",
		Active = true,
		BackgroundTransparency = 1,
		Size = UI.compute(function(use)
			local offset = use(UI.Theme.PaddingDouble).Offset
			return UDim2.new(0, 80 + offset * 1.5, 0, 64 + offset)
		end),

		UI.new "UIPadding" {
			PaddingLeft = UI.Theme.Padding,
			PaddingRight = UI.Theme.Padding,
			PaddingTop = UI.Theme.Padding,
			PaddingBottom = UI.Theme.Padding,
		},

		[UI.Children] = {
			hueSlider = hueSlider,
			SaturationValue = UI.new "Frame" {
				BackgroundColor3 = hueColor,
				Size = UDim2.new(1, 0, 1, 0),
				SizeConstraint = Enum.SizeConstraint.RelativeYY,

				[UI.Children] = {
					UICorner = UI.new "UICorner" {
						CornerRadius = UI.Theme.CornerRadius,
					},
					UIStroke = UI.new "UIStroke" {
						Enabled = UI.Theme.StrokeEnabled,
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
						Color = UI.Theme.Border,
						Transparency = UI.Theme.Transparency,
						Thickness = 1,
					},

					Saturation = UI.new "Frame" {
						BackgroundColor3 = Color3.new(1, 1, 1),
						Size = UDim2.new(1, 0, 1, 0),

						[UI.Children] = {
							UICorner = UI.new "UICorner" {
								CornerRadius = UI.Theme.CornerRadius,
							},
							UIGradient = UI.new "UIGradient" {
								Color = ColorSequence.new(Color3.new(1, 1, 1)),
								Transparency = NumberSequence.new(0, 1),
							},
						},
					},

					Value = UI.new "Frame" {
						BackgroundColor3 = Color3.new(0, 0, 0),
						Size = UDim2.new(1, 0, 1, 0),
						ZIndex = 2,

						[UI.Children] = {
							UICorner = UI.new "UICorner" {
								CornerRadius = UI.Theme.CornerRadius,
							},
							UIGradient = UI.new "UIGradient" {
								Color = ColorSequence.new(Color3.new()),
								Transparency = NumberSequence.new(0, 1),
								Rotation = -90,
							},
						},
					},

					Picker = UI.new "Frame" {
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

						[UI.Children] = {
							UICorner = UI.new "UICorner" {
								CornerRadius = UI.Theme.CornerDiameter,
							},
							UIStroke = UI.new "UIStroke" {
								ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
								Color = Color3.new(1, 1, 1),
								Thickness = 1.5,
							},
						},

						[UI.Event] = {
							InputBegan = inputBegan,
						},
					},
				},

				[UI.Event] = {
					InputBegan = inputBegan,
				},
			},
		},
	}

	sv = new._instance:FindFirstChild("SaturationValue")

	return setmetatable(new, ColorPicker)
end

return ColorPicker
