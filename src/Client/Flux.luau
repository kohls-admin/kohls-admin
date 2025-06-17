--- A generic function type
--- @within Flux
--- @type Function (...any) -> ...any
export type Function = (...any) -> ...any

--- A generic list type
--- @within Flux
--- @type List { T }
export type List<T> = { T }

--- A generic set type implemented as a table with boolean values
--- @within Flux
--- @type Set { [T]: boolean }
export type Set<T> = { [T]: boolean }

--- Represents a dictionary-like table with keys of type `T` and values of any type.
--- @within Flux
--- @type Dict { [T]: any }
export type Dict<T> = { [T]: any }

--[=[
	Represents a reactive state object in the Flux system
	@within Flux
	@type State { _update: (State<T>) -> boolean, _dependencies: Set<State<T>>, _dependents: Set<State<T>>, _binds: { [T]: any }, _hooks: Dict<Function>, _value: T, _stateful: boolean, _operation: List<any>?, _tweenInfo: TweenInfo | any, set: (self: State<T>, new: T, force: boolean?, noTween: boolean?) -> State<T>, get: (self: State<T>) -> T, hook: (self: State<T>, callback: Function) -> Function, Destroy: (self: State<T>) -> (), bindToProperty: (self: State<T>, instance: Instanceproperty: string) -> (), bindToAttribute: (self: State<T>, instance: Instance, attribute: string) -> () }
]=]
export type State<T> = {
	_update: (State<T>) -> boolean,
	_dependencies: Set<State<T>>,
	_dependents: Set<State<T>>,
	_binds: { [T]: any },
	_hooks: Dict<Function>,
	_value: T,
	_stateful: boolean,
	_operation: List<any>?,
	_tweenInfo: TweenInfo | any,
	set: (self: State<T>, new: T, force: boolean?, noTween: boolean?) -> State<T>,
	get: (self: State<T>) -> T,
	hook: (self: State<T>, callback: Function) -> Function,
	Destroy: (self: State<T>) -> (),
	bindToProperty: (self: State<T>, instance: Instance, property: string) -> (),
	bindToAttribute: (self: State<T>, instance: Instance, attribute: string) -> (),
}

--- A type for state or raw values
--- @within Flux
--- @type Stateful<T> T | State<T>
export type Stateful<T> = T | State<T>

--- A type unique keys
--- @within Flux
--- @type Symbol { type: "Symbol" }
export type Symbol = {
	type: "Symbol",
}

--- Represents the definition used in [Flux.new] and [Flux.edit]
--- @within Flux
--- @type SpecialDefinition { [number | string | Symbol]: unknown }
export type SpecialDefinition = { [any]: unknown }

local TweenService = game:GetService("TweenService")

local WEAK_KEYS_METATABLE = { __mode = "k" }
local ATTRIBUTE_PREFIX = "Attribute_"

--- Checks if an object is a Flux state
--- @within Flux
local function isState(object: any): boolean
	return typeof(object) == "table" and object._stateful == true
end

--- Gets the current value of a Flux state or returns the input if it's not a state
--- @within Flux
local function peek<T>(object: T): T
	return if typeof(object) == "table" and object._stateful then object._value :: T else object :: T
end

--- Gets the current values of multiple Flux states or non-state inputs
--- @within Flux
local function peekVariadic(...: any): ...any
	local result = {}
	for _, object in { ... } do
		table.insert(result, peek(object))
	end
	return unpack(result)
end

local function assertNotCircular<T>(state: State<T>, other: State<T>)
	if state._dependents[other] or other._dependencies[state] then
		error("Circular dependency chain detected!")
	end
	for dependency in other._dependencies do
		if isState(dependency) then
			assertNotCircular(state, dependency)
		end
	end
end

local function setProperty_unsafe(instance: Instance, property: string, value: any)
	instance[property] = value
end

local function testPropertyAssignable(instance: Instance, property: string)
	instance[property] = instance[property]
end

local function testProperty(instance: Instance, property: string)
	local _ = instance[property]
end

local function setProperty(instance: Instance, property: string, value: any)
	if pcall(setProperty_unsafe, instance, property, value) then
		return -- property assignment successful
	end
	if pcall(testPropertyAssignable, instance, property) then
		local got = typeof(value)
		local expected = typeof(instance[property])
		error(`Invalid value type for {instance.ClassName}.{property}: Expected {expected} got {got}`)
	elseif instance == nil then
		error("Attempt to index nil with " .. property)
	else
		error(`{instance.ClassName}.{property} is not assignable`)
	end
end

local function cleanup(task: any)
	local taskType = typeof(task)
	if taskType == "Instance" then
		task:Destroy()
	elseif taskType == "RBXScriptConnection" then
		task:Disconnect()
	elseif taskType == "function" then
		task()
	elseif taskType == "table" then
		if typeof(task.destroy) == "function" then
			task:destroy()
		elseif typeof(task.Destroy) == "function" then
			task:Destroy()
		elseif task[1] ~= nil then
			for _, subtask in ipairs(task) do
				cleanup(subtask)
			end
		elseif typeof(task._cleanup) == "table" then
			for _, subtask in ipairs(task._cleanup) do
				cleanup(subtask)
			end
		end
	end
end

--- A library for easily creating and managing reactive state.
--- @class Flux
local Flux = {
	cleanup = cleanup,
	peek = peek,
	peekVariadic = peekVariadic,
	isState = isState,

	__eq = function(a: any, b: any): boolean
		return peek(a) == peek(b)
	end,
	__lt = function(a: any, b: any): boolean
		return peek(a) < peek(b)
	end,
	__le = function(a: any, b: any): boolean
		return peek(a) <= peek(b)
	end,
}
Flux.__index = Flux

function Flux.Symbol(): Symbol
	return table.freeze({ type = "Symbol" })
end

--- @within Flux
--- A symbol for defining cleanup in [Flux.edit]
--- @prop Clean Symbol
--- @readonly
Flux.Clean = Flux.Symbol()

--- Adds a dependency to the current state
function Flux:_addDependency<T>(dependency: State<T>)
	if isState(dependency) then
		assertNotCircular(self, dependency)
		dependency._dependents[self] = true
	end
	self._dependencies[dependency] = true
end

--- Removes a dependency from the current state
function Flux:_removeDependency<T>(dependency: State<T>)
	if not isState(dependency) then
		return
	end
	for _, value in self._operation do
		if value == dependency then
			return -- depends on operation, can't be removed
		end
	end
	self._dependencies[dependency] = nil
	dependency._dependents[self] = nil
end

--- Updates the state and propagates changes to dependents
function Flux:_update(noTween: boolean?)
	local _operation = self._operation
	if type(_operation) == "table" then
		local computation = _operation[1] :: Function
		local args = {}
		for i = 2, #_operation do
			table.insert(args, peek(_operation[i]))
		end
		self._value = computation(unpack(args))
	end

	local value = peek(self)
	if self._binds then -- State -> Instance binding
		for instance, binds in self._binds do
			for k, v in binds do
				if type(k) == "string" then -- attribute
					instance:SetAttribute(k, value)
				elseif type(v) == "string" then -- property
					if not noTween and self._tweenInfo then
						TweenService:Create(instance, peek(self._tweenInfo), { [v] = value }):Play()
					else
						setProperty(instance, v, value)
					end
				end
			end
		end
	end

	for dependent in self._dependents do
		local dependentType = type(dependent)
		if dependentType == "table" then
			if type(dependent._update) == "function" then
				task.spawn(dependent._update, dependent, noTween)
			end
		end
	end

	if self._hooks then
		for hook in self._hooks do
			if type(hook) == "function" then
				task.spawn(hook, value)
			end
		end
	end
end

--- Destroys the state, clearing all dependencies and bindings
function Flux:Destroy()
	setmetatable(self, nil)
	for _, dependency in self._dependencies do
		self._dependencies[dependency] = nil
		dependency._dependents[self] = nil
	end
	if self._bindConnection then
		self._bindConnection:Disconnect()
	end
	if self.binds then
		table.clear(self._binds)
	end
	table.clear(self._dependents)
	table.clear(self)
end

--- Adds a hook callback function to be called when the state changes
function Flux:hook(callback: Function): Function
	if not self._hooks then
		self._hooks = {}
	end
	self._hooks[callback] = true
	return function()
		self._hooks[callback] = nil
	end
end

--- Gets the current value of the state
function Flux:get(): any
	return self._value
end

--- Sets a new value for the state and triggers an update
function Flux:set<T>(new: T, forceUpdate: boolean?, noTween: boolean?): State<T>
	local old = self._value
	if not forceUpdate and type(old) ~= "table" and new == old then
		return self
	end
	self._value = new
	self:_update(noTween)
	return self
end

--- Binds the state to a property of an Instance
function Flux:bindToProperty(instance: Instance, property: string)
	if typeof(instance) ~= "Instance" then
		error(`Instance expected got {typeof(instance)}`)
	end
	if not pcall(testProperty, instance, property) then
		error(`{instance.ClassName}.{property} is not valid`)
	end
	if self._bindConnection then
		self._bindConnection:Disconnect()
	end
	self:set(instance[property])
	self._bindConnection = instance:GetPropertyChangedSignal(property):Connect(function()
		self:set(instance[property])
	end)
end

--- Binds the state to an attribute of an Instance
function Flux:bindToAttribute(instance: Instance, attribute: string)
	if typeof(instance) ~= "Instance" then
		error(`Instance expected got {typeof(instance)}`)
	end
	if self._bindConnection then
		self._bindConnection:Disconnect()
	end
	self:set(instance:GetAttribute(attribute))
	self._bindConnection = instance:GetAttributeChangedSignal(attribute):Connect(function()
		self:set(instance:GetAttribute(attribute))
	end)
end

local instanceStateRef: { [Instance]: { [string | State<any>]: string | State<any> } } = {}

local function setupBind(instance: Instance, value: State<any>, property: string)
	if not value._binds then
		value._binds = {}
	end
	if not value._binds[instance] then
		value._binds[instance] = {}
		instance.Destroying:Once(function()
			if value._binds then
				value._binds[instance] = nil
			end
			task.defer(function()
				if instanceStateRef[instance] then
					table.clear(instanceStateRef[instance])
					instanceStateRef[instance] = nil
				end
			end)
		end)
	end

	local isAttribute = string.find(property, ATTRIBUTE_PREFIX, 1, true) == 1
	if isAttribute then
		value._binds[instance][string.sub(property, #ATTRIBUTE_PREFIX + 1)] = true
	else
		table.insert(value._binds[instance], property)
	end

	-- strong reference
	if not instanceStateRef[instance] then
		instanceStateRef[instance] = {
			[property] = value,
		}
	else
		instanceStateRef[instance][property] = value
	end
end

-- unbind existing state, only have one bound to a property at a time
local function cleanBind(instance: Instance, value: State<any>, property: string)
	-- TODO: attempt to destroy it if no other dependents?
	local ref = instanceStateRef[instance]
	if not ref then
		return
	end
	local existing = instanceStateRef[instance][property]
	if not existing then
		return
	end

	local binds = existing._binds[instance]
	local isAttribute = string.find(property, ATTRIBUTE_PREFIX, 1, true) == 1
	if isAttribute then -- attribute
		binds[string.sub(property, #ATTRIBUTE_PREFIX + 1)] = nil
	else -- property
		local foundIndex = table.find(binds, property)
		if foundIndex then
			table.remove(binds, foundIndex)
		end
	end
end

Flux._implicitComputeds = {}

--- Edits an existing Instance with Flux state bindings and other properties
--- @param definition SpecialDefinition & Instance
function Flux.edit(instance: Instance, definition): Instance
	definition = definition :: SpecialDefinition & Instance

	local clean = definition[Flux.Clean] or {}
	local parent = definition.Parent
	definition[Flux.Clean] = nil
	definition.Parent = nil

	local signals = { attribute = {}, property = {}, rbx = {} }

	for property, value in definition do
		-- numeric index child definition
		if type(property) == "number" and property == math.floor(property) then
			if typeof(value) == "Instance" then
				value.Parent = instance
			end
			continue
		end

		local isAttribute = string.find(property, ATTRIBUTE_PREFIX, 1, true) == 1
		local changed = string.find(property, "_Changed$")

		if type(value) == "function" then
			if isAttribute and changed then
				signals.attribute[string.sub(property, #ATTRIBUTE_PREFIX + 1, changed - 1)] = value
				continue
			end
			if changed then
				signals.property[string.sub(property, 1, changed - 1)] = value
				continue
			end
			if typeof(instance[property]) == "RBXScriptSignal" then
				signals.rbx[instance[property]] = value
				continue
			end
			local computed = Flux._implicitComputeds[value] or Flux.compute(value)
			Flux._implicitComputeds[value] = computed
			value = computed
		end

		cleanBind(instance, value, property)
		if isState(value) then
			setupBind(instance, value, property)
		end

		if isAttribute then
			instance:SetAttribute(string.sub(property, #ATTRIBUTE_PREFIX + 1), peek(value))
		else
			setProperty(instance, property, peek(value))
		end
	end

	for attribute, callback in signals.attribute do
		instance:GetAttributeChangedSignal(attribute):Connect(callback)
	end
	for property, callback in signals.property do
		instance:GetPropertyChangedSignal(property):Connect(callback)
	end
	for signal, callback in signals.rbx do
		signal:Connect(callback)
	end

	if #clean > 0 or next(clean) then
		instance.Destroying:Once(function()
			cleanup(clean)
		end)
	end

	if typeof(parent) == "Instance" then
		instance.Parent = parent
	end

	return instance
end

--- Creates a new Instance with Flux state bindings and other properties
--- @within Flux
--- @function new
--- @param className string
--- @return Flux.edit
Flux.new = function(className)
	return function(properties)
		return Flux.edit(Instance.new(className), properties)
	end
end :: ((className: string) -> (properties: Instance & SpecialDefinition) -> Instance) & typeof(Instance.new)

--- Creates a computed state based on other states or static values
function Flux.computeFrom<T>(computation: (...any) -> T, ...: any): State<T>
	local result = computation(peekVariadic(...))
	local new = Flux.state(result)
	for i = 1, select("#", ...) do
		local arg = select(i, ...)
		if isState(arg) then
			new:_addDependency(arg)
		end
	end
	new._operation = { computation, ... }
	return new
end

--- Creates a computed state, passing a use function to access and bind other states
function Flux.compute<T>(computation: (use: <U>(U | State<U>) -> U?) -> T): State<T>
	local new = Flux.state(nil)
	local function use<U>(state: U | State<U>): U?
		if isState(state) then
			new:_addDependency(state)
		end
		return peek(state) :: U
	end
	local result = computation(use)
	new._value = result
	new._operation = { computation, peek }
	return new
end

--- Applies TweenService tweens with Instance properties bound to the Flux state
function Flux.tween<T>(tweenInfo: Stateful<TweenInfo>, state: State<T>): State<T>
	if not isState(state) then
		error("Invalid Flux state object")
	end
	state._tweenInfo = tweenInfo
	return state
end

--- Creates a new Flux state with an initial value
function Flux.state<T>(initialValue: T | State<T> | Instance, property: string?): State<T>
	if isState(initialValue) then
		return initialValue :: State<T>
	end
	local new = setmetatable({
		_dependents = setmetatable({}, WEAK_KEYS_METATABLE),
		_dependencies = {},
		_operation = nil,
		_stateful = true,
		_value = initialValue,
	}, Flux)
	if property then
		if string.find(property, ATTRIBUTE_PREFIX, 1, true) == 1 then
			new:bindToAttribute(initialValue :: Instance, string.sub(property, #ATTRIBUTE_PREFIX + 1))
		else
			new:bindToProperty(initialValue :: Instance, property)
		end
	end
	return new
end

return Flux
