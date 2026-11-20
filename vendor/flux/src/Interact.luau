--!strict
--[[
Interaction state as read-only boolean nodes (`hover`, `press`, `selected`, `focused`) and the hit tests `pointIn`,
`sunk` and `covered`. Available as `Flux.Interact`.

```luau
local hovered = Flux.Interact.hover(button)
```
]]

local Compat = require("./Compat")
local Graph = require("./Graph")

local Enum = Compat.Enum

local dispose = Graph.dispose
local signal = Graph.signal

-- The engine services `press` and `selected` listen to; the specs hand in stand-ins.
--- @ignore
export type Services = {
	GuiService: GuiService,
	UserInputService: UserInputService,
}

export type HoverOptions = {
	-- Only guis outside the object cover it: a row, a card or a scrolling area stays hovered over its own buttons.
	within: boolean?,
}

-- What hover listens to. `events` hands out an object's own pointer events: the object itself, or a spec's stand-ins.
--- @ignore
export type HoverServices = {
	GuiService: any,
	UserInputService: any,
	RunService: any,
	events: ((object: any) -> any)?,
}

if Compat.Instance == nil or Enum == nil then
	local stubs = Compat.robloxStubs("Flux.Interact", {
		"pointIn",
		"sunk",
		"covered",
		"hover",
		"press",
		"selected",
		"focused",
	})
	return table.freeze({
		pointIn = stubs.pointIn,
		sunk = stubs.sunk,
		covered = stubs.covered,
		hover = stubs.hover,
		press = stubs.press,
		selected = stubs.selected,
		focused = stubs.focused,
		_useHoverServices = function()
			return nil
		end,
	}) :: any
end

local MOUSE_MOVEMENT = Enum.UserInputType.MouseMovement
local MOUSE_BUTTON1 = Enum.UserInputType.MouseButton1
local TOUCH = Enum.UserInputType.Touch
local STATE_END = Enum.UserInputState.End
local STATE_CANCEL = Enum.UserInputState.Cancel
local ACTIVATE_KEYS: { [any]: boolean } = {
	[Enum.KeyCode.ButtonA] = true,
	[Enum.KeyCode.Return] = true,
	[Enum.KeyCode.KeypadEnter] = true,
}

local engine: HoverServices? = nil

local function engineServices(): any
	local resolved = engine
	if resolved == nil then
		local guiService = Compat.getService("GuiService")
		if guiService == nil then
			return nil
		end
		resolved = {
			GuiService = guiService,
			UserInputService = Compat.getService("UserInputService"),
			RunService = Compat.getService("RunService"),
		} :: HoverServices
		engine = resolved
	end
	return resolved
end

local function menuOpen(env: { GuiService: any }?): boolean
	return env ~= nil and env.GuiService.MenuIsOpen == true
end

local function guiInset(env: { GuiService: any }?): (number, number)
	if env ~= nil then
		local ok, inset = pcall(env.GuiService.GetGuiInset, env.GuiService)
		if ok and inset ~= nil then
			return inset.X, inset.Y
		end
	end
	return 0, 0
end

--[[
Whether the point `(x, y)` lies within `object`'s absolute bounds (inclusive, ignoring rotation).
Coordinates are inset-relative, matching `InputObject.Position` and `AbsolutePosition`.

[Open Documentation](https://flux.kohl.gg/guide/utilities/interact#pointin)
]]
local function pointIn(x: number, y: number, object: GuiObject): boolean
	local position, size = object.AbsolutePosition, object.AbsoluteSize
	return x >= position.X and x <= position.X + size.X and y >= position.Y and y <= position.Y + size.Y
end

local memoToken: any = nil
local memoRoot: Instance? = nil
local memoX, memoY = 0, 0
local memoList: { GuiObject } = {}
local memoClearScheduled = false

local function clearMemo()
	memoClearScheduled = false
	memoToken, memoRoot, memoList = nil, nil, {}
end

local function scheduleClearMemo()
	if not memoClearScheduled then
		memoClearScheduled = true
		Compat.task.defer(clearMemo)
	end
end

local function guisAt(root: any, x: number, y: number): { GuiObject }?
	local ok, list = pcall(root.GetGuiObjectsAtPosition, root, x, y)
	return if ok then list else nil
end

local function isClass(root: any, className: string): boolean
	local ok, res = pcall(root.IsA, root, className)
	return ok and res == true
end

local function findAncestor(object: any, className: string): any
	return object:FindFirstAncestorWhichIsA(className)
end

local function getProp(object: any, prop: string): any
	return object[prop]
end

local function readProp(object: any, prop: string): (boolean, any)
	return pcall(getProp, object, prop)
end

local function connectSignal(object: any, signalName: string, handler: (...any) -> ()): RBXScriptConnection?
	local sig = object[signalName]
	return if sig ~= nil then sig:Connect(handler) else nil
end

local function tryConnect(object: any, signalName: string, handler: (...any) -> ()): RBXScriptConnection?
	local ok, conn = pcall(connectSignal, object, signalName, handler)
	return if ok then conn else nil
end

local function connectProperty(object: any, prop: string, handler: () -> ()): RBXScriptConnection
	return object:GetPropertyChangedSignal(prop):Connect(handler)
end

local function tryConnectProperty(object: any, prop: string, handler: () -> ()): RBXScriptConnection?
	local ok, conn = pcall(connectProperty, object, prop, handler)
	return if ok then conn else nil
end

local function is3DCollector(root: any): boolean
	return isClass(root, "BillboardGui") or isClass(root, "SurfaceGuiBase")
end

local function isPluginGui(root: any): boolean
	return isClass(root, "PluginGui")
end

local function pluginGuiOf(object: any): any
	if object == nil then
		return nil
	elseif isPluginGui(object) then
		return object
	end
	local ok, ancestor = pcall(findAncestor, object, "PluginGui")
	return if ok and ancestor ~= nil and isPluginGui(ancestor) then ancestor else nil
end

local function inPluginGui(object: any): boolean
	return pluginGuiOf(object) ~= nil
end

local function menuBlocks(env: { GuiService: any }?, object: any): boolean
	return menuOpen(env) and not inPluginGui(object)
end

local function find3DCollector(object: any): any
	local ok, collector = pcall(findAncestor, object, "LayerCollector")
	if ok and collector ~= nil and is3DCollector(collector) then
		return collector
	end
	return nil
end

local function is3DVisible(object: any, collector: any): boolean
	if collector == nil then
		return false
	end
	local okEnabled, enabled = readProp(collector, "Enabled")
	if okEnabled and enabled == false then
		return false
	end
	local cur = object
	while cur ~= nil and cur ~= collector do
		if isClass(cur, "GuiObject") then
			local okVis, vis = readProp(cur, "Visible")
			if okVis and vis == false then
				return false
			end
		end
		local okParent, parent = readProp(cur, "Parent")
		if not okParent then
			break
		end
		cur = parent
	end
	return true
end

local function hitRoot(object: GuiObject): Instance?
	local collector = object:FindFirstAncestorWhichIsA("LayerCollector")
	if collector ~= nil and is3DCollector(collector) then
		return nil
	end
	return object:FindFirstAncestorWhichIsA("BasePlayerGui") or collector
end

local function rootCursor(tracker: Tracker, root: any): (number?, number?)
	if isPluginGui(root) then
		local ok, at = pcall(root.GetRelativeMousePosition, root)
		if ok and at ~= nil then
			return at.X, at.Y
		end
		return nil, nil
	end
	return tracker.x, tracker.y
end

local function hits(root: Instance, x: number, y: number, token: any?): { GuiObject }?
	if token ~= nil and token == memoToken and root == memoRoot and x == memoX and y == memoY then
		return memoList
	end
	local list = guisAt(root, x, y)
	if list ~= nil and token ~= nil then
		memoToken, memoRoot, memoX, memoY, memoList = token, root, x, y, list
		scheduleClearMemo()
	end
	return list
end

local function claims(gui: GuiObject, object: GuiObject, within: boolean): boolean
	return (gui.Active or gui.InputSink.Value ~= 0) and not (within and gui:IsDescendantOf(object))
end

local function scan(list: { GuiObject }, object: GuiObject, within: boolean): (boolean, boolean)
	local claimed = false
	for _, gui in list do
		if gui == object then
			return true, claimed
		elseif not claimed and claims(gui, object, within) then
			claimed = true
		end
	end
	return false, claimed
end

local function claimedAt(
	env: { GuiService: any }?,
	x: number,
	y: number,
	object: GuiObject,
	token: any?,
	within: boolean
): boolean
	if menuBlocks(env, object) then
		return true
	end
	local root = hitRoot(object)
	if root == nil then
		return false
	end
	local list = hits(root, x, y, token)
	if list == nil then
		return false
	end
	local _, claimed = scan(list, object, within)
	return claimed
end

--[[
Returns `true` when input at `(x, y)` would be claimed by an `Active` or input-sinking GUI rendered above `object` (or while the Roblox escape menu is open).
Pass the `InputObject` as `token` to share the hit-test query across multiple controls on the same input event.

[Open Documentation](https://flux.kohl.gg/guide/utilities/interact#sunk)
]]
local function sunk(x: number, y: number, object: GuiObject, token: any?): boolean
	return claimedAt(engineServices(), x, y, object, token, false)
end

--[[
Returns `true` when input at `(x, y)` would be claimed by an `Active` or input-sinking GUI above `object` that is not a descendant of `object`.

[Open Documentation](https://flux.kohl.gg/guide/utilities/interact#covered)
]]
local function covered(x: number, y: number, object: GuiObject, token: any?): boolean
	return claimedAt(engineServices(), x, y, object, token, true)
end

--- @ignore
type Listener = {
	count: number,
	connections: { RBXScriptConnection }?,
	open: () -> { RBXScriptConnection },
	last: any?,
}

local function retain(listener: Listener)
	listener.count += 1
	if listener.count == 1 and listener.connections == nil then
		listener.connections = listener.open()
	end
end

local function release(listener: Listener)
	listener.count -= 1
	local connections = listener.connections
	if listener.count == 0 and connections ~= nil then
		listener.connections = nil
		listener.last = nil
		memoToken, memoRoot, memoList = nil, nil, {}
		dispose(connections)
	end
end

--- @ignore
type Handler = (any) -> ()
--- @ignore
type Hub = Listener & {
	handlers: { [Instance]: { [Handler]: true } },
	last: Instance?,
}

--- @ignore
type Entry = {
	object: GuiObject,
	state: Graph.Node<boolean>,
	within: boolean,
	root: Instance?,
	inWorld3d: boolean?,
	touch: InputObject?,
}

--- @ignore
type Tracker = Listener & {
	env: HoverServices,
	inside: { [Entry]: true },
	world3d: { [Entry]: true },
	touched: { [Entry]: true },
	pluginFocus: { [any]: { count: number, conn: RBXScriptConnection } }?,
	x: number?,
	y: number?,
}

--- @ignore
type Registry = { activate: Hub, selected: Hub, hover: Tracker }

local registries: { [any]: Registry } = setmetatable({}, { __mode = "k" })

local function dispatch(hub: Hub, object: Instance?, value: any)
	local set = if object ~= nil then hub.handlers[object] else nil
	if set == nil then
		return
	end
	for handler in set do
		handler(value)
	end
end

local function hubAdd(hub: Hub, object: Instance, handler: Handler)
	local set = hub.handlers[object]
	if set == nil then
		set = {}
		hub.handlers[object] = set
	end
	if not set[handler] then
		set[handler] = true
		retain(hub)
	end
end

local function hubRemove(hub: Hub, object: Instance, handler: Handler)
	local set = hub.handlers[object]
	if set == nil or not set[handler] then
		return
	end
	set[handler] = nil
	if next(set) == nil then
		hub.handlers[object] = nil
	end
	release(hub)
end

local function leavesMouse(kind: any): boolean
	if kind == nil then
		return false
	elseif TOUCH ~= nil and kind == TOUCH then
		return true
	elseif type(kind) ~= "userdata" and type(kind) ~= "table" then
		return false
	end
	local name = kind.Name
	return type(name) == "string" and string.sub(name, 1, 7) == "Gamepad"
end

local function settleTouch(tracker: Tracker, entry: Entry)
	if entry.touch ~= nil then
		entry.touch = nil
		tracker.touched[entry] = nil
		release(tracker)
	end
	if entry.root == nil and not entry.inWorld3d then
		entry.state:set(false)
	end
	memoToken, memoRoot, memoList = nil, nil, {}
end

local leave: (tracker: Tracker, entry: Entry) -> ()

local function leave3D(tracker: Tracker, entry: Entry)
	if entry.inWorld3d then
		entry.inWorld3d = nil
		tracker.world3d[entry] = nil
		release(tracker)
	end
	if entry.touch == nil and entry.root == nil then
		entry.state:set(false)
	end
end

local function enter3D(tracker: Tracker, entry: Entry)
	if not entry.inWorld3d then
		entry.inWorld3d = true
		tracker.world3d[entry] = true
		retain(tracker)
	end
end

local function releaseRoot(tracker: Tracker, root: any)
	local map = tracker.pluginFocus
	if map == nil then
		return
	end
	local record = map[root]
	if record == nil then
		return
	end
	record.count -= 1
	if record.count == 0 then
		map[root] = nil
		record.conn:Disconnect()
	end
end

local function retainRoot(tracker: Tracker, root: any)
	if not isPluginGui(root) then
		return
	end
	local existing = tracker.pluginFocus
	local map: { [any]: { count: number, conn: RBXScriptConnection } }
	if existing ~= nil then
		map = existing
	else
		map = {}
		tracker.pluginFocus = map
	end
	local record = map[root]
	if record ~= nil then
		record.count += 1
		return
	end
	local ok, conn = pcall(function(): any
		local sig = root.WindowFocusReleased
		if sig == nil then
			return nil
		end
		return sig:Connect(function()
			for entry in table.clone(tracker.inside) do
				if entry.root == root then
					leave(tracker, entry)
				end
			end
			if memoRoot == root then
				memoToken, memoRoot, memoList = nil, nil, {}
			end
		end)
	end)
	if ok and conn ~= nil then
		map[root] = { count = 1, conn = conn :: RBXScriptConnection }
	end
end

local function attachRoot(tracker: Tracker, entry: Entry, root: Instance)
	local prevRoot = entry.root
	if prevRoot == root then
		return
	end
	entry.root = root
	retainRoot(tracker, root)
	if prevRoot == nil then
		tracker.inside[entry] = true
		retain(tracker)
	else
		releaseRoot(tracker, prevRoot)
		if prevRoot == memoRoot then
			memoToken, memoRoot, memoList = nil, nil, {}
		end
	end
end

leave = function(tracker: Tracker, entry: Entry)
	local prevRoot = entry.root
	if prevRoot ~= nil then
		if prevRoot == memoRoot then
			memoToken, memoRoot, memoList = nil, nil, {}
		end
		entry.root = nil
		tracker.inside[entry] = nil
		releaseRoot(tracker, prevRoot)
		release(tracker)
	end
	if entry.touch == nil and not entry.inWorld3d then
		entry.state:set(false)
	end
end

local function stepTracker(tracker: Tracker)
	clearMemo()
	local open = menuOpen(tracker.env)
	if open then
		for entry in table.clone(tracker.touched) do
			if not inPluginGui(entry.object) then
				settleTouch(tracker, entry)
			end
		end
		for entry in table.clone(tracker.world3d) do
			if not inPluginGui(entry.object) then
				leave3D(tracker, entry)
			end
		end
	else
		for entry in table.clone(tracker.world3d) do
			local collector = find3DCollector(entry.object)
			if not is3DVisible(entry.object, collector) then
				leave3D(tracker, entry)
			end
		end
	end
	local lastRoot: any, lastList: { GuiObject }? = nil, nil
	for entry in table.clone(tracker.inside) do
		local prevRoot: any = entry.root
		if prevRoot == nil then
			continue
		end
		local root: any = hitRoot(entry.object)
		if root == nil then
			leave(tracker, entry)
			continue
		end
		attachRoot(tracker, entry, root)
		if open and not isPluginGui(root) then
			entry.state:set(false)
			continue
		end
		if root ~= lastRoot then
			lastRoot = root
			local rx, ry = rootCursor(tracker, root)
			lastList = if rx ~= nil then guisAt(root, rx, ry :: number) else nil
		end
		if lastList == nil then
			if entry.touch == nil and not entry.inWorld3d then
				entry.state:set(false)
			end
			continue
		end
		local found, claimed = scan(lastList, entry.object, entry.within)
		if not found then
			leave(tracker, entry)
		elseif entry.touch == nil then
			entry.state:set(not claimed)
		end
	end
end

local function connectTracker(tracker: Tracker): { RBXScriptConnection }
	local env = tracker.env
	tracker.x, tracker.y = nil, nil
	local input = env.UserInputService
	local function clearViewportMouse()
		for entry in table.clone(tracker.inside) do
			if not isPluginGui(entry.root) then
				leave(tracker, entry)
			end
		end
		for entry in table.clone(tracker.world3d) do
			leave3D(tracker, entry)
		end
		clearMemo()
	end
	local function clearAllMouse()
		clearViewportMouse()
		for entry in table.clone(tracker.inside) do
			leave(tracker, entry)
		end
	end
	local onHeartbeat = env.RunService.Heartbeat:Connect(function()
		stepTracker(tracker)
	end)
	local onChanged = input.InputChanged:Connect(function(changed: InputObject)
		if changed.UserInputType == MOUSE_MOVEMENT then
			tracker.x, tracker.y = changed.Position.X, changed.Position.Y
		end
	end)
	local onEnded = input.InputEnded:Connect(function(ended: InputObject)
		if ended.UserInputType == TOUCH then
			for entry in table.clone(tracker.touched) do
				if entry.touch == ended then
					settleTouch(tracker, entry)
				end
			end
		end
	end)
	local onLastInput = input.LastInputTypeChanged:Connect(function(kind: any)
		if leavesMouse(kind) then
			clearAllMouse()
		end
	end)
	local onFocusReleased = input.WindowFocusReleased:Connect(clearViewportMouse)
	return { onHeartbeat, onChanged, onEnded, onLastInput, onFocusReleased }
end

local function registryFor(env: any): Registry
	local registry = registries[env]
	if registry ~= nil then
		return registry
	end

	local activate: any = { handlers = {}, count = 0 }
	activate.open = function(): { RBXScriptConnection }
		local userInput = env.UserInputService
		local onInputBegan = userInput.InputBegan:Connect(function(input: InputObject)
			if ACTIVATE_KEYS[input.KeyCode] and userInput:GetFocusedTextBox() == nil then
				local target = env.GuiService.SelectedObject
				if target ~= nil and not menuBlocks(env, target) then
					dispatch(activate, target, input)
				end
			end
		end)
		return { onInputBegan }
	end

	local selected: any = { handlers = {}, count = 0 }
	selected.open = function(): { RBXScriptConnection }
		local guiService = env.GuiService
		selected.last = guiService.SelectedObject
		local onSelectedChanged = guiService:GetPropertyChangedSignal("SelectedObject"):Connect(function()
			local now = guiService.SelectedObject
			local last = selected.last
			if now ~= last then
				selected.last = now
				dispatch(selected, last, false)
				dispatch(selected, now, true)
			end
		end)
		return { onSelectedChanged }
	end

	local tracker: any = { env = env, inside = {}, world3d = {}, touched = {}, count = 0 }
	tracker.open = function(): { RBXScriptConnection }
		local connected = connectTracker(tracker)
		return connected
	end

	registry = { activate = activate, selected = selected, hover = tracker }
	registries[env] = registry
	return registry
end

local function expose(state: Graph.Node<boolean>, object: Instance, onRelease: () -> ()): Graph.Node<boolean>
	local settled = false
	local destroying: RBXScriptConnection? = nil
	local function settle()
		if settled then
			return
		end
		settled = true
		if destroying ~= nil then
			destroying:Disconnect()
			destroying = nil
		end
		onRelease()
	end
	destroying = object.Destroying:Connect(settle)
	state:onDestroy(settle)
	if Graph.getOwner() then
		Graph.cleanup(settle)
	end
	return state
end

local function enter(tracker: Tracker, entry: Entry, x: number?, y: number?)
	local root = hitRoot(entry.object)
	if root == nil then
		if entry.root ~= nil then
			leave(tracker, entry)
		end
		local collector = find3DCollector(entry.object)
		if is3DVisible(entry.object, collector) and not menuBlocks(tracker.env, entry.object) then
			enter3D(tracker, entry)
		elseif entry.inWorld3d then
			leave3D(tracker, entry)
		end
		return
	end
	if entry.inWorld3d then
		leave3D(tracker, entry)
	end
	attachRoot(tracker, entry, root)
	if isPluginGui(root) then
		return
	end
	if x ~= nil then
		tracker.x, tracker.y = x, y
	elseif tracker.x == nil then
		local env = tracker.env
		local ok, at = pcall(env.UserInputService.GetMouseLocation, env.UserInputService)
		if ok and at ~= nil then
			local ix, iy = guiInset(env)
			tracker.x, tracker.y = at.X - ix, at.Y - iy
		end
	end
end

local function _hoverWith(object: GuiObject, env: HoverServices?, options: HoverOptions?): Graph.Node<boolean>
	local within = options ~= nil and options.within == true
	local hovering = signal(false)
	local events: any = if env ~= nil and env.events ~= nil then env.events(object) else object
	local entry: Entry = { object = object, state = hovering, within = within }
	local tracker = if env ~= nil then registryFor(env).hover else nil

	local function track(input: InputObject)
		local kind = input.UserInputType
		if kind ~= MOUSE_MOVEMENT and kind ~= TOUCH then
			return
		end
		if kind == TOUCH and entry.touch ~= nil and entry.touch ~= input then
			return
		end
		local pos = input.Position
		local on = not menuBlocks(env, object) and not claimedAt(env, pos.X, pos.Y, object, input, within)
		hovering:set(on)
		if kind == MOUSE_MOVEMENT then
			if tracker ~= nil then
				enter(tracker, entry, pos.X, pos.Y)
			end
		elseif tracker ~= nil then
			if on and entry.touch == nil then
				entry.touch = input
				tracker.touched[entry] = true
				retain(tracker)
			elseif not on and entry.touch ~= nil then
				settleTouch(tracker, entry)
			end
		end
	end

	local onBegan: RBXScriptConnection = events.InputBegan:Connect(track)
	local onChanged: RBXScriptConnection = events.InputChanged:Connect(track)
	local onEnded: RBXScriptConnection = events.InputEnded:Connect(function(input: InputObject)
		local kind = input.UserInputType
		if kind == MOUSE_MOVEMENT then
			if tracker ~= nil then
				leave(tracker, entry)
				leave3D(tracker, entry)
			else
				hovering:set(false)
			end
		elseif kind == TOUCH then
			if entry.touch ~= nil and entry.touch ~= input then
				return
			end
			if tracker ~= nil and entry.touch ~= nil then
				settleTouch(tracker, entry)
			end
			hovering:set(false)
		end
	end)
	local connections: { RBXScriptConnection } = { onBegan, onChanged, onEnded }
	local mouseEnter: any = events.MouseEnter
	local mouseLeave: any = events.MouseLeave
	if tracker ~= nil and mouseEnter ~= nil then
		local tracking: Tracker = tracker
		local onEnter: RBXScriptConnection = mouseEnter:Connect(function(mx: number?, my: number?)
			if not leavesMouse(tracking.env.UserInputService:GetLastInputType()) then
				if mx ~= nil and my ~= nil and find3DCollector(entry.object) == nil then
					local ix, iy = guiInset(tracking.env)
					enter(tracking, entry, mx - ix, my - iy)
				else
					enter(tracking, entry)
				end
			end
		end)
		local onLeave: RBXScriptConnection = mouseLeave:Connect(function()
			leave(tracking, entry)
			leave3D(tracking, entry)
		end)
		table.insert(connections, onEnter)
		table.insert(connections, onLeave)
	end

	return expose(hovering, object, function()
		dispose(connections)
		table.clear(connections)
		if tracker ~= nil then
			if entry.touch ~= nil then
				settleTouch(tracker, entry)
			end
			leave(tracker, entry)
			leave3D(tracker, entry)
		end
		hovering:set(false)
	end)
end

local hoverOverride: HoverServices? = nil

--[[
Returns a read-only boolean [node](https://flux.kohl.gg/guide/concepts/signals) that is `true` while a pointer or touch contact is inside `object` with no input-claiming GUI above it.
Pass `{ within = true }` on containers so child controls inside `object` do not count as covering it.

[Open Documentation](https://flux.kohl.gg/guide/utilities/interact#hover)
]]
local function hover(object: GuiObject, options: HoverOptions?): Graph.Node<boolean>
	return _hoverWith(object, hoverOverride or engineServices(), options)
end

local function useHoverServices(env: HoverServices?): HoverServices?
	local previous = hoverOverride
	hoverOverride = env
	return previous
end

local function _pressWith(object: GuiObject, env: Services?): Graph.Node<boolean>
	local pressed = signal(false)
	local held: InputObject? = nil
	local releaseListener: RBXScriptConnection? = nil
	local objectReleaseListener: RBXScriptConnection? = nil
	local focusListener: RBXScriptConnection? = nil
	local pluginFocusListener: RBXScriptConnection? = nil
	local stateListener: RBXScriptConnection? = nil
	local menuListener: RBXScriptConnection? = nil

	local function disconnectOne(conn: RBXScriptConnection?): nil
		if conn ~= nil then
			conn:Disconnect()
		end
		return nil
	end

	local function releasePress()
		held = nil
		menuListener = disconnectOne(menuListener)
		releaseListener = disconnectOne(releaseListener)
		objectReleaseListener = disconnectOne(objectReleaseListener)
		focusListener = disconnectOne(focusListener)
		pluginFocusListener = disconnectOne(pluginFocusListener)
		stateListener = disconnectOne(stateListener)
		pressed:set(false)
	end

	local function isHeld(input: InputObject): boolean
		local current = held
		if current == nil then
			return false
		elseif input == current then
			return true
		end
		local kind = current.UserInputType
		return kind ~= TOUCH and input.UserInputType == kind and input.KeyCode == current.KeyCode
	end

	local function hold(input: InputObject)
		if held ~= nil or menuBlocks(env, object) then
			return
		end
		held = input
		pressed:set(true)
		local pluginRoot = pluginGuiOf(object)
		local isPlugin = pluginRoot ~= nil
		if env ~= nil then
			local services: Services = env
			if not isPlugin then
				menuListener = services.GuiService:GetPropertyChangedSignal("MenuIsOpen"):Connect(function()
					if menuBlocks(services, object) then
						releasePress()
					end
				end)
			end
			releaseListener = services.UserInputService.InputEnded:Connect(function(ended: InputObject)
				if isHeld(ended) then
					releasePress()
				end
			end)
			focusListener = tryConnect(services.UserInputService, "WindowFocusReleased", releasePress)
		end
		if env == nil or isPlugin then
			objectReleaseListener = object.InputEnded:Connect(function(ended: InputObject)
				if isHeld(ended) then
					releasePress()
				end
			end)
		end
		if pluginRoot ~= nil then
			pluginFocusListener = tryConnect(pluginRoot, "WindowFocusReleased", releasePress)
		end
		stateListener = tryConnectProperty(input, "UserInputState", function()
			local state = input.UserInputState
			if state == STATE_END or state == STATE_CANCEL then
				releasePress()
			end
		end)
	end

	local pointer = object.InputBegan:Connect(function(input: InputObject)
		local kind = input.UserInputType
		if kind == MOUSE_BUTTON1 or kind == TOUCH then
			local position = input.Position
			if not claimedAt(env, position.X, position.Y, object, input, false) then
				hold(input)
			end
		end
	end)
	local hub = if env ~= nil then registryFor(env).activate else nil
	local holdHandler: any = hold
	if hub ~= nil then
		hubAdd(hub, object, holdHandler)
	end

	return expose(pressed, object, function()
		pointer:Disconnect()
		if hub ~= nil then
			hubRemove(hub, object, holdHandler)
		end
		releasePress()
	end)
end

--[[
Returns a read-only boolean [node](https://flux.kohl.gg/guide/concepts/signals) that is `true` while `object` is held down by pointer, touch, or gamepad/keyboard activation (`ButtonA`/`Enter`).
Stays `true` until that input ends anywhere on screen.

[Open Documentation](https://flux.kohl.gg/guide/utilities/interact#press)
]]
local function press(object: GuiObject): Graph.Node<boolean>
	return _pressWith(object, engineServices())
end

local function _selectedWith(object: GuiObject, env: Services?): Graph.Node<boolean>
	if env == nil then
		return expose(signal(false), object, function() end)
	end
	local guiService = env.GuiService
	local isSelected = signal(guiService.SelectedObject == object)
	local hub = registryFor(env).selected
	local function follow(on: any)
		isSelected:set(on == true)
	end
	hubAdd(hub, object, follow)

	return expose(isSelected, object, function()
		hubRemove(hub, object, follow)
		isSelected:set(false)
	end)
end

--[[
Returns a read-only boolean [node](https://flux.kohl.gg/guide/concepts/signals) tracking whether `object` is currently [`GuiService.SelectedObject`](https://create.roblox.com/docs/reference/engine/classes/GuiService#SelectedObject).

[Open Documentation](https://flux.kohl.gg/guide/utilities/interact#selected)
]]
local function selected(object: GuiObject): Graph.Node<boolean>
	return _selectedWith(object, engineServices())
end

--[[
Returns a read-only boolean [node](https://flux.kohl.gg/guide/concepts/signals) tracking whether `textBox` currently has keyboard focus.

[Open Documentation](https://flux.kohl.gg/guide/utilities/interact#focused)
]]
local function focused(textBox: TextBox): Graph.Node<boolean>
	local isFocused = signal(textBox:IsFocused())
	local onFocused = textBox.Focused:Connect(function()
		isFocused:set(true)
	end)
	local onFocusLost = textBox.FocusLost:Connect(function()
		isFocused:set(false)
	end)
	local connections = { onFocused, onFocusLost }

	return expose(isFocused, textBox, function()
		dispose(connections)
		isFocused:set(false)
	end)
end

return table.freeze({
	pointIn = pointIn,
	sunk = sunk,
	covered = covered,

	hover = hover,
	press = press,
	selected = selected,
	focused = focused,

	--- @ignore
	_hoverWith = _hoverWith,
	--- @ignore
	_useHoverServices = useHoverServices,
	--- @ignore
	_pressWith = _pressWith,
	--- @ignore
	_selectedWith = _selectedWith,
})
