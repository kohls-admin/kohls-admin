local _K = nil

local function sanitizeMember(self, memberId: string)
	if self.definition.ignoreSelf then
		if memberId == tostring(self.command.from) then
			return nil, "Can't target yourself"
		end
	else
		if memberId == tostring(self.command.from) then
			return memberId
		end
	end

	local rank, role = self._K.Auth.getRank(self.command.from)
	if role.onlyTargetSelf then
		if memberId == tostring(self.command.from) then
			return memberId
		else
			return nil, "Can only target yourself"
		end
	elseif self.definition.lowerRank or self.definition.shouldRequest then
		if self._K.Auth.getRank(memberId) < rank then
			return memberId
		end
		return nil, "Can only target lower ranks"
	else
		return memberId
	end
end

local function parseMember(input: string, self: any): string?
	local query = string.lower(input)
	local fromString = tostring(self.command.from)

	if input == "" or input == "me" and _K.Data.members[fromString] then
		return sanitizeMember(self, fromString)
	end

	local partial
	for id, member in _K.Data.members do
		local name = string.lower(member.name)
		if id == query or name == query then
			return sanitizeMember(self, id)
		end
		if not partial and string.find(name, query, 1, true) == 1 then
			partial = id
		end
	end

	if partial then
		return sanitizeMember(self, partial)
	end

	return nil, "Invalid member"
end

local function nameSort(a, b)
	return string.lower(a[1]) < string.lower(b[1])
end

local function idSort(a, b)
	return a[1] < b[1]
end

local typeMember = {
	validate = parseMember,
	parse = parseMember,
	suggestions = function(text: string, from: number, definition)
		local names, ids = {}, {}
		local fromString = tostring(from)
		local rank = _K.Auth.getRank(from)
		local lowerRank = definition.lowerRank or definition.shouldRequest

		for id, member in _K.Data.members do
			local memberRank = _K.Auth.getRank(id)
			if definition.ignoreSelf and id == fromString then
				continue
			end
			if not lowerRank or (fromString == id) or rank > memberRank then
				table.insert(ids, { id, `{id} ({member.name})` })
				table.insert(names, { member.name, nil })
			end
		end

		table.sort(names, nameSort)
		table.sort(ids, idSort)
		table.move(ids, 1, #ids, #names + 1, names)

		local fromMember = _K.Data.members[fromString]
		if fromMember and not definition.ignoreSelf then
			table.insert(names, 1, { "me", `me ({fromMember.name})` })
		end

		return _K.Util.Suggest.query(text, names)
	end,
}

local typeMembers = {
	listable = true,
}

return function(context)
	_K = context
	_K.Registry.registerType("member", typeMember)
	_K.Registry.registerType("members", typeMembers, typeMember)
end
