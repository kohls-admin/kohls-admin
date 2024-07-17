local BaseClass = require(script.Parent.BaseClass)
local UI = require(script.Parent)

local Tooltip = {}
Tooltip.__index = Tooltip
setmetatable(Tooltip, BaseClass)

function Tooltip.new(definition)
	local new = UI.makeStatefulDefaults({
		Enabled = true,
		Visible = false,
	}, definition)

	local parentState = UI.state(nil)
	local positionState = UI.state(Vector2.zero)
	local sizeState = UI.state(Vector2.zero)

	new._instance = UI.new "TextLabel" {
		Name = "Tooltip",
		Visible = UI.compute(function(use)
			return use(new.Enabled) and use(new.Visible)
		end),
		Parent = UI.LayerTop,
		BackgroundColor3 = UI.tween(UI.Theme.NormalTween, UI.Theme.Primary),
		Font = UI.Theme.Font,
		TextSize = UI.Theme.FontSize,
		Text = "Example tooltip text.",
		TextColor3 = UI.Theme.PrimaryText,
		TextWrapped = true,
		RichText = true,
		AutomaticSize = Enum.AutomaticSize.XY,
		Position = UI.compute(function(use)
			local position, size = use(positionState), use(sizeState)
			local yOffset = position.Y + size.Y + use(UI.TopbarInset).Height + use(UI.Theme.PaddingHalf).Offset
			-- TODO: flip at screen edges
			return UDim2.fromOffset(position.X, yOffset)
		end),

		[UI.Children] = {
			UICorner = UI.new "UICorner" {
				CornerRadius = UI.Theme.CornerRadius,
			},

			UIPadding = UI.new "UIPadding" {
				PaddingLeft = UI.Theme.Padding,
				PaddingRight = UI.Theme.Padding,
				PaddingTop = UI.Theme.Padding,
				PaddingBottom = UI.Theme.Padding,
			},

			UISizeConstraint = UI.new "UISizeConstraint" {
				MinSize = Vector2.new(8, 8),
				MaxSize = Vector2.new(256, math.huge),
			},
		},
	}

	new._cleanup = {
		new._instance:GetPropertyChangedSignal("Parent"):Connect(function()
			local parent = new._instance.Parent
			if parent and parent ~= UI.LayerTop then
				if parentState._value then
					for _, v in new._cleanup do
						v:Disconnect()
					end
				end
				local hoverStart
				table.insert(
					new._cleanup,
					parent.MouseEnter:Connect(function()
						local start = tick()
						hoverStart = start
						task.delay(0.4, function()
							if hoverStart == start then
								new.Visible:set(true)
							end
						end)
					end)
				)
				table.insert(
					new._cleanup,
					parent.MouseLeave:Connect(function()
						hoverStart = nil
						new.Visible:set(false)
					end)
				)
				parentState:set(parent)
				positionState:bindToProperty(parent, "AbsolutePosition")
				sizeState:bindToProperty(parent, "AbsoluteSize")
				task.defer(function()
					new._instance.Parent = UI.LayerTop
				end)
			end
		end),
	}

	return setmetatable(new, Tooltip)
end

return Tooltip
