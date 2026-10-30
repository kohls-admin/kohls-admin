local Package = script.Parent.Parent.Parent

local Flux = require(Package:WaitForChild("Flux"))
local ThemesFolder = script:WaitForChild("Themes")
local Default = require(script:WaitForChild("Default"))

local computed = Flux.computed
local signal = Flux.signal

local themes = {}

local function loadTheme(themeModule: ModuleScript)
	if themeModule:IsA("ModuleScript") then
		if themes[themeModule.Name] then
			warn("Duplicate theme found, make sure they have different names!")
		end
		local theme = require(themeModule)
		if typeof(theme.Font) == "EnumItem" then
			theme.Font = Font.fromEnum(theme.Font :: Enum.Font)
		end
		if typeof(theme.FontMono) == "EnumItem" then
			theme.FontMono = Font.fromEnum(theme.FontMono :: Enum.Font)
		end
		for _, definition in { theme.Image, theme.Sound } do
			for key, value in definition do
				definition[key] = "rbxassetid://" .. value
			end
		end
		if theme == Default then
			return
		end
		if themeModule.Name == "Default" then
			-- clone the default theme to not use overwritten values
			local default = {}
			for key, value in theme do
				default[key] = if type(value) == "table" then table.clone(value) else value
			end
			themes[themeModule.Name] = default
		else
			themes[themeModule.Name] = theme
		end
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

local userDefault = ThemesFolder:FindFirstChild("Default") :: ModuleScript
userDefault = if userDefault then require(userDefault) else {}
for k, v in Default do
	Theme[k] = userDefault[k] or v
end

local function makeStateful(source: { [string]: any })
	for key, value in source do
		if type(value) == "table" then
			makeStateful(value)
		else
			source[key] = signal(value)
		end
	end
end
makeStateful(Theme)

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
