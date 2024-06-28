local Object
do
	Object = Instance.new("Frame")
	Object.Name = "List"
	Object.BackgroundTransparency = 1
	Object.BorderSizePixel = 0
	Object.Size = UDim2.new(1, 0, 1, 0)
	Object.ClipsDescendants = true

	local Layout = Instance.new("UIListLayout", Object)
	Layout.Name = "Layout"
	Layout.SortOrder = Enum.SortOrder.LayoutOrder
	Layout.FillDirection = Enum.FillDirection.Vertical
	Layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	Layout.VerticalAlignment = Enum.VerticalAlignment.Top

	local Content = Instance.new("Frame", Object)
	Content.Name = "Content"
	Content.LayoutOrder = 1
	Content.BackgroundTransparency = 1
	Content.Size = UDim2.new(1, 0, 1, 0)
	Content.ClipsDescendants = true

	local ContentLayout = Layout:Clone()
	ContentLayout.Padding = UDim.new(0, 8)
	ContentLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	ContentLayout.Parent = Content

	local Padding = Instance.new("UIPadding", Content)
	Padding.Name = "Padding"
	Padding.PaddingBottom = UDim.new(0, 8)
	Padding.PaddingLeft = UDim.new(0, 8)
	Padding.PaddingRight = UDim.new(0, 8)
	Padding.PaddingTop = UDim.new(0, 8)
end

local Label
do
	Label = Instance.new("Frame")
	Label.Name = "Label"
	Label.Active = true
	Label.BackgroundTransparency = 1
	Label.Size = UDim2.new(1, 0, 0, 24)

	local Arrow = Instance.new("ImageLabel", Label)
	Arrow.Name = "Arrow"
	Arrow.BackgroundTransparency = 1
	Arrow.AnchorPoint = Vector2.new(0, 0.5)
	Arrow.Position = UDim2.new(0, 0, 0.5, 0)
	Arrow.Size = UDim2.new(0, 18, 0, 18)
	Arrow.Image = "rbxassetid://2374890977"
	Arrow.ImageTransparency = 0.5
	Arrow.ResampleMode = Enum.ResamplerMode.Pixelated

	local Title = Instance.new("TextLabel", Label)
	Title.Name = "Title"
	Title.BackgroundTransparency = 1
	Title.Position = UDim2.new(0, 18, 0, 0)
	Title.Size = UDim2.new(1, -18, 1, 0)
	Title.FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Bold)
	Title.Text = "LIST"
	Title.TextSize = 16
	Title.TextColor3 = Color3.new(1, 1, 1)
	Title.TextTransparency = 0.5
	Title.TextStrokeTransparency = 0.95
	Title.TextTruncate = Enum.TextTruncate.AtEnd
	Title.TextXAlignment = "Left"
	Title.Active = true
end

game:GetService("ContentProvider"):PreloadAsync({ Object, Label })

local Class = require(script.Parent)

return Class:Create({
	_name = "List",
	_super = "BaseClass",

	_hide = {
		absoluteY = 0,
		textMax = 0,
	},

	_prop = {
		Collapsible = function(self, value)
			Class.CheckType(value, "boolean")
			self:rawset("Collapsible", value)
			if self._rbx:FindFirstChild("Label") then
				self._rbx.Label.Arrow.Visible = value
				self._rbx.Label.Title.Position = UDim2.new(0, value and 18 or 12, 0, 0)
			end
		end,

		Padding = function(self, value)
			Class.CheckType(value, "UDim")
			self:rawset("Padding", value)

			local rbx = self._rbx
			if rbx then
				rbx.Content.Layout.Padding = value
				rbx.Content.Padding.PaddingBottom = value
				rbx.Content.Padding.PaddingLeft = value
				rbx.Content.Padding.PaddingRight = value
				rbx.Content.Padding.PaddingTop = self.Title and UDim.new(value.Scale, value.Offset - 8) or value
			end
		end,

		Title = function(self, value)
			Class.CheckType(value, "string")
			self:rawset("Title", value)

			local label = self._rbx:FindFirstChild("Label")
			if not label then
				self._rbx.Content.Padding.PaddingTop = UDim.new(self.Padding.Scale, self.Padding.Offset - 8)
				self._rbx.Content.Size = UDim2.new(1, 0, 1, -24)
				label = Label:Clone()
				label.Arrow.Visible = self.Collapsible
				label.Title.Position = UDim2.new(0, self.Collapsible and 18 or 12, 0, 0)

				self.ThemeData[label.Arrow] = { ImageColor3 = "PrimaryText" }
				self.ThemeData[label.Title] = { TextColor3 = "PrimaryText", TextStrokeColor3 = "SecondaryText" }
				if self.Theme then
					self.Theme.Add(label.Arrow, "ImageColor3", self.Theme.PrimaryText)
					self.Theme:Apply(
						label.Title,
						{ TextColor3 = self.Theme.PrimaryText, TextStrokeColor3 = self.Theme.SecondaryText }
					)
				end

				local collapsed, clicking
				label.InputBegan:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 and self.Collapsible then
						clicking = true
					end
				end)
				label.InputEnded:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 and clicking then
						clicking = false
						collapsed = not collapsed
						game:GetService("TweenService")
							:Create(label.Arrow, TweenInfo.new(0.2), { Rotation = collapsed and -90 or 0 })
							:Play()
						self._rbx.Content:TweenSize(
							UDim2.new(1, 0, collapsed and 0 or 1, collapsed and 0 or -24),
							"Out",
							"Quad",
							0.2,
							true
						)
						self._rbx:TweenSize(
							UDim2.new(1, 0, 0, collapsed and 24 or self.absoluteY),
							"Out",
							"Quad",
							0.2,
							true
						)
					end
				end)

				label.Parent = self._rbx
			end
			label.Title.Text = value
		end,
	},

	_init = function(self)
		local rbx = Object:Clone()
		self:rawset("_rbx", rbx) -- read-only
		self:rawset("_parentTo", rbx.Content)

		self.Collapsible = true
		self.Padding = UDim.new(0, 8)

		rbx.Content.ChildAdded:Connect(function(child)
			if child and child:IsA("GuiObject") and child.Size.Y.Scale ~= 0 then
				local old = child.Size
				child.Size = UDim2.new(old.X.Scale, old.X.Offset, 0, old.Y.Offset + 32)
				-- on child size changed
			end
		end)

		rbx.Content.Layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
			local acs = rbx.Content.Layout.AbsoluteContentSize
			rbx.Size = UDim2.new(
				rbx.Size.X.Scale,
				rbx.Size.X.Offset,
				0,
				(self.Title and 24 or 0) + acs.Y + self.Padding.Offset * 2
			)
			self.absoluteY = rbx.AbsoluteSize.Y
		end)

		self.ThemeData[rbx] = { BackgroundColor3 = "Primary" }
	end,
})
