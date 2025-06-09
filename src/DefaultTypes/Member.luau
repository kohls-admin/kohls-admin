local _K = nil

local function parseMember(input: string, self: any): string?
	local query = string.lower(input)
	local fromString = tostring(self.command.from)

	if input == "" or input == "me" and _K.Data.members[fromString] then
		return self._K.Auth.targetUserArgument(self, self.command.from, fromString)
	end

	local partial
	for id, member in _K.Data.members do
		local name = string.lower(member.name)
		if id == query or name == query then
			return self._K.Auth.targetUserArgument(self, tonumber(id) :: number, id)
		end
		if not partial and string.find(name, query, 1, true) == 1 then
			partial = id
		end
	end

	if partial then
		return self._K.Auth.targetUserArgument(self, tonumber(partial) :: number, partial)
	end

	return nil, "Invalid member"
end

local function nameSort(a, b)
	return string.lower(a[1][1]) < string.lower(b[1][1])
end

local typeMember = {
	validate = parseMember,
	parse = parseMember,
	suggestions = function(text: string, from: number, definition)
		local names = {}
		local fromString = tostring(from)
		local rank = _K.Auth.getRank(from)
		local lowerRank = definition.lowerRank
			or (definition.shouldRequest and _K.Data.settings.commandRequests ~= false)

		for id, member in _K.Data.members do
			local memberRank = _K.Auth.getRank(id)
			if id == fromString then
				continue
			end
			if from == _K.creatorId or not lowerRank or (fromString == id) or rank > memberRank then
				table.insert(names, { { member.name, id }, `{member.name} [{id}]` })
			end
		end

		table.sort(names, nameSort)

		local fromMember = _K.Data.members[fromString]
		if fromMember and not definition.ignoreSelf then
			table.insert(names, 1, { { "me", fromMember.name, from }, `me [{fromMember.name}] [{from}]` })
		end

		return names
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
