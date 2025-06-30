local BaseClass = require(script.Parent.BaseClass)
local UI = require(script.Parent.Parent)

local Dialog = {}
Dialog.__index = Dialog
setmetatable(Dialog, BaseClass)

-- alert, simple, confirmation dialogs
-- allow timed dialogs using announce design, fire an event when duration ends so cleanup can be handled dynamically?
-- maximum of 2 actions
function Dialog.new(definition)
	local new = UI.makeStatefulDefaults({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Text = "",
		TextSize = UI.Theme.FontSize,
		TextColor3 = UI.Theme.PrimaryText,
		TextStrokeColor3 = UI.Theme.Primary,
		TextStrokeTransparency = UI.Theme.TextStrokeTransparency,
		Title = "",
		TitleSize = UI.Theme.FontSizeLargest,
		Activated = false,
		ActionText = UI.Nil,
		ActionTextSize = UI.Theme.FontSize,
		Action = UI.Nil,
		Duration = UI.Nil,
		Draggable = false,
		LeftAction = UI.Nil,
		RightAction = UI.Nil,
		ExitButton = false,
		Close = UI.Function,
		Visible = true,
		Width = 256,
	}, definition)

	local dragInput, dragStart, startOffset
	local dragging = UI.state(false)

	local function dragUpdate(input)
		if not dragInput then
			return
		end

		local delta = input.Position - dragStart
		local size = new._instance.AbsoluteSize
		local offset = size * new._instance.AnchorPoint
		local min = new._instance.Parent.AbsolutePosition + offset
		local max = new._instance.Parent.AbsoluteSize - (size - offset)

		new.Position(
			UDim2.fromOffset(
				math.clamp(math.round(startOffset.X + delta.X), min.X, math.max(offset.X, max.X)),
				math.clamp(math.round(startOffset.Y + delta.Y), math.max(offset.Y, min.Y), math.max(offset.Y, max.Y))
			)
		)
	end

	local function dragInputBegan(input, gameProcessed)
		if gameProcessed or not new.Draggable._value then
			return
		end
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			startOffset = (new._instance.AbsolutePosition + new._instance.AbsoluteSize * new._instance.AnchorPoint)
				- new._instance.Parent.AbsolutePosition
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
		if UI.raw(new.Activated) then
			return
		end
		new.Activated(true)
		new.Action(active, true)

		if con then
			con:Disconnect()
		end
		if new.Close and type(new.Close._value) == "function" then
			new.Close._value(new)
		else
			new:Destroy()
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
		Visible = if new.Duration and new.Duration._value > 0 then true else false,

		UI.new "Frame" {
			Name = "Bar",
			AnchorPoint = Vector2.new(0, 1),
			BackgroundColor3 = UI.Theme.Secondary,
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(),
			UI.new "UICorner" {
				CornerRadius = UI.Theme.CornerRadius,
			},
		},
	}

	local hovering = UI.state(false)
	new._hovering = hovering

	if new.Duration and new.Duration._value > 0 then
		local duration = new.Duration._value
		local elapsed = 0
		con = game:GetService("RunService").PreRender:Connect(function(dt: number)
			if hovering._value then
				return
			end

			elapsed += dt
			local alpha = elapsed / duration
			progress.Size = UDim2.new(math.clamp(1 - alpha, 0, 1), 0, 0, 4)
			if alpha >= 1 then
				con:Disconnect()
				if new.Close and type(new.Close._value) == "function" then
					new.Close._value(new)
				else
					new:Destroy()
				end
			end
		end)
	end

	local buttonSize = UI.compute(function()
		return UDim2.new(0, UI.Theme.FontSizeLargest(), 0, UI.Theme.FontSizeLargest())
	end)

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
			if new.Close and type(new.Close._value) == "function" then
				new.Close._value(new)
			else
				new:Destroy()
			end
		end,
		Visible = function()
			return if new.ExitButton() then true else false
		end,
	}
	exitButton._instance:FindFirstChildOfClass("UIStroke"):Destroy()
	new._exitButton = exitButton

	new._content = UI.new "Frame" {
		Name = "UIContent",
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0),

		UI.new "UIListLayout" {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UI.Theme.Padding,
			HorizontalFlex = Enum.UIFlexAlignment.Fill,
		},

		UI.new "TextButton" {
			Name = "Title",
			AutoLocalize = false,
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
			Text = "",
			Visible = function()
				local title = new.Title()
				return title and title ~= ""
			end,

			UI.new "UIListLayout" {
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UI.Theme.Padding,
				FillDirection = Enum.FillDirection.Horizontal,
			},

			UI.new "TextLabel" {
				AutoLocalize = false,
				BackgroundTransparency = 1,
				TextColor3 = UI.Theme.PrimaryText,
				TextStrokeColor3 = UI.Theme.Primary,
				TextStrokeTransparency = UI.Theme.TextStrokeTransparency,
				Text = new.Title,
				TextSize = new.TitleSize,
				TextTruncate = Enum.TextTruncate.SplitWord,
				TextXAlignment = "Left",
				FontFace = UI.Theme.FontHeavy,
				RichText = true,

				AutomaticSize = Enum.AutomaticSize.XY,
				UI.new "UIFlexItem" {
					FlexMode = Enum.UIFlexMode.Fill,
				},
			},

			if UI.raw(new.Title) then exitButton else nil,

			InputBegan = dragInputBegan,
		},

		UI.new "TextLabel" {
			AutoLocalize = false,
			Name = "Text",
			BackgroundTransparency = 1,
			TextColor3 = new.TextColor3,
			Text = new.Text,
			TextSize = new.TextSize,
			TextWrapped = true,
			TextXAlignment = "Left",
			Font = UI.Theme.Font,
			RichText = true,
			Visible = function()
				local text = new.Text()
				return text and text ~= ""
			end,

			AutomaticSize = Enum.AutomaticSize.XY,

			if UI.raw(new.Title) then nil else exitButton,
		},
	}

	new._instance = UI.new "TextButton" {
		Name = "Dialog",
		Active = false,
		AutoButtonColor = false,
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = UI.Theme.Primary,
		BackgroundTransparency = UI.Theme.Transparency,
		ClipsDescendants = true,
		AnchorPoint = new.AnchorPoint,
		Position = new.Position,
		Size = function()
			return UDim2.fromOffset(new.Width(), 0)
		end,
		Text = "",
		Visible = new.Visible,

		UI.new "UICorner" {
			CornerRadius = UI.Theme.CornerRadius,
		},
		UI.new "Stroke" {},
		UI.new "UIListLayout" {
			SortOrder = Enum.SortOrder.LayoutOrder,
		},

		UI.new "Frame" {
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 0),

			UI.new "UIPadding" {
				PaddingLeft = UI.Theme.Padding,
				PaddingRight = UI.Theme.Padding,
				PaddingTop = UI.Theme.Padding,
				PaddingBottom = UI.Theme.Padding,
			},
			UI.new "UIListLayout" {
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UI.Theme.Padding,
			},

			new._content,
			if new.LeftAction or new.RightAction
				then UI.new "Frame" {
					Name = "Actions",
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,

					Size = UDim2.new(1, 0, 0, 0),

					UI.new "UIListLayout" {
						SortOrder = Enum.SortOrder.LayoutOrder,
						FillDirection = Enum.FillDirection.Horizontal,
						HorizontalAlignment = Enum.HorizontalAlignment.Right,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						VerticalFlex = Enum.UIFlexAlignment.Fill,
						Padding = UI.Theme.Padding,
					},

					UI.new "TextLabel" {
						AutoLocalize = false,
						Name = "Text",
						BackgroundTransparency = 1,
						TextColor3 = UI.Theme.PrimaryText,
						TextStrokeColor3 = UI.Theme.Primary,
						TextStrokeTransparency = UI.Theme.TextStrokeTransparency,
						Text = new.ActionText,
						TextSize = new.ActionTextSize,
						TextWrapped = true,
						TextTruncate = Enum.TextTruncate.SplitWord,
						TextXAlignment = "Left",
						FontFace = UI.Theme.FontBold,
						RichText = true,
						Visible = function()
							local text = new.ActionText()
							return text and text ~= ""
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
		},
		progress,

		InputChanged = function(input, processed)
			if processed then
				return
			end
			if
				input.UserInputType == Enum.UserInputType.MouseMovement
				or input.UserInputType == Enum.UserInputType.Touch
			then
				hovering(true)
			end
		end,
		inputEnded = function(input)
			if
				input.UserInputType == Enum.UserInputType.MouseMovement
				or input.UserInputType == Enum.UserInputType.Touch
			then
				hovering(false)
			end
		end,

		[UI.Clean] = {
			UI.UserInputService.InputChanged:Connect(function(input)
				if not (new.Draggable._value and new._instance.Visible) then
					return
				end
				if
					input.UserInputType == Enum.UserInputType.MouseMovement
					or input.UserInputType == Enum.UserInputType.Touch
				then
					if dragging._value then
						dragUpdate(input)
					end
				end
			end),
			hovering,
		},
	}

	local sizeState = UI.state(new._instance, "AbsoluteSize")

	UI.edit(progress.Bar, {
		Size = function()
			local size = sizeState()
			return UDim2.fromOffset(size.X, size.Y)
		end,
	})

	return setmetatable(new, Dialog)
end

return Dialog
