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
		Text = UI.Nil,
		TextSize = UI.Theme.FontSize,
		TextColor3 = UI.Theme.PrimaryText,
		TextStrokeColor3 = UI.Theme.Primary,
		TextStrokeTransparency = UI.Theme.TextStrokeTransparency,
		Title = UI.Nil,
		TitleSize = UI.Theme.FontSizeLargest,
		Activated = false,
		ActionText = UI.Nil,
		ActionTextSize = UI.Theme.FontSize,
		Action = UI.Nil,
		Duration = UI.Nil,
		Draggable = false,
		LeftAction = UI.Nil,
		RightAction = UI.Nil,
		ExitButton = UI.Nil,
		Close = UI.Nil,
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
		local anchorOffset = size * new._instance.AnchorPoint
		local minPosition = new._instance.Parent.AbsolutePosition + anchorOffset
		local maxPosition = new._instance.Parent.AbsoluteSize - (size - anchorOffset)

		new.Position:set(
			UDim2.fromOffset(
				math.clamp(math.round(startOffset.X + delta.X), minPosition.X, math.max(0, maxPosition.X)),
				math.clamp(math.round(startOffset.Y + delta.Y), minPosition.Y, math.max(0, maxPosition.Y))
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

	local con
	local function activate(active)
		if UI.peek(new.Activated) then
			return
		end
		new.Activated:set(true)
		new.Action:set(active, true)

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

	if new.Duration and new.Duration._value > 0 then
		local duration = new.Duration._value
		local start = tick()
		con = game:GetService("RunService").PreRender:Connect(function()
			local alpha = (tick() - start) / duration
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

	local buttonSize = UI.computeFrom(UDim2.new, 0, UI.Theme.FontSizeLargest, 0, UI.Theme.FontSizeLargest)

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
		Visible = UI.compute(function(use)
			return if use(new.ExitButton) then true else false
		end),
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
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
			Text = "",
			Visible = UI.compute(function(use)
				local title = use(new.Title)
				return title and title ~= ""
			end),

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

			if UI.peek(new.Title) then exitButton else nil,

			[UI.Event] = {
				InputBegan = dragInputBegan,
			},
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
			Visible = UI.compute(function(use)
				local text = use(new.Text)
				return text and text ~= ""
			end),

			AutomaticSize = Enum.AutomaticSize.XY,

			if UI.peek(new.Title) then nil else exitButton,
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
		Size = UI.computeFrom(UDim2.fromOffset, new.Width, 0),
		Text = "",
		Visible = new.Visible,

		UI.new "UICorner" {
			CornerRadius = UI.Theme.CornerRadius,
		},
		UI.new "UIStroke" {
			Enabled = UI.Theme.StrokeEnabled,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Transparency = UI.Theme.TransparencyClamped,
			Color = UI.Theme.Border,
		},
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
			UI.new "Frame" {
				Name = "Actions",
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				Visible = if new.LeftAction or new.RightAction then true else false,

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
					Visible = UI.compute(function(use)
						local text = use(new.ActionText)
						return text and text ~= ""
					end),

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
			},
		},
		progress,

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
		},
	}

	local sizeState = UI.state(new._instance, "AbsoluteSize")

	UI.edit(progress.Bar, {
		Size = UI.compute(function(use)
			local size = use(sizeState)
			return UDim2.fromOffset(size.X, size.Y)
		end),
	})

	return setmetatable(new, Dialog)
end

return Dialog
