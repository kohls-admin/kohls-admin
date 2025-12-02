local _K

local function parse(input: string, self: any): (boolean, string?)
	local exact = _K.Data.reservedServers[input]
	if exact then
		return exact
	end
	local query, partial = string.lower(input)
	for reservedCode, data in _K.Data.reservedServers do
		local match = string.lower(reservedCode)
		if match == query then
			return data
		elseif string.find(match, query) then
			if not partial or #partial < #reservedCode then
				partial = reservedCode
			end
		end
	end
	return _K.Data.reservedServers[partial], "Invalid reserveCode"
end

local reservedType = {
	validate = parse,
	parse = parse,
	suggestions = function(text: string, from: number)
		local names = {}
		for reservedCode in _K.Data.reservedServers do
			table.insert(names, reservedCode)
		end
		table.sort(names)
		return names
	end,
}

return function(context)
	_K = context
	_K.Registry.registerType("reservedServer", reservedType)
	_K.Registry.registerType("reservedServers", { listable = true }, reservedType)
end
