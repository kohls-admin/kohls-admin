local Members = {}
Members.__index = Members

local memberRichFormat = `<b>%s</b> %s\t<font transparency="0.5">%s</font>`
local filterRichFormat = `<font transparency="0.5">%s</font><b>%s</b><font transparency="0.5">%s</font>`

local function filteredText(_K, escape, self, lineItem, member, roles, name)
	local text = `{name} {member.userId}\t{roles}`
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
			local roles = table.concat(member.roles, " | ")

			if self._filter ~= "" then
				local userInfo = _K.Util.getUserInfo(member.userId)

				if not userInfo then
					task.defer(function()
						local info = _K.Util.getUserInfo(member.userId)
						lineItem.Text = filteredText(_K, escape, self, lineItem, member, roles, info.Username)
					end)
				end

				local name = if userInfo then userInfo.Username else "LOADING"
				return filteredText(_K, escape, self, lineItem, member, roles, name)
			end

			local userInfo = _K.Util.getUserInfo(member.userId)

			if not userInfo then
				task.defer(function()
					local info = _K.Util.getUserInfo(member.userId)
					lineItem.Text = string.format(memberRichFormat, info.Username, escape(member.userId), escape(roles))
				end)
			end

			local name = if userInfo then userInfo.Username else "LOADING"
			return string.format(memberRichFormat, name, escape(member.userId), escape(roles))
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
			local text = `{member.name} {userId}\t{table.concat(member.roles, " | ")}`
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
