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
	local startIndex = math.floor(self._scroller.CanvasPosition.Y / lineHeight) + 1
	local endIndex =
		math.min(startIndex + math.ceil(self._scroller.AbsoluteWindowSize.Y / lineHeight), #self._filteredList)

	self._scroller.CanvasSize = UDim2.new(0, 0, 0, #self._filteredList * lineHeight)

	local cacheIndex = 1
	for i = startIndex, endIndex do
		local lineItem = self._lineItemCache[cacheIndex]
		if not lineItem then
			lineItem = UI.new "TextLabel" {
				BackgroundTransparency = 1,
				Size = self._lineItemSize,
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
		lineItem.Text = if self.RenderText
			then self.RenderText._value(self, self._filteredList[i])
			else self._filteredList[i]
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
	self:cloneRaw()
	if self._sortFunction then
		table.sort(self._sortedList, self._sortFunction)
	end
	self:refreshList()
end

function ScrollerFast:refreshList()
	self._filteredList = if self._filterFunction then self._filterFunction(self, self._sortedList) else self._sortedList
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
		self:cloneRaw()
	end
	self:refreshList()
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

-- if dictlist then convert List into an array
function ScrollerFast.new(definition)
	local self = UI.makeStatefulDefaults({
		List = {},
		DictList = false,
		FilterInput = false,
		RenderText = UI.Nil,
	}, definition)

	ScrollerFast.cloneRaw(self)
	self._filteredList = self._sortedList
	self._lineItemCache = {}

	self.List:hook(function()
		self:updateList()
	end)

	local function render()
		ScrollerFast.render(self)
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

		[UI.Event.Property] = {
			AbsoluteWindowSize = render,
			CanvasPosition = render,
		},
	}

	self._instance = UI.new "Frame" {
		Name = "ScrollerFast",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0),

		UI.new "UIListLayout" { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UI.Theme.Padding },
		self._scroller,

		[UI.Event.Property] = {
			Parent = render,
		},
	}

	if self.FilterInput._value then
		self._input = UI.new "Input" {
			LayoutOrder = -1,
			Parent = self._instance,
			Placeholder = "Search",
			Icon = "rbxassetid://18416000656",
			IconProperties = {
				Size = UDim2.fromOffset(18, 18),
			},

			[UI.Hook] = {
				Value = function()
					self:refreshList()
				end,
			},
		}
	end
	return setmetatable(self, ScrollerFast)
end

return ScrollerFast
