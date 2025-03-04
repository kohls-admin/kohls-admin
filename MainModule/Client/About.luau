local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")

local CREDITS = require(script.Parent.Parent.Credits)
local UserFrame = require(script.Parent.UserFrame)

local About = {}
About.__index = About

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

		UI.new "TextBox" {
			Name = "Version",
			AutoLocalize = false,
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundColor3 = UI.Theme.Secondary,
			BackgroundTransparency = 0.875,
			Font = UI.Theme.FontMono,
			TextSize = UI.Theme.FontSizeSmall,
			TextColor3 = UI.Theme.PrimaryText,
			Text = `Version {_K.VERSION}`,
			TextTransparency = 0.125,
			TextWrapped = true,
			TextEditable = false,
			ClearTextOnFocus = false,

			UI.new "UICorner" {
				CornerRadius = UI.Theme.CornerRadius,
			},
			UI.new "UIPadding" {
				PaddingLeft = UI.Theme.Padding,
				PaddingRight = UI.Theme.Padding,
				PaddingTop = UI.Theme.PaddingHalf,
				PaddingBottom = UI.Theme.PaddingHalf,
			},
		},
		UserFrame(Players.LocalPlayer.UserId),
		UI.new "TextLabel" {
			AutoLocalize = false,
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

	local adminModelId = 172732271
	local adminModelButton = UI.new "Button" {
		LayoutOrder = 6,
		Parent = scroller,
		Name = "adminModelButton",
		Icon = "rbxasset://textures/ui/common/robux.png",
		IconRightAlign = true,
		Label = "<sc><b>Get Kohl's Admin</b></sc>",
		HoverTransparency = 0.5,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, -2, 0, 32),

		UI.new "Frame" {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 0, 0.5, 0),
			Size = UDim2.new(0, 28, 0, 28),
			UI.new "ImageLabel" {
				BackgroundTransparency = 1,
				Size = UDim2.new(0, 28, 0, 28),
				Image = "rbxasset://textures/ui/InspectMenu/ico_favorite@2x.png",
				ImageColor3 = Color3.new(0, 0, 0),
				ImageTransparency = 0.875,
			},
			UI.new "ImageButton" {
				BackgroundTransparency = 1,
				Position = UDim2.new(0, 2, 0, 2),
				Size = UDim2.new(0, 24, 0, 24),
				Image = "rbxasset://textures/ui/InspectMenu/ico_favorite@2x.png",
				ImageColor3 = Color3.new(1, 0.8, 0),
				[UI.Event] = {
					Activated = function()
						_K.Util.Services.AvatarEditorService:PromptSetFavorite(adminModelId, 1, true)
					end,
				},
				UI.new "Tooltip" {
					Text = "Add to Favorites",
				},
			},
		},

		UI.new "TextLabel" {
			Name = "Price",
			LayoutOrder = 8,
			AutoLocalize = false,
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
			Font = UI.Theme.FontMono,
			TextSize = UI.Theme.FontSizeLarge,
			TextColor3 = UI.Theme.PrimaryText,
			TextWrapped = true,
			Size = UI.computeFrom(UDim2.new, 0, UI.Theme.FontSizeLarge, 0, 32),
			Text = "<b>FREE</b>",
			RichText = true,
		},

		[UI.Event] = {
			Activated = function()
				UI.Scope.lastAttemptedPurchase = adminModelId
				if UI.Scope.AllowThirdPartySales then
					UI.Scope.purchaseDialog.Visible:set(false)
					_K.Util.Services.MarketplaceService:PromptPurchase(_K.UI.LocalPlayer, adminModelId)
				else
					UI.Scope.purchaseDialog.Text:set(thirdPartyText)
					UI.Scope.purchaseLink.Text = "https://create.roblox.com/store/asset/" .. adminModelId
					UI.Scope.purchaseDialog.Visible:set(true)
				end
			end,
		},
	}

	UI.new "Tooltip" {
		Parent = adminModelButton,
		Text = "🚀 Used by <b>30M+</b> developers since 2011, Kohl's Admin is the leading tool for experience management.",
		TextXAlignment = Enum.TextXAlignment.Left,
		Visible = adminModelButton._hovering,
	}

	task.defer(function()
		local ok, owned = _K.Util.Retry(function()
			return _K.Util.Services.MarketplaceService:PlayerOwnsAsset(_K.UI.LocalPlayer, adminModelId)
		end, 5, 1, 2)
		if ok and owned then
			adminModelButton._content.Price.Text = `<b>OWNED</b>`
		end
	end)

	task.defer(function()
		local success, result = _K.Util.Retry(function()
			return PolicyService:GetPolicyInfoForPlayerAsync(Players.LocalPlayer)
		end, 5, 0.2, 2)

		local discordInvite = success
			and result.AllowedExternalLinkReferences
			and table.find(result.AllowedExternalLinkReferences, "Discord")

		if discordInvite then
			UI.new "TextLabel" {
				Parent = scroller,
				LayoutOrder = 4,
				AutoLocalize = false,
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				Font = UI.Theme.Font,
				TextSize = UI.Theme.FontSize,
				TextColor3 = UI.Theme.PrimaryText,
				TextWrapped = true,
				Size = UDim2.new(1, 0, 0, 24),
				Text = `<b>Need help or want to contribute?</b>\n<font transparency="0.33">Join the <b>Kohl's Admin</b> Discord community!</font>`,
				RichText = true,
			}

			UI.new "TextBox" {
				Parent = scroller,
				LayoutOrder = 5,
				Name = "Invite",
				AutoLocalize = false,
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundColor3 = Color3.fromHex("#5865F2"),
				Font = UI.Theme.FontMono,
				TextSize = UI.Theme.FontSize,
				TextColor3 = Color3.new(1, 1, 1),
				Text = "https://discord.gg/kohl",
				TextWrapped = true,
				TextEditable = false,
				ClearTextOnFocus = false,

				UI.new "UICorner" {
					CornerRadius = UI.Theme.CornerRadius,
				},
				UI.new "UIPadding" {
					PaddingLeft = UI.Theme.Padding,
					PaddingRight = UI.Theme.Padding,
					PaddingTop = UI.Theme.Padding,
					PaddingBottom = UI.Theme.Padding,
				},
			}
		end

		local order = 1
		for _, group in CREDITS do
			UI.new "TextLabel" {
				AutoLocalize = false,
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
			task.defer(function()
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
	end)

	return scroller._instance
end

return About
