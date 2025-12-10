local UI = require(script.Parent.Parent) :: any
local BaseClass = require(script.Parent.BaseClass)
local Button = require(script.Parent.Button)
local Menu = require(script.Parent.Menu)

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

	local itemSize = UI.compute(function()
		local choices = self.Choices()
		local font = self.FontFace()
		local size = UI.Theme.FontSize()
		local padding = if self.Padding then self.Padding().Offset else UI.Theme.Padding().Offset
		local maxWidth = size

		local params = Instance.new("GetTextBoundsParams")
		params.Size = size
		params.Width = math.huge
		params.RichText = true

		for _, choice in choices do
			if typeof(choice) == "Font" then
				font = choice
			elseif typeof(choice) == "EnumItem" then
				if choice.Name == "Unknown" then
					continue
				end
				if choice.EnumType == Enum.Font then
					font = Font.fromEnum(choice :: Enum.Font)
				end
			end

			params.Font = font
			params.Text = getName(choice)

			maxWidth = math.max(maxWidth, math.ceil(UI.retryGetTextBoundsAsync(params).X))
		end

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

	UI.edit(headerButton._content.Label.UIPadding, { PaddingRight = UDim.new() })

	local cleanup = { itemSize }

	self._instance = UI.new "Frame" {
		ZIndex = 100,
		Name = "Select",
		BackgroundTransparency = 1,
		Size = itemSize,
		headerButton,
		[UI.Clean] = cleanup,
	} :: Frame & { Header: Button }

	local absoluteSize = UI.state(self._instance, "AbsoluteSize")
	table.insert(cleanup, absoluteSize)

	self.menu = UI.new "Menu" {
		Adornee = self._instance,
		Size = function()
			return UDim2.new(0, absoluteSize().X, 0, math.min(#self.Choices(), 7.5) * itemSize().Y.Offset)
		end,
	} :: Menu
	table.insert(cleanup, self.menu)

	UI.edit(self.menu._instance.UICorner, {
		CornerRadius = UI.Theme.CornerPadded,
	})

	local choiceCleanup = {}

	local selectedButton
	local function updateChoices()
		local selected = self.Value._value
		for i, choice in self.Choices._value do
			local name = getName(choice)
			local font
			if typeof(choice) == "Font" then
				font = choice
			elseif typeof(choice) == "EnumItem" then
				if choice.Name == "Unknown" then
					continue
				end
				if choice.EnumType == Enum.Font then
					font = Font.fromEnum(choice :: Enum.Font)
				end
			end

			local choiceButton
			choiceButton = UI.new "Button" {
				LayoutOrder = math.min(2 ^ 31 - 1, i),
				ZIndex = 1e3,
				Parent = self.menu._content,
				Name = tostring(name),
				Label = name,
				FontFace = font,
				TextSize = UI.Theme.FontSize,
				TextXAlignment = Enum.TextXAlignment.Left,
				Size = itemSize,

				Activated = function()
					selectedButton = choiceButton._instance
					self.Value(choice, true)
					UI.deactivateState(self.menu.Visible, "floating")
				end,
			}
			choiceButton._instance:FindFirstChildOfClass("UIStroke"):Destroy()
			UI.edit(choiceButton._instance, {
				BackgroundColor3 = function()
					local hovering = choiceButton._hovering()
					return if self.Value() == choice and not hovering
						then UI.Theme.Secondary()
						elseif hovering or UI.Theme.Transparency() > 0 then UI.Theme.Secondary()
						else UI.Theme.Primary()
				end,
				BackgroundTransparency = function()
					return if not choiceButton._hovering()
							and UI.Theme.Transparency() > 0
							and self.Value() ~= choice
						then 1
						else UI.Theme.TransparencyHeavy()
				end,
			})
			table.insert(
				choiceCleanup,
				choiceButton._hovering:Connect(function(value)
					if value then
						UI.Sound.Hover02:Play()
					end
				end)
			)

			if choice == selected then
				selectedButton = choiceButton._instance
			end
		end
	end

	table.insert(
		cleanup,
		self.menu.Visible:Connect(function(value)
			if selectedButton and value then
				local buttonHeight = selectedButton.AbsoluteSize.Y
				local buttonPosition = selectedButton.AbsolutePosition.Y + self.menu._content.CanvasPosition.Y
				local offset = math.round((self.menu._content.AbsoluteSize.Y / 2) / buttonHeight) * buttonHeight
				self.menu._content.CanvasPosition =
					Vector2.new(0, buttonPosition - self.menu._content.AbsolutePosition.Y - offset)
			end
		end)
	)

	table.insert(
		cleanup,
		self.Choices:Connect(function(value)
			for _, child in self.menu._content:GetChildren() do
				if not child:IsA("UIBase") then
					child:Destroy()
				end
			end
			UI.cleanup(choiceCleanup)
			updateChoices()
		end)
	)

	updateChoices()

	return setmetatable(self, Class) :: typeof(self) & typeof(Class)
end

return Class
