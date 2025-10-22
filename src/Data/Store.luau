local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local Util = require(script.Parent.Parent.Util)

local Store = {
	dataStore = nil :: DataStore?,
}

function Store.getBudget(requestType: Enum.DataStoreRequestType)
	return DataStoreService:GetRequestBudgetForRequestType(requestType)
end

function Store.getAsync(key: string, options: DataStoreSetOptions?): (boolean, any)
	return Util.Retry(function()
		return Store.dataStore:GetAsync(key, options)
	end, math.huge)
end

function Store.setAsync(key: string, value: any, userIds: { number }?, options: DataStoreSetOptions?): (boolean, any)
	return Util.Retry(function()
		return Store.dataStore:SetAsync(key, value, userIds, options)
	end, math.huge)
end

function Store.updateAsync(key: string, func: (value: any, keyInfo: DataStoreKeyInfo) -> any): (boolean, any)
	return Util.Retry(function()
		return Store.dataStore:UpdateAsync(key, func)
	end, math.huge)
end

function Store.removeAsync(key: string): (boolean, any)
	return Util.Retry(function()
		return Store.dataStore:RemoveAsync(key)
	end, math.huge)
end

function Store.loadStore(name, scope)
	if Store.dataStore then
		return Store.dataStore
	end

	print(`[Kohl's Admin] Initializing DataStore {name}...`)
	local ok, result = pcall(DataStoreService.GetDataStore, DataStoreService, name, scope)
	if not ok then
		if RunService:IsStudio() and type(result) == "string" then
			if string.find(result, "publish", 1, true) then
				error("You must publish this game to Roblox.")
			end
		end
		ok, result = Util.Retry(function()
			return DataStoreService:GetDataStore(name, scope)
		end)
	end

	if not ok then
		error(result)
	end

	local success, err = pcall(result.GetAsync, result, "__TEST")
	if not success then
		if string.find(err, "Studio access", 1, true) then
			error("Enable Studio access to API services in Game Settings.")
		end
	end

	Store.dataStore = result

	return result
end

return Store
