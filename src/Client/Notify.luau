local _K = require(script.Parent.Parent)
local UI = _K.UI
local announcements = {}
local notifications = {}

local function resetOffset(announce: boolean?)
	local heightOffset = 0
	for i, list in ipairs(if announce then announcements else notifications) do
		local card, _, offset = unpack(list)
		offset(heightOffset, true)
		heightOffset += card.AbsoluteSize.Y + UI.Theme.Padding:peek().Offset
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
	task.delay(1 + UI.Theme.TweenOut:peek().Time, card.Destroy, card)
end

return function(dialogOverride)
	if type(dialogOverride) ~= "table" then
		return
	end

	if not dialogOverride.Text then
		dialogOverride.Text = "No text provided"
	end

	local visible = UI.signal(false)
	local offset = UI.signal(0)
	local self

	local activated = dialogOverride.Activated
	local announce = dialogOverride.Announce
	local closeCallback = dialogOverride.Close
	local from = dialogOverride.From
	local name = dialogOverride.Name
	local image = dialogOverride.Image
	local sound = dialogOverride.Sound
	local userFrame = dialogOverride.UserFrame
	dialogOverride.Activated = nil
	dialogOverride.Announce = nil
	dialogOverride.Close = nil
	dialogOverride.From = nil
	dialogOverride.Name = nil
	dialogOverride.Image = nil
	dialogOverride.Sound = nil
	dialogOverride.UserFrame = nil

	local function close()
		if not self then
			return
		end
		if closeCallback then
			task.spawn(closeCallback, self)
		end
		hide(self, announce)
	end

	if announce and not dialogOverride.TextSize then
		dialogOverride.TextSize = _K.UI.Theme.FontSizeLarge
	end

	local dialog
	-- not owned by the card: destroyed with it by the __CLEAN below, once hide()'s delayed Destroy ends the animation
	local position = if announce
		then UI.spring(function()
			local padding = UI.Theme.Padding().Offset
			local height = UI.TopbarInset().Height
			local y = if visible() then padding + offset() + dialog._instance.AbsoluteSize.Y else -height - 32
			return UDim2.new(0.5, 0, 0, y)
		end, 8 / math.pi, 0.5)
		else UI.spring(function()
			local padding = UI.Theme.Padding().Offset
			return UDim2.new(1, if visible() then -padding else 256 + 32, 1, -(padding + offset()))
		end, 8 / math.pi, 0.625)

	dialog = UI.new("Dialog")(_K.Util.Table.merge({
		Parent = UI.LayerTopInset,
		Close = close,
		Duration = 4 + 0.0625 * #dialogOverride.Text,
		ExitButton = true,

		Size = UDim2.fromScale(0.5, 0),
		AnchorPoint = if announce then Vector2.new(0.5, 1) else Vector2.new(1, 1),
		Position = position,
		if announce then UI.padding(UI.Theme.Padding) else nil,
	}, dialogOverride))
	UI.edit(dialog._instance)({ __CLEAN = { position, visible, offset } })

	if type(activated) == "function" then
		dialog._instance.Active = true
		dialog._instance.Activated:Once(function()
			task.spawn(activated)
			close()
		end)
	end

	UI.sizeConstraint({
		max = Vector2.new(if announce then 512 else 256, 9e9),
	}).Parent = dialog._instance

	UI.Haptic.Notification:Play()

	if userFrame or from then
		userFrame = if userFrame then _K.client.UserFrame(unpack(userFrame)) else _K.client.UserFrame(from, name, image)
		UI.edit(userFrame)({
			Parent = dialog,

			UI.list {
				direction = "x",
				gap = 4,
			},
			UI.new "Spacer" {
				LayoutOrder = 8,
			},
			dialog._exitButton,
		})
	end

	local list = if announce then announcements else notifications

	self = { dialog._instance, visible, offset, dialogOverride.Duration }
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
