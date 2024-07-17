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
	@type State { _update: (State<T>) -> boolean, _dependencies: Set<State<T>>, _dependents: Set<State<T>>, _binds: { [T]: any, _cleanup: List<any> }, _hooks: Dict<Function>, _value: T, _stateful: boolean, _operation: List<any>?, _tweenInfo: TweenInfo?, set: (self: State<T>, new: T, force: boolean?, noTween: boolean?) -> State<T>, get: (self: State<T>) -> T, hook: (self: State<T>, callback: Function) -> Function, Destroy: (self: State<T>) -> (), bindToProperty: (self: State<T>, instance: Instance, property: string) -> (), bindToAttribute: (self: State<T>, instance: Instance, attribute: string) -> (), }
]=]
export type State<T> = {
	_update: (State<T>) -> boolean,
	_dependencies: Set<State<T>>,
	_dependents: Set<State<T>>,
	_binds: { [T]: any, _cleanup: List<any> },
	_hooks: Dict<Function>,
	_value: T,
	_stateful: boolean,
	_operation: List<any>?,
	_tweenInfo: TweenInfo?,
	set: (self: State<T>, new: T, force: boolean?, noTween: boolean?) -> State<T>,
	get: (self: State<T>) -> T,
	hook: (self: State<T>, callback: Function) -> Function,
	Destroy: (self: State<T>) -> (),
	bindToProperty: (self: State<T>, instance: Instance, property: string) -> (),
	bindToAttribute: (self: State<T>, instance: Instance, attribute: string) -> (),
}

return nil
