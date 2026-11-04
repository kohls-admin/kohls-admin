--!strict
local Compat = require("./Compat")
local Graph = require("./Graph")
local Type = require("./Type")

local compatTypeof = Compat.typeof
local warn = Compat.warn

local effect = Graph.effect
local get = Graph.Node.get
local kindOf = Graph.kindOf
local new = Graph.new
local signal = Graph.signal
local raw = Graph.raw
local read = Graph.read
local untrack = Graph.untrack
local isNode = Graph.isNode
local isReactive = Graph.isReactive
local withOwner = Graph.withOwner

local MODEL_SYMBOL: any = table.freeze({ type = "Model" })
local NO_VALUE: any = nil
local NOOP = function() end

--- @ignore
type BindData = {
	rbx: { [Instance]: { { [string]: any }? } },
	eff: Graph.Node<any>,
	flushed: boolean,
	children: {
		cleanupConnection: RBXScriptConnection?,
		list: { Instance },
		parent: Instance?,
		order: number?,
		token: number?,
	}?,
}

local bindData: { [Graph.Node<any>]: BindData } = setmetatable({}, { __mode = "k" })
local bindGeneration = 0

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

local function applyLayoutOrder(child: Instance, order: number): number
	if child:IsA("GuiObject") and (child :: GuiObject).LayoutOrder == 0 and not pinnedOrder[child] then
		(child :: GuiObject).LayoutOrder = order
		return order + 1
	end
	return order
end

local function isInstance(value: any): boolean
	return kindOf(value) == "Instance"
end

local function collectChildren(value: any, into: { Instance }): { Instance }
	if isInstance(value) then
		table.insert(into, value)
	elseif isNode(value) then
		collectChildren(get(value), into)
	elseif type(value) == "table" then
		for _, child in value do
			collectChildren(child, into)
		end
	end
	return into
end

local function applyChildren(bind: BindData, value: any)
	local data = bind.children
	if data == nil then
		return
	end
	local list = data.list
	local parent = data.parent
	local layoutOrder = data.order or 1

	while isNode(value) do
		value = get(value)
	end

	if type(value) == "table" and not isInstance(value) then
		local children = collectChildren(value, {})
		if list[1] ~= nil then
			if children[2] == nil then
				local first = children[1]
				for _, child in list do
					if child.Parent == parent and child ~= first then
						child.Parent = nil
					end
				end
			else
				local incoming: { [Instance]: true } = {}
				for _, child in children do
					incoming[child] = true
				end
				for _, child in list do
					if child.Parent == parent and incoming[child] == nil then
						child.Parent = nil
					end
				end
			end
			table.clear(list)
		end
		for count, child in children do
			layoutOrder = applyLayoutOrder(child, layoutOrder)
			list[count] = child
			child.Parent = parent
		end
	else
		for _, child in list do
			if child.Parent == parent and child ~= value then
				child.Parent = nil
			end
		end
		table.clear(list)
		if value ~= nil and isInstance(value) then
			local child = value :: Instance
			applyLayoutOrder(child, layoutOrder)
			list[1] = child
			child.Parent = parent
		end
	end
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
	return function()
		added:Disconnect()
		removed:Disconnect()
		ancestry:Disconnect()
	end
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

local function cleanupChildrenBind<T>(node: Graph.Node<T>, parent: Instance?)
	local data = bindData[node]
	local children = data and data.children
	if not children then
		return
	end
	if children.cleanupConnection then
		children.cleanupConnection:Disconnect()
	end
	for _, child in children.list do
		local current = child and child.Parent
		if current ~= nil and (parent == nil or current == parent) then
			child.Parent = nil
		end
	end
	table.clear(children.list)
	table.clear(children)
	data.children = nil
end

local function startBindEffect(node: Graph.Node<any>, data: any): Graph.Node<any>
	data.flushed = false
	-- Writing instance properties fires engine listeners (`Changed`, `GetPropertyChangedSignal`, `AncestryChanged`)
	-- synchronously. Run the writes untracked and ownerless so those listeners neither subscribe this effect to
	-- what they read nor hand it the instances they create (which it would destroy on its next run). Children
	-- stay tracked: nested child nodes are read while mounting them.
	local pending: any = nil
	local function write()
		local value = pending
		pending = nil
		writeBinds(data, value)
	end
	local function isolated()
		untrack(write)
	end
	local eff = withOwner(NO_VALUE, function()
		return effect(function()
			data.flushed = true
			local value = get(node)
			if next(data.rbx) ~= nil then
				pending = value
				withOwner(NO_VALUE, isolated)
			end
			applyChildren(data, value)
		end)
	end)
	return eff
end

local function getBindData<T>(node: Graph.Node<T>)
	local data: any = bindData[node]
	if data == nil then
		data = { rbx = {}, children = nil, eff = nil, flushed = false }
		bindData[node] = data
		data.eff = startBindEffect(node, data)
		node:onDestroy(function()
			data.eff:Destroy()
			table.clear(data.rbx)
			cleanupChildrenBind(node)
			bindData[node] = nil
		end)
	end
	return data
end

local function bindDestroy(node: Graph.Node<any>, disconnect: () -> ()): () -> ()
	local rawNode: any = node
	local done = false
	local function disconnectOnce()
		if done then
			return
		end
		done = true
		local inner = rawNode[1]
		local destroys = inner and inner.destroys
		if destroys then
			local idx = table.find(destroys, disconnectOnce)
			if idx then
				table.remove(destroys, idx)
			end
		end
		disconnect()
	end
	node:onDestroy(disconnectOnce)
	return disconnectOnce
end

local Bind = {
	--- @ignore
	pinOrder = function(instance: Instance)
		pinnedOrder[instance] = true
	end,
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
	bindDestroy = bindDestroy,
}

--[[
Wraps a reactive [node](https://flux.kohl.gg/guide/concepts/signals) for two-way binding on an [`Instance`](https://create.roblox.com/docs/reference/engine/classes/Instance) property, attribute, or tag.
Updates the instance from `node` and writes changes back to `node` when the instance fires its changed signal.

[Open Documentation](https://flux.kohl.gg/guide/roblox/creation#flux-model-two-way-binding-in-one-key)
]]
function Bind.model<N>(node: N): Graph.Unwrap<N>
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
	return type(value) == "table" and rawValue[1] == MODEL_SYMBOL
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

local pendingChildData: BindData?
local pendingChildValue: any

local function applyPendingChildren()
	local data, value = pendingChildData :: BindData, pendingChildValue
	pendingChildData, pendingChildValue = nil, nil
	applyChildren(data, value)
end

--- @ignore
function Bind.children<T>(node: Graph.Node<T>, parent: Instance, layoutOrder: number?): () -> ()
	local data = getBindData(node)
	bindGeneration += 1
	local token = bindGeneration
	local function disconnectBind()
		local current = data.children
		if current ~= nil and current.token == token then
			cleanupChildrenBind(node, parent)
		end
	end

	local children = data.children
	if children == nil then
		children = { list = {} }
		data.children = children
	else
		if children.cleanupConnection then
			children.cleanupConnection:Disconnect()
		end
		local oldParent = children.parent
		if oldParent ~= nil and oldParent ~= parent then
			for _, child in children.list do
				if child and child.Parent == oldParent then
					child.Parent = nil
				end
			end
			table.clear(children.list)
		end
	end
	children.cleanupConnection = parent.Destroying:Once(disconnectBind)
	children.order = layoutOrder or 1
	children.parent = parent
	children.token = token

	if data.flushed then
		data.eff:Destroy()
		data.eff = startBindEffect(node, data)
	end
	if isReactive() then
		pendingChildData, pendingChildValue = data, raw(node)
		untrack(applyPendingChildren)
	else
		applyChildren(data, raw(node))
	end
	return disconnectBind
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
	return node, bindDestroy(node, disconnect)
end

local function follow(instance: Instance, property: string): Graph.Node<any>
	return (Bind.from(signal(NO_VALUE), instance, property))
end

-- The `"Name"` singleton in `property`'s type keeps a literal argument from widening to `string`, so `K` stays the key.
--[[
Creates a [node](https://flux.kohl.gg/guide/concepts/signals) mirroring an [`Instance`](https://create.roblox.com/docs/reference/engine/classes/Instance) property, an attribute (`$Name` or `_attr_Name`), or a [`CollectionService`](https://create.roblox.com/docs/reference/engine/classes/CollectionService) tag (`#Tag` or `_tag_Tag`).
Disconnects automatically when the node or its owning scope is destroyed.

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

-- The core constructor behind `Flux(...)`: a value becomes a signal, a function a computed, and an Instance with a
-- property, `"$Attribute"` / `"_attr_Attribute"`, or `"#Tag"` / `"_tag_Tag"` name a `Bind.property` node.
--- @ignore
function Bind.node(obj: any, second: string?): Graph.Node<any>
	if isInstance(obj) then
		if type(second) ~= "string" then
			error(
				`Flux(instance, property) expects a property, "$Attribute", or "#Tag" name, got {compatTypeof(second)}`,
				3
			)
		end
		return follow(obj, second)
	elseif second ~= nil then
		error(`Flux(value) takes a single argument; only an Instance takes a property name`, 3)
	end
	return new(obj)
end

--[[
Wraps `fn` so a [computed](https://flux.kohl.gg/guide/concepts/computeds) or [effect](https://flux.kohl.gg/guide/concepts/effects) tracks only `deps` and runs `fn(input, prevInput, prevResult)` untracked.
Pass `defer = true` to skip the initial run and fire only when `deps` change.

[Open Documentation](https://flux.kohl.gg/guide/concepts/tracking#flux-on)
]]
function Bind.on<D, R>(
	deps: any,
	fn: (input: any, prevInput: any?, prevResult: R?) -> R,
	defer: boolean?
): (prevResult: R?) -> R?
	local isArray = type(deps) == "table" and not isNode(deps)
	local count = if isArray then #(deps :: { any }) else 0
	local prevInput: any = nil
	local curInput: any = nil
	local curPrevResult: any = nil
	local function runOnFn(): R
		local input, prevRes = curInput, curPrevResult
		curInput, curPrevResult = nil, nil
		return fn(input, prevInput, prevRes)
	end

	return function(prevResult: R?): R?
		local input
		if isArray then
			input = table.create(count)
			for i = 1, count do
				input[i] = read(deps[i])
			end
		else
			input = read(deps)
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

--- @ignore
function Bind.to<T>(node: Graph.Node<T>, instance: Instance, property: string, isAttribute: boolean?)
	local data = getBindData(node)
	local attribute = isAttribute == true
	local index = if attribute then 1 else 2
	release(instance, property, attribute)

	local value = raw(node)
	local function applyInitial()
		if attribute then
			setAttribute(instance, property, value)
		else
			setProperty(instance, property, value)
		end
	end
	if isReactive() or Graph.getOwner() ~= nil then
		withOwner(NO_VALUE, function()
			untrack(applyInitial)
		end)
	else
		applyInitial()
	end

	local binds = data.rbx[instance]
	if binds == nil then
		binds = {}
		data.rbx[instance] = binds
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

return table.freeze(Bind)
