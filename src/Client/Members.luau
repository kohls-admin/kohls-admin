local Members = {}
Members.__index = Members

local memberRichFormat = `<b>%s</b> [%s]\t<font transparency="0.33"><b>%s</b></font><font transparency="0.66">%s</font>`
local filterRichFormat = `<font transparency="0.5">%s</font><b>%s</b><font transparency="0.5">%s</font>`

local function filteredText(_K, escape, self, lineItem, member, persist, roles)
	local text = `{member.name or "UNKNOWN"} {member.userId}\t{roles}`
	local filterFound = string.find(string.lower(text), self._filter, 1, true)

	return if filterFound
		then string.format(
			filterRichFormat,
			escape(string.sub(text, 1, filterFound - 1)),
			escape(string.sub(text, filterFound, filterFound + #self._filter - 1)),
			escape(string.sub(text, filterFound + #self._filter))
		)
		else text
end

function Members.new(_K)
	local UI = _K.UI
	local escape = _K.Util.String.escapeRichText

	local function createItem(self, log)
		return UI.new "Frame" {
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

				UI.new "UIFlexItem" { FlexMode = Enum.UIFlexMode.Fill },
			},
		}
	end

	local function renderItem(self, item, member)
		local roles = {}
		if member.roles then
			for _, role in member.roles do
				if not table.find(member.persist, role) then
					table.insert(roles, role)
				end
			end
		end

		local persist = if member.persist then table.concat(member.persist, " | ") else ""
		local roleString = table.concat(roles, " | ") or ""
		if #persist > 0 and #roleString > 0 then
			persist ..= " | "
		end

		local text
		if self._filter ~= "" then
			text = filteredText(_K, escape, self, item, member, persist, roleString)
		else
			text = string.format(
				memberRichFormat,
				member.name or "UNKNOWN",
				member.userId,
				escape(persist),
				escape(roleString)
			)
		end

		item.TextLabel.Text = text
		item.ImageLabel.Image = `rbxthumb://type=AvatarHeadShot&id={member.userId}&w=48&h=48`
	end

	local scroller = UI.new "ScrollerFast" {
		Name = "Members",
		List = _K.client.members,
		Enabled = false,
		DictList = true,
		FilterInput = true,
		CreateItem = createItem,
		RenderItem = renderItem,
	}
	UI.edit(scroller._scroller, {
		UI.new "UIFlexItem" {
			FlexMode = Enum.UIFlexMode.Fill,
		},
	})

	local debounceScrollerUpdate = _K.Util.Function.debounce(0.2, scroller.refreshList)

	local function filterTest(self, list)
		local filter = string.lower(scroller._input._input.Text)
		self._filter = filter
		local new = {}
		for _, userId in list do
			local member = _K.Data.members[userId]
			if not member then
				continue
			end
			member.userId = userId
			local text = `{member.name} {userId}\t{if member.roles then table.concat(member.roles, " | ") else ""}`
			if string.find(string.lower(text), filter, 1, true) then
				table.insert(new, member)
			end
			if not member.name then
				task.spawn(function()
					local info = _K.Util.getUserInfo(member.userId)
					member.name = info.Username
					debounceScrollerUpdate(scroller)
				end)
			end
		end
		return new
	end

	task.defer(scroller.filter, scroller, filterTest)

	return scroller
end

return Members
