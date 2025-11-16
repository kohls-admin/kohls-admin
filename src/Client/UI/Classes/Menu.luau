local UI = require(script.Parent.Parent) :: any
local BaseClass = require(script.Parent.BaseClass)

local DEFAULT = {
	Adornee = false,
	RightAlign = false,
	Visible = false,
}

type Properties = typeof(DEFAULT) & TextButton

local Class = {}
Class.__index = Class
setmetatable(Class, BaseClass)

local LayerTopSize = UI.state(UI.LayerTop, "AbsoluteSize")

function Class.new(properties: Properties?)
	local self = table.clone(DEFAULT)
	UI.makeStatefulDefaults(self, properties)

	local cleanup = {}

	self._list = UI.new "UIListLayout" {
		SortOrder = Enum.SortOrder.LayoutOrder,
		FillDirection = Enum.FillDirection.Vertical,
		VerticalAlignment = Enum.VerticalAlignment.Top,
	}

	local listContentSize = UI.state(self._list, "AbsoluteContentSize")
	table.insert(cleanup, listContentSize)

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

		[UI.Event] = {
			CanvasPosition = function()
				UI.clearState("hover")
			end,
		},
	} :: ScrollingFrame & { UIListLayout: UIListLayout }

	self._instance = UI.new "TextButton" {
		Name = "Menu",
		ZIndex = 100,
		Visible = self.Visible,
		Parent = UI.LayerTop,
		AnchorPoint = function()
			return if self.RightAlign() then Vector2.new(1, 0) else Vector2.zero
		end,
		BackgroundColor3 = UI.Theme.Primary,
		ClipsDescendants = true,

		AutoButtonColor = false,
		Text = "",

		self._content,
		UI.new "UICorner" {
			CornerRadius = UI.Theme.CornerRadius,
		},
		UI.new "Stroke" {},

		[UI.Clean] = cleanup,
	} :: TextButton & { UIContent: typeof(self._content), UICorner: UICorner, UIStroke: UIStroke }

	local positionState = UI.state(Vector2.zero)
	local sizeState = UI.state(Vector2.zero)
	local menuSize = UI.state(self._instance, "AbsoluteSize")
	table.insert(cleanup, positionState)
	table.insert(cleanup, sizeState)
	table.insert(cleanup, menuSize)

	local menuPosition = UI.compute(function()
		local size = menuSize()
		local layerSize = LayerTopSize()
		local absolutePos = positionState()
		local absoluteSize = sizeState()
		local rightAlign = self.RightAlign()
		local padding = UI.Theme.Padding().Offset
		local height = UI.TopbarInset().Height

		local xPos = absolutePos.X + if rightAlign then absoluteSize.X else 0
		local yPos = absolutePos.Y + absoluteSize.Y + padding + height

		return UDim2.fromOffset(
			if rightAlign
				then math.clamp(xPos, size.X, math.max(size.X, layerSize.X))
				else math.clamp(xPos, 0, math.max(0, layerSize.X - size.X)),
			math.clamp(yPos, 0, math.max(0, layerSize.Y - size.Y))
		)
	end)

	UI.edit(self._instance, {
		Position = menuPosition,
	})

	table.insert(
		cleanup,
		UI.UserInputService.InputBegan:Connect(function(input, gameProcessed)
			if
				(
					input.UserInputType == Enum.UserInputType.MouseButton1
					or input.UserInputType == Enum.UserInputType.Touch
					or input.UserInputType == Enum.UserInputType.TextInput
				)
				and self.Visible._value
				and not UI.pointInGuiObject(input.Position.X, input.Position.Y, self.Adornee._value)
				and not UI.pointInGuiObject(input.Position.X, input.Position.Y, self._instance)
			then
				UI.deactivateState(self.Visible, "floating")
			end
		end)
	)

	table.insert(
		cleanup,
		self._instance:GetPropertyChangedSignal("Visible"):Connect(function()
			local adornee = self.Adornee._value
			if self._instance.Visible and typeof(adornee) == "Instance" and adornee:IsA("GuiObject") then
				positionState(adornee.AbsolutePosition, true)
				sizeState(adornee.AbsoluteSize, true)
				positionState:_bindToProperty(adornee, "AbsolutePosition")
				sizeState:_bindToProperty(adornee, "AbsoluteSize")
			else
				if positionState._bindConnection then
					positionState._bindConnection:Disconnect()
				end
				if sizeState._bindConnection then
					sizeState._bindConnection:Disconnect()
				end
			end
		end)
	)

	return setmetatable(self, Class) :: typeof(self) & typeof(Class)
end

return Class
