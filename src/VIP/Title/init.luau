local Title = {
	definition = {
		vip = {
			color = Color3.fromHex("#fc0"),
			gamepass = 5411126,
		},
		patron = {
			color = Color3.fromHex("#0ff"),
			gamepass = 938480383,
		},
		benefactor = {
			color = Color3.fromHex("#0bf"),
			gamepass = 939618404,
		},
		luminary = {
			color = Color3.fromHex("#80f"),
			gamepass = 936146448,
		},
		epic = {
			color = Color3.fromHex("#f0f"),
			gamepass = 941076536,
		},
		hero = {
			color = Color3.fromHex("#f08"),
			gamepass = 941162509,
		},
		legend = {
			color = Color3.fromHex("#f00"),
			gamepass = 941006661,
		},
		mythic = {
			color = Color3.fromHex("#fff"),
			topColor = Color3.fromHex("#000"),
			gamepass = 983235767,
		},
	},
}

local gui = Instance.new("BillboardGui")
gui.Name = "_K_Title"
gui.Size = UDim2.new(4, 0, 1, 0)
gui.StudsOffset = Vector3.new(0, 3, 1)
gui.ResetOnSpawn = false
gui.LightInfluence = 0

local title = Instance.new("TextLabel")
title.Name = "Title"
title.BackgroundTransparency = 1
title.Size = UDim2.fromScale(1, 1)
title.Font = Enum.Font.FredokaOne
title.Text = "LEGEND"
title.TextScaled = true
title.TextColor3 = Color3.new(1, 1, 1)
title.Parent = gui

local stroke = Instance.new("UIStroke")
stroke.Thickness = 1
stroke.Parent = title

local gradient = Instance.new("UIGradient")
gradient.Rotation = 90
gradient.Parent = title

function Title.Method(character: Model, title: string?, color: Color3?, topColor: Color3?, font: Enum.Font?)
	local titleGui = character:FindFirstChild("_K_Title")
	if title == nil then
		if titleGui then
			titleGui:Destroy()
		end
		return
	end

	local titleDefinition = Title.definition[string.lower(title)]
	if titleDefinition then
		color = color or titleDefinition.color
		topColor = topColor or titleDefinition.topColor
	end

	if not titleGui then
		titleGui = gui:Clone()
		titleGui.Parent = character
		titleGui.Adornee = character:FindFirstChild("Head")
	end

	titleGui.Title.Text = title
	titleGui.Title.UIGradient.Color = ColorSequence.new(topColor or Color3.new(1, 1, 1), color or Color3.new(1, 1, 1))
	if font then
		titleGui.Title.Font = font
	end
end

return Title
