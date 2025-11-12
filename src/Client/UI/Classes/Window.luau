local UI = require(script.Parent.Parent) :: any
local BaseClass = require(script.Parent.BaseClass)

local Class = {}
Class.__index = Class
setmetatable(Class, BaseClass)

local resizeReference = {
	{ -1, 1, 0, 0, 48 }, -- left
	{ 1, 0, 0, 0, 48 }, -- right
	{ 0, 0, -1, 1, 0 }, -- top
	{ 0, 0, 1, 0, 0 }, -- bottom
	{ -1, 1, -1, 1, 72 }, -- top left
	{ 1, 0, -1, 1, 24 }, -- top right
	{ 1, 0, 1, 0, 72 }, -- bottom right
	{ -1, 1, 1, 0, 24 }, -- bottom left
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

local function sortZIndex(a, b)
	return a.ZIndex < b.ZIndex
end

function Class.bringToFront(self)
	local windows = {}
	for window in windowCache do
		table.insert(windows, window._instance)
	end
	table.sort(windows, sortZIndex)
	table.insert(windows, self._instance)
	for index, window in windows do
		window.ZIndex = index
	end
end

function Class.nudge(self)
	local nudgeAmount = 32
	local maxAttempts = 16
	local position = self._instance.AbsolutePosition
	local size = self._instance.AbsoluteSize
	local parentSize = self._instance.Parent.AbsoluteSize

	for i = 1, maxAttempts do
		local nudged
		for window in windowCache do
			if not window._instance.Visible or window == self then
				continue
			end
			if (position - window._instance.AbsolutePosition).Magnitude < 16 then
				local newX = math.clamp(position.X + nudgeAmount, 0, math.max(0, parentSize.X - size.X))
				local newY = math.clamp(position.Y + nudgeAmount, 0, math.max(0, parentSize.Y - size.Y))

				position += Vector2.new(nudgeAmount, nudgeAmount)
				self.Position(UDim2.fromOffset(newX, newY))
				nudged = true
				break
			end
		end
		if not nudged then
			break
		end
	end
end

local DEFAULT = {
	Exitable = true,
	Draggable = true,
	Resizable = true,
	RemoveOnClose = false,
	Close = UI.Function,
	Icon = "",
	IconProperties = {},
	Title = "Window",
	Position = UDim2.new(0.5, -210, 0.5, -210),
	Size = UDim2.new(0, 420, 0, 420),
	SizeBounds = Rect.new(128, 128, 9e9, 9e9),
}

type Properties = typeof(DEFAULT) & Frame

function Class.new(properties: Properties?)
	local self = table.clone(DEFAULT)
	self.IconProperties = {}
	UI.makeStatefulDefaults(self, properties)

	windowCache[self] = true

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
		local maxPosition = self._instance.Parent.AbsoluteSize - self._instance.AbsoluteSize

		self.Position(
			UDim2.fromOffset(
				math.clamp(math.round(startOffset.X + delta.X), 0, math.max(0, maxPosition.X)),
				math.clamp(math.round(startOffset.Y + delta.Y), 0, math.max(0, maxPosition.Y))
			),
			true
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
			Class.bringToFront(self)

			startOffset = self._instance.AbsolutePosition - self._instance.Parent.AbsolutePosition
			dragInput, dragStart = input, input.Position
			dragging(true)
			local con
			con = input:GetPropertyChangedSignal("UserInputState"):Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					con:Disconnect()
					if dragInput == input then
						dragInput = nil
						dragging(false)
					end
				end
			end)
		end
	end

	local resizeBuffer = 5
	local startSize, xSize, xPos, ySize, yPos
	local function resizeUpdate(input)
		local parentSize = self._instance.Parent.AbsoluteSize
		local delta = Vector3.new(
			math.clamp(input.Position.X, 0, parentSize.X),
			math.clamp(input.Position.Y, 0, parentSize.Y),
			0
		) - dragStart
		local resizeMin = self.SizeBounds._value.Min - startSize
		local resizeMax = self.SizeBounds._value.Max - startSize
		inputPosition(input.Position)
		self.Size(
			UDim2.fromOffset(
				math.round(startSize.X + math.clamp(xSize * delta.X, resizeMin.X, math.max(resizeMin.X, resizeMax.X))),
				math.round(startSize.Y + math.clamp(ySize * delta.Y, resizeMin.Y, math.max(resizeMin.Y, resizeMax.Y)))
			)
		)

		self.Position(
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
			and self._instance.Visible
		then
			local resize = getResizeIndex(
				Vector2.new(input.Position.X, input.Position.Y),
				self._instance.AbsoluteSize,
				self._instance.AbsolutePosition,
				resizeBuffer
			)
			if resize then
				xSize, xPos, ySize, yPos = unpack(resize, 1, 4)
				dragInput, dragStart = input, input.Position
				startOffset = self._instance.AbsolutePosition - self._instance.Parent.AbsolutePosition
				startSize = self._instance.AbsoluteSize
				resizing(true)
				local con
				con = input:GetPropertyChangedSignal("UserInputState"):Connect(function()
					if input.UserInputState == Enum.UserInputState.End then
						con:Disconnect()
						if dragInput == input then
							dragInput = nil
							resizing(false)
						end
					end
				end)
			end
		end
	end

	local titleBarHeight = UI.compute(function()
		return UI.Theme.FontSize() + UI.Theme.Padding().Offset * 2
	end)
	local buttonSize = function()
		return UDim2.fromOffset(titleBarHeight(), titleBarHeight())
	end
	local iconSize = function()
		return UDim2.fromOffset(UI.Theme.FontSize(), UI.Theme.FontSize())
	end

	self._exitButton = UI.new "Button" {
		LayoutOrder = 9,
		BackgroundColor3 = Color3.fromRGB(200, 0, 0),
		BackgroundTransparency = 1,
		HoverTransparency = 0,
		Size = buttonSize,
		Icon = UI.Theme.Image.Close,
		IconProperties = {
			ImageColor3 = UI.Theme.PrimaryText,
			Size = UDim2.fromScale(0.5, 0.5),
		},
		Text = "",
		Activated = function()
			self._instance.Visible = false
			UI.clearActiveStates()

			if self.Close and type(self.Close._value) == "function" then
				self.Close._value(self)
			elseif self.RemoveOnClose._value then
				self:Destroy()
			end
		end,
	}
	self._exitButton._instance:FindFirstChildOfClass("UIStroke"):Destroy()
	UI.edit(self._exitButton._instance.UICorner, { CornerRadius = UI.Theme.CornerPadded })

	self._content = UI.new "Frame" {
		Name = "UIContent",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0),
		ClipsDescendants = true,

		UI.new "UIFlexItem" {
			FlexMode = Enum.UIFlexMode.Fill,
		},
		UI.new "UIPadding" {
			PaddingLeft = UI.Theme.Padding,
			PaddingRight = UI.Theme.Padding,
			PaddingBottom = UI.Theme.Padding,
			PaddingTop = UDim.new(0, 1),
		},
	}

	self._instance = UI.new "Frame" {
		Name = "Window",
		BackgroundColor3 = UI.Theme.Primary,
		BackgroundTransparency = UI.Theme.Transparency,
		Position = self.Position,
		Size = self.Size,
		Visible = false,

		UI.new "UICorner" {
			CornerRadius = UI.Theme.CornerRadius,
		},
		UI.new "Stroke" {},

		UI.new "ImageLabel" {
			Name = "ResizeIcon",
			ZIndex = 1e3,
			BackgroundTransparency = 1,
			Image = "rbxassetid://72264604015628",
			ImageRectSize = Vector2.new(24, 24),
			ImageRectOffset = resizeIconRectOffset,
			Size = UDim2.new(0, 24, 0, 24),
			Visible = resizeHover,
			Position = function()
				local inputPos = inputPosition()
				return UDim2.fromOffset(inputPos.X - 12, inputPos.Y - 12) - self.Position()
			end,

			InputBegan = resizeBegan,
		},

		UI.new "Frame" {
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			Size = UDim2.fromScale(1, 1),

			UI.new "UIListLayout" {
				SortOrder = Enum.SortOrder.LayoutOrder,
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
					VerticalAlignment = Enum.VerticalAlignment.Center,
				},
				UI.new "UIPadding" {
					PaddingLeft = function()
						return UDim.new(0, UI.Theme.Padding().Offset + UI.Theme.FontSize / 2)
					end,
					PaddingRight = UI.Theme.Padding,
					PaddingTop = UI.Theme.Padding,
					PaddingBottom = UI.Theme.Padding,
				},

				UI.new "Frame" {
					Name = "Left",
					AutomaticSize = Enum.AutomaticSize.XY,
					BackgroundTransparency = 1,
					Size = UDim2.new(),

					UI.edit(
						UI.new "ImageLabel" {
							AnchorPoint = Vector2.new(0, 0.5),
							BackgroundTransparency = 1,
							Image = self.Icon,
							ImageColor3 = UI.Theme.PrimaryText,
							Position = UDim2.fromScale(0, 0.5),
							Size = iconSize,
							Visible = function()
								return if self.Icon() ~= "" then true else false
							end,
						},
						self.IconProperties()
					),

					UI.new "TextLabel" {
						AutoLocalize = false,
						Name = "Title",
						BackgroundTransparency = 1,
						AutomaticSize = Enum.AutomaticSize.XY,
						Size = UDim2.new(0, 0, 0, 0),
						FontFace = UI.Theme.Font,
						Position = function()
							return UDim2.fromOffset(UI.Theme.FontSize + UI.Theme.Padding().Offset, 0)
						end,
						RichText = true,
						Text = function()
							return `<b>{self.Title()}</b>`
						end,
						TextColor3 = UI.Theme.PrimaryText,
						TextStrokeColor3 = UI.Theme.Primary,
						TextStrokeTransparency = UI.Theme.TextStrokeTransparency,
						TextSize = UI.Theme.FontSizeLarger,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextYAlignment = Enum.TextYAlignment.Center,
						TextTruncate = Enum.TextTruncate.SplitWord,
					},
				},
				UI.new "Spacer" {},

				self._exitButton,

				InputBegan = dragInputBegan,
			},

			self._content,
		},

		[UI.Event] = {
			Visible = function()
				if self._instance.Visible then
					Class.bringToFront(self)
					Class.nudge(self)
				end
			end,
		},
	} :: Frame

	local mouseIconWasEnabled, mouseIconChanging = UI.UserInputService.MouseIconEnabled, nil
	UI.UserInputService:GetPropertyChangedSignal("MouseIconEnabled"):Connect(function()
		if mouseIconChanging then
			return
		end
		mouseIconWasEnabled = UI.UserInputService.MouseIconEnabled
	end)

	UI.UserInputService.InputBegan:Connect(resizeBegan)
	UI.UserInputService.InputChanged:Connect(function(input)
		if not self._instance.Visible then
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
					self._instance.AbsoluteSize,
					self._instance.AbsolutePosition,
					resizeBuffer
				)
				if resize then
					inputPosition(input.Position)
					resizeHover(true)
					resizeIconRectOffset(Vector2.new(resize[5]))
					if UI.UserInputService.MouseIconEnabled then
						mouseIconChanging = true
						UI.UserInputService.MouseIconEnabled = false
						mouseIconChanging = false
					end
				elseif resizeHover._value then
					resizeHover(false)
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
	self._instance:GetPropertyChangedSignal("Parent"):Connect(function()
		if parentConn then
			parentConn:Disconnect()
		end
		local parent = self._instance.Parent
		if parent and parent:IsA("GuiBase2d") then
			local function updateSize()
				if not self._instance.Visible then
					return
				end

				local parentSize = self._instance.Parent.AbsoluteSize
				local windowSize = self._instance.AbsoluteSize
				local maxPosition = parentSize - windowSize
				local position = self._instance.AbsolutePosition - self._instance.Parent.AbsolutePosition

				local padding = self._instance.Parent:FindFirstChildOfClass("UIPadding")
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

				self.Size(
					UDim2.fromOffset(
						math.clamp(windowSize.X, 0, math.max(0, parentSize.X - paddingX)),
						math.clamp(windowSize.Y, 0, math.max(0, parentSize.Y - paddingY))
					)
				)
				self.Position(
					UDim2.fromOffset(
						math.clamp(position.X, 0, math.max(0, maxPosition.X)),
						math.clamp(position.Y, 0, math.max(0, maxPosition.Y))
					)
				)
			end
			parentConn = parent:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateSize)
			self._instance:GetPropertyChangedSignal("Visible"):Connect(updateSize)
			if self._instance.Visible then
				updateSize()
			end
		end
	end)

	return setmetatable(self, Class) :: typeof(self) & typeof(Class)
end

return Class
