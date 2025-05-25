local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")

local Data = require(script.Parent.Parent.Defaults)
local Util = require(script.Parent.Parent.Parent.Util)

local function deserializeItem(data: string)
	local result = {}
	for i in string.gmatch(data, "%S+") do
		local c, d = string.match(i, "(.+):(.+)")
		result[tonumber(c)] = tonumber(d)
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

	local dataKAI = GlobalDataStore:GetAsync("KSave")
	if type(dataKAI) == "table" then
		local admins, bans, settings = unpack(dataKAI)
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

		if settings then
			for key, value in HttpService:JSONDecode(settings) do
				key = string.lower(key)
				for setting in Data.settings do
					if string.lower(setting) == key then
						main[2][key] = value
						break
					end
				end
			end
		end

		return newBans, main
	end

	return
end

return migrateKAI
