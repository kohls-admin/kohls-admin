-- snap show value/tickmarks?

local ceil, floor = math.ceil, math.floor
local function round(n, x)
	return n < 0 and (x and ceil(n / x - 0.5) * x or ceil(n - 0.5)) or (x and floor(n / x + 0.5) * x or floor(n + 0.5))
end

local Object
do
	Object = Instance.new("Frame")
	Object.Name = "Slider"
	Object.Active = true
	Object.BackgroundTransparency = 1
	Object.Size = UDim2.new(1, 0, 1, 0)

	local Bar1 = Instance.new("Frame", Object)
	Bar1.Name = "Bar1"
	Bar1.AnchorPoint = Vector2.new(0, 0.5)
	Bar1.BorderSizePixel = 0
	Bar1.BackgroundColor3 = Color3.new(1, 1, 1) -- theme.Secondary
	Bar1.Position = UDim2.new(0, 0, 0.5, 0)
	Bar1.Size = UDim2.new(0, 0, 0, 2)

	local Bar2 = Bar1:Clone()
	Bar2.Name = "Bar2"
	Bar2.Parent = Object
	Bar2.BackgroundTransparency = 0.75
	Bar2.Position = UDim2.new(0, 0, 0.5, 0)
	Bar2.Size = UDim2.new(1, 0, 0, 2)

	local Slider = Instance.new("ImageLabel", Object)
	Slider.Name = "Slider"
	Slider.BackgroundTransparency = 1
	Slider.Image = "rbxassetid://1447652759"
	Slider.ImageColor3 = Color3.new(1, 1, 1)
	Slider.AnchorPoint = Vector2.new(0.5, 0.5)
	Slider.Position = UDim2.new(0, 0, 0.5, 0)
	Slider.Size = UDim2.new(0, 8, 0, 8)
	SizeConstraint = Enum.SizeConstraint.RelativeXX
end

local Class = require(script.Parent)

return Class:Create({
	_name = "Slider",
	_super = "BaseClass",

	_event = { "Updated" },

	_prop = {
		Snap = function(self, value)
			Class.CheckType(value, "number")
			self:rawset("Snap", math.max(1, value - 1))
		end,

		Value = function(self, value)
			Class.CheckType(value, "number")
			self:rawset("Value", value)
			self.Updated:Fire(value)
		end,
	},

	_init = function(self)
		local rbx = Object:Clone()
		self:rawset("_rbx", rbx) -- read-only

		self.ThemeData[rbx.Bar1] = { BackgroundColor3 = "Secondary" }
		self.ThemeData[rbx.Bar2] = { BackgroundColor3 = "Primary" }
		self.ThemeData[rbx.Slider] = { BackgroundColor3 = "Secondary" }

		local dragging, dragInput

		local function Update(input)
			local snap, value =
				self.Snap, math.max(0, math.min(1, (input.Position.X - rbx.AbsolutePosition.X) / rbx.AbsoluteSize.X))
			if snap then
				value = round(value, 1 / snap)
			end
			rbx.Slider:TweenPosition(UDim2.new(value, 0, 0.5, 0), "Out", "Quad", 0.1, true)
			rbx.Bar1:TweenSize(UDim2.new(value, 0, 0, 2), "Out", "Quad", 0.1, true)
			rbx.Bar2:TweenSizeAndPosition(
				UDim2.new(1 - value, 0, 0, 2),
				UDim2.new(value, 0, 0.5, 0),
				"Out",
				"Quad",
				0.1,
				true
			)
			self:rawset("Value", value)
			self.Updated:Fire(snap and snap * value + 1 or value)
		end

		rbx.InputBegan:Connect(function(input)
			if
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				dragging = true
				rbx.Slider:TweenSize(UDim2.new(0, 16, 0, 16), "Out", "Quad", 0.1, true)
				input.Changed:Connect(function()
					if input.UserInputState == Enum.UserInputState.End then
						dragging = false
						rbx.Slider:TweenSize(UDim2.new(0, 8, 0, 8), "Out", "Quad", 0.1, true)
					end
				end)
				Update(input)
			end
		end)

		rbx.InputChanged:Connect(function(input)
			if
				input.UserInputType == Enum.UserInputType.MouseMovement
				or input.UserInputType == Enum.UserInputType.Touch
			then
				dragInput = input
			end
		end)

		game:GetService("UserInputService").InputChanged:Connect(function(input)
			if input == dragInput and dragging then
				Update(input)
			end
		end)
	end,
})
