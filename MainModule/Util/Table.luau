export type Dict = { [any]: any }
export type List = { any }

local Table = {}

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

function Table.fastRemove(t: { any }, index: number, indexEnd: number?)
	for i = index, indexEnd or index do
		t[i] = nil
	end
	local shift = 1
	for i, v in t do
		t[shift], t[i] = v, nil
		shift += 1
	end
end

return Table
