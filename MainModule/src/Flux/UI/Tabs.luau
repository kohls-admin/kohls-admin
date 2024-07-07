local BaseClass = require(script.Parent.BaseClass)
local UI = require(script.Parent)

local Tabs = {}
Tabs.__index = Tabs
setmetatable(Tabs, BaseClass)

function Tabs.new(definition)
	local new = UI.makeStatefulDefaults({
		TabSize = 64,
	}, definition)

	local tabOffset = UI.state(0)

	local tabList = UI.new "UIListLayout" {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UI.Theme.Padding,
	}

	local tabs = UI.new "Frame" {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0),
		Position = UI.tween(UI.Theme.NormalTween, UI.computeFrom(UDim2.new, 0, tabOffset, 0, 0)),

		[UI.Children] = {
			UIListLayout = tabList,
		},
	}

	-- clamp offset on resize
	tabs:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		tabOffset:set(
			math.max(math.min(0, -tabList.AbsoluteContentSize.X + tabs.AbsoluteSize.X), tabOffset._value),
			false,
			true
		)
		-- TODO: keep current page visible when resizing down?
	end)

	local pages = UI.new "UIPageLayout" {
		Animated = true,
		TweenTime = 0.2,
		EasingStyle = Enum.EasingStyle.Quad,
		SortOrder = Enum.SortOrder.LayoutOrder,
		ScrollWheelInputEnabled = false,
		Padding = UDim.new(0, 8),
	}
	new._pages = pages
	new._instance = UI.new "Frame" {
		Name = "TabController",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0),

		[UI.Children] = {
			Bar = UI.new "Frame" {
				BackgroundTransparency = 1,
				ClipsDescendants = true,
				Size = UDim2.new(1, 0, 0, 24),

				[UI.Children] = {
					Tabs = tabs,
				},

				[UI.Event] = {
					MouseWheelForward = function()
						tabOffset:set(math.min(0, tabOffset._value + new.TabSize._value + tabList.Padding.Offset))
					end,
					MouseWheelBackward = function()
						tabOffset:set(
							math.max(
								math.min(0, -tabList.AbsoluteContentSize.X + tabs.AbsoluteSize.X),
								tabOffset._value - (new.TabSize._value + tabList.Padding.Offset)
							)
						)
					end,
				},
			},
		},
	}

	local content = UI.new "Frame" {
		Name = "UIContent",
		Parent = new._instance,
		AnchorPoint = Vector2.new(0, 1),
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, -24),
		Position = UDim2.new(0, 0, 1, 0),
		ClipsDescendants = true,

		[UI.Children] = {
			Pages = pages,
			UIPadding = UI.new "UIPadding" {
				PaddingTop = UI.Theme.Padding,
			},
		},
	}

	local currentPage = UI.state(nil)
	local tabFontSize = UI.compute(function(use)
		return use(UI.Theme.FontSize) - 4
	end)
	content.ChildAdded:Connect(function(page)
		local nameState = UI.state(page, "Name")
		local upperState = UI.computeFrom(string.upper, nameState)
		local hovering, textFits, button = UI.state(false), UI.state(false)
		button = UI.new "TextButton" {
			Parent = tabs,
			Name = nameState,
			LayoutOrder = page.LayoutOrder,
			AutoButtonColor = false,
			Size = UI.computeFrom(UDim2.new, 0, new.TabSize, 1, 0),
			BackgroundColor3 = UI.Theme.Border,
			BackgroundTransparency = UI.tween(
				UI.Theme.NormalTween,
				UI.compute(function(use)
					return if use(currentPage) == page then use(UI.Theme.Transparency) else 1
				end)
			),
			Font = UI.Theme.Font,
			Text = upperState,
			TextSize = tabFontSize,
			TextColor3 = UI.Theme.PrimaryText,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextTransparency = UI.tween(
				UI.Theme.NormalTween,
				UI.compute(function(use)
					return if use(hovering) or use(currentPage) == page then 0 else 0.5
				end)
			),

			UI.new "UICorner" {
				CornerRadius = UI.Theme.CornerDiameter,
			},
			UI.new "UIStroke" {
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Transparency = UI.Theme.Transparency,
				Color = UI.Theme.Border,
			},
			UI.new "Tooltip" {
				Text = upperState,
				Enabled = UI.compute(function(use)
					return not use(textFits)
				end),
			},

			[UI.Event] = {
				MouseEnter = function()
					hovering:set(true)
				end,
				MouseLeave = function()
					hovering:set(false)
				end,
				Activated = function()
					currentPage:set(page)
					pages:JumpTo(page)
					if
						button.AbsolutePosition.X
						> tabs.Parent.AbsolutePosition.X
							+ tabs.Parent.AbsoluteSize.X
							- new.TabSize._value * 1.5
							- tabList.Padding.Offset
					then
						tabOffset:set(
							math.max(
								-tabList.AbsoluteContentSize.X + tabs.AbsoluteSize.X,
								tabOffset._value - (new.TabSize._value + tabList.Padding.Offset)
							)
						)
					elseif
						button.AbsolutePosition.X
						< tabs.Parent.AbsolutePosition.X + new.TabSize._value + tabList.Padding.Offset
					then
						tabOffset:set(math.min(0, tabOffset._value + new.TabSize._value * 1.5 + tabList.Padding.Offset))
					end
				end,
			},
		}
		textFits:bindToProperty(button, "TextFits")
		task.defer(function()
			if pages.CurrentPage == page then
				currentPage:set(page)
			end
		end)
	end)

	return setmetatable(new, Tabs)
end

return Tabs
