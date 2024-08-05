local Bans = {}
Bans.__index = Bans

local banRichFormat = `<b>@%s</b><font transparency="0.5">%s</font> %s\t%s\t<font transparency="0.5">%s</font>`
local filterRichFormat = `<font transparency="0.5">%s</font><b>%s</b><font transparency="0.5">%s</font>`

function Bans.new(_K)
	local UI = _K.client.UI
	local escape = _K.Util.escapeRichText

	local scroller = UI.new "ScrollerFast" {
		Name = "Bans",
		List = UI.Scope.bans,
		DictList = true,
		FilterInput = true,
		RenderText = function(self, ban)
			local term = if ban[3]
				then (if ban[3] > 0 then os.date("%y-%m-%d %X", ban[3]) else "Permanently")
				else "Session"

			local userInfo = _K.Util.getUserInfo(ban.userId)
			local displayName = if userInfo and (userInfo.DisplayName ~= userInfo.Username)
				then userInfo.DisplayName .. " "
				else ""

			if self._filter ~= "" then
				local text = `@{userInfo.Username} {displayName}{ban.userId}\t{ban[2]}\t{term}`
				local filterFound = string.find(text:lower(), self._filter)
				return if filterFound
					then string.format(
						filterRichFormat,
						escape(string.sub(text, 1, filterFound - 1)),
						escape(string.sub(text, filterFound, filterFound + #self._filter - 1)),
						escape(string.sub(text, filterFound + #self._filter))
					)
					else text
			end

			return string.format(
				banRichFormat,
				escape(userInfo.Username),
				escape(displayName),
				escape(ban.userId),
				escape(ban[2]),
				escape(term)
			)
		end,
	}
	UI.edit(scroller._scroller, {
		UI.new "UIFlexItem" {
			FlexMode = Enum.UIFlexMode.Fill,
		},
	})
	local function filterTest(self, list)
		local filter = scroller._input.Value._value:lower()
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
			local text = `@{userInfo.Username} {displayName} {ban.userId}\t{ban[2]}\t{term}`
			if text:lower():find(filter, 1, true) then
				table.insert(new, ban)
			end
		end
		return new
	end

	scroller:filter(filterTest)

	return scroller
end

return Bans
