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
	local results, partial = {}, {}
	local textLower = string.lower(text)

	for index, name in names do
		local nameQuery, nameDisplay, key = name, nil, index
		if type(name) == "table" then
			nameQuery, nameDisplay, key = unpack(name)
		end

		local nameLower = string.lower(nameQuery)
		local value = instances and (instances[key] or instances[name]) or name
		-- Continue on checking for non-exact matches...
		-- exact match goes to the start
		if nameLower == textLower then
			table.insert(results, 1, { nameQuery, value, nameDisplay })
		else
			local found = string.find(nameLower, textLower, 1, true)
			-- start matches are normal priority
			if found == 1 then
				table.insert(results, { nameQuery, value, nameDisplay })
			elseif found then -- partial matches are added after everything else
				table.insert(partial, { nameQuery, value, nameDisplay })
			end
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
