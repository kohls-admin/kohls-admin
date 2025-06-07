local Logs = {}
Logs.__index = Logs

local clientTag = " <font color='#0bb'><b>CLIENT</b></font>"
local serverTag = " <font color='#b60'><b>SERVER</b></font>"
local logTypes = {
	{ "DEBUG", "#888" },
	{ "INFO", "#fff" },
	{ "WARN", "#ff0" },
	{ "ERROR", "#f00" },
	{ "CHAT", "#0f8" },
	{ "COMMAND", "#80f" },
	{ "JOIN", "#0f0" },
	{ "LEAVE", "#080" },
	{ "KILL", "#a00" },
	{ "DEATH", "#800" },
	{ "DAMAGE", "#a80" },
	{ "PURCHASE", "#0ff" },
}

local logTypeColors = {}
for _, array in logTypes do
	local logType, color = unpack(array)
	logTypeColors[logType] = color
end

function Logs.new(_K)
	local UI = _K.UI

	local function createItem(self, log)
		local tooltip = UI.new "Tooltip" {
			Font = UI.Theme.FontMono,
			Text = "Loading...",
			TextXAlignment = Enum.TextXAlignment.Left,
		}

		local itemRef = {
			_instance = UI.new "TextBox" {
				AutoLocalize = false,
				BackgroundColor3 = UI.Theme.PrimaryText,
				BackgroundTransparency = 1,
				Size = self.ItemSize,
				TextEditable = false,
				ClearTextOnFocus = false,
				Font = UI.Theme.FontMono,
				Text = "",
				TextSize = UI.Theme.FontSize,
				TextColor3 = UI.Theme.Primary,
				TextTransparency = 0.5,
				TextTruncate = Enum.TextTruncate.SplitWord,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Center,

				tooltip,

				UI.new "TextLabel" {
					AutoLocalize = false,
					BackgroundTransparency = 1,
					Size = self.ItemSize,
					RichText = true,
					Font = UI.Theme.FontMono,
					Text = "Log failed to render.",
					TextSize = UI.Theme.FontSize,
					TextColor3 = UI.Theme.PrimaryText,
					TextStrokeColor3 = UI.Theme.Primary,
					TextStrokeTransparency = UI.Theme.TextStrokeTransparency,
					TextTransparency = 0,
					TextTruncate = Enum.TextTruncate.SplitWord,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Center,
				},
			},

			tipText = "",
		}

		tooltip.Visible:hook(function()
			if tooltip.Visible._value then
				tooltip._instance.Text = itemRef.tipText
			end
		end)

		return itemRef
	end

	local function renderItem(self, itemData, log)
		if log.renderText then
			local item = itemData._instance
			item.Text = if string.find(self._filter, "^%s*$") then log.textBoxText else log.rawText
			item.TextLabel.Text = log.renderText
			itemData.tipText = log.tipText
		end
	end

	local scroller = UI.new "ScrollerFast" {
		Name = "Logs",
		List = _K.client.logs,
		Enabled = false,
		FilterInput = true,
		ReverseOrder = true,
		Visible = false,
		CreateItem = createItem,
		RenderItem = renderItem,
		ItemSize = UI.compute(function(use)
			return UDim2.new(1, 0, 0, use(UI.Theme.FontSize) + use(UI.Theme.Padding).Offset)
		end),
	}

	local logTypeFilter = {}
	for _, array in logTypes do
		logTypeFilter[array[1]] = UI.state(array[1] ~= "DEBUG" or _K.DEBUG)
	end
	-- TODO: load filter options from client datastore profile

	local escape = _K.Util.String.escapeRichText
	local function filterTest(self, list)
		local filter = string.lower(self._input._input.Text)
		self._filter = filter

		local noFilter = string.find(filter, "^%s*$")

		local new = {}
		for i, log in list do
			if not log.filterText then
				local date = os.date("%y-%m-%d", log.time)
				local timeOfDay = os.date("%X", log.time)

				log.levelText = _K.Logger:decode(log.level)

				log.rawText = `{date} {timeOfDay} {log.levelText}{if log.client
					then " CLIENT"
					elseif not log.from then " SERVER"
					else ""} {if log.name then log.name .. ": " else ""}{log.text}`

				log.textBoxText = `{timeOfDay} {log.levelText}{if log.client
					then " CLIENT"
					elseif not log.from then " SERVER"
					else ""} {if log.name then log.name .. ": " else ""}{log.text}`

				log.filterText = string.lower(log.rawText)
				log.richText =
					`<font transparency="0.5">{escape(timeOfDay)}</font> <font color="{logTypeColors[log.levelText] or "#fff"}"><b>{log.levelText}</b></font><b>{if log.client
						then clientTag
						elseif not log.from then serverTag
						else ""}</b> {if log.name then `<font transparency='0.5'>{log.name}:</font> ` else ""}{escape(
						log.text or ""
					)}`
				log.tipText = `<font transparency="0.5">{date}</font> {log.richText}`
			end

			if not logTypeFilter[log.levelText]._value then
				continue
			end

			if noFilter then
				log.renderText = log.richText
				table.insert(new, log)
			else
				local filterIndex, filterEnd = string.find(log.filterText, filter, 1, true)
				if filterIndex then
					log.renderText =
						`<font transparency="0.5">{escape(string.sub(log.rawText, 1, filterIndex - 1))}</font><b>{escape(
							string.sub(log.rawText, filterIndex, filterEnd)
						)}</b><font transparency="0.5">{escape(string.sub(log.rawText, filterEnd + 1))}</font>`
					table.insert(new, log)
				end
			end
		end

		return new
	end

	task.defer(scroller.filter, scroller, filterTest)

	local filterMenu
	local filterButton = UI.new "Button" {
		LayoutOrder = 3,
		ActiveSound = false,
		Icon = UI.Theme.Image.Filter,
		IconProperties = {
			ImageColor3 = UI.Theme.PrimaryText,
			Size = UDim2.fromScale(0.75, 0.75),
		},
		Size = UDim2.new(1, 0, 1, 0),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		UI.new "UIPadding" {
			PaddingTop = UI.Theme.PaddingHalf,
			PaddingBottom = UI.Theme.PaddingHalf,
			PaddingLeft = UI.Theme.PaddingHalf,
			PaddingRight = UI.Theme.PaddingHalf,
		},

		[UI.Event] = {
			Activated = function()
				UI.toggleState(filterMenu.Visible, "floating")
				local value = UI.peek(filterMenu.Visible)
				if value then
					UI.Sound.Hover03:Play()
				else
					UI.Sound.Hover01:Play()
				end
			end,
		},
	}

	filterMenu = UI.new "Menu" {
		Adornee = filterButton._instance,
		AutomaticSize = Enum.AutomaticSize.Y,
		RightAlign = true,
		Size = UI.compute(function(use)
			local padding = use(UI.Theme.Padding).Offset
			return UDim2.fromOffset(256 + padding * 3, 0)
		end),

		UI.new "UIPadding" {
			PaddingTop = UI.Theme.Padding,
			PaddingBottom = UI.Theme.Padding,
			PaddingLeft = UI.Theme.Padding,
			PaddingRight = UI.Theme.Padding,
		},
	}

	filterMenu._content.AutomaticSize = Enum.AutomaticSize.Y

	UI.edit(filterMenu._list, {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UI.Theme.Padding,
		Wraps = true,
	})

	local lineItemSize = UI.compute(function(use)
		return UDim2.fromOffset(128, use(UI.Theme.FontSizeLarger))
	end)

	for index, array in logTypes do
		local logType = array[1]
		UI.new "ListItem" {
			Parent = filterMenu._content,
			LayoutOrder = index,
			Text = logType,
			ContentAutomaticSize = true,
			Size = lineItemSize,

			UI.new "Checkbox" {
				Value = logTypeFilter[logType],

				[UI.Hook] = {
					Value = function(value)
						scroller._filterUpdate = true
						logTypeFilter[logType]:set(value)
						scroller:refreshList()
					end,
				},
			},
		}
	end

	for label, value in { SELECT = true, DESELECT = false } do
		UI.new "Button" {
			Parent = filterMenu._content,
			LayoutOrder = #logTypes + 1,
			Label = `<b>{label} ALL</b>`,
			Size = lineItemSize,

			[UI.Event] = {
				Activated = function()
					scroller._filterUpdate = true
					for index, array in logTypes do
						local logType = array[1]
						logTypeFilter[logType]:set(value)
						scroller:refreshList()
					end
				end,
			},
		}
	end

	UI.new "Frame" {
		Parent = scroller,
		Name = "FilterInput",

		BackgroundTransparency = 1,
		Size = UI.compute(function(use)
			return UDim2.new(1, 0, 0, use(UI.Theme.FontSize) + use(UI.Theme.PaddingDouble).Offset)
		end),

		UI.new "UIListLayout" {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UI.Theme.Padding,
			SortOrder = Enum.SortOrder.LayoutOrder,
		},
		UI.edit(scroller._input, {
			UI.new "UIFlexItem" {
				FlexMode = Enum.UIFlexMode.Fill,
			},
		}),
		filterButton,
	}

	UI.edit(scroller._scroller, {
		UI.new "UIFlexItem" {
			FlexMode = Enum.UIFlexMode.Fill,
		},
	})

	scroller.logTypeFilter = logTypeFilter

	return scroller
end

return Logs
