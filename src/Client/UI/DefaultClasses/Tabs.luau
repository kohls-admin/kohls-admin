local BaseClass = require(script.Parent.BaseClass)
local UI = require(script.Parent.Parent)

local Tabs = {}
Tabs.__index = Tabs
setmetatable(Tabs, BaseClass)

function Tabs.new(definition)
	local new = UI.makeStatefulDefaults({
		Vertical = false,
	}, definition)

	local tabOffset = UI.state(0)
	local lastScroll

	local tabList = UI.new "UIListLayout" {
		FillDirection = function()
			return if new.Vertical() then Enum.FillDirection.Vertical else Enum.FillDirection.Horizontal
		end,
		HorizontalFlex = function()
			return if new.Vertical() then Enum.UIFlexAlignment.Fill else Enum.UIFlexAlignment.None
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
			return if new.Vertical() then Enum.AutomaticSize.X else Enum.AutomaticSize.Y
		end,
		BackgroundTransparency = 1,
		ClipsDescendants = false,
		CanvasPosition = UI.tween(function()
			return if new.Vertical() then Vector2.new(0, tabOffset()) else Vector2.new(tabOffset(), 0)
		end, UI.Theme.TweenOut),
		CanvasSize = UDim2.new(),
		Size = UDim2.new(1, 0, 1, 0),
		ScrollBarThickness = 0,

		MouseWheelForward = function()
			if new.Vertical() then
				lastScroll = nil
				return
			end
			local absoluteStart = new._instance.AbsolutePosition.X
			local closest, closestChild = math.huge, nil
			for _, child in tabs:GetChildren() do
				if child:IsA("GuiObject") then
					local childStart = child.AbsolutePosition.X
					if childStart < absoluteStart - 2 and absoluteStart - childStart < closest then
						print(child)
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
			if new.Vertical() then
				lastScroll = nil
				return
			end
			local absoluteStart = new._instance.AbsolutePosition.X
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
				if tabs.CanvasPosition.Y == 1 and not new.Vertical() then
					tabs.CanvasPosition = Vector2.new(tabs.CanvasPosition.X, 0)
				end
			end,
		},

		tabList,
	}

	tabs:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		if new.Vertical() then
			tabOffset(math.clamp(tabOffset._value, 0, tabList.AbsoluteContentSize.Y + tabs.AbsoluteSize.Y), false, true)
		else
			tabOffset(math.clamp(tabOffset._value, 0, tabList.AbsoluteContentSize.X + tabs.AbsoluteSize.X), false, true)
		end
		-- TODO: keep current page visible when resizing down?
	end)

	local pageCache, containerCache = {}, {}
	local currentPage = UI.state(nil)

	local pages = UI.new "UIPageLayout" {
		Animated = false,
		SortOrder = Enum.SortOrder.LayoutOrder,
		ScrollWheelInputEnabled = false,
		Padding = UI.Theme.Padding,
	}
	new._pages = pages

	pages.PageEnter:Connect(function(container)
		currentPage(container)
		local page = pageCache[container]
		if not page then
			return
		end
		page.Visible = true
		page.Parent = container
	end)

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

	new.JumpTo = function(page)
		page = containerCache[page] or page
		currentPage(page)
		pages:JumpTo(page)
	end

	local function tabPadding()
		return if new.Vertical() then UI.Theme.Padding() else UDim.new(0, 1)
	end

	new._instance = UI.new "Frame" {
		Name = "TabController",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0),

		UI.new "UIListLayout" {
			FillDirection = function()
				return if new.Vertical() then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical
			end,
			SortOrder = Enum.SortOrder.LayoutOrder,
		},

		UI.new "Frame" {
			Name = "Bar",
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			AutomaticSize = function()
				return if new.Vertical() then Enum.AutomaticSize.X else Enum.AutomaticSize.Y
			end,
			Size = function()
				return if new.Vertical() then UDim2.new(0, 0, 1, 0) else UDim2.new(1, 0, 0, 0)
			end,

			tabs,

			UI.new "UIPadding" {
				PaddingTop = tabPadding,
				PaddingBottom = tabPadding,
				PaddingLeft = UI.Theme.Padding,
				PaddingRight = UI.Theme.Padding,
			},
		},
	}

	local PagesFrame = UI.new "Frame" {
		Name = "PagesFrame",
		AnchorPoint = Vector2.new(0, 1),
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0),
		Position = UDim2.new(0, 0, 1, 0),

		UI.new "UIPadding" {
			PaddingTop = UDim.new(0, 1),
			PaddingLeft = UI.Theme.Padding,
			PaddingRight = UI.Theme.Padding,
		},

		pages,
	}

	new._content = UI.new "Frame" {
		LayoutOrder = 3,
		Name = "UIContent",
		Parent = new._instance,
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
			task.defer(function()
				page.Parent = if currentPage() == container then container else nil
			end)
			if container then
				return
			end

			container = UI.new "Frame" {
				Parent = PagesFrame,
				Name = page.Name,
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
			}
			pageCache[container] = page
			containerCache[page] = container

			local nameState = UI.state(page, "Name")
			local boldState = function()
				return `<b>{nameState()}</b>`
			end
			local hovering, button = UI.state(false)
			button = UI.new "TextButton" {
				AutoLocalize = false,
				Parent = tabs,
				Name = nameState,
				LayoutOrder = page.LayoutOrder,
				AutoButtonColor = false,
				AutomaticSize = Enum.AutomaticSize.XY,
				Size = UDim2.new(0, 0, 0, 0),
				BackgroundColor3 = UI.Theme.Secondary,
				BackgroundTransparency = UI.tween(function()
					local hover = hovering()
					local selected = currentPage() == container
					return if selected
						then UI.Theme.TransparencyHeavy()
						elseif hover then UI.Theme.TransparencyMax()
						else 1
				end, UI.Theme.TweenOut),
				Font = UI.Theme.Font,
				RichText = true,
				Text = boldState,
				TextSize = UI.Theme.FontSize,
				TextColor3 = UI.Theme.PrimaryText,
				TextStrokeColor3 = UI.Theme.Primary,
				TextStrokeTransparency = UI.Theme.TextStrokeTransparency,
				TextTransparency = UI.tween(function()
					local hover = hovering()
					local current = currentPage() == container
					return if current then 0 elseif hover then 0.125 else 0.5
				end, UI.Theme.TweenOut),
				TextXAlignment = Enum.TextXAlignment.Left,

				UI.new "UICorner" {
					CornerRadius = UI.Theme.CornerRadius,
				},
				UI.new "Stroke" {
					Transparency = UI.tween(function()
						local hover = hovering()
						local selected = currentPage() == container
						return if selected
							then UI.Theme.TransparencyLight()
							elseif hover then UI.Theme.TransparencyBalanced()
							else 1
					end, UI.Theme.TweenOut),
				},
				UI.new "UIPadding" {
					PaddingTop = UI.Theme.Padding,
					PaddingBottom = UI.Theme.Padding,
					PaddingLeft = UI.Theme.Padding,
					PaddingRight = UI.Theme.Padding,
				},

				InputChanged = function(input, processed)
					if processed then
						return
					end
					if
						input.UserInputType == Enum.UserInputType.MouseMovement
						or input.UserInputType == Enum.UserInputType.Touch
					then
						if UI.sinkInput(input.Position.X, input.Position.Y, button) then
							UI.deactivateState(hovering, "hover")
							return
						end
						UI.activateState(hovering, "hover")
					end
				end,
				inputEnded = function(input)
					if
						input.UserInputType == Enum.UserInputType.MouseMovement
						or input.UserInputType == Enum.UserInputType.Touch
					then
						UI.deactivateState(hovering, "hover")
					end
				end,
				Activated = function()
					UI.clearActiveStates()
					UI.Sound.Hover03:Play()
					currentPage(container)
					pages:JumpTo(container)

					local axis = if new.Vertical() then "Y" else "X"
					local absoluteStart = tabs.Parent.AbsolutePosition[axis]
					local absoluteEnd = absoluteStart + tabs.Parent.AbsoluteSize[axis]
					local buttonStart = button.AbsolutePosition[axis]
					local buttonEnd = buttonStart + button.AbsoluteSize[axis] + tabList.Padding.Offset

					if
						tabList.AbsoluteContentSize[axis] >= tabs.AbsoluteSize[axis]
						and absoluteEnd < buttonEnd + 32
					then
						tabOffset(
							math.min(
								tabList.AbsoluteContentSize[axis] - tabs.AbsoluteSize[axis],
								tabOffset + (32 + (buttonEnd - absoluteEnd))
							)
						)
					elseif buttonStart - 32 < absoluteStart then
						tabOffset(
							math.max(0, tabOffset - ((absoluteStart - buttonStart) + 32 + tabList.Padding.Offset))
						)
					end
				end,
			}
			local function hideButton()
				button.Visible = (page.Parent == container or page.Parent == nil)
					and page:GetAttribute("Enabled") ~= false
				container.Visible = button.Visible
				container.Parent = if button.Visible then PagesFrame else nil
			end
			page:GetPropertyChangedSignal("Parent"):Connect(hideButton)
			page:GetAttributeChangedSignal("Enabled"):Connect(hideButton)
			hideButton()
			task.defer(function()
				if pages.CurrentPage == container then
					currentPage(container)
				end
			end)
		end,
	}

	return setmetatable(new, Tabs)
end

return Tabs
