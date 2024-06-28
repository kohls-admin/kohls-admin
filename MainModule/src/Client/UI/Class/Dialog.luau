local Class = require(script.Parent)

local function checkBounds(obj, pos)
	local ap = obj.AbsolutePosition
	local as = obj.AbsoluteSize
	return pos.x > ap.x and pos.x < ap.x + as.x and pos.y > ap.y and pos.y < ap.y + as.y
end

local Object
do
	Object = Instance.new("TextButton")
	Object.Name = "Dialog"
	Object.Active = true
	Object.AutoButtonColor = false
	Object.BackgroundColor3 = Color3.new()
	Object.BackgroundTransparency = 0.5
	Object.BorderSizePixel = 0
	Object.Size = UDim2.new(1, 0, 1, 0)
	Object.Text = ""

	local Padding = Instance.new("UIPadding", Object)
	Padding.Name = "Padding"

	local Frame = Instance.new("Frame", Object)
	Frame.Name = "Frame"
	Frame.Active = true
	Frame.AnchorPoint = Vector2.new(0.5, 0.5)
	Frame.BackgroundColor3 = Color3.fromRGB(31, 31, 31)
	Frame.BorderSizePixel = 0
	Frame.Position = UDim2.new(0.5, 0, 0.5, 0)
	Frame.Size = UDim2.new(1, 0, 1, 0)

	local Content = Instance.new("ScrollingFrame", Frame)
	Content.Name = "Content"
	Content.Active = true
	Content.BackgroundTransparency = 1
	Content.BorderSizePixel = 0
	Content.Size = UDim2.new(1, 0, 1, 0)
	Content.CanvasSize = UDim2.new(1, 0, 1, 0)
	Content.ScrollBarThickness = 8
	Content.HorizontalScrollBarInset = Enum.ScrollBarInset.ScrollBar
	Content.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
	Content.BottomImage = "rbxasset://textures/SurfacesDefault.png"
	Content.MidImage = "rbxasset://textures/SurfacesDefault.png"
	Content.TopImage = "rbxasset://textures/SurfacesDefault.png"
end

local Title = Instance.new("TextLabel")
Title.BackgroundTransparency = 1
Title.Position = UDim2.new(0, 16, 0, 16)
Title.Size = UDim2.new(1, -32, 0, 24)
Title.FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.SemiBold)
Title.Text = "Title"
Title.TextColor3 = Color3.new(1, 1, 1)
Title.TextSize = 24
Title.TextStrokeTransparency = 0.9
Title.TextXAlignment = "Left"
Title.TextTruncate = Enum.TextTruncate.AtEnd

local Body = Instance.new("TextLabel")
Body.BackgroundTransparency = 1
Body.Position = UDim2.new(0, 16, 0, 0)
Body.Size = UDim2.new(1, -32, 1, 0)
Body.Font = Enum.Font.Roboto
Body.Text = "Body"
Body.TextColor3 = Color3.new(1, 1, 1)
Body.TextSize = 20
Body.TextStrokeTransparency = 0.95
Body.TextTransparency = 0.5
Body.TextXAlignment = "Left"
Body.TextYAlignment = "Top"
Body.TextWrapped = true
Body.TextTruncate = Enum.TextTruncate.AtEnd

return Class:Create({
	_name = "Dialog",
	_super = "BaseClass",

	_event = { "Updated" },

	_hide = { "hasButton", "labelObj", "titleObj", "dismissCon" },

	_prop = {
		Accept = function(self, value)
			Class.CheckType(value, "string")
			self:rawset("Accept", value)
			local btn = self.Frame:FindFirstChild("Accept")
			if not btn then
				btn = Class.new("Button")
				btn.Name = "Accept"
				btn.Theme = self.Theme
				btn.AnchorPoint = Vector2.new(1, 1)
				btn.BackgroundTransparency = 1
				btn.Position = UDim2.new(1, -8, 1, -8)
				btn.Size = UDim2.new(0, 80, 0, 32)
				btn.Parent = self.Frame
				btn.OnClick:Connect(function()
					self.Updated:Fire(true)
					self._rbx.Visible = false
				end)
				self.hasButton = true
			end
			btn.Text = value
		end,

		Decline = function(self, value)
			Class.CheckType(value, "string")
			self:rawset("Decline", value)
			local btn = self.Frame:FindFirstChild("Decline")
			if not btn then
				btn = Class.new("Button")
				btn.Name = "Decline"
				btn.Theme = self.Theme
				btn.AnchorPoint = Vector2.new(1, 1)
				btn.BackgroundTransparency = 1
				btn.Position = UDim2.new(1, -96, 1, -8)
				btn.Size = UDim2.new(0, 80, 0, 32)
				btn.Parent = self.Frame
				btn.OnClick:Connect(function()
					self.Updated:Fire(false)
					self._rbx.Visible = false
				end)
				self.hasButton = true
			end
			btn.Text = value
		end,

		Dismiss = function(self, value)
			Class.CheckType(value, "boolean")
			self:rawset("Dismiss", value)
			if self.dismissCon then
				self.dismissCon:Disconnect()
			end
			if value then
				self.dismissCon = game:GetService("UserInputService").InputEnded:Connect(function(input)
					if
						self.Visible
						and input.UserInputType == Enum.UserInputType.MouseButton1
						and not checkBounds(self.Frame, input.Position)
					then
						self.Visible = false
					end
				end)
			end
		end,

		Body = function(self, value)
			Class.CheckType(value, "string")
			self:rawset("Body", value)
			if not self.labelObj then -- create body obj
				local obj = Body:Clone()
				obj.Parent = self.Frame.Content
				self.labelObj = obj
			end
			self.labelObj.Text = value
		end,

		Title = function(self, value)
			Class.CheckType(value, "string")
			self:rawset("Title", value)
			if not self.titleObj then -- create title obj
				local obj = Title:Clone()
				obj.Parent = self.Frame
				self.titleObj = obj
				self.Frame.Content.Position = UDim2.new(0, 0, 0, 56)
				self.Frame.Content.Size = UDim2.new(1, 0, 1, self.hasButton and -104 or -56)
				self.Frame.Content.CanvasSize = self.Frame.Content.Size
			end
			self.titleObj.Text = value
		end,

		--		Visible = function(self, value)
		--			Class.CheckType(value, 'boolean')
		--			self:rawset('Visible', value)
		--			self._rbx.Visible = value
		--			-- tween in/out?
		--		end;
	},

	_init = function(self)
		local rbx = Object:Clone()
		self:rawset("_rbx", rbx) -- read-only
		self:rawset("_parentTo", rbx.Frame.Content)

		rbx:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			local padding = UDim.new(0, rbx.AbsoluteSize.X / 10)
			self.Padding.PaddingBottom = padding
			self.Padding.PaddingLeft = padding
			self.Padding.PaddingRight = padding
			self.Padding.PaddingTop = padding
		end)

		rbx.AncestryChanged:Connect(function() -- parent dialog
			local x, parent = rbx
			repeat
				local content = x and x:FindFirstAncestor("Content")
				if content then
					local obj = Class.objTables[content.Parent]
					if obj and obj.ClassName == "Window" then
						parent = content.Parent
					else
						x = content
					end
				else
					parent = rbx.Parent
				end
			until parent
			rbx.Parent = parent
		end)
	end,
})
