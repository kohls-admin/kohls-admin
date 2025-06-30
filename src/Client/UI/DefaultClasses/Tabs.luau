local BaseClass = require(script.Parent.BaseClass)
local UI = require(script.Parent.Parent)

local Tabs = {}
Tabs.__index = Tabs
setmetatable(Tabs, BaseClass)

function Tabs.new(definition)
	local new = UI.makeStatefulDefaults({
		-- TabSize = 64,
	}, definition)

	local tabOffset = UI.state(0)

	local tabList = UI.new "UIListLayout" {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UI.Theme.Padding,
	}

	local tabs = UI.new "Frame" {
		Name = "Tabs",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0),
		Position = UI.tween(function()
			return UDim2.new(0, tabOffset(), 0, 0)
		end, UI.Theme.TweenOut),

		tabList,
	}

	-- clamp offset on resize
	tabs:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		tabOffset(
			math.max(math.min(0, -tabList.AbsoluteContentSize.X + tabs.AbsoluteSize.X), tabOffset._value),
			false,
			true
		)
		-- TODO: keep current page visible when resizing down?
	end)

	local lastScroll
	local pageCache, containerCache = {}, {}
	local currentPage = UI.state(nil)

	local pages = UI.new "UIPageLayout" {
		Animated = true,
		TweenTime = 0.2,
		EasingStyle = Enum.EasingStyle.Quad,
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
		task.delay(pages.TweenTime, function()
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

	new._instance = UI.new "Frame" {
		Name = "TabController",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0),

		UI.new "UIListLayout" { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UI.Theme.Padding },

		UI.new "Frame" {
			Name = "Bar",
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),

			tabs,
			UI.new "UIPadding" {
				PaddingTop = UDim.new(0, 1),
				PaddingBottom = UDim.new(0, 1),
				PaddingLeft = UDim.new(0, 1),
				PaddingRight = UDim.new(0, 1),
			},

			-- TODO: Figure out next/previous tab size
			MouseWheelForward = function()
				local absoluteStart = new._instance.AbsolutePosition.X
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
				if closest == math.huge or lastScroll == closestChild then
					return
				end
				lastScroll = closestChild
				tabOffset(math.min(0, -(closestChild.AbsolutePosition.X - tabs.AbsolutePosition.X)))
			end,
			MouseWheelBackward = function()
				local absoluteStart = new._instance.AbsolutePosition.X
				local closest, closestChild = 9e9, nil
				for _, child in tabs:GetChildren() do
					if child:IsA("GuiObject") then
						local childStart = child.AbsolutePosition.X
						if childStart > absoluteStart + 2 and childStart - absoluteStart < closest then
							closest = math.floor(childStart - absoluteStart)
							closestChild = child
						end
					end
				end
				if closest == math.huge or lastScroll == closestChild then
					return
				end
				local maxOffset = tabList.AbsoluteContentSize.X - tabs.AbsoluteSize.X

				if maxOffset > 0 then
					lastScroll = closestChild
				end
				tabOffset(
					math.max(math.min(0, -maxOffset), -(closestChild.AbsolutePosition.X - tabs.AbsolutePosition.X))
				)
			end,
		},
	}

	local PagesFrame = UI.new "Frame" {
		Name = "PagesFrame",
		AnchorPoint = Vector2.new(0, 1),
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0),
		Position = UDim2.new(0, 0, 1, 0),

		pages,
	}

	new._content = UI.new "Frame" {
		LayoutOrder = 2,
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
		UI.new "UIPadding" {
			PaddingTop = UDim.new(0, 1),
			PaddingBottom = UDim.new(0, 1),
			PaddingLeft = UDim.new(0, 1),
			PaddingRight = UDim.new(0, 1),
		},
		PagesFrame,

		ChildAdded = function(page)
			local container = containerCache[page]
			task.defer(function()
				page.Parent = container
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
					return if currentPage() == container then UI.Theme.TransparencyOverlay() else 1
				end, UI.Theme.TweenOut),
				Font = UI.Theme.Font,
				RichText = true,
				Text = boldState,
				TextSize = UI.Theme.FontSize,
				TextColor3 = UI.Theme.PrimaryText,
				TextStrokeColor3 = UI.Theme.Primary,
				TextStrokeTransparency = UI.Theme.TextStrokeTransparency,
				TextTransparency = UI.tween(function()
					return if hovering() or currentPage() == container then 0 else 0.5
				end, UI.Theme.TweenOut),

				UI.new "UICorner" {
					CornerRadius = UI.Theme.CornerDiameter,
				},
				UI.new "Stroke" {},
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
					local absoluteStart = tabs.Parent.AbsolutePosition.X
					local absoluteEnd = absoluteStart + tabs.Parent.AbsoluteSize.X
					local buttonStart = button.AbsolutePosition.X
					local buttonEnd = buttonStart + button.AbsoluteSize.X + tabList.Padding.Offset

					if tabList.AbsoluteContentSize.X >= tabs.AbsoluteSize.X and absoluteEnd < buttonEnd + 32 then
						tabOffset(
							math.max(
								tabs.AbsoluteSize.X - tabList.AbsoluteContentSize.X,
								tabOffset._value - (32 + (buttonEnd - absoluteEnd))
							)
						)
					elseif buttonStart - 32 < absoluteStart then
						tabOffset(
							math.min(0, tabOffset._value + (absoluteStart - buttonStart) + 32 + tabList.Padding.Offset)
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
