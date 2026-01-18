local a = Instance.new "TextLabel"
a.AnchorPoint = Vector2.new(0, 1)
a.Name = "Note"
a.AutoLocalize = false

a.ZIndex = 10
a.Visible = false
a.Size = UDim2.new(0, 0, 0, 20)
a.BorderColor3 = Color3.fromRGB(0, 0, 0)
a.BackgroundTransparency = 1
a.BorderSizePixel = 0
a.BackgroundColor3 = Color3.fromRGB(0, 0, 0)

a.TextStrokeTransparency = 0.7
a.TextSize = 14
a.TextColor3 = Color3.fromRGB(255, 255, 255)
a.Text = ""
a.Font = 3
local b = Instance.new "Frame"
b.Name = "Back"
b.ZIndex = 9
b.Size = UDim2.new(1, 0, 1, 0)
b.BorderColor3 = Color3.fromRGB(0, 0, 0)
b.BackgroundTransparency = 0.5
b.BorderSizePixel = 0
b.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
b.Parent = a

return a
