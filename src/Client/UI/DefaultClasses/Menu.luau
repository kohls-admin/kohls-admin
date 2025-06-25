local BaseClass = require(script.Parent.BaseClass)
local UI = require(script.Parent.Parent)

local Menu = {}
Menu.__index = Menu
setmetatable(Menu, BaseClass)

local LayerTopSize = UI.state(UI.LayerTop, "AbsoluteSize")

function Menu.new(definition)
	local new = UI.makeStatefulDefaults({
		Adornee = false,
		RightAlign = false,
		Visible = false,
	}, definition)

	new._list = UI.new "UIListLayout" {
		SortOrder = Enum.SortOrder.LayoutOrder,
		FillDirection = Enum.FillDirection.Vertical,
		VerticalAlignment = Enum.VerticalAlignment.Top,
	}

	local listContentSize = UI.state(new._list, "AbsoluteContentSize")

	new._content = UI.new "ScrollingFrame" {
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

		new._list,

		[UI.Event] = {
			CanvasPosition = function()
				UI.clearState("hover")
			end,
		},
	}

	new._instance = UI.new "TextButton" {
		Name = "Menu",
		ZIndex = 100,
		Visible = new.Visible,
		Parent = UI.LayerTop,
		AnchorPoint = function()
			return if new.RightAlign() then Vector2.new(1, 0) else Vector2.zero
		end,
		BackgroundColor3 = UI.Theme.Primary,
		ClipsDescendants = true,

		AutoButtonColor = false,
		Text = "",

		new._content,
		UI.new "UICorner" {
			CornerRadius = UI.Theme.CornerRadius,
		},
		UI.new "UIStroke" {
			Enabled = UI.Theme.StrokeEnabled,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Transparency = UI.Theme.TransparencyClamped,
			Color = UI.Theme.Border,
		},
	}

	local positionState = UI.state(Vector2.zero)
	local sizeState = UI.state(Vector2.zero)
	local menuSize = UI.state(new._instance, "AbsoluteSize")

	UI.edit(new._instance, {
		Position = function()
			local size = menuSize()
			local layerSize = LayerTopSize()
			local absolutePos = positionState()
			local absoluteSize = sizeState()
			local rightAlign = new.RightAlign()
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
		end,
	})

	UI.edit(new._instance, {
		[UI.Clean] = {
			UI.UserInputService.InputBegan:Connect(function(input, gameProcessed)
				if
					(
						input.UserInputType == Enum.UserInputType.MouseButton1
						or input.UserInputType == Enum.UserInputType.Touch
						or input.UserInputType == Enum.UserInputType.TextInput
					)
					and new.Visible._value
					and not UI.pointInGuiObject(input.Position.X, input.Position.Y, new.Adornee._value)
					and not UI.pointInGuiObject(input.Position.X, input.Position.Y, new._instance)
				then
					UI.deactivateState(new.Visible, "floating")
				end
			end),
		},
		new._instance:GetPropertyChangedSignal("Visible"):Connect(function()
			local adornee = new.Adornee._value
			if new._instance.Visible and typeof(adornee) == "Instance" then
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
		end),
	})

	return setmetatable(new, Menu)
end

return Menu
