local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local Util = require(script.Parent.Parent.Util)

type Dict = { [any]: any }

local RETRY_COUNT = 5
local RETRY_DELAY = 5
local RETRY_BACKOFF = 1

local Store = {
	REMOVE = table.freeze({ type = "Remove" }),
	dataStore = nil,
}

function Store.getAsync(key: string, options: DataStoreSetOptions?): (boolean, any)
	return Util.Retry(function()
		return Store.dataStore:GetAsync(key, options)
	end, RETRY_COUNT, RETRY_DELAY, RETRY_BACKOFF)
end

function Store.setAsync(key: string, value: any, userIds: { number }?, options: DataStoreSetOptions?): (boolean, any)
	return Util.Retry(function()
		return Store.dataStore:SetAsync(key, value, userIds, options)
	end, RETRY_COUNT, RETRY_DELAY, RETRY_BACKOFF)
end

function Store.updateAsync(key: string, func: (value: any, keyInfo: DataStoreKeyInfo) -> any): (boolean, any)
	return Util.Retry(function()
		return Store.dataStore:UpdateAsync(key, func)
	end, RETRY_COUNT, RETRY_DELAY, RETRY_BACKOFF)
end

function Store.removeAsync(key: string): (boolean, any)
	return Util.Retry(function()
		return Store.dataStore:RemoveAsync(key)
	end, RETRY_COUNT, RETRY_DELAY, RETRY_BACKOFF)
end

function Store.mergeRemove(to: Dict, from: Dict): Dict
	for key, value in from do
		to[key] = if value == Store.REMOVE then nil else value
	end
	return to
end

function Store.filterRemove(source: Dict): Dict
	for key, value in source do
		if value == Store.REMOVE then
			source[key] = nil
		elseif type(value) == "table" then
			Store.filterRemove(value)
		end
	end
	return source
end

function Store.loadStore(name)
	if Store.dataStore then
		return Store.dataStore
	end

	print(`[Kohl's Admin] Initializing DataStore {name}...`)
	local ok, store = pcall(DataStoreService.GetDataStore, DataStoreService, name, "_K_Beta.1")
	if not ok then
		if RunService:IsStudio() and type(store) == "string" then
			if string.find(store, "publish", 1, true) then
				warn("Data failed to load, enable Studio access to API services in Game Settings.")
				return
			end
			if string.find(store, "502", 1, true) then
				warn("Data failed to load, enable Studio access to API services in Game Settings.")
				return
			end
		end
		ok, store = Util.Retry(function()
			return DataStoreService:GetDataStore(name, "Kohl's Admin Test")
		end, RETRY_COUNT, 1, 1)
	end

	if not ok then
		error(store)
	end

	Store.dataStore = store

	return store
end

return Store
