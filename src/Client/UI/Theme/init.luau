local Flux = require(script.Parent.Parent.Parent:WaitForChild("Flux"))
local Default = require(script:WaitForChild("Themes"):WaitForChild("Default"))

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

-- import values from default studio theme
for key, value in Default do
	Theme[key] = value
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

Theme.TransparencyOverlay = compute(function(use)
	return use(Theme.Transparency) * 0.125 + 0.875
end)

Theme.TransparencyClamped = compute(function(use)
	return math.min(0.75, use(Theme.Transparency))
end)

Theme.FontHeavy = compute(function(use)
	local font = Font.fromEnum(use(Theme.Font))
	font.Weight = Enum.FontWeight.Heavy
	return font
end)

Theme.FontBold = compute(function(use)
	local font = Font.fromEnum(use(Theme.Font))
	font.Weight = Enum.FontWeight.Bold
	return font
end)

Theme.FontSemiBold = compute(function(use)
	local font = Font.fromEnum(use(Theme.Font))
	font.Weight = Enum.FontWeight.SemiBold
	return font
end)

Theme.FontLight = compute(function(use)
	local font = Font.fromEnum(use(Theme.Font))
	font.Weight = Enum.FontWeight.Light
	return font
end)

Theme.FontSizeDouble = compute(function(use)
	return math.round(use(Theme.FontSize) * 2)
end)

Theme.FontSizeLargest = compute(function(use)
	return math.round(use(Theme.FontSize) * 1.75)
end)

Theme.FontSizeLarger = compute(function(use)
	return math.round(use(Theme.FontSize) * 1.5)
end)

Theme.FontSizeLarge = compute(function(use)
	return math.round(use(Theme.FontSize) * 1.25)
end)

Theme.FontSizeSmall = compute(function(use)
	return math.round(use(Theme.FontSize) * 0.75)
end)

Theme.FontSizeSmaller = compute(function(use)
	return math.round(use(Theme.FontSize) * 0.5)
end)

Theme.FontSizeSmallest = compute(function(use)
	return math.round(use(Theme.FontSize) * 0.25)
end)

Theme.PaddingHalf = compute(function(use)
	local padding = use(Theme.Padding)
	return UDim.new(padding.Scale / 2, padding.Offset / 2)
end)

Theme.PaddingDouble = compute(function(use)
	local padding = use(Theme.Padding)
	return UDim.new(padding.Scale * 2, padding.Offset * 2)
end)

Theme.CornerHalf = compute(function(use)
	local radius = use(Theme.CornerRadius)
	return UDim.new(radius.Scale / 2, radius.Offset / 2)
end)

Theme.CornerDiameter = compute(function(use)
	local radius = use(Theme.CornerRadius)
	return UDim.new(radius.Scale * 2, radius.Offset * 2)
end)

Theme.ScrollMidImage = state("rbxassetid://18370268668")
Theme.ScrollTopImage = compute(function(use)
	return if use(Theme.CornerRadius).Offset == 0 then "rbxassetid://18370268668" else "rbxassetid://105141456035522"
end)
Theme.ScrollBottomImage = compute(function(use)
	return if use(Theme.CornerRadius).Offset == 0 then "rbxassetid://18370268668" else "rbxassetid://110012579042362"
end)

return Theme
