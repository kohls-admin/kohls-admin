local Members = {}
Members.__index = Members

local memberRichFormat = `<b>%s</b> %s\t<font transparency="0.5">%s</font>`
local filterRichFormat = `<font transparency="0.5">%s</font><b>%s</b><font transparency="0.5">%s</font>`

function Members.new(_K)
	local UI = _K.client.UI
	local escape = _K.Util.escapeRichText

	local scroller = UI.new "ScrollerFast" {
		Name = "Members",
		List = UI.Scope.members,
		DictList = true,
		FilterInput = true,
		RenderText = function(self, member)
			if self._filter ~= "" then
				local text = `{member.name} {member.userId}\t{table.concat(member.roles, " | ")}`
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
				memberRichFormat,
				escape(member.name),
				escape(member.userId),
				escape(table.concat(member.roles, " | "))
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
			local member = _K.Data.members[userId]
			if not member then
				continue
			end
			member.userId = userId
			local text = `{member.name} {userId}\t{table.concat(member.roles, " | ")}`
			if text:lower():find(filter, 1, true) then
				table.insert(new, member)
			end
		end
		return new
	end

	scroller:filter(filterTest)

	return scroller
end

return Members
