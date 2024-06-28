--[[
	UI.new('Button', {
		Icon	[assetid]
		Text	[string]
		Toggle	[function](bool Toggled)
	})
--]]

--local Button = {}
--Button.__index = Button
--
--function Button.new(props, theme)
--	local self = setmetatable({
--	}, Button)
--end

local Tween = game:GetService("TweenService")
local Class = require(script.Parent)

local Object
do
	Object = Instance.new("TextButton")
	Object.Name = "Button"
	Object.Active = true
	Object.AutoButtonColor = false
	Object.BackgroundColor3 = Color3.new(1, 1, 1) --props('BackgroundColor3', theme.Secondary)
	Object.BackgroundTransparency = 0.8 --bgtrans
	Object.BorderSizePixel = 0
	Object.ClipsDescendants = true
	Object.Text = ""
	Object.Size = UDim2.new(1, 0, 0, 32)
end

local Label
do
	Label = Instance.new("TextLabel")
	Label.Name = "Label"
	Label.AnchorPoint = Vector2.new(0.5, 0.5)
	Label.BackgroundTransparency = 1
	Label.Position = UDim2.new(0.5, 0, 0.5, 0)
	Label.Size = UDim2.new(1, -8, 0.5, 0)
	Label.Font = Enum.Font.Roboto
	Label.TextSize = 16 --props('TextSize', 16);
	Label.TextColor3 = Color3.new(1, 1, 1) --theme.PrimaryText;
	Label.TextTransparency = 0 --props('TextTransparency', theme.PrimaryText);
	Label.TextStrokeTransparency = 0.9 --props('TextStrokeTransparency', {theme.PrimaryText, .9});
	Label.TextTruncate = Enum.TextTruncate.AtEnd
end

local Ripple
do
	Ripple = Instance.new("ImageLabel")
	Ripple.Name = "Ripple"
	Ripple.BackgroundColor3 = Color3.new(1, 1, 1) --theme.Secondary
	Ripple.BackgroundTransparency = 1
	Ripple.ImageTransparency = 1
	Ripple.Image = "rbxassetid://1447652759"
	Ripple.AnchorPoint = Vector2.new(0.5, 0.5)
	Ripple.Position = UDim2.new(0.5, 0, 0.5, 0)
	Ripple.Size = UDim2.new()
	Ripple.SizeConstraint = Enum.SizeConstraint.RelativeXX
end

return Class:Create({
	_name = "Button",
	_super = "BaseClass",

	_event = { "OnClick", "OnToggle" },

	_hide = { "Connections" },

	_prop = {
		BackgroundTransparency = function(self, value)
			if type(value) ~= "number" then
				return warn("Invalid argument: <number> expected, got", typeof(value))
			end
			self:rawset("BackgroundTransparency", value)
			self._rbx.BackgroundTransparency = value
		end,
		Icon = function(self, value)
			if type(value) ~= "string" then
				return warn("Invalid argument: <string> expected, got", typeof(value))
			end
			self:rawset("Icon", value)
			-- create/update icon shit
			local rbx = self._rbx
		end,
		Text = function(self, value)
			if type(value) ~= "string" then
				return warn("Invalid argument: <string> expected, got", typeof(value))
			end
			self:rawset("Text", value)

			local rbx = self._rbx
			local label = rbx:FindFirstChild("Label") or Label:Clone()

			label.Text = value
			label.Parent = rbx
		end,
		Toggle = function(self, value)
			if type(value) ~= "boolean" then
				return warn("Invalid argument: <bool> expected, got", typeof(value))
			end
			self:rawset("Toggle", value)

			local rbx = self._rbx
			local con = self.Connections
			for k, v in next, con do
				v:Disconnect()
				rawset(con, k, nil)
			end

			if value then
				local clicking, toggled
				local ripple = Ripple:Clone()
				ripple.Parent = rbx
				con[#con + 1] = rbx.Activated:Connect(function()
					toggled = not toggled
					Tween:Create(rbx, TweenInfo.new(toggled and 0.1 or 0.2), {
						BackgroundTransparency = toggled and self.BackgroundTransparency / 2
							or self.BackgroundTransparency,
					}):Play()
					self.OnToggle:Fire(toggled)
					self.OnClick:Fire()
				end)
				con[#con + 1] = rbx.MouseEnter:Connect(function()
					Tween:Create(
						ripple,
						TweenInfo.new(0.2),
						{ ImageTransparency = 0.9, Size = UDim2.new(5 / 3, 0, 5 / 3, 0) }
					):Play()
				end)
				con[#con + 1] = rbx.MouseLeave:Connect(function()
					Tween:Create(ripple, TweenInfo.new(0.2), { ImageTransparency = 1, Size = UDim2.new() }):Play()
				end)
			else
				con[#con + 1] = rbx.Activated:Connect(function()
					self.OnClick:Fire()
				end)
				con[#con + 1] = rbx.MouseEnter:Connect(function()
					rbx.BackgroundTransparency = self.BackgroundTransparency
						+ (self.BackgroundTransparency > 0.1 and -0.1 or 0.1)
				end)
				con[#con + 1] = rbx.MouseLeave:Connect(function()
					rbx.BackgroundTransparency = self.BackgroundTransparency
				end)
			end
		end,
	},

	_init = function(self)
		self:rawset("_rbx", Object:Clone()) -- read-only

		local ink = Class.new("Ripple")
		ink.Parent = self
		ink.Bounded = true

		self.Connections = {}
		self.BackgroundTransparency = 0.8
		self.Toggle = false
	end,
})

--	local flat = props('Flat')
--	local img = props('Image')
--	local toggle = props('Toggle')
--	local bgtrans = props('BackgroundTransparency', flat and 1 or 0)
--	local hovertrans = flat and .25 or .5

--	button.MouseHover:Connect(function()
--		if flat then
--			TweenService:Create(button, TweenInfo.new(.15), {BackgroundTransparency = .25}):Play()
--		end
--		button.BackgroundTransparency = flat and .2
--		TweenService:Create(button, TweenInfo.new(.15), {button.BackgroundTransparency = flat and .2}):Play()
--	end)
--
--	if icon then
--		-- Image & Proper padding?
--		local basetrans = props('ImageTransparency', .5)
--		local icon = UI.new('ImageLabel', {
--			Name = 'Icon';
--			AnchorPoint = Vector2.new(.5, .5);
--			BackgroundTransparency = 1;
--			Position = UDim2.new(.5, 0, .5, 0);
--			Size = props('ImageSize', UDim2.new(1, -4, 1, -4));
--			Image = tonumber(img) and 'rbxassetid://'..img or img;
--			ImageColor3 = props('ImageColor3', theme.Primary);
--			ImageTransparency = props('ImageTransparency', 0);
--		}).Parent = button;
--
--
--	end
