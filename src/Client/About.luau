local UI = require(script.Parent.UI)
local CREDITS = require(script.Parent.Credits)
local UserFrame = require(script.Parent.UserFrame)

local About = {}
About.__index = About

function About.new(_K)
	local scroller = UI.new "Scroller" {
		Name = "About",
	}

	task.defer(function()
		local thirdPartyText = "Copy the link below to continue."
			.. "\n<font transparency='0.5'>Rejoin after your purchase to get your perks!</font>"

		local adminModelId = 172732271
		local adminModelButton = UI.new "Button" {
			Name = "adminModelButton",
			AutomaticSize = Enum.AutomaticSize.X,
			Icon = "rbxasset://textures/ui/common/robux.png",
			IconProperties = { ImageColor3 = UI.Theme.PrimaryText },
			IconRightAlign = true,
			Label = "<b>Get Kohl's Admin</b>",
			TextXAlignment = Enum.TextXAlignment.Left,

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
					Activated = function()
						_K.Service.AvatarEditor:PromptSetFavorite(adminModelId, 1, true)
					end,
					UI.new "Tooltip" {
						Text = "Add to Favorites",
					},
				},
			},

			UI.new "TextLabel" {
				Name = "Price",
				AutoLocalize = false,
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = 1,
				FontFace = UI.Theme.FontMono,
				TextSize = UI.Theme.FontSizeLarge,
				TextColor3 = UI.Theme.PrimaryText,
				TextStrokeColor3 = UI.Theme.Primary,
				TextStrokeTransparency = UI.Theme.TextStrokeTransparency,
				TextWrapped = true,
				Size = function()
					return UDim2.new(0, UI.Theme.FontSizeLarge(), 0, 32)
				end,
				Text = "<b>FREE</b>",
				RichText = true,
			},

			Activated = function()
				_K.client.lastAttemptedPurchase = adminModelId
				_K.client.purchaseDialog.Title("Get Kohl's Admin")
				_K.client.purchaseDialog.Text(thirdPartyText)
				_K.client.purchaseLink._instance.Text = "create.roblox.com/store/asset/" .. adminModelId
				if _K.client.AllowThirdPartySales then
					_K.client.purchaseDialog.Visible(false)
					_K.Service.Marketplace:PromptPurchase(_K.LocalPlayer, adminModelId)
				else
					_K.client.purchaseDialog.Visible(true)
				end
			end,
		}

		UI.new "Tooltip" {
			Parent = adminModelButton,
			Text = "Used by <b>32M+</b> developers since 2011, Kohl's Admin is the longest-running and most reliable admin solution on Roblox.",
			Hovering = adminModelButton._hovering,
		}

		task.defer(function()
			local ok, owned = _K.Util.Retry(function()
				return _K.Service.Marketplace:PlayerOwnsAsset(_K.LocalPlayer, adminModelId)
			end)
			if ok and owned then
				adminModelButton._content.Price.Text = `<b>OWNED</b>`
				adminModelButton._content.Price.TextTransparency = 0.5
			end
		end)

		local gamesTooltipText = "Find games using Kohl's Admin!\n\n"
			.. "<font transparency='0.5'>Check the Kohl's Admin <b>Settings</b> script in Studio to add your game to the charts.</font>\n\n"
			.. "<b>Game Creators</b> get up to <font color='#0f0'><b>40%</b></font> when "
			.. "<font transparency='0.5'><b>Third Party Purchases</b></font> are enabled in their Roblox Game Settings!"

		local communityLink = UI.new "Link" {
			Name = "CatalogLink",
			Text = "roblox.com/communities/3403354",
			Visible = false,
		}

		local communityButton
		communityButton = UI.new "Button" {
			Label = "Join Community",
			BackgroundColor3 = Color3.fromRGB(51, 95, 255),
			BackgroundTransparency = 0.25,
			HoverTransparency = 0,
			AutomaticSize = Enum.AutomaticSize.X,
			Activated = function()
				if not pcall(_K.Service.Group.PromptJoinAsync, _K.Service.Group, 3403354) then
					communityButton._instance.Visible = false
					communityLink._instance.Visible = true
					communityLink:Select()
				end
			end,
		}

		local communityFrame = UI.new "Frame" {
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.XY,
			Visible = false,

			UI.new "UIListLayout" {
				FillDirection = Enum.FillDirection.Vertical,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UI.Theme.Padding,
			},

			UI.new "TextLabel" {
				AutoLocalize = false,
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = 1,
				FontFace = UI.Theme.Font,
				TextSize = UI.Theme.FontSize,
				TextColor3 = UI.Theme.PrimaryText,
				TextStrokeColor3 = UI.Theme.Primary,
				TextStrokeTransparency = UI.Theme.TextStrokeTransparency,
				TextWrapped = true,
				Size = UDim2.new(0, 0, 0, 0),
				Text = "<b>Join our community for cool perks!</b>",
				RichText = true,
				UI.new "Tooltip" {
					Text = gamesTooltipText,
				},
			},

			communityButton,
			communityLink,

			UI.new "Frame" { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0) },
		}

		task.spawn(function()
			if not _K.Util.Retry(_K.LocalPlayer.IsInGroup, math.huge, nil, _K.LocalPlayer, 3403354) then
				communityFrame.Visible = true
			end
		end)

		UI.edit(scroller._instance, {

			UI.new "TextLabel" {
				AutoLocalize = false,
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				FontFace = UI.Theme.Font,
				TextSize = UI.Theme.FontSize,
				TextColor3 = UI.Theme.PrimaryText,
				TextStrokeColor3 = UI.Theme.Primary,
				TextStrokeTransparency = UI.Theme.TextStrokeTransparency,
				TextWrapped = true,
				Size = UDim2.new(1, 0, 0, 0),
				Text = "<b>Kohl's Admin</b>\n<font transparency='0.5'><i>Embrace creativity, not chaos.</i>\n\n<b>Stop playing. Take command.</b> Get the same powerful tools used here for your own games. Total control, advanced security, and professional moderation are yours for free.</font>",
				RichText = true,

				UI.new "UISizeConstraint" {
					MaxSize = Vector2.new(420, math.huge),
				},
			},
			UI.new "Frame" { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0) },

			adminModelButton,
			UI.new "Frame" { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0) },

			communityFrame,

			UI.new "TextLabel" {
				AutoLocalize = false,
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = 1,
				FontFace = UI.Theme.Font,
				TextSize = UI.Theme.FontSize,
				TextColor3 = UI.Theme.PrimaryText,
				TextStrokeColor3 = UI.Theme.Primary,
				TextStrokeTransparency = UI.Theme.TextStrokeTransparency,
				TextWrapped = true,
				Size = UDim2.new(0, 0, 0, 0),
				Text = "<b>Looking for more games with Kohl's Admin?</b>",
				RichText = true,
				UI.new "Tooltip" {
					Text = gamesTooltipText,
				},
			},

			UI.new "Frame" {
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = 1,

				UI.new "UIListLayout" {
					FillDirection = Enum.FillDirection.Horizontal,
					Padding = UI.Theme.PaddingWithStroke,
					SortOrder = Enum.SortOrder.LayoutOrder,
					VerticalAlignment = Enum.VerticalAlignment.Center,
				},

				UI.new "ImageButton" {
					BackgroundTransparency = 1,
					Size = UDim2.new(0, 24, 0, 24),
					Image = "rbxasset://textures/ui/InspectMenu/ico_favorite@2x.png",
					ImageColor3 = Color3.new(1, 0.8, 0),
					Activated = function()
						_K.Service.AvatarEditor:PromptSetFavorite(17873329124, 1, true)
					end,
					UI.new "Tooltip" {
						Text = "Add to Favorites",
					},
				},
				UI.new "Link" {
					Name = "CatalogLink",
					Text = "roblox.com/games/17873329124",
					Tooltip = `<b>Copy:</b> Ctrl + C\n\n{gamesTooltipText}`,
				},
			},

			UI.new "Frame" { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0) },
		})

		UI.edit(scroller._instance.UIListLayout, {
			Padding = UI.Theme.PaddingWithStroke,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
		})

		task.defer(function()
			local credits = UI.new "Frame" {
				Name = "Credits",
				Parent = scroller,
				LayoutOrder = 1e6,
				AutomaticSize = Enum.AutomaticSize.Y,
				Size = UDim2.new(1, 0, 0, 0),
				BackgroundTransparency = 1,

				UI.new "UIListLayout" {
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UI.Theme.PaddingDouble,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
				},
			}

			local order = 1
			for _, group in CREDITS do
				UI.new "TextLabel" {
					AutoLocalize = false,
					Parent = credits,
					LayoutOrder = order,
					Name = group.Title,
					BackgroundTransparency = 1,
					FontFace = UI.Theme.FontHeavy,
					TextTruncate = Enum.TextTruncate.SplitWord,
					TextSize = UI.Theme.FontSizeLargest,
					TextColor3 = UI.Theme.PrimaryText,
					TextStrokeColor3 = UI.Theme.Primary,
					TextStrokeTransparency = UI.Theme.TextStrokeTransparency,
					Size = UDim2.new(1, 0, 0, 24),
					Text = string.upper(group.Title),
					TextTransparency = 0.5,
				}
				order += 1
				local flexFrame = UI.new "Frame" {
					Parent = credits,
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
						local userFrame = UserFrame(_K.LocalPlayer.UserId, "You", nil, false)
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
	end)

	return scroller._instance
end

return About
