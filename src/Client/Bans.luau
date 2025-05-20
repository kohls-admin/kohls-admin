local Bans = {}
Bans.__index = Bans

local banRichFormat = `<b>@%s</b><font transparency="0.5">%s</font> [%s]`
local filterRichFormat = `<font transparency="0.5">%s</font><b>%s</b><font transparency="0.5">%s</font>`

function Bans.new(_K)
	local UI = _K.UI
	local escape = _K.Util.String.escapeRichText

	local unbanDialog
	unbanDialog = UI.new "Dialog" {
		LayoutOrder = 9,
		BackgroundTransparency = 0.875,
		BackgroundColor3 = UI.Theme.Secondary,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.fromScale(1, 0),
		ActionText = "Unban this user?",
		Action = true,
		LeftAction = true,
		RightAction = true,
		Visible = false,
		Close = function(self)
			task.defer(self.Activated.set, self.Activated, false)
		end,

		[UI.Hook] = {
			Action = function(v)
				unbanDialog._instance.Visible = false
				if v and unbanDialog.userId then
					_K.Remote.Unban:FireServer(tonumber(unbanDialog.userId))
				end
				unbanDialog.userId = nil
			end,
		},
	}
	unbanDialog._content:Destroy()

	local function createItem(self)
		local item
		local unbanButton = UI.new "Button" {
			LayoutOrder = 9,
			BackgroundColor3 = Color3.fromRGB(200, 0, 0),
			Size = UDim2.new(1, 0, 1, 0),
			SizeConstraint = Enum.SizeConstraint.RelativeYY,
			Icon = "rbxassetid://1476571006",
			IconProperties = {
				Size = UDim2.new(0, 10, 0, 10),
			},
			Text = "",
			Activated = function()
				local userId = item:GetAttribute("_KUserId")
				unbanDialog.userId = userId
				unbanDialog.ActionText:set(`Unban {item:GetAttribute("_KName")} [{userId}]?`)
				unbanDialog._instance.Visible = true
			end,
		}

		item = UI.new "Frame" {
			BackgroundTransparency = 1,
			Size = self.ItemSize,

			UI.new "UIPadding" {
				PaddingTop = UI.Theme.PaddingHalf,
				PaddingBottom = UI.Theme.PaddingHalf,
			},

			UI.new "UIListLayout" {
				VerticalAlignment = Enum.VerticalAlignment.Center,
				FillDirection = Enum.FillDirection.Horizontal,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UI.Theme.Padding,
			},

			UI.new "ImageLabel" {
				BackgroundTransparency = 0.75,
				BackgroundColor3 = UI.Theme.Border,
				Size = UDim2.new(1, 0, 1, 0),
				SizeConstraint = Enum.SizeConstraint.RelativeYY,

				UI.new "UICorner" {
					CornerRadius = UDim.new(1, 0),
				},
				UI.new "UIStroke" {
					Enabled = UI.Theme.StrokeEnabled,
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					Transparency = UI.Theme.TransparencyClamped,
					Color = UI.Theme.Border,
				},
			},

			UI.new "TextLabel" {
				Name = "Left",
				AutoLocalize = false,
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundTransparency = 1,
				Size = UDim2.new(0, 0, 1, 0),
				RichText = true,
				Font = UI.Theme.FontMono,
				TextSize = UI.Theme.FontSize,
				TextColor3 = UI.Theme.PrimaryText,
				TextTruncate = Enum.TextTruncate.SplitWord,
				TextXAlignment = Enum.TextXAlignment.Left,
			},
			UI.new "TextLabel" {
				Name = "Right",
				AutoLocalize = false,
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundTransparency = 1,
				Size = UDim2.new(0, 0, 1, 0),
				RichText = true,
				Font = UI.Theme.FontMono,
				TextSize = UI.Theme.FontSize,
				TextColor3 = UI.Theme.PrimaryText,
				TextTruncate = Enum.TextTruncate.SplitWord,
				TextXAlignment = Enum.TextXAlignment.Right,

				UI.new "UIFlexItem" { FlexMode = Enum.UIFlexMode.Fill },
			},

			unbanButton,
		}

		return item
	end

	local function renderItem(self, item, ban)
		if not ban.userId then
			return
		end

		item:SetAttribute("_KName", ban[1])
		item:SetAttribute("_KUserId", ban.userId)

		local reason = if ban[2] and _K.Util.String.trim(ban[2]) ~= "" then ban[2] else "No reason."
		local term = ban[3]
		term = if term
			then (if term > 0 and term ~= math.huge then os.date("%y-%m-%d %X", ban[3]) else "Forever")
			else "Session"

		local left, right
		if self._filter ~= "" then
			left = `@{ban[1] or "UNKNOWN"} [{ban.userId}]`
			right = reason .. string.rep(" ", 18 - #term) .. term
			local filterLeft = string.find(string.lower(left), self._filter, 1, true)
			if filterLeft then
				right = string.format(filterRichFormat, right, "", "")
				left = string.format(
					filterRichFormat,
					escape(string.sub(left, 1, filterLeft - 1)),
					escape(string.sub(left, filterLeft, filterLeft + #self._filter - 1)),
					escape(string.sub(left, filterLeft + #self._filter))
				)
			else
				local filterRight = string.find(string.lower(right), self._filter, 1, true)
				if filterRight then
					left = string.format(filterRichFormat, left, "", "")
					right = string.format(
						filterRichFormat,
						escape(string.sub(right, 1, filterRight - 1)),
						escape(string.sub(right, filterRight, filterRight + #self._filter - 1)),
						escape(string.sub(right, filterRight + #self._filter))
					)
				end
			end
		else
			left = string.format(banRichFormat, if ban[1] then escape(ban[1]) else "UNKNOWN", "", ban.userId)
			right = `<font transparency="0.5">{term}</font>`
			if #term < 18 then
				right = reason .. string.rep(" ", 18 - #term) .. right
			else
				right = reason .. right
			end
		end

		item.Left.Text = left
		item.Right.Text = right
		if item:FindFirstChild("ImageLabel") then
			item.ImageLabel.Image = `rbxthumb://type=AvatarHeadShot&id={ban.userId}&w=48&h=48`
		end

		task.spawn(function()
			local userInfo = _K.Util.getUserInfo(ban.userId)
			local displayName = if userInfo and (userInfo.DisplayName ~= userInfo.Username)
				then userInfo.DisplayName .. " "
				else ""

			if item.Left.Text == left and self._filter == "" then
				item:SetAttribute("_KName", userInfo.Username)

				item.Left.Text = string.format(
					banRichFormat,
					if not userInfo.Deleted and not userInfo.Unknown
						then escape(userInfo.Username)
						elseif ban[1] then escape(ban[1])
						elseif userInfo.Deleted then "<s>DELETED</s>"
						else "<s>UNKNOWN</s>",
					if userInfo.Deleted or userInfo.Unknown then "" else escape(displayName),
					escape(ban.userId),
					escape(reason)
				)
			end
		end)
	end

	local scroller = UI.new "ScrollerFast" {
		Name = "Bans",
		List = _K.client.bans,
		Enabled = false,
		DictList = true,
		FilterInput = true,
		Visible = false,
		CreateItem = createItem,
		RenderItem = renderItem,

		unbanDialog,
	}
	UI.edit(scroller._scroller, {
		UI.new "UIFlexItem" {
			FlexMode = Enum.UIFlexMode.Fill,
		},
	})

	local function filterTest(self, list)
		local filter = string.lower(scroller._input._input.Text)
		self._filter = filter
		local new = {}
		for _, userId in list do
			local ban = _K.Data.bans[userId]
			if not ban then
				warn("no ban defined?")
				continue
			end
			ban.userId = userId

			local reason = if ban[2] and _K.Util.String.trim(ban[2]) ~= "" then ban[2] else "No reason."
			local term = ban[3]
			term = if term
				then (if term > 0 and term ~= math.huge then os.date("%y-%m-%d %X", ban[3]) else "Forever")
				else "Session"

			local text = `@{ban[1] or "UNKNOWN"} [{ban.userId}]\t{reason}\t{term}`
			if string.find(string.lower(text), filter, 1, true) then
				table.insert(new, ban)
			end
		end
		return new
	end

	task.defer(scroller.filter, scroller, filterTest)

	return scroller
end

return Bans
