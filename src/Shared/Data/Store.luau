local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local Util = require(script.Parent.Parent:WaitForChild("Util"))

local Store = {
	dataStore = nil :: DataStore?,
	closing = false,
	minBudgetReserve = 1,
}

function Store.getBudget(requestType: Enum.DataStoreRequestType)
	return DataStoreService:GetRequestBudgetForRequestType(requestType)
end

function Store.waitForBudget(requestType: Enum.DataStoreRequestType, reserve: number?)
	if Store.closing then
		return
	end
	local minBudget = reserve or Store.minBudgetReserve
	local attempts = 0
	while not Store.closing and attempts < 5 do
		local ok, budget = pcall(Store.getBudget, requestType)
		if not ok or type(budget) ~= "number" or budget >= minBudget then
			break
		end
		attempts += 1
		task.wait(1)
	end
end

local function jitterBase(): number
	return 1.5 + math.random() * 0.5
end

function Store.getAsync(key: string, options: DataStoreGetOptions?): (boolean, any, any)
	Store.waitForBudget(Enum.DataStoreRequestType.GetAsync)
	return Util.Retry(function()
		return Store.dataStore:GetAsync(key, options)
	end, 5, jitterBase())
end

function Store.setAsync(key: string, value: any, userIds: { number }?, options: DataStoreSetOptions?): (boolean, any)
	Store.waitForBudget(Enum.DataStoreRequestType.SetIncrementAsync)
	return Util.Retry(function()
		return Store.dataStore:SetAsync(key, value, userIds, options)
	end, 5, jitterBase())
end

function Store.updateAsync(key: string, func: (value: any, keyInfo: DataStoreKeyInfo) -> any): (boolean, any, any)
	Store.waitForBudget(Enum.DataStoreRequestType.UpdateAsync)
	return Util.Retry(function()
		return Store.dataStore:UpdateAsync(key, func)
	end, 5, jitterBase())
end

function Store.removeAsync(key: string): (boolean, any, any)
	Store.waitForBudget(Enum.DataStoreRequestType.SetIncrementAsync)
	return Util.Retry(function()
		return Store.dataStore:RemoveAsync(key)
	end, 5, jitterBase())
end

local canSave = true
local loadedName: any = nil
local loadedScope: any = nil

function Store.loadStore(name, scope): (boolean, DataStore | string)
	if Store.dataStore and loadedName == name and loadedScope == scope then
		return canSave, Store.dataStore
	end
	canSave = true

	print(`[Kohl's Admin] Initializing DataStore {name}...`)
	local ok, result = pcall(DataStoreService.GetDataStore, DataStoreService, name, scope)
	if not ok then
		if RunService:IsStudio() and type(result) == "string" then
			if string.find(result :: string, "publish", 1, true) then
				result = "You must publish this game to Roblox for full features."
				canSave = false
				warn(result)
			end
		end
		if canSave then
			ok, result = Util.Retry(function()
				return DataStoreService:GetDataStore(name, scope)
			end)
		end
	end

	if canSave and not ok then
		canSave = false
		warn(result)
	end

	if canSave and RunService:IsStudio() then
		local success, err = pcall(result.GetAsync, result, "__TEST")
		if not success then
			if type(err) == "string" and string.find(err, "Studio access", 1, true) then
				result = "Enable Studio access to API services in Experience Settings for full features."
				canSave = false
				warn(result)
			end
		end
	end

	if canSave then
		Store.dataStore = result
		loadedName = name
		loadedScope = scope
	else
		Store.dataStore = nil
		loadedName = nil
		loadedScope = nil
	end

	return canSave, result
end

return Store
