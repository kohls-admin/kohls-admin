local CREDITS = require(script.Parent.Parent.Credits)
local UserFrame = require(script.Parent.UserFrame)

local About = {}
About.__index = About

function About.new(_K)
	local UI = _K.UI

	local scroller = UI.new "Scroller" {
		Name = "About",
	}

	task.defer(function()
		local thirdPartyText = "<font color='#f00'>A developer has disabled <b>Third Party Purchases</b>!</font>\n\n"
			.. "<font transparency='0.5'>Copy the link below to continue.</font>"
		local perksText = "\n<font color='#fc0'><b>To get perks, rejoin after your purchase!</b></font>"

		local donationLevel = _K.LocalPlayer:GetAttribute("_KDonationLevel")

		local equippedUGC = {}
		local debounceEquip = _K.Util.Function.debounce(0.25, function(id, equip, equipped, name, button)
			local existing = equippedUGC[equip]
			if existing and existing ~= button then
				existing.BackgroundColor3:set(Color3.fromRGB(0, 200, 0))
				existing.Label:set("<b>WEAR</b>")
			end

			if equipped then
				equippedUGC[equip] = button
				button.BackgroundColor3:set(Color3.fromRGB(200, 0, 0))
				button.Label:set("<b>HIDE</b>")
			else
				equippedUGC[equip] = nil
				button.BackgroundColor3:set(Color3.fromRGB(0, 200, 0))
				button.Label:set("<b>WEAR</b>")
			end

			_K.Remote.VIPUGCMethod:FireServer(id, equip, equipped, name)
		end)

		-- THIRD PARTY PURCHASES HANDLING

		_K.client.AllowThirdPartySales = if _K.DEBUG and _K.IsStudio then false else true
		_K.client.lastAttemptedPurchase = false

		local purchaseLink = UI.new "TextBox" {
			Name = "Link",
			LayoutOrder = 10,
			AutoLocalize = false,
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = UI.Theme.Secondary,
			BackgroundTransparency = 0.25,
			Size = UDim2.fromScale(1, 0),
			Font = UI.Theme.FontMono,
			TextSize = UI.Theme.FontSize,
			TextColor3 = UI.Theme.SecondaryText,
			TextStrokeColor3 = UI.Theme.Secondary,
			TextStrokeTransparency = UI.Theme.TextStrokeTransparency,
			Text = "roblox.com/game-pass/5391355/",
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
			Draggable = true,
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

		local function promptThirdPartyGamePassDialog(passId, passName)
			_K.client.lastAttemptedPurchase = passId
			purchaseDialog.Title:set("Buy " .. passName)
			purchaseDialog.Text:set(thirdPartyText .. perksText)
			purchaseLink.Text = "roblox.com/game-pass/" .. passId
			if _K.client.AllowThirdPartySales then
				purchaseDialog.Visible:set(false)
				_K.Service.Marketplace:PromptGamePassPurchase(_K.LocalPlayer, passId)
			else
				purchaseDialog.Visible:set(true)
			end
		end
		_K.client.promptThirdPartyGamePassDialog = promptThirdPartyGamePassDialog

		local function updatePassPriceText(label: TextLabel, gamePassId: number, ownedText: string?)
			local success, owned = _K.Util.Retry(function()
				return _K.Service.Marketplace:UserOwnsGamePassAsync(_K.LocalPlayer.UserId, gamePassId)
			end)

			if success then
				if owned then
					label.Text = ownedText or "<b>OWNED</b>"
					return
				end

				local conn
				conn = _K.Service.Marketplace.PromptGamePassPurchaseFinished:Connect(function(userId, passId, purchased)
					if purchased and passId == gamePassId and userId == _K.LocalPlayer.UserId then
						conn:Disconnect()
						owned = true
						label.Text = ownedText or "<b>OWNED</b>"
					end
				end)

				local ok, result = _K.Util.Retry(function()
					return _K.Service.Marketplace:GetProductInfo(gamePassId, Enum.InfoType.GamePass).PriceInRobux
				end)
				if ok then
					if not owned then
						label.Text = `<b>{result or "?"}</b>`
					end
				end
			end
		end

		local con
		con = _K.Service.Log.MessageOut:Connect(function(message, messageType)
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
					tip = "🕊️ <b>Light Wings</b>\n<font transparency='0.33'>Provides the following special effects in games using Kohl's Admin:</font>"
						.. "\n - Flying Animations 💫\n - Neon Material ✨\n\n<font transparency='0.66'>Animator: <b>@LuhHorsie</b>\nModeler: <b>@HyperbolicHydra</b>\nScripter: <b>@Scripth</b></font>",
					id = 133292294488871,
					equip = "rbxassetid://89119211625300",
					name = "Light Wings",
					level = 3,
				},
				{
					tip = "👑 <b>Light Crown</b>\n<font transparency='0.33'>Provides the following special effects in games using Kohl's Admin:</font>"
						.. "\n - Fire Effect 🔥\n - Neon Material ✨\n - Spinning 💫",
					id = 18966788838,
					equip = "rbxassetid://18966762965",
					name = "Light Crown",
					level = 2,
				},
				{
					tip = "🕊️ <b>Dark Wings</b>\n<font transparency='0.33'>Provides the following special effects in games using Kohl's Admin:</font>"
						.. "\n - Flying Animations 💫\n - Neon Material ✨\n\n<font transparency='0.66'>Animator: <b>@LuhHorsie</b>\nModeler: <b>@HyperbolicHydra</b>\nScripter: <b>@Scripth</b></font>",
					id = 110848154960799,
					equip = "rbxassetid://89119211625300",
					name = "Dark Wings",
					level = 3,
				},
				{
					tip = "👑 <b>Dark Crown</b>\n<font transparency='0.33'>Provides the following special effects in games using Kohl's Admin:</font>"
						.. "\n - Fire Effect 🔥\n - Neon Material ✨\n - Spinning 💫",
					id = 106645613603989,
					equip = "rbxassetid://18966762965",
					name = "Dark Crown",
					level = 2,
				},
				{
					tip = "🕊️ <b>Gold Wings</b>\n<font transparency='0.33'>Provides the following special effects in games using Kohl's Admin:</font>"
						.. "\n - Flying Animations 💫\n - Neon Material ✨\n\n<font transparency='0.66'>Animator: <b>@LuhHorsie</b>\nModeler: <b>@HyperbolicHydra</b>\nScripter: <b>@Scripth</b></font>",
					id = 92807314389236,
					equip = "rbxassetid://89119211625300",
					name = "Gold Wings",
					level = 3,
				},
				{
					tip = "👑 <b>Gold Crown</b>\n<font transparency='0.33'>Provides the following special effects in games using Kohl's Admin:</font>"
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
				ugc.price = if owned then "WEAR" else "?"

				local frame = UI.new "Frame" {
					Parent = customUGC,
					LayoutOrder = i,
					AutomaticSize = Enum.AutomaticSize.XY,
					BackgroundTransparency = 1,

					UI.new "ImageLabel" {
						BackgroundColor3 = Color3.new(0, 0, 0),
						BackgroundTransparency = 0.875,
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
										_K.Service.AvatarEditor:PromptSetFavorite(ugc.id, 1, true)
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
					IconProperties = { ImageColor3 = UI.Theme.PrimaryText },
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
									From = "_K",
									Text = `Trying <b>{ugc.name}</b>.`,
									Duration = 15,
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
							purchaseDialog.Title:set("Buy" .. ugc.name)
							purchaseDialog.Text:set(thirdPartyText .. perksText)
							purchaseLink.Text = "roblox.com/catalog/" .. ugc.id
							if _K.client.AllowThirdPartySales then
								purchaseDialog.Visible:set(false)
								_K.Service.Marketplace:PromptPurchase(_K.LocalPlayer, ugc.id)
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

					local con, con2
					local function setOwned()
						if con then
							con:Disconnect()
							con = nil
						end
						if con2 then
							con2:Disconnect()
							con2 = nil
						end
						owned, try = true, nil
						button.Label:set("<b>WEAR</b>")
						button._content.IconFrame.Visible = false
						button._content.Label.TextXAlignment = Enum.TextXAlignment.Center
					end

					con = _K.Service.Marketplace.PromptPurchaseFinished:Connect(function(player, assetId, purchased)
						if purchased and assetId == ugc.id and player == _K.LocalPlayer then
							setOwned()
						end
					end)

					con2 = _K.LocalPlayer:GetAttributeChangedSignal("_KDonationLevel"):Connect(function()
						donationLevel = math.max(donationLevel or 0, _K.LocalPlayer:GetAttribute("_KDonationLevel"))
						if (donationLevel or 0) >= (ugc.level or 3) then
							setOwned()
						end
					end)

					task.spawn(function()
						local ok, result = _K.Util.Retry(function()
							if owned then
								return true
							end
							return _K.Service.Marketplace:PlayerOwnsAsset(_K.LocalPlayer, ugc.id)
						end)
						if ok and result then
							setOwned()
						end
					end)

					local ok, result = _K.Util.Retry(function()
						return _K.Service.Marketplace:GetProductInfo(ugc.id, Enum.InfoType.Asset).PriceInRobux
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

		local function updateTitleLabel(button, name: string, display: string?)
			local titleRef = string.lower(name)
			local definition = shared._KVIPTitle.definition[titleRef]
			local label = button._content.Label

			UI.new "Spacer" {
				Parent = button._content,
				LayoutOrder = 2,
			}
			UI.edit(label, {
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.new(0, 0, 1, 0),
				Font = Enum.Font.FredokaOne,
				TextSize = UI.Theme.FontSizeLarge,
				TextColor3 = Color3.new(1, 1, 1),
			})
			label.UIFlexItem.FlexMode = Enum.UIFlexMode.Shrink

			if definition then
				label.Name = "Title"
				label.Text = `<stroke thickness="1">{name}</stroke>{display or ""}`

				UI.new "UIGradient" {
					Parent = label,
					Color = ColorSequence.new(
						definition.topColor or Color3.new(1, 1, 1),
						definition.color or Color3.new(1, 1, 1)
					),
					Rotation = definition.rotation or 90,
				}
				button._content:AddTag("_K" .. titleRef)
			else
				UI.new "UIStroke" {
					Parent = label,
					Thickness = 1,
				}
			end
		end

		local passDefinition = {
			{ name = "Tip", color = "#bf0", id = 5391355 },
			{ name = "Donation", color = "#8f0", id = 5391356 },
			{ name = "Gift", color = "#0f0", id = 933980650 },
			{ name = "Tribute", color = "#0f8", id = 933582848 },
			{ name = "Patron", color = "#0ff", id = 938480383 },
			{ name = "Elite", color = "#80f", id = 939618404 },
			{ name = "Epic", color = "#f0f", id = 936146448 },
			{ name = "Hero", color = "#f08", id = 941076536 },
			{ name = "Legend", color = "#f00", id = 941162509 },
			{ name = "Mythic", color = "#f00", id = 941006661 },
			{ name = "Eternal", color = "#000", id = 983235767 },
		}

		local remoteEquipped = {}
		local function donorEquip(name, button, remote)
			local equipped = remoteEquipped[remote]
			if equipped then
				equipped._content.Price.Text = `<b>SHOW</b>`
			end
			if equipped ~= button then
				remoteEquipped[remote] = button
				button._content.Price.Text = `<b>HIDE</b>`
				remote:FireServer(name)
			else
				remoteEquipped[remote] = nil
				remote:FireServer()
			end
		end
		for i, pass in passDefinition do
			local isTitle = _K.Data.settings.vip and i > 4
			local remote = if isTitle then _K.Remote.Title else _K.Remote.DonorTrail
			local button
			button = UI.new "Button" {
				Parent = gamePasses,
				LayoutOrder = i,
				Icon = "rbxasset://textures/ui/common/robux.png",
				IconProperties = { ImageColor3 = UI.Theme.PrimaryText },
				IconRightAlign = true,
				Label = `<font color='{pass.color}'><b>{pass.name}</b></font>`,
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
					TextStrokeColor3 = UI.Theme.Primary,
					TextStrokeTransparency = UI.Theme.TextStrokeTransparency,
					TextWrapped = true,
					Size = UI.computeFrom(UDim2.new, 0, UI.Theme.FontSizeLarge, 0, 32),
					Text = `?`,
					RichText = true,
				},

				[UI.Event] = {
					Activated = function()
						if
							button._content.Price.Text == `<b>SHOW</b>`
							or button._content.Price.Text == `<b>HIDE</b>`
						then
							donorEquip(pass.name, button, remote)
						else
							promptThirdPartyGamePassDialog(pass.id, pass.name)
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
				Text = `We've poured thousands of hours into Kohl's Admin.\nIf you enjoy it, please donate! ❤️\n\n<b>{if i
						> 4
					then "<font color='#0f0'>Gives a title!"
					else "<font color='#0f0'>Gives a particle effect!"}</font></b>`,
				TextXAlignment = Enum.TextXAlignment.Left,
				Visible = button._hovering,
			}

			updateTitleLabel(button, pass.name)

			task.spawn(updatePassPriceText, button._content.Price, pass.id, `<b>SHOW</b>`)
		end

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

		local vipDeveloperPassId = _K.Data.roles.vip.gamepasses and _K.Data.roles.vip.gamepasses[1]
		local vipGlobalPassId = 5411126
		local vipButtonGlobal
		vipButtonGlobal = UI.new "Button" {
			Parent = vipList,
			LayoutOrder = 3,
			Icon = "rbxasset://textures/ui/common/robux.png",
			IconProperties = { ImageColor3 = UI.Theme.PrimaryText },
			IconRightAlign = true,
			Label = "VIP",
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
				TextStrokeColor3 = UI.Theme.Primary,
				TextStrokeTransparency = UI.Theme.TextStrokeTransparency,
				TextWrapped = true,
				Size = UI.computeFrom(UDim2.new, 0, UI.Theme.FontSizeLarge, 0, 32),
				Text = "?",
				RichText = true,
			},
			[UI.Event] = {
				Activated = function()
					if
						vipButtonGlobal._content.Price.Text == `<b>SHOW</b>`
						or vipButtonGlobal._content.Price.Text == `<b>HIDE</b>`
					then
						donorEquip("VIP", vipButtonGlobal, _K.Remote.Title)
					else
						promptThirdPartyGamePassDialog(vipGlobalPassId, "VIP (Global)")
					end
				end,
			},
		}

		UI.new "Tooltip" {
			Parent = vipButtonGlobal,
			Text = "✨ <b>Become a VIP</b>\n\n<font color='#0f0'>Unlock <b>VIP commands</b> globally!</font>",
			Visible = vipButtonGlobal._hovering,
		}

		updateTitleLabel(
			vipButtonGlobal,
			"VIP",
			`  <font transparency="0.75"><stroke thickness="1" transparency="0.75">(Global)</stroke></font>`
		)

		local vipButtonDeveloper = UI.new "Button" {
			Parent = vipList,
			LayoutOrder = 4,
			Icon = "rbxasset://textures/ui/common/robux.png",
			IconProperties = { ImageColor3 = UI.Theme.PrimaryText },
			IconRightAlign = true,
			Label = "VIP",
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
				TextStrokeColor3 = UI.Theme.Primary,
				TextStrokeTransparency = UI.Theme.TextStrokeTransparency,
				TextWrapped = true,
				Size = UI.computeFrom(UDim2.new, 0, UI.Theme.FontSizeLarge, 0, 32),
				Text = "?",
				RichText = true,
			},
			[UI.Event] = {
				Activated = function()
					_K.Service.Marketplace:PromptGamePassPurchase(_K.LocalPlayer, vipDeveloperPassId)
				end,
			},
		}

		updateTitleLabel(
			vipButtonDeveloper,
			"VIP",
			`  <font transparency="0.75"><stroke thickness="1" transparency="0.75">(Game)</font>`
		)

		task.defer(updatePassPriceText, vipButtonGlobal._content.Price, vipGlobalPassId, `<b>SHOW</b>`)
		if vipDeveloperPassId then
			task.defer(updatePassPriceText, vipButtonDeveloper._content.Price, vipDeveloperPassId)
		end

		local purchaseVIPDialog
		purchaseVIPDialog = UI.new "Dialog" {
			Parent = UI.LayerTop,
			Title = "✨ <b>Become a VIP</b>",
			Text = "<font color='#0f0'>Unlock <b>VIP commands</b> globally!</font>",
			Visible = false,
			Draggable = true,
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
			end,
		}

		function _K.promptPurchaseVIP(global: boolean?)
			if not global and vipDeveloperPassId then
				vipList.Visible = false
				vipButtonDeveloper._instance.Parent = purchaseVIPDialog._content
				vipButtonGlobal._instance.Parent = purchaseVIPDialog._content
				purchaseVIPDialog.Visible:set(true)
			else
				promptThirdPartyGamePassDialog(vipGlobalPassId, "VIP (Global)")
			end
		end

		local adminModelId = 172732271
		local adminModelButton = UI.new "Button" {
			Name = "adminModelButton",
			Icon = "rbxasset://textures/ui/common/robux.png",
			IconProperties = { ImageColor3 = UI.Theme.PrimaryText },
			IconRightAlign = true,
			Label = "<b>Get Kohl's Admin</b>",
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
							_K.Service.AvatarEditor:PromptSetFavorite(adminModelId, 1, true)
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
				TextStrokeColor3 = UI.Theme.Primary,
				TextStrokeTransparency = UI.Theme.TextStrokeTransparency,
				TextWrapped = true,
				Size = UI.computeFrom(UDim2.new, 0, UI.Theme.FontSizeLarge, 0, 32),
				Text = "<b>FREE</b>",
				RichText = true,
			},

			[UI.Event] = {
				Activated = function()
					_K.client.lastAttemptedPurchase = adminModelId
					purchaseDialog.Title:set("Get Kohl's Admin")
					purchaseDialog.Text:set(thirdPartyText)
					purchaseLink.Text = "create.roblox.com/store/asset/" .. adminModelId
					if _K.client.AllowThirdPartySales then
						purchaseDialog.Visible:set(false)
						_K.Service.Marketplace:PromptPurchase(_K.LocalPlayer, adminModelId)
					else
						purchaseDialog.Visible:set(true)
					end
				end,
			},
		}

		UI.new "Tooltip" {
			Parent = adminModelButton,
			Text = "Used by <b>30M+</b> developers since 2011, Kohl's Admin is the leading tool for experience management. 🚀",
			TextXAlignment = Enum.TextXAlignment.Left,
			Visible = adminModelButton._hovering,
		}

		task.defer(function()
			local ok, owned = _K.Util.Retry(function()
				return _K.Service.Marketplace:PlayerOwnsAsset(_K.LocalPlayer, adminModelId)
			end)
			if ok and owned then
				adminModelButton._content.Price.Text = `<b>OWNED</b>`
			end
		end)

		UI.edit(scroller._instance, {

			UI.new "TextLabel" {
				Name = "Status",
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundColor3 = Color3.new(1, 0, 0),
				BackgroundTransparency = 0.75,
				Font = UI.Theme.FontMono,
				TextSize = UI.Theme.FontSizeSmall,
				TextColor3 = Color3.new(1, 1, 1),
				Text = `<sc>VIP benefits have been <b>disabled</b> by a developer!</sc>`,
				TextStrokeTransparency = UI.Theme.TextStrokeTransparency,
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

			UI.new "TextLabel" {
				AutoLocalize = false,
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				Font = UI.Theme.Font,
				TextSize = UI.Theme.FontSize,
				TextColor3 = UI.Theme.PrimaryText,
				TextStrokeColor3 = UI.Theme.Primary,
				TextStrokeTransparency = UI.Theme.TextStrokeTransparency,
				TextWrapped = true,
				Size = UDim2.new(1, 0, 0, 0),
				Text = "<b>❤️ Kohl's Admin?</b>\n<font transparency='0.5'>Donate and rate it for cool features!</font>",
				RichText = true,
			},

			adminModelButton,
			vipList,
			gamePasses,
			customUGC,

			UI.new "TextLabel" {
				AutoLocalize = false,
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				Font = UI.Theme.Font,
				TextSize = UI.Theme.FontSize,
				TextColor3 = UI.Theme.PrimaryText,
				TextStrokeColor3 = UI.Theme.Primary,
				TextStrokeTransparency = UI.Theme.TextStrokeTransparency,
				TextWrapped = true,
				Size = UDim2.new(1, 0, 0, 0),
				Text = "<b>Looking for more games with Kohl's Admin?</b>",
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
				TextStrokeColor3 = UI.Theme.Secondary,
				TextStrokeTransparency = UI.Theme.TextStrokeTransparency,
				Text = "roblox.com/games/17873329124/",
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
					Text = "A list of games using Kohl's Admin!\n\n"
						.. "<font transparency='0.5'>Check the Kohl's Admin <b>Settings</b> script in Studio to add your game to the list.</font>\n\n"
						.. "<b>Game Creators</b> get up to <font color='#0f0'><b>40%</b></font> when "
						.. "<font transparency='0.5'><b>Third Party Purchases</b></font> are enabled in their Roblox Game Settings!",
					TextXAlignment = Enum.TextXAlignment.Left,
				},
			},
		})

		UI.edit(scroller._instance.UIListLayout, {
			Padding = UI.Theme.PaddingDouble,
			HorizontalAlignment = "Center",
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
					TextStrokeColor3 = UI.Theme.Primary,
					TextStrokeTransparency = UI.Theme.TextStrokeTransparency,
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
