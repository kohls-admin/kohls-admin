--!strict
--[[
Reactive UI library for Roblox and Luau, including fine-grained signals, declarative instances, layout, motion, `Flux.Clock`, and `Flux.Sync`.

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
local Sync = require("@self/Sync")
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
export type SyncSignal<T = any> = Sync.SyncSignal<T>
export type SyncValidator<T> = Sync.Validator<T>
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
	Shared time source for timers, frame callbacks, and deterministic test stepping.
	Call `Clock.manual(true)` and `Clock.step(seconds)` in tests to advance timers, motion, and frame flushes in order.

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
	Perceptual [`Color3`](https://create.roblox.com/docs/reference/engine/datatypes/Color3) utilities in Oklab (`lighten`, `saturate`, `mix`, `rotateHue`, and WCAG `contrast`/`readable`).

	[Open Documentation](https://flux.kohl.gg/guide/motion/color)
	]]
	Color = Motion.Color,
	--[[
	Mutable table of per-class default properties applied by [`Flux.new`](https://flux.kohl.gg/guide/roblox/creation#the-flux-new-function).

	[Open Documentation](https://flux.kohl.gg/guide/roblox/defaults)
	]]
	Defaults = Edit.Defaults,
	--[[
	Instance selectors (`Child`, `Descendant`, `Ancestor`, `Path`, `Query`) for hydrating trees inside [`Flux.edit`](https://flux.kohl.gg/guide/roblox/hydration).

	[Open Documentation](https://flux.kohl.gg/guide/roblox/hydration#instance-selectors-flux-find)
	]]
	Find = Edit.Find,
	--[[
	Global behavior flags (`Flags.defaults` toggles per-class defaults in [`Flux.new`](https://flux.kohl.gg/guide/roblox/creation#the-flux-new-function)).

	[Open Documentation](https://flux.kohl.gg/guide/roblox/defaults#disabling-defaults)
	]]
	Flags = Edit.Flags,
	--[[
	Read-only interaction state nodes (`hover`, `press`, `selected`, `focused`) and pointer hit-testing helpers (`pointIn`, `sunk`, `covered`).

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
	Advances active [`Flux.spring`](https://flux.kohl.gg/guide/motion/spring) and [`Flux.tween`](https://flux.kohl.gg/guide/motion/tween) nodes.
	Stepped automatically each frame, or manually in tests via `Motion.step(dt)`.

	[Open Documentation](https://flux.kohl.gg/guide/tips/testing#full-engine-tests-in-ci)
	]]
	Motion = table.freeze({
		step = Motion.step,
	}),
	--[[
	Reactive nodes for viewport size, UI scale, breakpoints, device platform, active input mode, and accessibility settings.

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
	Array mutation (`insert`, `remove`, `move`), snapshot diffing (`reconcile`), unwrapping (`unwrap`), and teardown (`Destroy`) for [`Flux.store`](https://flux.kohl.gg/guide/concepts/stores) proxies.

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
	--[[
	Network-synchronized signals replicated from the server to clients once per frame.
	Use `sig:of(player)` for per-player values and pass a `validate` callback to allow client writes.

	[Open Documentation](https://flux.kohl.gg/guide/concepts/sync)
	]]
	Sync = Sync :: Sync.Namespace,

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
	Terse untyped constructor for a [signal](https://flux.kohl.gg/guide/concepts/signals) (`Flux(value)`), [computed](https://flux.kohl.gg/guide/concepts/computeds) (`Flux(fn)`), or [instance property node](https://flux.kohl.gg/guide/concepts/signals#binding-from-an-instance-property) (`Flux(instance, key)`).
	Use `Flux.signal`, `Flux.computed`, and `Flux.property` when you want strict type inference.

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
Applies reactive properties, events, children, and directives to an existing [`Instance`](https://create.roblox.com/docs/reference/engine/classes/Instance).
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
Creates a Roblox [`Instance`](https://create.roblox.com/docs/reference/engine/classes/Instance) of `className` with its per-class [defaults](https://flux.kohl.gg/guide/roblox/defaults) and applies a table of properties, events, children, and directives.
When called inside a [`Flux.scope`](https://flux.kohl.gg/guide/concepts/scopes), the instance is destroyed with the scope.

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

local syncStep = Sync._internal.flushAll
local function stepFrame(dt: number)
	Motion.step(dt)
	Graph.flush()
	syncStep()
end

if game then
	local RunService = game:GetService("RunService")
	local frame = if RunService:IsClient() then RunService.PreRender else RunService.Heartbeat
	local _frameConnection = frame:Connect(function(dt: number)
		if not Clock.isManual() then
			stepFrame(dt)
		end
	end)
end

Clock._internal.setFrame(stepFrame)

return table.freeze(setmetatable(Flux, FluxMT))
