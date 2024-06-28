--[[	DOCUMENTATION


--]]

local Class = require(script.Parent)

local Object
do
	Object = Instance.new("Frame")
	Object.Name = "TextField"
	Object.BackgroundTransparency = 1
	Object.Size = UDim2.new(1, 0, 0, 24)

	local Input = Instance.new("TextBox", Object)
	Input.Name = "Input"
	Input.BackgroundTransparency = 1
	Input.AnchorPoint = Vector2.new(0.5, 0.5)
	Input.Position = UDim2.new(0.5, 0, 0.5, 0)
	Input.Size = UDim2.new(1, -8, 1, -8)
	Input.Font = Enum.Font.Roboto
	Input.PlaceholderText = "PlaceholderText"
	Input.Text = ""
	Input.TextSize = 16
	Input.TextColor3 = Color3.new(1, 1, 1)
	Input.TextStrokeTransparency = 0.9
	Input.TextXAlignment = "Left"
	Input.ClearTextOnFocus = false
	Input.ClipsDescendants = true

	local Line = Instance.new("Frame", Object)
	Line.Name = "Line"
	Line.BackgroundColor3 = Color3.new(1, 1, 1)
	Line.BorderSizePixel = 0
	Line.AnchorPoint = Vector2.new(0, 1)
	Line.Position = UDim2.new(0, 0, 1, 0)
	Line.Size = UDim2.new(1, 0, 0, 1)
end

return Class:Create({
	_name = "TextField",
	_super = "BaseClass",

	_event = { "Submit", "Updated" },

	_hide = {},

	_prop = {
		Filter = function(self, value)
			Class.CheckType(value, "function", "nil")
			self:rawset("Filter", value)
		end,

		HelperText = function(self, value)
			Class.CheckType(value, "string")
			self:rawset("HelperText", value)
		end,

		Placeholder = function(self, value)
			Class.CheckType(value, "string")
			self:rawset("Placeholder", value)
			self.Input.PlaceholderText = value
		end,

		Text = function(self, value)
			Class.CheckType(value, "string")
			self:rawset("Text", value)
			self.Input.Text = value
		end,
	},

	_wrap = {
		Input = { "PlaceholderText", "Text" },
	},

	_init = function(self)
		local rbx = Object:Clone()
		self:rawset("_rbx", rbx) -- read-only

		local input = rbx.Input
		self.Input = input
		input:GetPropertyChangedSignal("Text"):Connect(function()
			if self.Filter then
				self.Filter(input, rbx.Helper)
			end
			self:rawset("Text", input.Text)
			self.Updated:Fire(input.Text)
			input.TextXAlignment = input.TextBounds.X > input.AbsoluteSize.X and "Right" or "Left"
		end)

		input.Focused:Connect(function()
			rbx.Line.Size = UDim2.new(1, 0, 0, 2)
		end)

		input.FocusLost:Connect(function(enterPressed)
			rbx.Line.Size = UDim2.new(1, 0, 0, 1)
			if enterPressed then
				self.Submit:Fire(input.Text)
			end
		end)

		self.ThemeData[rbx.Input] = { TextColor3 = "PrimaryText" }
		self.ThemeData[rbx.Line] = { BackgroundColor3 = "PrimaryText" }
	end,
})
