local Retry = require(script.Parent:WaitForChild("Retry"))

local function pagesToTable(pages)
	local items = {}
	while true do
		table.insert(items, pages:GetCurrentPage())
		if pages.IsFinished then
			break
		end
		local ok, err = Retry(pages.AdvanceToNextPageAsync, 5, 2, pages)
		if not ok then
			error(err)
		end
	end
	return items
end

local function iterPageItems(pages)
	local contents = pagesToTable(pages)
	local pageNum = 1
	local lastPageNum = #contents

	return coroutine.wrap(function()
		while pageNum <= lastPageNum do
			for _, item in ipairs(contents[pageNum]) do
				coroutine.yield(item, pageNum)
			end
			pageNum += 1
		end
	end)
end

return iterPageItems
