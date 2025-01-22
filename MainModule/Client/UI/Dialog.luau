local BaseClass = require(script.Parent.BaseClass)
local UI = require(script.Parent)

local Dialog = {}
Dialog.__index = Dialog
setmetatable(Dialog, BaseClass)

-- alert, simple, confirmation dialogs
-- allow timed dialogs using announce design, fire an event when duration ends so cleanup can be handled dynamically?
-- maximum of 2 actions
function Dialog.new(definition)
	local new = UI.makeStatefulDefaults({
		Text = UI.Nil,
		TextColor3 = UI.Theme.PrimaryText,
		Title = UI.Nil,
		Activated = false,
		ActionText = UI.Nil,
		Action = UI.Nil,
		Duration = UI.Nil,
		LeftAction = UI.Nil,
		RightAction = UI.Nil,
		ExitButton = UI.Nil,
		Close = UI.Nil,
		Visible = true,
		Width = 256,
	}, definition)

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

	local exitButton = UI.new "Button" {
		LayoutOrder = 9,
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = Color3.fromRGB(200, 0, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UI.computeFrom(UDim2.new, 0, UI.Theme.FontSizeLarger, 0, UI.Theme.FontSizeLarger),
		Icon = "rbxassetid://1476571006",
		IconProperties = {
			Size = UDim2.new(0, 10, 0, 10),
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

		UI.new "Frame" {
			Name = "Title",
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
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
				Text = new.Title,
				TextSize = UI.Theme.FontSizeLarge,
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
		},

		UI.new "TextLabel" {
			AutoLocalize = false,
			Name = "Text",
			BackgroundTransparency = 1,
			TextColor3 = new.TextColor3,
			Text = new.Text,
			TextSize = UI.Theme.FontSize,
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

	new._instance = UI.new "Frame" {
		Name = "Dialog",
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = UI.Theme.Primary,
		BackgroundTransparency = UI.Theme.Transparency,
		ClipsDescendants = true,
		Size = UI.computeFrom(UDim2.fromOffset, new.Width, 0),
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
					HorizontalFlex = Enum.UIFlexAlignment.Fill,
					VerticalFlex = Enum.UIFlexAlignment.Fill,
					Padding = UI.Theme.Padding,
				},

				UI.new "TextLabel" {
					AutoLocalize = false,
					Name = "Text",
					BackgroundTransparency = 1,
					TextColor3 = UI.Theme.PrimaryText,
					Text = new.ActionText,
					TextSize = UI.Theme.FontSize,
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
				UI.new "Frame" {
					Name = "Spacer",
					BackgroundTransparency = 1,
					UI.new "UIFlexItem" {
						FlexMode = Enum.UIFlexMode.Fill,
					},
				},
				UI.new "TextButton" {
					AutoLocalize = false,
					Name = "LeftAction",
					AutomaticSize = Enum.AutomaticSize.XY,
					BackgroundTransparency = 1,
					Visible = if new.LeftAction then true else false,
					Text = "",

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
					UI.new "UIAspectRatioConstraint" {
						DominantAxis = Enum.DominantAxis.Height,
						AspectType = Enum.AspectType.ScaleWithParentSize,
					},

					UI.new "ImageLabel" {
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						Position = UDim2.fromScale(0.5, 0.5),
						Size = UDim2.new(0, 10, 0, 10),
						Image = "rbxassetid://1476571006",
						ImageColor3 = UI.Theme.Invalid,
					},

					[UI.Event] = {
						Activated = function()
							activate(false)
						end,
					},
				},
				UI.new "TextButton" {
					AutoLocalize = false,
					Name = "RightAction",
					AutomaticSize = Enum.AutomaticSize.XY,
					BackgroundTransparency = 1,
					Visible = if new.RightAction then true else false,
					Text = "",

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
					UI.new "UIAspectRatioConstraint" {
						DominantAxis = Enum.DominantAxis.Height,
						AspectType = Enum.AspectType.ScaleWithParentSize,
					},

					UI.new "ImageLabel" {
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						Position = UDim2.fromScale(0.5, 0.5),
						Size = UDim2.new(0, 14, 0, 14),
						Image = "rbxassetid://2340153468",
						ImageColor3 = UI.Theme.Valid,
					},

					[UI.Event] = {
						Activated = function()
							activate(true)
						end,
					},
				},
			},
		},
		progress,
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
