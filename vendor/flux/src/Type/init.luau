--!strict
-- Type-level machinery for property tables and component props: `Properties`, `EditProperties`, `PropertyType`,
-- `Merge`, `Partial`, `Pick`, `Omit`, `NonNil`, and the child types.

local Graph = require("./Graph")
local Instances = require("@self/Instances")

type GraphNode = Graph.Node<any>

--- @within Flux
--- @private
export type Map<T> = { [T]: any }

type _ATTR = "__ATTR"
type _CLEAN = "__CLEAN"
type _EVENT = "__EVENT"
type _REF = "__REF"
type _TAG = "__TAG"

-- A handle returned by `Flux.portal(target, children)` that mounts UI into `target` on parent cleanup or portal removal.
export type Portal = { read __fluxPortal: true }
-- A component schema marker returned by `Flux.prop(default)` that makes `default` optional in `Flux.Props` and non-nil in `Flux.split`.
export type DefaultProp<T> = { read __fluxDefault: T }

-- Anything a property table accepts at a numeric index: a child Instance, a node yielding children, a portal, an init
-- action run with the instance, or a nested property table flattened into its parent.
export type Child = Instance | GraphNode | Portal | ((instance: Instance) -> ()) | { [any]: any }
export type Children = { Child }

--- @within Flux
--- @private
export type function Properties(instance: type?)
	local function indexerTable(indexType: type, valueType: type): type
		local t = types.newtable()
		t:setindexer(indexType, valueType)
		return t
	end

	local function readProp(t: type, key: type, name: string): type?
		if t:is("table") then
			return t:readproperty(key)
		elseif t:is("extern") then
			for k, prop in t:properties() do
				if k:value() == name then
					return prop.read
				end
			end
		end
		return nil
	end

	local result = indexerTable(types.number, types.any)
	-- `__EVENT`: a change listener per property, called with the new value. Signals connect at the top level.
	local events = types.newtable(nil, { index = types.number, readresult = types.never, writeresult = types.never })
	local connectKey = types.singleton("Connect")

	type MemberInfo = {
		key: type,
		signal: type?,
		read: type?,
		write: type?,
	}

	local function collectMembers(component: type?): { [string]: MemberInfo }
		local members: { [string]: MemberInfo } = {}
		local class: type? = component
		while class and (class:is("extern") or class:is("table")) do
			for i, v in class:properties() do
				local propName = i:value()
				if type(propName) ~= "string" or members[propName] ~= nil then
					continue
				end
				local connector = if v.read then readProp(v.read, connectKey, "Connect") else nil
				local isSignal = false
				local sigListener: type? = nil
				if connector then
					if connector:is("function") then
						local params = connector:parameters().head
						if params and params[2] then
							sigListener = params[2]
							isSignal = true
						end
					elseif v.read and v.read:is("extern") then
						isSignal = true
					end
				end
				if isSignal then
					members[propName] = { key = i, signal = sigListener }
				else
					members[propName] = { key = i, read = v.read, write = v.write }
				end
			end
			class = if class:is("extern") then class:readparent() else nil
		end
		return members
	end

	local function uniqueUnion(list: { type }): type
		local unique: { type } = {}
		for _, t in list do
			if not table.find(unique, t) then
				table.insert(unique, t)
			end
		end
		return if #unique == 1 then unique[1] else types.unionof(table.unpack(unique))
	end

	local function uniqueIntersection(list: { type }): type
		local unique: { type } = {}
		for _, t in list do
			if not table.find(unique, t) then
				table.insert(unique, t)
			end
		end
		return if #unique == 1 then unique[1] else types.intersectionof(table.unpack(unique))
	end

	local nodeProperties = if GraphNode:is("table") then GraphNode:properties() else nil
	local nodeMetatable = if GraphNode:is("table") then GraphNode:metatable() else nil
	local function nodeOf(valueType: type): type
		if nodeProperties == nil then
			return GraphNode
		end
		local nodeTable = types.newtable()
		local getterFn = types.newfunction({ head = { types.any } }, { head = { valueType } })
		for key, prop in nodeProperties do
			local name = key:value()
			if name == "peek" or name == "get" then
				nodeTable:setreadproperty(key, getterFn)
			else
				local propType = prop.read or prop.write
				if propType then
					nodeTable:setreadproperty(key, propType)
				end
			end
		end
		if nodeMetatable then
			nodeTable:setmetatable(nodeMetatable)
		end
		return nodeTable
	end

	local function emitMember(info: MemberInfo)
		if info.signal then
			result:setreadproperty(info.key, types.optional(info.signal))
			return
		end
		if info.read then
			local changedListener = types.optional(types.newfunction({ head = { info.read } }))
			events:setproperty(info.key, changedListener)
			local propName = info.key:value()
			if type(propName) == "string" then
				result:setreadproperty(types.singleton("_" .. propName), changedListener)
			end
		end
		if info.write then
			local t = types.optional(
				types.unionof(info.write, types.newfunction({}, { head = { info.write } }), nodeOf(info.write))
			)
			result:setreadproperty(info.key, t)
		elseif info.read then
			result:setreadproperty(info.key, types.singleton(nil))
		end
	end

	local function collectBranchMembers(root: type?): { [string]: MemberInfo }
		local merged: { [string]: MemberInfo } = {}
		local function walk(component: type?)
			if component and component:is("intersection") then
				for _, part in component:components() do
					walk(part)
				end
				return
			end
			for propName, info in collectMembers(component) do
				local prev = merged[propName]
				if prev == nil then
					merged[propName] = info
				else
					merged[propName] = {
						key = prev.key,
						signal = info.signal or prev.signal,
						read = info.read or prev.read,
						write = info.write or prev.write,
					}
				end
			end
		end
		walk(root)
		return merged
	end

	if instance and instance:is("union") then
		local branchMaps: { { [string]: MemberInfo } } = {}
		for _, part in instance:components() do
			if not part:is("nil") then
				table.insert(branchMaps, collectBranchMembers(part))
			end
		end
		if #branchMaps == 1 then
			for _, info in branchMaps[1] do
				emitMember(info)
			end
		elseif #branchMaps > 1 then
			local first = branchMaps[1]
			for propName, firstInfo in first do
				local allPresent = true
				local allSignal = firstInfo.signal ~= nil
				local allWrite = firstInfo.write ~= nil
				local sigs: { type } = {}
				local reads: { type } = {}
				local writes: { type } = {}
				for _, map in branchMaps do
					local m = map[propName]
					if m == nil then
						allPresent = false
						break
					end
					if m.signal then
						table.insert(sigs, m.signal)
					else
						allSignal = false
					end
					if m.read then
						table.insert(reads, m.read)
					end
					if m.write then
						table.insert(writes, m.write)
					else
						allWrite = false
					end
				end
				if allPresent then
					if allSignal and #sigs > 0 then
						emitMember({ key = firstInfo.key, signal = uniqueIntersection(sigs) })
					elseif not allSignal then
						emitMember({
							key = firstInfo.key,
							read = if #reads == #branchMaps then uniqueUnion(reads) else nil,
							write = if allWrite and #writes > 0 then uniqueIntersection(writes) else nil,
						})
					end
				end
			end
		end
	else
		for _, info in collectBranchMembers(instance) do
			emitMember(info)
		end
	end

	local attrListener = types.newfunction({ head = { types.any } })
	events:setproperty(
		_ATTR,
		types.optional(
			types.newtable(nil, { index = types.string, readresult = attrListener, writeresult = attrListener })
		)
	)
	local tagListener = types.newfunction({ head = { types.boolean } })
	events:setproperty(
		_TAG,
		types.optional(
			types.newtable(nil, { index = types.string, readresult = tagListener, writeresult = tagListener })
		)
	)

	result:setreadproperty(_ATTR, types.optional(indexerTable(types.string, types.any)))
	local tag = types.unionof(types.string, GraphNode, types.newfunction({}, { head = { types.any } }))
	result:setreadproperty(_TAG, types.optional(types.unionof(tag, indexerTable(types.number, tag))))
	result:setreadproperty(_CLEAN, types.optional(indexerTable(types.number, types.any)))
	result:setreadproperty(_EVENT, types.optional(events))
	local refType = if instance then instance else types.any
	local refCallback = types.newfunction({ head = { refType } }, { tail = types.any })
	local refState = types.newtable()
	refState:setreadproperty(
		types.singleton("set"),
		types.newfunction({ head = { types.any, refType, types.optional(types.boolean) } }, { head = { types.any } })
	)
	refState:setreadproperty(
		types.singleton("get"),
		types.newfunction({ head = { types.any } }, { head = { types.any } })
	)
	result:setreadproperty(_REF, types.optional(types.unionof(refCallback, refState)))

	return result
end

-- Merges table types into one, later properties winning. `Flux.Props` uses it to add a component's own props to an
-- instance's property table: a table literal checks against one merged table, but not against an intersection.
--- @within Flux
--- @private
export type function Merge(base: type, extra: type)
	local result = types.newtable()
	local defaultKey = types.singleton("__fluxDefault")
	local function unwrapDefault(t: type): type?
		if t:is("table") then
			return t:readproperty(defaultKey)
		elseif t:is("union") then
			local parts = {}
			local found = false
			for _, part in t:components() do
				if not part:is("nil") then
					local inner = if part:is("table") then part:readproperty(defaultKey) else nil
					if inner then
						found = true
						table.insert(parts, inner)
					else
						table.insert(parts, part)
					end
				end
			end
			if found and #parts > 0 then
				return if #parts == 1 then parts[1] else types.unionof(table.unpack(parts))
			end
		end
		return nil
	end
	local function addTable(target: type, source: type, makeOptional: boolean)
		for key, prop in source:properties() do
			local value = prop.read or prop.write
			if value then
				local def = unwrapDefault(value)
				local out = if def or makeOptional then types.optional(def or value) else value
				target:setreadproperty(key, out)
			end
		end
		local indexer = source:indexer()
		if indexer then
			target:setindexer(indexer.index, indexer.readresult)
		end
	end
	local function combineUnion(list: { type }): type
		local unique: { type } = {}
		for _, t in list do
			if not table.find(unique, t) then
				table.insert(unique, t)
			end
		end
		return if #unique == 1 then unique[1] else types.unionof(table.unpack(unique))
	end
	local function add(target: type, source: type, makeOptional: boolean)
		if source:is("nil") then
			return
		elseif source:is("intersection") then
			for _, part in source:components() do
				add(target, part, makeOptional)
			end
			return
		elseif source:is("union") then
			local nonNil = {}
			local hasNil = false
			for _, part in source:components() do
				if part:is("nil") then
					hasNil = true
				else
					table.insert(nonNil, part)
				end
			end
			local opt = makeOptional or hasNil
			if #nonNil == 1 then
				add(target, nonNil[1], opt)
				return
			elseif #nonNil > 1 then
				local branchTables: { type } = {}
				local keyByName: { [any]: type } = {}
				for _, part in nonNil do
					local branch = types.newtable()
					add(branch, part, false)
					table.insert(branchTables, branch)
					for key in branch:properties() do
						local name = key:value()
						if name ~= nil and keyByName[name] == nil then
							keyByName[name] = key
						end
					end
				end
				for _, key in keyByName do
					local parts = {}
					local allPresent = true
					for _, branch in branchTables do
						local val = branch:readproperty(key)
						if val == nil then
							allPresent = false
						else
							table.insert(parts, val)
						end
					end
					if #parts > 0 then
						local combined = combineUnion(parts)
						if opt or not allPresent then
							combined = types.optional(combined)
						end
						target:setreadproperty(key, combined)
					end
				end
				for _, branch in branchTables do
					local idx = branch:indexer()
					if idx then
						target:setindexer(idx.index, idx.readresult)
					end
				end
			end
			return
		elseif not source:is("table") then
			return
		end
		addTable(target, source, makeOptional)
	end
	add(result, base, false)
	add(result, extra, false)
	return result
end

-- The property table `Flux.edit` accepts: the same as `Properties`. Selectors (`Flux.Find`) sit at numeric indices.
--- @within Flux
--- @private
export type EditProperties<T> = Properties<T>

-- The type of `instance[key]` for `Flux.property`: the property's read type, `boolean` for `"#Tag"` / `"_tag_Tag"`, or
-- `any` for `"$Attribute"` / `"_attr_Attribute"`, an event, or a key the class doesn't have (or a key that isn't a
-- string literal).
--- @within Flux
--- @private
export type function PropertyType(instance: type, key: type)
	if not key:is("singleton") then
		return types.any
	end
	local name = key:value()
	if type(name) ~= "string" then
		return types.any
	end
	local prefix = string.sub(name, 1, 1)
	if prefix == "$" then
		return types.any
	elseif prefix == "#" then
		return types.boolean
	elseif prefix == "_" then
		if string.sub(name, 1, 6) == "_attr_" then
			return types.any
		elseif string.sub(name, 1, 5) == "_tag_" then
			return types.boolean
		end
	end

	local connectKey = types.singleton("Connect")
	local function readProp(t: type, propKey: type, propName: string): type?
		if t:is("table") then
			return t:readproperty(propKey)
		elseif t:is("extern") then
			for k, prop in t:properties() do
				if k:value() == propName then
					return prop.read
				end
			end
		end
		return nil
	end
	local function lookup(component: type): type?
		local class: type? = component
		while class and (class:is("extern") or class:is("table")) do
			for propKey, prop in class:properties() do
				if propKey:value() == name then
					local value = prop.read
					if value == nil or readProp(value, connectKey, "Connect") ~= nil then
						return types.any
					end
					return value
				end
			end
			class = if class:is("extern") then class:readparent() else nil
		end
		return nil
	end

	if instance:is("union") then
		local parts: { type } = {}
		for _, part in instance:components() do
			if not part:is("nil") then
				local found = lookup(part)
				if found == nil or found:is("any") then
					return types.any
				elseif not table.find(parts, found) then
					table.insert(parts, found)
				end
			end
		end
		if #parts == 0 then
			return types.any
		end
		return if #parts == 1 then parts[1] else types.unionof(table.unpack(parts))
	end

	local components = if instance:is("intersection") then instance:components() else { instance }
	for _, component in components do
		local found = lookup(component)
		if found ~= nil then
			return found
		end
	end
	return types.any
end

--- @within Flux
--- @private
export type Creatable = Instances.Creatable
--- @within Flux
--- @private
export type Editable = Instances.Editable

--- @within Flux
--- @private
export type Resolve<Name> = index<Creatable & { [string]: Instance }, Name>

--- @within Flux
--- @private
export type function NonNil(t: type): type
	if t:is("nil") then
		return types.never
	elseif not t:is("union") then
		return t
	end
	local parts = {}
	for _, part in t:components() do
		if not part:is("nil") then
			table.insert(parts, part)
		end
	end
	return if #parts == 0 then types.never elseif #parts == 1 then parts[1] else types.unionof(table.unpack(parts))
end

--- @within Flux
--- @private
export type function Truthy(t: type): type
	if t:is("nil") or (t:is("singleton") and t:value() == false) then
		return types.never
	elseif not t:is("union") then
		return t
	end
	local parts = {}
	for _, part in t:components() do
		if not part:is("nil") and not (part:is("singleton") and part:value() == false) then
			table.insert(parts, part)
		end
	end
	return if #parts == 0 then types.never elseif #parts == 1 then parts[1] else types.unionof(table.unpack(parts))
end

-- Merges component schema tables into a single read-only schema table, preserving literal unions.
--- @within Flux
--- @private
export type function MergeOwn(a: type, b: type, c: type, d: type): type
	local result = types.newtable()
	local function add(source: type)
		if source:is("nil") then
			return
		elseif source:is("union") then
			for _, part in source:components() do
				if not part:is("nil") then
					add(part)
				end
			end
			return
		elseif source:is("intersection") then
			for _, part in source:components() do
				add(part)
			end
			return
		elseif not source:is("table") then
			return
		end
		for key, prop in source:properties() do
			local value = prop.read or prop.write
			if value then
				result:setreadproperty(key, value)
			end
		end
		local indexer = source:indexer()
		if indexer then
			result:setindexer(indexer.index, indexer.readresult)
		end
	end
	add(a)
	add(b)
	add(c)
	add(d)
	return result
end

-- `T` with every property optional.
--- @within Flux
--- @private
export type function Partial(t: type): type
	if t:is("nil") then
		return t
	elseif t:is("union") then
		local parts = {}
		for _, part in t:components() do
			if not part:is("nil") then
				table.insert(parts, Partial(part))
			end
		end
		return if #parts == 0
			then types.newtable()
			elseif #parts == 1 then parts[1]
			else types.unionof(table.unpack(parts))
	elseif t:is("intersection") then
		local merged = types.newtable()
		local hasTable = false
		local function collect(source: type)
			if source:is("intersection") then
				for _, part in source:components() do
					collect(part)
				end
				return
			elseif not source:is("table") then
				return
			end
			hasTable = true
			for key, prop in source:properties() do
				local valueType = prop.read or prop.write
				if valueType then
					merged:setproperty(key, types.optional(valueType))
				end
			end
			local indexer = source:indexer()
			if indexer then
				merged:setindexer(indexer.index, indexer.readresult)
			end
		end
		collect(t)
		return if hasTable then merged else t
	elseif not t:is("table") then
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

--- @within Flux
--- @private
export type function CloneProps(t: type): type
	if t:is("nil") then
		return types.newtable()
	elseif t:is("union") then
		for _, part in t:components() do
			if part:is("nil") then
				return Partial(t)
			end
		end
	end
	return t
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
			for key, prop in partKeys:properties() do
				keys:setproperty(key, prop.read or prop.write or key)
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
			if name ~= nil and name ~= true and name ~= false then
				keys:setproperty(part, part)
			elseif name ~= true then
				return types.string
			end
		end
	end
	for key, prop in group:properties() do
		keys:setproperty(key, prop.read or prop.write or key)
	end
	return keys
end

--- @ignore
type function pickWhere(t: type, group: type, prior: type, inGroup: type): type
	local wantAll = inGroup:is("singleton") and inGroup:value() == false
	local function isSchema(src: type): boolean
		if src:is("intersection") then
			for _, part in src:components() do
				if not isSchema(part) then
					return false
				end
			end
			return true
		elseif src:is("union") then
			for _, part in src:components() do
				if not part:is("nil") and not isSchema(part) then
					return false
				end
			end
			return true
		end
		return src:is("table") and src:indexer() == nil
	end
	local schemaGroup = isSchema(group)
	local defaultKey = types.singleton("__fluxDefault")

	local function unwrapDefault(src: type): type?
		if src:is("table") then
			return src:readproperty(defaultKey)
		elseif src:is("union") then
			local parts = {}
			local found = false
			for _, part in src:components() do
				if not part:is("nil") then
					local inner = if part:is("table") then part:readproperty(defaultKey) else nil
					if inner then
						found = true
						table.insert(parts, inner)
					else
						table.insert(parts, part)
					end
				end
			end
			if found and #parts > 0 then
				return if #parts == 1 then parts[1] else types.unionof(table.unpack(parts))
			end
		end
		return nil
	end

	local function canBeNil(src: type): boolean
		if src:is("nil") then
			return true
		elseif src:is("union") then
			for _, part in src:components() do
				if part:is("nil") then
					return true
				end
			end
		end
		return false
	end

	local function stripNil(src: type): type
		if src:is("nil") then
			return types.never
		elseif not src:is("union") then
			return src
		end
		local parts = {}
		for _, part in src:components() do
			if not part:is("nil") then
				table.insert(parts, part)
			end
		end
		return if #parts == 0 then types.never elseif #parts == 1 then parts[1] else types.unionof(table.unpack(parts))
	end

	local function resolveSchemaGroup(src: type, makeOptional: boolean): type
		local keys = groupKeys(src)
		if keys:is("string") then
			return src
		end
		local out = types.newtable()
		for key, prop in keys:properties() do
			local propType = prop.read or prop.write
			if propType then
				local def = unwrapDefault(propType)
				if def then
					out:setproperty(key, def)
				else
					out:setproperty(key, if makeOptional then types.optional(propType) else propType)
				end
			end
		end
		return out
	end

	local function flatten(source: type): (type?, boolean)
		if source:is("nil") then
			return nil, true
		elseif source:is("union") then
			local nonNil = {}
			local hasNil = false
			for _, part in source:components() do
				if part:is("nil") then
					hasNil = true
				else
					table.insert(nonNil, part)
				end
			end
			if #nonNil == 1 then
				local inner, innerNil = flatten(nonNil[1])
				return inner, hasNil or innerNil
			end
			return nil, hasNil
		elseif source:is("intersection") then
			local merged = types.newtable()
			local hasTable = false
			local function collect(partSource: type)
				if partSource:is("intersection") then
					for _, part in partSource:components() do
						collect(part)
					end
					return
				elseif partSource:is("union") then
					local inner = flatten(partSource)
					if inner then
						collect(inner)
					end
					return
				elseif not partSource:is("table") then
					return
				end
				hasTable = true
				for key, prop in partSource:properties() do
					local valueType = prop.read or prop.write
					if valueType then
						merged:setproperty(key, valueType)
					end
				end
				local indexer = partSource:indexer()
				if indexer then
					merged:setindexer(indexer.index, indexer.readresult)
				end
			end
			collect(source)
			return if hasTable then merged else nil, false
		elseif source:is("table") then
			return source, false
		end
		return nil, false
	end

	local flat, wasOptional = flatten(t)
	if flat == nil then
		if t:is("union") and not t:is("nil") then
			local parts = {}
			for _, part in t:components() do
				if not part:is("nil") then
					local sub = pickWhere(part, group, prior, inGroup)
					local entry = if wasOptional then Partial(sub) else sub
					if wasOptional and not wantAll and schemaGroup and entry:is("table") then
						local schemaKeys = groupKeys(group)
						if not schemaKeys:is("string") then
							for sKey, sProp in schemaKeys:properties() do
								local sType = sProp.read or sProp.write
								local def = if sType then unwrapDefault(sType) else nil
								if def then
									local curProp = entry:readproperty(sKey)
									if canBeNil(def) then
										local nonNil = if curProp then stripNil(curProp) else types.never
										entry:setproperty(sKey, if nonNil:is("never") then def else curProp :: type)
									else
										local nonNil = if curProp then stripNil(curProp) else types.never
										entry:setproperty(sKey, if nonNil:is("never") then def else nonNil)
									end
								end
							end
						end
					end
					table.insert(parts, entry)
				end
			end
			if #parts > 0 then
				return if #parts == 1 then parts[1] else types.unionof(table.unpack(parts))
			end
		end
		if wantAll and t:is("nil") then
			return types.newtable()
		elseif not t:is("any") and not wantAll and schemaGroup then
			return resolveSchemaGroup(group, wasOptional)
		end
		return t
	end
	if not wantAll and group:is("nil") then
		return Partial(flat)
	end
	local wanted, excluded = groupKeys(group), groupKeys(prior)
	if wanted:is("string") or excluded:is("string") then
		return Partial(flat)
	end
	local function has(names: type, key: type): boolean
		return names:readproperty(key) ~= nil
	end
	local result = types.newtable()
	for key, prop in flat:properties() do
		local valueType = prop.read or prop.write
		local inWanted = has(wanted, key)
		local outType = if wasOptional and valueType then types.optional(valueType) else valueType
		if not wantAll and schemaGroup and inWanted and valueType then
			local schemaProp = wanted:readproperty(key)
			local def = if schemaProp then unwrapDefault(schemaProp) else nil
			if def then
				if canBeNil(def) then
					local nonNil = stripNil(valueType)
					if nonNil:is("never") then
						outType = def
					elseif wasOptional then
						outType = types.optional(nonNil)
					else
						outType = valueType
					end
				else
					local nonNil = stripNil(valueType)
					outType = if nonNil:is("never") then def else nonNil
				end
			end
		end
		if outType and not has(excluded, key) and inWanted ~= wantAll then
			result:setproperty(key, outType)
		end
	end
	if not wantAll and schemaGroup then
		for key, prop in wanted:properties() do
			if result:readproperty(key) == nil and not has(excluded, key) then
				local fallbackType = prop.read or prop.write
				if fallbackType then
					local def = unwrapDefault(fallbackType)
					result:setproperty(key, if def then def else types.optional(fallbackType))
				end
			end
		end
	end
	local indexer = flat:indexer()
	if indexer and wantAll then
		result:setindexer(indexer.index, indexer.readresult)
	end
	return result
end

-- Merges 1-4 table types left-to-right into one read-only type, narrowing optional overrides over earlier non-nil values.
--- @within Flux
--- @private
export type function MergeTables(a: type, b: type, c: type, d: type): type
	local result = types.newtable()

	local function canBeNil(src: type): boolean
		if src:is("nil") then
			return true
		elseif src:is("union") then
			for _, part in src:components() do
				if part:is("nil") then
					return true
				end
			end
		end
		return false
	end

	local function stripNil(src: type): type
		if src:is("nil") then
			return types.never
		elseif not src:is("union") then
			return src
		end
		local parts = {}
		for _, part in src:components() do
			if not part:is("nil") then
				table.insert(parts, part)
			end
		end
		return if #parts == 0 then types.never elseif #parts == 1 then parts[1] else types.unionof(table.unpack(parts))
	end

	local function combine(aType: type, bType: type): type
		local parts: { type } = {}
		local function add(t: type)
			if t:is("never") then
				return
			elseif t:is("union") then
				for _, part in t:components() do
					add(part)
				end
			elseif not table.find(parts, t) then
				table.insert(parts, t)
			end
		end
		add(aType)
		add(bType)
		return if #parts == 0 then types.never elseif #parts == 1 then parts[1] else types.unionof(table.unpack(parts))
	end

	local function mergeProp(prev: type?, nextVal: type, srcOptional: boolean): type
		if prev == nil then
			return if srcOptional then types.optional(nextVal) else nextVal
		elseif not srcOptional and not canBeNil(nextVal) then
			return nextVal
		end
		return combine(prev, stripNil(nextVal))
	end

	local function mergeInto(target: type, source: type, srcOptional: boolean)
		if source:is("nil") then
			return
		elseif source:is("union") then
			local nonNil = {}
			local hasNil = false
			for _, part in source:components() do
				if part:is("nil") then
					hasNil = true
				else
					table.insert(nonNil, part)
				end
			end
			local branchOptional = srcOptional or hasNil
			if #nonNil == 0 then
				return
			elseif #nonNil == 1 then
				mergeInto(target, nonNil[1], branchOptional)
				return
			end
			local branchTables: { type } = {}
			local keyByName: { [any]: type } = {}
			for _, part in nonNil do
				local branch = types.newtable()
				mergeInto(branch, part, false)
				table.insert(branchTables, branch)
				for key in branch:properties() do
					local name = key:value()
					if name ~= nil and keyByName[name] == nil then
						keyByName[name] = key
					end
				end
			end
			for _, key in keyByName do
				local combined: type? = nil
				local allPresentAndNonNil = true
				for _, branch in branchTables do
					local val = branch:readproperty(key)
					if val == nil then
						allPresentAndNonNil = false
					else
						if canBeNil(val) then
							allPresentAndNonNil = false
						end
						local stripped = stripNil(val)
						combined = if combined == nil then stripped else combine(combined, stripped)
					end
				end
				if combined ~= nil then
					local propOptional = branchOptional or not allPresentAndNonNil
					target:setreadproperty(key, mergeProp(target:readproperty(key), combined, propOptional))
				end
			end
			local idxKey: type? = nil
			local idxVal: type? = nil
			local allHaveIndexer = true
			for _, branch in branchTables do
				local idx = branch:indexer()
				if idx == nil then
					allHaveIndexer = false
				else
					idxKey = if idxKey == nil then idx.index else combine(idxKey, idx.index)
					idxVal = if idxVal == nil then idx.readresult else combine(idxVal, idx.readresult)
				end
			end
			if idxKey ~= nil and idxVal ~= nil then
				local finalVal = if branchOptional or not allHaveIndexer then types.optional(idxVal) else idxVal
				target:setindexer(idxKey, finalVal)
			end
			return
		elseif source:is("intersection") then
			for _, part in source:components() do
				mergeInto(target, part, srcOptional)
			end
			return
		elseif not source:is("table") then
			return
		end
		for key, prop in source:properties() do
			local val = prop.read or prop.write
			if val then
				target:setreadproperty(key, mergeProp(target:readproperty(key), val, srcOptional))
			end
		end
		local indexer = source:indexer()
		if indexer then
			local idxVal = if srcOptional then types.optional(indexer.readresult) else indexer.readresult
			local curIdx = target:indexer()
			if curIdx then
				target:setindexer(combine(curIdx.index, indexer.index), combine(curIdx.readresult, idxVal))
			else
				target:setindexer(indexer.index, idxVal)
			end
		end
	end

	mergeInto(result, a, false)
	mergeInto(result, b, false)
	mergeInto(result, c, false)
	mergeInto(result, d, false)
	if result:indexer() == nil then
		result:setindexer(types.number, types.any)
	end
	return result
end

--- @within Flux
--- @private
export type Pick<T, G> = pickWhere<T, G, nil, true>

--- @within Flux
--- @private
export type Omit<T, G> = pickWhere<T, nil, G, false>

-- Extracts the first payload type accepted by a signal's `Connect` / `connect` listener, defaulting to `any`.
--- @within Flux
--- @private
export type function SignalPayload(sig: type): type
	local connectKey = types.singleton("Connect")
	local lowerConnectKey = types.singleton("connect")

	local function fromObject(t: type): type?
		local current: type? = t
		while current and (current:is("extern") or current:is("table")) do
			local connector: type? = nil
			if current:is("table") then
				connector = current:readproperty(connectKey) or current:readproperty(lowerConnectKey)
			else
				for k, prop in current:properties() do
					local kn = k:value()
					if kn == "Connect" then
						connector = prop.read
						break
					elseif kn == "connect" and connector == nil then
						connector = prop.read
					end
				end
			end
			if connector and connector:is("function") then
				local params = connector:parameters().head
				local listener = if params
						and params[2]
						and params[2]:is("function")
					then params[2]
					elseif params and params[1] and params[1]:is("function") then params[1]
					else nil
				if listener then
					local cb = listener:parameters()
					if cb.head and cb.head[1] ~= nil then
						return cb.head[1]
					elseif cb.tail == nil then
						return types.singleton(nil)
					end
					return types.any
				end
			end
			current = if current:is("extern") then current:readparent() else nil
		end
		return nil
	end

	local function resolve(t: type): type?
		if t:is("any") or t:is("unknown") then
			return types.any
		elseif t:is("nil") then
			return nil
		elseif t:is("union") then
			local parts: { type } = {}
			for _, part in t:components() do
				local found = resolve(part)
				if found ~= nil and not table.find(parts, found) then
					table.insert(parts, found)
				end
			end
			if #parts == 0 then
				return nil
			end
			return if #parts == 1 then parts[1] else types.unionof(table.unpack(parts))
		elseif t:is("intersection") then
			for _, part in t:components() do
				local found = resolve(part)
				if found ~= nil then
					return found
				end
			end
			return nil
		end
		return fromObject(t)
	end

	return resolve(sig) or types.any
end

-- Unwraps the dependency shape passed to `Flux.on`: a node, getter, plain value, or array of them.
--- @within Flux
--- @private
export type function OnInput(deps: type): type
	local function returned(fn: type): type
		local head = fn:returns().head
		return if head and head[1] then head[1] else types.singleton(nil)
	end

	local function nodeValue(t: type): type?
		if not t:is("table") then
			return nil
		end
		local get = t:readproperty(types.singleton("get"))
		if get and get:is("function") and t:readproperty(types.singleton("peek")) then
			return returned(get)
		end
		return nil
	end

	local function unwrapValue(t: type): type
		if t:is("any") or t:is("unknown") then
			return types.any
		elseif t:is("union") then
			local parts: { type } = {}
			local function add(part: type)
				if part:is("union") then
					for _, member in part:components() do
						add(member)
					end
				elseif not table.find(parts, part) then
					table.insert(parts, part)
				end
			end
			for _, part in t:components() do
				add(unwrapValue(part))
			end
			return if #parts == 1 then parts[1] else types.unionof(table.unpack(parts))
		elseif t:is("intersection") then
			for _, part in t:components() do
				local found = nodeValue(part)
				if found then
					return found
				end
			end
			return t
		elseif t:is("function") then
			return returned(t)
		end
		return nodeValue(t) or t
	end

	local function resolve(t: type): type
		if t:is("any") or t:is("unknown") then
			return types.any
		elseif t:is("union") then
			local parts: { type } = {}
			for _, part in t:components() do
				local resolved = resolve(part)
				if not table.find(parts, resolved) then
					table.insert(parts, resolved)
				end
			end
			return if #parts == 1 then parts[1] else types.unionof(table.unpack(parts))
		elseif t:is("intersection") then
			for _, part in t:components() do
				local found = nodeValue(part)
				if found then
					return found
				end
			end
			return t
		elseif t:is("function") then
			return returned(t)
		elseif t:is("table") then
			local found = nodeValue(t)
			if found then
				return found
			end
			local indexer = t:indexer()
			if indexer and indexer.readresult then
				local elem = unwrapValue(indexer.readresult)
				return types.newtable(nil, { index = types.number, readresult = elem, writeresult = elem })
			end
			return t
		end
		return t
	end

	return resolve(deps)
end

return nil
