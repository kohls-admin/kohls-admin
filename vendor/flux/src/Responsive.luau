--!strict
--[[
The screen and the player as shared nodes: viewport, UI scale, breakpoint, input device and accessibility settings.
Available as `Flux.Responsive`. For safe areas (the topbar, notches, rounded corners), set the engine's
`ScreenGui.ScreenInsets` (`CoreUISafeInsets` or `DeviceSafeInsets`) and `ScreenGui.SafeAreaCompatibility` instead.

```luau
Flux.new "UIScale" { Scale = Flux.Responsive.scale }
```
]]

local Compat = require("./Compat")
local Graph = require("./Graph")

local getService = Compat.getService
local warn = Compat.warn

local computed = Graph.computed
local read = Graph.read
local signal = Graph.signal

export type ScaleMode = "min" | "width" | "height" | "max"
export type Breakpoint = "phone" | "tablet" | "desktop"
export type Platform = "console" | "mobile" | "pc" | "vr"
export type DisplaySize = "Small" | "Medium" | "Large"
export type Input = "keyboard" | "touch" | "gamepad"
export type TextSize = "Medium" | "Large" | "Larger" | "Largest"
export type Breakpoints = { phone: number, tablet: number }

export type Config = {
	reference: Vector2,
	mode: ScaleMode,
	min: number?,
	max: number?,
	breakpoints: Breakpoints,
}

export type PartialConfig = {
	reference: Vector2?,
	mode: ScaleMode?,
	min: number?,
	max: number?,
	breakpoints: Breakpoints?,
	viewport: Graph.Reactive<Vector2>?,
}

local DEFAULT_SIZE = Compat.Vector2.new(1920, 1080)

--[[
Live defaults shared by every derived node; mutate once at startup.

[Open Documentation](https://flux.kohl.gg/guide/utilities/responsive#configuration)
]]
local config: Config = {
	reference = DEFAULT_SIZE,
	mode = "min",
	breakpoints = { phone = 600, tablet = 1024 },
}

local EMPTY: PartialConfig = {}
local warnedModes: { [string]: boolean } = {}

local function scaleFor(width: number, height: number, partial: PartialConfig): number
	local ref = partial.reference or config.reference
	local refX, refY = math.max(ref.X, 1), math.max(ref.Y, 1)
	local mode = partial.mode or config.mode

	local factor: number
	if mode == "width" then
		factor = width / refX
	elseif mode == "height" then
		factor = height / refY
	elseif mode == "max" then
		factor = math.max(width / refX, height / refY)
	else
		if mode ~= "min" then
			local key = tostring(mode)
			if not warnedModes[key] then
				warnedModes[key] = true
				warn(`[Flux] unknown scale mode "{mode}"; falling back to "min"`)
			end
		end
		factor = math.min(width / refX, height / refY)
	end

	local min = if partial.min ~= nil then partial.min else config.min
	if min ~= nil and factor < min then
		factor = min
	end
	local max = if partial.max ~= nil then partial.max else config.max
	if max ~= nil and factor > max then
		factor = max
	end

	return factor
end

local function breakpointFor(width: number, partial: PartialConfig): Breakpoint
	local breakpoints = partial.breakpoints or config.breakpoints
	if width < breakpoints.phone then
		return "phone"
	elseif width < breakpoints.tablet then
		return "tablet"
	end
	return "desktop"
end

--[[
The active camera's `ViewportSize` as a node, live on the client.

[Open Documentation](https://flux.kohl.gg/guide/utilities/responsive#viewport)
]]
local viewport: Graph.Node<Vector2> = signal(DEFAULT_SIZE)

--[[
Factory escape hatch: a `scale` node with per-surface config (merged over defaults).

[Open Documentation](https://flux.kohl.gg/guide/utilities/responsive#per-surface-overrides)
]]
local function scaleOf(partial: PartialConfig?): Graph.Node<number>
	local cfg = partial or EMPTY
	local source = cfg.viewport or viewport
	return computed(function(): number
		local vp = read(source) :: Vector2
		return scaleFor(vp.X, vp.Y, cfg)
	end)
end

--[[
Factory escape hatch: a `breakpoint` node with per-surface thresholds.

[Open Documentation](https://flux.kohl.gg/guide/utilities/responsive#per-surface-overrides)
]]
local function breakpointOf(partial: PartialConfig?): Graph.Node<Breakpoint>
	local cfg = partial or EMPTY
	local source = cfg.viewport or viewport
	return computed(function(): Breakpoint
		local vp = read(source) :: Vector2
		return breakpointFor(vp.X, cfg)
	end)
end

--[[
UIScale factor derived from `viewport`; `1.0` at `config.reference`.

[Open Documentation](https://flux.kohl.gg/guide/utilities/responsive#scale)
]]
local scale: Graph.Node<number> = scaleOf()
--[[
Size class derived from `viewport` width.

[Open Documentation](https://flux.kohl.gg/guide/utilities/responsive#breakpoint)
]]
local breakpoint: Graph.Node<Breakpoint> = breakpointOf()

local RunService = getService("RunService")
local isClient = RunService ~= nil and RunService:IsClient() and RunService:IsRunning()
local GuiService = isClient and getService("GuiService")
local UserInputService = isClient and getService("UserInputService")
local VRService = isClient and getService("VRService")
local tenFoot = isClient and GuiService:IsTenFootInterface()

local function detectPlatform(): Platform
	return if VRService.VREnabled
		then "vr"
		elseif tenFoot then "console"
		elseif UserInputService.KeyboardEnabled and UserInputService.MouseEnabled then "pc"
		else "mobile"
end

--[[
The device class: `"vr"`, `"console"` (ten-foot interface), `"pc"` (keyboard and mouse), or `"mobile"`. Live on
the client, so plugging in a keyboard and mouse or putting on a headset changes it; `"pc"` elsewhere.

[Open Documentation](https://flux.kohl.gg/guide/utilities/responsive#platform)
]]
local platform: Graph.Node<Platform> = signal((if isClient then detectPlatform() else "pc") :: Platform)
--[[
How large the screen is physically (`GuiService.ViewportDisplaySize`): `"Small"` (phones, tablets, handhelds),
`"Medium"` (laptops and monitors, the default) or `"Large"` (TVs). Live on the client; where the engine lacks the
property, a ten-foot interface counts as `"Large"`.

[Open Documentation](https://flux.kohl.gg/guide/utilities/responsive#display-size)
]]
local displaySize: Graph.Node<DisplaySize> = signal((if tenFoot then "Large" else "Medium") :: DisplaySize)

local INPUT_BY_NAME: { [string]: Input } = {
	KeyboardAndMouse = "keyboard",
	Keyboard = "keyboard",
	MouseMovement = "keyboard",
	MouseButton1 = "keyboard",
	MouseButton2 = "keyboard",
	MouseButton3 = "keyboard",
	MouseWheel = "keyboard",
	Touch = "touch",
	Gamepad = "gamepad",
}
for slot = 1, 8 do
	INPUT_BY_NAME[`Gamepad{slot}`] = "gamepad"
end

local function inputFor(name: string): Input?
	return INPUT_BY_NAME[name]
end

local INPUT_BY_PLATFORM: { [Platform]: Input } = {
	pc = "keyboard",
	mobile = "touch",
	console = "gamepad",
	vr = "gamepad",
}

--[[
The input the player is using right now: `"keyboard"` (keyboard and mouse), `"touch"`, or `"gamepad"`. Follows
`UserInputService.PreferredInput` live on the client, so picking up a controller switches it; elsewhere it holds
the mode matching `platform`.

[Open Documentation](https://flux.kohl.gg/guide/utilities/responsive#input)
]]
local input: Graph.Node<Input> = signal(INPUT_BY_PLATFORM[platform:peek()] :: Input)
--[[
The player's preferred text size (`GuiService.PreferredTextSize`): `"Medium"` (default), `"Large"`, `"Larger"`, or
`"Largest"`. The engine already draws text larger to match, so use it to make room around text, never to
multiply `TextSize` again.

[Open Documentation](https://flux.kohl.gg/guide/utilities/responsive#text-size)
]]
local textSize: Graph.Node<TextSize> = signal("Medium" :: TextSize)
--[[
Whether the player asked for reduced motion (`GuiService.ReducedMotionEnabled`). When `true`, swap movement and
scaling animations for instant changes or simple fades.

[Open Documentation](https://flux.kohl.gg/guide/utilities/responsive#reduced-motion)
]]
local reducedMotion: Graph.Node<boolean> = signal(false)
--[[
The player's background transparency preference (`GuiService.PreferredTransparency`), from `0` (opaque
backgrounds) to `1` (the default). Multiply translucent `BackgroundTransparency` values by it.

[Open Documentation](https://flux.kohl.gg/guide/utilities/responsive#preferred-transparency)
]]
local preferredTransparency: Graph.Node<number> = signal(1)

if isClient then
	local Workspace = getService("Workspace")

	local viewportConnection: RBXScriptConnection?
	local function bindCamera(camera: Camera?)
		if viewportConnection ~= nil then
			viewportConnection:Disconnect()
			viewportConnection = nil
		end
		if camera ~= nil then
			viewport:set(camera.ViewportSize)
			viewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
				viewport:set(camera.ViewportSize)
			end)
		end
	end

	local serviceConnections: { RBXScriptConnection } = {}
	bindCamera(Workspace.CurrentCamera)
	local cameraConn: RBXScriptConnection = Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		bindCamera(Workspace.CurrentCamera)
	end)
	table.insert(serviceConnections, cameraConn)
	local function mirror(
		object: Instance,
		property: string,
		node: Graph.Node<any>,
		map: ((value: any) -> any)?
	): boolean
		local ok, changed = pcall(object.GetPropertyChangedSignal, object, property)
		if not ok then
			return false
		end
		local rawObject: any = object
		local function sync()
			local rawValue = rawObject[property]
			local value = if map then map(rawValue) else rawValue
			if value ~= nil then
				node:set(value)
			end
		end
		sync()
		local conn: RBXScriptConnection = changed:Connect(sync)
		table.insert(serviceConnections, conn)
		return true
	end

	local function nameOf(item: EnumItem): string
		return item.Name
	end
	local function inputOf(item: EnumItem): Input?
		local name = item.Name
		return inputFor(name)
	end
	local function syncPlatform()
		platform:set(detectPlatform())
	end
	local function bindPlatform(object: Instance, property: string)
		local ok, changed = pcall(object.GetPropertyChangedSignal, object, property)
		if ok then
			local conn: RBXScriptConnection = changed:Connect(syncPlatform)
			table.insert(serviceConnections, conn)
		end
	end

	if not mirror(UserInputService, "PreferredInput", input, inputOf) then
		local conn: RBXScriptConnection = UserInputService.LastInputTypeChanged:Connect(
			function(lastInputType: Enum.UserInputType)
				local mode = inputFor(lastInputType.Name)
				if mode ~= nil then
					input:set(mode)
				end
			end
		)
		table.insert(serviceConnections, conn)
	end
	mirror(GuiService, "PreferredTextSize", textSize, nameOf)
	mirror(GuiService, "ViewportDisplaySize", displaySize, nameOf)
	bindPlatform(UserInputService, "KeyboardEnabled")
	bindPlatform(UserInputService, "MouseEnabled")
	bindPlatform(VRService, "VREnabled")
	mirror(GuiService, "ReducedMotionEnabled", reducedMotion)
	mirror(GuiService, "PreferredTransparency", preferredTransparency)
end

return table.freeze({
	config = config,
	platform = platform,

	viewport = viewport,
	scale = scale,
	breakpoint = breakpoint,
	displaySize = displaySize,

	input = input,
	textSize = textSize,
	reducedMotion = reducedMotion,
	preferredTransparency = preferredTransparency,

	scaleOf = scaleOf,
	breakpointOf = breakpointOf,

	--- @ignore
	_inputFor = inputFor,
})
