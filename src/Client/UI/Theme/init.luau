local Package = script.Parent.Parent.Parent

local Flux = require(Package:WaitForChild("Flux"))
local ThemesFolder = script:WaitForChild("Themes")
local Default = require(script:WaitForChild("Default"))

local computed = Flux.computed
local signal = Flux.signal

local themes = {}
local initialized = false

local function makeStateful(source: { [string]: any })
	for key, value in source do
		if type(value) == "table" and not Flux.isNode(value) then
			makeStateful(value)
		elseif not Flux.isNode(value) then
			source[key] = signal(value)
		end
	end
end

local function loadTheme(themeModule: ModuleScript)
	if themeModule:IsA("ModuleScript") then
		if themes[themeModule.Name] and themeModule.Name ~= "Default" then
			warn("Duplicate theme found, make sure they have different names!")
		end
		local ok, theme = pcall(require, themeModule)
		if not ok or type(theme) ~= "table" then
			return
		end
		if typeof(theme.Font) == "EnumItem" then
			theme.Font = Font.fromEnum(theme.Font :: Enum.Font)
		end
		if typeof(theme.FontMono) == "EnumItem" then
			theme.FontMono = Font.fromEnum(theme.FontMono :: Enum.Font)
		end
		for _, key in { "Image", "Sound" } do
			local definition = theme[key]
			if type(definition) == "table" then
				for k, value in definition do
					if type(value) == "string" and not string.find(value, "rbxassetid://", 1, true) then
						definition[k] = "rbxassetid://" .. value
					end
				end
			end
		end
		local cloned = {}
		for key, value in Default do
			local v = if theme[key] ~= nil then theme[key] else value
			if type(value) == "table" and not Flux.isNode(value) then
				local merged = table.clone(value)
				if type(theme[key]) == "table" then
					for k, item in theme[key] do
						merged[k] = item
					end
				end
				cloned[key] = merged
			else
				cloned[key] = Flux.raw(v)
			end
		end
		if initialized then
			makeStateful(cloned)
		end
		themes[themeModule.Name] = cloned
	end
end

loadTheme(script:WaitForChild("Default"))
for _, themeModule: ModuleScript in ThemesFolder:GetChildren() do
	loadTheme(themeModule)
end
task.wait()

--- A directory of Flux state for UI components to use as theme variables
local Theme = {
	Themes = themes,
}

local defaultTheme = themes.Default or Default
for k, v in defaultTheme do
	Theme[k] = if type(v) == "table" and not Flux.isNode(v) then table.clone(v) else Flux.raw(v)
end

makeStateful(Theme)
initialized = true

local function updateSignals(target: { [string]: any }, source: { [string]: any })
	for k, v in source do
		local node = target[k]
		if type(node) == "table" then
			if type(node.set) == "function" then
				node(Flux.raw(v))
			elseif type(v) == "table" then
				updateSignals(node, v)
			end
		end
	end
end

ThemesFolder.ChildRemoved:Connect(function(child)
	themes[child.Name] = nil
end)

ThemesFolder.ChildAdded:Connect(function(child)
	loadTheme(child :: ModuleScript)
	if child.Name == "Default" and themes.Default then
		updateSignals(Theme, themes.Default)
	end
end)

-- COMPUTED THEME VALUES

Theme.TransparencySlight = computed(function()
	return Theme.Transparency() * 0.9375 + 0.0625
end)

Theme.TransparencyLight = computed(function()
	return Theme.Transparency() * 0.875 + 0.125
end)

Theme.TransparencyMedium = computed(function()
	return Theme.Transparency() * 0.75 + 0.25
end)

Theme.TransparencyBalanced = computed(function()
	return Theme.Transparency() * 0.5 + 0.5
end)

Theme.TransparencyStrong = computed(function()
	return Theme.Transparency() * 0.25 + 0.75
end)

Theme.TransparencyHeavy = computed(function()
	return Theme.Transparency() * 0.125 + 0.875
end)

Theme.TransparencyMax = computed(function()
	return Theme.Transparency() * 0.0625 + 0.9375
end)

Theme.TransparencyClamped = computed(function()
	return Theme.Transparency() * 0.75
end)

Theme.FontHeavy = computed(function()
	return Font.new(Theme.Font().Family, Enum.FontWeight.Heavy)
end)

Theme.FontBold = computed(function()
	return Font.new(Theme.Font().Family, Enum.FontWeight.Bold)
end)

Theme.FontSemiBold = computed(function()
	return Font.new(Theme.Font().Family, Enum.FontWeight.SemiBold)
end)

Theme.FontLight = computed(function()
	return Font.new(Theme.Font().Family, Enum.FontWeight.Light)
end)

Theme.FontThin = computed(function()
	return Font.new(Theme.Font().Family, Enum.FontWeight.Thin)
end)

Theme.FontSizeDouble = computed(function()
	return math.round(Theme.FontSize() * 2)
end)

Theme.FontSizeLargest = computed(function()
	return math.round(Theme.FontSize() * 1.75)
end)

Theme.FontSizeLarger = computed(function()
	return math.round(Theme.FontSize() * 1.5)
end)

Theme.FontSizeLarge = computed(function()
	return math.round(Theme.FontSize() * 1.25)
end)

Theme.FontSizeSmall = computed(function()
	return math.round(Theme.FontSize() * 0.75)
end)

Theme.FontSizeSmaller = computed(function()
	return math.round(Theme.FontSize() * 0.5)
end)

Theme.FontSizeSmallest = computed(function()
	return math.round(Theme.FontSize() * 0.25)
end)

Theme.PaddingHalf = computed(function()
	local padding = Theme.Padding()
	return UDim.new(padding.Scale / 2, padding.Offset / 2)
end)

Theme.PaddingDouble = computed(function()
	local padding = Theme.Padding()
	return UDim.new(padding.Scale * 2, padding.Offset * 2)
end)

Theme.PaddingStroke = computed(function()
	return UDim.new(0, if Theme.StrokeEnabled() then 1 else 0)
end)

Theme.PaddingWithStroke = computed(function()
	return Theme.Padding() + Theme.PaddingStroke()
end)

Theme.CornerHalf = computed(function()
	local radius = Theme.CornerRadius()
	return UDim.new(radius.Scale / 2, radius.Offset / 2)
end)

Theme.CornerDiameter = computed(function()
	local radius = Theme.CornerRadius()
	return UDim.new(radius.Scale * 2, radius.Offset * 2)
end)

Theme.CornerPadded = computed(function()
	local padding = Theme.Padding()
	local radius = Theme.CornerRadius()
	return UDim.new(radius.Scale, radius.Offset - padding.Offset / 2)
end)

Theme.CornerPadded2 = computed(function()
	local padding = Theme.Padding()
	local radius = Theme.CornerRadius()
	return UDim.new(radius.Scale, radius.Offset - padding.Offset)
end)

Theme.CornerPadded3 = computed(function()
	local padding = Theme.Padding()
	local radius = Theme.CornerRadius()
	return UDim.new(radius.Scale, radius.Offset - padding.Offset * 1.5)
end)

Theme.ScrollMidImage = signal("rbxassetid://18370268668")
Theme.ScrollTopImage = computed(function()
	return if Theme.CornerRadius().Offset == 0 then "rbxassetid://18370268668" else "rbxassetid://105141456035522"
end)
Theme.ScrollBottomImage = computed(function()
	return if Theme.CornerRadius().Offset == 0 then "rbxassetid://18370268668" else "rbxassetid://110012579042362"
end)

return Theme :: typeof(Default) & typeof(Theme)
