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

function Settings.new(_K)
	local UI = _K.UI

	local settingsDialog
	local pendingChanges = {}

	local function resetChanges()
		table.clear(pendingChanges)
		for key, value in _K.Data.settings do
			if string.find(key, "theme", 1, true) == 1 then
				local themeKey = string.sub(key, 6)
				UI.Theme[themeKey]:set(value)
			end
		end
	end

	local function confirmChanges()
		_K.Remote.Settings:FireServer(pendingChanges)
		for key, value in pendingChanges do
			_K.Data.settings[key] = value
			if _K.client.settings[key] then
				_K.client.settings[key]:set(value, key == "prefix")
			end
		end
		table.clear(pendingChanges)
	end

	local function change(key, value)
		if not _K.client.ready then
			return
		end
		pendingChanges[key] = value

		local different = false
		for key, value in pendingChanges do
			if value ~= _K.Data.settings[key] then
				different = true
				break
			end
		end

		if settingsDialog then
			settingsDialog._instance.Visible = different
		end
	end

	local settingsScroller = UI.new "Scroller" {
		UI.new "UIFlexItem" {
			FlexMode = Enum.UIFlexMode.Fill,
		},
	}

	local lineItemHeight = UI.compute(function(use)
		return use(UI.Theme.FontSize) + use(UI.Theme.Padding).Offset
	end)

	local reservedPrefixes = { ",", " ", "`", '"', "@", "$", "%", "*", "~" }
	local settingsLineItems = {
		Local = {
			-- FIX: prevent selecting reserved characters (comma, space, !@#$%^&*, `, ")
			-- TODO: customizable listable/argument delimiter?
			UI.new "ListItem" {
				ContentAutomaticSize = false,
				Text = "Command Bar Hotkey",
				UI.new "Input" {
					Font = UI.Theme.FontMono,
					Size = UI.computeFrom(UDim2.new, 1, 0, 0, lineItemHeight),
					FontSize = UI.Theme.FontSize,
					Padding = UDim.new(0, 5),
					Placeholder = ";",
					HotkeyInput = true,
					Value = UI.UserInputService:GetStringForKeyCode(_K.client.hotkeys.commandBar.key._value),
					Hotkey = _K.client.hotkeys.commandBar.key,
					Modifiers = _K.client.hotkeys.commandBar.mods,
				},
			},
			UI.new "ListItem" {
				ContentAutomaticSize = false,
				Text = "Dashboard Hotkey",
				UI.new "Input" {
					Font = UI.Theme.FontMono,
					Size = UI.computeFrom(UDim2.new, 1, 0, 0, lineItemHeight),
					FontSize = 14,
					Padding = UDim.new(0, 5),
					Placeholder = "'",
					HotkeyInput = true,
					Value = UI.UserInputService:GetStringForKeyCode(_K.client.hotkeys.dashboard.key._value),
					Hotkey = _K.client.hotkeys.dashboard.key,
					Modifiers = _K.client.hotkeys.dashboard.mods,
				},
			},
			UI.new "ListItem" {
				ContentAutomaticSize = false,
				Text = "Command Prefix",
				UI.new "Input" {
					Font = UI.Theme.FontMono,
					Size = UI.computeFrom(UDim2.new, 0, 24, 0, lineItemHeight),
					FontSize = 14,
					Padding = UDim.new(0, 5),
					Placeholder = ";",
					MaxChars = 1,
					Value = UI.compute(function(use)
						return use(_K.client.settings.playerPrefix)[UI.LocalPlayer.UserId]
							or use(_K.client.settings.prefix)[1]
					end),
					Validate = function(text)
						return not (text == "" or table.find(reservedPrefixes, text))
					end,

					[UI.Hook] = {
						Selected = function(value)
							_K.Data.settings.playerPrefix[UI.LocalPlayer.UserId] = value
							_K.client.settings.playerPrefix:set(_K.Data.settings.playerPrefix, true)
							_K.Remote.PlayerPrefix:FireServer(value)
						end,
					},
				},
			},
		},
		General = {
			UI.new "ListItem" {
				ContentAutomaticSize = false,
				Text = "Default Command Prefix",
				UI.new "Input" {
					Font = UI.Theme.FontMono,
					Size = UI.computeFrom(UDim2.new, 0, 24, 0, lineItemHeight),
					FontSize = 14,
					Padding = UDim.new(0, 5),
					Placeholder = ";",
					MaxChars = 1,
					Value = UI.compute(function(use)
						return use(_K.client.settings.prefix)[1]
					end),
					Validate = function(text)
						return not (text == "" or table.find(reservedPrefixes, text))
					end,

					[UI.Hook] = {
						Selected = function(value)
							_K.client.settings.prefix._value[1] = value
							change("prefix", _K.client.settings.prefix._value)
						end,
					},
				},
			},
		},
		Theme = {},
	}

	task.defer(function()
		_K.Util.Defer.reset()
		-- switches
		for _, data in
			{
				{ key = "SoundEnabled", text = "UI Sounds Enabled" },
				{
					key = "ClackEnabled",
					text = "Enable typing sounds",
					tip = "<b>NOTE:</b> Requires taking the audios and adding permissions to your game!\n<font transparency='0.66'>Why does Roblox do this to me</font> 😔",
				},
				{ key = "ClackAll", text = "Sounds on every TextBox" },
				{ key = "StrokeEnabled", text = "UI Borders Enabled" },
			}
		do
			table.insert(
				settingsLineItems.Theme,
				UI.new "ListItem" {
					Text = data.text,
					UI.new "Switch" {
						Value = UI.Theme[data.key],

						[UI.Hook] = {
							Selected = function(value)
								change("theme" .. data.key, value)
							end,
						},
					},
					if data.tip
						then UI.new "Tooltip" {
							Text = data.tip,
							TextXAlignment = Enum.TextXAlignment.Left,
						}
						else nil,
				}
			)
		end

		-- font faces
		do
			for _, key in { "Font", "FontMono" } do
				_K.Util.Defer.wait()
				table.insert(
					settingsLineItems.Theme,
					UI.new "ListItem" {
						ContentAutomaticSize = false,
						Text = key:gsub("(.)(%u)", "%1 %2"),
						UI.new "Select" {
							Choice = UI.Theme[key],
							Choices = Enum.Font:GetEnumItems(),
							[UI.Hook] = {
								Selected = function(value)
									change("theme" .. key, value)
								end,
							},
						},
					}
				)
			end
		end
		_K.Util.Defer.wait()

		local sliderInputSize = UI.computeFrom(UDim2.new, 0, 37, 0, lineItemHeight)

		do -- Font Size
			table.insert(
				settingsLineItems.Theme,
				UI.new "ListItem" {
					ContentAutomaticSize = false,
					Text = "Font Size",
					UI.new "Input" {
						Font = UI.Theme.FontMono,
						Size = sliderInputSize,
						FontSize = 14,
						Padding = UDim.new(0, 5),
						NumberOnly = true,
						NumberRange = NumberRange.new(8, 32),
						Placeholder = "",
						Value = UI.Theme.FontSize,
						[UI.Hook] = {
							Selected = function(value)
								local number = tonumber(value)
								if not number then
									return
								end
								change("themeFontSize", number)
							end,
						},
					},
					UI.new "Slider" {
						Snap = 25,
						Value = UI.compute(function(use)
							return math.clamp(use(UI.Theme.FontSize) - 7, 1, 25)
						end),
						UI.new "UIFlexItem" {
							FlexMode = Enum.UIFlexMode.Fill,
						},
						[UI.Hook] = {
							Selected = function(value)
								UI.Theme.FontSize:set(value + 7)
								change("themeFontSize", value + 7)
							end,
						},
					},
				}
			)
		end
		_K.Util.Defer.wait()

		-- UDim options
		for i, key in { "CornerRadius", "Padding" } do
			table.insert(
				settingsLineItems.Theme,
				UI.new "ListItem" {
					ContentAutomaticSize = false,
					Text = key:gsub("(.)(%u)", "%1 %2"),
					UI.new "Input" {
						Font = UI.Theme.FontMono,
						Size = sliderInputSize,
						FontSize = 14,
						Padding = UDim.new(0, 5),
						NumberOnly = true,
						NumberRange = NumberRange.new(0, 16),
						Placeholder = "",
						Value = UI.compute(function(use)
							return use(UI.Theme[key]).Offset
						end),
						[UI.Hook] = {
							Selected = function(value)
								local number = tonumber(value)
								if not number then
									return
								end
								value = UDim.new(0, number)
								UI.Theme[key]:set(value)
								change("theme" .. key, value)
							end,
						},
					},
					UI.new "Slider" {
						Snap = 17,
						Value = UI.compute(function(use)
							return math.clamp(use(UI.Theme[key]).Offset + 1, 1, 17)
						end),
						UI.new "UIFlexItem" {
							FlexMode = Enum.UIFlexMode.Fill,
						},
						[UI.Hook] = {
							Selected = function(value)
								value = UDim.new(0, value - 1)
								UI.Theme[key]:set(value)
								change("theme" .. key, value)
							end,
						},
					},
				}
			)
		end
		_K.Util.Defer.wait()

		do -- Background Transparency
			table.insert(
				settingsLineItems.Theme,
				UI.new "ListItem" {
					ContentAutomaticSize = false,
					Text = "Background Transparency",
					UI.new "Input" {
						Font = UI.Theme.FontMono,
						Size = sliderInputSize,
						FontSize = 14,
						Padding = UDim.new(0, 5),
						MaxChars = 4,
						NumberOnly = true,
						NumberRange = NumberRange.new(0, 1),
						Placeholder = "",
						Value = UI.compute(function(use)
							return use(UI.Theme.Transparency)
						end),
						[UI.Hook] = {
							Selected = function(value)
								local number = tonumber(value)
								if not tonumber(value) then
									return
								end
								UI.Theme.Transparency:set(number)
								change("themeTransparency", number)
							end,
						},
					},
					UI.new "Slider" {
						Value = UI.Theme.Transparency,
						UI.new "UIFlexItem" {
							FlexMode = Enum.UIFlexMode.Fill,
						},
						[UI.Hook] = {
							Selected = function(value)
								change("themeTransparency", value)
							end,
						},
					},
				}
			)
		end

		-- Color options
		for index, key in colors do
			_K.Util.Defer.wait()
			local state = UI.Theme[key]
			local dataKey = "theme" .. key
			table.insert(
				settingsLineItems.Theme,
				UI.new "ListItem" {
					Text = key:gsub("(.)(%u)", "%1 %2") .. " Color",
					UI.new "Color" {
						Value = state,
						[UI.Hook] = {
							Selected = function(value)
								change(dataKey, value)
							end,
						},
					},
				}
			)
		end

		local keyOrder = { "general", "theme" }
		for key, lineItems in settingsLineItems do
			if key == "Theme" then -- don't show Theme if user isn't able to modify them.
				if Settings._K.Data.settings.dashboardThemeAuthority == "Server" then
					continue
				end
				if
					Settings._K.Data.settings.dashboardThemeAuthority == "Shared"
					and not (Settings._K.Auth.hasPermission(Settings._K.Service.Players.LocalPlayer.UserId, "settings"))
				then
					continue
				end
			end

			if
				key == "General"
				and not (_K.Auth.hasPermission(Settings._K.Service.Players.LocalPlayer.UserId, "settings"))
			then
				continue
			end

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
	end)

	settingsDialog = UI.new "Dialog" {
		BackgroundTransparency = UI.Theme.TransparencyOverlay,
		BackgroundColor3 = UI.Theme.Secondary,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.fromScale(1, 0),
		ActionText = "Save changes"
			.. (_K.Data.settings.themeAuthority == "Server" and " and update for everyone?" or "?"),
		Action = true,
		LeftAction = true,
		RightAction = true,
		Visible = false,
		Close = function(self)
			task.defer(self.Activated.set, self.Activated, false)
		end,

		[UI.Hook] = {
			Action = function(v)
				settingsDialog._instance.Visible = false
				if v then
					confirmChanges()
				else
					resetChanges()
				end
			end,
		},
	}
	settingsDialog._content:Destroy()

	local settingsFrame = UI.new "Frame" {
		Name = "Settings",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0),

		UI.new "UIListLayout" { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UI.Theme.Padding },
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
							local found = string.find(string.lower(rawText), filter, 1, true)
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
		settingsScroller,
		settingsDialog,
	}

	return settingsFrame
end

return Settings
