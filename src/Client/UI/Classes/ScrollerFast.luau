local RunService = game:GetService("RunService")
local BaseClass = require(script.Parent:WaitForChild("BaseClass"))
local String =
	require(script.Parent.Parent.Parent.Parent:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("String"))

local UI = require(script.Parent.Parent)

local Defer = {}
do
	local defaultBudget, expireTime = 1 / 240, 0
	-- Call at start of process to prevent unnecessarily waiting.
	function Defer.reset(budget: number?)
		local now = os.clock()
		if now >= expireTime then
			expireTime = os.clock() + (defaultBudget or budget)
		end
	end

	function Defer.wait(budget: number?)
		if os.clock() >= expireTime then
			task.wait()
			Defer.reset(budget)
		end
	end
end

local Class = {}
Class.__index = Class
setmetatable(Class, BaseClass)

local filterRichFormat = `<font transparency="0.5">%s</font><b>%s</b><font transparency="0.5">%s</font>`
local function defaultFilter(self, list)
	local filter = string.lower(self._input._input.Text)
	self._filter = filter
	if string.find(filter, "^%s*$") then
		return list
	end
	local new = {}
	for k, text in list :: { string } do
		local filterIndex, filterEnd = string.find(string.lower(text), filter, 1, true)
		if filterIndex then
			table.insert(
				new,
				string.format(
					filterRichFormat,
					Class.escapeRichText(string.sub(text, 1, filterIndex - 1)),
					Class.escapeRichText(string.sub(text, filterIndex, filterEnd)),
					Class.escapeRichText(string.sub(text, filterEnd + 1))
				)
			)
		end
	end
	return new
end

Class.escapeRichText = String.escapeRichText

local queueBudget = 1 / 90
local updateQueue = {}
local cloneQueue = {}
local refreshQueue = {}
local renderQueue = {}
RunService.Heartbeat:connect(function()
	local start = os.clock()

	-- UPDATE
	local queue = updateQueue
	updateQueue = {}
	for scroller in queue do
		if not scroller._instance.Visible or os.clock() - start > queueBudget then
			scroller:updateList()
			continue
		end
		scroller:cloneRaw()
		scroller:refreshList()
	end

	if os.clock() - start > queueBudget then
		return
	end

	-- CLONE
	queue = cloneQueue
	cloneQueue = {}
	for scroller in queue do
		if not scroller._instance.Visible or os.clock() - start > queueBudget then
			scroller:cloneRaw()
			continue
		end
		if scroller.DictList:peek() then
			local list, index = scroller._sortedList ~= scroller.List:peek() and scroller._sortedList or {}, 1
			table.clear(list)
			for key in scroller.List:peek() do
				list[index] = key
				index += 1
			end
			scroller._sortedList = list
		elseif scroller._sortFunction then
			scroller._sortedList = table.clone(scroller.List:peek())
		else
			scroller._sortedList = scroller.List:peek()
		end
		if scroller._sortFunction then
			table.sort(scroller._sortedList, scroller._sortFunction)
		end
	end

	if os.clock() - start > queueBudget then
		return
	end

	-- REFRESH
	queue = refreshQueue
	refreshQueue = {}
	for scroller in queue do
		if not scroller._instance.Visible or os.clock() - start > queueBudget then
			scroller:refreshList()
			continue
		end
		scroller._filteredList = if scroller._filterFunction
			then scroller._filterFunction(scroller, scroller._sortedList)
			else scroller._sortedList
		-- pause canvas
		if not scroller.DictList:peek() then
			local lineHeight = scroller.ItemSize:peek().Y.Offset
			if scroller._lastValue and scroller._scroller.CanvasPosition.Y > lineHeight then
				local change = #scroller._filteredList - scroller._lastLength
				if change == 0 then
					change = (table.find(scroller._filteredList, scroller._lastValue) or 1) - 1
				end
				scroller._scroller.CanvasPosition += Vector2.new(0, change * lineHeight)
			end
			scroller._lastLength = #scroller._filteredList
			scroller._lastValue = scroller._filteredList[1]
		end
		scroller:render(true)
	end

	if os.clock() - start > queueBudget then
		return
	end

	-- RENDER
	queue = renderQueue
	renderQueue = {}
	for scroller in queue do
		if not scroller._instance.Visible or os.clock() - start > queueBudget then
			scroller:render()
			continue
		end
		scroller:forceRender()
	end
end)

function Class:forceRender()
	if not (self.Enabled:peek() and self._instance.Visible and self._filteredList) then
		return
	end
	local length = #self._filteredList
	local lineHeight = self.ItemSize:peek().Y.Offset
	local startIndex = math.max(0, math.floor(self._scroller.CanvasPosition.Y / lineHeight)) + 1
	local endIndex = math.min(startIndex + math.ceil(self._scroller.AbsoluteWindowSize.Y / lineHeight), length)

	local padding = self._scroller:FindFirstChild("UIPadding")
	padding = if padding then padding.PaddingTop.Offset + padding.PaddingBottom.Offset else 0
	self._scroller.CanvasSize = UDim2.new(0, 0, 0, length * lineHeight + padding)

	local usedItems = {}
	for i = math.max(1, startIndex - 4), math.min(length, endIndex + 4) do
		local lineData = if self.ReverseOrder:peek() then self._filteredList[length - i + 1] else self._filteredList[i]
		local lineItem = self._lineItemCache[lineData]
		if not lineItem then
			lineItem = table.remove(self._lineItemFree)
				or if self.CreateItem
					then self.CreateItem:peek()(self, lineData)
					else UI.new "TextLabel" {
						AutoLocalize = false,
						BackgroundTransparency = 1,
						Size = self.ItemSize,
						RichText = true,
						FontFace = UI.Theme.FontMono,
						TextSize = UI.Theme.FontSize,
						TextColor3 = UI.Theme.PrimaryText,
						TextStrokeColor3 = UI.Theme.Primary,
						TextStrokeTransparency = UI.Theme.TextStrokeTransparency,
						TextTruncate = Enum.TextTruncate.SplitWord,
						TextXAlignment = Enum.TextXAlignment.Left,
					}
			self._lineItemCache[lineData] = lineItem

			if self.RenderItem then
				self.RenderItem:peek()(self, lineItem, lineData)
			else
				lineItem.Text = lineData
			end

			local instance = if type(lineItem) == "table" then lineItem._instance else lineItem
			instance.Position = UDim2.new(0, 0, 0, (i - 1) * lineHeight)
			instance.Parent = self._scroller
		end

		usedItems[lineData] = lineItem
	end

	self:freeCache(usedItems)
end

function Class:freeCache(usedItems: { [any]: any }?)
	for data, item in self._lineItemCache do
		if usedItems and usedItems[data] then
			continue
		end
		self._lineItemCache[data] = nil
		table.insert(self._lineItemFree, item)
		local instance = if type(item) == "table" then item._instance else item
		instance.Parent = nil
	end
end

-- Used to render changes from the _rawList
function Class:updateList()
	updateQueue[self] = true
end

function Class:cloneRaw()
	cloneQueue[self] = true
end

function Class:refreshList()
	refreshQueue[self] = true
end

function Class:render(bustCache: boolean?)
	if bustCache then
		self:freeCache()
	end
	renderQueue[self] = true
end

function Class:filter(filterFunction: (...any) -> { any })
	self._filterFunction = filterFunction
	self.Enabled(true)
	self:refreshList()
end

function Class:sort(sortFunction: (...any) -> any)
	self._sortFunction = sortFunction
	if self._instance.Visible then
		if sortFunction then
			if self._sortedList then
				table.sort(self._sortedList, sortFunction)
			end
		else -- unsort
			self:cloneRaw()
		end
		self:refreshList()
	end
end

local DEFAULT = {
	Enabled = true,
	ItemSize = function()
		return UDim2.new(1, 0, 0, UI.Theme.FontSize() + UI.Theme.PaddingDouble().Offset)
	end,
	List = {},
	DictList = false,
	FilterInput = false,
	FilterInputDebounce = 0,
	CreateItem = UI.Function,
	RenderItem = UI.Function,
	ReverseOrder = false,
	Visible = true,
}

type Properties = typeof(DEFAULT) & Frame

function Class.new(properties: Properties?)
	local self = table.clone(DEFAULT)
	UI.makeStatefulDefaults(self, properties)

	self._lineItemCache = {}
	self._lineItemFree = {}
	self._lastSizeY = 0
	self._lastScrollY = 0

	local function render()
		if not self._scroller then
			return
		end
		UI.clearState("hover")

		local sizeY = self._scroller.AbsoluteWindowSize.Y
		local scrollY = self._scroller.CanvasPosition.Y

		if sizeY ~= self._lastSizeY or scrollY ~= self._lastScrollY then
			if math.abs(scrollY - self._lastScrollY) >= sizeY then
				self:forceRender()
			else
				self:render()
			end
			self._lastSizeY, self._lastScrollY = sizeY, scrollY
		end
	end

	-- PaddingRight follows a signal so a resize only writes it, instead of re-editing the UIPadding each time
	local scrollBarShown = UI.signal(false)
	local padding = UI.padding {
		y = UI.Theme.PaddingWithStroke,
		left = UI.Theme.PaddingStroke,
		right = function()
			return if scrollBarShown() then UI.Theme.PaddingWithStroke() else UDim.new()
		end,
	}

	self._scroller = UI.new "ScrollingFrame" {
		Name = "ScrollerFast",
		LayoutOrder = 2,
		BorderSizePixel = 0,
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 0, 0, 0),
		Size = UDim2.new(1, 0, 1, 0),
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = UI.Theme.Secondary,
		ScrollBarImageTransparency = UI.Theme.TransparencyClamped,
		TopImage = UI.Theme.ScrollTopImage,
		MidImage = UI.Theme.ScrollMidImage,
		BottomImage = UI.Theme.ScrollBottomImage,
		VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,

		UI.flex("fill"),
		padding,

		_AbsoluteWindowSize = render,
		_CanvasPosition = render,
	} :: ScrollingFrame & { UIFlexItem: UIFlexItem, UIPadding: UIPadding }

	local function updatePadding()
		scrollBarShown(self._scroller.AbsoluteCanvasSize.Y > self._scroller.AbsoluteWindowSize.Y)
		if not UI.isReactive() then
			UI.flush()
		end
	end
	updatePadding()

	local cleanup = {
		scrollBarShown,
		self._scroller:GetPropertyChangedSignal("AbsoluteWindowSize"):Connect(updatePadding),
		self._scroller:GetPropertyChangedSignal("AbsoluteCanvasSize"):Connect(updatePadding),
	}

	self._instance = UI.new "Frame" {
		Name = "ScrollerFast",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0),
		Visible = self.Visible,

		UI.list { gap = UI.Theme.Padding },
		self._scroller,

		__CLEAN = cleanup,
		_Parent = render,
	} :: Frame & { UIListLayout: UIListLayout, ScrollerFast: typeof(self._scroller) }

	self = setmetatable(self, Class)

	local listEffect = UI.effect(UI.on(self.List, function()
		self:updateList()
	end, true))
	listEffect:get()
	table.insert(cleanup, listEffect)
	self:updateList()

	local function refresh()
		self:refreshList()
	end
	local fontSizeEffect = UI.effect(UI.on(UI.Theme.FontSize, refresh, true))
	fontSizeEffect:get()
	table.insert(cleanup, fontSizeEffect)
	local paddingEffect = UI.effect(UI.on(UI.Theme.Padding, refresh, true))
	paddingEffect:get()
	table.insert(cleanup, paddingEffect)

	if self.FilterInput:peek() then
		local thread = false
		local function debounce()
			if typeof(thread) == "thread" and coroutine.status(thread :: thread) == "suspended" then
				task.cancel(thread)
			end
			thread = task.delay(self.FilterInputDebounce:peek(), self.refreshList, self)
		end
		self._input = UI.new "Input" {
			LayoutOrder = -1,
			Parent = self._instance,
			ClearTextButton = true,
			Fill = true,
			Placeholder = "Search",
			Icon = UI.Theme.Image.Search,
			IconProperties = {
				ImageColor3 = UI.Theme.PrimaryText,
				Size = UDim2.fromOffset(18, 18),
			},
		}
		table.insert(cleanup, self._input._input:GetPropertyChangedSignal("Text"):Connect(debounce))
		self:filter(defaultFilter)
	end

	return setmetatable(self, Class) :: typeof(self) & typeof(Class)
end

return Class
