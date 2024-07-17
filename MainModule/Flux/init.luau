local TweenService = game:GetService("TweenService")

local Types = require(script.Types)

local WEAK_KEYS_METATABLE = { __mode = "k" }
local ATTRIBUTE_PREFIX = "Attribute:"

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

local function assertNotCircular<T>(state: Types.State<T>, other: Types.State<T>)
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

local function cleanupScope(scope: any)
	print("cleanupScope", scope)
end

--- @within Flux
--- @type Scope {[any] = Scope | any}
local scopeMetatable = {
	__index = function(self: any, key: string): any
		if key == "cleanup" then
			return function()
				cleanupScope(self)
			end
		end
		-- new scope
		local new = setmetatable({}, getmetatable(self))
		self[key] = new
		return new
	end,
}

--- A library for easily creating and managing reactive state.
--- @class Flux
local Flux = {
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

--- @within Flux
--- A scope object for organizing and cleaning up Flux states
--- @prop Scope Scope
Flux.Scope = setmetatable({}, scopeMetatable)

--- @within Flux
--- A marker for defining Instance attributes in [Flux.edit]
--- @prop Attribute newproxy
--- @readonly
Flux.Attribute = newproxy()

--- @within Flux
--- A marker for defining Instance children in [Flux.edit]
--- @prop Children newproxy
--- @readonly
Flux.Children = newproxy()

--- @within Flux
--- Markers for defining events in [Flux.edit]
--- @prop Event { Attribute = newproxy, Property = newproxy }
--- @readonly
Flux.Event = table.freeze({ Attribute = newproxy(), Property = newproxy() })

--- Adds a dependency to the current state
function Flux:_addDependency<T>(dependency: Types.State<T>)
	if isState(dependency) then
		assertNotCircular(self, dependency)
		dependency._dependents[self] = true
	end
	self._dependencies[dependency] = true
end

--- Removes a dependency from the current state
function Flux:_removeDependency<T>(dependency: Types.State<T>)
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
		local computation = _operation[1] :: Types.Function
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
						TweenService:Create(instance, self._tweenInfo, { [v] = value }):Play()
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
	for _, disconnect in self._binds._cleanup do
		if disconnect then
			disconnect()
		end
	end
	table.clear(self._dependents)
	table.clear(self._binds)
	table.clear(self)
end

--- Adds a hook callback function to be called when the state changes
function Flux:hook(callback: Types.Function): Types.Function
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
function Flux:set<T>(new: T, forceUpdate: boolean?, noTween: boolean?): Types.State<T>
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

local instanceStateRef: { [Instance]: { [string | Types.State<any>]: string | Types.State<any> } } = {}

local function setupBind(instance: Instance, value: Types.State<any>, property: string)
	if not value._binds then
		value._binds = { _cleanup = {} }
	end
	if not value._binds[instance] then
		value._binds[instance] = {}
		table.insert(
			value._binds._cleanup,
			instance.Destroying:Connect(function()
				value._binds[instance] = nil
				instanceStateRef[instance][value] = nil
			end)
		)
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
local function cleanBind(instance: Instance, value: Types.State<any>, property: string)
	-- TODO: attempt to destroy it if no other dependents?
	local ref = instanceStateRef[instance]
	if not ref then
		return
	end
	local existing = instanceStateRef[instance][property]
	if not existing then
		return
	end

	local bind = existing._binds[instance]
	if string.find(property, ".", 1, true) == 1 then -- attribute
		bind[string.sub(property, 2)] = nil
	else -- property
		local foundIndex = table.find(bind, property)
		if foundIndex then
			table.remove(bind, foundIndex)
		end
	end
end

--- Edits an existing Instance with Flux state bindings and other properties
function Flux.edit(instance: Instance, definition: Types.Dict<any>): Instance
	local parent = definition.Parent
	definition.Parent = nil

	local attributes = definition[Flux.Attribute]
	local children = definition[Flux.Children]
	local events = definition[Flux.Event]
	local eventAttributes = definition[Flux.Event.Attribute]
	local eventProperties = definition[Flux.Event.Property]

	definition[Flux.Attribute] = nil
	definition[Flux.Children] = nil
	definition[Flux.Event] = nil
	definition[Flux.Event.Attribute] = nil
	definition[Flux.Event.Property] = nil

	-- numeric index child definition
	for index, child in ipairs(definition) do
		if typeof(child) == "Instance" then
			child.Parent = instance
		end
		definition[index] = nil
	end

	for property, value in definition do
		cleanBind(instance, value, property)
		if isState(value) then
			setupBind(instance, value, property)
			table.insert(value._binds[instance], property)
		end
		setProperty(instance, property, peek(value))
	end

	if attributes then
		if typeof(attributes) ~= "table" then
			error("Invalid Flux.Attribute definition")
		end
		for attribute, value in attributes do
			cleanBind(instance, value, "." .. attribute)
			if isState(value) then
				setupBind(instance, value, "." .. attribute)
				value._binds[instance][attribute] = true
			end
			instance:SetAttribute(attribute, peek(value))
		end
	end

	if children then
		if typeof(children) ~= "table" then
			error("Invalid Flux.Children definition")
		end
		for name, child in children do
			child.Name = name or child.Name
			child.Parent = instance
		end
	end

	if events then
		if typeof(events) ~= "table" then
			error("Invalid Flux.Event definition")
		end
		for event, callback in events do
			(instance[event] :: RBXScriptSignal):Connect(callback)
		end
	end

	if eventAttributes then
		if typeof(eventAttributes) ~= "table" then
			error("Invalid Flux.Event.Attribute definition")
		end
		for attribute, callback in eventAttributes do
			instance:GetAttributeChangedSignal(attribute):Connect(callback)
		end
	end

	if eventProperties then
		if typeof(eventProperties) ~= "table" then
			error("Invalid Flux.Event.Property definition")
		end
		for property, callback in eventProperties do
			instance:GetPropertyChangedSignal(property):Connect(callback)
		end
	end

	if typeof(parent) == "Instance" then
		instance.Parent = parent
	end
	return instance
end

--- Creates a new Instance with Flux state bindings and other properties
function Flux.new(className: string): (properties: Types.Dict<any>) -> Instance
	return function(properties: Types.Dict<any>)
		return Flux.edit(Instance.new(className), properties)
	end
end

--- Creates a computed state based on other states or static values
function Flux.computeFrom<T>(computation: (...any) -> T, ...: any): Types.State<T>
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
function Flux.compute<T>(computation: (use: <U>(U | Types.State<U>) -> U?) -> T): Types.State<T>
	local new = Flux.state(nil)
	local function use<U>(state: U | Types.State<U>): U?
		if not isState(state) then
			error("Invalid Flux state object")
		end
		new:_addDependency(state)
		return peek(state) :: U
	end
	local result = computation(use)
	new._value = result
	new._operation = { computation, peek }
	return new
end

--- Applies TweenService tweens with Instance properties bound to the Flux state
function Flux.tween<T>(tweenInfo: TweenInfo, state: Types.State<T>): Types.State<T>
	if not isState(state) then
		error("Invalid Flux state object")
	end
	state._tweenInfo = tweenInfo
	return state
end

--- Creates a new Flux state with an initial value
function Flux.state<T>(initialValue: T | Types.State<T> | Instance, property: string?): Types.State<T>
	if isState(initialValue) then
		return initialValue :: Types.State<T>
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
