local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local TextService = game:GetService("TextService")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")

local Flux = require(script.Parent.Parent.Flux)
local Type = require(script.Parent.Parent.Flux.Type)
local state = Flux.state

local playerGui = Players.LocalPlayer and Players.LocalPlayer:WaitForChild("PlayerGui")

--- @class UI
local UI = { Class = {} }
UI.__index = UI
setmetatable(UI, Flux)

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
--- @type Platform "Console" | "Mobile" | "PC" | "VR"
export type Platform = "Console" | "Mobile" | "PC" | "VR"

--- @within UI
--- @prop Touch boolean
UI.Touch = UserInputService.TouchEnabled

UI.IsConsoleScreen = GuiService:IsTenFootInterface()

--- @within UI
--- @prop Platform Platform
UI.Platform = if UserInputService.VREnabled
	then "VR"
	elseif UI.IsConsoleScreen then "Console"
	elseif UserInputService.KeyboardEnabled and UserInputService.MouseEnabled then "PC"
	else "Mobile"

--- @within UI
--- A marker for defining UI state hooks in [UI.edit]
--- @prop Hook Flux.Symbol
--- @readonly
UI.Hook = table.freeze({ type = "Symbol" }) :: Type.Symbol

--- @within UI
--- A marker for defining function defaultState in [UI.makeStatefulDefaults]
--- @prop Function Flux.Symbol
--- @readonly
UI.Function = table.freeze({ type = "Symbol" }) :: Type.Symbol

--- @within UI
--- A marker for defining Nil defaultState in [UI.makeStatefulDefaults]
--- @prop Nil Flux.Symbol
--- @readonly
UI.Nil = table.freeze({ type = "Symbol" }) :: Type.Symbol

--- @within UI
--- GuiService.TopbarInset as a Flux state
--- @prop TopbarInset State<Rect>
UI.TopbarInset = state(GuiService, "TopbarInset")
UI.TopbarPadding = Flux.compute(function()
	return UDim.new(0, if UI.IsConsoleScreen then 10 else UI.TopbarInset().Height - 46)
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
	Size = if UI.IsConsoleScreen
		then UDim2.new(1, 0, 1, -54)
		else function()
			return UDim2.new(1, 0, 1, -UI.TopbarInset().Height)
		end,
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
	Position = UDim2.new(0, 0, 0, if UI.IsConsoleScreen then 4 else 0),
	Size = UDim2.new(1, 0, 1, if UI.IsConsoleScreen then 50 else 0),

	UI.new "UIListLayout" {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		Padding = UI.TopbarPadding,
	},
	UI.new "UIPadding" {
		PaddingLeft = UI.TopbarPadding,
		PaddingRight = UI.TopbarPadding,
		PaddingTop = if UI.IsConsoleScreen
			then UDim.new(0, 6)
			else Flux.compute(function()
				return UDim.new(0, UI.TopbarPadding().Offset)
			end),
		PaddingBottom = UDim.new(0, if UI.IsConsoleScreen then 0 else 2),
	},
}

--- @within UI
--- @type ActiveStateType "hover" | "floating" | "dialog"
export type ActiveStateType = "hover" | "floating" | "dialog"

UI._activeState = {}

--- A generalized function to handle activation/deactivation of both floating and hover states
function UI.activateState(activeState: any, stateType: ActiveStateType)
	if not Flux.isState(activeState) then
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
end

--- A generalized function to deactivate both floating and hover states
function UI.deactivateState(activeState: any, stateType: ActiveStateType)
	if not Flux.isState(activeState) then
		error("Invalid active state")
	end

	-- Clear the previous state if it matches
	local previousState = UI._activeState[stateType]
	if previousState and previousState == activeState then
		UI._activeState[stateType] = nil
	end

	local state: any = activeState
	state(false)
end

--- A generalized function to toggle both floating and hover states
function UI.toggleState(activeState: any, stateType: ActiveStateType)
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
	local activeState = UI._activeState[stateType]
	if Flux.isState(activeState) then
		activeState(false)
		UI._activeState[stateType] = nil
	end
end

--- Function to clear all active state types
function UI.clearActiveStates()
	for stateType in UI._activeState do
		UI.clearState(stateType)
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
function UI.pointInGuiObject(x: number, y: number, object: GuiObject): boolean
	local size = object.AbsoluteSize
	local position = object.AbsolutePosition
	return x >= position.X and x <= position.X + size.X and y >= position.Y and y <= position.Y + size.Y
end

function UI.sinkInput(x: number, y: number, object: GuiObject): boolean
	for _, gui in UI.PlayerGui:GetGuiObjectsAtPosition(x, y) do
		if gui == object then
			break
		end
		if gui.Active or gui:IsA("GuiButton") then
			return true
		end
	end
	return false
end

--- Helper function for defining Flux state defaults
function UI.makeStatefulDefaults(default: Type.Dict<any>, definition: Type.Dict<any>?)
	for key, value in default do
		if definition then
			value = if definition[key] ~= nil then definition[key] else value
		end
		if typeof(value) == "function" and default[key] ~= UI.Function then
			value = Flux.compute(value)
		end
		if value == UI.Nil or value == UI.Function then
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
function UI.edit(new: Instance | Type.Dict<any>, properties: Type.Dict<any>): Instance | Type.Dict<any>
	properties = properties :: Type.Dict<any> & GuiObject

	local instance = new
	local contentParent = instance
	local cleanup = {}

	if type(new) == "table" then
		instance = new._instance
		contentParent = new._content or new._instance
	end

	-- numeric index child definition
	for index, child in properties do
		if type(index) ~= "number" or index ~= math.floor(index) then
			continue
		end
		if type(child) == "table" and child._instance then
			child = child._instance
		end
		if typeof(child) == "Instance" then
			if child:IsA("GuiObject") then
				child.LayoutOrder = if child.LayoutOrder ~= 0 then child.LayoutOrder else index
			end
			child.Parent = contentParent
			properties[index] = nil
		end
	end

	if type(new) == "table" then
		local hooks = properties[UI.Hook]
		properties[UI.Hook] = nil
		if hooks then
			for key, hook in hooks do
				local classMember = new[key]
				if not UI.isState(classMember) then
					error(`Invalid UI State Hook {key}`)
				end
				if type(hook) == "function" then
					table.insert(cleanup, classMember:Connect(hook))
				end
			end
		end
		for key, value in properties do
			local classMember = new[key]
			if classMember == nil then
				continue
			end
			properties[key] = nil -- strip class members
			-- connect alias signals
			if typeof(classMember) == "RBXScriptSignal" then
				classMember:Connect(value)
			end
		end
	end

	if not properties[Flux.Clean] then
		properties[Flux.Clean] = {}
	end

	for _, v in cleanup do
		table.insert(properties[Flux.Clean], v)
	end

	local parent = properties.Parent
	if parent then
		properties.Parent = if type(parent) == "table" then (parent._content or parent._instance) else parent
	end
	-- apply non class members to the root instance with Flux.edit
	Flux.edit(instance, properties)
	return new
end

local constructors: { [string]: () -> Instance } = {}
setmetatable(constructors, {
	__index = function(self, className: string)
		local class = UI.Class[className]
		local new

		if class then
			new = function(properties: Type.Dict<any>): Instance | Type.Dict<any>
				return UI.edit(class.new(properties), properties)
			end
		else
			new = function(properties: Type.Dict<any>): Instance | Type.Dict<any>
				return UI.edit(Instance.new(className), properties)
			end
		end

		self[className] = new
		return new
	end,
})

--- Creates a new Instance with [UI.edit]
--- @within UI
--- @function new
--- @param className string
--- @return UI.edit
UI.new = function(className)
	return constructors[className]
end :: Type.Constructor

--- Registers a new UI component class
function UI.register(className: string, class: Type.Dict<any>)
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
