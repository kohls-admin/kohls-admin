local _K = require(script.Parent.Parent)
local UI = _K.UI
local announcements = {}
local notifications = {}

local function resetOffset(announce: boolean?)
	local heightOffset = 0
	for i, list in ipairs(if announce then announcements else notifications) do
		local card, _, offset = unpack(list)
		offset(heightOffset, true)
		heightOffset += card.AbsoluteSize.Y + UI.Theme.Padding._value.Offset
	end
	return heightOffset
end

local function hide(info, announce: boolean?)
	local list = if announce then announcements else notifications
	local card, visible = unpack(info)
	local found = table.find(list, info)
	if not found then
		return
	end
	UI.Sound.Swipe:Play()

	table.remove(list, found)
	resetOffset(announce)
	card.ZIndex = -1
	visible(nil)
	task.delay(1 + UI.Theme.TweenOut._value.Time, card.Destroy, card)
end

return function(dialogOverride)
	local visible = UI.state(false)
	local offset = UI.state(0)
	local self

	local announce = dialogOverride.Announce
	local duration = dialogOverride.Duration
	local from = dialogOverride.From
	local name = dialogOverride.Name
	local image = dialogOverride.Image
	local sound = dialogOverride.Sound
	local userFrame = dialogOverride.UserFrame
	dialogOverride.Announce = nil
	dialogOverride.From = nil
	dialogOverride.Name = nil
	dialogOverride.Image = nil
	dialogOverride.Sound = nil
	dialogOverride.UserFrame = nil

	local function close()
		if not self then
			return
		end
		hide(self, announce)
	end

	local dialog
	dialog = UI.new("Dialog")(_K.Util.Table.merge({
		Parent = UI.LayerTopInset,
		Close = close,
		Duration = 4 + 0.0625 * #dialogOverride.Text,
		ExitButton = true,

		Size = UDim2.fromScale(0.5, 0),
		AnchorPoint = if announce then Vector2.new(0.5, 1) else Vector2.new(1, 1),
		Position = if announce
			then UI.spring(function()
				local padding = UI.Theme.Padding().Offset
				local height = UI.TopbarInset().Height
				local y = if visible() then padding + offset() + dialog._instance.AbsoluteSize.Y else -height - 32
				return UDim2.new(0.5, 0, 0, y)
			end, 16, 0.5)
			else UI.spring(function()
				local padding = UI.Theme.Padding().Offset
				return UDim2.new(1, if visible() then -padding else 256 + 32, 1, -(padding + offset()))
			end, 16, 0.625),
		if announce
			then UI.new "UIPadding" {
				PaddingLeft = UI.Theme.Padding,
				PaddingRight = UI.Theme.Padding,
				PaddingTop = UI.Theme.Padding,
				PaddingBottom = UI.Theme.Padding,
			}
			else nil,
	}, dialogOverride))

	UI.new "UISizeConstraint" {
		Parent = dialog._instance,
		MaxSize = Vector2.new(if announce then 512 else 256, 9e9),
	}

	UI.Haptic.Notification:Play()

	if userFrame or from then
		userFrame = if userFrame then _K.client.UserFrame(unpack(userFrame)) else _K.client.UserFrame(from, name, image)
		UI.edit(userFrame, {
			Parent = dialog,

			UI.new "UIListLayout" {
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 4),
				FillDirection = Enum.FillDirection.Horizontal,
			},
			UI.new "Spacer" {
				LayoutOrder = 8,
			},
			dialog._exitButton,
		})
	end

	local list = if announce then announcements else notifications

	self = { dialog._instance, visible, offset, duration }
	table.insert(list, 1, self)
	task.defer(function()
		visible(true)
	end)

	if resetOffset(announce) > UI.LayerTopInset.AbsoluteSize.Y / (if announce then 2 else 1) then
		for index = #list, 1, -1 do
			local _card, _visible, _offset, delay = unpack(list[index])
			if delay == 0 then
				continue
			end
			hide(list[index], announce)
			break
		end
	end

	UI.Sound[sound or if announce then "Notification_Low" else "Notification_High"]:Play()

	return dialog
end
