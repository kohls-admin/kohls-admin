local _K = require(script.Parent.Parent)
local UI = _K.UI
local announcements = {}
local notifications = {}

local function resetOffset(announce: boolean?)
	local heightOffset = 0
	for i, list in ipairs(if announce then announcements else notifications) do
		local card, _, offset = unpack(list)
		offset:set(heightOffset, true)
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
	visible:set(nil)
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

	local dialog = UI.new("Dialog")(_K.Util.Table.merge({
		Parent = UI.LayerTopInset,
		Close = close,
		Duration = 4 + 0.0625 * #dialogOverride.Text,
		ExitButton = true,

		Size = UDim2.fromScale(0.5, 0),
		AnchorPoint = UI.tween(
			UI.Theme.TweenInOut,
			UI.compute(function(use)
				return if announce
					then Vector2.new(0.5, if use(visible) then 0 else 1)
					else Vector2.new(if use(visible) then 1 else 0, 1)
			end)
		),
		Position = UI.tween(
			UI.Theme.TweenInOut,
			UI.compute(function(use)
				local padding = use(UI.Theme.Padding).Offset
				if announce then
					local height = use(UI.TopbarInset).Height
					local heightOffset = use(offset)
					return UDim2.new(0.5, 0, 0, if use(visible) then padding + heightOffset else -height)
				else
					return UDim2.new(1, if use(visible) then -padding else 0, 1, -(padding + use(offset)))
				end
			end)
		),
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

	if userFrame or from then
		userFrame = if userFrame
			then _K.client.UserFrame(unpack(userFrame))
			else _K.client.UserFrame(if from ~= "_K" then from else nil, name, image)
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
	visible:set(true)

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
