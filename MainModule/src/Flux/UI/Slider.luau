local UserInputService = game:GetService("UserInputService")

local UI = require(script.Parent)
local BaseClass = require(script.Parent.BaseClass)

local Slider = {}
Slider.__index = Slider
setmetatable(Slider, BaseClass)

function Slider.new(definition)
	local new = UI.makeStatefulDefaults({
		_instance = nil,
		Snap = 0,
		Value = 1,
		Vertical = false,
	}, definition)

	local dragInput
	local dragging = UI.state(false)
	local valueAlpha = UI.state(
		if new.Snap._value > 1 then math.max(0, new.Value._value - 1) / (new.Snap._value - 1) else new.Value._value
	)

	local function update(input)
		if not dragInput then
			return
		end
		-- stylua: ignore
		local value = if new.Vertical._value
			then math.clamp((input.Position.Y - new._instance.AbsolutePosition.Y) / new._instance.AbsoluteSize.Y, 0, 1)
			else math.clamp((input.Position.X - new._instance.AbsolutePosition.X) / new._instance.AbsoluteSize.X, 0, 1)
		local snap = new.Snap._value

		if snap > 1 then
			local snapInt = math.round(1 + value * (snap - 1))
			valueAlpha:set(math.max(0, snapInt - 1) / (snap - 1))
			value = snapInt
		else
			valueAlpha:set(value)
		end

		new.Value:set(value)
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

	new._instance = UI.new "Frame" {
		Name = "Slider",
		Active = true,
		BackgroundTransparency = 1,
		Size = UI.compute(function(use)
			return if use(new.Vertical) then UDim2.new(0, 24, 1, 0) else UDim2.new(1, 0, 0, 24)
		end),

		[UI.Children] = {
			Slider = UI.new "Frame" {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = UI.Theme.Secondary,
				ZIndex = 2,
				Position = UI.tween(
					UI.Theme.NormalTween,
					UI.compute(function(use)
						return if use(new.Vertical)
							then UDim2.new(0.5, 0, use(valueAlpha), 0)
							else UDim2.new(use(valueAlpha), 0, 0.5, 0)
					end)
				),
				Size = UI.tween(
					UI.Theme.NormalTween,
					UI.compute(function(use)
						return if use(dragging) then UDim2.new(0, 16, 0, 16) else UDim2.new(0, 8, 0, 8)
					end)
				),

				[UI.Children] = {
					UICorner = UI.new "UICorner" {
						CornerRadius = UI.Theme.CornerDiameter,
					},
				},

				[UI.Event] = {
					InputBegan = inputBegan,
				},
			},

			Filled = UI.new "Frame" {
				AnchorPoint = UI.compute(function(use)
					return if use(new.Vertical) then Vector2.new(0.5, 0) else Vector2.new(0, 0.5)
				end),
				BackgroundColor3 = UI.Theme.Secondary,
				BackgroundTransparency = UI.Theme.Transparency,
				BorderSizePixel = 0,
				Position = UI.compute(function(use)
					return if use(new.Vertical) then UDim2.new(0.5, 0, 0, 0) else UDim2.new(0, 0, 0.5, 0)
				end),
				Size = UI.tween(
					UI.Theme.NormalTween,
					UI.compute(function(use)
						return if use(new.Vertical)
							then UDim2.new(0, 2, use(valueAlpha), 0)
							else UDim2.new(use(valueAlpha), 0, 0, 2)
					end)
				),
			},

			Unfilled = UI.new "Frame" {
				AnchorPoint = UI.compute(function(use)
					return if use(new.Vertical) then Vector2.new(0.5, 1) else Vector2.new(1, 0.5)
				end),
				BackgroundColor3 = UI.Theme.Border,
				BackgroundTransparency = UI.Theme.Transparency,
				BorderSizePixel = 0,
				Position = UI.compute(function(use)
					return if use(new.Vertical) then UDim2.new(0.5, 0, 1, 0) else UDim2.new(1, 0, 0.5, 0)
				end),
				Size = UI.tween(
					UI.Theme.NormalTween,
					UI.compute(function(use)
						return if use(new.Vertical)
							then UDim2.new(0, 2, 1 - use(valueAlpha), 0)
							else UDim2.new(1 - use(valueAlpha), 0, 0, 2)
					end)
				),
			},
		},

		[UI.Event] = {
			InputBegan = inputBegan,
		},
	}

	return setmetatable(new, Slider)
end

return Slider
