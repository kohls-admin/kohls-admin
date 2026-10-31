--!strict
--[[
Flux: fine-grained reactive UI for Roblox. The reactive graph and the instance API are flat on `Flux`; utilities live
in namespaces (`Flux.Color`, `Flux.Find`, `Flux.Interact`, `Flux.Motion`, `Flux.Responsive`, `Flux.Store`, and the
`Flux.Defaults` and `Flux.Flags` settings).

```luau
local count = Flux.signal(0)
Flux.new "TextButton" {
	Parent = gui,
	Text = function() return `Clicked {count()} times` end,
	Activated = function() count(count() + 1) end,
}
```
]]

local Async = require("@self/Async")
local Bind = require("@self/Bind")
local Clock = require("@self/Clock")
local Conditional = require("@self/Conditional")
local Edit = require("@self/Edit")
local Graph = require("@self/Graph")
local Interact = require("@self/Interact")
local Layout = require("@self/Layout")
local Motion = require("@self/Motion")
local Responsive = require("@self/Responsive")
local Store = require("@self/Store")
local Type = require("@self/Type")

export type Node<T> = Graph.Node<T>
export type State<T> = Graph.State<T>
export type Reactive<T> = Graph.Reactive<T>
export type Unwrap<T> = Graph.Unwrap<T>
export type Owner = Graph.Owner
export type Cleanable = Graph.Cleanable
-- The property table `Flux.new(className)` accepts (typed properties and events, directives, numeric children), with a
-- component's own props from `Extra` merged in.
export type Props<ClassName, Extra = {}> = Type.Merge<Type.Properties<Type.Resolve<ClassName>>, Extra>
export type Child = Type.Child
export type Children = Type.Children
-- A component: a function building an instance from its props.
export type Component<P, I = Instance> = (props: P) -> I
export type Partial<T> = Edit.Partial<T>
export type Pick<T, G> = Edit.Pick<T, G>
export type Omit<T, G> = Edit.Omit<T, G>

export type Async<T> = Async.Async<T>
export type AsyncState = Async.AsyncState
export type Context<T> = Graph.Context<T>
export type Selector<K> = Conditional.Selector<K>
export type Spring<T> = Motion.Spring<T>
export type HoverOptions = Interact.HoverOptions

export type Breakpoint = Responsive.Breakpoint
export type Input = Responsive.Input
export type Platform = Responsive.Platform
export type TextSize = Responsive.TextSize
export type DisplaySize = Responsive.DisplaySize

export type Length = Layout.Length
export type ReactiveLength = Layout.ReactiveLength
export type Insets = Layout.Insets
export type Align = Layout.Align
export type FlexAlign = Layout.FlexAlign
export type LineAlign = Layout.LineAlign
export type Direction = Layout.Direction
export type FlexMode = Layout.FlexMode
export type PaddingSides = Layout.PaddingSides
export type CornerSides = Layout.CornerSides
export type ListConfig = Layout.ListConfig
export type GridConfig = Layout.GridConfig
export type StrokeConfig = Layout.StrokeConfig
export type GradientConfig = Layout.GradientConfig
export type SizeConstraintConfig = Layout.SizeConstraintConfig
export type TextSizeConstraintConfig = Layout.TextSizeConstraintConfig

local construct = Edit.new
local editInstance = Edit.edit

local Constructors = setmetatable({}, {
	__index = function(self: any, class: string)
		if type(class) ~= "string" then
			error(`String expected, got {typeof(class)}`, 3)
		end
		self[class] = function(properties: Type.Map<any>): Instance
			return construct(class, properties)
		end
		return self[class]
	end,
})

local Flux = {
	--[[
	<strong>Clock</strong>: the time Flux and your code run on. `now` (monotonic) and `wall` (Unix, server-synced) read
	it; `delay`, `wait`, `defer`, `cancel` and `connect(phase, fn)` schedule on it, like `task.*` and the RunService
	frame signals. Tests turn on a manual clock (`manual(true)`; always on headless): `step(seconds, frameLength?)`
	advances time, runs due timers and frame subscribers, steps springs and tweens, and flushes the reactive graph in
	order; `drain` runs deferred work and `reset` cancels all pending tasks.

	[Open Documentation](https://flux.kohl.gg/guide/tips/testing)
	]]
	Clock = table.freeze({
		now = Clock.now,
		wall = Clock.wall,
		delay = Clock.delay,
		wait = Clock.wait,
		defer = Clock.defer,
		cancel = Clock.cancel,
		connect = Clock.connect,
		manual = Clock.manual,
		isManual = Clock.isManual,
		step = Clock.step,
		drain = Clock.drain,
		reset = Clock.reset,
	}),
	--[[
	<strong>Color</strong>: a perceptual
	[`Color3`](https://create.roblox.com/docs/reference/engine/datatypes/Color3) toolkit working in gamut-clipped
	Oklab: `lighten`/`saturate` (negative amounts darken/desaturate), `mix`, `rotateHue`, and WCAG `contrast`/`readable`.

	[Open Documentation](https://flux.kohl.gg/guide/motion/color)
	]]
	Color = Motion.Color,
	--[[
	<strong>Defaults</strong>: per-class default properties applied to every
	[`Instance`](https://create.roblox.com/docs/reference/engine/classes/Instance) built by
	[`Flux.new`](https://flux.kohl.gg/guide/roblox/creation#the-flux-new-function). Mutable.

	[Open Documentation](https://flux.kohl.gg/guide/roblox/defaults)
	]]
	Defaults = Edit.Defaults,
	--[[
	<strong>Find</strong>: instance selectors for hydration. `Child`, `Descendant`, `Ancestor`, `Query` and their
	class-filtered variants apply props to matching instances around the one being edited.

	[Open Documentation](https://flux.kohl.gg/guide/roblox/hydration#instance-selectors-flux-find)
	]]
	Find = Edit.Find,
	--[[
	<strong>Flags</strong>: process-wide switches. `Flags.defaults` turns the per-class defaults of
	[`Flux.new`](https://flux.kohl.gg/guide/roblox/creation#the-flux-new-function) on or off.

	[Open Documentation](https://flux.kohl.gg/guide/roblox/defaults#disabling-defaults)
	]]
	Flags = Edit.Flags,
	--[[
	<strong>Interact</strong>: interaction state as read-only boolean nodes (`hover`, `press`, `selected`,
	`focused`) and the hit tests `pointIn`, `sunk` and `covered`.

	[Open Documentation](https://flux.kohl.gg/guide/utilities/interact)
	]]
	Interact = table.freeze({
		pointIn = Interact.pointIn,
		sunk = Interact.sunk,
		covered = Interact.covered,
		hover = Interact.hover,
		press = Interact.press,
		selected = Interact.selected,
		focused = Interact.focused,
	}),
	--[[
	<strong>Motion</strong>: the engine behind [`Flux.spring`](https://flux.kohl.gg/guide/motion/spring) and
	[`Flux.tween`](https://flux.kohl.gg/guide/motion/tween). `step(dt?)` advances every motion (wired to the frame
	automatically); call it yourself only to step motion in tests.

	[Open Documentation](https://flux.kohl.gg/guide/tips/testing#full-engine-tests-in-ci)
	]]
	Motion = table.freeze({
		step = Motion.step,
	}),
	--[[
	<strong>Responsive</strong>: the screen and the player as nodes: `viewport`, `scale`, and `breakpoint` follow the
	camera; `displaySize` and `platform` report the physical screen dimensions and device category; `input` follows the
	active input device; `textSize`, `reducedMotion`, and `preferredTransparency` track accessibility settings.
	`scaleOf`/`breakpointOf` build per-surface variants; `config` holds the defaults.

	[Open Documentation](https://flux.kohl.gg/guide/utilities/responsive)
	]]
	Responsive = table.freeze({
		config = Responsive.config,
		platform = Responsive.platform,
		viewport = Responsive.viewport,
		scale = Responsive.scale,
		breakpoint = Responsive.breakpoint,
		displaySize = Responsive.displaySize,
		input = Responsive.input,
		textSize = Responsive.textSize,
		reducedMotion = Responsive.reducedMotion,
		preferredTransparency = Responsive.preferredTransparency,
		scaleOf = Responsive.scaleOf,
		breakpointOf = Responsive.breakpointOf,
	}),
	--[[
	<strong>Store</strong>: helpers for [`Flux.store`](https://flux.kohl.gg/guide/concepts/stores) proxies:
	`insert`, `remove` and `move` for arrays, `reconcile` to diff in a snapshot, `unwrap` for the raw table, and
	`Destroy`.

	[Open Documentation](https://flux.kohl.gg/guide/concepts/stores)
	]]
	Store = table.freeze({
		insert = Store.insert,
		remove = Store.remove,
		move = Store.move,
		reconcile = Store.reconcile,
		unwrap = Store.unwrap,
		Destroy = Store.Destroy,
	}),

	-- The reactive graph
	signal = Graph.signal,
	computed = Graph.computed,
	effect = Graph.effect,
	createSignal = Graph.createSignal,
	createMemo = Graph.createMemo,
	createEffect = Graph.createEffect,
	getter = Graph.getter,
	setter = Graph.setter,
	scope = Graph.scope,
	flush = Graph.flush,
	cleanup = Graph.cleanup,
	dispose = Graph.dispose,
	getOwner = Graph.getOwner,
	withOwner = Graph.withOwner,
	read = Graph.read,
	raw = Graph.raw,
	untrack = Graph.untrack,
	retrack = Graph.retrack,
	isNode = Graph.isNode,
	isReactive = Graph.isReactive,
	on = Bind.on,

	-- State
	context = Graph.context,
	bindContext = Graph.bindContext,
	async = Async.new,
	selector = Conditional.selector,
	store = Store.new,
	split = Edit.split,
	safe = Graph.safe,

	-- Instances and control flow
	property = Bind.property,
	model = Bind.model,
	isModel = Bind.isModel,
	modelNode = Bind.modelNode,
	show = Conditional.show,
	showKeyed = Conditional.showKeyed,
	switch = Conditional.switch,
	otherwise = Conditional.otherwise,
	presence = Conditional.presence,
	pick = Conditional.pick,
	fallback = Conditional.fallback,
	forValue = Conditional.forValue,
	forIndex = Conditional.forIndex,
	spring = Motion.spring,
	tween = Motion.tween,

	-- Layout instances
	padding = Layout.padding,
	corner = Layout.corner,
	stroke = Layout.stroke,
	aspectRatio = Layout.aspectRatio,
	list = Layout.list,
	grid = Layout.grid,
	flex = Layout.flex,
	gradient = Layout.gradient,
	sizeConstraint = Layout.sizeConstraint,
	textSizeConstraint = Layout.textSizeConstraint,
}

local FluxMT = table.freeze({
	--[[
	The terse constructor: `Flux(value)` is a [signal](https://flux.kohl.gg/guide/concepts/signals), `Flux(fn)` a
	[computed](https://flux.kohl.gg/guide/concepts/computeds), and `Flux(instance, property)` a node following a Roblox
	[`Instance`](https://create.roblox.com/docs/reference/engine/classes/Instance) property, `"$Attribute"` /
	`"_attr_Attribute"`, or `"#Tag"` / `"_tag_Tag"`. A node is returned as is. The result is a `Node<any>`; use
	`Flux.signal`, `Flux.computed`, `Flux.effect` and `Flux.property` for typed nodes.

	```luau
	local size = Flux(frame, "AbsoluteSize")
	```

	[Open Documentation](https://flux.kohl.gg/guide/concepts/signals#creating-a-signal)
	]]
	__call = function(_: any, obj: any, propertyName: string?): Graph.Node<any>
		local node = Bind.node(obj, propertyName)
		return node
	end,
})

--[[
Hydrates an existing Roblox [`Instance`](https://create.roblox.com/docs/reference/engine/classes/Instance): applies
reactive properties, events and directives like
[`Flux.new`](https://flux.kohl.gg/guide/roblox/creation#the-flux-new-function), onto an instance you already have.
Bindings created inside a [`Flux.scope`](https://flux.kohl.gg/guide/concepts/scopes) disconnect when the scope is destroyed.

```luau
Flux.edit(existingLabel) { Text = function() return `HP {health()}` end }
```

[Open Documentation](https://flux.kohl.gg/guide/roblox/hydration#the-flux-edit-function)
]]
function Flux.edit<T>(instance: T & Instance)
	return function(properties: Type.EditProperties<T>): T
		return editInstance(instance, properties)
	end
end

--[[
Creates a Roblox [`Instance`](https://create.roblox.com/docs/reference/engine/classes/Instance) of `className` with
its per-class [defaults](https://flux.kohl.gg/guide/roblox/defaults), then takes a property table of values, nodes,
getters, events, children, prefix keys (`_Prop`, `_attr_Name`, `__attr_Name`, `_tag_Name`, `__tag_Name`), and
directives (`__EVENT`, `__ATTR`, `__TAG`, `__REF`, `__CLEAN`). Created inside a
[`Flux.scope`](https://flux.kohl.gg/guide/concepts/scopes), the instance is destroyed when the scope is destroyed.

```luau
Flux.new "Frame" {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = function() return if hovered() then 0 else 0.5 end,
	_attr_Kind = "Panel",
	_tag_Interactive = true,
	Flux.new "UICorner" {},
}
```

[Open Documentation](https://flux.kohl.gg/guide/roblox/creation#the-flux-new-function)
]]
function Flux.new<T>(className: T | keyof<Type.Creatable>)
	return Constructors[className] :: (Type.Properties<Type.Resolve<T>>) -> Type.Resolve<T>
end

if game then
	local RunService = game:GetService("RunService")
	local frame = if RunService:IsClient() then RunService.PreRender else RunService.Heartbeat
	local _frameConnection = frame:Connect(function(dt: number)
		if not Clock.isManual() then
			Motion.step(dt)
			Graph.flush()
		end
	end)
end

Clock._internal.setFrame(function(dt: number)
	Motion.step(dt)
	Graph.flush()
end)

return table.freeze(setmetatable(Flux, FluxMT))
