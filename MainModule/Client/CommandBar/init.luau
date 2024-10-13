local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local TextService = game:GetService("TextService")

local _K = require(script.Parent.Parent)
local CompletionData = require(script.CompletionData)

local UI = _K.UI

local validState = UI.state(nil)
local indicatorColor = UI.compute(function(use)
	local valid = use(validState)
	if valid == true then
		return use(UI.Theme.Valid)
	elseif valid == false then
		return use(UI.Theme.Invalid)
	else
		return Color3.new(1, 1, 1)
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
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Position = UDim2.new(0.5, 0, 0.5, 0),
				Size = UDim2.new(0, 14, 0, 14),
				ImageColor3 = Color3.new(0, 1, 0),
				Image = "rbxassetid://2340153468",
				Visible = UI.compute(function(use)
					return use(validState) == true
				end),
			},

			UI.new "ImageLabel" {
				Name = "Invalid",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Position = UDim2.new(0.5, 0, 0.5, 0),
				Size = UDim2.new(0, 10, 0, 10),
				ImageColor3 = Color3.new(1, 0, 0),
				Image = "rbxassetid://1476571006",
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

	-- [UI.Hook] = {
	-- 	Value = function(text)
	-- 		-- TODO: do what it used to do on text changed?
	-- 	end,
	-- },
}

UI.edit(Input._instance.UICorner, {
	CornerRadius = if UI.LegacyTopBar._value then UDim.new(0, 9) else UDim.new(1, 0),
})

UI.edit(Input._instance.UIListLayout, {
	Padding = UDim.new(0, if UI.LegacyTopBar._value then 6 else 12),
})

UI.edit(Input._instance.UIPadding, {
	PaddingLeft = UDim.new(0, if UI.LegacyTopBar._value then 6 else 12),
	PaddingRight = UDim.new(0, if UI.LegacyTopBar._value then 6 else 12),
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

local invalidStroke = UI.edit(Input._instance.UIStroke, {
	Thickness = 2,
	Color = UI.Theme.Invalid,
	Enabled = false,
})

local TooltipFrame = UI.new "Frame" {
	Parent = CommandBar,
	Name = "Tooltip",
	Active = true,
	BackgroundColor3 = UI.Theme.Primary,
	BackgroundTransparency = UI.Theme.Transparency,
	Size = UDim2.fromOffset(200, 32),
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
	Size = UI.computeFrom(UDim2.new, 1, 0, 0, UI.Theme.FontSize),
	TextWrapped = true,
	RichText = true,
	Font = UI.Theme.FontMono,
	TextSize = 20,
	TextColor3 = UI.Theme.PrimaryText,
	TextXAlignment = Enum.TextXAlignment.Left,

	UI.new "UIPadding" {
		PaddingTop = UI.Theme.Padding,
		PaddingBottom = UI.Theme.Padding,
		PaddingLeft = UI.Theme.Padding,
		PaddingRight = UI.Theme.Padding,
	},
}

Tooltip:GetPropertyChangedSignal("TextBounds"):Connect(function()
	Tooltip.Size = UDim2.new(1, 0, 0, Tooltip.TextBounds.Y + UI.Theme.Padding._value.Offset * 2)
end)

TooltipLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	TooltipFrame.Size = UDim2.fromOffset(256, TooltipLayout.AbsoluteContentSize.Y + UI.Theme.Padding._value.Offset / 2)
end)

local SuggestionFrame = UI.new "TextButton" {
	AutoLocalize = false,
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
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0),
		RichText = true,
		Font = UI.Theme.FontMono,
		TextSize = 20,
		TextColor3 = UI.Theme.PrimaryText,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.SplitWord,

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
	`<font transparency="0.33">%s</font>%s<font transparency="0.33">%s<font transparency="0.66">%s</font>%s</font>`
local suggestFormat = `%s<font transparency="0.5">%s</font>`

local suggestionIndex = 1
local suggestionLabels = {}

local updateCompletion, currentCompletion, tabCompleting
local function completeSuggestion()
	if not currentCompletion then
		return
	end
	tabCompleting = true

	local pos, text = unpack(currentCompletion)
	if not string.find(text, " $") then
		text = text .. " "
		pos += 1
	end
	Input._input.Text = text
	Input._input.CursorPosition = pos + 1
	tabCompleting = false
end

local suggestionUpdating
local function updateSuggestionLabels(data)
	if suggestionUpdating then
		return
	end
	suggestionUpdating = true
	for _, label in suggestionLabels do
		label:Destroy()
	end
	table.clear(suggestionLabels)

	local amount = math.min(7, #data.suggestions - 1)
	local start = math.max(1, suggestionIndex - 7)

	for i = start, start + amount do
		local suggestion = data.suggestions[i]
		local name, value, displayName = unpack(suggestion)
		local frame = SuggestionFrame:Clone()
		local label = frame:FindFirstChildOfClass("TextLabel")
		frame.LayoutOrder = i
		frame.BackgroundTransparency = if i == suggestionIndex then 0.9 else 0.95

		displayName = displayName or name

		local valueType = typeof(value)
		if valueType == "Instance" and value:IsA("Player") then
			displayName = `{name} ({if name == value.DisplayName then "@" .. value.Name else value.DisplayName})`
			UI.new "ImageLabel" {
				Parent = frame,
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, 0, 0, 0),
				Size = UDim2.new(1, 0, 1, 0),
				SizeConstraint = Enum.SizeConstraint.RelativeYY,
				Image = `rbxthumb://type=AvatarHeadShot&id={value.UserId}&w=48&h=48`,
			}
		elseif valueType == "Color3" or valueType == "BrickColor" then
			UI.new "Frame" {
				Parent = frame,
				BackgroundColor3 = if valueType == "BrickColor" then value.Color else value,
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, 0, 0, 0),
				Size = UDim2.new(1, 0, 1, 0),
				SizeConstraint = Enum.SizeConstraint.RelativeYY,
			}
		end

		label.Text = string.format(
			suggestFormat,
			string.sub(displayName, 1, #data.query),
			string.sub(displayName, #data.query + 1)
		)
		frame.Activated:Connect(function()
			Input._input:CaptureFocus()
			suggestionIndex = i
			updateCompletion()
			completeSuggestion()
		end)
		frame.Parent = TooltipFrame
		-- show highlight
		table.insert(suggestionLabels, frame)
	end
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

local function invalidSuggestion(data, err, pos, text)
	validState:set(false)
	-- red text inlineFormat
	Input.DisplayText:set(
		`<font transparency="0.33">{_K.Util.String.escapeRichText(string.sub(data.message, 1, pos - 1))}<font color="#f00" transparency="0"><b>{_K.Util.String.escapeRichText(
			text
		)}</b></font>{_K.Util.String.escapeRichText(string.sub(data.message, pos + #text))}</font>`
	)
	-- TODO: command definition
	Tooltip.Text = if not data.argDefinition
		then ""
		else string.format(
			argumentFormat,
			_K.Util.String.escapeRichText(data.argDefinition.displayName or data.argDefinition.name),
			_K.Util.String.escapeRichText(data.argDefinition.type),
			data.argDefinition.description
		)
	for _, label in suggestionLabels do
		label:Destroy()
	end
	-- FIX: inline all the invalids and only show tooltip for first
	table.clear(suggestionLabels)
	local frame = SuggestionFrame:Clone()
	local label = frame:FindFirstChildOfClass("TextLabel")
	label.Text = `<font color="#f00"><b>{_K.Util.String.escapeRichText(err)}</b></font>`
	frame.Parent = TooltipFrame
	-- show highlight
	table.insert(suggestionLabels, frame)

	TooltipFrame.Visible = true

	if not data.suggestions or not data.suggestions[suggestionIndex] then
		return
	end

	local currentSuggestion = data.suggestions[suggestionIndex]
	local suggestionText, suggestionValue = unpack(currentSuggestion)
	if data.argIndex == 1 then -- command
		-- TODO: inline argument types if command
		-- show command aliases too!
		Tooltip.Text = string.format(
			argumentFormat,
			_K.Util.String.escapeRichText(suggestionText),
			"command",
			suggestionValue.description
		)
	end
	return
end

local commandHistory = {}
local currentCompletionData
updateCompletion = function()
	local data = currentCompletionData
	currentCompletion = nil

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
		validState:set(false)
		invalidSuggestion(data, unpack(invalid))
		return
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
			_K.Util.String.escapeRichText(data.argDefinition.type),
			data.argDefinition.description
		)
		TooltipFrame.Visible = true
		-- TODO: some types should show a widget for fast select e.g. color wheel
	end

	-- move tooltip to start of query
	-- FIX: adjust with inputoffset
	-- FIX: assign greedy pos that's used instead!
	local argX = TextService:GetTextSize(
		string.sub(data.message, 1, data.argPos - 1),
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

	-- local firstSuggestion = data.suggestions[1][1]
	-- local firstValue = data.suggestions[1][2]
	local endPos = data.argPos + #data.rawArg
	local currentSuggestion = data.suggestions[suggestionIndex]
	local suggestionText, suggestionValue = unpack(currentSuggestion)

	if data.query ~= "" then
		local reservedCharacters = { " ", _K.Data.settings.prefix }
		for _, char in reservedCharacters do
			if string.find(suggestionText, char) and not string.find(suggestionText, '^["`]') then
				suggestionText = `"{suggestionText}"`
				break
			end
		end
	end

	currentCompletion = {
		data.argPos + #suggestionText,
		string.sub(data.message, 1, data.argPos - 1) .. suggestionText .. string.sub(data.message, endPos),
	}

	-- inline format (preceding message, query, post query arg, suggestion, post query message)
	-- FIX: how to not escape invalid/valid rich text coloring?
	-- need a way to merge it somehow? (or don't use richtext maybe red underline instead! with a button you can hover to show error tooltip :)
	Input.DisplayText:set(
		string.format(
			inlineFormat,
			_K.Util.String.escapeRichText(string.sub(data.message, 1, data.argPos - 1)),
			_K.Util.String.escapeRichText(data.query),
			_K.Util.String.escapeRichText(string.sub(data.rawArg, #data.query + 1)),
			_K.Util.String.escapeRichText(string.sub(suggestionText, #data.rawArg + 1)),
			_K.Util.String.escapeRichText(string.sub(data.message, endPos))
		)
	)

	-- show completion tooltip
	if data.argIndex == 1 then -- command
		-- TODO: inline argument types if command
		-- show command aliases too!
		Tooltip.Text = string.format(
			argumentFormat,
			_K.Util.String.escapeRichText(suggestionText),
			"command",
			suggestionValue.description
		)
	end
	if data.argDefinition or data.argIndex == 1 then
		updateSuggestionLabels(data)
		TooltipFrame.Visible = true
	end

	return
end

local function updateCompletionData()
	for _, label in suggestionLabels do
		label:Destroy()
	end
	table.clear(suggestionLabels)
	suggestionIndex = 1
	currentCompletionData = CompletionData(_K, Input._input.Text, Input._input.CursorPosition)
	updateCompletion()
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
			if
				coreType ~= Enum.CoreGuiType.Chat
				and coreType ~= Enum.CoreGuiType.Captures
				and coreType ~= Enum.CoreGuiType.Health
			then
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
		Input._input.TextEditable = false
		CommandBar.Visible = false
		if _K.client then
			_K.client.TopbarPlus.setTopbarEnabled(true)
		end
		coreGuiEnabled(true)
	end
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if input.UserInputType == Enum.UserInputType.Keyboard then
		if not Input._input:IsFocused() then
			return
		end
		local max = currentCompletionData.suggestions and #currentCompletionData.suggestions
		if input.KeyCode == Enum.KeyCode.Up then
			if currentCompletionData.suggestionType == "History" then
				suggestionIndex = math.min(math.max(1, max), suggestionIndex + 1)
			else
				suggestionIndex = math.max(1, suggestionIndex - 1)
			end
			updateCompletion()
		elseif input.KeyCode == Enum.KeyCode.Down then
			if currentCompletionData.suggestionType == "History" then
				suggestionIndex = math.max(1, suggestionIndex - 1)
			else
				suggestionIndex = math.min(math.max(1, max), suggestionIndex + 1)
			end
			updateCompletion()
		end
	elseif
		input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
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
		if cursorPosition < #_K.Data.settings.prefix + 1 then
			Input._input.CursorPosition = #_K.Data.settings.prefix + 1
			return
		end
		task.defer(updateCompletionData)
	end
end)

Input._input.Focused:Connect(function()
	invalidStroke.Enabled = false
	-- prevent input hotkey from being captured
	task.delay(0, function()
		if CommandBar.Visible then
			Input._input.TextEditable = true
		end
	end)
end)

Input._input.FocusLost:Connect(function(enterPressed)
	if enterPressed then
		invalidStroke.Enabled = true
		Input._input.TextEditable = false

		local data = currentCompletionData
		if #data.invalid > 0 then
			UI.Sound.Negative:Play()
			return
		end

		if Input._input.Text ~= _K.Data.settings.prefix and #data.commands < 1 then
			validState:set(false)
			UI.Sound.Negative:Play()
			invalidSuggestion(data, "Invalid command", data.argPos, data.rawArg)
			return
		end

		for _, command in data.commands do
			if command.invalidArg then
				validState:set(false)
				UI.Sound.Negative:Play()
				invalidSuggestion(
					data,
					command.argMissing or command.invalidMessage,
					command.invalidPos,
					command.invalidArg
				)
				return
			end
		end

		hideCommandBar()

		-- ignore empty command strings
		if Input._input.Text == _K.Data.settings.prefix then
			return
		end

		-- FIX: if validated lol
		_K.Remote.Command:FireServer(Input._input.Text)
		task.spawn(_K.Process.runCommands, _K, _K.Services.Players.LocalPlayer.UserId, Input._input.Text)
		-- Find the command in the history (and remove if not the most recent)
		local cmd = string.sub(Input._input.Text, 2)
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
		Input._input.Text = _K.Data.settings.prefix
	end
end)
-- FIX: make sure _K reliant connections aren't connected until init!
Input._input:GetPropertyChangedSignal("Text"):Connect(function()
	if not tabCompleting and UserInputService:IsKeyDown(Enum.KeyCode.Tab) then
		completeSuggestion()
		return
	end
	local prefix = _K.Data.settings.prefix
	if string.find(Input._input.Text, prefix, 1, true) ~= 1 then
		Input._input.CursorPosition += 1
		Input._input.Text = prefix .. Input._input.Text
		Input._input.CursorPosition += 1
		return
	end

	if Input._input.Text == _K.Data.settings.prefix then
		Input.DisplayText:set(Input._input.Text .. "<font transparency='0.5'><i>command</i></font>")
	else
		Input.DisplayText:set(_K.Util.String.escapeRichText(Input._input.Text))
	end
end)

return {
	Bar = CommandBar,
	Input = Input,
	init = function(self, _K)
		Input._input.Text = _K.Data.settings.prefix
		Input._input.TextEditable = false
		CommandBar.Parent = UI.TopBarFrame
		_K.client.hotkeys.commandBar = { key = UI.state(Enum.KeyCode.Semicolon), mods = {}, callback = self.show }
		_K.client.CommandBarState = { validState, indicatorColor }
		UI.Scope.settings.prefix:hook(function(value)
			if value then
				Input._input.Text = value .. string.sub(Input._input.Text, #value + 1)
			end
		end)
	end,
	show = function()
		_K.client.TopbarPlus.setTopbarEnabled(false)
		coreGuiEnabled(false)
		CommandBar.Visible = true
		Input._input:CaptureFocus()
	end,
	hide = hideCommandBar,
}
