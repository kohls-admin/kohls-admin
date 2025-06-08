local BaseClass = require(script.Parent.BaseClass)
local UI = require(script.Parent.Parent)
local Clack = require(script.Clack).registerAll()

Clack.enabled = UI.peek(UI.Theme.TypingSounds)
Clack.everyTextBox = UI.peek(UI.Theme.TypingSoundsOnEveryTextBox)
UI.Theme.SoundEnabled:hook(function(value)
	Clack.enabled = value and UI.Theme.TypingSounds._value
end)
UI.Theme.TypingSounds:hook(function(value)
	Clack.enabled = value and UI.Theme.SoundEnabled._value
end)
UI.Theme.TypingSoundsOnEveryTextBox:hook(function(value)
	Clack.everyTextBox = value
end)

-- NOTE: only works for single line inputs
-- TODO: fallback for multiline
local function bytePositionToWidth(text, size, font, bytePosition)
	if bytePosition == 1 then
		return 0
	end
	local subText = string.sub(text, 1, bytePosition - 1)
	local bounds = UI.TextService:GetTextSize(subText, size, font, Vector2.zero)
	return bounds.X
end

local function updateSelection(selection, display, input, inputOffset, cursorWidth)
	cursorWidth = cursorWidth or bytePositionToWidth(input.Text, display.TextSize, display.Font, input.CursorPosition)
	local selectWidth = bytePositionToWidth(input.Text, display.TextSize, display.Font, input.SelectionStart)
	local deltaWidth = cursorWidth - selectWidth
	selection.Size = UDim2.fromOffset(deltaWidth, display.TextSize)
	selection.Position = UDim2.new(0, selectWidth - inputOffset._value, 0.5, 0)
	selection.Visible = true
end

local function updateCursor(cursor, display, input, inputMask, inputOffset, selection)
	local cursorWidth = bytePositionToWidth(input.Text, display.TextSize, display.Font, input.CursorPosition)
	local visibleWidth = inputMask.AbsoluteSize.X
	local cursorOffset = cursorWidth - inputOffset._value

	local margin = if (display.TextBounds.X > visibleWidth or inputOffset._value > 0) and cursorWidth > 32
		then 32
		else 0
	if cursorOffset > visibleWidth then
		inputOffset:set(math.min(display.TextBounds.X, inputOffset._value + cursorOffset - visibleWidth))
		cursorOffset = visibleWidth
	elseif cursorOffset < margin then
		inputOffset:set(inputOffset._value + cursorOffset - margin)
		if margin == 0 or inputOffset._value <= display.TextSize / 2 then
			inputOffset:set(math.min(0, inputOffset._value))
		end
		cursorOffset = margin
	end

	input.Position = UDim2.fromOffset(-inputOffset._value, 0)
	cursor.Position = UDim2.fromOffset(cursorOffset, 1)
	cursor.Visible = true

	if input.SelectionStart ~= -1 then
		updateSelection(selection, display, input, inputOffset, cursorWidth)
	end
end

local MODIFIERS = {
	Enum.KeyCode.LeftControl,
	Enum.KeyCode.RightControl,
	Enum.KeyCode.LeftShift,
	Enum.KeyCode.RightShift,
	Enum.KeyCode.LeftAlt,
	Enum.KeyCode.RightAlt,
	Enum.KeyCode.LeftMeta,
	Enum.KeyCode.RightMeta,
	Enum.KeyCode.LeftSuper,
	Enum.KeyCode.RightSuper,
}

local Input = {}
Input.__index = Input
setmetatable(Input, BaseClass)
-- TODO: send/clear button
function Input.new(definition)
	local new = UI.makeStatefulDefaults({
		Cursor = "_",
		DisplayText = "",
		Placeholder = "",
		Value = "",
		Selected = "",
		Font = UI.Theme.Font,
		FontSize = UI.Theme.FontSize,
		TextColor3 = UI.Theme.PrimaryText,
		TextStrokeColor3 = UI.Theme.Primary,
		TextStrokeTransparency = UI.Theme.TextStrokeTransparency,
		Padding = UI.Theme.Padding,
		Icon = "",
		IconProperties = {},
		IconRightAlign = false,
		HotkeyInput = false,
		Hotkey = UI.Nil,
		Modifiers = UI.Nil,
		MaxChars = math.huge,
		NumberOnly = false,
		IntegerOnly = false,
		NumberRange = NumberRange.new(0, 1),
		Validate = UI.Nil,
	}, definition)

	new.Selected._value = UI.peek(new.Value)

	local displayLabel = UI.new "TextLabel" {
		AutoLocalize = false,
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		TextSize = new.FontSize,
		TextColor3 = new.TextColor3,
		Font = new.Font,
		RichText = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = UI.compute(function(use)
			local display = use(new.DisplayText)
			local placeholder = use(new.Placeholder)
			local value = use(new.Value)
			local maxChars = use(new.MaxChars)

			local text = if display ~= "" then display elseif value ~= "" then value else placeholder
			text = string.gsub(string.gsub(text, "\n", " "), "\r", " ")

			return if maxChars ~= math.huge then string.sub(text, 1, maxChars) else text
		end),
		TextTransparency = UI.compute(function(use)
			return if use(new.Value) == "" and use(new.DisplayText) == "" then 0.5 else 0
		end),
	}
	new._displayLabel = displayLabel

	new._input = UI.new "TextBox" {
		AutomaticSize = Enum.AutomaticSize.X,
		AutoLocalize = false,
		ClearTextOnFocus = false,
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		TextTransparency = 1,
		TextSize = new.FontSize,
		Text = new.Value,
		Font = new.Font,
		RichText = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		CursorPosition = -1,

		displayLabel,

		[UI.Event] = {
			FocusLost = function()
				local text = new._input.Text
				local numberOnly = new.NumberOnly._value
				local integerOnly = new.IntegerOnly._value

				if text == "" and (numberOnly or integerOnly) then
					new.Selected:set(new.NumberRange._value.Min, true)
					new.Value:set(new.NumberRange._value.Min)
					return
				end

				if (numberOnly or integerOnly) and text ~= "" then
					local number = tonumber(text)
					if not number or (integerOnly and string.find(text, "%D")) then
						new._input.Text = new.Value._value
						return
					end
					local numberClamped = math.clamp(number, new.NumberRange._value.Min, new.NumberRange._value.Max)
					text = if number == numberClamped then new._input.Text else numberClamped
					new._input.Text = text
					local textLength = #tostring(text)
					if new._input.CursorPosition - 1 > textLength then
						new._input.CursorPosition = textLength + 1
					end
				end

				if new.MaxChars._value ~= math.huge then
					text = string.sub(text, 1, new.MaxChars._value)
					new._input.CursorPosition = math.min(new.MaxChars._value + 1, new._input.CursorPosition)
					new._input.Text = text
				end
				if new.Validate and not new.Validate._value(text) then
					new._input.Text = if new.MaxChars._value ~= math.huge
						then string.sub(new.Value._value, 1, new.MaxChars._value)
						else new.Value._value
					return
				end
				new.Selected:set(text, true)
				new.Value:set(text)
			end,
		},
	}
	new._input:AddTag("KeyClackSound")

	if new.HotkeyInput._value then
		new._input.Focused:Connect(function()
			table.clear(new.Modifiers._value)
			new.Selected:set("", true)
			new.Value:set("")
		end)
		UI.UserInputService.InputBegan:Connect(function(input, gameProcessed)
			if not new._input:IsFocused() then
				return
			end
			if input.UserInputType == Enum.UserInputType.Keyboard then
				local mods = new.Modifiers._value
				mods.Shift = input:IsModifierKeyDown(Enum.ModifierKey.Shift)
				mods.Alt = input:IsModifierKeyDown(Enum.ModifierKey.Alt)

				local hotkeyText = `{mods.Shift and "Shift+" or ""}{mods.Alt and "Alt+" or ""}`
				if table.find(MODIFIERS, input.KeyCode) then
					new.Selected:set(hotkeyText, true)
					new.Value:set(hotkeyText)
					return
				end

				new.Selected:set(hotkeyText .. UI.UserInputService:GetStringForKeyCode(input.KeyCode), true)
				new.Value:set(hotkeyText .. UI.UserInputService:GetStringForKeyCode(input.KeyCode))
				new.Hotkey:set(input.KeyCode)
				new._input:ReleaseFocus(true)
			end
		end)
	end

	local selection = UI.new "Frame" {
		Name = "Selection",
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundTransparency = 0.75,
		Size = UDim2.new(0, 0, 0, Input.TextSize),
		Position = UDim2.new(0, 0, 0.5, 0),
		BackgroundColor3 = UI.Theme.Secondary,
		BorderSizePixel = 0,
		Visible = false,
	}

	local cursor = UI.new "TextLabel" {
		Name = "Cursor",
		AutoLocalize = false,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.new(0, 0, 1, 0),
		Position = UDim2.new(0, 0, 0, 0),
		BackgroundTransparency = 1,
		TextSize = new.FontSize,
		TextColor3 = UI.Theme.PrimaryText,
		TextStrokeColor3 = UI.Theme.Primary,
		TextStrokeTransparency = UI.Theme.TextStrokeTransparency,
		Font = new.Font,
		RichText = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = new.Cursor,
		Visible = false,
	}
	local lastCursorChange = 0
	task.defer(function() -- blinking cursor
		while cursor and cursor.Parent do
			if cursor.Visible and tick() - lastCursorChange > 0.25 then
				cursor.TextTransparency = if cursor.TextTransparency == 1 then 0 else 1
			end
			task.wait(0.5)
		end
	end)

	local inputMask = UI.new "Frame" {
		Name = "InputMask",
		ClipsDescendants = true,
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 0, 0, 0),
		Size = UDim2.new(1, 0, 1, 0),

		new._input,
		selection,
	}

	new._inputOffset = UI.state(0)
	new._maskSize = UI.state(inputMask, "AbsoluteSize")
	new._bounds = UI.state(new._input, "TextBounds")

	new._input:GetPropertyChangedSignal("Text"):Connect(function()
		local text = new._input.Text
		new.DisplayText:set(if new.MaxChars._value ~= math.huge then string.sub(text, 1, new.MaxChars._value) else text)
	end)

	UI.edit(new._input, {
		Position = UI.compute(function(use)
			local xOffset = if use(new._bounds).X > use(new._maskSize).X then -use(new._inputOffset) else 0
			return UDim2.fromOffset(xOffset, 0)
		end),
	})

	local icon = UI.new "ImageLabel" {
		LayoutOrder = 1,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		Image = new.Icon,
		ImageColor3 = UI.Theme.Secondary,
		Visible = UI.compute(function(use)
			return use(new.Icon) ~= ""
		end),
	}
	if definition.IconProperties then
		UI.edit(icon, definition.IconProperties)
	end

	new._instance = UI.new "Frame" {
		Name = "Input",
		ClipsDescendants = true,
		BackgroundColor3 = UI.Theme.Secondary,
		BackgroundTransparency = UI.Theme.TransparencyOverlay,
		Size = UI.compute(function(use)
			return UDim2.new(1, 0, 0, use(new.FontSize) + use(new.Padding).Offset * 2)
		end),

		UI.new "UICorner" {
			CornerRadius = UI.Theme.CornerRadius,
		},
		UI.new "UIStroke" {
			Enabled = UI.Theme.StrokeEnabled,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Transparency = UI.Theme.TransparencyClamped,
			Color = UI.Theme.Border,
		},
		UI.new "UIPadding" {
			PaddingLeft = new.Padding,
			PaddingRight = new.Padding,
		},
		UI.new "UIListLayout" {
			VerticalAlignment = Enum.VerticalAlignment.Center,
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = new.Padding,
		},

		icon,

		UI.new "Frame" {
			LayoutOrder = 2,
			Name = "InputFrame",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 1, 0),

			cursor,
			inputMask,
			UI.new "UIFlexItem" {
				FlexMode = Enum.UIFlexMode.Fill,
			},
		},
	}

	new._cleanup = {
		new._input:GetPropertyChangedSignal("SelectionStart"):Connect(function()
			if new._input.SelectionStart == -1 then
				selection.Visible = false
			else
				updateSelection(selection, displayLabel, new._input, new._inputOffset)
			end
		end),

		new._input:GetPropertyChangedSignal("CursorPosition"):Connect(function()
			lastCursorChange = tick()
			cursor.TextTransparency = 0
			if new._input.CursorPosition == -1 then
				cursor.Visible = false
			else
				-- defer for text to register
				task.defer(updateCursor, cursor, displayLabel, new._input, inputMask, new._inputOffset, selection)
			end
		end),
	}

	return setmetatable(new, Input)
end

return Input
