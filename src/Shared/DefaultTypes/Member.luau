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

local function parseAll(arg, self)
	local feedback = {}
	local members = {}
	for id, member in _K.Data.members do
		local message
		member, message = self._K.Auth.targetUserArgument(self, tonumber(id) :: number, id)
		if member then
			table.insert(members, member)
		elseif not table.find(feedback, message) then
			table.insert(feedback, message)
		end
	end

	if #members > 0 then
		return members
	end

	return nil, #feedback > 0 and table.concat(feedback, "\n") or "No targetable member found"
end

local typeAll = {
	listable = true,
	transform = string.lower,
	validate = function(v, self)
		local ok, feedback = parseAll(v, self)
		return ok, feedback or "Invalid member"
	end,
	suggestions = { { { "*", "all" }, "*  [all] (Everyone)" } },
	parse = parseAll,
}

local function nameSort(a, b)
	return string.lower(a[1][1]) < string.lower(b[1][1])
end

local typeMember = {
	validate = parseMember,
	parse = parseMember,
	prefixes = {
		["^%*$"] = "allMembers",
		["^all$"] = "allMembers",
	},
	suggestions = function(text: string, from: number, definition)
		local names = { { { "*", "all" }, "*  [all] (Everyone)" } }
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
	_K.Registry.registerType("allMembers", typeAll)
end
