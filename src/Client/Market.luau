local UI = require(script.Parent:WaitForChild("UI"))

local Market = {}
Market.__index = Market

function Market.new(_K)
	local scroller = UI.new "Scroller" {
		Name = "Market",
	}

	task.defer(function()
		local donationLevel = _K.LocalPlayer:GetAttribute("_KDonationLevel")

		local equippedUGC = {}
		local debounceEquip = _K.Util.Function.debounce(0.25, function(id, equip, equipped, name, button)
			local existing = equippedUGC[equip]
			if existing and existing ~= button then
				existing.BackgroundColor3(Color3.fromRGB(0, 200, 0))
				existing.Label("<b>WEAR</b>")
			end

			if equipped then
				equippedUGC[equip] = button
				button.BackgroundColor3(Color3.fromRGB(200, 0, 0))
				button.Label("<b>HIDE</b>")
			else
				equippedUGC[equip] = nil
				button.BackgroundColor3(Color3.fromRGB(0, 200, 0))
				button.Label("<b>WEAR</b>")
			end

			_K.Remote.VIPUGCMethod:Fire(id, equip, equipped, name)
		end)

		-- THIRD PARTY PURCHASES HANDLING

		local STUDIO_DEBUG = _K.DEBUG and _K.IsStudio
		local DEBUG_SHOW_PRICES = STUDIO_DEBUG

		local assetPriceConnections: { [TextLabel]: RBXScriptConnection } = {}
		local function updateAssetPriceText(label: TextLabel, assetId: number, ownedText: string?)
			if assetPriceConnections[label] then
				assetPriceConnections[label]:Disconnect()
				assetPriceConnections[label] = nil
			end

			local success, owned = _K.Util.Retry(function()
				return _K.Service.Marketplace:PlayerOwnsAssetAsync(_K.LocalPlayer, assetId)
			end)

			if success then
				if owned and not DEBUG_SHOW_PRICES then
					label.Text = ownedText or "<b>OWNED</b>"
					label.TextTransparency = 0.5
					return
				end

				if assetPriceConnections[label] then
					assetPriceConnections[label]:Disconnect()
				end
				local conn
				conn = _K.Service.Marketplace.PromptBulkPurchaseFinished:Connect(function(player, status, results)
					if player ~= _K.LocalPlayer or type(results) ~= "table" or type(results.Items) ~= "table" then
						return
					end
					local item = results.Items[1]
					local itemId = item and tonumber(item.Id or item.id)
					if itemId ~= assetId then
						return
					end
					_K.Remote.VIPCheck:Fire(assetId)
					if status == Enum.MarketplaceBulkPurchasePromptStatus.Completed then
						conn:Disconnect()
						if assetPriceConnections[label] == conn then
							assetPriceConnections[label] = nil
						end
						owned = true
						label.Text = ownedText or "<b>OWNED</b>"
						label.TextTransparency = 0.5
					end
				end)
				assetPriceConnections[label] = conn

				local ok, result = _K.Util.Retry(function()
					return _K.Service.Marketplace:GetProductInfoAsync(assetId, Enum.InfoType.Asset).PriceInRobux
				end)
				if ok then
					if not owned or DEBUG_SHOW_PRICES then
						label.Text = `<b>{result or "?"}</b>`
					end
				end
			end
		end

		local function updatePassPriceText(label: TextLabel, gamePassId: number, ownedText: string?)
			local success, owned = _K.Util.Retry(function()
				return _K.Service.Marketplace:UserOwnsGamePassAsync(_K.LocalPlayer.UserId, gamePassId)
			end)

			if success then
				if owned and not DEBUG_SHOW_PRICES then
					label.Text = ownedText or "<b>OWNED</b>"
					label.TextTransparency = 0.5
					return
				end

				local conn
				conn = _K.Service.Marketplace.PromptGamePassPurchaseFinished:Connect(function(userId, passId, purchased)
					if purchased and passId == gamePassId and userId == _K.LocalPlayer.UserId then
						conn:Disconnect()
						owned = true
						label.Text = ownedText or "<b>OWNED</b>"
						label.TextTransparency = 0.5
					end
				end)

				local ok, result = _K.Util.Retry(function()
					return _K.Service.Marketplace:GetProductInfoAsync(gamePassId, Enum.InfoType.GamePass).PriceInRobux
				end)
				if ok then
					if not owned or DEBUG_SHOW_PRICES then
						label.Text = `<b>{result or "?"}</b>`
					end
				end
			end
		end

		local function updateTitleLabel(button, name: string, display: string?)
			local titleRef = string.lower(name)
			local definition = shared._KVIPTitle.definition[titleRef]
			local label = button._content.Label

			UI.new "Spacer" {
				Parent = button._content,
				LayoutOrder = 2,
			}
			UI.edit(label)({
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.new(0, 0, 1, 0),
				FontFace = Font.fromEnum(Enum.Font.FredokaOne),
				TextSize = UI.Theme.FontSizeLarge,
				TextColor3 = Color3.new(1, 1, 1),
			})
			label.UIFlexItem.FlexMode = Enum.UIFlexMode.Shrink

			if definition then
				label.Name = "Title"
				label.Text = `<stroke thickness="1">{name}</stroke>{display or ""}`

				UI.gradient({
					color = ColorSequence.new(
						definition.topColor or Color3.new(1, 1, 1),
						definition.color or Color3.new(1, 1, 1)
					),
					rotation = definition.rotation or 90,
				}).Parent =
					label
				button._content:AddTag("_K" .. titleRef)
			else
				UI.new "UIStroke" {
					Parent = label,
					Thickness = 1,
				}
			end
		end

		-- CUSTOM UGC

		local customUGC = UI.new "Frame" {
			Name = "UGC",
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -2, 0, 0),

			UI.edit(UI.list {
				direction = "x",
				horizontalAlign = "evenly",
				gap = UI.Theme.PaddingWithStroke,
				wraps = true,
			})({ HorizontalAlignment = Enum.HorizontalAlignment.Center }),
		}

		for i, ugc in _K.VIP.purchasables.scriptedUGC do
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

						UI.corner(UI.Theme.CornerPadded),
						UI.new "Stroke" {},

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
								Activated = function()
									local _ = pcall(function()
										_K.Service.AvatarEditor:PromptSetFavorite(ugc.id, 1, true)
									end)
								end,
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
						button.Label(`<b>{ugc.price}</b>`)
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
						FontFace = UI.Theme.FontMono,
						TextSize = UI.Theme.FontSizeLarge,
						TextXAlignment = if owned then nil else Enum.TextXAlignment.Left,
						TextTruncate = Enum.TextTruncate.None,
					},
					BackgroundColor3 = Color3.fromRGB(0, 200, 0),
					BackgroundTransparency = 0.5,
					Size = UDim2.new(0, 80, 0, 32),
					Position = UDim2.fromOffset(0, 88),

					__ATTR = {
						Price = ugc.price,
					},

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
									existing.Label(`<b>{existing._instance:GetAttribute("Price")}</b>`)
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

						_K.PromptBulkPurchase(ugc.id)
					end,
				}

				if not owned then
					try = true
					button.Label("<b>TRY</b>")
					button._content.IconFrame.Visible = false
					button._content.Label.TextXAlignment = Enum.TextXAlignment.Center

					local con, con2, con3
					local function setOwned()
						if con then
							con:Disconnect()
							con = nil
						end
						if con2 then
							con2:Disconnect()
							con2 = nil
						end
						if con3 then
							con3:Disconnect()
							con3 = nil
						end
						owned, try = true, nil
						button.Label("<b>WEAR</b>")
						button._content.IconFrame.Visible = false
						button._content.Label.TextXAlignment = Enum.TextXAlignment.Center
					end

					con = _K.Service.Marketplace.PromptPurchaseFinished:Connect(function(player, assetId, purchased)
						if purchased and assetId == ugc.id and player == _K.LocalPlayer then
							setOwned()
						end
					end)

					con3 = _K.Service.Marketplace.PromptBulkPurchaseFinished:Connect(function(player, status, results)
						if
							player ~= _K.LocalPlayer
							or status ~= Enum.MarketplaceBulkPurchasePromptStatus.Completed
							or type(results) ~= "table"
							or type(results.Items) ~= "table"
						then
							return
						end
						local item = results.Items[1]
						if item and tonumber(item.Id or item.id) == ugc.id then
							setOwned()
							_K.Remote.VIPCheck:Fire(ugc.id)
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
							return _K.Service.Marketplace:PlayerOwnsAssetAsync(_K.LocalPlayer, ugc.id)
						end)
						if ok and result then
							setOwned()
						end
					end)

					local ok, result = _K.Util.Retry(function()
						return _K.Service.Marketplace:GetProductInfoAsync(ugc.id, Enum.InfoType.Asset).PriceInRobux
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
						Hovering = button._hovering,
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

			UI.edit(UI.list {
				direction = "x",
				horizontalAlign = "evenly",
				gap = UI.Theme.PaddingWithStroke,
				wraps = true,
			})({ HorizontalAlignment = Enum.HorizontalAlignment.Center }),
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
				remote:Fire(name)
			else
				remoteEquipped[remote] = nil
				remote:Fire()
			end
		end

		local function generateDonationButtons(parent: Instance)
			for i, pass in _K.VIP.purchasables.donations do
				local isTitle = _K.Data.settings.vip and i > 4
				local remote = if isTitle then _K.Remote.Title else _K.Remote.DonorTrail
				local button
				button = UI.new "Button" {
					Parent = parent,
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
						FontFace = UI.Theme.FontMono,
						TextSize = UI.Theme.FontSizeLarge,
						TextColor3 = UI.Theme.PrimaryText,
						TextStrokeColor3 = UI.Theme.Primary,
						TextStrokeTransparency = UI.Theme.TextStrokeTransparency,
						TextWrapped = true,
						Size = function()
							return UDim2.new(0, UI.Theme.FontSizeLarge(), 0, 32)
						end,
						Text = `?`,
						RichText = true,
					},

					Activated = function()
						if
							button._content.Price.Text == `<b>SHOW</b>`
							or button._content.Price.Text == `<b>HIDE</b>`
						then
							donorEquip(pass.name, button, remote)
						else
							_K.PromptBulkPurchase(pass.assetId)
						end
					end,
				}
				UI.flex("fill").Parent = button._instance

				local perkText = if i > 5
					then "Unlocks:</b></font>\n💬 Chat commands\n👑 All animated accessories\n✨ Custom particle effects\n😎 Exclusive title"
					elseif
						i > 4
					then "Unlocks:</b></font>\n💬 Chat commands\n👑 Floating crown\n✨ Custom particle effects\n😎 Exclusive title"
					elseif i > 3 then "Unlocks:</b></font>\n💬 Chat commands\n✨ Custom particle effects"
					else "Unlocks a particle effect!</b></font>"

				UI.new "Tooltip" {
					Parent = button._instance,
					Text = `We've poured thousands of hours into Kohl's Admin.\nIf you enjoy it, please donate! ❤️\n\n<font color='#0f0'><b>{perkText}`,
					Hovering = button._hovering,
				}

				updateTitleLabel(button, pass.name)

				task.spawn(function()
					if not DEBUG_SHOW_PRICES then
						local success, owned = _K.Util.Retry(function()
							return _K.Service.Marketplace:UserOwnsGamePassAsync(_K.LocalPlayer.UserId, pass.id)
						end)
						if success and owned then
							button._content.Price.Text = `<b>SHOW</b>`
							return
						end
					end
					updateAssetPriceText(button._content.Price, pass.assetId, `<b>SHOW</b>`)
				end)
			end
		end

		_K.client.generateDonationButtons = generateDonationButtons

		generateDonationButtons(gamePasses)

		local vipList = UI.new "Frame" {
			Name = "VIP",
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -2, 0, 0),

			UI.list {
				direction = "x",
				horizontalAlign = "center",
				gap = UI.Theme.PaddingWithStroke,
				wraps = true,
			},
		}

		local halfButtonSize = UI.computed(function()
			return UDim2.new(0.5, -UI.Theme.Padding().Offset, 0, 32)
		end)

		local vipDeveloperPassId = if _K.Data.roles.vip and _K.Data.roles.vip.gamepasses
			then _K.Data.roles.vip.gamepasses[1]
			else nil

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
				FontFace = UI.Theme.FontMono,
				TextSize = UI.Theme.FontSizeLarge,
				TextColor3 = UI.Theme.PrimaryText,
				TextStrokeColor3 = UI.Theme.Primary,
				TextStrokeTransparency = UI.Theme.TextStrokeTransparency,
				TextWrapped = true,
				Size = function()
					return UDim2.new(0, UI.Theme.FontSizeLarge(), 0, 32)
				end,
				Text = "?",
				RichText = true,
			},
			Activated = function()
				if
					vipButtonGlobal._content.Price.Text == `<b>SHOW</b>`
					or vipButtonGlobal._content.Price.Text == `<b>HIDE</b>`
				then
					donorEquip("VIP", vipButtonGlobal, _K.Remote.Title)
				else
					_K.PromptPurchaseVIP()
				end
			end,
		}

		UI.new "Tooltip" {
			Parent = vipButtonGlobal,
			Text = "✨ <b>Become a VIP</b>\n\n<font color='#0f0'>Unlock <b>VIP commands</b> globally!</font>",
			Hovering = vipButtonGlobal._hovering,
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
				FontFace = UI.Theme.FontMono,
				TextSize = UI.Theme.FontSizeLarge,
				TextColor3 = UI.Theme.PrimaryText,
				TextStrokeColor3 = UI.Theme.Primary,
				TextStrokeTransparency = UI.Theme.TextStrokeTransparency,
				TextWrapped = true,
				Size = function()
					return UDim2.new(0, UI.Theme.FontSizeLarge(), 0, 32)
				end,
				Text = "?",
				RichText = true,
			},
			Activated = function()
				_K.Service.Marketplace:PromptGamePassPurchase(_K.LocalPlayer, vipDeveloperPassId)
			end,
		}

		updateTitleLabel(
			vipButtonDeveloper,
			"VIP",
			`  <font transparency="0.75"><stroke thickness="1" transparency="0.75">(Game)</stroke></font>`
		)

		task.defer(function()
			local vipOwned = (donationLevel or 0) >= 3
			if vipOwned and not DEBUG_SHOW_PRICES then
				vipButtonGlobal._content.Price.Text = `<b>SHOW</b>`
				vipButtonGlobal._content.Price.TextTransparency = 0.5
				return
			end

			local levelCon
			levelCon = _K.LocalPlayer:GetAttributeChangedSignal("_KDonationLevel"):Connect(function()
				if (_K.LocalPlayer:GetAttribute("_KDonationLevel") or 0) >= 3 and not DEBUG_SHOW_PRICES then
					levelCon:Disconnect()
					vipButtonGlobal._content.Price.Text = `<b>SHOW</b>`
					vipButtonGlobal._content.Price.TextTransparency = 0.5
				end
			end)

			local success, owned = _K.Util.Retry(function()
				return _K.Service.Marketplace:UserOwnsGamePassAsync(_K.LocalPlayer.UserId, 5411126)
			end)
			if success and owned then
				task.defer(updatePassPriceText, vipButtonGlobal._content.Price, 5411126, `<b>SHOW</b>`)
			else
				local VIP_UGC_ID = 110019084552349
				local VIP_UGC_SALE_ID = 115444443724463
				for _, assetId in _K.VIP.purchasables.chatCommands do
					local ok, ugcOwned = _K.Util.Retry(function()
						return _K.Service.Marketplace:PlayerOwnsAssetAsync(_K.LocalPlayer, assetId)
					end)
					if ok and ugcOwned and not DEBUG_SHOW_PRICES then
						levelCon:Disconnect()
						vipButtonGlobal._content.Price.Text = `<b>SHOW</b>`
						vipButtonGlobal._content.Price.TextTransparency = 0.5
						return
					end
				end

				local activeId = if _K.VIP.isOnSale and _K.VIP.isOnSale() then VIP_UGC_SALE_ID else VIP_UGC_ID
				task.defer(updateAssetPriceText, vipButtonGlobal._content.Price, activeId, `<b>SHOW</b>`)
				if _K.VIP.saleStateChanged then
					_K.VIP.saleStateChanged:Connect(function(onSale: boolean, newId: number)
						if
							vipButtonGlobal._content.Price.Text ~= `<b>SHOW</b>`
							and vipButtonGlobal._content.Price.Text ~= `<b>HIDE</b>`
						then
							task.defer(
								updateAssetPriceText,
								vipButtonGlobal._content.Price,
								newId or (if onSale then VIP_UGC_SALE_ID else VIP_UGC_ID),
								`<b>SHOW</b>`
							)
						end
					end)
				end
			end
		end)

		if vipDeveloperPassId then
			task.defer(updatePassPriceText, vipButtonDeveloper._content.Price, vipDeveloperPassId)
		end

		local gamesTooltipText = "Find games using Kohl's Admin!\n\n"
			.. "<font transparency='0.5'>Check the Kohl's Admin <b>Settings</b> script in Studio to add your game to the charts.</font>\n\n"
			.. "<b>Game Creators</b> get up to <font color='#0f0'><b>40%</b></font> when "
			.. "<font transparency='0.5'><b>Third Party Purchases</b></font> are enabled in their Roblox Game Settings!"

		UI.edit(scroller._instance)({

			UI.new "TextLabel" {
				Name = "Status",
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundColor3 = Color3.new(1, 0, 0),
				BackgroundTransparency = 0.75,
				FontFace = UI.Theme.FontMono,
				TextSize = UI.Theme.FontSizeSmall,
				TextColor3 = Color3.new(1, 1, 1),
				Text = `<sc>VIP benefits are <b>disabled</b> in this game!</sc>`,
				TextStrokeTransparency = UI.Theme.TextStrokeTransparency,
				TextWrapped = true,
				RichText = true,
				Visible = function()
					return not _K.client.settings.vip()
				end,

				UI.corner(UI.Theme.CornerPadded),
				UI.padding {
					x = UI.Theme.Padding,
					y = UI.Theme.PaddingHalf,
				},
			},

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
				Text = "<b>❤️ Kohl's Admin?</b>\n<font transparency='0.5'>Donate for cool perks and more updates!</font>",
				RichText = true,
			},

			vipList,
			gamePasses,
			customUGC,

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
					Size = UDim2.new(0, 24, 0, 24),
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
		})

		UI.edit(scroller._instance.UIListLayout)({
			Padding = UI.Theme.PaddingWithStroke,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
		})
	end)

	return scroller
end

return Market
