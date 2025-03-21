export type Dict = { [any]: any }
export type List = { any }

local Table = {}

function Table.concat(array: List, delimiter: string): string
	local strings = {}
	for _, item in array do
		table.insert(strings, tostring(item))
	end
	return table.concat(strings, delimiter)
end

function Table.toHashMap(array: List): Dict
	local map = {}
	for _, key in array do
		map[key] = true
	end
	return map
end

function Table.merge(to: Dict, from: Dict): Dict
	for key, value in from do
		to[key] = value
	end
	return to
end

function Table.deepMerge(to: Dict, from: Dict): Dict
	for key, value in from do
		if to[key] and type(value) == "table" then
			Table.deepMerge(to[key], value)
		else
			to[key] = value
		end
	end
	return to
end

function Table.deepCopy(original: Dict): Dict
	local copy = table.clone(original)
	for key, value in copy do
		if type(value) == "table" then
			copy[key] = Table.deepCopy(value)
		end
	end
	return copy
end

function Table.settle(t: { any })
	local shift = 1
	for i, v in t do
		t[shift], t[i] = v, nil
		shift += 1
	end
	return t
end

function Table.fastRemove(t: { any }, index: number, indexEnd: number?)
	for i = index, indexEnd or index do
		t[i] = nil
	end
	return Table.settle(t)
end

function Table.shuffle(list: { any })
	for i = #list, 2, -1 do
		local j = math.random(i)
		list[i], list[j] = list[j], list[i]
	end
	return list
end

return Table
