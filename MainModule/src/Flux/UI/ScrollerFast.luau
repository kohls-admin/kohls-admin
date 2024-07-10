local BaseClass = require(script.Parent.BaseClass)
local UI = require(script.Parent)

local ScrollerFast = {
	_lineHeight = UI.compute(function(use)
		return use(UI.Theme.FontSize) + use(UI.Theme.Padding).Offset
	end),
	_lineItemSize = UI.compute(function(use)
		return UDim2.new(1, 0, 0, use(UI.Theme.FontSize))
	end),
}
ScrollerFast.__index = ScrollerFast
setmetatable(ScrollerFast, BaseClass)

function ScrollerFast:render()
	local lineHeight = self._lineHeight._value
	local startIndex = math.floor(self._instance.CanvasPosition.Y / lineHeight) + 1
	local endIndex =
		math.min(startIndex + math.ceil(self._instance.AbsoluteWindowSize.Y / lineHeight), #self._filteredList)

	self._instance.CanvasSize = UDim2.new(0, 0, 0, #self._filteredList * lineHeight)

	local cacheIndex = 1
	for i = startIndex, endIndex do
		local lineItem = self._lineItemCache[cacheIndex]
		if not lineItem then
			lineItem = UI.new "TextLabel" {
				BackgroundTransparency = 1,
				Size = self._lineItemSize,
				RichText = true,
				Font = UI.Theme.Font,
				TextSize = UI.Theme.FontSize,
				TextColor3 = UI.Theme.PrimaryText,
				TextTruncate = Enum.TextTruncate.AtEnd,
				TextXAlignment = Enum.TextXAlignment.Left,
			}
		end
		lineItem.Visible = true
		lineItem.Text = if self._renderText then self._renderText(self._filteredList[i]) else self._filteredList[i]
		lineItem.Position = UDim2.new(0, 0, 0, (i - 1) * lineHeight)
		lineItem.Parent = self._instance

		self._lineItemCache[cacheIndex] = lineItem
		cacheIndex = cacheIndex + 1
	end

	for i = cacheIndex, #self._lineItemCache do
		self._lineItemCache[i].Visible = false
	end
end

-- Used to render changes from the _rawList
function ScrollerFast:updateList()
	self._sortedList = table.clone(self._rawList)
	if self._sortFunction then
		table.sort(self._sortedList)
	end
	self:refreshList()
end

function ScrollerFast:refreshList()
	self._filteredList = if self._filterFunction then self._filterFunction(self._sortedList) else self._sortedList
	self:render()
end

function ScrollerFast:filter(filterFunction: (...any) -> { any })
	self._filterFunction = filterFunction
	self:refreshList()
end

function ScrollerFast:sort(sortFunction: (...any) -> any)
	self._sortFunction = sortFunction
	if sortFunction then
		table.sort(self._sortedList, sortFunction)
	else -- unsort
		self._sortedList = table.clone(self._rawList)
	end
	self:refreshList()
end

function ScrollerFast.new(definition)
	local new = UI.makeStatefulDefaults({
		List = {},
	}, definition)

	new._rawList = definition.List
	new._sortedList = table.clone(new._rawList)
	new._filteredList = new._sortedList
	new._lineItemCache = {}

	local function render()
		ScrollerFast.render(new)
	end

	new._instance = UI.new "ScrollingFrame" {
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

		-- UI.new "UIPadding" { PaddingRight = UI.Theme.Padding },
		[UI.Event.Property] = {
			AbsoluteWindowSize = render,
			CanvasPosition = render,
			Parent = render,
		},
	}

	return setmetatable(new, ScrollerFast)
end

return ScrollerFast
