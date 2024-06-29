local ScrollingFrame = Instance.new("ScrollingFrame")
ScrollingFrame.BackgroundTransparency = 1
ScrollingFrame.Position = UDim2.new(0, 0, 0, 0)
ScrollingFrame.Size = UDim2.new(1, 0, 1, 0)
ScrollingFrame.ScrollBarThickness = 8
ScrollingFrame.ScrollBarImageColor3 = Color3.new(1, 1, 1)

local LineItem = Instance.new("TextLabel")
LineItem.BackgroundTransparency = 1
LineItem.Size = UDim2.new(1, 0, 0, 32)
LineItem.Font = Enum.Font.Roboto
LineItem.TextSize = 24
LineItem.TextColor3 = Color3.new(1, 1, 1)
LineItem.TextXAlignment = Enum.TextXAlignment.Left

local Scroller = {}
Scroller.__index = Scroller

function Scroller.new(list: { any })
	local object = {
		_sortedList = table.clone(list),
		_rawList = list,
		_lineItemCache = {},
		_lineItem = LineItem:Clone(),
		_frame = ScrollingFrame:Clone(),
	}
	object._filteredList = object._sortedList

	local function render()
		Scroller.render(object)
	end
	object._frame:GetPropertyChangedSignal("AbsoluteWindowSize"):Connect(render)
	object._frame:GetPropertyChangedSignal("CanvasPosition"):Connect(render)

	return setmetatable(object, Scroller)
end

function Scroller:setParent(parent)
	self._frame.Parent = parent
	self:render()
end

function Scroller:render()
	local lineHeight = self._lineItem.AbsoluteSize.Y
	local startIndex = math.floor(self._frame.CanvasPosition.Y / lineHeight) + 1
	local endIndex =
		math.min(startIndex + math.ceil(self._frame.AbsoluteWindowSize.Y / lineHeight), #self._filteredList)

	self._frame.CanvasSize = UDim2.new(0, 0, 0, #self._filteredList * lineHeight)

	local cacheIndex = 1
	for i = startIndex, endIndex do
		local lineItem = self._lineItemCache[cacheIndex] or self._lineItem:Clone()
		lineItem.Visible = true
		lineItem.Text = if self._renderText then self._renderText(self._filteredList[i]) else self._filteredList[i]
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
function Scroller:updateList()
	self._sortedList = table.clone(self._rawList)

	-- PERF: compare against table.clone performance
	-- PERF: try batch delete?
	-- for _, v in deletions do
	-- 	local foundIndex = table.find(self._sortedList, v)
	-- 	if foundIndex then
	-- 		table.remove(self._sortedList, foundIndex)
	-- 	end
	-- end
	-- for _, v in additions do
	-- 	table.insert(self._sortedList, v)
	-- end

	if self._sortFunction then
		table.sort(self._sortedList)
	end
	self:refreshList()
end

function Scroller:refreshList()
	self._filteredList = if self._filterFunction then self._filterFunction(self._sortedList) else self._sortedList
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
