local Logs = {}
Logs.__index = Logs

local logRichFormat = `<font transparency="0.5">%s</font> <font color="%s"><b>%s</b></font> %s`
local filterRichFormat = `<font transparency="0.5">%s</font><b>%s</b><font transparency="0.5">%s</font>`
local logTypeColors = {
	Chat = "#0f0",
	Command = "#ff0",
	Info = "#0ff",
	Warning = "#f80",
	Error = "#f00",
	System = "#fff",
}

function Logs.new(_K)
	local UI = _K.UI
	local escape = _K.Util.escapeRichText

	local scroller = UI.new "ScrollerFast" {
		Name = "Logs",
		List = _K.logState,
		FilterInput = true,
		RenderText = function(self, log)
			local msg = log[2]
			local timestamp = os.date("%y-%m-%d %X", log[1])
			local logTypeLabel = _K.Enum.LogType[log[3]]

			if self._filter ~= "" then
				local text = `{timestamp} {logTypeLabel:upper()} {msg}`
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
				logTypeColors[logTypeLabel] or "#fff",
				logTypeLabel:upper(),
				escape(msg)
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
			local timestamp = os.date("%y-%m-%d %X", log[1])
			local logTypeLabel = _K.Enum.LogType[log[3]]
			local text = `{timestamp} {logTypeLabel:upper()} {log[2]}`
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
