local Logs = {}
Logs.__index = Logs

local filterRichFormat = `<font transparency="0.5">%s</font><b>%s</b><font transparency="0.5">%s</font>`
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
	local escape = _K.Util.String.escapeRichText

	local logTypeFilter = {}
	for _, array in logTypes do
		logTypeFilter[array[1]] = UI.state(array[1] ~= "DEBUG" or _K.DEBUG)
	end
	-- TODO: load filter options from client datastore profile

	local scroller

	local function filterTest(self, list)
		local filter = string.lower(self._input._input.Text)
		self._filter = filter
		local new = {}
		for i, log in list do
			local levelText = _K.Logger:decode(log.level)
			if not logTypeFilter[levelText]._value then
				continue
			end

			if not log.filterText then
				local date = os.date("%y-%m-%d", log.time)
				local timeOfDay = os.date("%X", log.time)

				log.rawText = `{date} {timeOfDay} {levelText} {log.name}: {log.text}`
				log.filterText = string.lower(log.rawText)
				log.richText =
					`<font transparency="0.5">{escape(timeOfDay)}</font> <font color="{logTypeColors[levelText] or "#fff"}"><b>{levelText}</b></font><b>{if log.client
						then clientTag
						elseif not log.from then serverTag
						else ""}</b> {if log.from then `<font transparency='0.5'>{log.name}:</font> ` else ""}{escape(
						log.text or ""
					)}`
				log.tipText = `<font transparency="0.5">{date}</font> {log.richText}`
			end

			local filterIndex, filterEnd = string.find(log.filterText, filter, 1, true)
			log.filterRichText = if filterIndex
				then `<font transparency="0.5">{escape(string.sub(log.filterText, 1, filterIndex - 1))}</font><b>{escape(
					string.sub(log.filterText, filterIndex, filterEnd)
				)}</b><font transparency="0.5">{escape(string.sub(log.filterText, filterEnd + 1))}</font>`
				else `<font transparency="0.5">{log.rawText}</font>`

			if filterIndex then
				table.insert(new, log)
			end
		end
		return new
	end

	local function createItem(self, log)
		local tooltip = UI.new "Tooltip" {
			Font = UI.Theme.FontMono,
			Text = "Loading...",
			TextXAlignment = Enum.TextXAlignment.Left,
		}
		return UI.new "TextLabel" {
			AutoLocalize = false,
			BackgroundTransparency = 1,
			Size = self.ItemSize,
			RichText = true,
			Font = UI.Theme.FontMono,
			TextSize = UI.Theme.FontSize,
			TextColor3 = UI.Theme.PrimaryText,
			TextTruncate = Enum.TextTruncate.SplitWord,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,

			tooltip,

			UI.new "ObjectValue" {
				Name = "TooltipRef",
				Value = tooltip._instance,
			},
		}
	end

	local function renderItem(self, item, log)
		item.Text = if self._filter ~= "" then log.filterRichText else log.richText
		if item:FindFirstChild("TooltipRef") and item.TooltipRef.Value then
			item.TooltipRef.Value.Text = log.tipText
		end
	end

	scroller = UI.new "ScrollerFast" {
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

	task.defer(scroller.filter, scroller, filterTest)

	local filterMenu
	local filterButton = UI.new "Button" {
		LayoutOrder = 3,
		ActiveSound = false,
		Icon = "rbxassetid://18854695275",
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
		RightAlign = true,
		Size = UI.compute(function(use)
			local padding = use(UI.Theme.Padding).Offset
			return UDim2.fromOffset(256 + padding * 3, (24 + padding) * math.ceil(#logTypes / 2) + padding)
		end),

		UI.new "UIPadding" {
			PaddingTop = UI.Theme.Padding,
			PaddingBottom = UI.Theme.Padding,
			PaddingLeft = UI.Theme.Padding,
			PaddingRight = UI.Theme.Padding,
		},
	}

	UI.edit(filterMenu._list, {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UI.Theme.Padding,
		Wraps = true,
	})

	for index, array in logTypes do
		local logType = array[1]
		UI.new "ListItem" {
			Parent = filterMenu._menu,
			LayoutOrder = index,
			Text = logType,
			ContentAutomaticSize = true,
			Size = UDim2.fromOffset(128, 24),

			UI.new "Checkbox" {
				Value = logTypeFilter[logType],

				[UI.Hook] = {
					Value = function(value)
						logTypeFilter[logType]:set(value)
						scroller:refreshList()
					end,
				},
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
