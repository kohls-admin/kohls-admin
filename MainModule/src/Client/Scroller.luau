local ScrollingFrame = Instance.new("ScrollingFrame")
ScrollingFrame.BackgroundTransparency = 0.5
ScrollingFrame.Position = UDim2.new(0.25, 0, 0.25, 0)
ScrollingFrame.Size = UDim2.new(0.5, 0, 0.5, 0)
ScrollingFrame.ScrollBarThickness = 8
ScrollingFrame.ScrollBarImageColor3 = Color3.new(1, 1, 1)

local LineItem = Instance.new("TextLabel")
LineItem.Size = UDim2.new(1, 0, 0, 32)
LineItem.Font = Enum.Font.Roboto
LineItem.TextSize = 24

local Scroller = {}
Scroller.__index = Scroller

function Scroller.new(list, lineHeight, renderLine)
	lineHeight = lineHeight or 32
	local object = {
		_sortedList = table.clone(list),
		_rawList = list,
		_lineItemCache = {},
		_lineItem = LineItem:Clone(),
		_frame = ScrollingFrame:Clone(),
		_renderLine = renderLine,
	}
	object._filteredList = object._sortedList
	object._lineItem.Size = UDim2.new(1, 0, 0, lineHeight)
	object._lineItem.TextSize = lineHeight - 8
	object._frame:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
		Scroller.render(object)
	end)

	return setmetatable(object, Scroller)
end

function Scroller:setParent(parent)
	self._frame.Parent = parent
end

function Scroller:render()
	local lineHeight = self._lineItem.AbsoluteSize.Y
	local startIndex = math.floor(self._frame.CanvasPosition.Y / lineHeight) + 1
	local endIndex = math.min(startIndex + math.ceil(self._frame.AbsoluteWindowSize.Y / lineHeight), #self._list)

	self._frame.CanvasSize = UDim2.new(0, 0, 0, #self._list * lineHeight)

	local cacheIndex = 1
	for i = startIndex, endIndex do
		local lineItem = self._lineItemCache[cacheIndex] or self._lineItem:Clone()
		lineItem.Visible = true
		lineItem.Text = if self._renderLine then self._renderLine(self._list[i]) else self._list[i]
		lineItem.Position = UDim2.new(0, 0, 0, (i - 1) * lineHeight)
		lineItem.Parent = self._frame

		self._lineItemCache[cacheIndex] = lineItem
		cacheIndex = cacheIndex + 1
	end

	for i = cacheIndex, #self._lineItemCache do
		self._lineItemCache[i].Visible = false
	end
end

-- Used to render changes to the _rawList
-- PERF: test performance of this, may be more efficient to diff
function Scroller:updateList()
	self._sortedList = table.clone(self._rawList)
	if self._sortFunction then
		table.sort(self._sortedList)
	end
	self:refreshList()
end

function Scroller:refreshList()
	self._list = if self._filterFunction then self._filterFunction(self._sortedList) else self._sortedList
	self:render()
end

function Scroller:filter(filterFunction: (...any) -> { any })
	self._filterFunction = filterFunction
	self:refreshList()
end

function Scroller:sort(sortFunction: (...any) -> any)
	self._sortFunction = sortFunction
	if sortFunction then
		table.sort(self._sortedList, sortFunction)
	else -- unsort
		self._sortedList = table.clone(self._rawList)
	end
	self:refreshList()
end

return Scroller
