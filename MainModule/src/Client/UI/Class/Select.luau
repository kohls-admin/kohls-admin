local Object
do
	Object = Instance.new("TextButton")
	Object.Name = "Select"
	Object.Text = ""
	Object.Active = true
	Object.AutoButtonColor = false
	Object.BackgroundTransparency = 1
	Object.Size = UDim2.new(1, 0, 1, 0)
	Object.ZIndex = 2

	local Choice = Instance.new("TextLabel", Object)
	Choice.Name = "Choice"
	Choice.BackgroundTransparency = 1
	Choice.Size = UDim2.new(1, -18, 1, 0)
	Choice.Font = Enum.Font.Roboto
	Choice.Text = "Default"
	Choice.TextSize = 16
	Choice.TextColor3 = Color3.new(1, 1, 1) -- theme.PrimaryText
	Choice.TextStrokeTransparency = 0.9
	Choice.TextTruncate = Enum.TextTruncate.AtEnd
	Choice.TextXAlignment = Enum.TextXAlignment.Left

	local Arrow = Instance.new("ImageLabel", Object)
	Arrow.Name = "Arrow"
	Arrow.AnchorPoint = Vector2.new(1, 0.5)
	Arrow.BackgroundTransparency = 1
	Arrow.Position = UDim2.new(1, 0, 0.5, 0)
	Arrow.Size = UDim2.new(0, 18, 0, 18)
	Arrow.Image = "rbxassetid://2374890977"
	Arrow.ResampleMode = Enum.ResamplerMode.Pixelated

	local Line = Instance.new("Frame", Object)
	Line.Name = "Line"
	Line.BackgroundColor3 = Color3.new(1, 1, 1)
	Line.BorderSizePixel = 0
	Line.Position = UDim2.new(0, 0, 1, -1)
	Line.Size = UDim2.new(1, 0, 0, 1)

	local Menu = Instance.new("ScrollingFrame", Object)
	Menu.Name = "Menu"
	Menu.BackgroundColor3 = Color3.new()
	Menu.BorderSizePixel = 0
	Menu.Size = UDim2.new(1, 0, 1, 0)
	Menu.AutomaticCanvasSize = Enum.AutomaticSize.Y
	Menu.TopImage = Menu.MidImage
	Menu.BottomImage = Menu.MidImage
	Menu.ScrollBarThickness = 0
	Menu.Visible = false

	local Layout = Instance.new("UIListLayout", Menu)
	Layout.Name = "Layout"
	Layout.SortOrder = Enum.SortOrder.LayoutOrder
	Layout.FillDirection = Enum.FillDirection.Vertical
	Layout.VerticalAlignment = Enum.VerticalAlignment.Top
end

game:GetService("ContentProvider"):PreloadAsync({ Object })

local Class = require(script.Parent)

return Class:Create({
	_name = "Select",
	_super = "BaseClass",

	_event = { "Updated" },

	_prop = {
		Choice = function(self, value)
			Class.CheckType(value, "string")
			self:rawset("Choice", value)
			self._rbx.Choice.Text = value
		end,

		Options = function(self, value)
			Class.CheckType(value, "table")
			self:rawset("Options", value)

			local rbx = self._rbx
			local options = {}

			for _, v in next, rbx.Menu:GetChildren() do
				if not v:IsA("UIComponent") then
					v:Destroy()
				end
			end

			local count = 0
			for k, v in next, value do
				count += 1
				local option = Class.new("Button")
				option.LayoutOrder = k
				option.Name = k
				option.Text = v
				option.Theme = self.Theme
				option.BackgroundTransparency = 1
				option.Label.TextXAlignment = "Left"
				option.Label.Size = UDim2.new(1, -16, 0.5, 0)
				option.Active = true
				option.OnClick:Connect(function()
					rbx.Menu.Visible = false
					self.Choice = v
					self.Updated:Fire(v)
				end)
				table.insert(options, option)
				option.Parent = rbx.Menu
			end
			rbx.Menu.Size = UDim2.new(1, 0, math.min(count, 3.5), 0)
		end,
	},

	_init = function(self)
		local rbx = Object:Clone()
		self:rawset("_rbx", rbx) -- read-only

		--		local dialog = Class.new'Dialog'
		--		self:rawset('_dialog', dialog._rbx)
		--		dialog.Dismiss = true
		--		dialog.Visible = false
		--		dialog.Parent = self

		-- local menu = Class.new("List")
		-- self:rawset("_menu", menu._rbx)
		-- menu.Padding = UDim.new()
		-- menu.Visible = false
		-- menu.Parent = self

		--		local Layout = Instance.new('UIListLayout', dialog.Frame.Content)
		--		Layout.SortOrder = Enum.SortOrder.LayoutOrder
		--		Layout.VerticalAlignment = 'Center'

		self.ThemeData[rbx.Menu] = { BackgroundColor3 = "Primary" }
		self.ThemeData[rbx.Choice] = { TextColor3 = "PrimaryText", TextStrokeColor3 = "SecondaryText" }
		self.ThemeData[rbx.Arrow] = { ImageColor3 = "PrimaryText" }
		self.ThemeData[rbx.Line] = { BackgroundColor3 = "PrimaryText" }

		--		menu.Layout:GetPropertyChangedSignal'AbsoluteContentSize':Connect(function()
		--			local size = menu.Layout.AbsoluteContentSize
		--			dialog.Frame.Content.CanvasSize = UDim2.new(0, size.X, 0, size.Y)
		--			dialog.Frame.Size = UDim2.new(1, 0, 0, math.min(size.Y, dialog.AbsoluteSize.Y - dialog.Padding.PaddingTop.Offset * 2))
		--		end)
		rbx.Menu.Layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
			rbx.Menu.CanvasSize = UDim2.new(0, 0, 0, rbx.Menu.Layout.AbsoluteContentSize.Y)
		end)

		rbx.Activated:Connect(function()
			task.spawn(function()
				rbx.Menu.Visible = true
			end)
		end)
	end,
})
