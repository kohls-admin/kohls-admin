local BaseClass = require(script.Parent.BaseClass)
local UI = require(script.Parent)

local Select = {}
Select.__index = Select
setmetatable(Select, BaseClass)

function Select.new(definition)
	local new = UI.makeStatefulDefaults({
		Choice = "Default",
		Choices = { "Default", "Choice A", "Choice B", "Choice C" },
	}, definition)

	local list = UI.new "UIListLayout" {
		SortOrder = Enum.SortOrder.LayoutOrder,
		FillDirection = Enum.FillDirection.Vertical,
		VerticalAlignment = Enum.VerticalAlignment.Top,
	}

	local listContentSize = UI.state(list, "AbsoluteContentSize")

	local menu, menuFrame = UI.new "ScrollingFrame" {
		Name = "Menu",
		ZIndex = 100,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0),
		CanvasSize = UI.compute(function(use)
			return UDim2.new(0, 0, 0, use(listContentSize).Y)
		end),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 0,

		list,
	}

	new._instance = UI.new "Frame" {
		ZIndex = 100,
		Name = "Select",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 24), -- TODO: use fontsize derivative for sizing

		UI.new "Button" {
			Name = "Header",
			Icon = "rbxassetid://2374890977",
			IconRightAlign = true,
			IconProperties = {
				Size = UDim2.new(0, 18, 0, 18),
			},
			Label = new.Choice,
			TextSize = 16,
			Padding = UDim.new(0, 8),
			Size = UDim2.new(1, 0, 0, 24),
			TextXAlignment = Enum.TextXAlignment.Left,

			[UI.Event] = {
				Activated = function()
					menuFrame.Visible = not menuFrame.Visible
				end,
			},
		},
	}

	local absoluteSize = UI.state(new._instance, "AbsoluteSize")
	local absolutePosition = UI.state(new._instance, "AbsolutePosition")
	-- if too close to viewport boundary top/botton flip menu direction
	menuFrame = UI.new "Frame" {
		ZIndex = 100,
		Visible = false,
		Parent = UI.LayerTop,
		BackgroundColor3 = UI.Theme.Primary,
		Size = UI.compute(function(use)
			return UDim2.new(0, use(absoluteSize).X, 0, math.min(#use(new.Choices), 7.5) * 24)
		end),
		Position = UI.compute(function(use)
			local pos = use(absolutePosition)
			return UDim2.fromOffset(pos.x, pos.y + 24 + use(UI.Theme.PaddingHalf).Offset + use(UI.TopbarInset).Height)
		end),

		menu,
		UI.new "UICorner" {
			CornerRadius = UI.Theme.CornerRadius,
		},
		UI.new "UIStroke" {
			Enabled = UI.Theme.StrokeEnabled,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Transparency = UI.Theme.Transparency,
			Color = UI.Theme.Border,
		},
	}

	local function updateChoices()
		for i, choice in new.Choices._value do
			if typeof(choice) == "EnumItem" then
				if choice.Name == "Unknown" then
					continue
				end
				choice = choice.Name
			end
			local choiceButton = UI.new "Button" {
				LayoutOrder = i,
				ZIndex = 1e3,
				Parent = menu,
				Name = choice,
				Label = choice,
				TextSize = 16,
				Padding = UDim.new(0, 8),
				TextXAlignment = Enum.TextXAlignment.Left,
				Size = UDim2.new(1, 0, 0, 24),

				[UI.Event] = {
					Activated = function()
						new.Choice:set(choice)
						menuFrame.Visible = false
					end,
				},
			}
			choiceButton._instance:FindFirstChildOfClass("UIStroke"):Destroy()
			UI.edit(choiceButton._instance, {
				BackgroundColor3 = UI.compute(function(use)
					local hovering = use(choiceButton._hovering)
					return if use(new.Choice) == choice and not hovering
						then use(UI.Theme.BorderMuted)
						elseif hovering or use(UI.Theme.Transparency) > 0 then use(UI.Theme.Border)
						else use(UI.Theme.Primary)
				end),
				BackgroundTransparency = UI.compute(function(use)
					return if not use(choiceButton._hovering)
							and use(UI.Theme.Transparency) > 0
							and use(new.Choice) ~= choice
						then 1
						else 0
				end),
			})
		end
	end

	menu.Destroying:Connect(new.Choices:hook(function(value)
		for _, child in menu:GetChildren() do
			if not child:IsA("UIBase") then
				child:Destroy()
			end
		end
		updateChoices()
	end))
	updateChoices()

	return setmetatable(new, Select)
end

return Select
