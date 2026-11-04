local UI = require(script.Parent.Parent)
local BaseClass = require(script.Parent:WaitForChild("BaseClass"))

local SNAP_TWEEN = TweenInfo.new(0)

local DEFAULT = {
	CurrentPage = false,
	Tabs = {},
	Vertical = false,
}

type Properties = typeof(DEFAULT) & Frame

local Class = {}
Class.__index = Class
setmetatable(Class, BaseClass)

function Class.new(properties: Properties?)
	local self = table.clone(DEFAULT)
	UI.makeStatefulDefaults(self, properties)

	local cleanup = {}

	local currentPage = self.CurrentPage:peek()
	if type(currentPage) == "table" and currentPage._instance then
		self.CurrentPage(currentPage._instance)
	end

	local tabOffset = UI.signal(0)
	-- Flux tweens have no :snap(), so a resize clamp swaps in a zero-length TweenInfo until the next user scroll
	local snapCanvas = UI.signal(false)
	local lastScroll

	table.insert(cleanup, tabOffset)
	table.insert(cleanup, snapCanvas)

	local function scrollTo(offset: number)
		snapCanvas(false)
		tabOffset(offset)
	end

	-- motion nodes bound straight to a property are not owned by the instance: destroy them with the tabs
	local canvasPosition = UI.tween(function()
		return if self.Vertical() then Vector2.new(0, tabOffset()) else Vector2.new(tabOffset(), 0)
	end, function()
		return if snapCanvas() then SNAP_TWEEN else UI.Theme.TweenOut()
	end)
	table.insert(cleanup, canvasPosition)

	local tabList = UI.list {
		direction = UI.pick(self.Vertical, "y", "x"),
		horizontalAlign = UI.pick(self.Vertical, "fill", "none"),
		gap = UI.Theme.Padding,
	}

	local tabs
	local function onWheelForward()
		if self.Vertical() then
			lastScroll = nil
			return
		end
		local absoluteStart = self._instance.AbsolutePosition.X
		local closest, closestChild = math.huge, nil
		for _, child in tabs:GetChildren() do
			if child:IsA("GuiObject") then
				local childStart = child.AbsolutePosition.X
				if childStart < absoluteStart - 2 and absoluteStart - childStart < closest then
					closest = math.floor(absoluteStart - childStart)
					closestChild = child
				end
			end
		end
		if closest == math.huge then
			return
		end
		lastScroll = closestChild
		scrollTo(math.max(0, closestChild.AbsolutePosition.X - (tabs.AbsolutePosition.X - tabs.CanvasPosition.X)))
	end
	local function onWheelBackward()
		if self.Vertical() then
			lastScroll = nil
			return
		end
		local absoluteStart = self._instance.AbsolutePosition.X + (if lastScroll then lastScroll.AbsoluteSize.X else 0)
		local closest, closestChild = math.huge, nil
		for _, child in tabs:GetChildren() do
			if child:IsA("GuiObject") then
				local childStart = child.AbsolutePosition.X
				if childStart > absoluteStart + 2 and childStart - absoluteStart < closest then
					closest = math.floor(childStart - absoluteStart)
					closestChild = child
				end
			end
		end
		if closest == math.huge then
			return
		end
		local maxOffset = tabList.AbsoluteContentSize.X - tabs.AbsoluteSize.X

		if maxOffset > 0 then
			lastScroll = closestChild
		end
		scrollTo(closestChild.AbsolutePosition.X - (tabs.AbsolutePosition.X - tabs.CanvasPosition.X))
	end
	local function onCanvasPosition()
		if tabs.CanvasPosition.Y == 1 and not self.Vertical() then
			tabs.CanvasPosition = Vector2.new(tabs.CanvasPosition.X, 0)
		end
	end
	tabs = UI.new "ScrollingFrame" {
		Name = "Tabs",
		Active = false,
		AutomaticCanvasSize = Enum.AutomaticSize.XY,
		AutomaticSize = UI.pick(self.Vertical, Enum.AutomaticSize.X, Enum.AutomaticSize.Y),
		BackgroundTransparency = 1,
		ClipsDescendants = false,
		CanvasPosition = canvasPosition,
		CanvasSize = UDim2.new(),
		Size = UDim2.new(1, 0, 1, 0),
		ScrollBarThickness = 0,

		MouseWheelForward = onWheelForward,
		MouseWheelBackward = onWheelBackward,
		_CanvasPosition = onCanvasPosition,

		tabList,
	} :: ScrollingFrame

	table.insert(
		cleanup,
		tabs:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			snapCanvas(true)
			if self.Vertical() then
				tabOffset(math.clamp(tabOffset:peek(), 0, tabList.AbsoluteContentSize.Y + tabs.AbsoluteSize.Y), true)
			else
				tabOffset(math.clamp(tabOffset:peek(), 0, tabList.AbsoluteContentSize.X + tabs.AbsoluteSize.X), true)
			end
			-- TODO: keep current page visible when resizing down?
		end)
	)

	local pageCache, containerCache = {}, {}

	local pages = UI.new "UIPageLayout" {
		Animated = false,
		SortOrder = Enum.SortOrder.LayoutOrder,
		ScrollWheelInputEnabled = false,
		Padding = UI.Theme.PaddingWithStroke,
	}
	self._pages = pages
	self._pageCache = pageCache
	self._containerCache = containerCache

	local pageEnterConn = pages.PageEnter:Connect(function(container)
		local page = pageCache[container]
		if not page then
			return
		end
		self.CurrentPage(page)
		page.Visible = true
		page.Parent = container
	end)
	table.insert(cleanup, pageEnterConn)

	local pageLeaveConn = pages.PageLeave:Connect(function(container)
		local page = pageCache[container]
		if not page then
			return
		end
		task.defer(function()
			if pages.CurrentPage ~= container then
				page.Parent = nil
				page.Visible = false
			end
		end)
	end)
	table.insert(cleanup, pageLeaveConn)

	local tabPadding = UI.pick(self.Vertical, UI.Theme.Padding, UDim.new(0, 1))
	table.insert(cleanup, tabPadding)

	self._instance = UI.new "Frame" {
		Name = "TabController",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0),

		UI.list {
			direction = UI.pick(self.Vertical, "x", "y"),
		},

		UI.new "Frame" {
			Name = "Bar",
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			AutomaticSize = UI.pick(self.Vertical, Enum.AutomaticSize.X, Enum.AutomaticSize.Y),
			Size = UI.pick(self.Vertical, UDim2.new(0, 0, 1, 0), UDim2.new(1, 0, 0, 0)),

			tabs,

			UI.padding {
				y = tabPadding,
				x = UI.Theme.Padding,
			},
		},
	} :: Frame

	local sidePadding = UI.pick(self.Vertical, UI.Theme.PaddingStroke, UI.Theme.PaddingWithStroke)
	table.insert(cleanup, sidePadding)

	local PagesFrame = UI.new "Frame" {
		Name = "PagesFrame",
		AnchorPoint = Vector2.new(0, 1),
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0),
		Position = UDim2.new(0, 0, 1, 0),

		UI.padding {
			y = UI.Theme.PaddingStroke,
			x = sidePadding,
		},

		pages,
	}

	local function onContentChildAdded(page)
		local container = containerCache[page]
		if container then
			task.defer(function()
				page.Parent = if self.CurrentPage:peek() == page then container else nil
			end)
		end
	end

	self._content = UI.new "Frame" {
		LayoutOrder = 3,
		Name = "UIContent",
		Parent = self._instance,
		AnchorPoint = Vector2.new(0, 1),
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0),
		Position = UDim2.new(0, 0, 1, 0),
		ClipsDescendants = true,

		UI.flex("fill"),
		PagesFrame,

		ChildAdded = onContentChildAdded,
	} :: Frame

	for i, v in UI.raw(self.Tabs) do
		local page, icon = unpack(v)
		if type(page) == "table" then
			page = page._instance
		end

		if containerCache[page] then
			continue
		end

		local container = UI.new "Frame" {
			Parent = PagesFrame,
			Name = page.Name,
			LayoutOrder = i,
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
		}
		pageCache[container] = page
		containerCache[page] = container

		if self.CurrentPage:peek() == page then
			page.Parent = container
			pages:JumpTo(container)
		end

		local nameState = UI.property(page, "Name")
		table.insert(cleanup, nameState)
		-- measured off the reactive graph: GetTextBoundsAsync yields and must never run inside a reactive property
		local labelWidth, labelMeasure = UI.textWidth(function()
			return { { Text = nameState(), Font = UI.Theme.FontBold(), Size = UI.Theme.FontSize() } }
		end)
		table.insert(cleanup, labelWidth)
		table.insert(cleanup, labelMeasure)
		local button
		button = UI.new "Button" {
			Parent = tabs,
			LayoutOrder = i,
			Name = nameState,
			Icon = icon,
			IconProperties = {
				Size = function()
					local size = UI.Theme.FontSize() + UI.Theme.PaddingHalf().Offset
					return UDim2.fromOffset(size, size)
				end,
			},
			Size = function()
				local padding = UI.Theme.Padding().Offset
				local width = labelWidth() + padding * 2
				return UDim2.new(0, math.ceil(width), 0, UI.Theme.FontSize() + padding * 2)
			end,
			Label = function()
				return `<b>{nameState()}</b>`
			end,
			TextXAlignment = Enum.TextXAlignment.Left,

			Activated = function()
				UI.clearActiveStates()
				pages:JumpTo(container)

				local axis = if self.Vertical() then "Y" else "X"
				local absoluteStart = tabs.Parent.AbsolutePosition[axis]
				local absoluteEnd = absoluteStart + tabs.Parent.AbsoluteSize[axis]
				local buttonStart = button._instance.AbsolutePosition[axis]
				local buttonEnd = buttonStart + button._instance.AbsoluteSize[axis] + tabList.Padding.Offset

				if tabList.AbsoluteContentSize[axis] >= tabs.AbsoluteSize[axis] and absoluteEnd < buttonEnd + 32 then
					scrollTo(
						math.min(
							tabList.AbsoluteContentSize[axis] - tabs.AbsoluteSize[axis],
							tabOffset() + (32 + (buttonEnd - absoluteEnd))
						)
					)
				elseif buttonStart - 32 < absoluteStart then
					scrollTo(math.max(0, tabOffset() - ((absoluteStart - buttonStart) + 32 + tabList.Padding.Offset)))
				end
			end,
		}
		table.insert(cleanup, button)

		-- the tab buttons are built once here with no owner, so their motion nodes go with the button
		local labelTransparency = UI.tween(function()
			return if self.CurrentPage() == page then 0 elseif button._hovering() then 0.125 else 0.5
		end, UI.Theme.TweenOut)
		local strokeTransparency = UI.tween(function()
			return if self.CurrentPage() == page
				then UI.Theme.TransparencyLight()
				elseif button._hovering() then UI.Theme.TransparencyBalanced()
				else 1
		end, UI.Theme.TweenOut)
		local backgroundTransparency = UI.tween(function()
			return if self.CurrentPage() == page
				then UI.Theme.TransparencyHeavy()
				elseif button._hovering() then UI.Theme.TransparencyMax()
				else 1
		end, UI.Theme.TweenOut)

		UI.edit(button._content.Label)({
			TextTransparency = labelTransparency,
		})

		UI.edit(button._content.Label.UIPadding)({
			PaddingLeft = UI.Theme.Padding,
		})

		UI.edit(button._instance.UIStroke)({
			Transparency = strokeTransparency,
		})

		UI.edit(button._instance)({
			BackgroundTransparency = backgroundTransparency,
			__CLEAN = { labelTransparency, strokeTransparency, backgroundTransparency },
		})

		local function hideButton()
			local visible = (page.Parent == container or page.Parent == nil) and page:GetAttribute("Enabled") ~= false
			button._instance.Visible = visible
			container.Visible = visible
		end
		table.insert(cleanup, page:GetPropertyChangedSignal("Parent"):Connect(hideButton))
		table.insert(cleanup, page:GetAttributeChangedSignal("Enabled"):Connect(hideButton))
		hideButton()
	end

	UI.edit(self._instance)({ __CLEAN = cleanup })

	return setmetatable(self, Class) :: typeof(self) & typeof(Class)
end

return Class
