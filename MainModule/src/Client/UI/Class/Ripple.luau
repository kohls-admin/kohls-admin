local Tween = game:GetService("TweenService")

local Class = require(script.Parent)

local Object
do
	Object = Instance.new("ImageLabel")
	Object.Name = "Ripple"
	Object.BackgroundTransparency = 1
	Object.ImageTransparency = 1
	Object.Image = "rbxassetid://1447652759"
	Object.AnchorPoint = Vector2.new(0.5, 0.5)
	Object.Position = UDim2.new(0.5, 0, 0.5, 0)
	Object.Size = UDim2.new()
	Object.SizeConstraint = Enum.SizeConstraint.RelativeXX
end

-- parent update this shit?

return Class:Create({
	_name = "Ripple",
	_super = "BaseClass",

	_hide = { "Connections" },

	_prop = {
		Bounded = function(self, value)
			if type(value) == "boolean" then
				self:rawset("Bounded", value)
				local con = self.Connections
				for k, v in next, con do
					v:Disconnect()
					rawset(con, k, nil)
				end
				local obj, rbx = self.Parent, self._rbx
				if obj and rbx then
					if value then
						con[#con + 1] = obj.InputBegan:Connect(function(input)
							if input.UserInputType == Enum.UserInputType.MouseButton1 then
								local ap, as = obj.AbsolutePosition, obj.AbsoluteSize
								local x, y = input.Position.X, input.Position.Y
								local dx = math.max(x - ap.x, 0, (ap.x + as.x - x))
								local dy = math.max(y - ap.y, 0, (ap.y + as.y) - y)
								local dist = math.sqrt(dx * dx + dy * dy) * 2

								rbx.Position, rbx.Size = UDim2.new(0, x - ap.x, 0, y - ap.y), UDim2.new()
								Tween:Create(
									rbx,
									TweenInfo.new(0.2),
									{ ImageTransparency = 0.8, Size = UDim2.new(0, dist, 0, dist) }
								):Play()
							end
						end)
						con[#con + 1] = obj.InputEnded:Connect(function(input)
							if
								input.UserInputType == Enum.UserInputType.MouseButton1
								or input.UserInputType == Enum.UserInputType.MouseMovement
							then
								Tween:Create(rbx, TweenInfo.new(0.2), { ImageTransparency = 1 }):Play()
							end
						end)
					else
						self.Parent = rbx:FindFirstAncestorWhichIsA("LayerCollector") or obj
						con[#con + 1] = rbx.AncestryChanged:Connect(function()
							self.Parent = rbx:FindFirstAncestorWhichIsA("LayerCollector") or obj
						end)
						con[#con + 1] = obj.InputBegan:Connect(function(input)
							if input.UserInputType == Enum.UserInputType.MouseButton1 then
								local ap, as = obj.AbsolutePosition, obj.AbsoluteSize
								rbx.Size = UDim2.new()
								rbx.Position = UDim2.new(0, ap.x + as.x / 2, 0, ap.y + as.y / 2)
								Tween:Create(
									rbx,
									TweenInfo.new(0.2),
									{ ImageTransparency = 0.8, Size = UDim2.new(0, 40, 0, 40) }
								):Play()
							end
						end)
						con[#con + 1] = obj.InputEnded:Connect(function(input)
							if input.UserInputType == Enum.UserInputType.MouseButton1 then
								Tween:Create(
									rbx,
									TweenInfo.new(0.2),
									{ ImageTransparency = 1, Size = UDim2.new(0, 56, 0, 56) }
								):Play()
							elseif input.UserInputType == Enum.UserInputType.MouseMovement then
								Tween:Create(
									rbx,
									TweenInfo.new(0.2),
									{ ImageTransparency = 1, Size = UDim2.new(0, 56, 0, 56) }
								):Play()
							end
						end)
					end
				end
			end
		end,
	},

	_init = function(self)
		local rbx = Object:Clone()
		self:rawset("_rbx", rbx) -- read-only
		self.Connections = {}

		self.ThemeData[rbx] = { ImageColor3 = "Secondary" }
	end,
})
