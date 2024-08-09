local Logs = {}
Logs.__index = Logs

local logRichFormat = `<font transparency="0.5">%s</font> <font color="%s"><b>%s</b></font> %s%s`
local filterRichFormat = `<font transparency="0.5">%s</font><b>%s</b><font transparency="0.5">%s</font>`
local logTypeColors = {
	DEBUG = "#888",
	INFO = "#fff",
	WARN = "#ff0",
	ERROR = "#f00",
	CHAT = "#0f8",
	COMMAND = "#80f",
	JOIN = "#0f0",
	LEAVE = "#080",
	KILL = "#a00",
	DEATH = "#800",
	DAMAGE = "#a80",
	PURCHASE = "#0ff",
}

function Logs.new(_K)
	local UI = _K.client.UI
	local escape = _K.Util.String.escapeRichText

	local function filterTest(self, list)
		local filter = string.lower(self._input.Value._value)
		self._filter = filter
		local new = {}
		_K.Util.Defer.reset()
		for i, log in list do
			if not log.filterText then
				local timestamp = os.date("%y-%m-%d %X", log.time)
				local levelText = _K.logger:decode(log.level)
				local userInfo = log.from and _K.Util.getUserInfo(log.from)
				local displayName = if userInfo and (userInfo.DisplayName ~= userInfo.Username)
					then userInfo.DisplayName .. " "
					else ""
				local fromText = if userInfo then `{displayName}@{userInfo.Username}: ` else ""

				log.rawText = `{timestamp} {string.upper(levelText)} {fromText}{log.text}`
				log.filterText = string.lower(log.rawText)
				log.richText = string.format(
					logRichFormat,
					escape(timestamp),
					logTypeColors[levelText] or "#fff",
					levelText:upper(),
					if userInfo
						then `{escape(displayName)}<font transparency="0.5">@{escape(userInfo.Username)}:</font> `
						else "",
					escape(log.text)
				)
			end

			local ok, found, foundEnd = string.find(log.filterText, filter, 1, true)
			if ok and found then
				log.filterIndex = found
				log.filterEnd = foundEnd
				table.insert(new, log)
			end
			_K.Util.Defer.wait()
		end
		return new
	end

	local function renderText(self, log)
		if self._filter ~= "" then
			local text = log.rawText
			return if log.filterIndex
				then string.format(
					filterRichFormat,
					escape(string.sub(text, 1, log.filterIndex - 1)),
					escape(string.sub(text, log.filterIndex, log.filterEnd)),
					escape(string.sub(text, log.filterEnd + 1))
				)
				else text
		end

		return log.richText
	end

	local scroller = UI.new "ScrollerFast" {
		Name = "Logs",
		List = UI.Scope.logs,
		FilterInput = true,
		FilterInputDebounce = 0.2,
		ReverseOrder = true,
		RenderText = renderText,
	}
	UI.edit(scroller._scroller, {
		UI.new "UIFlexItem" {
			FlexMode = Enum.UIFlexMode.Fill,
		},
	})

	scroller:filter(filterTest)

	return scroller
end

return Logs
