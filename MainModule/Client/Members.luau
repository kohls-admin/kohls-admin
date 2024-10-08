local Members = {}
Members.__index = Members

local memberRichFormat = `<b>%s</b> [%s]\t<font transparency="0.33"><b>%s</b></font><font transparency="0.66">%s</font>`
local filterRichFormat = `<font transparency="0.5">%s</font><b>%s</b><font transparency="0.5">%s</font>`

local function filteredText(_K, escape, self, lineItem, member, persist, roles)
	local text = `{member.name or "UNKNOWN"} {member.userId}\t{roles}`
	local filterFound = string.find(string.lower(text), self._filter)

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

	local scroller = UI.new "ScrollerFast" {
		Name = "Members",
		List = UI.Scope.members,
		Enabled = false,
		DictList = true,
		FilterInput = true,
		RenderText = function(self, lineItem, member)
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

			if self._filter ~= "" then
				return filteredText(_K, escape, self, lineItem, member, persist, roleString)
			end

			return string.format(
				memberRichFormat,
				member.name or "UNKNOWN",
				member.userId,
				escape(persist),
				escape(roleString)
			)
		end,
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
			local member = _K.Data.members[userId]
			if not member then
				continue
			end
			member.userId = userId
			local text = `{member.name} {userId}\t{if member.roles then table.concat(member.roles, " | ") else ""}`
			if string.find(string.lower(text), filter, 1, true) then
				table.insert(new, member)
			end
		end
		return new
	end

	task.defer(scroller.filter, scroller, filterTest)

	return scroller
end

return Members
