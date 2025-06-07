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

	new.Selected._value = UI.peek(new.Choice)

	local menu

	local itemSize = UI.compute(function(use)
		return UDim2.new(1, 0, 0, use(UI.Theme.FontSize) + use(UI.Theme.Padding).Offset)
	end)

	new._instance = UI.new "Frame" {
		ZIndex = 100,
		Name = "Select",
		BackgroundTransparency = 1,
		Size = itemSize,

		UI.new "Button" {
			Name = "Header",
			ActiveSound = false,
			BackgroundColor3 = UI.Theme.Secondary,
			BackgroundTransparency = UI.Theme.TransparencyOverlay,
			Icon = "rbxassetid://2374890977",
			IconRightAlign = true,
			IconProperties = {
				Size = UDim2.new(0, 18, 0, 18),
			},
			Label = UI.compute(function(use)
				local choice = use(new.Choice)
				local typeOf = typeof(choice)
				return if typeOf == "EnumItem" or typeOf == "Instance" then choice.Name else choice
			end),
			Size = itemSize,
			Font = new.Font,
			TextXAlignment = Enum.TextXAlignment.Left,

			[UI.Event] = {
				Activated = function()
					UI.toggleState(menu.Visible, "floating")
					local value = UI.peek(menu.Visible)
					if value then
						UI.Sound.Hover03:Play()
					else
						UI.Sound.Hover01:Play()
					end
				end,
			},
		},
	}

	local absoluteSize = UI.state(new._instance, "AbsoluteSize")

	menu = UI.new "Menu" {
		Adornee = new._instance,
		Size = UI.compute(function(use)
			return UDim2.new(0, use(absoluteSize).X, 0, math.min(#use(new.Choices), 7.5) * use(itemSize).Y.Offset)
		end),
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
			elseif typeof(choice) == "Instance" then
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
				Padding = UDim.new(0, 8),
				TextXAlignment = Enum.TextXAlignment.Left,
				Size = itemSize,

				[UI.Event] = {
					Activated = function()
						selectedButton = choiceButton._instance
						new.Selected:set(choice, true)
						new.Choice:set(choice)
						UI.deactivateState(menu.Visible, "floating")
					end,
				},
			}
			choiceButton._instance:FindFirstChildOfClass("UIStroke"):Destroy()
			UI.edit(choiceButton._instance, {
				BackgroundColor3 = UI.compute(function(use)
					local hovering = use(choiceButton._hovering)
					return if use(new.Choice) == choice and not hovering
						then use(UI.Theme.Secondary)
						elseif hovering or use(UI.Theme.Transparency) > 0 then use(UI.Theme.Secondary)
						else use(UI.Theme.Primary)
				end),
				BackgroundTransparency = UI.compute(function(use)
					return if not use(choiceButton._hovering)
							and use(UI.Theme.Transparency) > 0
							and use(new.Choice) ~= choice
						then 1
						else use(UI.Theme.TransparencyOverlay)
				end),
			})
			choiceButton._hovering:hook(function(value)
				if value then
					UI.Sound.Hover02:Play()
				end
			end)

			if choice == selected then
				selectedButton = choiceButton._instance
			end
		end
	end

	menu.Visible:hook(function(value)
		if selectedButton and value then
			local buttonHeight = selectedButton.AbsoluteSize.Y
			local buttonPosition = selectedButton.AbsolutePosition.Y + menu._content.CanvasPosition.Y
			local offset = math.round((menu._content.AbsoluteSize.Y / 2) / buttonHeight) * buttonHeight
			menu._content.CanvasPosition = Vector2.new(0, buttonPosition - menu._content.AbsolutePosition.Y - offset)
		end
	end)

	local disconnectHook = new.Choices:hook(function(value)
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
