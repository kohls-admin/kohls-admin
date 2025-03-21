local _K = nil

local typeMember = {
	validate = function(input: string, self: any): (boolean, string?)
		local query = string.lower(input)
		local fromString = tostring(self.command.from)
		local rank = _K.Auth.getRank(self.command.from)
		local lowerRank = self.definition.lowerRank or self.definition.shouldRequest

		for id, member in _K.Data.members do
			local memberRank = _K.Auth.getRank(id)
			local username = member.name or _K.Util.getUserInfo(id).Username
			if self.definition.ignoreSelf and id == fromString then
				continue
			end
			if
				(not lowerRank or (fromString == id) or rank > memberRank)
				and string.find(string.lower(username), query, 1, true) == 1
			then
				return true
			end
		end

		return false, "Invalid member."
	end,
	parse = function(input: string, self: any): string
		local query = string.lower(input)
		local fromString = tostring(self.command.from)
		local rank = _K.Auth.getRank(self.command.from)
		local lowerRank = self.definition.lowerRank or self.definition.shouldRequest

		for id, member in _K.Data.members do
			local memberRank = _K.Auth.getRank(id)
			local username = member.name or _K.Util.getUserInfo(id).Username
			if self.definition.ignoreSelf and id == fromString then
				continue
			end
			if
				(not lowerRank or (fromString == id) or rank > memberRank)
				and string.find(string.lower(username), query, 1, true) == 1
			then
				return id
			end
		end

		error("Invalid member value")
	end,
	suggestions = function(text: string, from: number, definition)
		local names = {}
		local fromString = tostring(from)
		local rank = _K.Auth.getRank(from)
		local lowerRank = definition.lowerRank or definition.shouldRequest

		for id, member in _K.Data.members do
			local memberRank = _K.Auth.getRank(id)
			local username = member.name or _K.Util.getUserInfo(id).Username
			if definition.ignoreSelf and id == fromString then
				continue
			end
			if not lowerRank or (fromString == id) or rank > memberRank then
				names[id] = username
			end
		end

		return _K.Util.Suggest.query(text, names, _K.Data.members)
	end,
	log = function(arg)
		return _K.Util.Table.concat(arg.parsedArgs, ",")
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
