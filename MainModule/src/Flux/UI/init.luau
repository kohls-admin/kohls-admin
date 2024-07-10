local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local TextService = game:GetService("TextService")
local UserInputService = game:GetService("UserInputService")

local Flux = require(script.Parent)
local state = Flux.state

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

-- TODO: allow a way to easily override builtin theme binds with a new compute or whatever!
local UI = {
	GuiService = GuiService,
	TextService = TextService,
	UserInputService = UserInputService,

	Class = {},
	Hook = newproxy(),
	Scope = Flux.Scope.UI,
	TopbarInset = state(GuiService, "TopbarInset"),
	Theme = {
		ClackAll = state(true),
		ClackEnabled = state(true),
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
		StrokeEnabled = state(false),

		NormalTween = TweenInfo.new(0.2),
		-- BasePixelHeight 32?
	},

	LayerBottom = Flux.new "ScreenGui" {
		Parent = playerGui,
		Name = "FluxUILayerBottom",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	},
	LayerDefault = Flux.new "ScreenGui" {
		Parent = playerGui,
		Name = "FluxUILayerDefault",
		DisplayOrder = 2,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	},
	LayerTop = Flux.new "ScreenGui" {
		Parent = playerGui,
		Name = "FluxUILayerTop",
		DisplayOrder = 999999999,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	},
}
UI.Scope.Theme = UI.Theme
UI.__index = UI
setmetatable(UI, Flux)

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

local _currentHover
function UI.handleHover(new)
	if not Flux.isState(new) then
		error("Invalid hovering state")
	end
	if _currentHover and not rawequal(_currentHover, new) then
		_currentHover:set(false)
	end
	_currentHover = new
	new:set(true)
end

function UI.getLuminance(color: Color3): number
	return math.sqrt(0.299 * color.R ^ 2 + 0.587 * color.G ^ 2 + 0.114 * color.B ^ 2)
end

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

function UI.pointInGuiObject(x: number, y: number, object: GuiObject)
	local size = object.AbsoluteSize
	local position = object.AbsolutePosition
	return x >= position.X and x <= position.X + size.X and y >= position.Y and y <= position.Y + size.Y
end

function UI.makeStatefulDefaults(default: { [any]: any }, definition: { [any]: any }?)
	for key, value in default do
		if definition then
			value = definition[key] or value
		end
		if not Flux.isState(value) then
			value = Flux.state(value)
		end
		default[key] = value
	end
	return default
end

function UI.new(className)
	local class = UI.Class[className]
	return function(definition)
		local new = class and class.new(definition)
		local instance = if new then new._instance else Instance.new(className)
		local children = definition[UI.Children]

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
				child.Parent = instance:FindFirstChild("UIContent") or instance
			end
			definition[UI.Children] = nil
		end
		-- numeric index child definition
		for index, child in ipairs(definition) do
			if type(child) == "table" and child._instance then
				child = child._instance
			end
			if typeof(child) ~= "Instance" then
				error("Invalid UI Instance")
			end
			if child:IsA("GuiObject") then
				child.LayoutOrder = if child.LayoutOrder > 0 then child.LayoutOrder else index
			end
			child.Parent = instance:FindFirstChild("UIContent") or instance
			definition[index] = nil
		end

		if new then
			local hooks = definition[UI.Hook]
			definition[UI.Hook] = nil
			if hooks then
				for key, hook in hooks do
					local classMember = new[key]
					if not UI.isState(classMember) then
						error("Invalid UI State Hook", key)
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
		-- apply non class members to the root instance
		UI.edit(instance, definition)
		return new or instance
	end
end

function UI.register(className, class)
	if UI.Class[className] then
		error(`UI class "{className}" already exists`)
	end
	UI.Class[className] = class
end

function UI.registerChildren()
	UI.registerChildren = nil :: any
	for _, child in script:GetChildren() do
		if child:IsA("ModuleScript") then
			UI.register(child.Name, require(child))
		end
	end
	return UI
end

return UI
