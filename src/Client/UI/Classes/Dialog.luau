local RunService = game:GetService("RunService")

local UI = require(script.Parent.Parent)
local BaseClass = require(script.Parent:WaitForChild("BaseClass"))

local DEFAULT = {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0.5, 0, 0.5, 0),
	Text = "",
	TextSize = UI.Theme.FontSize,
	TextColor3 = UI.Theme.PrimaryText,
	TextStrokeColor3 = UI.Theme.Primary,
	TextStrokeTransparency = UI.Theme.TextStrokeTransparency,
	TextXAlignment = Enum.TextXAlignment.Left,
	Title = "",
	TitleSize = UI.Theme.FontSizeLargest,
	TitleTextXAlignment = Enum.TextXAlignment.Left,
	Activated = false,
	ActionText = "",
	ActionTextSize = UI.Theme.FontSize,
	Action = UI.Nil,
	Duration = UI.Nil,
	Draggable = false,
	LeftAction = UI.Nil,
	RightAction = UI.Nil,
	Options = UI.Nil,
	OptionColors = UI.Nil,
	ExitButton = false,
	Close = UI.Function,
	Selectable = false,
	Visible = true,
	Width = 256,
}

type Properties = typeof(DEFAULT) & TextButton

local Class = {}
Class.__index = Class
setmetatable(Class, BaseClass)

-- alert, simple, confirmation dialogs
-- allow timed dialogs using announce design, fire an event when duration ends so cleanup can be handled dynamically?
-- maximum of 2 icon actions, or labeled Options that fire Action with the chosen index
function Class.new(properties: Properties?)
	local self = table.clone(DEFAULT)
	UI.makeStatefulDefaults(self, properties)
	if not self.Action and (self.Options or self.LeftAction or self.RightAction) then
		self.Action = UI.signal(nil)
		if self._createdNodes then
			table.insert(self._createdNodes, self.Action)
		end
	end

	local dragInput, dragStart, startOffset
	local dragging = UI.signal(false)
	self._dragging = dragging

	local function dragUpdate(input)
		if not dragInput then
			return
		end

		local delta = input.Position - dragStart
		local size = self._instance.AbsoluteSize
		local offset = size * self._instance.AnchorPoint
		local min = self._instance.Parent.AbsolutePosition + offset
		local max = self._instance.Parent.AbsoluteSize - (size - offset)

		self.Position(
			UDim2.fromOffset(
				math.clamp(math.round(startOffset.X + delta.X), min.X, math.max(offset.X, max.X)),
				math.clamp(math.round(startOffset.Y + delta.Y), math.max(offset.Y, min.Y), math.max(offset.Y, max.Y))
			),
			true
		)
		UI.flush()
	end

	local function dragInputBegan(input, gameProcessed)
		if gameProcessed or not self.Draggable:peek() then
			return
		end
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			startOffset = (self._instance.AbsolutePosition + self._instance.AbsoluteSize * self._instance.AnchorPoint)
				- self._instance.Parent.AbsolutePosition
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

	local con
	local function activate(active)
		if UI.raw(self.Activated) then
			return
		end
		self.Activated(true)
		if self.Action then
			self.Action(active, true)
		end
		UI.flush()

		if con then
			con:Disconnect()
		end
		if self.Close and type(self.Close:peek()) == "function" then
			self.Close:peek()(self)
		else
			self:Destroy()
		end
	end

	local progress = UI.new "Frame" {
		ZIndex = -1,
		Name = "Progress",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 4),
		ClipsDescendants = true,
		Visible = if self.Duration and self.Duration:peek() > 0 then true else false,

		UI.new "Frame" {
			Name = "Bar",
			AnchorPoint = Vector2.new(0, 1),
			BackgroundColor3 = UI.Theme.Secondary,
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(),
			UI.corner(UI.Theme.CornerRadius),
		},
	}

	local buttonSize = UI.computed(function()
		return UDim2.new(0, UI.Theme.FontSizeLargest(), 0, UI.Theme.FontSizeLargest())
	end)
	self._buttonSize = buttonSize

	-- one button per option, activating it fires Action with its index
	local optionLabels = if self.Options then UI.raw(self.Options) else nil
	local optionColors = if self.OptionColors then UI.raw(self.OptionColors) else nil
	local optionsFrame = nil
	if optionLabels and #optionLabels > 0 then
		optionsFrame = UI.new "Frame" {
			Name = "Options",
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 0),

			UI.list {
				gap = UI.Theme.Padding,
			},
			UI.new "TextLabel" {
				AutoLocalize = false,
				Name = "Text",
				LayoutOrder = -1, -- non-zero, UI.edit would otherwise reorder it by its child index
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = 1,
				TextColor3 = UI.Theme.PrimaryText,
				TextStrokeColor3 = UI.Theme.Primary,
				TextStrokeTransparency = UI.Theme.TextStrokeTransparency,
				Text = self.ActionText,
				TextSize = self.ActionTextSize,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				FontFace = UI.Theme.FontBold,
				RichText = true,
				Visible = function()
					local text = self.ActionText and self.ActionText()
					return text ~= nil and text ~= ""
				end,
			},
		}
		for index, label in optionLabels do
			UI.new "Button" {
				Parent = optionsFrame,
				Name = `Option{index}`,
				LayoutOrder = index,
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundColor3 = if optionColors then optionColors[index] else nil,
				Label = label,
				LabelProperties = {
					TextTruncate = Enum.TextTruncate.None,
					TextWrapped = true,
					-- the button's height as a minimum so one line stays centered, it grows when the text wraps
					Size = function()
						return UDim2.new(1, 0, 0, UI.Theme.FontSize() + UI.Theme.Padding().Offset * 2)
					end,
				},
				Activated = function()
					activate(index)
				end,
			}
		end
	end

	local exitButton = UI.new "Button" {
		LayoutOrder = 9,
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = Color3.fromRGB(200, 0, 0),
		BackgroundTransparency = 1,
		HoverTransparency = 0,
		Position = UDim2.new(1, 0, 0, 0),
		Size = buttonSize,
		Icon = UI.Theme.Image.Close,
		IconProperties = {
			ImageColor3 = UI.Theme.PrimaryText,
			Size = UDim2.fromScale(0.5, 0.5),
		},
		Text = "",
		Activated = function()
			if con then
				con:Disconnect()
			end
			if self.Close and type(self.Close:peek()) == "function" then
				self.Close:peek()(self)
			else
				self:Destroy()
			end
		end,
		Visible = function()
			return if self.ExitButton() then true else false
		end,
	}
	exitButton._instance:FindFirstChildOfClass("UIStroke"):Destroy()
	self._exitButton = exitButton

	self._content = UI.new "Frame" {
		Name = "UIContent",
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0),

		UI.list {
			gap = UI.Theme.Padding,
			horizontalAlign = "fill",
		},

		UI.new "TextButton" {
			Name = "Title",
			LayoutOrder = -2,
			AutoLocalize = false,
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
			Text = "",
			Visible = function()
				local title = self.Title()
				return title and title ~= ""
			end,

			UI.list {
				direction = "x",
				gap = UI.Theme.Padding,
			},

			UI.new "TextLabel" {
				AutoLocalize = false,
				BackgroundTransparency = 1,
				TextColor3 = UI.Theme.PrimaryText,
				TextStrokeColor3 = UI.Theme.Primary,
				TextStrokeTransparency = UI.Theme.TextStrokeTransparency,
				Text = self.Title,
				TextSize = self.TitleSize,
				TextTruncate = Enum.TextTruncate.SplitWord,
				TextXAlignment = self.TitleTextXAlignment,
				FontFace = UI.Theme.FontHeavy,
				RichText = true,

				AutomaticSize = Enum.AutomaticSize.XY,
				UI.flex("fill"),
			},

			if UI.raw(self.Title) ~= nil and UI.raw(self.Title) ~= "" then exitButton else nil,

			InputBegan = dragInputBegan,
		},

		UI.new "TextBox" {
			AutoLocalize = false,
			Name = "Text",
			LayoutOrder = -1,
			BackgroundTransparency = 1,
			ClearTextOnFocus = false,
			Interactable = self.Selectable,
			TextEditable = false,
			TextColor3 = self.TextColor3,
			Text = self.Text,
			TextSize = self.TextSize,
			TextWrapped = true,
			TextXAlignment = self.TextXAlignment,
			FontFace = UI.Theme.Font,
			RichText = true,
			Visible = function()
				local text = self.Text()
				return text and text ~= ""
			end,

			AutomaticSize = Enum.AutomaticSize.XY,

			if UI.raw(self.Title) ~= nil and UI.raw(self.Title) ~= "" then nil else exitButton,
		},
	}

	self._instance = UI.new "ImageButton" {
		Name = "Dialog",
		Active = false,
		AutoButtonColor = false,
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = function()
			return if UI.Theme.BackgroundGradientEnabled() then Color3.new(1, 1, 1) else UI.Theme.Primary()
		end,
		BackgroundTransparency = UI.Theme.Transparency,
		Image = UI.Theme.BackgroundImage,
		ImageTransparency = UI.Theme.BackgroundImageTransparency,
		ScaleType = UI.Theme.BackgroundImageScaleType,
		ClipsDescendants = true,
		AnchorPoint = self.AnchorPoint,
		Position = self.Position,
		Size = function()
			return UDim2.fromOffset(self.Width(), 0)
		end,
		Visible = self.Visible,

		UI.corner(UI.Theme.CornerRadius),
		UI.new "Gradient" {},
		UI.new "Stroke" {},
		UI.list {},

		UI.new "Frame" {
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 0),

			UI.padding(UI.Theme.Padding),
			UI.list {
				gap = UI.Theme.Padding,
			},

			self._content,
			if self.LeftAction or self.RightAction
				then UI.new "Frame" {
					Name = "Actions",
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,

					Size = UDim2.new(1, 0, 0, 0),

					UI.edit(UI.list {
						direction = "x",
						gap = UI.Theme.Padding,
						horizontalAlign = "end",
						verticalAlign = "fill",
					})({ VerticalAlignment = Enum.VerticalAlignment.Center }),

					UI.new "TextLabel" {
						AutoLocalize = false,
						Name = "Text",
						BackgroundTransparency = 1,
						TextColor3 = UI.Theme.PrimaryText,
						TextStrokeColor3 = UI.Theme.Primary,
						TextStrokeTransparency = UI.Theme.TextStrokeTransparency,
						Text = self.ActionText,
						TextSize = self.ActionTextSize,
						TextWrapped = true,
						TextTruncate = Enum.TextTruncate.SplitWord,
						TextXAlignment = "Left",
						FontFace = UI.Theme.FontBold,
						RichText = true,
						Visible = function()
							local text = self.ActionText and self.ActionText()
							return text ~= nil and text ~= ""
						end,

						AutomaticSize = Enum.AutomaticSize.XY,
					},
					UI.new "Spacer" {},
					UI.new "Button" {
						Name = "LeftAction",
						AutomaticSize = Enum.AutomaticSize.None,
						BackgroundTransparency = 1,
						Size = buttonSize,
						Icon = UI.Theme.Image.Close_Bold,
						IconProperties = {
							ImageColor3 = UI.Theme.Invalid,
							Size = UDim2.fromScale(0.5, 0.5),
						},
						Text = "",
						Activated = function()
							activate(false)
						end,
					},
					UI.new "Button" {
						Name = "RightAction",
						AutomaticSize = Enum.AutomaticSize.None,
						BackgroundTransparency = 1,
						Size = buttonSize,
						Icon = UI.Theme.Image.Check_Bold,
						IconProperties = {
							ImageColor3 = UI.Theme.Valid,
							Size = UDim2.fromScale(0.625, 0.625),
						},
						Text = "",
						Activated = function()
							activate(true)
						end,
					},
				}
				else nil,
			optionsFrame,
		},
		progress,
	} :: TextButton

	local hovering = UI.Interact.hover(self._instance, { within = true })
	self._hovering = hovering

	local inputConn = UI.UserInputService.InputChanged:Connect(function(input)
		if not (self.Draggable:peek() and self._instance.Visible) then
			return
		end
		if
			input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch
		then
			if dragging:peek() then
				dragUpdate(input)
			end
		end
	end)
	local cleanup = {
		inputConn,
		hovering,
	}

	if self.Duration and self.Duration:peek() > 0 then
		local duration = self.Duration:peek()
		local pauseOnHover = not (self.Options or self.LeftAction or self.RightAction)
		local elapsed = 0
		con = RunService.PreRender:Connect(function(dt: number)
			if pauseOnHover and hovering() then
				return
			end

			elapsed += dt
			local alpha = elapsed / duration
			progress.Size = UDim2.new(math.clamp(1 - alpha, 0, 1), 0, 0, 4)
			if alpha >= 1 then
				con:Disconnect()
				if self.Close and type(self.Close:peek()) == "function" then
					self.Close:peek()(self)
				else
					self:Destroy()
				end
			end
		end)
	end

	local sizeState = UI.property(self._instance, "AbsoluteSize")
	self.sizeState = sizeState
	table.insert(cleanup, dragging)
	table.insert(cleanup, sizeState)
	table.insert(cleanup, buttonSize)
	table.insert(cleanup, exitButton)
	if con then
		table.insert(cleanup, con)
	end

	UI.edit(self._instance)({ __CLEAN = cleanup })

	UI.edit(progress.Bar)({
		Size = function()
			local size = sizeState()
			return UDim2.fromOffset(size.X, size.Y)
		end,
	})

	return setmetatable(self, Class) :: typeof(self) & typeof(Class)
end

return Class
