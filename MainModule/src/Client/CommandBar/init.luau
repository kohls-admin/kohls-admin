local UserInputService = game:GetService("UserInputService")
local TextChatService = game:GetService("TextChatService")
local TextService = game:GetService("TextService")

local Clack = require(script.Clack)
local CompletionData = require(script.CompletionData)

local ChatInputBarConfiguration = TextChatService:FindFirstChildOfClass("ChatInputBarConfiguration")

local _K = nil

local CommandBar = Instance.new("Frame")
CommandBar.Name = "CommandBar"
CommandBar.AnchorPoint = Vector2.new(0.5, 0.5)
CommandBar.Size = UDim2.new(0, 512, 0, 32)
CommandBar.Position = UDim2.new(0.5, 0, 0.5, 0)
CommandBar.BackgroundColor3 = Color3.new(0, 0, 0)
CommandBar.BackgroundTransparency = 0.3
CommandBar.ZIndex = 100
CommandBar.Visible = false

local UICorner = Instance.new("UICorner", CommandBar)
UICorner.CornerRadius = UDim.new(1, 0)

local InputFrame = Instance.new("Frame", CommandBar)
InputFrame.Name = "Input"
InputFrame.ClipsDescendants = true
InputFrame.BackgroundTransparency = 1
InputFrame.Size = UDim2.new(1, 0, 1, 0)

local InputMask = InputFrame:Clone()
InputMask.Name = "InputMask"
InputMask.Parent = InputFrame
InputMask.Position = UDim2.new(0, 20, 0, 0)
InputMask.Size = UDim2.new(1, -20, 1, 0)

local UIPadding = Instance.new("UIPadding", InputFrame)
UIPadding.PaddingTop = UDim.new(0, 8)
UIPadding.PaddingBottom = UDim.new(0, 8)
UIPadding.PaddingLeft = UDim.new(0, 8)
UIPadding.PaddingRight = UDim.new(0, 8)

local CircleButton = Instance.new("Frame", InputFrame)
CircleButton.Name = "CircleButton"
CircleButton.BackgroundTransparency = 1
CircleButton.Size = UDim2.new(1, 0, 1, 0)
CircleButton.SizeConstraint = Enum.SizeConstraint.RelativeYY
Instance.new("UICorner", CircleButton).CornerRadius = UDim.new(1, 0)
local CircleStroke = Instance.new("UIStroke", CircleButton)
CircleStroke.Thickness = 2
local CircleIconValid = Instance.new("ImageLabel", CircleButton)
CircleIconValid.Name = "Icon"
CircleIconValid.AnchorPoint = Vector2.new(0.5, 0.5)
CircleIconValid.BackgroundTransparency = 1
CircleIconValid.Position = UDim2.new(0.5, 0, 0.5, 0)
CircleIconValid.Size = UDim2.new(0, 14, 0, 14)
CircleIconValid.ImageColor3 = Color3.new(0, 1, 0)
CircleIconValid.Image = "rbxassetid://2340153468"
-- CircleIconValid.ResampleMode = Enum.ResamplerMode.Pixelated
CircleIconValid.ImageTransparency = 0
CircleIconValid.Visible = false
local CircleIconInvalid = CircleIconValid:Clone()
CircleIconInvalid.Parent = CircleButton
CircleIconInvalid.Size = UDim2.new(0, 10, 0, 10)
CircleIconInvalid.ImageColor3 = Color3.new(1, 0, 0)
CircleIconInvalid.Image = "rbxassetid://1476571006"

local Input = Instance.new("TextBox", InputMask)
Input.TextEditable = false
Input.AutoLocalize = false
Input.ClearTextOnFocus = false
Input.Size = UDim2.new(1, -32, 1, 0)
Input.BackgroundTransparency = 1
Input.TextTransparency = 1
Input.TextSize = 16
Input.TextColor3 = Color3.new(1, 1, 1)
Input.Font = Enum.Font.RobotoMono
Input.RichText = true
Input.TextXAlignment = Enum.TextXAlignment.Left
Input.TextYAlignment = Enum.TextYAlignment.Center
-- TODO: add a send button for touch input

-- for inline autocomplete suggestion/warning
local InputLabel = Instance.new("TextLabel", Input)
InputLabel.AutoLocalize = false
InputLabel.Size = UDim2.new(1, 0, 1, 0)
InputLabel.BackgroundTransparency = 1
InputLabel.TextSize = Input.TextSize
InputLabel.TextColor3 = Color3.new(1, 1, 1)
InputLabel.Font = Enum.Font.RobotoMono
InputLabel.RichText = true
InputLabel.TextXAlignment = Enum.TextXAlignment.Left
InputLabel.TextYAlignment = Enum.TextYAlignment.Center

local Cursor = InputLabel:Clone()
Cursor.Parent = InputFrame
Cursor.Name = "Cursor"
Cursor.Size = UDim2.new(0, 12, 1, 0)
Cursor.Position = UDim2.new(0, 0, 0, 0)
Cursor.Text = "_"
Cursor.Visible = false

local Selection = Instance.new("Frame", InputMask)
Selection.Name = "Selection"
Selection.AnchorPoint = Vector2.new(0, 0.5)
Selection.BackgroundTransparency = 0.75
Selection.Size = UDim2.new(0, 0, 0, Input.TextSize)
Selection.Position = UDim2.new(0, 0, 0.5, 0)
Selection.BackgroundColor3 = Color3.new(1, 1, 1)
Selection.BorderSizePixel = 0
Selection.Visible = false

local TooltipFrame = Instance.new("Frame", CommandBar)
TooltipFrame.Name = "Tooltip"
TooltipFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
TooltipFrame.BackgroundTransparency = 0.3
TooltipFrame.Size = UDim2.fromOffset(200, 32)
TooltipFrame.Visible = false

Instance.new("UICorner", TooltipFrame).CornerRadius = UDim.new(0, 8)

local TooltipLayout = Instance.new("UIListLayout", TooltipFrame)
TooltipLayout.SortOrder = Enum.SortOrder.LayoutOrder
TooltipLayout.Padding = UDim.new(0, 0)

local Tooltip = Instance.new("TextLabel", TooltipFrame)
Tooltip.LayoutOrder = 0
Tooltip.Name = "Tooltip"
Tooltip.BackgroundTransparency = 1
Tooltip.Size = UDim2.new(1, 0, 0, Tooltip.TextSize)
Tooltip.TextWrapped = true
Tooltip.RichText = true
Tooltip.Font = Enum.Font.RobotoMono
Tooltip.TextSize = 16
Tooltip.TextColor3 = Color3.new(1, 1, 1)
Tooltip.TextXAlignment = Enum.TextXAlignment.Left
-- Tooltip.TextYAlignment = Enum.TextYAlignment.Top

local TooltipPadding = Instance.new("UIPadding", Tooltip)
TooltipPadding.PaddingTop = UDim.new(0, 8)
TooltipPadding.PaddingBottom = UDim.new(0, 8)
TooltipPadding.PaddingLeft = UDim.new(0, 8)
TooltipPadding.PaddingRight = UDim.new(0, 8)

Tooltip:GetPropertyChangedSignal("TextBounds"):Connect(function()
	Tooltip.Size = UDim2.new(1, 0, 0, Tooltip.TextBounds.Y + TooltipPadding.PaddingTop.Offset * 2)
end)

TooltipLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	TooltipFrame.Size =
		UDim2.fromOffset(256, TooltipLayout.AbsoluteContentSize.Y + TooltipPadding.PaddingTop.Offset / 2)
end)

local SuggestionFrame = Instance.new("Frame")
SuggestionFrame.Name = "Suggestion"
SuggestionFrame.BackgroundTransparency = 0.9
SuggestionFrame.BackgroundColor3 = Color3.new(1, 1, 1)
SuggestionFrame.Size = UDim2.new(1, 0, 0, Tooltip.TextSize + TooltipPadding.PaddingTop.Offset)

local SuggestionLabel = Tooltip:Clone()
SuggestionLabel.Name = "Label"
SuggestionLabel.Size = UDim2.new(1, 0, 1, 0)
SuggestionLabel.TextXAlignment = Enum.TextXAlignment.Left
SuggestionLabel.TextYAlignment = Enum.TextYAlignment.Center
SuggestionLabel.Parent = SuggestionFrame

local SuggestionPadding = SuggestionLabel:FindFirstChildOfClass("UIPadding")
SuggestionPadding.PaddingTop = UDim.new(0, TooltipPadding.PaddingTop.Offset / 2)
SuggestionPadding.PaddingBottom = SuggestionPadding.PaddingTop

local argumentFormat =
	`<b><sc>%s</sc> <font transparency="0.66" size="15"><i>&lt;%s&gt;</i></font></b>\n<font size="14">%s</font>`
local inlineFormat =
	`<font transparency="0.33">%s</font>%s<font transparency="0.33">%s</font><font transparency="0.66">%s</font>%s`
local suggestFormat = `%s<font transparency="0.5">%s</font>`

local playerThumbs = {}

local suggestionIndex = 1
local suggestionLabels = {}

local function updateSuggestionLabels(data)
	for _, label in suggestionLabels do
		label:Destroy()
	end
	table.clear(suggestionLabels)

	local argType
	if data.argDefinition then
		argType = data.argDefinition.type
		if argType:find("player") == 1 then
			argType = "player"
		end
	end

	for i, suggestion in data.suggestions do
		local name, value = unpack(suggestion)
		local frame = SuggestionFrame:Clone()
		local label = frame:FindFirstChildOfClass("TextLabel")
		frame.LayoutOrder = i
		frame.BackgroundTransparency = if i == suggestionIndex then 0.9 else 0.95

		if argType == "player" then
			name = `{name} ({value.DisplayName})`
			local userId = value.UserId
			local image = playerThumbs[tostring(userId)]
			if not image then
				image = _K.Util.Services.Players:GetUserThumbnailAsync(
					userId,
					Enum.ThumbnailType.HeadShot,
					Enum.ThumbnailSize.Size48x48
				)
				playerThumbs[tostring(userId)] = image
			end
			local thumb = Instance.new("ImageLabel", frame)
			thumb.AnchorPoint = Vector2.new(1, 0)
			thumb.BackgroundTransparency = 1
			thumb.Size = UDim2.new(1, 0, 1, 0)
			thumb.Position = UDim2.new(1, 0, 0, 0)
			thumb.Image = image
			thumb.SizeConstraint = Enum.SizeConstraint.RelativeYY
		end

		label.Text = string.format(suggestFormat, data.query, string.sub(name, #data.query + 1))
		frame.Parent = TooltipFrame
		-- show highlight
		table.insert(suggestionLabels, frame)
	end
end

local function clearCompletion()
	TooltipFrame.Visible = false
	InputLabel.Text = _K.Util.escapeRichText(Input.Text)
	for _, label in suggestionLabels do
		label:Destroy()
	end
	table.clear(suggestionLabels)
end

local commandHistory = {}
local currentCompletion, currentCompletionData
local function updateCompletion()
	local data = currentCompletionData
	currentCompletion = nil
	print("auto", data)

	if data.suggestionType == "History" then
		TooltipFrame.Visible = false
		data.suggestions = table.create(#commandHistory)
		for _, cmd in commandHistory do
			table.insert(data.suggestions, { cmd })
		end
	end

	CircleStroke.Color = Color3.new(1, 1, 1)
	CircleIconValid.Visible = false
	CircleIconInvalid.Visible = false

	-- handle validation hints
	-- TODO: somehow show validated arguments/text as green :)
	for _, invalid in data.invalid do
		CircleStroke.Color = Color3.new(1, 0, 0)
		CircleIconInvalid.Visible = true
		print("invalid", invalid)
		local pos, text, err = unpack(invalid)
		-- red text inlineFormat
		InputLabel.Text =
			`<font transparency="0.33">{_K.Util.escapeRichText(string.sub(data.message, 1, pos - 1))}<font color="#f00" transparency="0"><b>{_K.Util.escapeRichText(
				text
			)}</b></font>{_K.Util.escapeRichText(string.sub(data.message, pos + #text))}</font>`
		Tooltip.Text = if not data.argDefinition
			then ""
			else string.format(
				argumentFormat,
				_K.Util.escapeRichText(data.argDefinition.displayName or data.argDefinition.name),
				_K.Util.escapeRichText(data.argDefinition.type),
				_K.Util.escapeRichText(data.argDefinition.description)
			)
		for _, label in suggestionLabels do
			label:Destroy()
		end
		-- FIX: inline all the invalids and only show tooltip for first
		table.clear(suggestionLabels)
		local frame = SuggestionFrame:Clone()
		local label = frame:FindFirstChildOfClass("TextLabel")
		label.Text = `<font color="#f00"><b>{_K.Util.escapeRichText(err)}</b></font>`
		frame.Parent = TooltipFrame
		-- show highlight
		table.insert(suggestionLabels, frame)

		TooltipFrame.Visible = true
		return
	end

	-- TODO: check if every argument for every command is valid somehow!
	-- and then show valid icon and color :)

	if not data.suggestionType then
		return clearCompletion() -- no suggestions without argument type
	end
	-- show normal argument type hints here!
	if data.argDefinition then
		print("argDef", data.argDefinition)
		Tooltip.Text = string.format(
			argumentFormat,
			_K.Util.escapeRichText(data.argDefinition.displayName or data.argDefinition.name),
			_K.Util.escapeRichText(data.argDefinition.type),
			_K.Util.escapeRichText(data.argDefinition.description)
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
	TooltipFrame.Position = UDim2.new(0, argX + 20, 1, 4)

	if not (data.suggestions and #data.suggestions > 0) then
		print("nothing to suggest")
		return
	end
	-- suggestion hints

	-- local firstSuggestion = data.suggestions[1][1]
	-- local firstValue = data.suggestions[1][2]
	local endPos = data.argPos + #data.rawArg
	local currentSuggestion = data.suggestions[suggestionIndex]
	print(suggestionIndex, #data.suggestions)
	local suggestionText, suggestionValue = unpack(currentSuggestion)

	currentCompletion = {
		data.argPos + #suggestionText,
		string.sub(data.message, 1, data.argPos - 1) .. suggestionText .. string.sub(data.message, endPos),
	}

	-- inline format (preceding message, query, post query arg, suggestion, post query message)
	-- FIX: how to not escape invalid/valid rich text coloring?
	-- need a way to merge it somehow? (or don't use richtext maybe red underline instead! with a button you can hover to show error tooltip :)
	InputLabel.Text = string.format(
		inlineFormat,
		_K.Util.escapeRichText(string.sub(data.message, 1, data.argPos - 1)),
		_K.Util.escapeRichText(data.query),
		_K.Util.escapeRichText(string.sub(data.rawArg, #data.query + 1)),
		_K.Util.escapeRichText(string.sub(suggestionText, #data.rawArg + 1)),
		_K.Util.escapeRichText(string.sub(data.message, endPos))
	)

	-- show completion tooltip
	if data.argIndex == 1 then -- command
		-- TODO: inline argument types if command
		-- show command aliases too!
		Tooltip.Text = string.format(
			argumentFormat,
			_K.Util.escapeRichText(suggestionText),
			"command",
			_K.Util.escapeRichText(suggestionValue.description)
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
	currentCompletionData = CompletionData(_K, Input.Text, Input.CursorPosition)
	updateCompletion()
end

local function bytePositionToWidth(text, size, font, bytePosition)
	if bytePosition == 1 then
		return 0
	end
	local sub = string.sub(text, 1, bytePosition - 1)
	local bounds = TextService:GetTextSize(sub, size, font, Vector2.zero)
	return bounds.X
end

local inputOffset = 0

local function updateSelection()
	local cursorWidth = bytePositionToWidth(Input.Text, Input.TextSize, Input.Font, Input.CursorPosition)
	local selectWidth = bytePositionToWidth(Input.Text, Input.TextSize, Input.Font, Input.SelectionStart)
	local deltaWidth = cursorWidth - selectWidth

	Selection.Size = UDim2.new(0, deltaWidth, 1, 0)
	Selection.Position = UDim2.new(0, selectWidth - inputOffset, 0.5, 0)
	Selection.Visible = true
end

Input:GetPropertyChangedSignal("SelectionStart"):Connect(function()
	if Input.SelectionStart == -1 then
		Selection.Visible = false
	else
		updateSelection()
	end
end)

local function updateCursor()
	-- if Input.CursorPosition == -1 then
	-- 	return
	-- end

	local textWidthToCursor = bytePositionToWidth(Input.Text, Input.TextSize, Input.Font, Input.CursorPosition)
	local visibleWidth = InputMask.AbsoluteSize.X
	local cursorOffset = textWidthToCursor - inputOffset

	local margin = if (Input.TextBounds.X > visibleWidth or inputOffset > 0) and textWidthToCursor > 32 then 32 else 0
	if cursorOffset > visibleWidth then
		inputOffset += cursorOffset - visibleWidth
		inputOffset = math.min(inputOffset, Input.TextBounds.X)
		cursorOffset = visibleWidth
	elseif cursorOffset < margin then
		inputOffset += cursorOffset - margin
		if margin == 0 or inputOffset <= Input.TextSize / 2 then
			inputOffset = math.min(0, inputOffset)
		end
		cursorOffset = margin
	end

	Input.Position = UDim2.fromOffset(-inputOffset, 0)
	Cursor.Position = UDim2.fromOffset(cursorOffset + 20, 1)

	Cursor.Visible = true

	if Input.SelectionStart ~= -1 then
		updateSelection()
	end
end

local focused, textBoxFocused = {}, false
UserInputService.TextBoxFocused:Connect(function(textbox)
	if not textbox then
		return
	end
	focused[textbox] = true
	textBoxFocused = true
end)

UserInputService.TextBoxFocusReleased:Connect(function(textbox)
	if not textbox then
		return
	end
	focused[textbox] = nil
	if next(focused) then
		return
	end
	textBoxFocused = false
end)

local tabCompleting
UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
	if not (textBoxFocused or ChatInputBarConfiguration.IsFocused) then
		return
	end
	if input.UserInputType == Enum.UserInputType.Keyboard then
		-- TODO: check for tab to complete suggestion
		-- TODO: check for up/down arrow to adjust suggestion index and update suggestion labels without deleting!
		task.spawn(Clack.sound, input.KeyCode)
		if not Input:IsFocused() then
			return
		end
		if input.KeyCode == Enum.KeyCode.Tab then
			if not currentCompletion then
				return
			end
			tabCompleting = true
			local pos, text = unpack(currentCompletion)
			task.delay(0, function()
				tabCompleting = false
				Input.Text = text
				Input.CursorPosition = pos + 1
			end)
		elseif input.KeyCode == Enum.KeyCode.Up then
			suggestionIndex = math.max(1, suggestionIndex - 1)
			updateCompletion()
		elseif input.KeyCode == Enum.KeyCode.Down then
			local max = currentCompletionData.suggestions and #currentCompletionData.suggestions
			suggestionIndex = math.min(math.max(1, max), suggestionIndex + 1)
			updateCompletion()
		end
	end
end)

Input:GetPropertyChangedSignal("CursorPosition"):Connect(function()
	if Input.CursorPosition == -1 then
		Cursor.Visible = false
	else
		if Input.CursorPosition < #_K.settings.prefix + 1 then
			Input.CursorPosition = #_K.settings.prefix + 1
			return
		end
		if tabCompleting then
			return -- don't show tab artifact
		end
		-- defer for text to register
		task.defer(updateCursor)
		task.defer(updateCompletionData)
	end
end)

Input.FocusLost:Connect(function(enterPressed)
	CommandBar.Visible = false
	Input.TextEditable = false
	if enterPressed then
		task.spawn(_K.Process.runCommands, _K.Services.Players.LocalPlayer, Input.Text)
		-- Find the command in the history (and remove if not the most recent)
		local cmd = string.sub(Input.Text, 2)
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
		Input.Text = _K.settings.prefix
	end
end)
-- FIX: make sure _K reliant connections aren't connected until init!
Input:GetPropertyChangedSignal("Text"):Connect(function()
	if tabCompleting then
		return
	end
	if string.find(Input.Text, _K.settings.prefix, 1, true) ~= 1 then
		Input.Text = _K.settings.prefix .. Input.Text
		Input.CursorPosition += #_K.settings.prefix
		return
	end
	local bounds = TextService:GetTextSize(Input.Text, Input.TextSize, Input.Font, Vector2.zero)

	if bounds.X > InputMask.AbsoluteSize.X then
		Input.Position = UDim2.fromOffset(-inputOffset, 0)
		Input.Size = UDim2.new(0, bounds.X, 1, 0)
	else
		Input.Position = UDim2.new(0, 0, 0, 0)
		Input.Size = UDim2.new(1, 0, 1, 0)
	end
	if Input.Text == _K.settings.prefix then
		InputLabel.Text = Input.Text .. "<font transparency='0.5'><i>command</i></font>"
	else
		InputLabel.Text = _K.Util.escapeRichText(Input.Text)
	end
end)

return {
	init = function(self, context)
		_K = context
		Input.Text = _K.settings.prefix
		CommandBar.Parent = _K.Interface
		_K.hotkeys.commandBar = { key = Enum.KeyCode.Quote, callback = self.show }
	end,
	show = function()
		CommandBar.Visible = true
		Input:CaptureFocus()
		-- prevent input hotkey from being captured
		task.delay(0, function()
			Input.TextEditable = true
		end)
	end,
}
