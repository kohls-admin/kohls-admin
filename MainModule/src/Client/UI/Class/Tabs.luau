local Class = require(script.Parent)

local Object
do
	Object = Instance.new("Frame")
	Object.Name = "TabController"
	Object.Transparency = 1
	Object.Size = UDim2.new(1, 0, 1, 0)

	local Bar = Instance.new("Frame", Object)
	Bar.Name = "Bar"
	Bar.BackgroundColor3 = Color3.new()
	Bar.BackgroundTransparency = 0.8
	Bar.BorderSizePixel = 0
	Bar.ClipsDescendants = true
	Bar.Size = UDim2.new(1, 0, 0, 24)

	local Current = Instance.new("Frame", Bar)
	Current.Name = "Current"
	Current.BorderSizePixel = 0
	Current.AnchorPoint = Vector2.new(0, 1)
	Current.BackgroundColor3 = Color3.new(1, 1, 1)
	Current.Position = UDim2.new(0, 0, 1, 0)
	Current.Size = UDim2.new(0, 80, 0, 2)

	local Tabs = Instance.new("Frame", Bar)
	Tabs.Name = "Tabs"
	Tabs.Transparency = 1
	Tabs.Size = UDim2.new(1, 0, 1, 0)

	local Layout = Instance.new("UIListLayout", Tabs)
	Layout.Name = "Layout"
	Layout.FillDirection = Enum.FillDirection.Horizontal
	Layout.SortOrder = Enum.SortOrder.LayoutOrder

	local Content = Instance.new("Frame", Object)
	Content.Name = "Content"
	Content.Transparency = 1
	Content.ClipsDescendants = true
	Content.Position = UDim2.new(0, 0, 0, 24)
	Content.Size = UDim2.new(1, 0, 1, -24)

	local Pages = Instance.new("UIPageLayout", Content)
	Pages.Name = "Pages"
	Pages.Animated = true
	Pages.TweenTime = 0.2
	Pages.EasingStyle = Enum.EasingStyle.Quad
	Pages.SortOrder = Enum.SortOrder.LayoutOrder
	Pages.ScrollWheelInputEnabled = false
end

return Class:Create({
	_name = "Tabs",
	_super = "BaseClass",

	_init = function(self)
		local rbx = Object:Clone()
		self:rawset("_rbx", rbx) -- read-only
		self:rawset("_parentTo", rbx.Content) -- read-only

		self.ThemeData[rbx.Bar] = { BackgroundColor3 = "Primary", BackgroundTransparency = { "Primary", 0.5 } }
		self.ThemeData[rbx.Bar.Current] = { BackgroundColor3 = "Secondary" }

		local pages = rbx.Content.Pages

		local tabs, tabMax = {}, 0
		local tabSize = 80 -- make a property for this...

		local bar = rbx.Bar
		local barMax, barOffset, currentOffset = 0, 0, 0

		bar.MouseWheelBackward:Connect(function()
			barOffset = math.max(-barMax, barOffset - tabSize)
			bar.Current:TweenPosition(UDim2.new(0, currentOffset + barOffset, 1, 0), "Out", "Quad", 0.2, true)
			bar.Tabs:TweenPosition(UDim2.new(0, barOffset, 0, 0), "Out", "Quad", 0.2, true)
		end)

		bar.MouseWheelForward:Connect(function()
			barOffset = math.min(0, barOffset + tabSize)
			bar.Current:TweenPosition(UDim2.new(0, currentOffset + barOffset, 1, 0), "Out", "Quad", 0.2, true)
			bar.Tabs:TweenPosition(UDim2.new(0, barOffset, 0, 0), "Out", "Quad", 0.2, true)
		end)

		bar:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			local barSize = bar.AbsoluteSize.X
			barMax = math.max(0, tabMax - barSize)
			--		if tabsMax < barSize then
			--			for i, v in next, bar.Tabs:GetChildren() do
			--				if v.ClassName ~= 'UIListLayout' then
			--
			--				end
			--			end
			--		end
		end)

		rbx.Content.ChildAdded:Connect(function(page)
			local obj = Class.objTables[page]
			if obj and obj.ClassName == "Dialog" then
				return
			end

			local btn = Class.new("Button")
			btn.Name = page.Name
			btn.Theme = self.Theme
			btn.LayoutOrder = page.LayoutOrder
			btn.BackgroundTransparency = 1
			btn.Size = UDim2.new(0, tabSize, 1, 0)
			btn.Text = page.Name:upper()
			btn.Label.FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.SemiBold)
			btn.Label.TextSize = 12
			btn.Label.TextTransparency = 0.5
			btn.Label.TextStrokeTransparency = 0.95

			btn.MouseEnter:Connect(function()
				if pages.CurrentPage ~= page then
					for k, v in next, tabs do
						if pages.CurrentPage ~= v then
							k.Label.TextTransparency = 0.5
							k.Label.TextStrokeTransparency = 0.95
						end
					end
					btn.Label.TextTransparency = 0
					btn.Label.TextStrokeTransparency = 0.9
				end
			end)

			btn.MouseLeave:Connect(function()
				if pages.CurrentPage ~= page then
					btn.Label.TextTransparency = 0.5
					btn.Label.TextStrokeTransparency = 0.95
				end
			end)

			btn.MouseButton1Click:Connect(function()
				for _, v in next, bar.Tabs:GetChildren() do
					if v:IsA("TextButton") then
						v.Label.TextTransparency, v.Label.TextStrokeTransparency = 0.5, 0.95
					end
				end
				btn.Label.TextTransparency, btn.Label.TextStrokeTransparency = 0, 0.9
				pages:JumpTo(page)
				currentOffset = btn.AbsolutePosition.X - bar.Tabs.AbsolutePosition.X
				if btn.AbsolutePosition.X > bar.AbsolutePosition.X + bar.AbsoluteSize.X - tabSize - 1 then
					barOffset = math.max(-barMax, barOffset - tabSize)
					bar.Current:TweenPosition(UDim2.new(0, currentOffset + barOffset, 1, 0), "Out", "Quad", 0.2, true)
					bar.Tabs:TweenPosition(UDim2.new(0, barOffset, 0, 0), "Out", "Quad", 0.2, true)
				elseif btn.AbsolutePosition.X < bar.AbsolutePosition.X + tabSize then
					barOffset = math.min(0, barOffset + tabSize)
					bar.Current:TweenPosition(UDim2.new(0, currentOffset + barOffset, 1, 0), "Out", "Quad", 0.2, true)
					bar.Tabs:TweenPosition(UDim2.new(0, barOffset, 0, 0), "Out", "Quad", 0.2, true)
				else
					bar.Current:TweenPosition(
						UDim2.new(0, btn.AbsolutePosition.X - bar.AbsolutePosition.X, 1, 0),
						"Out",
						"Quad",
						0.2,
						true
					)
				end
			end)

			btn.Parent = bar.Tabs
			tabs[btn], tabMax = page, tabMax + tabSize
			bar.Tabs.Size = UDim2.new(0, tabMax, 1, 0)

			spawn(function()
				if pages.CurrentPage == page then
					btn.Label.TextTransparency = 0
					btn.Label.TextStrokeTransparency = 0.9
				end
			end)
		end)
	end,
})
