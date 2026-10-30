local UI = require(script.Parent.Parent)
local BaseClass = require(script.Parent:WaitForChild("BaseClass"))

local layerSizeState = UI.property(UI.LayerTop, "AbsoluteSize")
local positionState = UI.signal(Vector2.zero)
local sizeState = UI.signal(Vector2.zero)
local tipSizeState = UI.signal(Vector2.zero)
local activeTooltip = UI.signal(nil)
local positionConn, sizeConn

local tooltip
local function onTipSizeChanged()
	tipSizeState(tooltip.AbsoluteSize)
end
local function init()
	tooltip = UI.new "TextLabel" {
		Parent = UI.LayerTop,
		AutoLocalize = false,
		AutomaticSize = Enum.AutomaticSize.XY,
		Name = "Tooltip",
		ZIndex = 9e8,
		BackgroundColor3 = UI.Theme.Primary,
		FontFace = function()
			local active = activeTooltip()
			return if active then active.FontFace() else UI.Theme.Font()
		end,
		TextSize = UI.Theme.FontSize,
		TextColor3 = UI.Theme.PrimaryText,
		TextStrokeColor3 = UI.Theme.Primary,
		TextStrokeTransparency = UI.Theme.TextStrokeTransparency,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		RichText = true,
		Text = function()
			local active = activeTooltip()
			return if active then tostring(active.Text()) else ""
		end,
		Visible = function()
			local active = activeTooltip()
			return active ~= nil and active.Visible()
		end,

		_AbsoluteSize = onTipSizeChanged,

		Position = function()
			local tipSize = tipSizeState()
			local max = layerSizeState()
			local position, size = positionState(), sizeState()
			local padding = UI.Theme.Padding().Offset
			local yOffset = position.Y + size.Y + padding + UI.TopbarInset().Height
			local tipBoundX = math.max(0, max.X - tipSize.X)
			local tipBoundY = math.max(0, max.Y - tipSize.Y)
			local xOffset = 0

			if yOffset > tipBoundY then
				yOffset = position.Y - tipSize.Y - padding + UI.TopbarInset().Height
				if yOffset < 0 then
					xOffset = size.X + padding
					if position.X + size.X + padding > tipBoundX then
						xOffset = -(tipSize.X + padding)
					end
				end
			end

			return UDim2.fromOffset(math.clamp(position.X + xOffset, 0, tipBoundX), math.clamp(yOffset, 0, tipBoundY))
		end,

		UI.corner(UI.Theme.CornerRadius),
		UI.padding(UI.Theme.Padding),
		UI.sizeConstraint {
			min = Vector2.new(8, 8),
			max = Vector2.new(256, math.huge),
		},
		UI.new "Stroke" {},
	}

	tipSizeState(tooltip.AbsoluteSize)
end

local function disconnectAdornee()
	if positionConn then
		positionConn:Disconnect()
		positionConn = nil
	end
	if sizeConn then
		sizeConn:Disconnect()
		sizeConn = nil
	end
end

local function updateTooltip(visible: boolean, adornee: GuiObject?, selfTooltip: any?)
	if visible and selfTooltip and typeof(adornee) == "Instance" and adornee:IsA("GuiObject") then
		disconnectAdornee()
		activeTooltip(selfTooltip)
		positionState(adornee.AbsolutePosition, true)
		sizeState(adornee.AbsoluteSize, true)
		positionConn = adornee:GetPropertyChangedSignal("AbsolutePosition"):Connect(function()
			positionState(adornee.AbsolutePosition)
		end)
		sizeConn = adornee:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			sizeState(adornee.AbsoluteSize)
		end)
	elseif not visible and (selfTooltip == nil or activeTooltip:peek() == selfTooltip) then
		disconnectAdornee()
		activeTooltip:set(nil)
	end
	if not UI.isReactive() then
		UI.flush()
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

local Class = { Cache = setmetatable({} :: { [GuiObject]: any }, { __mode = "k" }) }
Class.__index = Class
setmetatable(Class, BaseClass)

function Class.new(properties: Properties?)
	if not tooltip then
		init()
	end

	local customHovering = properties ~= nil
		and (UI.isNode(properties.Hovering) or type(properties.Hovering) == "function")
	local self = table.clone(DEFAULT)
	UI.makeStatefulDefaults(self, properties)

	local parent
	if properties then
		parent = properties.Parent
		table.clear(properties)
		properties.Parent = parent
	end

	local Adornee: GuiObject?
	local hoverCleanup = {}
	local hovering = self.Hovering
	local hoverStart
	-- This tooltip's claim on the shared "hover" state, taken as soon as a hover starts (before the show delay) so
	-- UI.clearState("hover") on scroll, tab switch, menu open or window close cancels a pending show as well as
	-- hiding a shown tooltip. Hovering another tooltip's adornee releases it the same way.
	local hoverActive = UI.signal(false)

	local function hover(value)
		if value and self.Enabled:peek() then
			local start = os.clock()
			hoverStart = start
			UI.activateState(hoverActive, "hover")
			task.delay(0.4, function()
				if hoverStart == start and hoverActive:peek() and hovering:peek() and self.Enabled:peek() then
					self.Visible(true)
					if not UI.isReactive() then
						UI.flush()
					end
				end
			end)
		else
			hoverStart = nil
			if hoverActive:peek() then
				UI.deactivateState(hoverActive, "hover")
			end
			self.Visible(false)
		end
	end

	local function updateAdornee(adornee: Instance)
		if adornee.Name == "UIContent" and adornee.Parent and adornee.Parent:IsA("GuiObject") then
			adornee = adornee.Parent
		end
		if not adornee:IsA("GuiObject") then
			return
		end
		UI.dispose(hoverCleanup)
		table.clear(hoverCleanup)
		if Adornee and Class.Cache[Adornee] == self then
			Class.Cache[Adornee] = nil
		end
		Class.Cache[adornee] = self
		Adornee = adornee
		if not customHovering then
			local hoverNode = UI.Interact.hover(adornee, { within = adornee:IsA("GuiButton") })
			local selectNode = UI.Interact.selected(adornee)
			local hoverSync = UI.effect(function()
				hovering(hoverNode() or selectNode())
			end)
			hoverSync:get()
			table.insert(hoverCleanup, hoverNode)
			table.insert(hoverCleanup, selectNode)
			table.insert(hoverCleanup, hoverSync)
		end
		-- after the hover state was cleared (e.g. by scrolling) while the pointer stayed over the adornee, moving the
		-- pointer again restarts the tooltip without having to leave and re-enter
		local inputChangedConn = adornee.InputChanged:Connect(function(input)
			if
				input.UserInputType == Enum.UserInputType.MouseMovement
				and hovering:peek()
				and not hoverActive:peek()
				and self.Enabled:peek()
			then
				hover(true)
			end
		end)
		table.insert(hoverCleanup, inputChangedConn)
	end

	local hoverEffect = UI.effect(UI.on(hovering, hover, true))
	hoverEffect:get()
	local hoverActiveEffect = UI.effect(UI.on(hoverActive, function(active)
		if not active then
			hoverStart = nil
			self.Visible(false)
		end
	end, true))
	hoverActiveEffect:get()
	local visibleEffect = UI.effect(UI.on(self.Visible, function(visible)
		updateTooltip(visible, Adornee, self)
	end, true))
	visibleEffect:get()
	local function onRefParentChanged()
		local newParent = self._instance.Parent
		if newParent and newParent ~= UI.LayerTop then
			updateAdornee(newParent)
		end
	end
	local touchMovedConn = UI.UserInputService.TouchMoved:Connect(function()
		if not customHovering then
			hovering(false)
		else
			hover(false)
		end
		if not UI.isReactive() then
			UI.flush()
		end
	end)

	self._instance = UI.new "Folder" {
		Name = "TooltipReference",

		-- no nil holes: Flux only disposes a cleanup list whose first entry is set, so a leading nil (custom
		-- hovering) silently skipped every cleanup below and left tooltips stuck visible after their adornee died
		__CLEAN = {
			hoverCleanup,
			function()
				if Adornee and Class.Cache[Adornee] == self then
					Class.Cache[Adornee] = nil
				end
				hoverStart = nil
				-- release the shared hover state before the node goes away (cleanup order is not guaranteed)
				if hoverActive:peek() then
					UI.deactivateState(hoverActive, "hover")
				end
				hoverActive:Destroy()
				if activeTooltip:peek() == self then
					updateTooltip(false, nil, self)
				end
				if not customHovering then
					hovering:Destroy()
				end
			end,
			hoverEffect,
			hoverActiveEffect,
			visibleEffect,
			touchMovedConn,
		},

		_Parent = onRefParentChanged,
	} :: Folder

	return setmetatable(self, Class) :: typeof(self) & typeof(Class)
end

return Class
