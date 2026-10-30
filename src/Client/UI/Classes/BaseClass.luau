local UI = require(script.Parent.Parent)

local BaseClass = {}
BaseClass.__index = BaseClass

function BaseClass:Destroy()
	for key, value in self do
		if typeof(value) == "Instance" or (key ~= "__index" and string.byte(key) == 95 and UI.isNode(value)) then
			value:Destroy()
		end
	end
	if self._createdNodes then
		for _, node in self._createdNodes do
			node:Destroy()
		end
		table.clear(self._createdNodes)
	end
end

function BaseClass:ToggleValue()
	local value = not UI.raw(self.Value)
	self.Value(value)
	if value then
		UI.Sound.Hover03:Play()
	else
		UI.Sound.Hover01:Play()
	end
end

function BaseClass.bindDragInput(dragging: any, onDrag: (InputObject) -> (), cleanup: { any }): (InputObject) -> ()
	local dragInput: InputObject?
	local function onInputChanged(input: InputObject)
		if not dragInput then
			return
		end
		onDrag(input)
	end
	table.insert(cleanup, UI.UserInputService.InputChanged:Connect(onInputChanged))
	return function(input: InputObject)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			UI.Sound.Hover03:Play()
			dragInput = input
			dragging(true)
			local con
			con = input:GetPropertyChangedSignal("UserInputState"):Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					con:Disconnect()
					if dragInput == input then
						UI.Sound.Hover01:Play()
						dragInput = nil
						dragging(false)
					end
				end
			end)
			onDrag(input)
		end
	end
end

return BaseClass
