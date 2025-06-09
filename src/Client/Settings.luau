local Settings = { _K = nil }
Settings.__index = Settings

local filterRichFormat = `<font transparency="0.5">%s</font><b>%s</b><font transparency="0.5">%s</font>`
local colors = {
	"Primary",
	"PrimaryText",
	"Secondary",
	"SecondaryText",
	"Border",
	"Valid",
	"Invalid",
}

function Settings.new(_K)
	local UI = _K.UI

	local settingsDialog
	local originalValues = {}
	local pendingChanges = {}

	local function resetChanges()
		for key, value in originalValues do
			_K.Data.settings[key] = value
			if _K.client.settings[key] then
				_K.client.settings[key]:set(value, true)
			end
		end
		table.clear(originalValues)
		table.clear(pendingChanges)
	end

	local function confirmChanges()
		_K.Remote.Settings:FireServer(pendingChanges)
		for key, value in pendingChanges do
			_K.Data.settings[key] = value
			if _K.client.settings[key] then
				_K.client.settings[key]:set(value, true)
			end
		end
		table.clear(originalValues)
		table.clear(pendingChanges)
	end

	local function change(key, value)
		if not _K.client.ready then
			return
		end
		pendingChanges[key] = value
		if not originalValues[key] then
			originalValues[key] = _K.Data.settings[key]
		end

		local different = false
		local differentTheme = false
		for key, value in pendingChanges do
			if string.find(key, "theme", 1, true) == 1 then
				local themeModule = _K.client.themes._value[_K.Data.settings.defaultTheme]
				if themeModule and UI.peek(themeModule[string.sub(key, 6)]) ~= value then
					differentTheme = true
				end
			end
			if value ~= _K.Data.settings[key] and (key ~= "defaultTheme" or value ~= "Custom (DataStore)") then
				different = true
			end
		end

		if string.find(key, "theme", 1, true) == 1 and _K.Data.settings.defaultTheme ~= "Custom (DataStore)" then
			local theme = if differentTheme then "Custom (DataStore)" else _K.Data.settings.defaultTheme
			change("defaultTheme", theme)
		elseif key == "defaultTheme" then
			local themeModule = _K.client.themes._value[value]
			if themeModule then
				-- FIX: update images and sounds
				for key, value in themeModule do
					local dataKey = "theme" .. key
					local existing = _K.Data.settings[dataKey]
					if existing ~= nil and existing ~= UI.peek(value) then
						change(dataKey, UI.peek(value))
					end
				end
			end
			_K.client.settings.defaultTheme:set(value)
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
						return use(_K.client.settings.playerPrefix)[_K.LocalPlayer.UserId]
							or use(_K.client.settings.prefix)[1]
					end),
					Validate = function(text)
						return not (text == "" or table.find(reservedPrefixes, text))
					end,

					[UI.Hook] = {
						Selected = function(value)
							_K.Data.settings.playerPrefix[_K.LocalPlayer.UserId] = value
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
							change("prefix", { value, unpack(_K.client.settings.prefix._value, 2) })
						end,
					},
				},
			},
		},
		Theme = {},
	}

	task.defer(function()
		_K.Util.Defer.reset()
		-- Theme select
		local themeList = UI.compute(function(use)
			local themes = {}
			for key in use(_K.client.themes) do
				table.insert(themes, key)
			end
			table.sort(themes)
			table.insert(themes, "Custom (DataStore)")
			return themes
		end)
		table.insert(
			settingsLineItems.Theme,
			UI.new "ListItem" {
				ContentAutomaticSize = false,
				Text = "Theme",
				UI.new "Select" {
					Choice = UI.compute(function(use)
						return use(_K.client.settings.defaultTheme)
					end),
					Choices = themeList,
					[UI.Hook] = {
						Selected = function(value)
							change("defaultTheme", value)
						end,
					},
				},
			}
		)
		-- switches
		for _, data in
			{
				{ key = "SoundEnabled", text = "UI Sounds" },
				{
					key = "TypingSounds",
					text = "Typing sounds",
					tip = "<b>NOTE:</b> Requires taking the audios and adding permissions to your game!\n<font transparency='0.66'>Why does Roblox do this to me</font> 😔",
				},
				{ key = "TypingSoundsOnEveryTextBox", text = "Sounds on every TextBox" },
				{ key = "StrokeEnabled", text = "UI Borders" },
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
			local fonts = Enum.Font:GetEnumItems()
			table.sort(fonts, function(a, b)
				return a.Name < b.Name
			end)
			for _, key in { "Font", "FontMono" } do
				_K.Util.Defer.wait()
				table.insert(
					settingsLineItems.Theme,
					UI.new "ListItem" {
						ContentAutomaticSize = false,
						Text = key:gsub("(.)(%u)", "%1 %2"),
						UI.new "Select" {
							Font = UI.Theme[key],
							Choice = UI.Theme[key],
							Choices = fonts,
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

		do -- Transparency
			for _, data in
				{
					{ key = "Transparency", text = "Background Transparency" },
					{ key = "TextStrokeTransparency", text = "Text Stroke Transparency" },
				}
			do
				table.insert(
					settingsLineItems.Theme,
					UI.new "ListItem" {
						ContentAutomaticSize = false,
						Text = data.text,
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
								return use(UI.Theme[data.key])
							end),
							[UI.Hook] = {
								Selected = function(value)
									local number = tonumber(value)
									if not tonumber(value) then
										return
									end
									UI.Theme[data.key]:set(number)
									change("theme" .. data.key, number)
								end,
							},
						},
						UI.new "Slider" {
							Value = UI.Theme[data.key],
							UI.new "UIFlexItem" {
								FlexMode = Enum.UIFlexMode.Fill,
							},
							[UI.Hook] = {
								Selected = function(value)
									change("theme" .. data.key, value)
								end,
							},
						},
					}
				)
			end
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

		local function updateSettingsAuth()
			local settingsAuth = _K.Auth.hasPermission(_K.LocalPlayer.UserId, "settings")
			local themeAuthority = _K.Data.settings.changeThemeAuthority
			settingsScroller._instance.Theme.Visible = themeAuthority == "Client"
				or (themeAuthority == "Server" and settingsAuth)
			settingsScroller._instance.General.Visible = settingsAuth
		end
		_K.Hook.authChanged:Connect(updateSettingsAuth)
		updateSettingsAuth()
	end)

	settingsDialog = UI.new "Dialog" {
		BackgroundTransparency = UI.Theme.TransparencyOverlay,
		BackgroundColor3 = UI.Theme.Secondary,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.fromScale(1, 0),
		ActionText = "Save changes"
			.. (_K.Data.settings.changeThemeAuthority == "Server" and " and update for everyone?" or "?"),
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
			Icon = UI.Theme.Image.Search,
			IconProperties = {
				ImageColor3 = UI.Theme.PrimaryText,
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
