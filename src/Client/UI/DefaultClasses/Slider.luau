local UserInputService = game:GetService("UserInputService")

local UI = require(script.Parent.Parent)
local BaseClass = require(script.Parent.BaseClass)

local Slider = {}
Slider.__index = Slider
setmetatable(Slider, BaseClass)

function Slider.new(definition)
	local new = UI.makeStatefulDefaults({
		_instance = nil,
		Snap = 0,
		SnapSound = true,
		Value = 1,
		Selected = 1,
		Vertical = false,
	}, definition)

	new.Selected._value = UI.peek(new.Value)

	local dragInput
	local dragging = UI.state(false)
	local valueAlpha = UI.compute(function(use)
		local snap = use(new.Snap)
		local value = use(new.Value)
		return if snap > 1 then math.max(0, value - 1) / (snap - 1) else value
	end)

	local function update(input)
		if not dragInput then
			return
		end
		-- stylua: ignore
		local value = if new.Vertical._value
			then math.clamp((input.Position.Y - new._instance.AbsolutePosition.Y - 12) / (new._instance.AbsoluteSize.Y - 24), 0, 1)
			else math.clamp((input.Position.X - new._instance.AbsolutePosition.X - 12) / (new._instance.AbsoluteSize.X - 24), 0, 1)
		local snap = new.Snap._value

		if snap > 1 then
			value = math.round(1 + value * (snap - 1))

			if new.SnapSound._value and new.Value._value ~= value then
				UI.Sound.Hover02:Play()
			end
		end

		new.Selected:set(value, true)
		new.Value:set(value)
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

	new._slider = UI.new "Frame" {
		Name = "Slider",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = UI.Theme.SecondaryText,
		Position = UI.tween(
			UI.Theme.TweenOut,
			UI.compute(function(use)
				return if use(new.Vertical)
					then UDim2.new(0.5, 0, use(valueAlpha), 0)
					else UDim2.new(use(valueAlpha), 0, 0.5, 0)
			end)
		),
		Size = UI.tween(
			UI.Theme.TweenOut,
			UI.compute(function(use)
				local size = use(UI.Theme.FontSize)
				local half = size / 2
				return if use(dragging) then UDim2.new(0, size, 0, size) else UDim2.new(0, half, 0, half)
			end)
		),

		UI.new "UICorner" {
			CornerRadius = UI.Theme.CornerDiameter,
		},

		[UI.Event] = {
			InputBegan = inputBegan,
		},
	}

	new._instance = UI.new "Frame" {
		Name = "Slider",
		Active = true,
		BackgroundColor3 = UI.Theme.Secondary,
		BackgroundTransparency = UI.Theme.TransparencyOverlay,
		Size = UI.compute(function(use)
			local height = use(UI.Theme.FontSize) + use(UI.Theme.Padding).Offset
			return if use(new.Vertical) then UDim2.new(0, height, 1, 0) else UDim2.new(1, 0, 0, height)
		end),

		UI.new "UICorner" {
			CornerRadius = UI.Theme.CornerDiameter,
		},
		UI.new "UIStroke" {
			Enabled = UI.Theme.StrokeEnabled,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Transparency = UI.Theme.TransparencyClamped,
			Color = UI.Theme.Border,
		},

		UI.new "Frame" {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 1, 0),
			ZIndex = 2,

			UI.new "UIPadding" {
				PaddingTop = UDim.new(0, 12),
				PaddingBottom = UDim.new(0, 12),
				PaddingLeft = UDim.new(0, 12),
				PaddingRight = UDim.new(0, 12),
			},
			new._slider,
		},

		UI.new "Frame" {
			Name = "Filled",
			BackgroundColor3 = UI.Theme.Secondary,
			BorderSizePixel = 0,
			Size = UI.tween(
				UI.Theme.TweenOut,
				UI.compute(function(use)
					local alpha = use(valueAlpha)
					local buffer = 24 * (1 - alpha)
					return if use(new.Vertical) then UDim2.new(1, 0, alpha, buffer) else UDim2.new(alpha, buffer, 1, 0)
				end)
			),

			UI.new "UICorner" {
				CornerRadius = UI.Theme.CornerDiameter,
			},
		},

		[UI.Event] = {
			InputBegan = inputBegan,
		},
	}

	return setmetatable(new, Slider)
end

return Slider
