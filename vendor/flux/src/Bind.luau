--!strict
local Compat = require("./Compat")
local Graph = require("./Graph")
local Type = require("./Type")

local compatTask = Compat.task
local compatTypeof = Compat.typeof
local warn = Compat.warn

local cleanup = Graph.cleanup
local dispose = Graph.dispose
local effect = Graph.effect
local get = Graph.Node.get
local getOwner = Graph.getOwner
local isolate = Graph.isolate
local kindOf = Graph.kindOf
local new = Graph.new
local signal = Graph.signal
local raw = Graph.raw
local read = Graph.read
local untrack = Graph.untrack
local isNode = Graph.isNode
local nodeVersion = Graph.version

local MODEL_SYMBOL: any = table.freeze({ type = "Model" })
local PORTAL_SYMBOL: any = table.freeze({ type = "Portal" })
local NO_VALUE: any = nil
local NOOP = function() end

--- @ignore
type MountedPortal = {
	spec: any,
	stop: () -> (),
}

--- @ignore
type ListenerEntry = {
	fn: ((value: any) -> ())?,
	skipVer: number?,
}

--- @ignore
type ChildrenState = {
	cleanupConnection: RBXScriptConnection?,
	eff: Graph.Node<any>?,
	list: { Instance },
	portals: { MountedPortal }?,
	nextPortals: { MountedPortal }?,
	parent: Instance?,
	order: number?,
	offset: number?,
	token: number?,
	lastEndOrder: number?,
}

--- @ignore
type OrderSlot = {
	kind: string,
	child: Instance?,
	bind: ChildrenState?,
	offset: number?,
}

--- @ignore
type BindData = {
	fn: { ListenerEntry },
	rbx: { [Instance]: { { [string]: any }? } },
	eff: Graph.Node<any>?,
	flushed: boolean,
	value: any,
	ver: number?,
	destroyCleanup: (() -> ())?,
	pin: number?,
	scratchChildren: { Instance }?,
	scratchPortals: { any }?,
	scratchIncoming: { [Instance]: true }?,
	children: ChildrenState?,
}

local bindData: { [Graph.Node<any>]: BindData } = setmetatable({}, { __mode = "k" })
local bindGeneration = 0

--- @ignore
export type Portal = Type.Portal

-- The source that currently drives each instance property or attribute (attributes keyed with a `$` prefix). An edit
-- that sets the key again, bound or static, releases the previous claim first, so the newest value wins and stays
-- instead of racing the original source whenever it changes. A claim is a list of releasers: its unbind, then anything
-- edit attached to it (the node it made from a function, a model's read-back connection).
type Claim = { (() -> ()) | Graph.Node<any> }
local claims: { [Instance]: { [string]: Claim } } = setmetatable({}, { __mode = "k" })

local function claimKey(property: string, isAttribute: boolean?): string
	return if isAttribute then "$" .. property else property
end

local function release(instance: Instance, property: string, isAttribute: boolean?)
	local owned = claims[instance]
	if owned == nil then
		return
	end
	local key = claimKey(property, isAttribute)
	local claim = owned[key]
	if claim == nil then
		return
	end
	owned[key] = nil
	if next(owned) == nil then
		claims[instance] = nil
	end
	for _, releaser in claim do
		if type(releaser) == "function" then
			releaser()
		else
			Graph.dispose(releaser)
		end
	end
end
local pinnedOrder: { [Instance]: boolean } = setmetatable({}, { __mode = "k" })
local autoOrder: { [Instance]: number } = setmetatable({}, { __mode = "k" })
local staticOrder: { [Instance]: number } = setmetatable({}, { __mode = "k" })
local parentSlots: { [Instance]: { OrderSlot } } = setmetatable({}, { __mode = "k" })

local function applyLayoutOrder(child: Instance, order: number): number
	if child:IsA("GuiObject") and not pinnedOrder[child] then
		local gui = child :: GuiObject
		local current = gui.LayoutOrder
		if current == 0 or autoOrder[child] == current then
			gui.LayoutOrder = order
			autoOrder[child] = order
			return order + 1
		end
	end
	return order
end

local function stepOrderSlot(
	parent: Instance,
	slot: OrderSlot,
	order: number,
	skipChild: Instance?,
	skipBind: ChildrenState?
): (boolean, number)
	if slot.kind == "single" then
		local child = slot.child
		if child ~= nil and child ~= skipChild and child.Parent == parent then
			return true, applyLayoutOrder(child, order)
		end
		return false, order
	end
	local bindState = slot.bind
	if bindState ~= nil and bindState ~= skipBind and bindState.parent == parent then
		local effOrder = order
		if slot.offset ~= nil and effOrder < slot.offset then
			effOrder = slot.offset
		end
		bindState.order = effOrder
		for _, child in bindState.list do
			if child.Parent == parent then
				effOrder = applyLayoutOrder(child, effOrder)
			end
		end
		bindState.lastEndOrder = effOrder
		return true, effOrder
	end
	return false, order
end

local function compactOrderSlots(
	parent: Instance,
	slots: { OrderSlot },
	startIndex: number,
	startOrder: number,
	skipChild: Instance?,
	skipBind: ChildrenState?
): number
	local writeIdx = startIndex
	local order = startOrder
	for readIdx = startIndex, #slots do
		local slot = slots[readIdx]
		local keep, nextOrder = stepOrderSlot(parent, slot, order, skipChild, skipBind)
		if keep then
			order = nextOrder
			if writeIdx ~= readIdx then
				slots[writeIdx] = slot
			end
			writeIdx += 1
		end
	end
	for i = writeIdx, #slots do
		slots[i] = nil
	end
	return order
end

local function refreshParentSlots(parent: Instance)
	local slots = parentSlots[parent]
	if slots == nil then
		return
	end
	compactOrderSlots(parent, slots, 1, (staticOrder[parent] or 0) + 1, nil, nil)
	if #slots == 0 then
		parentSlots[parent] = nil
	end
end

local function placeChildOrder(parent: Instance, child: Instance)
	if not child:IsA("GuiObject") then
		return
	end
	local slots = parentSlots[parent]
	if slots == nil then
		local nextOrder = (staticOrder[parent] or 0) + 1
		if applyLayoutOrder(child, nextOrder) > nextOrder then
			staticOrder[parent] = nextOrder
		end
		return
	end
	local order = compactOrderSlots(parent, slots, 1, (staticOrder[parent] or 0) + 1, child, nil)
	applyLayoutOrder(child, order)
	table.insert(slots, { kind = "single", child = child })
end

local function attachChildrenSlot(parent: Instance, bindState: ChildrenState, offset: number?): number
	local slots = parentSlots[parent]
	if slots == nil then
		slots = {}
		parentSlots[parent] = slots
	end
	local order = compactOrderSlots(parent, slots, 1, (staticOrder[parent] or 0) + 1, nil, bindState)
	if offset ~= nil and order < offset then
		order = offset
	end
	table.insert(slots, { kind = "children", bind = bindState, offset = offset })
	return order
end

local function removeChildrenSlot(parent: Instance?, bindState: ChildrenState)
	if parent == nil then
		return
	end
	local slots = parentSlots[parent]
	if slots == nil then
		return
	end
	for i = 1, #slots do
		if slots[i].bind == bindState then
			table.remove(slots, i)
			refreshParentSlots(parent)
			return
		end
	end
end

local function refreshAfterChildrenSlot(parent: Instance, bindState: ChildrenState, endOrder: number)
	local slots = parentSlots[parent]
	if slots == nil then
		return
	end
	for i = 1, #slots do
		if slots[i].bind == bindState then
			for prefixIdx = 1, i - 1 do
				local pre = slots[prefixIdx]
				local alive = if pre.kind == "single"
					then pre.child ~= nil and pre.child.Parent == parent
					else pre.bind ~= nil and pre.bind.parent == parent
				if not alive then
					refreshParentSlots(parent)
					return
				end
			end
			if slots[i + 1] ~= nil then
				compactOrderSlots(parent, slots, i + 1, endOrder, nil, nil)
			end
			return
		end
	end
end

local function isInstance(value: any): boolean
	return kindOf(value) == "Instance"
end

local function isPortal(value: unknown): boolean
	local rawValue: any = value
	return type(value) == "table" and rawget(rawValue, 1) == PORTAL_SYMBOL
end

local mountPortal: (portal: any) -> () -> ()

local function stopPortals(portals: { () -> () }?)
	if portals == nil then
		return
	end
	for _, stop in portals do
		stop()
	end
	table.clear(portals)
end

local function stopMountedPortals(portals: { MountedPortal }?)
	if portals == nil then
		return
	end
	for _, entry in portals do
		entry.stop()
	end
	table.clear(portals)
end

local function collectChildren(value: any, into: { Instance }, portals: { any }): { Instance }
	if isInstance(value) then
		table.insert(into, value)
	elseif isNode(value) then
		collectChildren(get(value), into, portals)
	elseif isPortal(value) then
		table.insert(portals, value)
	elseif type(value) == "table" then
		for _, child in value do
			collectChildren(child, into, portals)
		end
	end
	return into
end

local function syncPortals(data: any, portals: { any }, count: number)
	local oldPortals = data.portals
	if count == 0 then
		stopMountedPortals(oldPortals)
		return
	end
	local mounted = data.nextPortals
	if mounted == nil then
		mounted = {}
	else
		data.nextPortals = nil
		table.clear(mounted)
	end
	if oldPortals ~= nil and oldPortals[1] ~= nil then
		local nOld = #oldPortals
		for i = 1, count do
			local spec = portals[i]
			local matched: MountedPortal? = nil
			for j = 1, nOld do
				local oldEntry = oldPortals[j]
				if oldEntry and oldEntry.spec == spec then
					matched = oldEntry
					oldPortals[j] = false :: any
					break
				end
			end
			mounted[i] = matched or { spec = spec, stop = NOOP }
		end
		for j = 1, nOld do
			local oldEntry = oldPortals[j]
			if oldEntry then
				oldEntry.stop()
			end
		end
		table.clear(oldPortals)
	else
		for i = 1, count do
			mounted[i] = { spec = portals[i], stop = NOOP }
		end
	end
	data.portals = mounted
	if oldPortals ~= nil then
		data.nextPortals = oldPortals
	end
	for i = 1, count do
		local entry = mounted[i]
		if entry.stop == NOOP then
			entry.stop = isolate(mountPortal, entry.spec)
		end
	end
end

local function applyChildren(bind: BindData, value: any)
	local data = bind.children
	if data == nil then
		return
	end
	while isNode(value) do
		value = get(value)
	end
	local parent = data.parent
	if parent == nil then
		return
	end

	local children: { Instance }? = nil
	local portals: { any }? = nil
	local kind = 0 -- 0 = single/none, 1 = single portal, 2 = table
	if isPortal(value) then
		portals = bind.scratchPortals or {}
		bind.scratchPortals = nil
		(portals :: { any })[1] = value
		kind = 1
	elseif type(value) == "table" and not isInstance(value) then
		children = bind.scratchChildren or {}
		bind.scratchChildren = nil
		portals = bind.scratchPortals or {}
		bind.scratchPortals = nil
		collectChildren(value, children :: { Instance }, portals :: { any })
		kind = 2
	end

	local function commitDom()
		local list = data.list
		local layoutOrder = data.order or 1
		if kind == 1 then
			for _, child in list do
				if child.Parent == parent then
					child.Parent = nil
				end
			end
			table.clear(list)
			local portalList = portals :: { any }
			syncPortals(data, portalList, 1)
			table.clear(portalList)
			bind.scratchPortals = portalList
		elseif kind == 2 then
			local childList = children :: { Instance }
			local portalList = portals :: { any }
			if list[1] ~= nil then
				if childList[2] == nil then
					local first = childList[1]
					for _, child in list do
						if child.Parent == parent and child ~= first then
							child.Parent = nil
						end
					end
				else
					local incoming: { [Instance]: true } = bind.scratchIncoming or {}
					bind.scratchIncoming = nil
					for _, child in childList do
						incoming[child] = true
					end
					for _, child in list do
						if child.Parent == parent and incoming[child] == nil then
							child.Parent = nil
						end
					end
					table.clear(incoming)
					bind.scratchIncoming = incoming
				end
				table.clear(list)
			end
			for count, child in childList do
				layoutOrder = applyLayoutOrder(child, layoutOrder)
				list[count] = child
				if child.Parent ~= parent then
					child.Parent = parent
				end
			end
			syncPortals(data, portalList, #portalList)
			table.clear(childList)
			table.clear(portalList)
			bind.scratchChildren = childList
			bind.scratchPortals = portalList
		else
			for _, child in list do
				if child.Parent == parent and child ~= value then
					child.Parent = nil
				end
			end
			table.clear(list)
			syncPortals(data, list, 0)
			if value ~= nil and isInstance(value) then
				local child = value :: Instance
				layoutOrder = applyLayoutOrder(child, layoutOrder)
				list[1] = child
				if child.Parent ~= parent then
					child.Parent = parent
				end
			end
		end
		data.lastEndOrder = layoutOrder
		refreshAfterChildrenSlot(parent, data, layoutOrder)
	end

	isolate(commitDom)
end

local function setAttribute(instance: Instance, attr: string, value: any)
	instance:SetAttribute(attr, value)
end

local function setProperty(instance: Instance, prop: string, value: any)
	local rawInstance: any = instance
	rawInstance[prop] = value
end

local function resolveKey(name: string, isAttribute: boolean?): (string, boolean, boolean)
	if isAttribute ~= nil then
		return name, isAttribute, false
	end
	local first = string.byte(name)
	if first == 36 then
		local attr = string.sub(name, 2)
		if attr == "" then
			error('attribute name after "$" cannot be empty', 4)
		end
		return attr, true, false
	elseif first == 35 then
		local tag = string.sub(name, 2)
		if tag == "" then
			error('tag name after "#" cannot be empty', 4)
		end
		return tag, false, true
	elseif first == 95 then
		if string.sub(name, 1, 6) == "_attr_" then
			local attr = string.sub(name, 7)
			if attr == "" then
				error('attribute name after "_attr_" cannot be empty', 4)
			end
			return attr, true, false
		elseif string.sub(name, 1, 5) == "_tag_" then
			local tag = string.sub(name, 6)
			if tag == "" then
				error('tag name after "_tag_" cannot be empty', 4)
			end
			return tag, false, true
		end
	end
	return name, false, false
end

local function onTagChanged(instance: Instance, tag: string, fn: (hasTag: boolean) -> ()): () -> ()
	local collectionService = Compat.getService("CollectionService")
	if collectionService == nil then
		return NOOP
	end
	local last = instance:HasTag(tag)
	local function check(inst: Instance)
		if inst == instance then
			local current = instance:HasTag(tag)
			if current ~= last then
				last = current
				fn(current)
			end
		end
	end
	local added = collectionService:GetInstanceAddedSignal(tag):Connect(check)
	local removed = collectionService:GetInstanceRemovedSignal(tag):Connect(check)
	local ancestry = instance.AncestryChanged:Connect(function()
		check(instance)
	end)
	local destroying: RBXScriptConnection
	local function disconnect()
		added:Disconnect()
		removed:Disconnect()
		ancestry:Disconnect()
		destroying:Disconnect()
	end
	destroying = instance.Destroying:Connect(disconnect)
	return disconnect
end

local function onChanged(
	instance: Instance,
	name: string,
	isAttribute: boolean?,
	fn: (value: any) -> ()
): RBXScriptConnection
	if isAttribute then
		return instance:GetAttributeChangedSignal(name):Connect(function()
			fn(instance:GetAttribute(name))
		end)
	end
	local rawInstance: any = instance
	return instance:GetPropertyChangedSignal(name):Connect(function()
		fn(rawInstance[name])
	end)
end

local function writeInstance(bind: BindData, value: any)
	for instance, syncTo in bind.rbx do
		local attrs = syncTo[1]
		if attrs then
			for attr in attrs do
				setAttribute(instance, attr, value)
			end
		end
		local props = syncTo[2]
		if props then
			for prop in props do
				setProperty(instance, prop, value)
			end
		end
	end
end

local function writeBinds(bind: BindData, value: any)
	if next(bind.rbx) ~= nil and not pcall(writeInstance, bind, value) then
		for instance, syncTo in bind.rbx do
			local attrs = syncTo[1]
			if attrs then
				for attr in attrs do
					local ok, result = pcall(setAttribute, instance, attr, value)
					if not ok then
						warn(`[Flux] failed to set attribute "{attr}" of {instance:GetFullName()}: {result}`)
					end
				end
			end
			local props = syncTo[2]
			if props then
				for prop in props do
					local ok, result = pcall(setProperty, instance, prop, value)
					if not ok then
						warn(`[Flux] failed to set property "{prop}" of {instance:GetFullName()}: {result}`)
					end
				end
			end
		end
	end
end

local bindDestroy: (node: Graph.Node<any>, disconnect: () -> ()) -> () -> ()

local function releaseBindDataIfIdle<T>(node: Graph.Node<T>)
	local data = bindData[node]
	if data == nil or data.pin ~= nil or #data.fn > 0 or next(data.rbx) ~= nil or data.children ~= nil then
		return
	end
	bindData[node] = nil
	local stopDestroy = data.destroyCleanup
	data.destroyCleanup = nil
	if stopDestroy ~= nil then
		stopDestroy()
	end
	if data.eff ~= nil then
		data.eff:Destroy()
		data.eff = nil
	end
	data.flushed = false
	data.value = nil
end

local function releaseSignalEffectIfIdle<T>(node: Graph.Node<T>, data: BindData)
	if data.pin == nil and #data.fn == 0 and next(data.rbx) == nil then
		if data.eff ~= nil then
			data.eff:Destroy()
			data.eff = nil
		end
		data.flushed = false
		data.value = nil
	end
	releaseBindDataIfIdle(node)
end

local function cleanupChildrenBind<T>(node: Graph.Node<T>, parent: Instance?)
	local data = bindData[node]
	local children = data and data.children
	if not children then
		return
	end
	if children.cleanupConnection then
		children.cleanupConnection:Disconnect()
		children.cleanupConnection = nil
	end
	if children.eff ~= nil then
		children.eff:Destroy()
		children.eff = nil
	end
	removeChildrenSlot(parent or children.parent, children)
	stopMountedPortals(children.portals)
	for _, child in children.list do
		local current = child and child.Parent
		if current ~= nil and (parent == nil or current == parent) then
			child.Parent = nil
		end
	end
	table.clear(children.list)
	table.clear(children)
	data.children = nil
	releaseBindDataIfIdle(node)
end

local function dispatchListener(entry: ListenerEntry, value: any, ver: number?)
	local fn = entry.fn
	if fn == nil then
		return
	end
	local skipVer = entry.skipVer
	if skipVer ~= nil then
		entry.skipVer = nil
		if ver == skipVer then
			return
		end
	end
	compatTask.spawn(fn, value)
end

local function startBindEffect(node: Graph.Node<any>, data: BindData): Graph.Node<any>
	data.flushed = false
	-- Writing instance properties fires engine listeners (`Changed`, `GetPropertyChangedSignal`, `AncestryChanged`)
	-- synchronously. Run the writes untracked and ownerless so those listeners neither subscribe this effect to
	-- what they read nor hand it the instances they create (which it would destroy on its next run).
	local pending: any = nil
	local pendingVer: number? = nil
	local notifyListeners = false
	local function write()
		local value = pending
		local ver = pendingVer
		local shouldNotify = notifyListeners
		pending = nil
		pendingVer = nil
		notifyListeners = false
		if shouldNotify then
			local fns = data.fn
			local count = #fns
			if count == 1 then
				dispatchListener(fns[1], value, ver)
			elseif count > 1 then
				local list = table.move(fns, 1, count, 1, table.create(count) :: { ListenerEntry })
				for _, entry in list do
					dispatchListener(entry, value, ver)
				end
			end
		end
		writeBinds(data, value)
	end
	local eff = isolate(effect, function()
		local notify = data.flushed
		data.flushed = true
		local value = get(node)
		local ver = nodeVersion(node)
		data.value = value
		data.ver = ver
		local hasFn = notify and #data.fn > 0
		if hasFn or next(data.rbx) ~= nil then
			pending = value
			pendingVer = ver
			notifyListeners = hasFn
			isolate(write)
		end
	end)
	return eff
end

function bindDestroy(node: Graph.Node<any>, disconnect: () -> ()): () -> ()
	local rawNode: any = node
	local done = false
	local destroyingNode = false
	local disconnectOnce: () -> ()
	local function onNodeDestroy()
		destroyingNode = true
		disconnectOnce()
	end
	function disconnectOnce()
		if done then
			return
		end
		done = true
		if not destroyingNode then
			local inner = rawget(rawNode, 1)
			local destroys = inner and inner.destroys
			if destroys then
				local idx = table.find(destroys, onNodeDestroy)
				if idx then
					table.remove(destroys, idx)
				end
			end
		end
		disconnect()
	end
	node:onDestroy(onNodeDestroy)
	return disconnectOnce
end

local function ensureBindData<T>(node: Graph.Node<T>): BindData
	local data: any = bindData[node]
	if data == nil then
		data = { fn = {}, rbx = {}, children = nil, eff = nil, flushed = false, value = nil }
		bindData[node] = data
		data.destroyCleanup = bindDestroy(node, function()
			if bindData[node] ~= data then
				return
			end
			if data.eff ~= nil then
				data.eff:Destroy()
				data.eff = nil
			end
			for _, entry in data.fn do
				entry.fn = nil
			end
			table.clear(data.fn)
			table.clear(data.rbx)
			if data.children ~= nil then
				cleanupChildrenBind(node)
			end
			bindData[node] = nil
		end)
	end
	return data
end

local function ensureSignalEffect<T>(node: Graph.Node<T>, data: BindData): Graph.Node<any>
	if data.eff == nil then
		data.eff = startBindEffect(node, data)
	end
	return data.eff :: Graph.Node<any>
end

local Bind = {
	--- @ignore
	pinOrder = function(instance: Instance)
		pinnedOrder[instance] = true
		autoOrder[instance] = nil
	end,
	--- @ignore
	placeChildOrder = placeChildOrder,
	--- @ignore
	applyLayoutOrder = applyLayoutOrder,
	--- @ignore
	setAttribute = setAttribute,
	--- @ignore
	setProperty = setProperty,
	--- @ignore
	onChanged = onChanged,
	--- @ignore
	onTagChanged = onTagChanged,
	--- @ignore
	syncPortals = syncPortals,
	--- @ignore
	bindDestroy = bindDestroy,
}

--[[
Wraps a reactive [node](https://flux.kohl.gg/guide/concepts/signals) for two-way binding on an [`Instance`](https://create.roblox.com/docs/reference/engine/classes/Instance) property, attribute, or tag.
Updates the instance from `node` and writes changes back to `node` when the instance fires its changed signal.

[Open Documentation](https://flux.kohl.gg/guide/roblox/creation#flux-model-two-way-binding-in-one-key)
]]
function Bind.model<T>(node: { read get: (any) -> T, read peek: (any) -> T, read set: (any, ...any) -> any }): T
	if not isNode(node) then
		error("Flux.model expects a reactive node", 2)
	end
	local wrapped: any = table.freeze({ MODEL_SYMBOL, node })
	return wrapped
end

--[[
Returns `true` when `value` is a [`Flux.model`](https://flux.kohl.gg/guide/roblox/creation#flux-model-two-way-binding-in-one-key) wrapper.

[Open Documentation](https://flux.kohl.gg/guide/roblox/creation#flux-model-two-way-binding-in-one-key)
]]
function Bind.isModel(value: unknown): boolean
	local rawValue: any = value
	return type(value) == "table" and rawget(rawValue, 1) == MODEL_SYMBOL
end

--[[
Returns the underlying node from a [`Flux.model`](https://flux.kohl.gg/guide/roblox/creation#flux-model-two-way-binding-in-one-key) wrapper, or `nil` if `value` is not a model.

```luau
local node = Flux.modelNode(props.value)
if node then
	node:set(text)
end
```

[Open Documentation](https://flux.kohl.gg/guide/roblox/creation#flux-model-two-way-binding-in-one-key)
]]
function Bind.modelNode(value: unknown): Graph.Node<any>?
	local rawValue: any = value
	return if Bind.isModel(value) then rawValue[2] else nil
end

--- @ignore
function Bind.children<T>(node: Graph.Node<T>, parent: Instance, layoutOrder: number?): () -> ()
	local data = ensureBindData(node)
	bindGeneration += 1
	local token = bindGeneration
	local children: ChildrenState
	local function disconnectBind()
		local current = data.children
		if current ~= nil and current.token == token then
			cleanupChildrenBind(node, parent)
		end
	end

	local existing = data.children
	local oldParent: Instance? = nil
	if existing == nil then
		local fresh: ChildrenState = { list = {} }
		children = fresh
		data.children = fresh
	else
		children = existing
		if children.cleanupConnection then
			children.cleanupConnection:Disconnect()
			children.cleanupConnection = nil
		end
		if children.eff ~= nil then
			children.eff:Destroy()
			children.eff = nil
		end
		oldParent = children.parent
		if oldParent ~= nil and oldParent ~= parent then
			removeChildrenSlot(oldParent, children)
			for _, child in children.list do
				if child and child.Parent == oldParent then
					child.Parent = nil
				end
			end
			table.clear(children.list)
		end
	end
	children.cleanupConnection = parent.Destroying:Once(disconnectBind)
	children.offset = layoutOrder
	children.order = attachChildrenSlot(parent, children, layoutOrder)
	children.lastEndOrder = children.order
	children.parent = parent
	children.token = token

	local childEff = isolate(effect, function()
		applyChildren(data, get(node))
	end)
	children.eff = childEff
	local ok, err: any = pcall(function()
		childEff:peek()
	end)
	if not ok then
		if data.children == children and children.token == token then
			cleanupChildrenBind(node, parent)
		else
			childEff:Destroy()
		end
		error(err, 0)
	end
	return disconnectBind
end

--[[
Subscribes `fn` to updates of `node` with [`RBXScriptSignal:Connect`](https://create.roblox.com/docs/reference/engine/datatypes/RBXScriptSignal#Connect) semantics and returns an unsubscribe function.
Fires on each flush after `node` changes, spawning `fn(value)` on its own thread via [`task.spawn`](https://create.roblox.com/docs/reference/engine/libraries/task#spawn) so callbacks may yield freely.

[Open Documentation](https://flux.kohl.gg/guide/concepts/effects#bridging-to-external-systems)
]]
function Bind.listen<T>(node: Graph.Node<T>, fn: (value: T) -> ()): () -> ()
	if not isNode(node) then
		error(`Flux.listen expects a reactive node, got {compatTypeof(node)}`, 2)
	elseif type(fn) ~= "function" then
		error(`Flux.listen expects a function, got {compatTypeof(fn)}`, 2)
	end
	local data = ensureBindData(node)
	local eff = ensureSignalEffect(node, data)
	local fnData = data.fn
	if not data.flushed or #fnData == 0 then
		eff:peek()
	end
	local entry: ListenerEntry = { fn = fn }
	if #fnData > 0 then
		local curVer = nodeVersion(node)
		if curVer ~= data.ver then
			entry.skipVer = curVer
		end
	end
	table.insert(fnData, entry)
	return function()
		if entry.fn == nil then
			return
		end
		entry.fn = nil
		entry.skipVer = nil
		local idx = table.find(fnData, entry)
		if idx ~= nil then
			table.remove(fnData, idx)
		end
		releaseSignalEffectIfIdle(node, data)
	end
end

--- @ignore
function Bind.from<T>(node: Graph.Node<T>, instance: Instance, property: string, isAttribute: boolean?)
	local name, attribute, isTag = resolveKey(property, isAttribute)
	local rawNode: any = node
	local rawInstance: any = instance
	local disconnect: any
	if isTag then
		rawNode:set(instance:HasTag(name))
		disconnect = onTagChanged(instance, name, function(hasTag)
			rawNode:set(hasTag)
		end)
	else
		rawNode:set(if attribute then instance:GetAttribute(name) else rawInstance[name])
		local connection = onChanged(instance, name, attribute, function(value)
			rawNode:set(value)
		end)
		disconnect = function()
			connection:Disconnect()
		end
	end
	local destroyConn: RBXScriptConnection? = nil
	local stop = bindDestroy(node, function()
		local conn = destroyConn
		destroyConn = nil
		if conn ~= nil then
			conn:Disconnect()
		end
		disconnect()
	end)
	destroyConn = instance.Destroying:Once(stop)
	if getOwner() ~= nil then
		cleanup(stop)
	end
	return node, stop
end

local function follow(instance: Instance, property: string): Graph.Node<any>
	return (Bind.from(signal(NO_VALUE), instance, property))
end

local function readSignalConnector(obj: any): ((any, (any) -> ()) -> any)?
	local ok, connect = pcall(function()
		return obj.Connect
	end)
	if ok and type(connect) == "function" then
		return connect
	end
	local okLower, lower = pcall(function()
		return obj.connect
	end)
	return if okLower and type(lower) == "function" then lower else nil
end

local function getSignalConnector(obj: any): ((any, (any) -> ()) -> any)?
	if isNode(obj) or isInstance(obj) then
		return nil
	end
	if kindOf(obj) == "RBXScriptSignal" then
		return (obj :: any).Connect
	end
	local objType = type(obj)
	if objType ~= "table" and objType ~= "userdata" then
		return nil
	end
	if objType == "table" and getmetatable(obj :: any) == nil then
		local connect = rawget(obj :: any, "Connect")
		if type(connect) == "function" then
			return connect
		end
		local lower = rawget(obj :: any, "connect")
		return if type(lower) == "function" then lower else nil
	end
	return isolate(readSignalConnector, obj)
end

local function fromSignal(sig: any, initial: any): Graph.Node<any>
	local connect = getSignalConnector(sig)
	if connect == nil then
		error(`Flux.fromSignal expects an RBXScriptSignal or signal with :Connect(), got {compatTypeof(sig)}`, 2)
	end
	local node = signal(initial)
	local destroyed = false
	local conn: any = nil
	local stop = bindDestroy(node, function()
		destroyed = true
		if conn ~= nil then
			local active = conn
			conn = nil
			dispose(active)
		end
	end)
	local ok, connected = isolate(pcall, connect, sig, function(value: any)
		if not destroyed then
			node:set(value)
		end
	end)
	if not ok then
		node:Destroy()
		error(connected, 0)
	end
	if destroyed then
		dispose(connected)
	else
		conn = connected
		if getOwner() ~= nil then
			cleanup(stop)
		end
	end
	return node
end

--[[
Creates a [node](https://flux.kohl.gg/guide/concepts/signals#bridging-signals) updated from the first argument of an
[`RBXScriptSignal`](https://create.roblox.com/docs/reference/engine/datatypes/RBXScriptSignal) or signal table with
`:Connect()` / `:connect()`, seeding from `initial` and deduplicating equal values. Disconnects automatically when the node or its owning scope is destroyed.
]]
Bind.fromSignal = fromSignal :: (<S>(
	signal: S & (RBXScriptSignal | { Connect: any } | { connect: any })
) -> Graph.Node<Type.SignalPayload<S>?>) & (<S, I>(
	signal: S & (RBXScriptSignal | { Connect: any } | { connect: any }),
	initial: I
) -> Graph.Node<Type.SignalPayload<S> | I>)

-- The `"Name"` singleton in `property`'s type keeps a literal argument from widening to `string`, so `K` stays the key.
--[[
Creates a [node](https://flux.kohl.gg/guide/concepts/signals) mirroring an [`Instance`](https://create.roblox.com/docs/reference/engine/classes/Instance) property, an attribute (`$Name` or `_attr_Name`), or a [`CollectionService`](https://create.roblox.com/docs/reference/engine/classes/CollectionService) tag (`#Tag` or `_tag_Tag`).
Disconnects automatically when `instance`, the node, or its owning scope is destroyed.

```luau
local text = Flux.property(textBox, "Text")
local health = Flux.property(character, "$Health")
local isEnemy = Flux.property(character, "#Enemy")
```

[Open Documentation](https://flux.kohl.gg/guide/concepts/signals#binding-from-an-instance-property)
]]
function Bind.property<I, K>(instance: I & Instance, property: K | "Name"): Graph.Node<Type.PropertyType<I, K>>
	if not isInstance(instance) then
		error(`Flux.property expects an Instance, got {compatTypeof(instance)}`, 2)
	elseif type(property) ~= "string" then
		error(`Flux.property expects a property, "$Attribute", or "#Tag" name, got {compatTypeof(property)}`, 2)
	end
	return follow(instance, property)
end

-- The core constructor behind `Flux(...)`: a value becomes a signal, a function a computed, an Instance with a
-- property, `"$Attribute"` / `"_attr_Attribute"`, or `"#Tag"` / `"_tag_Tag"` name a `Bind.property` node, and an
-- `RBXScriptSignal` a `Bind.fromSignal` node.
--- @ignore
function Bind.node(obj: any, second: any?): Graph.Node<any>
	if isInstance(obj) then
		if type(second) ~= "string" then
			error(
				`Flux(instance, property) expects a property, "$Attribute", or "#Tag" name, got {compatTypeof(second)}`,
				3
			)
		end
		return follow(obj, second)
	elseif kindOf(obj) == "RBXScriptSignal" then
		return (Bind.fromSignal :: any)(obj, second)
	elseif second ~= nil then
		error(
			`Flux(value) takes a single argument; only an Instance takes a property name (or an RBXScriptSignal an initial value)`,
			3
		)
	end
	return new(obj)
end

--[[
Wraps `fn` so a [computed](https://flux.kohl.gg/guide/concepts/computeds) or [effect](https://flux.kohl.gg/guide/concepts/effects) tracks only `deps` and runs `fn(input, prevInput, prevResult)` untracked.
Pass `defer = true` to skip the initial run and fire only when `deps` change.

[Open Documentation](https://flux.kohl.gg/guide/concepts/tracking#flux-on)
]]
type OnFn =
	(<D, R>(
		deps: D,
		fn: (input: Type.OnInput<D>, prevInput: Type.OnInput<D>?, prevResult: R?) -> R
	) -> (prevResult: R?) -> R)
	& (<D, R>(
		deps: D,
		fn: (input: Type.OnInput<D>, prevInput: Type.OnInput<D>?, prevResult: R?) -> R,
		defer: boolean
	) -> (prevResult: R?) -> R?)

local function on<D, R>(
	deps: D,
	fn: (input: Type.OnInput<D>, prevInput: Type.OnInput<D>?, prevResult: R?) -> R,
	defer: boolean?
): (prevResult: R?) -> R?
	local rawDeps: any = deps
	local rawFn: (any, any, any) -> any = fn
	local isArray = type(rawDeps) == "table"
		and not isNode(rawDeps)
		and getmetatable(rawDeps) == nil
		and (rawDeps[1] ~= nil or next(rawDeps) == nil)
	local count = if isArray then #(rawDeps :: { any }) else 0
	local prevInput: any = nil
	local curInput: any = nil
	local curPrevResult: any = nil
	local function runOnFn(): R
		local input, prevRes = curInput, curPrevResult
		curInput, curPrevResult = nil, nil
		return rawFn(input, prevInput, prevRes)
	end

	return function(prevResult: R?): R?
		local input
		if isArray then
			input = table.create(count)
			for i = 1, count do
				input[i] = read(rawDeps[i])
			end
		else
			input = read(rawDeps)
		end

		if defer then
			defer = false
			prevInput = input
			return prevResult
		end

		curInput, curPrevResult = input, prevResult
		local result = untrack(runOnFn)
		prevInput = input
		return result
	end
end

Bind.on = on :: OnFn

--- @ignore
function Bind.to<T>(node: Graph.Node<T>, instance: Instance, property: string, isAttribute: boolean?)
	local data = ensureBindData(node)
	ensureSignalEffect(node, data)
	data.pin = (data.pin or 0) + 1
	local attribute = isAttribute == true
	local index = if attribute then 1 else 2
	local ok, err: any = pcall(function()
		release(instance, property, attribute)

		local value = raw(node)
		if attribute then
			isolate(setAttribute, instance, property, value)
		else
			isolate(setProperty, instance, property, value)
		end
	end)
	local pin = (data.pin or 1) - 1
	data.pin = if pin > 0 then pin else nil
	if not ok then
		releaseSignalEffectIfIdle(node, data)
		error(err, 0)
	end
	if bindData[node] ~= data then
		return NOOP
	end

	local binds = data.rbx[instance]
	if binds == nil then
		local newBinds: { { [string]: any }? } = {}
		binds = newBinds
		data.rbx[instance] = newBinds
	end
	local bucket = binds[index]
	if bucket == nil then
		bucket = {}
		binds[index] = bucket
	end

	bindGeneration += 1
	local token = bindGeneration
	bucket[property] = token

	local function unbind()
		if bucket[property] ~= token then
			return
		end
		bucket[property] = nil
		if (binds[1] == nil or next(binds[1]) == nil) and (binds[2] == nil or next(binds[2]) == nil) then
			data.rbx[instance] = nil
		end
		releaseSignalEffectIfIdle(node, data)
	end

	local key = claimKey(property, attribute)
	local claim: Claim = { unbind }
	local owned = claims[instance]
	if owned == nil then
		owned = {}
		claims[instance] = owned
	end
	owned[key] = claim

	return function()
		local current = claims[instance]
		if current and current[key] == claim then
			current[key] = nil
			if next(current) == nil then
				claims[instance] = nil
			end
		end
		unbind()
	end
end

--- @ignore
--- Releases the source currently bound to an instance property or attribute, so a static write replaces it.
Bind.release = release

--- @ignore
--- Ties `releaser` (a cleanup function or cleanable) to the current binding of a key, run when a later edit replaces it.
function Bind.attach(instance: Instance, property: string, isAttribute: boolean?, releaser: any)
	local owned = claims[instance]
	local claim = owned and owned[claimKey(property, isAttribute)]
	if claim then
		table.insert(claim, releaser)
	end
end

--- @ignore
function Bind.isPortal(value: unknown): boolean
	return isPortal(value)
end

--[[
Creates a portal mounting `children` into `target` (static [`Instance`](https://create.roblox.com/docs/reference/engine/classes/Instance)
or reactive target node) without transferring ownership of `target`.
Mounted children are unparented when the owning scope tears down, the target changes, or the portal host is destroyed.

[Open Documentation](https://flux.kohl.gg/guide/roblox/creation#portals-flux-portal)
]]
function Bind.portal(target: Graph.Reactive<Instance?>, children: any): Portal
	if target ~= nil and not isInstance(target) and not Graph.isDynamic(target) then
		error(`Flux.portal expects an Instance, reactive target, or nil, got {compatTypeof(target)}`, 2)
	end
	local wrapped: any = table.freeze({ PORTAL_SYMBOL, target, children })
	return wrapped
end

local UNMOUNTED = table.freeze({})

--- @ignore
function mountPortal(portal: any): () -> ()
	local targetSpec = portal[2]
	local content = portal[3]
	local mountedInstances: { Instance } = {}
	local subCleanups: { () -> () } = {}
	local targetConn: RBXScriptConnection? = nil
	local currentTarget: Instance? = nil
	local eff: any = nil
	local stopped = false

	local function clearMounted()
		if targetConn ~= nil then
			targetConn:Disconnect()
			targetConn = nil
		end
		stopPortals(subCleanups)
		local target = currentTarget
		currentTarget = nil
		if target ~= nil then
			for _, inst in mountedInstances do
				if inst.Parent == target then
					inst.Parent = nil
				end
			end
			if #mountedInstances > 0 then
				refreshParentSlots(target)
			end
		end
		table.clear(mountedInstances)
	end

	local function mountItem(target: Instance, item: any)
		if isInstance(item) then
			if parentSlots[target] == nil then
				parentSlots[target] = {}
			end
			placeChildOrder(target, item)
			table.insert(mountedInstances, item)
			item.Parent = target
		elseif isNode(item) then
			table.insert(subCleanups, Bind.children(item, target))
		elseif isPortal(item) then
			table.insert(subCleanups, mountPortal(item))
		elseif type(item) == "table" then
			for _, sub in item do
				mountItem(target, sub)
			end
		end
	end

	local function mountTo(target: any)
		isolate(function()
			clearMounted()
			if stopped or target == nil then
				return
			end
			if not isInstance(target) then
				error(`Flux.portal target must resolve to an Instance or nil, got {compatTypeof(target)}`, 2)
			end
			currentTarget = target
			targetConn = target.Destroying:Once(clearMounted)
			local ok, err: any = pcall(mountItem, target, content)
			if not ok then
				clearMounted()
				error(err, 0)
			end
		end)
	end

	local function stop()
		if stopped then
			return
		end
		stopped = true
		if eff ~= nil then
			(eff :: any):Destroy()
			eff = nil
		end
		isolate(clearMounted)
	end

	if Graph.isDynamic(targetSpec) then
		local mountedTarget: any = UNMOUNTED
		eff = isolate(effect, function()
			local nextTarget = read(targetSpec)
			if nextTarget ~= mountedTarget then
				mountedTarget = nextTarget
				mountTo(nextTarget)
			end
		end)
	else
		mountTo(targetSpec)
	end

	if getOwner() ~= nil then
		cleanup(stop)
	end

	return stop
end

--- @ignore
Bind.mountPortal = mountPortal

return table.freeze(Bind)
