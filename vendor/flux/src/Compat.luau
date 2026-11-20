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
	requireRoblox: (name: string) -> (),
	robloxStubs: (prefix: string, names: { string }) -> { [string]: any },
	services: { [string]: any },
	Instance: any,
	Color3: typeof(Color3),
	UDim: typeof(UDim),
	UDim2: typeof(UDim2),
	Vector2: typeof(Vector2),
	Vector3: typeof(Vector3),
	CFrame: typeof(CFrame),
	Rect: typeof(Rect),
	NumberRange: typeof(NumberRange),
	Font: typeof(Font),
	TweenInfo: typeof(TweenInfo),
	Enum: typeof(Enum),
	ColorSequence: typeof(ColorSequence),
	ColorSequenceKeypoint: typeof(ColorSequenceKeypoint),
	NumberSequence: typeof(NumberSequence),
	NumberSequenceKeypoint: typeof(NumberSequenceKeypoint),
}

local rawWarn: (...any) -> () = warn or print
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
	spawn = Clock._internal.spawn,
	defer = Clock.defer,
	delay = Clock.delay,
	wait = Clock.wait,
	cancel = Clock.cancel,
})

local Compat: any = {
	isRoblox = IS_ROBLOX,
	traceback = traceback,
	warn = warn,
	setWarnHook = setWarnHook,
	task = compatTask,
	clock = Clock.now,
	typeof = typeof,
	services = if IS_ROBLOX
		then setmetatable({}, {
			__index = function(self: { [string]: any }, name: string): any
				local getService: (DataModel, string) -> Instance = game.GetService
				local ok, service = pcall(getService, game, name)
				if ok and service ~= nil then
					self[name] = service
					return service
				end
				return nil
			end,
		})
		else {} :: { [string]: any },
	Instance = if IS_ROBLOX then Instance else nil,
	Color3 = Color3,
	UDim = UDim,
	UDim2 = UDim2,
	Vector2 = Vector2,
	Vector3 = Vector3,
	CFrame = CFrame,
	Rect = Rect,
	NumberRange = NumberRange,
	Font = Font,
	TweenInfo = TweenInfo,
	Enum = Enum,
	ColorSequence = ColorSequence,
	ColorSequenceKeypoint = ColorSequenceKeypoint,
	NumberSequence = NumberSequence,
	NumberSequenceKeypoint = NumberSequenceKeypoint,
}

function Compat.getService(name: string): any
	return Compat.services[name]
end

function Compat.requireRoblox(name: string)
	if Compat.Instance == nil then
		error(`{name} requires a Roblox environment`, 3)
	end
end

function Compat.robloxStubs(prefix: string, names: { string }): { [string]: any }
	local stubs: { [string]: any } = {}
	for _, name in names do
		local message = `{prefix}.{name} requires a Roblox environment`
		stubs[name] = function()
			error(message, 2)
		end
	end
	return table.freeze(stubs)
end

if IS_ROBLOX then
	table.freeze(Compat)
end

return Compat :: Compat
