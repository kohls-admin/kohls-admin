local Settings = { _K = nil }
Settings.__index = Settings

local filterRichFormat = `<font transparency="0.5">%s</font><b>%s</b><font transparency="0.5">%s</font>`
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

local debounceNetwork = {}

function Settings.network(key, value)
	local debounce = debounceNetwork[key]
		or Settings._K.Util.Function.debounce(1, function(key, value)
			Settings._K.Remote.Setting:FireServer(key, value)
		end)

	if not debounceNetwork[key] then
		debounceNetwork[key] = debounce
	end

	return debounce(key, value)
end

function Settings.new(_K)
	Settings._K = _K
	local UI = _K.client.UI

	local settingsLineItems = {
		General = {
			-- FIX: prevent selecting reserved characters (comma, space, !@#$%^&*)
			-- TODO: consider allowing argument prefixes?
			-- UI.new "ListItem" {
			-- 	Text = "Local Command Prefix",
			-- 	UI.new "Input" {
			-- 		Font = UI.Theme.FontMono,
			-- 		Size = UDim2.new(0, 24, 1, 0),
			-- 		FontSize = 14,
			-- 		Padding = UDim.new(0, 5),
			-- 		Placeholder = ";",
			-- 		MaxChars = 1,
			-- 		Value = UI.Scope.settings.prefix,
			--
			-- 		[UI.Hook] = {
			-- 			Value = function(value)
			-- 				_K.Remote.Prefix:FireServer(value)
			-- 			end,
			-- 		},
			-- 	},
			-- },
			UI.new "ListItem" {
				Text = "Command Prefix",
				UI.new "Input" {
					Font = UI.Theme.FontMono,
					Size = UDim2.new(0, 24, 1, 0),
					FontSize = 14,
					Padding = UDim.new(0, 5),
					Placeholder = ";",
					MaxChars = 1,
					Value = UI.Scope.settings.prefix,

					[UI.Hook] = {
						Value = function(value)
							Settings.network("prefix", value)
						end,
					},
				},
			},
			UI.new "ListItem" {
				Text = "Command Bar Hotkey",
				UI.new "Input" {
					Font = UI.Theme.FontMono,
					Size = UDim2.new(1, 0, 1, 0),
					FontSize = 14,
					Padding = UDim.new(0, 5),
					Placeholder = ";",
					HotkeyInput = true,
					Value = UI.UserInputService:GetStringForKeyCode(_K.client.hotkeys.commandBar.key._value),
					Hotkey = _K.client.hotkeys.commandBar.key,
					Modifiers = _K.client.hotkeys.commandBar.mods,
				},
			},
			UI.new "ListItem" {
				Text = "Dashboard Hotkey",
				UI.new "Input" {
					Font = UI.Theme.FontMono,
					Size = UDim2.new(1, 0, 1, 0),
					FontSize = 14,
					Padding = UDim.new(0, 5),
					Placeholder = "'",
					HotkeyInput = true,
					Value = UI.UserInputService:GetStringForKeyCode(_K.client.hotkeys.dashboard.key._value),
					Hotkey = _K.client.hotkeys.dashboard.key,
					Modifiers = _K.client.hotkeys.dashboard.mods,
				},
			},
		},
		Theme = {
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
				Text = "Border Enabled",
				UI.new "Switch" {
					Value = UI.Theme.StrokeEnabled,

					[UI.Hook] = {
						Value = function(value)
							Settings.network("themeStrokeEnabled", value)
						end,
					},
				},
			},
		},
	}

	-- font faces
	do
		local font = UI.new "Select" {
			Choice = UI.Theme.Font._value.Name,
			Choices = Enum.Font:GetEnumItems(),
			[UI.Hook] = {
				Choice = function(value)
					if Enum.Font[value] == _K.Data.settings.themeFont then
						return
					end
					UI.Theme.Font:set(Enum.Font[value])
					_K.Remote.Setting:FireServer("themeFont", value)
				end,
			},
		}
		local fontMono = UI.new "Select" {
			Choice = UI.Theme.FontMono._value.Name,
			Choices = Enum.Font:GetEnumItems(),
			[UI.Hook] = {
				Choice = function(value)
					if Enum.Font[value] == _K.Data.settings.themeFontMono then
						return
					end
					UI.Theme.FontMono:set(Enum.Font[value])
					_K.Remote.Setting:FireServer("themeFontMono", value)
				end,
			},
		}

		UI.Theme.Font:hook(function(value)
			font.Choice:set(value.Name)
		end)
		UI.Theme.FontMono:hook(function(value)
			fontMono.Choice:set(value.Name)
		end)

		table.insert(
			settingsLineItems.Theme,
			UI.new "ListItem" {
				Text = "Font",
				font,
			}
		)
		table.insert(
			settingsLineItems.Theme,
			UI.new "ListItem" {
				Text = "Font Mono",
				fontMono,
			}
		)
	end

	-- font size
	do
		local input, lastChange
		local slider = UI.new "Slider" {
			Snap = 25,
			Value = math.clamp(UI.Theme.FontSize._value - 7, 1, 25),
			UI.new "UIFlexItem" {
				FlexMode = Enum.UIFlexMode.Fill,
			},
			[UI.Hook] = {
				Value = function(value)
					lastChange = value + 7
					UI.Theme.FontSize:set(value + 7)
					if tonumber(input._input.Text) == value + 7 then
						return
					end
					input._input.Text = value + 7

					Settings.network("themeFontSize", value + 7)
				end,
			},
		}
		input = UI.new "Input" {
			Font = UI.Theme.FontMono,
			Size = UDim2.new(0, 30, 1, 0),
			FontSize = 14,
			Padding = UDim.new(0, 5),
			NumberOnly = true,
			NumberRange = NumberRange.new(8, 32),
			Placeholder = "",
			Value = UI.Theme.FontSize._value,
			[UI.Hook] = {
				Value = function(value)
					local number = tonumber(value)
					if not number then
						return
					end
					UI.Theme.FontSize:set(number)
					if tonumber(slider.Value._value) == number - 7 then
						return
					end
					slider.Value:set(number - 7)
				end,
			},
		}
		table.insert(
			settingsLineItems.Theme,
			UI.new "ListItem" {
				Text = "Font Size",
				input,
				slider,
			}
		)
		UI.Theme.FontSize:hook(function(value)
			if lastChange ~= value then
				slider.Value:set(value - 7)
				input._input.Text = value
			end
		end)
	end

	-- UDim options
	for i, key in { "CornerRadius", "Padding" } do
		local input, lastChange
		local slider = UI.new "Slider" {
			Snap = 17,
			Value = UI.Theme[key]._value.Offset + 1,
			UI.new "UIFlexItem" {
				FlexMode = Enum.UIFlexMode.Fill,
			},
			[UI.Hook] = {
				Value = function(value)
					value -= 1
					lastChange = value
					UI.Theme[key]:set(UDim.new(0, value))
					if tonumber(input._input.Text) == value then
						return
					end
					input._input.Text = value

					Settings.network("theme" .. key, value)
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
		table.insert(
			settingsLineItems.Theme,
			UI.new "ListItem" {
				Text = key:gsub("(.)(%u)", "%1 %2"),
				input,
				slider,
			}
		)
		UI.Theme[key]:hook(function(value)
			value = value.Offset
			if lastChange ~= value then
				slider.Value:set(value + 1)
				input._input.Text = value
			end
		end)
	end

	do
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

					Settings.network("themeTransparency", number)
				end,
			},
		}
		table.insert(
			settingsLineItems.Theme,
			UI.new "ListItem" {
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
		)
	end

	-- Color options
	for index, key in colors do
		local state = UI.Theme[key]
		table.insert(
			settingsLineItems.Theme,
			UI.new "ListItem" {
				Text = key:gsub("(.)(%u)", "%1 %2") .. " Color",
				UI.new "Color" {
					Value = state,

					[UI.Hook] = {
						Value = function(value)
							Settings.network("theme" .. key, value)
						end,
					},
				},
			}
		)
	end

	local settingsScroller = UI.new "Scroller" {
		Name = "Settings",
		ClipsDescendants = false,

		UI.new "Input" {
			Placeholder = "Search",
			Icon = "rbxassetid://18416000656",
			IconProperties = {
				Size = UDim2.fromOffset(18, 18),
			},
			[UI.Hook] = {
				Value = function(value)
					-- filter settings
					local filter = string.lower(value)
					for _, lineItems in settingsLineItems do
						for _, lineItem in lineItems do
							if value == "" then
								lineItem.Text:set(lineItem._instance.Name)
								lineItem._instance.Visible = true
								continue
							end
							local rawText = lineItem._instance.Name
							local found = string.find(string.lower(rawText), filter)
							local text = if found
								then string.format(
									filterRichFormat,
									_K.Util.String.escapeRichText(string.sub(rawText, 1, found - 1)),
									_K.Util.String.escapeRichText(string.sub(rawText, found, found + #filter - 1)),
									_K.Util.String.escapeRichText(string.sub(rawText, found + #filter))
								)
								else rawText
							lineItem.Text:set(text)
							lineItem._instance.Visible = found
						end
					end
				end,
			},
		},
	}

	local keyOrder = { "general", "theme" }
	for key, lineItems in settingsLineItems do
		local list = UI.new "List" {
			Parent = settingsScroller,
			Name = key,
			Label = key,
			Collapsible = true,
			LayoutOrder = table.find(keyOrder, string.lower(key)),
		}
		for index, lineItem in ipairs(lineItems) do
			UI.edit(lineItem, {
				LayoutOrder = index,
				Parent = list,
			})
		end
	end

	return settingsScroller
end

return Settings
