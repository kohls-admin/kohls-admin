local Bans = {}
Bans.__index = Bans

local banRichFormat = `<b>@%s</b><font transparency="0.5">%s</font> [%s]\t%s\t<font transparency="0.5">%s</font>`
local filterRichFormat = `<font transparency="0.5">%s</font><b>%s</b><font transparency="0.5">%s</font>`

function Bans.new(_K)
	local UI = _K.UI
	local escape = _K.Util.String.escapeRichText

	local function createItem(self, log)
		return UI.new "TextLabel" {
			AutoLocalize = false,
			BackgroundTransparency = 1,
			Size = self.ItemSize,
			RichText = true,
			Font = UI.Theme.FontMono,
			TextSize = UI.Theme.FontSize,
			TextColor3 = UI.Theme.PrimaryText,
			TextTruncate = Enum.TextTruncate.SplitWord,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
		}
	end

	local function renderItem(self, item, ban)
		if not ban.userId then
			return
		end

		local reason = if ban[2] and _K.Util.String.trim(ban[2]) ~= "" then ban[2] else "No reason."
		local term = ban[3]
		term = if term
			then (if term > 0 and term ~= math.huge then os.date("%y-%m-%d %X", ban[3]) else "Forever")
			else "Session"

		local text
		if self._filter ~= "" then
			text = `@{ban[1]} [{ban.userId}]\t{reason}\t{term}`
			local filterFound = string.find(text:lower(), self._filter)
			text = if filterFound
				then string.format(
					filterRichFormat,
					escape(string.sub(text, 1, filterFound - 1)),
					escape(string.sub(text, filterFound, filterFound + #self._filter - 1)),
					escape(string.sub(text, filterFound + #self._filter))
				)
				else text
		else
			text = string.format(
				banRichFormat,
				if ban[1] then escape(ban[1]) else "",
				"",
				ban.userId,
				escape(reason),
				escape(term)
			)
		end

		item.Text = text
		task.spawn(function()
			local userInfo = _K.Util.getUserInfo(ban.userId)
			local displayName = if userInfo and (userInfo.DisplayName ~= userInfo.Username)
				then userInfo.DisplayName .. " "
				else ""

			if item.Text == text and self._filter == "" then
				item.Text = string.format(
					banRichFormat,
					if userInfo.Deleted
						then "<s>DELETED</s>"
						elseif userInfo.Unknown then "<s>UNKNOWN</s>"
						else escape(userInfo.Username),
					if userInfo.Deleted or userInfo.Unknown then "" else escape(displayName),
					escape(ban.userId),
					escape(reason),
					escape(term)
				)
			end
		end)
	end

	local scroller = UI.new "ScrollerFast" {
		Name = "Bans",
		List = UI.Scope.bans,
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
			local term = if ban[3]
				then (if ban[3] > 0 then os.date("%y-%m-%d %X", ban[3]) else "Permanently")
				else "Session"
			local userInfo = _K.Util.getUserInfo(ban.userId)
			local displayName = if userInfo and (userInfo.DisplayName ~= userInfo.Username)
				then userInfo.DisplayName .. " "
				else ""
			local text = `@{userInfo.Username} {displayName} {ban.userId}\t{ban[2] or "No reason."}\t{term}`
			if text:lower():find(filter, 1, true) then
				table.insert(new, ban)
			end
		end
		return new
	end

	task.defer(scroller.filter, scroller, filterTest)

	return scroller
end

return Bans
