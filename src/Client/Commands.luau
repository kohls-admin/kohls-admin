local Commands = {}
Commands.__index = Commands

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
		local itemRef = {
			_instance = UI.new "TextLabel" {
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

	local function renderItem(self, itemData, command)
		if not command.richText then
			return
		end

		itemData.tipText = command.tipText
		local item = itemData._instance
		item.TextColor3 = command.roleColorAuth
		item.Description.TextColor3 = command.roleColorAuth

		if self._filter ~= "" then
			item.Text = command.filterRichText
			item.Description.Text = command.filterRichDesc
		else
			item.Text = command.richText
			item.Description.Text = command.richDesc
		end
	end

	local commandsList = UI.state(_K.Registry.commandsList)
	local function updateCommandsList()
		if _K.client.settings.onlyShowUsableCommands._value then
			local list = {}
			for _, command in _K.Registry.commandsList do
				local added
				for role, roleData in _K.Data.roles do
					if
						(roleData.assets or roleData.gamepasses or roleData.subscriptions)
						and _K.Auth.roleCanUseCommand(role, command)
					then
						table.insert(list, command)
						added = true
						break
					end
				end
				if not added and _K.Auth.hasCommand(UI.LocalPlayer.UserId, command) then
					table.insert(list, command)
				end
			end
			commandsList:set(list)
		else
			commandsList:set(_K.Registry.commandsList)
		end
	end
	_K.client.settings.onlyShowUsableCommands:hook(updateCommandsList)
	_K.client.rank:hook(updateCommandsList)
	updateCommandsList()

	local scroller = UI.new "ScrollerFast" {
		Name = "Commands",
		List = commandsList,
		Enabled = false,
		FilterInput = true,
		Visible = false,
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

	local function updateRenderParameters(command)
		if not command.aliasText then
			command.aliasText = if command.aliases and #command.aliases ~= 0
				then table.concat(command.aliases, ", ")
				else ""

			command.argNames = table.create(#command.args)
			command.argTooltip = table.create(#command.args)

			if #command.args > 0 then
				table.insert(command.argTooltip, "")
			end

			for _, arg in command.args do
				table.insert(command.argNames, if arg.optional then arg.name .. "?" else arg.name)
				table.insert(
					command.argTooltip,
					`\n<b><sc>{arg.name}</sc> <font transparency="0.66"><i>&lt;{arg.type}{if arg.optional
						then `?`
						else ""}&gt;</i></font></b>\n{arg.description}`
				)
				if arg.ignoreSelf then
					table.insert(command.argTooltip, `\t<font transparency="0.5"><b>ignoreSelf:</b> true</font>`)
				end
				if arg.lowerRank then
					table.insert(command.argTooltip, `\t<font transparency="0.5"><b>lowerRank:</b> true</font>`)
				end
				if arg.shouldRequest and _K.Data.settings.commandRequests ~= false then
					table.insert(command.argTooltip, `\t<font transparency="0.5"><b>shouldRequest:</b> true</font>`)
				end
			end

			command.argNames = table.concat(command.argNames, " ")
			command.argTooltip = table.concat(command.argTooltip, "\n")

			local roles = {}
			for role, _roleData in _K.Data.roles do
				if _K.Auth.roleCanUseCommand(role, command) then
					table.insert(roles, role)
				end
			end

			table.sort(roles, function(a, b)
				return _K.Data.roles[a]._rank < _K.Data.roles[b]._rank
			end)

			command.roleColor = if #roles > 0
				then Color3.fromHex(_K.Data.roles[roles[1]].color)
				else UI.peek(UI.Theme.Primary)

			for i, role in roles do
				local roleData = _K.Data.roles[role]
				roles[i] = `<font color="{roleData.color}">{roleData.name}</font>`
			end

			command.roleText = table.concat(roles, ", ")

			local credit = command.credit or "Kohl @Scripth"
			command.creditText = if type(credit) == "table" then table.concat(credit, ", ") else credit
			command.tipText =
				`<b>Restricted to:</b> {command.roleText}{command.argTooltip}\n\n<font transparency="0.5"><b>Credit:</b> {command.creditText}</font>`

			command.rawTextNoAlias = `{_K.getCommandPrefix()}{command.name} {command.argNames}`
			command.rawText = `{command.rawTextNoAlias} {command.aliasText}`

			command.richText =
				`<b>{escape(command.rawTextNoAlias)}</b> <font transparency="0.66">{escape(command.aliasText)}</font>`
			command.richDesc = `<font transparency="0.33">{command.description}</font>`

			command.filterTest = string.lower(`{command.rawText} {command.description}`)
			command.filterText = string.lower(command.rawText)
			command.filterDesc = string.lower(command.description)
		end

		command.roleColorAuth = if command.LocalPlayerAuthorized
			then command.roleColor
			else command.roleColor:Lerp(UI.peek(UI.Theme.Primary), 0.5)
	end

	local function filterTest(self, list)
		local filter = string.lower(scroller._input._input.Text)
		self._filter = filter

		local new = {}
		for _, command in list do
			updateRenderParameters(command)
			if string.find(command.filterTest, filter, 1, true) then
				local filterFound = string.find(command.filterText, self._filter, 1, true)
				command.filterRichText = if filterFound
					then string.format(
						filterRichFormat,
						escape(string.sub(command.rawText, 1, filterFound - 1)),
						escape(string.sub(command.rawText, filterFound, filterFound + #self._filter - 1)),
						escape(string.sub(command.rawText, filterFound + #self._filter))
					)
					else `<font transparency="0.5">{command.rawText}</font>`

				local descFound = string.find(command.filterDesc, self._filter, 1, true)
				command.filterRichDesc = if descFound
					then string.format(
						filterRichFormat,
						escape(string.sub(command.description, 1, descFound - 1)),
						escape(string.sub(command.description, descFound, descFound + #self._filter - 1)),
						escape(string.sub(command.description, descFound + #self._filter))
					)
					else `<font transparency="0.5">{command.description}</font>`

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
			if rankA == rankB then
				return a._listIndex < b._listIndex
			else
				return rankA < rankB
			end
		end)
		scroller:filter(filterTest)
	end)

	return scroller
end

return Commands
