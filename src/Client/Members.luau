local Members = {}
Members.__index = Members

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

	local function renderItem(self, item, userId)
		local member = _K.Data.members[userId]
		if member and member.renderText then
			item.TextLabel.Text = member.renderText
			item.ImageLabel.Image = `rbxthumb://type=AvatarHeadShot&id={member.userId}&w=48&h=48`
		end
	end

	local scroller = UI.new "ScrollerFast" {
		Name = "Members",
		List = _K.client.members,
		Enabled = false,
		DictList = true,
		FilterInput = true,
		Visible = false,
		CreateItem = createItem,
		RenderItem = renderItem,
	}
	UI.edit(scroller._scroller, {
		UI.new "UIFlexItem" {
			FlexMode = Enum.UIFlexMode.Fill,
		},
	})

	local function isDifferent(a: { string? }?, b: { string? }?)
		if not a ~= not b then
			return true
		end
		if a and b then
			if #a ~= #b then
				return true
			end
			for k, v in a do
				if b[k] ~= v then
					return true
				end
			end
		end
		return false
	end

	local function updateCache(member)
		member.nameCache = member.name
		member.rolesCache = if member.roles then table.clone(member.roles) else nil
		member.persistCache = if member.persist then table.clone(member.persist) else nil

		if member.roles then
			local roles = {}
			for _, role in member.roles do
				if not table.find(member.persist, role) then
					table.insert(roles, role)
				end
			end

			member.persistString = if member.persist then table.concat(member.persist, " | ") else ""
			member.roleString = table.concat(roles, " | ") or ""
			if #member.persistString > 0 and #member.roleString > 0 then
				member.roleString = " | " .. member.roleString
			end
		else
			member.roleString = ""
		end

		member.richText = `<b>{member.name or "UNKNOWN"}</b> [{member.userId}]\t<font transparency="0.33"><b>{escape(
			member.persistString
		)}</b></font><font transparency="0.66">{escape(member.roleString)}</font>`

		member.rawText = `{member.name or "UNKNOWN"} {member.userId}\t{member.persistString}{member.roleString}`
		member.filterText = string.lower(member.rawText)
	end

	local function filterTest(self, list)
		local filter = string.lower(scroller._input._input.Text)
		self._filter = filter

		local noFilter = string.find(self._filter, "^%s*$")

		local new = {}
		for _, userId in list do
			local member = _K.Data.members[userId]
			if not member then
				continue
			end

			if
				member.name ~= member.nameCache
				or isDifferent(member.roles, member.rolesCache)
				or isDifferent(member.persist, member.persistCache)
			then
				member.userId = userId
				updateCache(member)
			end

			if noFilter then
				member.renderText = member.richText
				table.insert(new, userId)
			else
				local filterFound = string.find(member.filterText, filter, 1, true)
				if filterFound then
					local pre = escape(string.sub(member.rawText, 1, filterFound - 1))
					local query = escape(string.sub(member.rawText, filterFound, filterFound + #filter - 1))
					local post = escape(string.sub(member.rawText, filterFound + #filter))
					member.renderText =
						`<font transparency="0.5">{pre}</font><b>{query}</b><font transparency="0.5">{post}</font>`
					table.insert(new, userId)
				end
			end
		end
		return new
	end

	task.defer(scroller.filter, scroller, filterTest)

	return scroller
end

return Members
