local _K = nil

local typeMember = {
	validate = function(input: string, self: any): (boolean, string?)
		local query = string.lower(input)
		local rank = _K.Auth.getRank(self.command.from)
		for id, member in _K.Data.members do
			local memberRank = _K.Auth.getRank(id)
			local userInfo = _K.Util.getUserInfo(id)
			if
				(not self.definition.lowerRank or rank > memberRank)
				and string.find(string.lower(userInfo.Username), query) == 1
			then
				return true
			end
		end
		return false, "Invalid member."
	end,
	parse = function(input: string, self: any): string
		local query = string.lower(input)
		local rank = _K.Auth.getRank(self.command.from)
		for id, member in _K.Data.members do
			local memberRank = _K.Auth.getRank(id)
			local userInfo = _K.Util.getUserInfo(id)
			if
				(not self.definition.lowerRank or rank > memberRank)
				and string.find(string.lower(userInfo.Username), query) == 1
			then
				return id
			end
		end
		error("Invalid member value")
	end,
	suggestions = function(text: string, from: number, definition)
		local names = {}
		local rank = _K.Auth.getRank(from)
		for id, member in _K.Data.members do
			local memberRank = _K.Auth.getRank(id)
			local userInfo = _K.Util.getUserInfo(id)
			if not definition.lowerRank or rank > memberRank then
				names[id] = if userInfo.DisplayName ~= userInfo.Username
					then `{userInfo.Username} ({userInfo.DisplayName})`
					else userInfo.Username
			end
		end
		return _K.Util.querySuggestions(text, names, _K.Data.members)
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
