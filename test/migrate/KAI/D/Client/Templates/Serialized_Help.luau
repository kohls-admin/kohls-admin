local a = Instance.new "Frame"
a.Name = "Help"
a.ZIndex = 9
a.Visible = false
a.Size = UDim2.new(0, 300, 0, 20)
a.Draggable = true
a.BorderColor3 = Color3.fromRGB(0, 0, 0)
a.BackgroundTransparency = 1
a.Position = UDim2.new(0.5, -150, 0.5, -150)
a.Active = true
a.BorderSizePixel = 0
a.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
local b = Instance.new "Frame"
b.Name = "BG"
b.ZIndex = 7
b.Size = UDim2.new(1, 0, 0, 300)
b.BorderColor3 = Color3.fromRGB(0, 0, 0)
b.BackgroundTransparency = 0.8
b.Position = UDim2.new(0, 0, 0, 21)
b.BorderSizePixel = 0
b.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
b.Parent = a
local d = Instance.new "TextButton"
d.Name = "Close"
d.AutoLocalize = false

d.ZIndex = 10
d.Size = UDim2.new(0, 20, 0, 20)
d.BorderColor3 = Color3.fromRGB(0, 0, 0)
d.BackgroundTransparency = 1
d.Position = UDim2.new(1, -20, 0, 0)
d.BorderSizePixel = 0
d.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
d.Modal = true

d.TextStrokeTransparency = 0.75
d.TextSize = 18
d.TextColor3 = Color3.fromRGB(255, 255, 255)
d.Text = "X"
d.Font = 1
d.Parent = a
local e = Instance.new "TextLabel"
e.Name = "Title"
e.AutoLocalize = false

e.ZIndex = 10
e.Size = UDim2.new(1, -25, 0, 20)
e.BorderColor3 = Color3.fromRGB(0, 0, 0)
e.BackgroundTransparency = 1
e.Position = UDim2.new(0, 5, 0, 0)
e.BorderSizePixel = 0
e.BackgroundColor3 = Color3.fromRGB(0, 0, 0)

e.TextStrokeTransparency = 0.75
e.TextSize = 18
e.TextColor3 = Color3.fromRGB(255, 255, 255)
e.Text = "Kohl's Admin Help"
e.Font = 4
e.TextXAlignment = 0
e.Parent = a
local f = Instance.new "Frame"
f.Name = "Bar"
f.ZIndex = 8
f.Size = UDim2.new(1, 0, 1, 0)
f.BorderColor3 = Color3.fromRGB(0, 0, 0)
f.BackgroundTransparency = 0.8
f.BorderSizePixel = 0
f.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
f.Parent = a
local g = Instance.new "TextButton"
g.Name = "Hide"
g.AutoLocalize = false

g.ZIndex = 10
g.Size = UDim2.new(0, 20, 0, 20)
g.BorderColor3 = Color3.fromRGB(0, 0, 0)
g.BackgroundTransparency = 1
g.Position = UDim2.new(1, -40, 0, 0)
g.BorderSizePixel = 0
g.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
g.Modal = true

g.TextStrokeTransparency = 0.75
g.TextSize = 24
g.TextColor3 = Color3.fromRGB(255, 255, 255)
g.Text = "-"
g.Font = 1
g.Parent = a
local h = Instance.new "ScrollingFrame"
h.Name = "List"
h.ZIndex = 9
h.Size = UDim2.new(1, 0, 0, 300)
h.BorderColor3 = Color3.fromRGB(0, 0, 0)
h.BackgroundTransparency = 1
h.Position = UDim2.new(0, 0, 0, 21)
h.Active = true
h.BorderSizePixel = 0
h.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
h.ScrollingDirection = 2
h.CanvasSize = UDim2.new(1, 0, 0, 745)
h.MidImage = "rbxassetid://305807572"
h.ScrollBarThickness = 5
h.TopImage = "rbxassetid://305807549"
h.BottomImage = "rbxassetid://305807605"
h.Parent = a
local i = Instance.new "TextLabel"
i.Name = "Prefix"
i.AutoLocalize = false

i.ZIndex = 9
i.Size = UDim2.new(1, 0, 0, 25)
i.BorderColor3 = Color3.fromRGB(0, 0, 0)
i.BackgroundTransparency = 1
i.BorderSizePixel = 0
i.BackgroundColor3 = Color3.fromRGB(0, 0, 0)

i.TextStrokeTransparency = 0.75
i.TextSize = 18
i.TextColor3 = Color3.fromRGB(255, 255, 255)
i.Text = 'The prefix is ":"'
i.TextWrapped = true
i.Font = 3
i.Parent = h
local j = Instance.new "TextLabel"
j.Name = "T1"
j.AutoLocalize = false

j.ZIndex = 9
j.Size = UDim2.new(1, 0, 0, 20)
j.BorderColor3 = Color3.fromRGB(0, 0, 0)
j.BackgroundTransparency = 1
j.Position = UDim2.new(0, 0, 0, 25)
j.BorderSizePixel = 0
j.BackgroundColor3 = Color3.fromRGB(0, 0, 0)

j.TextStrokeTransparency = 0.75
j.TextSize = 24
j.TextColor3 = Color3.fromRGB(255, 255, 255)
j.Text = "Overview"
j.TextWrapped = true
j.Font = 4
j.Parent = h
local k = Instance.new "TextLabel"
k.Name = "Body"
k.AutoLocalize = false

k.ZIndex = 9
k.Size = UDim2.new(1, -10, 0, 30)
k.BorderColor3 = Color3.fromRGB(0, 0, 0)
k.BackgroundTransparency = 1
k.Position = UDim2.new(0, 5, 0, 20)
k.BorderSizePixel = 0
k.BackgroundColor3 = Color3.fromRGB(0, 0, 0)

k.TextStrokeTransparency = 0.75
k.TextSize = 14
k.TextColor3 = Color3.fromRGB(255, 255, 255)
k.Text = "Kohl's Admin Infinite has various features you can use to benefit your experience."
k.TextWrapped = true
k.Font = 3
k.Parent = j
local l = Instance.new "Frame"
l.Name = "Features"
l.Size = UDim2.new(1, -10, 0, 0)
l.BorderColor3 = Color3.fromRGB(0, 0, 0)
l.BackgroundTransparency = 1
l.Position = UDim2.new(0, 5, 0, 55)
l.BorderSizePixel = 0
l.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
l.Parent = j
local m = Instance.new "TextLabel"
m.Name = "F1"
m.AutoLocalize = false

m.ZIndex = 9
m.Size = UDim2.new(1, 0, 0, 15)
m.BorderColor3 = Color3.fromRGB(0, 0, 0)
m.BackgroundTransparency = 1
m.BorderSizePixel = 0
m.BackgroundColor3 = Color3.fromRGB(0, 0, 0)

m.TextStrokeTransparency = 0.75
m.TextSize = 18
m.TextColor3 = Color3.fromRGB(255, 255, 255)
m.Text = "- Permanent Admins & Bans"
m.TextWrapped = true
m.Font = 4
m.TextXAlignment = 0
m.Parent = l
local n = Instance.new "TextLabel"
n.Name = "D"
n.AutoLocalize = false

n.ZIndex = 9
n.Size = UDim2.new(1, -5, 2, 0)
n.BorderColor3 = Color3.fromRGB(0, 0, 0)
n.BackgroundTransparency = 1
n.Position = UDim2.new(0, 5, 1, 0)
n.BorderSizePixel = 0
n.BackgroundColor3 = Color3.fromRGB(0, 0, 0)

n.TextStrokeTransparency = 0.75
n.TextSize = 14
n.TextColor3 = Color3.fromRGB(255, 255, 255)
n.Text = "There are a variety of permanent commands.\nFor Example;\t:padmin kohl\t/\t:pban noob"
n.TextWrapped = true
n.Font = 3
n.TextXAlignment = 0
n.Parent = m
local o = Instance.new "TextLabel"
o.Name = "F5"
o.AutoLocalize = false

o.ZIndex = 9
o.Size = UDim2.new(1, 0, 0, 15)
o.BorderColor3 = Color3.fromRGB(0, 0, 0)
o.BackgroundTransparency = 1
o.Position = UDim2.new(0, 0, 0, 170)
o.BorderSizePixel = 0
o.BackgroundColor3 = Color3.fromRGB(0, 0, 0)

o.TextStrokeTransparency = 0.75
o.TextSize = 18
o.TextColor3 = Color3.fromRGB(255, 255, 255)
o.Text = "- Group & VIP Admin/Cmd Permissions"
o.TextWrapped = true
o.Font = 4
o.TextXAlignment = 0
o.Parent = l
local p = Instance.new "TextLabel"
p.Name = "D"
p.AutoLocalize = false

p.ZIndex = 9
p.Size = UDim2.new(1, -5, 1, 0)
p.BorderColor3 = Color3.fromRGB(0, 0, 0)
p.BackgroundTransparency = 1
p.Position = UDim2.new(0, 5, 1, 0)
p.BorderSizePixel = 0
p.BackgroundColor3 = Color3.fromRGB(0, 0, 0)

p.TextStrokeTransparency = 0.75
p.TextSize = 14
p.TextColor3 = Color3.fromRGB(255, 255, 255)
p.Text = 'Refer to "Settings" module in ROBLOX Studio.'
p.TextWrapped = true
p.Font = 3
p.TextXAlignment = 0
p.Parent = o
local q = Instance.new "TextLabel"
q.Name = "F4"
q.AutoLocalize = false

q.ZIndex = 9
q.Size = UDim2.new(1, 0, 0, 15)
q.BorderColor3 = Color3.fromRGB(0, 0, 0)
q.BackgroundTransparency = 1
q.Position = UDim2.new(0, 0, 0, 135)
q.BorderSizePixel = 0
q.BackgroundColor3 = Color3.fromRGB(0, 0, 0)

q.TextStrokeTransparency = 0.75
q.TextSize = 18
q.TextColor3 = Color3.fromRGB(255, 255, 255)
q.Text = "- In-game Settings"
q.TextWrapped = true
q.Font = 4
q.TextXAlignment = 0
q.Parent = l
local r = Instance.new "TextLabel"
r.Name = "D"
r.AutoLocalize = false

r.ZIndex = 9
r.Size = UDim2.new(1, -5, 1, 0)
r.BorderColor3 = Color3.fromRGB(0, 0, 0)
r.BackgroundTransparency = 1
r.Position = UDim2.new(0, 5, 1, 0)
r.BorderSizePixel = 0
r.BackgroundColor3 = Color3.fromRGB(0, 0, 0)

r.TextStrokeTransparency = 0.75
r.TextSize = 14
r.TextColor3 = Color3.fromRGB(255, 255, 255)
r.Text = "Use the 'set' command to access the in-game settings."
r.TextWrapped = true
r.Font = 3
r.TextXAlignment = 0
r.Parent = q
local s = Instance.new "TextLabel"
s.Name = "F3"
s.AutoLocalize = false

s.ZIndex = 9
s.Size = UDim2.new(1, 0, 0, 15)
s.BorderColor3 = Color3.fromRGB(0, 0, 0)
s.BackgroundTransparency = 1
s.Position = UDim2.new(0, 0, 0, 100)
s.BorderSizePixel = 0
s.BackgroundColor3 = Color3.fromRGB(0, 0, 0)

s.TextStrokeTransparency = 0.75
s.TextSize = 18
s.TextColor3 = Color3.fromRGB(255, 255, 255)
s.Text = '- Command Bar(key: ";")'
s.TextWrapped = true
s.Font = 4
s.TextXAlignment = 0
s.Parent = l
local t = Instance.new "TextLabel"
t.Name = "D"
t.AutoLocalize = false

t.ZIndex = 9
t.Size = UDim2.new(1, -5, 1, 0)
t.BorderColor3 = Color3.fromRGB(0, 0, 0)
t.BackgroundTransparency = 1
t.Position = UDim2.new(0, 5, 1, 0)
t.BorderSizePixel = 0
t.BackgroundColor3 = Color3.fromRGB(0, 0, 0)

t.TextStrokeTransparency = 0.75
t.TextSize = 14
t.TextColor3 = Color3.fromRGB(255, 255, 255)
t.Text = 'Press the ";" key to use the command bar.'
t.TextWrapped = true
t.Font = 3
t.TextXAlignment = 0
t.Parent = s
local u = Instance.new "TextLabel"
u.Name = "F2"
u.AutoLocalize = false

u.ZIndex = 9
u.Size = UDim2.new(1, 0, 0, 15)
u.BorderColor3 = Color3.fromRGB(0, 0, 0)
u.BackgroundTransparency = 1
u.Position = UDim2.new(0, 0, 0, 50)
u.BorderSizePixel = 0
u.BackgroundColor3 = Color3.fromRGB(0, 0, 0)

u.TextStrokeTransparency = 0.75
u.TextSize = 18
u.TextColor3 = Color3.fromRGB(255, 255, 255)
u.Text = "- Batch commands"
u.TextWrapped = true
u.Font = 4
u.TextXAlignment = 0
u.Parent = l
local v = Instance.new "TextLabel"
v.Name = "D"
v.AutoLocalize = false

v.ZIndex = 9
v.Size = UDim2.new(1, -5, 2, 0)
v.BorderColor3 = Color3.fromRGB(0, 0, 0)
v.BackgroundTransparency = 1
v.Position = UDim2.new(0, 5, 1, 0)
v.BorderSizePixel = 0
v.BackgroundColor3 = Color3.fromRGB(0, 0, 0)

v.TextStrokeTransparency = 0.75
v.TextSize = 14
v.TextColor3 = Color3.fromRGB(255, 255, 255)
v.Text = "You can use multiple commands in a single sentence\nFor example;\t:ff me :m hello"
v.TextWrapped = true
v.Font = 3
v.TextXAlignment = 0
v.Parent = u
local w = Instance.new "TextLabel"
w.Name = "F6"
w.AutoLocalize = false

w.ZIndex = 9
w.Size = UDim2.new(1, 0, 0, 15)
w.BorderColor3 = Color3.fromRGB(0, 0, 0)
w.BackgroundTransparency = 1
w.Position = UDim2.new(0, 0, 0, 205)
w.BorderSizePixel = 0
w.BackgroundColor3 = Color3.fromRGB(0, 0, 0)

w.TextStrokeTransparency = 0.75
w.TextSize = 18
w.TextColor3 = Color3.fromRGB(255, 255, 255)
w.Text = "- Custom Commands"
w.TextWrapped = true
w.Font = 4
w.TextXAlignment = 0
w.Parent = l
local x = Instance.new "TextLabel"
x.Name = "D"
x.AutoLocalize = false

x.ZIndex = 9
x.Size = UDim2.new(1, -5, 1, 0)
x.BorderColor3 = Color3.fromRGB(0, 0, 0)
x.BackgroundTransparency = 1
x.Position = UDim2.new(0, 5, 1, 0)
x.BorderSizePixel = 0
x.BackgroundColor3 = Color3.fromRGB(0, 0, 0)

x.TextStrokeTransparency = 0.75
x.TextSize = 14
x.TextColor3 = Color3.fromRGB(255, 255, 255)
x.Text = 'Refer to "Custom Commands" module in ROBLOX Studio.'
x.TextWrapped = true
x.Font = 3
x.TextXAlignment = 0
x.Parent = w
local y = Instance.new "TextLabel"
y.Name = "T2"
y.AutoLocalize = false

y.ZIndex = 9
y.Size = UDim2.new(1, 0, 0, 20)
y.BorderColor3 = Color3.fromRGB(0, 0, 0)
y.BackgroundTransparency = 1
y.Position = UDim2.new(0, 0, 0, 325)
y.BorderSizePixel = 0
y.BackgroundColor3 = Color3.fromRGB(0, 0, 0)

y.TextStrokeTransparency = 0.75
y.TextSize = 24
y.TextColor3 = Color3.fromRGB(255, 255, 255)
y.Text = "General Usage"
y.TextWrapped = true
y.Font = 4
y.Parent = h
local z = Instance.new "TextLabel"
z.Name = "Body"
z.AutoLocalize = false

z.ZIndex = 9
z.Size = UDim2.new(1, -10, 0, 30)
z.BorderColor3 = Color3.fromRGB(0, 0, 0)
z.BackgroundTransparency = 1
z.Position = UDim2.new(0, 5, 0, 20)
z.BorderSizePixel = 0
z.BackgroundColor3 = Color3.fromRGB(0, 0, 0)

z.TextStrokeTransparency = 0.75
z.TextSize = 14
z.TextColor3 = Color3.fromRGB(255, 255, 255)
z.Text = 'To configure the admin edit the "Settings" module in ROBLOX Studio.'
z.TextWrapped = true
z.Font = 3
z.Parent = y
local A = Instance.new "TextLabel"
A.Name = "PlayerCmds"
A.AutoLocalize = false

A.ZIndex = 9
A.Size = UDim2.new(1, -10, 0, 20)
A.BorderColor3 = Color3.fromRGB(0, 0, 0)
A.BackgroundTransparency = 1
A.Position = UDim2.new(0, 5, 0, 145)
A.BorderSizePixel = 0
A.BackgroundColor3 = Color3.fromRGB(0, 0, 0)

A.TextStrokeTransparency = 0.75
A.TextSize = 18
A.TextColor3 = Color3.fromRGB(255, 255, 255)
A.Text = "Player Commands"
A.TextWrapped = true
A.Font = 4
A.Parent = y
local B = Instance.new "TextLabel"
B.Name = "c1"
B.AutoLocalize = false

B.ZIndex = 9
B.Size = UDim2.new(0, 0, 0, 20)
B.BorderColor3 = Color3.fromRGB(0, 0, 0)
B.BackgroundTransparency = 1
B.Position = UDim2.new(0.5, -30, 0, 25)
B.BorderSizePixel = 0
B.BackgroundColor3 = Color3.fromRGB(0, 0, 0)

B.TextStrokeTransparency = 0.75
B.TextSize = 18
B.TextColor3 = Color3.fromRGB(255, 255, 255)
B.Text = "all"
B.Font = 3
B.TextXAlignment = 1
B.Parent = A
local C = Instance.new "TextLabel"
C.Name = "D"
C.AutoLocalize = false

C.ZIndex = 9
C.Size = UDim2.new(0, 0, 0, 20)
C.BorderColor3 = Color3.fromRGB(0, 0, 0)
C.BackgroundTransparency = 1
C.Position = UDim2.new(0, 10, 0, 0)
C.BorderSizePixel = 0
C.BackgroundColor3 = Color3.fromRGB(0, 0, 0)

C.TextStrokeTransparency = 0.75
C.TextSize = 18
C.TextColor3 = Color3.fromRGB(255, 255, 255)
C.Text = "All in-game"
C.TextWrapped = true
C.Font = 5
C.TextXAlignment = 0
C.Parent = B
local D = Instance.new "TextLabel"
D.Name = "c2"
D.AutoLocalize = false

D.ZIndex = 9
D.Size = UDim2.new(0, 0, 0, 20)
D.BorderColor3 = Color3.fromRGB(0, 0, 0)
D.BackgroundTransparency = 1
D.Position = UDim2.new(0.5, -30, 0, 40)
D.BorderSizePixel = 0
D.BackgroundColor3 = Color3.fromRGB(0, 0, 0)

D.TextStrokeTransparency = 0.75
D.TextSize = 18
D.TextColor3 = Color3.fromRGB(255, 255, 255)
D.Text = "me"
D.Font = 3
D.TextXAlignment = 1
D.Parent = A
local E = Instance.new "TextLabel"
E.Name = "D"
E.AutoLocalize = false

E.ZIndex = 9
E.Size = UDim2.new(0, 0, 0, 20)
E.BorderColor3 = Color3.fromRGB(0, 0, 0)
E.BackgroundTransparency = 1
E.Position = UDim2.new(0, 10, 0, 0)
E.BorderSizePixel = 0
E.BackgroundColor3 = Color3.fromRGB(0, 0, 0)

E.TextStrokeTransparency = 0.75
E.TextSize = 18
E.TextColor3 = Color3.fromRGB(255, 255, 255)
E.Text = "Yourself"
E.TextWrapped = true
E.Font = 5
E.TextXAlignment = 0
E.Parent = D
local F = Instance.new "TextLabel"
F.Name = "c3"
F.AutoLocalize = false

F.ZIndex = 9
F.Size = UDim2.new(0, 0, 0, 20)
F.BorderColor3 = Color3.fromRGB(0, 0, 0)
F.BackgroundTransparency = 1
F.Position = UDim2.new(0.5, -30, 0, 55)
F.BorderSizePixel = 0
F.BackgroundColor3 = Color3.fromRGB(0, 0, 0)

F.TextStrokeTransparency = 0.75
F.TextSize = 18
F.TextColor3 = Color3.fromRGB(255, 255, 255)
F.Text = "random"
F.Font = 3
F.TextXAlignment = 1
F.Parent = A
local G = Instance.new "TextLabel"
G.Name = "D"
G.AutoLocalize = false

G.ZIndex = 9
G.Size = UDim2.new(0, 0, 0, 20)
G.BorderColor3 = Color3.fromRGB(0, 0, 0)
G.BackgroundTransparency = 1
G.Position = UDim2.new(0, 10, 0, 0)
G.BorderSizePixel = 0
G.BackgroundColor3 = Color3.fromRGB(0, 0, 0)

G.TextStrokeTransparency = 0.75
G.TextSize = 18
G.TextColor3 = Color3.fromRGB(255, 255, 255)
G.Text = "Random player"
G.TextWrapped = true
G.Font = 5
G.TextXAlignment = 0
G.Parent = F
local H = Instance.new "TextLabel"
H.Name = "c4"
H.AutoLocalize = false

H.ZIndex = 9
H.Size = UDim2.new(0, 0, 0, 20)
H.BorderColor3 = Color3.fromRGB(0, 0, 0)
H.BackgroundTransparency = 1
H.Position = UDim2.new(0.5, -30, 0, 70)
H.BorderSizePixel = 0
H.BackgroundColor3 = Color3.fromRGB(0, 0, 0)

H.TextStrokeTransparency = 0.75
H.TextSize = 18
H.TextColor3 = Color3.fromRGB(255, 255, 255)
H.Text = "others"
H.Font = 3
H.TextXAlignment = 1
H.Parent = A
local I = Instance.new "TextLabel"
I.Name = "D"
I.AutoLocalize = false

I.ZIndex = 9
I.Size = UDim2.new(0, 0, 0, 20)
I.BorderColor3 = Color3.fromRGB(0, 0, 0)
I.BackgroundTransparency = 1
I.Position = UDim2.new(0, 10, 0, 0)
I.BorderSizePixel = 0
I.BackgroundColor3 = Color3.fromRGB(0, 0, 0)

I.TextStrokeTransparency = 0.75
I.TextSize = 18
I.TextColor3 = Color3.fromRGB(255, 255, 255)
I.Text = "All but yourself"
I.TextWrapped = true
I.Font = 5
I.TextXAlignment = 0
I.Parent = H
local J = Instance.new "TextLabel"
J.Name = "c5"
J.AutoLocalize = false

J.ZIndex = 9
J.Size = UDim2.new(0, 0, 0, 20)
J.BorderColor3 = Color3.fromRGB(0, 0, 0)
J.BackgroundTransparency = 1
J.Position = UDim2.new(0.5, -30, 0, 85)
J.BorderSizePixel = 0
J.BackgroundColor3 = Color3.fromRGB(0, 0, 0)

J.TextStrokeTransparency = 0.75
J.TextSize = 18
J.TextColor3 = Color3.fromRGB(255, 255, 255)
J.Text = "friends"
J.Font = 3
J.TextXAlignment = 1
J.Parent = A
local K = Instance.new "TextLabel"
K.Name = "D"
K.AutoLocalize = false

K.ZIndex = 9
K.Size = UDim2.new(0, 0, 0, 20)
K.BorderColor3 = Color3.fromRGB(0, 0, 0)
K.BackgroundTransparency = 1
K.Position = UDim2.new(0, 10, 0, 0)
K.BorderSizePixel = 0
K.BackgroundColor3 = Color3.fromRGB(0, 0, 0)

K.TextStrokeTransparency = 0.75
K.TextSize = 18
K.TextColor3 = Color3.fromRGB(255, 255, 255)
K.Text = "Your friends"
K.TextWrapped = true
K.Font = 5
K.TextXAlignment = 0
K.Parent = J
local L = Instance.new "TextLabel"
L.Name = "c6"
L.AutoLocalize = false

L.ZIndex = 9
L.Size = UDim2.new(0, 0, 0, 20)
L.BorderColor3 = Color3.fromRGB(0, 0, 0)
L.BackgroundTransparency = 1
L.Position = UDim2.new(0.5, -30, 0, 100)
L.BorderSizePixel = 0
L.BackgroundColor3 = Color3.fromRGB(0, 0, 0)

L.TextStrokeTransparency = 0.75
L.TextSize = 18
L.TextColor3 = Color3.fromRGB(255, 255, 255)
L.Text = "guests"
L.Font = 3
L.TextXAlignment = 1
L.Parent = A
local M = Instance.new "TextLabel"
M.Name = "D"
M.AutoLocalize = false

M.ZIndex = 9
M.Size = UDim2.new(0, 0, 0, 20)
M.BorderColor3 = Color3.fromRGB(0, 0, 0)
M.BackgroundTransparency = 1
M.Position = UDim2.new(0, 10, 0, 0)
M.BorderSizePixel = 0
M.BackgroundColor3 = Color3.fromRGB(0, 0, 0)

M.TextStrokeTransparency = 0.75
M.TextSize = 18
M.TextColor3 = Color3.fromRGB(255, 255, 255)
M.Text = "Guest players"
M.TextWrapped = true
M.Font = 5
M.TextXAlignment = 0
M.Parent = L
local N = Instance.new "TextLabel"
N.Name = "c7"
N.AutoLocalize = false

N.ZIndex = 9
N.Size = UDim2.new(0, 0, 0, 20)
N.BorderColor3 = Color3.fromRGB(0, 0, 0)
N.BackgroundTransparency = 1
N.Position = UDim2.new(0.5, -30, 0, 115)
N.BorderSizePixel = 0
N.BackgroundColor3 = Color3.fromRGB(0, 0, 0)

N.TextStrokeTransparency = 0.75
N.TextSize = 18
N.TextColor3 = Color3.fromRGB(255, 255, 255)
N.Text = "veterans"
N.Font = 3
N.TextXAlignment = 1
N.Parent = A
local O = Instance.new "TextLabel"
O.Name = "D"
O.AutoLocalize = false

O.ZIndex = 9
O.Size = UDim2.new(0, 0, 0, 20)
O.BorderColor3 = Color3.fromRGB(0, 0, 0)
O.BackgroundTransparency = 1
O.Position = UDim2.new(0, 10, 0, 0)
O.BorderSizePixel = 0
O.BackgroundColor3 = Color3.fromRGB(0, 0, 0)

O.TextStrokeTransparency = 0.75
O.TextSize = 18
O.TextColor3 = Color3.fromRGB(255, 255, 255)
O.Text = "Over 1 year old"
O.TextWrapped = true
O.Font = 5
O.TextXAlignment = 0
O.Parent = N
local P = Instance.new "TextLabel"
P.Name = "c8"
P.AutoLocalize = false

P.ZIndex = 9
P.Size = UDim2.new(0, 0, 0, 20)
P.BorderColor3 = Color3.fromRGB(0, 0, 0)
P.BackgroundTransparency = 1
P.Position = UDim2.new(0.5, -30, 0, 130)
P.BorderSizePixel = 0
P.BackgroundColor3 = Color3.fromRGB(0, 0, 0)

P.TextStrokeTransparency = 0.75
P.TextSize = 18
P.TextColor3 = Color3.fromRGB(255, 255, 255)
P.Text = "alts"
P.Font = 3
P.TextXAlignment = 1
P.Parent = A
local Q = Instance.new "TextLabel"
Q.Name = "D"
Q.AutoLocalize = false

Q.ZIndex = 9
Q.Size = UDim2.new(0, 0, 0, 20)
Q.BorderColor3 = Color3.fromRGB(0, 0, 0)
Q.BackgroundTransparency = 1
Q.Position = UDim2.new(0, 10, 0, 0)
Q.BorderSizePixel = 0
Q.BackgroundColor3 = Color3.fromRGB(0, 0, 0)

Q.TextStrokeTransparency = 0.75
Q.TextSize = 18
Q.TextColor3 = Color3.fromRGB(255, 255, 255)
Q.Text = "Under 1 year old"
Q.TextWrapped = true
Q.Font = 5
Q.TextXAlignment = 0
Q.Parent = P
local R = Instance.new "TextLabel"
R.Name = "c9"
R.AutoLocalize = false

R.ZIndex = 9
R.Size = UDim2.new(0, 0, 0, 20)
R.BorderColor3 = Color3.fromRGB(0, 0, 0)
R.BackgroundTransparency = 1
R.Position = UDim2.new(0.5, -30, 0, 145)
R.BorderSizePixel = 0
R.BackgroundColor3 = Color3.fromRGB(0, 0, 0)

R.TextStrokeTransparency = 0.75
R.TextSize = 18
R.TextColor3 = Color3.fromRGB(255, 255, 255)
R.Text = "close"
R.Font = 3
R.TextXAlignment = 1
R.Parent = A
local S = Instance.new "TextLabel"
S.Name = "D"
S.AutoLocalize = false

S.ZIndex = 9
S.Size = UDim2.new(0, 0, 0, 20)
S.BorderColor3 = Color3.fromRGB(0, 0, 0)
S.BackgroundTransparency = 1
S.Position = UDim2.new(0, 10, 0, 0)
S.BorderSizePixel = 0
S.BackgroundColor3 = Color3.fromRGB(0, 0, 0)

S.TextStrokeTransparency = 0.75
S.TextSize = 18
S.TextColor3 = Color3.fromRGB(255, 255, 255)
S.Text = "Within 50 studs"
S.TextWrapped = true
S.Font = 5
S.TextXAlignment = 0
S.Parent = R
local T = Instance.new "TextLabel"
T.Name = "c10"
T.AutoLocalize = false

T.ZIndex = 9
T.Size = UDim2.new(0, 0, 0, 20)
T.BorderColor3 = Color3.fromRGB(0, 0, 0)
T.BackgroundTransparency = 1
T.Position = UDim2.new(0.5, -30, 0, 160)
T.BorderSizePixel = 0
T.BackgroundColor3 = Color3.fromRGB(0, 0, 0)

T.TextStrokeTransparency = 0.75
T.TextSize = 18
T.TextColor3 = Color3.fromRGB(255, 255, 255)
T.Text = "far"
T.Font = 3
T.TextXAlignment = 1
T.Parent = A
local U = Instance.new "TextLabel"
U.Name = "D"
U.AutoLocalize = false

U.ZIndex = 9
U.Size = UDim2.new(0, 0, 0, 20)
U.BorderColor3 = Color3.fromRGB(0, 0, 0)
U.BackgroundTransparency = 1
U.Position = UDim2.new(0, 10, 0, 0)
U.BorderSizePixel = 0
U.BackgroundColor3 = Color3.fromRGB(0, 0, 0)

U.TextStrokeTransparency = 0.75
U.TextSize = 18
U.TextColor3 = Color3.fromRGB(255, 255, 255)
U.Text = "Not within 50 studs"
U.TextWrapped = true
U.Font = 5
U.TextXAlignment = 0
U.Parent = T
local V = Instance.new "TextLabel"
V.Name = "c11"
V.AutoLocalize = false

V.ZIndex = 9
V.Size = UDim2.new(0, 0, 0, 20)
V.BorderColor3 = Color3.fromRGB(0, 0, 0)
V.BackgroundTransparency = 1
V.Position = UDim2.new(0.5, -30, 0, 175)
V.BorderSizePixel = 0
V.BackgroundColor3 = Color3.fromRGB(0, 0, 0)

V.TextStrokeTransparency = 0.75
V.TextSize = 18
V.TextColor3 = Color3.fromRGB(255, 255, 255)
V.Text = "radius-99"
V.Font = 3
V.TextXAlignment = 1
V.Parent = A
local W = Instance.new "TextLabel"
W.Name = "D"
W.AutoLocalize = false

W.ZIndex = 9
W.Size = UDim2.new(0, 0, 0, 20)
W.BorderColor3 = Color3.fromRGB(0, 0, 0)
W.BackgroundTransparency = 1
W.Position = UDim2.new(0, 10, 0, 0)
W.BorderSizePixel = 0
W.BackgroundColor3 = Color3.fromRGB(0, 0, 0)

W.TextStrokeTransparency = 0.75
W.TextSize = 18
W.TextColor3 = Color3.fromRGB(255, 255, 255)
W.Text = "Within # studs"
W.TextWrapped = true
W.Font = 5
W.TextXAlignment = 0
W.Parent = V
local X = Instance.new "TextLabel"
X.Name = "c13"
X.AutoLocalize = false

X.ZIndex = 9
X.Size = UDim2.new(0, 0, 0, 20)
X.BorderColor3 = Color3.fromRGB(0, 0, 0)
X.BackgroundTransparency = 1
X.Position = UDim2.new(0.5, -30, 0, 205)
X.BorderSizePixel = 0
X.BackgroundColor3 = Color3.fromRGB(0, 0, 0)

X.TextStrokeTransparency = 0.75
X.TextSize = 18
X.TextColor3 = Color3.fromRGB(255, 255, 255)
X.Text = "%raiders"
X.Font = 3
X.TextXAlignment = 1
X.Parent = A
local Y = Instance.new "TextLabel"
Y.Name = "D"
Y.AutoLocalize = false

Y.ZIndex = 9
Y.Size = UDim2.new(0, 0, 0, 20)
Y.BorderColor3 = Color3.fromRGB(0, 0, 0)
Y.BackgroundTransparency = 1
Y.Position = UDim2.new(0, 10, 0, 0)
Y.BorderSizePixel = 0
Y.BackgroundColor3 = Color3.fromRGB(0, 0, 0)

Y.TextStrokeTransparency = 0.75
Y.TextSize = 18
Y.TextColor3 = Color3.fromRGB(255, 255, 255)
Y.Text = "On team"
Y.TextWrapped = true
Y.Font = 5
Y.TextXAlignment = 0
Y.Parent = X
local Za = Instance.new "TextLabel"
Za.Name = "c12"
Za.AutoLocalize = false

Za.ZIndex = 9
Za.Size = UDim2.new(0, 0, 0, 20)
Za.BorderColor3 = Color3.fromRGB(0, 0, 0)
Za.BackgroundTransparency = 1
Za.Position = UDim2.new(0.5, -30, 0, 190)
Za.BorderSizePixel = 0
Za.BackgroundColor3 = Color3.fromRGB(0, 0, 0)

Za.TextStrokeTransparency = 0.75
Za.TextSize = 18
Za.TextColor3 = Color3.fromRGB(255, 255, 255)
Za.Text = "group-123"
Za.Font = 3
Za.TextXAlignment = 1
Za.Parent = A
local aa = Instance.new "TextLabel"
aa.Name = "D"
aa.AutoLocalize = false

aa.ZIndex = 9
aa.Size = UDim2.new(0, 0, 0, 20)
aa.BorderColor3 = Color3.fromRGB(0, 0, 0)
aa.BackgroundTransparency = 1
aa.Position = UDim2.new(0, 10, 0, 0)
aa.BorderSizePixel = 0
aa.BackgroundColor3 = Color3.fromRGB(0, 0, 0)

aa.TextStrokeTransparency = 0.75
aa.TextSize = 18
aa.TextColor3 = Color3.fromRGB(255, 255, 255)
aa.Text = "In group"
aa.TextWrapped = true
aa.Font = 5
aa.TextXAlignment = 0
aa.Parent = Za
local ba = Instance.new "TextLabel"
ba.Name = "c14"
ba.AutoLocalize = false

ba.ZIndex = 9
ba.Size = UDim2.new(0, 0, 0, 20)
ba.BorderColor3 = Color3.fromRGB(0, 0, 0)
ba.BackgroundTransparency = 1
ba.Position = UDim2.new(0.5, -30, 0, 220)
ba.BorderSizePixel = 0
ba.BackgroundColor3 = Color3.fromRGB(0, 0, 0)

ba.TextStrokeTransparency = 0.75
ba.TextSize = 18
ba.TextColor3 = Color3.fromRGB(255, 255, 255)
ba.Text = "#5"
ba.Font = 3
ba.TextXAlignment = 1
ba.Parent = A
local ca = Instance.new "TextLabel"
ca.Name = "D"
ca.AutoLocalize = false

ca.ZIndex = 9
ca.Size = UDim2.new(0, 0, 0, 20)
ca.BorderColor3 = Color3.fromRGB(0, 0, 0)
ca.BackgroundTransparency = 1
ca.Position = UDim2.new(0, 10, 0, 0)
ca.BorderSizePixel = 0
ca.BackgroundColor3 = Color3.fromRGB(0, 0, 0)

ca.TextStrokeTransparency = 0.75
ca.TextSize = 18
ca.TextColor3 = Color3.fromRGB(255, 255, 255)
ca.Text = "# Random players"
ca.TextWrapped = true
ca.Font = 5
ca.TextXAlignment = 0
ca.Parent = ba
local da = Instance.new "TextLabel"
da.Name = "c16"
da.AutoLocalize = false

da.ZIndex = 9
da.Size = UDim2.new(0, 0, 0, 20)
da.BorderColor3 = Color3.fromRGB(0, 0, 0)
da.BackgroundTransparency = 1
da.Position = UDim2.new(0.5, -30, 0, 250)
da.BorderSizePixel = 0
da.BackgroundColor3 = Color3.fromRGB(0, 0, 0)

da.TextStrokeTransparency = 0.75
da.TextSize = 18
da.TextColor3 = Color3.fromRGB(255, 255, 255)
da.Text = "nonadmins"
da.Font = 3
da.TextXAlignment = 1
da.Parent = A
local ea = Instance.new "TextLabel"
ea.Name = "D"
ea.AutoLocalize = false

ea.ZIndex = 9
ea.Size = UDim2.new(0, 0, 0, 20)
ea.BorderColor3 = Color3.fromRGB(0, 0, 0)
ea.BackgroundTransparency = 1
ea.Position = UDim2.new(0, 10, 0, 0)
ea.BorderSizePixel = 0
ea.BackgroundColor3 = Color3.fromRGB(0, 0, 0)

ea.TextStrokeTransparency = 0.75
ea.TextSize = 18
ea.TextColor3 = Color3.fromRGB(255, 255, 255)
ea.Text = "Nonadmins"
ea.TextWrapped = true
ea.Font = 5
ea.TextXAlignment = 0
ea.Parent = da
local fa = Instance.new "TextLabel"
fa.Name = "c15"
fa.AutoLocalize = false

fa.ZIndex = 9
fa.Size = UDim2.new(0, 0, 0, 20)
fa.BorderColor3 = Color3.fromRGB(0, 0, 0)
fa.BackgroundTransparency = 1
fa.Position = UDim2.new(0.5, -30, 0, 235)
fa.BorderSizePixel = 0
fa.BackgroundColor3 = Color3.fromRGB(0, 0, 0)

fa.TextStrokeTransparency = 0.75
fa.TextSize = 18
fa.TextColor3 = Color3.fromRGB(255, 255, 255)
fa.Text = "admins"
fa.Font = 3
fa.TextXAlignment = 1
fa.Parent = A
local ga = Instance.new "TextLabel"
ga.Name = "D"
ga.AutoLocalize = false

ga.ZIndex = 9
ga.Size = UDim2.new(0, 0, 0, 20)
ga.BorderColor3 = Color3.fromRGB(0, 0, 0)
ga.BackgroundTransparency = 1
ga.Position = UDim2.new(0, 10, 0, 0)
ga.BorderSizePixel = 0
ga.BackgroundColor3 = Color3.fromRGB(0, 0, 0)

ga.TextStrokeTransparency = 0.75
ga.TextSize = 18
ga.TextColor3 = Color3.fromRGB(255, 255, 255)
ga.Text = "Admins"
ga.TextWrapped = true
ga.Font = 5
ga.TextXAlignment = 0
ga.Parent = fa
local ha = Instance.new "TextLabel"
ha.Name = "Admins&Bans"
ha.AutoLocalize = false

ha.ZIndex = 9
ha.Size = UDim2.new(1, -10, 0, 20)
ha.BorderColor3 = Color3.fromRGB(0, 0, 0)
ha.BackgroundTransparency = 1
ha.Position = UDim2.new(0, 5, 0, 55)
ha.BorderSizePixel = 0
ha.BackgroundColor3 = Color3.fromRGB(0, 0, 0)

ha.TextStrokeTransparency = 0.75
ha.TextSize = 18
ha.TextColor3 = Color3.fromRGB(255, 255, 255)
ha.Text = "Admins & Bans"
ha.TextWrapped = true
ha.Font = 4
ha.Parent = y
local ia = Instance.new "TextLabel"
ia.Name = "c1"
ia.AutoLocalize = false

ia.ZIndex = 9
ia.Size = UDim2.new(0, 0, 0, 20)
ia.BorderColor3 = Color3.fromRGB(0, 0, 0)
ia.BackgroundTransparency = 1
ia.Position = UDim2.new(0.5, -5, 0, 25)
ia.BorderSizePixel = 0
ia.BackgroundColor3 = Color3.fromRGB(0, 0, 0)

ia.TextStrokeTransparency = 0.75
ia.TextSize = 18
ia.TextColor3 = Color3.fromRGB(255, 255, 255)
ia.Text = "padmin userid/name"
ia.Font = 3
ia.TextXAlignment = 1
ia.Parent = ha
local ja = Instance.new "TextLabel"
ja.Name = "D"
ja.AutoLocalize = false

ja.ZIndex = 9
ja.Size = UDim2.new(0, 0, 0, 20)
ja.BorderColor3 = Color3.fromRGB(0, 0, 0)
ja.BackgroundTransparency = 1
ja.Position = UDim2.new(0, 10, 0, 0)
ja.BorderSizePixel = 0
ja.BackgroundColor3 = Color3.fromRGB(0, 0, 0)

ja.TextStrokeTransparency = 0.75
ja.TextSize = 18
ja.TextColor3 = Color3.fromRGB(255, 255, 255)
ja.Text = "Perm. Admins a player"
ja.TextWrapped = true
ja.Font = 5
ja.TextXAlignment = 0
ja.Parent = ia
local ka = Instance.new "TextLabel"
ka.Name = "c2"
ka.AutoLocalize = false

ka.ZIndex = 9
ka.Size = UDim2.new(0, 0, 0, 20)
ka.BorderColor3 = Color3.fromRGB(0, 0, 0)
ka.BackgroundTransparency = 1
ka.Position = UDim2.new(0.5, -5, 0, 45)
ka.BorderSizePixel = 0
ka.BackgroundColor3 = Color3.fromRGB(0, 0, 0)

ka.TextStrokeTransparency = 0.75
ka.TextSize = 18
ka.TextColor3 = Color3.fromRGB(255, 255, 255)
ka.Text = "pban userid/name"
ka.Font = 3
ka.TextXAlignment = 1
ka.Parent = ha
local la = Instance.new "TextLabel"
la.Name = "D"
la.AutoLocalize = false

la.ZIndex = 9
la.Size = UDim2.new(0, 0, 0, 20)
la.BorderColor3 = Color3.fromRGB(0, 0, 0)
la.BackgroundTransparency = 1
la.Position = UDim2.new(0, 10, 0, 0)
la.BorderSizePixel = 0
la.BackgroundColor3 = Color3.fromRGB(0, 0, 0)

la.TextStrokeTransparency = 0.75
la.TextSize = 18
la.TextColor3 = Color3.fromRGB(255, 255, 255)
la.Text = "Perm. Bans a player"
la.TextWrapped = true
la.Font = 5
la.TextXAlignment = 0
la.Parent = ka
local ma = Instance.new "TextLabel"
ma.Name = "c3"
ma.AutoLocalize = false

ma.ZIndex = 9
ma.Size = UDim2.new(0, 0, 0, 20)
ma.BorderColor3 = Color3.fromRGB(0, 0, 0)
ma.BackgroundTransparency = 1
ma.Position = UDim2.new(0.5, -5, 0, 65)
ma.BorderSizePixel = 0
ma.BackgroundColor3 = Color3.fromRGB(0, 0, 0)

ma.TextStrokeTransparency = 0.75
ma.TextSize = 18
ma.TextColor3 = Color3.fromRGB(255, 255, 255)
ma.Text = "ban id/name"
ma.Font = 3
ma.TextXAlignment = 1
ma.Parent = ha
local na = Instance.new "TextLabel"
na.Name = "D"
na.AutoLocalize = false

na.ZIndex = 9
na.Size = UDim2.new(0, 0, 0, 20)
na.BorderColor3 = Color3.fromRGB(0, 0, 0)
na.BackgroundTransparency = 1
na.Position = UDim2.new(0, 10, 0, 0)
na.BorderSizePixel = 0
na.BackgroundColor3 = Color3.fromRGB(0, 0, 0)

na.TextStrokeTransparency = 0.75
na.TextSize = 18
na.TextColor3 = Color3.fromRGB(255, 255, 255)
na.Text = "Temp. Bans a player"
na.TextWrapped = true
na.Font = 5
na.TextXAlignment = 0
na.Parent = ma

return a
