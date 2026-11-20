--!strict
local Bind = require("./Bind")
local Compat = require("./Compat")
local Graph = require("./Graph")
local Type = require("./Type")

local IS_ROBLOX = Compat.isRoblox
local Color3 = Compat.Color3
local Enum = Compat.Enum
local Vector3 = Compat.Vector3
local compatTypeof = Compat.typeof
local task = Compat.task
local warn = Compat.warn

local dispose = Graph.dispose
local get = Graph.Node.get
local isolate = Graph.isolate
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

	[Open Documentation](https://flux.kohl.gg/guide/roblox/defaults#disabling-defaults)
	]]
	defaults = true,
}

local Defaults: { [string]: { [string]: unknown } } = {}
if Color3 ~= nil and Enum ~= nil and Vector3 ~= nil then
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

	Defaults = {
		Part = {
			Material = Enum.Material.SmoothPlastic,
			Size = Vector3.new(1, 1, 1),
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
		ImageButton = guiBase({ AutoButtonColor = false }),
		ImageLabel = guiBase(),
		VideoFrame = guiBase(),
		ViewportFrame = guiBase(),
		ScrollingFrame = guiBase({ ScrollBarImageColor3 = BLACK }),
		TextBox = textBase({ ClearTextOnFocus = false }),
		TextButton = textBase({ AutoButtonColor = false }),
		TextLabel = textBase(),
		UIListLayout = { SortOrder = Enum.SortOrder.LayoutOrder },
		UIGridLayout = { SortOrder = Enum.SortOrder.LayoutOrder },
		UITableLayout = { SortOrder = Enum.SortOrder.LayoutOrder },
		UIPageLayout = { SortOrder = Enum.SortOrder.LayoutOrder },
	}
end

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

-- A handle returned by `Flux.portal(target, children)` that mounts UI into `target`.
--- @ignore
export type Portal = Bind.Portal
-- A component schema marker returned by `Flux.prop(default)`.
--- @ignore
export type DefaultProp<T> = Type.DefaultProp<T>

-- `T` with every property optional.
--- @ignore
export type Partial<T> = Type.Partial<T>

-- The members of `T` a `split` group named by `G` receives. Required members stay required. When the names are only known as `string` (an unannotated array), every member is optional.
--- @ignore
export type Pick<T, G> = Type.Pick<T, G>
-- The members of `T` that no `split` group took: properties forwarded to the root instance.
--- @ignore
export type Omit<T, G> = Type.Omit<T, G>

local PROP_DEFAULT: any = table.freeze({ type = "PropDefault" })
local mergeSources: { [any]: { n: number, [number]: any } } = setmetatable({}, { __mode = "k" })

local MergeMT: { [string]: any } = {
	__index = function(self: any, key: any): any
		local sources = mergeSources[self]
		if sources == nil then
			return nil
		end
		for index = sources.n, 1, -1 do
			local source = sources[index]
			if source ~= nil then
				local value = source[key]
				if value ~= nil then
					return value
				end
			end
		end
		return nil
	end,
	__newindex = function()
		error("Flux.merge tables are read-only", 2)
	end,
	__len = function(self: any): number
		local sources = mergeSources[self]
		if sources == nil then
			return 0
		end
		local maxLen = 0
		for index = 1, sources.n do
			local source = sources[index]
			if source ~= nil then
				local len = #source
				if len > maxLen then
					maxLen = len
				end
			end
		end
		return maxLen
	end,
	__iter = function(self: any)
		local sources = mergeSources[self]
		local snap: { [any]: any } = {}
		if sources ~= nil then
			for index = 1, sources.n do
				local source = sources[index]
				if source ~= nil then
					for key, value in source do
						snap[key] = value
					end
				end
			end
		end
		return next, snap
	end,
}

local function merge(...: any): any
	local count = select("#", ...)
	for index = 1, count do
		local source = select(index, ...)
		if source ~= nil and type(source) ~= "table" then
			error(`Flux.merge expects tables or nil, got {compatTypeof(source)}`, 2)
		end
	end
	local proxy = setmetatable({}, MergeMT)
	mergeSources[proxy] = table.pack(...)
	return proxy
end

type MergeProps = <A, B, C, D>(a: A & {}, b: (B & {})?, c: (C & {})?, d: (D & {})?) -> Type.MergeTables<A, B, C, D>

local function clonePlainDefault(value: any, seen: { [any]: any }?): any
	if type(value) ~= "table" or getmetatable(value) ~= nil or table.isfrozen(value) then
		return value
	end
	if seen and seen[value] ~= nil then
		return seen[value]
	end
	local copy = table.clone(value)
	local nextSeen = seen
	if nextSeen ~= nil then
		nextSeen[value] = copy
	end
	for k, v in copy do
		if type(v) == "table" and getmetatable(v) == nil and not table.isfrozen(v) then
			if nextSeen == nil then
				nextSeen = { [value] = copy }
			end
			copy[k] = clonePlainDefault(v, nextSeen)
		end
	end
	return copy
end

local function isKeyList(group: { [any]: any }): boolean
	local first = group[1]
	if first == nil then
		return false
	end
	return first ~= true and (type(first) ~= "table" or rawget(first, 1) ~= PROP_DEFAULT)
end

local function applySchemaDefaults(own: { [any]: any }, schema: { [any]: any })
	for key, spec in schema do
		if own[key] == nil and type(spec) == "table" and rawget(spec, 1) == PROP_DEFAULT then
			own[key] = clonePlainDefault(rawget(spec, 2))
		end
	end
end

local function split(props: any, keys: any, ...: any): ...any
	if keys == nil and select("#", ...) == 0 then
		if type(props) ~= "table" then
			return {}
		elseif getmetatable(props) ~= nil then
			local out: { [any]: any } = {}
			for key, value in props do
				out[key] = value
			end
			return out
		end
		return table.clone(props)
	elseif select("#", ...) == 0 then
		if type(keys) ~= "table" then
			return {}, split(props, nil)
		end
		local own = {}
		local rest = {}
		if isKeyList(keys) then
			if type(props) == "table" then
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
			end
		else
			if type(props) == "table" then
				for key, value in props do
					local target = if keys[key] ~= nil then own else rest
					target[key] = value
				end
			end
			applySchemaDefaults(own, keys)
		end
		return own, rest
	end

	local groups = table.pack(keys, ...)
	local count = groups.n
	local owners: { [any]: number } = {}
	local isSchemaGroup: { [number]: boolean } = {}
	local results: any = {}

	for index = 1, count do
		results[index] = {}
		local group = groups[index]
		if type(group) ~= "table" then
			isSchemaGroup[index] = false
			continue
		end
		local keyList = isKeyList(group)
		isSchemaGroup[index] = not keyList
		if keyList then
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

	for index = 1, count do
		if isSchemaGroup[index] then
			local group = groups[index]
			local target = results[index]
			for key, spec in group do
				if
					owners[key] == index
					and target[key] == nil
					and type(spec) == "table"
					and rawget(spec, 1) == PROP_DEFAULT
				then
					target[key] = clonePlainDefault(rawget(spec, 2))
				end
			end
		end
	end

	return table.unpack(results, 1, count + 1)
end

type Split =
	(<T>(props: T) -> Type.CloneProps<T>)
	& (<T, G>(props: T, keys: G) -> (Pick<T, G>, Omit<T, G>))
	& (<T>(props: T, first: { [any]: any }, second: { [any]: any }, ...{ [any]: any }) -> ...Partial<T>)

-- Marks a key in a component prop schema at runtime; pair with a type cast (`Flux.prop() :: Flux.Reactive<string>`)
-- or pass a `default` value (`Flux.prop(16)`).
type Prop = (() -> any) & (<T>(default: T) -> Type.DefaultProp<T>)

local function prop(...: any): any
	if select("#", ...) == 0 then
		return true
	end
	local default = select(1, ...)
	if default == nil then
		return true
	end
	return table.freeze({ PROP_DEFAULT, default })
end

type Own = <A, B, C, D>(a: (A & {})?, b: (B & {})?, c: (C & {})?, d: (D & {})?) -> Type.MergeOwn<A, B, C, D>

local function own(...: { [string]: any }): any
	local schema = {}
	for index = 1, select("#", ...) do
		local part: any = select(index, ...)
		if part ~= nil then
			if type(part) ~= "table" then
				error(`Flux.own expected table at argument #{index}, got {compatTypeof(part)}`, 2)
			end
			for key, value in part do
				schema[key] = value
			end
		end
	end
	return table.freeze(schema)
end

-- Edit & Construct ----------------------------------------------------------------------------------------------------

local function bindModel(node: any, instance: Instance, property: string, _CLEAN: { any }, isAttribute: boolean)
	table.insert(_CLEAN, bindTo(node, instance, property, isAttribute))
	local _, disconnect = bindFrom(node, instance, property, isAttribute)
	table.insert(_CLEAN, disconnect)
	attachToBinding(instance, property, isAttribute, disconnect)
end

local tagCounts: { [Instance]: { [string]: number } } = setmetatable({}, { __mode = "k" })

local function rawAddTag(instance: Instance, tag: string)
	instance:AddTag(tag)
end

local function rawRemoveTag(instance: Instance, tag: string)
	instance:RemoveTag(tag)
end

local function addTagRef(instance: Instance, tag: string)
	local counts = tagCounts[instance]
	if not counts then
		counts = {}
		tagCounts[instance] = counts
	end
	local count = counts[tag]
	counts[tag] = (count or 0) + 1
	if not count then
		isolate(rawAddTag, instance, tag)
	end
end

local function decrementTagRef(instance: Instance, tag: string): boolean
	local counts = tagCounts[instance]
	local count = if counts then counts[tag] else nil
	if count and count > 1 then
		counts[tag] = count - 1
		return false
	end
	if counts then
		counts[tag] = nil
		if next(counts) == nil then
			tagCounts[instance] = nil
		end
	end
	return true
end

local function removeTagRef(instance: Instance, tag: string)
	if decrementTagRef(instance, tag) then
		isolate(rawRemoveTag, instance, tag)
	end
end

local function releaseTagRefOnly(instance: Instance, tag: string)
	decrementTagRef(instance, tag)
end

local function bindTag(instance: Instance, tagValue: any, _CLEAN: { any })
	if type(tagValue) == "string" then
		addTagRef(instance, tagValue)
		local released = false
		table.insert(_CLEAN, function()
			if not released then
				released = true
				releaseTagRefOnly(instance, tagValue)
			end
		end)
		return
	elseif isModel(tagValue) then
		error("__TAG does not accept Flux.model; use _tag_Name = Flux.model(node) for a two-way tag", 0)
	elseif type(tagValue) == "function" then
		tagValue = newNode(tagValue)
		table.insert(_CLEAN, tagValue)
	end

	if isNode(tagValue) then
		local node = tagValue :: Graph.Node<any>
		local currentSet: { [string]: boolean } = {}
		local disposed = false

		local function updateTags(newTag: string | { string })
			if disposed then
				return
			end
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
		table.insert(_CLEAN, function()
			if disposed then
				return
			end
			disposed = true
			for tag in currentSet do
				releaseTagRefOnly(instance, tag)
			end
			table.clear(currentSet)
		end)
	elseif type(tagValue) == "table" then
		for _, value in tagValue do
			bindTag(instance, value, _CLEAN)
		end
	end
end

local function stripUnmanagedTag(instance: Instance, tag: string)
	local counts = tagCounts[instance]
	if (not counts or not counts[tag]) and instance:HasTag(tag) then
		isolate(rawRemoveTag, instance, tag)
	end
end

local namedTagClaims: { [Instance]: { [string]: (strip: boolean) -> () } } = setmetatable({}, { __mode = "k" })

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
	release(true)
end

local function cleanupNamedTag(instance: Instance, tag: string, release: (strip: boolean) -> ())
	local claims = namedTagClaims[instance]
	if claims and claims[tag] == release then
		claims[tag] = nil
		if next(claims) == nil then
			namedTagClaims[instance] = nil
		end
		release(false)
	end
end

local function claimNamedTag(instance: Instance, tag: string, release: (strip: boolean) -> (), _CLEAN: { any })
	local claims = namedTagClaims[instance]
	if not claims then
		claims = {}
		namedTagClaims[instance] = claims
	end
	claims[tag] = release
	table.insert(_CLEAN, function()
		cleanupNamedTag(instance, tag, release)
	end)
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
			local wrappedRelease = function(strip: boolean)
				disconnect()
				prevRelease(strip)
			end
			claims[tag] = wrappedRelease
			table.insert(_CLEAN, function()
				cleanupNamedTag(instance, tag, wrappedRelease)
			end)
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
		claimNamedTag(instance, tag, function(strip: boolean)
			eff:Destroy()
			if made then
				made:Destroy()
			end
			if active then
				active = false
				if strip then
					removeTagRef(instance, tag)
				else
					releaseTagRefOnly(instance, tag)
				end
			end
		end, _CLEAN)
	elseif tagValue then
		addTagRef(instance, tag)
		local released = false
		claimNamedTag(instance, tag, function(strip: boolean)
			if not released then
				released = true
				if strip then
					removeTagRef(instance, tag)
				else
					releaseTagRefOnly(instance, tag)
				end
			end
		end, _CLEAN)
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
		isolate(setAttribute, instance, name, value)
	else
		releaseBinding(instance, name, false)
		isolate(setProperty, instance, name, value)
		if name == "LayoutOrder" then
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
	isRoot: boolean,
	applyEdit: (
		Instance,
		Type.Map<any>,
		{ [any]: boolean }?,
		{ [any]: boolean }?,
		{ any }?,
		boolean?,
		{ any }?
	) -> any,
	findEdit: (Instance, Type.Map<any>) -> Instance
): any
	if childKeys then
		if #childKeys > 1 then
			table.sort(childKeys)
		end
		for _, key in childKeys do
			local child: any = properties[key]
			if kindOf(child) == "Instance" then
				Bind.placeChildOrder(instance, child)
				child.Parent = instance
			elseif type(child) == "function" then
				if actions == nil then
					actions = {}
				end
				table.insert(actions :: { any }, child)
			elseif isNode(child) then
				table.insert(_CLEAN, Bind.children(child, instance))
			elseif Bind.isPortal(child) then
				table.insert(_CLEAN, Bind.mountPortal(child))
			elseif rawget(child, 1) == FIND_SYMBOL then
				resolveFind(child, instance, findEdit)
			else
				local nestedParent = applyEdit(instance, child, seenAttrs, seenProps, _CLEAN, false, actions)
				if parent == nil and nestedParent ~= nil then
					parent = nestedParent
				end
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

	if signals then
		for index = 1, #signals, 2 do
			local connected: any = signals[index]:Connect(bindContext(signals[index + 1]))
			table.insert(_CLEAN, connected)
		end
	end

	if not isRoot then
		return parent
	end

	local madeParent = nil
	if type(parent) == "function" then
		parent = newNode(parent)
		madeParent = parent
		table.insert(_CLEAN, parent)
	end
	local parentIsNode = isNode(parent)
	local hasActions = actions ~= nil and #actions > 0
	local cleaned = false

	if parentIsNode or next(_CLEAN) ~= nil or hasActions then
		local function cleanAll()
			cleaned = true
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
			isolate(setProperty, instance, "Parent", parent)
		end
	end

	if hasActions and actions ~= nil and not cleaned then
		for _, action in actions do
			table.insert(_CLEAN, task.defer(bindContext(action), instance))
		end
	end

	return nil
end

local function ensureFlattenSeen(
	properties: Type.Map<any>,
	existingAttrs: { [any]: boolean }?,
	existingProps: { [any]: boolean }?
): ({ [any]: boolean }, { [any]: boolean })
	if existingAttrs and existingProps then
		return existingAttrs, existingProps
	end
	local nextAttrs: { [any]: boolean } = existingAttrs or {}
	local _ATTR = properties.__ATTR
	if _ATTR then
		for attrName in _ATTR do
			nextAttrs[attrName] = true
		end
	end
	local nextProps: { [any]: boolean } = existingProps or {}
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

local editInstance: (instance: Instance, properties: Type.Map<any>) -> Instance

local function edit(
	instance: Instance,
	properties: Type.Map<any>,
	seenAttrs: { [any]: boolean }?,
	seenProps: { [any]: boolean }?,
	_CLEAN: { any },
	isRoot: boolean,
	actions: { any }?
): any
	local signals: { any }? = nil
	local childKeys: { number }? = nil
	local hasFlatten = false
	local rawInstance: any = instance
	local applyEdit: any = edit
	local _USER_CLEAN = properties.__CLEAN
	if _USER_CLEAN ~= nil then
		table.insert(_CLEAN, _USER_CLEAN)
	end
	if properties.__ATTR ~= nil and seenAttrs == nil then
		seenAttrs = {}
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
			if kindOf(value) == "Instance" or type(value) == "function" then
				childKeys = childKeys or {}
				table.insert(childKeys :: { number }, property)
			elseif type(value) == "table" then
				if not isModel(value) then
					if rawget(value, 1) ~= FIND_SYMBOL and not Bind.isPortal(value) and not isNode(value) then
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
	if hasFlatten then
		seenAttrs, seenProps = ensureFlattenSeen(properties, seenAttrs, seenProps)
		if isRoot and actions == nil then
			actions = {}
		end
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
		isRoot,
		applyEdit,
		editInstance
	)
end

function editInstance(instance: Instance, properties: Type.Map<any>): Instance
	Compat.requireRoblox("Flux.edit")
	local clean = {}
	local ok, err = (pcall :: (any) -> (boolean, any))(function()
		edit(instance, properties, nil, nil, clean, true, nil)
	end)
	if not ok then
		dispose(clean)
		table.clear(clean)
		error(err, 0)
	end
	return instance
end

local function assign(instance: Instance, values: { [string]: unknown }?)
	if values then
		local rawInstance: any = instance
		for key, value in values do
			rawInstance[key] = value
		end
	end
end

local function new(className: string, properties: any): Instance
	Compat.requireRoblox("Flux.new")
	local instance = Compat.Instance.new(className)
	assign(instance, if Flags.defaults then Defaults[className] else nil)
	local ok, res = pcall(editInstance, instance, properties)
	if not ok then
		instance:Destroy()
		error(res, 0)
	end
	if getOwner() then
		cleanup(instance)
	end
	return res
end

local EMPTY_PORTALS: { any } = table.freeze({} :: { any })

local function collectMountedPortals(item: any, into: { any })
	while isNode(item) do
		item = get(item)
	end
	if item == nil then
		return
	elseif Bind.isPortal(item) then
		table.insert(into, item)
	elseif type(item) == "table" and kindOf(item) ~= "Instance" then
		for _, child in item do
			collectMountedPortals(child, into)
		end
	end
end

local function mountTopPortals(item: any)
	if item == nil then
		return
	elseif Bind.isPortal(item) then
		cleanup(Bind.mountPortal(item))
	elseif isNode(item) then
		local portalData: { portals: any?, nextPortals: any? } = {}
		local stopped = false
		local function stopAll()
			if stopped then
				return
			end
			stopped = true
			Bind.syncPortals(portalData, EMPTY_PORTALS, 0)
		end
		cleanup(stopAll)
		local eff = effect(function()
			if stopped then
				return
			end
			local desired: { any } = {}
			collectMountedPortals(item, desired)
			Bind.syncPortals(portalData, desired, #desired)
		end)
		eff:peek()
	elseif type(item) == "table" and kindOf(item) ~= "Instance" then
		for _, child in item do
			mountTopPortals(child)
		end
	end
end

local function mount(fn: () -> any, target: Graph.Reactive<Instance?>?): () -> ()
	if type(fn) ~= "function" then
		error(`Flux.mount expects a function, got {compatTypeof(fn)}`, 2)
	elseif target ~= nil and kindOf(target) ~= "Instance" and not Graph.isDynamic(target) then
		error(`Flux.mount expects an Instance target, reactive target, or nil, got {compatTypeof(target)}`, 2)
	end

	local root = Graph.scope(function()
		local result = fn()
		if target ~= nil then
			cleanup(Bind.mountPortal(Bind.portal(target, result)))
		elseif result ~= nil then
			mountTopPortals(result)
		end
	end)

	local done = false
	local targetConn: RBXScriptConnection? = nil
	local function disconnectTarget()
		if targetConn ~= nil then
			targetConn:Disconnect()
			targetConn = nil
		end
	end
	local function unmount()
		if done then
			return
		end
		done = true
		disconnectTarget()
		root:Destroy()
	end

	root:onDestroy(disconnectTarget)
	if target ~= nil and kindOf(target) == "Instance" then
		targetConn = (target :: Instance).Destroying:Once(unmount)
	end
	return unmount
end

return table.freeze({
	edit = editInstance,
	new = new,
	--[[
	Runs `fn` inside a new root [scope](https://flux.kohl.gg/guide/concepts/scopes), mounts the returned UI into `target` (or mounts returned portals when `target` is omitted), and returns an idempotent `unmount` function. Never destroys `target`.

	[Open Documentation](https://flux.kohl.gg/guide/roblox/creation#mounting-a-root-flux-mount)
	]]
	mount = mount,
	portal = Bind.portal,
	Flags = Flags,
	Defaults = Defaults,
	Find = Find,
	--[[
	Partitions `props` into one table per `keys` group plus a final table holding every remaining key, leaving `props`
	untouched. Pass a `Flux.prop()` / `Flux.own()` schema or an annotated key-literal array (`{ "label" | "onClick" }`)
	to preserve exact `Pick` and `Omit` types on a single group.

	```luau
	local OWN = {
		label = Flux.prop() :: Flux.Reactive<string>,
		onClick = Flux.prop() :: ((...any) -> ())?,
	}
	local own, rest = Flux.split(props, OWN)
	```

	[Open Documentation](https://flux.kohl.gg/guide/concepts/components#splitting-props-with-flux-split)
	]]
	split = split :: Split,
	--[[
	Marks a key in a component prop schema for `Flux.split`; cast a bare call to declare the type (`Flux.prop() :: Flux.Reactive<string>`), or pass `default` (`Flux.prop(16)`) to fill missing/`nil` values automatically.

	[Open Documentation](https://flux.kohl.gg/guide/concepts/components#splitting-props-with-flux-split)
	]]
	prop = prop :: Prop,
	--[[
	Merges one or more component prop schemas into a single frozen schema table for `Flux.Props` and `Flux.split`.

	[Open Documentation](https://flux.kohl.gg/guide/concepts/components#splitting-props-with-flux-split)
	]]
	own = own :: Own,
	--[[
	Returns a shallow read-only live view merging 1-4 prop tables left-to-right where the rightmost non-`nil` value wins
	per key. Nest `{ base, rest }` arrays or chain `Flux.edit` to combine children and directives instead.

	[Open Documentation](https://flux.kohl.gg/guide/concepts/components#merging-props-with-flux-merge)
	]]
	merge = merge :: MergeProps,
})
