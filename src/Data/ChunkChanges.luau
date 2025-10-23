local Http = game:GetService("HttpService")

local LIMIT = 32 * 1024 - 32 -- 32 KB

local function getNewData(chunk, size, key, action)
	local newSize = size

	if not chunk[key] then
		chunk[key] = {}
		newSize += #key + 5 -- "key":{}
	end

	local newInfo = chunk[key]
	if not newInfo[action] then
		newInfo[action] = {}
		newSize += #action + 5 -- "action":{}
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
			if action == "insert" then -- array
				for _, v in data do
					local size = #Http:JSONEncode(v) + 1 -- ,value

					if currentChunkSize + size >= LIMIT then
						currentChunk, currentChunkSize = {}, 2
						table.insert(chunks, currentChunk)
					end

					local newData
					newData, currentChunkSize = getNewData(currentChunk, currentChunkSize, key, action)

					table.insert(newData, v)
					currentChunkSize += size
				end
			else -- dictionary
				for k, v in pairs(data) do
					local size = #Http:JSONEncode(v) + #k + 4 -- ,"k":value

					if currentChunkSize + size >= LIMIT then
						currentChunk, currentChunkSize = {}, 2
						table.insert(chunks, currentChunk)
					end

					local newData
					newData, currentChunkSize = getNewData(currentChunk, currentChunkSize, key, action)

					newData[k] = v
					currentChunkSize += size
				end
			end
		end
	end

	return chunks
end
