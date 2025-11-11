local ContentProvider = game:GetService("ContentProvider")

local Flux = require(script.Parent.Parent.Parent:WaitForChild("Flux"))
local ThemesFolder = script:WaitForChild("Themes")
local Default = require(ThemesFolder:WaitForChild("Default"))

local compute = Flux.compute
local state = Flux.state

--- @within UI
--- A directory of Flux state for UI components to use as theme variables
--- @interface Theme
--- .Transparency State<number>
--- .Primary State<Color3>
--- .PrimaryText State<Color3>
--- .Secondary State<Color3>
--- .SecondaryText State<Color3>
--- .Border State<Color3>
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
--- .SoundsEnabled State<boolean>
--- .TypingSounds State<boolean>
--- .TypingSoundsOnEveryTextBox State<boolean>
--- .Volume State<number>

local themes = {}
for _, themeModule: ModuleScript in ThemesFolder:GetChildren() do
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

local Theme = {
	Themes = themes,
}
for k, v in Default do
	Theme[k] = v
end

local function makeStateful(source: { [string]: any })
	for key, value in source do
		if type(value) == "table" then
			makeStateful(value)
		else
			source[key] = state(value)
		end
	end
end
makeStateful(Theme)

-- COMPUTED THEME VALUES

Theme.TransparencySlight = compute(function()
	return Theme.Transparency * 0.9375 + 0.0625
end)

Theme.TransparencyLight = compute(function()
	return Theme.Transparency * 0.875 + 0.125
end)

Theme.TransparencyMedium = compute(function()
	return Theme.Transparency * 0.75 + 0.25
end)

Theme.TransparencyBalanced = compute(function()
	return Theme.Transparency * 0.5 + 0.5
end)

Theme.TransparencyStrong = compute(function()
	return Theme.Transparency * 0.25 + 0.75
end)

Theme.TransparencyHeavy = compute(function()
	return Theme.Transparency * 0.125 + 0.875
end)

Theme.TransparencyMax = compute(function()
	return Theme.Transparency * 0.0625 + 0.9375
end)

Theme.TransparencyClamped = compute(function()
	return Theme.Transparency * 0.75
end)

Theme.FontHeavy = compute(function()
	return Font.new(Theme.Font().Family, Enum.FontWeight.Heavy)
end)

Theme.FontBold = compute(function()
	return Font.new(Theme.Font().Family, Enum.FontWeight.Bold)
end)

Theme.FontSemiBold = compute(function()
	return Font.new(Theme.Font().Family, Enum.FontWeight.SemiBold)
end)

Theme.FontLight = compute(function()
	return Font.new(Theme.Font().Family, Enum.FontWeight.Light)
end)

Theme.FontThin = compute(function()
	return Font.new(Theme.Font().Family, Enum.FontWeight.Thin)
end)

Theme.FontSizeDouble = compute(function()
	return math.round(Theme.FontSize * 2)
end)

Theme.FontSizeLargest = compute(function()
	return math.round(Theme.FontSize * 1.75)
end)

Theme.FontSizeLarger = compute(function()
	return math.round(Theme.FontSize * 1.5)
end)

Theme.FontSizeLarge = compute(function()
	return math.round(Theme.FontSize * 1.25)
end)

Theme.FontSizeSmall = compute(function()
	return math.round(Theme.FontSize * 0.75)
end)

Theme.FontSizeSmaller = compute(function()
	return math.round(Theme.FontSize * 0.5)
end)

Theme.FontSizeSmallest = compute(function()
	return math.round(Theme.FontSize * 0.25)
end)

Theme.PaddingHalf = compute(function()
	local padding = Theme.Padding()
	return UDim.new(padding.Scale / 2, padding.Offset / 2)
end)

Theme.PaddingDouble = compute(function()
	local padding = Theme.Padding()
	return UDim.new(padding.Scale * 2, padding.Offset * 2)
end)

Theme.CornerHalf = compute(function()
	local radius = Theme.CornerRadius()
	return UDim.new(radius.Scale / 2, radius.Offset / 2)
end)

Theme.CornerDiameter = compute(function()
	local radius = Theme.CornerRadius()
	return UDim.new(radius.Scale * 2, radius.Offset * 2)
end)

Theme.ScrollMidImage = state("rbxassetid://18370268668")
Theme.ScrollTopImage = compute(function()
	return if Theme.CornerRadius().Offset == 0 then "rbxassetid://18370268668" else "rbxassetid://105141456035522"
end)
Theme.ScrollBottomImage = compute(function()
	return if Theme.CornerRadius().Offset == 0 then "rbxassetid://18370268668" else "rbxassetid://110012579042362"
end)

return Theme :: typeof(Default) & typeof(Theme)
