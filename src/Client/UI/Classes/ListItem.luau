local UI = require(script.Parent.Parent)
local BaseClass = require(script.Parent:WaitForChild("BaseClass"))

local DEFAULT = {
	Text = "ListItem",
	ContentAutomaticSize = true,
	ContentListLayout = true,
	Tooltip = UI.Nil,
}

type Properties = typeof(DEFAULT) & Frame

local Class = {}
Class.__index = Class
setmetatable(Class, BaseClass)

function Class.new(properties: Properties?)
	local self = table.clone(DEFAULT)
	UI.makeStatefulDefaults(self, properties)

	local cleanup = {}

	self._label = UI.new "TextLabel" {
		AutoLocalize = false,
		AutomaticSize = Enum.AutomaticSize.XY,
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.new(0, 0, 0, 0),
		FontFace = UI.Theme.Font,
		RichText = true,
		Text = self.Text,
		TextColor3 = UI.Theme.PrimaryText,
		TextSize = UI.Theme.FontSize,
		TextStrokeColor3 = UI.Theme.Primary,
		TextStrokeTransparency = UI.Theme.TextStrokeTransparency,
		TextXAlignment = Enum.TextXAlignment.Left,
	} :: TextLabel

	local labelSize = UI.property(self._label, "AbsoluteSize")
	local automaticSize = UI.computed(function()
		return self.ContentAutomaticSize() and Enum.AutomaticSize.Y or Enum.AutomaticSize.None
	end)
	table.insert(cleanup, labelSize)
	table.insert(cleanup, automaticSize)

	self._content = UI.new "Frame" {
		Name = "UIContent",
		AnchorPoint = Vector2.new(1, 0),
		AutomaticSize = automaticSize,
		Size = function()
			return UDim2.new(1, -labelSize().X - UI.Theme.Padding().Offset, self.ContentAutomaticSize() and 0 or 1, 0)
		end,
		Position = UDim2.new(1, 0, 0, 0),
		BackgroundTransparency = 1,

		UI.padding {
			right = UDim.new(0, 1),
		},
	} :: Frame & { UIPadding: UIPadding }

	local layout = UI.list {
		direction = "x",
		gap = UI.Theme.Padding,
		horizontalAlign = "end",
		verticalAlign = "center",
	}

	self._layoutParentCompute = UI.effect(function()
		layout.Parent = if self.ContentListLayout() then self._content else nil
	end)
	table.insert(cleanup, self._layoutParentCompute)
	table.insert(cleanup, layout)

	self._instance = UI.new "Frame" {
		Name = self.Text:peek(),
		AutomaticSize = automaticSize,
		BackgroundTransparency = 1,
		Size = function()
			return UDim2.new(1, 0, 0, self.ContentAutomaticSize() and 0 or labelSize().Y + UI.Theme.Padding().Offset)
		end,
		self._label,
		self._content,
		if self.Tooltip then UI.new "Tooltip" { Text = self.Tooltip } else nil,
		__CLEAN = cleanup,
	} :: Frame & { TextLabel: TextLabel, UIContent: typeof(self._content) }

	return setmetatable(self, Class) :: typeof(self) & typeof(Class)
end

return Class
