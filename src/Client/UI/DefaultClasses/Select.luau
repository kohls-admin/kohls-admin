local BaseClass = require(script.Parent.BaseClass)
local UI = require(script.Parent.Parent)

local Select = {}
Select.__index = Select
setmetatable(Select, BaseClass)

function Select.new(definition)
	local new = UI.makeStatefulDefaults({
		Choice = "Default",
		Choices = { "Default", "Choice A", "Choice B", "Choice C" },
		Selected = "Default",
		Font = UI.Theme.Font,
	}, definition)

	new.Selected._value = UI.raw(new.Choice)

	local menu

	local itemSize = UI.compute(function()
		local choices = new.Choices()
		local font = new.Font()
		local size = UI.Theme.FontSize()
		local padding = UI.Theme.Padding().Offset
		local maxWidth = size
		for _, choice in choices do
			if typeof(choice) == "EnumItem" then
				if choice.Name == "Unknown" then
					continue
				end
				if choice.EnumType == Enum.Font then
					font = choice
				end
				choice = choice.Name
			elseif typeof(choice) == "Instance" or type(choice) == "table" then
				choice = choice.Name
			end
			maxWidth = math.max(maxWidth, UI.TextService:GetTextSize(choice, size, font, Vector2.zero).X)
		end

		return UDim2.fromOffset(maxWidth + padding * 2 + size, size + padding)
	end)

	local headerButton = UI.new "Button" {
		Name = "Header",
		ActiveSound = false,
		BackgroundColor3 = UI.Theme.Secondary,
		BackgroundTransparency = UI.Theme.TransparencyOverlay,
		Icon = UI.Theme.Image.Down,
		IconRightAlign = true,
		IconProperties = {
			Position = UDim2.new(0.5, 0, 0.5, 1),
			Size = UDim2.fromScale(0.5, 0.5),
		},
		Label = function()
			local choice = new.Choice()
			local typeOf = typeof(choice)
			return if typeOf == "EnumItem" or typeOf == "Instance" or typeOf == "table" then choice.Name else choice
		end,
		Size = itemSize,
		Font = new.Font,
		TextXAlignment = Enum.TextXAlignment.Left,

		Activated = function()
			UI.toggleState(menu.Visible, "floating")
			local value = UI.raw(menu.Visible)
			if value then
				UI.Sound.Hover03:Play()
			else
				UI.Sound.Hover01:Play()
			end
		end,
	}

	UI.edit(headerButton._content.Label.UIPadding, { PaddingRight = UDim.new() })

	new._instance = UI.new "Frame" {
		ZIndex = 100,
		Name = "Select",
		BackgroundTransparency = 1,
		Size = itemSize,
		headerButton,
	}

	local absoluteSize = UI.state(new._instance, "AbsoluteSize")

	menu = UI.new "Menu" {
		Adornee = new._instance,
		Size = function()
			return UDim2.new(0, absoluteSize().X, 0, math.min(#new.Choices(), 7.5) * itemSize().Y.Offset)
		end,
	}

	local selectedButton
	local function updateChoices()
		local selected = new.Selected._value
		for i, choice in new.Choices._value do
			local name = choice
			local font
			if typeof(choice) == "EnumItem" then
				if choice.Name == "Unknown" then
					continue
				end
				if choice.EnumType == Enum.Font then
					font = choice
				end
				name = choice.Name
			elseif typeof(choice) == "Instance" or type(choice) == "table" then
				name = choice.Name
			end

			local choiceButton
			choiceButton = UI.new "Button" {
				LayoutOrder = i,
				ZIndex = 1e3,
				Parent = menu._content,
				Name = tostring(name),
				Label = name,
				Font = font,
				TextSize = UI.Theme.FontSize,
				TextXAlignment = Enum.TextXAlignment.Left,
				Size = itemSize,

				Activated = function()
					selectedButton = choiceButton._instance
					new.Selected(choice, true)
					new.Choice(choice)
					UI.deactivateState(menu.Visible, "floating")
				end,
			}
			choiceButton._instance:FindFirstChildOfClass("UIStroke"):Destroy()
			UI.edit(choiceButton._instance, {
				BackgroundColor3 = function()
					local hovering = choiceButton._hovering()
					return if new.Choice() == choice and not hovering
						then UI.Theme.Secondary()
						elseif hovering or UI.Theme.Transparency() > 0 then UI.Theme.Secondary()
						else UI.Theme.Primary()
				end,
				BackgroundTransparency = function()
					return if not choiceButton._hovering()
							and UI.Theme.Transparency() > 0
							and new.Choice() ~= choice
						then 1
						else UI.Theme.TransparencyOverlay()
				end,
			})
			choiceButton._hovering:Connect(function(value)
				if value then
					UI.Sound.Hover02:Play()
				end
			end)

			if choice == selected then
				selectedButton = choiceButton._instance
			end
		end
	end

	menu.Visible:Connect(function(value)
		if selectedButton and value then
			local buttonHeight = selectedButton.AbsoluteSize.Y
			local buttonPosition = selectedButton.AbsolutePosition.Y + menu._content.CanvasPosition.Y
			local offset = math.round((menu._content.AbsoluteSize.Y / 2) / buttonHeight) * buttonHeight
			menu._content.CanvasPosition = Vector2.new(0, buttonPosition - menu._content.AbsolutePosition.Y - offset)
		end
	end)

	local disconnectHook = new.Choices:Connect(function(value)
		for _, child in menu._content:GetChildren() do
			if not child:IsA("UIBase") then
				child:Destroy()
			end
		end
		updateChoices()
	end)

	menu._instance.Destroying:Connect(disconnectHook)
	updateChoices()

	return setmetatable(new, Select)
end

return Select
