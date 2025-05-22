local BaseClass = require(script.Parent.BaseClass)
local UI = require(script.Parent.Parent)

local Window = {}
Window.__index = Window
setmetatable(Window, BaseClass)

local resizeReference = {
	{ -1, 1, 0, 0, 30 }, -- left
	{ 1, 0, 0, 0, 30 }, -- right
	{ 0, 0, -1, 1, 0 }, -- top
	{ 0, 0, 1, 0, 0 }, -- bottom
	{ -1, 1, -1, 1, 45 }, -- top left
	{ 1, 0, -1, 1, 15 }, -- top right
	{ 1, 0, 1, 0, 45 }, -- bottom right
	{ -1, 1, 1, 0, 15 }, -- bottom left
}

-- TODO: account for anchorpoint...
local function getResizeIndex(point, size, position, buffer: number): number?
	local max = position + size
	-- not inside box buffer
	if
		point.X < position.X - buffer
		or point.X > max.X + buffer
		or point.Y < position.Y - buffer
		or point.Y > max.Y + buffer
	then
		return
	end

	local edges = {
		math.abs(point.X - position.X), -- left
		math.abs(point.X - max.X), -- right
		math.abs(point.Y - position.Y), -- top
		math.abs(point.Y - max.Y), -- bottom
	}
	-- PERF: can't be close to corner if not close to edge
	if math.min(unpack(edges)) > buffer then
		return
	end

	local corners = {
		point - position, -- top left
		point - Vector2.new(max.X, position.Y), -- top right
		point - max, -- bottom right
		point - Vector2.new(position.X, max.Y), -- bottom left
	}

	for i, corner in corners do
		if math.abs(corner.X) <= buffer and math.abs(corner.Y) <= buffer then
			return resizeReference[i + 4] -- THE CURRENT CORNER
		end
	end

	for i, distance in edges do
		if distance <= buffer then
			return resizeReference[i]
		end
	end

	return
end

local windowCache = {}

function Window.new(definition)
	local new = UI.makeStatefulDefaults({
		Exitable = true,
		Draggable = true,
		Resizable = true,
		RemoveOnClose = false,
		Close = UI.Nil,
		Title = "Window",
		Position = UDim2.new(0.5, -210, 0.5, -210),
		Size = UDim2.new(0, 420, 0, 420),
		SizeBounds = Rect.new(128, 128, 9e9, 9e9),
	}, definition)

	windowCache[new] = true

	local dragInput, dragStart, startOffset
	local inputPosition = UI.state(Vector2.new())
	local dragging = UI.state(false)
	local resizing = UI.state(false)
	local resizeHover = UI.state(false)
	local resizeIconRectOffset = UI.state(Vector2.new())

	local function dragUpdate(input)
		if not dragInput or resizing._value then
			return
		end

		local delta = input.Position - dragStart
		local maxPosition = new._instance.Parent.AbsoluteSize - new._instance.AbsoluteSize

		new.Position:set(
			UDim2.fromOffset(
				math.clamp(math.round(startOffset.X + delta.X), 0, math.max(0, maxPosition.X)),
				math.clamp(math.round(startOffset.Y + delta.Y), 0, math.max(0, maxPosition.Y))
			)
		)
	end

	local function dragInputBegan(input, gameProcessed)
		if gameProcessed then
			return
		end
		if
			(input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch)
			and not resizing._value
			and not resizeHover._value
		then
			for window in windowCache do
				window._instance.ZIndex = 1
			end
			new._instance.ZIndex = 2

			startOffset = new._instance.AbsolutePosition - new._instance.Parent.AbsolutePosition
			dragInput, dragStart = input, input.Position
			dragging:set(true)
			local con
			con = input:GetPropertyChangedSignal("UserInputState"):Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					con:Disconnect()
					if dragInput == input then
						dragInput = nil
						dragging:set(false)
					end
				end
			end)
		end
	end

	local resizeBuffer = 4
	local startSize, xSize, xPos, ySize, yPos
	local function resizeUpdate(input)
		local delta = input.Position - dragStart
		local resizeMin = new.SizeBounds._value.Min - startSize
		local resizeMax = new.SizeBounds._value.Max - startSize
		inputPosition:set(input.Position)
		new.Size:set(
			UDim2.fromOffset(
				math.round(startSize.X + math.clamp(xSize * delta.X, resizeMin.X, math.max(resizeMin.X, resizeMax.X))),
				math.round(startSize.Y + math.clamp(ySize * delta.Y, resizeMin.Y, math.max(resizeMin.Y, resizeMax.Y)))
			)
		)
		new.Position:set(
			UDim2.fromOffset(
				math.round(startOffset.X - math.clamp(xPos * -delta.X, resizeMin.X, math.max(resizeMin.X, resizeMax.X))),
				math.round(startOffset.Y - math.clamp(yPos * -delta.Y, resizeMin.Y, math.max(resizeMin.Y, resizeMax.Y)))
			)
		)
	end

	local function resizeBegan(input, gameProcessed)
		if gameProcessed then
			return
		end
		if
			(input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch)
			and new._instance.Visible
		then
			local resize = getResizeIndex(
				Vector2.new(input.Position.X, input.Position.Y),
				new._instance.AbsoluteSize,
				new._instance.AbsolutePosition,
				resizeBuffer
			)
			if resize then
				xSize, xPos, ySize, yPos = unpack(resize, 1, 4)
				dragInput, dragStart = input, input.Position
				startOffset = new._instance.AbsolutePosition - new._instance.Parent.AbsolutePosition
				startSize = new._instance.AbsoluteSize
				resizing:set(true)
				local con
				con = input:GetPropertyChangedSignal("UserInputState"):Connect(function()
					if input.UserInputState == Enum.UserInputState.End then
						con:Disconnect()
						if dragInput == input then
							dragInput = nil
							resizing:set(false)
						end
					end
				end)
			end
		end
	end

	new._exitButton = UI.new "Button" {
		LayoutOrder = 9,
		BackgroundColor3 = Color3.fromRGB(200, 0, 0),
		Size = UI.compute(function(use)
			local size = use(UI.Theme.FontSize) + use(UI.Theme.PaddingDouble).Offset
			return UDim2.new(0, size, 0, size)
		end),
		Icon = UI.Theme.Image.Close,
		IconProperties = {
			Size = UDim2.new(0, 10, 0, 10),
		},
		Text = "",
		Activated = function()
			new._instance.Visible = false
			UI.clearState("hover")
			UI.clearState("floating")

			if new.Close and type(new.Close._value) == "function" then
				new.Close._value(new)
			elseif new.RemoveOnClose._value then
				new:Destroy()
			end
		end,
	}
	new._exitButton._instance:FindFirstChildOfClass("UIStroke"):Destroy()

	new._content = UI.new "Frame" {
		Name = "UIContent",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0),
		ClipsDescendants = true,

		UI.new "UIFlexItem" {
			FlexMode = Enum.UIFlexMode.Fill,
		},
	}

	new._instance = UI.new "Frame" {
		Name = "Window",
		BackgroundColor3 = UI.Theme.Primary,
		BackgroundTransparency = UI.Theme.Transparency,
		Position = new.Position,
		Size = new.Size,
		ZIndex = 2,

		UI.new "UICorner" {
			CornerRadius = UI.Theme.CornerRadius,
		},
		UI.new "UIStroke" {
			Enabled = UI.Theme.StrokeEnabled,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Transparency = UI.Theme.TransparencyClamped,
			Color = UI.Theme.Border,
		},
		UI.new "UIPadding" {
			PaddingLeft = UI.Theme.Padding,
			PaddingRight = UI.Theme.Padding,
			PaddingTop = UI.Theme.Padding,
			PaddingBottom = UI.Theme.Padding,
		},

		UI.new "ImageLabel" {
			Name = "ResizeIcon",
			ZIndex = 1e3,
			AnchorPoint = Vector2.new(1, 1),
			BackgroundTransparency = 1,
			Image = "rbxassetid://2286551482",
			ImageRectSize = Vector2.new(15, 15),
			ImageRectOffset = resizeIconRectOffset,
			Size = UDim2.new(0, 15, 0, 15),
			Visible = resizeHover,
			ResampleMode = Enum.ResamplerMode.Pixelated,
			Position = UI.compute(function(use)
				local inputPos = use(inputPosition)
				return UDim2.fromOffset(inputPos.X, inputPos.Y) - use(new.Position)
			end),

			[UI.Event] = {
				InputBegan = resizeBegan,
			},
		},

		UI.new "Frame" {
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			Size = UDim2.fromScale(1, 1),

			UI.new "UIListLayout" {
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UI.Theme.Padding,
			},

			UI.new "TextButton" {
				Name = "TitleBar",
				Active = true,
				Modal = true,
				LayoutOrder = -9e9,
				BackgroundTransparency = 1,
				ClipsDescendants = true,
				AutomaticSize = Enum.AutomaticSize.Y,
				Size = UDim2.new(1, 0, 0, 0),
				TextTransparency = 1,

				UI.new "UIListLayout" {
					FillDirection = Enum.FillDirection.Horizontal,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UI.Theme.Padding,
				},

				UI.new "TextLabel" {
					AutoLocalize = false,
					Name = "Title",
					BackgroundTransparency = 1,
					AutomaticSize = Enum.AutomaticSize.Y,
					Size = UDim2.new(1, 0, 0, 32),
					Font = UI.Theme.Font,
					Text = new.Title,
					TextColor3 = UI.Theme.PrimaryText,
					TextSize = UI.Theme.FontSizeLarger,
					TextStrokeTransparency = 0.9,
					TextXAlignment = "Left",
					TextTruncate = Enum.TextTruncate.SplitWord,

					UI.new "UIFlexItem" {
						FlexMode = Enum.UIFlexMode.Fill,
					},
					UI.new "UIPadding" {
						PaddingLeft = UI.Theme.Padding,
					},
				},

				new._exitButton,

				[UI.Event] = {
					InputBegan = dragInputBegan,
				},
			},

			new._content,
		},
	}

	local mouseIconWasEnabled, mouseIconChanging = UI.UserInputService.MouseIconEnabled, nil
	UI.UserInputService:GetPropertyChangedSignal("MouseIconEnabled"):Connect(function()
		if mouseIconChanging then
			return
		end
		mouseIconWasEnabled = UI.UserInputService.MouseIconEnabled
	end)

	UI.UserInputService.InputBegan:Connect(resizeBegan)
	UI.UserInputService.InputChanged:Connect(function(input)
		if not new._instance.Visible then
			return
		end

		if
			input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch
		then
			if resizing._value then
				-- update resize
				resizeUpdate(input)
			elseif dragging._value then
				dragUpdate(input)
			else
				local resize = getResizeIndex(
					Vector2.new(input.Position.X, input.Position.Y),
					new._instance.AbsoluteSize,
					new._instance.AbsolutePosition,
					resizeBuffer
				)
				if resize then
					inputPosition:set(input.Position)
					resizeHover:set(true)
					resizeIconRectOffset:set(Vector2.new(resize[5]))
					if UI.UserInputService.MouseIconEnabled then
						mouseIconChanging = true
						UI.UserInputService.MouseIconEnabled = false
						mouseIconChanging = false
					end
				elseif resizeHover._value then
					resizeHover:set(false)
					if UI.UserInputService.MouseIconEnabled ~= mouseIconWasEnabled then
						mouseIconChanging = true
						UI.UserInputService.MouseIconEnabled = mouseIconWasEnabled
						mouseIconChanging = false
					end
				end
			end
		end
	end)

	local parentConn
	new._instance:GetPropertyChangedSignal("Parent"):Connect(function()
		if parentConn then
			parentConn:Disconnect()
		end
		local parent = new._instance.Parent
		if parent and parent:IsA("GuiBase2d") then
			local function updateSize()
				local parentSize = new._instance.Parent.AbsoluteSize
				local windowSize = new._instance.AbsoluteSize
				local maxPosition = parentSize - windowSize
				local position = new._instance.AbsolutePosition

				local padding = new._instance.Parent:FindFirstChildOfClass("UIPadding")
				local paddingX = if padding
					then padding.PaddingLeft.Offset
						+ parentSize.X * padding.PaddingLeft.Scale
						+ padding.PaddingRight.Offset
						+ parentSize.X * padding.PaddingRight.Scale
					else 0
				local paddingY = if padding
					then padding.PaddingTop.Offset
						+ parentSize.Y * padding.PaddingTop.Scale
						+ padding.PaddingBottom.Offset
						+ parentSize.Y * padding.PaddingBottom.Scale
					else 0

				new.Size:set(
					UDim2.fromOffset(
						math.clamp(windowSize.X, 0, math.max(0, parentSize.X - paddingX)),
						math.clamp(windowSize.Y, 0, math.max(0, parentSize.Y - paddingY))
					)
				)
				new.Position:set(
					UDim2.fromOffset(
						math.clamp(position.X, 0, math.max(0, maxPosition.X)),
						math.clamp(position.Y, 0, math.max(0, maxPosition.Y))
					)
				)
			end
			parentConn = parent:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateSize)
			updateSize()
		end
	end)

	return setmetatable(new, Window)
end

return Window
