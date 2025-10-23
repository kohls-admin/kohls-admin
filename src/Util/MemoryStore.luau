local module = {}

function module.getItemsFromHashMap(hashMap: MemoryStoreHashMap): { [string]: any }
	local items = {}
	local pages = hashMap:ListItemsAsync(200)

	while true do
		for _, entry in pages:GetCurrentPage() do
			items[entry.key] = entry.value
		end
		if pages.IsFinished then
			break
		end
		pages:AdvanceToNextPageAsync()
	end

	return items
end

return module
