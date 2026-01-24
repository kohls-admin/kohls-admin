local UI = require(script.Parent.Parent) :: any
local BaseClass = require(script.Parent:WaitForChild("BaseClass"))
local Clack = require(script.Clack).registerAll()

Clack.enabled = UI.raw(UI.Theme.TypingSounds)
Clack.everyTextBox = UI.raw(UI.Theme.TypingSoundsOnEveryTextBox)
UI.Theme.TypingSounds:Connect(function(value)
	Clack.enabled = value and UI.Theme.SoundEnabled._value
end)
UI.Theme.TypingSoundsOnEveryTextBox:Connect(function(value)
	Clack.everyTextBox = value
end)

local function stripNewLines(text: string)
	return string.gsub(string.gsub(text, "\n", " "), "\r", " ")
end

-- NOTE: only works for single line inputs
-- TODO: fallback for multiline
local function bytePositionToWidth(text, size, font, richText, bytePosition)
	if bytePosition == 1 then
		return 0
	end

	local params = Instance.new("GetTextBoundsParams")
	params.Font = font
	params.RichText = richText
	params.Size = size
	params.Text = string.sub(text, 1, bytePosition - 1)
	params.Width = math.huge

	return math.ceil(UI.retryGetTextBoundsAsync(params).X)
end

local function updateSelection(selection, display, input, inputOffset, cursorWidth)
	cursorWidth = cursorWidth
		or bytePositionToWidth(input.Text, display.TextSize, display.FontFace, display.RichText, input.CursorPosition)
	local selectWidth =
		bytePositionToWidth(input.Text, display.TextSize, display.FontFace, display.RichText, input.SelectionStart)
	local deltaWidth = cursorWidth - selectWidth
	selection.Size = UDim2.fromOffset(deltaWidth, display.TextSize)
	selection.Position = UDim2.new(0, selectWidth - inputOffset._value, 0.5, 0)
	selection.Visible = true
end

local function updateCursor(cursor, display, input, inputMask, inputOffset, selection)
	local cursorWidth =
		bytePositionToWidth(input.Text, display.TextSize, display.FontFace, display.RichText, input.CursorPosition)
	local visibleWidth = cursor.Parent.AbsoluteSize.X
	local cursorOffset = cursorWidth - inputOffset._value

	local margin = if (display.TextBounds.X > visibleWidth or inputOffset._value > 0) and cursorWidth > 32
		then 32
		else 0
	if cursorOffset > visibleWidth then
		inputOffset(math.min(display.TextBounds.X, inputOffset._value + cursorOffset - visibleWidth))
		cursorOffset = visibleWidth
	elseif cursorOffset < margin then
		inputOffset(inputOffset._value + cursorOffset - margin)
		if margin == 0 or inputOffset._value <= display.TextSize / 2 then
			inputOffset(math.min(0, inputOffset._value))
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

local DEFAULT = {
	Cursor = "_",
	DisplayText = "",
	Placeholder = "",
	Value = "",
	--- Fills to the size of the text input.
	Fill = false,
	FontFace = UI.Theme.Font,
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
	Validate = UI.Function,
}

type Properties = typeof(DEFAULT) & TextButton

local Class = {}
Class.__index = Class
setmetatable(Class, BaseClass)

-- TODO: send/clear button
function Class.new(properties: Properties?)
	local self = table.clone(DEFAULT)
	UI.makeStatefulDefaults(self, properties)
	self.IconProperties = {}

	local cleanup = {}
	local textState = UI.state(UI.raw(self.Value))

	local inputSize = function()
		local fill = self.Fill()
		return UDim2.new(if fill then 1 else 0, if fill then 0 else self.FontSize(), 1, 0)
	end

	local displayLabel = UI.new "TextLabel" {
		AutomaticSize = Enum.AutomaticSize.X,
		AutoLocalize = false,
		Size = inputSize,
		BackgroundTransparency = 1,
		TextSize = self.FontSize,
		TextColor3 = self.TextColor3,
		FontFace = self.FontFace,
		RichText = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = function()
			local display = self.DisplayText()
			local placeholder = self.Placeholder()
			local input = textState()
			local maxChars = self.MaxChars()

			local text = if display ~= "" then display elseif input ~= "" then input else placeholder
			text = stripNewLines(text)

			return if maxChars ~= math.huge then string.sub(text, 1, maxChars) else text
		end,
		TextTransparency = function()
			return if textState() == "" and self.DisplayText() == "" then 0.5 else 0
		end,
	}
	self._displayLabel = displayLabel

	self._input = UI.new "TextBox" {
		AutomaticSize = Enum.AutomaticSize.X,
		AutoLocalize = false,
		ClearTextOnFocus = false,
		Size = inputSize,
		BackgroundTransparency = 1,
		TextTransparency = 1,
		TextSize = self.FontSize,
		Text = self.Value,
		FontFace = self.FontFace,
		RichText = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		CursorPosition = -1,

		displayLabel,

		FocusLost = function()
			local text = self._input.Text
			local numberOnly = self.NumberOnly._value
			local integerOnly = self.IntegerOnly._value

			if text == "" and (numberOnly or integerOnly) then
				self.Value(self.NumberRange._value.Min)
				return
			end

			if (numberOnly or integerOnly) and text ~= "" then
				local number = tonumber(text)
				if not number or (integerOnly and string.find(text :: string, "%D")) then
					self._input.Text = self.Value._value
					return
				end
				local numberClamped = math.clamp(number, self.NumberRange._value.Min, self.NumberRange._value.Max)
				text = if number == numberClamped then self._input.Text else numberClamped
				self._input.Text = text
				local textLength = #tostring(text)
				if self._input.CursorPosition - 1 > textLength then
					self._input.CursorPosition = textLength + 1
				end
			end

			if self.Hotkey and self.Hotkey._value then
				local key = UI.UserInputService:GetStringForKeyCode(self.Hotkey._value)
				if key ~= string.sub(text, -1) then
					text ..= key
				end
			end

			if self.MaxChars._value ~= math.huge then
				text = string.sub(text, 1, self.MaxChars._value)
				self._input.CursorPosition = math.min(self.MaxChars._value + 1, self._input.CursorPosition)
				self._input.Text = text
			end

			if self.Validate and not self.Validate._value(text) then
				self._input.Text = if self.MaxChars._value ~= math.huge
					then string.sub(self.Value._value, 1, self.MaxChars._value)
					else self.Value._value
				return
			end

			self.Value(text)
		end,
	}
	self._input:AddTag("KeyClackSound")

	if self.HotkeyInput._value then
		table.insert(
			cleanup,
			self._input.Focused:Connect(function()
				self.Value("")
			end)
		)
		UI.UserInputService.InputBegan:Connect(function(input, gameProcessed)
			if not self._input:IsFocused() then
				return
			end
			if input.UserInputType == Enum.UserInputType.Keyboard then
				local mods = {}
				mods.Ctrl = input:IsModifierKeyDown(Enum.ModifierKey.Ctrl)
				mods.Shift = input:IsModifierKeyDown(Enum.ModifierKey.Shift)
				mods.Alt = input:IsModifierKeyDown(Enum.ModifierKey.Alt)
				mods.Meta = input:IsModifierKeyDown(Enum.ModifierKey.Meta)

				local hotkeyText =
					`{mods.Ctrl and "Ctrl+" or ""}{mods.Shift and "Shift+" or ""}{mods.Alt and "Alt+" or ""}{mods.Meta and "Meta+" or ""}`
				if table.find(MODIFIERS, input.KeyCode) then
					self.Value(hotkeyText)
					return
				end

				self.Hotkey(input.KeyCode)
				self.Modifiers(mods)
				self.Value(hotkeyText .. UI.UserInputService:GetStringForKeyCode(input.KeyCode), true)
				self._input:ReleaseFocus(true)
			end
		end)
	end

	local selection = UI.new "Frame" {
		Name = "Selection",
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundTransparency = 0.75,
		Size = UDim2.new(0, 0, 0, self.FontSize),
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
		TextSize = self.FontSize,
		TextColor3 = UI.Theme.PrimaryText,
		TextStrokeColor3 = UI.Theme.Primary,
		TextStrokeTransparency = UI.Theme.TextStrokeTransparency,
		FontFace = self.FontFace,
		RichText = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = self.Cursor,
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

	local automaticFill = function()
		return if self.Fill() then Enum.AutomaticSize.None else Enum.AutomaticSize.X
	end

	local inputMask = UI.new "Frame" {
		Name = "InputMask",
		AutomaticSize = automaticFill,
		ClipsDescendants = true,
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 0, 0, 0),
		Size = UDim2.new(1, 0, 1, 0),

		self._input,
		selection,
	}

	self._inputOffset = UI.state(0)
	self._maskSize = UI.state(inputMask, "AbsoluteSize")
	self._bounds = UI.state(self._input, "TextBounds")

	local isUpdating = false
	self._input:GetPropertyChangedSignal("Text"):Connect(function()
		if isUpdating then
			return
		end
		isUpdating = true

		local text = self._input.Text
		text = if self.MaxChars._value ~= math.huge then string.sub(text, 1, self.MaxChars._value) else text
		self._input.Text = text
		textState(text, true)

		isUpdating = false
	end)

	UI.edit(self._input, {
		Position = function()
			local xOffset = if self._bounds().X > self._maskSize().X then -self._inputOffset() else 0
			return UDim2.fromOffset(xOffset, 0)
		end,
	})

	local icon = UI.new "ImageLabel" {
		LayoutOrder = 1,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		Image = self.Icon,
		ImageColor3 = UI.Theme.Secondary,
		Visible = function()
			return self.Icon() ~= ""
		end,
	}
	if properties and properties.IconProperties then
		UI.edit(icon, properties.IconProperties)
	end

	self._instance = UI.new "Frame" {
		Name = "Input",
		AutomaticSize = automaticFill,
		ClipsDescendants = true,
		BackgroundColor3 = UI.Theme.Secondary,
		BackgroundTransparency = UI.Theme.TransparencyHeavy,
		Size = function()
			return UDim2.new(0, 0, 0, self.FontSize() + self.Padding().Offset * 2)
		end,

		UI.new "UICorner" {
			CornerRadius = UI.Theme.CornerPadded,
		},
		UI.new "Stroke" {},
		UI.new "UIPadding" {
			PaddingLeft = self.Padding,
			PaddingRight = self.Padding,
		},
		UI.new "UIListLayout" {
			VerticalAlignment = Enum.VerticalAlignment.Center,
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = self.Padding,
		},

		icon,

		UI.new "Frame" {
			LayoutOrder = 2,
			AutomaticSize = Enum.AutomaticSize.X,
			Name = "InputFrame",
			BackgroundTransparency = 1,
			Size = UDim2.new(0, 0, 1, 0),

			cursor,
			inputMask,
			UI.new "UIFlexItem" {
				FlexMode = Enum.UIFlexMode.Fill,
			},
		},
		[UI.Clean] = cleanup,
	}

	table.insert(
		cleanup,
		self._input:GetPropertyChangedSignal("SelectionStart"):Connect(function()
			if self._input.SelectionStart == -1 then
				selection.Visible = false
			else
				updateSelection(selection, displayLabel, self._input, self._inputOffset)
			end
		end)
	)

	table.insert(
		cleanup,
		self._input:GetPropertyChangedSignal("CursorPosition"):Connect(function()
			lastCursorChange = tick()
			cursor.TextTransparency = 0
			if self._input.CursorPosition == -1 then
				cursor.Visible = false
			else
				-- defer for text to register
				task.defer(updateCursor, cursor, displayLabel, self._input, inputMask, self._inputOffset, selection)
			end
		end)
	)

	return setmetatable(self, Class) :: typeof(self) & typeof(Class)
end

return Class
