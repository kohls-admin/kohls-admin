type Dict = { [any]: any }
type List = { any }

local Logger = require(script.Logger)

--- @class Util
local Util = {
	Logger = Logger,
	ReadableTime = require(script.ReadableTime),
	Remote = require(script.Remote),
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

local userNameCache = {} :: { [number]: string }
function Util.getUserName(userId: number): string?
	if userNameCache[userId] then
		return userNameCache[userId]
	end

	local player = Util.Services.Players:GetPlayerByUserId(userId)
	if player then
		userNameCache[userId] = player.Name
		return player.Name
	end

	local ok, result = pcall(Util.Services.Players.GetNameFromUserIdAsync, Util.Services.Players, userId)
	if ok then
		userNameCache[userId] = result
		return result
	end

	return "Unknown"
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
	local copy = {}
	for key, value in original do
		if type(value) == "table" then
			value = Util.deepCopy(value)
		end
		copy[key] = value
	end
	return copy
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

function Util.querySuggestions(text: string, names: { string }, instances: { any })
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

return Util
