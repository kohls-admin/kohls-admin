local TextService = game:GetService("TextService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

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
InputFrame.ClipsDescendants = true
InputFrame.BackgroundTransparency = 1
InputFrame.Size = UDim2.new(1, 0, 1, 0)

local InputMask = InputFrame:Clone()
InputMask.Name = "InputMask"
InputMask.Parent = InputFrame

local UIPadding = Instance.new("UIPadding", InputFrame)
UIPadding.PaddingTop = UDim.new(0, 8)
UIPadding.PaddingBottom = UDim.new(0, 8)
UIPadding.PaddingLeft = UDim.new(0, 8)
UIPadding.PaddingRight = UDim.new(0, 8)

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
TooltipFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
TooltipFrame.BackgroundTransparency = 0.3
TooltipFrame.Size = UDim2.fromOffset(200, 32)
TooltipFrame.Visible = false

Instance.new("UICorner", TooltipFrame).CornerRadius = UDim.new(0, 8)

local TooltipLayout = Instance.new("UIListLayout", TooltipFrame)
TooltipLayout.SortOrder = Enum.SortOrder.LayoutOrder
TooltipLayout.Padding = UDim.new(0, 0)

local Tooltip = InputLabel:Clone()
Tooltip.LayoutOrder = 0
Tooltip.Name = "Tooltip"
Tooltip.BackgroundTransparency = 1
Tooltip.Size = UDim2.new(1, 0, 0, Tooltip.TextSize)
Tooltip.TextWrapped = true
Tooltip.TextYAlignment = Enum.TextYAlignment.Top
Tooltip.Parent = TooltipFrame

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
SuggestionLabel.Visible = true
SuggestionLabel.BackgroundTransparency = 1
SuggestionLabel.Size = UDim2.new(1, 0, 1, 0)
SuggestionLabel.TextYAlignment = Enum.TextYAlignment.Center
SuggestionLabel.Parent = SuggestionFrame

local SuggestionPadding = SuggestionLabel:FindFirstChildOfClass("UIPadding")
SuggestionPadding.PaddingTop = UDim.new(0, TooltipPadding.PaddingTop.Offset / 2)
SuggestionPadding.PaddingBottom = SuggestionPadding.PaddingTop

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
	if Input.CursorPosition == -1 then
		return
	end

	local cursorWidth = bytePositionToWidth(Input.Text, Input.TextSize, Input.Font, Input.CursorPosition)
	local offset = cursorWidth - inputOffset
	local maskX = InputMask.AbsoluteSize.X

	if offset > maskX or (inputOffset > 0 and offset < maskX) then
		inputOffset += offset - maskX
		offset = maskX
	elseif offset < 0 then
		inputOffset = 0
	end
	Input.Position = UDim2.fromOffset(-inputOffset, 0)
	Cursor.Position = UDim2.fromOffset(offset, 1)
	Cursor.Visible = true

	if Input.SelectionStart ~= -1 then
		updateSelection()
	end
end

local function autocompleteData(message)
	local cursorPosition = Input.CursorPosition

	local data = {
		invalid = {
			-- {argPos, rawArg, text}
		},
	}

	-- TODO: if message is prefix then show command history suggestions! (or all commands)
	if message == _K.settings.prefix then
		data.query = ""
		data.rawArg = ""
		data.argPos = 2
		data.argIndex = 1
		data.suggestionType = _K.Registry.types.command
		data.suggestions = {}
		for alias, value in _K.Registry.commands do
			table.insert(data.suggestions, { alias, value })
		end
		return data
	end

	local rawCommands = _K.Process.rawParse(_K.Util.trimStart(message), _K.settings.prefix)
	if not rawCommands then
		table.insert(data.invalid, { 1, message, "Invalid command" })
		return data -- invalid command string, show valid example
	end

	for _, commandArray in rawCommands do
		local commandDefinition = _K.Registry.commands[string.lower(commandArray[1][2])]
		local lastArg = commandArray[#commandArray]

		if cursorPosition < commandArray[1][1] or cursorPosition > lastArg[1] + #lastArg[2] then
			continue -- cursor not within commandArray
		end

		local lastArgDefinition = commandDefinition and commandDefinition.args[#commandDefinition.args]

		for i, arg in commandArray do
			local argPos, rawArg = unpack(arg)
			-- FIX: need to validate every command/argument even if not in cursor...
			local query = string.sub(rawArg, 1, cursorPosition - argPos)
			data.query = query
			data.rawArg = rawArg
			data.argPos = argPos
			data.argIndex = i
			data.commandDefinition = commandDefinition
			if i == 1 then -- command suggestions
				data.suggestionType = _K.Registry.types.command
				data.suggestions = _K.Registry.types.command.suggestions(query)
				if #data.suggestions < 1 then
					table.insert(data.invalid, { argPos, rawArg, "Invalid command" })
					return data
				end
			else
				-- validate command
				if not commandDefinition then
					-- invalid command feedback
					table.insert(data.invalid, { argPos, rawArg, "Invalid command" })
					return data
				end
				local argDefinition = commandDefinition.args[i - 1]
				-- complete argument
				if not argDefinition then
					-- check if last arg is greedy string, if not invalidate?
					table.insert(data.invalid, { argPos, rawArg, "Too many arguments" })
					return data
				end
				data.argDefinition = argDefinition
				local rawType, rawArgs = _K.Process.initArgument(argDefinition, rawArg)
				local ok, result = _K.Process.validateArgument(argDefinition, LocalPlayer, rawType, rawArgs)
				-- invalid argument
				-- FIX: need transformArgPos from validateArgument to show invalid listables separately!
				if not ok then
					table.insert(data.invalid, { argPos, rawArg, result })
					return data
				end

				if cursorPosition < argPos or cursorPosition > argPos + #rawArg then
					continue -- not within cursor
				end

				local transformedArgs, transformedTypes = unpack(result)

				-- TODO: account for transformed type suggestions and listable types (like players)
				local transformPos = argPos
				for k, transformedArg in transformedArgs do
					local transformedType = transformedTypes[k]
					data.suggestionType = transformedType
					local pos = transformPos
					transformPos += #transformedArg + 1
					print(argPos, pos, pos + #transformedArg, cursorPosition)
					-- cursor within this transformedArg
					print(cursorPosition < pos, cursorPosition > transformPos)
					if cursorPosition < pos or cursorPosition > pos + #transformedArg then
						continue
					end
					if not transformedType.suggestions then
						continue -- no suggestions for this type  TODO: (make sure to still show tool hint)
					end
					-- data.query = transformedArg
					data.argPos = pos
					data.rawArg = transformedArg
					data.query = string.sub(transformedArg, 1, cursorPosition - pos)
					data.suggestions = transformedType.suggestions(data.query)
				end
			end
		end
	end

	return data
end

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
		if i == suggestionIndex then
			frame.BackgroundTransparency = 0.9
		else
			frame.BackgroundTransparency = 0.95
		end

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

local function hideAutocomplete()
	TooltipFrame.Visible = false
	InputLabel.Text = _K.Util.escapeRichText(Input.Text)
	for _, label in suggestionLabels do
		label:Destroy()
	end
	table.clear(suggestionLabels)
end

local function updateAutocomplete()
	local message = Input.Text
	local data = autocompleteData(message)
	print("auto", data)

	-- handle validation hints
	-- TODO: somehow show validated arguments/text as green :)
	for _, invalid in data.invalid do
		print("invalid", invalid)
		local pos, text, err = unpack(invalid)
		-- red text inlineFormat
		InputLabel.Text =
			`<font transparency="0.33">{_K.Util.escapeRichText(string.sub(message, 1, pos - 1))}<font color="#f00" transparency="0"><b>{_K.Util.escapeRichText(
				text
			)}</b></font>{_K.Util.escapeRichText(string.sub(message, pos + #text))}</font>`
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
		table.clear(suggestionLabels)
		local frame = SuggestionFrame:Clone()
		local label = frame:FindFirstChildOfClass("TextLabel")
		label.Text = `<font color="#f00"><b>{_K.Util.escapeRichText(err)}</b></font>`
		frame.Parent = TooltipFrame
		-- show highlight
		table.insert(suggestionLabels, frame)

		Tooltip.Visible = true
		return
	end

	if not data.suggestionType then
		return hideAutocomplete() -- no suggestions without argument type
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

	if not (data.suggestions and #data.suggestions > 0) then
		print("nothing to suggest")
		return hideAutocomplete() -- nothing to suggest
	end
	-- suggestion hints

	local firstSuggestion = data.suggestions[1][1]
	local firstValue = data.suggestions[1][2]

	-- inline format (preceding message, query, post query arg, suggestion, post query message)
	-- FIX: how to not escape invalid/valid rich text coloring?
	-- need a way to merge it somehow? (or don't use richtext maybe red underline instead! with a button you can hover to show error tooltip :)
	InputLabel.Text = string.format(
		inlineFormat,
		_K.Util.escapeRichText(string.sub(message, 1, data.argPos - 1)),
		_K.Util.escapeRichText(data.query),
		_K.Util.escapeRichText(string.sub(data.rawArg, #data.query + 1)),
		_K.Util.escapeRichText(string.sub(firstSuggestion, #data.rawArg + 1)),
		_K.Util.escapeRichText(string.sub(message, data.argPos + #data.rawArg))
	)

	-- move tooltip to start of query
	local argX = TextService:GetTextSize(data.query, Tooltip.TextSize, Tooltip.Font, Vector2.zero).X
	TooltipFrame.Position = UDim2.new(
		0,
		(Cursor.AbsolutePosition.X - CommandBar.AbsolutePosition.X) - argX - TooltipPadding.PaddingLeft.Offset,
		1,
		4
	)

	-- show completion tooltip
	if data.argIndex == 1 then -- command
		-- TODO: inline argument types if command
		-- show command aliases too!
		Tooltip.Text = string.format(
			argumentFormat,
			_K.Util.escapeRichText(firstSuggestion),
			"command",
			_K.Util.escapeRichText(firstValue.description)
		)
	end
	if data.argDefinition or data.argIndex == 1 then
		updateSuggestionLabels(data)
		TooltipFrame.Visible = true
	end

	return
end

Input:GetPropertyChangedSignal("CursorPosition"):Connect(function()
	if Input.CursorPosition == -1 then
		Cursor.Visible = false
	else
		if Input.CursorPosition < #_K.settings.prefix + 1 then
			Input.CursorPosition = #_K.settings.prefix + 1
			return
		end
		-- defer for text to register
		task.defer(updateCursor)
		task.defer(updateAutocomplete)
	end
end)

Input.FocusLost:Connect(function(enterPressed)
	CommandBar.Visible = false
	Input.TextEditable = false
	if enterPressed then
		task.spawn(_K.Process.runCommands, _K.Services.Players.LocalPlayer, Input.Text)
		Input.Text = _K.settings.prefix
	end
end)
-- FIX: make sure _K reliant connections aren't connected until init!
Input:GetPropertyChangedSignal("Text"):Connect(function()
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
