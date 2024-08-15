local BaseClass = require(script.Parent.BaseClass)
local UI = require(script.Parent)

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
		Minimizable = true,
		Minimized = false,
		Title = "Window",
		Position = UDim2.fromOffset(
			math.floor(workspace.CurrentCamera.ViewportSize.X / 2) - 256,
			math.floor(workspace.CurrentCamera.ViewportSize.Y / 2) - 256
		),
		Size = UDim2.new(0, 512, 0, 512),
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
				math.clamp(math.round(startOffset.X + delta.X), 0, maxPosition.X),
				math.clamp(math.round(startOffset.Y + delta.Y), 0, maxPosition.Y)
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
				math.round(startSize.X + math.clamp(xSize * delta.X, resizeMin.X, resizeMax.X)),
				math.round(startSize.Y + math.clamp(ySize * delta.Y, resizeMin.Y, resizeMax.Y))
			)
		)
		new.Position:set(
			UDim2.fromOffset(
				math.round(startOffset.X - math.clamp(xPos * -delta.X, resizeMin.X, resizeMax.X)),
				math.round(startOffset.Y - math.clamp(yPos * -delta.Y, resizeMin.Y, resizeMax.Y))
			)
		)
	end

	local function resizeBegan(input, gameProcessed)
		if gameProcessed then
			return
		end
		if
			(input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch)
			and not new.Minimized._value
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

	local exitButton = UI.new "Button" {
		BackgroundColor3 = Color3.fromRGB(200, 0, 0),
		Size = UDim2.new(0, 32, 0, 32),
		Icon = "rbxassetid://1476571006",
		IconProperties = {
			Size = UDim2.new(0, 10, 0, 10),
		},
		Text = "",
		Activated = function()
			new._instance.Visible = false
		end,
	}
	exitButton._instance:FindFirstChildOfClass("UIStroke"):Destroy()

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
		Size = new.Size,
		Position = new.Position,

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
			BackgroundTransparency = 1,
			Image = "rbxassetid://2286551482",
			ImageRectSize = Vector2.new(15, 15),
			ImageRectOffset = resizeIconRectOffset,
			Size = UDim2.new(0, 15, 0, 15),
			Visible = resizeHover,
			ResampleMode = Enum.ResamplerMode.Pixelated,
			Position = UI.compute(function(use)
				local inputPos = use(inputPosition)
				return UDim2.fromOffset(inputPos.X - 8, inputPos.Y - 8 + use(UI.TopbarInset).Height) - use(new.Position)
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

			UI.new "Frame" {
				Name = "TitleBar",
				Active = true,
				LayoutOrder = -9e9,
				BackgroundTransparency = 1,
				ClipsDescendants = true,
				AutomaticSize = Enum.AutomaticSize.Y,
				Size = UDim2.new(1, 0, 0, 0),

				UI.new "UIListLayout" {
					FillDirection = Enum.FillDirection.Horizontal,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UI.Theme.Padding,
				},

				UI.new "TextLabel" {
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

				exitButton,

				[UI.Event] = {
					InputBegan = dragInputBegan,
				},
			},

			new._content,
		},
	}

	UI.UserInputService.InputBegan:Connect(resizeBegan)
	UI.UserInputService.InputChanged:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch
		then
			if resizing._value then
				-- update resize
				resizeUpdate(input)
			elseif dragging._value then
				dragUpdate(input)
			elseif not new.Minimized._value then
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
					UI.UserInputService.MouseIconEnabled = false
				else
					resizeHover:set(false)
					UI.UserInputService.MouseIconEnabled = true
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
			parentConn = parent:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
				local maxPosition = new._instance.Parent.AbsoluteSize - new._instance.AbsoluteSize
				local position = new._instance.Position
				new.Position:set(
					UDim2.fromOffset(
						math.clamp(position.X.Offset, 0, math.max(0, maxPosition.X)),
						math.clamp(position.Y.Offset, 0, math.max(0, maxPosition.Y))
					)
				)
			end)
		end
	end)

	return setmetatable(new, Window)
end

return Window
