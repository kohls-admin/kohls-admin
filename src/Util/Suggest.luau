--!optimize 2
--!native

local String = require("./String")
local Table = require("./Table")

local Suggest = {}

function Suggest.getNames(objects: any): { string }
	local names = {}
	local existing = {}
	for key, object in objects do
		local name = object.Name or object.name or tostring(object)
		if existing[name] then
			continue
		end
		existing[name] = true
		names[key] = name
	end
	return names, objects
end

function Suggest.query(text: string, names: { string | { string } }, instances: { any }?)
	local results, starts, contains, levenshtein = {}, {}, {}, {}
	local query = string.lower(text)

	for index, name in names do
		local suggestions, display, key = name, nil
		if type(name) == "table" then
			suggestions, display, key = unpack(name)
		end
		if type(suggestions) ~= "table" then
			suggestions = { suggestions }
		end
		local value = instances and (instances[key] or instances[index] or instances[name]) or key

		local matched = false
		for _, target in suggestions do
			if string.lower(target) == query then
				table.insert(results, 1, { target, display, value or target })
				matched = true
				break
			end
		end
		if not matched then
			local length, suggestion, partial = 0, nil, nil
			for _, target in suggestions do
				local startIndex, endIndex = string.find(string.lower(target), query, 1, true)
				if startIndex then
					if startIndex == 1 and endIndex > length then -- starts
						length, suggestion = endIndex, target
					elseif length == 0 and not partial then -- contains
						partial = target
					end
				end
			end
			local target = suggestion or partial
			if target then
				table.insert(if suggestion then starts else contains, { target, display, value or target })
				matched = true
			end
		end
		if not matched then
			for _, target in suggestions do
				table.insert(levenshtein, { target, display, value or target })
			end
		end
	end

	if #levenshtein > 0 then
		local lowestDistance, suggestionData = math.huge, nil
		for _, data in levenshtein do
			local distance = String.levenshteinDistance(string.lower(data[1]), query)
			if distance < lowestDistance then
				lowestDistance = distance
				suggestionData = data
			end
		end
		if suggestionData then
			table.insert(contains, suggestionData)
		end
	end

	if #starts > 0 then
		Table.mergeList(results, starts)
	end
	if #contains > 0 then
		Table.mergeList(results, contains)
	end

	return results
end

function Suggest.new(setOrContainer: any): ({ string }, { any })
	local names
	local instances = {}
	local setType = typeof(setOrContainer)

	if setType == "Enum" then
		setOrContainer = setOrContainer:GetEnumItems()
		setType = typeof(setOrContainer)
	end

	if setType == "Instance" then
		names, instances = Suggest.getNames(setOrContainer:GetChildren())
	elseif setType == "table" then
		local setItem = setOrContainer[1] or next(setOrContainer)
		local setItemType = typeof(setItem)
		if
			setItemType == "Instance"
			or setItemType == "EnumItem"
			or (
				setItemType == "table"
				and setItem
				and (type(setItem.Name) == "string" or type(setItem.name) == "string")
			)
		then
			names, instances = Suggest.getNames(setOrContainer)
		elseif setItemType == "string" then
			names = setOrContainer
		elseif setItem ~= nil then
			error("only accepts tables of instances or strings.")
		else
			names = {}
		end
	else
		error("only accepts a table, Enum, or Instance.")
	end

	return names, instances
end

return Suggest
