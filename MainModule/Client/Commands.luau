local Commands = {}
Commands.__index = Commands

local commandRichFormat = `<b>%s</b> %s`
local filterRichFormat = `<font transparency="0.5">%s</font><b>%s</b><font transparency="0.5">%s</font>`

local function _argsString(command)
	if not command.args or #command.args == 0 then
		return ""
	end
	local argTypes = {}
	for _, arg in command.args do
		table.insert(argTypes, arg.type)
	end
	return " <" .. table.concat(argTypes, "> <") .. ">"
end

function Commands.new(_K)
	local UI = _K.client.UI
	local escape = _K.Util.escapeRichText

	local scroller = UI.new "ScrollerFast" {
		Name = "Commands",
		List = _K.Registry.commandsList,
		FilterInput = true,
		RenderText = function(self, command)
			if self._filter ~= "" then
				local aliasText = if command.aliases and #command.aliases ~= 0
					then "/" .. table.concat(command.aliases, "/")
					else ""
				local text = `{_K.Data.settings.prefix}{command.name}{aliasText} {command.description}`
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
				commandRichFormat,
				escape(
					_K.Data.settings.prefix
						.. command.name
						.. if command.aliases and #command.aliases ~= 0
							then "/" .. table.concat(command.aliases, "/")
							else ""
				),
				escape(command.description)
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
		for _, command in list do
			local aliasText = if command.aliases and #command.aliases ~= 0
				then "/" .. table.concat(command.aliases, "/")
				else ""
			local text = `{_K.Data.settings.prefix}{command.name}{aliasText} {command.description}`
			if text:lower():find(filter, 1, true) then
				table.insert(new, command)
			end
		end
		return new
	end

	scroller:filter(filterTest)

	return scroller
end

return Commands
