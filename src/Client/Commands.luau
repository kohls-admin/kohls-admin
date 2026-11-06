local UI = require(script.Parent:WaitForChild("UI"))

local Commands = {}
Commands.__index = Commands

local filterRichFormat = `<font transparency="0.5">%s</font><b>%s</b><font transparency="0.5">%s</font>`

local function createItem(self, lineData)
	local itemRef = {
		command = UI.signal(lineData),
	}

	local textColor = function()
		return if itemRef.command().LocalPlayerAuthorized
			then UI.Theme.PrimaryText()
			else UI.Theme.PrimaryText():Lerp(UI.Theme.Primary(), 0.5)
	end

	-- follows the row's command, so a row recycled in place by ScrollerFast never shows a stale tooltip
	local tooltip = UI.new "Tooltip" {
		Text = function()
			return itemRef.command().tipText or "Loading..."
		end,
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

		__CLEAN = cleanup,
	}

	return itemRef
end

local function renderItem(_self, itemData, lineData)
	local command = lineData
	if command.renderText then
		local item = itemData._instance
		item.Text = command.renderText
		item.Description.Text = command.renderDesc
		itemData.command(command, true)
	end
end

local function updateRenderParameters(_K, command)
	if command.aliasText then
		return
	end
	local escape = _K.Util.String.escapeRichText
	command.aliasText = if command.aliases and #command.aliases ~= 0 then table.concat(command.aliases, ", ") else ""

	command.argNames = table.create(#command.args)
	command.argTooltip = table.create(#command.args)

	if #command.args > 0 then
		table.insert(command.argTooltip, "")
	end

	for _, arg in command.args do
		table.insert(command.argNames, if arg.optional then arg.name .. "?" else arg.name)
		table.insert(
			command.argTooltip,
			`\n<b><sc>{arg.name}</sc> <font transparency="0.66"><i>&lt;{arg.type}{if arg.optional then `?` else ""}&gt;</i></font></b>\n{arg.description or "No description."}`
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

	table.sort(roles, _K.Auth.roleIdSortAscending)

	-- non-breaking spaces
	local narrowSpace = " "
	local thinSpace = " "

	local roleColor = if #roles > 0 then _K.Data.roles[roles[1]].color else UI.Theme.Primary:peek():ToHex()
	local roleCircle = `<font color="{roleColor}">●</font>{narrowSpace}`
	command.roleCircle = roleCircle

	for i, roleId in roles do
		local role = _K.Data.roles[roleId]
		roles[i] = `<font color="{role.color}">●</font>{narrowSpace}{string.gsub(role.name, " ", thinSpace)}`
	end

	command.roleText = table.concat(roles, ", ")
	command.filterRole = string.lower(command.roleText)

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

local function filterCommands(_K, self, list)
	local escape = _K.Util.String.escapeRichText
	local filter = string.lower(self._input._input.Text)
	self._filter = filter

	local noFilter = string.find(filter, "^%s*$")
	local new = {}

	if string.find(filter, "role=", 1, true) == 1 then
		filter = string.sub(filter, 6)
		for _, command in list do
			updateRenderParameters(_K, command)
			if string.find(command.filterRole, filter, 1, true) then
				command.renderText = command.richText
				command.renderDesc = command.richDesc
				table.insert(new, command)
			end
		end

		return new
	end

	local function formatMatch(text: string, found: number): string
		local filterEnd = found + #filter
		return string.format(
			filterRichFormat,
			escape(string.sub(text, 1, found - 1)),
			escape(string.sub(text, found, filterEnd - 1)),
			escape(string.sub(text, filterEnd))
		)
	end

	for _, command in list do
		updateRenderParameters(_K, command)

		if noFilter then
			command.renderText = command.richText
			command.renderDesc = command.richDesc
			table.insert(new, command)
		elseif string.find(command.filterTest, filter, 1, true) then
			local filterFound = string.find(command.filterText, filter, 1, true)
			command.renderText = if filterFound
				then command.roleCircle .. formatMatch(command.rawText, filterFound)
				else `{command.roleCircle}<font transparency="0.5">{command.rawText}</font>`

			local description = command.description or "No description."
			local descFound = string.find(command.filterDesc, filter, 1, true)
			command.renderDesc = if descFound
				then formatMatch(description, descFound)
				else `<font transparency="0.5">{description}</font>`

			table.insert(new, command)
		end
	end

	return new
end

local function getTargetChannel(textChat: Instance, chatInputBar: ChatInputBarConfiguration?): TextChannel?
	local inputBar = chatInputBar or textChat:FindFirstChildOfClass("ChatInputBarConfiguration")
	if inputBar and inputBar.TargetTextChannel then
		return inputBar.TargetTextChannel
	end
	local channels = textChat:FindFirstChild("TextChannels")
	local general = (channels and channels:FindFirstChild("RBXGeneral")) or textChat:FindFirstChild("RBXGeneral", true)
	return if general and general:IsA("TextChannel") then general else nil
end

local function connectChatCommand(
	_K,
	textChat: Instance,
	chatInputBar: ChatInputBarConfiguration?,
	child: TextChatCommand
): RBXScriptConnection
	return child.Triggered:Connect(function(source: TextSource, text: string)
		if source.UserId ~= _K.LocalPlayer.UserId then
			return
		end
		local trimmed = _K.Util.String.trimStart(text)
		if trimmed == "" or string.sub(trimmed, 1, 1) == "/" then
			return
		end
		local channel = getTargetChannel(textChat, chatInputBar)
		if not channel then
			return
		end
		child.Enabled = false
		task.spawn(pcall, channel.SendAsync, channel, text)
		child.Enabled = _K.Data.settings.chatCommands ~= false
	end)
end

local function setupChatCommands(_K, onChanged: () -> ())
	local textChat = _K.Service.TextChat
	local chatInputBar = textChat:FindFirstChildOfClass("ChatInputBarConfiguration")
	local chatCommandsFolder: Instance?
	local folderReparented = false
	local watchedChatCommands: { [Instance]: RBXScriptConnection } = {}

	local function watchChatCommand(child: Instance)
		if child:IsA("TextChatCommand") and not watchedChatCommands[child] then
			watchedChatCommands[child] = connectChatCommand(_K, textChat, chatInputBar, child)
		end
	end

	local function unwatchChatCommand(child: Instance)
		local conn = watchedChatCommands[child]
		if conn then
			watchedChatCommands[child] = nil
			conn:Disconnect()
		end
	end

	local function reparentChatCommands()
		if chatCommandsFolder and chatCommandsFolder.Parent == textChat then
			chatCommandsFolder.Parent = nil
			chatCommandsFolder.Parent = textChat
		end
	end

	local function updateChatCommandsAutocomplete(list)
		local folder = chatCommandsFolder or textChat:FindFirstChild("TextChatCommands_KA")
		if not folder then
			return
		end
		local visible = {}
		if _K.Data.settings.chatCommands ~= false then
			for _, command in list do
				visible[string.lower(command.name)] = true
			end
		end
		for _, child in folder:GetChildren() do
			if child:IsA("TextChatCommand") then
				child.AutocompleteVisible = visible[child.Name] == true and string.sub(child.PrimaryAlias, 1, 1) == "/"
			end
		end
		if not folderReparented and game:IsLoaded() then
			folderReparented = true
			reparentChatCommands()
		end
	end

	local function watchChatCommandsFolder(folder: Instance)
		if chatCommandsFolder == folder then
			return
		end
		chatCommandsFolder = folder
		folderReparented = false
		for _, child in folder:GetChildren() do
			watchChatCommand(child)
		end
		local _ = folder.ChildAdded:Connect(function(child)
			watchChatCommand(child)
			onChanged()
		end)
		local _ = folder.ChildRemoved:Connect(function(child)
			unwatchChatCommand(child)
			onChanged()
		end)
		onChanged()
	end

	local existingFolder = textChat:FindFirstChild("TextChatCommands_KA")
	if existingFolder then
		watchChatCommandsFolder(existingFolder)
	end
	local _ = textChat.ChildAdded:Connect(function(child)
		if child.Name == "TextChatCommands_KA" then
			watchChatCommandsFolder(child)
		end
	end)

	if chatInputBar then
		local focusedConn: RBXScriptConnection?
		focusedConn = chatInputBar:GetPropertyChangedSignal("IsFocused"):Connect(function()
			if chatInputBar.IsFocused then
				if focusedConn then
					focusedConn:Disconnect()
					focusedConn = nil
				end
				reparentChatCommands()
			end
		end)
	end

	return updateChatCommandsAutocomplete
end

local function updatePurchaseData(purchaseData, list)
	table.clear(purchaseData)
	local current
	for index, command in list do
		if command.LocalPlayerAuthorized then
			continue
		end
		local role = command.RestrictedToRole
		if current and role == current then
			purchaseData[current].lastIndex = index
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

local function createPurchaseButton(_K, purchase)
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
	purchaseButton._content.Price.Text = `<b>799</b>`
	return purchaseButton
end

local function buildCommandsList(_K)
	local list
	if _K.client.settings.onlyShowUsableCommands:peek() then
		list = {}
		for _, command in _K.Registry.commandsList do
			if _K.VIP.canPurchaseCommand(command) or _K.Auth.hasCommand(_K.LocalPlayer.UserId, command) then
				table.insert(list, command)
			end
		end
	else
		list = _K.Registry.commandsList
	end
	local ranks = {}
	for _, command in list do
		local minRank = math.huge
		for rank, role in _K.Data.rolesList do
			if _K.Auth.roleCanUseCommand(role._key, command) then
				minRank = rank
				if not command.RestrictedToRole then
					command.RestrictedToRole = role
				end
				break
			end
		end
		ranks[command] = minRank
	end
	table.sort(list, function(a, b)
		local rankA, rankB = ranks[a], ranks[b]
		return if rankA == rankB then a.name < b.name else rankA < rankB
	end)
	return list
end

function Commands.new(_K)
	local purchase = { gamepass = nil, role = nil }
	local purchaseData = {}
	local purchaseButton = createPurchaseButton(_K, purchase)

	local commandsList = UI.signal(_K.Registry.commandsList)
	local updateChatCommandsAutocomplete

	local function updateCommandsList()
		local list = buildCommandsList(_K)
		commandsList(list, true)
		updatePurchaseData(purchaseData, list)
		if updateChatCommandsAutocomplete then
			updateChatCommandsAutocomplete(list)
		end
	end

	local debounceUpdateCommandsList = _K.Util.Function.debounce(0.2, updateCommandsList)
	updateChatCommandsAutocomplete = setupChatCommands(_K, debounceUpdateCommandsList)

	UI.effect(UI.on(_K.client.settings.onlyShowUsableCommands, debounceUpdateCommandsList, true)):get()
	if _K.client.settings.chatCommands then
		UI.effect(UI.on(_K.client.settings.chatCommands, debounceUpdateCommandsList, true)):get()
	end
	if _K.client.settings.vip then
		UI.effect(UI.on(_K.client.settings.vip, debounceUpdateCommandsList, true)):get()
	end
	local _ = _K.Hook.authChanged:Connect(debounceUpdateCommandsList)
	local _ = _K.Hook.commandRegistered:Connect(debounceUpdateCommandsList)

	debounceUpdateCommandsList()

	local scroller = UI.new "ScrollerFast" {
		Name = "Commands",
		List = commandsList,
		Enabled = false,
		FilterInput = true,
		Visible = false,
		ItemSize = function()
			return UDim2.new(1, 0, 0, UI.Theme.FontSize() * 2 + UI.Theme.Padding().Offset)
		end,
		CreateItem = createItem,
		RenderItem = renderItem,
		purchaseButton,
	}

	local function updatePurchaseButton()
		local itemHeight = UI.Theme.FontSize:peek() * 2
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
				then (_K.VIP.getActiveAssetId and _K.VIP.getActiveAssetId() or 110019084552349)
				else role.gamepasses[1]
			if not purchase.gamepass then
				return
			end
			purchaseButton.Label(`<b>Unlock <font color="{role.color}">{role.name or role._key}</font> Commands</b>`)
			purchaseButton._instance.Visible = true
			task.spawn(_K.VIP.updatePurchasePrice, purchase, purchaseButton)
			return
		end

		purchaseButton._instance.Visible = false
	end

	local _ = _K.Hook.authChanged:Connect(updatePurchaseButton)
	if _K.VIP and _K.VIP.saleStateChanged then
		local _ = _K.VIP.saleStateChanged:Connect(updatePurchaseButton)
	end
	UI.effect(UI.on(UI.Theme.FontSize, updatePurchaseButton, true)):get()
	local _ = scroller._scroller:GetPropertyChangedSignal("CanvasPosition"):Connect(updatePurchaseButton)

	task.defer(function()
		scroller:filter(function(self, list)
			return filterCommands(_K, self, list)
		end)
	end)

	return scroller
end

return Commands
