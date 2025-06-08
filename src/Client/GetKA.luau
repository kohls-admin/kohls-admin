local _K = require(script.Parent.Parent)
local UI = _K.UI

task.defer(function()
	local adminModelId = 172732271
	local ok, owned = _K.Util.Retry(function()
		return _K.Service.Marketplace:PlayerOwnsAsset(_K.LocalPlayer, adminModelId)
	end)

	if not ok or owned then
		return
	end

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
				_K.client.purchaseLink.Text = "create.roblox.com/store/asset/" .. adminModelId
				if _K.client.AllowThirdPartySales then
					_K.Service.Marketplace:PromptPurchase(_K.LocalPlayer, adminModelId)
				else
					_K.client.purchaseDialog.Visible:set(true)
					dialog.Visible:set(false)
				end
			end,
		},
	}

	dialog = UI.new "Dialog" {
		Parent = UI.LayerTop,
		Title = "❤️ Kohl's Admin?",
		Text = "Used by <b>30M+</b> developers since 2011, Kohl's Admin is the leading tool for experience management. 🚀",
		Visible = false,
		Draggable = true,
		ExitButton = true,
		BackgroundTransparency = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.new(0, 320, 0, 0),
		Modal = true,
		ZIndex = 1000,

		adminModelButton,
	}

	local attempt, connection = 0, nil
	connection = _K.Hook.runPreparedCommands:Connect(function()
		if not _K.Data.settings.getKohlsAdminPopup then
			connection:Disconnect()
			dialog:Destroy()
		end

		attempt += 1
		if attempt == 5 then
			connection:Disconnect()
			dialog.Visible:set(true)
		end
	end)
end)

return true
