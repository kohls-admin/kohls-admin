local Commands = {}
Commands.__index = Commands

local commandRichFormat = `<b>%s</b> <font transparency="0.66">%s</font>`
local filterRichFormat = `<font transparency="0.5">%s</font><b>%s</b><font transparency="0.5">%s</font>`

local function _argsString(command)
	if not command.args or #command.args == 0 then
		return ""
	end
	local argTypes = {}
	for _, arg in command.args do
		table.insert(argTypes, arg.type)
	end
	return " <" .. table.concat(argTypes, "> <") .. ">"
end

function Commands.new(_K)
	local UI = _K.client.UI
	local escape = _K.Util.String.escapeRichText

	-- TODO: sort by role rank

	-- command arg names [aliases]
	-- description
	-- roles with access

	local function createItem(self, command)
		local tooltip = UI.new "Tooltip" {
			Text = "roles that can use this command :)",
		}
		return UI.new "TextLabel" {
			BackgroundTransparency = 1,
			Size = self.ItemSize,
			RichText = true,
			Font = UI.Theme.FontMono,
			TextSize = UI.Theme.FontSize,
			TextColor3 = UI.Theme.PrimaryText,
			TextTruncate = Enum.TextTruncate.SplitWord,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,

			UI.new "TextLabel" {
				BackgroundTransparency = 1,
				Name = "Description",
				RichText = true,
				Font = UI.Theme.FontMono,
				TextSize = UI.Theme.FontSize,
				TextColor3 = UI.Theme.PrimaryText,
				TextTruncate = Enum.TextTruncate.SplitWord,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
				Size = UI.computeFrom(UDim2.new, 1, 0, 0, UI.Theme.FontSize),
				Position = UI.compute(function(use)
					local size = use(UI.Theme.FontSize)
					return UDim2.new(0, size, 0, size)
				end),
			},

			tooltip,

			UI.new "ObjectValue" {
				Name = "TooltipRef",
				Value = tooltip._instance,
			},
		}
	end

	local function renderItem(self, item, command)
		if self._filter ~= "" then
			local aliasText = if command.aliases and #command.aliases > 0
				then "/" .. table.concat(command.aliases, "/")
				else ""
			local text = `{_K.Data.settings.prefix}{command.name}{aliasText} {command.description}`
			local filterFound = string.find(text:lower(), self._filter)
			item.Text = if filterFound
				then string.format(
					filterRichFormat,
					escape(string.sub(text, 1, filterFound - 1)),
					escape(string.sub(text, filterFound, filterFound + #self._filter - 1)),
					escape(string.sub(text, filterFound + #self._filter))
				)
				else text
			return
		end

		local argNames = table.create(#command.args)
		for _, arg in command.args do
			table.insert(argNames, arg.name)
		end

		item.Text = string.format(
			commandRichFormat,
			escape(_K.Data.settings.prefix .. command.name .. " " .. table.concat(argNames, " ")),
			escape(if command.aliases and #command.aliases > 0 then `[{table.concat(command.aliases, ", ")}]` else "")
		)
		item.Description.Text = `<font transparency="0.33">{escape(command.description)}</font>`
		item.TooltipRef.Value.Text = "TODO show example usage, roles, and credit"
	end

	local scroller = UI.new "ScrollerFast" {
		Name = "Commands",
		List = _K.Registry.commandsList,
		FilterInput = true,
		ItemSize = UI.compute(function(use)
			return UDim2.new(1, 0, 0, use(UI.Theme.FontSize) * 2)
		end),
		CreateItem = createItem,
		RenderItem = renderItem,
	}

	UI.edit(scroller._scroller, {
		UI.new "UIFlexItem" {
			FlexMode = Enum.UIFlexMode.Fill,
		},
	})

	local function filterTest(self, list)
		local filter = scroller._input.Value._value:lower()
		self._filter = filter
		local new = {}
		for _, command in list do
			local aliasText = if command.aliases and #command.aliases ~= 0
				then "/" .. table.concat(command.aliases, "/")
				else ""
			local text = `{_K.Data.settings.prefix}{command.name}{aliasText} {command.description}`
			if text:lower():find(filter, 1, true) then
				table.insert(new, command)
			end
		end
		return new
	end

	scroller:filter(filterTest)

	return scroller
end

return Commands
