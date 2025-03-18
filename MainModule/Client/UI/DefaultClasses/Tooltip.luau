local BaseClass = require(script.Parent.BaseClass)
local UI = require(script.Parent.Parent)

local Tooltip = {}
Tooltip.__index = Tooltip
setmetatable(Tooltip, BaseClass)

local layerSizeState = UI.state(UI.LayerTop, "AbsoluteSize")

function Tooltip.new(definition)
	local new = UI.makeStatefulDefaults({
		Enabled = true,
		Visible = false,
	}, definition)

	local parentState = UI.state(nil)
	local positionState = UI.state(Vector2.zero)
	local sizeState = UI.state(Vector2.zero)
	local hovering = UI.state(false)

	local tipSizeState = UI.state(Vector2.zero)

	new._instance = UI.new "TextLabel" {
		AutoLocalize = false,
		Parent = UI.LayerTop,
		Name = "Tooltip",
		Visible = UI.compute(function(use)
			return use(new.Enabled) and use(new.Visible)
		end),
		ZIndex = 100,
		BackgroundColor3 = UI.tween(UI.Theme.TweenOut, UI.Theme.Primary),
		Font = UI.Theme.Font,
		TextSize = UI.Theme.FontSize,
		Text = "Example tooltip text.",
		TextColor3 = UI.Theme.PrimaryText,
		TextWrapped = true,
		RichText = true,
		AutomaticSize = Enum.AutomaticSize.XY,
		Position = UI.compute(function(use)
			local tipSize = use(tipSizeState)
			local max = use(layerSizeState)
			local position, size = use(positionState), use(sizeState)
			local yOffset = position.Y + size.Y + use(UI.TopbarInset).Height + use(UI.Theme.PaddingHalf).Offset

			return UDim2.fromOffset(
				math.clamp(position.X, 0, math.max(0, max.X - tipSize.X)),
				math.clamp(yOffset, 0, math.max(0, max.Y - tipSize.Y))
			)
		end),

		UI.new "UICorner" {
			CornerRadius = UI.Theme.CornerRadius,
		},
		UI.new "UIPadding" {
			PaddingLeft = UI.Theme.Padding,
			PaddingRight = UI.Theme.Padding,
			PaddingTop = UI.Theme.Padding,
			PaddingBottom = UI.Theme.Padding,
		},
		UI.new "UISizeConstraint" {
			MinSize = Vector2.new(8, 8),
			MaxSize = Vector2.new(256, math.huge),
		},
		UI.new "UIStroke" {
			Enabled = UI.Theme.StrokeEnabled,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Transparency = UI.Theme.TransparencyClamped,
			Color = UI.Theme.Border,
		},
	}

	tipSizeState:bindToProperty(new._instance, "AbsoluteSize")

	local hoverStart

	UI.UserInputService.TouchMoved:Connect(function()
		hovering:set(false)
	end)

	new._cleanup = {
		hovering:hook(function(value)
			if value then
				local start = tick()
				hoverStart = start
				task.delay(0.4, function()
					if hoverStart == start and hovering._value then
						new.Visible:set(true)
					end
				end)
			else
				new.Visible:set(false)
			end
		end),
		new._instance:GetPropertyChangedSignal("Parent"):Connect(function()
			local parent = new._instance.Parent
			if parent and parent ~= UI.LayerTop then
				if parentState._value then
					for _, v in new._cleanup do
						v:Disconnect()
					end
				end
				table.insert(
					new._cleanup,
					parent.MouseEnter:Connect(function()
						UI.activateState(hovering, "hover")
					end)
				)
				table.insert(
					new._cleanup,
					parent.MouseLeave:Connect(function()
						UI.deactivateState(hovering, "hover")
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
		parentState,
		positionState,
		sizeState,
		hovering,
	}

	return setmetatable(new, Tooltip)
end

return Tooltip
