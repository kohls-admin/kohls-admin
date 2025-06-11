local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local TextService = game:GetService("TextService")

local _K = require(script.Parent.Parent)
local CompletionData = require(script.CompletionData)

local UI = _K.UI
local prefix = _K.getCommandPrefix()

local validState = UI.state(nil)
local indicatorColor = UI.compute(function(use)
	local valid = use(validState)
	if valid == true then
		return use(UI.Theme.Valid)
	elseif valid == false then
		return use(UI.Theme.Invalid)
	else
		return use(UI.Theme.PrimaryText)
	end
end)

local Input
Input = UI.new "Input" {
	AnchorPoint = Vector2.new(0, 0.5),
	Placeholder = "Search",
	BackgroundColor3 = UI.Theme.Primary,
	BackgroundTransparency = UI.Theme.Transparency,
	Font = UI.Theme.FontMono,
	FontSize = 20,
	Position = UDim2.fromScale(0, 0.5),
	Size = UDim2.new(1, 0, 1, 0),

	UI.new "TextButton" {
		AutoLocalize = false,
		Name = "CircleIndicator",
		BackgroundTransparency = 1,
		TextTransparency = 1,
		Size = UDim2.new(0, 20, 0, 20),

		UI.new "Frame" {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 1, 0),
			SizeConstraint = Enum.SizeConstraint.RelativeYY,

			UI.new "UICorner" {
				CornerRadius = UDim.new(1, 0),
			},
			UI.new "UIStroke" {
				Thickness = 2,
				Color = indicatorColor,
			},

			UI.new "ImageLabel" {
				Name = "Valid",
				AnchorPoint = Vector2.new(0.55, 0.45),
				BackgroundTransparency = 1,
				Position = UDim2.new(0.5, 0, 0.5, 0),
				Size = UDim2.fromScale(0.75, 0.75),
				ImageColor3 = UI.Theme.Valid,
				Image = UI.Theme.Image.Check_Bold,
				Visible = UI.compute(function(use)
					return use(validState) == true
				end),
			},

			UI.new "ImageLabel" {
				Name = "Invalid",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Position = UDim2.new(0.5, 0, 0.5, 0),
				Size = UDim2.fromScale(0.5, 0.5),
				ImageColor3 = UI.Theme.Invalid,
				Image = UI.Theme.Image.Close_Bold,
				Visible = UI.compute(function(use)
					return use(validState) == false
				end),
			},
		},

		[UI.Event] = {
			Activated = function()
				Input._input:CaptureFocus()
				Input._input:ReleaseFocus(true)
			end,
		},
	},
}

UI.edit(Input._instance.UICorner, {
	CornerRadius = UDim.new(1, 0),
})

UI.edit(Input._instance.UIListLayout, {
	Padding = UDim.new(0, 8),
})

UI.edit(Input._instance.UIPadding, {
	PaddingLeft = UDim.new(0, 14),
	PaddingRight = UDim.new(0, 12),
	PaddingTop = UDim.new(0, 0),
	PaddingBottom = UDim.new(0, 0),
})

local CommandBar = UI.new "Frame" {
	Name = "CommandBar",
	AnchorPoint = Vector2.new(0.5, 0),
	Size = UDim2.new(1, 0, 1, 0),
	Position = UDim2.fromScale(0.5, 0),
	BackgroundTransparency = 1,
	ZIndex = 100,
	Visible = false,

	Input,
	UI.new "UIFlexItem" { FlexMode = Enum.UIFlexMode.Fill },
}

UI.edit(Input._instance.UIStroke, {
	Thickness = 2,
	Color = UI.Theme.Invalid,
	Enabled = UI.compute(function(use)
		return use(validState) == false
	end),
})

local TooltipFrame = UI.new "Frame" {
	Parent = CommandBar,
	Name = "Tooltip",
	Active = true,
	BackgroundColor3 = UI.Theme.Primary,
	BackgroundTransparency = UI.Theme.Transparency,
	Size = UDim2.fromOffset(256, 32),
	Visible = false,

	UI.new "UICorner" {
		CornerRadius = UI.Theme.CornerRadius,
	},
	UI.new "UIStroke" {
		Color = UI.Theme.Border,
	},
}

local TooltipLayout = UI.new "UIListLayout" {
	Parent = TooltipFrame,
	SortOrder = Enum.SortOrder.LayoutOrder,
	Padding = UDim.new(0, 0),
}

local Tooltip = UI.new "TextLabel" {
	Parent = TooltipFrame,
	LayoutOrder = 0,
	AutoLocalize = false,
	Name = "Tooltip",
	BackgroundTransparency = 1,
	TextWrapped = true,
	RichText = true,
	Font = UI.Theme.FontMono,
	TextSize = 20,
	TextColor3 = UI.Theme.PrimaryText,
	TextStrokeColor3 = UI.Theme.Primary,
	TextStrokeTransparency = UI.Theme.TextStrokeTransparency,
	TextXAlignment = Enum.TextXAlignment.Left,

	UI.new "UIPadding" {
		PaddingTop = UI.Theme.Padding,
		PaddingBottom = UI.Theme.Padding,
		PaddingLeft = UI.Theme.Padding,
		PaddingRight = UI.Theme.Padding,
	},
}

local TooltipTextBounds = UI.state(Tooltip, "TextBounds")
UI.edit(Tooltip, {
	Size = UI.compute(function(use)
		local height = use(TooltipTextBounds).Y
		local padding = use(UI.Theme.PaddingDouble).Offset
		return UDim2.new(1, 0, 0, math.max(32, height + padding))
	end),
})

TooltipLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	local size = TooltipLayout.AbsoluteContentSize
	TooltipFrame.Size = UDim2.fromOffset(TooltipFrame.AbsoluteSize.X, size.Y + UI.Theme.PaddingHalf._value.Offset)
end)

local SuggestionFrame = UI.new "TextButton" {
	AutoLocalize = false,
	AutomaticSize = Enum.AutomaticSize.X,
	Name = "Suggestion",
	BackgroundTransparency = 0.9,
	BackgroundColor3 = UI.Theme.Secondary,
	Size = UI.compute(function(use)
		return UDim2.new(1, 0, 0, Tooltip.TextSize + use(UI.Theme.Padding).Offset)
	end),
	Text = "",
	TextTransparency = 1,

	UI.new "TextLabel" {
		LayoutOrder = 0,
		AutoLocalize = false,
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 0, 1, 0),
		RichText = true,
		Font = UI.Theme.FontMono,
		TextSize = Tooltip.TextSize,
		TextColor3 = UI.Theme.PrimaryText,
		TextStrokeColor3 = UI.Theme.Primary,
		TextStrokeTransparency = UI.Theme.TextStrokeTransparency,
		TextXAlignment = Enum.TextXAlignment.Left,

		UI.new "UIPadding" {
			PaddingTop = UI.Theme.PaddingHalf,
			PaddingBottom = UI.Theme.PaddingHalf,
			PaddingLeft = UI.Theme.Padding,
			PaddingRight = UI.Theme.Padding,
		},
	},
}

local argumentFormat = `<b><sc>%s</sc> <font transparency="0.66"><i>&lt;%s&gt;</i></font></b>\n%s`
local inlineFormat =
	`<font transparency="0.33">%s<font transparency="0.66">%s<font transparency="0">%s</font>%s</font>%s</font>`
local invalidInlineFormat =
	`<font transparency="0.33">%s<b><font color="#f00" transparency="0.66">%s<font transparency="0">%s</font>%s</font></b>%s</font>`
local suggestFormat = `<font transparency="0.5">%s</font>%s<font transparency="0.5">%s</font>`
local invalidSuggestFormat = `<font color="#f00">{suggestFormat}</font>`

local function updateInvalidColor(invalidColor)
	invalidColor = invalidColor:ToHex()
	invalidInlineFormat =
		`<font transparency="0.33">%s<b><font color="#{invalidColor}" transparency="0.66">%s<font transparency="0">%s</font>%s</font></b>%s</font>`
	invalidSuggestFormat = `<font color="#{invalidColor}">{suggestFormat}</font>`
end
UI.Theme.Invalid:hook(updateInvalidColor)
updateInvalidColor(UI.Theme.Invalid._value)

local suggestionIndex = 1
local suggestionLabels = {}

local updateCompletion, currentCompletion, currentCompletionData
local function updateCompletionData()
	if Input._input.SelectionStart ~= -1 then
		return
	end
	suggestionIndex = 1
	currentCompletionData = CompletionData(_K, Input._input.Text, Input._input.CursorPosition)
	updateCompletion()
end

local function fillSuggestion()
	local pos, text = unpack(currentCompletion)
	if not string.find(text, " $") then
		text = text .. " "
		pos += 1
	end
	currentCompletion = nil

	Input.Value:set(text, true)
	Input._input.CursorPosition = pos + 1
end

local completeSuggestion = _K.Util.Function.throttle(0.1, function()
	if not currentCompletion then
		return
	end

	fillSuggestion()
	task.defer(updateCompletionData)
end)

local function formatSuggestionLabel(label, display, query, invalid)
	local startIndex, endIndex = string.find(string.lower(display), query, 1, true)
	if not startIndex then
		startIndex, endIndex = 0, 0
	end

	label.Text = string.format(
		if invalid then invalidSuggestFormat else suggestFormat,
		if startIndex > 1 then _K.Util.String.escapeRichText(string.sub(display, 1, startIndex - 1)) else "",
		_K.Util.String.escapeRichText(string.sub(display, startIndex, endIndex)),
		_K.Util.String.escapeRichText(string.sub(display, endIndex + 1))
	)

	return TextService:GetTextSize(display, label.TextSize, label.Font, Vector2.zero).X
		+ UI.Theme.PaddingDouble._value.Offset
end

local suggestionUpdating
local function updateSuggestionLabels(data)
	if suggestionUpdating then
		return
	end
	suggestionUpdating = true

	local query = string.lower(_K.Util.String.trim(data.query))

	local amount = math.min(7, #data.suggestions - 1)
	local start = math.max(1, suggestionIndex - 7)

	local suggestionWidth = 256
	for i = start, start + amount do
		local suggestion = data.suggestions[i]
		local text, display, value, invalid = unpack(suggestion)
		local frame = SuggestionFrame:Clone()
		local label = frame:FindFirstChildOfClass("TextLabel")
		frame.LayoutOrder = i
		frame.BackgroundTransparency = if i == suggestionIndex then 0.9 else 0.95
		display = display or text

		local widthOffset = 0
		local valueType = typeof(value)
		if valueType == "Instance" and value:IsA("Player") then
			UI.new "ImageLabel" {
				Parent = frame,
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, 0, 0, 0),
				Size = UDim2.new(1, 0, 1, 0),
				SizeConstraint = Enum.SizeConstraint.RelativeYY,
				Image = `rbxthumb://type=AvatarHeadShot&id={value.UserId}&w=48&h=48`,
			}
			widthOffset = label.AbsoluteSize.Y
		elseif valueType == "Color3" or valueType == "BrickColor" then
			UI.new "Frame" {
				Parent = frame,
				BackgroundColor3 = if valueType == "BrickColor" then value.Color else value,
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, 0, 0, 0),
				Size = UDim2.new(1, 0, 1, 0),
				SizeConstraint = Enum.SizeConstraint.RelativeYY,
			}
			widthOffset = label.AbsoluteSize.Y
		elseif valueType == "EnumItem" then
			if value.EnumType == Enum.Font then
				frame.TextLabel.Font = value
			end
		elseif valueType == "table" then
			if value.userId or value.UserId then
				UI.new "ImageLabel" {
					Parent = frame,
					BackgroundTransparency = 1,
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, 0, 0, 0),
					Size = UDim2.new(1, 0, 1, 0),
					SizeConstraint = Enum.SizeConstraint.RelativeYY,
					Image = `rbxthumb://type=AvatarHeadShot&id={value.userId or value.UserId}&w=48&h=48`,
				}
				widthOffset = label.AbsoluteSize.Y
				task.spawn(function()
					display ..= ` ({value.Name or _K.Util.getUserInfo(value.UserId).Username})`

					local textWidth = formatSuggestionLabel(label, display, query, invalid)
					suggestionWidth = math.max(suggestionWidth, textWidth + widthOffset)
					TooltipFrame.Size = UDim2.fromOffset(suggestionWidth, TooltipLayout.AbsoluteContentSize.Y)
				end)
			end
		elseif data.suggestionType.name == "image" or data.suggestionType.name == "images" and data.arg then
			UI.new "ImageLabel" {
				Parent = frame,
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, 0, 0, 0),
				Size = UDim2.new(1, 0, 1, 0),
				SizeConstraint = Enum.SizeConstraint.RelativeYY,
				Image = data.arg.parsedArgs[1],
			}
			widthOffset = label.AbsoluteSize.Y
		end

		local textWidth = formatSuggestionLabel(label, display, query, invalid)
		suggestionWidth = math.max(suggestionWidth, textWidth + widthOffset)

		frame.Activated:Connect(function()
			Input._input:CaptureFocus()
			suggestionIndex = i
			updateCompletion()
			completeSuggestion()
		end)
		frame.Parent = TooltipFrame
		table.insert(suggestionLabels, frame)
	end

	TooltipFrame.Size = UDim2.fromOffset(suggestionWidth, TooltipLayout.AbsoluteContentSize.Y)

	suggestionUpdating = false
end

local function clearCompletion()
	TooltipFrame.Visible = false
	Input.DisplayText:set(_K.Util.String.escapeRichText(Input._input.Text))
	for _, label in suggestionLabels do
		label:Destroy()
	end
	table.clear(suggestionLabels)
end

local suggestionPurchase = {
	role = nil,
	gamepass = nil,
}
local suggestionPurchaseButton = UI.new "Button" {
	LayoutOrder = math.huge,
	Label = "Loading...",
	Icon = "rbxasset://textures/ui/common/robux.png",
	IconProperties = { ImageColor3 = UI.Theme.PrimaryText },
	IconRightAlign = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	Size = UDim2.new(1, 0, 0, 32),

	UI.new "TextLabel" {
		Name = "Price",
		LayoutOrder = 8,
		AutoLocalize = false,
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 1,
		Font = UI.Theme.FontMono,
		TextSize = UI.Theme.FontSizeLarge,
		TextColor3 = UI.Theme.PrimaryText,
		TextStrokeColor3 = UI.Theme.Primary,
		TextStrokeTransparency = UI.Theme.TextStrokeTransparency,
		TextWrapped = true,
		Size = UI.computeFrom(UDim2.new, 0, UI.Theme.FontSizeLarge, 0, 32),
		Text = `<b>?</b>`,
		RichText = true,
	},

	[UI.Event] = {
		Activated = function()
			if suggestionPurchase.role == "vip" and _K.Data.settings.vip then
				_K.promptPurchaseVIP()
			elseif suggestionPurchase.gamepass then
				_K.Service.Marketplace:PromptGamePassPurchase(_K.LocalPlayer, suggestionPurchase.gamepass)
			end
		end,
	},
}

local function updateSuggestionPurchasePrice()
	local ok, result = pcall(function()
		return _K.Service.Marketplace:GetProductInfo(suggestionPurchase.gamepass, Enum.InfoType.GamePass).PriceInRobux
	end)
	if ok then
		suggestionPurchaseButton._content.Price.Text = `<b>{result or "?"}</b>`
	end
end

local function invalidSuggestion(data, err, pos, text)
	validState:set(false)
	Input.DisplayText:set(
		string.format(
			invalidSuggestFormat,
			_K.Util.String.escapeRichText(string.sub(data.message, 1, pos - 1)),
			_K.Util.String.escapeRichText(text),
			_K.Util.String.escapeRichText(string.sub(data.message, pos + #text))
		)
	)
	-- TODO: command definition
	Tooltip.Visible = data.argDefinition ~= nil
	Tooltip.Text = if not data.argDefinition
		then ""
		else string.format(
			argumentFormat,
			_K.Util.String.escapeRichText(data.argDefinition.displayName or data.argDefinition.name),
			_K.Util.String.escapeRichText(data.suggestionType.name) .. if data.argDefinition.optional then "?" else "",
			data.argDefinition.description
		)

	local frame = SuggestionFrame:Clone()
	local label = frame:FindFirstChildOfClass("TextLabel")
	label.Text = `<font color="#{UI.Theme.Invalid._value:ToHex()}"><b>{_K.Util.String.escapeRichText(err)}</b></font>`
	frame.Parent = TooltipFrame
	-- show highlight
	table.insert(suggestionLabels, frame)

	TooltipFrame.Size = UDim2.fromOffset(
		math.max(TooltipFrame.AbsoluteSize.X, label.AbsoluteSize.X),
		TooltipLayout.AbsoluteContentSize.Y
	)
	TooltipFrame.Visible = true

	if not data.suggestions or not data.suggestions[suggestionIndex] then
		return
	end

	local suggestion, _, value = unpack(data.suggestions[suggestionIndex])
	if data.argIndex == 1 then -- command
		-- TODO: inline argument types if command
		-- show command aliases too!
		Tooltip.Text =
			string.format(argumentFormat, _K.Util.String.escapeRichText(suggestion), "command", value.description)
	end
	return
end

local commandHistory = {}
updateCompletion = function()
	local data = currentCompletionData
	currentCompletion = nil

	Input.DisplayText:set(_K.Util.String.escapeRichText(Input._input.Text))
	for _, label in suggestionLabels do
		label:Destroy()
	end
	table.clear(suggestionLabels)

	if data.suggestionType == "History" then
		TooltipFrame.Visible = false
		data.suggestions = table.create(#commandHistory)
		for _, cmd in commandHistory do
			table.insert(data.suggestions, { cmd })
		end
	end

	validState:set(nil)

	-- handle validation hints
	-- TODO: somehow show validated arguments/text as green :)
	for _, invalid in data.invalid do
		invalidSuggestion(data, unpack(invalid))
	end

	if not data.suggestionType then
		return
	end

	if data.invalidPermissionsCommand and not data.validSuggestion then
		for role, roleData in _K.Data.roles do
			if
				(roleData.gamepasses or role == "vip")
				and _K.Auth.roleCanUseCommand(role, data.invalidPermissionsCommand)
			then
				suggestionPurchase.role = role
				suggestionPurchase.gamepass = if role == "vip" then 5411126 else roleData.gamepasses[1]
				suggestionPurchaseButton._instance.Parent = TooltipFrame
				suggestionPurchaseButton.Label:set(
					`<sc>Purchase <font color="{roleData.color}">{roleData.name or role}</font></sc>`
				)
				task.spawn(updateSuggestionPurchasePrice)
				break
			end
		end
	else
		suggestionPurchaseButton._instance.Parent = nil
	end

	if #data.commands > 0 then
		local valid = true
		for _, command in data.commands do
			if not command.validated then
				valid = false
				break
			end
		end

		if valid then
			validState:set(true)
		end
	end

	if not data.suggestionType then
		return clearCompletion() -- no suggestions without argument type
	end

	-- show normal argument type hints here!
	if data.argDefinition then
		Tooltip.Text = string.format(
			argumentFormat,
			_K.Util.String.escapeRichText(data.argDefinition.displayName or data.argDefinition.name),
			_K.Util.String.escapeRichText(data.suggestionType.name) .. if data.argDefinition.optional then "?" else "",
			data.argDefinition.description
		)
		Tooltip.Visible = true
		TooltipFrame.Visible = true
		-- TODO: some types should show a widget for fast select e.g. color wheel
	end

	-- move tooltip to start of query
	-- FIX: adjust with inputoffset
	local argX = TextService:GetTextSize(
		string.sub(string.gsub(string.gsub(data.message, "\n", " "), "\r", " "), 1, data.argPos - 1),
		Tooltip.TextSize,
		Tooltip.Font,
		Vector2.zero
	).X
	TooltipFrame.Position = UDim2.new(
		0,
		math.floor(argX)
			+ Input._input.AbsolutePosition.X
			- Input._instance.AbsolutePosition.X
			- UI.Theme.Padding._value.Offset,
		0.5,
		Input._instance.AbsoluteSize.Y / 2 + 6
	)

	-- suggestion hints
	if not (data.suggestions and #data.suggestions > 0) then
		return
	end

	local arg = _K.Util.String.trim(data.rawArg)
	local endPos = data.argPos + #arg
	local suggestion, _, value, invalid = unpack(data.suggestions[suggestionIndex])

	if not string.find(string.lower(suggestion), `{string.lower(_K.Util.String.stripQuotes(arg))}`, 1, true) then
		invalid = true
		data.validSuggestion = false
	end

	if invalid and not data.validSuggestion then
		validState:set(false)
	end

	local completion = suggestion
	local preCompletion = string.sub(data.message, 1, data.argPos - 1)
	local postCompletion = string.sub(data.message, endPos)
	local quote = string.match(preCompletion, '(["`])$')
	if quote and not string.match(postCompletion, '^["`]') then
		completion ..= quote
	elseif
		not quote
		and data.suggestionType ~= "History"
		and string.find(completion, `[ {_K.Util.String.escapePattern(prefix)}]`)
	then
		completion = `"{completion}"`
	end

	currentCompletion = { data.argPos + #completion, preCompletion .. completion .. postCompletion, invalid }

	-- inline format (preceding message, pre query suggestion, query, post query suggestion, post query message)
	-- FIX: how to not escape invalid/valid rich text coloring?
	-- need a way to merge it somehow? (or don't use richtext maybe red underline instead! with a button you can hover to show error tooltip :)
	local query = string.lower(_K.Util.String.trim(data.query))
	local startIndex, endIndex = string.find(string.lower(suggestion), query, 1, true)
	if not startIndex then
		startIndex, endIndex = 1, #suggestion
	end

	Input.DisplayText:set(
		string.format(
			if invalid then invalidInlineFormat else inlineFormat,
			_K.Util.String.escapeRichText(preCompletion),
			if startIndex > 1 then _K.Util.String.escapeRichText(string.sub(suggestion, 1, startIndex - 1)) else "",
			_K.Util.String.escapeRichText(data.rawQuery or data.query),
			_K.Util.String.escapeRichText(string.sub(suggestion, endIndex + 1)),
			_K.Util.String.escapeRichText(postCompletion)
		)
	)

	-- show completion tooltip
	if data.argIndex == 1 then -- command
		Tooltip.Text =
			string.format(argumentFormat, _K.Util.String.escapeRichText(suggestion), "command", value.description)
	end

	if data.argDefinition or data.argIndex == 1 then
		updateSuggestionLabels(data)
		Tooltip.Visible = true
		TooltipFrame.Visible = true
	end

	return
end

-- hides and caches the state of core guis, toggles the cached state otherwise
local coreGuiCache, coreChatActiveCache = {}, nil
local function coreGuiEnabled(enabled: boolean)
	if enabled then
		StarterGui:SetCore("ChatActive", coreChatActiveCache)
		coreChatActiveCache = nil
		for coreType, value in coreGuiCache do
			coreGuiCache[coreType] = nil
			StarterGui:SetCoreGuiEnabled(coreType, value)
		end
	else
		if coreChatActiveCache == nil then
			coreChatActiveCache = StarterGui:GetCore("ChatActive")
		end
		StarterGui:SetCore("ChatActive", false)
		for _, coreType in Enum.CoreGuiType:GetEnumItems() do
			if coreType ~= Enum.CoreGuiType.Chat and coreType ~= Enum.CoreGuiType.Health then
				continue
			end
			if coreGuiCache[coreType] == nil then
				local value = StarterGui:GetCoreGuiEnabled(coreType)
				StarterGui:SetCoreGuiEnabled(coreType, false)
				if value == true then
					coreGuiCache[coreType] = value
				end
			end
		end
	end
end

local function hideCommandBar()
	if CommandBar.Visible then
		CommandBar.Visible = false
		if _K.client then
			_K.client.TopbarPlus.setTopbarEnabled(true)
		end
		coreGuiEnabled(true)
	end
end

local function suggestionUp()
	if currentCompletionData.suggestionType == "History" then
		suggestionIndex = math.min(
			math.max(1, currentCompletionData.suggestions and #currentCompletionData.suggestions or 1),
			suggestionIndex + 1
		)
	else
		suggestionIndex = math.max(1, suggestionIndex - 1)
	end
	updateCompletion()
end

local function suggestionDown()
	if currentCompletionData.suggestionType == "History" then
		suggestionIndex = math.max(1, suggestionIndex - 1)
	else
		suggestionIndex = math.min(
			math.max(1, currentCompletionData.suggestions and #currentCompletionData.suggestions or 1),
			suggestionIndex + 1
		)
	end
	updateCompletion()
end

local initialized
return {
	Bar = CommandBar,
	Input = Input,
	updateCompletionData = updateCompletionData,
	init = function(self, _K)
		if initialized then
			return
		end
		initialized = true

		prefix = _K.getCommandPrefix()
		Input.Value:set(prefix, true)
		CommandBar.Parent = UI.TopbarFrame
		_K.client.hotkeys.commandBar = { key = UI.state(Enum.KeyCode.Semicolon), mods = {}, callback = self.show }
		_K.client.CommandBarState = { validState, indicatorColor }

		local function updatePrefix()
			local value = _K.getCommandPrefix()
			local oldPrefix = prefix
			prefix = value
			Input.Value:set(value .. string.sub(Input._input.Text, #oldPrefix + 1), true)
		end
		_K.client.settings.prefix:hook(updatePrefix)
		_K.client.settings.playerPrefix:hook(updatePrefix)

		TooltipFrame.MouseWheelForward:Connect(suggestionUp)
		TooltipFrame.MouseWheelBackward:Connect(suggestionDown)

		UserInputService.InputBegan:Connect(function(input, gameProcessed)
			if input.UserInputType == Enum.UserInputType.Keyboard then
				if not Input._input:IsFocused() then
					return
				end
				if input.KeyCode == Enum.KeyCode.Up then
					suggestionUp()
				elseif input.KeyCode == Enum.KeyCode.Down then
					suggestionDown()
				end
			elseif
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				if gameProcessed then
					return
				end
				hideCommandBar()
			end
		end)

		Input._input:GetPropertyChangedSignal("CursorPosition"):Connect(function()
			local cursorPosition = Input._input.CursorPosition
			if cursorPosition ~= -1 then
				local prefixPosition = #prefix + 1
				if cursorPosition < prefixPosition then
					Input._input.CursorPosition = prefixPosition
					return
				end
				if not UserInputService:IsKeyDown(Enum.KeyCode.Tab) then
					task.defer(updateCompletionData)
				end
			else
			end
		end)
		Input._input:GetPropertyChangedSignal("SelectionStart"):Connect(function()
			if Input._input.SelectionStart ~= -1 then
				if validState._value == false then
					validState:set(nil)
				end
				clearCompletion()
			else
				updateCompletionData()
			end
		end)

		Input._input.Focused:Connect(function()
			Input.Value:set(_K.Util.String.trimEnd(Input._input.Text), true)
		end)

		Input._input.FocusLost:Connect(function(enterPressed)
			if enterPressed then
				local data = currentCompletionData
				if #data.invalid > 0 then
					UI.Sound.Negative:Play()
					return Input._input:CaptureFocus()
				end

				if Input._input.Text ~= prefix and #data.commands < 1 then
					UI.Sound.Negative:Play()
					return Input._input:CaptureFocus()
				end

				for _, command in data.commands do
					if command.invalidArg then
						UI.Sound.Negative:Play()
						return Input._input:CaptureFocus()
					end
				end

				hideCommandBar()

				-- ignore empty command strings
				if Input._input.Text == prefix then
					return
				end

				if
					currentCompletion
					and not currentCompletion[4]
					and data.suggestionType ~= "History"
					and #data.suggestions > 1
				then
					fillSuggestion()
					task.defer(Input._input.ReleaseFocus, Input._input)
				end

				-- FIX: if validated lol
				local trimmed = _K.Util.String.trimEnd(Input._input.Text)
				task.spawn(_K.Process.runCommands, _K, _K.LocalPlayer.UserId, trimmed)
				-- Find the command in the history (and remove if not the most recent)
				local cmd = string.sub(trimmed, 2)
				local foundIndex = table.find(commandHistory, cmd)
				if foundIndex ~= 1 then
					if foundIndex then
						table.remove(commandHistory, foundIndex)
					end
					table.insert(commandHistory, 1, cmd)
					if #commandHistory > 32 then
						table.remove(commandHistory)
					end
				end
				Input.Value:set(prefix, true)
			end
			return
		end)

		Input._input:GetPropertyChangedSignal("Text"):Connect(function()
			if currentCompletion and UserInputService:IsKeyDown(Enum.KeyCode.Tab) then
				completeSuggestion()
				return
			end

			local prefixLen = #prefix
			local text = Input._input.Text

			if string.find(text, prefix, 1, true) ~= 1 then
				Input._input.CursorPosition += prefixLen
				Input.Value:set(prefix .. text, true)
				Input._input.CursorPosition += prefixLen
				return
			else -- trim whitespace after prefix
				local trimmed = prefix .. _K.Util.String.trimStart(string.sub(text, prefixLen + 1))
				if trimmed ~= Input._input.Text then
					Input.Value:set(trimmed, true)
					return
				end
			end

			if text ~= prefix then
				if string.find(text, prefix, prefixLen + 1, true) == prefixLen + 1 then
					text = string.sub(text, prefixLen + 1)
					Input.Value:set(text, true)
					return
				end
				Input.DisplayText:set(_K.Util.String.escapeRichText(text), true)
			end
		end)
	end,
	show = function()
		if _K.client.toggleCommandBar._instance.Visible then
			_K.client.TopbarPlus.setTopbarEnabled(false)
			coreGuiEnabled(false)
			CommandBar.Visible = true
			task.wait()
			Input._input:CaptureFocus()
		end
	end,
	hide = hideCommandBar,
}
