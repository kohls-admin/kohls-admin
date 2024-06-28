local LocalPlayer = game.Players.LocalPlayer
local UI = require(script.Parent.UI)

local app = UI.new("ScreenGui", {
	Name = "App",
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Window = UI.new("Window", {
		Tabs = UI.new("Tabs", {
			--Test = UI.new('TextArea', {Placeholder = 'Potato test'});
			FrameTest = UI.new("Frame", {
				LayoutOrder = 1,
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 1, 0),
				Layout = UI.new("UIListLayout"),
				List = UI.new("List", {
					Title = "TEST LIST",
					Button = UI.new("Button", { Text = "Test Button", Size = UDim2.new(1, 0, 0, 32) }),
					Checkbox = UI.new(
						"Checkbox",
						{ Indeterminate = true, Tip = UI.new("Tooltip", { Text = "Potato tooltip test yo" }) }
					),
					Slider = UI.new("Slider", { Snap = 5, Size = UDim2.new(1, 0, 0, 32) }),
					Select = UI.new("Select", {
						Choice = "TestChoice1",
						Options = {
							"TestChoice1",
							"TestChoice2",
							"TestChoice3",
							"TestChoice4",
							"TestChoice5",
							"TestChoice6",
							"TestChoice7",
							"TestChoice8",
							"TestChoice9",
							"TestChoice10",
						},
						Size = UDim2.new(1, 0, 0, 32),
					}),
				}),
				List2 = UI.new("List", {
					Title = "test list 2",
					Button = UI.new("Button", { Text = "Test Button" }),
					Checkbox = UI.new("Checkbox", { Checked = true }),
					Slider = UI.new("Slider", { Snap = 5 }),
					Select = UI.new("Select", {
						Choice = "TestChoice1",
						Options = { "TestChoice1", "TestChoice2", "TestChoice3" },
					}),
				}),
			}),
			Button = UI.new("Button", { Text = "Test Button", LayoutOrder = 2 }),
			Button2 = UI.new("Button", { Text = "Test Button", LayoutOrder = 3 }),
			ExtraTab = UI.new("Button", { Text = "Test Button", LayoutOrder = 4 }),
			ExtraTab2 = UI.new("Button", { Text = "Test Button", LayoutOrder = 5 }),
			ExtraTab3 = UI.new("Button", { Text = "Test Button", LayoutOrder = 6 }),
			ExtraTab4 = UI.new("Button", { Text = "Test Button", LayoutOrder = 7 }),
			ExtraTab5 = UI.new("Button", { Text = "Test Button", LayoutOrder = 8 }),
		}),
	}),
})

app.Parent = LocalPlayer:WaitForChild("PlayerGui")

return true
