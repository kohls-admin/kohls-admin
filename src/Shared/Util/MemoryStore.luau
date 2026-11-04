local HttpService = game:GetService("HttpService")

local iterPageItems = require(script.Parent:WaitForChild("iterPageItems"))
local Retry = require(script.Parent:WaitForChild("Retry"))
local String = require(script.Parent:WaitForChild("String"))
local Tasks = require(script.Parent:WaitForChild("Tasks"))

local SERVER_SEED = if #game.JobId > 0 then game.JobId else HttpService:GenerateGUID(false)
local SERVER_SEED_HASH = String.hash(SERVER_SEED)

local module = {}

local function shardStartAndStep(key: string, shardCount: number, seed: string?): (number, number)
	local seedHash = if seed then String.hash(seed) else SERVER_SEED_HASH
	local h1 = String.hash(key, seedHash)
	local start = h1 % shardCount
	local h2 = String.hash(seed or SERVER_SEED, bit32.bxor(h1, 0x9E3779B9))
	local step = (h2 % (shardCount - 1)) + 1
	for _ = 1, shardCount do
		local a, b = step, shardCount
		while b ~= 0 do
			a, b = b, a % b
		end
		if a == 1 then
			break
		end
		step = (step % (shardCount - 1)) + 1
	end
	return start, step
end

function module.shardIndex(key: string, shardCount: number, offset: number?, seed: string?): number
	if shardCount <= 1 then
		return 1
	end
	local probeOffset = offset or 0
	if probeOffset == 0 then
		local seedHash = if seed then String.hash(seed) else SERVER_SEED_HASH
		return (String.hash(key, seedHash) % shardCount) + 1
	end
	local start, step = shardStartAndStep(key, shardCount, seed)
	return (start + probeOffset * step) % shardCount + 1
end

function module.getItemsFromHashMap(hashMap: MemoryStoreHashMap): { [string]: any }
	local items = {}
	local pages = hashMap:ListItemsAsync(200)

	for entry in iterPageItems(pages) do
		items[entry.key] = entry.value
	end

	return items
end

function module.getSharded(
	hashMap: MemoryStoreHashMap,
	keyPrefix: string,
	shardCount: number,
	maxProbes: number?,
	attempts: number?
): (boolean, any)
	if shardCount <= 0 then
		return false, nil
	end
	local probes = math.min(shardCount, maxProbes or shardCount)
	local anyOk = false
	for offset = 0, probes - 1 do
		local shard = module.shardIndex(keyPrefix, shardCount, offset)
		local ok, value = Retry(hashMap.GetAsync, attempts or 1, 2, hashMap, `{keyPrefix}_{shard}`)
		if ok then
			if value ~= nil then
				return true, value
			end
			anyOk = true
		end
	end
	return anyOk, nil
end

function module.setSharded(
	hashMap: MemoryStoreHashMap,
	keyPrefix: string,
	value: any,
	expiration: number,
	shardCount: number,
	attempts: number?
): boolean
	local anySuccess = false
	local tasks = Tasks.new()
	for shard = 1, shardCount do
		tasks:add(function()
			local ok = Retry(hashMap.SetAsync, attempts or 1, 2, hashMap, `{keyPrefix}_{shard}`, value, expiration)
			if ok then
				anySuccess = true
			end
		end)
	end
	tasks:wait()
	return anySuccess
end

return module
