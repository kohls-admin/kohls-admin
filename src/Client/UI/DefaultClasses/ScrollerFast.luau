local BaseClass = require(script.Parent.BaseClass)
local UI = require(script.Parent.Parent)

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

function ScrollerFast:render()
	if not (self.Enabled._value and self._instance.Visible) then
		return
	end
	local lineHeight = self.ItemSize._value.Y.Offset
	local startIndex = math.max(0, math.floor(self._scroller.CanvasPosition.Y / lineHeight)) + 1
	local endIndex =
		math.min(startIndex + math.ceil(self._scroller.AbsoluteWindowSize.Y / lineHeight), #self._filteredList)

	self._scroller.CanvasSize = UDim2.new(0, 0, 0, #self._filteredList * lineHeight)

	local cacheIndex = 1
	for i = startIndex, endIndex do
		local lineItem = self._lineItemCache[cacheIndex]
		local lineData = if self.ReverseOrder._value
			then self._filteredList[#self._filteredList - i + 1]
			else self._filteredList[i]
		if not lineItem then
			lineItem = if self.CreateItem
				then self.CreateItem._value(self, lineData)
				else UI.new "TextLabel" {
					AutoLocalize = false,
					BackgroundTransparency = 1,
					Size = self.ItemSize,
					RichText = true,
					Font = UI.Theme.FontMono,
					TextSize = UI.Theme.FontSize,
					TextColor3 = UI.Theme.PrimaryText,
					TextTruncate = Enum.TextTruncate.SplitWord,
					TextXAlignment = Enum.TextXAlignment.Left,
				}
			table.insert(self._lineItemCache, lineItem)
		end
		lineItem.Visible = true
		if self.RenderItem then
			self.RenderItem._value(self, lineItem, lineData)
		else
			lineItem.Text = if self.RenderText then self.RenderText._value(self, lineItem, lineData) else lineData
		end
		lineItem.Position = UDim2.new(0, 0, 0, (i - 1) * lineHeight)
		lineItem.Parent = self._scroller

		cacheIndex = cacheIndex + 1
	end

	for i = cacheIndex, #self._lineItemCache do
		self._lineItemCache[i].Visible = false
	end
end

-- Used to render changes from the _rawList
function ScrollerFast:updateList()
	if self._instance.Visible then
		self:cloneRaw()
		if self._sortFunction then
			table.sort(self._sortedList, self._sortFunction)
		end
		self:refreshList()
	end
	self.pendingUpdate = not self._instance.Visible
end

function ScrollerFast:refreshList()
	if self._instance.Visible then
		self._filteredList = if self._filterFunction
			then self._filterFunction(self, self._sortedList)
			else self._sortedList
		self:render()
	end
	self.pendingRefresh = not self._instance.Visible
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
	self.pendingUpdate = not self._instance.Visible
end

function ScrollerFast:cloneRaw()
	if self.DictList._value then
		local list = {}
		for key in self.List._value do
			table.insert(list, key)
		end
		self._sortedList = list
	else
		self._sortedList = table.clone(self.List._value)
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

	ScrollerFast.cloneRaw(self)
	self._filteredList = self._sortedList
	self._lineItemCache = {}

	self.List:hook(function()
		self:updateList()
	end)

	local lastSizeY = 0
	local lastScrollY = 0
	local function render()
		UI.clearState("hover")
		local sizeY = self._scroller.AbsoluteWindowSize.Y
		local scrollY = self._scroller.CanvasPosition.Y
		if sizeY ~= lastSizeY or scrollY ~= lastScrollY then
			lastSizeY, lastScrollY = lastSizeY, lastScrollY
			ScrollerFast.render(self)
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
			Visible = function()
				if self._instance.Visible then
					if self.pendingUpdate then
						self:updateList()
					elseif self.pendingRefresh then
						self:refreshList()
					end
				end
			end,
		},
	}

	self = setmetatable(self, ScrollerFast)
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
			Icon = "rbxassetid://18416000656",
			IconProperties = {
				Size = UDim2.fromOffset(18, 18),
			},
		}
		self._input._input:GetPropertyChangedSignal("Text"):Connect(debounce)
		self:filter(defaultFilter)
	end
	return self
end

return ScrollerFast
