--!strict
--[[
Spring and tween animations (`spring`, `tween`) stepped once per frame, plus perceptual `Color` utilities.

```luau
local width = Flux.spring(function() return if open() then 300 else 0 end)
```
]]

local Clock = require("./Clock")
local Compat = require("./Compat")
local Graph = require("./Graph")

local IS_ROBLOX = Compat.isRoblox
local Color3 = Compat.Color3
local ColorSequence = Compat.ColorSequence
local ColorSequenceKeypoint = Compat.ColorSequenceKeypoint
local Enum = Compat.Enum
local NumberSequence = Compat.NumberSequence
local NumberSequenceKeypoint = Compat.NumberSequenceKeypoint
local TweenInfo = Compat.TweenInfo
local UDim = Compat.UDim
local UDim2 = Compat.UDim2
local Vector2 = Compat.Vector2
local Vector3 = Compat.Vector3
local typeof = Compat.typeof
local warn = Compat.warn

local clock = Clock.now
local effect = Graph.effect
local isDynamic = Graph.isDynamic
local raw = Graph.raw
local read = Graph.read
local sampleSignal: any = Graph.signal(nil)
local SignalMT: any = getmetatable(sampleSignal)
local getSignal = SignalMT.get
local setNode = SignalMT.set

--- @ignore
type Reactive<T> = Graph.Reactive<T>
--- @ignore
type Unwrap<T> = Graph.Unwrap<T>

export type Spring<T> = Graph.Node<T> & {
	-- Adds `delta` to the spring's current velocity without changing its target.
	impulse: (self: any, delta: T) -> (),
	-- Replaces the spring's velocity outright without changing its target.
	setVelocity: (self: any, velocity: T) -> (),
	-- Sets the spring's current animated value immediately without altering its target or velocity.
	setCurrent: (self: any, value: T) -> (),
	-- Jumps both the target and current value to `value` and zeroes the velocity.
	snap: (self: any, value: T) -> (),
}

-- Color & Oklab -------------------------------------------------------------------------------------------------------

local function fromLinear(c: number): number
	return if c < 0.0031308 then c * 12.92 else c ^ (1 / 2.4) * 1.055 - 0.055
end

local function toLinear(c: number): number
	return if c < 0.04045 then c / 12.92 else ((c + 0.055) / 1.055) ^ 2.4
end

local sRGB = table.freeze({
	--- Converts linear sRGB space to sRGB space.
	fromLinear = function(color: Color3): Color3
		return Color3.new(fromLinear(color.R), fromLinear(color.G), fromLinear(color.B))
	end,
	--- Converts sRGB space to linear sRGB space.
	toLinear = function(color: Color3): Color3
		return Color3.new(toLinear(color.R), toLinear(color.G), toLinear(color.B))
	end,
})

local function oklabToLinearRGB(L: number, A: number, B: number): (number, number, number)
	local l_ = L + 0.3963377774 * A + 0.2158037573 * B
	local m_ = L - 0.1055613458 * A - 0.0638541728 * B
	local s_ = L - 0.0894841775 * A - 1.2914855480 * B
	local l, m, s = l_ * l_ * l_, m_ * m_ * m_, s_ * s_ * s_
	return 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
		-1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
		-0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s
end

local GAMUT_SLACK = 1e-5

local function cbrt(x: number): number
	return if x >= 0 then x ^ (1 / 3) else -((-x) ^ (1 / 3))
end

local function linearToOklab(R: number, G: number, B: number): (number, number, number)
	local l_ = cbrt(R * 0.4122214708 + G * 0.5363325363 + B * 0.0514459929)
	local m_ = cbrt(R * 0.2119034982 + G * 0.6806995451 + B * 0.1073969566)
	local s_ = cbrt(R * 0.0883024619 + G * 0.2817188376 + B * 0.6299787005)
	return l_ * 0.2104542553 + m_ * 0.7936177850 - s_ * 0.0040720468,
		l_ * 1.9779984951 - m_ * 2.4285922050 + s_ * 0.4505937099,
		l_ * 0.0259040371 + m_ * 0.7827717662 - s_ * 0.8086757660
end

local function rgbToOklab(rgb: Color3): (number, number, number)
	return linearToOklab(toLinear(rgb.R), toLinear(rgb.G), toLinear(rgb.B))
end

local function oklabComponentsToLinear(L: number, A: number, B: number, clamped: boolean?): (number, number, number)
	local r, g, b = oklabToLinearRGB(L, A, B)
	if clamped ~= false and (r < 0 or g < 0 or b < 0 or r > 1 or g > 1 or b > 1) then
		if
			r >= -GAMUT_SLACK
			and g >= -GAMUT_SLACK
			and b >= -GAMUT_SLACK
			and r <= 1 + GAMUT_SLACK
			and g <= 1 + GAMUT_SLACK
			and b <= 1 + GAMUT_SLACK
		then
			return math.clamp(r, 0, 1), math.clamp(g, 0, 1), math.clamp(b, 0, 1)
		end
		local L0 = math.clamp(L, 0, 1)
		local lo, hi = 0, 1
		for _ = 1, 12 do
			local mid = (lo + hi) / 2
			local mr, mg, mb = oklabToLinearRGB(L0, A * mid, B * mid)
			if mr >= 0 and mg >= 0 and mb >= 0 and mr <= 1 and mg <= 1 and mb <= 1 then
				lo = mid
			else
				hi = mid
			end
		end
		r, g, b = oklabToLinearRGB(L0, A * lo, B * lo)
	end
	return r, g, b
end

local function oklabToSRGB(L: number, A: number, B: number, clamped: boolean?): Color3
	local r, g, b = oklabComponentsToLinear(L, A, B, clamped)
	return Color3.new(fromLinear(r), fromLinear(g), fromLinear(b))
end

local function saturateAB(a: number, b: number, amount: number): (number, number)
	local c = math.sqrt(a * a + b * b)
	if c < 1e-6 then
		return a, b
	end
	local scale = math.max(c + amount, 0) / c
	return a * scale, b * scale
end

local function rotateAB(a: number, b: number, degrees: number): (number, number)
	local r = math.rad(degrees)
	local cos, sin = math.cos(r), math.sin(r)
	return a * cos - b * sin, a * sin + b * cos
end

local Oklab = table.freeze({
	--- Converts a Color3 in linear sRGB space to a Vector3 in Oklab space.
	fromLinear = function(color: Color3): Vector3
		return Vector3.new(linearToOklab(color.R, color.G, color.B))
	end,
	--- Converts a Vector3 in Oklab space to a Color3 in linear sRGB space.
	toLinear = function(color: Vector3, clamped: boolean?): Color3
		return Color3.new(oklabComponentsToLinear(color.X, color.Y, color.Z, clamped))
	end,
	--- Converts a Color3 in sRGB space to a Vector3 in Oklab space.
	fromRGB = function(rgb: Color3): Vector3
		return Vector3.new(rgbToOklab(rgb))
	end,
	--- Converts a Vector3 in Oklab space to a Color3 in sRGB space.
	toRGB = function(lab: Vector3, clamped: boolean?): Color3
		return oklabToSRGB(lab.X, lab.Y, lab.Z, clamped)
	end,
	--- Raises Oklab lightness by `amount` (negative darkens).
	lighten = function(lab: Vector3, amount: number): Vector3
		return Vector3.new(math.clamp(lab.X + amount, 0, 1), lab.Y, lab.Z)
	end,
	--- Raises Oklab chroma by `amount`, preserving hue and lightness (negative desaturates).
	saturate = function(lab: Vector3, amount: number): Vector3
		local a, b = saturateAB(lab.Y, lab.Z, amount)
		return if a == lab.Y and b == lab.Z then lab else Vector3.new(lab.X, a, b)
	end,
	--- Rotates hue by `degrees`, preserving chroma and lightness.
	rotateHue = function(lab: Vector3, degrees: number): Vector3
		local a, b = rotateAB(lab.Y, lab.Z, degrees)
		return Vector3.new(lab.X, a, b)
	end,
	--- Removes all chroma, preserving Oklab lightness.
	grayscale = function(lab: Vector3): Vector3
		return Vector3.new(lab.X, 0, 0)
	end,
	--- Linearly interpolates between `lab1` and `lab2` in Oklab space by `alpha`.
	mix = function(lab1: Vector3, lab2: Vector3, alpha: number): Vector3
		return lab1:Lerp(lab2, alpha)
	end,
})

local BLACK = Color3.new(0, 0, 0)
local WHITE = Color3.new(1, 1, 1)

local function luminance(c: Color3): number
	return 0.2126 * toLinear(c.R) + 0.7152 * toLinear(c.G) + 0.0722 * toLinear(c.B)
end

local function contrastLuminance(la: number, lb: number): number
	return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05)
end

local Color = table.freeze({
	Oklab = Oklab,
	sRGB = sRGB,
	--[[
	Raises the perceptual lightness of `c` in Oklab space by `amount` (negative darkens).

	[Open Documentation](https://flux.kohl.gg/guide/motion/color#manipulation)
	]]
	lighten = function(c: Color3, amount: number): Color3
		local L, a, b = rgbToOklab(c)
		return oklabToSRGB(math.clamp(L + amount, 0, 1), a, b)
	end,
	--[[
	Raises the chroma of `c` in Oklab space by `amount` while preserving hue and lightness (negative desaturates).

	[Open Documentation](https://flux.kohl.gg/guide/motion/color#manipulation)
	]]
	saturate = function(c: Color3, amount: number): Color3
		local L, a, b = rgbToOklab(c)
		a, b = saturateAB(a, b, amount)
		return oklabToSRGB(L, a, b)
	end,
	--[[
	Rotates the hue of `c` by `degrees` around the Oklab color wheel while preserving chroma and lightness.

	[Open Documentation](https://flux.kohl.gg/guide/motion/color#manipulation)
	]]
	rotateHue = function(c: Color3, degrees: number): Color3
		local L, a, b = rgbToOklab(c)
		a, b = rotateAB(a, b, degrees)
		return oklabToSRGB(L, a, b)
	end,
	--[[
	Strips all chroma from `c`, returning a neutral gray with the same Oklab perceptual lightness.

	[Open Documentation](https://flux.kohl.gg/guide/motion/color#manipulation)
	]]
	grayscale = function(c: Color3): Color3
		local L = rgbToOklab(c)
		return oklabToSRGB(L, 0, 0)
	end,
	--[[
	Blends `a` and `b` in Oklab space by unclamped fraction `t` (`0` = `a`, `1` = `b`).

	[Open Documentation](https://flux.kohl.gg/guide/motion/color#blending)
	]]
	mix = function(a: Color3, b: Color3, t: number): Color3
		local L1, a1, b1 = rgbToOklab(a)
		local L2, a2, b2 = rgbToOklab(b)
		return oklabToSRGB(L1 + (L2 - L1) * t, a1 + (a2 - a1) * t, b1 + (b2 - b1) * t)
	end,
	--[[
	Returns the WCAG relative luminance of `c` from `0` (black) to `1` (white).

	[Open Documentation](https://flux.kohl.gg/guide/motion/color#accessibility)
	]]
	luminance = luminance,
	--[[
	Returns the WCAG contrast ratio between `a` and `b` from `1` (identical) to `21` (black on white).

	[Open Documentation](https://flux.kohl.gg/guide/motion/color#accessibility)
	]]
	contrast = function(a: Color3, b: Color3): number
		return contrastLuminance(luminance(a), luminance(b))
	end,
	--[[
	Returns whichever of `dark` (default black) or `light` (default white) has the higher WCAG contrast ratio against `bg`.

	[Open Documentation](https://flux.kohl.gg/guide/motion/color#accessibility)
	]]
	readable = function(bg: Color3, dark: Color3?, light: Color3?): Color3
		local d = dark or BLACK
		local l = light or WHITE
		local lBg = luminance(bg)
		return if contrastLuminance(lBg, luminance(d)) >= contrastLuminance(lBg, luminance(l)) then d else l
	end,
})

-- DataType ------------------------------------------------------------------------------------------------------------

--- @ignore
export type Animatable =
	number
	| vector
	| CFrame
	| Color3
	| ColorSequence
	| ColorSequenceKeypoint
	| NumberRange
	| NumberSequence
	| NumberSequenceKeypoint
	| Rect
	| UDim
	| UDim2
	| Vector2
	| Vector3

local round = math.round
local math_max = math.max
local Color3_new = Color3.new
local ColorSequence_new = ColorSequence.new
local ColorSequenceKeypoint_new = ColorSequenceKeypoint.new
local NumberSequence_new = NumberSequence.new
local NumberSequenceKeypoint_new = NumberSequenceKeypoint.new
local UDim_new = UDim.new
local UDim2_new = UDim2.new
local Vector2_new = Vector2.new
local Vector3_new = Vector3.new

local function Oklab_toRGB(L: number, A: number, B: number, clamped: boolean): Color3
	local r, g, b = oklabComponentsToLinear(L, A, B, clamped)
	return Color3_new(math_max(fromLinear(r), 0), math_max(fromLinear(g), 0), math_max(fromLinear(b), 0))
end

local packers: { [string]: ({ number }, any) -> () } = {
	number = function(v, value: number)
		v[1] = value
	end,
	vector = function(v, value: vector)
		v[1], v[2], v[3] = value.x, value.y, value.z
	end,
	Color3 = function(t, v: Color3)
		t[1], t[2], t[3] = rgbToOklab(v)
	end,
	ColorSequence = function(t, v: ColorSequence)
		for i, k in v.Keypoints do
			local base = (i - 1) * 4
			t[base + 1], t[base + 2], t[base + 3], t[base + 4] = k.Time, rgbToOklab(k.Value)
		end
	end,
	ColorSequenceKeypoint = function(t, v: ColorSequenceKeypoint)
		t[1], t[2], t[3], t[4] = v.Time, rgbToOklab(v.Value)
	end,
	NumberSequence = function(t, v: NumberSequence)
		for i, k in v.Keypoints do
			local base = (i - 1) * 3
			t[base + 1], t[base + 2], t[base + 3] = k.Time, k.Value, k.Envelope
		end
	end,
	NumberSequenceKeypoint = function(t, v: NumberSequenceKeypoint)
		t[1], t[2], t[3] = v.Time, v.Value, v.Envelope
	end,
	UDim = function(t, v: UDim)
		t[1], t[2] = v.Scale, v.Offset
	end,
	UDim2 = function(t, v: UDim2)
		t[1], t[2], t[3], t[4] = v.X.Scale, v.X.Offset, v.Y.Scale, v.Y.Offset
	end,
	Vector2 = function(t, v: Vector2)
		t[1], t[2] = v.X, v.Y
	end,
	Vector3 = function(t, v: Vector3)
		t[1], t[2], t[3] = v.X, v.Y, v.Z
	end,
}

local unpackers: { [string]: ({ number }) -> any } = {
	number = function(v): number
		return v[1]
	end,
	vector = function(v): vector
		return vector.create(v[1], v[2], v[3])
	end,
	Color3 = function(t): Color3
		return Oklab_toRGB(t[1], t[2], t[3], false)
	end,
	ColorSequence = function(t): ColorSequence
		local n = #t // 4
		local k = table.create(n) :: { ColorSequenceKeypoint }
		local prevTime = 0
		for idx = 1, n do
			local base = (idx - 1) * 4
			local time = if idx == 1 then 0 elseif idx == n then 1 else math.clamp(t[base + 1], prevTime, 1)
			prevTime = time
			k[idx] = ColorSequenceKeypoint_new(time, Oklab_toRGB(t[base + 2], t[base + 3], t[base + 4], true))
		end
		return ColorSequence_new(k)
	end,
	ColorSequenceKeypoint = function(t): ColorSequenceKeypoint
		return ColorSequenceKeypoint_new(math.clamp(t[1], 0, 1), Oklab_toRGB(t[2], t[3], t[4], false))
	end,
	NumberSequence = function(t): NumberSequence
		local n = #t // 3
		local k = table.create(n) :: { NumberSequenceKeypoint }
		local prevTime = 0
		for idx = 1, n do
			local base = (idx - 1) * 3
			local time = if idx == 1 then 0 elseif idx == n then 1 else math.clamp(t[base + 1], prevTime, 1)
			prevTime = time
			k[idx] = NumberSequenceKeypoint_new(time, t[base + 2], math_max(t[base + 3], 0))
		end
		return NumberSequence_new(k)
	end,
	NumberSequenceKeypoint = function(t): NumberSequenceKeypoint
		return NumberSequenceKeypoint_new(math.clamp(t[1], 0, 1), t[2], math_max(t[3], 0))
	end,
	UDim = function(t): UDim
		return UDim_new(t[1], round(t[2]))
	end,
	UDim2 = function(t): UDim2
		return UDim2_new(t[1], round(t[2]), t[3], round(t[4]))
	end,
	Vector2 = function(t): Vector2
		return Vector2_new(t[1], t[2])
	end,
	Vector3 = function(t): Vector3
		return Vector3_new(t[1], t[2], t[3])
	end,
}

if IS_ROBLOX then
	local CFrame_new = CFrame.new
	local CFrame_fromAxisAngle = CFrame.fromAxisAngle
	local NumberRange_new = NumberRange.new
	local Rect_new = Rect.new

	packers.CFrame = function(t, v: CFrame)
		local p, a = v:ToAxisAngle()
		t[1], t[2], t[3], t[4], t[5], t[6] = v.X, v.Y, v.Z, p.X * a, p.Y * a, p.Z * a
	end
	packers.NumberRange = function(t, v: NumberRange)
		t[1], t[2] = v.Min, v.Max
	end
	packers.Rect = function(t, v: Rect)
		t[1], t[2], t[3], t[4] = v.Min.X, v.Min.Y, v.Max.X, v.Max.Y
	end

	unpackers.CFrame = function(t): CFrame
		local p = CFrame_new(t[1], t[2], t[3])
		local rx, ry, rz = t[4], t[5], t[6]
		local a = math.sqrt(rx * rx + ry * ry + rz * rz)
		return if a < 1e-6 then p else p * CFrame_fromAxisAngle(Vector3_new(rx / a, ry / a, rz / a), a)
	end
	unpackers.NumberRange = function(t): NumberRange
		local min, max = t[1], t[2]
		return NumberRange_new(min, math_max(min, max))
	end
	unpackers.Rect = function(t): Rect
		local minX, minY, maxX, maxY = t[1], t[2], t[3], t[4]
		return Rect_new(minX, minY, maxX, maxY)
	end
end

local function pack(arr: { number }, value: Animatable, t: string)
	table.clear(arr)
	local packer = packers[t]
	if packer then
		packer(arr, value)
	end
	return arr
end

-- Easing --------------------------------------------------------------------------------------------------------------

--- @ignore
export type Curve = (alpha: number) -> number

local sin, cos, sqrt, pi = math.sin, math.cos, math.sqrt, math.pi
local BACK = 1.70158

local function bounceOut(t: number): number
	if t < 1 / 2.75 then
		return 7.5625 * t * t
	elseif t < 2 / 2.75 then
		t -= 1.5 / 2.75
		return 7.5625 * t * t + 0.75
	elseif t < 2.5 / 2.75 then
		t -= 2.25 / 2.75
		return 7.5625 * t * t + 0.9375
	else
		t -= 2.625 / 2.75
		return 7.5625 * t * t + 0.984375
	end
end

local curves: { [string]: { In: Curve, Out: Curve, InOut: Curve? } } = {
	Linear = {
		In = function(t)
			return t
		end,
		Out = function(t)
			return t
		end,
	},
	Sine = {
		In = function(t)
			return 1 - cos(t * pi / 2)
		end,
		Out = function(t)
			return sin(t * pi / 2)
		end,
		InOut = function(t)
			return (1 - cos(t * pi)) / 2
		end,
	},
	Quad = {
		In = function(t)
			return t * t
		end,
		Out = function(t)
			t = 1 - t
			return 1 - t * t
		end,
	},
	Cubic = {
		In = function(t)
			return t * t * t
		end,
		Out = function(t)
			t = 1 - t
			return 1 - t * t * t
		end,
	},
	Quart = {
		In = function(t)
			t *= t
			return t * t
		end,
		Out = function(t)
			t = 1 - t
			t *= t
			return 1 - t * t
		end,
	},
	Quint = {
		In = function(t)
			local t2 = t * t
			return t2 * t2 * t
		end,
		Out = function(t)
			t = 1 - t
			local t2 = t * t
			return 1 - t2 * t2 * t
		end,
	},
	Exponential = {
		In = function(t)
			return if t == 0 then 0 else 2 ^ (10 * t - 10)
		end,
		Out = function(t)
			return if t == 1 then 1 else 1 - 2 ^ (-10 * t)
		end,
	},
	Circular = {
		In = function(t)
			return 1 - sqrt(1 - t * t)
		end,
		Out = function(t)
			t = 1 - t
			return sqrt(1 - t * t)
		end,
	},
	Back = {
		In = function(t)
			return t * t * ((BACK + 1) * t - BACK)
		end,
		Out = function(t)
			t -= 1
			return 1 + t * t * ((BACK + 1) * t + BACK)
		end,
	},
	Elastic = {
		In = function(t)
			if t == 0 or t == 1 then
				return t
			end
			t = 1 - t
			return 2 ^ (-10 * t) * cos(6.5 * pi * t)
		end,
		Out = function(t)
			if t == 0 or t == 1 then
				return t
			end
			return 1 - 2 ^ (-10 * t) * cos(6.5 * pi * t)
		end,
	},
	Bounce = {
		In = function(t)
			return 1 - bounceOut(1 - t)
		end,
		Out = bounceOut,
	},
}

local function inOut(easeIn: Curve, easeOut: Curve): Curve
	return function(t)
		return if t < 0.5 then easeIn(2 * t) / 2 else (1 + easeOut(2 * t - 1)) / 2
	end
end

local styles: { [any]: { [any]: Curve } } = {}
local easingDirection: any = if Enum then Enum.EasingDirection else nil
local easingStyle: any = if Enum then Enum.EasingStyle else nil
local DIRECTIONS = { "In", "Out", "InOut" }
for name, set in curves do
	local byDirection: { [any]: Curve } = {
		In = set.In,
		Out = set.Out,
		InOut = set.InOut or inOut(set.In, set.Out),
	}
	if easingDirection then
		for _, direction in DIRECTIONS do
			byDirection[easingDirection[direction]] = byDirection[direction]
		end
		styles[easingStyle[name]] = byDirection
	end
	styles[name] = byDirection
end

local function itemKey(item: any): any
	return if type(item) == "string" then item else item.Name
end

local Easing = {}

function Easing.curve(style: any, direction: any): Curve
	local byDirection = styles[style] or styles[itemKey(style)]
	if byDirection == nil then
		error(`Unknown EasingStyle {tostring(style)}`, 2)
	end
	local curve = byDirection[direction] or byDirection[itemKey(direction)]
	if curve == nil then
		error(`Unknown EasingDirection {tostring(direction)}`, 2)
	end
	return curve
end

function Easing.get(alpha: number, style: any, direction: any): number
	return Easing.curve(style, direction)(math.clamp(alpha, 0, 1))
end

table.freeze(Easing)

-- Engine --------------------------------------------------------------------------------------------------------------

local lastClock = clock()

local TYPE_TWEEN = 1
local TYPE_SPRING = 2
local EPSILON = 1e-4

--- @ignore
export type Motion = {
	type: number,
	count: number,
	node: Graph.Node<any>,
	typeString: string,
	unpack: ({ number }) -> any,
	target: { number },
	value: { number },
}

--- @ignore
export type EngineSpring = Motion & {
	vel: { number },
	frequency: number,
	damping: number,
}

--- @ignore
export type Tween = Motion & {
	info: TweenInfo,
	ease: Curve,
	startTime: number,
	repeatsLeft: number,
	reversing: boolean,
	start: { number },
}

local activeSprings: { [Motion]: any } = {}
local activeTweens: { [Motion]: any } = {}

local Engine = {
	now = 0,
	DEFAULT_TWEEN_INFO = TweenInfo.new(0.3, Enum.EasingStyle.Cubic, Enum.EasingDirection.InOut),
	isActive = function(motion: EngineSpring | Tween): boolean
		return activeSprings[motion] ~= nil or activeTweens[motion] ~= nil
	end,
}

function Engine.newSpring(
	count: number,
	typeString: string,
	node: any,
	frequency: number?,
	damping: number?
): EngineSpring
	return {
		type = TYPE_SPRING,
		count = count,
		node = node,
		typeString = typeString,
		unpack = unpackers[typeString],
		target = table.create(count, 0),
		value = table.create(count, 0),
		vel = table.create(count, 0),
		frequency = math.max(frequency or 1, EPSILON),
		damping = math.max(damping or 1, EPSILON),
	}
end

function Engine.newTween(count: number, typeString: string, node: any, tweenInfo: TweenInfo?): Tween
	local info = tweenInfo or Engine.DEFAULT_TWEEN_INFO
	return {
		type = TYPE_TWEEN,
		count = count,
		node = node,
		typeString = typeString,
		unpack = unpackers[typeString],
		start = table.create(count, 0),
		target = table.create(count, 0),
		value = table.create(count, 0),
		info = info,
		ease = Easing.curve(info.EasingStyle, info.EasingDirection),
		startTime = Engine.now + info.DelayTime,
		repeatsLeft = info.RepeatCount,
		reversing = false,
	}
end

function Engine.destroy(motion: EngineSpring | Tween)
	activeSprings[motion] = nil
	activeTweens[motion] = nil
	table.clear(motion)
end

function Engine.setupSpring(spring: EngineSpring, frequency: number?, damping: number?)
	spring.frequency = math.max(frequency or 1, EPSILON)
	spring.damping = math.max(damping or 1, EPSILON)
	activeSprings[spring] = spring.node
end

function Engine.setupTween(tween: Tween, tweenInfo: TweenInfo?)
	local info = tweenInfo or Engine.DEFAULT_TWEEN_INFO
	tween.info = info
	tween.ease = Easing.curve(info.EasingStyle, info.EasingDirection)
	tween.startTime = Engine.now + info.DelayTime
	tween.repeatsLeft = info.RepeatCount
	tween.reversing = false
	local start, value = tween.start, tween.value
	table.move(value, 1, #value, 1, start)
	activeTweens[tween] = tween.node
end

function Engine.snap(motion: EngineSpring | Tween, arr: { number })
	local n = #arr
	local target, value = motion.target, motion.value
	table.clear(target)
	table.clear(value)
	table.move(arr, 1, n, 1, target)
	table.move(arr, 1, n, 1, value)
	if motion.type == TYPE_TWEEN then
		local start = (motion :: Tween).start
		table.clear(start)
		table.move(arr, 1, n, 1, start)
	else
		local vel = (motion :: EngineSpring).vel
		table.clear(vel)
		for i = 1, n do
			vel[i] = 0
		end
	end
	motion.count = n
	activeSprings[motion] = nil
	activeTweens[motion] = nil
end

function Engine.setTarget(motion: EngineSpring | Tween, arr: { number })
	local activeMap = if motion.type == TYPE_TWEEN then activeTweens else activeSprings
	local n = #arr
	if n ~= motion.count then
		Engine.snap(motion, arr)
		activeMap[motion] = motion.node
		return
	end

	local target = motion.target
	local changed = false
	for i, v in arr do
		if target[i] ~= v then
			changed = true
			target[i] = v
		end
	end
	if not changed then
		return
	end

	if motion.type == TYPE_TWEEN then
		motion = motion :: Tween
		table.move(motion.value, 1, n, 1, motion.start)
		motion.startTime = Engine.now
		motion.repeatsLeft = motion.info.RepeatCount
		motion.reversing = false
	end
	activeMap[motion] = motion.node
end

function Engine.addVelocity(spring: EngineSpring, arr: { number })
	local vel = spring.vel
	for i = 1, math.min(#arr, spring.count) do
		vel[i] += arr[i]
	end
	activeSprings[spring] = spring.node
end

function Engine.setVelocity(spring: EngineSpring, arr: { number })
	local vel = spring.vel
	for i = 1, math.min(#arr, spring.count) do
		vel[i] = arr[i]
	end
	activeSprings[spring] = spring.node
end

local function stepSpring(motion: EngineSpring, dt: number)
	local f, d = motion.frequency, motion.damping
	local w = math.tau * f
	local isSleeping = true
	local target, value, m_vel = motion.target, motion.value, motion.vel

	if d == 1 then
		local expTerm = math.exp(-w * dt)
		for c, pos in value do
			local tar, vel = target[c], m_vel[c]
			local c1 = pos - tar
			if math.abs(c1) > EPSILON or math.abs(vel) > EPSILON then
				isSleeping = false
				local c2 = vel + w * c1
				local positionTerm = c1 + c2 * dt
				value[c] = tar + positionTerm * expTerm
				m_vel[c] = (c2 - w * positionTerm) * expTerm
			end
		end
	elseif d < 1 then
		local wd = w * math.sqrt(1 - d * d)
		local dampingRate = w * d
		local expTerm = math.exp(-dampingRate * dt)
		local phase = wd * dt
		local cosTerm, sinTerm = math.cos(phase), math.sin(phase)
		for c, pos in value do
			local tar, vel = target[c], m_vel[c]
			local c1 = pos - tar
			if math.abs(c1) > EPSILON or math.abs(vel) > EPSILON then
				isSleeping = false
				local c2 = (vel + dampingRate * c1) / wd
				value[c] = tar + expTerm * (c1 * cosTerm + c2 * sinTerm)
				m_vel[c] = expTerm * (vel * cosTerm - (c1 * wd + c2 * dampingRate) * sinTerm)
			end
		end
	else
		local wd = w * math.sqrt(d * d - 1)
		local negDampingRate = -w * d
		local r1, r2 = negDampingRate + wd, negDampingRate - wd
		local rDiff = r2 - r1
		local exp1, exp2 = math.exp(r1 * dt), math.exp(r2 * dt)
		for c, pos in value do
			local tar, vel = target[c], m_vel[c]
			local displacement = pos - tar
			if math.abs(displacement) > EPSILON or math.abs(vel) > EPSILON then
				isSleeping = false
				local c2 = (vel - r1 * displacement) / rDiff
				local c1 = displacement - c2
				value[c] = tar + c1 * exp1 + c2 * exp2
				m_vel[c] = c1 * r1 * exp1 + c2 * r2 * exp2
			end
		end
	end

	if isSleeping then
		for c, tar in target do
			value[c] = tar
			m_vel[c] = 0
		end
		activeSprings[motion] = nil
	end
end

local function stepTween(tween: Tween, now: number)
	local elapsed = now - tween.startTime
	if elapsed < 0 then
		return
	end
	local tInfo = tween.info
	local duration = tInfo.Time
	local alpha = if duration > 0 then elapsed / duration else 1

	while alpha >= 1 do
		if tInfo.Reverses and not tween.reversing then
			tween.reversing = true
		elseif tween.repeatsLeft ~= 0 then
			if tween.repeatsLeft > 0 then
				tween.repeatsLeft -= 1
			end
			tween.reversing = false
		else
			activeTweens[tween] = nil
			local value = tween.value
			for i, v in (if tween.reversing then tween.start else tween.target) do
				value[i] = v
			end
			return
		end
		tween.startTime += duration
		if duration <= 0 then
			alpha = 1
			break
		end
		alpha = (now - tween.startTime) / duration
	end

	alpha = tween.ease(math.clamp(alpha, 0, 1))
	if tween.reversing then
		alpha = 1 - alpha
	end
	local value, target = tween.value, tween.target
	for i, start in tween.start do
		value[i] = start + (target[i] - start) * alpha
	end
end

local stepping: { any } = {}

local function stepActive(activeMap: { [Motion]: any }, stepFn: (any, number) -> (), arg: number)
	if next(activeMap) == nil then
		return
	end
	local n = 0
	for motion in activeMap do
		n += 1
		stepping[n] = motion
	end
	for i = 1, n do
		local motion = stepping[i]
		stepping[i] = nil
		local node = activeMap[motion]
		if node ~= nil then
			stepFn(motion, arg)
			setNode(node, motion.unpack(motion.value))
		end
	end
end

function Engine.step(dt: number?)
	local time = clock()
	local elapsed = math_max(0, dt or (time - lastClock))
	local now = Engine.now + elapsed
	lastClock = time
	Engine.now = now

	stepActive(activeSprings, stepSpring, elapsed)
	stepActive(activeTweens, stepTween, now)
end

-- Motion Nodes (spring & tween) ---------------------------------------------------------------------------------------

local tempArray = { 0, 0, 0, 0, 0, 0, 0 }
local NodeToMotion: { [Graph.Node<any>]: EngineSpring | Tween } = setmetatable({}, { __mode = "k" })

local function packSpring(self: Graph.Node<any>, method: string, value: any): EngineSpring?
	local spring = NodeToMotion[self]
	if spring == nil or spring.type ~= TYPE_SPRING then
		warn(`[Flux] :{method}() is only valid on a spring; ignoring`)
		return nil
	end
	local val = raw(value)
	local typeString = typeof(val)
	if typeString ~= spring.typeString then
		local msg = if method == "impulse"
			then `Cannot impulse a {spring.typeString} spring with a {typeString} value`
			elseif
				method == "setVelocity"
			then `Cannot set velocity of a {spring.typeString} spring to a {typeString} value`
			elseif
				method == "setCurrent"
			then `Cannot set a {spring.typeString} spring's current value to a {typeString} value`
			else `Cannot snap a {spring.typeString} spring to a {typeString} value`
		error(msg, 3)
	end
	pack(tempArray, val, typeString)
	return spring :: EngineSpring
end

--- @class Spring
local MotionStateMetatable: { [string]: any } = {
	__call = function<T>(self: any, value: any?): any?
		if value ~= nil then
			self:set(value)
			return
		end
		return getSignal(self)
	end,
}
for key, method in SignalMT do
	if MotionStateMetatable[key] == nil then
		MotionStateMetatable[key] = method
	end
end
MotionStateMetatable.__index = MotionStateMetatable

--[[
Retargets the animation toward `value` from its current position (`motion(value)` does the same). If `value` is a node,
it's read once.

[Open Documentation](https://flux.kohl.gg/guide/motion/spring#reactive-targets)
]]
function MotionStateMetatable.set<T>(self: Graph.Node<T>, value: T)
	local motion = NodeToMotion[self]
	if motion == nil then
		warn("[Flux] :set() called on a destroyed motion node; ignoring")
		return
	end
	local goal = raw(value)
	local typeString = typeof(goal)
	if typeString ~= motion.typeString then
		error(`Cannot retarget a {motion.typeString} motion with a {typeString} value`, 2)
	end
	Engine.setTarget(motion, pack(tempArray, goal, typeString))
end

--[[
*(Spring only)* Adds `delta` to the spring's current velocity without changing its goal.

[Open Documentation](https://flux.kohl.gg/guide/motion/spring#velocity-control-impulse-set-velocity)
]]
function MotionStateMetatable.impulse<T>(self: Graph.Node<T>, delta: T)
	local spring = packSpring(self, "impulse", delta)
	if spring ~= nil then
		Engine.addVelocity(spring, tempArray)
	end
end

--[[
*(Spring only)* Replaces the spring's current velocity with `velocity` without changing its goal.

[Open Documentation](https://flux.kohl.gg/guide/motion/spring#velocity-control-impulse-set-velocity)
]]
function MotionStateMetatable.setVelocity<T>(self: Graph.Node<T>, velocity: T)
	local spring = packSpring(self, "setVelocity", velocity)
	if spring ~= nil then
		Engine.setVelocity(spring, tempArray)
	end
end

--[[
*(Spring only)* Sets the spring's current animated value immediately without changing its target or velocity.

[Open Documentation](https://flux.kohl.gg/guide/motion/spring)
]]
function MotionStateMetatable.setCurrent<T>(self: Graph.Node<T>, value: T)
	local spring = packSpring(self, "setCurrent", value)
	if spring == nil then
		return
	end
	local val = spring.value
	table.move(tempArray, 1, math.min(#tempArray, spring.count), 1, val)
	setNode(spring.node, spring.unpack(val))
	activeSprings[spring] = spring.node
end

--[[
*(Spring only)* Jumps both the target and current value of the spring to `value` and zeroes its velocity.

[Open Documentation](https://flux.kohl.gg/guide/motion/spring#snap)
]]
function MotionStateMetatable.snap<T>(self: Graph.Node<T>, value: T)
	local spring = packSpring(self, "snap", value)
	if spring ~= nil then
		Engine.snap(spring, tempArray)
		setNode(spring.node, spring.unpack(spring.value))
	end
end

local function attachEffect(stateNode: Graph.Node<any>, fn: () -> ())
	local effectNode = effect(fn)
	stateNode:onDestroy(function()
		effectNode:Destroy()
	end)
end

local function register(stateNode: Graph.Node<any>, motion: EngineSpring | Tween)
	NodeToMotion[stateNode] = motion
	local function unregister()
		NodeToMotion[stateNode] = nil
		Engine.destroy(motion)
	end
	stateNode:onDestroy(unregister)
	if Graph.getOwner() then
		Graph.cleanup(unregister)
	end
end

local function packOrFallback(target: any, initialVal: any, typeStr: string): any
	pack(tempArray, initialVal, typeStr)
	if #tempArray ~= 0 then
		return nil
	end
	if typeStr == "nil" then
		warn("[Flux] Animating a nil value; following the goal without animation")
		local stateNode: any = Graph.signal(initialVal)
		stateNode.snap = setNode
		stateNode.setCurrent = setNode
		stateNode.impulse = MotionStateMetatable.impulse
		stateNode.setVelocity = MotionStateMetatable.setVelocity
		if isDynamic(target) then
			attachEffect(stateNode, function()
				stateNode:set(read(target))
			end)
		end
		return stateNode
	end
	error(`Cannot animate a {typeStr} value`, 3)
end

local MotionModule = {
	Color = Color,
	--- @ignore
	Easing = Easing,
	--- @ignore
	Engine = Engine,
	--- @ignore
	NodeToMotion = NodeToMotion,
	--[[
	Advances every active [spring](https://flux.kohl.gg/guide/motion/spring) and
	[tween](https://flux.kohl.gg/guide/motion/tween) by `dt` seconds (or the time since the last step). Wired to
	`RunService` automatically in Roblox, so you only call this in tests (`Flux.Motion.step(1 / 60)`).

	[Open Documentation](https://flux.kohl.gg/guide/tips/testing#full-engine-tests-in-ci)
	]]
	step = Engine.step,
}

--[[
Creates a [node](https://flux.kohl.gg/guide/concepts/signals) that animates toward `target` using an analytic harmonic
oscillator (`frequency` in Hz and `damping` ratio both default to `1` and may be reactive). Retargets preserve current
velocity.

```luau
local size = Flux.spring(function() return if open() then 300 else 0 end, 4)
```

[Open Documentation](https://flux.kohl.gg/guide/motion/spring#basic-usage)
]]
function MotionModule.spring<A>(
	target: A,
	frequency: Reactive<number>?,
	damping: Reactive<number>?,
	initialVelocity: any?
): Spring<Unwrap<A>>
	local initialVal = raw(target)
	local typeStr = typeof(initialVal)
	local fallback = packOrFallback(target, initialVal, typeStr)
	if fallback ~= nil then
		return fallback
	end

	local stateNode = Graph.signal(initialVal)
	local spring = Engine.newSpring(#tempArray, typeStr, stateNode, raw(frequency), raw(damping))
	register(stateNode, spring)
	Engine.snap(spring, tempArray)
	if initialVelocity ~= nil then
		local initVel: any = raw(initialVelocity)
		if typeof(initVel) == typeStr then
			Engine.setVelocity(spring, pack(tempArray, initVel, typeStr))
		end
	end

	local dynamicTarget = isDynamic(target)
	local reactiveSetup = isDynamic(frequency) or isDynamic(damping)
	if dynamicTarget or reactiveSetup then
		attachEffect(stateNode, function()
			if reactiveSetup then
				local wasActive = activeSprings[spring] ~= nil
				Engine.setupSpring(spring, read(frequency), read(damping))
				if not wasActive then
					activeSprings[spring] = nil
				end
			end
			if dynamicTarget then
				local goal = read(target)
				if typeof(goal) == typeStr then
					Engine.setTarget(spring, pack(tempArray, goal, typeStr))
				end
			end
		end)
	end

	local motionNode: any = setmetatable(stateNode, MotionStateMetatable)
	return motionNode
end

--[[
Creates a [node](https://flux.kohl.gg/guide/concepts/signals) that eases toward `target` over a
[`TweenInfo`](https://create.roblox.com/docs/reference/engine/datatypes/TweenInfo) curve. When `target` or `tweenInfo`
changes, the tween restarts from its current value without waiting for `DelayTime`.

[Open Documentation](https://flux.kohl.gg/guide/motion/tween#basic-usage)
]]
function MotionModule.tween<A>(target: A, tweenInfo: Reactive<TweenInfo>?): Graph.Node<Unwrap<A>>
	local initialVal = raw(target)
	local typeStr = typeof(initialVal)
	local fallback = packOrFallback(target, initialVal, typeStr)
	if fallback ~= nil then
		return fallback
	end

	local stateNode = Graph.signal(initialVal)
	local tween = Engine.newTween(#tempArray, typeStr, stateNode, raw(tweenInfo))
	register(stateNode, tween)
	Engine.snap(tween, tempArray)

	local dynamicTarget = isDynamic(target)
	local dynamicInfo = isDynamic(tweenInfo)
	if dynamicTarget or dynamicInfo then
		attachEffect(stateNode, function()
			if dynamicInfo then
				local i = read(tweenInfo) or Engine.DEFAULT_TWEEN_INFO
				if tween.info ~= i then
					local wasActive = activeTweens[tween] ~= nil
					Engine.setupTween(tween, i)
					if wasActive then
						tween.startTime = Engine.now
					else
						activeTweens[tween] = nil
					end
				end
			end
			if dynamicTarget then
				local goal = read(target)
				if typeof(goal) == typeStr then
					Engine.setTarget(tween, pack(tempArray, goal, typeStr))
				end
			end
		end)
	end

	local motionNode: any = setmetatable(stateNode, MotionStateMetatable)
	return motionNode
end

return table.freeze(MotionModule)
