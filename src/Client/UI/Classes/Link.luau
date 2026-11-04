local UI = require(script.Parent.Parent)
local BaseClass = require(script.Parent:WaitForChild("BaseClass"))

local DEFAULT = {
	Tooltip = UI.Nil,
}

type Properties = typeof(DEFAULT) & TextBox

local Class = {}
Class.__index = Class
setmetatable(Class, BaseClass)

function Class:_updateSelection()
	if self._updatingSelection then
		return
	end
	local instance = self._instance
	if instance and instance:IsFocused() then
		local cursor = #instance.Text + 1
		if instance.SelectionStart ~= 1 or instance.CursorPosition ~= cursor then
			self._updatingSelection = true
			instance.CursorPosition = cursor
			instance.SelectionStart = 1
			self._updatingSelection = false
		end
	end
end

function Class:Select()
	if not UI.isReactive() then
		UI.flush()
	end
	local instance = self._instance
	if not instance then
		return
	end
	instance:CaptureFocus()
	self:_updateSelection()
	task.defer(function()
		if instance.Parent and not instance:IsFocused() then
			instance:CaptureFocus()
		end
		self:_updateSelection()
	end)
end

function Class.new(properties: Properties?)
	local self = table.clone(DEFAULT)
	UI.makeStatefulDefaults(self, properties)

	local selectionDeferred = false
	local function onFocused()
		self:_updateSelection()
		if not selectionDeferred then
			selectionDeferred = true
			task.defer(function()
				selectionDeferred = false
				if self._instance.Parent then
					self:_updateSelection()
				end
			end)
		end
	end

	local function clearSelection()
		if self._instance.Parent and not self._instance:IsFocused() then
			self._updatingSelection = true
			self._instance.SelectionStart = -1
			self._updatingSelection = false
		end
	end

	local function onPointerInput(input: InputObject)
		local inputType = input.UserInputType
		if
			inputType == Enum.UserInputType.MouseButton1
			or inputType == Enum.UserInputType.MouseMovement
			or inputType == Enum.UserInputType.Touch
		then
			onFocused()
		end
	end

	local cleanup = {}

	self._instance = UI.new "TextBox" {
		AutoLocalize = false,
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = UI.Theme.Secondary,
		BackgroundTransparency = 0.25,
		FontFace = UI.Theme.FontMono,
		TextSize = UI.Theme.FontSize,
		TextColor3 = UI.Theme.SecondaryText,
		TextStrokeColor3 = UI.Theme.Secondary,
		TextStrokeTransparency = UI.Theme.TextStrokeTransparency,
		TextEditable = false,
		ClearTextOnFocus = false,

		UI.corner(UI.Theme.CornerPadded),
		UI.padding {
			x = UI.Theme.Padding,
		},

		Focused = onFocused,
		FocusLost = function()
			clearSelection()
			task.defer(clearSelection)
		end,
		InputBegan = onPointerInput,
		InputChanged = onPointerInput,
		InputEnded = onPointerInput,

		_CursorPosition = onFocused,
		_SelectionStart = onFocused,
		_Text = onFocused,
	} :: TextBox & { UICorner: UICorner, UIPadding: UIPadding, UISizeConstraint: UISizeConstraint }

	local richText = UI.property(self._instance, "RichText")
	local text = UI.property(self._instance, "Text")
	-- follow the instance, so a FontFace or TextSize passed to the link sizes it too
	local fontFace = UI.property(self._instance, "FontFace")
	local textSize = UI.property(self._instance, "TextSize")
	table.insert(cleanup, richText)
	table.insert(cleanup, text)
	table.insert(cleanup, fontFace)
	table.insert(cleanup, textSize)

	if UI.UserInputService.KeyboardEnabled or self.Tooltip then
		local hovered = UI.Interact.hover(self._instance)
		local focused = UI.Interact.focused(self._instance)
		local active = UI.computed(function()
			return hovered() or focused()
		end)
		self._tooltip = UI.new "Tooltip" {
			Parent = self._instance,
			FontFace = UI.Theme.FontMono,
			Hovering = active,
			Text = self.Tooltip or "<b>Copy:</b> Ctrl + C",
		}
		table.insert(cleanup, hovered)
		table.insert(cleanup, focused)
		table.insert(cleanup, active)
		table.insert(cleanup, self._tooltip)
	end

	-- measured off the reactive graph: GetTextBoundsAsync yields and must never run inside a reactive property
	local textWidth, textMeasure = UI.textWidth(function()
		return {
			{ Text = text(), Font = fontFace(), Size = textSize(), RichText = richText() },
		}
	end)
	table.insert(cleanup, textWidth)
	table.insert(cleanup, textMeasure)

	UI.edit(self._instance)({
		UI.sizeConstraint {
			min = function()
				local padding = UI.Theme.Padding().Offset * 2
				return Vector2.new(textWidth() + padding, textSize() + padding)
			end,
			max = Vector2.new(math.huge, math.huge),
		},
		__CLEAN = cleanup,
	})

	return setmetatable(self, Class) :: typeof(self) & typeof(Class)
end

return Class
