--!strict
local Clock = require("./Clock")

local IS_ROBLOX = game ~= nil

type Task = {
	spawn: (fnOrThread: any, ...any) -> thread,
	defer: (fnOrThread: any, ...any) -> thread,
	delay: (seconds: number?, fnOrThread: any, ...any) -> thread,
	wait: (seconds: number?) -> number,
	cancel: (thread: thread) -> (),
}

type Compat = {
	isRoblox: boolean,
	traceback: (err: any, level: number?) -> any,
	warn: (...any) -> (),
	setWarnHook: (hook: ((message: string) -> ())?) -> (),
	task: Task,
	clock: () -> number,
	typeof: (value: any) -> string,
	getService: (name: string) -> any,
	services: { [string]: any },
	Instance: any,
	Color3: typeof(Color3),
	UDim: typeof(UDim),
	UDim2: typeof(UDim2),
	Vector2: typeof(Vector2),
	Vector3: typeof(Vector3),
	Font: typeof(Font),
	TweenInfo: typeof(TweenInfo),
	Enum: typeof(Enum),
	ColorSequence: typeof(ColorSequence),
	ColorSequenceKeypoint: typeof(ColorSequenceKeypoint),
	NumberSequence: typeof(NumberSequence),
	NumberSequenceKeypoint: typeof(NumberSequenceKeypoint),
}

local builtinTypeof = typeof
local rawWarn: (...any) -> () = if IS_ROBLOX then warn else print
local warnHook: ((message: string) -> ())? = nil

local function warn(...: any)
	local hook = warnHook
	if hook then
		local parts: any = table.pack(...)
		for i = 1, parts.n do
			parts[i] = tostring(parts[i])
		end
		hook(table.concat(parts, " ", 1, parts.n))
		return
	end
	rawWarn(...)
end

local function setWarnHook(hook: ((message: string) -> ())?)
	warnHook = hook
end

local function traceback(err: any, level: number?): any
	return if type(err) == "string" then debug.traceback(err, level) else err
end

Clock._internal.setReport(warn)

local compatTask: any = table.freeze({
	spawn = if IS_ROBLOX then task.spawn else Clock._internal.spawn,
	defer = Clock.defer,
	delay = Clock.delay,
	wait = Clock.wait,
	cancel = Clock.cancel,
})

if IS_ROBLOX then
	local gameGetService: any = game.GetService
	local robloxServices: { [string]: any } = {}
	local robloxCompat: any = table.freeze({
		isRoblox = true,
		traceback = traceback,
		warn = warn,
		setWarnHook = setWarnHook,
		task = compatTask,
		clock = Clock.now,
		typeof = typeof,
		getService = function(name: string): any
			local service = robloxServices[name]
			if service == nil then
				service = gameGetService(game, name)
				robloxServices[name] = service
			end
			return service
		end,
		services = robloxServices,
		Instance = Instance,
		Color3 = Color3,
		UDim = UDim,
		UDim2 = UDim2,
		Vector2 = Vector2,
		Vector3 = Vector3,
		Font = Font,
		TweenInfo = TweenInfo,
		Enum = Enum,
		ColorSequence = ColorSequence,
		ColorSequenceKeypoint = ColorSequenceKeypoint,
		NumberSequence = NumberSequence,
		NumberSequenceKeypoint = NumberSequenceKeypoint,
	})
	return robloxCompat :: Compat
end

local function compatTypeof(value: any): string
	local mt = getmetatable(value)
	return if type(mt) == "table" and type(mt.__type) == "string" then mt.__type else builtinTypeof(value)
end

local function fieldsEqual(a: any, b: any): boolean
	if getmetatable(a) ~= getmetatable(b) then
		return false
	end
	for key, value in a do
		if b[key] ~= value then
			return false
		end
	end
	return true
end

local function datatype(
	name: string,
	repr: (self: any) -> string,
	methods: { [string]: any }?,
	metamethods: { [string]: any }?
): (any, (fields: { [string]: any }) -> any)
	local mt: { [string]: any } = {
		__type = name,
		__index = methods,
		__eq = fieldsEqual,
		__tostring = function(self: any): string
			return `{name}({repr(self)})`
		end,
	}
	if metamethods ~= nil then
		for key, fn in metamethods do
			mt[key] = fn
		end
	end
	return mt, function(fields: { [string]: any }): any
		return table.freeze(setmetatable(fields, mt))
	end
end

local newColor3: (fields: { [string]: any }) -> any
local _, buildColor3 = datatype("Color3", function(s: any)
	return `{s.R}, {s.G}, {s.B}`
end, {
	Lerp = function(self: any, other: any, alpha: number): any
		return newColor3({
			R = self.R + (other.R - self.R) * alpha,
			G = self.G + (other.G - self.G) * alpha,
			B = self.B + (other.B - self.B) * alpha,
		})
	end,
	ToHex = function(self: any): string
		return string.format(
			"%02x%02x%02x",
			math.round(self.R * 255),
			math.round(self.G * 255),
			math.round(self.B * 255)
		)
	end,
})
newColor3 = buildColor3

local Color3Stub = {
	new = function(r: number?, g: number?, b: number?): any
		return newColor3({ R = r or 0, G = g or 0, B = b or 0 })
	end,
	fromRGB = function(r: number?, g: number?, b: number?): any
		return newColor3({ R = (r or 0) / 255, G = (g or 0) / 255, B = (b or 0) / 255 })
	end,
	fromHex = function(hex: string): any
		local digits = string.match(hex, "^#?(%x+)$")
		if digits == nil or (#digits ~= 3 and #digits ~= 6) then
			error(`invalid hex color "{hex}"`, 2)
		end
		if #digits == 3 then
			digits = string.gsub(digits, "(%x)", "%1%1")
		end
		local v = tonumber(digits, 16) :: number
		return newColor3({
			R = bit32.rshift(v, 16) / 255,
			G = bit32.band(bit32.rshift(v, 8), 0xff) / 255,
			B = bit32.band(v, 0xff) / 255,
		})
	end,
}

local function int32(v: number): number
	return if v >= 0 then math.floor(v) else math.ceil(v)
end

local udim: (scale: number?, offset: number?) -> any
local _, newUDim = datatype(
	"UDim",
	function(s: any)
		return `{s.Scale}, {s.Offset}`
	end,
	nil,
	{
		__add = function(a: any, b: any): any
			return udim(a.Scale + b.Scale, a.Offset + b.Offset)
		end,
		__sub = function(a: any, b: any): any
			return udim(a.Scale - b.Scale, a.Offset - b.Offset)
		end,
	}
)

function udim(scale: number?, offset: number?): any
	return newUDim({ Scale = scale or 0, Offset = int32(offset or 0) })
end

local UDimStub = {
	new = udim,
}

local _, newUDim2 = datatype("UDim2", function(s: any)
	return `\{{s.X.Scale}, {s.X.Offset}\}, \{{s.Y.Scale}, {s.Y.Offset}\}`
end)

local function udim2(x: any, y: any): any
	return newUDim2({ X = x, Y = y, Width = x, Height = y })
end

local UDim2Stub = {
	new = function(a: any, b: any, c: number?, d: number?): any
		return if type(a) == "table" then udim2(a, b) else udim2(UDimStub.new(a, b), UDimStub.new(c, d))
	end,
	fromScale = function(x: number?, y: number?): any
		return udim2(UDimStub.new(x, 0), UDimStub.new(y, 0))
	end,
	fromOffset = function(x: number?, y: number?): any
		return udim2(UDimStub.new(0, x), UDimStub.new(0, y))
	end,
}

local vector2: (x: number?, y: number?) -> any
local _, newVector2 = datatype("Vector2", function(s: any)
	return `{s.X}, {s.Y}`
end, {
	Lerp = function(self: any, goal: any, alpha: number): any
		return vector2(self.X + (goal.X - self.X) * alpha, self.Y + (goal.Y - self.Y) * alpha)
	end,
}, {
	__add = function(a: any, b: any): any
		return vector2(a.X + b.X, a.Y + b.Y)
	end,
	__sub = function(a: any, b: any): any
		return vector2(a.X - b.X, a.Y - b.Y)
	end,
	__mul = function(a: any, b: any): any
		if type(b) == "number" then
			return vector2(a.X * b, a.Y * b)
		elseif type(a) == "number" then
			return vector2(a * b.X, a * b.Y)
		end
		return vector2(a.X * b.X, a.Y * b.Y)
	end,
	__div = function(a: any, b: any): any
		return if type(b) == "number" then vector2(a.X / b, a.Y / b) else vector2(a.X / b.X, a.Y / b.Y)
	end,
	__unm = function(a: any): any
		return vector2(-a.X, -a.Y)
	end,
})
function vector2(x: number?, y: number?): any
	return newVector2({ X = x or 0, Y = y or 0 })
end

local Vector2Stub = { new = vector2, zero = vector2(0, 0) }

local vector3: (x: number?, y: number?, z: number?) -> any
local _, newVector3 = datatype("Vector3", function(s: any)
	return `{s.X}, {s.Y}, {s.Z}`
end, {
	Lerp = function(self: any, goal: any, alpha: number): any
		return vector3(
			self.X + (goal.X - self.X) * alpha,
			self.Y + (goal.Y - self.Y) * alpha,
			self.Z + (goal.Z - self.Z) * alpha
		)
	end,
}, {
	__add = function(a: any, b: any): any
		return vector3(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
	end,
	__sub = function(a: any, b: any): any
		return vector3(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
	end,
	__mul = function(a: any, b: any): any
		if type(b) == "number" then
			return vector3(a.X * b, a.Y * b, a.Z * b)
		elseif type(a) == "number" then
			return vector3(a * b.X, a * b.Y, a * b.Z)
		end
		return vector3(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
	end,
	__div = function(a: any, b: any): any
		return if type(b) == "number"
			then vector3(a.X / b, a.Y / b, a.Z / b)
			else vector3(a.X / b.X, a.Y / b.Y, a.Z / b.Z)
	end,
	__unm = function(a: any): any
		return vector3(-a.X, -a.Y, -a.Z)
	end,
})
function vector3(x: number?, y: number?, z: number?): any
	return newVector3({ X = x or 0, Y = y or 0, Z = z or 0 })
end

local Vector3Stub = { new = vector3, zero = vector3(0, 0, 0) }

local ENUM_VALUES: { [string]: { [string]: number } } = {
	FontWeight = {
		Thin = 100,
		ExtraLight = 200,
		Light = 300,
		Regular = 400,
		Medium = 500,
		SemiBold = 600,
		Bold = 700,
		ExtraBold = 800,
		Heavy = 900,
	},
	InputSink = { None = 0, Activate = 1, All = 100 },
	EasingStyle = {
		Linear = 0,
		Sine = 1,
		Back = 2,
		Quad = 3,
		Quart = 4,
		Quint = 5,
		Bounce = 6,
		Elastic = 7,
		Exponential = 8,
		Circular = 9,
		Cubic = 10,
	},
	EasingDirection = { In = 0, Out = 1, InOut = 2 },
}

local EnumItemMt = {
	__type = "EnumItem",
	__tostring = function(self: any): string
		return `Enum.{tostring(self.EnumType)}.{self.Name}`
	end,
}

local EnumStub = setmetatable({}, {
	__type = "Enums",
	__index = function(enums: any, enumType: string): any
		local values = ENUM_VALUES[enumType]
		local items
		items = setmetatable({}, {
			__type = "Enum",
			__index = function(self: any, name: string): any
				local item = table.freeze(setmetatable({
					Name = name,
					EnumType = items,
					Value = if values then values[name] or 0 else 0,
				}, EnumItemMt))
				rawset(self, name, item)
				return item
			end,
			__tostring = function(): string
				return enumType
			end,
		})
		rawset(enums, enumType, items)
		return items
	end,
	__tostring = function(): string
		return "Enums"
	end,
})

local _, newFont = datatype("Font", function(s: any)
	return `{s.Family}, {s.Weight.Name}, {s.Style.Name}`
end)

local function font(family: string, weight: any?, style: any?): any
	local resolvedWeight = weight or EnumStub.FontWeight.Regular
	return newFont({
		Family = family,
		Weight = resolvedWeight,
		Style = style or EnumStub.FontStyle.Normal,
		Bold = resolvedWeight.Value >= 600,
	})
end

local FontStub = {
	new = font,
	fromEnum = function(item: any): any
		return font(`rbxasset://fonts/families/{item.Name}.json`)
	end,
	fromId = function(id: number, weight: any?, style: any?): any
		return font(`rbxassetid://{id}`, weight, style)
	end,
}

local _, newTweenInfo = datatype("TweenInfo", function(s: any)
	return `{s.Time}, {s.EasingStyle.Name}, {s.EasingDirection.Name}, {s.RepeatCount}, {s.Reverses}, {s.DelayTime}`
end)

local TweenInfoStub = {
	new = function(
		time: number?,
		easingStyle: any?,
		easingDirection: any?,
		repeatCount: number?,
		reverses: boolean?,
		delayTime: number?
	): any
		return newTweenInfo({
			Time = time or 1,
			EasingStyle = easingStyle or EnumStub.EasingStyle.Quad,
			EasingDirection = easingDirection or EnumStub.EasingDirection.Out,
			RepeatCount = repeatCount or 0,
			Reverses = reverses or false,
			DelayTime = delayTime or 0,
		})
	end,
}

local _, newColorKeypoint = datatype("ColorSequenceKeypoint", function(s: any)
	return `{s.Time}, {s.Value}`
end)
local function colorKeypoint(time: number, value: any): any
	return newColorKeypoint({ Time = time, Value = value })
end

local _, newNumberKeypoint = datatype("NumberSequenceKeypoint", function(s: any)
	return `{s.Time}, {s.Value}, {s.Envelope}`
end)
local function numberKeypoint(time: number, value: number, envelope: number?): any
	return newNumberKeypoint({ Time = time, Value = value, Envelope = envelope or 0 })
end

local function sequence(name: string, keypoint: (time: number, value: any) -> any): any
	local mt = {
		__type = name,
		__eq = function(a: any, b: any): boolean
			if getmetatable(b) ~= getmetatable(a) or #a.Keypoints ~= #b.Keypoints then
				return false
			end
			for i, point in a.Keypoints do
				if point ~= b.Keypoints[i] then
					return false
				end
			end
			return true
		end,
		__tostring = function(self: any): string
			local parts = {}
			for _, point in self.Keypoints do
				table.insert(parts, `({tostring(point)})`)
			end
			return `{name}({table.concat(parts, ", ")})`
		end,
	}
	return {
		new = function(first: any, last: any?): any
			local points = if type(first) == "table" and getmetatable(first) == nil
				then table.clone(first)
				else { keypoint(0, first), keypoint(1, if last == nil then first else last) }
			return table.freeze(setmetatable({ Keypoints = table.freeze(points) }, mt))
		end,
	}
end

local Compat: any = {}
Compat.isRoblox = false
Compat.traceback = traceback
Compat.warn = warn
Compat.setWarnHook = setWarnHook
Compat.task = compatTask
Compat.clock = Clock.now
Compat.typeof = compatTypeof
Compat.services = {} :: { [string]: any }
Compat.getService = function(name: string): any
	return Compat.services[name]
end
Compat.Instance = nil
Compat.Color3 = Color3Stub
Compat.UDim = UDimStub
Compat.UDim2 = UDim2Stub
Compat.Vector2 = Vector2Stub
Compat.Vector3 = Vector3Stub
Compat.Font = FontStub
Compat.TweenInfo = TweenInfoStub
Compat.Enum = EnumStub
Compat.ColorSequence = sequence("ColorSequence", colorKeypoint)
Compat.ColorSequenceKeypoint = { new = colorKeypoint }
Compat.NumberSequence = sequence("NumberSequence", numberKeypoint)
Compat.NumberSequenceKeypoint = { new = numberKeypoint }

return Compat :: Compat
