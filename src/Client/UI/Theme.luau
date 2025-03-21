local Flux = require(script.Parent.Parent.Parent.Flux)
local compute = Flux.compute
local state = Flux.state

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
local Theme = {
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

	FontSize = state(15),
	Font = state(Enum.Font.Roboto),
	FontMono = state(Enum.Font.RobotoMono),

	CornerRadius = state(UDim.new(0, 8)),
	Padding = state(UDim.new(0, 6)),
	StrokeEnabled = state(true),
	SoundEnabled = state(true),

	TweenIn = state(TweenInfo.new(0.3, Enum.EasingStyle.Cubic, Enum.EasingDirection.In)),
	TweenOut = state(TweenInfo.new(0.3, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)),
	TweenInOut = state(TweenInfo.new(0.3, Enum.EasingStyle.Cubic, Enum.EasingDirection.InOut)),
}

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
	return if use(Theme.CornerRadius).Offset == 0 then "rbxassetid://18370268668" else "rbxassetid://18370266164"
end)
Theme.ScrollBottomImage = compute(function(use)
	return if use(Theme.CornerRadius).Offset == 0 then "rbxassetid://18370268668" else "rbxassetid://18370271296"
end)

return Theme
