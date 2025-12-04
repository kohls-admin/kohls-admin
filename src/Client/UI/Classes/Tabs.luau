local UI = require(script.Parent.Parent) :: any
local BaseClass = require(script.Parent.BaseClass)

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

	local currentPage = self.CurrentPage()
	if type(currentPage) == "table" and currentPage._instance then
		self.CurrentPage(currentPage._instance)
	end

	local tabOffset = UI.state(0)
	local lastScroll

	table.insert(cleanup, tabOffset)

	local tabList = UI.new "UIListLayout" {
		FillDirection = function()
			return if self.Vertical() then Enum.FillDirection.Vertical else Enum.FillDirection.Horizontal
		end,
		HorizontalFlex = function()
			return if self.Vertical() then Enum.UIFlexAlignment.Fill else Enum.UIFlexAlignment.None
		end,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UI.Theme.Padding,
	}

	local tabs
	tabs = UI.new "ScrollingFrame" {
		Name = "Tabs",
		Active = false,
		AutomaticCanvasSize = Enum.AutomaticSize.XY,
		AutomaticSize = function()
			return if self.Vertical() then Enum.AutomaticSize.X else Enum.AutomaticSize.Y
		end,
		BackgroundTransparency = 1,
		ClipsDescendants = false,
		CanvasPosition = UI.tween(function()
			return if self.Vertical() then Vector2.new(0, tabOffset()) else Vector2.new(tabOffset(), 0)
		end, UI.Theme.TweenOut),
		CanvasSize = UDim2.new(),
		Size = UDim2.new(1, 0, 1, 0),
		ScrollBarThickness = 0,

		MouseWheelForward = function()
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
			tabOffset(math.max(0, closestChild.AbsolutePosition.X - (tabs.AbsolutePosition.X - tabs.CanvasPosition.X)))
		end,
		MouseWheelBackward = function()
			if self.Vertical() then
				lastScroll = nil
				return
			end
			local absoluteStart = self._instance.AbsolutePosition.X
				+ (if lastScroll then lastScroll.AbsoluteSize.X else 0)
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
			tabOffset(closestChild.AbsolutePosition.X - (tabs.AbsolutePosition.X - tabs.CanvasPosition.X))
		end,

		[UI.Event] = {
			CanvasPosition = function()
				if tabs.CanvasPosition.Y == 1 and not self.Vertical() then
					tabs.CanvasPosition = Vector2.new(tabs.CanvasPosition.X, 0)
				end
			end,
		},

		tabList,
	} :: ScrollingFrame

	table.insert(
		cleanup,
		tabs:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			if self.Vertical() then
				tabOffset(
					math.clamp(tabOffset._value, 0, tabList.AbsoluteContentSize.Y + tabs.AbsoluteSize.Y),
					false,
					true
				)
			else
				tabOffset(
					math.clamp(tabOffset._value, 0, tabList.AbsoluteContentSize.X + tabs.AbsoluteSize.X),
					false,
					true
				)
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

	table.insert(
		cleanup,
		pages.PageEnter:Connect(function(container)
			local page = pageCache[container]
			if not page then
				return
			end
			self.CurrentPage(page)
			page.Visible = true
			page.Parent = container
		end)
	)

	table.insert(
		cleanup,
		pages.PageLeave:Connect(function(container)
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
	)

	local tabPadding = UI.compute(function()
		return if self.Vertical() then UI.Theme.Padding() else UDim.new(0, 1)
	end)
	table.insert(cleanup, tabPadding)

	self._instance = UI.new "Frame" {
		Name = "TabController",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0),

		UI.new "UIListLayout" {
			FillDirection = function()
				return if self.Vertical() then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical
			end,
			SortOrder = Enum.SortOrder.LayoutOrder,
		},

		UI.new "Frame" {
			Name = "Bar",
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			AutomaticSize = function()
				return if self.Vertical() then Enum.AutomaticSize.X else Enum.AutomaticSize.Y
			end,
			Size = function()
				return if self.Vertical() then UDim2.new(0, 0, 1, 0) else UDim2.new(1, 0, 0, 0)
			end,

			tabs,

			UI.new "UIPadding" {
				PaddingTop = tabPadding,
				PaddingBottom = tabPadding,
				PaddingLeft = UI.Theme.Padding,
				PaddingRight = UI.Theme.Padding,
			},
		},
		[UI.Clean] = cleanup,
	} :: Frame

	local sidePadding = UI.compute(function()
		return if self.Vertical() then UI.Theme.PaddingStroke else UI.Theme.PaddingWithStroke
	end)
	table.insert(cleanup, sidePadding)

	local PagesFrame = UI.new "Frame" {
		Name = "PagesFrame",
		AnchorPoint = Vector2.new(0, 1),
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0),
		Position = UDim2.new(0, 0, 1, 0),

		UI.new "UIPadding" {
			PaddingTop = UI.Theme.PaddingStroke,
			PaddingBottom = UI.Theme.PaddingStroke,
			PaddingLeft = sidePadding,
			PaddingRight = sidePadding,
		},

		pages,
	}

	self._content = UI.new "Frame" {
		LayoutOrder = 3,
		Name = "UIContent",
		Parent = self._instance,
		AnchorPoint = Vector2.new(0, 1),
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0),
		Position = UDim2.new(0, 0, 1, 0),
		ClipsDescendants = true,

		UI.new "UIFlexItem" {
			FlexMode = Enum.UIFlexMode.Fill,
		},
		PagesFrame,

		ChildAdded = function(page)
			local container = containerCache[page]
			if container then
				task.defer(function()
					page.Parent = if self.CurrentPage() == container then container else nil
				end)
			end
		end,
	} :: Frame

	for i, v in UI.raw(self.Tabs) do
		local page, icon = unpack(v)
		if type(page) == "table" then
			page = page._instance
		end

		if containerCache[page] then
			return
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

		if self.CurrentPage() == page then
			page.Parent = container
			pages:JumpTo(container)
		end

		local nameState = UI.state(page, "Name")
		local button
		button = UI.new "Button" {
			Parent = tabs,
			LayoutOrder = i,
			Name = nameState,
			Icon = icon,
			IconProperties = {
				Size = function()
					local size = UI.Theme.FontSize + UI.Theme.PaddingHalf().Offset
					return UDim2.fromOffset(size, size)
				end,
			},
			Size = function()
				local padding = UI.Theme.Padding().Offset
				local params = Instance.new("GetTextBoundsParams")
				params.Text = nameState()
				params.Font = UI.Theme.FontBold()
				params.Size = UI.Theme.FontSize()
				local width = UI.TextService:GetTextBoundsAsync(params).X + padding * 2
				return UDim2.new(0, math.ceil(width), 0, UI.Theme.FontSize + padding * 2)
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
					tabOffset(
						math.min(
							tabList.AbsoluteContentSize[axis] - tabs.AbsoluteSize[axis],
							tabOffset + (32 + (buttonEnd - absoluteEnd))
						)
					)
				elseif buttonStart - 32 < absoluteStart then
					tabOffset(math.max(0, tabOffset - ((absoluteStart - buttonStart) + 32 + tabList.Padding.Offset)))
				end
			end,
		}
		table.insert(cleanup, button)

		UI.edit(button._content.Label, {
			TextTransparency = UI.tween(function()
				return if self.CurrentPage() == page then 0 elseif button._hovering() then 0.125 else 0.5
			end, UI.Theme.TweenOut),
		})

		UI.edit(button._content.Label.UIPadding, {
			PaddingLeft = UI.Theme.Padding,
		})

		UI.edit(button._instance.UIStroke, {
			Transparency = UI.tween(function()
				return if self.CurrentPage() == page
					then UI.Theme.TransparencyLight
					elseif button._hovering() then UI.Theme.TransparencyBalanced
					else 1
			end, UI.Theme.TweenOut),
		})

		UI.edit(button._instance, {
			BackgroundTransparency = UI.tween(function()
				return if self.CurrentPage() == page
					then UI.Theme.TransparencyHeavy
					elseif button._hovering() then UI.Theme.TransparencyMax
					else 1
			end, UI.Theme.TweenOut),
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

	return setmetatable(self, Class) :: typeof(self) & typeof(Class)
end

return Class
