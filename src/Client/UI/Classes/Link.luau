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
	local instance = self._instance
	if instance:IsFocused() and (instance.SelectionStart ~= 1 or instance.CursorPosition ~= #instance.Text + 1) then
		instance.SelectionStart = 1
		instance.CursorPosition = #instance.Text + 1
	end
end

function Class:Select()
	self._instance:CaptureFocus()
	self:_updateSelection()
end

function Class.new(properties: Properties?)
	local self = table.clone(DEFAULT)
	UI.makeStatefulDefaults(self, properties)

	local function onFocused()
		self:_updateSelection()
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
			self._instance.SelectionStart = -1
			self._instance.CursorPosition = -1
		end,

		_CursorPosition = onFocused,
		_SelectionStart = onFocused,
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
