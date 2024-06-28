--[[	DOCUMENTATION

	Properties

		Checked				boolean
		Indeterminate		boolean
		_rbx				Instance

	Events

		Updated				Fires the updated Checked value.

--]]

local Tween = game:GetService("TweenService")

local Class = require(script.Parent)

local Object
do
	Object = Instance.new("ImageButton")
	Object.Name = "Checkbox"
	Object.Active = true
	Object.BackgroundTransparency = 1
	Object.Image = "rbxassetid://1636607226"
	Object.ScaleType = Enum.ScaleType.Slice
	Object.SliceCenter = Rect.new(3, 3, 3, 3)
	Object.AnchorPoint = Vector2.new(1, 0.5)
	Object.Position = UDim2.new(1, -8, 0.5, 0)
	Object.Size = UDim2.new(0, 20, 0, 20)
	Object.ResampleMode = Enum.ResamplerMode.Pixelated

	Instance.new("UIAspectRatioConstraint", Object).Name = "AspectRatio"

	local Checkmark = Instance.new("Frame", Object)
	Checkmark.Name = "Checkmark"
	Checkmark.BackgroundTransparency = 1
	Checkmark.Size = UDim2.new(0, 0, 1, 0)
	Checkmark.ClipsDescendants = true

	local Icon = Instance.new("ImageLabel", Checkmark)
	Icon.Name = "Icon"
	Icon.AnchorPoint = Vector2.new(0, 0.5)
	Icon.BackgroundTransparency = 1
	Icon.Position = UDim2.new(0, 3, 0.5, 0)
	Icon.Size = UDim2.new(0, 14, 0, 14)
	Icon.Image = "rbxassetid://2340153468"
	Icon.ResampleMode = Enum.ResamplerMode.Pixelated

	local Line = Instance.new("Frame", Object)
	Line.Name = "Line"
	Line.AnchorPoint = Vector2.new(0.5, 0.5)
	Line.BackgroundTransparency = 1
	Line.BorderSizePixel = 0
	Line.BackgroundColor3 = Color3.new(1, 1, 1)
	Line.Position = UDim2.new(0.5, 0, 0.5, 0)
	Line.Size = UDim2.new(0, 10, 0, 2)
end

return Class:Create({
	_name = "Checkbox",
	_super = "BaseClass",

	_event = { "Updated" },

	_hide = {
		Activated = function(self)
			self.Checked = not self.Checked
		end,
	},

	_prop = {
		Checked = function(self, value)
			Class.CheckType(value, "boolean")
			self:rawset("Checked", value)
			if self.Indeterminate and value then
				self:rawset("Indeterminate", false)
				self.Checkmark.Size = UDim2.new(1, 0, 1, 0)
				Tween:Create(self.Line, TweenInfo.new(0.5), { BackgroundTransparency = 1, Rotation = 315 }):Play()
				Tween:Create(self.Checkmark.Icon, TweenInfo.new(0.5), { ImageTransparency = 0, Rotation = 0 }):Play()
			else
				Tween:Create(
					self.Checkmark,
					TweenInfo.new(0.2),
					{ Size = value and UDim2.new(1, 0, 1, 0) or UDim2.new(0, 0, 1, 0) }
				):Play()
			end
			self.Updated:Fire(value)
		end,

		Indeterminate = function(self, value)
			Class.CheckType(value, "boolean")
			self:rawset("Indeterminate", value)
			if value then
				if self.Checked then
					self:rawset("Checked", false)
				end
				self.Checkmark.Icon.ImageTransparency = 1
				self.Checkmark.Icon.Rotation = -315
				self.Line.BackgroundTransparency = 0
				self.Line.Rotation = 0
			end
		end,
	},

	_init = function(self)
		local rbx = Object:Clone()
		self:rawset("_rbx", rbx) -- read-only

		self.Checked = false

		local ink = Class.new("Ripple")
		ink.Parent = self
		ink.Bounded = false

		rbx.Activated:Connect(function()
			self:Activated()
		end)

		self.ThemeData[rbx] = { ImageColor3 = "Secondary" }
		self.ThemeData[rbx.Line] = { BackgroundColor3 = "Secondary" }
		self.ThemeData[rbx.Checkmark.Icon] = { ImageColor3 = "Secondary" }
	end,
})
