local UI = require(script.Parent.Parent)
local BaseClass = require(script.Parent:WaitForChild("BaseClass"))

local DEFAULT = {
	Adornee = false,
	RightAlign = false,
	Visible = false,
}

type Properties = typeof(DEFAULT) & TextButton

local Class = {}
Class.__index = Class
setmetatable(Class, BaseClass)

local LayerTopSize = UI.property(UI.LayerTop, "AbsoluteSize")

function Class.new(properties: Properties?)
	local self = table.clone(DEFAULT)
	UI.makeStatefulDefaults(self, properties)

	local cleanup = {}

	self._list = UI.list {
		direction = "y",
		verticalAlign = "start",
	}

	local listContentSize = UI.property(self._list, "AbsoluteContentSize")
	table.insert(cleanup, listContentSize)
	local function onCanvasPosition()
		UI.clearState("hover")
	end

	self._content = UI.new "ScrollingFrame" {
		Name = "Menu",
		ZIndex = 100,
		BackgroundTransparency = 1,
		ClipsDescendants = false,
		Size = UDim2.new(1, 0, 1, 0),
		CanvasSize = function()
			return UDim2.new(0, 0, 0, listContentSize().Y)
		end,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 0,

		self._list,

		_CanvasPosition = onCanvasPosition,
	} :: ScrollingFrame & { UIListLayout: UIListLayout }

	self._instance = UI.new "TextButton" {
		Name = "Menu",
		ZIndex = 100,
		Visible = self.Visible,
		Parent = UI.LayerTop,
		AnchorPoint = UI.pick(self.RightAlign, Vector2.new(1, 0), Vector2.zero),
		BackgroundColor3 = UI.Theme.Primary,
		ClipsDescendants = true,

		AutoButtonColor = false,
		Text = "",

		self._content,
		UI.corner(UI.Theme.CornerRadius),
		UI.new "Gradient" {},
		UI.new "Stroke" {},

		__CLEAN = cleanup,
	} :: TextButton & { UIContent: typeof(self._content), UICorner: UICorner, UIStroke: UIStroke }

	local positionState = UI.signal(Vector2.zero)
	local sizeState = UI.signal(Vector2.zero)
	local menuSize = UI.property(self._instance, "AbsoluteSize")
	local positionConn, sizeConn
	table.insert(cleanup, positionState)
	table.insert(cleanup, sizeState)
	table.insert(cleanup, menuSize)
	table.insert(cleanup, function()
		if positionConn then
			positionConn:Disconnect()
		end
		if sizeConn then
			sizeConn:Disconnect()
		end
	end)

	local menuPosition = UI.computed(function()
		local size = menuSize()
		local layerSize = LayerTopSize()
		local absolutePos = positionState()
		local absoluteSize = sizeState()
		local rightAlign = self.RightAlign()
		local padding = UI.Theme.Padding().Offset
		local height = UI.TopbarInset().Height

		local xPos = absolutePos.X + (rightAlign and absoluteSize.X or 0)
		local yPos = absolutePos.Y + absoluteSize.Y + padding + height
		local xClamped = rightAlign and math.clamp(xPos, size.X, math.max(size.X, layerSize.X))
			or math.clamp(xPos, 0, math.max(0, layerSize.X - size.X))

		return UDim2.fromOffset(xClamped, math.clamp(yPos, 0, math.max(0, layerSize.Y - size.Y)))
	end)
	table.insert(cleanup, menuPosition)

	local function disconnectAdornee()
		if positionConn then
			positionConn:Disconnect()
			positionConn = nil
		end
		if sizeConn then
			sizeConn:Disconnect()
			sizeConn = nil
		end
	end
	table.insert(cleanup, disconnectAdornee)

	UI.edit(self._instance)({
		Position = menuPosition,
		_Visible = function()
			disconnectAdornee()
			local adornee = self.Adornee:peek()
			if self._instance.Visible and typeof(adornee) == "Instance" and adornee:IsA("GuiObject") then
				positionState(adornee.AbsolutePosition, true)
				sizeState(adornee.AbsoluteSize, true)
				UI.flush()
				positionConn = adornee:GetPropertyChangedSignal("AbsolutePosition"):Connect(function()
					positionState(adornee.AbsolutePosition)
				end)
				sizeConn = adornee:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
					sizeState(adornee.AbsoluteSize)
				end)
			end
		end,
	})

	local inputConn = UI.UserInputService.InputBegan:Connect(function(input, gameProcessed)
		local adornee = self.Adornee:peek()
		if
			(
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
				or input.UserInputType == Enum.UserInputType.TextInput
			)
			and self.Visible:peek()
			and not (typeof(adornee) == "Instance" and adornee:IsA("GuiObject") and UI.Interact.pointIn(
				input.Position.X,
				input.Position.Y,
				adornee
			))
			and not UI.Interact.pointIn(input.Position.X, input.Position.Y, self._instance)
		then
			UI.deactivateState(self.Visible, "floating")
		end
	end)
	table.insert(cleanup, inputConn)

	return setmetatable(self, Class) :: typeof(self) & typeof(Class)
end

return Class
