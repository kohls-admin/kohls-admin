local _K = require(script.Parent.Parent)
local UI = _K.UI

task.defer(function()
	local ADMIN_MODEL_ID = 172732271
	local ok, owned = _K.Util.Retry(function()
		return _K.Service.Marketplace:PlayerOwnsAssetAsync(_K.LocalPlayer, ADMIN_MODEL_ID)
	end)

	local dialog
	local adminModelButton = UI.new "Button" {
		LayoutOrder = 10,
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
				Activated = function()
					pcall(function()
						_K.Service.AvatarEditor:PromptSetFavorite(ADMIN_MODEL_ID, 1, true)
					end)
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
			Text = if owned then "<b>OWNED</b>" else "<b>FREE</b>",
			RichText = true,
		},

		Activated = if owned
			then nil
			else function()
				_K.client.lastAttemptedPurchase = true
				if _K.client.AllowThirdPartySales then
					_K.Service.Marketplace:PromptPurchase(_K.LocalPlayer, ADMIN_MODEL_ID)
				else
					_K.client.purchaseKADialog.Visible(true)
				end
			end,
	}

	local donations = UI.new "Frame" {
		Name = "Donations",
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -2, 0, 0),
		LayoutOrder = 11,

		UI.new "UIListLayout" {
			SortOrder = Enum.SortOrder.LayoutOrder,
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalFlex = Enum.UIFlexAlignment.SpaceEvenly,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UI.Theme.PaddingWithStroke,
			Wraps = true,
		},
	}

	_K.client.generateDonationButtons(donations)

	dialog = UI.new "Dialog" {
		Parent = UI.LayerTop,
		Title = "❤️ Kohl's Admin?",
		Text = `<b>Stop playing. Take command.</b> Get the same powerful tools used here for your own games.\n<font transparency="0.5">Total control, advanced security, and professional moderation are yours for <b>free</b>.</font>`,
		Visible = false,
		Draggable = true,
		ExitButton = true,
		BackgroundTransparency = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.new(0, 480, 0, 0),
		Modal = true,
		ZIndex = 999,

		adminModelButton,
		donations,
	}

	local attempt, connection = 0, nil
	connection = _K.Hook.runPreparedCommands:Connect(function()
		if not _K.Data.settings.getKohlsAdminPopup then
			connection:Disconnect()
			dialog:Destroy()
		end

		attempt += 1
		if attempt == 4 then
			connection:Disconnect()
			dialog.Visible(true)
		end
	end)
end)

return true
