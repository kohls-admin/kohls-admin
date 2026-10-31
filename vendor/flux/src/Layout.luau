--!strict
--[[
Layout instances with friendly, reactive arguments: `padding`, `corner`, `stroke`, `list`, `grid`, `flex`, `gradient`,
`aspectRatio`, `sizeConstraint`, `textSizeConstraint`. Each is flat on `Flux`.

```luau
Flux.new "Frame" { Flux.list { gap = 8, align = "center" }, Flux.corner(12) }
```
]]

local Compat = require("./Compat")
local Edit = require("./Edit")
local Graph = require("./Graph")

local construct: (className: string, props: Props) -> any = Edit.new

local Color3 = Compat.Color3
local ColorSequence = Compat.ColorSequence
local ColorSequenceKeypoint = Compat.ColorSequenceKeypoint
local Enum = Compat.Enum
local NumberSequence = Compat.NumberSequence
local NumberSequenceKeypoint = Compat.NumberSequenceKeypoint
local UDim = Compat.UDim
local UDim2 = Compat.UDim2
local Vector2 = Compat.Vector2
local typeof = Compat.typeof
local warn = Compat.warn

local computed = Graph.computed
local isDynamic = Graph.isDynamic
local isNode = Graph.isNode
local new = Graph.new
local read: (source: any) -> any = Graph.read

--- @ignore
type Props = { [string]: any }
--- @ignore
type EnumMap = { [string]: EnumItem }

--- @ignore
export type Reactive<T> = Graph.Reactive<T>
export type Length = number | UDim
export type ReactiveLength = Reactive<number> | Reactive<UDim>
export type Insets = { top: number?, bottom: number?, left: number?, right: number? }
export type Align = "start" | "center" | "end"
export type FlexAlign = Align | "between" | "around" | "evenly" | "stretch" | "fill" | "none"
export type LineAlign = Align | "stretch" | "automatic"
export type Direction = "x" | "y"
export type FlexMode = "fill" | "grow" | "shrink" | "none"

export type PaddingSides = {
	top: ReactiveLength?,
	bottom: ReactiveLength?,
	left: ReactiveLength?,
	right: ReactiveLength?,
	x: ReactiveLength?,
	y: ReactiveLength?,
}

export type ListConfig = {
	gap: ReactiveLength?,
	direction: Reactive<Direction | Enum.FillDirection>?,
	align: Reactive<FlexAlign>?,
	justify: Reactive<FlexAlign>?,
	horizontalAlign: Reactive<FlexAlign | Enum.HorizontalAlignment | Enum.UIFlexAlignment>?,
	verticalAlign: Reactive<FlexAlign | Enum.VerticalAlignment | Enum.UIFlexAlignment>?,
	lineAlign: Reactive<LineAlign | Enum.ItemLineAlignment>?,
	wraps: Reactive<boolean>?,
}

export type GridConfig = {
	cell: Reactive<number | Vector2 | UDim2>?,
	gap: Reactive<number | Vector2 | UDim2>?,
	fill: Reactive<Direction | Enum.FillDirection>?,
	align: Reactive<Align | Enum.HorizontalAlignment>?,
	justify: Reactive<Align | Enum.VerticalAlignment>?,
	maxCells: Reactive<number>?,
}

export type StrokeConfig = {
	thickness: Reactive<number>?,
	color: Reactive<Color3>?,
	transparency: Reactive<number>?,
	mode: Reactive<"contextual" | "border" | Enum.ApplyStrokeMode>?,
	joins: Reactive<"round" | "bevel" | "miter" | Enum.LineJoinMode>?,
	position: Reactive<"inner" | "center" | "outer" | Enum.BorderStrokePosition>?,
	offset: Reactive<number | UDim>?,
}

export type CornerSides = {
	radius: ReactiveLength?,
	topLeft: ReactiveLength?,
	topRight: ReactiveLength?,
	bottomLeft: ReactiveLength?,
	bottomRight: ReactiveLength?,
	top: ReactiveLength?,
	bottom: ReactiveLength?,
	left: ReactiveLength?,
	right: ReactiveLength?,
}

export type GradientConfig = {
	color: Reactive<Color3 | ColorSequence | { Color3 }>?,
	transparency: Reactive<number | NumberSequence | { number }>?,
	rotation: Reactive<number>?,
	offset: Reactive<Vector2>?,
	enabled: Reactive<boolean>?,
}

export type SizeConstraintConfig = {
	min: Reactive<Vector2>?,
	max: Reactive<Vector2>?,
	minWidth: Reactive<number>?,
	minHeight: Reactive<number>?,
	maxWidth: Reactive<number>?,
	maxHeight: Reactive<number>?,
}

export type TextSizeConstraintConfig = {
	min: Reactive<number>?,
	max: Reactive<number>?,
}

local EMPTY: any = table.freeze({})
local ZERO_UDIM = UDim.new()
local SORT_ORDER = Enum.SortOrder.LayoutOrder
local FILL_DIRECTION: EnumMap = { x = Enum.FillDirection.Horizontal, y = Enum.FillDirection.Vertical }
local HORIZONTAL_ALIGN: EnumMap = {
	start = Enum.HorizontalAlignment.Left,
	center = Enum.HorizontalAlignment.Center,
	["end"] = Enum.HorizontalAlignment.Right,
}
local VERTICAL_ALIGN: EnumMap = {
	start = Enum.VerticalAlignment.Top,
	center = Enum.VerticalAlignment.Center,
	["end"] = Enum.VerticalAlignment.Bottom,
}
local FLEX_ALIGNMENT: EnumMap = {
	none = Enum.UIFlexAlignment.None,
	fill = Enum.UIFlexAlignment.Fill,
	stretch = Enum.UIFlexAlignment.Fill,
	between = Enum.UIFlexAlignment.SpaceBetween,
	around = Enum.UIFlexAlignment.SpaceAround,
	evenly = Enum.UIFlexAlignment.SpaceEvenly,
}
local ITEM_LINE_ALIGN: EnumMap = {
	automatic = Enum.ItemLineAlignment.Automatic,
	start = Enum.ItemLineAlignment.Start,
	center = Enum.ItemLineAlignment.Center,
	["end"] = Enum.ItemLineAlignment.End,
	stretch = Enum.ItemLineAlignment.Stretch,
}
local FLEX_MODE: EnumMap = {
	fill = Enum.UIFlexMode.Fill,
	grow = Enum.UIFlexMode.Grow,
	shrink = Enum.UIFlexMode.Shrink,
	none = Enum.UIFlexMode.None,
}
local ASPECT_TYPE: EnumMap = {
	fit = Enum.AspectType.FitWithinMaxSize,
	scale = Enum.AspectType.ScaleWithParentSize,
}
local DOMINANT_AXIS: EnumMap = { width = Enum.DominantAxis.Width, height = Enum.DominantAxis.Height }
local STROKE_MODE: EnumMap = { contextual = Enum.ApplyStrokeMode.Contextual, border = Enum.ApplyStrokeMode.Border }
local LINE_JOIN: EnumMap = {
	round = Enum.LineJoinMode.Round,
	bevel = Enum.LineJoinMode.Bevel,
	miter = Enum.LineJoinMode.Miter,
}
local STROKE_POSITION: EnumMap = {
	inner = Enum.BorderStrokePosition.Inner,
	center = Enum.BorderStrokePosition.Center,
	outer = Enum.BorderStrokePosition.Outer,
}

local FLEX_ITEMS: { [EnumItem]: true } = {}
for _, item in FLEX_ALIGNMENT do
	FLEX_ITEMS[item] = true
end

local warnedEnums: { [string]: boolean } = {}

local function resolveEnum(map: EnumMap, value: any, label: string): any
	if value == nil then
		return nil
	elseif type(value) == "string" then
		local mapped = map[value]
		if mapped == nil then
			local key = `{label}:{value}`
			if not warnedEnums[key] then
				warnedEnums[key] = true
				warn(`[Flux] unknown {label} "{value}"; falling back to default`)
			end
			return nil
		end
		return mapped
	end
	return value
end

local function enumProp(map: EnumMap, value: any, label: string, default: EnumItem): any
	if isDynamic(value) then
		return function()
			local resolved = resolveEnum(map, read(value), label)
			return if resolved == nil then default else resolved
		end
	end
	return resolveEnum(map, value, label)
end

local function toUDim(value: any): UDim
	return if type(value) == "number" then UDim.new(0, value) else value
end

local function toUDim2(value: any): UDim2
	local kind = typeof(value)
	if kind == "Vector2" then
		return UDim2.fromOffset(value.X, value.Y)
	elseif kind == "number" then
		return UDim2.fromOffset(value, value)
	end
	return value
end

local function reactiveProp(value: any, convert: (any) -> any): any
	if isDynamic(value) then
		return function()
			return convert(read(value))
		end
	end
	return convert(value)
end

local function udimProp(value: any): any
	return reactiveProp(value, toUDim)
end

local function cornerProp(sides: CornerSides, corner: string, vertical: string, horizontal: string): any
	local entries: any = sides
	local value = entries[corner] or entries[vertical] or entries[horizontal] or sides.radius
	return udimProp(if value == nil then 8 else value)
end

local function spread(values: { any }, Keypoint: any, Sequence: any): any
	local count = #values
	if count == 1 then
		return Sequence.new(values[1])
	end
	local keypoints = table.create(count)
	for index, value in values do
		keypoints[index] = Keypoint.new((index - 1) / (count - 1), value)
	end
	return Sequence.new(keypoints)
end

local function toColorSequence(value: any): ColorSequence
	local kind = typeof(value)
	if kind == "ColorSequence" then
		return value
	elseif kind == "Color3" then
		return ColorSequence.new(value :: Color3)
	elseif kind == "table" and #value > 0 then
		return spread(value, ColorSequenceKeypoint, ColorSequence)
	end
	return ColorSequence.new(Color3.new(1, 1, 1))
end

local function toNumberSequence(value: any): NumberSequence
	local kind = typeof(value)
	if kind == "NumberSequence" then
		return value
	elseif kind == "number" then
		return NumberSequence.new(value :: number)
	elseif kind == "table" and #value > 0 then
		return spread(value, NumberSequenceKeypoint, NumberSequence)
	end
	return NumberSequence.new(0)
end

local function toAxisPair(vector: any, x: any, y: any, fallback: number): Vector2
	local base = read(vector)
	local width, height = read(x), read(y)
	return Vector2.new(
		if width ~= nil then width elseif base ~= nil then base.X else fallback,
		if height ~= nil then height elseif base ~= nil then base.Y else fallback
	)
end

local function axisPair(vector: any, x: any, y: any, fallback: number): any
	if vector == nil and x == nil and y == nil then
		return nil
	end
	if isDynamic(vector) or isDynamic(x) or isDynamic(y) then
		return function(): Vector2
			return toAxisPair(vector, x, y, fallback)
		end
	end
	return toAxisPair(vector, x, y, fallback)
end

local function setSide(props: Props, prop: string, value: any)
	if value ~= nil then
		props[prop] = udimProp(value)
	end
end

local function paddingSide(source: any, field: string, axis: string): () -> UDim
	return function()
		local value = read(source)
		if typeof(value) == "table" then
			return toUDim(value[field] or value[axis] or 0)
		elseif value == nil then
			return ZERO_UDIM
		end
		return toUDim(value)
	end
end

local function toFlexAlignment(value: any): EnumItem?
	if type(value) == "string" then
		return FLEX_ALIGNMENT[value]
	end
	return if FLEX_ITEMS[value] then value else nil
end

local function readListAlign(
	pinned: any,
	direction: any,
	align: any,
	justify: any,
	axis: Direction,
	label: string
): (any, string)
	if pinned ~= nil then
		local override = read(pinned)
		if override ~= nil then
			return override, label
		end
	end
	local main = read(direction) == FILL_DIRECTION.x
	if (axis == "x") == main then
		return read(justify), "justify"
	end
	return read(align), "align"
end

local function listAlign(cfg: ListConfig, direction: any, axis: Direction, map: EnumMap, label: string): (any, any)
	local pinned = if axis == "x" then cfg.horizontalAlign else cfg.verticalAlign
	local align, justify = cfg.align, cfg.justify

	if pinned == nil and align == nil and justify == nil then
		return nil, nil
	end

	local reactive: boolean
	if pinned ~= nil then
		reactive = isDynamic(pinned)
	elseif isDynamic(direction) then
		reactive = true
	else
		local active = if (axis == "x") == (direction == FILL_DIRECTION.x) then justify else align
		if active == nil then
			return nil, nil
		end
		reactive = isDynamic(active)
	end
	if reactive then
		return function()
			local v, source = readListAlign(pinned, direction, align, justify, axis, label)
			return if toFlexAlignment(v) ~= nil then map.start else resolveEnum(map, v, source) or map.start
		end, function()
			local v, _ = readListAlign(pinned, direction, align, justify, axis, label)
			return toFlexAlignment(v) or FLEX_ALIGNMENT.none
		end
	end

	local v, source = readListAlign(pinned, direction, align, justify, axis, label)
	local flex = toFlexAlignment(v)
	if flex ~= nil then
		return map.start, flex
	end
	return resolveEnum(map, v, source), nil
end

local Layout = {}

--[[
Creates a [`UIPadding`](https://create.roblox.com/docs/reference/engine/classes/UIPadding) from a single
length (applied to all sides), a per-side `{ top, bottom, left, right, x, y }` table, or a reactive
[node](https://flux.kohl.gg/guide/concepts/signals) or function yielding a length or a
`{ top, bottom, left, right }` struct. Plain `number` values are offset pixels; a [`UDim`](https://create.roblox.com/docs/reference/engine/datatypes/UDim) is used as-is.
<em>Reactive sides bind and update in place; a reactive source may change shape between updates, and
`nil` reads as no padding.</em>

[Open Documentation](https://flux.kohl.gg/guide/utilities/layout#padding)
]]
function Layout.padding(value: Length | PaddingSides | Graph.Node<any> | (() -> Length | Insets)): UIPadding
	local props: Props = {}

	if isDynamic(value) then
		local rawValue: any = value
		local source: any = new(rawValue)
		props.PaddingTop = paddingSide(source, "top", "y")
		props.PaddingBottom = paddingSide(source, "bottom", "y")
		props.PaddingLeft = paddingSide(source, "left", "x")
		props.PaddingRight = paddingSide(source, "right", "x")
		if source ~= value then
			props.__CLEAN = { source }
		end
	elseif typeof(value) == "table" then
		local sides = value :: PaddingSides
		setSide(props, "PaddingTop", sides.top or sides.y)
		setSide(props, "PaddingBottom", sides.bottom or sides.y)
		setSide(props, "PaddingLeft", sides.left or sides.x)
		setSide(props, "PaddingRight", sides.right or sides.x)
	else
		local side = udimProp(value)
		props.PaddingTop, props.PaddingBottom, props.PaddingLeft, props.PaddingRight = side, side, side, side
	end

	return construct("UIPadding", props)
end

--[[
Creates a [`UICorner`](https://create.roblox.com/docs/reference/engine/classes/UICorner) rounding the
parent's corners. `radius` is offset pixels or a
[`UDim`](https://create.roblox.com/docs/reference/engine/datatypes/UDim), optionally reactive; omit it
for the engine default (8 px). A `{ topLeft, topRight, bottomLeft, bottomRight, top, bottom, left, right, radius }`
table rounds each corner on its own, for a card whose header meets its body or a button at the end of a
group; a corner named nowhere keeps the engine default.

[Open Documentation](https://flux.kohl.gg/guide/utilities/layout#corner)
]]
function Layout.corner(radius: ReactiveLength | CornerSides?): UICorner
	local rawRadius: any = radius
	if type(radius) == "table" and not isNode(radius) and rawRadius.Offset == nil then
		local sides: CornerSides = rawRadius
		return construct("UICorner", {
			TopLeftRadius = cornerProp(sides, "topLeft", "top", "left"),
			TopRightRadius = cornerProp(sides, "topRight", "top", "right"),
			BottomLeftRadius = cornerProp(sides, "bottomLeft", "bottom", "left"),
			BottomRightRadius = cornerProp(sides, "bottomRight", "bottom", "right"),
		})
	end
	return construct("UICorner", { CornerRadius = udimProp(radius) })
end

--[[
Creates a [`UIStroke`](https://create.roblox.com/docs/reference/engine/classes/UIStroke) outlining the
parent. `thickness` (px), `color`, and `transparency` bind reactively; `mode` is `"contextual"` (text
outline on text objects, border otherwise) or `"border"`, and `joins` is `"round"`/`"bevel"`/`"miter"`,
each also accepting the raw Enum or a reactive source. For a border, `position` is `"inner"` (drawn inside the
parent's box, so nothing around it clips it and a thicker stroke grows inward), `"center"` or `"outer"` (the engine
default), and `offset` moves it out (px or a `UDim`; negative moves it in).

[Open Documentation](https://flux.kohl.gg/guide/utilities/layout#stroke)
]]
function Layout.stroke(config: StrokeConfig?): UIStroke
	local cfg: StrokeConfig = config or EMPTY
	return construct("UIStroke", {
		Thickness = cfg.thickness,
		Color = cfg.color,
		Transparency = cfg.transparency,
		ApplyStrokeMode = enumProp(STROKE_MODE, cfg.mode, "strokeMode", STROKE_MODE.contextual),
		LineJoinMode = enumProp(LINE_JOIN, cfg.joins, "lineJoin", LINE_JOIN.round),
		BorderStrokePosition = if cfg.position ~= nil
			then enumProp(STROKE_POSITION, cfg.position, "strokePosition", STROKE_POSITION.outer)
			else nil,
		BorderOffset = if cfg.offset ~= nil then udimProp(cfg.offset) else nil,
	})
end

--[[
Creates a [`UIAspectRatioConstraint`](https://create.roblox.com/docs/reference/engine/classes/UIAspectRatioConstraint)
constraining a frame's width-to-height ratio to `ratio`. `aspectType` accepts `"fit"` (`FitWithinMaxSize`), `"scale"`
(`ScaleWithParentSize`), or an [`Enum.AspectType`](https://create.roblox.com/docs/reference/engine/enums/AspectType);
`dominantAxis` accepts `"width"`, `"height"`, or an
[`Enum.DominantAxis`](https://create.roblox.com/docs/reference/engine/enums/DominantAxis) (unknown strings warn and
fall back). Every argument may be reactive.

[Open Documentation](https://flux.kohl.gg/guide/utilities/layout#aspectratio)
]]
function Layout.aspectRatio(
	ratio: Reactive<number>,
	aspectType: Reactive<"fit" | "scale" | Enum.AspectType>?,
	dominantAxis: Reactive<"width" | "height" | Enum.DominantAxis>?
): UIAspectRatioConstraint
	return construct("UIAspectRatioConstraint", {
		AspectRatio = ratio,
		AspectType = enumProp(ASPECT_TYPE, aspectType, "aspectType", ASPECT_TYPE.fit),
		DominantAxis = enumProp(DOMINANT_AXIS, dominantAxis, "dominantAxis", DOMINANT_AXIS.width),
	})
end

--[[
Creates a [`UIListLayout`](https://create.roblox.com/docs/reference/engine/classes/UIListLayout) that
arranges siblings in a line with flexbox semantics. `gap` is the spacing between items (offset px or a
[`UDim`](https://create.roblox.com/docs/reference/engine/datatypes/UDim)); `direction` is `"x"`/`"y"`.
`align` sets the <strong>cross-axis</strong> and `justify` the <strong>main-axis</strong> value:
`"start"`/`"center"`/`"end"` align items, `"between"`/`"around"`/`"evenly"` distribute the free space,
and `"stretch"`/`"fill"` resize items to fill the axis. `horizontalAlign` and `verticalAlign` provide explicit
axis-pinned overrides; `wraps` flows items onto multiple lines, and `lineAlign` aligns items within
their wrapped line. <em>Every value, including `direction`, may be reactive; alignments re-route when a
reactive `direction` flips.</em>

[Open Documentation](https://flux.kohl.gg/guide/utilities/layout#list)
]]
function Layout.list(config: ListConfig?): UIListLayout
	local cfg: ListConfig = config or EMPTY
	local props: Props = {
		SortOrder = SORT_ORDER,
		Padding = udimProp(cfg.gap),
		Wraps = cfg.wraps,
		ItemLineAlignment = enumProp(ITEM_LINE_ALIGN, cfg.lineAlign, "lineAlign", ITEM_LINE_ALIGN.automatic),
	}

	local direction: any = cfg.direction
	if isDynamic(direction) then
		local source = direction
		direction = computed(function()
			return resolveEnum(FILL_DIRECTION, read(source), "direction") or FILL_DIRECTION.y
		end)
		props.__CLEAN = { direction }
	else
		direction = resolveEnum(FILL_DIRECTION, direction, "direction")
	end
	props.FillDirection = direction

	props.HorizontalAlignment, props.HorizontalFlex =
		listAlign(cfg, direction, "x", HORIZONTAL_ALIGN, "horizontalAlign")
	props.VerticalAlignment, props.VerticalFlex = listAlign(cfg, direction, "y", VERTICAL_ALIGN, "verticalAlign")

	return construct("UIListLayout", props)
end

--[[
Creates a [`UIGridLayout`](https://create.roblox.com/docs/reference/engine/classes/UIGridLayout) that
arranges siblings in a uniform grid. `cell` is the cell size and `gap` is the spacing; each accepts a
[`Vector2`](https://create.roblox.com/docs/reference/engine/datatypes/Vector2), a `number` (offset px), or a
[`UDim2`](https://create.roblox.com/docs/reference/engine/datatypes/UDim2). `fill` is the flow direction
`"x"`/`"y"`; `align`/`justify` map to horizontal/vertical alignment; `maxCells` caps cells per line.
<em>Every value may be reactive.</em>

[Open Documentation](https://flux.kohl.gg/guide/utilities/layout#grid)
]]
function Layout.grid(config: GridConfig?): UIGridLayout
	local cfg: GridConfig = config or EMPTY
	return construct("UIGridLayout", {
		SortOrder = SORT_ORDER,
		CellSize = reactiveProp(cfg.cell, toUDim2),
		CellPadding = reactiveProp(cfg.gap, toUDim2),
		FillDirectionMaxCells = cfg.maxCells,
		FillDirection = enumProp(FILL_DIRECTION, cfg.fill, "fill", FILL_DIRECTION.x),
		HorizontalAlignment = enumProp(HORIZONTAL_ALIGN, cfg.align, "align", HORIZONTAL_ALIGN.start),
		VerticalAlignment = enumProp(VERTICAL_ALIGN, cfg.justify, "justify", VERTICAL_ALIGN.start),
	})
end

--[[
Creates a [`UIFlexItem`](https://create.roblox.com/docs/reference/engine/classes/UIFlexItem) controlling how
a child grows or shrinks inside a flex
[`UIListLayout`](https://create.roblox.com/docs/reference/engine/classes/UIListLayout). `mode` is `"fill"`
(the default when omitted), `"grow"`, `"shrink"`, or `"none"`, or a raw
[`Enum.UIFlexMode`](https://create.roblox.com/docs/reference/engine/enums/UIFlexMode), optionally reactive.

[Open Documentation](https://flux.kohl.gg/guide/utilities/layout#flex)
]]
function Layout.flex(mode: Reactive<FlexMode | Enum.UIFlexMode>?): UIFlexItem
	if isDynamic(mode) then
		return construct("UIFlexItem", {
			FlexMode = function()
				local value = read(mode)
				return if value == nil
					then FLEX_MODE.fill
					else resolveEnum(FLEX_MODE, value, "flexMode") or FLEX_MODE.none
			end,
		})
	end
	return construct("UIFlexItem", {
		FlexMode = if mode == nil then FLEX_MODE.fill else resolveEnum(FLEX_MODE, mode, "flexMode"),
	})
end

--[[
Creates a [`UIGradient`](https://create.roblox.com/docs/reference/engine/classes/UIGradient). `color` takes a
[`Color3`](https://create.roblox.com/docs/reference/engine/datatypes/Color3), an array of stops spread evenly from start
to end, or a [`ColorSequence`](https://create.roblox.com/docs/reference/engine/datatypes/ColorSequence); `transparency`
takes a number, an array of stops, or a
[`NumberSequence`](https://create.roblox.com/docs/reference/engine/datatypes/NumberSequence). `rotation` is in degrees,
and `offset` and `enabled` map straight through. <em>Every value may be reactive; a reactive stop array re-spreads
when it changes.</em>

[Open Documentation](https://flux.kohl.gg/guide/utilities/layout#gradient)
]]
function Layout.gradient(config: GradientConfig?): UIGradient
	local cfg: GradientConfig = config or EMPTY
	return construct("UIGradient", {
		Color = if cfg.color ~= nil then reactiveProp(cfg.color, toColorSequence) else nil,
		Transparency = if cfg.transparency ~= nil then reactiveProp(cfg.transparency, toNumberSequence) else nil,
		Rotation = cfg.rotation,
		Offset = cfg.offset,
		Enabled = cfg.enabled,
	})
end

--[[
Creates a [`UISizeConstraint`](https://create.roblox.com/docs/reference/engine/classes/UISizeConstraint) bounding its
parent's size. `min` and `max` are whole [`Vector2`](https://create.roblox.com/docs/reference/engine/datatypes/Vector2)
bounds; `minWidth`, `minHeight`, `maxWidth`, and `maxHeight` set a single axis and win over the matching vector
component. An axis not specified in `config` remains unconstrained. <em>Every value may be reactive.</em>

[Open Documentation](https://flux.kohl.gg/guide/utilities/layout#sizeconstraint)
]]
function Layout.sizeConstraint(config: SizeConstraintConfig?): UISizeConstraint
	local cfg: SizeConstraintConfig = config or EMPTY
	return construct("UISizeConstraint", {
		MinSize = axisPair(cfg.min, cfg.minWidth, cfg.minHeight, 0),
		MaxSize = axisPair(cfg.max, cfg.maxWidth, cfg.maxHeight, math.huge),
	})
end

--[[
Creates a [`UITextSizeConstraint`](https://create.roblox.com/docs/reference/engine/classes/UITextSizeConstraint)
bounding the text size of its parent to `min`/`max` pixels; an omitted bound keeps the engine default (1 and 100). A
`max` also caps the enlargement players get from a larger preferred
[text size](https://flux.kohl.gg/guide/utilities/responsive#text-size). <em>Both values may be reactive.</em>

[Open Documentation](https://flux.kohl.gg/guide/utilities/layout#textsizeconstraint)
]]
function Layout.textSizeConstraint(config: TextSizeConstraintConfig?): UITextSizeConstraint
	local cfg: TextSizeConstraintConfig = config or EMPTY
	return construct("UITextSizeConstraint", {
		MinTextSize = cfg.min,
		MaxTextSize = cfg.max,
	})
end

return table.freeze(Layout)
