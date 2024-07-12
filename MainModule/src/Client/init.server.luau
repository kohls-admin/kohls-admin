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
_K.clientSettings = {}
_K.hotkeys = {}

require(script.CommandBar):init(_K)

-- stateful hotkeys
for _, data in _K.hotkeys do
	data.key = Flux.state(data.key)
end

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
			if
				input.KeyCode == data.key._value
				or (type(data.key._value) == "table" and table.find(data.key._value, input.KeyCode))
			then
				local missingMod = false
				for mod, value in data.mods do
					if not value then
						continue
					end
					if not input:IsModifierKeyDown(Enum.ModifierKey[mod]) then
						missingMod = true
						break
					end
				end
				if missingMod then
					return
				end
				task.defer(data.callback)
			end
		end
	end
end)

Interface.Parent = LocalPlayer:WaitForChild("PlayerGui")

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

-- udim options
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

local filterRichFormat = `<font transparency="0.5">%s</font><b>%s</b><font transparency="0.5">%s</font>`

local Settings = UI.new "Scroller" {
	Name = "Settings",

	UI.new "Input" {
		Placeholder = "Search settings",
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

local keyOrder = { "theme" }
for key, lineItems in settingsLineItems do
	local list = UI.new "List" {
		Parent = Settings,
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

local logTypeColors = {
	Chat = "#0f0",
	Command = "#ff0",
	Info = "#0ff",
	Warning = "#f80",
	Error = "#f00",
}

local scrollerTest = UI.new "ScrollerFast" {
	List = _K.logs,
	FilterText = function(log)
		local timestamp = os.date("%b %d %X", log[1])
		local logTypeLabel = _K.Enum.LogType[log[3]]
		return `{timestamp} {logTypeLabel:upper()} {log[2]}`
	end,
	RenderText = function(self, log)
		local msg = log[2]
		local timestamp = os.date("%b %d %X", log[1])
		local logTypeLabel = _K.Enum.LogType[log[3]]

		if self._filter ~= "" then
			local text = `{timestamp} {logTypeLabel:upper()} {msg}`
			local filterFound = string.find(text:lower(), self._filter)
			return if filterFound
				then string.format(
					filterRichFormat,
					_K.Util.escapeRichText(string.sub(text, 1, filterFound - 1)),
					_K.Util.escapeRichText(string.sub(text, filterFound, filterFound + #self._filter - 1)),
					_K.Util.escapeRichText(string.sub(text, filterFound + #self._filter))
				)
				else text
		end

		local found = string.find(msg, " ")
		return `<font transparency="0.5">{_K.Util.escapeRichText(timestamp)}</font> <font color="{logTypeColors[logTypeLabel]}" weight="900">{logTypeLabel:upper()}</font> <b>{_K.Util.escapeRichText(
			string.sub(msg, 1, found - 1)
		)}</b>{string.sub(msg, found)}`
	end,
	UI.new "UIFlexItem" {
		FlexMode = Enum.UIFlexMode.Fill,
	},
}

local scrollerInput = UI.new "Input" {
	Placeholder = "Search logs",
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
	Name = "Logs",
	BackgroundTransparency = 1,
	Size = UDim2.new(1, 0, 1, 0),
	UI.new "UIListLayout" { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UI.Theme.Padding },
	scrollerInput,
	scrollerTest,
}

local function filterTest(self, list)
	local filter = scrollerInput._input.Text:lower()
	self._filter = filter
	local new = {}
	for i, v in list do
		if self.FilterText._value(v):lower():find(filter, 1, true) then
			table.insert(new, v)
		end
	end
	return new
end

scrollerTest:filter(filterTest)

local _uiTestWindow = UI.new "Window" {
	Parent = UI.LayerDefault,
	Title = "Settings",

	UI.new "Tabs" {
		Settings,
		scrollerFrame,
		UI.new "Frame" {},
		UI.new "Frame" {},
		UI.new "Frame" {},
		UI.new "Frame" {},
		UI.new "Frame" {},
		UI.new "Frame" {},
		UI.new "Frame" {},
		UI.new "Frame" {},
		UI.new "Frame" {},
		UI.new "Frame" {},
	},
}

local initCon
initCon = _K.Remote "Init".OnClientEvent:Connect(function(auth, bans, logs, settings)
	initCon:Disconnect()
	_K.Authorization = auth
	_K.bans = bans
	_K.logs = logs
	_K.settings = settings
	scrollerTest:updateList()
end)

_K.Remote "Log".OnClientEvent:Connect(function(log)
	table.insert(_K.logs, log)
	if #_K.logs > 1e5 then
		table.remove(_K.logs, 1)
	end
	scrollerTest:updateList()
end)
