local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local TextService = game:GetService("TextService")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")

local Package = script.Parent.Parent

local Flux = require(Package:WaitForChild("Flux"))

type Dict<T> = { [T]: any }
type Symbol = { type: "Symbol" }

local playerGui = Players.LocalPlayer and Players.LocalPlayer:WaitForChild("PlayerGui")

--- @class UI
local UI = { Class = {} }
UI.__index = UI
setmetatable(UI, {
	__index = Flux,
	__call = function(_, obj: any, propertyName: string?)
		return Flux(obj, propertyName)
	end,
})

UI.Fonts = require(script.Fonts)
UI.Theme = require(script.Theme)
UI.Themes = UI.Theme.Themes
UI.Sound = {}

local SoundGroup = Flux.new "SoundGroup" {
	Parent = SoundService,
	Name = "_KASounds",
	Volume = function()
		return if UI.Theme.SoundEnabled() then UI.Theme.Volume() else 0
	end,
}

for key, soundIdState in UI.Theme.Sound do
	UI.Sound[key] = Flux.new "Sound" {
		Name = key,
		Parent = SoundGroup,
		SoundId = soundIdState,
		SoundGroup = SoundGroup,
	}
end

UI.Haptic = {
	Click = Flux.new "HapticEffect" {
		Parent = workspace,
		Type = Enum.HapticEffectType.Custom,
		function(self)
			self:SetWaveformKeys({
				FloatCurveKey.new(0, 0.1, Enum.KeyInterpolationMode.Constant),
				FloatCurveKey.new(1, 0, Enum.KeyInterpolationMode.Constant),
			})
		end,
	},
	Hover = Flux.new "HapticEffect" {
		Parent = workspace,
		Type = Enum.HapticEffectType.UIHover,
	},
	Notification = Flux.new "HapticEffect" {
		Parent = workspace,
		Type = Enum.HapticEffectType.UINotification,
	},
}

function UI.getFontName(font: Font | Enum.Font)
	if typeof(font) == "Font" then
		local id = string.match(font.Family, "%d+$")
		if id then
			return UI.Fonts[id]
		else
			return string.match(font.Family, "/([^/]+)%.json$")
		end
	else
		return font.Name
	end
end

UI.GuiService = GuiService
UI.TextService = TextService
UI.UserInputService = UserInputService
UI.LocalPlayer = Players.LocalPlayer
UI.PlayerGui = playerGui

export type Platform = "Console" | "Mobile" | "PC" | "VR"

UI.Touch = UserInputService.TouchEnabled
UI.IsConsoleScreen = GuiService:IsTenFootInterface()

UI.Platform = (
	if UserInputService.VREnabled
		then "VR"
		elseif UI.IsConsoleScreen then "Console"
		elseif UserInputService.KeyboardEnabled and UserInputService.MouseEnabled then "PC"
		else "Mobile"
) :: Platform

--- A marker for defining UI state hooks in [UI.edit]
UI.Hook = table.freeze({ type = "Symbol" }) :: Symbol

--- A marker for defining function defaultState in [UI.makeStatefulDefaults]
UI.Function = table.freeze({ type = "Symbol" }) :: Symbol

--- A marker for defining Nil defaultState in [UI.makeStatefulDefaults]
UI.Nil = table.freeze({ type = "Symbol" }) :: Symbol

--- GuiService.TopbarInset as a Flux state
UI.TopbarInset = Flux.property(GuiService, "TopbarInset")
UI.TopbarPadding = Flux.computed(function()
	local offset = UI.IsConsoleScreen and 10 or (UI.TopbarInset().Height - 46)
	return UDim.new(0, offset)
end)

--- The lowermost ScreenGui for UI components
UI.LayerBottom = Flux.new "ScreenGui" {
	Parent = playerGui,
	Name = "FluxUILayerBottom",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	ScreenInsets = Enum.ScreenInsets.None,
}

--- The default ScreenGui for UI components
UI.LayerDefault = Flux.new "ScreenGui" {
	Parent = playerGui,
	Name = "FluxUILayerDefault",
	DisplayOrder = 2,
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	ScreenInsets = Enum.ScreenInsets.None,
}

--- The topmost ScreenGui for UI components
UI.LayerTop = Flux.new "ScreenGui" {
	Parent = playerGui,
	Name = "FluxUILayerTop",
	DisplayOrder = 999999999,
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	ScreenInsets = Enum.ScreenInsets.None,
}

UI.LayerTopInset = UI.new "Frame" {
	Name = "TopbarInset",
	Parent = UI.LayerTop,
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.fromScale(0, 1),
	Size = if UI.IsConsoleScreen
		then UDim2.new(1, 0, 1, -54)
		else function()
			return UDim2.new(1, 0, 1, -UI.TopbarInset().Height)
		end,
}

--- The Topbar ScreenGui for UI components
UI.LayerTopbar = Flux.new "ScreenGui" {
	Parent = playerGui,
	Name = "FluxUILayerTopbar",
	DisplayOrder = 999999999,
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	ScreenInsets = Enum.ScreenInsets.TopbarSafeInsets,
}

--- A sorted Topbar Frame for UI components, parented under [UI.LayerTopbar]
UI.TopbarFrame = UI.new "Frame" {
	Parent = UI.LayerTopbar,
	BackgroundTransparency = 1,
	Position = UDim2.new(0, 0, 0, if UI.IsConsoleScreen then 4 else 0),
	Size = function()
		return UDim2.new(1, 0, 0, UI.TopbarInset().Height + if UI.IsConsoleScreen then 50 else 0)
	end,
	Visible = function()
		return UI.IsConsoleScreen or UI.TopbarInset().Height > 0
	end,

	UI.list {
		direction = "x",
		verticalAlign = "end",
		gap = UI.TopbarPadding,
	},
	UI.padding {
		left = if UI.IsConsoleScreen
			then UDim.new(0, 10)
			else function()
				return UDim.new(0, 2 + UI.TopbarPadding().Offset / 2)
			end,
		right = UI.TopbarPadding,
		top = if UI.IsConsoleScreen then UDim.new(0, 6) else UI.TopbarPadding,
		bottom = UDim.new(0, if UI.IsConsoleScreen then 0 else 2),
	},
}

export type ActiveStateType = "hover" | "floating" | "dialog"

UI._activeState = {}

--- A generalized function to handle activation/deactivation of both floating and hover states
function UI.activateState(activeState: any, stateType: ActiveStateType)
	if not Flux.isNode(activeState) then
		error("Invalid active state")
	end

	-- Clear the previous state if it's different
	local previousState = UI._activeState[stateType]
	if previousState and previousState ~= activeState then
		previousState(false)
	end

	-- Set the new active state
	UI._activeState[stateType] = activeState

	local state: any = activeState
	state(true)
	if not Flux.isReactive() then
		Flux.flush()
	end
end

--- A generalized function to deactivate both floating and hover states
function UI.deactivateState(activeState: any, stateType: ActiveStateType)
	if not Flux.isNode(activeState) then
		error("Invalid active state")
	end

	-- Clear the previous state if it matches
	local previousState = UI._activeState[stateType]
	if previousState and previousState == activeState then
		UI._activeState[stateType] = nil
	end

	local state: any = activeState
	state(false)
	if not Flux.isReactive() then
		Flux.flush()
	end
end

--- A generalized function to toggle both floating and hover states
function UI.toggleState(activeState: any, stateType: ActiveStateType)
	if not Flux.isNode(activeState) then
		error("Invalid active state")
	end
	if activeState:peek() then
		UI.deactivateState(activeState, stateType)
	else
		UI.activateState(activeState, stateType)
	end
end

--- Function to clear a specific state type
function UI.clearState(stateType: ActiveStateType)
	local activeState = UI._activeState[stateType]
	if Flux.isNode(activeState) then
		activeState(false)
		UI._activeState[stateType] = nil
		if not Flux.isReactive() then
			Flux.flush()
		end
	end
end

--- Function to clear all active state types
function UI.clearActiveStates()
	for stateType in UI._activeState do
		UI.clearState(stateType)
	end
end

--- Gets the luminance of a [Color3]
UI.getLuminance = Flux.Color.luminance

--- Inverts the luminance of a [Color3] by an amount
function UI.invertLuminance(color: Color3, amount: number): Color3
	-- relative luminance is linear, so a 0.5 cutoff would call mid-light colors dark; readable() splits at the
	-- perceptual midpoint
	local isLight = Flux.Color.readable(color) == Color3.new(0, 0, 0)
	return Flux.Color.lighten(color, if isLight then -amount else amount)
end

--- Checks if x, y is within the absolute bounds of the GuiObject
UI.pointInGuiObject = Flux.Interact.pointIn

UI.sinkInput = Flux.Interact.sunk

function UI.retryGetTextBoundsAsync(params)
	local attempt = 1
	local ok, bounds = pcall(TextService.GetTextBoundsAsync, TextService, params)
	while not ok do
		task.wait(2 ^ attempt)
		attempt += 1
		ok, bounds = pcall(TextService.GetTextBoundsAsync, TextService, params)
	end
	return bounds
end

export type TextRequest = { Text: string, Font: Font, Size: number, RichText: boolean? }

local function estimateTextWidth(request: TextRequest): number
	local text = if request.RichText then string.gsub(request.Text, "<[^>]->", "") else request.Text
	return (utf8.len(text) or #text) * request.Size * 0.55
end

--- Measures the widest of `getRequests()` without yielding inside the reactive graph.
--- `getRequests` runs in an effect (its reads are tracked); the returned signal starts at an estimate and settles to
--- the measured width once `TextService:GetTextBoundsAsync` resolves on a deferred thread. Stale measurements are
--- dropped. Never call [UI.retryGetTextBoundsAsync] inside a computed, effect, or reactive property: it yields
--- mid-flush, which stalls Flux and corrupts dependency tracking for every other thread.
--- Returns the width signal and the measuring effect; dispose both with the owning component.
function UI.textWidth(getRequests: () -> { TextRequest }): (Flux.Node<number>, Flux.Node<any>)
	local width = Flux.signal(0)
	local version = 0
	local measure = Flux.effect(function()
		local requests = getRequests()
		version += 1
		local current = version
		if width:peek() == 0 then
			local estimate = 0
			for _, request in requests do
				estimate = math.max(estimate, estimateTextWidth(request))
			end
			width:set(math.ceil(estimate))
		end
		task.defer(function()
			if current ~= version then
				return
			end
			local params = Instance.new("GetTextBoundsParams")
			params.Width = math.huge
			local maxWidth = 0
			for _, request in requests do
				params.Text = request.Text
				params.Font = request.Font
				params.Size = request.Size
				params.RichText = request.RichText == true
				maxWidth = math.max(maxWidth, UI.retryGetTextBoundsAsync(params).X)
				if current ~= version then
					return
				end
			end
			width:set(math.ceil(maxWidth))
			if not Flux.isReactive() then
				Flux.flush()
			end
		end)
	end)
	measure:onDestroy(function()
		version += 1
	end)
	measure:get()
	return width, measure
end

--- Helper function for defining Flux state defaults
function UI.makeStatefulDefaults(default: Dict<any>, definition: Dict<any>?)
	local createdNodes = {}
	for key, value in default do
		if definition then
			value = if definition[key] ~= nil then definition[key] else value
		end
		if typeof(value) == "function" and default[key] ~= UI.Function then
			local fn = value
			value = Flux.computed(function()
				return fn()
			end)
			table.insert(createdNodes, value)
		end
		if value == UI.Nil or value == UI.Function then
			default[key] = nil
			continue
		end
		if not Flux.isNode(value) then
			value = Flux.signal(value)
			table.insert(createdNodes, value)
		end
		default[key] = value
	end
	default._createdNodes = createdNodes
	return default
end

function UI.newSinkHoverState(object: GuiObject, hovering: any?, options: Flux.HoverOptions?)
	local state = Flux.Interact.hover(object, options)
	local target = hovering or state
	local sync = Flux.effect(function()
		local value = state()
		if target ~= state then
			target(value)
		end
		if value then
			UI.activateState(target, "hover")
		else
			UI.deactivateState(target, "hover")
		end
	end)
	sync:get()
	Flux.edit(object)({ __CLEAN = { state, sync } })
	return target
end

local FIND_SYMBOL = Flux.Find.Child("")({})[1]

local function unwrapChild(child: any): any
	if type(child) == "table" then
		if child._instance then
			return child._instance
		elseif not Flux.isNode(child) and not table.isfrozen(child) and child[1] ~= FIND_SYMBOL then
			for k, v in child do
				if type(k) == "number" then
					child[k] = unwrapChild(v)
				end
			end
		end
	end
	return child
end

--- Inherits [Flux.edit]
--- * Parents children to the ._content variable of a UI component if one exists
--- * Unwraps UI component children and auto-numbers [GuiObject.LayoutOrder] sequentially via [Flux.edit]
--- * Allows UI.Hook to easily hook to default UI state or [RBXScriptSignal] aliases
function UI.edit(new: Instance | Dict<any>)
	return function(properties: Dict<any>): Instance | Dict<any>
		properties = properties :: Dict<any> & GuiObject

		local instance = new
		local contentParent = instance
		local cleanup = {}

		if type(new) == "table" then
			instance = new._instance
			contentParent = new._content or new._instance
		end

		local contentChildren
		for index, child in properties do
			if type(index) ~= "number" or index ~= math.floor(index :: number) then
				continue
			end
			child = unwrapChild(child)
			-- actions run on the component root as they did in 0.2, only children move to the content frame
			if contentParent ~= instance and type(child) ~= "function" then
				if not contentChildren then
					contentChildren = {}
				end
				contentChildren[index] = child
				properties[index] = nil
			else
				properties[index] = child
			end
		end

		if type(new) == "table" then
			local hooks = properties[UI.Hook]
			properties[UI.Hook] = nil
			if hooks then
				for key, hook in hooks do
					local classMember = new[key]
					if not Flux.isNode(classMember) then
						error(`Invalid UI State Hook {key}`)
					end
					if type(hook) == "function" then
						local eff = Flux.effect(Flux.on(classMember, hook, true))
						eff:get()
						table.insert(cleanup, eff)
					end
				end
			end
			for key, value in properties do
				if type(key) ~= "string" then
					continue
				end
				local classMember = new[key]
				if classMember == nil then
					continue
				end
				properties[key] = nil -- strip class members
				-- connect alias signals
				if typeof(classMember) == "RBXScriptSignal" then
					table.insert(cleanup, classMember:Connect(value))
				end
			end
		end

		if properties.__CLEAN and (type(properties.__CLEAN) ~= "table" or Flux.isNode(properties.__CLEAN)) then
			properties.__CLEAN = { properties.__CLEAN }
		end
		if #cleanup > 0 then
			if not properties.__CLEAN then
				properties.__CLEAN = cleanup
			else
				for _, v in cleanup do
					table.insert(properties.__CLEAN, v)
				end
			end
		end

		local parent = properties.Parent
		if parent and type(parent) == "table" and not Flux.isNode(parent) then
			properties.Parent = parent._content or parent._instance
		end
		-- apply non class members to the root instance with Flux.edit
		Flux.edit(instance)(properties)
		if contentChildren then
			Flux.edit(contentParent)(contentChildren)
		end
		if not Flux.isReactive() then
			Flux.flush()
		end
		return new
	end
end

local defaultProperties = {
	ImageButton = {
		HoverHapticEffect = UI.Haptic.Hover,
		PressHapticEffect = UI.Haptic.Click,
	},
	TextButton = {
		HoverHapticEffect = UI.Haptic.Hover,
		PressHapticEffect = UI.Haptic.Click,
	},
}
for className, defaults in defaultProperties do
	if Flux.Defaults[className] then
		for k, v in defaults do
			Flux.Defaults[className][k] = v
		end
	else
		Flux.Defaults[className] = defaults
	end
end

local constructors: { [string]: () -> Instance } = {}
setmetatable(constructors, {
	__index = function(self, className: string)
		local class = UI.Class[className]
		local new

		if class then
			new = function(properties: Dict<any>): Instance | Dict<any>
				local obj = class.new(properties)
				if obj._instance and obj._createdNodes and #obj._createdNodes > 0 then
					Flux.edit(obj._instance)({ __CLEAN = obj._createdNodes })
				end
				return UI.edit(obj)(properties)
			end
		else
			local construct = Flux.new(className)
			new = function(properties: Dict<any>): Instance | Dict<any>
				for index, child in properties do
					if type(index) == "number" and index == math.floor(index) then
						child = unwrapChild(child)
						properties[index] = child
						if typeof(child) == "Instance" and child:IsA("GuiObject") and child.LayoutOrder == 0 then
							child.LayoutOrder = index
						end
					end
				end
				local parent = properties.Parent
				if parent and type(parent) == "table" and not Flux.isNode(parent) then
					properties.Parent = parent._content or parent._instance
				end
				local instance = construct(properties)
				if not Flux.isReactive() then
					Flux.flush()
				end
				return instance
			end
		end

		self[className] = new
		return new
	end,
})

type Constructor = typeof(Flux.new) & ((className: string) -> (Dict<any>) -> Dict<any>)

--- Creates a new Instance with [UI.edit]
local function createInstance(className: string)
	return constructors[className]
end
UI.new = (createInstance :: unknown) :: Constructor

--- Registers a new UI component class
function UI.register(className: string, class: Dict<any>)
	if UI.Class[className] then
		error(`UI class "{className}" already exists`)
	end
	UI.Class[className] = class
end

--- Run to register the default classes for the UI module
function UI.registerClasses(): typeof(UI)
	UI.registerClasses = (nil :: unknown) :: typeof(UI.registerClasses)
	for _, child in script.Classes:GetChildren() do
		if child:IsA("ModuleScript") then
			UI.register(child.Name, require(child))
		end
	end
	return UI
end

return UI
