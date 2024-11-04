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
	local UI = _K.UI
	local escape = _K.Util.String.escapeRichText

	local function createItem(self, command)
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

			UI.new "TextLabel" {
				AutoLocalize = false,
				BackgroundTransparency = 1,
				Name = "Description",
				RichText = true,
				Font = UI.Theme.FontMono,
				TextSize = UI.Theme.FontSize,
				TextColor3 = UI.Theme.PrimaryText,
				TextTruncate = Enum.TextTruncate.SplitWord,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
				Size = UI.compute(function(use)
					local size = use(UI.Theme.FontSize)
					return UDim2.new(1, -size, 0, size)
				end),
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
		local aliasText = command.aliasText

		if not aliasText then
			aliasText = if command.aliases and #command.aliases > 0
				then `[{table.concat(command.aliases, ", ")}]`
				else ""
			command.aliasText = aliasText
		end

		local argNames = command.argNames
		local argTooltip = command.argTooltip

		if not argNames then
			argNames = table.create(#command.args)
			argTooltip = table.create(#command.args)

			if #command.args > 0 then
				table.insert(argTooltip, "")
			end

			for _, arg in command.args do
				table.insert(argNames, if arg.optional then arg.name .. "?" else arg.name)
				table.insert(
					argTooltip,
					`\n<b><sc>{arg.name}</sc> <font transparency="0.66"><i>&lt;{arg.type}&gt;</i></font></b>\n{arg.description}`
				)
				if arg.optional then
					table.insert(argTooltip, `\t<font transparency="0.5"><b>optional:</b> true</font>`)
				end
				if arg.ignoreSelf then
					table.insert(argTooltip, `\t<font transparency="0.5"><b>ignoreSelf:</b> true</font>`)
				end
				if arg.lowerRank then
					table.insert(argTooltip, `\t<font transparency="0.5"><b>lowerRank:</b> true</font>`)
				end
				if arg.shouldRequest then
					table.insert(argTooltip, `\t<font transparency="0.5"><b>shouldRequest:</b> true</font>`)
				end
			end

			argNames = table.concat(argNames, " ")
			argTooltip = table.concat(argTooltip, "\n")
			command.argNames = argNames
			command.argTooltip = argTooltip
		end

		local roleString = command.roleString
		local roleColor = command.roleColor

		if not roleString then
			local roles = {}
			for role, _roleData in _K.Data.roles do
				if _K.Auth.roleCanUseCommand(role, command) then
					table.insert(roles, role)
				end
			end

			table.sort(roles, function(a, b)
				return _K.Data.roles[a]._rank < _K.Data.roles[b]._rank
			end)

			roleColor = if #roles > 0 then Color3.fromHex(_K.Data.roles[roles[1]].color) else UI.peek(UI.Theme.Primary)
			command.roleColor = roleColor

			for i, role in roles do
				local roleData = _K.Data.roles[role]
				roles[i] = `<font color="{roleData.color}">{roleData.name}</font>`
			end

			roleString = table.concat(roles, ", ")
			command.roleString = roleString
		end

		local color = if command.LocalPlayerAuthorized
			then roleColor
			else roleColor:Lerp(UI.peek(UI.Theme.Primary), 0.5)
		item.TextColor3 = color
		item.Description.TextColor3 = color

		local credit = command.creditString
		if not credit then
			credit = command.credit or "Kohl @Scripth"
			if type(credit) == "table" then
				credit = table.concat(credit, ", ")
			end
			command.creditString = credit
		end

		local tipString = command.tipString
		if not tipString then
			tipString =
				`<b>Restricted to:</b> {roleString}{argTooltip}\n\n<font transparency="0.5"><b>Credit:</b> {credit}</font>`
			command.tipString = tipString
		end

		if self._filter ~= "" then
			local text = `{_K.Data.settings.prefix}{command.name} {argNames} {aliasText}`
			local filterFound = string.find(string.lower(text), self._filter)
			item.Text = if filterFound
				then string.format(
					filterRichFormat,
					escape(string.sub(text, 1, filterFound - 1)),
					escape(string.sub(text, filterFound, filterFound + #self._filter - 1)),
					escape(string.sub(text, filterFound + #self._filter))
				)
				else `<font transparency="0.5">{text}</font>`
			local descFound = string.find(string.lower(command.description), self._filter)
			-- TODO: make something that remove richtext tags to prevent highlight filter
			item.Description.Text = if descFound
				then string.format(
					filterRichFormat,
					string.sub(command.description, 1, descFound - 1),
					string.sub(command.description, descFound, descFound + #self._filter - 1),
					string.sub(command.description, descFound + #self._filter)
				)
				else `<font transparency="0.5">{command.description}</font>`
			item.TooltipRef.Value.Text = tipString
			return
		end

		item.Text = string.format(
			commandRichFormat,
			escape(_K.Data.settings.prefix .. command.name .. " " .. argNames),
			escape(aliasText)
		)
		item.Description.Text = `<font transparency="0.33">{command.description}</font>`
		item.TooltipRef.Value.Text = tipString
	end

	local scroller = UI.new "ScrollerFast" {
		Name = "Commands",
		List = _K.Registry.commandsList,
		Enabled = false,
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
		local filter = string.lower(scroller._input._input.Text)
		self._filter = filter

		local new = {}
		for _, command in list do
			local aliasText = command.aliasText
			if not aliasText then
				aliasText = if command.aliases and #command.aliases ~= 0
					then "/" .. table.concat(command.aliases, "/")
					else ""
				command.aliasText = aliasText
			end

			local text = `{_K.Data.settings.prefix}{command.name}{aliasText} {command.description}`
			if text:lower():find(filter, 1, true) then
				table.insert(new, command)
			end
		end

		return new
	end

	task.defer(function()
		scroller:sort(function(a, b)
			local rankA, rankB = math.huge, math.huge
			for role, roleData in _K.Data.roles do
				if _K.Auth.roleCanUseCommand(role, a) and roleData._rank < rankA then
					rankA = roleData._rank
				end
				if _K.Auth.roleCanUseCommand(role, b) and roleData._rank < rankB then
					rankB = roleData._rank
				end
			end
			return rankA < rankB
		end)
		scroller:filter(filterTest)
	end)

	return scroller
end

return Commands
