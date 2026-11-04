local UI = require(script.Parent:WaitForChild("UI"))
local UserFrame = require(script.Parent:WaitForChild("UserFrame"))
local Contributions = require(script:WaitForChild("Contributions"))
local CREDITS = require(script:WaitForChild("Credits"))
local Order = require(script:WaitForChild("Order"))

local About = {}
About.__index = About

function About.new(_K)
	local scroller = UI.new "Scroller" {
		Name = "About",
	}

	local STUDIO_DEBUG = _K.DEBUG and _K.IsStudio

	_K.client.AllowThirdPartySales = not STUDIO_DEBUG
	_K.client.lastAttemptedPurchase = false
	_K.client.ownsKAModel = UI.signal(false)

	local KA_MODEL_ID = 172732271

	local purchaseLink = UI.new "Link" {
		LayoutOrder = 10,
		Text = "create.roblox.com/store/asset/" .. KA_MODEL_ID,
	}

	local purchaseKADialog
	purchaseKADialog = UI.new "Dialog" {
		Parent = UI.LayerTop,
		Title = "Get Kohl's Admin",
		Text = "Third-party model sales are disabled in this experience.\n<b>Favorite ⭐</b> Kohl's Admin or copy the Creator Store link below to get it for <b>free</b>!",
		Visible = false,
		Draggable = true,
		ExitButton = true,
		BackgroundTransparency = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(340, 0),
		Modal = true,
		ZIndex = 1000,
		Close = function()
			_K.client.lastAttemptedPurchase = false
			purchaseKADialog.Visible(false)
		end,

		purchaseLink,
	}

	_K.client.purchaseKADialog = purchaseKADialog

	local favoriteConn: RBXScriptConnection?
	local function showFallbackDialog()
		purchaseKADialog.Visible(true)
		purchaseLink:Select()
		local _ = pcall(function()
			_K.Service.AvatarEditor:PromptSetFavorite(KA_MODEL_ID, 1, true)
			if favoriteConn then
				favoriteConn:Disconnect()
			end
			favoriteConn = _K.Service.AvatarEditor.PromptSetFavoriteCompleted:Once(function()
				favoriteConn = nil
				if purchaseKADialog.Visible:peek() then
					purchaseLink:Select()
				end
			end)
		end)
	end

	function _K.client.promptGetKA()
		_K.client.lastAttemptedPurchase = KA_MODEL_ID
		if _K.client.AllowThirdPartySales then
			purchaseKADialog.Visible(false)
			_K.Service.Marketplace:PromptPurchase(_K.LocalPlayer, KA_MODEL_ID)
		else
			showFallbackDialog()
		end
	end

	local con
	con = _K.Service.Log.MessageOut:Connect(function(message, messageType)
		if messageType == Enum.MessageType.MessageWarning and string.find(message, "AllowThirdPartySales") then
			con:Disconnect()
			_K.client.AllowThirdPartySales = false
			if _K.client.lastAttemptedPurchase then
				showFallbackDialog()
			end
		end
	end)

	task.defer(function()
		local ctaLabel = UI.new "TextLabel" {
			AutoLocalize = false,
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			FontFace = UI.Theme.Font,
			TextSize = UI.Theme.FontSize,
			TextColor3 = UI.Theme.PrimaryText,
			TextStrokeColor3 = UI.Theme.Primary,
			TextStrokeTransparency = UI.Theme.TextStrokeTransparency,
			TextWrapped = true,
			Size = UDim2.fromScale(1, 0),
			Text = "<font transparency='0.5'>Add Kohl's Admin to your own games for <b>free</b>; 200+ commands, role permissions, and live moderation tools.</font>",
			RichText = true,

			UI.sizeConstraint {
				max = Vector2.new(420, math.huge),
			},
		}

		local adminModelButton = UI.new "Button" {
			Name = "adminModelButton",
			AutomaticSize = Enum.AutomaticSize.X,
			Icon = "rbxasset://textures/ui/common/robux.png",
			IconProperties = { ImageColor3 = UI.Theme.PrimaryText },
			IconRightAlign = true,
			Label = "<b>Get Kohl's Admin</b>",
			TextXAlignment = Enum.TextXAlignment.Left,

			UI.new "TextLabel" {
				LayoutOrder = 2,
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
					return UDim2.fromOffset(UI.Theme.FontSizeLarge(), 32)
				end,
				Text = "<b>FREE</b>",
				RichText = true,
			},

			Activated = function()
				_K.client.promptGetKA()
			end,
		}

		UI.new "Tooltip" {
			Parent = adminModelButton,
			Text = "Taken by <b>30M+</b> creators since 2010 and running across <b>100K+</b> active games today.",
			Hovering = adminModelButton._hovering,
		}

		local adminModelFrame = UI.new "Frame" {
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,

			UI.list {
				direction = "x",
				gap = UI.Theme.PaddingWithStroke,
				verticalAlign = "center",
			},
			UI.new "Frame" {
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.fromScale(0, 0.5),
				Size = UDim2.fromOffset(28, 28),
				UI.new "ImageLabel" {
					BackgroundTransparency = 1,
					Size = UDim2.fromOffset(28, 28),
					Image = "rbxasset://textures/ui/InspectMenu/ico_favorite@2x.png",
					ImageColor3 = Color3.new(0, 0, 0),
					ImageTransparency = 0.875,
				},
				UI.new "ImageButton" {
					BackgroundTransparency = 1,
					Position = UDim2.fromOffset(2, 2),
					Size = UDim2.fromOffset(24, 24),
					Image = "rbxasset://textures/ui/InspectMenu/ico_favorite@2x.png",
					ImageColor3 = Color3.new(1, 0.8, 0),
					Activated = function()
						local _ = pcall(function()
							_K.Service.AvatarEditor:PromptSetFavorite(KA_MODEL_ID, 1, true)
						end)
					end,
					UI.new "Tooltip" {
						Text = "Add to Favorites",
					},
				},
			},

			adminModelButton,
		}

		local markedOwned = false
		local function markModelOwned()
			if markedOwned then
				return
			end
			markedOwned = true
			_K.client.ownsKAModel(true)
			if not STUDIO_DEBUG then
				adminModelButton._instance.Visible = false
				UI.new "Link" {
					Parent = adminModelFrame,
					LayoutOrder = 3,
					Name = "CatalogLink",
					Text = "create.roblox.com/store/asset/" .. KA_MODEL_ID,
				}
				ctaLabel.Text = "<b>Love the Power?</b>\nDrop a Like 👍 and Favorite ⭐ to support us!"
			end
		end

		local _ = _K.Service.Marketplace.PromptPurchaseFinished:Connect(function(player, assetId, purchased)
			if purchased and assetId == KA_MODEL_ID and player == _K.LocalPlayer then
				markModelOwned()
			end
		end)

		task.defer(function()
			local ok, owned = _K.Util.Retry(function()
				return _K.Service.Marketplace:PlayerOwnsAssetAsync(_K.LocalPlayer, KA_MODEL_ID)
			end)
			if ok and owned then
				markModelOwned()
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

		local communityButton, communityFrame
		communityButton = UI.new "Button" {
			Label = "Join Community",
			BackgroundColor3 = Color3.fromRGB(51, 95, 255),
			BackgroundTransparency = 0.25,
			HoverTransparency = 0,
			AutomaticSize = Enum.AutomaticSize.X,
			Activated = function()
				local ok, result = pcall(_K.Service.Group.PromptJoinAsync, _K.Service.Group, 3403354)
				if ok then
					if result == Enum.GroupMembershipStatus.None then
						return
					end
					communityButton._instance.Visible = false
					communityLink._instance.Visible = true
					communityFrame.TextLabel.Text = "<b>Need help or have a suggestion?</b>"
				else
					communityButton._instance.Visible = false
					communityLink._instance.Visible = true
					communityLink:Select()
				end
			end,
		}

		communityFrame = UI.new "Frame" {
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.XY,
			Visible = true,

			UI.list {
				direction = "y",
				horizontalAlign = "center",
				gap = UI.Theme.Padding,
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
				Text = "<b>Join our community for help and cool perks!</b>",
				RichText = true,
				UI.new "Tooltip" {
					Text = gamesTooltipText,
				},
			},

			communityButton,
			communityLink,
		}

		task.spawn(function()
			local ok, result = _K.Util.Retry(_K.LocalPlayer.IsInGroup, 5, 2, _K.LocalPlayer, 3403354)
			if ok and result then
				communityButton._instance.Visible = false
				communityLink._instance.Visible = true
				communityFrame.TextLabel.Text = "<b>Need help or have a suggestion?</b>"
			end
		end)

		UI.edit(scroller._instance)({

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
				Size = UDim2.fromScale(1, 0),
				Text = "<b>Kohl's Admin</b>\n<font transparency='0.5'><i>Embrace creativity, not chaos.</i></font>",
				RichText = true,
			},
			ctaLabel,

			adminModelFrame,

			communityFrame,

			UI.new "Frame" {
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = 1,

				UI.list {
					direction = "y",
					horizontalAlign = "center",
					gap = UI.Theme.Padding,
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
					Text = "<b>Looking for more games with Kohl's Admin?</b>",
					RichText = true,
					UI.new "Tooltip" {
						Text = gamesTooltipText,
					},
				},

				UI.new "Frame" {
					AutomaticSize = Enum.AutomaticSize.XY,
					BackgroundTransparency = 1,

					UI.list {
						direction = "x",
						gap = UI.Theme.PaddingWithStroke,
						verticalAlign = "center",
					},

					UI.new "ImageButton" {
						BackgroundTransparency = 1,
						Size = UDim2.fromOffset(24, 24),
						Image = "rbxasset://textures/ui/InspectMenu/ico_favorite@2x.png",
						ImageColor3 = Color3.new(1, 0.8, 0),
						Activated = function()
							local _ = pcall(function()
								_K.Service.AvatarEditor:PromptSetFavorite(17873329124, 1, true)
							end)
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
			},
		})

		UI.edit(scroller._instance.UIListLayout)({
			Padding = UI.Theme.PaddingDouble,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
		})

		task.defer(function()
			local credits = UI.new "Frame" {
				Name = "Credits",
				Parent = scroller,
				LayoutOrder = 1e6,
				AutomaticSize = Enum.AutomaticSize.Y,
				Size = UDim2.fromScale(1, 0),
				BackgroundTransparency = 1,

				UI.list {
					gap = UI.Theme.PaddingDouble,
					horizontalAlign = "center",
				},
			}

			local sections = {
				{ Title = "Active contributors", Chips = true, People = Order.active(CREDITS.people) },
				{ Title = "Contributors", Chips = false, People = Order.plain(CREDITS.people) },
				{ Title = "Special Thanks", Chips = true, People = { CREDITS.specialThanks } },
			}

			local order = 1
			for _, group in sections do
				if #group.People == 0 then
					continue
				end
				local sectionFrame = UI.new "Frame" {
					Name = group.Title,
					Parent = credits,
					LayoutOrder = order,
					BackgroundTransparency = 1,
					AutomaticSize = Enum.AutomaticSize.Y,
					Size = UDim2.fromScale(1, 0),

					UI.list {
						gap = UI.Theme.Padding,
						horizontalAlign = "center",
					},
				}
				order += 1

				UI.new "TextLabel" {
					AutoLocalize = false,
					Parent = sectionFrame,
					LayoutOrder = 1,
					Name = "Title",
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

				local flexFrame = UI.new "Frame" {
					Name = "Users",
					Parent = sectionFrame,
					LayoutOrder = 2,
					BackgroundTransparency = 1,
					AutomaticSize = Enum.AutomaticSize.Y,
					Size = UDim2.fromScale(1, 0),

					UI.edit(UI.list {
						direction = "x",
						horizontalAlign = "evenly",
						gap = if group.Chips then UI.Theme.PaddingDouble else UI.Theme.Padding,
						wraps = true,
					})({ HorizontalAlignment = Enum.HorizontalAlignment.Center }),
				}

				task.defer(function()
					for i, person in group.People do
						local known = Contributions.names[person.Id]
						if group.Chips then
							local userFrame =
								UserFrame(person.Id, known and known.displayName, nil, false, known and known.name)
							userFrame:SetAttribute("UserId", person.Id)
							userFrame.LayoutOrder = i
							userFrame.Parent = flexFrame
							if person.Tooltip then
								UI.new "Tooltip" {
									Parent = userFrame,
									Text = person.Tooltip,
								}
							end
						else
							local label = UI.new "TextLabel" {
								_attr_UserId = person.Id,
								AutoLocalize = false,
								Parent = flexFrame,
								LayoutOrder = i,
								Name = "Credit",
								BackgroundTransparency = 1,
								FontFace = UI.Theme.Font,
								TextSize = UI.Theme.FontSize,
								TextColor3 = UI.Theme.PrimaryText,
								TextStrokeColor3 = UI.Theme.Primary,
								TextStrokeTransparency = UI.Theme.TextStrokeTransparency,
								TextTransparency = 0.35,
								AutomaticSize = Enum.AutomaticSize.XY,
								Text = if known then `@{known.name}` else `@{person.Id}`,
							}
							if person.Tooltip then
								UI.new "Tooltip" {
									Parent = label,
									Text = person.Tooltip,
								}
							end
						end
					end
				end)
			end
		end)
	end)

	return scroller
end

return About
