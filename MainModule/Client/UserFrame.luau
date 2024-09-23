local Players = game:GetService("Players")

local _K = require(script.Parent.Parent)
local UI = require(script.Parent.UI)

local thumbCache = {}
local function userThumb(userId: number)
	if thumbCache[userId] then
		return thumbCache[userId]
	end

	local ok, content = _K.Util.Retry(function()
		return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
	end, 5, 1, 2)

	if ok then
		thumbCache[userId] = content
	end
	return if ok then content else nil
end

return function(from: number?, name: string?, image: string?, badgeEnabled: boolean?)
	local displayName = name or "Kohl's Admin"
	image = image or "rbxassetid://10650688076"

	if badgeEnabled == nil then
		badgeEnabled = true
	end

	local userName = "Scripth"
	local badge = "system"
	local color = "#fff"

	local imageLabel = UI.new "ImageLabel" {
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
			Transparency = UI.Theme.TransparencyClamped,
			Color = UI.Theme.Border,
		},
	}

	local displayNameLabel = UI.new "TextLabel" {
		AutoLocalize = false,
		Name = "From",
		BackgroundTransparency = 1,
		TextColor3 = UI.Theme.PrimaryText,
		Text = `<b>{displayName}</b>`,
		TextSize = UI.Theme.FontSizeLarge,
		TextTruncate = Enum.TextTruncate.SplitWord,
		TextXAlignment = "Left",
		Font = UI.Theme.Font,
		RichText = true,

		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UI.compute(UDim2.fromOffset, 0, UI.Theme.FontSizeLarge),
	}

	local userNameLabel = UI.new "TextLabel" {
		AutoLocalize = false,
		Name = "FromBottom",
		BackgroundTransparency = 1,
		TextColor3 = UI.Theme.PrimaryText,
		Text = `<font transparency="0.5"><b>@{userName}</b></font>`,
		TextSize = UI.Theme.FontSizeSmall,
		TextTruncate = Enum.TextTruncate.SplitWord,
		TextXAlignment = "Left",
		Font = UI.Theme.Font,
		RichText = true,

		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UI.compute(UDim2.fromOffset, 0, UI.Theme.FontSizeSmall),
	}

	local badgeLabel = if badgeEnabled
		then UI.new "TextLabel" {
			AutoLocalize = false,
			Name = "Badge",
			BackgroundColor3 = Color3.fromHex(color),
			TextColor3 = if UI.getLuminance(Color3.fromHex(color)) > 0.5 then Color3.new() else Color3.new(1, 1, 1),
			Text = `<b>{string.upper(badge)}</b>`,
			TextSize = UI.compute(function(use)
				return use(UI.Theme.FontSizeLarge) - 8
			end),
			TextTruncate = Enum.TextTruncate.SplitWord,
			TextXAlignment = "Left",
			Font = UI.Theme.FontMono,
			RichText = true,

			AutomaticSize = Enum.AutomaticSize.X,
			Size = UI.computeFrom(UDim2.fromOffset, 0, UI.Theme.FontSizeLarge),

			UI.new "UICorner" {
				CornerRadius = UI.Theme.CornerDiameter,
			},
			UI.new "UIPadding" {
				PaddingLeft = UDim.new(0, 4),
				PaddingRight = UDim.new(0, 4),
				PaddingTop = UDim.new(0, 4),
				PaddingBottom = UDim.new(0, 4),
			},
		}
		else nil

	task.spawn(function()
		if not from then
			return
		end

		-- avatar
		task.spawn(function()
			imageLabel.Image = userThumb(from) or image
		end)

		-- role badge
		if badgeLabel then
			local _rank, role = _K.Auth.getRank(from)
			badgeLabel.Text = `<b>{string.upper(if role then role.name else "Unknown")}</b>`
			badgeLabel.TextColor3 = if UI.getLuminance(Color3.fromHex(role.color or Color3.new(1, 1, 1))) > 0.5
				then Color3.new()
				else Color3.new(1, 1, 1)
		end

		-- name
		local info = _K.Util.getUserInfo(from)
		displayNameLabel.Text = `<b>{name or info.DisplayName}</b>`
		userNameLabel.Text = `<font transparency="0.5"><b>@{info.Username}</b></font>`
	end)

	return UI.new "Frame" {
		Name = "Header",
		Size = UDim2.new(),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 1,

		UI.new "UIListLayout" {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UI.Theme.PaddingHalf,
			FillDirection = Enum.FillDirection.Horizontal,
		},

		imageLabel,

		UI.new "Frame" {
			Name = "From",
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
			ClipsDescendants = true,

			UI.new "UIListLayout" {
				SortOrder = Enum.SortOrder.LayoutOrder,
				HorizontalFlex = Enum.UIFlexAlignment.Fill,
			},
			UI.new "UIFlexItem" {
				FlexMode = Enum.UIFlexMode.Shrink,
			},

			UI.new "Frame" {
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = 1,

				UI.new "UIListLayout" {
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UI.Theme.PaddingHalf,
					FillDirection = Enum.FillDirection.Horizontal,
				},

				displayNameLabel,
				badgeLabel,
			},

			userNameLabel,
		},
	}
end
