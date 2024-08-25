local _K

local typeBan = {
	validate = function(input: string): (boolean, string?)
		local query = string.lower(input)
		for userId, ban in _K.Data.bans do
			local userInfo = _K.Util.getUserInfo(userId)
			if
				string.find(string.lower(userInfo.Username), query) == 1
				or string.find(string.lower(userId), query) == 1
			then
				return true
			end
		end
		return false, "Invalid ban."
	end,
	parse = function(input: string): string
		local query = string.lower(input)
		for userId, ban in _K.Data.bans do
			local userInfo = _K.Util.getUserInfo(userId)
			if
				string.find(string.lower(userInfo.Username), query) == 1
				or string.find(string.lower(userId), query) == 1
			then
				return userId
			end
		end
		error("Invalid ban value.")
	end,
	suggestions = function(text)
		local names = {}
		for userId, bans in _K.Data.bans do
			local userInfo = _K.Util.getUserInfo(userId)
			local name = userInfo.Username
			names[userId] = if string.find(name, " ") then `"{name}"` else name
		end
		return _K.Util.Suggest.query(text, names, _K.Data.bans)
	end,
}

local typeBans = {
	listable = true,
}

return function(context)
	_K = context
	_K.Registry.registerType("ban", typeBan)
	_K.Registry.registerType("bans", typeBans, typeBan)
end
