--!strict
--[[
Layout instances with friendly, reactive arguments: `padding`, `corner`, `stroke`, `list`, `grid`, `flex`, `scale`, `gradient`,
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
export type Insets = {
	top: Length?,
	bottom: Length?,
	left: Length?,
	right: Length?,
	x: Length?,
	y: Length?,
}
export type Align = "start" | "center" | "end"
export type FlexAlign = Align | "between" | "around" | "evenly" | "stretch" | "fill" | "none"
export type LineAlign = Align | "stretch" | "automatic"
export type Direction = "x" | "y"
export type FlexMode = "fill" | "grow" | "shrink" | "none" | "custom"

export type FlexConfig = {
	mode: Reactive<FlexMode | Enum.UIFlexMode>?,
	grow: Reactive<number>?,
	shrink: Reactive<number>?,
	lineAlign: Reactive<LineAlign | Enum.ItemLineAlignment>?,
}

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
	align: Reactive<Align | Enum.HorizontalAlignment | Enum.VerticalAlignment>?,
	justify: Reactive<Align | Enum.HorizontalAlignment | Enum.VerticalAlignment>?,
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
	color: Reactive<Color3 | ColorSequence | { Color3 } | { ColorSequenceKeypoint }>?,
	transparency: Reactive<number | NumberSequence | { number } | { NumberSequenceKeypoint }>?,
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

if Compat.Instance == nil or Enum == nil or UDim == nil or UDim2 == nil then
	return Compat.robloxStubs("Flux", {
		"padding",
		"corner",
		"stroke",
		"aspectRatio",
		"list",
		"grid",
		"flex",
		"scale",
		"gradient",
		"sizeConstraint",
		"textSizeConstraint",
	}) :: any
end

local EMPTY: any = table.freeze({})
local ZERO_UDIM = UDim.new()
local DEFAULT_CORNER = UDim.new(0, 8)
local DEFAULT_CELL_SIZE = UDim2.fromOffset(100, 100)
local DEFAULT_CELL_PADDING = UDim2.fromOffset(5, 5)
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
	custom = Enum.UIFlexMode.Custom,
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
	elseif value == nil then
		return nil
	end
	local resolved = resolveEnum(map, value, label)
	return if resolved == nil then default else resolved
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

local function defaultProp(value: any, default: any, convert: ((any) -> any)?): any
	if isDynamic(value) then
		return function()
			local v = read(value)
			if v == nil then
				return default
			end
			return if convert ~= nil then convert(v) else v
		end
	elseif value == nil then
		return nil
	end
	return if convert ~= nil then convert(value) else value
end

local function cornerProp(sides: CornerSides, corner: string, vertical: string, horizontal: string): any
	local entries: any = sides
	local c, v, h, r = entries[corner], entries[vertical], entries[horizontal], sides.radius
	if isDynamic(c) or isDynamic(v) or isDynamic(h) or isDynamic(r) then
		return function()
			local val = read(c)
			if val == nil then
				val = read(v)
			end
			if val == nil then
				val = read(h)
			end
			if val == nil then
				val = read(r)
			end
			return toUDim(if val == nil then 8 else val)
		end
	end
	local value = if c ~= nil then c elseif v ~= nil then v elseif h ~= nil then h else r
	return toUDim(if value == nil then 8 else value)
end

local function spread(values: { any }, Keypoint: any, Sequence: any, keypointType: string): any
	local count = #values
	if typeof(values[1]) == keypointType then
		if count == 1 then
			return Sequence.new(values[1].Value)
		end
		return Sequence.new(values)
	end
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
		return spread(value, ColorSequenceKeypoint, ColorSequence, "ColorSequenceKeypoint")
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
		return spread(value, NumberSequenceKeypoint, NumberSequence, "NumberSequenceKeypoint")
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

local function setSidePair(props: Props, prop: string, side: any, axis: any)
	if side == nil and axis == nil then
		return
	elseif isDynamic(side) or isDynamic(axis) then
		props[prop] = function()
			local val = read(side)
			if val == nil then
				val = read(axis)
			end
			return toUDim(if val == nil then 0 else val)
		end
	else
		props[prop] = toUDim(if side ~= nil then side else axis)
	end
end

local function paddingSide(source: any, field: string, axis: string): () -> UDim
	return function()
		local value = read(source)
		if typeof(value) == "table" then
			local side = read(value[field])
			if side == nil then
				side = read(value[axis])
			end
			return toUDim(if side == nil then 0 else side)
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

local function readAxisAlign(
	direction: any,
	align: any,
	justify: any,
	axis: Direction,
	pinned: any?,
	label: string?
): (any, string)
	if pinned ~= nil then
		local override = read(pinned)
		if override ~= nil then
			return override, label :: string
		end
	end
	if (axis == "x") == (read(direction) == FILL_DIRECTION.x) then
		return read(justify), "justify"
	end
	return read(align), "align"
end

local function isAxisAlignReactive(direction: any, align: any, justify: any, axis: Direction, pinned: any?): boolean?
	if pinned ~= nil then
		return isDynamic(pinned)
	elseif isDynamic(direction) then
		return true
	end
	local active = if (axis == "x") == (direction == FILL_DIRECTION.x) then justify else align
	if active == nil then
		return nil
	end
	return isDynamic(active)
end

local function listAlign(cfg: ListConfig, direction: any, axis: Direction, map: EnumMap, label: string): (any, any)
	local pinned = if axis == "x" then cfg.horizontalAlign else cfg.verticalAlign
	local align, justify = cfg.align, cfg.justify
	if pinned == nil and align == nil and justify == nil then
		return nil, nil
	end
	local reactive = isAxisAlignReactive(direction, align, justify, axis, pinned)
	if reactive == nil then
		return nil, nil
	elseif reactive then
		return function()
			local v, source = readAxisAlign(direction, align, justify, axis, pinned, label)
			return if toFlexAlignment(v) ~= nil then map.start else resolveEnum(map, v, source) or map.start
		end, function()
			local v, _ = readAxisAlign(direction, align, justify, axis, pinned, label)
			return toFlexAlignment(v) or FLEX_ALIGNMENT.none
		end
	end
	local v, source = readAxisAlign(direction, align, justify, axis, pinned, label)
	local flex = toFlexAlignment(v)
	if flex ~= nil then
		return map.start, flex
	end
	return resolveEnum(map, v, source), nil
end

local Layout = {}

--[[
Creates a [`UIPadding`](https://create.roblox.com/docs/reference/engine/classes/UIPadding) from a single length, a `{ top, bottom, left, right, x, y }` table, or a reactive source.
Plain `number` values are interpreted as offset pixels.

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
		setSidePair(props, "PaddingTop", sides.top, sides.y)
		setSidePair(props, "PaddingBottom", sides.bottom, sides.y)
		setSidePair(props, "PaddingLeft", sides.left, sides.x)
		setSidePair(props, "PaddingRight", sides.right, sides.x)
	else
		local side = udimProp(value)
		props.PaddingTop, props.PaddingBottom, props.PaddingLeft, props.PaddingRight = side, side, side, side
	end

	return construct("UIPadding", props)
end

--[[
Creates a [`UICorner`](https://create.roblox.com/docs/reference/engine/classes/UICorner) from an offset pixel radius, a [`UDim`](https://create.roblox.com/docs/reference/engine/datatypes/UDim), or a per-corner `{ topLeft, topRight, bottomLeft, bottomRight, top, bottom, left, right, radius }` table.

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
	return construct("UICorner", {
		CornerRadius = defaultProp(radius, DEFAULT_CORNER, toUDim),
	})
end

--[[
Creates a [`UIStroke`](https://create.roblox.com/docs/reference/engine/classes/UIStroke) with static or reactive `thickness`, `color`, `transparency`, `mode`, `joins`, `position`, and `offset`.

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
		BorderOffset = defaultProp(cfg.offset, ZERO_UDIM, toUDim),
	})
end

local function gridAlign(cfg: GridConfig, fill: any, axis: Direction, map: EnumMap): any
	local align, justify = cfg.align, cfg.justify
	if align == nil and justify == nil then
		return nil
	end
	local reactive = isAxisAlignReactive(fill, align, justify, axis)
	if reactive == nil then
		return nil
	elseif reactive then
		return function()
			local v, source = readAxisAlign(fill, align, justify, axis)
			return resolveEnum(map, v, source) or map.start
		end
	end
	local v, source = readAxisAlign(fill, align, justify, axis)
	if v == nil then
		return nil
	end
	return resolveEnum(map, v, source) or map.start
end

--[[
Creates a [`UIAspectRatioConstraint`](https://create.roblox.com/docs/reference/engine/classes/UIAspectRatioConstraint) with `ratio`, `aspectType` (`"fit"` or `"scale"`), and `dominantAxis` (`"width"` or `"height"`).

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
Creates a [`UIListLayout`](https://create.roblox.com/docs/reference/engine/classes/UIListLayout) with `SortOrder = LayoutOrder` and flexbox-style `gap`, `direction`, `align` (cross-axis), `justify` (main-axis), and `wraps` options.

[Open Documentation](https://flux.kohl.gg/guide/utilities/layout#list)
]]
function Layout.list(config: ListConfig?): UIListLayout
	local cfg: ListConfig = config or EMPTY
	local props: Props = {
		SortOrder = SORT_ORDER,
		Padding = defaultProp(cfg.gap, ZERO_UDIM, toUDim),
		Wraps = if isDynamic(cfg.wraps)
			then function()
				return read(cfg.wraps) == true
			end
			else cfg.wraps,
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
Creates a [`UIGridLayout`](https://create.roblox.com/docs/reference/engine/classes/UIGridLayout) with `SortOrder = LayoutOrder` and `cell`, `gap`, `fill`, `align`, `justify`, and `maxCells` options.
Routes `justify` along the `fill` axis and `align` across it (matching `Flux.list`), re-routing automatically when `fill` is reactive.

[Open Documentation](https://flux.kohl.gg/guide/utilities/layout#grid)
]]
function Layout.grid(config: GridConfig?): UIGridLayout
	local cfg: GridConfig = config or EMPTY
	local props: Props = {
		SortOrder = SORT_ORDER,
		CellSize = defaultProp(cfg.cell, DEFAULT_CELL_SIZE, toUDim2),
		CellPadding = defaultProp(cfg.gap, DEFAULT_CELL_PADDING, toUDim2),
		FillDirectionMaxCells = defaultProp(cfg.maxCells, 0),
	}

	local fill: any = cfg.fill
	if isDynamic(fill) then
		local source = fill
		fill = computed(function()
			return resolveEnum(FILL_DIRECTION, read(source), "fill") or FILL_DIRECTION.x
		end)
		props.__CLEAN = { fill }
		props.FillDirection = fill
	elseif fill ~= nil then
		fill = resolveEnum(FILL_DIRECTION, fill, "fill") or FILL_DIRECTION.x
		props.FillDirection = fill
	else
		fill = FILL_DIRECTION.x
	end

	props.HorizontalAlignment = gridAlign(cfg, fill, "x", HORIZONTAL_ALIGN)
	props.VerticalAlignment = gridAlign(cfg, fill, "y", VERTICAL_ALIGN)

	return construct("UIGridLayout", props)
end

--[[
Creates a [`UIFlexItem`](https://create.roblox.com/docs/reference/engine/classes/UIFlexItem) from `nil` (`"fill"`), a
numeric `GrowRatio` (`Custom` mode), a preset `"fill"`/`"grow"`/`"shrink"`/`"none"`/`"custom"` string, or a `{ mode?, grow?, shrink?, lineAlign? }` config table.

[Open Documentation](https://flux.kohl.gg/guide/utilities/layout#flex)
]]
function Layout.flex(config: Reactive<FlexConfig | number | FlexMode | Enum.UIFlexMode>?): UIFlexItem
	if config == nil then
		return construct("UIFlexItem", {
			FlexMode = FLEX_MODE.fill,
		})
	elseif type(config) == "number" then
		return construct("UIFlexItem", {
			FlexMode = FLEX_MODE.custom,
			GrowRatio = config,
		})
	elseif isDynamic(config) then
		local isFn = type(config) == "function"
		local source = if isFn then new(config) else config
		return construct("UIFlexItem", {
			__CLEAN = if isFn then { source } else nil,
			FlexMode = function()
				local value = read(source)
				if type(value) == "number" then
					return FLEX_MODE.custom
				elseif type(value) == "table" and typeof(value) ~= "EnumItem" then
					local mode = read(value.mode)
					if mode ~= nil then
						local resolved = resolveEnum(FLEX_MODE, mode, "flexMode")
						if resolved ~= nil then
							return resolved
						end
					end
					local grow, shrink = read(value.grow), read(value.shrink)
					return if grow ~= nil or shrink ~= nil then FLEX_MODE.custom else FLEX_MODE.fill
				elseif value == nil then
					return FLEX_MODE.fill
				end
				return resolveEnum(FLEX_MODE, value, "flexMode") or FLEX_MODE.none
			end,
			GrowRatio = function()
				local value = read(source)
				if type(value) == "number" then
					return value
				elseif type(value) == "table" and typeof(value) ~= "EnumItem" then
					return read(value.grow) or 0
				end
				return 0
			end,
			ShrinkRatio = function()
				local value = read(source)
				if type(value) == "table" and typeof(value) ~= "EnumItem" then
					return read(value.shrink) or 0
				end
				return 0
			end,
			ItemLineAlignment = function()
				local value = read(source)
				if type(value) == "table" and typeof(value) ~= "EnumItem" then
					return resolveEnum(ITEM_LINE_ALIGN, read(value.lineAlign), "lineAlign") or ITEM_LINE_ALIGN.automatic
				end
				return ITEM_LINE_ALIGN.automatic
			end,
		})
	elseif type(config) == "table" and typeof(config) ~= "EnumItem" then
		local cfg: FlexConfig = config :: any
		local defaultMode = if cfg.grow ~= nil or cfg.shrink ~= nil then FLEX_MODE.custom else FLEX_MODE.fill
		return construct("UIFlexItem", {
			FlexMode = if cfg.mode == nil then defaultMode else enumProp(FLEX_MODE, cfg.mode, "flexMode", defaultMode),
			GrowRatio = defaultProp(cfg.grow, 0),
			ShrinkRatio = defaultProp(cfg.shrink, 0),
			ItemLineAlignment = enumProp(ITEM_LINE_ALIGN, cfg.lineAlign, "lineAlign", ITEM_LINE_ALIGN.automatic),
		})
	end
	return construct("UIFlexItem", {
		FlexMode = resolveEnum(FLEX_MODE, config, "flexMode"),
	})
end

--[[
Creates a [`UIScale`](https://create.roblox.com/docs/reference/engine/classes/UIScale) with `Scale` (`1` by default).

[Open Documentation](https://flux.kohl.gg/guide/utilities/layout#scale)
]]
function Layout.scale(scale: Reactive<number>?): UIScale
	return construct("UIScale", {
		Scale = if scale == nil then 1 else scale,
	})
end

--[[
Creates a [`UIGradient`](https://create.roblox.com/docs/reference/engine/classes/UIGradient) from single values, evenly spaced stop arrays, or sequences for `color` and `transparency`.

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
Creates a [`UISizeConstraint`](https://create.roblox.com/docs/reference/engine/classes/UISizeConstraint) from `min`/`max` `Vector2` bounds or per-axis `minWidth`, `minHeight`, `maxWidth`, and `maxHeight` bounds.

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
Creates a [`UITextSizeConstraint`](https://create.roblox.com/docs/reference/engine/classes/UITextSizeConstraint) bounding text size between `min` and `max` pixels.

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
