local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local TextService = game:GetService("TextService")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")

local Package = script.Parent.Parent

local Flux = require(Package:WaitForChild("Flux"))
local Type = require(Package.Flux:WaitForChild("Type"))
local state = Flux.state

local Classes = script:WaitForChild("Classes")
local playerGui = Players.LocalPlayer and Players.LocalPlayer:WaitForChild("PlayerGui")

--- @class UI
local UI = { Class = {} }
UI.__index = UI
setmetatable(UI, Flux)

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
		Flux.action(function(self)
			self:SetWaveformKeys({
				FloatCurveKey.new(0, 0.1, Enum.KeyInterpolationMode.Constant),
				FloatCurveKey.new(1, 0, Enum.KeyInterpolationMode.Constant),
			})
		end),
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
--- @prop LocalPlayer Player
UI.LocalPlayer = Players.LocalPlayer

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
	Size = function()
		return UDim2.new(1, 0, 0, UI.TopbarInset().Height + if UI.IsConsoleScreen then 50 else 0)
	end,
	Visible = function()
		return UI.IsConsoleScreen or UI.TopbarInset().Height > 0
	end,

	UI.new "UIListLayout" {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		Padding = UI.TopbarPadding,
	},
	UI.new "UIPadding" {
		PaddingLeft = if UI.IsConsoleScreen
			then UDim.new(0, 10)
			else function()
				return UDim.new(0, 2 + UI.TopbarPadding().Offset / 2)
			end,
		PaddingRight = UI.TopbarPadding,
		PaddingTop = if UI.IsConsoleScreen then UDim.new(0, 6) else UI.TopbarPadding,
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

function UI.newSinkHoverState(object: GuiObject, hovering: any?)
	if not hovering then
		hovering = UI.state(false)
	end

	UI.edit(object, {
		InputChanged = function(input, processed)
			if processed then
				return
			end
			if
				input.UserInputType == Enum.UserInputType.MouseMovement
				or input.UserInputType == Enum.UserInputType.Touch
			then
				if UI.sinkInput(input.Position.X, input.Position.Y, object) then
					UI.deactivateState(hovering, "hover")
					return
				end
				UI.activateState(hovering, "hover")
			end
		end,
		InputEnded = function(input)
			if
				input.UserInputType == Enum.UserInputType.MouseMovement
				or input.UserInputType == Enum.UserInputType.Touch
			then
				UI.deactivateState(hovering, "hover")
			end
		end,
	})

	return hovering
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
		if type(index) ~= "number" or index ~= math.floor(index :: number) then
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

local defaultProperties = require(script.DefaultProperties)(UI)

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
				local instance = Instance.new(className)

				if defaultProperties[className] then
					UI.edit(instance, defaultProperties[className])
				end

				return UI.edit(instance, properties)
			end
		end

		self[className] = new
		return new
	end,
})

type Constructor =
	Type.Constructor
	& Type.New<"Button", typeof(require(Classes.Button).new())>
	& Type.New<"Checkbox", typeof(require(Classes.Checkbox).new())>
	& Type.New<"CircleProgress", typeof(require(Classes.CircleProgress).new())>
	& Type.New<"Color", typeof(require(Classes.Color).new())>
	& Type.New<"ColorPicker", typeof(require(Classes.ColorPicker).new())>
	& Type.New<"Dialog", typeof(require(Classes.Dialog).new())>
	& Type.New<"Link", typeof(require(Classes.Link).new())>
	& Type.New<"List", typeof(require(Classes.List).new())>
	& Type.New<"ListItem", typeof(require(Classes.ListItem).new())>
	& Type.New<"Menu", typeof(require(Classes.Menu).new())>
	& Type.New<"Scroller", typeof(require(Classes.Scroller).new())>
	& Type.New<"ScrollerFast", typeof(require(Classes.ScrollerFast).new())>
	& Type.New<"Select", typeof(require(Classes.Select).new())>
	& Type.New<"Slider", typeof(require(Classes.Slider).new())>
	& Type.New<"Spacer", typeof(require(Classes.Spacer).new())>
	& Type.New<"Stroke", typeof(require(Classes.Stroke).new())>
	& Type.New<"Switch", typeof(require(Classes.Switch).new())>
	& Type.New<"Tabs", typeof(require(Classes.Tabs).new())>
	& Type.New<"Tooltip", typeof(require(Classes.Tooltip).new())>
	& Type.New<"Window", typeof(require(Classes.Window).new())>

--- Creates a new Instance with [UI.edit]
--- @within UI
--- @function new
--- @param className string
--- @return UI.edit
UI.new = (function(className)
	return constructors[className]
end :: any) :: Constructor

--- Registers a new UI component class
function UI.register(className: string, class: Type.Dict<any>)
	if UI.Class[className] then
		error(`UI class "{className}" already exists`)
	end
	UI.Class[className] = class
end

--- Run to register the default classes for the UI module
function UI.registerClasses(): typeof(UI)
	UI.registerClasses = nil :: any
	for _, child in script.Classes:GetChildren() do
		if child:IsA("ModuleScript") then
			UI.register(child.Name, require(child))
		end
	end
	return UI
end

return UI
