type Dict = { [any]: any }
type List = { any }

local Logger = require(script.Logger)

--- @class Util
local Util = {
	Logger = Logger,
	ReadableTime = require(script.ReadableTime),
	Rollout = require(script.Rollout),
	SignalFast = require(script.SignalFast),
	SignalGood = require(script.SignalGood),
}

export type Log = Logger.Log
export type LogType = Logger.LogType
export type Logger = Logger.Logger

Util.Services = setmetatable({}, {
	__index = function(self, key: string)
		local service = game:GetService(key)
		self[key] = service
		return service
	end,
})

local userInfoCache =
	{} :: { [number]: { Id: number, Username: string, DisplayName: string, HasVerifiedBadge: boolean } }

function Util.getUserInfo(userId: number)
	if userInfoCache[userId] then
		return userInfoCache[userId]
	end

	userId = tonumber(userId) :: number

	local player = Util.Services.Players:GetPlayerByUserId(userId)
	if player then
		userInfoCache[userId] = {
			Id = userId,
			Username = player.Name,
			DisplayName = player.DisplayName,
			HasVerifiedBadge = player.HasVerifiedBadge,
		}
		return userInfoCache[userId]
	end

	local ok, result =
		pcall(Util.Services.UserService.GetUserInfosByUserIdsAsync, Util.Services.UserService, { userId })
	if ok and result and result[1] then
		userInfoCache[userId] = result[1]
		return result[1]
	end

	return { Id = userId, Username = "Unknown", DisplayName = "Unknown", HasVerifiedBadge = false }
end

function Util.toHashMap(array: List): Dict
	local map = {}
	for _, key in array do
		map[key] = true
	end
	return map
end

function Util.mergeTable(to: Dict, from: Dict): Dict
	for key, value in from do
		to[key] = value
	end
	return to
end

function Util.deepCopy(original: Dict): Dict
	local copy = table.clone(original)
	for key, value in copy do
		if type(value) == "table" then
			copy[key] = Util.deepCopy(value)
		end
	end
	return copy
end

function Util.fastRemove(t: { any }, index: number, indexEnd: number?)
	for i = index, indexEnd or index do
		t[i] = nil
	end
	local shift = 1
	for i, v in t do
		t[shift], t[i] = v, nil
		shift += 1
	end
end

function Util.trimStart(s: string): string
	return if string.find(s, "^%s*$") then "" else (string.match(s, "^%s*(.*)") or "")
end

function Util.trimEnd(s: string): string
	return if string.find(s, "^%s*$") then "" else (string.match(s, "(.-)%s*$") or "")
end

function Util.trim(s: string): string
	return if string.find(s, "^%s*$") then "" else (string.match(s, "^%s*(.*%S)") or "")
end

function Util.escapeRichText(s: string): string
	s = string.gsub(s, "&", "&amp;") -- first because substitutes contain it
	s = string.gsub(s, "<", "&lt;")
	s = string.gsub(s, ">", "&gt;")
	s = string.gsub(s, '"', "&quot;")
	s = string.gsub(s, "'", "&apos;")
	return s
end

function Util.debounce(delay: number, func: (...any) -> ...any)
	local thread
	return function(...)
		if thread then
			task.cancel(thread)
		end
		thread = task.delay(delay, func, ...)
	end
end

function Util.throttle(delay: number, func: (...any) -> ...any)
	local throttled
	local function reset()
		throttled = nil
	end
	return function(...)
		if throttled then
			return
		end
		throttled = true
		task.delay(delay, reset)
		func(...)
	end
end

do
	local budget, expireTime = 1 / 120, 0

	-- Call at start of process to prevent unnecessarily waiting.
	function Util.deferTimerReset()
		expireTime = tick() + budget
	end

	function Util.deferWait()
		if tick() >= expireTime then
			task.wait()
			Util.deferTimerReset()
		end
	end
end

function Util.getNames(objects: any): { string }
	local names = {}
	for key, object in objects do
		names[key] = object.Name or object.name or tostring(object)
	end
	return names, objects
end

function Util.stripQuotes(text: string): string
	return string.gsub(text, '["`]', "")
end

function Util.querySuggestions(text: string, names: { string }, instances: { any }?)
	local results = {}
	local textLower = string.lower(text)

	for key, name in names do
		local nameLower = string.lower(name)
		local value = instances and instances[key] or name
		-- Continue on checking for non-exact matches...
		-- exact match goes to the start
		if nameLower == textLower then
			table.insert(results, 1, { name, value })
		else
			local found = string.find(nameLower, textLower, 1, true)
			-- start matches are normal priority
			if found == 1 then
				table.insert(results, { name, value })
			end
		end
	end

	return results
end

function Util.newSuggestions(setOrContainer: any): ({ string }, { any })
	local names
	local instances = {}
	local setType = typeof(setOrContainer)

	if setType == "Enum" then
		setOrContainer = setOrContainer:GetEnumItems()
		setType = typeof(setOrContainer)
	end

	if setType == "Instance" then
		names, instances = Util.getNames(setOrContainer:GetChildren())
	elseif setType == "table" then
		local setItemType = typeof(setOrContainer[1])
		if
			setItemType == "Instance"
			or setItemType == "EnumItem"
			or (
				setItemType == "table"
				and (type(setOrContainer[1].Name) == "string" or type(setOrContainer[1].name) == "string")
			)
		then
			names, instances = Util.getNames(setOrContainer)
		elseif setItemType == "string" then
			names = setOrContainer
		elseif setOrContainer[1] ~= nil then
			error("only accepts tables of instances or strings.")
		else
			names = {}
		end
	else
		error("only accepts a table, Enum, or Instance.")
	end

	-- cache lowered names
	for i, name in names do
		names[i] = string.lower(name)
	end
	return names, instances
end

function Util.makeEnumType(typeName: string, enumItems: { EnumItem | string })
	local suggestions = Util.newSuggestions(enumItems)
	return {
		validate = function(text)
			return Util.querySuggestions(text, suggestions)[1] ~= nil, `Invalid {typeName}`
		end,
		parse = function(text)
			return Util.querySuggestions(text, suggestions, enumItems)[1][2]
		end,
		suggestions = function(text)
			return Util.querySuggestions(text, suggestions, enumItems)
		end,
	}
end

return Util
