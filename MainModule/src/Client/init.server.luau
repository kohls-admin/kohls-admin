-- NOTE: CLIENT ENTRY POINT
-- NOT A SERVER SCRIPT, HAS CLIENT RUNCONTEXT
local _K = require(script.Parent)
local Scroller = require(script.Scroller)

local LocalPlayer = _K.Services.Players.LocalPlayer

--_K.Remote.Test:FireServer("Hey this is a test!")

local Interface = Instance.new("ScreenGui")
Interface.Name = "KInterface"
Interface.DisplayOrder = math.huge
Interface.IgnoreGuiInset = true
Interface.ResetOnSpawn = false
Interface.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

_K.Interface = Interface
_K.hotkeys = {}

require(script.CommandBar):init(_K)

-- implement autocomplete
-- check for start of command and autocomplete it based on _K.Registry.commands
-- TODO: benchmark speed against an array of aliases for fuzzy matching?
-- once a command has been validated start autocompleting the individual arguments

_K.Services.UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
	if gameProcessedEvent then
		return
	end
	if input.UserInputType == Enum.UserInputType.Keyboard then
		for keyName, data in _K.hotkeys do
			if input.KeyCode == data.key or (type(data.key) == "table" and table.find(data.key, input.KeyCode)) then
				task.defer(data.callback)
			end
		end
	end
end)

local testList = {}
for i = 1, 1e5 do
	testList[i] = i .. ": this is a test log, let's see just how terrible we can make this stress test."
end

local testFrame = Instance.new("Frame", Interface)
testFrame.BackgroundTransparency = 0.3
testFrame.BackgroundColor3 = Color3.new()
testFrame.AnchorPoint = Vector2.new(0.5, 0.5)
testFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
testFrame.Size = UDim2.new(0.5, 0, 0.5, 0)
testFrame.SizeConstraint = Enum.SizeConstraint.RelativeYY

local testInput = Instance.new("TextBox", testFrame)
testInput.Text = ""
testInput.Size = UDim2.new(1, 0, 0, 32)
testInput.Font = Enum.Font.RobotoMono
testInput.TextSize = 24

local scrollerTest = Scroller.new(testList)

local function filterTest(list)
	local filter = testInput.Text:lower()
	local new = {}
	for i, v in list do
		if v:lower():find(filter, 1, true) then
			table.insert(new, v)
		end
	end
	return new
end

scrollerTest:filter(filterTest)

testInput:GetPropertyChangedSignal("Text"):Connect(function()
	scrollerTest:refreshList()
end)

scrollerTest:setParent(testFrame)

scrollerTest._frame.Size = UDim2.new(1, 0, 1, -32)
scrollerTest._frame.Position = UDim2.new(0, 0, 0, 32)

Interface.Parent = LocalPlayer:WaitForChild("PlayerGui")

-- NOTE: MATERIAL INTERFACE TEST
if true then
	require(script.InterfaceTest)
end
