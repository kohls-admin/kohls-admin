-- NOTE: CLIENT ENTRY POINT
-- NOT A SERVER SCRIPT, HAS CLIENT RUNCONTEXT
local _K = require(script.Parent)

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

Interface.Parent = LocalPlayer:WaitForChild("PlayerGui")

-- NOTE: MATERIAL INTERFACE TEST
if true then
	require(script.InterfaceTest)
end
