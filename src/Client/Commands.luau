local UI = require(script.Parent:WaitForChild("UI"))

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
	local escape = _K.Util.String.escapeRichText

	local function createItem(self, command)
		local itemRef = {
			command = UI.state(command),
		}

		local textColor = function()
			return if itemRef.command().LocalPlayerAuthorized
				then UI.Theme.PrimaryText()
				else UI.Theme.PrimaryText():Lerp(UI.Theme.Primary(), 0.5)
		end

		local tooltip = UI.new "Tooltip" {
			Text = "Loading...",
		}

		local cleanup = { tooltip }

		itemRef._instance = UI.new "TextLabel" {
			AutoLocalize = false,
			BackgroundTransparency = 1,
			Size = self.ItemSize,
			RichText = true,
			FontFace = UI.Theme.Font,
			TextColor3 = textColor,
			TextSize = UI.Theme.FontSize,
			TextStrokeColor3 = UI.Theme.Primary,
			TextStrokeTransparency = UI.Theme.TextStrokeTransparency,
			TextTruncate = Enum.TextTruncate.SplitWord,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,

			UI.new "TextLabel" {
				AutoLocalize = false,
				BackgroundTransparency = 1,
				Name = "Description",
				RichText = true,
				FontFace = UI.Theme.Font,
				TextColor3 = textColor,
				TextSize = UI.Theme.FontSize,
				TextStrokeColor3 = UI.Theme.Primary,
				TextStrokeTransparency = UI.Theme.TextStrokeTransparency,
				TextTruncate = Enum.TextTruncate.SplitWord,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
				Size = function()
					local size = UI.Theme.FontSize()
					return UDim2.new(1, -size, 0, size)
				end,
				Position = function()
					local size = UI.Theme.FontSize()
					return UDim2.new(0, size, 0, size)
				end,
			},
			tooltip,

			[UI.Clean] = cleanup,
		}

		table.insert(
			cleanup,
			tooltip.Visible:Connect(function()
				if tooltip.Visible._value then
					tooltip.Text(itemRef.command._value.tipText)
				end
			end)
		)

		return itemRef
	end

	local function renderItem(self, itemData, command)
		if command.renderText then
			local item = itemData._instance
			item.Text = command.renderText
			item.Description.Text = command.renderDesc
			itemData.command(command)
		end
	end

	local purchase = { gamepass = nil, role = nil }
	local purchaseData = {}
	local function updatePurchaseData(list)
		table.clear(purchaseData)
		local current
		for index, command in list do
			if not command.RestrictedToRole then
				for rank, role in _K.Data.rolesList do
					if _K.Auth.roleCanUseCommand(role._key, command) then
						command.RestrictedToRole = role
						break
					end
				end
			end
			if command.LocalPlayerAuthorized then
				continue
			end
			local role = command.RestrictedToRole
			if current then
				if role == current then
					purchaseData[current].lastIndex = index
				end
			end
			if not current and role and (role._key == "vip" or role.gamepasses) then
				current = role
				purchaseData[role] = {
					firstIndex = index - 1,
					lastIndex = index,
				}
			end
		end
	end

	-- TODO: update text/price based on current view, find bounds of the canvas position items

	local purchaseButton = UI.new "Button" {
		Label = "Loading...",
		LayoutOrder = 9,
		Icon = "rbxasset://textures/ui/common/robux.png",
		IconProperties = { ImageColor3 = UI.Theme.PrimaryText },
		IconRightAlign = true,
		Padding = UI.Theme.PaddingDouble,
		TextSize = UI.Theme.FontSizeLarge,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = function()
			return UDim2.new(1, 0, 0, UI.Theme.FontSizeLarge() + UI.Theme.PaddingDouble().Offset)
		end,
		Visible = false,

		UI.new "TextLabel" {
			Name = "Price",
			LayoutOrder = 8,
			AutoLocalize = false,
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
			FontFace = UI.Theme.FontMono,
			TextSize = UI.Theme.FontSizeLarge,
			TextColor3 = UI.Theme.PrimaryText,
			TextStrokeColor3 = UI.Theme.Primary,
			TextStrokeTransparency = UI.Theme.TextStrokeTransparency,
			TextWrapped = true,
			Size = function()
				return UDim2.new(0, UI.Theme.FontSizeLarge(), 1, 0)
			end,
			Text = `<b>?</b>`,
			RichText = true,
		},

		Activated = function()
			if purchase.role == "vip" and _K.Data.settings.vip then
				_K.PromptPurchaseVIP()
			elseif purchase.gamepass then
				_K.Service.Marketplace:PromptGamePassPurchase(_K.LocalPlayer, purchase.gamepass)
			end
		end,
	}

	local function updatePurchasePrice()
		local ok, result = pcall(function()
			local productType = if purchase.role == "vip" and _K.Data.settings.vip
				then Enum.InfoType.Asset
				else Enum.InfoType.GamePass
			return _K.Service.Marketplace:GetProductInfoAsync(purchase.gamepass, productType).PriceInRobux
		end)
		purchaseButton._content.Price.Text = `<b>{ok and result or "?"}</b>`
	end

	purchaseButton._content.Price.Text = `<b>799</b>`

	local function sortCommandsList(a, b)
		local rankA, rankB = math.huge, math.huge
		for rank, role in _K.Data.rolesList do
			if rankA > rank and _K.Auth.roleCanUseCommand(role._key, a) then
				rankA = rank
			end
			if rankB > rank and _K.Auth.roleCanUseCommand(role._key, b) then
				rankB = rank
			end
		end
		if rankA == rankB then
			return a.name < b.name
		else
			return rankA < rankB
		end
	end

	local commandsList = UI.state(_K.Registry.commandsList)
	local function updateCommandsList()
		local list
		if _K.client.settings.onlyShowUsableCommands._value then
			list = {}
			for _, command in _K.Registry.commandsList do
				local added
				for role, roleData in _K.Data.roles do
					if
						(
							(roleData.assets and next(roleData.assets))
							or (roleData.gamepasses and next(roleData.gamepasses))
							or (roleData.subscriptions and next(roleData.subscriptions))
							or (role == "vip" and _K.Data.settings.vip)
						) and _K.Auth.roleCanUseCommand(role, command)
					then
						table.insert(list, command)
						added = true
						break
					end
				end
				if not added and _K.Auth.hasCommand(_K.LocalPlayer.UserId, command) then
					table.insert(list, command)
				end
			end
		else
			list = _K.Registry.commandsList
		end
		table.sort(list, sortCommandsList)
		commandsList(list)
		updatePurchaseData(list)
	end

	local debounceUpdateCommandsList = _K.Util.Function.debounce(0.2, updateCommandsList)
	_K.client.settings.onlyShowUsableCommands:Connect(debounceUpdateCommandsList)
	_K.Hook.authChanged:Connect(debounceUpdateCommandsList)
	debounceUpdateCommandsList()

	local scroller = UI.new "ScrollerFast" {
		Name = "Commands",
		List = commandsList,
		Enabled = false,
		FilterInput = true,
		Visible = false,
		ItemSize = function()
			return UDim2.new(1, 0, 0, UI.Theme.FontSize * 2 + UI.Theme.Padding().Offset)
		end,
		CreateItem = createItem,
		RenderItem = renderItem,
		purchaseButton,
	}

	local function updatePurchaseButton()
		local itemHeight = UI.Theme.FontSize._value * 2
		local windowHeight = scroller._scroller.AbsoluteWindowSize.Y
		local top = scroller._scroller.CanvasPosition.Y
		local middle = top + windowHeight / 2
		local bottom = top + windowHeight

		local role
		for roleData, data in purchaseData do
			local first = data.firstIndex * itemHeight
			local last = data.lastIndex * itemHeight
			if first < bottom and last > middle then
				role = roleData
			end
		end

		if role and ((role._key == "vip" and _K.Data.settings.vip) or role.gamepasses) then
			purchase.role = role._key
			purchase.gamepass = if role._key == "vip" and _K.Data.settings.vip
				then 110019084552349
				else role.gamepasses[1]
			if not purchase.gamepass then
				return
			end
			purchaseButton.Label(`<b>Unlock <font color="{role.color}">{role.name or role._key}</font> Commands</b>`)
			purchaseButton._instance.Visible = true
			task.spawn(updatePurchasePrice)
			return
		end

		purchaseButton._instance.Visible = false
	end

	_K.Hook.authChanged:Connect(updatePurchaseButton)
	UI.Theme.FontSize:Connect(updatePurchaseButton)
	scroller._scroller:GetPropertyChangedSignal("CanvasPosition"):Connect(updatePurchaseButton)

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
						else ""}&gt;</i></font></b>\n{arg.description or "No description."}`
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

			-- non-breaking spaces
			local narrowSpace = " "
			local thinSpace = " "

			local roleColor = if #roles > 0 then _K.Data.roles[roles[1]].color else UI.Theme.Primary._value:ToHex()
			local roleCircle = `<font color="{roleColor}">●</font>{narrowSpace}`
			command.roleCircle = roleCircle

			for i, roleId in roles do
				local role = _K.Data.roles[roleId]
				roles[i] = `<font color="{role.color}">●</font>{narrowSpace}{string.gsub(role.name, " ", thinSpace)}`
			end

			command.roleText = table.concat(roles, ", ")

			local credit = command.credit or "Kohl @Scripth"
			local description = command.description or "No description."

			command.creditText = if type(credit) == "table" then table.concat(credit, ", ") else credit
			command.tipText =
				`<b>Restricted to:</b> {command.roleText}{command.argTooltip}\n\n<font transparency="0.5"><b>Credit:</b> {command.creditText}</font>`

			command.rawTextNoAlias = `{_K.getCommandPrefix()}{command.name} {command.argNames}`
			command.rawText = `{command.rawTextNoAlias} {command.aliasText}`

			command.richText = `{roleCircle}<b>{escape(command.rawTextNoAlias)}</b> <font transparency="0.66">{escape(
				command.aliasText
			)}</font>`
			command.richDesc = `<font transparency="0.33">{description}</font>`

			command.filterTest = string.lower(`{command.rawText} {description}`)
			command.filterText = string.lower(command.rawText)
			command.filterDesc = string.lower(description)
		end

		command.colorAuth = if command.LocalPlayerAuthorized
			then UI.Theme.PrimaryText._value
			else UI.Theme.PrimaryText._value:Lerp(UI.Theme.Primary._value, 0.5)
	end

	local function filterTest(self, list)
		local filter = string.lower(scroller._input._input.Text)
		self._filter = filter

		local noFilter = string.find(self._filter, "^%s*$")

		local new = {}

		if string.find(filter, "role=", 1, true) == 1 then
			filter = string.sub(filter, 6)
			for _, command in list do
				updateRenderParameters(command)
				if string.find(string.lower(command.roleText), filter, 1, true) then
					command.renderText = command.richText
					command.renderDesc = command.richDesc
					table.insert(new, command)
				end
			end

			return new
		end

		for _, command in list do
			updateRenderParameters(command)

			if noFilter then
				command.renderText = command.richText
				command.renderDesc = command.richDesc
				table.insert(new, command)
			else
				if string.find(command.filterTest, filter, 1, true) then
					local filterFound = string.find(command.filterText, self._filter, 1, true)
					command.renderText = if filterFound
						then command.roleCircle .. string.format(
							filterRichFormat,
							escape(string.sub(command.rawText, 1, filterFound - 1)),
							escape(string.sub(command.rawText, filterFound, filterFound + #self._filter - 1)),
							escape(string.sub(command.rawText, filterFound + #self._filter))
						)
						else `{command.roleCircle}<font transparency="0.5">{command.rawText}</font>`

					local description = command.description or "No description."
					local descFound = string.find(command.filterDesc, self._filter, 1, true)
					command.renderDesc = if descFound
						then string.format(
							filterRichFormat,
							escape(string.sub(description, 1, descFound - 1)),
							escape(string.sub(description, descFound, descFound + #self._filter - 1)),
							escape(string.sub(description, descFound + #self._filter))
						)
						else `<font transparency="0.5">{description}</font>`

					table.insert(new, command)
				end
			end
		end

		return new
	end

	task.defer(function()
		scroller:filter(filterTest)
	end)

	return scroller
end

return Commands
