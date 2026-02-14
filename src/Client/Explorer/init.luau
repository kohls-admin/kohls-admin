local _K = require(script.Parent.Parent)
local UI = require(script.Parent:WaitForChild("UI"))
local ExplorerOrder = require(script:WaitForChild("ExplorerOrder"))

local ContentProvider = game:GetService("ContentProvider")
local Reflection = game:GetService("ReflectionService")

local DragScope = {
	Active = false,
	StartPos = Vector3.zero,
	Ghost = nil :: Instance?,
	TargetNode = nil :: any,
}

local CLIPBOARD = {}
local SELECTION = {}
local SHOW_HIDDEN = false
local NODES = setmetatable({ [game] = { AncestorExpanded = true, Expanded = true, Instance = game } }, { __mode = "k" })

local scroller, updateListThrottled

local function isService(instance: Instance)
	local class = Reflection:GetClass(instance.ClassName)
	return class and class.Permits and class.Permits.GetService
end

local function setAncestorExpanded(node, value)
	local v = if node.Expanded then value else false
	for _, child in node.Instance:GetChildren() do
		local childNode = NODES[child]
		if childNode then
			childNode.AncestorExpanded = v
			setAncestorExpanded(childNode, v)
		end
	end
end

local function getFallbackIcon(instance: Instance)
	local path = if isService(instance)
		then "InsertableObjects/Dark/Standard/Service"
		else "Placeholder/Dark/Standard/Placeholder"

	return `rbxasset://studio_svg_textures/Shared/{path}.png`
end

local classIcons = {}
local function getClassIcon(instance: Instance)
	local existing = classIcons[instance.ClassName]
	if existing ~= nil then
		return existing or getFallbackIcon(instance)
	end

	return `rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/{instance.ClassName}.png`
end

local function setClassIcon(item, instance: Instance)
	local existing = classIcons[instance.ClassName]
	if existing ~= nil then
		item._instance.IconFrame.ImageLabel.Image = existing or getFallbackIcon(instance)
		return
	end

	item._instance.IconFrame.ImageLabel.Image =
		"rbxasset://studio_svg_textures/Shared/Placeholder/Dark/Standard/Placeholder.png"

	local texture = `rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/{instance.ClassName}.png`
	task.spawn(
		ContentProvider.PreloadAsync,
		ContentProvider,
		{ texture },
		function(path: string, Status: Enum.AssetFetchStatus)
			if Status == Enum.AssetFetchStatus.Success then
				classIcons[instance.ClassName] = path
				if item.node.Instance == instance then
					item._instance.IconFrame.ImageLabel.Image = path
				end
			elseif Status == Enum.AssetFetchStatus.Failure or Status == Enum.AssetFetchStatus.TimedOut then
				classIcons[instance.ClassName] = false
				if item.node.Instance == instance then
					item._instance.IconFrame.ImageLabel.Image = getFallbackIcon(instance)
				end
			end
		end
	)
end

local function sortChildren(a, b)
	local orderA = ExplorerOrder[a.ClassName]
	local orderB = ExplorerOrder[b.ClassName]
	if orderA and orderB and orderA ~= orderB then
		return orderA < orderB
	end
	if a.ClassName == b.ClassName then
		return a.Name < b.Name
	end
	return a.ClassName < b.ClassName
end

local function sortNodes(A: Instance, B: Instance)
	local a, b = NODES[A], NODES[B]
	if not a or not b then
		return false
	end
	return a.Index < b.Index
end

local function traverse(instance: Instance, index: number, traverseAll: boolean?)
	local node = NODES[instance]
	if not node or not (node.AncestorExpanded or traverseAll) then
		return index
	end

	node.Index = index

	local children = instance:GetChildren()
	table.sort(children, sortChildren)

	for _, child in children do
		index = traverse(child, index + 1, traverseAll)
	end

	return index
end

local function instanceRemoving(instance: Instance)
	local parentNode = instance.Parent and NODES[instance.Parent]
	if parentNode and parentNode.Expanded then
		updateListThrottled(scroller)
	end
end

local function check(instance: Instance)
	return instance.AncestryChanged
end

local function isAncestorExpanded(instance: Instance)
	if instance == game then
		return true
	end

	local parent = instance.Parent
	while parent do
		if parent == game then
			return true
		end
		local node = NODES[parent]
		if node and not node.Expanded then
			return false
		end
		parent = parent.Parent
	end

	return false
end

local function removeNode(instance)
	local node = NODES[instance]
	if node then
		if _K and _K.Flux and _K.Flux.cleanup then
			_K.Flux.cleanup(node)
		end
		NODES[instance] = nil
	end

	for _, descendant in instance:GetDescendants() do
		local descNode = NODES[descendant]
		if descNode then
			if _K and _K.Flux and _K.Flux.cleanup then
				_K.Flux.cleanup(descNode)
			end
			NODES[descendant] = nil
		end
	end
end

local function instanceAdded(instance: Instance, parent: Instance?)
	if not pcall(check, instance) then
		return
	end

	if not parent then
		parent = instance.Parent
	end

	if not parent then
		local node = NODES[instance]
		if node then
			removeNode(instance)
			if isAncestorExpanded(instance) then
				updateListThrottled(scroller)
			end
		end
		return
	end

	local tree, currParent = { instance }, parent
	while currParent do
		table.insert(tree, currParent)
		currParent = currParent.Parent
	end

	for i = #tree - 1, 1, -1 do
		local obj = tree[i]
		local objNode = NODES[obj]
		if not objNode then
			objNode = {
				AncestorExpanded = isAncestorExpanded(obj),
				Expanded = false,
				Selected = false,
				Instance = obj,
				Index = 0,
			}
			NODES[obj] = objNode
		end
		objNode.Depth = (#tree - i) - 1
	end

	local node = NODES[instance]
	if node then
		node.AncestorExpanded = isAncestorExpanded(instance)
		if not node.Connection then
			node.Connection = true

			instance.AncestryChanged:Connect(instanceAdded)
			instance.Destroying:Connect(function()
				local parentNode = instance.Parent and NODES[instance.Parent]
				if parentNode and parentNode.Expanded then
					updateListThrottled(scroller)
				end
				removeNode(instance)
			end)
		end
	end

	local parentNode = NODES[parent]
	if parentNode and parentNode.Expanded then
		updateListThrottled(scroller)
	end
end

local function parentInstanceUnsafe(instance: Instance, parent: Instance?)
	instance.Parent = parent
end

local function cloneInstanceUnsafe(instance, parent: Instance?)
	local clone = instance:Clone()
	clone.Parent = parent

	return clone
end

local function COPY()
	table.clear(CLIPBOARD)
	for _, node in SELECTION do
		if pcall(cloneInstanceUnsafe, node.Instance) then
			table.insert(CLIPBOARD, node.Instance)
		end
	end
end

local function DELETE()
	local instances = table.create(#SELECTION)
	for _, node in SELECTION do
		table.insert(instances, node.Instance)
	end
	_K.Remote.Explorer:Fire("DELETE", instances)

	for _, node in SELECTION do
		if node.Instance:IsA("Player") then
			continue
		end
		pcall(game.Destroy, node.Instance)
	end
	table.clear(SELECTION)
end

local function PASTE()
	local selected = SELECTION[1]
	_K.Remote.Explorer:Fire("PASTE", CLIPBOARD, selected.Instance)

	if not selected.Expanded then
		selected.Expanded = true
		setAncestorExpanded(selected, true)
	end

	updateListThrottled(scroller)
end

local titleBarHeight = UI.compute(function()
	return UI.Theme.FontSize() + UI.Theme.Padding().Offset * 2
end)

local titleBarButtonSize = function()
	return UDim2.fromOffset(titleBarHeight(), titleBarHeight())
end

local function Initialize()
	local Explorer = UI.new "Window" {
		Parent = UI.LayerTopInset,
		Icon = "rbxassetid://71961243872230",
		Name = "Explorer",
		Title = "Explorer",

		UI.new "UIListLayout" {
			Padding = UI.Theme.Padding,
		},
	}

	local titleBar = Explorer._instance.Frame.TitleBar

	local deleteButton = UI.new "Button" {
		Parent = titleBar,
		LayoutOrder = 4,
		Icon = UI.Theme.Image.Delete,
		IconProperties = {
			ImageColor3 = UI.Theme.PrimaryText,
			Size = UDim2.fromScale(0.625, 0.625),
		},
		Size = titleBarButtonSize,

		Activated = DELETE,
	}
	UI.new "Tooltip" { Parent = deleteButton, Hovering = deleteButton._hovering, Text = "Delete" }

	local copyButton = UI.new "Button" {
		Parent = titleBar,
		LayoutOrder = 6,
		Icon = UI.Theme.Image.Copy,
		IconProperties = {
			ImageColor3 = UI.Theme.PrimaryText,
			Size = UDim2.fromScale(0.625, 0.625),
		},
		Size = titleBarButtonSize,

		Activated = COPY,
	}
	UI.new "Tooltip" { Parent = copyButton, Hovering = copyButton._hovering, Text = "Copy" }

	local pasteButton = UI.new "Button" {
		Parent = titleBar,
		LayoutOrder = 7,
		Icon = UI.Theme.Image.Paste,
		IconProperties = {
			ImageColor3 = UI.Theme.PrimaryText,
			Size = UDim2.fromScale(0.625, 0.625),
		},
		Size = titleBarButtonSize,

		Activated = PASTE,
	}
	UI.new "Tooltip" { Parent = pasteButton, Hovering = pasteButton._hovering, Text = "Paste" }

	local itemSize = UDim2.new(1, 0, 0, 20)

	local function createGhost()
		if DragScope.Ghost then
			DragScope.Ghost:Destroy()
		end

		local ghost = UI.new "Frame" {
			Parent = UI.LayerTop,
			BackgroundTransparency = 1,
			Active = false,
			AutomaticSize = Enum.AutomaticSize.XY,
			Size = UDim2.new(),

			UI.new "UIListLayout" {
				SortOrder = Enum.SortOrder.LayoutOrder,
			},
		}

		for i, node in SELECTION do
			if node.Depth > 0 then
				UI.new "Frame" {
					LayoutOrder = i,
					Parent = ghost,
					AutomaticSize = Enum.AutomaticSize.X,
					BackgroundTransparency = 1,
					Size = UDim2.new(0, 0, 0, 20),

					UI.new "UIListLayout" {
						FillDirection = Enum.FillDirection.Horizontal,
						SortOrder = Enum.SortOrder.LayoutOrder,
						VerticalAlignment = Enum.VerticalAlignment.Center,
					},

					UI.new "Frame" {
						Name = "IconFrame",
						BackgroundTransparency = 1,
						Size = UDim2.fromOffset(20, 20),

						UI.new "ImageLabel" {
							BackgroundTransparency = 1,
							AnchorPoint = Vector2.new(0, 0.5),
							Position = UDim2.fromScale(0, 0.5),
							Size = UDim2.fromOffset(16, 16),
							Image = getClassIcon(node.Instance),
							ImageTransparency = 0.25,
						},
					},

					UI.new "TextLabel" {
						AutomaticSize = Enum.AutomaticSize.X,
						BackgroundTransparency = 1,
						Font = Enum.Font.SourceSans,
						Text = node.Instance.Name,
						TextSize = 16,
						TextColor3 = UI.Theme.PrimaryText,
						TextStrokeColor3 = UI.Theme.Primary,
						TextStrokeTransparency = UI.Theme.TextStrokeTransparency,
						TextTransparency = 0.25,
						TextTruncate = Enum.TextTruncate.SplitWord,
						Size = UDim2.new(0, 0, 1, 0),
						TextXAlignment = Enum.TextXAlignment.Left,
					},
				}
			end
		end

		DragScope.Ghost = ghost
	end

	local function updateGhost(position: Vector3)
		if DragScope.Ghost then
			DragScope.Ghost.Position = UDim2.fromOffset(position.X + 6, position.Y - 10 + UI.TopbarInset._value.Height)
		end
	end

	local function executeReparent()
		if not DragScope.TargetNode or not DragScope.TargetNode.Instance then
			return
		end

		local target = DragScope.TargetNode.Instance
		local changed = false

		for _, node in SELECTION do
			local inst = node.Instance
			if inst ~= target and not isService(inst) and not target:IsDescendantOf(inst) and inst.Parent ~= target then
				pcall(parentInstanceUnsafe, inst, target)
				changed = true
			end
		end

		if changed and DragScope.TargetNode then
			DragScope.TargetNode.Expanded = true
			setAncestorExpanded(DragScope.TargetNode, DragScope.TargetNode.Expanded)
			updateListThrottled(scroller)
		end
	end

	UI.UserInputService.InputChanged:Connect(function(input, processed)
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			if DragScope.Active then
				updateGhost(input.Position)
			end
		end
	end)

	UI.UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			if DragScope.Active then
				executeReparent()
				DragScope.Active = false
				DragScope.TargetNode = nil
				if DragScope.Ghost then
					DragScope.Ghost:Destroy()
					DragScope.Ghost = nil
				end
			end
		end
	end)

	UI.UserInputService.InputBegan:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.Keyboard then
			local ctrl = UI.UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
			if input.KeyCode == Enum.KeyCode.C and ctrl then
				COPY()
			elseif input.KeyCode == Enum.KeyCode.V and ctrl then
				PASTE()
			elseif input.KeyCode == Enum.KeyCode.Delete then
				DELETE()
			end
		end
	end)

	scroller = UI.new "ScrollerFast" {
		Parent = Explorer,
		List = NODES,
		DictList = true,
		Enabled = true,
		FilterInput = true,
		Visible = true,
		ItemSize = itemSize,
		CreateItem = function(self)
			local item = {} :: any
			local lastActivate = 0
			item._instance = UI.new "TextButton" {
				Parent = Explorer._content,
				AutoButtonColor = false,
				BackgroundColor3 = UI.Theme.Secondary,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				TextTransparency = 1,
				Size = itemSize,

				UI.new "UIPadding" {},

				UI.new "UIListLayout" {
					FillDirection = Enum.FillDirection.Horizontal,
					SortOrder = Enum.SortOrder.LayoutOrder,
					VerticalAlignment = Enum.VerticalAlignment.Center,
				},

				UI.new "TextButton" {
					Name = "Expand",
					BackgroundTransparency = 1,
					TextTransparency = 1,
					Size = UDim2.fromOffset(20, 20),

					UI.new "ImageLabel" {
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.fromScale(0.5, 0.5),
						BackgroundTransparency = 1,
						Size = UDim2.fromOffset(8, 8),
						Image = UI.Theme.Image.Down,
						Rotation = -90,
					},

					Activated = function()
						if item._instance.Expand.ImageLabel.Visible then
							item.node.Expanded = not item.node.Expanded
							setAncestorExpanded(item.node, item.node.Expanded)

							scroller:refreshList()
						end
					end,
				},

				UI.new "Frame" {
					Name = "IconFrame",
					BackgroundTransparency = 1,
					Size = UDim2.fromOffset(20, 20),

					UI.new "ImageLabel" {
						BackgroundTransparency = 1,
						AnchorPoint = Vector2.new(0, 0.5),
						Position = UDim2.fromScale(0, 0.5),
						Size = UDim2.fromOffset(16, 16),
						Image = UI.Theme.Image.Add,
					},
				},

				UI.new "TextLabel" {
					BackgroundTransparency = 1,
					Font = Enum.Font.SourceSans,
					TextSize = 16,
					TextColor3 = UI.Theme.PrimaryText,
					TextStrokeColor3 = UI.Theme.Primary,
					TextStrokeTransparency = UI.Theme.TextStrokeTransparency,
					TextTruncate = Enum.TextTruncate.SplitWord,
					Size = UDim2.new(1, -40, 1, 0),
					TextXAlignment = Enum.TextXAlignment.Left,
				},

				-- LOGIC START --
				Activated = function()
					if item._instance.Expand.ImageLabel.Visible then
						local last = lastActivate
						lastActivate = os.clock()
						if lastActivate - last < 0.3 then
							item.node.Expanded = not item.node.Expanded
							setAncestorExpanded(item.node, item.node.Expanded)
							scroller:refreshList()
							return
						end
					end

					local ctrl = UI.UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
					local shift = UI.UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)

					if ctrl or shift then -- Toggle selection
						item.node.Selected = not item.node.Selected
						if item.node.Selected then
							table.insert(SELECTION, item.node)
							item._instance.BackgroundTransparency = 0.75
						else
							local idx = table.find(SELECTION, item.node)
							if idx then
								table.remove(SELECTION, idx)
								item._instance.BackgroundTransparency = 0.9
							end
						end
					else -- Single select
						for _, v in scroller._lineItemCache do
							v._instance.BackgroundTransparency = 1
						end
						for _, v in scroller._lineItemFree do
							v._instance.BackgroundTransparency = 1
						end
						for _, v in SELECTION do
							v.Selected = false
						end
						table.clear(SELECTION)

						item.node.Selected = true
						table.insert(SELECTION, item.node)
						item._instance.BackgroundTransparency = 0.75
					end
				end,

				TouchLongPress = function(input, processed)
					DragScope.StartPos = input.Position
				end,

				InputBegan = function(input, processed)
					if input.UserInputType == Enum.UserInputType.MouseButton1 then
						DragScope.StartPos = input.Position
					end
				end,

				InputChanged = function(input, processed)
					if input.UserInputType == Enum.UserInputType.MouseMovement then
						if
							not DragScope.Active
							and UI.UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
							and item.node
							and item.node.Depth > 0
						then
							local delta = (input.Position - DragScope.StartPos).Magnitude
							if delta > 5 then
								DragScope.Active = true

								if item.node and not item.node.Selected then
									for _, v in SELECTION do
										v.Selected = false
									end
									table.clear(SELECTION)
									item.node.Selected = true
									table.insert(SELECTION, item.node)
									scroller:refreshList()
								end

								createGhost()
								updateGhost(input.Position)
							end
						end
					end
				end,
			}

			item.hovering = UI.newSinkHoverState(item._instance)
			UI.edit(item._instance, {
				BackgroundTransparency = UI.compute(function()
					local hover = item.hovering()
					if hover and DragScope.Active then
						DragScope.TargetNode = item.node
					end
					if item.node and item.node.Selected then
						return 0.75
					end
					return if hover then 0.875 else 1
				end),
			})

			return item
		end,
		RenderItem = function(self, item, instance)
			local node = NODES[instance]
			if node then
				item.node = node
				item._instance.TextLabel.Text = instance.Name
				item._instance.BackgroundTransparency = if node.Selected then 0.75 else 1

				setClassIcon(item, instance)
				item._instance.Expand.ImageLabel.Visible = #instance:GetChildren() > 0
				item._instance.Expand.ImageLabel.Rotation = if node.Expanded then 0 else -90
				item._instance.UIPadding.PaddingLeft = UDim.new(0, node.Depth * 10)
			end
		end,
	}

	UI.new "Tooltip" {
		Parent = scroller._input._instance.ImageLabel,
		Text = "Search uses game:QueryDescendants()",
	}

	updateListThrottled = _K.Util.Function.throttle(1, scroller.updateList)

	scroller:filter(function(self, list)
		local new = {}
		local rawFilter = scroller._input._input.Text
		local filter = rawFilter
		self._filter = filter

		local noFilter = string.find(self._filter, "^%s*$")
		local query

		if noFilter then
			for _, instance in list do
				if not ExplorerOrder[instance.ClassName] and not SHOW_HIDDEN then
					continue
				end
				local node = NODES[instance]
				if node and node.AncestorExpanded and node.Depth then
					table.insert(new, instance)
				end
			end
		else
			-- prefix names with "#"
			if string.find(filter, "^%w$") and not Reflection:GetClass(filter) then
				filter = "#" .. filter
			end

			local cache, count, ok = {}, 0, nil
			ok, query = pcall(game.QueryDescendants, game, filter)
			if not ok then
				query = {}
			end

			if #query > 0 then
				for _, instance in query do
					if not ExplorerOrder[instance.ClassName] and not SHOW_HIDDEN then
						continue
					end
					local node = NODES[instance]
					if node and node.Depth then
						count += 1
						cache[instance] = true
						local parent = instance.Parent
						while parent and parent ~= game and not cache[parent] do
							cache[parent] = true
							parent = parent.Parent
						end
					end
				end
			else
				filter = string.lower(rawFilter)
				for _, instance in list do
					if not ExplorerOrder[instance.ClassName] and not SHOW_HIDDEN then
						continue
					end
					local node = NODES[instance]
					if node and node.Depth and string.find(string.lower(instance.Name), filter, 1, true) then
						count += 1
						cache[instance] = true
						local parent = instance.Parent
						while parent and parent ~= game and not cache[parent] do
							cache[parent] = true
							parent = parent.Parent
						end
					end
				end
			end
			if count > 32 then
				new = table.create(count)
			end
			for instance in cache do
				table.insert(new, instance)
			end
		end

		traverse(game, 0, not noFilter)
		table.sort(new, sortNodes)

		return new
	end)

	UI.edit(Explorer, { Visible = true })

	game.DescendantAdded:Connect(instanceAdded)
	game.DescendantRemoving:Connect(instanceRemoving)
	for _, instance in game:GetDescendants() do
		task.spawn(instanceAdded, instance)
	end

	return Explorer
end

local initialized = false

return {
	Show = function()
		if not initialized then
			initialized = Initialize()
		else
			UI.edit(initialized, { Visible = true })
		end
	end,
}
