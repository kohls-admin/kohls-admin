local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")

local CREDITS = require(script.Parent.Parent.Credits)
local UserFrame = require(script.Parent.UserFrame)

local About = {}
About.__index = About

function About.new(_K)
	local UI = _K.UI

	local thirdPartyText = "<font color='#fd0'>The game developer has disabled <b>Third Party Purchases</b>!</font>\n\n"
		.. "<font transparency='0.5'>Copy the link below to purchase.</font>\n"
		.. "<font color='#f00'><b>To receive perks, join a new server after your purchase!</b></font>"

	local donationLevel = _K.UI.LocalPlayer:GetAttribute("_KDonationLevel")
	if not donationLevel then
		_K.UI.LocalPlayer:GetAttributeChangedSignal("_KDonationLevel"):Wait()
		donationLevel = _K.UI.LocalPlayer:GetAttribute("_KDonationLevel")
	end

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

	-- THIRD PARTY PURCHASES HANDLING

	_K.client.AllowThirdPartySales = true
	_K.client.lastAttemptedPurchase = false

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
		Visible = _K.client.settings.gameHubEnabled,

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
		Modal = true,
		ZIndex = 1000,
		Close = function()
			_K.client.lastAttemptedPurchase = false
			purchaseDialog.Visible:set(false)
		end,

		purchaseLink,
	}
	_K.client.purchaseDialog = purchaseDialog
	_K.client.purchaseLink = purchaseLink

	local function promptThirdPartyGamePassDialog(passId)
		_K.client.lastAttemptedPurchase = passId
		purchaseLink.Text = "https://roblox.com/game-pass/" .. passId
		if _K.client.AllowThirdPartySales then
			purchaseDialog.Visible:set(false)
			_K.Util.Services.MarketplaceService:PromptGamePassPurchase(_K.UI.LocalPlayer, passId)
		else
			purchaseDialog.Visible:set(true)
		end
	end
	_K.client.promptThirdPartyGamePassDialog = promptThirdPartyGamePassDialog

	local function updatePassPriceText(label: TextLabel, gamePassId: number, ownedText: string?)
		local success, owned = _K.Util.Retry(function()
			return _K.Util.Services.MarketplaceService:UserOwnsGamePassAsync(_K.UI.LocalPlayer.UserId, gamePassId)
		end)

		if success then
			if owned then
				label.Text = ownedText or "<b>OWNED</b>"
				return
			end

			local conn
			conn = _K.Util.Services.MarketplaceService.PromptGamePassPurchaseFinished:Connect(
				function(userId, passId, purchased)
					if purchased and passId == gamePassId and userId == _K.UI.LocalPlayer.UserId then
						conn:Disconnect()
						owned = true
						label.Text = ownedText or "<b>OWNED</b>"
					end
				end
			)

			local ok, result = _K.Util.Retry(function()
				return _K.Util.Services.MarketplaceService:GetProductInfo(gamePassId, Enum.InfoType.GamePass).PriceInRobux
			end)
			if ok then
				if not owned then
					label.Text = `<b>{result or "?"}</b>`
				end
			end
		end
	end

	local con
	con = _K.Util.Services.LogService.MessageOut:Connect(function(message, messageType)
		if messageType == Enum.MessageType.MessageWarning and string.find(message, "AllowThirdPartySales") then
			con:Disconnect()
			_K.client.AllowThirdPartySales = false
			if _K.client.lastAttemptedPurchase then
				purchaseDialog.Visible:set(true)
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
		task.defer(function()
			local owned = (donationLevel or 0) >= (ugc.level or 3)
			if not owned then
				local ok, result = _K.Util.Retry(function()
					return _K.Util.Services.MarketplaceService:PlayerOwnsAsset(_K.UI.LocalPlayer, ugc.id)
				end)
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
							_K.Notify({
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

						_K.client.lastAttemptedPurchase = ugc.id
						purchaseLink.Text = "https://roblox.com/catalog/" .. ugc.id
						if _K.client.AllowThirdPartySales then
							purchaseDialog.Visible:set(false)
							_K.Util.Services.MarketplaceService:PromptPurchase(_K.UI.LocalPlayer, ugc.id)
						else
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
				end)
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
		{ name = "Tip", color = "#bf0", id = 5391355 },
		{ name = "Donation", color = "#8f0", id = 5391356 },
		{ name = "Gift", color = "#0f0", id = 933980650 },
		{ name = "Tribute", color = "#0f8", id = 933582848 },
		{ name = "Patron", color = "#0ff", id = 938480383 },
		{ name = "Benefactor", color = "#0bf", id = 939618404 },
		{ name = "Luminary", color = "#80f", id = 936146448 },
		{ name = "Epic", color = "#f0f", id = 941076536 },
		{ name = "Hero", color = "#f08", id = 941162509 },
		{ name = "Legend", color = "#f00", id = 941006661 },
		{ name = "Mythic", color = "#fff", id = 983235767 },
	}

	local titleEquipped
	for i, pass in passDefinition do
		local isTitle = _K.Data.settings.vip and i > 4
		local button
		button = UI.new "Button" {
			Parent = gamePasses,
			LayoutOrder = i,
			Icon = "rbxasset://textures/ui/common/robux.png",
			IconRightAlign = true,
			Label = `<font color='{pass.color}'><sc><b>{pass.name}</b></sc></font>`,
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
				Text = `?`,
				RichText = true,
			},

			[UI.Event] = {
				Activated = function()
					if
						isTitle
						and (
							button._content.Price.Text == `<b>EQUIP</b>`
							or button._content.Price.Text == `<b>UNEQUIP</b>`
						)
					then
						if titleEquipped then
							titleEquipped._content.Price.Text = `<b>EQUIP</b>`
						end
						if titleEquipped ~= button then
							titleEquipped = button
							button._content.Price.Text = `<b>UNEQUIP</b>`
							_K.Remote.Title:FireServer(pass.name)
						else
							titleEquipped = nil
							_K.Remote.Title:FireServer()
						end
					else
						promptThirdPartyGamePassDialog(pass.id)
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
			Text = `❤️ Thanks for supporting Kohl's Admin!\n<b>{if i > 4
				then "Gives a title in participating experiences!"
				else "This doesn't provide any in-game benefits!"}</b>`,
			TextXAlignment = Enum.TextXAlignment.Left,
			Visible = button._hovering,
		}

		task.spawn(updatePassPriceText, button._content.Price, pass.id, if isTitle then `<b>EQUIP</b>` else nil)
	end

	local vipLabel = UI.new "TextLabel" {
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
	}

	local vipList = UI.new "Frame" {
		Name = "VIP",
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -2, 0, 0),

		UI.new "UIListLayout" {
			SortOrder = Enum.SortOrder.LayoutOrder,
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UI.Theme.PaddingDouble,
			Wraps = true,
		},
	}

	local halfButtonSize = UI.compute(function(use)
		return UDim2.new(0.5, -use(UI.Theme.Padding).Offset, 0, 32)
	end)

	local vipDeveloperPassId = _K.Data.roles.vip.gamepass
	local vipGlobalPassId = 5411126
	local vipButtonGlobal
	vipButtonGlobal = UI.new "Button" {
		Parent = vipList,
		LayoutOrder = 3,
		Icon = "rbxasset://textures/ui/common/robux.png",
		IconRightAlign = true,
		Label = "<font color='#fc0'><sc><b>VIP</b></sc></font> <font transparency='0.5'>(Global)</font>",
		HoverTransparency = 0.5,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = halfButtonSize,

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
				if
					vipButtonGlobal._content.Price.Text == `<b>EQUIP</b>`
					or vipButtonGlobal._content.Price.Text == `<b>UNEQUIP</b>`
				then
					if titleEquipped then
						titleEquipped._content.Price.Text = `<b>EQUIP</b>`
					end
					if titleEquipped ~= vipButtonGlobal then
						titleEquipped = vipButtonGlobal
						vipButtonGlobal._content.Price.Text = `<b>UNEQUIP</b>`
						_K.Remote.Title:FireServer("VIP")
					else
						titleEquipped = nil
						_K.Remote.Title:FireServer()
					end
				else
					promptThirdPartyGamePassDialog(vipGlobalPassId)
				end
			end,
		},
	}

	local vipButtonDeveloper = UI.new "Button" {
		Parent = vipList,
		LayoutOrder = 4,
		Icon = "rbxasset://textures/ui/common/robux.png",
		IconRightAlign = true,
		Label = "<font color='#fc0'><sc><b>VIP</b></sc></font> <font transparency='0.5'>(Game)</font>",
		HoverTransparency = 0.5,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = halfButtonSize,
		Visible = if vipDeveloperPassId then true else false,

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
				promptThirdPartyGamePassDialog(vipGlobalPassId)
			end,
		},
	}

	task.defer(updatePassPriceText, vipButtonGlobal._content.Price, vipGlobalPassId, `<b>EQUIP</b>`)
	if vipDeveloperPassId then
		task.defer(updatePassPriceText, vipButtonDeveloper._content.Price, vipDeveloperPassId)
	end

	local purchaseVIPDialog
	purchaseVIPDialog = UI.new "Dialog" {
		Parent = UI.LayerTop,
		Title = "✨ <b>Become a VIP</b>",
		Text = "<font transparency='0.5'>Unlock exclusive commands in participating experiences.</font>",
		Visible = false,
		ExitButton = true,
		BackgroundTransparency = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.new(0, 320, 0, 0),
		ZIndex = 999,
		Close = function()
			purchaseVIPDialog.Visible:set(false)
			vipButtonDeveloper._instance.Parent = vipList
			vipButtonGlobal._instance.Parent = vipList
			vipList.Visible = true
			vipLabel.Visible = true
		end,
	}

	function _K.promptPurchaseVIP()
		if _K.Data.roles.vip.gamepass then
			vipLabel.Visible = false
			vipList.Visible = false
			vipButtonDeveloper._instance.Parent = purchaseVIPDialog._content
			vipButtonGlobal._instance.Parent = purchaseVIPDialog._content
			purchaseVIPDialog.Visible:set(true)
		else
			promptThirdPartyGamePassDialog(vipGlobalPassId)
		end
	end

	local adminModelId = 172732271
	local adminModelButton = UI.new "Button" {
		Name = "adminModelButton",
		Icon = "rbxasset://textures/ui/common/robux.png",
		IconRightAlign = true,
		Label = "<sc><b>Get Kohl's Admin</b></sc>",
		HoverTransparency = 0.5,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(0.75, 0, 0, 32),

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
				_K.client.lastAttemptedPurchase = adminModelId
				purchaseLink.Text = "https://create.roblox.com/store/asset/" .. adminModelId
				if _K.client.AllowThirdPartySales then
					purchaseDialog.Visible:set(false)
					_K.Util.Services.MarketplaceService:PromptPurchase(_K.UI.LocalPlayer, adminModelId)
				else
					purchaseDialog.Visible:set(true)
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
		end)
		if ok and owned then
			adminModelButton._content.Price.Text = `<b>OWNED</b>`
		end
	end)

	local social = UI.new "Frame" {
		Name = "Social",
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -2, 0, 0),
		Visible = false,

		UI.new "UIListLayout" {
			SortOrder = Enum.SortOrder.LayoutOrder,
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UI.Theme.PaddingDouble,
			Wraps = true,
		},
	}

	local scroller = UI.new "Scroller" {
		Name = "About",

		UI.new "TextBox" {
			Name = "Version",
			LayoutOrder = -9,
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

		adminModelButton,

		UI.new "TextLabel" {
			Name = "Status",
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
				return not use(_K.client.settings.vip)
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

		vipLabel,
		vipList,

		social,

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
			Visible = _K.client.settings.gameHubEnabled,

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

	task.defer(function()
		local success, result = _K.Util.Retry(function()
			return PolicyService:GetPolicyInfoForPlayerAsync(Players.LocalPlayer)
		end)

		local discordInvite = success
			and result.AllowedExternalLinkReferences
			and table.find(result.AllowedExternalLinkReferences, "Discord")

		if discordInvite then
			social.Visible = true

			UI.new "TextLabel" {
				Parent = social,
				LayoutOrder = -2,
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
				Parent = social,
				LayoutOrder = -1,
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
				HorizontalAlignment = "Center",
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
				Size = UDim2.new(1, 0, 0, 24),
				Text = `<sc>{string.lower(group.Title)}</sc>`,
				TextTransparency = 0.5,
				RichText = true,
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
