local _K = require(script.Parent.Parent)
local UI = _K.UI

task.defer(function()
	local ADMIN_MODEL_ID = 172732271
	local ok, result = _K.Util.Retry(function()
		return _K.Service.Marketplace:PlayerOwnsAssetAsync(_K.LocalPlayer, ADMIN_MODEL_ID)
	end)
	local ownsModel = ok and result

	if (_K.LocalPlayer:GetAttribute("_KDonationLevel") or 0) > 3 then
		return
	end

	local function openMarket()
		local market = _K.client.dashboard and _K.client.dashboard.Market
		local tabs = _K.client.dashboard and _K.client.dashboard.Tabs
		if market and tabs and tabs._containerCache and tabs._containerCache[market._instance] then
			tabs._pages:JumpTo(tabs._containerCache[market._instance])
		end
		if _K.client.dashboard and _K.client.dashboard.Window and not _K.client.dashboard.Window._instance.Visible then
			if
				_K.client.dashboardEnabled
				and _K.client.hotkeys
				and _K.client.hotkeys.dashboard
				and _K.client.hotkeys.dashboard.callback
			then
				_K.client.hotkeys.dashboard.callback()
			else
				_K.client.dashboard.Window._instance.Visible = true
			end
		end
	end

	local function showCornerPrompt()
		local currentlyOwned = ownsModel or (_K.client.ownsKAModel and _K.client.ownsKAModel:peek())
		local dialog

		local favoriteButton = UI.new "Frame" {
			BackgroundTransparency = 1,
			Size = UDim2.new(0, 28, 0, 28),
			LayoutOrder = 1,

			UI.new "ImageLabel" {
				BackgroundTransparency = 1,
				Size = UDim2.new(0, 28, 0, 28),
				Image = "rbxasset://textures/ui/InspectMenu/ico_favorite@2x.png",
				ImageColor3 = Color3.new(0, 0, 0),
				ImageTransparency = 0.875,
			},
			UI.new "ImageButton" {
				Name = "FavoriteButton",
				BackgroundTransparency = 1,
				Position = UDim2.new(0, 2, 0, 2),
				Size = UDim2.new(0, 24, 0, 24),
				Image = "rbxasset://textures/ui/InspectMenu/ico_favorite@2x.png",
				ImageColor3 = Color3.new(1, 0.8, 0),
				Activated = function()
					local _ = pcall(function()
						_K.Service.AvatarEditor:PromptSetFavorite(ADMIN_MODEL_ID, 1, true)
					end)
				end,
				UI.new "Tooltip" {
					Text = "Add to Favorites",
				},
			},
		}

		local getButton = if currentlyOwned
			then nil
			else UI.new "Button" {
				LayoutOrder = 2,
				Name = "adminModelButton",
				AutomaticSize = Enum.AutomaticSize.X,
				Icon = "rbxasset://textures/ui/common/robux.png",
				IconProperties = { ImageColor3 = UI.Theme.PrimaryText },
				IconRightAlign = true,
				Label = "<b>Get Kohl's Admin</b>",
				TextXAlignment = Enum.TextXAlignment.Left,
				Size = UDim2.new(0, 0, 0, 28),

				UI.flex("fill"),

				UI.new "TextLabel" {
					Name = "Price",
					LayoutOrder = 8,
					AutoLocalize = false,
					AutomaticSize = Enum.AutomaticSize.XY,
					BackgroundTransparency = 1,
					FontFace = UI.Theme.FontMono,
					TextSize = UI.Theme.FontSize,
					TextColor3 = UI.Theme.PrimaryText,
					TextStrokeColor3 = UI.Theme.Primary,
					TextStrokeTransparency = UI.Theme.TextStrokeTransparency,
					Text = "<b>FREE</b>",
					RichText = true,
				},

				Activated = function()
					if _K.client.promptGetKA then
						_K.client.promptGetKA()
					else
						_K.client.lastAttemptedPurchase = ADMIN_MODEL_ID
						if _K.client.AllowThirdPartySales then
							_K.Service.Marketplace:PromptPurchase(_K.LocalPlayer, ADMIN_MODEL_ID)
						elseif _K.client.purchaseKADialog then
							_K.client.purchaseKADialog.Visible(true)
						end
					end
				end,
			}

		local donateButton = UI.new "Button" {
			LayoutOrder = 3,
			Name = "DonateButton",
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = Color3.fromRGB(51, 95, 255),
			BackgroundTransparency = 0.25,
			HoverTransparency = 0,
			Label = if currentlyOwned then "<b>Donate / Perks ✨</b>" else "<b>Perks ✨</b>",
			Size = UDim2.new(0, 0, 0, 28),
			UI.flex(if currentlyOwned then "fill" else "none"),
			Activated = function()
				openMarket()
				if dialog and dialog.Close and type(dialog.Close:peek()) == "function" then
					dialog.Close:peek()(dialog)
				end
			end,
		}

		local actionsRow = UI.new "Frame" {
			Name = "Actions",
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 28),
			LayoutOrder = 10,

			UI.list {
				direction = "x",
				verticalAlign = "center",
				gap = UI.Theme.PaddingWithStroke,
			},

			favoriteButton,
			getButton,
			donateButton,
		}

		local text = if currentlyOwned
			then "<b>❤️ Love Kohl's Admin?</b>\n<font transparency='0.35'>Drop a <b>Favorite ⭐</b> on the model or check out <b>Market</b> perks to support future updates!</font>"
			else "<b>❤️ Enjoying Kohl's Admin?</b>\n<font transparency='0.35'>Get the same powerful tools for your own games for <b>free</b>, or unlock donor perks!</font>"

		dialog = _K.Notify({
			From = "_K",
			Text = text,
			Duration = 30,
			actionsRow,
		})
	end

	local attempt, connection = 0, nil
	connection = _K.Hook.runPreparedCommands:Connect(function(from, _commands, _rawText, silent)
		if
			_K.Data.settings.getKohlsAdminPopup == false
			or (_K.LocalPlayer:GetAttribute("_KDonationLevel") or 0) > 3
		then
			connection:Disconnect()
			return
		end

		if (from and from ~= _K.LocalPlayer.UserId) or silent == false then
			return
		end

		attempt += 1
		if attempt >= 3 then
			connection:Disconnect()
			showCornerPrompt()
		end
	end)
end)

return true
