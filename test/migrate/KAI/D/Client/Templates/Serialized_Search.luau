local a = Instance.new "Frame"
a.Name = "Search"
a.ZIndex = 6
a.Size = UDim2.new(1, 0, 0, 20)
a.BorderColor3 = Color3.fromRGB(0, 0, 0)
a.BackgroundTransparency = 1
a.Position = UDim2.new(0, 0, 0, 222)
a.BorderSizePixel = 0
a.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
local b = Instance.new "TextBox"
b.Name = "BG"
b.AutoLocalize = false

b.Size = UDim2.new(1, 0, 1, 0)
b.ClipsDescendants = true
b.BorderColor3 = Color3.fromRGB(0, 0, 0)
b.BackgroundTransparency = 0.75
b.BorderSizePixel = 0
b.BackgroundColor3 = Color3.fromRGB(0, 0, 0)

b.TextStrokeTransparency = 0.75
b.TextSize = 14
b.TextColor3 = Color3.fromRGB(255, 255, 255)
b.Text = "Type here to search"
b.Font = 4
b.TextXAlignment = 1
b.Parent = a

return a
