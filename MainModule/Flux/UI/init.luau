local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local SoundService = game:GetService("SoundService")
local TextService = game:GetService("TextService")
local UserInputService = game:GetService("UserInputService")

local Sound = {}
Sound.__index = Sound

export type Sound = typeof(setmetatable({} :: { sound: Instance }, Sound))

function Sound.new(id: string): Sound
	local self = {
		sound = Instance.new("Sound"),
	}
	self.sound.PlayOnRemove = true
	self.sound.SoundId = "rbxassetid://" .. id
	return setmetatable(self, Sound)
end

--- Creates a copy of the sound and plays it
function Sound:Play()
	local sound = self.sound:Clone()
	sound.Parent = SoundService
	sound:Destroy()
end

local Flux = require(script.Parent)
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
--- A scope object for organizing and cleaning up UI states
--- @prop Scope Scope
UI.Scope = setmetatable({}, Flux.scopeMetatable)
Flux.Scope.UI = UI.Scope

--- @within UI
--- GuiService.TopbarInset as a Flux state
--- @prop TopbarInset State<Rect>
UI.TopbarInset = state(GuiService, "TopbarInset")
UI.LegacyTopBar = Flux.compute(function(use)
	return use(UI.TopbarInset).Height == 36
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
--- The TopBar ScreenGui for UI components
--- @prop LayerTopBar State<ScreenGui>
UI.LayerTopBar = Flux.new "ScreenGui" {
	Parent = playerGui,
	Name = "FluxUILayerTopBar",
	DisplayOrder = 10,
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	ScreenInsets = Enum.ScreenInsets.TopbarSafeInsets,
}

--- @within UI
--- A sorted TopBar Frame for UI components, parented under [UI.LayerTopBar]
--- @prop TopBarFrame State<Frame>
UI.TopBarFrame = UI.new "Frame" {
	Parent = UI.LayerTopBar,
	BackgroundTransparency = 1,
	Size = UDim2.new(1, 0, 1, 0),

	UI.new "UIListLayout" {
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
	},
	UI.new "UIPadding" {
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 12),
		PaddingBottom = Flux.compute(function(use)
			return UDim.new(0, if use(UI.LegacyTopBar) then 0 else 2)
		end),
	},
}

--- @within UI
--- A directory of Flux state for UI components to use as theme variables
--- @interface Theme
--- .ClackAll State<boolean>
--- .ClackEnabled State<boolean>
--- .Transparency State<number>
--- .Primary State<Color3>
--- .PrimaryText State<Color3>
--- .Secondary State<Color3>
--- .SecondaryText State<Color3>
--- .Muted State<Color3>
--- .MutedText State<Color3>
--- .Border State<Color3>
--- .BorderMuted State<Color3>
--- .Valid State<Color3>
--- .Invalid State<Color3>
--- .FontSize State<number>
--- .Font State<Font>
--- .FontMono State<Font>
--- .FontHeavy State<Font>
--- .FontBold State<Font>
--- .FontSemiBold State<Font>
--- .FontLight State<Font>
--- .CornerRadius State<UDim>
--- .CornerHalf State<UDim>
--- .CornerDiameter State<UDim>
--- .Padding State<UDim>
--- .PaddingHalf State<UDim>
--- .PaddingDouble State<UDim>
--- .StrokeEnabled State<boolean>
--- .NormalTween State<TweenInfo>
--- .TransparencyClamped State<number>
--- .ScrollMidImage State<string>
--- .ScrollTopImage State<string>
--- .ScrollBottomImage State<string>
UI.Theme = {
	ClackAll = state(true),
	ClackEnabled = state(false),
	Transparency = state(0.3),

	Primary = state(Color3.fromRGB(0, 0, 0)),
	PrimaryText = state(Color3.fromRGB(255, 255, 255)),

	Secondary = state(Color3.fromRGB(255, 255, 255)),
	SecondaryText = state(Color3.fromRGB(0, 0, 0)),

	Muted = state(Color3.fromRGB(200, 200, 200)),
	MutedText = state(Color3.fromRGB(127, 127, 127)),

	Border = state(Color3.fromRGB(100, 100, 100)),
	BorderMuted = state(Color3.fromRGB(50, 50, 50)),

	Valid = state(Color3.fromRGB(0, 255, 0)),
	Invalid = state(Color3.fromRGB(255, 0, 0)),

	FontSize = state(16),
	Font = state(Enum.Font.Roboto),
	FontMono = state(Enum.Font.RobotoMono),

	CornerRadius = state(UDim.new(0, 8)),
	Padding = state(UDim.new(0, 8)),
	StrokeEnabled = state(true),

	TweenIn = state(TweenInfo.new(0.3, Enum.EasingStyle.Cubic, Enum.EasingDirection.In)),
	TweenOut = state(TweenInfo.new(0.3, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)),
	TweenInOut = state(TweenInfo.new(0.3, Enum.EasingStyle.Cubic, Enum.EasingDirection.InOut)),

	-- BasePixelHeight 32?
}

UI.Theme.TransparencyClamped = UI.compute(function(use)
	return math.min(0.75, use(UI.Theme.Transparency))
end)

UI.Theme.FontHeavy = Flux.compute(function(use)
	local font = Font.fromEnum(use(UI.Theme.Font))
	font.Weight = Enum.FontWeight.Heavy
	return font
end)

UI.Theme.FontBold = Flux.compute(function(use)
	local font = Font.fromEnum(use(UI.Theme.Font))
	font.Weight = Enum.FontWeight.Bold
	return font
end)

UI.Theme.FontSemiBold = Flux.compute(function(use)
	local font = Font.fromEnum(use(UI.Theme.Font))
	font.Weight = Enum.FontWeight.SemiBold
	return font
end)

UI.Theme.FontLight = Flux.compute(function(use)
	local font = Font.fromEnum(use(UI.Theme.Font))
	font.Weight = Enum.FontWeight.Light
	return font
end)

UI.Theme.FontSizeDouble = Flux.compute(function(use)
	return math.round(use(UI.Theme.FontSize) * 2)
end)

UI.Theme.FontSizeLargest = Flux.compute(function(use)
	return math.round(use(UI.Theme.FontSize) * 1.75)
end)

UI.Theme.FontSizeLarger = Flux.compute(function(use)
	return math.round(use(UI.Theme.FontSize) * 1.5)
end)

UI.Theme.FontSizeLarge = Flux.compute(function(use)
	return math.round(use(UI.Theme.FontSize) * 1.25)
end)

UI.Theme.FontSizeSmall = Flux.compute(function(use)
	return math.round(use(UI.Theme.FontSize) * 0.75)
end)

UI.Theme.FontSizeSmaller = Flux.compute(function(use)
	return math.round(use(UI.Theme.FontSize) * 0.5)
end)

UI.Theme.FontSizeSmallest = Flux.compute(function(use)
	return math.round(use(UI.Theme.FontSize) * 0.25)
end)

UI.Theme.PaddingHalf = UI.compute(function(use)
	local padding = use(UI.Theme.Padding)
	return UDim.new(padding.Scale / 2, padding.Offset / 2)
end)

UI.Theme.PaddingDouble = UI.compute(function(use)
	local padding = use(UI.Theme.Padding)
	return UDim.new(padding.Scale * 2, padding.Offset * 2)
end)

UI.Theme.CornerHalf = UI.compute(function(use)
	local radius = use(UI.Theme.CornerRadius)
	return UDim.new(radius.Scale / 2, radius.Offset / 2)
end)

UI.Theme.CornerDiameter = UI.compute(function(use)
	local radius = use(UI.Theme.CornerRadius)
	return UDim.new(radius.Scale * 2, radius.Offset * 2)
end)

UI.Theme.ScrollMidImage = UI.state("rbxassetid://18370268668")
UI.Theme.ScrollTopImage = UI.compute(function(use)
	return if use(UI.Theme.CornerRadius).Offset == 0 then "rbxassetid://18370268668" else "rbxassetid://18370266164"
end)
UI.Theme.ScrollBottomImage = UI.compute(function(use)
	return if use(UI.Theme.CornerRadius).Offset == 0 then "rbxassetid://18370268668" else "rbxassetid://18370271296"
end)

UI.Sound = {
	Back = Sound.new("10066914500"),
	Call_Decline = Sound.new("17208214688"),
	Call_Leave = Sound.new("17208295577"),
	Hover01 = Sound.new("17208339919"),
	Hover02 = Sound.new("17208343514"),
	Hover03 = Sound.new("17208348006"),
	Negative = Sound.new("17208353912"),
	Notification_High = Sound.new("17208361335"),
	Notification_Low = Sound.new("17208372272"),
}

local _currentHover

--- Handles a global hovering state for specific edge-cases
function UI.handleHover(hoverState: State<boolean>)
	if not Flux.isState(hoverState) then
		error("Invalid hovering state")
	end
	if _currentHover and not rawequal(_currentHover, hoverState) then
		_currentHover:set(false)
	end
	_currentHover = hoverState
	hoverState:set(true)
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
			value = definition[key] or value
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
			if type(name) == "number" then
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
			child.LayoutOrder = if child.LayoutOrder > 0 then child.LayoutOrder else index
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
					-- FIX: add a way to clean it up with the class:Destroy() method
					local _cleanup = classMember:hook(hook)
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

--- Run to register all default children in the UI module
function UI.registerChildren(): typeof(UI)
	UI.registerChildren = nil :: any
	for _, child in script:GetChildren() do
		if child:IsA("ModuleScript") then
			UI.register(child.Name, require(child))
		end
	end
	return UI
end

return UI
