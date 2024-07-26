local Players = game:GetService("Players")
local TextService = game:GetService("TextService")

local _K = require(script.Parent.Parent)
local UI = require(script.Parent.Parent.Flux.UI)
local Util = require(script.Parent.Parent.Util)

local existing = {}

local function resetOffset(height: number?)
	local heightOffset = 0
	for i, list in ipairs(existing) do
		local card, _, offset = unpack(list)
		offset:set(heightOffset)
		if height and i == 1 then
			heightOffset = height
		end
		heightOffset += card.AbsoluteSize.Y + UI.Theme.Padding._value.Offset
	end
	return heightOffset
end

local function hide(info, height: number?)
	local announce, visible, _offset = unpack(info)
	local found = table.find(existing, info)
	if not found then
		return
	end

	table.remove(existing, found)
	resetOffset(height)
	announce.ZIndex = -1
	visible:set(nil)
	task.delay(1 + UI.Theme.TweenOut._value.Time, announce.Destroy, announce)
end

return function(text: string, from: number?, delay: number?, name: string?, image: string?)
	delay = delay or 4 + 0.125 * #text
	name = name or "Kohl's Admin"
	image = image or "rbxassetid://10650688076"

	local userName = ""
	local badge = "system"
	local color = "#fff"

	if from then
		local content, _isReady =
			Players:GetUserThumbnailAsync(from, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
		image = content or image
		local info = Util.getUserInfo(from)
		name = info.DisplayName
		userName = info.Username
		local role = _K.Auth.getRoleFromRank(_K.Auth.getRank(from))
		badge = if role then role.name else "Unknown"
		color = role.color
	end

	local visible = UI.state(false)
	local offset = UI.state(0)
	local self

	local bar = UI.new "Frame" {
		Name = "Bar",
		AnchorPoint = Vector2.new(0, 1),
		BackgroundColor3 = UI.Theme.Secondary,
		Position = UDim2.fromScale(0, 1),
		UI.new "UICorner" {
			CornerRadius = UI.Theme.CornerRadius,
		},
	}

	local exitButton = UI.new "Button" {
		BackgroundColor3 = Color3.fromRGB(200, 0, 0),
		Size = UI.computeFrom(UDim2.new, 0, UI.Theme.FontSizeLarger, 0, UI.Theme.FontSizeLarger),
		Icon = "rbxassetid://1476571006",
		IconProperties = {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.new(0, 10, 0, 10),
			Position = UDim2.new(0.5, 0, 0.5, 0),
			ResampleMode = Enum.ResamplerMode.Pixelated,
		},
		Text = "",
		Activated = function()
			hide(self)
		end,
	}
	exitButton._instance:FindFirstChildOfClass("UIStroke"):Destroy()

	local card
	card = UI.new "Frame" {
		Parent = UI.LayerTop,
		Name = "Announcement",
		AnchorPoint = UI.tween(
			UI.Theme.TweenInOut,
			UI.compute(function(use)
				return Vector2.new(0.5, if use(visible) then 0 else 1)
			end)
		),
		BackgroundColor3 = UI.Theme.Primary,
		BackgroundTransparency = UI.Theme.Transparency,

		AutomaticSize = Enum.AutomaticSize.Y,
		Position = UI.tween(
			UI.Theme.TweenInOut,
			UI.compute(function(use)
				local height = use(UI.TopbarInset).Height
				local padding = use(UI.Theme.Padding).Offset
				local offset = use(offset)
				return UDim2.new(0.5, 0, 0, if use(visible) then height + padding + offset else 0)
			end)
		),
		Size = UDim2.new(0.5),

		UI.new "UISizeConstraint" {
			MinSize = Vector2.new(128, 0),
			MaxSize = Vector2.new(512, 9e9),
		},

		UI.new "UICorner" {
			CornerRadius = UI.Theme.CornerRadius,
		},
		UI.new "UIStroke" {
			Enabled = UI.Theme.StrokeEnabled,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Transparency = UI.Theme.Transparency,
			Color = UI.Theme.Border,
		},

		UI.new "Frame" {
			ZIndex = -1,
			Name = "Progress",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UI.tween(
				TweenInfo.new(delay, Enum.EasingStyle.Linear),
				UI.compute(function(use)
					return UDim2.new(if use(visible) ~= false then 0 else 1, 0, 0, 4)
				end)
			),
			ClipsDescendants = true,
			bar,
		},

		UI.new "Frame" {
			Name = "Content",
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.fromScale(1, 0),

			UI.new "UIPadding" {
				PaddingLeft = UI.Theme.PaddingDouble,
				PaddingRight = UI.Theme.PaddingDouble,
				PaddingTop = UI.Theme.PaddingDouble,
				PaddingBottom = UI.Theme.PaddingDouble,
			},
			UI.new "UIListLayout" {
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UI.Theme.PaddingDouble,
				HorizontalFlex = Enum.UIFlexAlignment.Fill,
			},

			UI.new "Frame" {
				Name = "Header",
				Size = UDim2.new(),
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = 1,

				UI.new "UIListLayout" {
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UI.Theme.PaddingHalf,
					FillDirection = Enum.FillDirection.Horizontal,
				},

				UI.new "ImageLabel" {
					Name = "Icon",
					BackgroundTransparency = 0.75,
					BackgroundColor3 = UI.Theme.Border,
					Size = UI.computeFrom(UDim2.fromOffset, UI.Theme.FontSizeDouble, UI.Theme.FontSizeDouble),
					Image = image,

					UI.new "UICorner" {
						CornerRadius = UDim.new(1, 0),
					},
					UI.new "UIStroke" {
						Enabled = UI.Theme.StrokeEnabled,
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
						Transparency = UI.Theme.Transparency,
						Color = UI.Theme.Border,
					},
				},

				UI.new "Frame" {
					Name = "From",
					AutomaticSize = Enum.AutomaticSize.XY,
					BackgroundTransparency = 1,

					UI.new "UIListLayout" {
						SortOrder = Enum.SortOrder.LayoutOrder,
					},

					UI.new "Frame" {
						AutomaticSize = Enum.AutomaticSize.XY,
						BackgroundTransparency = 1,

						UI.new "UIListLayout" {
							SortOrder = Enum.SortOrder.LayoutOrder,
							Padding = UI.Theme.PaddingHalf,
							FillDirection = Enum.FillDirection.Horizontal,
						},

						UI.new "TextLabel" {
							Name = "From",
							BackgroundTransparency = 1,
							TextColor3 = UI.Theme.PrimaryText,
							Text = `<b>{name}</b>`,
							TextSize = UI.Theme.FontSizeLarge,
							TextTruncate = Enum.TextTruncate.SplitWord,
							TextXAlignment = "Left",
							Font = UI.Theme.Font,
							RichText = true,

							AutomaticSize = Enum.AutomaticSize.XY,
							Size = UI.compute(UDim2.fromOffset, 0, UI.Theme.FontSizeLarge),
						},

						UI.new "TextLabel" {
							Name = "Badge",
							BackgroundColor3 = Color3.fromHex(color),
							TextColor3 = if UI.getLuminance(Color3.fromHex(color)) > 0.5
								then Color3.new()
								else Color3.new(1, 1, 1),
							Text = `<b>{string.upper(badge)}</b>`,
							TextSize = UI.compute(function(use)
								return use(UI.Theme.FontSizeLarge) - 8
							end),
							TextTruncate = Enum.TextTruncate.SplitWord,
							TextXAlignment = "Left",
							Font = UI.Theme.FontMono,
							RichText = true,

							AutomaticSize = Enum.AutomaticSize.X,
							Size = UI.computeFrom(UDim2.fromOffset, 0, UI.Theme.FontSizeLarge),

							UI.new "UICorner" {
								CornerRadius = UI.Theme.CornerDiameter,
							},
							UI.new "UIPadding" {
								PaddingLeft = UDim.new(0, 4),
								PaddingRight = UDim.new(0, 4),
								PaddingTop = UDim.new(0, 4),
								PaddingBottom = UDim.new(0, 4),
							},
						},
					},

					UI.new "TextLabel" {
						Name = "FromBottom",
						BackgroundTransparency = 1,
						TextColor3 = UI.Theme.PrimaryText,
						Text = `<font transparency="0.5"><b>@{userName}</b></font>`,
						TextSize = UI.Theme.FontSizeSmall,
						TextTruncate = Enum.TextTruncate.SplitWord,
						TextXAlignment = "Left",
						Font = UI.Theme.Font,
						RichText = true,

						AutomaticSize = Enum.AutomaticSize.XY,
						Size = UI.compute(UDim2.fromOffset, 0, UI.Theme.FontSizeSmall),
					},
				},

				UI.new "Frame" {
					Name = "Spacer",
					BackgroundTransparency = 1,
					UI.new "UIFlexItem" {
						FlexMode = Enum.UIFlexMode.Fill,
					},
				},

				exitButton,
			},

			UI.new "TextLabel" {
				Name = "Message",
				BackgroundTransparency = 1,
				TextColor3 = UI.Theme.PrimaryText,
				Text = text,
				TextSize = UI.Theme.FontSizeLarge,
				TextXAlignment = "Left",
				TextWrapped = true,
				Font = UI.Theme.Font,
				RichText = true,

				AutomaticSize = Enum.AutomaticSize.XY,
				Size = UDim2.new(),
				UI.new "UIFlexItem" {
					FlexMode = Enum.UIFlexMode.Fill,
				},
			},
		},
	}

	self = { card, visible, offset }
	table.insert(existing, 1, self)
	visible:set(true)

	local sizeState = UI.state(card, "AbsoluteSize")

	UI.edit(bar, {
		Size = UI.compute(function(use)
			local size = use(sizeState)
			return UDim2.fromOffset(size.X, size.Y)
		end),
	})

	local height =
		TextService:GetTextSize(text, UI.Theme.FontSize._value, UI.Theme.Font._value, Vector2.new(512, 9e9)).Y

	if resetOffset(height) > (UI.LayerTop.AbsoluteSize.Y - UI.TopbarInset._value.Height) / 2 then
		hide(existing[#existing], height)
	end

	task.delay(delay, hide, self)
end
