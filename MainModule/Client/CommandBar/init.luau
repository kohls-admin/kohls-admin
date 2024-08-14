local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local TextService = game:GetService("TextService")

-- disable CoreGui HealthBar for dashboard button consistency
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)

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

local Input = UI.new "Input" {
	AnchorPoint = Vector2.new(0, 0.5),
	Placeholder = "Search",
	BackgroundColor3 = UI.Theme.Primary,
	BackgroundTransparency = UI.Theme.Transparency,
	Font = UI.Theme.FontMono,

	UI.new "Frame" {
		Name = "CircleIndicator",
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 14, 1, 0),

		UI.new "UIPadding" {
			PaddingTop = UI.Theme.Padding,
			PaddingBottom = UI.Theme.Padding,
		},

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
	},

	-- [UI.Hook] = {
	-- 	Value = function(text)
	-- 		-- TODO: do what it used to do on text changed?
	-- 	end,
	-- },
}

UI.edit(Input._instance.UICorner, {
	CornerRadius = UI.Theme.CornerDiameter,
})

local CommandBar = UI.new "Frame" {
	Name = "CommandBar",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Size = UDim2.new(0, 512, 0, 0),
	Position = UDim2.new(0.5, 0, 0.5, 0),
	BackgroundTransparency = 1,
	ZIndex = 100,
	Visible = false,

	Input,
}

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
	Name = "Tooltip",
	BackgroundTransparency = 1,
	Size = UI.computeFrom(UDim2.new, 1, 0, 0, UI.Theme.FontSize),
	TextWrapped = true,
	RichText = true,
	Font = UI.Theme.FontMono,
	TextSize = UI.Theme.FontSize,
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
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0),
		TextWrapped = true,
		RichText = true,
		Font = UI.Theme.FontMono,
		TextSize = UI.Theme.FontSize,
		TextColor3 = UI.Theme.PrimaryText,
		TextXAlignment = Enum.TextXAlignment.Left,

		UI.new "UIPadding" {
			PaddingTop = UI.Theme.PaddingHalf,
			PaddingBottom = UI.Theme.PaddingHalf,
			PaddingLeft = UI.Theme.Padding,
			PaddingRight = UI.Theme.Padding,
		},
	},
}

local argumentFormat =
	`<b><sc>%s</sc> <font transparency="0.66" size="15"><i>&lt;%s&gt;</i></font></b>\n<font size="14">%s</font>`
local inlineFormat =
	`<font transparency="0.33">%s</font>%s<font transparency="0.33">%s<font transparency="0.66">%s</font>%s</font>`
local suggestFormat = `%s<font transparency="0.5">%s</font>`

local playerThumbs = {}

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

		if typeof(value) == "Instance" and value:IsA("Player") then
			displayName = `{name} ({value.DisplayName})`
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
		local pos, text, err = unpack(invalid)
		-- red text inlineFormat
		Input.DisplayText:set(
			`<font transparency="0.33">{_K.Util.String.escapeRichText(string.sub(data.message, 1, pos - 1))}<font color="#f00" transparency="0"><b>{_K.Util.String.escapeRichText(
				text
			)}</b></font>{_K.Util.String.escapeRichText(string.sub(data.message, pos + #text))}</font>`
		)
		Tooltip.Text = if not data.argDefinition
			then ""
			else string.format(
				argumentFormat,
				_K.Util.String.escapeRichText(data.argDefinition.displayName or data.argDefinition.name),
				_K.Util.String.escapeRichText(data.argDefinition.type),
				_K.Util.String.escapeRichText(data.argDefinition.description)
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
		return
	end

	-- TODO: check if every argument for every command is valid somehow!
	-- and then show valid icon and color :)

	if not data.suggestionType then
		return clearCompletion() -- no suggestions without argument type
	end
	-- show normal argument type hints here!
	if data.argDefinition then
		Tooltip.Text = string.format(
			argumentFormat,
			_K.Util.String.escapeRichText(data.argDefinition.displayName or data.argDefinition.name),
			_K.Util.String.escapeRichText(data.argDefinition.type),
			_K.Util.String.escapeRichText(data.argDefinition.description)
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
		math.floor(argX) + 14 + UI.Theme.Padding._value.Offset,
		0,
		Input._input.AbsoluteSize.Y / 2 + UI.Theme.PaddingHalf._value.Offset
	)

	if not (data.suggestions and #data.suggestions > 0) then
		return
	end
	-- suggestion hints

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
			_K.Util.String.escapeRichText(suggestionValue.description)
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

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if input.UserInputType == Enum.UserInputType.Keyboard then
		if not Input._input:IsFocused() then
			return
		end
		if input.KeyCode == Enum.KeyCode.Up then
			suggestionIndex = math.max(1, suggestionIndex - 1)
			updateCompletion()
		elseif input.KeyCode == Enum.KeyCode.Down then
			local max = currentCompletionData.suggestions and #currentCompletionData.suggestions
			suggestionIndex = math.min(math.max(1, max), suggestionIndex + 1)
			updateCompletion()
		end
	elseif
		input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
	then
		if gameProcessed then
			return
		end
		CommandBar.Visible = false
		Input._input.TextEditable = false
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

Input._input.FocusLost:Connect(function(enterPressed)
	if enterPressed then
		CommandBar.Visible = false
		Input._input.TextEditable = false
		if currentCompletionData and currentCompletionData.invalid and #currentCompletionData.invalid > 0 then
			-- if not fully validated need to show feedback
			return
		end
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
	init = function(self, _K)
		Input._input.Text = _K.Data.settings.prefix
		Input._input.TextEditable = false
		CommandBar.Parent = _K.UI.LayerTop
		_K.client.hotkeys.commandBar = { key = UI.state(Enum.KeyCode.Semicolon), mods = {}, callback = self.show }
		_K.client.CommandBarState = { validState, indicatorColor }
	end,
	show = function()
		CommandBar.Visible = true
		Input._input:CaptureFocus()
		-- prevent input hotkey from being captured
		task.delay(0, function()
			Input._input.TextEditable = true
		end)
	end,
}
