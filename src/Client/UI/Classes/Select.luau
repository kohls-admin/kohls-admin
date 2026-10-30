local UI = require(script.Parent.Parent)
local BaseClass = require(script.Parent:WaitForChild("BaseClass"))
local Button = require(script.Parent:WaitForChild("Button"))
local Menu = require(script.Parent:WaitForChild("Menu"))

type Button = typeof(Button.new())
type Menu = typeof(Menu.new())

local DEFAULT = {
	Value = "Default",
	Choices = { "Default", "Choice A", "Choice B", "Choice C" },
	FontFace = UI.Theme.Font,
}

type Properties = typeof(DEFAULT) & Frame

local function getName(choice)
	local name = tostring(choice)
	local typeOf = typeof(choice)

	if typeOf == "EnumItem" or typeOf == "Instance" then
		name = choice.Name
	elseif typeOf == "Font" then
		name = UI.getFontName(choice)
	elseif typeOf == "table" then
		name = choice.Name or choice.name
	end

	return name
end

local Class = {}
Class.__index = Class
setmetatable(Class, BaseClass)

function Class.new(properties: Properties?)
	local self = table.clone(DEFAULT)
	UI.makeStatefulDefaults(self, properties)

	-- measured off the reactive graph: GetTextBoundsAsync yields and must never run inside a computed
	local textWidth, textMeasure = UI.textWidth(function()
		local font = self.FontFace()
		local size = UI.Theme.FontSize()
		local requests = {}
		for _, choice in self.Choices() do
			local choiceFont = font
			if typeof(choice) == "Font" then
				choiceFont = choice
			elseif typeof(choice) == "EnumItem" then
				if choice.Name == "Unknown" then
					continue
				end
				if choice.EnumType == Enum.Font then
					choiceFont = Font.fromEnum(choice :: Enum.Font)
				end
			end
			table.insert(requests, { Text = getName(choice), Font = choiceFont, Size = size, RichText = true })
		end
		return requests
	end)

	local itemSize = UI.computed(function()
		local size = UI.Theme.FontSize()
		local padding = if self.Padding then self.Padding().Offset else UI.Theme.Padding().Offset
		local maxWidth = math.max(size, textWidth())
		return UDim2.fromOffset(maxWidth + padding * 2 + size, size + padding)
	end)

	local headerButton = UI.new "Button" {
		Name = "Header",
		ActiveSound = false,
		BackgroundColor3 = UI.Theme.Secondary,
		BackgroundTransparency = UI.Theme.TransparencyHeavy,
		Icon = UI.Theme.Image.Down,
		IconRightAlign = true,
		IconProperties = {
			ImageColor3 = UI.Theme.PrimaryText,
			Position = UDim2.new(0.5, 0, 0.5, 1),
			Size = UDim2.fromScale(0.5, 0.5),
		},
		Label = function()
			return getName(self.Value())
		end,
		Size = itemSize,
		FontFace = self.FontFace,
		TextXAlignment = Enum.TextXAlignment.Left,

		Activated = function()
			UI.toggleState(self.menu.Visible, "floating")
			local value = UI.raw(self.menu.Visible)
			if value then
				UI.Sound.Hover03:Play()
			else
				UI.Sound.Hover01:Play()
			end
		end,
	} :: Button

	UI.edit(headerButton._content.Label.UIPadding)({ PaddingRight = UDim.new() })

	local cleanup = { itemSize, textWidth, textMeasure }

	self._instance = UI.new "Frame" {
		ZIndex = 100,
		Name = "Select",
		BackgroundTransparency = 1,
		Size = itemSize,
		headerButton,
		__CLEAN = cleanup,
	} :: Frame & { Header: Button }

	local absoluteSize = UI.property(self._instance, "AbsoluteSize")
	table.insert(cleanup, absoluteSize)

	self.menu = UI.new "Menu" {
		Adornee = self._instance,
		Size = function()
			return UDim2.new(0, absoluteSize().X, 0, math.min(#self.Choices(), 7.5) * itemSize().Y.Offset)
		end,
	} :: Menu
	table.insert(cleanup, self.menu)

	UI.edit(self.menu._instance.UICorner)({
		CornerRadius = UI.Theme.CornerPadded,
	})

	local isSelected = UI.selector(self.Value)
	table.insert(cleanup, isSelected)

	local selectedButton
	local function createOption(i: number, choiceSignal: any)
		local choiceButton
		choiceButton = UI.new "Button" {
			LayoutOrder = math.min(2 ^ 31 - 1, i),
			ZIndex = 1e3,
			Name = function()
				return tostring(getName(choiceSignal()))
			end,
			Label = function()
				return getName(choiceSignal())
			end,
			FontFace = function()
				local choice = choiceSignal()
				if typeof(choice) == "Font" then
					return choice
				elseif typeof(choice) == "EnumItem" and choice.EnumType == Enum.Font and choice.Name ~= "Unknown" then
					return Font.fromEnum(choice :: Enum.Font)
				end
				return self.FontFace()
			end,
			TextSize = UI.Theme.FontSize,
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = itemSize,
			Visible = function()
				local choice = choiceSignal()
				return not (typeof(choice) == "EnumItem" and choice.Name == "Unknown")
			end,

			Activated = function()
				local choice = choiceSignal:peek()
				selectedButton = choiceButton._instance
				self.Value(choice, true)
				UI.deactivateState(self.menu.Visible, "floating")
			end,
		}
		choiceButton._instance:FindFirstChildOfClass("UIStroke"):Destroy()
		UI.edit(choiceButton._instance)({
			BackgroundColor3 = function()
				local hovering = choiceButton._hovering()
				return if isSelected(choiceSignal()) and not hovering
					then UI.Theme.Secondary()
					elseif hovering or UI.Theme.Transparency() > 0 then UI.Theme.Secondary()
					else UI.Theme.Primary()
			end,
			BackgroundTransparency = function()
				return if not choiceButton._hovering()
						and UI.Theme.Transparency() > 0
						and not isSelected(choiceSignal())
					then 1
					else UI.Theme.TransparencyHeavy()
			end,
		})
		local hoverEffect = UI.effect(UI.on(choiceButton._hovering, function(value)
			if value then
				UI.Sound.Hover02:Play()
			end
		end, true))
		hoverEffect:get()
		local selectEffect = UI.effect(function()
			if isSelected(choiceSignal()) then
				selectedButton = choiceButton._instance
			end
		end)
		selectEffect:get()

		return choiceButton
	end

	local choicesNode = UI.forIndex(self.Choices, function(i, choiceSignal)
		local option = createOption(i, choiceSignal)
		UI.cleanup(option)
		return option._instance
	end)
	table.insert(cleanup, headerButton)
	table.insert(cleanup, choicesNode)
	UI.edit(self.menu._content)({ choicesNode })

	local menuVisibleEffect = UI.effect(UI.on(self.menu.Visible, function(value)
		if selectedButton and value then
			local buttonHeight = selectedButton.AbsoluteSize.Y
			local buttonPosition = selectedButton.AbsolutePosition.Y + self.menu._content.CanvasPosition.Y
			local offset = math.round((self.menu._content.AbsoluteSize.Y / 2) / buttonHeight) * buttonHeight
			self.menu._content.CanvasPosition =
				Vector2.new(0, buttonPosition - self.menu._content.AbsolutePosition.Y - offset)
		end
	end, true))
	menuVisibleEffect:get()
	table.insert(cleanup, menuVisibleEffect)

	return setmetatable(self, Class) :: typeof(self) & typeof(Class)
end

return Class
