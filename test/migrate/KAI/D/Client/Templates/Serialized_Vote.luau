local a = Instance.new "Frame"
a.Name = "Vote"
a.Visible = false
a.Size = UDim2.new(0, 250, 0, 100)
a.BorderColor3 = Color3.fromRGB(0, 0, 0)
a.BackgroundTransparency = 1
a.Position = UDim2.new(0.5, -125, 0.5, -50)
a.BorderSizePixel = 0
a.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
local b = Instance.new "Frame"
b.Name = "BG"
b.ZIndex = 8
b.Size = UDim2.new(1, 0, 1, 0)
b.BorderColor3 = Color3.fromRGB(0, 0, 0)
b.BackgroundTransparency = 0.8
b.BorderSizePixel = 0
b.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
b.Parent = a
local c = Instance.new "TextLabel"
c.Name = "Msg"
c.AutoLocalize = false

c.ZIndex = 9
c.Size = UDim2.new(1, -10, 0, 60)
c.BorderColor3 = Color3.fromRGB(0, 0, 0)
c.BackgroundTransparency = 1
c.Position = UDim2.new(0, 5, 0, 5)
c.BorderSizePixel = 0
c.BackgroundColor3 = Color3.fromRGB(0, 0, 0)

c.TextStrokeTransparency = 0.75
c.TextSize = 18
c.TextColor3 = Color3.fromRGB(255, 255, 255)
c.Text = ""
c.TextWrapped = true
c.Font = 2
c.Parent = a
local d = Instance.new "TextButton"
d.Name = "Y"
d.AutoLocalize = false

d.ZIndex = 9
d.Size = UDim2.new(0, 50, 0, 25)
d.BorderColor3 = Color3.fromRGB(0, 0, 0)
d.BackgroundTransparency = 0.75
d.Position = UDim2.new(0.5, -75, 1, -30)
d.BorderSizePixel = 0
d.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
d.Modal = true

d.TextStrokeTransparency = 0.75
d.TextSize = 18
d.TextColor3 = Color3.fromRGB(255, 255, 255)
d.Text = "YES"
d.Font = 2
d.Parent = a
local e = Instance.new "TextButton"
e.Name = "N"
e.AutoLocalize = false

e.ZIndex = 9
e.Size = UDim2.new(0, 50, 0, 25)
e.BorderColor3 = Color3.fromRGB(0, 0, 0)
e.BackgroundTransparency = 0.75
e.Position = UDim2.new(0.5, 25, 1, -30)
e.BorderSizePixel = 0
e.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
e.Modal = true

e.TextStrokeTransparency = 0.75
e.TextSize = 18
e.TextColor3 = Color3.fromRGB(255, 255, 255)
e.Text = "NO"
e.Font = 2
e.Parent = a

return a
