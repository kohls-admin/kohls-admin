local String = require("./String")

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
	local results, levenshtein, partial = {}, {}, {}
	local textLower = string.lower(text)

	for index, name in names do
		local suggestion, display, key, query = name, nil
		if type(name) == "table" then
			suggestion, display, key, query = unpack(name)
		end

		local suggestionLower = string.lower(suggestion)
		local queryLower = string.lower(query or suggestion)
		local value = instances and (instances[key] or instances[index] or instances[name]) or key or name
		if suggestionLower == textLower or queryLower == textLower then
			table.insert(results, 1, { suggestion, display, value, query })
		else
			local found = string.find(queryLower, textLower, 1, true)
			if found == 1 then
				table.insert(results, { suggestion, display, value, query })
			elseif found then -- partial matches are added after everything else
				table.insert(partial, { suggestion, display, value, query })
			else
				table.insert(levenshtein, { queryLower, suggestion, display, value, query })
			end
		end
	end

	if #levenshtein > 0 then
		local suggestionData = nil
		local lowestDistance = math.huge
		for _, data in levenshtein do
			local distance = String.levenshteinDistance(data[1], textLower)
			if distance < lowestDistance then
				lowestDistance = distance
				suggestionData = data
			end
			if distance == 0 then
				break
			end
		end
		if suggestionData then
			table.insert(partial, { suggestionData[2], suggestionData[3], suggestionData[4], suggestionData[5] })
		end
	end

	if #partial > 0 then
		table.move(partial, 1, #partial, #results + 1, results)
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
