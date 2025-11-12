local UI = require(script.Parent.Parent) :: any
local BaseClass = require(script.Parent.BaseClass)

local layerSizeState = UI.state(UI.LayerTop, "AbsoluteSize")
local positionState = UI.state(Vector2.zero)
local sizeState = UI.state(Vector2.zero)
local tipSizeState = UI.state(Vector2.zero)

local tooltip = UI.new "TextLabel" {
	Parent = UI.LayerTop,
	AutoLocalize = false,
	AutomaticSize = Enum.AutomaticSize.XY,
	Name = "Tooltip",
	ZIndex = 100,
	BackgroundColor3 = UI.Theme.Primary,
	FontFace = UI.Theme.Font,
	TextSize = UI.Theme.FontSize,
	TextColor3 = UI.Theme.PrimaryText,
	TextStrokeColor3 = UI.Theme.Primary,
	TextStrokeTransparency = UI.Theme.TextStrokeTransparency,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextWrapped = true,
	RichText = true,
	Visible = false,

	Position = function()
		local tipSize = tipSizeState()
		local max = layerSizeState()
		local position, size = positionState(), sizeState()
		local padding = UI.Theme.Padding().Offset
		local yOffset = position.Y + size.Y + UI.TopbarInset().Height + padding
		local tipBoundX = math.max(0, max.X - tipSize.X)
		local tipBoundY = math.max(0, max.Y - tipSize.Y)
		local xOffset = 0

		-- slide horizontally
		if yOffset > tipBoundY then
			xOffset = size.X + UI.Theme.Padding().Offset
			if position.X + size.X + padding > tipBoundX then
				xOffset = -(tipSize.X + padding)
			end
		end

		return UDim2.fromOffset(math.clamp(position.X + xOffset, 0, tipBoundX), math.clamp(yOffset, 0, tipBoundY))
	end,

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

tipSizeState:_bindToProperty(tooltip, "AbsoluteSize")

local invalidProperties = { "Enabled", "Hovering", "Parent", "_instance" }
local function updateTooltip(visible: boolean, adornee: GuiObject?, properties: { [string]: any }?)
	tooltip.Visible = visible
	if visible and properties and typeof(adornee) == "Instance" and adornee:IsA("GuiObject") then
		properties = table.clone(properties)
		for _, key in invalidProperties do
			properties[key] = nil
		end
		UI.edit(tooltip, properties)
		positionState(adornee.AbsolutePosition, true)
		sizeState(adornee.AbsoluteSize, true)
		positionState:_bindToProperty(adornee, "AbsolutePosition")
		sizeState:_bindToProperty(adornee, "AbsoluteSize")
	else
		if positionState._bindConnection then
			positionState._bindConnection:Disconnect()
		end
		if sizeState._bindConnection then
			sizeState._bindConnection:Disconnect()
		end
	end
end

local DEFAULT = {
	Enabled = true,
	Hovering = false,
	Visible = false,
	FontFace = UI.Theme.Font,
	Text = "Example tooltip text.",
}

type Properties = typeof(DEFAULT) & Folder

local Class = { Cache = {} }
Class.__index = Class
setmetatable(Class, BaseClass)

function Class.new(properties: Properties?)
	local self = table.clone(DEFAULT)
	UI.makeStatefulDefaults(self, properties)

	local parent
	if properties then
		parent = properties.Parent
		table.clear(properties)
		properties.Parent = parent
	end

	local Adornee
	local hoverConnections = {}
	local hovering = self.Hovering
	local hoverStart

	local function hover(value)
		if value and self.Enabled._value then
			local start = tick()
			hoverStart = start
			task.delay(0.4, function()
				if hoverStart == start and hovering._value then
					self.Visible(true)
				end
			end)
		else
			self.Visible(false)
		end
	end

	local function hoverEnter()
		UI.activateState(hovering, "hover")
	end
	local function hoverLeave()
		UI.deactivateState(hovering, "hover")
	end

	local function inputChanged(input, processed)
		if processed then
			return
		end
		if
			input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch
		then
			if UI.sinkInput(input.Position.X, input.Position.Y, Adornee) then
				hoverLeave()
				return
			end
			hoverEnter()
		end
	end

	local function inputEnded(input)
		if
			input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch
		then
			hoverLeave()
		end
	end

	local function updateAdornee(adornee: GuiObject)
		if Adornee then
			for _, v in hoverConnections do
				v:Disconnect()
			end
		end
		Class.Cache[adornee] = self
		table.insert(hoverConnections, adornee.InputChanged:Connect(inputChanged))
		table.insert(hoverConnections, adornee.InputEnded:Connect(inputEnded))
		table.insert(hoverConnections, adornee.SelectionGained:Connect(hoverEnter))
		table.insert(hoverConnections, adornee.SelectionLost:Connect(hoverLeave))
		Adornee = adornee
	end

	self._instance = UI.new "Folder" {
		Name = "TooltipReference",

		[UI.Clean] = {
			hoverState = hovering,
			hoverDisconnect = hovering:Connect(hover),
			self.Visible:Connect(function(visible)
				if visible then
					updateTooltip(true, Adornee, self)
				else
					updateTooltip(false)
				end
			end),
			UI.UserInputService.TouchMoved:Connect(function()
				hovering(false)
			end),
		},

		[UI.Event] = {
			Parent = function()
				local newParent = self._instance.Parent
				if newParent and newParent ~= UI.LayerTop then
					updateAdornee(newParent)
				end
			end,
		},
	} :: Folder

	return setmetatable(self, Class) :: typeof(self) & typeof(Class)
end

return Class
