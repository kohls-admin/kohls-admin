local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")

local Data = require(script.Parent.Parent:WaitForChild("Defaults"))
local Util = require(script.Parent.Parent.Parent:WaitForChild("Util"))

local function deserializeItem(data: string)
	local result = {}
	for i in string.gmatch(data, "%S+") do
		local c, d = string.match(i, "(.+):(.+)")
		local key, value = tonumber(c), tonumber(d)
		if key and value then
			result[key] = value
		end
	end
	return result
end

local function fillName(userId, data)
	data[1] = Util.getUserInfo(userId).Username
end

local defaultRoles = { "vip", "mod", "admin", "superadmin", "creator" }
local function getRoleFromRank(rank)
	rank = tonumber(rank)
	if rank then
		rank = math.clamp(math.abs(rank), 1, 5)
		local defaultRoleId = defaultRoles[rank]
		if Data.roles[defaultRoleId] then
			return defaultRoleId
		end
		for roleId, role in Data.roles do
			if role._rank == rank then
				return roleId
			end
		end
	end
	return
end

local function migrateKAI()
	local ok, GlobalDataStore = pcall(function()
		return DataStoreService:GetGlobalDataStore()
	end)
	if not ok then
		return
	end

	local okGet, dataKAI = Util.Retry(function()
		return GlobalDataStore:GetAsync("KSave")
	end)
	if okGet and type(dataKAI) == "table" then
		local admins, bans, settings = table.unpack(dataKAI, 1, 3)
		local newBans, main = {}, { {}, {} }

		if bans then
			for userId, duration in deserializeItem(bans) do
				if not (userId or duration) or duration >= 0 then
					continue
				end
				local ban = {
					nil,
					nil,
					if duration == -1 then -1 else math.abs(duration),
					nil,
				}
				newBans[tostring(userId)] = ban
				task.spawn(fillName, userId, ban)
			end
		end

		if admins then
			for userId, power in deserializeItem(admins) do
				if not (userId or power) or power >= 0 then
					continue
				end
				local role = getRoleFromRank(math.clamp(math.abs(power), 1, 5))
				if role then
					local member = { nil, { role } }
					main[1][tostring(userId)] = member
					task.spawn(fillName, userId, member)
				end
			end
		end

		if type(settings) == "string" then
			local okDecode, decoded = pcall(HttpService.JSONDecode, HttpService, settings)
			settings = if okDecode and type(decoded) == "table" then decoded else nil
		end
		if type(settings) == "table" then
			local freeAdmin = tonumber(settings.FreeAdmin)
			if freeAdmin then
				local role = Data.rolesList[freeAdmin + 1]
				if role then
					main[2].freeAdmin = { role._key }
				end
			end
			if settings.Prefix then
				main[2].prefix = { settings.Prefix }
			end
		end

		return newBans, main
	end

	return
end

return migrateKAI
