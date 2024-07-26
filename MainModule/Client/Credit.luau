local Credit = {}
Credit.__index = Credit

function Credit.new(_K)
	local UI = _K.client.UI
	local image = "rbxassetid://10650688076"

	-- local userIds = []
	-- https://create.roblox.com/docs/reference/engine/classes/Players#GetUserThumbnailAsync

	-- local userInfo = log.from and _K.Util.getUserInfo(log.from)
	-- local displayName = if userInfo and (userInfo.DisplayName ~= userInfo.Username)
	-- 	then userInfo.DisplayName .. " "
	-- 	else ""

	-- local contributorFrame = UI.new "Frame" {
	-- 	Name = "Contributor",
	-- 	Size = UDim2.new(1, 0, 0, 36),
	-- 	BackgroundColor3 = Color3.fromRGB(255, 144, 0),
	-- }

	local scroller = UI.new "Scroller" {
		Name = "Credit",

		-- Credit.TitleLabel
		UI.new "TextLabel" {
			Name = "Credit",
			BackgroundTransparency = 1,
			Font = UI.Theme.Font,
			TextTruncate = Enum.TextTruncate.SplitWord,

			TextSize = UI.Theme.FontSizeLargest,
			TextColor3 = UI.Theme.PrimaryText,
			Size = UDim2.new(1, 0, 0, 24),
			Text = "<sc>contributors</sc>",
			RichText = true,
		},

		UI.new "Frame" {
			Name = "Contributor",
			Size = UDim2.new(0.75, 0, 0, 48),
			BackgroundColor3 = UI.Theme.Primary,
			BackgroundTransparency = 0.75,

			UI.new "UIFlexItem" {},

			UI.new "UIPadding" {
				PaddingLeft = UI.Theme.PaddingDouble,
				PaddingRight = UI.Theme.PaddingDouble,
				PaddingTop = UI.Theme.Padding,
				PaddingBottom = UI.Theme.Padding,
			},

			UI.new "UIListLayout" {
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UI.Theme.PaddingHalf,
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalFlex = "SpaceBetween",
			},

			UI.new "UICorner" {
				CornerRadius = UI.Theme.CornerRadius,
			},

			UI.new "Frame" {
				Name = "UserDetails",
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = 1,

				UI.new "UIListLayout" {
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UI.Theme.PaddingHalf,
					FillDirection = Enum.FillDirection.Horizontal,
				},

				UI.new "ImageLabel" {
					Name = "Icon",
					BackgroundTransparency = 0.75,
					BackgroundColor3 = UI.Theme.Border,
					Size = UI.computeFrom(UDim2.fromOffset, UI.Theme.FontSizeDouble, UI.Theme.FontSizeDouble),
					Image = image,

					UI.new "UICorner" {
						CornerRadius = UDim.new(1, 0),
					},

					UI.new "UIStroke" {
						Enabled = UI.Theme.StrokeEnabled,
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
						Transparency = UI.Theme.Transparency,
						Color = UI.Theme.Border,
					},
				},

				UI.new "Frame" {
					Name = "UserFrame",
					AutomaticSize = Enum.AutomaticSize.XY,
					BackgroundTransparency = 1,

					UI.new "UIListLayout" {
						SortOrder = Enum.SortOrder.LayoutOrder,
					},
					
	
					UI.new "Frame" {
						AutomaticSize = Enum.AutomaticSize.XY,
						BackgroundTransparency = 1,
	
						UI.new "UIListLayout" {
							SortOrder = Enum.SortOrder.LayoutOrder,
							Padding = UI.Theme.PaddingHalf,
							FillDirection = Enum.FillDirection.Horizontal,
						},
	
						UI.new "TextLabel" {
							Name = "From",
							BackgroundTransparency = 1,
							TextColor3 = UI.Theme.PrimaryText,
							Text = `<b>Username</b>`,
							TextSize = UI.Theme.FontSizeLarge,
							TextTruncate = Enum.TextTruncate.SplitWord,
							TextXAlignment = "Left",
							Font = UI.Theme.Font,
							RichText = true,
	
							AutomaticSize = Enum.AutomaticSize.XY,
							Size = UI.compute(UDim2.fromOffset, 0, UI.Theme.FontSizeLarge),
						},
					},
	
					UI.new "TextLabel" {
						Name = "FromBottom",
						BackgroundTransparency = 1,
						TextColor3 = UI.Theme.PrimaryText,
						Text = `<font transparency="0.5"><b>@Name</b></font>`,
						TextSize = UI.Theme.FontSizeSmall,
						TextTruncate = Enum.TextTruncate.SplitWord,
						TextXAlignment = "Left",
						Font = UI.Theme.Font,
						RichText = true,
	
						AutomaticSize = Enum.AutomaticSize.XY,
						Size = UI.compute(UDim2.fromOffset, 0, UI.Theme.FontSizeSmall),
					},
				},

				
			},

			UI.new "TextLabel" {
				Name = "Credit",
				BackgroundTransparency = 1,
				Font = UI.Theme.Font,
				TextTruncate = Enum.TextTruncate.SplitWord,
				AutomaticSize = Enum.AutomaticSize.XY,
				TextSize = UI.Theme.FontSizeLargest,
				TextColor3 = UI.Theme.MutedText,
				TextSize = UI.Theme.FontSizeSmall,
				Text = "<sc>Design</sc>",
				RichText = true,
			},

			
			
		}


		-- frame list of user info
	}
	scroller._instance.UIListLayout.HorizontalAlignment = "Center"
	return scroller._instance
end

return Credit
