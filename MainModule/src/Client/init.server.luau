-- NOTE: CLIENT ENTRY POINT
-- NOT A SERVER SCRIPT, HAS CLIENT RUNCONTEXT
local _K = require(script.Parent)
local Flux = require(script.Parent.Flux)
local UI = require(script.Parent.Flux.UI).registerChildren()

local LocalPlayer = _K.Services.Players.LocalPlayer

--_K.Remote.Test:FireServer("Hey this is a test!")

local Interface = Flux.new "ScreenGui" {
	Name = "KInterface",
	DisplayOrder = math.huge,
	IgnoreGuiInset = true,
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}

_K.Interface = Interface
_K.hotkeys = {}

require(script.CommandBar):init(_K)

-- implement autocomplete
-- check for start of command and autocomplete it based on _K.Registry.commands
-- TODO: benchmark speed against an array of aliases for fuzzy matching?
-- once a command has been validated start autocompleting the individual arguments

_K.Services.UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
	if gameProcessedEvent then
		return
	end
	if input.UserInputType == Enum.UserInputType.Keyboard then
		for keyName, data in _K.hotkeys do
			if input.KeyCode == data.key or (type(data.key) == "table" and table.find(data.key, input.KeyCode)) then
				task.defer(data.callback)
			end
		end
	end
end)

Interface.Parent = LocalPlayer:WaitForChild("PlayerGui")

local themeList = UI.new "List" {
	Collapsible = true,
	Label = "Theme",

	UI.new "ListItem" {
		Text = "Input Test",
		UI.new "Input" {
			FontSize = 14,
			Padding = UDim.new(0, 5),
			Icon = "rbxassetid://18416000656",
			IconProperties = {
				Size = UDim2.fromOffset(18, 18),
				-- ResampleMode = Enum.ResamplerMode.Pixelated,
			},
		},
	},

	UI.new "ListItem" {
		Text = "Enable typing sounds",
		UI.new "Switch" {
			Value = UI.Theme.ClackEnabled,
		},
	},

	UI.new "ListItem" {
		Text = "Sounds on every TextBox",
		UI.new "Switch" {
			Value = UI.Theme.ClackAll,
		},
	},

	UI.new "ListItem" {
		Text = "Border Enabled Checkbox",
		UI.new "Checkbox" {
			Value = UI.Theme.StrokeEnabled,
		},
	},

	UI.new "ListItem" {
		Text = "Border Enabled",
		UI.new "Switch" {
			Value = UI.Theme.StrokeEnabled,
		},
	},
}

local count = 0
for _, child in themeList._instance.UIContent:GetChildren() do
	if child:IsA("GuiObject") then
		count += 1
	end
end

-- udim options
for i, key in { "CornerRadius", "Padding" } do
	count += 1
	local input
	local slider = UI.new "Slider" {
		Snap = 17,
		Value = UI.Theme[key]._value.Offset + 1,
		UI.new "UIFlexItem" {
			FlexMode = Enum.UIFlexMode.Fill,
		},
		[UI.Hook] = {
			Value = function(value)
				UI.Theme[key]:set(UDim.new(0, value - 1))
				if tonumber(input._input.Text) == value - 1 then
					return
				end
				input._input.Text = value - 1
			end,
		},
	}
	input = UI.new "Input" {
		Font = UI.Theme.FontMono,
		Size = UDim2.new(0, 24, 1, 0),
		FontSize = 14,
		Padding = UDim.new(0, 5),
		IntegerOnly = true,
		NumberRange = NumberRange.new(0, 16),
		Placeholder = "",
		Value = UI.Theme[key]._value.Offset,
		[UI.Hook] = {
			Value = function(value)
				local number = tonumber(value)
				if not number then
					return
				end
				UI.Theme[key]:set(UDim.new(0, number))
				if tonumber(slider.Value._value) == number + 1 then
					return
				end
				slider.Value:set(number + 1)
			end,
		},
	}
	UI.new "ListItem" {
		LayoutOrder = count,
		Parent = themeList._content,
		Text = key:gsub("(.)(%u)", "%1 %2"),
		input,
		slider,
	}
end

do
	count += 1
	local input = UI.new "Input" {
		Font = UI.Theme.FontMono,
		Size = UDim2.new(0, 30, 1, 0),
		FontSize = 14,
		Padding = UDim.new(0, 5),
		NumberOnly = true,
		NumberRange = NumberRange.new(0, 1),
		Placeholder = "",
		Value = UI.Theme.Transparency._value,
		[UI.Hook] = {
			Value = function(value)
				local number = tonumber(value)
				if not number then
					return
				end
				UI.Theme.Transparency:set(number)
			end,
		},
	}
	UI.new "ListItem" {
		LayoutOrder = count,
		Parent = themeList._content,
		Text = "Background Transparency",
		input,
		UI.new "Slider" {
			Value = UI.Theme.Transparency,
			UI.new "UIFlexItem" {
				FlexMode = Enum.UIFlexMode.Fill,
			},
			[UI.Hook] = {
				Value = function(value)
					if tonumber(input._input.Text) == value then
						return
					end
					input._input.Text = value
				end,
			},
		},
	}
end

local colors = {
	"Primary",
	"PrimaryText",
	"Secondary",
	"SecondaryText",
	"Muted",
	"MutedText",
	"Border",
	"BorderMuted",
	"Valid",
	"Invalid",
}

for index, key in colors do
	local state = UI.Theme[key]
	UI.new "ListItem" {
		LayoutOrder = index + count,
		Parent = themeList._instance.UIContent,
		Text = key:gsub("(.)(%u)", "%1 %2") .. " Color",
		UI.new "Color" {
			Value = state,
		},
	}
end

local Settings = UI.new "ScrollingFrame" {
	Name = "Settings",
	BorderSizePixel = 0,
	BackgroundTransparency = 1,
	Size = UDim2.new(1, 0, 1, 0),
	ScrollBarThickness = 8,
	ScrollBarImageColor3 = UI.Theme.Secondary,
	ScrollBarImageTransparency = UI.Theme.TransparencyClamped,
	TopImage = UI.Theme.ScrollTopImage,
	MidImage = UI.Theme.ScrollMidImage,
	BottomImage = UI.Theme.ScrollBottomImage,
	CanvasSize = UDim2.new(0, 0, 0, 0),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,

	UI.new "UIListLayout" { SortOrder = Enum.SortOrder.LayoutOrder },
	themeList,
}

local testList = {}
for i = 1, 1e5 do
	testList[i] = i .. ": this is a test log, let's see just how terrible we can make this stress test."
end
table.insert(testList, #testList / 2, "needle")

local scrollerTest = UI.new "ScrollerFast" {
	List = testList,
	UI.new "UIFlexItem" {
		FlexMode = Enum.UIFlexMode.Fill,
	},
}

local scrollerInput = UI.new "Input" {
	Placeholder = "Search logs...",
	Icon = "rbxassetid://18416000656",
	IconProperties = {
		Size = UDim2.fromOffset(18, 18),
		-- ResampleMode = Enum.ResamplerMode.Pixelated,
	},
}

scrollerInput._input:GetPropertyChangedSignal("Text"):Connect(function()
	scrollerTest:refreshList()
end)

local scrollerFrame = UI.new "Frame" {
	BackgroundTransparency = 1,
	Size = UDim2.new(1, 0, 1, 0),
	UI.new "UIListLayout" { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UI.Theme.Padding },
	scrollerInput,
	scrollerTest,
}

local function filterTest(list)
	local filter = scrollerInput._input.Text:lower()
	local new = {}
	for i, v in list do
		if v:lower():find(filter, 1, true) then
			table.insert(new, v)
		end
	end
	return new
end

scrollerTest:filter(filterTest)

local _uiTestWindow = UI.new "Window" {
	Parent = UI.LayerDefault,
	Title = "Flux UI Test",

	UI.new "Tabs" {
		scrollerFrame,
		Settings,
		UI.new "ColorPicker" {},
	},
}

-- NOTE: NEW INTERFACE FRAMEWORK TEST
-- local test = UI.new "Window" {
-- 	Parent = UI.LayerDefault,
--
-- 	[UI.Children] = {
-- 		Tabs = UI.new "Tabs" {
-- 			[UI.Children] = {
-- 				ListFrame = UI.new "Frame" {
-- 					Size = UDim2.new(1, 0, 1, 0),
-- 					BackgroundTransparency = 1,
-- 					[UI.Children] = {
-- 						Layout = UI.new "UIListLayout" {},
-- 						List = UI.new "List" {
-- 							Collapsible = true,
-- 							Label = "This is a test THIS IS A TEST",
-- 							[UI.Children] = {
-- 								Button = UI.new "Button" {},
-- 								Button2 = UI.new "Button" {},
-- 								Button3 = UI.new "Button" {},
-- 								Button4 = UI.new "Button" {},
-- 								Select = UI.new "Select" {
-- 									UI.new "Tooltip" {},
-- 								},
-- 							},
-- 						},
-- 						List2 = UI.new "List" {
-- 							Collapsible = true,
-- 							Label = "This is a test2 THIS IS A TEST2",
-- 							[UI.Children] = {
-- 								Button = UI.new "Button" {},
-- 								Button2 = UI.new "Button" {},
-- 								Button3 = UI.new "Button" {},
-- 								Button4 = UI.new "Button" {},
-- 							},
-- 						},
-- 					},
-- 				},
-- 				Snap = UI.new "Slider" {
-- 					Snap = 5,
-- 					[UI.Hook] = {
-- 						Value = function(value)
-- 							print("Slider value changed", value)
-- 						end,
-- 					},
-- 				},
-- 				Vertical = UI.new "Slider" {
-- 					Vertical = true,
-- 					[UI.Hook] = {
-- 						Value = function(value)
-- 							print("Slider snap value changed", value)
-- 						end,
-- 					},
-- 					[UI.Children] = {
-- 						Flex = UI.new "UIFlexItem" {
-- 							FlexMode = Enum.UIFlexMode.Fill,
-- 						},
-- 					},
-- 				},
-- 				Switch = UI.new "Switch" {
-- 					[UI.Hook] = {
-- 						Value = function(value)
-- 							print("Switch value changed", value)
-- 						end,
-- 					},
-- 				},
-- 				Color = UI.new "ColorPicker" {
-- 					[UI.Hook] = {
-- 						Value = function(value)
-- 							print("Color value changed", value)
-- 						end,
-- 					},
-- 				},
-- 			},
-- 		},
-- 	},
-- }
-- local test = UI.new "Frame" {
-- 	Parent = Interface,
-- 	BackgroundTransparency = 0.3,
-- 	BackgroundColor3 = Color3.new(),
-- 	AnchorPoint = Vector2.new(0.5, 0.5),
-- 	Position = UDim2.new(0.5, 0, 0.5, 0),
-- 	Size = UDim2.new(0, 512, 0, 512),
--
-- 	[UI.Children] = {
-- 		UICorner = UI.new "UICorner" {
-- 			CornerRadius = UDim.new(0, 16),
-- 		},
-- 		Padding = UI.new "UIPadding" {
-- 			PaddingLeft = UDim.new(0, 8),
-- 			PaddingRight = UDim.new(0, 8),
-- 			PaddingTop = UDim.new(0, 8),
-- 			PaddingBottom = UDim.new(0, 8),
-- 		},
-- 		ListLayout = UI.new "UIListLayout" {
-- 			Padding = UDim.new(0, 8),
-- 		},
-- 		Button = UI.new "Button" {
-- 			BackgroundColor3 = Color3.fromRGB(200, 0, 0),
-- 			Size = UDim2.new(0, 32, 0, 32),
-- 			Text = "",
-- 			Icon = "rbxassetid://1476571006",
-- 			IconProperties = {
-- 				AnchorPoint = Vector2.new(0.5, 0.5),
-- 				Size = UDim2.new(0, 10, 0, 10),
-- 				Position = UDim2.new(0.5, 0, 0.5, 0),
-- 				ResampleMode = Enum.ResamplerMode.Pixelated,
-- 			},
-- 			Activated = function()
-- 				print("Test button pressed!")
-- 			end,
-- 		},
-- 		Test = UI.new "Slider" {
-- 			Snap = 5,
-- 			[UI.Hook] = {
-- 				Value = function(value)
-- 					print("Slider value changed", value)
-- 				end,
-- 			},
-- 		},
-- 		Test2 = UI.new "Slider" {
-- 			Vertical = true,
-- 			[UI.Hook] = {
-- 				Value = function(value)
-- 					print("Slider snap value changed", value)
-- 				end,
-- 			},
-- 			[UI.Children] = {
-- 				Flex = UI.new "UIFlexItem" {
-- 					FlexMode = Enum.UIFlexMode.Fill,
-- 				},
-- 			},
-- 		},
-- 		Lol = UI.new "Switch" {
-- 			[UI.Hook] = {
-- 				Value = function(value)
-- 					print("Switch value changed", value)
-- 				end,
-- 			},
-- 		},
-- 		Color = UI.new "ColorPicker" {
-- 			[UI.Hook] = {
-- 				Value = function(value)
-- 					print("Color value changed", value)
-- 				end,
-- 			},
-- 		},
-- 	},
-- }
