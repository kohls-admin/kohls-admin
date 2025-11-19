local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local Flux = require(script.Parent.Parent.Flux)

local Oklab = Flux.Color.Oklab

local function sortKeypoints(a, b)
	return a.Time < b.Time
end

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
		elite = {
			color = Color3.fromHex("#0bf"),
			gamepass = 939618404,
		},
		epic = {
			gamepass = 936146448,
			rotation = 0,
			getValue = function(elapsed: number)
				elapsed /= 2
				local keypoints = {}
				for i = 0, 2 do
					local step = i / 2
					local oscillate = math.abs(((elapsed + step) % 2) - 1) * 1 / 7
					local color = Oklab.toRGB(Oklab.fromHCL(Vector3.new(3 / 7 + oscillate, 0.4, 1)))
					table.insert(keypoints, ColorSequenceKeypoint.new(step, color))
				end
				return ColorSequence.new(keypoints)
			end,
			update = function(object, value)
				object.Title.UIGradient.Color = value
			end,
		},
		hero = {
			gamepass = 941076536,
			getValue = function(elapsed: number)
				elapsed /= 2
				local keypoints = {}
				for i = 0, 2 do
					local step = i / 2
					local oscillate = math.abs(((elapsed + step) % 2) - 1) * 1 / 7
					local color = Oklab.toRGB(Oklab.fromHCL(Vector3.new(5 / 7 + oscillate, 0.4, 1)))
					table.insert(keypoints, ColorSequenceKeypoint.new(step, color))
				end
				return ColorSequence.new(keypoints)
			end,
			update = function(object, value)
				object.Title.UIGradient.Color = value
			end,
		},
		legend = {
			gamepass = 941162509,
			getValue = function(elapsed: number)
				elapsed /= 2
				local keypoints = {}
				for i = 0, 2 do
					local step = i / 2
					local oscillate = math.abs(((elapsed + step) % 2) - 1) * 1 / 7
					local color = Oklab.toRGB(Oklab.fromHCL(Vector3.new(oscillate, 0.4, 1)))
					table.insert(keypoints, ColorSequenceKeypoint.new(step, color))
				end
				return ColorSequence.new(keypoints)
			end,
			update = function(object, value)
				object.Title.UIGradient.Color = value
			end,
		},
		mythic = {
			gamepass = 941006661,
			getValue = function(elapsed: number)
				return ColorSequence.new(Oklab.toRGB(Oklab.fromHCL(Vector3.new((time() / 10) % 1, 0.4, 1))))
			end,
			update = function(object, value)
				object.Title.UIGradient.Color = value
			end,
		},
		eternal = {
			gamepass = 983235767,
			rotation = 0,
			getValue = function(elapsed: number)
				elapsed /= 4
				local steps = 6
				local keypoints = {}
				local offset = elapsed % 1

				local colorAtStart = Oklab.toRGB(Oklab.fromHCL(Vector3.new(-offset, 0.4, 1)))
				table.insert(keypoints, ColorSequenceKeypoint.new(0, colorAtStart))

				local colorAtEnd = Oklab.toRGB(Oklab.fromHCL(Vector3.new((1 - offset), 0.4, 1)))
				table.insert(keypoints, ColorSequenceKeypoint.new(1, colorAtEnd))

				for i = 0, steps do
					local step = i / steps
					local color = Oklab.toRGB(Oklab.fromHCL(Vector3.new(step, 0.4, 1)))
					local timeOffset = 1 - ((step + elapsed) % 1)
					table.insert(keypoints, ColorSequenceKeypoint.new(timeOffset, color))
				end
				table.sort(keypoints, sortKeypoints)
				return ColorSequence.new(keypoints)
			end,
			update = function(object, value)
				object.Title.UIGradient.Color = value
			end,
		},
	},
}

for _, definition in Title.definition do
	definition.ownerCache = {}
end

shared._KVIPTitle = Title

local gui = Instance.new("BillboardGui")
gui.Name = "_K_Title"
gui.MaxDistance = 256
gui.Size = UDim2.new(4, 0, 1, 0)
gui.StudsOffset = Vector3.new(0, 3, 0)
gui.ResetOnSpawn = false
gui.LightInfluence = 0

local title = Instance.new("TextLabel")
title.AutoLocalize = false
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
gradient.Parent = title

function Title.Method(character: Model, title: string?, color: Color3?, topColor: Color3?, font: Enum.Font?)
	local titleGui = character:FindFirstChild("_K_Title")
	if titleGui then
		titleGui:Destroy()
	end
	if title == nil then
		return
	end

	local titleRef = string.lower(title)
	local titleDefinition = Title.definition[titleRef]
	if titleDefinition then
		color = color or titleDefinition.color
		topColor = topColor or titleDefinition.topColor
	end

	titleGui = gui:Clone()
	titleGui.Parent = character
	titleGui.Adornee = character:FindFirstChild("Head")
	titleGui:AddTag("_K" .. titleRef)

	titleGui.Title.Text = title
	titleGui.Title.UIGradient.Color = ColorSequence.new(topColor or Color3.new(1, 1, 1), color or Color3.new(1, 1, 1))
	titleGui.Title.UIGradient.Rotation = titleDefinition and titleDefinition.rotation or 90
	if font then
		titleGui.Title.Font = font
	end
end

if RunService:IsClient() then
	local titleCache = {}
	for titleRef, definition in Title.definition do
		if not definition.update then
			continue
		end
		local tag = "_K" .. titleRef
		local cache = { getValue = definition.getValue, update = definition.update, objects = {} }
		titleCache[tag] = cache
		CollectionService:GetInstanceAddedSignal(tag):Connect(function(obj)
			cache.objects[obj] = true
		end)
		CollectionService:GetInstanceRemovedSignal(tag):Connect(function(obj)
			cache.objects[obj] = nil
		end)
	end

	local start = os.clock()
	RunService.Heartbeat:Connect(function()
		local elapsed = os.clock() - start
		for tag, cache in titleCache do
			if not next(cache.objects) then
				continue
			end
			local value = cache.getValue(elapsed)
			for object in cache.objects do
				if object.AbsoluteSize.Y <= 2 then
					continue
				end
				cache.update(object, value)
			end
		end
	end)
end

return Title
