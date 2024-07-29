local Players = game:GetService("Players")
local TextService = game:GetService("TextService")

local _K = require(script.Parent.Parent)
local UI = require(script.Parent.Parent.Flux.UI)
local UserFrame = require(script.Parent.UserFrame)
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

	local visible = UI.state(false)
	local offset = UI.state(0)
	local self

	local function close()
		hide(self)
	end

	local exitButton = UI.new "Button" {
		LayoutOrder = 9,
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
		Activated = close,
	}
	exitButton._instance:FindFirstChildOfClass("UIStroke"):Destroy()

	local userFrame = UserFrame(from, name, image)

	UI.edit(userFrame, {
		UI.new "Frame" {
			LayoutOrder = 8,
			Name = "Spacer",
			BackgroundTransparency = 1,
			UI.new "UIFlexItem" {
				FlexMode = Enum.UIFlexMode.Fill,
			},
		},

		exitButton,
	})

	local dialog
	dialog = UI.new "Dialog" {
		Parent = UI.LayerTop,
		Duration = delay,
		Close = close,

		Size = UDim2.new(0.5),
		AnchorPoint = UI.tween(
			UI.Theme.TweenInOut,
			UI.compute(function(use)
				return Vector2.new(0.5, if use(visible) then 0 else 1)
			end)
		),
		Position = UI.tween(
			UI.Theme.TweenInOut,
			UI.compute(function(use)
				local height = use(UI.TopbarInset).Height
				local padding = use(UI.Theme.Padding).Offset
				local offset = use(offset)
				return UDim2.new(0.5, 0, 0, if use(visible) then height + padding + offset else 0)
			end)
		),

		UI.new "Frame" {
			Name = "Content",
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.fromScale(1, 0),

			UI.new "UIPadding" {
				PaddingLeft = UI.Theme.Padding,
				PaddingRight = UI.Theme.Padding,
				PaddingTop = UI.Theme.Padding,
				PaddingBottom = UI.Theme.Padding,
			},
			UI.new "UIListLayout" {
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UI.Theme.PaddingDouble,
				HorizontalFlex = Enum.UIFlexAlignment.Fill,
			},

			userFrame,
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

	UI.new "UISizeConstraint" {
		Parent = dialog._instance,
		MaxSize = Vector2.new(512, 9e9),
	}

	self = { dialog._instance, visible, offset }
	table.insert(existing, 1, self)
	visible:set(true)

	local height =
		TextService:GetTextSize(text, UI.Theme.FontSizeLarge._value, UI.Theme.Font._value, Vector2.new(512, 9e9)).Y

	if resetOffset(height) > (UI.LayerTop.AbsoluteSize.Y - UI.TopbarInset._value.Height) / 2 then
		hide(existing[#existing], height)
	end
end
