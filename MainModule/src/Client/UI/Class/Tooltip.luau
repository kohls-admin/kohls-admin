local TextService = game:GetService("TextService")
local Tween = game:GetService("TweenService")

local Class = require(script.Parent)

local Object
do
	Object = Instance.new("Frame")
	Object.Name = "Tooltip"
	Object.BackgroundColor3 = Color3.new()
	Object.BackgroundTransparency = 0.4
	Object.BorderSizePixel = 0
	Object.Size = UDim2.new(0, 48, 0, 32)
	Object.Visible = false

	local Label = Instance.new("TextLabel", Object)
	Label.Name = "Label"
	Label.BackgroundTransparency = 1
	Label.Size = UDim2.new(1, 0, 1, 0)
	Label.Font = Enum.Font.Roboto
	Label.TextSize = 16
	Label.TextColor3 = Color3.new(1, 1, 1)
	Label.TextStrokeTransparency = 0.9
	Label.TextWrapped = true
	Label.TextTruncate = Enum.TextTruncate.AtEnd
end

return Class:Create({
	_name = "Tooltip",
	_super = "BaseClass",

	_hide = {
		"Connections",
		ParentUpdate = function(self, parent)
			local con, rbx = self.Connections, self._rbx
			for k, v in next, con do
				v:Disconnect()
				con[k] = nil
			end
			if parent and rbx then
				local inst
				rbx.Parent = parent:FindFirstAncestorWhichIsA("LayerCollector") or parent
				con[#con + 1] = rbx.AncestryChanged:Connect(function()
					rbx.Parent = parent:FindFirstAncestorWhichIsA("LayerCollector") or parent
				end)
				con[#con + 1] = parent.MouseEnter:Connect(function()
					local t = tick()
					inst = t
					delay(0.5, function()
						if t == inst then
							local size = rbx.AbsoluteSize
							local view = workspace.CurrentCamera.ViewportSize
							local ap, as = parent.AbsolutePosition, parent.AbsoluteSize
							rbx.AnchorPoint = Vector2.new(
								ap.X + size.X > view.X and 1 or 0,
								ap.Y + as.Y + size.Y + 8 > view.Y - 36 and 1 or 0
							)
							rbx.Position = UDim2.new(
								0,
								ap.X + (rbx.AnchorPoint.X == 0 and 0 or as.X),
								0,
								ap.Y + (rbx.AnchorPoint.Y == 0 and as.Y + 8 or -8)
							)
							rbx.BackgroundTransparency = 1
							rbx.Label.TextTransparency = 1
							rbx.Label.TextStrokeTransparency = 1
							rbx.Active = true
							rbx.Visible = true
							Tween:Create(
								rbx,
								TweenInfo.new(0.2),
								{
									BackgroundTransparency = (
										self.Theme and self.Theme:Get(rbx, "BackgroundTransparency") or 0.4
									),
								}
							):Play()
							Tween:Create(
								rbx.Label,
								TweenInfo.new(0.2),
								{ TextTransparency = 0, TextStrokeTransparency = 0.9 }
							):Play()
						end
					end)
				end)
				con[#con + 1] = parent.MouseLeave:Connect(function()
					local t = tick()
					inst = t
					Tween:Create(rbx, TweenInfo.new(0.2), { BackgroundTransparency = 1 }):Play()
					Tween:Create(rbx.Label, TweenInfo.new(0.2), { TextTransparency = 1, TextStrokeTransparency = 1 })
						:Play()
					delay(0.2, function()
						if inst == t then
							rbx.Visible = false
						end
					end)
				end)
			end
		end,
	},

	_prop = {
		Text = function(self, value)
			Class.CheckType(value, "string")
			self:rawset("Text", value)
			local size = TextService:GetTextSize(value, self.Label.TextSize, self.Label.Font, Vector2.new(240, 240))
			self.Size = UDim2.new(0, size.X + 16, 0, size.Y + 16)
			self.Label.Text = value
		end,
	},

	_init = function(self)
		local rbx = Object:Clone()
		self:rawset("_rbx", rbx) -- read-only

		self.Connections = {}

		self.ThemeData[rbx] = { BackgroundColor3 = "Primary", BackgroundTransparency = "Primary" }
		self.ThemeData[rbx.Label] = { TextColor3 = "PrimaryText" }
	end,
})
