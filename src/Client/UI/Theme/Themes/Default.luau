return {
	Transparency = 0.08,
	TextStrokeTransparency = 0.875,

	Primary = Color3.fromRGB(18, 18, 21),
	PrimaryText = Color3.fromRGB(255, 255, 255),

	Secondary = Color3.fromRGB(255, 255, 255),
	SecondaryText = Color3.fromRGB(0, 0, 0),

	Border = Color3.fromRGB(100, 100, 100),

	Valid = Color3.fromRGB(0, 255, 0),
	Invalid = Color3.fromRGB(255, 0, 0),

	FontSize = 15,
	Font = Enum.Font.Roboto,
	FontMono = Enum.Font.RobotoMono,

	CornerRadius = UDim.new(0, 8),
	Padding = UDim.new(0, 6),
	StrokeEnabled = false,

	TweenIn = TweenInfo.new(0.3, Enum.EasingStyle.Cubic, Enum.EasingDirection.In),
	TweenOut = TweenInfo.new(0.3, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out),
	TweenInOut = TweenInfo.new(0.3, Enum.EasingStyle.Cubic, Enum.EasingDirection.InOut),

	Image = {
		Add = "75463072948156",
		Check = "125053493387464",
		Close = "117385134461283",
		Check_Bold = "73008384795860",
		Close_Bold = "74789968601408",
		Edit = "76957302873541",
		Filter = "93483633020282",
		Search = "82890781874034",
		Terminal = "108121111850606",

		Down = "116491276097788",

		Play = "113952858544170",
		Stop = "94423843228984",
	},

	SoundEnabled = true,
	TypingSounds = true,
	TypingSoundsOnEveryTextBox = true,
	Volume = 1,

	Sound = {
		Back = "10066914500",
		Call_Accept = "17208209318",
		Call_Decline = "17208214688",
		Call_Hangup = "17208220181",
		Call_Leave = "17208295577",
		Hello = "17208335138",
		Hover01 = "17208339919",
		Hover02 = "17208343514",
		Hover03 = "17208348006",
		Negative = "17208353912",
		Notification_High = "17208361335",
		Notification_Low = "17208372272",
		PopSwipe = "10128766965",
		Select01 = "10128760939",
		Select02 = "10066968815",
		Select03 = "17208396156",
		Swipe = "17208405682",
	},
}
