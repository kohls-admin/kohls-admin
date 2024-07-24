local Logs = {}
Logs.__index = Logs

local logRichFormat = `<font transparency="0.5">%s</font> <font color="%s"><b>%s</b></font> %s%s`
local filterRichFormat = `<font transparency="0.5">%s</font><b>%s</b><font transparency="0.5">%s</font>`
local logTypeColors = {
	DEBUG = "#888",
	INFO = "#fff",
	WARN = "#f80",
	ERROR = "#f00",
	CHAT = "#0ff",
	COMMAND = "#ff0",
	JOIN = "#0f8",
	LEAVE = "#80f",
	KILL = "#800",
	DEATH = "#880",
	PURCHASE = "#0f0",
}

function Logs.new(_K)
	local UI = _K.client.UI
	local escape = _K.Util.escapeRichText

	local scroller = UI.new "ScrollerFast" {
		Name = "Logs",
		List = UI.Scope.logs,
		FilterInput = true,
		ReverseOrder = true,
		RenderText = function(self, log)
			local timestamp = os.date("%y-%m-%d %X", log.time)
			local levelText = _K.logger:decode(log.level)
			local userInfo = log.from and _K.Util.getUserInfo(log.from)
			local displayName = if userInfo and (userInfo.DisplayName ~= userInfo.Username)
				then userInfo.DisplayName .. " "
				else ""

			if self._filter ~= "" then
				local fromText = if userInfo then `{displayName}@{userInfo.Username}: ` else ""
				local text = `{timestamp} {levelText:upper()} {fromText}{log.text}`
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
				logRichFormat,
				escape(timestamp),
				logTypeColors[levelText] or "#fff",
				levelText:upper(),
				if userInfo
					then `{escape(displayName)}<font transparency="0.5">@{escape(userInfo.Username)}:</font> `
					else "",
				escape(log.text)
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
		for i, log in list do
			local timestamp = os.date("%y-%m-%d %X", log.time)
			local levelText = _K.logger:decode(log.level)
			local userInfo = log.from and _K.Util.getUserInfo(log.from)
			local displayName = if userInfo and (userInfo.DisplayName ~= userInfo.Username)
				then userInfo.DisplayName .. " "
				else ""
			local fromText = if userInfo then `{displayName}@{userInfo.Username}: ` else ""
			local text = `{timestamp} {levelText:upper()} {fromText}{log.text}`
			if text:lower():find(filter, 1, true) then
				table.insert(new, log)
			end
		end
		return new
	end

	scroller:filter(filterTest)

	return scroller
end

return Logs
