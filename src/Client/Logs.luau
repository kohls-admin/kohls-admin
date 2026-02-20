local UI = require(script.Parent:WaitForChild("UI"))

local Logs = {}
Logs.__index = Logs

local clientTag = " <font color='#0bb'><b>CLIENT</b></font>"
local serverTag = " <font color='#b60'><b>SERVER</b></font>"
local globalTag = " <font color='#0b6'><b>GLOBAL</b></font>"
local logTypes = {
	{ "DEBUG", "#888" },
	{ "INFO", "#ccc" },
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
	local function createItem(self, log)
		local tooltip = UI.new "Tooltip" {
			Text = "Loading...",
		}

		local cleanup = { tooltip }

		local itemRef = {
			_instance = UI.new "TextBox" {
				AutoLocalize = false,
				BackgroundColor3 = UI.Theme.PrimaryText,
				BackgroundTransparency = 1,
				Size = self.ItemSize,
				TextEditable = false,
				ClearTextOnFocus = false,
				FontFace = UI.Theme.FontMono,
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
					FontFace = UI.Theme.FontMono,
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

			[UI.Clean] = cleanup,
		}

		table.insert(
			cleanup,
			tooltip.Visible:Connect(function()
				if tooltip.Visible._value then
					tooltip.Text(itemRef.tipText)
				end
			end)
		)

		return itemRef
	end

	local escape = _K.Util.String.escapeRichText

	local function renderItem(self, itemData, log)
		if not log.filterText or #log < 3 then
			return
		end

		local item = itemData._instance
		local date = os.date("%y-%m-%d", log[3])
		local timeOfDay = os.date("%X", log[3])
		local level = _K.Logger:decode(log[2])

		local preText =
			`<font transparency="0.5">{escape(timeOfDay)}</font> <font color="{logTypeColors[level] or "#fff"}"><b>{level}</b></font><b>{if log[6]
				then clientTag
				elseif not log[5] then if log[6] == nil then serverTag else globalTag
				else ""}</b>`

		local postText = `{if log[5] then `<font transparency='0.5'>{log[5]}:</font> ` else ""}{escape(log[1] or "")}`

		itemData.tipText = `<font transparency="0.5">{date}</font> {preText}\n{postText}`

		local rawText = `{timeOfDay} {level}{if log[6]
			then " CLIENT"
			elseif not log[4] then if log[6] == nil then " SERVER" else " GLOBAL"
			else ""} {if log[5] then log[5] .. ": " else ""}{log[1]}`

		if self._noFilter then
			item.Text = rawText
			item.TextLabel.Text = `{preText} {postText}`
		else
			local filterIndex, filterEnd = string.find(log.filterText, self._filter, 1, true)
			rawText = `{date} {rawText}`

			item.Text = `{timeOfDay} {level}{if log[6]
				then " CLIENT"
				elseif not log[4] then if log[6] == nil then " SERVER" else " GLOBAL"
				else ""} {if log[5] then log[5] .. ": " else ""}{log[1]}`

			item.TextLabel.Text =
				`<font transparency="0.5">{escape(string.sub(rawText, 1, filterIndex - 1))}</font><b>{escape(
					string.sub(rawText, filterIndex, filterEnd)
				)}</b><font transparency="0.5">{escape(string.sub(rawText, filterEnd + 1))}</font>`
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
		ItemSize = function()
			return UDim2.new(1, 0, 0, UI.Theme.FontSize() + UI.Theme.Padding().Offset)
		end,
	}

	local logTypeFilter = {}
	for _, array in logTypes do
		logTypeFilter[array[1]] = UI.state(array[1] ~= "DEBUG" or _K.DEBUG)
	end
	scroller.logTypeFilter = logTypeFilter
	-- TODO: load filter options from client datastore profile

	local function filterTest(self, list)
		local filter = string.lower(self._input._input.Text)
		self._filter = filter

		local noFilter = string.find(filter, "^%s*$")
		self._noFilter = noFilter

		local new = {}
		for i, log in list do
			local level = _K.Logger:decode(log[2])

			if not log.filterText then
				local date = os.date("%y-%m-%d", log[3])
				local timeOfDay = os.date("%X", log[3])

				log.filterText = string.lower(
					`{date} {timeOfDay} {level}{if log[6]
						then " CLIENT"
						elseif not log[4] then if log[6] == nil then " SERVER" else " GLOBAL"
						else ""} {if log[5] then log[5] .. ": " else ""}{log[1]}`
				)
			end

			if not logTypeFilter[level]._value then
				continue
			end

			if noFilter then
				table.insert(new, log)
			elseif string.find(log.filterText, filter, 1, true) then
				table.insert(new, log)
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
		},
		Size = UDim2.new(1, 0, 1, 0),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,

		UI.new "UIPadding" {
			PaddingTop = UI.Theme.Padding,
			PaddingBottom = UI.Theme.Padding,
			PaddingLeft = UI.Theme.Padding,
			PaddingRight = UI.Theme.Padding,
		},

		Activated = function()
			UI.toggleState(filterMenu.Visible, "floating")
			local value = UI.raw(filterMenu.Visible)
			if value then
				UI.Sound.Hover03:Play()
			else
				UI.Sound.Hover01:Play()
			end
		end,
	}

	UI.new "Tooltip" { Parent = filterButton, Text = "Filter Logs", Hovering = filterButton._hovering }
	UI.edit(filterButton._instance.UICorner, { CornerRadius = UI.Theme.CornerPadded })

	filterMenu = UI.new "Menu" {
		Adornee = filterButton._instance,
		AutomaticSize = Enum.AutomaticSize.Y,
		RightAlign = true,
		Size = function()
			local padding = UI.Theme.Padding().Offset
			return UDim2.fromOffset(256 + padding * 3, 0)
		end,

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

	local lineItemSize = UI.compute(function()
		return UDim2.fromOffset(128, UI.Theme.FontSizeLarger())
	end)

	for index, array in logTypes do
		local logType = array[1]
		UI.new "ListItem" {
			Parent = filterMenu._content,
			LayoutOrder = index,
			Text = logType,
			Size = lineItemSize,

			UI.new "Checkbox" {
				Value = logTypeFilter[logType],

				[UI.Hook] = {
					Value = function(value)
						scroller._filterUpdate = true
						logTypeFilter[logType](value)
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

			Activated = function()
				scroller._filterUpdate = true
				for index, array in logTypes do
					local logType = array[1]
					logTypeFilter[logType](value)
					scroller:refreshList()
				end
			end,
		}
	end

	scroller._input._instance = UI.new "Frame" {
		Parent = scroller,
		Name = "FilterInput",

		BackgroundTransparency = 1,
		Size = function()
			return UDim2.new(1, 0, 0, UI.Theme.FontSize() + UI.Theme.PaddingDouble().Offset)
		end,

		UI.new "UIListLayout" {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UI.Theme.PaddingWithStroke,
			SortOrder = Enum.SortOrder.LayoutOrder,
		},
		UI.edit(scroller._input, { UI.new "UIFlexItem" { FlexMode = Enum.UIFlexMode.Fill } }),
		filterButton,
	}

	return scroller
end

return Logs
