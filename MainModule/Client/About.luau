local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")

local CREDITS = require(script.Parent.Parent.Credits)
local UserFrame = require(script.Parent.UserFrame)

local About = {}
About.__index = About

local success, result = pcall(function()
	return PolicyService:GetPolicyInfoForPlayerAsync(Players.LocalPlayer)
end)

local discordInvite = success
	and result.AllowedExternalLinkReferences
	and table.find(result.AllowedExternalLinkReferences, "Discord")

function About.new(_K)
	local UI = _K.UI

	local commandBarKey = _K.client.hotkeys.commandBar
	local commandBarKeyText = UI.compute(function(use)
		local key = use(commandBarKey.key)
		local raw = UI.UserInputService:GetStringForKeyCode(key)
		return `<b>Command Bar Hotkey:</b>\t<font color="#0f0">{commandBarKey.mods.Shift and "Shift+" or ""}{commandBarKey.mods.Alt and "Alt+" or ""}{key.Name} {raw}</font>\n`
	end)

	local dashboardKey = _K.client.hotkeys.dashboard
	local dashboardKeyText = UI.compute(function(use)
		local key = use(dashboardKey.key)
		local raw = UI.UserInputService:GetStringForKeyCode(key)
		return `<b>Dashboard Hotkey:</b>\t  <font color="#0f0">{dashboardKey.mods.Shift and "Shift+" or ""}{dashboardKey.mods.Alt and "Alt+" or ""}{key.Name} {raw}</font>`
	end)

	local scroller = UI.new "Scroller" {
		Name = "About",

		UserFrame(Players.LocalPlayer.UserId),
		UI.new "TextLabel" {
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
			Font = UI.Theme.FontMono,
			TextSize = UI.Theme.FontSize,
			TextColor3 = UI.Theme.PrimaryText,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = true,
			Size = UDim2.new(0, 0, 0, 24),
			Text = UI.compute(function(use)
				local prefix = use(UI.Scope.settings.prefix)
				local byte = string.byte(prefix)
				for i, key in Enum.KeyCode:GetEnumItems() do
					if key.Value == byte then
						prefix = `{key.Name} {prefix}`
						break
					end
				end
				return `<b>Command Prefix:</b>\t\t<font color="#0f0">{prefix}</font>\n`
					.. use(commandBarKeyText)
					.. use(dashboardKeyText)
			end),
			Selectable = true,
			RichText = true,
		},
		if discordInvite
			then UI.new "TextLabel" {
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				Font = UI.Theme.Font,
				TextSize = UI.Theme.FontSize,
				TextColor3 = UI.Theme.PrimaryText,
				TextWrapped = true,
				Size = UDim2.new(1, 0, 0, 24),
				Text = `<b>Need help?</b>\n<font transparency="0.5">Join our Discord community!</font>`,
				RichText = true,
			}
			else nil,

		if discordInvite
			then UI.new "TextBox" {
				Name = "Invite",
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundColor3 = Color3.fromHex("#5865F2"),
				Font = UI.Theme.Font,
				TextSize = UI.Theme.FontSize,
				TextColor3 = Color3.new(1, 1, 1),
				Text = "discord.gg/kohl",
				TextEditable = false,
				ClearTextOnFocus = false,

				UI.new "UICorner" {
					CornerRadius = UDim.new(1, 0),
				},
				UI.new "UIPadding" {
					PaddingLeft = UI.Theme.Padding,
					PaddingRight = UI.Theme.Padding,
					PaddingTop = UI.Theme.Padding,
					PaddingBottom = UI.Theme.Padding,
				},
			}
			else nil,
		UI.new "TextLabel" {
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Font = UI.Theme.Font,
			TextSize = UI.Theme.FontSize,
			TextColor3 = UI.Theme.PrimaryText,
			TextWrapped = true,
			Size = UDim2.new(1, 0, 0, 24),
			Text = "<b><sc>monetization made easy</sc></b>\n"
				.. "Get <font color='#0f0'><b>10-30%</b></font> of Kohl's Admin purchases when <font transparency='0.5'>Third Party Purchases</font> are enabled in the Roblox Game Settings!\n\n"
				.. "<b><sc>kohl's admin game catalog</sc></b>\n"
				.. "A catalog of games that use Kohl's Admin, check the Settings ModuleScript in Roblox Studio for more details!",
			RichText = true,
		},
		UI.new "TextBox" {
			Name = "CatalogLink",
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundColor3 = UI.Theme.Secondary,
			Font = UI.Theme.Font,
			TextSize = UI.Theme.FontSize,
			TextColor3 = UI.Theme.SecondaryText,
			Text = "roblox.com/games/17873329124/",
			TextEditable = false,
			ClearTextOnFocus = false,

			UI.new "UICorner" {
				CornerRadius = UDim.new(1, 0),
			},
			UI.new "UIPadding" {
				PaddingLeft = UI.Theme.Padding,
				PaddingRight = UI.Theme.Padding,
				PaddingTop = UI.Theme.Padding,
				PaddingBottom = UI.Theme.Padding,
			},
		},
	}

	UI.edit(scroller._instance.UIListLayout, {
		Padding = UI.Theme.PaddingDouble,
		HorizontalAlignment = "Center",
	})

	local content = UI.new "Frame" {
		Name = "Credits",
		Parent = scroller,
		LayoutOrder = 1e6,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
		BackgroundTransparency = 1,

		UI.new "UIListLayout" {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UI.Theme.PaddingDouble,
			HorizontalAlignment = "Center",
		},
	}

	local order = 1
	for _, group in CREDITS do
		UI.new "TextLabel" {
			Parent = content,
			LayoutOrder = order,
			Name = group.Title,
			BackgroundTransparency = 1,
			FontFace = UI.Theme.FontHeavy,
			TextTruncate = Enum.TextTruncate.SplitWord,
			TextSize = UI.Theme.FontSizeLargest,
			TextColor3 = UI.Theme.PrimaryText,
			Size = UDim2.new(1, 0, 0, 24),
			Text = `<sc>{string.lower(group.Title)}</sc>`,
			TextTransparency = 0.5,
			RichText = true,
		}
		order += 1
		local flexFrame = UI.new "Frame" {
			Parent = content,
			LayoutOrder = order,
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.fromScale(1, 0),

			UI.new "UIListLayout" {
				SortOrder = Enum.SortOrder.LayoutOrder,
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalFlex = Enum.UIFlexAlignment.SpaceEvenly,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				Padding = UI.Theme.PaddingDouble,
				Wraps = true,
			},
		}
		order += 1
		task.spawn(function()
			if string.lower(group.Title) == "special thanks" then
				local userFrame = UserFrame(UI.LocalPlayer.UserId, "You", nil, false)
				userFrame.LayoutOrder = 0
				userFrame.Parent = flexFrame
				UI.new "Tooltip" {
					Parent = userFrame,
					Text = "Thanks for using the admin!",
				}
			end
			for i, user in group.Users do
				local userType = type(user)
				if userType == "number" then
					local userFrame = UserFrame(user, nil, nil, false)
					userFrame.LayoutOrder = i
					userFrame.Parent = flexFrame
				elseif userType == "table" then
					local userFrame = UserFrame(user.Id, nil, nil, false)
					userFrame.LayoutOrder = i
					userFrame.Parent = flexFrame
					if user.Tooltip then
						UI.new "Tooltip" {
							Parent = userFrame,
							Text = user.Tooltip,
						}
					end
				end
			end
		end)
	end

	return scroller._instance
end

return About
