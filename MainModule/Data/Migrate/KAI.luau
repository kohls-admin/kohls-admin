local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")

local Data = require(script.Parent.Parent.Defaults)

local function deserializeItem(data: string)
	local result = {}
	for i in string.gmatch(data, "%S+") do
		local c, d = string.match(i, "(.+):(.+)")
		result[tonumber(c)] = tonumber(d)
	end
	return result
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
				newBans[tostring(userId)] = {
					nil,
					nil,
					if duration == -1 then -1 else math.abs(duration),
					nil,
				}
			end
		end

		if admins then
			for userId, power in deserializeItem(admins) do
				if not (userId or power) or power >= 0 then
					continue
				end
				power = math.min(math.abs(power), 5)
				for role, roleData in Data.roles do
					if roleData._rank == power then
						main[1][tostring(userId)] = {
							nil,
							{ role },
						}
						break
					end
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
