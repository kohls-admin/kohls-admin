local a = Instance.new "Frame"
a.Name = "Error"
a.Visible = false
a.Size = UDim2.new(1, 0, 0, 0)
a.BorderColor3 = Color3.fromRGB(0, 0, 0)
a.BackgroundTransparency = 1
a.Position = UDim2.new(0, 0, 0.5, 0)
a.BorderSizePixel = 0
a.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
local b = Instance.new "TextLabel"
b.Name = "Msg"
b.AutoLocalize = false
b.Localize = false
b.ZIndex = 9
b.Size = UDim2.new(1, 0, 0, 30)
b.BorderColor3 = Color3.fromRGB(0, 0, 0)
b.BackgroundTransparency = 0.5
b.Position = UDim2.new(0, 0, 0, -15)
b.BorderSizePixel = 0
b.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
b.FontSize = 7
b.TextStrokeTransparency = 0.7
b.TextSize = 24
b.TextColor3 = Color3.fromRGB(255, 255, 255)
b.Text = ""
b.TextWrapped = true
b.TextWrap = true
b.Font = 3
b.Parent = a
local c = Instance.new "TextLabel"
c.Name = "Title"
c.AutoLocalize = false
c.Localize = false
c.ZIndex = 10
c.BorderColor3 = Color3.fromRGB(0, 0, 0)
c.BackgroundTransparency = 1
c.Position = UDim2.new(0.5, 0, 0, -24)
c.BorderSizePixel = 0
c.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
c.FontSize = 7
c.TextStrokeTransparency = 0.7
c.TextSize = 24
c.TextColor3 = Color3.fromRGB(255, 255, 255)
c.TextYAlignment = 2
c.Text = "Kohl's Admin Infinite Error"
c.TextWrapped = true
c.TextWrap = true
c.Font = 4
c.Parent = a
local d = Instance.new "Frame"
d.Name = "Back"
d.ZIndex = 8
d.Size = UDim2.new(1, 0, 0, 48)
d.BorderColor3 = Color3.fromRGB(0, 0, 0)
d.BackgroundTransparency = 0.5
d.Position = UDim2.new(0, 0, 0, -24)
d.BorderSizePixel = 0
d.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
d.Parent = a

return a
