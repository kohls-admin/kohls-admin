local Http = game:GetService("HttpService")

local LIMIT = 32 * 1000 - 32 -- 32 KB

local function getNewData(chunk, size, key, action)
	local newSize = size

	if not chunk[key] then
		chunk[key] = {}
		newSize += #Http:JSONEncode(key) + 4 -- ,"key":{}
	end

	local newInfo = chunk[key]
	if not newInfo[action] then
		newSize += #action + (if next(newInfo) ~= nil then 6 else 5) -- "action":{} or ,"action":{}
		newInfo[action] = {}
	end

	local newData = newInfo[action]
	return newData, newSize
end

return function(changes)
	local changesSize = #Http:JSONEncode(changes)

	if changesSize <= LIMIT then
		return { changes }
	end

	local currentChunk, currentChunkSize = {}, 2 -- Start with an empty chunk (2 for {})
	local chunks = { currentChunk }

	for key, info in changes do
		for action, data in info do
			-- insert (log entries) and unset (removed keys) are arrays: re-index them from 1 in every chunk,
			-- a copied original index leaves later chunks sparse and they stop encoding as JSON arrays
			local isArray = action == "insert" or action == "unset"
			for k, v in data do
				local prefix = if isArray then 1 else #Http:JSONEncode(tostring(k)) + 2 -- , or ,"k":
				local size = #Http:JSONEncode(v) + prefix
				local wrapper = (if not currentChunk[key] then #Http:JSONEncode(key) + 4 else 0)
					+ (
						if not (currentChunk[key] and currentChunk[key][action])
							then #action + (if currentChunk[key] and next(currentChunk[key]) ~= nil then 6 else 5)
							else 0
					)

				if currentChunkSize + wrapper + size >= LIMIT and currentChunkSize > 2 then
					currentChunk, currentChunkSize = {}, 2
					table.insert(chunks, currentChunk)
				end

				local newData
				newData, currentChunkSize = getNewData(currentChunk, currentChunkSize, key, action)

				if isArray then
					table.insert(newData, v)
				else
					newData[k] = v
				end
				currentChunkSize += size
			end
		end
	end

	return chunks
end
