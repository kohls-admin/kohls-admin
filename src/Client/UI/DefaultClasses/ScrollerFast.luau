local RunService = game:GetService("RunService")

local BaseClass = require(script.Parent.BaseClass)
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

local ScrollerFast = {}
ScrollerFast.__index = ScrollerFast
setmetatable(ScrollerFast, BaseClass)

local filterRichFormat = `<font transparency="0.5">%s</font><b>%s</b><font transparency="0.5">%s</font>`
local function defaultFilter(self, list)
	local filter = string.lower(self._input._input.Text)
	self._filter = filter
	if string.find(filter, "^%s*$") then
		return list
	end
	local new = {}
	for k, text in list do
		local filterIndex, filterEnd = string.find(string.lower(text), filter, 1, true)
		if filterIndex then
			table.insert(
				new,
				string.format(
					filterRichFormat,
					ScrollerFast.escapeRichText(string.sub(text, 1, filterIndex - 1)),
					ScrollerFast.escapeRichText(string.sub(text, filterIndex, filterEnd)),
					ScrollerFast.escapeRichText(string.sub(text, filterEnd + 1))
				)
			)
		end
	end
	return new
end

function ScrollerFast.escapeRichText(s: string): string
	s = string.gsub(s, "&", "&amp;") -- first because substitutes contain it
	s = string.gsub(s, "<", "&lt;")
	s = string.gsub(s, ">", "&gt;")
	s = string.gsub(s, '"', "&quot;")
	s = string.gsub(s, "'", "&apos;")
	return s
end

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
		if scroller.DictList._value then
			local list, index = scroller._sortedList ~= scroller.List._value and scroller._sortedList or {}, 1
			table.clear(list)
			for key in scroller.List._value do
				list[index] = key
				index += 1
			end
			scroller._sortedList = list
		elseif scroller._sortFunction then
			scroller._sortedList = table.clone(scroller.List._value)
		else
			scroller._sortedList = scroller.List._value
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
		-- reset cache
		for data, item in scroller._lineItemCache do
			scroller._lineItemCache[data] = nil
			table.insert(scroller._lineItemFree, item)
			local instance = if type(item) == "table" then item._instance else item
			instance.Parent = nil
		end
		-- pause canvas
		if not scroller.DictList._value then
			local lineHeight = scroller.ItemSize._value.Y.Offset
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
		scroller:render()
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

function ScrollerFast:forceRender()
	if not (self.Enabled._value and self._instance.Visible and self._filteredList) then
		return
	end
	local length = #self._filteredList
	local lineHeight = self.ItemSize._value.Y.Offset
	local startIndex = math.max(0, math.floor(self._scroller.CanvasPosition.Y / lineHeight)) + 1
	local endIndex = math.min(startIndex + math.ceil(self._scroller.AbsoluteWindowSize.Y / lineHeight), length)

	self._scroller.CanvasSize = UDim2.new(0, 0, 0, length * lineHeight)

	local usedItems = {}
	for i = math.max(1, startIndex - 4), math.min(length, endIndex + 4) do
		local lineData = if self.ReverseOrder._value then self._filteredList[length - i + 1] else self._filteredList[i]
		local lineItem = self._lineItemCache[lineData]
		if not lineItem then
			lineItem = table.remove(self._lineItemFree)
				or if self.CreateItem
					then self.CreateItem._value(self, lineData)
					else UI.new "TextLabel" {
						AutoLocalize = false,
						BackgroundTransparency = 1,
						Size = self.ItemSize,
						RichText = true,
						Font = UI.Theme.FontMono,
						TextSize = UI.Theme.FontSize,
						TextColor3 = UI.Theme.PrimaryText,
						TextStrokeColor3 = UI.Theme.Primary,
						TextStrokeTransparency = UI.Theme.TextStrokeTransparency,
						TextTruncate = Enum.TextTruncate.SplitWord,
						TextXAlignment = Enum.TextXAlignment.Left,
					}
			self._lineItemCache[lineData] = lineItem

			if self.RenderItem then
				self.RenderItem._value(self, lineItem, lineData)
			else
				lineItem.Text = if self.RenderText then self.RenderText._value(self, lineItem, lineData) else lineData
			end

			local instance = if type(lineItem) == "table" then lineItem._instance else lineItem
			instance.Position = UDim2.new(0, 0, 0, (i - 1) * lineHeight)
			instance.Parent = self._scroller
		end

		usedItems[lineData] = lineItem
	end

	for data, item in self._lineItemCache do
		if usedItems[data] then
			continue
		end
		self._lineItemCache[data] = nil
		table.insert(self._lineItemFree, item)
		local instance = if type(item) == "table" then item._instance else item
		instance.Parent = nil
	end
end

-- Used to render changes from the _rawList
function ScrollerFast:updateList()
	updateQueue[self] = true
end

function ScrollerFast:cloneRaw()
	cloneQueue[self] = true
end

function ScrollerFast:refreshList()
	refreshQueue[self] = true
end

function ScrollerFast:render()
	renderQueue[self] = true
end

function ScrollerFast:filter(filterFunction: (...any) -> { any })
	self._filterFunction = filterFunction
	self.Enabled:set(true)
	self:refreshList()
end

function ScrollerFast:sort(sortFunction: (...any) -> any)
	self._sortFunction = sortFunction
	if self._instance.Visible then
		if sortFunction then
			table.sort(self._sortedList, sortFunction)
		else -- unsort
			self:cloneRaw()
		end
		self:refreshList()
	end
end

function ScrollerFast.new(definition)
	local self = UI.makeStatefulDefaults({
		Enabled = true,
		ItemSize = UI.compute(function(use)
			return UDim2.new(1, 0, 0, use(UI.Theme.FontSize) + use(UI.Theme.PaddingDouble).Offset)
		end),
		List = {},
		DictList = false,
		FilterInput = false,
		FilterInputDebounce = 0,
		CreateItem = UI.Nil,
		RenderItem = UI.Nil,
		RenderText = UI.Nil,
		ReverseOrder = false,
		Visible = true,
	}, definition)

	self._lineItemCache = {}
	self._lineItemFree = {}
	self._lastSizeY = 0
	self._lastScrollY = 0

	local function render()
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

	self._scroller = UI.new "ScrollingFrame" {
		Name = "ScrollerFast",
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

		UI.new "UIPadding" {
			PaddingRight = UI.Theme.Padding,
		},

		[UI.Event.Property] = {
			AbsoluteWindowSize = render,
			CanvasPosition = render,
		},
	}

	self._instance = UI.new "Frame" {
		Name = "ScrollerFast",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0),
		Visible = self.Visible,

		UI.new "UIListLayout" { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UI.Theme.Padding },
		self._scroller,

		[UI.Event.Property] = {
			Parent = render,
		},
	}

	self = setmetatable(self, ScrollerFast)

	self.List:hook(function()
		self:updateList()
	end)
	self:updateList()

	local function refresh()
		self:refreshList()
	end
	UI.Theme.FontSize:hook(refresh)
	UI.Theme.Padding:hook(refresh)

	if self.FilterInput._value then
		local thread = false
		local function debounce()
			if thread then
				task.cancel(thread)
			end
			thread = task.delay(self.FilterInputDebounce._value, self.refreshList, self)
		end
		self._input = UI.new "Input" {
			LayoutOrder = -1,
			Parent = self._instance,
			Placeholder = "Search",
			Icon = UI.Theme.Image.Search,
			IconProperties = {
				ImageColor3 = UI.Theme.PrimaryText,
				Size = UDim2.fromOffset(18, 18),
			},
		}
		self._input._input:GetPropertyChangedSignal("Text"):Connect(debounce)
		self:filter(defaultFilter)
	end

	return self
end

return ScrollerFast
