local Players = game:GetService("Players")

local UI = require(script.Parent.Parent.Flux.UI)
local Util = require(script.Parent.Parent.Util)

local existing

local function hide(announce, visible)
	announce.ZIndex = -1
	visible:set(false)
	task.delay(1 + UI.Theme.TweenOut.Time, announce.Destroy, announce)
end

local function removeExisting()
	if not existing then
		return
	end
	hide(unpack(existing))
	existing = nil
end

return function(text: string, from: number?, delay: number?, name: string?, image: string?)
	delay = delay or 4 + 0.125 * #text
	name = name or "Kohl's Admin"
	image = image or "rbxassetid://10650688076"

	if from then
		local content, isReady =
			Players:GetUserThumbnailAsync(from, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
		image = content or image
		name = Util.getUserName(from)
	end

	removeExisting()

	local timeLabel = UI.new "TextLabel" {
		Name = "Time",
		AnchorPoint = Vector2.new(1, 0),
		BackgroundTransparency = 1,
		TextTransparency = 0.75,
		TextColor3 = UI.Theme.PrimaryText,
		Text = math.ceil(delay),
		TextSize = UI.Theme.FontSizeLarger,
		TextXAlignment = "Right",
		Font = UI.Theme.Font,

		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UI.computeFrom(UDim2.fromOffset, 0, UI.Theme.FontSizeLarger),
		UI.new "UIFlexItem" {
			FlexMode = Enum.UIFlexMode.Fill,
		},
	}

	local visible = UI.state(false)

	local announce
	announce = UI.new "TextButton" {
		Parent = UI.LayerTop,
		Name = "Announcement",
		Active = false,
		AnchorPoint = UI.tween(
			UI.Theme.TweenInOut,
			UI.compute(function(use)
				return Vector2.new(0.5, if use(visible) then 0 else 1)
			end)
		),
		AutoButtonColor = false,
		BackgroundColor3 = UI.Theme.Primary,
		BackgroundTransparency = UI.Theme.Transparency,
		TextTransparency = 1,
		Text = "",

		AutomaticSize = Enum.AutomaticSize.XY,
		Position = UI.tween(
			UI.Theme.TweenInOut,
			UI.compute(function(use)
				return UDim2.new(
					0.5,
					0,
					0,
					if use(visible) then use(UI.TopbarInset).Height + use(UI.Theme.Padding).Offset else 0
				)
			end)
		),
		Size = UDim2.new(),

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
		UI.new "UIPadding" {
			PaddingLeft = UI.Theme.Padding,
			PaddingRight = UI.Theme.Padding,
			PaddingTop = UI.Theme.Padding,
			PaddingBottom = UI.Theme.Padding,
		},
		UI.new "UIListLayout" {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UI.Theme.Padding,
			HorizontalFlex = Enum.UIFlexAlignment.Fill,
		},

		UI.new "Frame" {
			Name = "Header",
			Size = UDim2.new(),
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,

			UI.new "UIListLayout" {
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UI.Theme.Padding,
				FillDirection = Enum.FillDirection.Horizontal,
			},

			UI.new "ImageLabel" {
				Name = "Icon",
				BackgroundTransparency = UI.Theme.Transparency,
				BackgroundColor3 = UI.Theme.Border,
				Size = UI.computeFrom(UDim2.fromOffset, UI.Theme.FontSizeLarger, UI.Theme.FontSizeLarger),
				Image = image,

				UI.new "UICorner" {
					CornerRadius = UDim.new(1, 0),
				},
			},

			UI.new "TextLabel" {
				Name = "From",
				BackgroundTransparency = 1,
				TextColor3 = UI.Theme.PrimaryText,
				Text = `<b>{name}</b>`,
				TextSize = UI.Theme.FontSizeLarger,
				TextTruncate = Enum.TextTruncate.SplitWord,
				TextXAlignment = "Left",
				Font = UI.Theme.Font,
				RichText = true,

				AutomaticSize = Enum.AutomaticSize.XY,
				Size = UDim2.new(),
			},

			timeLabel,
		},

		UI.new "TextLabel" {
			Name = "Message",
			BackgroundTransparency = 1,
			TextColor3 = UI.Theme.PrimaryText,
			Text = text,
			TextSize = UI.Theme.FontSize,
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

		[UI.Event] = {
			Activated = function()
				hide(announce, visible)
			end,
		},
	}

	local self = { announce, visible }
	existing = self
	visible:set(true)

	task.spawn(function()
		repeat
			timeLabel.Text = math.ceil(delay)
			delay -= task.wait(1)
		until delay <= 0 or existing ~= self
		hide(announce, visible)
	end)

	--task.delay(delay, removeExisting)
end
