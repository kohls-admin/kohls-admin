local a = Instance.new "Frame"
a.Name = "Hint"
a.Visible = false
a.Size = UDim2.new(1, 0, 1, 0)
a.BorderColor3 = Color3.fromRGB(0, 0, 0)
a.BackgroundTransparency = 1
a.BorderSizePixel = 0
a.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
local b = Instance.new "TextLabel"
b.Name = "BG"
b.AutoLocalize = false

b.ZIndex = 10
b.Size = UDim2.new(1, 0, 0, 24)
b.BorderColor3 = Color3.fromRGB(0, 0, 0)
b.BackgroundTransparency = 0.8
b.BorderSizePixel = 0
b.BackgroundColor3 = Color3.fromRGB(0, 0, 0)

b.TextStrokeTransparency = 0.7
b.TextSize = 18
b.TextColor3 = Color3.fromRGB(255, 255, 255)
b.Text = ""
b.TextWrapped = true
b.Font = 4
b.Parent = a

return a
