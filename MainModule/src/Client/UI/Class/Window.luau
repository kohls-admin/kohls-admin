-- eventually make it so u can ctrl+drag window to minimize on screen edge
local GuiService = game:GetService("GuiService")
local UserInputService = game:getService("UserInputService")
local Tween = game:GetService("TweenService")
local Class = require(script.Parent)

local Object
do
	Object = Instance.new("Frame")
	Object.Active = true
	Object.Name = "New Window"
	Object.BackgroundTransparency = 1
	Object.Position = UDim2.new(0.5, 0, 0.5, 0)
	Object.Size = UDim2.new(0, 320, 0, 320)

	local Bar = Instance.new("Frame", Object)
	Bar.Name = "Bar"
	Bar.BackgroundColor3 = Color3.new()
	Bar.BackgroundTransparency = 0.4
	Bar.BorderSizePixel = 0
	Bar.ClipsDescendants = true
	Bar.Size = UDim2.new(1, 0, 0, 32)

	local Title = Instance.new("TextLabel", Bar)
	Title.Name = "Title"
	Title.BackgroundTransparency = 1
	Title.Position = UDim2.new(0, 10, 0, -1)
	Title.Size = UDim2.new(1, -74, 1, 0)
	Title.Font = Enum.Font.Roboto
	Title.Text = "New Window"
	Title.TextColor3 = Color3.new(1, 1, 1)
	Title.TextSize = 24
	Title.TextStrokeTransparency = 0.9
	Title.TextXAlignment = "Left"
	Title.TextTruncate = Enum.TextTruncate.AtEnd

	local Exit = Instance.new("TextButton", Bar)
	Exit.Name = "Exit"
	Exit.AnchorPoint = Vector2.new(1, 0)
	Exit.AutoButtonColor = false
	Exit.BackgroundColor3 = Color3.new(1, 0, 0)
	Exit.BorderSizePixel = 0
	Exit.Position = UDim2.new(1, 0, 0, 0)
	Exit.Size = UDim2.new(1, 0, 1, 0)
	Exit.SizeConstraint = "RelativeYY"
	Exit.Transparency = 1

	local Icon = Instance.new("ImageLabel", Exit)
	Icon.Name = "Icon"
	Icon.AnchorPoint = Vector2.new(0.5, 0.5)
	Icon.BackgroundTransparency = 1
	Icon.Position = UDim2.new(0.5, 0, 0.5, 0)
	Icon.Size = UDim2.new(0, 10, 0, 10)
	Icon.ImageColor3 = Color3.new(1, 1, 1)
	Icon.Image = "rbxassetid://1476571006"
	Icon.ResampleMode = Enum.ResamplerMode.Pixelated

	local Content = Instance.new("Frame", Object)
	Content.Name = "Content"
	Content.AnchorPoint = Vector2.new(0, 1)
	Content.BackgroundColor3 = Color3.new()
	Content.BackgroundTransparency = 0.6
	Content.BorderSizePixel = 0
	Content.ClipsDescendants = true
	Content.Position = UDim2.new(0, 0, 1, 0)
	Content.Size = UDim2.new(1, 0, 1, -32)
end

local Minimize
do
	Mini = Instance.new("TextButton")
	Mini.Name = "Minimize"
	Mini.AnchorPoint = Vector2.new(1, 0)
	Mini.AutoButtonColor = false
	Mini.BackgroundColor3 = Color3.new(1, 1, 1) --theme.PrimaryText
	Mini.BorderSizePixel = 0
	Mini.Position = UDim2.new(1, -32, 0, 0)
	Mini.Size = UDim2.new(1, 0, 1, 0)
	Mini.SizeConstraint = "RelativeYY"
	Mini.Transparency = 1
	--Mini.ZIndex = 2

	local Line1 = Instance.new("Frame", Mini)
	Line1.Name = "Line1"
	Line1.BorderSizePixel = 0
	Line1.AnchorPoint = Vector2.new(0.5, 0.5)
	Line1.BackgroundColor3 = Color3.new(1, 1, 1) --theme.PrimaryText;
	Line1.Position = UDim2.new(0.5, 0, 0.5, 0)
	Line1.Size = UDim2.new(0, 11, 0, 1)

	local Line2 = Instance.new("Frame", Mini)
	Line2.Name = "Line2"
	Line2.BorderSizePixel = 0
	Line2.AnchorPoint = Vector2.new(0.5, 0.5)
	Line2.BackgroundColor3 = Color3.new(1, 1, 1) --theme.PrimaryText;
	Line2.Position = UDim2.new(0.5, 0, 0.5, 0)
	Line2.Size = UDim2.new(0, 1, 0, 11)
	Line2.Visible = false
end

local Resize
do
	local thick = 8
	Resize = Instance.new("Frame")
	Resize.Active = true
	Resize.Name = "Resize"
	Resize.BackgroundTransparency = 1
	Resize.Size = UDim2.new(1, 0, 1, 0)

	local Icon = Instance.new("ImageLabel", Resize)
	Icon.Name = "Icon"
	Icon.AnchorPoint = Vector2.new(0.5, 0.5)
	Icon.BackgroundTransparency = 1
	Icon.Image = "rbxassetid://2286551482"
	Icon.ImageRectSize = Vector2.new(15, 15)
	Icon.Size = UDim2.new(0, 15, 0, 15)
	Icon.Visible = false
	Icon.ResampleMode = Enum.ResamplerMode.Pixelated

	local Top = Resize:Clone()
	Top.Name = "Top"
	Top.Position = UDim2.new(0, 0, 0, -thick)
	Top.Size = UDim2.new(1, 0, 0, thick)
	Top.Parent = Resize

	local TopRight = Resize:Clone()
	TopRight.Name = "TopRight"
	TopRight.Position = UDim2.new(1, 0, 0, -thick)
	TopRight.Size = UDim2.new(0, thick, 0, thick)
	TopRight.Parent = Resize

	local Right = Resize:Clone()
	Right.Name = "Right"
	Right.Position = UDim2.new(1, 0, 0, 0)
	Right.Size = UDim2.new(0, thick, 1, 0)
	Right.Parent = Resize

	local BottomRight = Resize:Clone()
	BottomRight.Name = "BottomRight"
	BottomRight.Position = UDim2.new(1, 0, 1, 0)
	BottomRight.Size = UDim2.new(0, thick, 0, thick)
	BottomRight.Parent = Resize

	local Bottom = Resize:Clone()
	Bottom.Name = "Bottom"
	Bottom.Position = UDim2.new(0, 0, 1, 0)
	Bottom.Size = UDim2.new(1, 0, 0, thick)
	Bottom.Parent = Resize

	local BottomLeft = Resize:Clone()
	BottomLeft.Name = "BottomLeft"
	BottomLeft.Position = UDim2.new(0, -thick, 1, 0)
	BottomLeft.Size = UDim2.new(0, thick, 0, thick)
	BottomLeft.Parent = Resize

	local Left = Resize:Clone()
	Left.Name = "Left"
	Left.Position = UDim2.new(0, -thick, 0, 0)
	Left.Size = UDim2.new(0, thick, 1, 0)
	Left.Parent = Resize

	local TopLeft = Resize:Clone()
	TopLeft.Name = "TopLeft"
	TopLeft.Position = UDim2.new(0, -thick, 0, -thick)
	TopLeft.Size = UDim2.new(0, thick, 0, thick)
	TopLeft.Parent = Resize
end

return Class:Create({
	_name = "Window",
	_super = "BaseClass",

	_hide = {
		"Minimized",
		"DragConnections",
		"MiniConnections",
		"ResizeConnections",
	},

	_prop = {
		Draggable = function(self, value)
			Class.CheckType(value, "boolean")
			self:rawset("Draggable", value)

			local window = self._rbx
			local con = self.DragConnections
			for k, v in next, con do
				v:Disconnect()
				rawset(con, k, nil)
			end

			if value then
				local dragging
				local dragInput
				local dragStart
				local startPos
				local startAbsolute
				local endAbsolute

				local function update(input)
					if self.Resizing then
						return
					end
					local delta = input.Position - dragStart
					window.Position = startPos
						+ UDim2.new(
							0,
							math.min(endAbsolute.X, math.max(-startAbsolute.X, delta.X)),
							0,
							math.min(endAbsolute.Y, math.max(-startAbsolute.Y, delta.Y))
						)
				end

				con[#con + 1] = window.Bar.InputBegan:Connect(function(input)
					if
						(
							input.UserInputType == Enum.UserInputType.MouseButton1
							or input.UserInputType == Enum.UserInputType.Touch
						) and not self.Resizing
					then
						dragging = true
						dragStart = input.Position
						startPos = window.Position
						startAbsolute = window.AbsolutePosition
						endAbsolute = Vector2.new(
							workspace.CurrentCamera.ViewportSize.X - (startAbsolute.X + window.AbsoluteSize.X),
							workspace.CurrentCamera.ViewportSize.Y
								- GuiService.TopbarInset.Height
								- (startAbsolute.Y + window.AbsoluteSize.Y)
						)

						input.Changed:Connect(function()
							if input.UserInputState == Enum.UserInputState.End then
								dragging = false
							end
						end)
					end
				end)

				con[#con + 1] = window.Bar.InputChanged:Connect(function(input)
					if
						input.UserInputType == Enum.UserInputType.MouseMovement
						or input.UserInputType == Enum.UserInputType.Touch
					then
						dragInput = input
					end
				end)

				con[#con + 1] = UserInputService.InputChanged:Connect(function(input)
					if input == dragInput and dragging then
						update(input)
					end
				end)
			end
		end,

		Minimize = function(self, value)
			Class.CheckType(value, "boolean")
			self:rawset("Minimize", value)

			local window = self._rbx
			local con = self.MiniConnections
			for k, v in next, con do
				v:Disconnect()
				rawset(con, k, nil)
			end

			if value then
				if window.Bar:FindFirstChild("Minimize") then
					return
				end
				local oldSize

				local mini = Mini:Clone()
				mini.Parent = window.Bar

				self.ThemeData[mini] = { BackgroundColor3 = "PrimaryText" }
				self.ThemeData[mini.Line1] = { BackgroundColor3 = "PrimaryText" }
				self.ThemeData[mini.Line2] = { BackgroundColor3 = "PrimaryText" }
				if self.Theme then
					self.Theme.Add(mini, "BackgroundColor3", self.Theme.PrimaryText)
					self.Theme.Add(mini.Line1, "BackgroundColor3", self.Theme.PrimaryText)
					self.Theme.Add(mini.Line2, "BackgroundColor3", self.Theme.PrimaryText)
				end

				con[#con + 1] = mini.MouseEnter:Connect(function()
					Tween:Create(mini, TweenInfo.new(0.1), { BackgroundTransparency = 0.9 }):Play()
				end)
				con[#con + 1] = mini.MouseLeave:Connect(function()
					Tween:Create(mini, TweenInfo.new(0.2), { BackgroundTransparency = 1 }):Play()
				end)
				con[#con + 1] = mini.MouseButton1Down:Connect(function()
					mini.BackgroundTransparency = 0.5
				end)
				con[#con + 1] = mini.MouseButton1Click:Connect(function()
					self.Minimized = not self.Minimized
					mini.Line2.Visible = self.Minimized
					if self.Minimized then
						oldSize = window.Size
						window.Size = UDim2.new(window.Size.X.Scale, window.Size.X.Offset, 0, 32)
					else
						window.Size = oldSize
					end
				end)
			else
				if window.Bar:FindFirstChild("Minimize") then
					window.Bar.Minimize:Destroy()
				end
			end
		end,
		MinSize = function(self, value)
			Class.CheckType(value, "Vector2")
			self:rawset("MinSize", value)
		end,
		MaxSize = function(self, value)
			Class.CheckType(value, "Vector2")
			self:rawset("MaxSize", value)
		end,
		Resizing = function(self, value)
			Class.CheckType(value, "boolean")
			self:rawset("Resizing", value)
		end,
		Resizable = function(self, value)
			Class.CheckType(value, "boolean")
			self:rawset("Resizable", value)

			local window = self._rbx
			local con = self.ResizeConnections
			for k, v in next, con do
				v:Disconnect()
				rawset(con, k, nil)
			end

			if value then
				local resize = Resize:Clone()
				local resizeIcon = resize.Icon
				resize.Parent = window

				local hovering
				local dragging
				local dragInput
				local dragStart
				local startPos, startSize, deltaMax, deltaMin
				local xSize, xPos, ySize, yPos

				con[#con + 1] = game:GetService("RunService").RenderStepped:Connect(function()
					if hovering then
						local pos = window.AbsolutePosition
						local mouse = UserInputService:GetMouseLocation()
						resizeIcon.Position =
							UDim2.new(0, mouse.X - pos.x, 0, mouse.Y - GuiService.TopbarInset.Height - pos.y)
					end
				end)

				local function update(input)
					local delta = input.Position - dragStart
					local dX, dY = delta.X, delta.Y
					local xMin, yMin = deltaMin.X, deltaMin.Y
					local xMax, yMax = deltaMax.X, deltaMax.Y
					window.Size = startSize
						+ UDim2.new(0, math.clamp(xSize * dX, xMin, xMax), 0, math.clamp(ySize * dY, yMin, yMax))
					window.Position = startPos
						+ UDim2.new(0, -math.clamp(-xPos * dX, xMin, xMax), 0, -math.clamp(-yPos * dY, yMin, yMax))
				end

				con[#con + 1] = UserInputService.InputChanged:Connect(function(input)
					if input == dragInput and dragging then
						update(input)
					end
				end)

				local function inputBegan(input)
					if
						(
							input.UserInputType == Enum.UserInputType.MouseButton1
							or input.UserInputType == Enum.UserInputType.Touch
						) and not self.Minimized
					then
						self.Resizing = true
						dragging = true
						dragStart = input.Position
						startPos = window.Position
						startSize = window.Size
						deltaMax = self.MaxSize - window.AbsoluteSize
						deltaMin = self.MinSize - window.AbsoluteSize
						input.Changed:Connect(function()
							if input.UserInputState == Enum.UserInputState.End then
								dragging = false
								self.Resizing = false
							end
						end)
					end
				end

				local function inputChanged(input)
					if
						input.UserInputType == Enum.UserInputType.MouseMovement
						or input.UserInputType == Enum.UserInputType.Touch
					then
						dragInput = input
					end
				end

				for k, v in
					next,
					{
						[resize.Top] = { 0, 0, -1, 1, 0 },
						[resize.TopRight] = { 1, 0, -1, 1, 15 },
						[resize.Right] = { 1, 0, 0, 0, 30 },
						[resize.BottomRight] = { 1, 0, 1, 0, 45 },
						[resize.Bottom] = { 0, 0, 1, 0, 0 },
						[resize.BottomLeft] = { -1, 1, 1, 0, 15 },
						[resize.Left] = { -1, 1, 0, 0, 30 },
						[resize.TopLeft] = { -1, 1, -1, 1, 45 },
					}
				do
					local a, b, c, d, e = unpack(v)
					con[#con + 1] = k.InputBegan:Connect(inputBegan)
					con[#con + 1] = k.InputChanged:Connect(inputChanged)
					con[#con + 1] = k.InputBegan:Connect(function(input)
						if
							not dragging
							and input.UserInputType == Enum.UserInputType.MouseMovement
							and not self.Minimized
						then
							xSize, xPos, ySize, yPos, hovering = a, b, c, d, k
							resizeIcon.ImageRectOffset = Vector2.new(e, 0)
							resizeIcon.Visible = true
							UserInputService.MouseIconEnabled = false
						end
					end)
					con[#con + 1] = k.InputEnded:Connect(function(input)
						if
							not dragging
							and input.UserInputType == Enum.UserInputType.MouseMovement
							and hovering == k
						then
							hovering = nil
							resizeIcon.Visible = false
							UserInputService.MouseIconEnabled = true
						end
					end)
				end
			else
				if window:FindFirstChild("Resize") then
					window.Resize:Destroy()
				end
			end
		end,

		Title = function(self, value)
			Class.CheckType(value, "string")
			self:rawset("Title", value)
			local window = self._rbx
			window.Name = value
			window.Bar.Title.Text = value
		end,
	},

	_init = function(self)
		local rbx = Object:Clone()
		self:rawset("_rbx", rbx) -- read-only
		self:rawset("_parentTo", rbx.Content) -- read-only

		local exit = rbx.Bar.Exit
		exit.MouseEnter:Connect(function()
			Tween:Create(exit, TweenInfo.new(0.1), { BackgroundTransparency = 0 }):Play()
		end)
		exit.MouseLeave:Connect(function()
			Tween:Create(exit, TweenInfo.new(0.2), { BackgroundTransparency = 1 }):Play()
		end)
		exit.MouseButton1Down:Connect(function()
			exit.BackgroundTransparency = 0.5
		end)
		exit.MouseButton1Click:Connect(function()
			rbx.Visible = false
		end)

		self.DragConnections = {}
		self.MiniConnections = {}
		self.ResizeConnections = {}

		self.ThemeData[rbx.Bar] = { BackgroundColor3 = "Primary", BackgroundTransparency = "Primary" }
		self.ThemeData[rbx.Bar.Title] = { TextColor = "PrimaryText" }
		self.ThemeData[rbx.Content] = { BackgroundColor3 = "Primary", BackgroundTransparency = { "Primary", 0.1 } }

		self.Draggable = true
		self.Minimize = true
		self.Resizable = true
		self.MaxSize = Vector2.new(9e9, 9e9)
		self.MinSize = Vector2.new(128, 128)
	end,
})
