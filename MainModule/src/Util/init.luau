type Dict = { [any]: any }
type List = { any }

local module = {}

module.Services = setmetatable({}, {
	__index = function(self, key)
		local service = game:GetService(key)
		self[key] = service
		return service
	end,
})

function module.toHashMap(array: List): Dict
	local map = {}
	for _, key in array do
		map[key] = true
	end
	return map
end

function module.mergeTable(to: Dict, from: Dict): Dict
	for key, value in from do
		to[key] = value
	end
	return to
end

function module.deepCopy(original: Dict): Dict
	local copy = {}
	for key, value in original do
		if type(value) == "table" then
			value = module.deepCopy(value)
		end
		copy[key] = value
	end
	return copy
end

function module.trimStart(s: string): string
	return if string.find(s, "^%s*$") then "" else (string.match(s, "^%s*(.*)") or "")
end

function module.trimEnd(s: string): string
	return if string.find(s, "^%s*$") then "" else (string.match(s, "(.-)%s*$") or "")
end

function module.trim(s: string): string
	return if string.find(s, "^%s*$") then "" else (string.match(s, "^%s*(.*%S)") or "")
end

function module.escapeRichText(s: string): string
	s = string.gsub(s, "&", "&amp;") -- first because substitutes contain it
	s = string.gsub(s, "<", "&lt;")
	s = string.gsub(s, ">", "&gt;")
	s = string.gsub(s, '"', "&quot;")
	s = string.gsub(s, "'", "&apos;")
	return s
end

function module.getNames(objects: any): { string }
	local names = {}
	for key, object in objects do
		names[key] = object.Name or object.name or tostring(object)
	end
	return names, objects
end

function module.querySuggestions(text: string, names: { string }, instances: { any })
	local results = {}
	local textLower = string.lower(text)

	for key, name in names do
		local value = instances and instances[key] or name
		-- Continue on checking for non-exact matches...
		-- exact match goes to the start
		if name == textLower then
			table.insert(results, 1, { name, value })
		else
			local found = string.find(name, textLower, 1, true)
			-- start matches are normal priority
			if found == 1 then
				table.insert(results, { name, value })
			end
		end
	end

	return results
end

function module.newSuggestions(setOrContainer: any): ({ string }, { any })
	local names
	local instances = {}
	local setType = typeof(setOrContainer)

	if setType == "Enum" then
		setOrContainer = setOrContainer:GetEnumItems()
		setType = typeof(setOrContainer)
	end

	if setType == "Instance" then
		names, instances = module.getNames(setOrContainer:GetChildren())
	elseif setType == "table" then
		local setItemType = typeof(setOrContainer[1])
		if
			setItemType == "Instance"
			or setItemType == "EnumItem"
			or (
				setItemType == "table"
				and (type(setOrContainer[1].Name) == "string" or type(setOrContainer[1].name) == "string")
			)
		then
			names, instances = module.getNames(setOrContainer)
		elseif setItemType == "string" then
			names = setOrContainer
		elseif setOrContainer[1] ~= nil then
			error("only accepts tables of instances or strings.")
		else
			names = {}
		end
	else
		error("only accepts a table, Enum, or Instance.")
	end

	-- cache lowered names
	for i, name in names do
		names[i] = string.lower(name)
	end
	return names, instances
end

for _, child in script:GetChildren() do
	if child.ClassName == "ModuleScript" then
		module[child.Name] = require(child)
	end
end

return module
