local UI = require(script.Parent.Parent) :: any
local BaseClass = require(script.Parent.BaseClass)

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

	local function update()
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

		UI.new "UICorner" {
			CornerRadius = UI.Theme.CornerPadded,
		},
		UI.new "UIPadding" {
			PaddingLeft = UI.Theme.Padding,
			PaddingRight = UI.Theme.Padding,
			PaddingTop = UI.Theme.Padding,
			PaddingBottom = UI.Theme.Padding,
		},

		Focused = update,
		FocusLost = function()
			self._instance.SelectionStart = -1
			self._instance.CursorPosition = -1
		end,

		[UI.Clean] = cleanup,
		[UI.Event] = {
			CursorPosition = update,
			SelectionStart = update,
		},
	} :: TextBox & { UICorner: UICorner, UIPadding: UIPadding, UISizeConstraint: UISizeConstraint }

	local richText = UI.state(self._instance, "RichText")
	local text = UI.state(self._instance, "Text")

	UI.new "UISizeConstraint" {
		Parent = self._instance,
		MinSize = function()
			local params = UI.new "GetTextBoundsParams" {
				Width = math.huge,
				Font = properties and properties.FontFace or UI.Theme.FontMono,
				Size = properties and properties.TextSize or UI.Theme.FontSize,
				RichText = richText,
				Text = text,
			}

			return Vector2.new(
				UI.TextService:GetTextBoundsAsync(params).X + UI.Theme.Padding().Offset * 2,
				UI.Theme.FontSize + UI.Theme.Padding().Offset * 2
			)
		end,
		MaxSize = Vector2.new(math.huge, math.huge),
	}

	if UI.UserInputService.KeyboardEnabled or self.Tooltip then
		local hover = UI.state(false)
		self._tooltip = UI.new "Tooltip" {
			Parent = self._instance,
			FontFace = UI.Theme.FontMono,
			Hovering = hover,
			Text = self.Tooltip or "<b>Copy:</b> Ctrl + C",
		}
		table.insert(cleanup, self._tooltip)
		table.insert(
			cleanup,
			self._instance.Focused:Connect(function()
				hover(true)
			end)
		)
		table.insert(
			cleanup,
			self._instance.FocusLost:Connect(function()
				hover(false)
			end)
		)
	end

	return setmetatable(self, Class) :: typeof(self) & typeof(Class)
end

return Class
