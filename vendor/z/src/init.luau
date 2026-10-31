--!optimize 2
--!native
--!strict

-- Documentation: github.com/kohltastrophe/Z
-- High-performance, schematized buffer serialization for Roblox Luau

local SIZE_8 = 2 ^ 8 - 1
local SIZE_16 = 2 ^ 16 - 1
local SIZE_32 = 2 ^ 32 - 1

export type Read = (b: buffer, offset: number) -> (any, number)
export type Write = (b: buffer, offset: number, value: any) -> number
export type ZType = { read: Read, write: Write }

export type Data = { [number | string | ZType]: any }
export type SchemaDefinition = { [number | string | ZType]: ZType }

export type Field = { key: number | string | ZType, read: Read, write: Write, type: string }
export type Schema = {
	count: number,
	fields: { Field },
	keys: { number | string | ZType },
	reads: { Read },
	writes: { Write },
	isList: boolean,
	isMap: boolean,
	name: string,
	read: Read,
	write: Write,
	maxItems: number?,
	readLen: typeof(buffer.readu8)?,
	writeLen: typeof(buffer.writeu8)?,
	sizeLen: number?,
}

local function isZType(value: any?): boolean
	return type(value) == "table" and type(value.read) == "function" and type(value.write) == "function"
end

local MB = 1024 ^ 2

local Z = {
	BUFFER = buffer.create(MB),
	TRIM_STRINGS = false,
}

local someCache = {}

--- Wraps a ZType to make it optional, adding 1 byte of overhead.
function Z.some(t: ZType): ZType
	local result = someCache[t]

	if not result then
		local read, write = t.read, t.write
		result = table.freeze({
			name = `some({(t :: any).name})`,
			write = function(b: buffer, offset: number, value: any): number
				if value ~= nil then
					buffer.writeu8(b, offset, 1)
					return write(b, offset + 1, value)
				else
					buffer.writeu8(b, offset, 0)
					return offset + 1
				end
			end,
			read = function(b: buffer, offset: number, safe: boolean?): (any, number)
				if buffer.readu8(b, offset) == 1 then
					return (read :: any)(b, offset + 1, safe)
				else
					return nil, offset + 1
				end
			end,
		}) :: any
		someCache[t] = result
	end

	return result
end

type B = boolean

local function readBool(b: buffer, offset: number): (B, B, B, B, B, B, B, B)
	local x = buffer.readu8(b, offset)
	return bit32.btest(x, 1),
		bit32.btest(x, 2),
		bit32.btest(x, 4),
		bit32.btest(x, 8),
		bit32.btest(x, 16),
		bit32.btest(x, 32),
		bit32.btest(x, 64),
		bit32.btest(x, 128)
end

local function writeBool(buf: buffer, offset: number, a: B, b: B?, c: B?, d: B?, e: B?, f: B?, g: B?, h: B?)
	local byte = if a then 1 else 0
	if b then
		byte += 2
	end
	if c then
		byte += 4
	end
	if d then
		byte += 8
	end
	if e then
		byte += 16
	end
	if f then
		byte += 32
	end
	if g then
		byte += 64
	end
	if h then
		byte += 128
	end

	buffer.writeu8(buf, offset, byte)

	return offset + 1
end

Z.bool = {
	read = function(b: buffer, offset: number): (boolean, number)
		return buffer.readu8(b, offset) == 1, offset + 1
	end,
	write = function(b: buffer, offset: number, value: boolean): number
		if type(value) ~= "boolean" then
			error(`boolean expected, got {typeof(value)}`)
		end
		buffer.writeu8(b, offset, if value then 1 else 0)
		return offset + 1
	end,
}

Z.bools = {
	read = function(b: buffer, offset: number): ({ boolean }, number)
		return { readBool(b, offset) }, offset + 1
	end,
	write = function(b: buffer, offset: number, value: { boolean }): number
		return writeBool(b, offset, value[1], value[2], value[3], value[4], value[5], value[6], value[7], value[8])
	end,
}

Z.boolean = Z.bool

Z.u8 = {
	read = function(b: buffer, offset: number): (number, number)
		return buffer.readu8(b, offset), offset + 1
	end,
	write = function(b: buffer, offset: number, value: number): number
		buffer.writeu8(b, offset, value)
		return offset + 1
	end,
}

Z.u16 = {
	read = function(b: buffer, offset: number): (number, number)
		return buffer.readu16(b, offset), offset + 2
	end,
	write = function(b: buffer, offset: number, value: number): number
		buffer.writeu16(b, offset, value)
		return offset + 2
	end,
}

Z.u32 = {
	read = function(b: buffer, offset: number): (number, number)
		return buffer.readu32(b, offset), offset + 4
	end,
	write = function(b: buffer, offset: number, value: number): number
		buffer.writeu32(b, offset, value)
		return offset + 4
	end,
}

local function readVarIntFallback(b: buffer, offset: number, result: number): (number, number)
	local current = buffer.readu8(b, offset + 5)
	result += (current % 128) * 34359738368
	if current < 128 then
		return result, offset + 6
	end

	current = buffer.readu8(b, offset + 6)
	result += (current % 128) * 4398046511104
	if current < 128 then
		return result, offset + 7
	end

	current = buffer.readu8(b, offset + 7)
	result += (current % 128) * 562949953421312
	if current < 128 then
		return result, offset + 8
	end

	current = buffer.readu8(b, offset + 8)
	result += current * 72057594037927936
	return result, offset + 9
end

local function writeVarIntFallback(b: buffer, offset: number, value: number): number
	local temp = value
	while temp >= 128 do
		buffer.writeu8(b, offset, (temp % 128) + 128)
		offset += 1
		temp = temp // 128
	end
	buffer.writeu8(b, offset, temp)
	return offset + 1
end

local function writeVarIntUnsigned(b: buffer, offset: number, value: number): number
	if value < 0 then
		error(`unsigned integer expected, got negative number: {value}`)
	elseif value < 128 then
		buffer.writeu8(b, offset, value)
		return offset + 1
	elseif value < 16384 then
		buffer.writeu16(b, offset, (value % 128 + 128) + (value // 128) * 256)
		return offset + 2
	elseif value < 2097152 then
		buffer.writeu16(b, offset, (value % 128 + 128) + ((value // 128) % 128 + 128) * 256)
		buffer.writeu8(b, offset + 2, value // 16384)
		return offset + 3
	elseif value < 268435456 then
		buffer.writeu32(
			b,
			offset,
			(value % 128 + 128)
				+ ((value // 128) % 128 + 128) * 256
				+ ((value // 16384) % 128 + 128) * 65536
				+ (value // 2097152) * 16777216
		)
		return offset + 4
	elseif value < 34359738368 then
		buffer.writeu32(
			b,
			offset,
			(value % 128 + 128)
				+ ((value // 128) % 128 + 128) * 256
				+ ((value // 16384) % 128 + 128) * 65536
				+ ((value // 2097152) % 128 + 128) * 16777216
		)
		buffer.writeu8(b, offset + 4, value // 268435456)
		return offset + 5
	else
		return writeVarIntFallback(b, offset, value)
	end
end

Z.uint = {
	read = function(b: buffer, offset: number): (number, number)
		local b0 = buffer.readu8(b, offset)
		if b0 < 128 then
			return b0, offset + 1
		end

		local b1 = buffer.readu8(b, offset + 1)
		if b1 < 128 then
			return (b0 - 128) + (b1 * 128), offset + 2
		end

		local b2 = buffer.readu8(b, offset + 2)
		if b2 < 128 then
			return (b0 - 128) + (b1 - 128) * 128 + (b2 * 16384), offset + 3
		end

		local b3 = buffer.readu8(b, offset + 3)
		if b3 < 128 then
			return (b0 - 128) + (b1 - 128) * 128 + (b2 - 128) * 16384 + (b3 * 2097152), offset + 4
		end

		local b4 = buffer.readu8(b, offset + 4)
		if b4 < 128 then
			return (b0 - 128) + (b1 - 128) * 128 + (b2 - 128) * 16384 + (b3 - 128) * 2097152 + (b4 * 268435456),
				offset + 5
		end

		return readVarIntFallback(
			b,
			offset,
			(b0 - 128) + (b1 - 128) * 128 + (b2 - 128) * 16384 + (b3 - 128) * 2097152 + (b4 - 128) * 268435456
		)
	end,
	write = writeVarIntUnsigned,
}

Z.i8 = {
	read = function(b: buffer, offset: number): (number, number)
		return buffer.readi8(b, offset), offset + 1
	end,
	write = function(b: buffer, offset: number, value: number): number
		buffer.writei8(b, offset, value)
		return offset + 1
	end,
}

Z.i16 = {
	read = function(b: buffer, offset: number): (number, number)
		return buffer.readi16(b, offset), offset + 2
	end,
	write = function(b: buffer, offset: number, value: number): number
		buffer.writei16(b, offset, value)
		return offset + 2
	end,
}

Z.i32 = {
	read = function(b: buffer, offset: number): (number, number)
		return buffer.readi32(b, offset), offset + 4
	end,
	write = function(b: buffer, offset: number, value: number): number
		buffer.writei32(b, offset, value)
		return offset + 4
	end,
}

Z.int = {
	read = function(b: buffer, offset: number): (number, number)
		local b0 = buffer.readu8(b, offset)
		local isNegative = (b0 % 2 == 1)

		if b0 < 128 then
			local v = b0
			return (if isNegative then -(v + 1) / 2 else v / 2), offset + 1
		end

		local b1 = buffer.readu8(b, offset + 1)
		if b1 < 128 then
			local v = (b0 - 128) + (b1 * 128)
			return (if isNegative then -(v + 1) / 2 else v / 2), offset + 2
		end

		local b2 = buffer.readu8(b, offset + 2)
		if b2 < 128 then
			local v = (b0 - 128) + (b1 - 128) * 128 + (b2 * 16384)
			return (if isNegative then -(v + 1) / 2 else v / 2), offset + 3
		end

		local b3 = buffer.readu8(b, offset + 3)
		if b3 < 128 then
			local v = (b0 - 128) + (b1 - 128) * 128 + (b2 - 128) * 16384 + (b3 * 2097152)
			return (if isNegative then -(v + 1) / 2 else v / 2), offset + 4
		end

		local b4 = buffer.readu8(b, offset + 4)
		if b4 < 128 then
			local v = (b0 - 128) + (b1 - 128) * 128 + (b2 - 128) * 16384 + (b3 - 128) * 2097152 + (b4 * 268435456)
			return (if isNegative then -(v + 1) / 2 else v / 2), offset + 5
		end

		local v, newOffset = readVarIntFallback(
			b,
			offset,
			(b0 - 128) + (b1 - 128) * 128 + (b2 - 128) * 16384 + (b3 - 128) * 2097152 + (b4 - 128) * 268435456
		)

		return (if isNegative then -(v + 1) / 2 else v / 2), newOffset
	end,

	write = function(b: buffer, offset: number, value: number): number
		local head: number
		local tail: number

		if value >= 0 then
			head = (value % 64) * 2
			tail = value // 64
		else
			local absValue = -value
			head = ((absValue % 64) * 2 - 1) % 128
			tail = (absValue - 1) // 64
		end

		if tail == 0 then
			buffer.writeu8(b, offset, head)
			return offset + 1
		else
			buffer.writeu8(b, offset, head + 128)
			return writeVarIntUnsigned(b, offset + 1, tail)
		end
	end,
}

Z.f32 = {
	read = function(b: buffer, offset: number): (number, number)
		return buffer.readf32(b, offset), offset + 4
	end,
	write = function(b: buffer, offset: number, value: number): number
		buffer.writef32(b, offset, value)
		return offset + 4
	end,
}

Z.f64 = {
	read = function(b: buffer, offset: number): (number, number)
		return buffer.readf64(b, offset), offset + 8
	end,
	write = function(b: buffer, offset: number, value: number): number
		buffer.writef64(b, offset, value)
		return offset + 8
	end,
}

Z.number = Z.f64

Z.byte = {
	read = function(b: buffer, offset: number): (string, number)
		return buffer.readstring(b, offset, 1), offset + 1
	end,
	write = function(b: buffer, offset: number, value: string): number
		buffer.writestring(b, offset, value, 1)
		return offset + 1
	end,
}

local function createStringType(
	size: number,
	readLen: (b: buffer, offset: number) -> number,
	writeLen: (b: buffer, offset: number, value: number) -> (),
	lenBytes: number
)
	return {
		read = function(b: buffer, offset: number): (string, number)
			local length = readLen(b, offset)
			return buffer.readstring(b, offset + lenBytes, length), offset + lenBytes + length
		end,
		write = function(b: buffer, offset: number, value: string): number
			local rawLength = string.len(value)
			if rawLength > size and not Z.TRIM_STRINGS then
				error(`string exceeds bounds`)
			end
			local length = math.min(rawLength, size)
			writeLen(b, offset, length)
			buffer.writestring(b, offset + lenBytes, value, length)
			return offset + lenBytes + length
		end,
	}
end

Z.str8 = createStringType(SIZE_8, buffer.readu8, buffer.writeu8, 1)
Z.str16 = createStringType(SIZE_16, buffer.readu16, buffer.writeu16, 2)
Z.str32 = createStringType(SIZE_32, buffer.readu32, buffer.writeu32, 4)
Z.string = Z.str32

local function createBufferType(
	size: number,
	readLen: (b: buffer, offset: number) -> number,
	writeLen: (b: buffer, offset: number, value: number) -> (),
	lenBytes: number
)
	return {
		read = function(b: buffer, offset: number): (buffer, number)
			local length = readLen(b, offset)
			local value = buffer.create(length)
			buffer.copy(value, 0, b, offset + lenBytes, length)
			return value, offset + lenBytes + length
		end,
		write = function(b: buffer, offset: number, value: buffer): number
			local length = buffer.len(value)
			if length > size then
				error(`buffer exceeds bounds`)
			end
			writeLen(b, offset, length)
			buffer.copy(b, offset + lenBytes, value)
			return offset + lenBytes + length
		end,
	}
end

Z.buffer8 = createBufferType(SIZE_8, buffer.readu8, buffer.writeu8, 1)
Z.buffer16 = createBufferType(SIZE_16, buffer.readu16, buffer.writeu16, 2)
Z.buffer32 = createBufferType(SIZE_32, buffer.readu32, buffer.writeu32, 4)
Z.buffer = Z.buffer32

local range = math.rad(359)

local function Angle8(angle: number): number
	return math.floor((angle % (2 * math.pi)) * 255 / range + 0.5)
end

local Angle8Map: { number } = {}

for i = 0, SIZE_8 do
	Angle8Map[i] = i * range / SIZE_8
end

for degrees = 0, 315, 45 do
	local angle = math.rad(degrees)
	Angle8Map[Angle8(angle)] = angle
end

Z.Angle8 = {
	read = function(b: buffer, offset: number): (number, number)
		return Angle8Map[buffer.readu8(b, offset)], offset + 1
	end,
	write = function(b: buffer, offset: number, value: number): number
		buffer.writeu8(b, offset, Angle8(value))
		return offset + 1
	end,
}

if Axes then
	Z.Axes = {
		read = function(b: buffer, offset: number): (Axes, number)
			local x, y, z = readBool(b, offset)
			local back, bottom, front, left, right, top = readBool(b, offset + 1)
			return (Axes.new :: any)(
				x and Enum.Axis.X :: any,
				y and Enum.Axis.Y :: any,
				z and Enum.Axis.Z :: any,
				back and Enum.NormalId.Back :: any,
				bottom and Enum.NormalId.Bottom :: any,
				front and Enum.NormalId.Front :: any,
				left and Enum.NormalId.Left :: any,
				right and Enum.NormalId.Right :: any,
				top and Enum.NormalId.Top :: any
			),
				offset + 2
		end,
		write = function(b: buffer, offset: number, value: Axes): number
			writeBool(b, offset, value.X, value.Y, value.Z)
			writeBool(b, offset + 1, value.Back, value.Bottom, value.Front, value.Left, value.Right, value.Top)
			return offset + 2
		end,
	}
end

if BrickColor then
	Z.BrickColor = {
		read = function(b: buffer, offset: number): (BrickColor, number)
			return BrickColor.new(buffer.readu16(b, offset)), offset + 2
		end,
		write = function(b: buffer, offset: number, value: BrickColor): number
			buffer.writeu16(b, offset, value.Number)
			return offset + 2
		end,
	}
end

if CFrame then
	Z.CFrame = {
		read = function(b: buffer, offset: number): (CFrame, number)
			return CFrame.new(
				buffer.readf32(b, offset),
				buffer.readf32(b, offset + 4),
				buffer.readf32(b, offset + 8),
				buffer.readf32(b, offset + 12),
				buffer.readf32(b, offset + 16),
				buffer.readf32(b, offset + 20),
				buffer.readf32(b, offset + 24),
				buffer.readf32(b, offset + 28),
				buffer.readf32(b, offset + 32),
				buffer.readf32(b, offset + 36),
				buffer.readf32(b, offset + 40),
				buffer.readf32(b, offset + 44)
			),
				offset + 48
		end,
		write = function(b: buffer, offset: number, value: CFrame): number
			local v0, v1, v2, v3, v4, v5, v6, v7, v8, v9, v10, v11 = value:GetComponents()
			buffer.writef32(b, offset, v0)
			buffer.writef32(b, offset + 4, v1)
			buffer.writef32(b, offset + 8, v2)
			buffer.writef32(b, offset + 12, v3)
			buffer.writef32(b, offset + 16, v4)
			buffer.writef32(b, offset + 20, v5)
			buffer.writef32(b, offset + 24, v6)
			buffer.writef32(b, offset + 28, v7)
			buffer.writef32(b, offset + 32, v8)
			buffer.writef32(b, offset + 36, v9)
			buffer.writef32(b, offset + 40, v10)
			buffer.writef32(b, offset + 44, v11)
			return offset + 48
		end,
	}

	Z.CFrame28 = {
		read = function(b: buffer, offset: number): (CFrame, number)
			return CFrame.fromAxisAngle(
				Vector3.new(
					buffer.readf32(b, offset + 12),
					buffer.readf32(b, offset + 16),
					buffer.readf32(b, offset + 20)
				),
				buffer.readf32(b, offset + 24)
			) + Vector3.new(buffer.readf32(b, offset), buffer.readf32(b, offset + 4), buffer.readf32(b, offset + 8)),
				offset + 28
		end,
		write = function(b: buffer, offset: number, value: CFrame): number
			local axis, angle = value:ToAxisAngle()
			buffer.writef32(b, offset, value.X)
			buffer.writef32(b, offset + 4, value.Y)
			buffer.writef32(b, offset + 8, value.Z)
			buffer.writef32(b, offset + 12, axis.X)
			buffer.writef32(b, offset + 16, axis.Y)
			buffer.writef32(b, offset + 20, axis.Z)
			buffer.writef32(b, offset + 24, angle)
			return offset + 28
		end,
	}

	Z.CFrame15 = {
		read = function(b: buffer, offset: number): (CFrame, number)
			return CFrame.Angles(
				Angle8Map[buffer.readu8(b, offset + 12)],
				Angle8Map[buffer.readu8(b, offset + 13)],
				Angle8Map[buffer.readu8(b, offset + 14)]
			) + Vector3.new(buffer.readf32(b, offset), buffer.readf32(b, offset + 4), buffer.readf32(b, offset + 8)),
				offset + 15
		end,
		write = function(b: buffer, offset: number, value: CFrame): number
			local rx, ry, rz = value:ToOrientation()
			buffer.writef32(b, offset, value.X)
			buffer.writef32(b, offset + 4, value.Y)
			buffer.writef32(b, offset + 8, value.Z)
			buffer.writeu32(b, offset + 12, Angle8(rx) + Angle8(ry) * 256 + Angle8(rz) * 65536)
			return offset + 15
		end,
	}
end

if Color3 then
	Z.Color3 = {
		read = function(b: buffer, offset: number): (Color3, number)
			return Color3.fromRGB(buffer.readu8(b, offset), buffer.readu8(b, offset + 1), buffer.readu8(b, offset + 2)),
				offset + 3
		end,
		write = function(b: buffer, offset: number, value: Color3): number
			local R = math.floor(value.R * 255 + 0.5)
			local G = math.floor(value.G * 255 + 0.5)
			local B = math.floor(value.B * 255 + 0.5)
			buffer.writeu32(b, offset, R + G * 256 + B * 65536)
			return offset + 3
		end,
	}
end

if ColorSequenceKeypoint then
	Z.ColorSequenceKeypoint = {
		read = function(b: buffer, offset: number): (ColorSequenceKeypoint, number)
			return ColorSequenceKeypoint.new(
				buffer.readu8(b, offset) / 255,
				Color3.fromRGB(buffer.readu8(b, offset + 1), buffer.readu8(b, offset + 2), buffer.readu8(b, offset + 3))
			),
				offset + 4
		end,
		write = function(b: buffer, offset: number, value: ColorSequenceKeypoint): number
			local color = value.Value
			local T = math.floor(value.Time * 255 + 0.5)
			local R = math.floor(color.R * 255 + 0.5)
			local G = math.floor(color.G * 255 + 0.5)
			local B = math.floor(color.B * 255 + 0.5)
			buffer.writeu32(b, offset, T + R * 256 + G * 65536 + B * 16777216)
			return offset + 4
		end,
	}
end

if ColorSequence then
	Z.ColorSequence = {
		read = function(b: buffer, offset: number): (ColorSequence, number)
			local count = buffer.readu8(b, offset)
			local points: { ColorSequenceKeypoint } = {}
			for i = 1, count do
				local point = Z.ColorSequenceKeypoint.read(b, offset + 1 + (i - 1) * 4)
				table.insert(points, point)
			end
			return ColorSequence.new(points), offset + 1 + count * 4
		end,
		write = function(b: buffer, offset: number, value: ColorSequence): number
			local count = #value.Keypoints
			buffer.writeu8(b, offset, count)
			for i, point in value.Keypoints do
				Z.ColorSequenceKeypoint.write(b, offset + 1 + (i - 1) * 4, point)
			end
			return offset + 1 + count * 4
		end,
	}
end

if DateTime then
	Z.DateTime = {
		read = function(b: buffer, offset: number): (DateTime, number)
			return DateTime.fromUnixTimestampMillis(buffer.readf64(b, offset)), offset + 8
		end,
		write = function(b: buffer, offset: number, value: DateTime): number
			buffer.writef64(b, offset, value.UnixTimestampMillis)
			return offset + 8
		end,
	}
end

if Enum then
	local enumCache = {}

	Z.EnumItem = setmetatable({
		read = function(b: buffer, offset: number): (EnumItem, number)
			local enumType, nextOffset = Z.str8.read(b, offset)
			return (Z.EnumItem :: any)(Enum[enumType]).read(b, nextOffset)
		end,
		write = function(b: buffer, offset: number, value: EnumItem): number
			offset = Z.str8.write(b, offset, tostring(value.EnumType))
			return (Z.EnumItem :: any)(value.EnumType).write(b, offset, value)
		end,
	}, {
		__call = function(_, enum: Enum): ZType
			if not enumCache[enum] then
				local items: { EnumItem } = enum:GetEnumItems()

				table.sort(items, function(a: EnumItem, b: EnumItem)
					return a.Value < b.Value
				end)

				local idToItem = table.create(#items) :: { EnumItem }
				local itemToId = {}

				for i, item in items do
					idToItem[i] = item
					itemToId[item] = i
				end

				local size, read, write = 4, buffer.readu32, buffer.writeu32
				local n = #items
				if n <= SIZE_8 then
					size, read, write = 1, buffer.readu8, buffer.writeu8
				elseif n <= SIZE_16 then
					size, read, write = 2, buffer.readu16, buffer.writeu16
				end

				enumCache[enum] = table.freeze({
					name = tostring(enum),
					read = function(b: buffer, offset: number): (EnumItem, number)
						return idToItem[read(b, offset)], offset + size
					end,
					write = function(b: buffer, offset: number, value: EnumItem): number
						write(b, offset, itemToId[value])
						return offset + size
					end,
				})
			end

			return enumCache[enum] :: any
		end,
	})
end

if Faces then
	Z.Faces = {
		read = function(b: buffer, offset: number): (Faces, number)
			local back, bottom, front, left, right, top = readBool(b, offset)
			return Faces.new(
				back and Enum.NormalId.Back :: any,
				bottom and Enum.NormalId.Bottom :: any,
				front and Enum.NormalId.Front :: any,
				left and Enum.NormalId.Left :: any,
				right and Enum.NormalId.Right :: any,
				top and Enum.NormalId.Top :: any
			),
				offset + 1
		end,
		write = function(b: buffer, offset: number, value: Faces): number
			writeBool(b, offset, value.Back, value.Bottom, value.Front, value.Left, value.Right, value.Top)
			return offset + 1
		end,
	}
end

if FloatCurveKey then
	Z.FloatCurveKey = {
		read = function(b: buffer, offset: number): (FloatCurveKey, number)
			local interpolation = Z.EnumItem(Enum.KeyInterpolationMode).read(b, offset)
			local time = buffer.readf32(b, offset + 1)
			local value = buffer.readf32(b, offset + 5)
			local result = FloatCurveKey.new(time, value, interpolation)
			offset += 9
			if interpolation == Enum.KeyInterpolationMode.Cubic then
				result.LeftTangent, offset = Z.some(Z.f32).read(b, offset)
				result.RightTangent, offset = Z.some(Z.f32).read(b, offset)
			end
			return result, offset
		end,
		write = function(b: buffer, offset: number, value: FloatCurveKey): number
			Z.EnumItem(Enum.KeyInterpolationMode).write(b, offset, value.Interpolation)
			buffer.writef32(b, offset + 1, value.Time)
			buffer.writef32(b, offset + 5, value.Value)
			offset += 9
			if value.Interpolation == Enum.KeyInterpolationMode.Cubic then
				offset = Z.some(Z.f32).write(b, offset, value.LeftTangent)
				offset = Z.some(Z.f32).write(b, offset, value.RightTangent)
			end
			return offset
		end,
	}
end

if Font then
	local weights = Enum.FontWeight:GetEnumItems()

	table.sort(weights, function(a: EnumItem, b: EnumItem)
		return a.Value < b.Value
	end)

	local idToWeight = table.create(#weights) :: { Enum.FontWeight }
	local weightToId = {}

	for i, v in weights do
		idToWeight[i] = v
		weightToId[v] = i
	end

	Z.Font = {
		read = function(b: buffer, offset: number): (Font, number)
			local byte = buffer.readu8(b, offset)
			local family, newOffset = Z.str8.read(b, offset + 1)
			local font = Font.new(
				family,
				idToWeight[byte // 4],
				if byte % 4 >= 2 then Enum.FontStyle.Italic else Enum.FontStyle.Normal
			)
			if byte % 2 == 1 then
				font.Bold = true
			end
			return font, newOffset
		end,
		write = function(b: buffer, offset: number, value: Font): number
			local byte = if value.Bold then 1 else 0
			if value.Style == Enum.FontStyle.Italic then
				byte += 2
			end
			byte += weightToId[value.Weight] * 4
			buffer.writeu8(b, offset, byte)
			return Z.str8.write(b, offset + 1, value.Family)
		end,
	}
end

if NumberRange then
	Z.NumberRange = {
		read = function(b: buffer, offset: number): (NumberRange, number)
			local min = buffer.readf64(b, offset)
			local max = buffer.readf64(b, offset + 8)
			return NumberRange.new(min, max), offset + 16
		end,
		write = function(b: buffer, offset: number, value: NumberRange): number
			buffer.writef64(b, offset, value.Min)
			buffer.writef64(b, offset + 8, value.Max)
			return offset + 16
		end,
	}
end

if NumberSequenceKeypoint then
	Z.NumberSequenceKeypoint = {
		read = function(b: buffer, offset: number): (NumberSequenceKeypoint, number)
			return NumberSequenceKeypoint.new(
				buffer.readf32(b, offset),
				buffer.readf32(b, offset + 4),
				buffer.readf32(b, offset + 8)
			),
				offset + 12
		end,
		write = function(b: buffer, offset: number, value: NumberSequenceKeypoint): number
			buffer.writef32(b, offset, value.Time)
			buffer.writef32(b, offset + 4, value.Value)
			buffer.writef32(b, offset + 8, value.Envelope)
			return offset + 12
		end,
	}
end

if NumberSequence then
	Z.NumberSequence = {
		read = function(b: buffer, offset: number): (NumberSequence, number)
			local count = buffer.readu8(b, offset)
			local keypoints: { NumberSequenceKeypoint } = {}
			for i = 1, count do
				keypoints[i] = Z.NumberSequenceKeypoint.read(b, offset + 1 + (i - 1) * 12)
			end
			return NumberSequence.new(keypoints), offset + 1 + count * 12
		end,
		write = function(b: buffer, offset: number, value: NumberSequence): number
			local count = #value.Keypoints
			buffer.writeu8(b, offset, count)
			for i, point in value.Keypoints do
				Z.NumberSequenceKeypoint.write(b, offset + 1 + (i - 1) * 12, point)
			end
			return offset + 1 + count * 12
		end,
	}
end

if UDim then
	Z.UDim = {
		read = function(b: buffer, offset: number): (UDim, number)
			return UDim.new(buffer.readf32(b, offset), buffer.readf32(b, offset + 4)), offset + 8
		end,
		write = function(b: buffer, offset: number, value: UDim): number
			buffer.writef32(b, offset, value.Scale)
			buffer.writef32(b, offset + 4, value.Offset)
			return offset + 8
		end,
	}
end

if UDim2 then
	Z.UDim2 = {
		read = function(b: buffer, offset: number): (UDim2, number)
			return UDim2.new(
				buffer.readf32(b, offset),
				buffer.readf32(b, offset + 4),
				buffer.readf32(b, offset + 8),
				buffer.readf32(b, offset + 12)
			),
				offset + 16
		end,
		write = function(b: buffer, offset: number, value: UDim2): number
			buffer.writef32(b, offset, value.X.Scale)
			buffer.writef32(b, offset + 4, value.X.Offset)
			buffer.writef32(b, offset + 8, value.Y.Scale)
			buffer.writef32(b, offset + 12, value.Y.Offset)
			return offset + 16
		end,
	}
end

if Vector2 then
	Z.Vector2 = {
		read = function(b: buffer, offset: number): (Vector2, number)
			return Vector2.new(buffer.readf32(b, offset), buffer.readf32(b, offset + 4)), offset + 8
		end,
		write = function(b: buffer, offset: number, value: Vector2): number
			buffer.writef32(b, offset, value.X)
			buffer.writef32(b, offset + 4, value.Y)
			return offset + 8
		end,
	}
end

if Vector2int16 then
	Z.Vector2i16 = {
		read = function(b: buffer, offset: number): (Vector2int16, number)
			return Vector2int16.new(buffer.readi16(b, offset), buffer.readi16(b, offset + 2)), offset + 4
		end,
		write = function(b: buffer, offset: number, value: Vector2int16): number
			buffer.writei16(b, offset, value.X)
			buffer.writei16(b, offset + 2, value.Y)
			return offset + 4
		end,
	}
	Z.Vector2int16 = Z.Vector2i16
end

if Vector3 then
	Z.Vector3 = {
		read = function(b: buffer, offset: number): (Vector3, number)
			return Vector3.new(buffer.readf32(b, offset), buffer.readf32(b, offset + 4), buffer.readf32(b, offset + 8)),
				offset + 12
		end,
		write = function(b: buffer, offset: number, value: Vector3): number
			buffer.writef32(b, offset, value.X)
			buffer.writef32(b, offset + 4, value.Y)
			buffer.writef32(b, offset + 8, value.Z)
			return offset + 12
		end,
	}
end

if Vector3int16 then
	Z.Vector3i16 = {
		read = function(b: buffer, offset: number): (Vector3int16, number)
			return Vector3int16.new(
				buffer.readi16(b, offset),
				buffer.readi16(b, offset + 2),
				buffer.readi16(b, offset + 4)
			),
				offset + 6
		end,
		write = function(b: buffer, offset: number, value: Vector3int16): number
			buffer.writei16(b, offset, value.X)
			buffer.writei16(b, offset + 2, value.Y)
			buffer.writei16(b, offset + 4, value.Z)
			return offset + 6
		end,
	}
	Z.Vector3int16 = Z.Vector3i16
end

if Path2DControlPoint then
	local ZERO = UDim2.new(0, 0, 0, 0)

	Z.Path2DControlPoint = {
		read = function(b: buffer, offset: number): (Path2DControlPoint, number)
			local position, leftTangentOffset = Z.some(Z.UDim2).read(b, offset)
			local leftTangent, rightTangentOffset = Z.some(Z.UDim2).read(b, leftTangentOffset)
			local rightTangent, nextOffset = Z.some(Z.UDim2).read(b, rightTangentOffset)
			return Path2DControlPoint.new(position or ZERO, leftTangent or ZERO, rightTangent or ZERO), nextOffset
		end,
		write = function(b: buffer, offset: number, v: Path2DControlPoint): number
			offset = Z.some(Z.UDim2).write(b, offset, if v.Position ~= ZERO then v.Position else nil)
			offset = Z.some(Z.UDim2).write(b, offset, if v.LeftTangent ~= ZERO then v.LeftTangent else nil)
			return Z.some(Z.UDim2).write(b, offset, if v.RightTangent ~= ZERO then v.RightTangent else nil)
		end,
	}
end

if PathWaypoint then
	Z.PathWaypoint = {
		read = function(b: buffer, offset: number): (PathWaypoint, number)
			local label, newOffset = Z.str8.read(b, offset + 13)
			return PathWaypoint.new(
				Z.Vector3.read(b, offset + 1),
				Enum.PathWaypointAction:FromValue(buffer.readu8(b, offset)) or Enum.PathWaypointAction.Walk,
				label
			),
				newOffset
		end,
		write = function(b: buffer, offset: number, value: PathWaypoint): number
			buffer.writeu8(b, offset, value.Action.Value)
			return Z.str8.write(b, Z.Vector3.write(b, offset + 1, value.Position), value.Label)
		end,
	}
end

if PhysicalProperties then
	Z.PhysicalProperties = {
		read = function(b: buffer, offset: number): (PhysicalProperties, number)
			return PhysicalProperties.new(
				buffer.readf32(b, offset),
				buffer.readf32(b, offset + 4),
				buffer.readf32(b, offset + 8),
				buffer.readf32(b, offset + 12),
				buffer.readf32(b, offset + 16)
			),
				offset + 20
		end,
		write = function(b: buffer, offset: number, value: PhysicalProperties): number
			buffer.writef32(b, offset, value.Density)
			buffer.writef32(b, offset + 4, value.Friction)
			buffer.writef32(b, offset + 8, value.Elasticity)
			buffer.writef32(b, offset + 12, value.FrictionWeight)
			buffer.writef32(b, offset + 16, value.ElasticityWeight)
			return offset + 20
		end,
	}
end

if Ray then
	Z.Ray = {
		read = function(b: buffer, offset: number): (Ray, number)
			local origin = Z.Vector3.read(b, offset)
			local direction = Z.Vector3.read(b, offset + 12)
			return Ray.new(origin, direction), offset + 24
		end,
		write = function(b: buffer, offset: number, value: Ray): number
			return Z.Vector3.write(b, Z.Vector3.write(b, offset, value.Origin), value.Direction)
		end,
	}
end

if Rect then
	Z.Rect = {
		read = function(b: buffer, offset: number): (Rect, number)
			local min = Z.Vector2.read(b, offset)
			local max = Z.Vector2.read(b, offset + 8)
			return Rect.new(min, max), offset + 16
		end,
		write = function(b: buffer, offset: number, value: Rect): number
			return Z.Vector2.write(b, Z.Vector2.write(b, offset, value.Min), value.Max)
		end,
	}
end

if Region3 then
	Z.Region3 = {
		read = function(b: buffer, offset: number): (Region3, number)
			local min = Z.Vector3.read(b, offset)
			local max = Z.Vector3.read(b, offset + 12)
			return Region3.new(min, max), offset + 24
		end,
		write = function(b: buffer, offset: number, value: Region3): number
			local halfSize = value.Size / 2
			local pos = value.CFrame.Position
			return Z.Vector3.write(b, Z.Vector3.write(b, offset, pos - halfSize), pos + halfSize)
		end,
	}
end

if Region3int16 then
	Z.Region3int16 = {
		read = function(b: buffer, offset: number): (Region3int16, number)
			local min = Z.Vector3i16.read(b, offset)
			local max = Z.Vector3i16.read(b, offset + 6)
			return Region3int16.new(min, max), offset + 12
		end,
		write = function(b: buffer, offset: number, value: Region3int16): number
			return Z.Vector3i16.write(b, Z.Vector3i16.write(b, offset, value.Min), value.Max)
		end,
	}
end

if RotationCurveKey then
	Z.RotationCurveKey = {
		read = function(b: buffer, offset: number): (RotationCurveKey, number)
			local interpolation = Z.EnumItem(Enum.KeyInterpolationMode).read(b, offset)
			local time = buffer.readf32(b, offset + 1)
			local value = Z.CFrame.read(b, offset + 5)
			local result = RotationCurveKey.new(time, value, interpolation)
			offset += 53
			if interpolation == Enum.KeyInterpolationMode.Cubic then
				result.LeftTangent, offset = Z.some(Z.f32).read(b, offset)
				result.RightTangent, offset = Z.some(Z.f32).read(b, offset)
			end
			return result, offset
		end,
		write = function(b: buffer, offset: number, value: RotationCurveKey): number
			Z.EnumItem(Enum.KeyInterpolationMode).write(b, offset, value.Interpolation)
			buffer.writef32(b, offset + 1, value.Time)
			offset = Z.CFrame.write(b, offset + 5, value.Value)
			if value.Interpolation == Enum.KeyInterpolationMode.Cubic then
				offset = Z.some(Z.f32).write(b, offset, value.LeftTangent)
				return Z.some(Z.f32).write(b, offset, value.RightTangent)
			end
			return offset
		end,
	}
end

if TweenInfo then
	local direction = Z.EnumItem(Enum.EasingDirection)
	local style = Z.EnumItem(Enum.EasingStyle)

	Z.TweenInfo = {
		read = function(b: buffer, offset: number): (TweenInfo, number)
			local result = TweenInfo.new(
				buffer.readf32(b, offset),
				style.read(b, offset + 11),
				direction.read(b, offset + 12),
				buffer.readi16(b, offset + 8),
				buffer.readu8(b, offset + 10) == 255,
				buffer.readf32(b, offset + 4)
			)
			return result, offset + 13
		end,
		write = function(b: buffer, offset: number, value: TweenInfo): number
			buffer.writef32(b, offset, value.Time)
			buffer.writef32(b, offset + 4, value.DelayTime)
			buffer.writei16(b, offset + 8, value.RepeatCount)
			buffer.writeu8(b, offset + 10, if value.Reverses then 255 else 0)
			return direction.write(b, style.write(b, offset + 11, value.EasingStyle), value.EasingDirection)
		end,
	}
end

local idToZType: { ZType } = { Z.EnumItem :: any }
local ZTypeToId: { [ZType]: number } = {}

Z.table = {
	read = function(b: buffer, offset: number): ({ [any]: any }, number)
		local length = buffer.readu32(b, offset)
		local value = table.create(length)
		offset += 4
		for _ = 1, length do
			local zTypeK = idToZType[buffer.readu8(b, offset)]
			local zTypeV = idToZType[buffer.readu8(b, offset + 1)]
			local k, valueOffset = zTypeK.read(b, offset + 2)
			local v, nextOffset = zTypeV.read(b, valueOffset)
			offset = nextOffset
			value[k] = v
		end
		return value, offset
	end,
	write = function(b: buffer, offset: number, value: { [any]: any }): number
		local length = 0
		local start = offset
		offset += 4
		for k, v in value do
			local typeK = typeof(k)
			local zTypeK: ZType = Z[typeK :: any]
			if not zTypeK then
				error(`unsupported type "{typeK}" for key "{k}"`)
			end
			local typeV = typeof(v)
			local zTypeV: ZType = Z[typeV :: any]
			if not zTypeV then
				error(`unsupported type "{typeV}" for value "{tostring(v)}" of key "{k}"`)
			end
			buffer.writeu16(b, offset, ZTypeToId[zTypeK] + ZTypeToId[zTypeV] * 256)
			offset = zTypeK.write(b, offset + 2, k)
			offset = zTypeV.write(b, offset, v)
			length += 1
		end
		buffer.writeu32(b, start, length)
		return offset
	end,
}

for k, v in next, Z do
	if isZType(v) then
		if not (v :: any).name then
			(v :: any).name = k
		end
		if not table.isfrozen(v :: any) then
			table.freeze(v :: any)
		end
		if not table.find(idToZType, v :: ZType) then
			table.insert(idToZType, v :: ZType)
		end
	end
end

table.sort(idToZType, function(a: any, b: any)
	return a.name < b.name
end)

for i, v in idToZType do
	ZTypeToId[v] = i
end

local function serializeUnsafe(schema: Schema, obj: Data, b: buffer, offset: number): number
	local keys = schema.keys
	local writes = schema.writes

	for i = 1, schema.count do
		offset = writes[i](b, offset, obj[keys[i]])
	end

	return offset
end

local function serializeListUnsafe(schema: Schema, list: { any }, b: buffer, offset: number): number
	if #list > schema.maxItems :: number then
		error(`List length exceeds bounds of {schema.maxItems}, got {#list}`)
	end

	local writeLen = schema.writeLen :: typeof(buffer.writeu8)

	writeLen(b, offset, #list)
	offset += schema.sizeLen :: number

	local write = schema.writes[1]

	for _, obj in list do
		offset = write(b, offset, obj)
	end

	return offset
end

local function serializeMapUnsafe(schema: Schema, map: { [any]: any }, b: buffer, offset: number): number
	local start = offset
	local writeK = (schema.fields[1].key :: ZType).write
	local writeV = schema.writes[1]
	local writeLen = schema.writeLen :: typeof(buffer.writeu8)

	offset += schema.sizeLen :: number

	local n = 0
	for k, v in map do
		offset = writeK(b, offset, k)
		offset = writeV(b, offset, v)
		n += 1
	end

	if n > schema.maxItems :: number then
		error(`Map length exceeds bounds of {schema.maxItems}, got {n}`)
	end

	writeLen(b, start, n)

	return offset
end

local function deserialize(schema: Schema, b: buffer, offset: number, safe: boolean?): (Data, number)
	local result: Data = {}
	local keys = schema.keys
	local reads = schema.reads
	local count = schema.count

	if safe then
		for i = 1, count do
			local ok, value, pos = pcall(reads[i] :: any, b, offset, safe)
			if ok then
				result[keys[i]], offset = value, pos
			end
		end
	else
		for i = 1, count do
			result[keys[i]], offset = reads[i](b, offset)
		end
	end

	return result, offset
end

local function deserializeList(schema: Schema, b: buffer, offset: number, safe: boolean?): (Data, number)
	local readLen = schema.readLen :: typeof(buffer.readu8)
	local read = schema.fields[1].read :: any
	local result: Data

	if safe then
		local ok, length = pcall(readLen, b, offset)

		if not ok then
			return result, offset
		end

		result = table.create(length) :: Data
		offset += schema.sizeLen :: number

		for i = 1, length do
			local success, value, pos = pcall(read, b, offset, safe)

			if not success then
				break
			end

			result[i], offset = value, pos
		end
	else
		local length = readLen(b, offset)
		offset += schema.sizeLen :: number
		result = table.create(length) :: Data

		for i = 1, length do
			result[i], offset = read(b, offset)
		end
	end

	return result, offset
end

local function deserializeMap(schema: Schema, b: buffer, offset: number, safe: boolean?): (Data, number)
	local readLen = schema.readLen :: typeof(buffer.readu8)
	local readK = (schema.fields[1].key :: ZType).read :: any
	local readV = schema.reads[1] :: any
	local result: Data

	if safe then
		local ok, length = pcall(readLen, b, offset)

		if not ok then
			return result, offset
		end

		result = table.create(length) :: Data
		offset += schema.sizeLen :: number

		for i = 1, length do
			local success, key, pos = pcall(readK, b, offset, safe)

			if not success then
				break
			end

			local value
			success, value, pos = pcall(readV, b, pos, safe)

			if not success then
				break
			end

			result[key], offset = value, pos
		end
	else
		local length = readLen(b, offset)
		offset += schema.sizeLen :: number
		result = table.create(length) :: Data

		for i = 1, length do
			local key
			key, offset = readK(b, offset)
			result[key], offset = readV(b, offset)
		end
	end

	return result, offset
end

--- Serializes a table. Returns a new buffer or the next write offset if a buffer is provided.
function Z.ser(schema: Schema, obj: any, b: buffer?, offset: number?, maxSize: number?): (buffer? | number?, string?)
	local shouldReturnOffset = b
	b = b or Z.BUFFER
	offset = offset or 0

	local ok, result = pcall(schema.write :: any, b, offset, obj)

	if not ok then
		if schema.isList or schema.isMap or schema.name ~= "Schema" then
			return nil, result
		end

		for _, field in schema.fields do
			local value = obj[field.key]

			if value == nil then
				return nil, `Missing field "{field.key}"`
			end

			local success, writeResult = pcall(field.write :: any, b, offset, value)

			if success then
				offset = writeResult
			else
				local isZKey = isZType(field.key)
				local name = if isZKey then (field.key :: any).name else field.key

				if isZKey then
					if name == "Schema" then
						return nil, writeResult
					end

					return nil, `Failed to serialize field '[Z.{name}] = Z.{field.type}': {writeResult}`
				end

				return nil, `Failed to serialize field '["{name}"] = Z.{field.type}': {writeResult}`
			end
		end

		return nil, result
	elseif shouldReturnOffset then
		return result, nil
	elseif maxSize then
		local length = math.min(result, maxSize)
		local new = buffer.create(length)
		buffer.copy(new, 0, Z.BUFFER, 0, length)

		return new, nil
	end

	local new = buffer.create(result)
	buffer.copy(new, 0, Z.BUFFER, 0, result)

	return new, nil
end

--- Deserializes a buffer into a table. The `safe` flag suppresses errors from incomplete data.
function Z.des(schema: Schema | ZType, b: buffer, offset: number?, safe: boolean?): (Data, number)
	return (schema.read :: any)(b, offset or 0, safe)
end

--- Migrates a buffer to a new schema. When provided, the change function's result will be serialized with the new schema.
function Z.migrate(old: Schema, new: Schema, b: buffer, change: ((Data) -> Data)?): ((buffer | number)?, string?)
	local data, offset = Z.des(old, b, 0, true)
	if offset ~= buffer.len(b) then
		return nil, `Incomplete data: {offset} bytes read, {buffer.len(b)} bytes expected`
	end

	return Z.ser(new, if change then change(data) else data) :: any
end

local function sortByKey(a: Field, b: Field): boolean
	return (a.key :: string) < (b.key :: string)
end

--- Creates a schema for serialization.
function Z.schema(definition: SchemaDefinition, bits: number?): Schema
	local fields: { Field } = {}
	local isList = #definition == 1
	local firstKey = next(definition)
	local isMap = isZType(firstKey)

	local maxItems, readLen, writeLen
	if isList or isMap then
		maxItems = 2 ^ (bits or 32) - 1
		if bits == 8 then
			readLen, writeLen = buffer.readu8, buffer.writeu8
		elseif bits == 16 then
			readLen, writeLen = buffer.readu16, buffer.writeu16
		elseif bits == 32 or bits == nil then
			readLen, writeLen = buffer.readu32, buffer.writeu32
		else
			error(`Expected 8, 16, or 32 for parameter "bits", got {bits}`)
		end
	end

	for key, value in next, definition do
		if isList and key ~= 1 then
			error(`Expected \{ Z.{definition[1]} } for list schema, got field "{key}"`)
		elseif isMap then
			if key ~= firstKey then
				error(
					`Expected \{ [Z.{(key :: any).name}] = Z.{(value :: any).name} } for map schema, got field "{key}"`
				)
			end
		elseif type(key) ~= "string" and type(key) ~= "number" then
			error(`Expected "string" or "number" for field "{tostring(key)}", got "{typeof(key)}"`)
		end

		if not isZType(value) then
			error(`Expected "ZType" for field "{tostring(key)}", got incompatible "{typeof(key)}"`)
		end

		table.insert(fields :: any, {
			key = key,
			read = value.read,
			write = value.write,
			type = (value :: any).name,
		})
	end

	if #fields == 0 then
		error(`Empty schema`)
	end

	table.sort(fields, sortByKey)

	local keys = table.create(#fields)
	local reads = table.create(#fields)
	local writes = table.create(#fields)

	for i, field in fields do
		keys[i] = field.key
		reads[i] = field.read
		writes[i] = field.write
	end

	local deserialize: any = if isList then deserializeList elseif isMap then deserializeMap else deserialize
	local serialize: any = if isList then serializeListUnsafe elseif isMap then serializeMapUnsafe else serializeUnsafe

	local schema
	schema = table.freeze({
		count = #fields,
		fields = fields,
		keys = keys,
		reads = reads,
		writes = writes,
		name = "Schema",
		read = function(b: buffer, offset: number, safe: boolean?): (Data, number)
			return deserialize(schema, b, offset, safe)
		end,
		write = function(b: buffer, offset: number, value: any)
			if type(value) == "buffer" then
				buffer.copy(b, offset, value)
				return offset + buffer.len(value)
			end

			return serialize(schema, value, b, offset)
		end,

		isList = isList,
		isMap = isMap,
		maxItems = maxItems,
		readLen = readLen,
		writeLen = writeLen,
		sizeLen = math.ceil((bits or 32) / 8),
	})

	return schema :: Schema
end

--- Creates a schema with a 8-bit item limit, if it's a list or map schema.
Z.schema8 = function(definition: SchemaDefinition): Schema
	return (Z :: any).schema(definition, 8) :: Schema
end

--- Creates a schema with a 16-bit item limit, if it's a list or map schema.
Z.schema16 = function(definition: SchemaDefinition): Schema
	return (Z :: any).schema(definition, 16) :: Schema
end

--- Creates a schema with a 32-bit item limit, if it's a list or map schema.
Z.schema32 = function(definition: SchemaDefinition): Schema
	return (Z :: any).schema(definition, 32) :: Schema
end

return Z
