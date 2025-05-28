return {
	Transparency = 0.7,
	TextStrokeTransparency = 0.9,

	Primary = Color3.fromRGB(0, 0, 0),
	PrimaryText = Color3.fromRGB(255, 255, 255),

	Secondary = Color3.fromRGB(255, 255, 255),
	SecondaryText = Color3.fromRGB(0, 0, 0),

	Border = Color3.fromRGB(100, 100, 100),

	Valid = Color3.fromRGB(0, 255, 0),
	Invalid = Color3.fromRGB(255, 0, 0),

	FontSize = 18,
	Font = Enum.Font.SourceSans,
	FontMono = Enum.Font.RobotoMono,

	CornerRadius = UDim.new(0, 0),
	Padding = UDim.new(0, 4),
	StrokeEnabled = false,

	TweenIn = TweenInfo.new(0.3, Enum.EasingStyle.Cubic, Enum.EasingDirection.In),
	TweenOut = TweenInfo.new(0.3, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out),
	TweenInOut = TweenInfo.new(0.3, Enum.EasingStyle.Cubic, Enum.EasingDirection.InOut),
}
