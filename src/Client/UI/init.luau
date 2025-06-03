local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local TextService = game:GetService("TextService")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")

local Flux = require(script.Parent.Parent.Flux)
local state = Flux.state

export type Function = Flux.Function
export type List<T> = Flux.List<T>
export type Set<T> = Flux.Set<T>
export type Dict<T> = Flux.Dict<T>
export type State<T> = Flux.State<T>
export type Stateful<T> = Flux.Stateful<T>
export type SpecialKey = Flux.SpecialKey
export type SpecialDefinition = Flux.SpecialDefinition

local playerGui = Players.LocalPlayer and Players.LocalPlayer:WaitForChild("PlayerGui")

-- TODO: allow a way to easily override builtin theme binds with a new compute or whatever!

--- @class UI
local UI = { Class = {} }
UI.__index = UI
setmetatable(UI, Flux)

UI.Theme = require(script.Theme)
UI.Sound = {}

local SoundGroup = Instance.new("SoundGroup")
SoundGroup.Name = "_KASounds"
SoundGroup.Parent = SoundService

Flux.edit(SoundGroup, {
	Volume = Flux.compute(function(use)
		return if use(UI.Theme.SoundEnabled) then use(UI.Theme.Volume) else 0
	end),
})

for key, soundIdState in UI.Theme.Sound do
	UI.Sound[key] = Flux.new "Sound" {
		Name = key,
		Parent = SoundGroup,
		SoundId = soundIdState,
		SoundGroup = SoundGroup,
	}
end

--- @within UI
--- @prop GuiService GuiService
UI.GuiService = GuiService

--- @within UI
--- @prop TextService TextService
UI.TextService = TextService

--- @within UI
--- @prop UserInputService UserInputService
UI.UserInputService = UserInputService

--- @within UI
--- @prop PlayerGui PlayerGui
UI.PlayerGui = playerGui

--- @within UI
--- @type Platform "Console" | "Mobile" | "PC"
export type Platform = "Console" | "Mobile" | "PC"

--- @within UI
--- @prop Touch boolean
UI.Touch = UI.UserInputService.TouchEnabled

--- @within UI
--- @prop Platform Platform
UI.Platform = if UI.UserInputService.KeyboardEnabled and UI.UserInputService.MouseEnabled
	then "PC"
	elseif UI.UserInputService.GamepadEnabled then "Console"
	else "Mobile"

--- @within UI
--- A marker for defining Instance attributes in [UI.edit]
--- @prop Attribute newproxy
--- @readonly

--- @within UI
--- A marker for defining Instance children in [UI.edit]
--- @prop Children newproxy
--- @readonly

--- @within UI
--- Markers for defining events in [UI.edit]
--- @prop Event { Attribute = newproxy, Property = newproxy }
--- @readonly

--- @within UI
--- A marker for defining UI state hooks in [UI.edit]
--- @prop Hook newproxy
--- @readonly
UI.Hook = newproxy()

--- @within UI
--- A marker for defining Nil defaultState in [UI.makeStatefulDefaults]
--- @prop Nil newproxy
--- @readonly
UI.Nil = newproxy()

--- @within UI
--- GuiService.TopbarInset as a Flux state
--- @prop TopbarInset State<Rect>
UI.TopbarInset = state(GuiService, "TopbarInset")
UI.TopbarPadding = Flux.compute(function(use)
	return UDim.new(0, if GuiService:IsTenFootInterface() then 10 else use(UI.TopbarInset).Height - 46)
end)

--- @within UI
--- The lowermost ScreenGui for UI components
--- @prop LayerBottom State<ScreenGui>
UI.LayerBottom = Flux.new "ScreenGui" {
	Parent = playerGui,
	Name = "FluxUILayerBottom",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	ScreenInsets = Enum.ScreenInsets.None,
}

--- @within UI
--- The default ScreenGui for UI components
--- @prop LayerDefault State<ScreenGui>
UI.LayerDefault = Flux.new "ScreenGui" {
	Parent = playerGui,
	Name = "FluxUILayerDefault",
	DisplayOrder = 2,
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	ScreenInsets = Enum.ScreenInsets.None,
}

--- @within UI
--- The topmost ScreenGui for UI components
--- @prop LayerTop State<ScreenGui>
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
	Size = UI.compute(function(use)
		return UDim2.new(1, 0, 1, -use(UI.TopbarInset).Height)
	end),
}

--- @within UI
--- The Topbar ScreenGui for UI components
--- @prop LayerTopbar State<ScreenGui>
UI.LayerTopbar = Flux.new "ScreenGui" {
	Parent = playerGui,
	Name = "FluxUILayerTopbar",
	DisplayOrder = 999999999,
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	ScreenInsets = Enum.ScreenInsets.TopbarSafeInsets,
}

--- @within UI
--- A sorted Topbar Frame for UI components, parented under [UI.LayerTopbar]
--- @prop TopbarFrame State<Frame>
UI.TopbarFrame = UI.new "Frame" {
	Parent = UI.LayerTopbar,
	BackgroundTransparency = 1,
	Size = UDim2.new(1, 0, 1, 0),

	UI.new "UIListLayout" {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		Padding = UI.TopbarPadding,
	},
	UI.new "UIPadding" {
		PaddingLeft = UI.TopbarPadding,
		PaddingRight = UI.TopbarPadding,
		PaddingTop = Flux.compute(function(use)
			return UDim.new(0, use(UI.TopbarPadding).Offset)
		end),
		PaddingBottom = Flux.compute(function(use)
			return UDim.new(0, 2)
		end),
	},
}

-- generic floating/hover edge case handler

UI._activeFloating = nil
UI._activeHover = nil

--- @within UI
--- @type ActiveStateType "hover" | "floating"
export type ActiveStateType = "hover" | "floating"

--- A generalized function to handle activation/deactivation of both floating and hover states
function UI.activateState(activeState: State<boolean>, stateType: ActiveStateType)
	if not Flux.isState(activeState) then
		error("Invalid active state")
	end

	-- Clear the previous state if it's different
	local previousState = stateType == "floating" and UI._activeFloating or UI._activeHover
	if previousState and not rawequal(previousState, activeState) then
		previousState:set(false)
	end

	-- Set the new active state
	if stateType == "floating" then
		UI._activeFloating = activeState
	else
		UI._activeHover = activeState
	end
	activeState:set(true)
end

--- A generalized function to deactivate both floating and hover states
function UI.deactivateState(activeState: State<boolean>, stateType: ActiveStateType)
	if not Flux.isState(activeState) then
		error("Invalid active state")
	end

	-- Clear the previous state if it matches
	local previousState = stateType == "floating" and UI._activeFloating or UI._activeHover
	if previousState and rawequal(previousState, activeState) then
		if stateType == "floating" then
			UI._activeFloating = nil
		else
			UI._activeHover = nil
		end
	end
	activeState:set(false)
end

--- A generalized function to toggle both floating and hover states
function UI.toggleState(activeState: State<boolean>, stateType: ActiveStateType)
	if not Flux.isState(activeState) then
		error("Invalid active state")
	end
	if activeState._value then
		UI.deactivateState(activeState, stateType)
	else
		UI.activateState(activeState, stateType)
	end
end

--- Function to clear a specific state type
function UI.clearState(stateType: ActiveStateType)
	if stateType == "floating" then
		if Flux.isState(UI._activeFloating) then
			UI._activeFloating:set(false)
			UI._activeFloating = nil
		end
	elseif stateType == "hover" then
		if Flux.isState(UI._activeHover) then
			UI._activeHover:set(false)
			UI._activeHover = nil
		end
	else
		error("Invalid state type for clearing")
	end
end

--- Gets the luminance of a [Color3]
function UI.getLuminance(color: Color3): number
	return math.sqrt(0.299 * color.R ^ 2 + 0.587 * color.G ^ 2 + 0.114 * color.B ^ 2)
end

--- Inverts the luminance of a [Color3] by an amount
function UI.invertLuminance(color: Color3, amount: number): Color3
	local rLum = 0.299 * color.R ^ 2
	local gLum = 0.587 * color.G ^ 2
	local bLum = 0.114 * color.B ^ 2

	local originalLuminance = math.sqrt(rLum + gLum + bLum)
	if originalLuminance > 0.5 then -- invert amount if light
		amount = -amount
	end

	local targetRatio = math.clamp(originalLuminance + amount, 0, 1) / originalLuminance
	local newR = math.clamp(math.sqrt(rLum * targetRatio / 0.299), 0, 1)
	local newG = math.clamp(math.sqrt(gLum * targetRatio / 0.587), 0, 1)
	local newB = math.clamp(math.sqrt(bLum * targetRatio / 0.114), 0, 1)

	return Color3.new(newR, newG, newB)
end

--- Checks if x, y is within the absolute bounds of the GuiObject
function UI.pointInGuiObject(x: number, y: number, object: GuiObject)
	local size = object.AbsoluteSize
	local position = object.AbsolutePosition
	return x >= position.X and x <= position.X + size.X and y >= position.Y and y <= position.Y + size.Y
end

--- Helper function for defining Flux state defaults
function UI.makeStatefulDefaults(default: Dict<any>, definition: SpecialDefinition?)
	for key, value in default do
		if definition then
			local valueDef = definition[key]
			value = if valueDef ~= nil then valueDef else value
		end
		if value == UI.Nil then
			default[key] = nil
			continue
		end
		if not Flux.isState(value) then
			value = Flux.state(value)
		end
		default[key] = value
	end
	return default
end

--- Inherits [Flux.edit]
--- * Parents children to the ._content variable of a UI component if one exists
--- * Numeric indicies are defined as children with [GuiObject.LayoutOrder] set to the index
--- * Allows UI.Hook to easily hook to default UI state or [RBXScriptSignal] aliases
--- @param definition SpecialDefinition | GuiObject
function UI.edit(new: Instance | Dict<any>, definition): Instance | Dict<any>
	definition = definition :: SpecialDefinition & GuiObject

	local instance = new
	local contentParent = instance
	local children = definition[UI.Children]
	local parent = definition.Parent
	local cleanup = {}

	if type(new) == "table" then
		instance = new._instance
		contentParent = new._content or new._instance
	end

	if children then
		if typeof(children) ~= "table" then
			error("Invalid Children definition")
		end
		for name, child in children do
			if type(child) == "table" and child._instance then
				child = child._instance
			end
			if type(name) == "number" and child.LayoutOrder == 0 then
				if child:IsA("GuiObject") then
					child.LayoutOrder = name
				end
			else
				child.Name = name or child.Name
			end
			child.Parent = contentParent
		end
		definition[UI.Children] = nil
	end
	-- numeric index child definition
	for index, child in ipairs(definition) do
		if type(child) == "table" and child._instance then
			child = child._instance
		end
		if typeof(child) ~= "Instance" then
			error(`Invalid UI child Instance: {child}`)
		end
		if child:IsA("GuiObject") then
			child.LayoutOrder = if child.LayoutOrder ~= 0 then child.LayoutOrder else index
		end
		child.Parent = contentParent
		definition[index] = nil
	end

	if type(new) == "table" then
		local hooks = definition[UI.Hook]
		definition[UI.Hook] = nil
		if hooks then
			for key, hook in hooks do
				local classMember = new[key]
				if not UI.isState(classMember) then
					error(`Invalid UI State Hook {key}`)
				end
				if type(hook) == "function" then
					table.insert(cleanup, classMember:hook(hook))
				end
			end
		end
		for key, value in definition do
			local classMember = new[key]
			if classMember == nil then
				continue
			end
			definition[key] = nil -- strip class members
			-- connect alias signals
			if typeof(classMember) == "RBXScriptSignal" then
				classMember:Connect(value)
			end
		end
	end

	if not definition[Flux.Clean] then
		definition[Flux.Clean] = {}
	end

	for _, v in cleanup do
		table.insert(definition[Flux.Clean], v)
	end

	definition.Parent = nil
	if parent then
		instance.Parent = if type(parent) == "table" then (parent._content or parent._instance) else parent
	end
	-- apply non class members to the root instance with Flux.edit
	Flux.edit(instance, definition)
	return new
end

--- Creates a new Instance with [UI.edit]
--- @within UI
--- @function new
--- @param className string
--- @return UI.edit
UI.new = function(className)
	local class = UI.Class[className]
	return function(definition)
		return UI.edit(if class then class.new(definition) else Instance.new(className), definition)
	end
end :: ((className: string) -> (properties: GuiObject & SpecialDefinition) -> Instance | Dict<any>) & typeof(Instance.new)

--- Registers a new UI component class
function UI.register(className: string, class: Dict<any>)
	if UI.Class[className] then
		error(`UI class "{className}" already exists`)
	end
	UI.Class[className] = class
end

--- Run to register all default classes in the UI module
function UI.registerDefaultClasses(): typeof(UI)
	UI.registerDefaultClasses = nil :: any
	for _, child in script.DefaultClasses:GetChildren() do
		if child:IsA("ModuleScript") then
			UI.register(child.Name, require(child))
		end
	end
	return UI
end

return UI
