local VIP = {}
VIP.__index = VIP

function VIP.new(_K)
	local UI = _K.UI

	local thirdPartyText = "<font color='#fd0'>The game developer has disabled <b>Third Party Purchases</b>!</font>\n\n"
		.. "<font transparency='0.5'>Copy the link below to purchase.</font>\n"
		.. "<font color='#f00'><b>To receive perks, join a new server after your purchase!</b></font>"

	local equippedUGC = {}
	local debounceEquip = _K.Util.Function.debounce(0.25, function(id, equip, equipped, name, button)
		local existing = equippedUGC[equip]
		if existing and existing ~= button then
			existing.BackgroundColor3:set(Color3.fromRGB(0, 200, 0))
			existing.Label:set("<b>EQUIP</b>")
		end

		if equipped then
			equippedUGC[equip] = button
			button.BackgroundColor3:set(Color3.fromRGB(200, 0, 0))
			button.Label:set("<b>UNEQUIP</b>")
		else
			equippedUGC[equip] = nil
			button.BackgroundColor3:set(Color3.fromRGB(0, 200, 0))
			button.Label:set("<b>EQUIP</b>")
		end

		_K.Remote.VIPUGCMethod:FireServer(id, equip, equipped, name)
	end)
	local donationLevel = UI.state(_K.UI.LocalPlayer, "Attribute:_KDonationLevel")

	-- THIRD PARTY PURCHASES HANDLING

	UI.Scope.AllowThirdPartySales = true
	UI.Scope.lastAttemptedPurchase = false

	local purchaseLink = UI.new "TextBox" {
		Name = "Link",
		LayoutOrder = 10,
		AutoLocalize = false,
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundColor3 = UI.Theme.Secondary,
		BackgroundTransparency = 0.25,
		Font = UI.Theme.FontMono,
		TextSize = UI.Theme.FontSizeSmall,
		TextColor3 = UI.Theme.SecondaryText,
		Text = "https://roblox.com/game-pass/5391355/",
		TextWrapped = true,
		TextEditable = false,
		ClearTextOnFocus = false,
		Visible = UI.Scope.settings.gameHubEnabled,

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

	local purchaseDialog
	purchaseDialog = UI.new "Dialog" {
		Parent = UI.LayerTop,
		Title = "Kohl's Admin Purchase",
		Text = thirdPartyText,
		Visible = false,
		ExitButton = true,
		BackgroundTransparency = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.new(0, 320, 0, 0),
		ZIndex = 1000,
		Close = function()
			UI.Scope.lastAttemptedPurchase = false
			purchaseDialog.Visible:set(false)
		end,

		purchaseLink,
	}
	UI.Scope.purchaseDialog = purchaseDialog
	UI.Scope.purchaseLink = purchaseLink

	local con
	con = _K.Util.Services.LogService.MessageOut:Connect(function(message, messageType)
		if messageType == Enum.MessageType.MessageWarning and string.find(message, "AllowThirdPartySales") then
			con:Disconnect()
			UI.Scope.AllowThirdPartySales = false
			if UI.Scope.lastAttemptedPurchase then
				purchaseDialog._instance.Visible = true
			end
		end
	end)

	-- CUSTOM UGC

	local customUGC = UI.new "Frame" {
		Name = "UGC",
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -2, 0, 0),

		UI.new "UIListLayout" {
			SortOrder = Enum.SortOrder.LayoutOrder,
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalFlex = Enum.UIFlexAlignment.SpaceEvenly,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UI.Theme.PaddingDouble,
			Wraps = true,
		},
	}

	for i, ugc in
		{
			{
				tip = "🕊️ <sc><b>Light Wings</b></sc>\n<font transparency='0.33'>Provides the following special effects in participating experiences using Kohl's Admin:</font>"
					.. "\n - Flying Animations 💫\n - Neon Material ✨\n\n<font transparency='0.66'>Animator: <b>@LuhHorsie</b>\nModeler: <b>@HyperbolicHydra</b>\nScripter: <b>@Scripth</b></font>",
				id = 133292294488871,
				equip = "rbxassetid://89119211625300",
				name = "Light Wings",
				level = 3,
			},
			{
				tip = "👑 <sc><b>Light Crown</b></sc>\n<font transparency='0.33'>Provides the following special effects in participating experiences using Kohl's Admin:</font>"
					.. "\n - Fire Effect 🔥\n - Neon Material ✨\n - Spinning 💫",
				id = 18966788838,
				equip = "rbxassetid://18966762965",
				name = "Light Crown",
				level = 2,
			},
			{
				tip = "🕊️ <sc><b>Dark Wings</b></sc>\n<font transparency='0.33'>Provides the following special effects in participating experiences using Kohl's Admin:</font>"
					.. "\n - Flying Animations 💫\n - Neon Material ✨\n\n<font transparency='0.66'>Animator: <b>@LuhHorsie</b>\nModeler: <b>@HyperbolicHydra</b>\nScripter: <b>@Scripth</b></font>",
				id = 110848154960799,
				equip = "rbxassetid://89119211625300",
				name = "Dark Wings",
				level = 3,
			},
			{
				tip = "👑 <sc><b>Dark Crown</b></sc>\n<font transparency='0.33'>Provides the following special effects in participating experiences using Kohl's Admin:</font>"
					.. "\n - Fire Effect 🔥\n - Neon Material ✨\n - Spinning 💫",
				id = 106645613603989,
				equip = "rbxassetid://18966762965",
				name = "Dark Crown",
				level = 2,
			},
			{
				tip = "🕊️ <sc><b>Gold Wings</b></sc>\n<font transparency='0.33'>Provides the following special effects in participating experiences using Kohl's Admin:</font>"
					.. "\n - Flying Animations 💫\n - Neon Material ✨\n\n<font transparency='0.66'>Animator: <b>@LuhHorsie</b>\nModeler: <b>@HyperbolicHydra</b>\nScripter: <b>@Scripth</b></font>",
				id = 92807314389236,
				equip = "rbxassetid://89119211625300",
				name = "Gold Wings",
				level = 3,
			},
			{
				tip = "👑 <sc><b>Gold Crown</b></sc>\n<font transparency='0.33'>Provides the following special effects in participating experiences using Kohl's Admin:</font>"
					.. "\n - Fire Effect 🔥\n - Neon Material ✨\n - Spinning 💫",
				id = 99317257118206,
				equip = "rbxassetid://18966762965",
				name = "Gold Crown",
				level = 2,
			},
		}
	do
		-- TODO: equip button for donation level == 4 and if the own
		task.defer(function()
			local owned = (donationLevel._value or 0) >= (ugc.level or 3)
			if not owned then
				local ok, result = _K.Util.Retry(function()
					return _K.Util.Services.MarketplaceService:PlayerOwnsAsset(_K.UI.LocalPlayer, ugc.id)
				end, 5, 1, 2)
				if ok and result then
					owned = result
				end
			end
			ugc.price = if owned then "EQUIP" else "?"

			local frame = UI.new "Frame" {
				Parent = customUGC,
				LayoutOrder = i,
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = 1,

				UI.new "ImageLabel" {
					BackgroundTransparency = 1,
					Size = UDim2.new(0, 80, 0, 80),
					Image = "rbxasset://textures/meshPartFallback.png",
					ImageTransparency = 0.75,
					ScaleType = Enum.ScaleType.Tile,
					TileSize = UDim2.fromOffset(16, 16),

					UI.new "UICorner" {
						CornerRadius = UI.Theme.CornerRadius,
					},
					UI.new "UIStroke" {
						Enabled = UI.Theme.StrokeEnabled,
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
						Transparency = UI.Theme.TransparencyClamped,
						Color = UI.Theme.Border,
					},

					UI.new "ImageLabel" {
						BackgroundTransparency = 1,
						Size = UDim2.new(1, 0, 1, 0),
						Image = `rbxthumb://type=Asset&id={ugc.id}&w=150&h=150`,

						UI.new "ImageLabel" {
							BackgroundTransparency = 1,
							Size = UDim2.new(0, 28, 0, 28),
							Position = UDim2.new(0, 2, 0, 2),
							Image = "rbxasset://textures/ui/InspectMenu/ico_favorite@2x.png",
							ImageColor3 = Color3.new(0, 0, 0),
							ImageTransparency = 0.875,
						},
						UI.new "ImageButton" {
							BackgroundTransparency = 1,
							Position = UDim2.new(0, 4, 0, 4),
							Size = UDim2.new(0, 24, 0, 24),
							Image = "rbxasset://textures/ui/InspectMenu/ico_favorite@2x.png",
							ImageColor3 = Color3.new(1, 0.8, 0),
							[UI.Event] = {
								Activated = function()
									_K.Util.Services.AvatarEditorService:PromptSetFavorite(ugc.id, 1, true)
								end,
							},
							UI.new "Tooltip" {
								Text = "Add to Favorites",
							},
						},
					},
				},
			}

			local button, try, trying
			local function tryDone()
				trying = nil
				if not owned then
					button.Label:set(`<b>{ugc.price}</b>`)
					button._content.IconFrame.Visible = true
					button._content.Label.TextXAlignment = Enum.TextXAlignment.Left
				end
			end

			button = UI.new "Button" {
				Parent = frame,
				Icon = if owned then nil else "rbxasset://textures/ui/common/robux.png",
				IconRightAlign = not owned,
				Label = `<b>{ugc.price}</b>`,
				LabelProperties = {
					Font = UI.Theme.FontMono,
					TextSize = UI.Theme.FontSizeLarge,
					TextXAlignment = if owned then nil else Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.None,
				},
				BackgroundColor3 = Color3.fromRGB(0, 200, 0),
				BackgroundTransparency = 0.5,
				Size = UDim2.new(0, 80, 0, 32),
				Position = UDim2.fromOffset(0, 88),

				[UI.Attribute] = {
					Price = ugc.price,
				},

				[UI.Event] = {
					Activated = function()
						if try then
							try, trying = nil, true
							local existing = equippedUGC[ugc.equip]
							debounceEquip(ugc.id, ugc.equip, true, ugc.name, button)
							task.delay(15, function()
								if trying and equippedUGC[ugc.equip] == button then
									debounceEquip(ugc.id, ugc.equip, false, ugc.name, button)
								end
								task.delay(0.25, tryDone)
							end)
							_K.client.Notify({
								Text = `Trying <b>{ugc.name}</b>.`,
								Duration = 15,
								UserFrame = {},
							})

							if existing and existing ~= button then
								task.delay(0.25, function()
									existing.Label:set(`<b>{existing._instance:GetAttribute("Price")}</b>`)
									existing._content.IconFrame.Visible = true
									existing._content.Label.TextXAlignment = Enum.TextXAlignment.Left
								end)
							end

							return
						end

						local equipped = equippedUGC[ugc.equip]
						if owned or (trying and equipped == button) then
							equipped = equipped and equipped == button
							debounceEquip(ugc.id, ugc.equip, not equipped, ugc.name, button)
							if trying and equipped then
								task.delay(0.25, tryDone)
							end
							return
						end

						UI.Scope.lastAttemptedPurchase = ugc.id
						if UI.Scope.AllowThirdPartySales then
							purchaseDialog.Visible:set(false)
							_K.Util.Services.MarketplaceService:PromptPurchase(_K.UI.LocalPlayer, ugc.id)
						else
							-- set textbox text
							purchaseDialog.Text:set(thirdPartyText)
							purchaseLink.Text = "https://roblox.com/catalog/" .. ugc.id
							purchaseDialog.Visible:set(true)
						end
					end,
				},
			}

			if not owned then
				try = true
				button.Label:set("<b>TRY</b>")
				button._content.IconFrame.Visible = false
				button._content.Label.TextXAlignment = Enum.TextXAlignment.Center

				local con
				con = _K.Util.Services.MarketplaceService.PromptPurchaseFinished:Connect(
					function(player, assetId, purchased)
						if purchased and assetId == ugc.id and player == _K.UI.LocalPlayer then
							con:Disconnect()
							owned, try = true, nil
							button.Label:set("<b>EQUIP</b>")
							button._content.IconFrame.Visible = false
							button._content.Label.TextXAlignment = Enum.TextXAlignment.Center
						end
					end
				)

				local ok, result = _K.Util.Retry(function()
					return _K.Util.Services.MarketplaceService:GetProductInfo(ugc.id, Enum.InfoType.Asset).PriceInRobux
				end, 5, 1, 2)
				if ok then
					ugc.price = result or "?"
					button._instance:SetAttribute("Price", ugc.price)
				end
			end

			if ugc.tip then
				UI.new "Tooltip" {
					Parent = button._instance,
					Text = ugc.tip,
					TextXAlignment = Enum.TextXAlignment.Left,
					Visible = button._hovering,
				}
			end
		end)
	end

	-- SUPPORT GAMEPASSES

	local gamePasses = UI.new "Frame" {
		Name = "GamePasses",
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -2, 0, 0),

		UI.new "UIListLayout" {
			SortOrder = Enum.SortOrder.LayoutOrder,
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalFlex = Enum.UIFlexAlignment.SpaceEvenly,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UI.Theme.PaddingDouble,
			Wraps = true,
		},
	}

	local passDefinition = {
		{ name = "<font color='#bf0'><sc><b>Tip</b></sc></font>", id = 5391355 },
		{ name = "<font color='#8f0'><sc><b>Donation</b></sc></font>", id = 5391356 },
		{ name = "<font color='#0f0'><sc><b>Gift</b></sc></font>", id = 933980650 },
		{ name = "<font color='#0f8'><sc><b>Tribute</b></sc></font>", id = 933582848 },
		{ name = "<font color='#0ff'><sc><b>Patron</b></sc></font>", id = 938480383 },
		{ name = "<font color='#0bf'><sc><b>Benefactor</b></sc></font>", id = 939618404 },
		{ name = "<font color='#80f'><sc><b>Luminary</b></sc></font>", id = 936146448 },
		{ name = "<font color='#f0f'><sc><b>Epic</b></sc></font>", id = 941076536 },
		{ name = "<font color='#f08'><sc><b>Hero</b></sc></font>", id = 941162509 },
		{ name = "<font color='#f00'><sc><b>Legend</b></sc></font>", id = 941006661 },
		{ name = "<font color='#fff'><sc><b>Mythic</b></sc></font>", id = 983235767 },
	}

	for i, pass in passDefinition do
		task.defer(function()
			local success, owned = _K.Util.Retry(function()
				return _K.Util.Services.MarketplaceService:UserOwnsGamePassAsync(_K.UI.LocalPlayer.UserId, pass.id)
			end, 5, 1, 2)

			pass.price = "OWNED"

			local button = UI.new "Button" {
				Parent = gamePasses,
				LayoutOrder = i,
				Icon = "rbxasset://textures/ui/common/robux.png",
				IconRightAlign = true,
				Label = pass.name,
				HoverTransparency = 0.5,
				TextXAlignment = Enum.TextXAlignment.Left,
				Size = UDim2.new(0, 128, 0, 32),

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
					Text = `<b>{pass.price}</b>`,
					RichText = true,
				},

				[UI.Event] = {
					Activated = function()
						UI.Scope.lastAttemptedPurchase = pass.id
						if UI.Scope.AllowThirdPartySales then
							purchaseDialog.Visible:set(false)
							_K.Util.Services.MarketplaceService:PromptGamePassPurchase(_K.UI.LocalPlayer, pass.id)
						else
							purchaseDialog.Text:set(thirdPartyText)
							purchaseLink.Text = "https://roblox.com/game-pass/" .. pass.id
							purchaseDialog.Visible:set(true)
						end
					end,
				},
			}
			UI.new "UIFlexItem" {
				Parent = button._instance,
				FlexMode = Enum.UIFlexMode.Fill,
			}
			UI.new "Tooltip" {
				Parent = button._instance,
				Text = "❤️ Thanks for supporting Kohl's Admin!\n<b>This doesn't provide any in-game benefits!</b>",
				TextXAlignment = Enum.TextXAlignment.Left,
				Visible = button._hovering,
			}

			if success and not owned then
				local con
				con = _K.Util.Services.MarketplaceService.PromptGamePassPurchaseFinished:Connect(
					function(userId, passId, purchased)
						if purchased and passId == pass.id and userId == _K.UI.LocalPlayer.UserId then
							con:Disconnect()
							owned = true
							button._content.Price.Text = "<b>OWNED</b>"
						end
					end
				)

				local ok, result = _K.Util.Retry(function()
					return _K.Util.Services.MarketplaceService:GetProductInfo(pass.id, Enum.InfoType.GamePass).PriceInRobux
				end, 5, 1, 2)
				if ok then
					pass.price = result or "?"
					if not owned then
						button._content.Price.Text = `<b>{pass.price}</b>`
					end
				end
			end
		end)
	end

	local vipList = UI.new "Frame" {
		Name = "VIP",
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -2, 0, 0),

		UI.new "UIListLayout" {
			SortOrder = Enum.SortOrder.LayoutOrder,
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalFlex = Enum.UIFlexAlignment.Fill,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UI.Theme.PaddingDouble,
			Wraps = true,
		},

		UI.new "Button" {
			Icon = "rbxasset://textures/ui/common/robux.png",
			IconRightAlign = true,
			Label = "<font color='#fc0'><sc><b>VIP</b></sc></font>",
			HoverTransparency = 0.5,
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.new(0, 128, 0, 32),

			UI.new "TextLabel" {
				LayoutOrder = 8,
				AutoLocalize = false,
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = 1,
				Font = UI.Theme.FontMono,
				TextSize = UI.Theme.FontSizeLarge,
				TextColor3 = UI.Theme.PrimaryText,
				TextWrapped = true,
				Size = UI.computeFrom(UDim2.new, 0, UI.Theme.FontSizeLarge, 0, 32),
				Text = UI.compute(function(use)
					return if (use(donationLevel) or 0) < 3 then `<b>$4.99</b>` else "<b>OWNED</b>"
				end),
				RichText = true,
			},
			[UI.Event] = {
				Activated = function()
					purchaseDialog.Text:set(thirdPartyText)
					UI.Scope.lastAttemptedPurchase = true
					purchaseLink.Text = "https://create.roblox.com/store/asset/128259181447764"
					purchaseDialog.Visible:set(true)
				end,
			},
		},
	}

	local vipPassId = 5411126
	local vipButton = UI.new "Button" {
		Parent = vipList,
		Icon = "rbxasset://textures/ui/common/robux.png",
		IconRightAlign = true,
		Label = "<font color='#fc0'><sc><b>VIP</b></sc></font>",
		HoverTransparency = 0.5,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(0, 128, 0, 32),
		Visible = UI.compute(function(use)
			return (use(donationLevel) or 0) < 3
		end),

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
			Text = "?",
			RichText = true,
		},
		[UI.Event] = {
			Activated = function()
				UI.Scope.lastAttemptedPurchase = vipPassId
				if UI.Scope.AllowThirdPartySales then
					purchaseDialog.Visible:set(false)
					_K.Util.Services.MarketplaceService:PromptGamePassPurchase(_K.UI.LocalPlayer, vipPassId)
				else
					purchaseDialog.Text:set(thirdPartyText)
					purchaseLink.Text = "https://roblox.com/game-pass/" .. vipPassId
					purchaseDialog.Visible:set(true)
				end
			end,
		},
	}

	task.defer(function()
		local success, owned = _K.Util.Retry(function()
			return _K.Util.Services.MarketplaceService:UserOwnsGamePassAsync(_K.UI.LocalPlayer.UserId, vipPassId)
		end, 5, 1, 2)
		print(success, owned)

		if success then
			if owned then
				vipButton._content.Price.Text = "<b>OWNED</b>"
				return
			end

			local conn
			conn = _K.Util.Services.MarketplaceService.PromptGamePassPurchaseFinished:Connect(
				function(userId, passId, purchased)
					if purchased and passId == vipPassId and userId == _K.UI.LocalPlayer.UserId then
						conn:Disconnect()
						owned = true
						vipButton._content.Price.Text = "<b>OWNED</b>"
					end
				end
			)

			local ok, result = _K.Util.Retry(function()
				return _K.Util.Services.MarketplaceService:GetProductInfo(vipPassId, Enum.InfoType.GamePass).PriceInRobux
			end, 5, 1, 2)
			if ok then
				if not owned then
					vipButton._content.Price.Text = `<b>{result or "?"}</b>`
				end
			end
		end
	end)

	local scroller = UI.new "Scroller" {
		Name = "VIP",

		UI.new "TextLabel" {
			Name = "Status",
			LayoutOrder = -9,
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundColor3 = Color3.new(1, 0, 0),
			BackgroundTransparency = 0.75,
			Font = UI.Theme.FontMono,
			TextSize = UI.Theme.FontSizeSmall,
			TextColor3 = Color3.new(1, 1, 1),
			Text = `<sc>VIP benefits have been <b>disabled</b> by a developer!</sc>`,
			TextStrokeTransparency = 0.875,
			TextWrapped = true,
			RichText = true,
			Visible = UI.compute(function(use)
				return not use(UI.Scope.settings.vip)
			end),

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

		UI.new "TextLabel" {
			AutoLocalize = false,
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Font = UI.Theme.Font,
			TextSize = UI.Theme.FontSize,
			TextColor3 = UI.Theme.PrimaryText,
			TextWrapped = true,
			Size = UDim2.new(1, 0, 0, 0),
			Text = "✨ <b>Become a VIP</b>\n<font transparency='0.5'>Unlock exclusive commands in participating experiences.</font>",
			RichText = true,
		},

		vipList,

		UI.new "TextLabel" {
			AutoLocalize = false,
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Font = UI.Theme.Font,
			TextSize = UI.Theme.FontSize,
			TextColor3 = UI.Theme.PrimaryText,
			TextWrapped = true,
			Size = UDim2.new(1, 0, 0, 0),
			Text = "<b>❤️ Kohl's Admin?</b>\n<font transparency='0.5'>Donate to help us build amazing new features!</font>",
			RichText = true,
		},

		gamePasses,
		customUGC,

		UI.new "TextLabel" {
			AutoLocalize = false,
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Font = UI.Theme.Font,
			TextSize = UI.Theme.FontSize,
			TextColor3 = UI.Theme.PrimaryText,
			TextWrapped = true,
			Size = UDim2.new(1, 0, 0, 0),
			Text = "<b>Game Creators</b> get up to <font color='#0f0'><b>40%</b></font> when "
				.. "<font transparency='0.5'><b>Third Party Purchases</b></font> are enabled in their Roblox Game Settings!",
			RichText = true,
		},

		UI.new "TextBox" {
			Name = "CatalogLink",
			AutoLocalize = false,
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundColor3 = UI.Theme.Secondary,
			BackgroundTransparency = 0.25,
			Font = UI.Theme.FontMono,
			TextSize = UI.Theme.FontSize,
			TextColor3 = UI.Theme.SecondaryText,
			Text = "https://roblox.com/games/17873329124/",
			TextWrapped = true,
			TextEditable = false,
			ClearTextOnFocus = false,
			Visible = UI.Scope.settings.gameHubEnabled,

			UI.new "UICorner" {
				CornerRadius = UI.Theme.CornerRadius,
			},
			UI.new "UIPadding" {
				PaddingLeft = UI.Theme.Padding,
				PaddingRight = UI.Theme.Padding,
				PaddingTop = UI.Theme.Padding,
				PaddingBottom = UI.Theme.Padding,
			},
			UI.new "Tooltip" {
				Text = "The hub for games using Kohl's Admin!\n\n<font transparency='0.5'>Check the <i>Kohl's Admin</i> <b>Settings</b> script in Roblox Studio for more information.</font>",
				TextXAlignment = Enum.TextXAlignment.Left,
			},
		},
	}

	UI.edit(scroller._instance.UIListLayout, {
		Padding = UI.Theme.PaddingDouble,
		HorizontalAlignment = "Center",
	})

	return scroller._instance
end

return VIP
