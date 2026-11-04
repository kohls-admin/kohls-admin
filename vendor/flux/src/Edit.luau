--!strict
local Bind = require("./Bind")
local Compat = require("./Compat")
local Graph = require("./Graph")
local Type = require("./Type")

local IS_ROBLOX = Compat.isRoblox
local Color3 = Compat.Color3
local Enum = Compat.Enum
local compatTypeof = Compat.typeof
local task = Compat.task
local warn = Compat.warn

local dispose = Graph.dispose
local get = Graph.Node.get
local isNode = Graph.isNode
local newNode: (init: any, equals: any?) -> Graph.Node<any> = Graph.new
local effect = Graph.effect
local getOwner = Graph.getOwner
local cleanup = Graph.cleanup
local bindContext = Graph.bindContext

local bindFrom = Bind.from
local bindTo = Bind.to
local releaseBinding = Bind.release
local attachToBinding = Bind.attach
local isModel = Bind.isModel
local onChanged = Bind.onChanged
local onTagChanged = Bind.onTagChanged
local setAttribute = Bind.setAttribute
local setProperty = Bind.setProperty

local kindOf = Graph.kindOf

-- Flags & Defaults ----------------------------------------------------------------------------------------------------

local Flags = {
	--[[
	Controls whether [`Flux.new`](https://flux.kohl.gg/guide/roblox/creation#the-flux-new-function) applies the
	per-class [`Flux.Defaults`](https://flux.kohl.gg/guide/roblox/defaults) table to new instances (`true` by default).
	`AutoButtonColor = false` is still applied to `TextButton` and `ImageButton` even when `false`.

	[Open Documentation](https://flux.kohl.gg/guide/roblox/defaults#disabling-defaults)
	]]
	defaults = true,
}

local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)

local function guiBase(extra: { [string]: unknown }?): { [string]: unknown }
	local t: { [string]: unknown } = {
		BackgroundColor3 = WHITE,
		BorderColor3 = BLACK,
		BorderSizePixel = 0,
	}
	if extra then
		for k, v in extra do
			t[k] = v
		end
	end
	return t
end

local function textBase(extra: { [string]: unknown }?): { [string]: unknown }
	local t = guiBase(extra)
	t.Font = Enum.Font.SourceSans
	t.Text = ""
	t.TextColor3 = BLACK
	return t
end

local Defaults: { [string]: { [string]: unknown } } = {
	Part = {
		Material = Enum.Material.SmoothPlastic,
		Size = vector.create(1, 1, 1),
		Anchored = true,
	},
	BillboardGui = {
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	},
	ScreenGui = {
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	},
	SurfaceGui = {
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		PixelsPerStud = 50,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
	},
	Frame = guiBase(),
	ImageButton = guiBase(),
	ImageLabel = guiBase(),
	VideoFrame = guiBase(),
	ViewportFrame = guiBase(),
	ScrollingFrame = guiBase({ ScrollBarImageColor3 = BLACK }),
	TextBox = textBase({ ClearTextOnFocus = false }),
	TextButton = textBase(),
	TextLabel = textBase(),
	UIListLayout = { SortOrder = Enum.SortOrder.LayoutOrder },
	UIGridLayout = { SortOrder = Enum.SortOrder.LayoutOrder },
	UITableLayout = { SortOrder = Enum.SortOrder.LayoutOrder },
	UIPageLayout = { SortOrder = Enum.SortOrder.LayoutOrder },
}

-- Find ----------------------------------------------------------------------------------------------------------------

local FIND_SYMBOL: any = table.freeze({ type = "Symbol" })
local rawGame: any = game

local function indexParent(instance: Instance): Instance?
	return instance.Parent
end

local function queryFirst(instance: Instance, query: string): Instance?
	return instance:QueryDescendants(query)[1]
end

local function findPath(instance: Instance, pathStr: string): Instance?
	local cur: Instance = instance
	for _, segment in string.split(pathStr, ".") do
		if segment == "" then
			continue
		end
		local nextInst = if segment == "Parent" or segment == "^" then cur.Parent else cur:FindFirstChild(segment)
		if not nextInst then
			return nil
		end
		cur = nextInst
	end
	return cur
end

local function makeSelector(find: any): any
	local fn = if type(find) ~= "string"
		then find
		elseif IS_ROBLOX then rawGame[find]
		else function(instance: any, query: string): any
			return instance[find](instance, query)
		end
	return function(query: string)
		return function(properties: Type.Map<any>)
			return { FIND_SYMBOL, fn, properties, query }
		end
	end
end

--- @ignore
type Fallback<Name> = index<Type.Editable & { [string]: Instance }, Name>

export type Selection = { any }
export type ClassSelector = <T>(className: T | keyof<Type.Editable>) -> (Type.EditProperties<Fallback<T>>) -> Selection
-- A name, path or query says nothing about the class it finds, so its property table is untyped.
export type QuerySelector = (query: string) -> (Type.Map<any>) -> Selection
export type ParentSelector = () -> (Type.Map<any>) -> Selection

local function warnFind(query: string?, value: any)
	local desc = if query == nil then "a Find selector" else `query "{query}"`
	warn(`[Flux] Instance expected for {desc}, got {compatTypeof(value)}`)
end

local function resolveFind(
	applied: { any },
	instance: Instance,
	applyProps: (Instance, Type.Map<any>, ...any) -> ...any
)
	local query = applied[4]
	local result = applied[2](instance, query)
	local properties = applied[3]
	local kind = kindOf(result)

	if kind == "Instance" then
		applyProps(result, properties)
	elseif kind == "table" then
		for _, item in result do
			if kindOf(item) == "Instance" then
				applyProps(item, properties)
			else
				warnFind(query, item)
			end
		end
	else
		warnFind(query, result)
	end
end

local Find = table.freeze({
	--[[
	Selects the first ancestor named `name` via
	[`Instance:FindFirstAncestor`](https://create.roblox.com/docs/reference/engine/classes/Instance#FindFirstAncestor)
	and applies the property table to it.

	[Open Documentation](https://flux.kohl.gg/guide/roblox/hydration#available-selectors)
	]]
	Ancestor = makeSelector("FindFirstAncestor") :: QuerySelector,
	--[[
	Selects the first ancestor of class `className` via
	[`Instance:FindFirstAncestorOfClass`](https://create.roblox.com/docs/reference/engine/classes/Instance#FindFirstAncestorOfClass)
	and applies the property table to it.

	[Open Documentation](https://flux.kohl.gg/guide/roblox/hydration#available-selectors)
	]]
	AncestorClass = makeSelector("FindFirstAncestorOfClass") :: ClassSelector,
	--[[
	Selects the first ancestor matching `IsA(className)` via
	[`Instance:FindFirstAncestorWhichIsA`](https://create.roblox.com/docs/reference/engine/classes/Instance#FindFirstAncestorWhichIsA)
	and applies the property table to it.

	[Open Documentation](https://flux.kohl.gg/guide/roblox/hydration#available-selectors)
	]]
	AncestorIsA = makeSelector("FindFirstAncestorWhichIsA") :: ClassSelector,
	--[[
	Selects the first direct child named `name` via
	[`Instance:FindFirstChild`](https://create.roblox.com/docs/reference/engine/classes/Instance#FindFirstChild)
	and applies the property table to it.

	[Open Documentation](https://flux.kohl.gg/guide/roblox/hydration#instance-selectors-flux-find)
	]]
	Child = makeSelector("FindFirstChild") :: QuerySelector,
	--[[
	Selects the first direct child of class `className` via
	[`Instance:FindFirstChildOfClass`](https://create.roblox.com/docs/reference/engine/classes/Instance#FindFirstChildOfClass)
	and applies the property table to it.

	[Open Documentation](https://flux.kohl.gg/guide/roblox/hydration#available-selectors)
	]]
	ChildClass = makeSelector("FindFirstChildOfClass") :: ClassSelector,
	--[[
	Selects the first direct child matching `IsA(className)` via
	[`Instance:FindFirstChildWhichIsA`](https://create.roblox.com/docs/reference/engine/classes/Instance#FindFirstChildWhichIsA)
	and applies the property table to it.

	[Open Documentation](https://flux.kohl.gg/guide/roblox/hydration#available-selectors)
	]]
	ChildIsA = makeSelector("FindFirstChildWhichIsA") :: ClassSelector,
	--[[
	Selects the first descendant named `name` via `Instance:FindFirstChild(name, true)` and applies the property
	table to it.

	[Open Documentation](https://flux.kohl.gg/guide/roblox/hydration#instance-selectors-flux-find)
	]]
	Descendant = makeSelector(function(instance: Instance, name: string): Instance?
		return instance:FindFirstChild(name, true)
	end) :: QuerySelector,
	--[[
	Selects the target's [`Instance.Parent`](https://create.roblox.com/docs/reference/engine/classes/Instance#Parent)
	and applies the property table to it (`Find.Parent() { ... }`).

	[Open Documentation](https://flux.kohl.gg/guide/roblox/hydration#instance-selectors-flux-find)
	]]
	Parent = makeSelector(indexParent) :: ParentSelector,
	--[[
	Walks a `.`-separated child path from the target (`Parent` or `^` climbs to `Instance.Parent`) and applies the
	property table to the final [`Instance`](https://create.roblox.com/docs/reference/engine/classes/Instance).

	[Open Documentation](https://flux.kohl.gg/guide/roblox/hydration#instance-selectors-flux-find)
	]]
	Path = makeSelector(findPath) :: QuerySelector,
	--[[
	Selects every descendant matching a Roblox query string via
	[`Instance:QueryDescendants`](https://create.roblox.com/docs/reference/engine/classes/Instance#QueryDescendants)
	and applies the property table to each match.

	[Open Documentation](https://flux.kohl.gg/guide/roblox/hydration#instance-selectors-flux-find)
	]]
	Query = makeSelector("QueryDescendants") :: QuerySelector,
	--[[
	Selects the first descendant matching a Roblox query string via
	[`Instance:QueryDescendants`](https://create.roblox.com/docs/reference/engine/classes/Instance#QueryDescendants)
	and applies the property table to it.

	[Open Documentation](https://flux.kohl.gg/guide/roblox/hydration#instance-selectors-flux-find)
	]]
	QueryFirst = makeSelector(queryFirst) :: QuerySelector,
})

-- Split ---------------------------------------------------------------------------------------------------------------

-- `T` with every property optional.
--- @ignore
export type function Partial(t: type): type
	if not t:is("table") then
		return t
	end
	local result = types.newtable()
	for key, prop in t:properties() do
		local valueType = prop.read or prop.write
		if valueType then
			result:setproperty(key, types.optional(valueType))
		end
	end
	local indexer = t:indexer()
	if indexer then
		result:setindexer(indexer.index, indexer.readresult)
	end
	return result
end

--- @ignore
type function groupKeys(group: type): type
	local keys = types.newtable()
	if group:is("nil") then
		return keys
	elseif group:is("union") or group:is("intersection") then
		for _, part in group:components() do
			local partKeys = groupKeys(part)
			if partKeys:is("string") then
				return partKeys
			end
			for key in partKeys:properties() do
				keys:setproperty(key, key)
			end
		end
		return keys
	elseif not group:is("table") then
		return types.string
	end
	local indexer = group:indexer()
	if indexer then
		local result = indexer.readresult
		for _, part in if result:is("union") then result:components() else { result } do
			local name = if part:is("singleton") then part:value() else nil
			if type(name) == "string" then
				keys:setproperty(part, part)
			elseif name ~= true then
				return types.string
			end
		end
	end
	for key in group:properties() do
		keys:setproperty(key, key)
	end
	return keys
end

--- @ignore
type function pickWhere(t: type, group: type, prior: type, inGroup: type): type
	if not t:is("table") then
		return t
	end
	local wanted, excluded = groupKeys(group), groupKeys(prior)
	local wantAll = inGroup:is("singleton") and inGroup:value() == false
	if wanted:is("string") or excluded:is("string") then
		return Partial(t)
	end
	local function has(names: type, key: type): boolean
		return names:readproperty(key) ~= nil
	end
	local result = types.newtable()
	for key, prop in t:properties() do
		local valueType = prop.read or prop.write
		local inWanted = has(wanted, key)
		if valueType and not has(excluded, key) and inWanted ~= wantAll then
			result:setproperty(key, valueType)
		end
	end
	local indexer = t:indexer()
	if indexer and wantAll then
		result:setindexer(indexer.index, indexer.readresult)
	end
	return result
end

-- The members of `T` a `split` group named by `G` receives. Required members stay required. When the names are only known as `string` (an unannotated array), every member is optional.
--- @ignore
export type Pick<T, G> = pickWhere<T, G, nil, true>
-- The members of `T` that no `split` group took: properties forwarded to the root instance.
--- @ignore
export type Omit<T, G> = pickWhere<T, nil, G, false>

local function split(props: any, keys: any, ...: any): ...any
	if keys == nil and select("#", ...) == 0 then
		return if type(props) == "table" then table.clone(props) else {}
	elseif select("#", ...) == 0 then
		local own = {}
		local rest = {}
		if type(props) == "table" then
			if keys[1] ~= nil then
				for _, key in keys do
					local val = props[key]
					if val ~= nil then
						own[key] = val
					end
				end
				for key, value in props do
					if own[key] == nil then
						rest[key] = value
					end
				end
			else
				for key, value in props do
					local target = if keys[key] ~= nil then own else rest
					target[key] = value
				end
			end
		end
		return own, rest
	end

	local groups = table.pack(keys, ...)
	local count = groups.n
	local owners: { [any]: number } = {}
	local results: any = {}

	for index = 1, count do
		results[index] = {}
		local group = groups[index]
		if group[1] ~= nil then
			for _, key in group do
				if owners[key] == nil then
					owners[key] = index
				end
			end
		else
			for key in group do
				if owners[key] == nil then
					owners[key] = index
				end
			end
		end
	end

	local rest = {}
	results[count + 1] = rest
	if type(props) == "table" then
		for key, value in props do
			local owner = owners[key]
			local target = if owner ~= nil then results[owner] else rest
			target[key] = value
		end
	end

	return table.unpack(results, 1, count + 1)
end

type Split =
	(<T>(props: T?) -> T)
	& (<T, G>(props: T?, keys: G) -> (Pick<T, G>, Omit<T, G>))
	& (<T>(props: T?, first: { [any]: any }, second: { [any]: any }, ...{ [any]: any }) -> ...Partial<T>)

-- Edit & Construct ----------------------------------------------------------------------------------------------------

local function bindModel(node: any, instance: Instance, property: string, _CLEAN: { any }, isAttribute: boolean)
	table.insert(_CLEAN, bindTo(node, instance, property, isAttribute))
	local _, disconnect = bindFrom(node, instance, property, isAttribute)
	table.insert(_CLEAN, disconnect)
	attachToBinding(instance, property, isAttribute, disconnect)
end

local tagCounts: { [Instance]: { [string]: number } } = setmetatable({}, { __mode = "k" })

local function addTagRef(instance: Instance, tag: string)
	local counts = tagCounts[instance]
	if not counts then
		counts = {}
		tagCounts[instance] = counts
	end
	local count = counts[tag]
	counts[tag] = (count or 0) + 1
	if not count then
		instance:AddTag(tag)
	end
end

local function removeTagRef(instance: Instance, tag: string)
	local counts = tagCounts[instance]
	local count = if counts then counts[tag] else nil
	if count and count > 1 then
		counts[tag] = count - 1
	else
		if counts then
			counts[tag] = nil
		end
		instance:RemoveTag(tag)
	end
end

local function bindTag(instance: Instance, tagValue: any, _CLEAN: { any })
	if type(tagValue) == "string" then
		addTagRef(instance, tagValue)
		return
	elseif type(tagValue) == "function" then
		tagValue = newNode(tagValue)
		table.insert(_CLEAN, tagValue)
	end

	if isNode(tagValue) then
		local node = tagValue :: Graph.Node<any>
		local currentSet: { [string]: boolean } = {}

		local function updateTags(newTag: string | { string })
			local newSet: { [string]: boolean } = {}
			if type(newTag) == "table" then
				for _, tag in newTag do
					newSet[tag] = true
				end
			elseif type(newTag) == "string" then
				newSet[newTag] = true
			end
			for tag in newSet do
				if not currentSet[tag] then
					addTagRef(instance, tag)
				end
			end
			for tag in currentSet do
				if not newSet[tag] then
					removeTagRef(instance, tag)
				end
			end
			currentSet = newSet
		end

		updateTags(node:peek())
		table.insert(
			_CLEAN,
			effect(function()
				updateTags(get(node))
			end)
		)
	elseif type(tagValue) == "table" then
		for _, value in tagValue do
			bindTag(instance, value, _CLEAN)
		end
	end
end

local function stripUnmanagedTag(instance: Instance, tag: string)
	local counts = tagCounts[instance]
	if (not counts or not counts[tag]) and instance:HasTag(tag) then
		instance:RemoveTag(tag)
	end
end

local namedTagClaims: { [Instance]: { [string]: () -> () } } = setmetatable({}, { __mode = "k" })

local function releaseNamedTag(instance: Instance, tag: string)
	local claims = namedTagClaims[instance]
	if not claims then
		return
	end
	local release = claims[tag]
	if not release then
		return
	end
	claims[tag] = nil
	if next(claims) == nil then
		namedTagClaims[instance] = nil
	end
	release()
end

local function claimNamedTag(instance: Instance, tag: string, release: () -> ())
	local claims = namedTagClaims[instance]
	if not claims then
		claims = {}
		namedTagClaims[instance] = claims
	end
	claims[tag] = release
end

local function bindNamedTag(instance: Instance, tag: string, tagValue: any, _CLEAN: { any })
	if isModel(tagValue) then
		local modelNode = tagValue[2]
		bindNamedTag(instance, tag, modelNode, _CLEAN)
		modelNode:set(instance:HasTag(tag))
		local disconnect = Bind.bindDestroy(
			modelNode,
			onTagChanged(instance, tag, function(hasTag)
				modelNode:set(hasTag)
			end)
		)
		table.insert(_CLEAN, disconnect)
		local claims = namedTagClaims[instance]
		local prevRelease = claims and claims[tag]
		if prevRelease then
			claims[tag] = function()
				disconnect()
				prevRelease()
			end
		end
		return
	end

	releaseNamedTag(instance, tag)

	local made: Graph.Node<any>? = nil
	if type(tagValue) == "function" then
		made = newNode(tagValue)
		tagValue = made
		table.insert(_CLEAN, made)
	end

	if isNode(tagValue) then
		local node = tagValue :: Graph.Node<any>
		local active = not not node:peek()
		if active then
			addTagRef(instance, tag)
		else
			stripUnmanagedTag(instance, tag)
		end
		local eff = effect(function()
			local shouldHave = not not get(node)
			if shouldHave ~= active then
				active = shouldHave
				if shouldHave then
					addTagRef(instance, tag)
				else
					removeTagRef(instance, tag)
				end
			elseif not shouldHave then
				stripUnmanagedTag(instance, tag)
			end
		end)
		table.insert(_CLEAN, eff)
		claimNamedTag(instance, tag, function()
			eff:Destroy()
			if made then
				made:Destroy()
			end
			if active then
				active = false
				removeTagRef(instance, tag)
			end
		end)
	elseif tagValue then
		addTagRef(instance, tag)
		local released = false
		claimNamedTag(instance, tag, function()
			if not released then
				released = true
				removeTagRef(instance, tag)
			end
		end)
	else
		stripUnmanagedTag(instance, tag)
	end
end

local function applyBindingOrValue(
	instance: Instance,
	name: any,
	value: any,
	isAttribute: boolean,
	seen: { [any]: boolean }?,
	_CLEAN: { any }
)
	if seen then
		if seen[name] then
			return
		end
		seen[name] = true
	end

	local made = nil
	if type(value) == "function" then
		value = newNode(value)
		made = value
		table.insert(_CLEAN, value)
	end

	if isModel(value) then
		if not isAttribute and name == "LayoutOrder" then
			Bind.pinOrder(instance)
		end
		bindModel(value[2], instance, name, _CLEAN, isAttribute)
	elseif isNode(value) then
		if not isAttribute and name == "LayoutOrder" then
			Bind.pinOrder(instance)
		end
		table.insert(_CLEAN, bindTo(value, instance, name, isAttribute))
		if made then
			attachToBinding(instance, name, isAttribute, made)
		end
	elseif isAttribute then
		releaseBinding(instance, name, true)
		setAttribute(instance, name, value)
	else
		releaseBinding(instance, name, false)
		setProperty(instance, name, value)
		if name == "LayoutOrder" and value == 0 then
			Bind.pinOrder(instance)
		end
	end
end

local function connectChanged(
	instance: Instance,
	name: string,
	isAttribute: boolean,
	isTag: boolean,
	value: any,
	label: string,
	_CLEAN: { any }
)
	if isNode(value) then
		error(
			`{label} is a node: use Flux.model(node) for two-way binding or Flux.property(instance, prop) to follow a property`,
			0
		)
	elseif type(value) ~= "function" then
		error(`{label} expects a function called with the new value, got {compatTypeof(value)}`, 0)
	end
	local rawInstance: any = instance
	if not isAttribute and not isTag and kindOf(rawInstance[name]) == "RBXScriptSignal" then
		error(`{label} is an event, not a property: connect \`{name}\` as a top-level key`, 0)
	end
	if isTag then
		table.insert(_CLEAN, onTagChanged(instance, name, bindContext(value)))
	else
		table.insert(_CLEAN, onChanged(instance, name, isAttribute, bindContext(value)))
	end
end

local function applyPrefixKey(
	instance: Instance,
	property: string,
	value: any,
	seenAttrs: { [any]: boolean }?,
	seenProps: { [any]: boolean }?,
	_CLEAN: { any }
)
	local second = string.byte(property, 2)
	if second == 97 and string.sub(property, 1, 6) == "_attr_" then
		local attrName = string.sub(property, 7)
		if attrName == "" then
			error('attribute name after "_attr_" cannot be empty', 0)
		end
		applyBindingOrValue(instance, attrName, value, true, seenAttrs, _CLEAN)
		return
	elseif second == 116 and string.sub(property, 1, 5) == "_tag_" then
		local tagName = string.sub(property, 6)
		if tagName == "" then
			error('tag name after "_tag_" cannot be empty', 0)
		end
		if seenProps then
			if seenProps[property] then
				return
			end
			seenProps[property] = true
		end
		bindNamedTag(instance, tagName, value, _CLEAN)
		return
	end

	if second == nil then
		error('property name after "_" cannot be empty', 0)
	end
	local name = string.sub(property, 2)
	local isAttr = false
	local isTag = false
	if second == 95 then
		if string.sub(property, 1, 7) == "__attr_" then
			name = string.sub(property, 8)
			if name == "" then
				error('attribute name after "__attr_" cannot be empty', 0)
			end
			isAttr = true
		elseif string.sub(property, 1, 6) == "__tag_" then
			name = string.sub(property, 7)
			if name == "" then
				error('tag name after "__tag_" cannot be empty', 0)
			end
			isTag = true
		end
	end
	if seenProps then
		if seenProps[property] then
			return
		end
		seenProps[property] = true
	end
	connectChanged(instance, name, isAttr, isTag, value, `"{property}"`, _CLEAN)
end

local function applyDirectives(
	instance: Instance,
	properties: Type.Map<any>,
	seenAttrs: { [any]: boolean }?,
	_CLEAN: { any }
)
	local _ATTR = properties.__ATTR
	if _ATTR then
		for attrName, attrVal in _ATTR do
			applyBindingOrValue(instance, attrName, attrVal, true, seenAttrs, _CLEAN)
		end
	end

	local _TAG = properties.__TAG
	if _TAG then
		bindTag(instance, _TAG, _CLEAN)
	end

	local _EVENT = properties.__EVENT
	if _EVENT then
		local _EVENT_ATTR = _EVENT.__ATTR
		local _EVENT_TAG = _EVENT.__TAG
		for property, value in _EVENT do
			if property == "__ATTR" or property == "__TAG" then
				continue
			end
			connectChanged(instance, property, false, false, value, `__EVENT.{property}`, _CLEAN)
		end
		if _EVENT_ATTR then
			for attribute, value in _EVENT_ATTR do
				connectChanged(instance, attribute, true, false, value, `__EVENT.__ATTR.{attribute}`, _CLEAN)
			end
		end
		if _EVENT_TAG then
			for tag, value in _EVENT_TAG do
				connectChanged(instance, tag, false, true, value, `__EVENT.__TAG.{tag}`, _CLEAN)
			end
		end
	end
end

local function finalizeEdit(
	instance: Instance,
	properties: Type.Map<any>,
	childKeys: { number }?,
	actions: { any }?,
	signals: { any }?,
	parent: any,
	seenAttrs: { [any]: boolean }?,
	seenProps: { [any]: boolean }?,
	_CLEAN: { any },
	inheritedClean: { any }?,
	order: number,
	applyEdit: (
		Instance,
		Type.Map<any>,
		{ [any]: boolean }?,
		{ [any]: boolean }?,
		{ any }?,
		number?
	) -> number
): number
	if childKeys then
		if #childKeys > 1 then
			table.sort(childKeys)
		end
		for _, key in childKeys do
			local child: any = properties[key]
			if kindOf(child) == "Instance" then
				order = Bind.applyLayoutOrder(child, order)
				child.Parent = instance
			elseif isNode(child) then
				table.insert(_CLEAN, Bind.children(child, instance, order))
				order += 1
			elseif child[1] == FIND_SYMBOL then
				resolveFind(child, instance, applyEdit)
			else
				order = applyEdit(instance, child, seenAttrs, seenProps, _CLEAN, order)
			end
		end
	end

	local _REF: any = properties.__REF
	if _REF then
		if type(_REF) == "function" then
			local callRef: (Instance) -> any = _REF
			local refClean = callRef(instance)
			if refClean ~= nil then
				table.insert(_CLEAN, refClean)
			end
		elseif isNode(_REF) then
			_REF:set(instance)
		end
	end

	if actions then
		for _, action in actions do
			task.defer(bindContext(action), instance)
		end
	end

	if signals then
		for index = 1, #signals, 2 do
			local connected: any = signals[index]:Connect(bindContext(signals[index + 1]))
			table.insert(_CLEAN, connected)
		end
	end

	local madeParent = nil
	if type(parent) == "function" then
		parent = newNode(parent)
		madeParent = parent
		table.insert(_CLEAN, parent)
	end
	local parentIsNode = isNode(parent)

	if not inheritedClean and (parentIsNode or next(_CLEAN) ~= nil) then
		local function cleanAll()
			dispose(_CLEAN)
			table.clear(_CLEAN)
		end
		table.insert(_CLEAN, instance.Destroying:Once(cleanAll))
		if getOwner() then
			cleanup(cleanAll)
		end
	end

	if parent then
		if parentIsNode then
			table.insert(_CLEAN, bindTo(parent, instance, "Parent", false))
			if madeParent then
				attachToBinding(instance, "Parent", false, madeParent)
			end
		else
			releaseBinding(instance, "Parent", false)
			instance.Parent = parent
		end
	end

	return order
end

local function ensureFlattenSeen(properties: Type.Map<any>): ({ [any]: boolean }, { [any]: boolean })
	local nextAttrs: { [any]: boolean } = {}
	local _ATTR = properties.__ATTR
	if _ATTR then
		for attrName in _ATTR do
			nextAttrs[attrName] = true
		end
	end
	local nextProps: { [any]: boolean } = {}
	for key in properties do
		if type(key) ~= "number" then
			nextProps[key] = true
			if type(key) == "string" and string.sub(key, 1, 6) == "_attr_" then
				nextAttrs[string.sub(key, 7)] = true
			end
		end
	end
	return nextAttrs, nextProps
end

local function edit(
	instance: Instance,
	properties: Type.Map<any>,
	seenAttrs: { [any]: boolean }?,
	seenProps: { [any]: boolean }?,
	inheritedClean: { any }?,
	startOrder: number?
): number
	local actions: { any }? = nil
	local signals: { any }? = nil
	local childKeys: { number }? = nil
	local hasFlatten = false
	local order = startOrder or 1
	local rawInstance: any = instance
	local applyEdit: any = edit
	local _USER_CLEAN = properties.__CLEAN
	local _CLEAN = inheritedClean or {}
	if _USER_CLEAN ~= nil then
		table.insert(_CLEAN, _USER_CLEAN)
	end
	local parent = properties.Parent
	if parent and seenProps then
		if seenProps.Parent then
			parent = nil
		else
			seenProps.Parent = true
		end
	end
	for property, value in properties do
		if
			property == "Parent"
			or property == "__TAG"
			or property == "__ATTR"
			or property == "__CLEAN"
			or property == "__EVENT"
			or property == "__REF"
		then
			continue
		end
		local propType = type(property)
		if propType == "string" then
			if string.byte(property) == 95 then
				applyPrefixKey(instance, property, value, seenAttrs, seenProps, _CLEAN)
				continue
			end
		elseif propType == "number" and property == math.floor(property) then
			if kindOf(value) == "Instance" then
				childKeys = childKeys or {}
				table.insert(childKeys :: { number }, property)
			elseif type(value) == "function" then
				actions = actions or {}
				table.insert(actions :: { any }, value)
			elseif type(value) == "table" then
				if not isModel(value) then
					if value[1] ~= FIND_SYMBOL and not isNode(value) then
						hasFlatten = true
					end
					childKeys = childKeys or {}
					table.insert(childKeys :: { number }, property)
				end
			end
			continue
		end
		if type(value) == "function" then
			local signal = rawInstance[property]
			if kindOf(signal) == "RBXScriptSignal" then
				signals = signals or {}
				table.insert(signals :: { any }, signal)
				table.insert(signals :: { any }, value)
				continue
			end
		end
		applyBindingOrValue(instance, property, value, false, seenProps, _CLEAN)
	end
	applyDirectives(instance, properties, seenAttrs, _CLEAN)
	if hasFlatten and not seenAttrs then
		seenAttrs, seenProps = ensureFlattenSeen(properties)
	end
	return finalizeEdit(
		instance,
		properties,
		childKeys,
		actions,
		signals,
		parent,
		seenAttrs,
		seenProps,
		_CLEAN,
		inheritedClean,
		order,
		applyEdit
	)
end

local function editInstance(instance: Instance, properties: Type.Map<any>): Instance
	edit(instance, properties)
	return instance
end

local ALWAYS: { [string]: { [string]: unknown } } = {
	TextButton = { AutoButtonColor = false },
	ImageButton = { AutoButtonColor = false },
}

local function assign(instance: Instance, values: { [string]: unknown }?)
	if values then
		local rawInstance: any = instance
		for key, value in values do
			rawInstance[key] = value
		end
	end
end

local function new(className: string, properties: any): Instance
	local instance = Compat.Instance.new(className)
	assign(instance, ALWAYS[className])
	assign(instance, if Flags.defaults then Defaults[className] else nil)
	if getOwner() then
		cleanup(instance)
	end
	return editInstance(instance, properties)
end

return table.freeze({
	edit = editInstance,
	new = new,
	Flags = Flags,
	Defaults = Defaults,
	Find = Find,
	--[[
	Partitions `props` into one table per `keys` group plus a final table holding every remaining key, leaving `props`
	untouched. Pass a schema table or an annotated key-literal array (`{ "label" | "onClick" }`) to preserve exact
	`Pick`/`Omit` types on a single group.

	```luau
	local OWN: { "label" | "onClick" } = { "label", "onClick" }
	local own, rest = Flux.split(props, OWN)
	```

	[Open Documentation](https://flux.kohl.gg/guide/concepts/components#splitting-props-with-flux-split)
	]]
	split = split :: Split,
})
