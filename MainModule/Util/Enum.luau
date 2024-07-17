-- local Enum = require(path.to.module)
-- Enum.Letter = {"A", "B", "C"}
-- print(Enum.Letter.A)   ->  0
-- print(Enum.Letter[0])  ->  A

local meta = {
	__index = function(_, key: string)
		error(string.format("%s is not a valid EnumItem", key), 2)
	end,
	__newindex = function(_, key: string)
		error(string.format("Cannot write to index [%q]", key), 2)
	end,
}

return setmetatable({}, {
	__index = function(_, key: string)
		error(string.format("%s is not a valid Enum", key), 2)
	end,
	__newindex = function(self: { any }, key: string, items: { string })
		if type(items) ~= "table" then
			error(string.format("table expected got %s", type(items)), 2)
		end
		local result = {}
		for i = 1, #items do
			local v = items[i]
			result[i - 1] = v
			result[v] = i - 1
		end
		rawset(self, key :: any, setmetatable(result, meta))
	end,
})
