local Settings = {}
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

function Settings.new(_K)
	local UI = _K.UI

	local settingsLineItems = {
		General = {
			-- FIX: prevent selecting reserved characters (comma, space, !@#$%^&*)
			-- TODO: consider allowing argument prefixes?
			UI.new "ListItem" {
				Text = "Command Prefix",
				UI.new "Input" {
					Font = UI.Theme.FontMono,
					Size = UDim2.new(0, 24, 1, 0),
					FontSize = 14,
					Padding = UDim.new(0, 5),
					Placeholder = ";",
					MaxChars = 1,
					Value = _K.settings.prefix,
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
					Value = UI.UserInputService:GetStringForKeyCode(_K.hotkeys.commandBar.key._value),
					Hotkey = _K.hotkeys.commandBar.key,
					Modifiers = _K.hotkeys.commandBar.mods,
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
		},
	}

	-- UDim options
	for i, key in { "CornerRadius", "Padding" } do
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
		table.insert(
			settingsLineItems.Theme,
			UI.new "ListItem" {
				Text = key:gsub("(.)(%u)", "%1 %2"),
				input,
				slider,
			}
		)
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
				},
			}
		)
	end

	local settingsScroller = UI.new "Scroller" {
		Name = "Settings",

		UI.new "Input" {
			Placeholder = "Search",
			Icon = "rbxassetid://18416000656",
			IconProperties = {
				Size = UDim2.fromOffset(18, 18),
			},
			[UI.Hook] = {
				Value = function(value)
					print(`input value "{value}"`)
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
									_K.Util.escapeRichText(string.sub(rawText, 1, found - 1)),
									_K.Util.escapeRichText(string.sub(rawText, found, found + #filter - 1)),
									_K.Util.escapeRichText(string.sub(rawText, found + #filter))
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
