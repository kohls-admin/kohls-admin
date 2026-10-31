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

local MOUSE_MOVEMENT = Enum.UserInputType.MouseMovement
local MOUSE_BUTTON1 = Enum.UserInputType.MouseButton1
local TOUCH = Enum.UserInputType.Touch
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

local function guisAt(root: BasePlayerGui, x: number, y: number): { GuiObject }?
	local ok, list = pcall(root.GetGuiObjectsAtPosition, root, x, y)
	return if ok then list else nil
end

local function hits(root: BasePlayerGui, x: number, y: number, token: any?): { GuiObject }?
	if token ~= nil and token == memoToken and root == memoRoot and x == memoX and y == memoY then
		return memoList
	end
	local list = guisAt(root, x, y)
	if list ~= nil and token ~= nil then
		memoToken, memoRoot, memoX, memoY, memoList = token, root, x, y, list
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
	local root = object:FindFirstAncestorWhichIsA("BasePlayerGui")
	if root == nil then
		return false
	elseif menuOpen(env) then
		return true
	end
	local list = hits(root, x, y, token)
	if list == nil then
		return false
	end
	local _, claimed = scan(list, object, within)
	return claimed
end

--[[
Whether input at `(x, y)` would be claimed by an `Active` or input-sinking gui rendered
<strong>above</strong> `object`, e.g. dropping a hover state while a floating menu covers the
control. Outside a `BasePlayerGui` (a plugin dock, a `SurfaceGui` in workspace) nothing can claim
the point, so this yields `false`. With `token` (the InputObject), the hit test is asked once per
input per point, however many objects under the pointer ask.

[Open Documentation](https://flux.kohl.gg/guide/utilities/interact#sunk)
]]
local function sunk(x: number, y: number, object: GuiObject, token: any?): boolean
	return claimedAt(engineServices(), x, y, object, token, false)
end

--[[
Whether input at `(x, y)` would be claimed by an `Active` or input-sinking gui above `object` that is <strong>not
inside it</strong>: another panel, window or menu on top. Unlike [`sunk`](https://flux.kohl.gg/guide/utilities/interact#sunk),
the object's own buttons don't count, so a container (a scrolling list, a row list you drag to reorder, a window's
body) still hears a press on its rows while nothing else covers it.

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
	touch: InputObject?,
}

--- @ignore
type Tracker = Listener & {
	env: HoverServices,
	inside: { [Entry]: true },
	touched: { [Entry]: true },
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
	return kind == TOUCH or string.sub(kind.Name, 1, 7) == "Gamepad"
end

local function settleTouch(tracker: Tracker, entry: Entry)
	if entry.touch ~= nil then
		entry.touch = nil
		tracker.touched[entry] = nil
		release(tracker)
	end
	if entry.root == nil then
		entry.state:set(false)
	end
	memoToken, memoRoot, memoList = nil, nil, {}
end

local function leave(tracker: Tracker, entry: Entry)
	if entry.root ~= nil then
		if entry.root == memoRoot then
			memoToken, memoRoot, memoList = nil, nil, {}
		end
		entry.root = nil
		tracker.inside[entry] = nil
		release(tracker)
	end
	if entry.touch == nil then
		entry.state:set(false)
	end
end

local function step(tracker: Tracker)
	if menuOpen(tracker.env) then
		for entry in tracker.inside do
			entry.state:set(false)
		end
		for entry in tracker.touched do
			settleTouch(tracker, entry)
		end
		return
	end
	local x, y = tracker.x, tracker.y
	if x == nil or y == nil then
		return
	end
	local lastRoot: any, lastList: { GuiObject } = nil, {}
	for entry in tracker.inside do
		local root: any = entry.root
		if root ~= lastRoot then
			local list = guisAt(root, x, y)
			if list == nil then
				continue
			end
			lastRoot, lastList = root, list
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
	local function clearMouse()
		for entry in tracker.inside do
			leave(tracker, entry)
		end
		memoToken, memoRoot, memoList = nil, nil, {}
	end
	local onHeartbeat = env.RunService.Heartbeat:Connect(function()
		step(tracker)
	end)
	local onChanged = input.InputChanged:Connect(function(changed: InputObject)
		if changed.UserInputType == MOUSE_MOVEMENT then
			tracker.x, tracker.y = changed.Position.X, changed.Position.Y
		end
	end)
	local onEnded = input.InputEnded:Connect(function(ended: InputObject)
		if ended.UserInputType == TOUCH then
			for entry in tracker.touched do
				if entry.touch == ended then
					settleTouch(tracker, entry)
				end
			end
		end
	end)
	local onLastInput = input.LastInputTypeChanged:Connect(function(kind: any)
		if leavesMouse(kind) then
			clearMouse()
		end
	end)
	local onFocusReleased = input.WindowFocusReleased:Connect(clearMouse)
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
			if ACTIVATE_KEYS[input.KeyCode] and userInput:GetFocusedTextBox() == nil and not menuOpen(env) then
				dispatch(activate, env.GuiService.SelectedObject, input)
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

	local tracker: any = { env = env, inside = {}, touched = {}, count = 0 }
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
	if entry.root == nil then
		local root = entry.object:FindFirstAncestorWhichIsA("BasePlayerGui")
		if root == nil then
			return
		end
		entry.root = root
		tracker.inside[entry] = true
		retain(tracker)
	end
	if x ~= nil then
		tracker.x, tracker.y = x, y
	elseif tracker.x == nil then
		local env = tracker.env
		local ok, at = pcall(function(): Vector2
			return env.UserInputService:GetMouseLocation() - env.GuiService:GetGuiInset()
		end)
		if ok then
			tracker.x, tracker.y = at.X, at.Y
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
		local on = not menuOpen(env) and not claimedAt(env, pos.X, pos.Y, object, input, within)
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
		local onEnter: RBXScriptConnection = mouseEnter:Connect(function()
			if not leavesMouse(tracking.env.UserInputService:GetLastInputType()) then
				enter(tracking, entry)
			end
		end)
		local onLeave: RBXScriptConnection = mouseLeave:Connect(function()
			leave(tracking, entry)
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
		end
		hovering:set(false)
	end)
end

local hoverOverride: HoverServices? = nil

--[[
Whether a mouse pointer or touch contact is over `object` with no input-claiming gui drawn
<strong>above</strong> it (see [`sunk`](https://flux.kohl.gg/guide/utilities/interact#sunk)), as a read-only boolean
[node](https://flux.kohl.gg/guide/concepts/signals). It is settled again every frame the pointer is in its bounds, so
a menu or dialog opening over it, the pointer moving onto one, a scroll that carries it away, or it hiding drops the
hover, and the cover closing over a still pointer brings it back. With `{ within = true }`, only guis outside
`object` cover it (see [`covered`](https://flux.kohl.gg/guide/utilities/interact#covered)): a row or card stays
hovered over its own buttons. Listening starts on call and stops when the node, the
[scope](https://flux.kohl.gg/guide/concepts/scopes) that created it, or `object` is destroyed, which settles it `false`.

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
	local menuListener: RBXScriptConnection? = nil

	local function releasePress()
		held = nil
		if menuListener ~= nil then
			menuListener:Disconnect()
			menuListener = nil
		end
		local listener = releaseListener
		if listener ~= nil then
			releaseListener = nil
			listener:Disconnect()
		end
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
		if held ~= nil or menuOpen(env) then
			return
		end
		held = input
		pressed:set(true)
		if env ~= nil then
			menuListener = env.GuiService:GetPropertyChangedSignal("MenuIsOpen"):Connect(function()
				if menuOpen(env) then
					releasePress()
				end
			end)
			releaseListener = env.UserInputService.InputEnded:Connect(function(ended: InputObject)
				if isHeld(ended) then
					releasePress()
				end
			end)
		else
			releaseListener = object.InputEnded:Connect(function(ended: InputObject)
				if isHeld(ended) then
					releasePress()
				end
			end)
		end
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
Whether `object` is held down, as a read-only boolean [node](https://flux.kohl.gg/guide/concepts/signals): from a
left mouse button or touch that begins on it (unless a gui above claims the input), or `ButtonA`/`Enter` pressed while
it is the [`GuiService.SelectedObject`](https://create.roblox.com/docs/reference/engine/classes/GuiService#SelectedObject)
and no text box has focus, until that same input ends <em>anywhere</em>, so dragging off a control never leaves it stuck. It cleans up like
[`hover`](https://flux.kohl.gg/guide/utilities/interact#hover).

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
Whether `object` is the [`GuiService.SelectedObject`](https://create.roblox.com/docs/reference/engine/classes/GuiService#SelectedObject),
the gui that gamepad or keyboard UI navigation currently highlights, as a read-only boolean
[node](https://flux.kohl.gg/guide/concepts/signals). It cleans up like
[`hover`](https://flux.kohl.gg/guide/utilities/interact#hover).

[Open Documentation](https://flux.kohl.gg/guide/utilities/interact#selected)
]]
local function selected(object: GuiObject): Graph.Node<boolean>
	return _selectedWith(object, engineServices())
end

--[[
Whether `textBox` has keyboard focus, as a read-only boolean [node](https://flux.kohl.gg/guide/concepts/signals)
seeded from `IsFocused()` and kept current by `Focused` and `FocusLost`. It cleans up like
[`hover`](https://flux.kohl.gg/guide/utilities/interact#hover).

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
