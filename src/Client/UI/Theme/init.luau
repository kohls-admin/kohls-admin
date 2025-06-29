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
local Theme = Default

local themes = {}
for _, themeModule: ModuleScript in ThemesFolder:GetChildren() do
	if themeModule:IsA("ModuleScript") then
		if themes[themeModule.Name] then
			warn("Duplicate theme found, make sure they have different names!")
		end
		local theme = require(themeModule)
		local content = {}
		for _, definition in { theme.Image, theme.Sound } do
			for key, value in definition do
				definition[key] = "rbxassetid://" .. value
				table.insert(content, definition[key])
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

		task.spawn(ContentProvider.PreloadAsync, ContentProvider, content)
	end
end
Theme.Themes = themes

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

Theme.TransparencyOverlay = compute(function()
	return Theme.Transparency() * 0.125 + 0.875
end)

Theme.TransparencyClamped = compute(function()
	return math.min(0.75, Theme.Transparency())
end)

Theme.FontHeavy = compute(function()
	local font = Font.fromEnum(Theme.Font())
	font.Weight = Enum.FontWeight.Heavy
	return font
end)

Theme.FontBold = compute(function()
	local font = Font.fromEnum(Theme.Font())
	font.Weight = Enum.FontWeight.Bold
	return font
end)

Theme.FontSemiBold = compute(function()
	local font = Font.fromEnum(Theme.Font())
	font.Weight = Enum.FontWeight.SemiBold
	return font
end)

Theme.FontLight = compute(function()
	local font = Font.fromEnum(Theme.Font())
	font.Weight = Enum.FontWeight.Light
	return font
end)

Theme.FontSizeDouble = compute(function()
	return math.round(Theme.FontSize() * 2)
end)

Theme.FontSizeLargest = compute(function()
	return math.round(Theme.FontSize() * 1.75)
end)

Theme.FontSizeLarger = compute(function()
	return math.round(Theme.FontSize() * 1.5)
end)

Theme.FontSizeLarge = compute(function()
	return math.round(Theme.FontSize() * 1.25)
end)

Theme.FontSizeSmall = compute(function()
	return math.round(Theme.FontSize() * 0.75)
end)

Theme.FontSizeSmaller = compute(function()
	return math.round(Theme.FontSize() * 0.5)
end)

Theme.FontSizeSmallest = compute(function()
	return math.round(Theme.FontSize() * 0.25)
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

return Theme
