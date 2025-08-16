local Settings = { _K = nil }
Settings.__index = Settings

local filterRichFormat = `<font transparency="0.5">%s</font><b>%s</b><font transparency="0.5">%s</font>`

function Settings.new(_K)
	local UI = _K.UI

	local settingsDialog
	local originalValues = {}
	local pendingChanges = {}

	local function resetChanges()
		for key, value in originalValues do
			_K.Data.savedSettings[key] = value
			if _K.client.settings[key] then
				_K.client.settings[key](value, true)
			end
		end
		table.clear(originalValues)
		table.clear(pendingChanges)
	end

	local function confirmChanges()
		_K.Remote.Settings:FireServer(pendingChanges)
		for key, value in pendingChanges do
			_K.Data.savedSettings[key] = value
			if _K.client.settings[key] then
				_K.client.settings[key](value, true)
			end
		end
		table.clear(originalValues)
		table.clear(pendingChanges)
	end

	local function change(key, value, skipCustomCheck)
		if not _K.client.ready then
			return
		end

		if originalValues[key] == value then
			pendingChanges[key] = nil
		elseif _K.Data.savedSettings[key] ~= value then
			pendingChanges[key] = value
			if not originalValues[key] then
				local original = _K.Data.savedSettings[key]
				originalValues[key] = if type(original) == "table" then table.clone(original) else original
			end
		end

		local theme = _K.Data.savedSettings.theme
		local themeModule = UI.Themes[theme]

		local different = false
		local differentTheme = false
		for k, v in pendingChanges do
			if
				themeModule
				and k ~= "theme"
				and string.find(k, "theme", 1, true) == 1
				and UI.raw(themeModule[string.sub(k, 6)]) ~= v
			then
				differentTheme = true
			end
			if v ~= originalValues[k] then
				different = true
			end
		end

		if settingsDialog then
			settingsDialog._instance.Visible = different
		end

		if key ~= "theme" and string.find(key, "theme", 1, true) == 1 and not skipCustomCheck then
			local newTheme = if differentTheme then "Custom (DataStore)" else theme
			if pendingChanges.theme ~= newTheme then
				change("theme", newTheme)
			end
		elseif key == "theme" then
			themeModule = UI.Themes[value]
			if themeModule then
				_K.Data.savedSettings.theme = value
				-- FIX: update images and sounds
				for key, value in themeModule do
					local dataKey = "theme" .. key
					local existing = _K.Data.savedSettings[dataKey]
					if existing ~= nil and existing ~= UI.raw(value) then
						change(dataKey, UI.raw(value), true)
					end
				end
			end
			_K.client.settings.theme(value)
		end
	end

	local ignoredDefaultSettings = {
		announcement = true,
		announcements = true,
		notifications = true,
		freeAdmin = true,
		prefix = true,
	}

	local settingsScroller = UI.new "Scroller" {
		UI.new "UIFlexItem" {
			FlexMode = Enum.UIFlexMode.Fill,
		},
		UI.new "Button" {
			LayoutOrder = 2 ^ 31 - 1,
			Label = "Restore Default Settings",
			Visible = _K.client.settings.useSavedSettings,

			Activated = function()
				for k, v in _K.Data.defaultSettings do
					if not ignoredDefaultSettings[k] and _K.Data.savedSettings[k] ~= v then
						change(k, v)
						if _K.client.settings[k] then
							_K.client.settings[k](v)
						end
					end
				end
			end,
		},
	}

	local lineItemHeight = UI.compute(function()
		return UI.Theme.FontSize() + UI.Theme.Padding().Offset
	end)

	local inputSize = UI.compute(function()
		return UDim2.new(0, 0, 0, lineItemHeight())
	end)

	local themeLineItems = { Name = "Appearance" }

	local rankChoices = table.clone(_K.Data.rolesList)
	local disabledRankChoice = { _rank = false, name = "Disabled" }
	table.insert(rankChoices, disabledRankChoice)

	local function rankItem(setting: string, text: string, tooltip: string, callback)
		return UI.new "ListItem" {
			Text = text,
			Tooltip = tooltip,
			UI.new "Select" {
				Choice = function()
					local setting = _K.client.settings[setting]()
					return if setting then _K.Auth.getRoleFromRank(setting) else disabledRankChoice
				end,
				Choices = rankChoices,
				[UI.Hook] = {
					Selected = function(value)
						change(setting, value._rank)
						_K.client.settings[setting](value._rank)
						if callback then
							callback()
						end
					end,
				},
			},
		}
	end

	local function switchItem(setting: string, text: string, tooltip: string?)
		return UI.new "ListItem" {
			Text = text,
			Tooltip = tooltip,
			UI.new "Switch" {
				Value = _K.client.settings[setting],
				[UI.Hook] = {
					Selected = function(value)
						change(setting, value)
					end,
				},
			},
		}
	end

	local function sliderItem(setting: string, text: string, tooltip: string?)
		return UI.new "ListItem" {
			Text = text,
			Tooltip = tooltip,
			UI.new "Slider" {
				Value = _K.client.settings[setting],
				[UI.Hook] = {
					Selected = function(value)
						change(setting, value)
					end,
				},
			},
		}
	end

	local freeAdminCache = {}
	local reservedPrefixes = { ",", " ", "`", '"', "@", "$", "%", "*", "~" }
	local settingsLineItems = {
		{
			Name = "Admin",
			UI.new "ListItem" {
				Text = "Command Prefix",
				Tooltip = "The character to trigger a command.",
				UI.new "Input" {
					Font = UI.Theme.FontMono,
					FontSize = UI.Theme.FontSize,
					Size = inputSize,
					Placeholder = ";",
					MaxChars = 1,
					Value = function()
						return _K.client.settings.prefix()[1]
					end,
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
			UI.new "ListItem" {
				Text = "Free Admin",
				Tooltip = "🚨 Role given to every player who joins",
				UI.new "Select" {
					Choice = function()
						local freeAdmin = _K.client.settings.freeAdmin()
						return if type(freeAdmin) == "table" and freeAdmin[1]
							then _K.Data.roles[freeAdmin[1]]
							else disabledRankChoice
					end,
					Choices = rankChoices,
					[UI.Hook] = {
						Selected = function(value)
							local roleId = value._key
							value = freeAdminCache[roleId]
							if not value then
								value = { roleId }
								if roleId ~= nil then
									freeAdminCache[roleId] = value
								end
							end
							change("freeAdmin", value)
							_K.client.settings.freeAdmin(
								_K.Util.Table.merge(table.clone(_K.Data.defaultSettings.freeAdmin), value)
							)
						end,
					},
				},
			},
			rankItem("commandBarRank", "Command Bar Rank", "Minimum role to use the Command Bar"),
			rankItem("dashboardRank", "Dashboard Rank", "Minimum role to use the Dashboard", function()
				print(_K.client.settings.dashboardRank())
				if _K.client.settings.dashboardRank() == false then
					_K.Process.runCommands(_K, _K.LocalPlayer.UserId, ";settings")
				end
			end),
			rankItem("dashboardButtonRank", "Dashboard Button Rank", "Minimum role to show the Dashboard Button"),
			rankItem(
				"joinNotificationRank",
				"Join Notification Rank",
				"Minimum role to show the default join notification"
			),
			switchItem(
				"addToCharts",
				"Add Game to Charts",
				"Adds the game to a list of games using Kohl's Admin, check About for details."
			),
			switchItem(
				"vip",
				"Global VIP Features",
				"Toggles VIP features for the admin.\n<b>Required if game is added to charts!</b>"
			),
			switchItem("chatCommands", "Chat Commands", "Toggle commands via chat"),
			switchItem("commandRequests", "Command Requests", "Toggle commands requests on same or higher rank users"),
			switchItem("onlyShowUsableCommands", "Only Show Usable Commands", "Show only purchasable/usable commands"),
			switchItem(
				"getKohlsAdminPopup",
				"Get Kohl's Admin Popup",
				"Shows users a popup after using a few commands to get the Kohl's Admin model"
			),
			switchItem(
				"wrongPrefixWarning",
				"Wrong Prefix Warning",
				"Warns users when the wrong command prefix is used"
			),
			switchItem("saveLogs", "Save Logs", "Toggle the saving and synchronization of logs across servers"),
		},

		{
			Name = "Local",
			UI.new "ListItem" {
				Text = "Custom Command Prefix",
				Tooltip = "A custom character to trigger a command, only affects the client.",
				UI.new "Input" {
					Font = UI.Theme.FontMono,
					FontSize = UI.Theme.FontSize,
					Size = inputSize,
					Placeholder = ";",
					MaxChars = 1,
					Value = function()
						return _K.client.playerPrefix() or _K.client.settings.prefix()[1]
					end,
					Validate = function(text)
						return not (text == "" or table.find(reservedPrefixes, text))
					end,

					[UI.Hook] = {
						Selected = function(value)
							_K.client.playerPrefix(value, true)
							_K.Remote.PlayerPrefix:FireServer(value)
						end,
					},
				},
			},
			UI.new "ListItem" {
				Text = "Command Bar Hotkey",
				Tooltip = "The keyboard shortcut to open the command bar.",
				UI.new "Input" {
					Font = UI.Theme.FontMono,
					FontSize = UI.Theme.FontSize,
					Size = inputSize,
					Placeholder = ";",
					HotkeyInput = true,
					Value = UI.UserInputService:GetStringForKeyCode(_K.client.hotkeys.commandBar.key._value),
					Hotkey = _K.client.hotkeys.commandBar.key,
					Modifiers = _K.client.hotkeys.commandBar.mods,
				},
			},
			UI.new "ListItem" {
				Text = "Dashboard Hotkey",
				Tooltip = "The keyboard shortcut to open the dashboard.",
				UI.new "Input" {
					Font = UI.Theme.FontMono,
					FontSize = UI.Theme.FontSize,
					Size = inputSize,
					Placeholder = "'",
					HotkeyInput = true,
					Value = UI.UserInputService:GetStringForKeyCode(_K.client.hotkeys.dashboard.key._value),
					Hotkey = _K.client.hotkeys.dashboard.key,
					Modifiers = _K.client.hotkeys.dashboard.mods,
				},
			},
		},

		themeLineItems,

		{
			Name = "Sound",
			switchItem("themeSoundEnabled", "UI Sounds"),
			switchItem("themeTypingSounds", "Typing sounds"),
			switchItem("themeTypingSoundsOnEveryTextBox", "Typing sounds on every TextBox"),
		},
	}

	task.defer(function()
		_K.Util.Defer.reset()

		-- Theme select
		local themeList = UI.compute(function()
			local themes = {}
			for key in UI.Themes do
				table.insert(themes, key)
			end
			table.sort(themes)
			table.insert(themes, "Custom (DataStore)")
			return themes
		end)
		table.insert(
			themeLineItems,
			UI.new "ListItem" {
				Text = "Theme",
				Tooltip = "Changes the theme of Kohl's Admin interfaces.",
				UI.new "Select" {
					Choice = function()
						return _K.client.settings.theme()
					end,
					Choices = themeList,
					[UI.Hook] = {
						Selected = function(value)
							change("theme", value)
						end,
					},
				},
			}
		)

		-- font faces
		do
			local fonts = Enum.Font:GetEnumItems()
			local mono = { Enum.Font.Code, Enum.Font.RobotoMono }
			table.sort(fonts, function(a, b)
				return a.Name < b.Name
			end)
			for _, key in { "Font", "FontMono" } do
				table.insert(
					themeLineItems,
					UI.new "ListItem" {
						Text = key:gsub("(.)(%u)", "%1 %2"),
						UI.new "Select" {
							Font = UI.Theme[key],
							Choice = UI.Theme[key],
							Choices = if key == "Font" then fonts else mono,
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

		local vector2Huge = Vector2.new(math.huge, math.huge)
		local sliderMaxSize = UI.state(vector2Huge)

		local sliders = {}
		local function updateSliderSize()
			sliderMaxSize(vector2Huge, true)
			local minimumWidth = math.huge
			for _, slider in sliders do
				minimumWidth = math.min(slider.AbsoluteSize.X, minimumWidth)
			end
			sliderMaxSize(Vector2.new(minimumWidth, math.huge), true)
		end

		settingsScroller._instance:GetPropertyChangedSignal("AbsoluteWindowSize"):Connect(updateSliderSize)

		local lastSelected
		local lastSelectedY = 0
		settingsScroller._instance:GetPropertyChangedSignal("AbsoluteCanvasSize"):Connect(function()
			updateSliderSize()
			if not lastSelected then
				return
			end
			local change, selectedY = 0, lastSelected.AbsolutePosition.Y + lastSelected.AbsoluteSize.Y / 2
			if settingsScroller._instance.CanvasPosition.Y > 0 then
				change = selectedY - lastSelectedY
				settingsScroller._instance.CanvasPosition += Vector2.new(0, change)
			end
			lastSelectedY = selectedY - change
		end)

		do -- Font Size
			local slider
			slider = UI.new "Slider" {
				Snap = 25,
				Value = function()
					return math.clamp(UI.Theme.FontSize() - 7, 1, 25)
				end,
				UI.new "UIFlexItem" {
					FlexMode = Enum.UIFlexMode.Fill,
				},
				[UI.Hook] = {
					Selected = function(value)
						lastSelected = slider._instance
						lastSelectedY = lastSelected.AbsolutePosition.Y + lastSelected.AbsoluteSize.Y / 2
						UI.Theme.FontSize(value + 7)
						change("themeFontSize", value + 7)
					end,
				},
			}
			local listItem = UI.new "ListItem" {
				Text = "Font Size",
				UI.new "Input" {
					Font = UI.Theme.FontMono,
					FontSize = UI.Theme.FontSize,
					Size = inputSize,
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
				slider,
			}

			listItem._label.Size = UDim2.new(0.5, 0, 0, 0)
			table.insert(sliders, slider._instance)
			table.insert(themeLineItems, listItem)
		end
		_K.Util.Defer.wait()

		-- UDim options
		for i, key in { "CornerRadius", "Padding" } do
			local slider
			slider = UI.new "Slider" {
				Snap = 17,
				UI.new "UISizeConstraint" {
					MaxSize = sliderMaxSize,
				},
				Value = function()
					return math.clamp(UI.Theme[key]().Offset + 1, 1, 17)
				end,
				UI.new "UIFlexItem" {
					FlexMode = Enum.UIFlexMode.Fill,
				},
				[UI.Hook] = {
					Selected = function(value)
						lastSelected = slider._instance
						lastSelectedY = lastSelected.AbsolutePosition.Y + lastSelected.AbsoluteSize.Y / 2
						value = UDim.new(0, value - 1)
						UI.Theme[key](value)
						change("theme" .. key, value)
					end,
				},
			}
			table.insert(sliders, slider._instance)
			table.insert(
				themeLineItems,
				UI.new "ListItem" {
					Text = key:gsub("(.)(%u)", "%1 %2"),
					UI.new "Input" {
						Font = UI.Theme.FontMono,
						FontSize = UI.Theme.FontSize,
						Size = inputSize,
						NumberOnly = true,
						NumberRange = NumberRange.new(0, 16),
						Placeholder = "",
						Value = function()
							return UI.Theme[key]().Offset
						end,
						[UI.Hook] = {
							Selected = function(value)
								local number = tonumber(value)
								if not number then
									return
								end
								value = UDim.new(0, number)
								UI.Theme[key](value)
								change("theme" .. key, value)
							end,
						},
					},
					slider,
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
				local slider
				slider = UI.new "Slider" {
					UI.new "UISizeConstraint" {
						MaxSize = sliderMaxSize,
					},
					Value = UI.Theme[data.key],
					UI.new "UIFlexItem" {
						FlexMode = Enum.UIFlexMode.Fill,
					},
					[UI.Hook] = {
						Selected = function(value)
							change("theme" .. data.key, value)
						end,
					},
				}
				table.insert(sliders, slider._instance)
				table.insert(
					themeLineItems,
					UI.new "ListItem" {
						Text = data.text,
						UI.new "Input" {
							Font = UI.Theme.FontMono,
							FontSize = UI.Theme.FontSize,
							Size = inputSize,
							MaxChars = 5,
							NumberOnly = true,
							NumberRange = NumberRange.new(0, 1),
							Placeholder = "",
							Value = function()
								return string.sub(UI.Theme[data.key](), 1, 5)
							end,
							[UI.Hook] = {
								Selected = function(value)
									local number = tonumber(value)
									if not tonumber(value) then
										return
									end
									UI.Theme[data.key](number)
									change("theme" .. data.key, number)
								end,
							},
						},
						slider,
					}
				)
			end
		end

		-- switches
		table.insert(themeLineItems, switchItem("themeStrokeEnabled", "UI Borders"))

		-- Color options
		for index, key in
			{
				"Primary",
				"PrimaryText",
				"Secondary",
				"SecondaryText",
				"Border",
				"Valid",
				"Invalid",
			}
		do
			_K.Util.Defer.wait()
			local state = UI.Theme[key]
			local dataKey = "theme" .. key
			table.insert(
				themeLineItems,
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

		local savedSettingsSwitch = UI.new "ListItem" {
			Parent = settingsScroller,
			LayoutOrder = -1,
			Text = "Use Saved Settings",
			Tooltip = "Toggles using saved or studio-only settings.",
			UI.new "Switch" {
				Value = _K.client.settings.useSavedSettings,

				[UI.Hook] = {
					Selected = function(value)
						change("useSavedSettings", value)
					end,
				},
			},
		}

		UI.edit(savedSettingsSwitch._label, {
			FontFace = UI.Theme.FontBold,
		})

		for layoutOrder, definition in ipairs(settingsLineItems) do
			settingsLineItems[definition.Name] = UI.new("List")(_K.Util.Table.merge({
				Parent = settingsScroller,
				Label = definition.Name,
				Collapsible = true,
				Padding = UI.Theme.PaddingDouble,
				LayoutOrder = layoutOrder,
			}, definition))
		end

		local function updateSettingsAuth()
			local settingsAuth = _K.Auth.hasPermission(_K.LocalPlayer.UserId, "settings")
			local themeAuthority = _K.Data.settings.changeThemeAuthority
			settingsScroller._instance.Appearance.Visible = themeAuthority == "Client"
				or (themeAuthority == "Server" and settingsAuth)
			settingsScroller._instance.Admin.Visible = settingsAuth and _K.client.settings.useSavedSettings._value
			savedSettingsSwitch._instance.Visible = settingsAuth
		end
		_K.Hook.authChanged:Connect(updateSettingsAuth)
		_K.client.settings.useSavedSettings:Connect(updateSettingsAuth)
		updateSettingsAuth()
	end)

	local function close(self)
		self.Activated(false)
	end

	settingsDialog = UI.new "Dialog" {
		BackgroundTransparency = UI.Theme.TransparencyHeavy,
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
			task.defer(close, self)
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

	local filterInput = UI.new "Input" {
		Fill = true,
		Placeholder = "Search",
		Icon = UI.Theme.Image.Search,
		IconProperties = {
			ImageColor3 = UI.Theme.PrimaryText,
			Size = UDim2.fromOffset(18, 18),
		},
	}

	local function filterSettings()
		local filter = string.lower(filterInput._input.Text)
		for _, lineItems in ipairs(settingsLineItems) do
			local list = settingsScroller._instance[lineItems.Name]
			if filter == "" then
				list.Visible = true
				for _, lineItem in ipairs(lineItems) do
					lineItem.Text(lineItem._instance.Name)
					lineItem._instance.Visible = true
				end
				continue
			end

			local listFound = string.find(string.lower(lineItems.Name), filter, 1, true)
			if listFound then
				list.Visible = true
				settingsLineItems[lineItems.Name].Collapsed(false)
			else
				list.Visible = false
			end

			for _, lineItem in ipairs(lineItems) do
				local rawText = lineItem._instance.Name
				local found = string.find(string.lower(rawText), filter, 1, true)
				if found then
					list.Visible = true
					settingsLineItems[lineItems.Name].Collapsed(false)
				end
				local text = if found
					then string.format(
						filterRichFormat,
						_K.Util.String.escapeRichText(string.sub(rawText, 1, found - 1)),
						_K.Util.String.escapeRichText(string.sub(rawText, found, found + #filter - 1)),
						_K.Util.String.escapeRichText(string.sub(rawText, found + #filter))
					)
					else `<font transparency="0.5">{rawText}</font>`
				lineItem.Text(text)
				lineItem._instance.Visible = found or listFound
			end
		end
	end

	filterInput._input:GetPropertyChangedSignal("Text"):Connect(filterSettings)

	local settingsFrame = UI.new "Frame" {
		Name = "Settings",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0),

		UI.new "UIListLayout" { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UI.Theme.Padding },
		filterInput,
		settingsScroller,
		settingsDialog,
	}

	return {
		_instance = settingsFrame,
		_input = filterInput,
		_scroller = settingsScroller._instance,
	}
end

return Settings
