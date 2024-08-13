local BaseClass = require(script.Parent.BaseClass)
local UI = require(script.Parent)

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
		Position = UI.tween(UI.Theme.TweenOut, UI.computeFrom(UDim2.new, 0, tabOffset, 0, 0)),

		tabList,
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

	local lastScroll

	local pages = UI.new "UIPageLayout" {
		Animated = true,
		TweenTime = 0.2,
		EasingStyle = Enum.EasingStyle.Quad,
		SortOrder = Enum.SortOrder.LayoutOrder,
		ScrollWheelInputEnabled = false,
		Padding = UI.Theme.Padding,
	}
	new._pages = pages
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

			[UI.Event] = {
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
					tabOffset:set(math.min(0, -(closestChild.AbsolutePosition.X - tabs.AbsolutePosition.X)))
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
					tabOffset:set(
						math.max(math.min(0, -maxOffset), -(closestChild.AbsolutePosition.X - tabs.AbsolutePosition.X))
					)
				end,
			},
		},
	}

	local currentPage = UI.state(nil)
	local tabFontSize = UI.compute(function(use)
		return use(UI.Theme.FontSize) - 4
	end)

	new._content = UI.new "Frame" {
		LayoutOrder = 2,
		Name = "UIContent",
		Parent = new._instance,
		AnchorPoint = Vector2.new(0, 1),
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0),
		Position = UDim2.new(0, 0, 1, 0),
		ClipsDescendants = true,

		pages,
		UI.new "UIFlexItem" {
			FlexMode = Enum.UIFlexMode.Fill,
		},
		UI.new "UIPadding" {
			PaddingTop = UDim.new(0, 1),
			PaddingBottom = UDim.new(0, 1),
			PaddingLeft = UDim.new(0, 1),
			PaddingRight = UDim.new(0, 1),
		},

		[UI.Event] = {
			ChildAdded = function(page)
				local nameState = UI.state(page, "Name")
				local upperState = UI.computeFrom(string.upper, nameState)
				local hovering, textFits, button = UI.state(false), UI.state(false)
				button = UI.new "TextButton" {
					Parent = tabs,
					Name = nameState,
					LayoutOrder = page.LayoutOrder,
					AutoButtonColor = false,
					AutomaticSize = Enum.AutomaticSize.XY,
					Size = UDim2.new(0, 0, 0, 0), --UI.computeFrom(UDim2.new, 0, strokeTabSize, 1, 0),
					BackgroundColor3 = UI.Theme.Border,
					BackgroundTransparency = UI.tween(
						UI.Theme.TweenOut,
						UI.compute(function(use)
							return if use(currentPage) == page then use(UI.Theme.Transparency) else 1
						end)
					),
					Font = UI.Theme.Font,
					Text = upperState,
					TextSize = tabFontSize,
					TextColor3 = UI.Theme.PrimaryText,
					TextTransparency = UI.tween(
						UI.Theme.TweenOut,
						UI.compute(function(use)
							return if use(hovering) or use(currentPage) == page then 0 else 0.5
						end)
					),

					UI.new "UICorner" {
						CornerRadius = UI.Theme.CornerDiameter,
					},
					UI.new "UIStroke" {
						Enabled = UI.Theme.StrokeEnabled,
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
						Transparency = UI.Theme.TransparencyClamped,
						Color = UI.Theme.Border,
					},
					UI.new "UIPadding" {
						PaddingTop = UI.Theme.Padding,
						PaddingBottom = UI.Theme.Padding,
						PaddingLeft = UI.Theme.Padding,
						PaddingRight = UI.Theme.Padding,
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
							local absoluteStart = tabs.Parent.AbsolutePosition.X
							local absoluteEnd = absoluteStart + tabs.Parent.AbsoluteSize.X
							local buttonStart = button.AbsolutePosition.X
							local buttonEnd = buttonStart + button.AbsoluteSize.X + tabList.Padding.Offset

							if absoluteEnd < buttonEnd + 32 then
								tabOffset:set(
									math.max(
										-tabList.AbsoluteContentSize.X + tabs.AbsoluteSize.X,
										tabOffset._value - (32 + (buttonEnd - absoluteEnd))
									)
								)
							elseif buttonStart - 32 < absoluteStart then
								tabOffset:set(
									math.min(
										0,
										tabOffset._value + (absoluteStart - buttonStart) + 32 + tabList.Padding.Offset
									)
								)
								-- tabOffset:set(math.min(0, tabOffset._value + new.TabSize._value + tabList.Padding.Offset))
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
			end,
		},
	}

	return setmetatable(new, Tabs)
end

return Tabs
