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
			heightOffset = height + UI.Theme.Padding._value.Offset
		else
			heightOffset += card.AbsoluteSize.Y + UI.Theme.Padding._value.Offset
		end
	end
	return heightOffset
end

local function hide(info, height: number?)
	local announce, visible, _offset = unpack(info)
	local found = table.find(existing, info)
	if not found then
		return
	end

	_K.client.Sound.Hover01:Play()

	table.remove(existing, found)
	resetOffset(height)
	announce.ZIndex = -1
	visible:set(nil)
	task.delay(1 + UI.Theme.TweenOut._value.Time, announce.Destroy, announce)
end

return function(dialogOverride)
	local visible = UI.state(true)
	local offset = UI.state(0)
	local self

	local function close()
		hide(self)
	end

	local userFrame = dialogOverride.UserFrame
	dialogOverride.UserFrame = nil

	local dialog = UI.new("Dialog")(_K.Util.Table.merge({
		Close = close,
		Duration = 30,
		Parent = UI.LayerTopInset,
		Size = UDim2.new(0.5),
		AnchorPoint = UI.tween(
			UI.Theme.TweenInOut,
			UI.compute(function(use)
				return Vector2.new(if use(visible) then 1 else 0, 1)
			end)
		),
		Position = UI.tween(
			UI.Theme.TweenInOut,
			UI.compute(function(use)
				local padding = use(UI.Theme.Padding).Offset
				local visible = use(visible)
				local offset = use(offset)
				return UDim2.new(1, if use(visible) then -padding else 0, 1, -(padding + offset))
			end)
		),
		Visible = false,
	}, dialogOverride))

	UI.new "UISizeConstraint" {
		Parent = dialog._instance,
		MaxSize = Vector2.new(256, 9e9),
	}

	if userFrame then
		userFrame = UserFrame(unpack(userFrame))
		UI.edit(userFrame, {
			Parent = dialog,
			UI.new "Frame" {
				LayoutOrder = 8,
				Name = "Spacer",
				BackgroundTransparency = 1,
				UI.new "UIFlexItem" {
					FlexMode = Enum.UIFlexMode.Fill,
				},
			},
			dialog._exitButton,
		})
	end

	self = { dialog._instance, visible, offset }
	table.insert(existing, 1, self)

	local height = dialog._instance.AbsoluteSize.Y
	visible:set(false, true, true)
	dialog._instance.Visible = true
	visible:set(true)

	resetOffset(height)

	_K.client.Sound.Notification_High:Play()

	return dialog
end
